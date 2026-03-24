import XCTest
@testable import SQLAcademy

final class SQLExecutionServiceTests: XCTestCase {
    func testSelectReturnsRows() throws {
        let service = SQLExecutionService()
        try service.reset(setupStatements: [
            "CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT);",
            "INSERT INTO t (id, name) VALUES (1, 'Ada');"
        ])

        let result = try service.execute("SELECT id, name FROM t ORDER BY id;")
        XCTAssertEqual(result.columns, ["id", "name"])
        XCTAssertEqual(result.rows, [["1", "Ada"]])
    }

    func testRejectsMultipleStatements() throws {
        let service = SQLExecutionService()
        XCTAssertThrowsError(try service.execute("SELECT 1; SELECT 2;"))
    }

    func testRejectsUnsupportedKeyword() throws {
        let service = SQLExecutionService()
        XCTAssertThrowsError(try service.execute("PRAGMA table_info('t');"))
    }

    func testExecuteScriptRunsMultipleStatements() throws {
        let service = SQLExecutionService()
        let result = try service.executeScript("""
            CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT);
            INSERT INTO t (id, name) VALUES (1, 'Ada');
            SELECT name FROM t ORDER BY id;
            """)

        XCTAssertEqual(result.columns, ["name"])
        XCTAssertEqual(result.rows, [["Ada"]])
    }

    func testExecuteScriptRejectsForbiddenStatement() throws {
        let service = SQLExecutionService()
        XCTAssertThrowsError(try service.executeScript("""
            CREATE TABLE t (id INTEGER PRIMARY KEY);
            PRAGMA table_info('t');
            """))
    }
}
