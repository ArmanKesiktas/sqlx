import SwiftUI

struct TutorChatPanel: View {
    @ObservedObject var viewModel: TutorViewModel
    let localization: LocalizationService

    @StateObject private var speech = SpeechManager.shared
    @FocusState private var isInputFocused: Bool
    @State private var lastMessageAnimated = false

    private var showConnecting: Bool {
        viewModel.messages.isEmpty && !viewModel.isTyping && !viewModel.isPreparingResponse
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                speakerHeaderBar
                chatMessages
                Spacer(minLength: 0)
                bottomControls
            }
            .opacity(showConnecting ? 0 : 1)

            if showConnecting {
                TutorConnectingView()
            }
        }
        .onChange(of: viewModel.messages.count) { _, _ in
            lastMessageAnimated = false
            if let last = viewModel.messages.last, last.role == .assistant {
                if let audioData = viewModel.pendingAudioForPlayback {
                    speech.playPreparedAudio(audioData)
                    viewModel.clearPendingAudio()
                } else if !speech.isMuted {
                    let lang = localization.language.ttsCode
                    speech.speak(text: last.text, languageCode: lang)
                }
            }
        }
        .onChange(of: viewModel.activePanel) { _, newPanel in
            if newPanel != .chat {
                isInputFocused = false
            }
        }
        .onDisappear {
            speech.stop()
        }
    }

    private var speakerHeaderBar: some View {
        HStack {
            Spacer()
            Button {
                speech.isMuted.toggle()
            } label: {
                Image(systemName: speech.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(speech.isMuted ? AppTheme.textSecondary : AppTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(AppTheme.capsuleBackground)
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
            .padding(.top, 6)
        }
    }

    private var chatMessages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.messages) { message in
                        chatBubble(message)
                            .id(message.id)
                    }

                    if viewModel.isTyping || viewModel.isPreparingResponse {
                        SkeletonMessageBubble()
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isPreparingResponse) { _, _ in
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 8) {
            if !viewModel.quickReplies.isEmpty {
                quickRepliesView
            }
            inputBar
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var quickRepliesView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.quickReplies, id: \.self) { option in
                    Button(option) {
                        viewModel.sendQuickReply(option)
                    }
                    .buttonStyle(SolidGreenActionButtonStyle())
                    .disabled(viewModel.isTyping)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(localization.text("tutor.inputPlaceholder"), text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($isInputFocused)
                .disabled(viewModel.isTyping)
                .accessibilityIdentifier("tutor.input")

            Button {
                isInputFocused = false
                viewModel.sendFromInput()
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.buttonGradient)
                    .clipShape(Circle())
            }
            .disabled(viewModel.isTyping)
            .accessibilityIdentifier("tutor.send")
        }
    }

    @ViewBuilder
    private func chatBubble(_ message: TutorChatMessage) -> some View {
        let isLastAssistant = viewModel.messages.last?.id == message.id
            && message.role == .assistant
        let showLabCTA = isLastAssistant
            && viewModel.labState.isLabVisible
            && viewModel.activePanel == .chat
            && !viewModel.isTyping
            && lastMessageAnimated

        HStack(alignment: .top) {
            if message.role == .assistant {
                VStack(alignment: .leading, spacing: 6) {
                    AnimatedMessageText(
                        message: message,
                        targetDuration: isLastAssistant ? viewModel.pendingAnimationDuration : nil,
                        onAnimationComplete: isLastAssistant ? {
                            lastMessageAnimated = true
                        } : nil
                    )
                        .padding(12)
                        .background(AppTheme.elevatedCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    showLabCTA ? AppTheme.accent.opacity(0.55) : Color.clear,
                                    lineWidth: 1.5
                                )
                        )

                    if let result = message.result {
                        SQLResultView(result: result)
                            .padding(10)
                            .background(AppTheme.elevatedCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    if showLabCTA {
                        LabCTAButton(localization: localization) {
                            viewModel.switchPanel(to: .editor)
                        }
                    }
                }
                Spacer(minLength: 28)
            } else {
                Spacer(minLength: 28)
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(AppTheme.buttonGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}

// MARK: - Connecting View

private struct TutorConnectingView: View {
    @State private var dotPhase = 0

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentSoft.opacity(0.25))
                    .frame(width: 72, height: 72)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppTheme.accentDark)
            }

            VStack(spacing: 6) {
                Text("AI Coach")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(AppTheme.accent.opacity(dotPhase == i ? 1.0 : 0.3))
                            .frame(width: 6, height: 6)
                            .scaleEffect(dotPhase == i ? 1.2 : 0.8)
                            .animation(.easeInOut(duration: 0.3), value: dotPhase)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startDotAnimation()
        }
    }

    private func startDotAnimation() {
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 400_000_000)
                dotPhase = (dotPhase + 1) % 3
            }
        }
    }
}

