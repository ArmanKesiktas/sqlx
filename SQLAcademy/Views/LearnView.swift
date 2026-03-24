import SwiftUI

struct LearnView: View {
    private enum ModuleFilter: String, CaseIterable, Identifiable {
        case all, beginner, intermediate, advanced, completed, inProgress
        var id: String { rawValue }
    }

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localization: LocalizationService

@State private var selectedModuleFilter: ModuleFilter = .all
    @State private var expandedModuleID: String? = nil
    @State private var navigateToModule: LearningModule? = nil

    var body: some View {
        ZStack {
            AcademyBackground()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(localization.text("learn.heroTitle"))
                        .academyTitleStyle()

                    AcademySectionBlock(title: localization.text("learn.modules"), symbol: "book.pages") {
                        topControls
                        LazyVStack(spacing: 10) {
                            ForEach(filteredModules) { module in
                                VStack(spacing: 0) {
                                    Button {
                                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                            expandedModuleID = expandedModuleID == module.id ? nil : module.id
                                        }
                                    } label: {
                                        moduleRow(module, isExpanded: expandedModuleID == module.id)
                                    }
                                    .buttonStyle(.plain)

                                    if expandedModuleID == module.id {
                                        NavigationLink(destination: ModuleDetailView(module: module)) {
                                            HStack {
                                                Image(systemName: "play.fill")
                                                    .font(.caption.weight(.bold))
                                                Text(localization.text("learn.startLesson"))
                                                    .font(.subheadline.weight(.bold))
                                            }
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 13)
                                            .background(AppTheme.heroGradient)
                                            .clipShape(
                                                UnevenRoundedRectangle(
                                                    topLeadingRadius: 0,
                                                    bottomLeadingRadius: 14,
                                                    bottomTrailingRadius: 14,
                                                    topTrailingRadius: 0,
                                                    style: .continuous
                                                )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(
                                            expandedModuleID == module.id
                                                ? AppTheme.accent.opacity(0.45)
                                                : Color.clear,
                                            lineWidth: 1.2
                                        )
                                )
                                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: expandedModuleID)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .padding(.bottom, 110)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ModuleFilter.allCases) { filter in
                    Button(localizedModuleFilterTitle(filter)) {
                        selectedModuleFilter = filter
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selectedModuleFilter == filter ? .white : AppTheme.accentDark)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(selectedModuleFilter == filter ? AppTheme.solidButtonGreen : AppTheme.capsuleBackground)
                    )
                    .overlay(
                        Capsule()
                            .stroke(selectedModuleFilter == filter ? AppTheme.buttonBorderLight : AppTheme.cardBorder, lineWidth: 1.1)
                    )
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var filteredModules: [LearningModule] {
        switch selectedModuleFilter {
        case .all:
            return appState.modules
        case .beginner:
            return appState.modules.filter { $0.level == .beginner }
        case .intermediate:
            return appState.modules.filter { $0.level == .intermediate }
        case .advanced:
            return appState.modules.filter { $0.level == .advanced }
        case .completed:
            return appState.modules.filter { appState.progress.completedModuleIDs.contains($0.id) }
        case .inProgress:
            return appState.modules.filter { module in
                !appState.progress.completedModuleIDs.contains(module.id) &&
                module.challenges.contains { appState.progress.completedChallengeIDs.contains($0.id) }
            }
        }
    }

    private func localizedModuleFilterTitle(_ filter: ModuleFilter) -> String {
        switch filter {
        case .all:        return localization.text("learn.filter.all")
        case .beginner:   return localization.text("learn.filter.beginner")
        case .intermediate: return localization.text("learn.filter.intermediate")
        case .advanced:   return localization.text("learn.filter.advanced")
        case .completed:  return localization.text("learn.filter.completed")
        case .inProgress: return localization.text("learn.filter.inProgress")
        }
    }

    // MARK: - Tutor Package Cards (compact)

    private var packageCardWidth: CGFloat {
        min(max(UIScreen.main.bounds.width - 92, 200), 250)
    }

    private func tutorPackageCard(_ package: TutorPackage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: package.icon)
                        .foregroundStyle(.white)
                    BrandLogoView(.white, height: 12)
                }
                Spacer()
                Text(localization.text("learn.plus.badge"))
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.accentDark)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.92)))
            }

            Text(localization.text(package.titleKey))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(localization.text(package.descriptionKey))
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(2)

            Spacer(minLength: 0)

            ProgressView(value: appState.tutorPackageProgress(packageID: package.id))
                .tint(Color.white.opacity(0.94))
        }
        .frame(width: packageCardWidth, height: 120, alignment: .leading)
        .padding(14)
        .background(AppTheme.heroGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.buttonBorderLight.opacity(0.9), lineWidth: 1.2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: AppTheme.accentDark.opacity(0.22), radius: 16, x: 0, y: 8)
    }

    // MARK: - Module Row (redesigned with progress ring)

    private func moduleRow(_ module: LearningModule, isExpanded: Bool = false) -> some View {
        let isCompleted = appState.progress.completedModuleIDs.contains(module.id)
        let quizScore = appState.progress.quizScores[module.id]
        let completedChallengeCount = module.challenges.filter {
            appState.progress.completedChallengeIDs.contains($0.id)
        }.count
        let totalChallenges = module.challenges.count

        let levelColor: Color = module.level == .beginner
            ? AppTheme.accent
            : module.level == .intermediate
            ? AppTheme.secondaryAccent
            : AppTheme.rose

        return HStack(spacing: 14) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(AppTheme.cardBorder, lineWidth: 3)
                if let score = quizScore, !isCompleted {
                    Circle()
                        .trim(from: 0, to: Double(score) / 100.0)
                        .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.6), value: score)
                }
                if isCompleted {
                    Circle().fill(AppTheme.accent.opacity(0.18))
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.accentDark)
                } else {
                    Text("\(module.order)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 6) {
                Text(localization.text(module.titleKey))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(localization.text(module.descriptionKey))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    // Level badge
                    Text(module.level.rawValue.capitalized)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(levelColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(levelColor.opacity(0.12))
                        .clipShape(Capsule())

                    if let score = quizScore {
                        HStack(spacing: 3) {
                            Image(systemName: score >= 80 ? "star.fill" : "star.leadinghalf.filled")
                                .font(.system(size: 9))
                                .foregroundStyle(score >= 80 ? AppTheme.success : AppTheme.secondaryAccent)
                            Text("\(score)%")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(score >= 80 ? AppTheme.success : AppTheme.secondaryAccent)
                        }
                    } else if totalChallenges > 0 && completedChallengeCount > 0 {
                        Text("\(completedChallengeCount)/\(totalChallenges) \(localization.language == .tr ? "görev" : "done")")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isCompleted
                ? AppTheme.accent.opacity(0.06)
                : AppTheme.cardBackground
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: isExpanded ? 0 : 18,
                bottomTrailingRadius: isExpanded ? 0 : 18,
                topTrailingRadius: 18,
                style: .continuous
            )
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: isExpanded ? 0 : 18,
                bottomTrailingRadius: isExpanded ? 0 : 18,
                topTrailingRadius: 18,
                style: .continuous
            )
            .stroke(
                isCompleted ? AppTheme.accent.opacity(0.25) : AppTheme.cardBorder,
                lineWidth: 1.1
            )
        )
    }

    // MARK: - TutorView Factory

    private func makeTutorView(package: TutorPackage) -> TutorView {
        TutorView(
            package: package,
            localization: localization,
            packageProgress: { appState.tutorPackageProgress(packageID: package.id) },
            isLessonCompleted: { appState.isTutorLessonCompleted(packageID: package.id, interestID: $0) },
            storedProfession: appState.tutorProfession(packageID: package.id),
            initialSceneIndex: appState.resumeTutorPackage(packageID: package.id),
            competency: appState.tutorCompetency(packageID: package.id),
            isLabSceneCompleted: { appState.isTutorLabSceneCompleted(sceneID: $0) },
            onStartPackage: { appState.startTutorPackage(package.id) },
            onRestartPackage: { appState.restartTutorPackage(packageID: package.id, sceneIDs: $0) },
            onSaveSceneProgress: { appState.saveTutorSceneProgress(packageID: package.id, sceneIndex: $0, sceneID: $1) },
            onMarkLabSceneCompleted: { appState.markTutorLabSceneCompleted(sceneID: $0) },
            onApprove: { appState.addPoints($0) },
            onProfessionSaved: { appState.setTutorProfession(packageID: package.id, profession: $0) },
            onLessonCompleted: { interestID, evidenceSQL, masteryScore in
                appState.completeTutorLesson(packageID: package.id, interestID: interestID, masteryScore: masteryScore, evidenceSQL: evidenceSQL)
            },
            onMasteryStarted: { appState.startTutorMastery(packageID: package.id, interestID: $0) },
            onMiniTaskEvaluated: { appState.submitTutorMiniTask(packageID: package.id, interestID: $0, isCorrect: $1) },
            onMiniChallengeEvaluated: { appState.submitTutorMiniChallenge(packageID: package.id, interestID: $0, isCorrect: $1) },
            onCompetencyUpdated: { appState.updateTutorCompetency(packageID: package.id, competency: $0) }
        )
    }
}
