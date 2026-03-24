import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localization: LocalizationService

    @State private var showImportPicker = false
    @State private var backupStatusMessage = ""
    @State private var exportURL: URL?
    @State private var certificateURL: URL?
    @State private var selectedSummaryText = ""
    @State private var showSignOutConfirm = false
    @State private var showResetConfirm = false
@State private var selectedBadge: Badge? = nil

    var body: some View {
        ZStack {
            AcademyBackground()
            ScrollView {
                VStack(spacing: 14) {
                    Text(localization.text("profile.heroTitle"))
                        .academyTitleStyle()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    profileHeroCard
                    badgesSection
                    preferencesSection
                    backupSection
                    certificatesSection
                    dangerSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .padding(.bottom, 90)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first,
                      let data = try? Data(contentsOf: url) else {
                    backupStatusMessage = localization.text("profile.importFailed")
                    return
                }
                let imported = appState.importProgressJSON(data: data)
                backupStatusMessage = imported
                    ? localization.text("profile.importDone")
                    : localization.text("profile.importFailed")
            case .failure:
                backupStatusMessage = localization.text("profile.importFailed")
            }
        }
    }

    // MARK: - Profile Hero Card

    private var profileHeroCard: some View {
        AcademyCard {
            HStack(spacing: 14) {
                Circle()
                    .fill(AppTheme.buttonGradient)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(displayInitial)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.headline)
                    Text(appleStatus)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)

                    HStack(spacing: 12) {
                        Label("\(appState.progress.totalPoints)", systemImage: "star.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryAccent)
                        Label("\(appState.progress.streakDays)", systemImage: "flame.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.warm)
                        Label("\(appState.progress.completedModuleIDs.count)/\(appState.modules.count)", systemImage: "book.closed.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.accentDark)
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    Button(localization.text("profile.signOut")) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showSignOutConfirm.toggle()
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.rose)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.rose.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.rose.opacity(0.25), lineWidth: 1))

                    if showSignOutConfirm {
                        HStack(spacing: 6) {
                            Button(localization.text("profile.cancel")) {
                                withAnimation { showSignOutConfirm = false }
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(AppTheme.capsuleBackground)
                            .clipShape(Capsule())

                            Button(localization.text("profile.signOut")) {
                                appState.signOut()
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(AppTheme.rose)
                            .clipShape(Capsule())
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)))
                    }
                }
            }
        }
    }

    // MARK: - Preferences (combined)

    private var preferencesSection: some View {
        AcademySectionBlock(title: localization.text("profile.preferences"), symbol: "gearshape") {
            AcademySectionSurface(padding: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localization.text("profile.language"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Menu {
                            ForEach(AppLanguage.allCases) { lang in
                                Button {
                                    localization.language = lang
                                } label: {
                                    if localization.language == lang {
                                        Label(lang.flag + " " + lang.displayName, systemImage: "checkmark")
                                    } else {
                                        Text(lang.flag + " " + lang.displayName)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(localization.language.flag)
                                    .font(.body)
                                Text(localization.language.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text(localization.text("profile.appearance"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Picker(localization.text("profile.appearance"), selection: appearanceBinding) {
                            Text(localization.text("profile.appearance.system")).tag(AppAppearanceMode.system)
                            Text(localization.text("profile.appearance.light")).tag(AppAppearanceMode.light)
                            Text(localization.text("profile.appearance.dark")).tag(AppAppearanceMode.dark)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
    }

    // MARK: - Badges

    private var badgesSection: some View {
        AcademySectionBlock(title: localization.text("home.badges"), symbol: "sparkles") {
            GeometryReader { geo in
                let cellWidth = (geo.size.width - 20) / 3
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(appState.badges) { badge in
                            let isEarned = appState.progress.badgeIDs.contains(badge.id)
                            Button {
                                selectedBadge = badge
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(isEarned ? badgeColor(badge.rule).opacity(0.18) : Color.gray.opacity(0.1))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: badgeIcon(badge.rule))
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(isEarned ? badgeColor(badge.rule) : Color.gray.opacity(0.35))
                                    }
                                    Text(localization.text(badge.titleKey))
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(isEarned ? AppTheme.textPrimary : AppTheme.textSecondary.opacity(0.4))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .frame(width: cellWidth, height: 88)
                                .background(isEarned ? badgeColor(badge.rule).opacity(0.06) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(isEarned ? badgeColor(badge.rule).opacity(0.22) : Color.gray.opacity(0.1), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(height: 92)
        }
        .sheet(item: $selectedBadge) { badge in
            badgeDetailSheet(badge)
        }
    }


    private func badgeDetailSheet(_ badge: Badge) -> some View {
        let isEarned = appState.progress.badgeIDs.contains(badge.id)
        return VStack(spacing: 20) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            ZStack {
                Circle()
                    .fill(isEarned ? badgeColor(badge.rule).opacity(0.18) : Color.gray.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: badgeIcon(badge.rule))
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(isEarned ? badgeColor(badge.rule) : Color.gray.opacity(0.4))
            }

            VStack(spacing: 6) {
                Text(localization.text(badge.titleKey))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(localization.text(badge.descriptionKey))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if isEarned {
                Label(localization.language == .tr ? "Kazanıldı!" : "Earned!", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(AppTheme.accent.opacity(0.12))
                    .clipShape(Capsule())
            } else {
                Text(localization.language == .tr ? "Henüz kazanılmadı" : "Not yet earned")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.hidden)
        .background(AppTheme.cardBackground)
    }

    private func badgeIcon(_ rule: BadgeRule) -> String {
        switch rule {
        case .firstChallenge, .fiveChallenges, .tenChallenges, .twentyChallenges:
            return "bolt.fill"
        case .firstModule, .threeModules, .allModules:
            return "book.closed.fill"
        case .sevenDayStreak, .fourteenDayStreak, .thirtyDayStreak:
            return "flame.fill"
        case .fiveHundredPoints, .thousandPoints, .twoThousandPoints:
            return "star.fill"
        case .firstTutorLesson:
            return "brain.head.profile"
        case .firstExam:
            return "checkmark.seal.fill"
        }
    }

    private func badgeColor(_ rule: BadgeRule) -> Color {
        switch rule {
        case .firstChallenge, .fiveChallenges, .tenChallenges, .twentyChallenges:
            return AppTheme.accent
        case .firstModule, .threeModules, .allModules:
            return AppTheme.accentDark
        case .sevenDayStreak, .fourteenDayStreak, .thirtyDayStreak:
            return AppTheme.warm
        case .fiveHundredPoints, .thousandPoints, .twoThousandPoints:
            return AppTheme.secondaryAccent
        case .firstTutorLesson:
            return AppTheme.accentDark
        case .firstExam:
            return AppTheme.accent
        }
    }

    // MARK: - Backup

    private var backupSection: some View {
        AcademySectionBlock(title: localization.text("profile.backup"), symbol: "icloud") {
            VStack(spacing: 8) {
                backupActionRow(
                    title: localization.text("profile.syncICloud"),
                    subtitle: localization.text("profile.syncHint"),
                    icon: "icloud.and.arrow.up"
                ) {
                    appState.syncProgressToICloud()
                    backupStatusMessage = localization.text("profile.syncDone")
                }

                backupActionRow(
                    title: localization.text("profile.restoreICloud"),
                    subtitle: localization.text("profile.restoreHint"),
                    icon: "arrow.clockwise.icloud"
                ) {
                    let restored = appState.restoreProgressFromICloud()
                    backupStatusMessage = restored
                    ? localization.text("profile.restoreDone")
                    : localization.text("profile.restoreMissing")
                }

                backupActionRow(
                    title: localization.text("profile.exportJSON"),
                    subtitle: localization.text("profile.exportHint"),
                    icon: "square.and.arrow.up"
                ) {
                    exportURL = appState.exportProgressJSONFileURL()
                    if exportURL == nil {
                        backupStatusMessage = localization.text("profile.exportFailed")
                    }
                }

                backupActionRow(
                    title: localization.text("profile.importJSON"),
                    subtitle: localization.text("profile.importHint"),
                    icon: "square.and.arrow.down"
                ) {
                    showImportPicker = true
                }
            }

            if let exportURL {
                ShareLink(item: exportURL) {
                    Label(localization.text("profile.shareExport"), systemImage: "square.and.arrow.up.on.square")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(GradientActionButtonStyle())
            }

            if !backupStatusMessage.isEmpty {
                Text(backupStatusMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Certificates

    private var certificatesSection: some View {
        AcademySectionBlock(title: localization.text("profile.certificates"), symbol: "doc.badge") {
            if appState.progress.certificateRecords.isEmpty {
                Text(localization.text("profile.noCertificates"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(appState.progress.certificateRecords) { record in
                        AcademySectionSurface(padding: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(record.subtitle)
                                    .font(.subheadline.weight(.semibold))
                                Text("Score: \(record.masteryScore)%")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                HStack {
                                    Button(localization.text("profile.exportCertificate")) {
                                        certificateURL = appState.exportCertificatePDF(recordID: record.id)
                                    }
                                    .buttonStyle(SolidGreenActionButtonStyle())

                                    Button(localization.text("profile.projectSummary")) {
                                        selectedSummaryText = appState.projectSummaryText(recordID: record.id) ?? ""
                                    }
                                    .buttonStyle(SolidGreenActionButtonStyle())
                                }
                                if let certificateURL {
                                    ShareLink(item: certificateURL) {
                                        Text(localization.text("profile.shareCertificate"))
                                    }
                                    .buttonStyle(GradientActionButtonStyle())
                                }
                                if !selectedSummaryText.isEmpty {
                                    Text(selectedSummaryText)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .padding(8)
                                        .background(AppTheme.codeBlockBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerSection: some View {
        AcademySectionBlock(title: localization.text("profile.danger"), symbol: "exclamationmark.triangle") {
            VStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showResetConfirm.toggle()
                    }
                } label: {
                    Text(localization.text("profile.resetProgress"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(AppTheme.rose)
                        .clipShape(Capsule())
                }
                .accessibilityIdentifier("profile.reset")

                if showResetConfirm {
                    VStack(spacing: 8) {
                        Text(localization.language == .tr
                             ? "Tüm ilerleme, rozetler ve sertifikalar silinecek. Bu işlem geri alınamaz."
                             : "All progress, badges and certificates will be deleted. This cannot be undone.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.rose)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 10) {
                            Button(localization.text("profile.cancel")) {
                                withAnimation { showResetConfirm = false }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(AppTheme.capsuleBackground)
                            .clipShape(Capsule())

                            Button(localization.text("profile.resetProgress")) {
                                appState.resetProgress()
                                showResetConfirm = false
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(AppTheme.rose)
                            .clipShape(Capsule())
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
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

    private var appleStatus: String {
        appState.progress.isAppleSignedIn
        ? localization.text("profile.appleConnected")
        : localization.text("profile.appleNotConnected")
    }

    private var appearanceBinding: Binding<AppAppearanceMode> {
        Binding(
            get: { appState.appearanceMode },
            set: { appState.setAppearanceMode($0) }
        )
    }

    private func backupActionRow(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentSoft.opacity(0.45))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accentDark)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(AppTheme.accentSoft.opacity(0.16))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.buttonBorderLight.opacity(0.9), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
