import XCTest
@testable import SQLAcademy

@MainActor
final class AppStateMasteryAndExamTests: XCTestCase {
    func testCompleteTutorLessonRequiresMasteryPass() {
        let appState = makeAppState()
        guard let package = appState.tutorPackages.first,
              let interest = package.interests.first else {
            XCTFail("Expected tutor content")
            return
        }

        appState.completeTutorLesson(packageID: package.id, interestID: interest.id, masteryScore: 79)

        XCTAssertFalse(appState.isTutorLessonCompleted(packageID: package.id, interestID: interest.id))
        XCTAssertFalse(appState.canCompleteTutorLesson(packageID: package.id, interestID: interest.id))

        appState.completeTutorLesson(packageID: package.id, interestID: interest.id, masteryScore: 80)

        XCTAssertTrue(appState.isTutorLessonCompleted(packageID: package.id, interestID: interest.id))
        XCTAssertTrue(appState.canCompleteTutorLesson(packageID: package.id, interestID: interest.id))
    }

    func testFinishExamStoresAttemptAndSchedulesReviewItemsOnFailure() {
        let appState = makeAppState()
        appState.startExam(level: .beginner)

        XCTAssertNotNil(appState.currentExamSession)
        appState.finishExam()

        XCTAssertNil(appState.currentExamSession)
        XCTAssertEqual(appState.progress.examHistory.count, 1)
        XCTAssertFalse(appState.progress.examHistory[0].passed)
        XCTAssertFalse(appState.progress.reviewQueue.isEmpty)
    }

    func testAppearanceModeResolutionAndPersistence() {
        let suiteName = "AppStateMasteryAndExamTests-Appearance-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let appState = AppState(
            localization: LocalizationService(userDefaults: defaults),
            contentRepository: ContentRepository(),
            progressStore: ProgressStore(userDefaults: defaults),
            challengeEvaluator: ChallengeEvaluationService()
        )

        XCTAssertEqual(appState.appearanceMode, .system)
        XCTAssertNil(appState.resolvedPreferredColorScheme)

        appState.setAppearanceMode(.dark)
        XCTAssertEqual(appState.appearanceMode, .dark)
        XCTAssertEqual(appState.resolvedPreferredColorScheme, .dark)

        let reloaded = AppState(
            localization: LocalizationService(userDefaults: defaults),
            contentRepository: ContentRepository(),
            progressStore: ProgressStore(userDefaults: defaults),
            challengeEvaluator: ChallengeEvaluationService()
        )

        XCTAssertEqual(reloaded.appearanceMode, .dark)
        XCTAssertEqual(reloaded.resolvedPreferredColorScheme, .dark)

        reloaded.setAppearanceMode(.light)
        XCTAssertEqual(reloaded.resolvedPreferredColorScheme, .light)
    }

    private func makeAppState() -> AppState {
        let suiteName = "AppStateMasteryAndExamTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppState(
            localization: LocalizationService(userDefaults: defaults),
            contentRepository: ContentRepository(),
            progressStore: ProgressStore(userDefaults: defaults),
            challengeEvaluator: ChallengeEvaluationService()
        )
    }
}
