import Foundation
import SQLite3

enum SQLExecutionError: LocalizedError {
    case emptyQuery
    case multipleStatements
    case unsupportedStatement
    case sqliteError(String)

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Empty query."
        case .multipleStatements:
            return "Only one SQL statement is allowed."
        case .unsupportedStatement:
            return "Unsupported SQL statement."
        case .sqliteError(let message):
            return message
        }
    }
}

final class SQLExecutionService {
    private let allowedStatements: Set<String> = [
        "SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "DROP", "ALTER", "WITH"
    ]
    private let forbiddenKeywords: Set<String> = [
        "ATTACH", "DETACH", "PRAGMA", "VACUUM", "TRIGGER", "REINDEX", "ANALYZE"
    ]

    private var db: OpaquePointer?

    init() {
        try? openDatabase()
    }

    deinit {
        sqlite3_close(db)
    }

    func reset(setupStatements: [String]) throws {
        sqlite3_close(db)
        db = nil
        try openDatabase()
        for statement in setupStatements {
            _ = try execute(statement, validateSafety: false)
        }
    }

    @discardableResult
    func execute(_ query: String, validateSafety: Bool = true) throws -> SQLExecutionResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SQLExecutionError.emptyQuery }

        if validateSafety {
            try validate(query: trimmed)
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, trimmed, -1, &statement, nil) == SQLITE_OK else {
            throw SQLExecutionError.sqliteError(lastSQLiteError())
        }
        defer { sqlite3_finalize(statement) }

        let columnCount = Int(sqlite3_column_count(statement))
        var rows: [[String]] = []
        var stepResult: Int32 = SQLITE_ROW

        while stepResult == SQLITE_ROW {
            stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_ROW {
                var row: [String] = []
                for index in 0..<columnCount {
                    if let cString = sqlite3_column_text(statement, Int32(index)) {
                        row.append(String(cString: cString))
                    } else {
                        row.append("NULL")
                    }
                }
                rows.append(row)
            }
        }

        if stepResult != SQLITE_DONE {
            throw SQLExecutionError.sqliteError(lastSQLiteError())
        }

        let columns = (0..<columnCount).map { index in
            if let name = sqlite3_column_name(statement, Int32(index)) {
                return String(cString: name)
            }
            return "col\(index)"
        }

        return SQLExecutionResult(
            columns: columns,
            rows: rows,
            rowsAffected: Int(sqlite3_changes(db))
        )
    }

    @discardableResult
    func executeScript(_ script: String) throws -> SQLExecutionResult {
        let statements = splitStatements(script)
        guard !statements.isEmpty else {
            throw SQLExecutionError.emptyQuery
        }

        var lastResult = SQLExecutionResult(columns: [], rows: [], rowsAffected: 0)
        for statement in statements {
            lastResult = try execute(statement, validateSafety: true)
        }
        return lastResult
    }

    private func openDatabase() throws {
        if sqlite3_open(":memory:", &db) != SQLITE_OK {
            throw SQLExecutionError.sqliteError(lastSQLiteError())
        }
    }

    private func validate(query: String) throws {
        let statements = query
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard statements.count <= 1 else {
            throw SQLExecutionError.multipleStatements
        }

        let uppercased = query.uppercased()
        if forbiddenKeywords.contains(where: { uppercased.contains($0) }) {
            throw SQLExecutionError.unsupportedStatement
        }

        let firstToken = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace || $0 == "(" })
            .first?
            .uppercased() ?? ""
        guard allowedStatements.contains(firstToken) else {
            throw SQLExecutionError.unsupportedStatement
        }
    }

    private func splitStatements(_ script: String) -> [String] {
        var statements: [String] = []
        var current = ""
        var inSingleQuote = false

        for character in script {
            if character == "'" {
                inSingleQuote.toggle()
                current.append(character)
                continue
            }

            if character == ";" && !inSingleQuote {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    statements.append(trimmed)
                }
                current = ""
                continue
            }

            current.append(character)
        }

        let trailing = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailing.isEmpty {
            statements.append(trailing)
        }
        return statements
    }

    private func lastSQLiteError() -> String {
        if let db, let cMessage = sqlite3_errmsg(db) {
            return friendlyError(String(cString: cMessage))
        }
        return "Unknown error. Check your SQL syntax."
    }

    private func friendlyError(_ raw: String) -> String {
        let lower = raw.lowercased()

        if lower.contains("no such table") {
            let name = raw.components(separatedBy: ": ").last ?? raw
            return "Table '\(name)' does not exist. Check the table name for typos."
        }
        if lower.contains("no such column") {
            let name = raw.components(separatedBy: ": ").last ?? raw
            return "Column '\(name)' not found. Check the column name for typos."
        }
        if lower.contains("ambiguous column name") {
            let name = raw.components(separatedBy: ": ").last ?? raw
            return "Column '\(name)' exists in multiple tables. Use table.column syntax (e.g. customers.name)."
        }
        if lower.contains("syntax error") {
            if let nearRange = raw.range(of: #"near "(.*?)""#, options: .regularExpression) {
                let nearWord = String(raw[nearRange])
                return "Syntax error \(nearWord). Check for typos or missing keywords (SELECT, FROM, WHERE…)."
            }
            return "Syntax error. Check your SQL for missing keywords or typos."
        }
        if lower.contains("already exists") {
            return "This table already exists. Use DROP TABLE first, or CREATE TABLE IF NOT EXISTS."
        }
        if lower.contains("not null constraint") {
            return "A required column is missing a value. Check all columns in your INSERT statement."
        }
        if lower.contains("unique constraint") {
            return "Duplicate value detected. This column requires unique values."
        }
        if lower.contains("foreign key") {
            return "Foreign key constraint failed. Make sure the referenced row exists."
        }
        if lower.contains("no such function") {
            let name = raw.components(separatedBy: ": ").last ?? raw
            return "Function '\(name)' is not supported. Check the function name for typos."
        }
        if lower.contains("misuse") {
            return "Aggregate function misuse. Wrap aggregate functions inside GROUP BY or use OVER() for window functions."
        }
        return raw
    }
}
