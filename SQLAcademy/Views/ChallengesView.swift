import SwiftUI

struct ChallengesView: View {
    private enum ChallengeFilter: String, CaseIterable, Identifiable {
        case all
        case beginner
        case intermediate
        case advanced
        case completed
        case pending

        var id: String { rawValue }
    }

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localization: LocalizationService
    @State private var searchText = ""
    @State private var selectedFilter: ChallengeFilter = .all
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        ZStack {
            AcademyBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(localization.text("challenges.heroTitle"))
                        .academyTitleStyle()

                    AcademySectionTitle(title: localization.text("tab.challenges"), symbol: "flag")
                    searchBar
                    filterBar

                    if filteredChallenges.isEmpty {
                        AcademyCard {
                            Text(localization.text("challenges.empty"))
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredChallenges) { challenge in
                                NavigationLink {
                                    ChallengeDetailView(challenge: challenge)
                                } label: {
                                    let isDone = appState.progress.completedChallengeIDs.contains(challenge.id)
                                    let isBonus = challenge.id.hasPrefix("bonus_")

                                    HStack(spacing: 14) {
                                        // Status indicator
                                        ZStack {
                                            Circle()
                                                .fill(isDone ? AppTheme.accent.opacity(0.18) : AppTheme.cardBorder.opacity(0.3))
                                                .frame(width: 40, height: 40)
                                            Image(systemName: isDone ? "checkmark" : "terminal")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(isDone ? AppTheme.accentDark : AppTheme.textSecondary)
                                        }

                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(localization.text(challenge.titleKey))
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppTheme.textPrimary)
                                                .lineLimit(1)

                                            Text(localization.text(challenge.promptKey))
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.textSecondary)
                                                .lineLimit(1)

                                            HStack(spacing: 6) {
                                                if isBonus {
                                                    Text(localization.text("challenges.bonus"))
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundStyle(AppTheme.accent)
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 3)
                                                        .background(AppTheme.accent.opacity(0.12))
                                                        .clipShape(Capsule())
                                                }
                                                Text("+\(challenge.points) XP")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(AppTheme.secondaryAccent)
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 3)
                                                    .background(AppTheme.secondaryAccent.opacity(0.12))
                                                    .clipShape(Capsule())
                                            }
                                        }

                                        Spacer(minLength: 0)

                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(isDone ? AppTheme.accent.opacity(0.06) : AppTheme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(isDone ? AppTheme.accent.opacity(0.25) : AppTheme.cardBorder, lineWidth: 1.1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.textSecondary)
            TextField(localization.text("challenges.searchPlaceholder"), text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .focused($isSearchFieldFocused)
                .accessibilityIdentifier("challenges.search")
                .accessibilityLabel("challenges.search")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.inputBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                isSearchFieldFocused = true
            }
        )
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ChallengeFilter.allCases) { filter in
                    Button(localizedFilterTitle(filter)) {
                        selectedFilter = filter
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selectedFilter == filter ? .white : AppTheme.accentDark)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(selectedFilter == filter ? AppTheme.solidButtonGreen : AppTheme.capsuleBackground)
                    )
                    .overlay(
                        Capsule()
                            .stroke(selectedFilter == filter ? AppTheme.buttonBorderLight : AppTheme.cardBorder, lineWidth: 1.1)
                    )
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("challenges.filter.\(filter.rawValue)")
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var filteredChallenges: [SQLChallenge] {
        let moduleLevels = Dictionary(uniqueKeysWithValues: appState.modules.map { ($0.id, $0.level) })
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return appState.allChallenges.filter { challenge in
            let matchesFilter: Bool = {
                switch selectedFilter {
                case .all:
                    return true
                case .beginner:
                    return moduleLevels[challenge.moduleID] == .beginner
                case .intermediate:
                    return moduleLevels[challenge.moduleID] == .intermediate
                case .advanced:
                    return moduleLevels[challenge.moduleID] == .advanced
                case .completed:
                    return appState.progress.completedChallengeIDs.contains(challenge.id)
                case .pending:
                    return !appState.progress.completedChallengeIDs.contains(challenge.id)
                }
            }()

            guard matchesFilter else { return false }
            guard !normalizedSearch.isEmpty else { return true }

            let searchable = [
                challenge.id.lowercased(),
                localization.text(challenge.titleKey).lowercased(),
                localization.text(challenge.promptKey).lowercased(),
                localization.text(challenge.hintKey).lowercased()
            ]
            return searchable.contains { $0.contains(normalizedSearch) }
        }
    }

    private func localizedFilterTitle(_ filter: ChallengeFilter) -> String {
        switch filter {
        case .all:
            return localization.text("challenges.filter.all")
        case .beginner:
            return localization.text("challenges.filter.beginner")
        case .intermediate:
            return localization.text("challenges.filter.intermediate")
        case .advanced:
            return localization.text("challenges.filter.advanced")
        case .completed:
            return localization.text("challenges.filter.completed")
        case .pending:
            return localization.text("challenges.filter.pending")
        }
    }
}
