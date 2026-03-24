import XCTest
@testable import SQLAcademy

final class RetentionServiceTests: XCTestCase {
    func testScheduleReviewItemsCreatesOneThreeSevenDayQueue() {
        let service = RetentionService(calendar: Calendar(identifier: .gregorian))
        var progress = UserProgress.empty
        let baseDate = ISO8601DateFormatter().date(from: "2026-03-15T10:00:00Z")!

        service.scheduleReviewItems(progress: &progress, topicID: "m1", source: "quiz", baseDate: baseDate)

        XCTAssertEqual(progress.reviewQueue.count, 3)
        let dayDiffs = progress.reviewQueue.map { item in
            Calendar(identifier: .gregorian).dateComponents([.day], from: baseDate, to: item.dueDate).day ?? -1
        }.sorted()
        XCTAssertEqual(dayDiffs, [1, 3, 7])
    }

    func testCurrentDailyMissionsIsIdempotentForSameDay() {
        let service = RetentionService(calendar: Calendar(identifier: .gregorian))
        var progress = UserProgress.empty
        let repo = ContentRepository()
        let modules = repo.loadModulesWithBonusChallenges()
        let challenges = modules.flatMap(\.challenges)
        let packages = repo.tutorPackages()
        let now = ISO8601DateFormatter().date(from: "2026-03-15T10:00:00Z")!

        let first = service.currentDailyMissions(
            progress: &progress,
            modules: modules,
            challenges: challenges,
            packages: packages,
            localize: { $0 },
            now: now
        )
        let second = service.currentDailyMissions(
            progress: &progress,
            modules: modules,
            challenges: challenges,
            packages: packages,
            localize: { $0 },
            now: now
        )

        XCTAssertEqual(first.count, 3)
        XCTAssertEqual(first.map(\.mission.id), second.map(\.mission.id))
    }
}