// MARK: - Lab CTA Button (pulsing)

private struct LabCTAButton: View {
    let localization: LocalizationService
    let onTap: () -> Void

    @State private var pulsing = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.caption.weight(.semibold))
                Text(localization.language == .tr ? "SQL Editörü Aç" : "Open SQL Editor")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                AppTheme.accent.opacity(pulsing ? 0.14 : 0.06)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.accent.opacity(pulsing ? 0.7 : 0.25), lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}

// MARK: - Skeleton Message Bubble

private struct SkeletonMessageBubble: View {
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                shimmerBar(widthFraction: 1.0)
                shimmerBar(widthFraction: 0.75)
                shimmerBar(widthFraction: 0.5)
            }
            .padding(12)
            .background(AppTheme.elevatedCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer(minLength: 28)
        }
        .padding(.horizontal, 12)
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                shimmerOffset = 200
            }
        }
    }

    private func shimmerBar(widthFraction: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(AppTheme.textSecondary.opacity(0.12))
            .frame(maxWidth: .infinity)
            .frame(height: 12)
            .scaleEffect(x: widthFraction, anchor: .leading)
            .overlay(
                LinearGradient(
                    colors: [.clear, AppTheme.textSecondary.opacity(0.08), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: shimmerOffset)
            )
            .clipped()
    }
}

private final class AnimationTracker: @unchecked Sendable {
    static let shared = AnimationTracker()
    private var animatedIDs: Set<UUID> = []
    private let lock = NSLock()

    func markAnimated(_ id: UUID) { lock.withLock { _ = animatedIDs.insert(id) } }
    func hasAnimated(_ id: UUID) -> Bool { lock.withLock { animatedIDs.contains(id) } }
}

struct AnimatedMessageText: View {
    let message: TutorChatMessage
    var targetDuration: TimeInterval?
    var onAnimationComplete: (() -> Void)?

    @State private var displayedText = ""
    @State private var cursorVisible = true
    @State private var animationTask: Task<Void, Never>?
    @State private var isAnimating = false

    var body: some View {
        textWithCursor
            .font(.subheadline)
            .onAppear {
            startAnimationIfNeeded()
        }
        .onChange(of: message.id) { _, _ in
            startAnimationIfNeeded()
        }
        .onDisappear {
            animationTask?.cancel()
        }
    }

    private var textWithCursor: Text {
        if isAnimating {
            Text(displayedText)
                .foregroundColor(AppTheme.textPrimary)
            + Text(cursorVisible ? "\u{258F}" : " ")
                .foregroundColor(AppTheme.accent)
                .fontWeight(.bold)
        } else {
            Text(displayedText)
                .foregroundColor(AppTheme.textPrimary)
        }
    }

    private func startAnimationIfNeeded() {
        animationTask?.cancel()

        guard message.role == .assistant else {
            displayedText = message.text
            isAnimating = false
            onAnimationComplete?()
            return
        }

        // Already animated once — show full text instantly
        if AnimationTracker.shared.hasAnimated(message.id) {
            displayedText = message.text
            isAnimating = false
            onAnimationComplete?()
            return
        }

        AnimationTracker.shared.markAnimated(message.id)
        displayedText = ""
        isAnimating = true
        cursorVisible = true
        let fullText = message.text

        // Per-character delay: ~49ms (35ms * 1.4 = 40% slower)
        let charCount = fullText.count
        let baseDelayNanos: UInt64
        if let duration = targetDuration, charCount > 0 {
            baseDelayNanos = UInt64(duration * 1_000_000_000 * 2.24) / UInt64(charCount)
        } else {
            baseDelayNanos = 49_000_000  // ~49ms per character
        }

        animationTask = Task {
            var current = ""
            for (i, character) in fullText.enumerated() {
                if Task.isCancelled { return }
                current.append(character)
                await MainActor.run {
                    displayedText = current
                    // Blink cursor roughly every 8 characters
                    if i % 8 == 0 { cursorVisible.toggle() }
                }
                try? await Task.sleep(nanoseconds: baseDelayNanos)
            }
            await MainActor.run {
                isAnimating = false
                onAnimationComplete?()
            }
        }
    }
}
