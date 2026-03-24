import AuthenticationServices
import Foundation
import SwiftUI

protocol AppleCredentialStateChecking: Sendable {
    func credentialState(for userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState
}

struct AppleCredentialStateChecker: AppleCredentialStateChecking {
    func credentialState(for userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }
}

enum AppRoute: Equatable {
    case allPopularPackages
    case allTutorPackages
    case examMode
}

@MainActor
final class AppState: ObservableObject {
    let localization: LocalizationService
    let contentRepository: ContentRepository
    let progressStore: ProgressStore
    let challengeEvaluator: ChallengeEvaluationService
    let storeKitService: StoreKitService
    private let appleCredentialChecker: AppleCredentialStateChecking
    private let aiTutorAPIService: AITutorAPIService
    private let retentionService: RetentionService
    private let examEngineService: ExamEngineService
    private let backupSyncService: BackupSyncService
    private let certificateService: CertificateService
    private let reminderNotificationService: ReminderNotificationService
    private let processInfo: ProcessInfo

    @Published private(set) var modules: [LearningModule]
    @Published private(set) var badges: [Badge]
    @Published private(set) var tutorPackages: [TutorPackage]
    @Published private(set) var careerPaths: [CareerPath]
    @Published private(set) var progress: UserProgress
    @Published var routeRequest: AppRoute?
    @Published var pendingBadgeNotification: Badge?
    @Published private(set) var currentExamSession: ExamSession?
    @Published private(set) var lastExamAttempt: ExamAttempt?

    private let tutorPackageIDMigration: [String: String] = [
        "operations_analytics": "intermediate_sql",
        "growth_analytics": "senior_sql"
    ]

    init(
        localization: LocalizationService = LocalizationService(),
        contentRepository: ContentRepository = ContentRepository(),
        progressStore: ProgressStore = ProgressStore(),
        challengeEvaluator: ChallengeEvaluationService = ChallengeEvaluationService(),
        storeKitService: StoreKitService = StoreKitService(),
        appleCredentialChecker: AppleCredentialStateChecking = AppleCredentialStateChecker(),
        aiTutorAPIService: AITutorAPIService = AITutorAPIService(),
        retentionService: RetentionService = RetentionService(),
        examEngineService: ExamEngineService = ExamEngineService(),
        backupSyncService: BackupSyncService = BackupSyncService(),
        certificateService: CertificateService = CertificateService(),
        reminderNotificationService: ReminderNotificationService = ReminderNotificationService(),
        processInfo: ProcessInfo = .processInfo
    ) {
        self.localization = localization
        self.contentRepository = contentRepository
        self.progressStore = progressStore
        self.challengeEvaluator = challengeEvaluator
        self.storeKitService = storeKitService
        self.appleCredentialChecker = appleCredentialChecker
        self.aiTutorAPIService = aiTutorAPIService
        self.retentionService = retentionService
        self.examEngineService = examEngineService
        self.backupSyncService = backupSyncService
        self.certificateService = certificateService
        self.reminderNotificationService = reminderNotificationService
        self.processInfo = processInfo

        self.modules = contentRepository.loadModulesWithBonusChallenges()
        self.badges = contentRepository.badges()
        self.tutorPackages = contentRepository.tutorPackages()
        self.careerPaths = contentRepository.loadCareerPaths()

        if processInfo.environment["UITEST_RESET_PROGRESS"] == "1" {
            progressStore.reset()
        }
        self.progress = progressStore.load()
        if processInfo.environment["UITEST_BYPASS_AUTH"] == "1" {
            progress.hasCompletedOnboarding = true
            if progress.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                progress.displayName = "Tester"
            }
            progressStore.save(progress)
        }
        migrateTutorPackageIDsIfNeeded()
        progressStore.touchDailyActivity(progress: &progress)
        progressStore.applyBadges(progress: &progress, badges: badges)
        progressStore.save(progress)
    }

    var allChallenges: [SQLChallenge] {
        modules.flatMap(\.challenges)
    }

