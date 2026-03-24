import SwiftUI

private struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var glowOpacity: Double = 0

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.08, blue: 0.07)
                .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.18, green: 0.60, blue: 0.35).opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 30)
                .opacity(glowOpacity)

            VStack(spacing: 16) {
                BrandLogoView(.white, height: 52)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                Text("Learn SQL, Naturally.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .tracking(0.5)
                    .opacity(taglineOpacity)
            }
        }
        .onAppear { animate() }
    }

    private func animate() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
            logoScale = 1.0
            logoOpacity = 1.0
            glowOpacity = 1.0
        }
        withAnimation(.easeIn(duration: 0.4).delay(0.3)) {
            taglineOpacity = 1.0
        }
        withAnimation(.easeIn(duration: 0.35).delay(1.4)) {
            logoOpacity = 0
            taglineOpacity = 0
            glowOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            onComplete()
        }
    }
}

@main
struct SQLAcademyApp: App {
    @StateObject private var appState = AppState()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if appState.progress.hasCompletedOnboarding {
                        RootTabView()
                    } else if appState.progress.isAppleSignedIn {
                        PostAuthOnboardingView()
                    } else {
                        AuthEntryView()
                    }
                }
                .environmentObject(appState)
                .environmentObject(appState.localization)
                .environmentObject(appState.storeKitService)
                .fontDesign(.rounded)
                .preferredColorScheme(appState.resolvedPreferredColorScheme)
                .task {
                    await appState.refreshAppleCredentialState()
                    await appState.syncSubscriptionStatus()
                }

                if showSplash {
                    SplashScreenView {
                        showSplash = false
                    }
                    .zIndex(1)
                }
            }
        }
    }
}
