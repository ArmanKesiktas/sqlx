import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localization: LocalizationService
    @Environment(\.colorScheme) private var colorScheme
    @State private var dailyMissionStates: [DailyMissionState] = []
    @State private var missionNavTarget: DailyMission? = nil
    @State private var showPaywall = false
    private let onProfileTapped: () -> Void

    init(onProfileTapped: @escaping () -> Void = {}) {
        self.onProfileTapped = onProfileTapped
    }

    var body: some View {
        ZStack {
            AcademyBackground()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    heroHeader
                    continueLearningSection
                    compactStatsRow
                    streakCard
                    dailyMissionsSection

                    AcademySectionBlock(title: localization.text("home.badges"), symbol: "rosette") {
                        if appState.progress.badgeIDs.isEmpty {
                            Text(localization.text("home.noBadges"))
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(appState.badges.filter { appState.progress.badgeIDs.contains($0.id) }) { badge in
                                    AcademySectionSurface(padding: 14) {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "seal.fill")
                                                .foregroundStyle(AppTheme.secondaryAccent)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(localization.text(badge.titleKey))
                                                    .font(.subheadline.bold())
                                                Text(localization.text(badge.descriptionKey))
                                                    .font(.caption)
                                                    .foregroundStyle(AppTheme.textSecondary)
                                            }
                                            Spacer(minLength: 0)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .padding(.bottom, 90)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .toolbar(.hidden, for: .navigationBar)
.navigationDestination(item: $missionNavTarget) { mission in
            missionDestinationView(for: mission)
        }
        .task {
            refreshDailyMissions()
        }
        .onChange(of: missionNavTarget) { _, target in
            // When navigation dismisses (target becomes nil), auto-complete missions whose target was achieved
            if target == nil { autoCompleteMissions() }
        }
    }

    // MARK: - Hero Header (compact)

    private var heroHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            BrandLogoView(colorScheme == .dark ? .white : .black, height: 22)

            Spacer(minLength: 8)

            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Text("\(appState.progress.streakDays)")
                    .font(.title3.weight(.black))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(red: 0.98, green: 0.55, blue: 0.10))
            .clipShape(Capsule())

            profileAvatarButton
        }
        .padding(.top, 4)
    }

    // MARK: - Continue Learning Card

    private var continueLearningSection: some View {
        Group {
            if let nextModule = appState.modules.first(where: {
                !appState.progress.completedModuleIDs.contains($0.id)
            }) {
                NavigationLink {
                    ModuleDetailView(module: nextModule)
                } label: {
                    continueCard(
                        title: localization.text(nextModule.titleKey),
                        icon: "book.pages",
                        progress: appState.moduleCompletionRatio()
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func continueCard(title: String, icon: String, progress: Double) -> some View {
        AcademyCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(AppTheme.accentSoft.opacity(0.4), lineWidth: 4)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accentDark)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(localization.text("home.continueLearning"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .tracking(0.6)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Text("\(Int(progress * 100))% \(localization.text("home.complete"))")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }

    // MARK: - Plus Promo Card

    private var plusPromoCard: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        BrandLogoView(.white, height: 14)
                        Text("Plus")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    Text(localization.text("home.plusPromo"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }
                Spacer()
                Text(localization.text("home.viewPlans"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.accentDark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.92))
                    .clipShape(Capsule())
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.heroGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: AppTheme.accentDark.opacity(0.18), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Compact Stats Row

    private var compactStatsRow: some View {
        HStack(spacing: 10) {
            // XP Card — solid blue
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("\(appState.progress.totalPoints)")
                        .font(.title2.weight(.black))
                        .foregroundStyle(.white)
                }
                Text("XP")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.25, green: 0.47, blue: 0.95))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Modules stat — solid green
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "book.closed.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("\(appState.progress.completedModuleIDs.count)/\(appState.modules.count)")
                        .font(.title2.weight(.black))
                        .foregroundStyle(.white)
                }
                Text(localization.text("home.modules"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.13, green: 0.55, blue: 0.28))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        AcademyCard {
            VStack(spacing: 12) {
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.warm)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(appState.progress.streakDays)")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(localization.text("home.streak.days"))
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    Spacer()
                    if appState.progress.streakDays >= 7 {
                        Label(localization.text("home.streak.badge7"), systemImage: "star.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.warm)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppTheme.warm.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                // 7-day activity calendar
                HStack(spacing: 0) {
                    ForEach(last7Days, id: \.0) { entry in
                        VStack(spacing: 5) {
                            Text(entry.1)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                            Circle()
                                .fill(
                                    appState.progress.activityDates.contains(entry.0)
                                        ? AppTheme.accent
                                        : AppTheme.textSecondary.opacity(0.18)
                                )
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            appState.progress.activityDates.contains(entry.0)
                                                ? AppTheme.accent.opacity(0.4)
                                                : Color.clear,
                                            lineWidth: 2
                                        )
                                        .frame(width: 16, height: 16)
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var last7Days: [(String, String)] {
        let dateFmt = ISO8601DateFormatter()
        dateFmt.formatOptions = [.withFullDate]
        let dayFmt = DateFormatter()
        dayFmt.locale = Locale(identifier: localization.language.rawValue)
        dayFmt.dateFormat = "EEEEE"
        return stride(from: 6, through: 0, by: -1).compactMap { offset -> (String, String)? in
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return (dateFmt.string(from: date), dayFmt.string(from: date))
        }
    }

    // MARK: - Popular Section (compact cards)

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                AcademySectionTitle(title: localization.text("home.popular"), symbol: "sparkles")
                Spacer()
                NavigationLink {
                    TutorPackageListView(titleKey: "home.popularAllTitle")
                } label: {
                    Text(localization.text("home.viewMore"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(AppTheme.capsuleBackground)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(appState.tutorPackages) { package in
                        NavigationLink {
                            makeTutorView(package: package)
                        } label: {
                            packageCard(package)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.trailing, 12)
                .padding(.vertical, 8)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Package Card (compact ~160px)

    private var packageCardWidth: CGFloat {
        max(200, min(UIScreen.main.bounds.width - 72, 260))
    }

    private func packageCard(_ package: TutorPackage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: package.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text("\(package.interests.count) \(localization.text("home.lessonCountLabel"))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.75))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.85))
                    .clipShape(Capsule())
            }

            Spacer(minLength: 0)

            Text(localization.text(package.titleKey))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(localization.text(package.descriptionKey))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(2)

            ProgressView(value: appState.tutorPackageProgress(packageID: package.id))
                .tint(.white.opacity(0.9))
        }
        .padding(14)
        .frame(width: packageCardWidth, height: 160, alignment: .leading)
        .background(AppTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: AppTheme.accentDark.opacity(0.22), radius: 14, x: 0, y: 6)
    }

    // MARK: - Daily Missions

    private var dailyMissionsSection: some View {
        AcademySectionBlock(title: localization.text("retention.dailyTitle"), symbol: "calendar") {
            VStack(alignment: .leading, spacing: 10) {
                if dailyMissionStates.isEmpty {
                    Text(localization.text("retention.noMission"))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(dailyMissionStates) { state in
                        AcademySectionSurface(padding: 14) {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(state.mission.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(state.mission.detail)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                if state.isCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppTheme.accentDark)
                                } else {
                                    Button(localization.text("retention.goToMission")) {
                                        missionNavTarget = state.mission
                                    }
                                    .buttonStyle(SolidGreenActionButtonStyle())
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var displayName: String {
        let trimmed = appState.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return localization.text("onboarding.defaultName")
        }
        return trimmed
    }

    private var displayInitial: String {
        let scalar = displayName.unicodeScalars.first
        return scalar.map { String($0).uppercased() } ?? "S"
    }

    private var profileAvatarButton: some View {
        Button {
            onProfileTapped()
        } label: {
            Circle()
                .fill(AppTheme.buttonGradient)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(displayInitial)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                )
        }
        .buttonStyle(.plain)
    }

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

    private func refreshDailyMissions() {
        dailyMissionStates = appState.currentDailyMissions()
    }

    private func autoCompleteMissions() {
        var changed = false
        for state in dailyMissionStates where !state.isCompleted {
            let achieved: Bool
            switch state.mission.kind {
            case .moduleQuiz:
                achieved = appState.progress.completedModuleIDs.contains(state.mission.targetID)
            case .challenge:
                achieved = appState.progress.completedChallengeIDs.contains(state.mission.targetID)
            case .tutorMastery:
                achieved = appState.progress.tutorMasteryStatusByLessonID[state.mission.targetID] != nil
            case .review:
                achieved = false
            }
            if achieved {
                appState.completeDailyMission(missionID: state.mission.id)
                changed = true
            }
        }
        if changed { refreshDailyMissions() }
    }

    @ViewBuilder
    private func missionDestinationView(for mission: DailyMission) -> some View {
        switch mission.kind {
        case .moduleQuiz:
            if let module = appState.modules.first(where: { $0.id == mission.targetID }) {
                ModuleDetailView(module: module)
            }
        case .challenge:
            if let challenge = appState.allChallenges.first(where: { $0.id == mission.targetID }) {
                ChallengeDetailView(challenge: challenge)
            }
        case .tutorMastery, .review:
            TutorPackageListView(titleKey: "home.popularAllTitle")
        }
    }
}

extension DailyMission: Identifiable {}
extension DailyMission: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DailyMission, rhs: DailyMission) -> Bool { lhs.id == rhs.id }
}