    var displayName: String {
        progress.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var appearanceMode: AppAppearanceMode {
        progress.appearanceMode
    }

    /// True if user has an active Plus subscription (via StoreKit) or was locally activated.
    var isPlus: Bool {
        storeKitService.isSubscribed || progress.isPlus
    }

    func activatePlus() {
        progress.isPlus = true
        persistProgress()
    }

    func deactivatePlus() {
        progress.isPlus = false
        persistProgress()
    }

    /// Syncs StoreKit subscription status → local progress.isPlus.
    /// Call on app launch after StoreKit loads.
    func syncSubscriptionStatus() async {
        await storeKitService.refreshSubscriptionStatus()
        if storeKitService.isSubscribed && !progress.isPlus {
            activatePlus()
        }
    }

    var resolvedPreferredColorScheme: ColorScheme? {
        switch progress.appearanceMode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    private func tutorLessonID(packageID: String, interestID: String) -> String {
        "\(packageID):\(interestID)"
    }

    func consumeRouteRequest() {
        routeRequest = nil
    }

    func openAllPopularPackages() {
        routeRequest = .allPopularPackages
    }

    func openAllTutorPackages() {
        routeRequest = .allTutorPackages
    }

    func openExamMode() {
        routeRequest = .examMode
    }

    func scoreForModule(_ moduleID: String) -> Int {
        progress.quizScores[moduleID] ?? 0
    }

    func moduleCompletionRatio() -> Double {
        guard !modules.isEmpty else { return 0 }
        return Double(progress.completedModuleIDs.count) / Double(modules.count)
    }

    func challengeCompletionRatio() -> Double {
        let count = allChallenges.count
        guard count > 0 else { return 0 }
        return Double(progress.completedChallengeIDs.count) / Double(count)
    }

    func tutorPackageProgress(packageID: String) -> Double {
        guard let package = tutorPackages.first(where: { $0.id == packageID }) else { return 0 }
        let lessonCount = package.interests.count
        guard lessonCount > 0 else { return 0 }
        let completedCount = package.interests.reduce(0) { partial, interest in
            let lessonID = tutorLessonID(packageID: packageID, interestID: interest.id)
            return partial + (progress.completedTutorLessonIDs.contains(lessonID) ? 1 : 0)
        }
        return Double(completedCount) / Double(lessonCount)
    }

    func isTutorLessonCompleted(packageID: String, interestID: String) -> Bool {
        progress.completedTutorLessonIDs.contains(tutorLessonID(packageID: packageID, interestID: interestID))
    }

    func masteryStatus(packageID: String, interestID: String) -> MasteryStatus {
        progress.tutorMasteryStatusByLessonID[tutorLessonID(packageID: packageID, interestID: interestID)] ?? .empty
    }

    func activeTutorPackages() -> [TutorPackage] {
        tutorPackages.filter { package in
            progress.startedTutorPackageIDs.contains(package.id)
                && tutorPackageProgress(packageID: package.id) < 1.0
        }
    }

    func mostRecentActiveTutorPackage() -> TutorPackage? {
        activeTutorPackages().sorted { a, b in
            let aIndex = progress.tutorCurrentSceneIndexByPackageID[a.id] ?? -1
            let bIndex = progress.tutorCurrentSceneIndexByPackageID[b.id] ?? -1
            return aIndex > bIndex
        }.first
    }

    func resumeTutorPackage(packageID: String) -> Int {
        max(0, progress.tutorCurrentSceneIndexByPackageID[packageID] ?? 0)
    }

    func restartTutorPackage(packageID: String, sceneIDs: [String]) {
        progress.tutorCurrentSceneIndexByPackageID.removeValue(forKey: packageID)
        progress.tutorLastVisitedSceneIDByPackageID.removeValue(forKey: packageID)
        progress.tutorProfessionByPackageID.removeValue(forKey: packageID)
        progress.tutorCompletedLabSceneIDs.subtract(sceneIDs)
        persistProgress()
    }

    func saveTutorSceneProgress(packageID: String, sceneIndex: Int, sceneID: String) {
        progress.startedTutorPackageIDs.insert(packageID)
        progress.tutorCurrentSceneIndexByPackageID[packageID] = max(0, sceneIndex)
        progress.tutorLastVisitedSceneIDByPackageID[packageID] = sceneID
        persistProgress()
    }

    func markTutorLabSceneCompleted(sceneID: String) {
        progress.tutorCompletedLabSceneIDs.insert(sceneID)
        persistProgress()
    }

    func isTutorLabSceneCompleted(sceneID: String) -> Bool {
        progress.tutorCompletedLabSceneIDs.contains(sceneID)
    }

    func startTutorPackage(_ packageID: String) {
        progress.startedTutorPackageIDs.insert(packageID)
        persistProgress()
    }

    func startTutorMastery(packageID: String, interestID: String) {
        let lessonID = tutorLessonID(packageID: packageID, interestID: interestID)
        var status = progress.tutorMasteryStatusByLessonID[lessonID] ?? .empty
        status.state = .inProgress
        status.attempts += 1
        status.lastUpdatedAt = Date()
        progress.tutorMasteryStatusByLessonID[lessonID] = status
        persistProgress()
    }

    func submitTutorMiniTask(packageID: String, interestID: String, isCorrect: Bool) {
        let lessonID = tutorLessonID(packageID: packageID, interestID: interestID)
        var status = progress.tutorMasteryStatusByLessonID[lessonID] ?? .empty
        status.state = isCorrect ? .inProgress : .failed
        status.lastUpdatedAt = Date()
        progress.tutorMasteryStatusByLessonID[lessonID] = status
        if !isCorrect {
            retentionService.scheduleReviewItems(
                progress: &progress,
                topicID: lessonID,
                source: "tutor_mini_task",
                baseDate: Date()
            )
        }
        persistProgress()
    }

    func submitTutorMiniChallenge(packageID: String, interestID: String, isCorrect: Bool) {
        let lessonID = tutorLessonID(packageID: packageID, interestID: interestID)
        var status = progress.tutorMasteryStatusByLessonID[lessonID] ?? .empty
        status.state = isCorrect ? .inProgress : .failed
        status.lastUpdatedAt = Date()
        progress.tutorMasteryStatusByLessonID[lessonID] = status
        if !isCorrect {
            retentionService.scheduleReviewItems(
                progress: &progress,
                topicID: lessonID,
                source: "tutor_mini_challenge",
                baseDate: Date()
            )
        }
        persistProgress()
    }

    func canCompleteTutorLesson(packageID: String, interestID: String) -> Bool {
        let status = masteryStatus(packageID: packageID, interestID: interestID)
        return status.state == .passed && status.score >= 80
    }

    func completeTutorLesson(
        packageID: String,
        interestID: String,
        masteryScore: Int = 100,
        evidenceSQL: [String] = []
    ) {
        progress.startedTutorPackageIDs.insert(packageID)
        let lessonID = tutorLessonID(packageID: packageID, interestID: interestID)
        let passed = masteryScore >= 80
        progress.tutorMasteryStatusByLessonID[lessonID] = MasteryStatus(
            state: passed ? .passed : .failed,
            score: masteryScore,
            attempts: max(1, progress.tutorMasteryStatusByLessonID[lessonID]?.attempts ?? 1),
            lastUpdatedAt: Date()
        )
        guard passed else {
            persistProgress()
            return
        }
        progress.completedTutorLessonIDs.insert(lessonID)

        if let package = tutorPackages.first(where: { $0.id == packageID }),
           let interest = package.interests.first(where: { $0.id == interestID }),
           !progress.certificateRecords.contains(where: { $0.packageID == packageID && $0.interestID == interestID }) {
            let record = certificateService.makeRecord(
                packageID: packageID,
                interestID: interestID,
                packageTitle: localization.text(package.titleKey),
                lessonTitle: localization.text(interest.titleKey),
                displayName: displayName,
                masteryScore: masteryScore,
                summarySQL: evidenceSQL.isEmpty ? ["SELECT * FROM \(interest.tableName);"] : evidenceSQL
            )
            progress.certificateRecords.append(record)
        }
        persistProgress()
    }

    func setTutorProfession(packageID: String, profession: String) {
        let trimmed = profession.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        progress.tutorProfessionByPackageID[packageID] = trimmed
        persistProgress()
    }

    func tutorProfession(packageID: String) -> String? {
        let value = progress.tutorProfessionByPackageID[packageID]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value, !value.isEmpty {
            return value
        }
        return nil
    }

    func tutorCompetency(packageID: String) -> TutorCompetencyProfile {
        progress.tutorCompetencyByPackageID[packageID] ?? .empty
    }

    func updateTutorCompetency(packageID: String, competency: TutorCompetencyProfile) {
        progress.tutorCompetencyByPackageID[packageID] = competency
        persistProgress()
    }

    func completeModule(_ moduleID: String) {
        progress.completedModuleIDs.insert(moduleID)
        persistProgress()
    }

    func calculateQuizScore(for module: LearningModule, selectedOptions: [String: String]) -> Int {
        let total = module.quiz.count
        guard total > 0 else { return 0 }
        let correct = module.quiz.reduce(0) { partial, question in
            partial + (selectedOptions[question.id] == question.correctOptionID ? 1 : 0)
        }
        return Int((Double(correct) / Double(total)) * 100.0)
    }

    func submitQuiz(moduleID: String, score: Int) {
        progress.quizScores[moduleID] = max(progress.quizScores[moduleID] ?? 0, score)
        if score >= 80 {
            progress.completedModuleIDs.insert(moduleID)
        } else {
            retentionService.scheduleReviewItems(
                progress: &progress,
                topicID: moduleID,
                source: "module_quiz",
                baseDate: Date()
            )
        }
        persistProgress()
    }

    func completeChallenge(_ challenge: SQLChallenge) {
        let inserted = progress.completedChallengeIDs.insert(challenge.id).inserted
        if inserted {
            progress.totalPoints += challenge.points
        }
        persistProgress()
    }

    func addPoints(_ points: Int) {
        progress.totalPoints += max(0, points)
        persistProgress()
    }

    func currentDailyMissions() -> [DailyMissionState] {
        let beforeCount = progress.dailyMissionStateByDate.count
        let missions = retentionService.currentDailyMissions(
            progress: &progress,
            modules: modules,
            challenges: allChallenges,
            packages: tutorPackages,
            localize: { [weak localization] key in
                localization?.text(key) ?? key
            },
            now: Date()
        )
        if progress.dailyMissionStateByDate.count != beforeCount {
            persistProgress()
        }
        return missions
    }

    func completeDailyMission(missionID: String) {
        guard let completed = retentionService.completeMission(progress: &progress, missionID: missionID, now: Date()) else {
            return
        }
        progress.totalPoints += completed.mission.points

        if progress.lastNotificationPromptDate == nil {
            progress.lastNotificationPromptDate = Date()
            Task {
                let granted = await reminderNotificationService.requestAuthorization()
                if granted {
                    reminderNotificationService.scheduleDailyReminder()
                }
            }
        }
        persistProgress()
    }

    func dueReviewItems() -> [ReviewItem] {
        retentionService.dueReviewItems(progress: progress, now: Date())
    }

    func startExam(level: ExamLevel) {
        let session = examEngineService.makeSession(
            level: level,
            modules: modules,
            localize: { [weak localization] key in
                localization?.text(key) ?? key
            },
            now: Date()
        )
        currentExamSession = session
        openExamMode()
    }

    func submitExamAnswer(questionID: String, answer: String) {
        guard var session = currentExamSession else { return }
        examEngineService.submitAnswer(answer, for: questionID, in: &session)
        currentExamSession = session
    }

    func finishExam() {
        guard let session = currentExamSession else { return }
        let attempt = examEngineService.evaluate(session, finishedAt: Date())
        lastExamAttempt = attempt
        progress.examHistory.insert(attempt, at: 0)

        for topic in attempt.weakTopicIDs {
            retentionService.scheduleReviewItems(
                progress: &progress,
                topicID: topic,
                source: "exam",
                baseDate: Date()
            )
        }

        currentExamSession = nil
        persistProgress()
    }

    func cancelExam() {
        currentExamSession = nil
    }

    func remainingExamSeconds(now: Date = Date()) -> Int {
        guard let session = currentExamSession else { return 0 }
        return max(0, Int(session.endAt.timeIntervalSince(now)))
    }

    func exportProgressJSON() -> Data? {
        try? backupSyncService.exportJSON(progress: progress)
    }

    func exportProgressJSONFileURL() -> URL? {
        guard let data = exportProgressJSON() else { return nil }
        return certificateService.writeTemporaryJSON(data, fileName: "sqlx_progress_backup")
    }

    func importProgressJSON(data: Data) -> Bool {
        guard let imported = try? backupSyncService.importJSON(data: data) else {
            return false
        }
        progress = backupSyncService.merge(local: progress, remote: imported)
        persistProgress()
        return true
    }

    func syncProgressToICloud() {
        backupSyncService.syncToICloud(progress: progress)
        progress.lastICloudSyncDate = Date()
        progressStore.save(progress)
    }

    func restoreProgressFromICloud() -> Bool {
        guard let restored = backupSyncService.restoreFromICloud(localProgress: progress) else {
            return false
        }
        progress = restored
        persistProgress()
        return true
    }

    func exportCertificatePDF(recordID: String) -> URL? {
        guard let record = progress.certificateRecords.first(where: { $0.id == recordID }),
              let data = certificateService.makeCertificatePDF(record: record) else {
            return nil
        }
        return certificateService.writeTemporaryPDF(data, fileName: "sqlx_certificate_\(record.packageID)_\(record.interestID)")
    }

    func projectSummaryText(recordID: String) -> String? {
        guard let record = progress.certificateRecords.first(where: { $0.id == recordID }) else {
            return nil
        }
        let lines = record.summarySQL.map { "- \($0)" }.joined(separator: "\n")
        return """
        \(record.title)
        \(record.subtitle)
        Score: \(record.masteryScore)%

        SQL Summary
        \(lines)
        """
    }

    func setAppearanceMode(_ mode: AppAppearanceMode) {
        guard progress.appearanceMode != mode else { return }
        progress.appearanceMode = mode
        persistProgress()
    }

    func resetProgress() {
        let preservedAppearance = progress.appearanceMode
        progressStore.reset()
        progress = .empty
        progress.appearanceMode = preservedAppearance
        progressStore.touchDailyActivity(progress: &progress)
        persistProgress()
        // Clear AI chat cache so conversations start fresh
        TutorViewModel.clearAllCache()
        Task {
            await aiTutorAPIService.clearSession()
        }
    }

    func authenticateLocally(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        progress.displayName = trimmed.isEmpty ? localization.text("onboarding.defaultName") : trimmed
        progress.hasCompletedOnboarding = true
        persistProgress()
    }

    func completeOnboarding(name: String) {
        authenticateLocally(name: name)
    }

    func setDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        progress.displayName = trimmed
        persistProgress()
    }

    @discardableResult
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async -> Bool {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return false }
            let fallbackName = credential.fullName.flatMap { fullName -> String? in
                let text = PersonNameComponentsFormatter().string(from: fullName)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? nil : text
            }
            if let tokenData = credential.identityToken,
               let identityToken = String(data: tokenData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !identityToken.isEmpty,
               let session = await aiTutorAPIService.authenticateWithApple(
                    identityToken: identityToken,
                    displayName: fallbackName
               ),
               applyAppleSignInSession(session, fallbackName: fallbackName) {
                return true
            }

            let localOnlyApplied = handleAppleSignIn(userID: credential.user, fullName: credential.fullName)
            if localOnlyApplied, progress.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                progress.displayName = fallbackName ?? localization.text("onboarding.defaultName")
                persistProgress()
            }
            return localOnlyApplied
        case .failure:
            return false
        }
    }

    @discardableResult
    func handleAppleSignIn(userID: String, fullName: PersonNameComponents?) -> Bool {
        let trimmedID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return false }

        progress.appleUserID = trimmedID
        progress.isAppleSignedIn = true
        let fallbackName = fullName.flatMap { components -> String? in
            let formatted = PersonNameComponentsFormatter().string(from: components)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return formatted.isEmpty ? nil : formatted
        }
        if let fallbackName {
            progress.displayName = fallbackName
        }
        // If we already have a name (returning user), skip onboarding
        if !progress.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            progress.hasCompletedOnboarding = true
        }
        // Auto-restore from iCloud on sign-in, then sync local progress up
        if let restored = backupSyncService.restoreFromICloud(localProgress: progress) {
            progress = restored
        }
        backupSyncService.syncToICloud(progress: progress)
        persistProgress()
        return true
    }

    func refreshAppleCredentialState() async {
        guard progress.isAppleSignedIn, let userID = progress.appleUserID, !userID.isEmpty else { return }
        let state = await appleCredentialChecker.credentialState(for: userID)
        guard state != .authorized else { return }
        progress.isAppleSignedIn = false
        progress.appleUserID = nil
        await aiTutorAPIService.clearSession()
        persistProgress()
    }

    private func applyAppleSignInSession(_ session: AIAuthSession, fallbackName: String?) -> Bool {
        let trimmedID = session.appleUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return false }
        progress.appleUserID = trimmedID
        progress.isAppleSignedIn = true

        let resolvedName = session.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let resolvedName, !resolvedName.isEmpty {
            progress.displayName = resolvedName
        } else if let fallbackName, !fallbackName.isEmpty {
            progress.displayName = fallbackName
        } else if progress.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            progress.displayName = localization.text("onboarding.defaultName")
        }
        // Name is always resolved at this point — skip onboarding on re-login
        progress.hasCompletedOnboarding = true
        // Auto-restore from iCloud on sign-in, then sync local progress up
        if let restored = backupSyncService.restoreFromICloud(localProgress: progress) {
            progress = restored
        }
        backupSyncService.syncToICloud(progress: progress)
        persistProgress()
        return true
    }

    func signOut() {
        // Save progress to iCloud before clearing local state
        backupSyncService.syncToICloud(progress: progress)
        let preservedAppearance = progress.appearanceMode
        progress.isAppleSignedIn = false
        progress.appleUserID = nil
        progress.hasCompletedOnboarding = false
        progress.displayName = ""
        progress.appearanceMode = preservedAppearance
        persistProgress()
        Task {
            await aiTutorAPIService.clearSession()
        }
    }

    private func persistProgress() {
        progressStore.touchDailyActivity(progress: &progress)
        let newBadges = progressStore.applyBadges(progress: &progress, badges: badges)
        progressStore.save(progress)
        backupSyncService.syncToICloud(progress: progress)
        if let first = newBadges.first {
            pendingBadgeNotification = first
        }
    }

    private func migrateTutorPackageIDsIfNeeded() {
        var changed = false

        var migratedStartedIDs = Set<String>()
        for packageID in progress.startedTutorPackageIDs {
            if let newID = tutorPackageIDMigration[packageID] {
                migratedStartedIDs.insert(newID)
                changed = true
            } else {
                migratedStartedIDs.insert(packageID)
            }
        }
        progress.startedTutorPackageIDs = migratedStartedIDs

        var migratedLessonIDs = Set<String>()
        for lessonID in progress.completedTutorLessonIDs {
            guard let separator = lessonID.firstIndex(of: ":") else {
                migratedLessonIDs.insert(lessonID)
                continue
            }
            let packageID = String(lessonID[..<separator])
            let suffix = String(lessonID[separator...])
            if let newID = tutorPackageIDMigration[packageID] {
                migratedLessonIDs.insert("\(newID)\(suffix)")
                changed = true
            } else {
                migratedLessonIDs.insert(lessonID)
            }
        }
        progress.completedTutorLessonIDs = migratedLessonIDs

        var migratedProfessionByPackageID: [String: String] = [:]
        for (packageID, profession) in progress.tutorProfessionByPackageID {
            if let newID = tutorPackageIDMigration[packageID] {
                migratedProfessionByPackageID[newID] = profession
                changed = true
            } else {
                migratedProfessionByPackageID[packageID] = profession
            }
        }
        progress.tutorProfessionByPackageID = migratedProfessionByPackageID

        var migratedSceneIndexByPackageID: [String: Int] = [:]
        for (packageID, sceneIndex) in progress.tutorCurrentSceneIndexByPackageID {
            if let newID = tutorPackageIDMigration[packageID] {
                migratedSceneIndexByPackageID[newID] = sceneIndex
                changed = true
            } else {
                migratedSceneIndexByPackageID[packageID] = sceneIndex
            }
        }
        progress.tutorCurrentSceneIndexByPackageID = migratedSceneIndexByPackageID

        var migratedLastSceneIDByPackageID: [String: String] = [:]
        for (packageID, sceneID) in progress.tutorLastVisitedSceneIDByPackageID {
            if let newID = tutorPackageIDMigration[packageID] {
                migratedLastSceneIDByPackageID[newID] = sceneID
                changed = true
            } else {
                migratedLastSceneIDByPackageID[packageID] = sceneID
            }
        }
        progress.tutorLastVisitedSceneIDByPackageID = migratedLastSceneIDByPackageID

        var migratedMasteryByLessonID: [String: MasteryStatus] = [:]
        for (lessonID, status) in progress.tutorMasteryStatusByLessonID {
            guard let separator = lessonID.firstIndex(of: ":") else {
                migratedMasteryByLessonID[lessonID] = status
                continue
            }
            let packageID = String(lessonID[..<separator])
            let suffix = String(lessonID[separator...])
            if let newID = tutorPackageIDMigration[packageID] {
                migratedMasteryByLessonID["\(newID)\(suffix)"] = status
                changed = true
            } else {
                migratedMasteryByLessonID[lessonID] = status
            }
        }
        progress.tutorMasteryStatusByLessonID = migratedMasteryByLessonID

        if changed {
            progressStore.save(progress)
        }
    }
}
