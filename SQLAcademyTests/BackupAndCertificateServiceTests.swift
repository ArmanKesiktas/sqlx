import XCTest
@testable import SQLAcademy

final class BackupAndCertificateServiceTests: XCTestCase {
    func testExportImportRoundTripPreservesProgress() throws {
        let service = BackupSyncService()
        var progress = UserProgress.empty
        progress.completedModuleIDs = ["m1"]
        progress.totalPoints = 240
        progress.displayName = "Arman"

        let data = try service.exportJSON(progress: progress)
        let restored = try service.importJSON(data: data)

        XCTAssertEqual(restored.completedModuleIDs, ["m1"])
        XCTAssertEqual(restored.totalPoints, 240)
        XCTAssertEqual(restored.displayName, "Arman")
    }

    func testMergeUsesDeterministicConflictResolution() {
        let service = BackupSyncService()
        var local = UserProgress.empty
        local.lastActiveDate = ISO8601DateFormatter().date(from: "2026-03-15T12:00:00Z")
        local.completedModuleIDs = ["m1"]
        local.totalPoints = 100

        var remote = UserProgress.empty
        remote.lastActiveDate = local.lastActiveDate
        remote.completedModuleIDs = ["m1", "m2"]
        remote.totalPoints = 400

        let merged = service.merge(local: local, remote: remote)

        XCTAssertEqual(merged.completedModuleIDs, ["m1", "m2"])
        XCTAssertEqual(merged.totalPoints, 400)
        XCTAssertEqual(merged.lastActiveDate, local.lastActiveDate)
    }

    func testCertificateServiceBuildsPdf() {
        let service = CertificateService()
        let record = service.makeRecord(
            packageID: "data_analytics",
            interestID: "sql_intro",
            packageTitle: "SQL'e Giriş",
            lessonTitle: "SELECT",
            displayName: "Arman",
            masteryScore: 95,
            summarySQL: ["SELECT * FROM customers;", "SELECT name FROM customers WHERE city = 'Istanbul';"]
        )

        let pdf = service.makeCertificatePDF(record: record)
        XCTAssertNotNil(pdf)
        XCTAssertGreaterThan(pdf?.count ?? 0, 0)
    }
}
