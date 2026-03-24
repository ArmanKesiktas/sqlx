import Foundation

@MainActor
final class TutorLabState: ObservableObject {
    @Published var query = ""
    @Published private(set) var result: SQLExecutionResult?
    @Published private(set) var errorText: String?
    @Published private(set) var schemaDescription = ""
    @Published var isLabVisible = false

    func setResult(_ result: SQLExecutionResult) {
        self.result = result
        self.errorText = nil
    }

    func setError(_ error: String) {
        self.errorText = error
        self.result = nil
    }

    func clearResult() {
        result = nil
        errorText = nil
    }

    func updateSchema(_ description: String) {
        schemaDescription = description
        isLabVisible = true
    }
}

@MainActor
final class TutorViewModel: ObservableObject {
    @Published private(set) var messages: [TutorChatMessage] = []
    @Published var inputText = ""
    @Published private(set) var quickReplies: [String] = []
    @Published private(set) var isTyping = false
    @Published private(set) var isPreparingResponse = false
    @Published private(set) var pendingAudioForPlayback: Data?
    @Published private(set) var pendingAnimationDuration: TimeInterval?
    @Published private(set) var currentLessonTitle = ""
    @Published private(set) var currentObjective = ""
    @Published private(set) var competency: TutorCompetencyProfile = .empty
    @Published private(set) var activePanel: TutorPanel = .chat

    let labState = TutorLabState()

    enum TutorPanel: String, CaseIterable {
        case chat
        case editor
    }

    private let package: TutorPackage
    private let localization: LocalizationService
    private let aiService: any TutorAIProviding
    private let contextService: TutorContextService
    private let masteryService: TutorMasteryService
    private let promptService: TutorScenePromptService
    private let sqlExecutionService = SQLExecutionService()
    private let initialLessonIndex: Int

    private let isLabSceneCompleted: (String) -> Bool
    private let onSaveSceneProgress: (Int, String) -> Void
    private let onMarkLabSceneCompleted: (String) -> Void
    private let onApprove: ((Int) -> Void)?
    private let onLessonCompleted: ((String, [String], Int) -> Void)?
    private let onProfessionSaved: ((String) -> Void)?
    private let onMasteryStarted: ((String) -> Void)?
    private let onMiniTaskEvaluated: ((String, Bool) -> Void)?
    private let onMiniChallengeEvaluated: ((String, Bool) -> Void)?
    private let onCompetencyUpdated: ((TutorCompetencyProfile) -> Void)?

    // In-memory session cache: survives navigation pops, cleared on startOver
    private static var messageCache: [String: [TutorChatMessage]] = [:]

    /// Clears all in-memory chat caches for all packages (call on full progress reset).
    static func clearAllCache() {
        messageCache = [:]
    }

    private var storedProfession: String?
    private var hasStarted = false
    private var currentLessonIndex = 0
    private var currentContext: TutorSQLContext?

    var hasSavedSession: Bool { !messages.isEmpty }

    var storyboardSceneIDs: [String] {
        package.interests.map(\.id)
    }

    init(
        package: TutorPackage,
        localization: LocalizationService,
        storedProfession: String? = nil,
        aiService: any TutorAIProviding = GeminiTutorService(),
        contextService: TutorContextService = TutorContextService(),
        masteryService: TutorMasteryService = TutorMasteryService(),
        initialSceneIndex: Int = 0,
        competency: TutorCompetencyProfile = .empty,
        isLabSceneCompleted: @escaping (String) -> Bool = { _ in false },
        onSaveSceneProgress: @escaping (Int, String) -> Void = { _, _ in },
        onMarkLabSceneCompleted: @escaping (String) -> Void = { _ in },
        onApprove: ((Int) -> Void)? = nil,
        onLessonCompleted: ((String, [String], Int) -> Void)? = nil,
        onProfessionSaved: ((String) -> Void)? = nil,
        onMasteryStarted: ((String) -> Void)? = nil,
        onMiniTaskEvaluated: ((String, Bool) -> Void)? = nil,
        onMiniChallengeEvaluated: ((String, Bool) -> Void)? = nil,
        onCompetencyUpdated: ((TutorCompetencyProfile) -> Void)? = nil
    ) {
        self.package = package
        self.localization = localization
        self.aiService = aiService
        self.contextService = contextService
        self.masteryService = masteryService
        self.promptService = TutorScenePromptService(localization: localization)
        self.initialLessonIndex = min(max(0, initialSceneIndex), max(0, package.interests.count - 1))
        self.isLabSceneCompleted = isLabSceneCompleted
        self.onSaveSceneProgress = onSaveSceneProgress
        self.onMarkLabSceneCompleted = onMarkLabSceneCompleted
        self.onApprove = onApprove
        self.onLessonCompleted = onLessonCompleted
        self.onProfessionSaved = onProfessionSaved
        self.onMasteryStarted = onMasteryStarted
        self.onMiniTaskEvaluated = onMiniTaskEvaluated
        self.onMiniChallengeEvaluated = onMiniChallengeEvaluated
        self.onCompetencyUpdated = onCompetencyUpdated
        self.storedProfession = storedProfession?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.currentLessonIndex = self.initialLessonIndex
        self.competency = competency
        // Restore saved session (avoids stuck-waiting on re-entry)
        if let cached = Self.messageCache[package.id], !cached.isEmpty {
            self.messages = cached
        }
    }

