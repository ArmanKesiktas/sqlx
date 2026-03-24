import XCTest
@testable import SQLAcademy

@MainActor
final class PracticeViewModelTests: XCTestCase {
    func testRunScriptOnBlankDatabase() {
        let viewModel = PracticeViewModel(contentRepository: ContentRepository())
        viewModel.setDatasetMode(.blank)
        viewModel.query = """
        CREATE TABLE tasks (id INTEGER PRIMARY KEY, title TEXT);
        INSERT INTO tasks (id, title) VALUES (1, 'foundation');
        SELECT id, title FROM tasks;
        """

        viewModel.runScript()

        XCTAssertNil(viewModel.errorText)
        XCTAssertEqual(viewModel.lastResult?.columns, ["id", "title"])
        XCTAssertEqual(viewModel.lastResult?.rows, [["1", "foundation"]])
    }

    func testSampleDatasetSwitchChangesAvailableTables() {
        let viewModel = PracticeViewModel(contentRepository: ContentRepository())
        viewModel.query = "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name;"

        viewModel.run()
        let ecommerceTables = viewModel.lastResult?.rows.map { $0.first ?? "" } ?? []
        XCTAssertTrue(ecommerceTables.contains("customers"))
        XCTAssertTrue(ecommerceTables.contains("orders"))

        viewModel.setSampleDataset(.software)
        viewModel.run()
        let softwareTables = viewModel.lastResult?.rows.map { $0.first ?? "" } ?? []
        XCTAssertTrue(softwareTables.contains("services"))
        XCTAssertTrue(softwareTables.contains("incidents"))
    }
}
