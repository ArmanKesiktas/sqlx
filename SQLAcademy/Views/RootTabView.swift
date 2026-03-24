import SwiftUI
import UIKit

private enum RootTab: Hashable {
    case home
    case learn
    case career
    case challenges
    case profile

    static func initialValueFromEnvironment() -> RootTab {
        switch ProcessInfo.processInfo.environment["UITEST_INITIAL_TAB"]?.lowercased() {
        case "learn":
            return .learn
        case "career":
            return .career
        case "challenges":
            return .challenges
        case "profile":
            return .profile
        default:
            return .home
        }
    }
}

struct RootTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localization: LocalizationService
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: RootTab
    @State private var tabSwitchCount = 0

    init() {
        _selectedTab = State(initialValue: RootTab.initialValueFromEnvironment())
        Self.applyTabBarAppearance()
    }

    private static func applyTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor(AppTheme.tabBarBackground)
        appearance.shadowColor = .clear

        let normalAppearance = appearance.stackedLayoutAppearance.normal
        normalAppearance.iconColor = UIColor(AppTheme.textSecondary)
        normalAppearance.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.textSecondary)]

        let selectedAppearance = appearance.stackedLayoutAppearance.selected
        selectedAppearance.iconColor = UIColor(AppTheme.accentDark)
        selectedAppearance.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.accentDark)]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView {
                    selectedTab = .profile
                }
            }
            .tag(RootTab.home)
            .tabItem {
                Label(localization.text("tab.home"), systemImage: "house")
            }

            NavigationStack {
                LearnView()
            }
            .tag(RootTab.learn)
            .tabItem {
                Label(localization.text("tab.learn"), systemImage: "book")
            }

            NavigationStack {
                CareerPathListView()
            }
            .tag(RootTab.career)
            .tabItem {
                Label(localization.text("tab.career"), systemImage: "briefcase")
            }

            NavigationStack {
                ChallengesView()
            }
            .tag(RootTab.challenges)
            .tabItem {
                Label(localization.text("tab.challenges"), systemImage: "flag")
            }

            NavigationStack {
                ProfileView()
            }
            .tag(RootTab.profile)
            .tabItem {
                Label(localization.text("tab.profile"), systemImage: "line.3.horizontal")
            }
        }
        .tint(AppTheme.accent)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(AppTheme.tabBarBackground, for: .tabBar)
        .onAppear {
            Self.applyTabBarAppearance()
        }
        .onChange(of: colorScheme) { _, _ in
            Self.applyTabBarAppearance()
        }
        .onChange(of: localization.language) { _, _ in
            Self.applyTabBarAppearance()
        }
        .id(localization.language)
        .onChange(of: appState.routeRequest) { _, route in
            guard let route else { return }
            switch route {
            case .allPopularPackages:
                selectedTab = .home
            case .allTutorPackages, .examMode:
                selectedTab = .learn
            }
            appState.consumeRouteRequest()
        }
        .overlay(alignment: .top) {
            if let badge = appState.pendingBadgeNotification {
                BadgeToastView(badge: badge)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                appState.pendingBadgeNotification = nil
                            }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: appState.pendingBadgeNotification?.id)
        .environment(\.layoutDirection, localization.language.isRTL ? .rightToLeft : .leftToRight)
    }
}

// MARK: - Badge Toast

private struct BadgeToastView: View {
    @EnvironmentObject private var localization: LocalizationService
    let badge: Badge

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "star.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(localization.language == .tr ? "Başarım Kazanıldı!" : "Achievement Unlocked!")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                    .tracking(0.4)
                Text(localization.text(badge.titleKey))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.cardBackground)
                .shadow(color: Color.black.opacity(0.10), radius: 16, y: 6)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}
