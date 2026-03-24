import Foundation

@MainActor
final class PracticeViewModel: ObservableObject {
    @Published var query: String = "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name;"
    @Published var lastResult: SQLExecutionResult?
    @Published var errorText: String?
    @Published private(set) var datasetMode: PracticeDatasetMode = .sample
    @Published private(set) var selectedSample: PracticeSampleDataset = .ecommerce
    @Published private(set) var datasetPreview: [PracticeDatasetTablePreview] = []

    private let sqlService = SQLExecutionService()
    private let contentRepository: ContentRepository
    private var setupSQL: [String] = []

    init(contentRepository: ContentRepository = ContentRepository()) {
        self.contentRepository = contentRepository
        reloadDataset()
    }

    func resetDataset() {
        do {
            try sqlService.reset(setupStatements: setupSQL)
            lastResult = nil
            errorText = nil
            refreshDatasetPreview()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func setDatasetMode(_ mode: PracticeDatasetMode) {
        guard datasetMode != mode else { return }
        datasetMode = mode
        reloadDataset()
    }

    func setSampleDataset(_ sample: PracticeSampleDataset) {
        guard selectedSample != sample else { return }
        selectedSample = sample
        guard datasetMode == .sample else { return }
        reloadDataset()
    }

    func run() {
        do {
            let result = try sqlService.execute(query)
            lastResult = result
            errorText = nil
            refreshDatasetPreview()
        } catch {
            lastResult = nil
            errorText = error.localizedDescription
        }
    }

    func runScript() {
        do {
            let result = try sqlService.executeScript(query)
            lastResult = result
            errorText = nil
            refreshDatasetPreview()
        } catch {
            lastResult = nil
            errorText = error.localizedDescription
        }
    }

    private func reloadDataset() {
        setupSQL = selectedSetupSQL()
        do {
            try sqlService.reset(setupStatements: setupSQL)
            lastResult = nil
            errorText = nil
            refreshDatasetPreview()
        } catch {
            lastResult = nil
            errorText = error.localizedDescription
        }
    }

    private func selectedSetupSQL() -> [String] {
        switch datasetMode {
        case .blank:
            return contentRepository.practiceBlankSetupSQL()
        case .sample:
            return contentRepository.practiceSampleSetupSQL(for: selectedSample)
        }
    }

    private func refreshDatasetPreview() {
        do {
            let tablesResult = try sqlService.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name;",
                validateSafety: false
            )

            datasetPreview = tablesResult.rows.compactMap { row in
                guard let tableName = row.first, !tableName.hasPrefix("sqlite_") else {
                    return nil
                }

                let schemaResult = try? sqlService.execute("PRAGMA table_info(\(tableName));", validateSafety: false)
                let sampleResult = try? sqlService.execute("SELECT * FROM \(tableName) LIMIT 5;", validateSafety: false)

                let normalizedSchema = normalizedSchemaResult(schemaResult)
                let normalizedSample = sampleResult ?? SQLExecutionResult(columns: [], rows: [], rowsAffected: 0)
                return PracticeDatasetTablePreview(
                    tableName: tableName,
                    schema: normalizedSchema,
                    sample: normalizedSample
                )
            }
        } catch {
            datasetPreview = []
        }
    }

    private func normalizedSchemaResult(_ result: SQLExecutionResult?) -> SQLExecutionResult {
        guard let result else {
            return SQLExecutionResult(columns: ["column", "type", "nullable"], rows: [], rowsAffected: 0)
        }

        let rows = result.rows.map { row in
            let name = value(at: 1, in: row)
            let type = value(at: 2, in: row)
            let nullable = value(at: 3, in: row) == "1" ? "NO" : "YES"
            return [name, type, nullable]
        }

        return SQLExecutionResult(
            columns: ["column", "type", "nullable"],
            rows: rows,
            rowsAffected: rows.count
        )
    }

    private func value(at index: Int, in row: [String]) -> String {
        guard row.indices.contains(index) else { return "" }
        return row[index]
    }
}
