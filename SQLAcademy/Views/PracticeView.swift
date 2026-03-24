import SwiftUI

struct PracticeView: View {
    @EnvironmentObject private var localization: LocalizationService
    @StateObject var viewModel: PracticeViewModel
    @State private var previewTableIndex = 0
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        ZStack {
            AcademyBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(localization.text("practice.heroTitle"))
                        .academyTitleStyle()

                    workspaceHeader
                    datasetPreviewSection
                    sqlEditorSection
                    actionButtons
                    resultSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .padding(.bottom, 90)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - SQL Editor (dark terminal style)

    private var sqlEditorSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Terminal header bar
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color(red: 0.94, green: 0.36, blue: 0.34)).frame(width: 8, height: 8)
                    Circle().fill(Color(red: 0.98, green: 0.77, blue: 0.27)).frame(width: 8, height: 8)
                    Circle().fill(Color(red: 0.35, green: 0.78, blue: 0.35)).frame(width: 8, height: 8)
                }
                Spacer()
                Text("SQL")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Editor with line numbers
            HStack(alignment: .top, spacing: 0) {
                lineNumbers
                    .padding(.leading, 6)
                    .frame(width: 32)

                Divider()
                    .background(.white.opacity(0.1))

                TextEditor(text: $viewModel.query)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.92))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 200)
                    .padding(8)
                    .focused($isEditorFocused)
                    .accessibilityIdentifier("practice.queryEditor")
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button(localization.text("practice.keyboardDone")) {
                                isEditorFocused = false
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                        }
                    }
            }
        }
        .background(AppTheme.codeEditorBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var lineNumbers: some View {
        let lineCount = max(viewModel.query.components(separatedBy: "\n").count, 1)
        return VStack(alignment: .trailing, spacing: 0) {
            ForEach(1...lineCount, id: \.self) { num in
                Text("\(num)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
                    .frame(height: 20)
            }
            Spacer()
        }
        .padding(.top, 9)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                isEditorFocused = false
                viewModel.run()
            } label: {
                Text(localization.text("practice.run"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.buttonGradient)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("practice.run")

            Button {
                isEditorFocused = false
                viewModel.runScript()
            } label: {
                Text(localization.text("practice.runScript"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accentDark)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.accent.opacity(0.14))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.accent.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("practice.runScript")

            Button {
                isEditorFocused = false
                viewModel.resetDataset()
            } label: {
                Text(localization.text("practice.resetDataset"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.rose)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.rose.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.rose.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("practice.reset")
        }
    }

    // MARK: - Result Section

    private var resultSection: some View {
        AcademySectionBlock(title: localization.text("practice.result"), symbol: "checkmark.circle") {
            AcademySectionSurface(padding: 14) {
                if let errorText = viewModel.errorText {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.error)
                        Text(errorText)
                            .foregroundStyle(AppTheme.error)
                            .font(.caption.weight(.semibold))
                    }
                } else if let result = viewModel.lastResult {
                    SQLResultView(result: result)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "text.and.command.macwindow")
                            .font(.title2)
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                        Text(localization.text("practice.noResult"))
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            }
        }
    }

    // MARK: - Dataset Picker (chip style)

    private var workspaceHeader: some View {
        AcademySectionSurface(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                datasetModePicker
                if viewModel.datasetMode == .sample {
                    sampleDatasetPicker
                }
            }
        }
    }

    private var datasetModePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localization.text("practice.mode"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Picker(localization.text("practice.mode"), selection: modeBinding) {
                Text(localization.text("practice.mode.blank")).tag(PracticeDatasetMode.blank)
                Text(localization.text("practice.mode.sample")).tag(PracticeDatasetMode.sample)
            }
            .pickerStyle(.segmented)
        }
    }

    private var sampleDatasetPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localization.text("practice.sampleDataset"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)

            HStack(spacing: 8) {
                ForEach(PracticeSampleDataset.allCases) { sample in
                    let isSelected = viewModel.selectedSample == sample
                    Button(localizedSampleTitle(sample)) {
                        viewModel.setSampleDataset(sample)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isSelected ? AppTheme.accent : AppTheme.capsuleBackground)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Dataset Preview

    private var datasetPreviewSection: some View {
        AcademySectionBlock(title: localization.text("practice.datasetPreview"), symbol: "tablecells") {
            if viewModel.datasetPreview.isEmpty {
                Text(localization.text("practice.datasetEmpty"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    // Table chip selector
                    if viewModel.datasetPreview.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(viewModel.datasetPreview.enumerated()), id: \.offset) { index, table in
                                    Button(table.tableName) {
                                        previewTableIndex = index
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(previewTableIndex == index ? .white : AppTheme.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(previewTableIndex == index ? AppTheme.accent : AppTheme.capsuleBackground)
                                    .clipShape(Capsule())
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    let table = viewModel.datasetPreview[min(previewTableIndex, viewModel.datasetPreview.count - 1)]
                    VStack(alignment: .leading, spacing: 8) {
                        Text(table.tableName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.accentDark)
                        SQLResultView(result: table.sample)
                    }
                    .padding(12)
                    .background(AppTheme.subtleSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.cardBorder.opacity(0.72), lineWidth: 0.8)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .onChange(of: viewModel.datasetPreview) { _, _ in
                    previewTableIndex = 0
                }
            }
        }
    }

    // MARK: - Helpers

    private var modeBinding: Binding<PracticeDatasetMode> {
        Binding(
            get: { viewModel.datasetMode },
            set: { viewModel.setDatasetMode($0) }
        )
    }

    private func localizedSampleTitle(_ sample: PracticeSampleDataset) -> String {
        switch sample {
        case .ecommerce:
            return localization.text("practice.sample.ecommerce")
        case .software:
            return localization.text("practice.sample.software")
        case .construction:
            return localization.text("practice.sample.construction")
        }
    }
}
