import AuthenticationServices
import SwiftUI

struct AuthEntryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localization: LocalizationService
    @Environment(\.colorScheme) private var colorScheme

    @State private var helperText: String?

    var body: some View {
        ZStack {
            AcademyBackground()

            if let uiImage = UIImage(named: "auth_bg") {
                GeometryReader { geo in
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .mask(
                            LinearGradient(
                                colors: [.black, .black.opacity(0.7), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .ignoresSafeArea()
            }

            VStack(spacing: 20) {
                Spacer(minLength: 36)
                header
                appleSignInButton
                if let helperText {
                    Text(helperText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.rose)
                }
                Spacer(minLength: 36)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandLogoView(colorScheme == .dark ? .white : .normal, height: 72)

            Text(localization.text("auth.heroTitle"))
                .font(.system(size: 48, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineSpacing(-6)
                .minimumScaleFactor(0.75)

            Text(localization.text("auth.heroSubtitle"))
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var appleSignInButton: some View {
        SignInWithAppleButton(.continue) { request in
            request.requestedScopes = [.fullName]
        } onCompletion: { result in
            Task { @MainActor in
                let success = await appState.handleAppleSignIn(result: result)
                helperText = success ? nil : localization.text("auth.appleFailed")
            }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 54)
        .frame(maxWidth: .infinity)
        .clipShape(Capsule())
        .accessibilityIdentifier("auth.appleSignIn")
    }
}
