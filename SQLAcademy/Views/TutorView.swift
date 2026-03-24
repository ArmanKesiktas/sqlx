import SwiftUI

struct TutorView: View {
    @StateObject private var viewModel: TutorViewModel
    private let package: TutorPackage
    private let localization: LocalizationService
    private let packageProgress: () -> Double
    private let isLessonCompleted: (String) -> Bool
    private let onStartPackage: () -> Void
    private let onRestartPackage: ([String]) -> Void
    private let hasResumeState: Bool

    @State private var isChatStarted = false
    @State private var showLandscapeSuggestion = false
@State private var showTopicsExpanded = false
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(
        package: TutorPackage,
        localization: LocalizationService,
        packageProgress: @escaping () -> Double,
        isLessonCompleted: @escaping (String) -> Bool,
        storedProfession: String?,
        initialSceneIndex: Int = 0,
        competency: TutorCompetencyProfile = .empty,
        isLabSceneCompleted: @escaping (String) -> Bool = { _ in false },
        onStartPackage: @escaping () -> Void,
        onRestartPackage: @escaping ([String]) -> Void = { _ in },
        onSaveSceneProgress: @escaping (Int, String) -> Void = { _, _ in },
        onMarkLabSceneCompleted: @escaping (String) -> Void = { _ in },
        onApprove: @escaping (Int) -> Void,
        onProfessionSaved: @escaping (String) -> Void,
        onLessonCompleted: @escaping (String, [String], Int) -> Void,
        onMasteryStarted: @escaping (String) -> Void,
        onMiniTaskEvaluated: @escaping (String, Bool) -> Void,
        onMiniChallengeEvaluated: @escaping (String, Bool) -> Void,
        onCompetencyUpdated: @escaping (TutorCompetencyProfile) -> Void = { _ in }
    ) {
        self.package = package
        self.localization = localization
        self.packageProgress = packageProgress
        self.isLessonCompleted = isLessonCompleted
        self.onStartPackage = onStartPackage
        self.onRestartPackage = onRestartPackage
        self.hasResumeState = initialSceneIndex > 0
        _viewModel = StateObject(
            wrappedValue: TutorViewModel(
                package: package,
                localization: localization,
                storedProfession: storedProfession,
                initialSceneIndex: initialSceneIndex,
                competency: competency,
                isLabSceneCompleted: isLabSceneCompleted,
                onSaveSceneProgress: onSaveSceneProgress,
                onMarkLabSceneCompleted: onMarkLabSceneCompleted,
                onApprove: onApprove,
                onLessonCompleted: onLessonCompleted,
                onProfessionSaved: onProfessionSaved,
                onMasteryStarted: onMasteryStarted,
                onMiniTaskEvaluated: onMiniTaskEvaluated,
                onMiniChallengeEvaluated: onMiniChallengeEvaluated,
                onCompetencyUpdated: onCompetencyUpdated
            )
        )
    }

