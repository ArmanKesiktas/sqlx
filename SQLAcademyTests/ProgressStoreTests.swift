import XCTest
@testable import SQLAcademy

final class ProgressStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: ProgressStore!

    override func setUp() {
        super.setUp()
        suiteName = "ProgressStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = ProgressStore(userDefaults: defaults, calendar: Calendar(identifier: .gregorian))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        suiteName = nil
        super.tearDown()
    }

    func testSaveAndLoadProgress() {
        var progress = UserProgress.empty
        progress.totalPoints = 150
        progress.completedModuleIDs = ["m1"]
        progress.appearanceMode = .dark

        store.save(progress)
        let loaded = store.load()
        XCTAssertEqual(loaded.totalPoints, 150)
        XCTAssertEqual(loaded.completedModuleIDs, ["m1"])
        XCTAssertEqual(loaded.appearanceMode, .dark)
    }

    func testStreakIncrementsOnConsecutiveDays() {
        var progress = UserProgress.empty
        let day1 = ISO8601DateFormatter().date(from: "2026-03-10T10:00:00Z")!
        let day2 = ISO8601DateFormatter().date(from: "2026-03-11T10:00:00Z")!

        store.touchDailyActivity(progress: &progress, now: day1)
        store.touchDailyActivity(progress: &progress, now: day2)
        XCTAssertEqual(progress.streakDays, 2)
    }

    func testBadgeRulesAreApplied() {
        let badges = [
            Badge(id: "first", titleKey: "t1", descriptionKey: "d1", rule: .firstChallenge),
            Badge(id: "five", titleKey: "t2", descriptionKey: "d2", rule: .fiveChallenges)
        ]
        var progress = UserProgress.empty
        progress.completedChallengeIDs = ["c1", "c2", "c3", "c4", "c5"]

        store.applyBadges(progress: &progress, badges: badges)
        XCTAssertTrue(progress.badgeIDs.contains("first"))
        XCTAssertTrue(progress.badgeIDs.contains("five"))
    }

    func testUserProgressDecodesLegacyPayloadWithoutTutorFields() throws {
        let legacyPayload: [String: Any] = [
            "completedModuleIDs": ["m1"],
            "quizScores": ["m1": 85],
            "completedChallengeIDs": ["c1"],
            "totalPoints": 120,
            "streakDays": 2,
            "badgeIDs": ["b1"]
        ]
        let data = try JSONSerialization.data(withJSONObject: legacyPayload)
        let decoded = try JSONDecoder().decode(UserProgress.self, from: data)

        XCTAssertEqual(decoded.completedModuleIDs, ["m1"])
        XCTAssertEqual(decoded.startedTutorPackageIDs, [])
        XCTAssertEqual(decoded.completedTutorLessonIDs, [])
        XCTAssertEqual(decoded.tutorCurrentSceneIndexByPackageID, [:])
        XCTAssertEqual(decoded.tutorLastVisitedSceneIDByPackageID, [:])
        XCTAssertEqual(decoded.tutorCompletedLabSceneIDs, [])
        XCTAssertEqual(decoded.tutorProfessionByPackageID, [:])
        XCTAssertFalse(decoded.hasCompletedOnboarding)
        XCTAssertEqual(decoded.displayName, "")
        XCTAssertNil(decoded.appleUserID)
        XCTAssertFalse(decoded.isAppleSignedIn)
        XCTAssertEqual(decoded.appearanceMode, .system)
    }
}
