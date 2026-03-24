import XCTest
@testable import SQLAcademy

final class TutorContextServiceTests: XCTestCase {
    func testFallbackContextChangesByProfessionButKeepsSameSkeleton() {
        let service = TutorContextService()
        let interest = TutorInterest(
            lessonKind: .joinAggregate,
            id: "join",
            titleKey: "x",
            tableName: "base_table",
            selectColumn: "metric_value",
            whereColumn: "segment_type",
            whereValue: "core",
            orderColumn: "metric_value"
        )

        let software = service.fallbackContext(profession: "Bilgisayar mühendisiyim", interest: interest)
        let construction = service.fallbackContext(profession: "İnşaat işçisiyim", interest: interest)

        XCTAssertNotEqual(software.primaryTable, construction.primaryTable)
        XCTAssertNotEqual(software.secondaryTable, construction.secondaryTable)

        let softwareSQL = service.buildCommand(interest: interest, context: software).uppercased()
        let constructionSQL = service.buildCommand(interest: interest, context: construction).uppercased()

        for keyword in ["SELECT", "FROM", "JOIN", "WHERE", "GROUP BY", "ORDER BY", "LIMIT"] {
            XCTAssertTrue(softwareSQL.contains(keyword))
            XCTAssertTrue(constructionSQL.contains(keyword))
        }
    }

    func testParseGeneratedContextFallsBackOnInvalidIdentifiers() {
        let service = TutorContextService()
        let fallback = TutorSQLContext(
            primaryTable: "safe_table",
            secondaryTable: "safe_dim",
            metricColumn: "metric_value",
            dimensionColumn: "segment_name",
            filterColumn: "segment_type",
            filterValue: "core",
            orderColumn: "metric_value",
            joinPrimaryColumn: "segment_id",
            joinSecondaryColumn: "id"
        )

        let generated = """
        {
          "primaryTable": "DROP TABLE users",
          "secondaryTable": "dim ok",
          "metricColumn": "metric-value",
          "dimensionColumn": "segment_name",
          "filterColumn": "segment_type",
          "filterValue": "prod",
          "orderColumn": "metric_value",
          "joinPrimaryColumn": "segment_id",
          "joinSecondaryColumn": "id"
        }
        """

        let parsed = service.parseGeneratedContext(generated, fallback: fallback)
        XCTAssertEqual(parsed.primaryTable, "safe_table")
        XCTAssertEqual(parsed.secondaryTable, "dim_ok")
        XCTAssertEqual(parsed.metricColumn, "metric_value")
        XCTAssertEqual(parsed.filterValue, "prod")
    }
}
