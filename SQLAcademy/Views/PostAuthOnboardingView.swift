import SwiftUI
import UIKit

struct PostAuthOnboardingView: View {
    private struct Slide: Identifiable {
        let id: Int
        let titleKey: String
        let descriptionKey: String
        let bgAssetName: String
    }

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localization: LocalizationService
    @Environment(\.colorScheme) private var colorScheme

    @State private var currentIndex = 0
    @State private var name = ""
    @State private var showPaywall = false

    private let slides: [Slide] = [
        Slide(id: 0, titleKey: "onboarding.title1", descriptionKey: "onboarding.desc1", bgAssetName: "onboarding_bg_1"),
        Slide(id: 1, titleKey: "onboarding.title2", descriptionKey: "onboarding.desc2", bgAssetName: "onboarding_bg_2"),
        Slide(id: 2, titleKey: "onboarding.title3", descriptionKey: "onboarding.desc3", bgAssetName: "onboarding_bg_3"),
        Slide(id: 3, titleKey: "onboarding.title4", descriptionKey: "onboarding.desc4", bgAssetName: "onboarding_bg_4")
    ]

    var body: some View {
        ZStack {
            if currentIndex < slides.count {
                AppTheme.accentDark.ignoresSafeArea()
                slideBgImage(assetName: slides[currentIndex].bgAssetName)
                slideStage(slides[currentIndex])
            } else {
                AcademyBackground()
                fadingBackground(assetName: "onboarding_bg_name")
                nameStage
            }
        }
        .onAppear {
            if name.isEmpty {
                name = appState.displayName
            }
        }
    }

    // MARK: - Background image — full screen, fades at bottom for text readability

    @ViewBuilder
    private func slideBgImage(assetName: String) -> some View {
        if let uiImage = UIImage(named: assetName) {
            GeometryReader { geo in
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width * 0.75, height: geo.size.height * 0.75)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.35),
                                .init(color: .black.opacity(0.6), location: 0.50),
                                .init(color: .black.opacity(0.2), location: 0.65),
                                .init(color: .clear, location: 0.80)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func fadingBackground(assetName: String) -> some View {
        if let uiImage = UIImage(named: assetName) {
            GeometryReader { geo in
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height * 0.65)
                    .clipped()
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.30),
                                .init(color: .black.opacity(0.15), location: 0.60),
                                .init(color: .clear, location: 0.75)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Slide Stage

    private func slideStage(_ slide: Slide) -> some View {
        GeometryReader { geo in
            let isCompact = geo.size.height < 700

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button(localization.text("onboarding.skip")) {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                            currentIndex = slides.count
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding.skip")
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                // Push text to lower half of screen
                Spacer()

                // Title + description — lower on screen, above the bg image
                VStack(spacing: 14) {
                    Text(localization.text(slide.titleKey))
                        .font(.system(size: isCompact ? 28 : 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)

                    Text(localization.text(slide.descriptionKey))
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)

                // Space between text and button
                Spacer()
                    .frame(minHeight: 28, maxHeight: geo.size.height * 0.08)

                // Full-width white CTA button
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                        currentIndex += 1
                    }
                } label: {
                    HStack {
                        Text(localization.text(
                            currentIndex == slides.count - 1
                                ? "onboarding.getStarted"
                                : "onboarding.continue"
                        ))
                        .font(.body.weight(.semibold))

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.body.weight(.bold))
                    }
                    .foregroundStyle(AppTheme.accentDark)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.15), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .accessibilityIdentifier("onboarding.next")

                // Pagination dots
                pageIndicator
                    .padding(.top, 16)
                    .padding(.bottom, isCompact ? 16 : 24)
            }
        }
    }

    // MARK: - Name Stage

    private var nameStage: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 20)

            BrandLogoView(colorScheme == .dark ? .white : .normal, height: 66)

            VStack(spacing: 10) {
                Text(localization.text("onboarding.nameTitle"))
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text(localization.text("onboarding.nameDescription"))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AcademySectionSurface(padding: 14) {
                TextField(localization.text("onboarding.namePlaceholder"), text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityIdentifier("onboarding.name")
            }

            Button(localization.text("onboarding.getStarted")) {
                appState.setDisplayName(name)
                showPaywall = true
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(GradientActionButtonStyle())
            .accessibilityIdentifier("onboarding.getStarted")
            .sheet(isPresented: $showPaywall, onDismiss: {
                appState.completeOnboarding(name: name)
            }) {
                PaywallView()
            }

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(slides.indices, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.3))
                    .frame(width: index == currentIndex ? 20 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: currentIndex)
            }
        }
    }
}
