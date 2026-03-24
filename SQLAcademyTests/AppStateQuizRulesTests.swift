import XCTest
@testable import SQLAcademy

final class AppStateQuizRulesTests: XCTestCase {
    @MainActor
    private func makeAppState() -> (appState: AppState, defaults: UserDefaults, suiteName: String) {
        let suiteName = "AppStateQuizRulesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let localization = LocalizationService(userDefaults: defaults)
        let progressStore = ProgressStore(userDefaults: defaults, calendar: Calendar(identifier: .gregorian))
        let appState = AppState(localization: localization, progressStore: progressStore)
        return (appState, defaults, suiteName)
    }

    @MainActor
    func testSubmitQuizOnlyCompletesModuleAtEightyOrAbove() {
        let context = makeAppState()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        guard let module = context.appState.modules.first else {
            return XCTFail("Expected at least one module")
        }

        context.appState.submitQuiz(moduleID: module.id, score: 79)
        XCTAssertFalse(context.appState.progress.completedModuleIDs.contains(module.id))

        context.appState.submitQuiz(moduleID: module.id, score: 80)
        XCTAssertTrue(context.appState.progress.completedModuleIDs.contains(module.id))
    }

    @MainActor
    func testCalculateQuizScoreForFiveQuestionModule() {
        let context = makeAppState()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        guard let module = context.appState.modules.first(where: { $0.id == "m1_select_basics" }) else {
            return XCTFail("Expected m1_select_basics module")
        }
        XCTAssertEqual(module.quiz.count, 5)

        var selectedOptions: [String: String] = [:]
        for question in module.quiz.prefix(4) {
            selectedOptions[question.id] = question.correctOptionID
        }
        if let lastQuestion = module.quiz.last,
           let wrongOption = lastQuestion.options.first(where: { $0.id != lastQuestion.correctOptionID }) {
            selectedOptions[lastQuestion.id] = wrongOption.id
        }

        let score = context.appState.calculateQuizScore(for: module, selectedOptions: selectedOptions)
        XCTAssertEqual(score, 80)
    }
}
