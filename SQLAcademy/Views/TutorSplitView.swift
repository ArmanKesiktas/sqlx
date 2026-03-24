import SwiftUI

struct TutorSplitView: View {
    @ObservedObject var viewModel: TutorViewModel
    let localization: LocalizationService

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    private var iPadLayout: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                TutorChatPanel(viewModel: viewModel, localization: localization)
                    .frame(width: geo.size.width * 0.5)

                Divider()

                TutorEditorPanel(viewModel: viewModel, labState: viewModel.labState, localization: localization)
                    .frame(width: geo.size.width * 0.5)
            }
        }
    }

    private var iPhoneLayout: some View {
        VStack(spacing: 0) {
            panelPicker

            TabView(selection: panelBinding) {
                TutorChatPanel(viewModel: viewModel, localization: localization)
                    .tag(TutorViewModel.TutorPanel.chat)
                TutorEditorPanel(viewModel: viewModel, labState: viewModel.labState, localization: localization)
                    .tag(TutorViewModel.TutorPanel.editor)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)
        }
    }

    private var panelBinding: Binding<TutorViewModel.TutorPanel> {
        Binding(
            get: { viewModel.activePanel },
            set: { viewModel.switchPanel(to: $0) }
        )
    }

    private var panelPicker: some View {
        HStack(spacing: 0) {
            panelTab(
                title: localization.language == .tr ? "Sohbet" : "Chat",
                icon: "bubble.left.fill",
                panel: .chat
            )

            panelTab(
                title: localization.language == .tr ? "SQL Editör" : "SQL Editor",
                icon: "chevron.left.forwardslash.chevron.right",
                panel: .editor,
                showBadge: viewModel.labState.isLabVisible && viewModel.activePanel != .editor
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private func panelTab(title: String, icon: String, panel: TutorViewModel.TutorPanel, showBadge: Bool = false) -> some View {
        Button {
            viewModel.switchPanel(to: panel)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline.weight(.medium))

                if showBadge {
                    PulsingDot()
                }
            }
            .foregroundStyle(viewModel.activePanel == panel ? AppTheme.accent : AppTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                viewModel.activePanel == panel
                    ? AppTheme.accent.opacity(0.1)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pulsing Dot

private struct PulsingDot: View {
    @State private var animating = false

    var body: some View {
        Circle()
            .fill(AppTheme.accent)
            .frame(width: 8, height: 8)
            .scaleEffect(animating ? 1.5 : 0.8)
            .opacity(animating ? 1.0 : 0.4)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    animating = true
                }
            }
    }
}
