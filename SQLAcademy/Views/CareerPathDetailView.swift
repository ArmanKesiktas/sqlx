import SwiftUI
import AudioToolbox

struct CareerPathDetailView: View {
    let careerPath: CareerPath

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localization: LocalizationService
    @State private var showCompletionCelebration = false

    private var isTR: Bool { localization.language == .tr }

    private var pathModules: [LearningModule] {
        careerPath.moduleIDs.compactMap { mid in
            appState.modules.first { $0.id == mid }
        }
    }

    private var completedCount: Int {
        careerPath.moduleIDs.filter { appState.progress.completedModuleIDs.contains($0) }.count
    }

    private var totalCount: Int { careerPath.moduleIDs.count }

    private var progress: Double {
        totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
    }

    private var isPathComplete: Bool { completedCount == totalCount && totalCount > 0 }

    // Next recommended module (first incomplete)
    private var nextModule: LearningModule? {
        pathModules.first { !appState.progress.completedModuleIDs.contains($0.id) }
    }

    // Earned milestones
    private var earnedMilestones: [CareerMilestone] {
        careerPath.milestones.filter { completedCount >= $0.moduleCount }
    }

    // Next milestone
    private var nextMilestone: CareerMilestone? {
        careerPath.milestones.first { completedCount < $0.moduleCount }
    }

    var body: some View {
        ZStack {
            AcademyBackground()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    progressSection
                    if let next = nextMilestone {
                        nextMilestoneSection(next)
                    }
                    if let next = nextModule {
                        continueSection(next)
                    }
                    if !earnedMilestones.isEmpty {
                        milestonesSection
                    }
                    modulesSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }

            if showCompletionCelebration {
                pathCompletionOverlay
            }
        }
        .navigationTitle(localization.text(careerPath.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if isPathComplete {
                showCompletionCelebration = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.10))
                    .frame(width: 70, height: 70)
                Image(systemName: careerPath.icon)
                    .font(.system(size: 30))
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(.top, 8)

            Text(localization.text(careerPath.descriptionKey))
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            // Target audience
            HStack(spacing: 4) {
                Image(systemName: "person.2")
                    .font(.system(size: 10))
                Text(localization.text(careerPath.targetAudienceKey))
                    .font(.system(size: 11))
            }
            .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(isTR ? "Ilerleme" : "Progress")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(completedCount)/\(totalCount) \(isTR ? "modul" : "modules")")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isPathComplete ? AppTheme.accent : AppTheme.textSecondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.cardBorder.opacity(0.3))
                        .frame(height: 10)
                    Capsule()
                        .fill(isPathComplete ? AppTheme.accent : AppTheme.secondaryAccent)
                        .frame(width: max(0, geo.size.width * progress), height: 10)
                        .animation(.easeOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 10)

            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isPathComplete ? AppTheme.accent : AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(AppTheme.cardBackground.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Next Milestone

    private func nextMilestoneSection(_ milestone: CareerMilestone) -> some View {
        let remaining = milestone.moduleCount - completedCount
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.secondaryAccent.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "flag.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.secondaryAccent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(localization.text(milestone.titleKey))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(isTR ? "\(remaining) modul daha!" : "\(remaining) more modules!")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(AppTheme.secondaryAccent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.secondaryAccent.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Continue Button

    private func continueSection(_ module: LearningModule) -> some View {
        NavigationLink {
            ModuleDetailView(module: module)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(isTR ? "Devam Et" : "Continue")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .tracking(0.5)
                    Text(localization.text(module.titleKey))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.accent, in: Circle())
            }
            .padding(16)
            .background(AppTheme.accent.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.accent.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Earned Milestones

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AcademySectionTitle(
                title: isTR ? "Kazanilan Basarimlar" : "Milestones Earned",
                symbol: "star.fill"
            )

            ForEach(earnedMilestones, id: \.moduleCount) { milestone in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localization.text(milestone.titleKey))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(localization.text(milestone.descriptionKey))
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(AppTheme.accent.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Modules List

    private var modulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AcademySectionTitle(
                title: isTR ? "Moduller" : "Modules",
                symbol: "list.number"
            )

            ForEach(Array(pathModules.enumerated()), id: \.element.id) { index, module in
                let isCompleted = appState.progress.completedModuleIDs.contains(module.id)
                let isLocked = index > 0 && !appState.progress.completedModuleIDs.contains(pathModules[index - 1].id) && !isCompleted
                let quizScore = appState.progress.quizScores[module.id]

                if isLocked {
                    lockedModuleRow(index: index, module: module)
                } else {
                    NavigationLink {
                        ModuleDetailView(module: module)
                    } label: {
                        moduleRow(index: index, module: module, isCompleted: isCompleted, quizScore: quizScore)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func moduleRow(index: Int, module: LearningModule, isCompleted: Bool, quizScore: Int?) -> some View {
        HStack(spacing: 14) {
            // Step number / check
            ZStack {
                Circle()
                    .fill(isCompleted ? AppTheme.accent : AppTheme.cardBorder.opacity(0.3))
                    .frame(width: 34, height: 34)
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(localization.text(module.titleKey))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                if let score = quizScore {
                    Text(isTR ? "Puan: %\(score)" : "Score: \(score)%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(score >= 70 ? AppTheme.accent : AppTheme.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.4))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(isCompleted ? AppTheme.accent.opacity(0.03) : AppTheme.cardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isCompleted ? AppTheme.accent.opacity(0.15) : AppTheme.cardBorder.opacity(0.4), lineWidth: 1)
        )
    }

    private func lockedModuleRow(index: Int, module: LearningModule) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.cardBorder.opacity(0.2))
                    .frame(width: 34, height: 34)
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.4))
            }

            Text(localization.text(module.titleKey))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(AppTheme.cardBackground.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardBorder.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Path Completion Celebration

    private var pathCompletionOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showCompletionCelebration = false }
                }

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(AppTheme.accent)
                }

                Text(isTR ? "Kariyer Yolu Tamamlandi!" : "Career Path Complete!")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)

                Text(localization.text(careerPath.titleKey))
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)

                Text(isTR ? "Tebrikler! Bu yoldaki tum modulleri basariyla tamamladin." : "Congratulations! You've completed all modules in this path.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation { showCompletionCelebration = false }
                } label: {
                    Text(isTR ? "Kapat" : "Close")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientActionButtonStyle())
                .padding(.horizontal, 40)
            }
            .padding(28)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 30, y: 10)
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
        .onAppear {
            AudioServicesPlaySystemSound(1336)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
