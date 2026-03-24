import XCTest
@testable import SQLAcademy

final class ExamEngineServiceTests: XCTestCase {
    func testEvaluatePassesWhenAllAnswersCorrect() {
        let service = ExamEngineService()
        let modules = ContentRepository().loadModulesWithBonusChallenges()
        var session = service.makeSession(level: .intermediate, modules: modules, localize: { $0 })

        for question in session.questions {
            switch question.kind {
            case .multipleChoice:
                service.submitAnswer(question.correctAnswer, for: question.id, in: &session)
            case .sqlWriting:
                service.submitAnswer(question.expectedKeywords.joined(separator: " "), for: question.id, in: &session)
            }
        }

        let attempt = service.evaluate(session)
        XCTAssertEqual(attempt.score, 100)
        XCTAssertTrue(attempt.passed)
        XCTAssertTrue(attempt.weakTopicIDs.isEmpty)
    }

    func testEvaluateDetectsWeakTopicsWhenAnswersMissing() {
        let service = ExamEngineService()
        let modules = ContentRepository().loadModulesWithBonusChallenges()
        let session = service.makeSession(level: .beginner, modules: modules, localize: { $0 })

        let attempt = service.evaluate(session)

        XCTAssertFalse(attempt.passed)
        XCTAssertEqual(attempt.score, 0)
        XCTAssertFalse(attempt.weakTopicIDs.isEmpty)
    }
}
