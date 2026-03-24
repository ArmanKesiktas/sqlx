import AuthenticationServices
import XCTest
@testable import SQLAcademy

@MainActor
final class TutorPackagesTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "TutorPackagesTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testAppStateTracksTutorPackageProgressAndActivePackages() {
        let localization = LocalizationService(
            userDefaults: defaults,
            preload: [.en: [:], .tr: [:]]
        )
        let appState = AppState(
            localization: localization,
            contentRepository: ContentRepository(),
            progressStore: ProgressStore(userDefaults: defaults),
            challengeEvaluator: ChallengeEvaluationService()
        )
        guard let package = appState.tutorPackages.first else {
            XCTFail("Expected at least one tutor package")
            return
        }

        XCTAssertEqual(appState.tutorPackageProgress(packageID: package.id), 0, accuracy: 0.0001)
        XCTAssertTrue(appState.activeTutorPackages().isEmpty)

        appState.startTutorPackage(package.id)
        XCTAssertTrue(appState.activeTutorPackages().contains(where: { $0.id == package.id }))

        let firstInterest = package.interests[0]
        appState.completeTutorLesson(packageID: package.id, interestID: firstInterest.id)
        XCTAssertEqual(
            appState.tutorPackageProgress(packageID: package.id),
            1.0 / Double(package.interests.count),
            accuracy: 0.0001
        )

        for interest in package.interests {
            appState.completeTutorLesson(packageID: package.id, interestID: interest.id)
        }

        XCTAssertEqual(appState.tutorPackageProgress(packageID: package.id), 1.0, accuracy: 0.0001)
        XCTAssertFalse(appState.activeTutorPackages().contains(where: { $0.id == package.id }))
    }

    func testTutorViewModelStartsSceneJourneyAfterProfessionInput() async throws {
        let localization = LocalizationService(
            userDefaults: defaults,
            preload: [
                .en: [
                    "pkg.title": "SQL Foundations",
                    "pkg.desc": "Description",
                    "interest.title": "Define SQL",
                    "tutor.askProfession": "What is your profession?",
                    "tutor.interest.sqlIntro.definition.desc": "Define SQL and relational databases."
                ],
                .tr: [:]
            ]
        )
        let package = TutorPackage(
            id: "data_analytics",
            titleKey: "pkg.title",
            descriptionKey: "pkg.desc",
            icon: "chart.line.uptrend.xyaxis",
            interests: [
                TutorInterest(
                    id: "sql_intro_definition",
                    titleKey: "interest.title",
                    descriptionKey: "tutor.interest.sqlIntro.definition.desc",
                    tableName: "campaign_metrics",
                    selectColumn: "clicks",
                    whereColumn: "channel",
                    whereValue: "social",
                    orderColumn: "clicks"
                )
            ]
        )
        let viewModel = TutorViewModel(
            package: package,
            localization: localization,
            aiService: MockTutorAIProvider(
                narrationResponse: "Scene narration response",
                scenarioResponse: #"{"primaryTable":"service_tickets","secondaryTable":"team_directory","metricColumn":"resolution_minutes","dimensionColumn":"team_name","filterColumn":"team","filterValue":"backend","orderColumn":"resolution_minutes","joinPrimaryColumn":"team_id","joinSecondaryColumn":"id"}"#,
                outputResponse: "Output explanation response"
            ),
            onApprove: nil,
            onLessonCompleted: nil,
            typingDelayNanoseconds: 0
        )

        viewModel.startSessionIfNeeded()
        await waitUntil { viewModel.messages.contains(where: { $0.role == .assistant }) }

        viewModel.inputText = "Software engineer"
        viewModel.sendFromInput()
        await waitUntil {
            viewModel.messages.contains(where: { $0.role == .assistant && $0.text == "Scene narration response" })
        }

        XCTAssertEqual(viewModel.currentLessonTitle, "Define SQL")
        XCTAssertFalse(viewModel.quickReplies.isEmpty)
        XCTAssertEqual(viewModel.messages.last(where: { $0.role == .assistant })?.sceneID, "sql_intro_definition_intro")
    }

    func testTutorViewModelStartOverPromptsForPersonaAgain() async {
        let localization = LocalizationService(
            userDefaults: defaults,
            preload: [
                .en: [
                    "pkg.title": "SQL Foundations",
                    "pkg.desc": "Description",
                    "interest.title": "Define SQL",
                    "tutor.askProfession": "What do you do or which kind of work interests you?",
                    "tutor.interest.sqlIntro.definition.desc": "Define SQL and relational databases."
                ],
                .tr: [:]
            ]
        )
        let package = TutorPackage(
            id: "data_analytics",
            titleKey: "pkg.title",
            descriptionKey: "pkg.desc",
            icon: "chart.line.uptrend.xyaxis",
            interests: [
                TutorInterest(
                    id: "sql_intro_definition",
                    titleKey: "interest.title",
                    descriptionKey: "tutor.interest.sqlIntro.definition.desc",
                    tableName: "campaign_metrics",
                    selectColumn: "clicks",
                    whereColumn: "channel",
                    whereValue: "social",
                    orderColumn: "clicks"
                )
            ]
        )
        let viewModel = TutorViewModel(
            package: package,
            localization: localization,
            storedProfession: "Software engineer",
            aiService: MockTutorAIProvider(
                narrationResponse: "Scene narration response",
                scenarioResponse: #"{"primaryTable":"service_tickets","secondaryTable":"team_directory","metricColumn":"resolution_minutes","dimensionColumn":"team_name","filterColumn":"team","filterValue":"backend","orderColumn":"resolution_minutes","joinPrimaryColumn":"team_id","joinSecondaryColumn":"id"}"#,
                outputResponse: "Output explanation response"
            ),
            typingDelayNanoseconds: 0
        )

        viewModel.startSessionIfNeeded()
        await waitUntil { !viewModel.messages.isEmpty && !viewModel.quickReplies.isEmpty }

        viewModel.startOver()
        await waitUntil {
            viewModel.messages.contains(where: {
                $0.role == .assistant && $0.text == "What do you do or which kind of work interests you?"
            })
        }

        XCTAssertEqual(viewModel.currentSceneTitle, "SQL Foundations")
        XCTAssertTrue(viewModel.quickReplies.isEmpty)
    }

    func testTutorViewModelRunsIntegratedMiniLabAndShowsResult() async throws {
        let localization = LocalizationService(
            userDefaults: defaults,
            preload: [
                .en: [
                    "pkg.title": "SQL Foundations",
                    "pkg.desc": "Description",
                    "interest.title": "Define SQL",
                    "tutor.askProfession": "What is your profession?",
                    "tutor.interest.sqlIntro.definition.desc": "Define SQL and relational databases."
                ],
                .tr: [:]
            ]
        )
        let package = TutorPackage(
            id: "data_analytics",
            titleKey: "pkg.title",
            descriptionKey: "pkg.desc",
            icon: "chart.line.uptrend.xyaxis",
            interests: [
                TutorInterest(
                    id: "sql_intro_definition",
                    titleKey: "interest.title",
                    descriptionKey: "tutor.interest.sqlIntro.definition.desc",
                    tableName: "campaign_metrics",
                    selectColumn: "clicks",
                    whereColumn: "channel",
                    whereValue: "social",
                    orderColumn: "clicks"
                )
            ]
        )
        let viewModel = TutorViewModel(
            package: package,
            localization: localization,
            aiService: MockTutorAIProvider(
                narrationResponse: "Scene narration response",
                scenarioResponse: #"{"primaryTable":"service_tickets","secondaryTable":"team_directory","metricColumn":"resolution_minutes","dimensionColumn":"team_name","filterColumn":"team","filterValue":"backend","orderColumn":"resolution_minutes","joinPrimaryColumn":"team_id","joinSecondaryColumn":"id"}"#,
                outputResponse: "Output explanation response"
            ),
            typingDelayNanoseconds: 0
        )
        viewModel.startSessionIfNeeded()
        await waitUntil { viewModel.messages.contains(where: { $0.role == .assistant }) }
        viewModel.inputText = "Software engineer"
        viewModel.sendFromInput()
        await waitUntil { !viewModel.quickReplies.isEmpty }

        for _ in 0..<6 where viewModel.canvasContent.mode != .miniLab {
            let previousSceneTitle = viewModel.currentSceneTitle
            let option = try XCTUnwrap(viewModel.quickReplies.first)
            viewModel.sendQuickReply(option)
            await waitUntil { viewModel.currentSceneTitle != previousSceneTitle }
        }

        XCTAssertEqual(viewModel.canvasContent.mode, .miniLab)
        viewModel.runCurrentLabQuery()
        await waitUntil { viewModel.labResult != nil }

        let firstResult = try XCTUnwrap(viewModel.labResult)
        XCTAssertFalse(firstResult.columns.isEmpty)
        XCTAssertFalse(firstResult.rows.isEmpty)
        XCTAssertTrue(viewModel.messages.contains(where: { $0.role == .assistant && $0.result != nil }))
    }

    func testTutorViewModelUsesFallbackWhenAIRequestFails() async {
        let localization = LocalizationService(
            userDefaults: defaults,
            preload: [
                .en: [
                    "pkg.title": "SQL Foundations",
                    "pkg.desc": "Description",
                    "interest.title": "Define SQL",
                    "tutor.askProfession": "What is your profession?",
                    "tutor.interest.sqlIntro.definition.desc": "Define SQL and relational databases."
                ],
                .tr: [:]
            ]
        )
        let package = TutorPackage(
            id: "data_analytics",
            titleKey: "pkg.title",
            descriptionKey: "pkg.desc",
            icon: "chart.line.uptrend.xyaxis",
            interests: [
                TutorInterest(
                    id: "sql_intro_definition",
                    titleKey: "interest.title",
                    descriptionKey: "tutor.interest.sqlIntro.definition.desc",
                    tableName: "campaign_metrics",
                    selectColumn: "clicks",
                    whereColumn: "channel",
                    whereValue: "social",
                    orderColumn: "clicks"
                )
            ]
        )
        let viewModel = TutorViewModel(
            package: package,
            localization: localization,
            aiService: MockTutorAIProvider(
                narrationResponse: nil,
                scenarioResponse: nil,
                outputResponse: nil
            ),
            typingDelayNanoseconds: 0
        )
        viewModel.startSessionIfNeeded()
        await waitUntil { viewModel.messages.contains(where: { $0.role == .assistant }) }

        viewModel.inputText = "Software engineer"
        viewModel.sendFromInput()
        await waitUntil { viewModel.messages.count >= 3 }

        let assistantMessage = viewModel.messages.last(where: { $0.role == .assistant })?.text
        XCTAssertNotNil(assistantMessage)
        XCTAssertTrue(assistantMessage?.contains("structured data") == true || assistantMessage?.contains("same SQL goal") == true)
    }

    func testAppStatePersistsTutorSceneProgressAndCompletedLabScene() {
        let progressStore = ProgressStore(userDefaults: defaults)
        let localization = LocalizationService(userDefaults: defaults, preload: [.en: [:], .tr: [:]])
        let appState = AppState(
            localization: localization,
            contentRepository: ContentRepository(),
            progressStore: progressStore,
            challengeEvaluator: ChallengeEvaluationService()
        )

        appState.saveTutorSceneProgress(packageID: "data_analytics", sceneIndex: 4, sceneID: "scene_4")
        appState.markTutorLabSceneCompleted(sceneID: "scene_lab")

        let reloaded = AppState(
            localization: localization,
            contentRepository: ContentRepository(),
            progressStore: progressStore,
            challengeEvaluator: ChallengeEvaluationService()
        )

        XCTAssertEqual(reloaded.resumeTutorPackage(packageID: "data_analytics"), 4)
        XCTAssertEqual(reloaded.progress.tutorLastVisitedSceneIDByPackageID["data_analytics"], "scene_4")
        XCTAssertTrue(reloaded.isTutorLabSceneCompleted(sceneID: "scene_lab"))
    }

    func testRestartTutorPackageClearsSessionStateButKeepsCompletion() {
        let progressStore = ProgressStore(userDefaults: defaults)
        let localization = LocalizationService(userDefaults: defaults, preload: [.en: [:], .tr: [:]])
        let appState = AppState(
            localization: localization,
            contentRepository: ContentRepository(),
            progressStore: progressStore,
            challengeEvaluator: ChallengeEvaluationService()
        )

        appState.saveTutorSceneProgress(packageID: "data_analytics", sceneIndex: 5, sceneID: "sql_intro_definition_lab")
        appState.markTutorLabSceneCompleted(sceneID: "sql_intro_definition_lab")
        appState.setTutorProfession(packageID: "data_analytics", profession: "Analyst")
        appState.completeTutorLesson(packageID: "data_analytics", interestID: "sql_intro_definition")

        appState.restartTutorPackage(
            packageID: "data_analytics",
            sceneIDs: ["sql_intro_definition_intro", "sql_intro_definition_lab"]
        )

        XCTAssertEqual(appState.resumeTutorPackage(packageID: "data_analytics"), 0)
        XCTAssertNil(appState.tutorProfession(packageID: "data_analytics"))
        XCTAssertFalse(appState.isTutorLabSceneCompleted(sceneID: "sql_intro_definition_lab"))
        XCTAssertTrue(appState.isTutorLessonCompleted(packageID: "data_analytics", interestID: "sql_intro_definition"))
    }

    func testAppStateMigratesLegacyTutorPackageIDsAndProfessionMap() {
        let progressStore = ProgressStore(userDefaults: defaults)
        var progress = UserProgress.empty
        progress.startedTutorPackageIDs = ["operations_analytics", "growth_analytics"]
        progress.completedTutorLessonIDs = [
            "operations_analytics:join_fundamentals",
            "growth_analytics:subquery_design"
        ]
        progress.tutorProfessionByPackageID = [
            "operations_analytics": "Bilgisayar mühendisi",
            "growth_analytics": "İnşaat işçisi"
        ]
        progressStore.save(progress)

        let localization = LocalizationService(
            userDefaults: defaults,
            preload: [.en: [:], .tr: [:]]
        )
        let appState = AppState(
            localization: localization,
            contentRepository: ContentRepository(),
            progressStore: progressStore,
            challengeEvaluator: ChallengeEvaluationService()
        )

        XCTAssertTrue(appState.progress.startedTutorPackageIDs.contains("intermediate_sql"))
        XCTAssertTrue(appState.progress.startedTutorPackageIDs.contains("senior_sql"))
        XCTAssertFalse(appState.progress.startedTutorPackageIDs.contains("operations_analytics"))
        XCTAssertFalse(appState.progress.startedTutorPackageIDs.contains("growth_analytics"))

        XCTAssertTrue(appState.progress.completedTutorLessonIDs.contains("intermediate_sql:join_fundamentals"))
        XCTAssertTrue(appState.progress.completedTutorLessonIDs.contains("senior_sql:subquery_design"))

        XCTAssertEqual(appState.tutorProfession(packageID: "intermediate_sql"), "Bilgisayar mühendisi")
        XCTAssertEqual(appState.tutorProfession(packageID: "senior_sql"), "İnşaat işçisi")
    }

    func testCompleteOnboardingPersistsNameAndFlag() {
        let progressStore = ProgressStore(userDefaults: defaults)
        let localization = LocalizationService(userDefaults: defaults, preload: [.en: [:], .tr: [:]])
        let appState = AppState(
            localization: localization,
            contentRepository: ContentRepository(),
            progressStore: progressStore,
            challengeEvaluator: ChallengeEvaluationService()
        )

        appState.completeOnboarding(name: "Arman")

        XCTAssertTrue(appState.progress.hasCompletedOnboarding)
        XCTAssertEqual(appState.displayName, "Arman")

        let loaded = progressStore.load()
        XCTAssertTrue(loaded.hasCompletedOnboarding)
        XCTAssertEqual(loaded.displayName, "Arman")
    }

    func testAppleSignInRequiresOnboardingCompletionAfterAuth() {
        let progressStore = ProgressStore(userDefaults: defaults)
        let localization = LocalizationService(userDefaults: defaults, preload: [.en: [:], .tr: [:]])
        let appState = AppState(
            localization: localization,
            contentRepository: ContentRepository(),
            progressStore: progressStore,
            challengeEvaluator: ChallengeEvaluationService()
        )

        XCTAssertTrue(appState.handleAppleSignIn(userID: "apple-user", fullName: nil))

        XCTAssertTrue(appState.progress.isAppleSignedIn)
        XCTAssertEqual(appState.progress.appleUserID, "apple-user")
        XCTAssertFalse(appState.progress.hasCompletedOnboarding)
    }

    func testRefreshAppleCredentialStateClearsInvalidCredential() async {
        let progressStore = ProgressStore(userDefaults: defaults)
        var progress = UserProgress.empty
        progress.hasCompletedOnboarding = true
        progress.appleUserID = "apple-user-1"
        progress.isAppleSignedIn = true
        progressStore.save(progress)

        let appState = AppState(
            localization: LocalizationService(userDefaults: defaults, preload: [.en: [:], .tr: [:]]),
            contentRepository: ContentRepository(),
            progressStore: progressStore,
            challengeEvaluator: ChallengeEvaluationService(),
            appleCredentialChecker: MockAppleCredentialChecker(state: .revoked)
        )

        await appState.refreshAppleCredentialState()

        XCTAssertFalse(appState.progress.isAppleSignedIn)
        XCTAssertNil(appState.progress.appleUserID)
    }

    func testRefreshAppleCredentialStateKeepsAuthorizedCredential() async {
        let progressStore = ProgressStore(userDefaults: defaults)
        var progress = UserProgress.empty
        progress.hasCompletedOnboarding = true
        progress.appleUserID = "apple-user-2"
        progress.isAppleSignedIn = true
        progressStore.save(progress)

        let appState = AppState(
            localization: LocalizationService(userDefaults: defaults, preload: [.en: [:], .tr: [:]]),
            contentRepository: ContentRepository(),
            progressStore: progressStore,
            challengeEvaluator: ChallengeEvaluationService(),
            appleCredentialChecker: MockAppleCredentialChecker(state: .authorized)
        )

        await appState.refreshAppleCredentialState()

        XCTAssertTrue(appState.progress.isAppleSignedIn)
        XCTAssertEqual(appState.progress.appleUserID, "apple-user-2")
    }

    private struct MockAppleCredentialChecker: AppleCredentialStateChecking {
        let state: ASAuthorizationAppleIDProvider.CredentialState

        func credentialState(for userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
            state
        }
    }

    private struct MockTutorAIProvider: TutorAIProviding {
        let narrationResponse: String?
        let scenarioResponse: String?
        let outputResponse: String?

        func generate(systemPrompt: String, userPrompt: String) async -> String? {
            narrationResponse
        }

        func generateSceneNarration(systemPrompt: String, userPrompt: String) async -> String? {
            narrationResponse
        }

        func generateScenarioAdaptation(systemPrompt: String, userPrompt: String) async -> String? {
            scenarioResponse
        }

        func generateOutputExplanation(systemPrompt: String, userPrompt: String) async -> String? {
            outputResponse
        }
    }

    private func waitUntil(
        timeoutSeconds: TimeInterval = 2.0,
        checkEveryNanos: UInt64 = 15_000_000,
        condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: checkEveryNanos)
        }
        XCTFail("Condition timed out.")
    }
}
