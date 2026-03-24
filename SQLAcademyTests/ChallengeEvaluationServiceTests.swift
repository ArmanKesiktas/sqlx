import XCTest
@testable import SQLAcademy

final class ChallengeEvaluationServiceTests: XCTestCase {
    func testQueryResultValidationPasses() {
        let challenge = SQLChallenge(
            id: "c1",
            moduleID: "m1",
            titleKey: "t",
            promptKey: "p",
            setupSQL: [
                "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);",
                "INSERT INTO users (id, name) VALUES (1, 'Ada');"
            ],
            starterSQL: "SELECT id, name FROM users;",
            validation: ChallengeValidation(
                type: .queryResult,
                expectedColumns: ["id", "name"],
                expectedRows: [["1", "Ada"]],
                table: nil,
                expectedCount: nil
            ),
            hintKey: "h",
            points: 10
        )
        let outcome = ChallengeEvaluationService().evaluate(
            challenge: challenge,
            query: "SELECT id, name FROM users;",
            sqlService: SQLExecutionService()
        )
        XCTAssertTrue(outcome.passed)
    }

    func testTableRowCountValidationPasses() {
        let challenge = SQLChallenge(
            id: "c2",
            moduleID: "m2",
            titleKey: "t",
            promptKey: "p",
            setupSQL: [
                "CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT);",
                "INSERT INTO items (id, name) VALUES (1, 'A');",
                "INSERT INTO items (id, name) VALUES (2, 'B');"
            ],
            starterSQL: "DELETE FROM items WHERE id = 2;",
            validation: ChallengeValidation(
                type: .tableRowCount,
                expectedColumns: nil,
                expectedRows: nil,
                table: "items",
                expectedCount: 1
            ),
            hintKey: "h",
            points: 10
        )
        let outcome = ChallengeEvaluationService().evaluate(
            challenge: challenge,
            query: "DELETE FROM items WHERE id = 2;",
            sqlService: SQLExecutionService()
        )
        XCTAssertTrue(outcome.passed)
    }
}
