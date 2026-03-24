import XCTest
@testable import SQLAcademy

final class ContentRepositoryTests: XCTestCase {
    func testLoadModulesWithBonusChallengesAddsThirtyItems() {
        let repository = ContentRepository()
        let baseModules = repository.loadModules()
        let bonusModules = repository.loadModulesWithBonusChallenges(bonusCount: 30)

        let baseCount = baseModules.flatMap(\.challenges).count
        let bonusCount = bonusModules.flatMap(\.challenges).count
        XCTAssertEqual(bonusCount, baseCount + 30)
    }

    func testBonusChallengeIDsAreUnique() {
        let repository = ContentRepository()
        let modules = repository.loadModulesWithBonusChallenges(bonusCount: 30)
        let allIDs = modules.flatMap(\.challenges).map(\.id)

        XCTAssertEqual(Set(allIDs).count, allIDs.count)
    }

    func testEachModuleHasFiveQuizQuestionsWithThreeOptions() {
        let repository = ContentRepository()
        let modules = repository.loadModules()

        XCTAssertFalse(modules.isEmpty)
        for module in modules {
            XCTAssertEqual(module.quiz.count, 5, "Expected 5 quiz questions for module \(module.id)")
            for question in module.quiz {
                XCTAssertEqual(question.options.count, 3, "Expected 3 options for question \(question.id)")
            }
        }
    }
}
