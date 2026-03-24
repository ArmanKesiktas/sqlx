import SwiftUI

struct TutorEditorPanel: View {
    @ObservedObject var viewModel: TutorViewModel
    @ObservedObject var labState: TutorLabState
    let localization: LocalizationService

    @State private var isSchemaExpanded = true

    private var isTurkish: Bool { localization.language == .tr }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !labState.schemaDescription.isEmpty {
                    schemaSection
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                }

                keywordToolbar
                    .padding(.bottom, 6)

                editorSection
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                explainButton
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                statusAndResultsSection
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Keyword Quick-Insert Toolbar

    private var keywordToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(["SELECT", "FROM", "WHERE", "JOIN", "GROUP BY",
                         "ORDER BY", "HAVING", "INSERT", "UPDATE", "DELETE",
                         "*", "AND", "OR", "LIMIT", "AS", "ON"], id: \.self) { keyword in
                    Button {
                        let separator = labState.query.isEmpty || labState.query.hasSuffix(" ") || labState.query.hasSuffix("\n") ? "" : " "
                        labState.query += separator + keyword + " "
                    } label: {
                        Text(keyword)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AppTheme.sqlKeyword)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.sqlKeyword.opacity(0.1))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.sqlKeyword.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    // MARK: - Editor Section (with line numbers + syntax highlighting + floating Run)

    private var lineCount: Int {
        max(1, labState.query.components(separatedBy: "\n").count)
    }

    private var editorSection: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack(alignment: .top, spacing: 0) {
                // Line numbers
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(1...lineCount, id: \.self) { num in
                        Text("\(num)")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(AppTheme.sqlLineNumber)
                            .frame(height: 19.6) // matches TextEditor line height
                    }
                }
                .frame(width: 28)
                .padding(.top, 16)

                Rectangle()
                    .fill(AppTheme.sqlLineNumber.opacity(0.25))
                    .frame(width: 1)
                    .padding(.vertical, 8)

                // Editor with syntax overlay
                ZStack(alignment: .topLeading) {
                    // Invisible TextEditor for input
                    TextEditor(text: $labState.query)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.clear)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .frame(minHeight: 100, maxHeight: 220)
                        .tint(AppTheme.sqlKeyword)