    var body: some View {
        ZStack {
            AcademyBackground()
            if isChatStarted {
                activeLessonLayout
            } else {
                introLayout
            }
        }
        .navigationTitle(isChatStarted && horizontalSizeClass == .regular ? "" : localization.text("tutor.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isChatStarted && horizontalSizeClass == .regular ? .hidden : .visible, for: .navigationBar)
        .onAppear {
            // Auto-resume saved session without showing intro screen
            if viewModel.hasSavedSession {
                isChatStarted = true
                // If session ended mid-response (last message is from user), resume
                viewModel.resumeIfPendingResponse()
            } else if hasResumeState {
                // Session lost (e.g. app restart) but progress exists — auto-start
                isChatStarted = true
                viewModel.startSessionIfNeeded()
            }
        }
    }

    // MARK: - Intro Layout

    private var introLayout: some View {
        ScrollView {
            VStack(spacing: 12) {
                packageTitleHeader
                packageProgressCard
                lessonListCard
            }
            .padding()
            .padding(.bottom, 110)
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if hasResumeState {
                    HStack(spacing: 10) {
                        Button(localization.text("tutor.resume")) {
                            onStartPackage()
                            isChatStarted = true
                            viewModel.startSessionIfNeeded()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(SolidGreenActionButtonStyle())
                        .accessibilityIdentifier("tutor.resume")

                        Button(localization.text("tutor.startOver")) {
                            onStartPackage()
                            onRestartPackage(viewModel.storyboardSceneIDs)
                            isChatStarted = true
                            viewModel.startOver()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(SolidGreenActionButtonStyle())
                        .accessibilityIdentifier("tutor.startOver")
                    }
                } else {
                    Button(localization.text("tutor.start")) {
                        onStartPackage()
                        isChatStarted = true
                        viewModel.startSessionIfNeeded()
                    }
                    .buttonStyle(GradientActionButtonStyle())
                    .accessibilityIdentifier("tutor.start")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Active Lesson Layout (Split View)

    private var activeLessonLayout: some View {
        Group {
            if horizontalSizeClass == .regular {
                HStack(spacing: 0) {
                    TutorSplitView(viewModel: viewModel, localization: localization)
                    verticalProgressBar
                }
                .ignoresSafeArea(.container, edges: .top)
            } else {
                VStack(spacing: 0) {
                    progressHeader
                    TutorSplitView(viewModel: viewModel, localization: localization)
                }
            }
        }
        .overlay {
            if showLandscapeSuggestion {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { showLandscapeSuggestion = false }

                LandscapeSuggestionOverlay(localization: localization) {
                    showLandscapeSuggestion = false
                    UserDefaults.standard.set(true, forKey: "tutor.landscapeSuggestionShown")
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showLandscapeSuggestion)
        .onAppear {
            if horizontalSizeClass == .compact,
               !UserDefaults.standard.bool(forKey: "tutor.landscapeSuggestionShown") {
                showLandscapeSuggestion = true
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Chevron tap area to expand/collapse lesson topics
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    showTopicsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showTopicsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                    Text(localization.text("tutor.topics"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
            .buttonStyle(.plain)

            // Expandable topics list
            if showTopicsExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(package.interests) { interest in
                        HStack(spacing: 8) {
                            Image(systemName: isLessonCompleted(interest.id) ? "checkmark.circle.fill" : "circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isLessonCompleted(interest.id) ? AppTheme.accent : AppTheme.textSecondary)
                            Text(localization.text(interest.titleKey))
                                .font(.caption)
                                .foregroundStyle(isLessonCompleted(interest.id) ? AppTheme.textPrimary : AppTheme.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider().opacity(0.5)

            // Progress bar + labels
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.currentLessonTitle)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                HStack {
                    Text(viewModel.estimatedProgressLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text("\(Int(viewModel.sessionProgress * 100))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }

                ProgressView(value: viewModel.sessionProgress)
                    .tint(AppTheme.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    private var verticalProgressBar: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            // Vertical progress track (fills bottom-to-top)
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    Capsule()
                        .fill(AppTheme.accentSoft.opacity(0.3))
                    Capsule()
                        .fill(AppTheme.accent)
                        .frame(height: geo.size.height * viewModel.sessionProgress)
                        .animation(.easeInOut(duration: 0.4), value: viewModel.sessionProgress)
                }
            }
            .frame(width: 5)

            Spacer(minLength: 6)

            // Percentage label
            Text("\(Int(viewModel.sessionProgress * 100))%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.accent)

            Spacer(minLength: 8)
        }
        .frame(width: 32)
        .background(.ultraThinMaterial)
    }

    // MARK: - Intro Components

    private var packageTitleHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localization.text(package.titleKey))
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineSpacing(-4)
                .minimumScaleFactor(0.82)

            if !isChatStarted {
                Text(localization.text(package.descriptionKey))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var packageProgressCard: some View {
        AcademyCard {
            VStack(alignment: .leading, spacing: 8) {
                AcademySectionTitle(title: localization.text("tutor.packageProgress"), symbol: "chart.bar.fill")
                ProgressView(value: packageProgress())
                    .tint(AppTheme.accent)
                Text("\(Int(packageProgress() * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var lessonListCard: some View {
        AcademyCard {
            VStack(alignment: .leading, spacing: 10) {
                AcademySectionTitle(title: localization.text("tutor.packageLessons"), symbol: "list.bullet.rectangle")
                ForEach(package.interests) { interest in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(localization.text(interest.titleKey))
                                .font(.subheadline.weight(.semibold))
                            if let descriptionKey = interest.descriptionKey {
                                Text(localization.text(descriptionKey))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer()
                        Image(systemName: isLessonCompleted(interest.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isLessonCompleted(interest.id) ? AppTheme.accent : AppTheme.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Landscape Suggestion Overlay

private struct LandscapeSuggestionOverlay: View {
    let localization: LocalizationService
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "rotate.right")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(AppTheme.accent)

            Text(localization.text("tutor.rotateSuggestion"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)

            Button(localization.text("tutor.gotIt")) { onDismiss() }
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(AppTheme.buttonGradient)
                .clipShape(Capsule())
        }
        .padding(24)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
        .padding(.horizontal, 40)
    }
}