    private let speech = SpeechManager.shared

    func clearPendingAudio() {
        pendingAudioForPlayback = nil
        pendingAnimationDuration = nil
    }

    var sessionProgress: Double {
        guard !package.interests.isEmpty else { return 0 }
        return Double(currentLessonIndex) / Double(package.interests.count)
    }

    var estimatedProgressLabel: String {
        let tr = "Ders \(currentLessonIndex + 1)/\(max(1, package.interests.count))"
        let en = "Lesson \(currentLessonIndex + 1)/\(max(1, package.interests.count))"
        return localization.language == .tr ? tr : en
    }

    /// Call when re-entering a session that was interrupted mid-response.
    func resumeIfPendingResponse() {
        guard !hasStarted, messages.last?.role == .user else { return }
        hasStarted = true
        Task { await continueConversation() }
    }

    func startSessionIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        guard messages.isEmpty else { return }  // Existing session — show saved messages
        if let storedProfession, !storedProfession.isEmpty {
            Task { await beginLesson() }
        } else {
            appendMessage(
                role: .assistant,
                text: localization.language == .tr
                    ? "Merhaba! Ben SQL koçunuzum. Size uygun örnekler verebilmem için mesleğiniz veya ilginizi çeken bir alan nedir?"
                    : "Hi! I am your SQL coach. To give you relevant examples, what is your profession or an area of interest?",
                tone: .neutral
            )
        }
    }

    func startOver() {
        messages.removeAll()
        Self.messageCache[package.id] = nil
        hasStarted = true
        currentLessonIndex = 0
        labState.clearResult()
        labState.query = ""
        labState.isLabVisible = false

        appendMessage(
            role: .assistant,
            text: localization.language == .tr
                ? "Merhaba! Ben SQL koçunuzum. Size uygun örnekler verebilmem için mesleğiniz veya ilginizi çeken bir alan nedir?"
                : "Hi! I am your SQL coach. To give you relevant examples, what is your profession or an area of interest?",
            tone: .neutral
        )
    }

    func sendFromInput() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isTyping else { return }
        inputText = ""
        appendMessage(role: .user, text: trimmed, tone: .neutral)

        if let prof = storedProfession, !prof.isEmpty {
            Task { await continueConversation() }
        } else {
            storedProfession = trimmed
            onProfessionSaved?(trimmed)
            Task { await beginLesson() }
        }
    }

    func sendQuickReply(_ option: String) {
        guard !isTyping else { return }
        appendMessage(role: .user, text: option, tone: .neutral)
        Task { await continueConversation() }
    }

    func runCurrentLabQuery() {
        let trimmed = labState.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            labState.setError(SQLExecutionError.emptyQuery.localizedDescription)
            return
        }

        let interest = package.interests[currentLessonIndex]
        let context = currentContext ?? contextService.fallbackContext(profession: storedProfession ?? "Software", interest: interest)
        let targetCommand = contextService.buildCommand(interest: interest, context: context)

        competency.attemptedQueries += 1

        do {
            try prepareLabEnvironment(for: interest, context: context, command: targetCommand)
            let result = try sqlExecutionService.execute(trimmed)
            labState.setResult(result)
            competency.successfulQueries += 1
            onCompetencyUpdated?(competency)

            appendMessage(
                role: .user,
                text: "Here is the query I ran:\n```sql\n\(trimmed)\n```\nAnd the result had \(result.rows.count) rows.",
                result: result,
                tone: .neutral
            )

            Task { await continueConversation() }
        } catch {
            labState.setError(error.localizedDescription)

            let lessonKind = interest.lessonKind.rawValue
            if !competency.weakAreas.contains(lessonKind) {
                competency.weakAreas.append(lessonKind)
            }
            onCompetencyUpdated?(competency)
        }
    }

    func refreshCurrentSceneNarration() {
        Task { await continueConversation() }
    }

    func switchPanel(to panel: TutorPanel) {
        activePanel = panel
    }

    // MARK: - Private AI Flow Logic

    private func beginLesson() async {
        guard currentLessonIndex < package.interests.count else { return }
        isTyping = true  // Show skeleton immediately while resolving context
        await resolveContextForCurrentLesson()
        await continueConversation()
    }

    private func resolveContextForCurrentLesson() async {
        let interest = package.interests[currentLessonIndex]
        let prof = storedProfession ?? "General"

        let context = await contextService.requestAIGeneratedContext(
            profession: prof,
            lessonKind: interest.lessonKind,
            interest: interest,
            aiService: aiService
        )
        currentContext = context
        updateSchemaDescription(context: context)
    }

    private func continueConversation() async {
        guard currentLessonIndex < package.interests.count else { return }
        let interest = package.interests[currentLessonIndex]
        let prof = storedProfession ?? "General"
        let context = currentContext ?? contextService.fallbackContext(profession: prof, interest: interest)
        let targetCommand = contextService.buildCommand(interest: interest, context: context)

        let systemPrompt = promptService.generateSystemPrompt(
            package: package,
            interest: interest,
            profession: prof,
            context: context,
            targetCommand: targetCommand,
            competency: competency
        )

        isTyping = true
        quickReplies.removeAll()

        // 1. Generate AI response
        let responseText = await aiService.generate(systemPrompt: systemPrompt, messages: messages)

        guard let finalText = responseText else {
            isTyping = false
            // Append fallback so the screen never stays stuck at the connecting view
            appendMessage(
                role: .assistant,
                text: localization.language == .tr
                    ? "Bağlantı sorunu yaşandı. Lütfen tekrar deneyin."
                    : "A connection issue occurred. Please try again.",
                tone: .neutral
            )
            return
        }

        // 2. AI response ready — show skeleton while fetching TTS
        isTyping = false
        isPreparingResponse = true

        // 3. Pre-fetch TTS audio (synced with text animation)
        speech.resetSpokenTracking()
        if let result = await speech.prefetchAudio(for: finalText) {
            pendingAudioForPlayback = result.data
            pendingAnimationDuration = result.duration
        }

        // 4. Deliver the message (audio + text start together)
        handleAIResponse(finalText)
        isPreparingResponse = false
    }

    private func handleAIResponse(_ rawText: String) {
        var cleanText = rawText

        let hasLabTrigger = cleanText.contains("[SHOW_LAB]")
        let hasCompleteTrigger = cleanText.contains("[LESSON_COMPLETE]")
        let hasSchemaTrigger = cleanText.contains("[SHOW_SCHEMA]")

        cleanText = cleanText.replacingOccurrences(of: "[SHOW_LAB]", with: "")
        cleanText = cleanText.replacingOccurrences(of: "[LESSON_COMPLETE]", with: "")
        cleanText = cleanText.replacingOccurrences(of: "[SHOW_SCHEMA]", with: "")
        cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)

        appendMessage(role: .assistant, text: cleanText, tone: .neutral)

        if hasSchemaTrigger {
            if let ctx = currentContext {
                updateSchemaDescription(context: ctx)
            }
            labState.isLabVisible = true
            // Don't auto-switch — let the pulse animation guide the user
        }

        if hasLabTrigger {
            labState.isLabVisible = true
            // Don't auto-switch — let the pulse animation guide the user
        }

        if hasCompleteTrigger {
            let interest = package.interests[currentLessonIndex]
            completeCurrentLesson(interest: interest)
        }
    }

    private func completeCurrentLesson(interest: TutorInterest) {
        competency.completedLessonKinds.insert(interest.lessonKind.rawValue)
        competency.weakAreas.removeAll { $0 == interest.lessonKind.rawValue }
        if !competency.strongAreas.contains(interest.lessonKind.rawValue) {
            competency.strongAreas.append(interest.lessonKind.rawValue)
        }
        onCompetencyUpdated?(competency)

        onLessonCompleted?(interest.id, [labState.query], 100)
        onApprove?(20)

        if currentLessonIndex + 1 < package.interests.count {
            currentLessonIndex += 1
            quickReplies = [localization.language == .tr ? "Sonraki Derse Geç" : "Next Lesson"]
            onSaveSceneProgress(currentLessonIndex, package.interests[currentLessonIndex].id)
            Task { await resolveContextForCurrentLesson() }
        } else {
            quickReplies = [localization.language == .tr ? "Paketi Bitir" : "Finish Package"]
        }
    }

    private func updateSchemaDescription(context: TutorSQLContext) {
        let desc = """
        Primary: \(context.primaryTable)
          - \(context.metricColumn) (INTEGER)
          - \(context.filterColumn) (TEXT)
          - \(context.dimensionColumn) (TEXT)
        Secondary: \(context.secondaryTable)
          - \(context.joinSecondaryColumn) (INTEGER PK)
          - \(context.dimensionColumn) (TEXT)
        """
        labState.updateSchema(desc)
        currentLessonTitle = localization.text(package.interests[currentLessonIndex].titleKey)
    }

    private func appendMessage(role: TutorChatMessage.Role, text: String, result: SQLExecutionResult? = nil, tone: TutorChatMessage.Tone) {
        let msg = TutorChatMessage(id: UUID(), role: role, text: text, result: result, sceneID: nil, ctaOptions: [], tone: tone)
        messages.append(msg)
        Self.messageCache[package.id] = messages
    }

    private func prepareLabEnvironment(for interest: TutorInterest, context: TutorSQLContext, command: String) throws {
        let setupSQL = contextService.previewSetupSQL(interest: interest, context: context)
        try sqlExecutionService.reset(setupStatements: setupSQL)
    }
}