                    // Syntax-highlighted overlay
                    Text(SQLHighlighter.highlight(labState.query))
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)

                    // Placeholder
                    if labState.query.isEmpty {
                        Text(isTurkish ? "SELECT * FROM tablo_adi\nWHERE kolon = 'değer'" : "SELECT * FROM table_name\nWHERE column = 'value'")
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundStyle(AppTheme.sqlLineNumber.opacity(0.6))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
            }
            .background(AppTheme.codeEditorBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.cardBorder.opacity(0.5), lineWidth: 1)
            )

            // Floating buttons
            HStack(spacing: 8) {
                if !labState.query.isEmpty {
                    Button {
                        labState.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.sqlLineNumber)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    viewModel.runCurrentLabQuery()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(isTurkish ? "Çalıştır" : "Run")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.buttonGradient)
                    .clipShape(Capsule())
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tutor.lab.run")
            }
            .padding(10)
        }
    }

    // MARK: - Explain Button

    private var explainButton: some View {
        Button {
            viewModel.refreshCurrentSceneNarration()
            viewModel.switchPanel(to: .chat)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption)
                Text(isTurkish ? "Tekrar Açıkla" : "Explain Again")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(AppTheme.textSecondary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Schema Section

    private var schemaSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSchemaExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "tablecells.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.accent)
                    Text(isTurkish ? "Tablo Şeması" : "Table Schema")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Image(systemName: isSchemaExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if isSchemaExpanded {
                schemaContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(AppTheme.elevatedCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private var schemaContent: some View {
        let lines = labState.schemaDescription
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return VStack(alignment: .leading, spacing: 8) {
            ForEach(lines, id: \.self) { line in
                if line.hasPrefix("Primary:") || line.hasPrefix("Secondary:") {
                    let tableName = line
                        .replacingOccurrences(of: "Primary: ", with: "")
                        .replacingOccurrences(of: "Secondary: ", with: "")
                    HStack(spacing: 6) {
                        Image(systemName: "table.fill")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.accent)
                        // Tappable table name — inserts into editor
                        Button {
                            insertIntoEditor(tableName)
                        } label: {
                            Text(tableName)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        .buttonStyle(.plain)

                        Text(line.hasPrefix("Primary") ? "PRIMARY" : "SECONDARY")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent.opacity(0.12))
                            .clipShape(Capsule())
                    }
                } else if line.hasPrefix("-") {
                    let colInfo = line.replacingOccurrences(of: "- ", with: "")
                    columnChip(colInfo)
                }
            }
        }
    }

    private func columnChip(_ info: String) -> some View {
        let parts = info.components(separatedBy: " (")
        let name = parts.first ?? info
        let type = parts.count > 1 ? String(parts[1].dropLast()) : ""

        return Button {
            insertIntoEditor(name)
        } label: {
            HStack(spacing: 0) {
                Text(name)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.codeBlockBackground)
                if !type.isEmpty {
                    Text(type)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(AppTheme.subtleSurface)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private func insertIntoEditor(_ text: String) {
        let separator = labState.query.isEmpty || labState.query.hasSuffix(" ") || labState.query.hasSuffix("\n") ? "" : " "
        labState.query += separator + text
    }

    // MARK: - Status & Results Section

    private var statusAndResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusBar

            if let error = labState.errorText, !error.isEmpty {
                errorView(error)
            } else if let result = labState.result {
                resultView(result)
            } else if labState.isLabVisible {
                emptyStateView
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 6) {
            Group {
                if let error = labState.errorText, !error.isEmpty {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppTheme.error)
                    Text(isTurkish ? "Hata" : "Error")
                        .foregroundStyle(AppTheme.error)
                } else if let result = labState.result {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.accent)
                    Text(isTurkish ? "\(result.rows.count) satır döndü" : "\(result.rows.count) rows returned")
                        .foregroundStyle(AppTheme.accent)
                } else {
                    Image(systemName: "circle").foregroundStyle(AppTheme.textSecondary)
                    Text(isTurkish ? "Hazır" : "Ready")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .font(.caption.weight(.semibold))
        }
    }

    private func errorView(_ error: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.error)
                .font(.subheadline)
            Text(error)
                .font(.caption)
                .foregroundStyle(AppTheme.error)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.error.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.error.opacity(0.25), lineWidth: 1)
        )
    }

    private func resultView(_ result: SQLExecutionResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "tablecells")
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
                Text(isTurkish ? "Sorgu Sonucu" : "Query Result")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text("\(result.rows.count) \(isTurkish ? "satır" : "rows")")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.accent.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.elevatedCardBackground)

            Divider()

            SQLResultView(result: result)
                .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.title2)
                .foregroundStyle(AppTheme.textSecondary.opacity(0.4))
            Text(isTurkish ? "SQL yaz ve çalıştır" : "Write a query and run it")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - SQL Syntax Highlighter

private struct SQLHighlighter {
    private static let keywords: Set<String> = [
        "SELECT", "FROM", "WHERE", "INSERT", "UPDATE", "DELETE",
        "CREATE", "DROP", "ALTER", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER",
        "ON", "AND", "OR", "NOT", "IN", "BETWEEN", "LIKE", "IS", "NULL",
        "AS", "ORDER", "BY", "GROUP", "HAVING", "LIMIT", "OFFSET",
        "DISTINCT", "UNION", "ALL", "EXISTS", "CASE", "WHEN", "THEN",
        "ELSE", "END", "INTO", "VALUES", "SET", "TABLE", "INDEX",
        "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "COUNT", "SUM",
        "AVG", "MIN", "MAX", "ASC", "DESC", "WITH", "CROSS", "FULL",
        "TOP", "CONSTRAINT", "DEFAULT", "CHECK", "UNIQUE", "CASCADE",
        "REPLACE", "IF", "BEGIN", "COMMIT", "ROLLBACK", "GRANT",
        "REVOKE", "TRIGGER", "VIEW", "PROCEDURE", "FUNCTION",
        "RETURNS", "DECLARE", "EXEC", "EXECUTE", "FETCH", "CURSOR",
        "OPEN", "CLOSE", "DEALLOCATE", "TRUE", "FALSE", "BOOLEAN",
        "INTEGER", "TEXT", "REAL", "BLOB", "VARCHAR", "CHAR", "INT",
        "FLOAT", "DOUBLE", "DATE", "TIMESTAMP", "COALESCE", "IFNULL",
        "NULLIF", "CAST", "CONVERT", "SUBSTRING", "TRIM", "UPPER",
        "LOWER", "LENGTH", "CONCAT", "ROUND", "ABS", "OVER", "PARTITION",
        "ROW_NUMBER", "RANK", "DENSE_RANK", "LAG", "LEAD", "FIRST_VALUE",
        "LAST_VALUE", "NTILE", "ROWS", "RANGE", "UNBOUNDED", "PRECEDING",
        "FOLLOWING", "CURRENT", "ROW"
    ]

    static func highlight(_ sql: String) -> AttributedString {
        guard !sql.isEmpty else { return AttributedString() }

        var result = AttributedString()
        let chars = Array(sql)
        var i = 0

        while i < chars.count {
            let ch = chars[i]

            // String literal: 'xxx'
            if ch == "'" {
                let start = i
                i += 1
                while i < chars.count && chars[i] != "'" {
                    if chars[i] == "\\" { i += 1 }  // escape
                    i += 1
                }
                if i < chars.count { i += 1 } // closing quote
                let token = String(chars[start..<i])
                var attr = AttributedString(token)
                attr.foregroundColor = AppTheme.sqlString
                result += attr
                continue
            }

            // Number
            if ch.isNumber || (ch == "." && i + 1 < chars.count && chars[i + 1].isNumber) {
                let start = i
                while i < chars.count && (chars[i].isNumber || chars[i] == ".") {
                    i += 1
                }
                // Make sure it's not part of an identifier
                if start == 0 || !chars[start - 1].isLetter && chars[start - 1] != "_" {
                    let token = String(chars[start..<i])
                    var attr = AttributedString(token)
                    attr.foregroundColor = AppTheme.sqlNumber
                    result += attr
                } else {
                    let token = String(chars[start..<i])
                    var attr = AttributedString(token)
                    attr.foregroundColor = AppTheme.sqlPlainText
                    result += attr
                }
                continue
            }

            // Word (potential keyword or identifier)
            if ch.isLetter || ch == "_" {
                let start = i
                while i < chars.count && (chars[i].isLetter || chars[i].isNumber || chars[i] == "_") {
                    i += 1
                }
                let token = String(chars[start..<i])
                var attr = AttributedString(token)
                if keywords.contains(token.uppercased()) {
                    attr.foregroundColor = AppTheme.sqlKeyword
                } else {
                    attr.foregroundColor = AppTheme.sqlPlainText
                }
                result += attr
                continue
            }

            // Operators and punctuation
            if "(),;=<>!+-/*%".contains(ch) {
                var attr = AttributedString(String(ch))
                if ch == "*" {
                    attr.foregroundColor = AppTheme.sqlKeyword
                } else {
                    attr.foregroundColor = AppTheme.sqlOperator
                }
                result += attr
                i += 1
                continue
            }

            // Whitespace and everything else
            var attr = AttributedString(String(ch))
            attr.foregroundColor = AppTheme.sqlPlainText
            result += attr
            i += 1
        }

        return result
    }
}
