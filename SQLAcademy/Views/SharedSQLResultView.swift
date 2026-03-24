import SwiftUI

struct SQLResultView: View {
    let result: SQLExecutionResult

    var body: some View {
        if result.columns.isEmpty {
            Text("Rows affected: \(result.rowsAffected)")
                .font(.footnote)
                .foregroundStyle(AppTheme.accent)
        } else {
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        // Row number header
                        Text("#")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 32, alignment: .center)
                            .padding(.vertical, 7)
                            .background(AppTheme.heroGradient)

                        ForEach(result.columns, id: \.self) { column in
                            Text(column)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.vertical, 7)
                                .padding(.horizontal, 10)
                                .frame(minWidth: 90, alignment: .leading)
                                .background(AppTheme.heroGradient)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.bottom, 4)

                    // Data rows with zebra striping
                    ForEach(Array(result.rows.enumerated()), id: \.offset) { index, row in
                        HStack(spacing: 0) {
                            // Row number
                            Text("\(index + 1)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                                .frame(width: 32, alignment: .center)
                                .padding(.vertical, 6)

                            ForEach(Array(row.enumerated()), id: \.offset) { _, value in
                                Text(value)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .frame(minWidth: 90, alignment: .leading)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(index % 2 == 0 ? AppTheme.tableRowBackground : AppTheme.tableRowBackground.opacity(0.4))
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Hint Toggle Button

struct HintToggleView: View {
    let hintText: String
    @State private var isRevealed = false

    private let hintColor = Color(red: 0.90, green: 0.55, blue: 0.10)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isRevealed.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isRevealed ? "lightbulb.fill" : "lightbulb")
                        .font(.caption)
                        .foregroundStyle(hintColor)
                    Text(isRevealed ? "Hide Hint" : "Show Hint")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(hintColor)
                    Spacer()
                    Image(systemName: isRevealed ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(hintColor.opacity(0.6))
                }
                .padding(14)
                .background(hintColor.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            if isRevealed {
                Text(hintText)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(hintColor.opacity(0.05))
                    .clipShape(
                        .rect(bottomLeadingRadius: 12, bottomTrailingRadius: 12)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
