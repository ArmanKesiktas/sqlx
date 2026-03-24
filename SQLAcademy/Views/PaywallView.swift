import SwiftUI
import UIKit
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localization: LocalizationService
    @EnvironmentObject private var storeKit: StoreKitService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: PlusPlan = .yearly
    @State private var cardAppear = false
    @State private var ctaPulse = false
    @State private var showErrorAlert = false

    enum PlusPlan: String, CaseIterable {
        case monthly
        case yearly

        var productID: String {
            switch self {
            case .monthly: return "com.arman.sqlacademy.plus.monthly"
            case .yearly:  return "com.arman.sqlacademy.plus.yearly"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background — onboarding_bg_3 with black gradient fade
            Color.black.ignoresSafeArea()
            bgImage

            // Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer().frame(height: 50)

                    // Two floating Plus cards
                    cardsSection

                    // Brand + headline
                    headlineSection

                    // Privileges — text only
                    privilegesList

                    // Plan picker
                    planPicker

                    // Subscribe button (no icon)
                    subscribeButton

                    // Footer
                    restoreAndTerms

                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, 24)
            }

            // Dismiss
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding(.trailing, 20)
            .padding(.top, 16)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.35).delay(0.15)) {
                cardAppear = true
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                ctaPulse = true
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var bgImage: some View {
        if let uiImage = UIImage(named: "onboarding_bg_3") {
            GeometryReader { geo in
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .clear, location: 0.15),
                                .init(color: .black.opacity(0.6), location: 0.35),
                                .init(color: .black.opacity(0.92), location: 0.50),
                                .init(color: .black, location: 0.65)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Two Plus Cards (tilted)

    private var cardsSection: some View {
        ZStack {
            // Back card (left tilt)
            plusCard(
                icon: "infinity",
                title: localization.text("paywall.feature.unlimited"),
                subtitle: localization.text("paywall.feature.unlimited.sub")
            )
            .rotationEffect(.degrees(-6))
            .offset(x: -55, y: 12)
            .opacity(cardAppear ? 1 : 0)
            .offset(y: cardAppear ? 0 : 40)

            // Front card (right tilt)
            plusCard(
                icon: "brain.head.profile",
                title: localization.text("paywall.feature.aiCoach"),
                subtitle: localization.text("paywall.feature.aiCoach.sub")
            )
            .rotationEffect(.degrees(4))
            .offset(x: 50, y: -10)
            .opacity(cardAppear ? 1 : 0)
            .offset(y: cardAppear ? 0 : 60)
        }
        .frame(height: 200)
    }

    private func plusCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                BrandLogoView(.white, height: 12)
                Spacer()
                Text("Plus")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.92)))
            }

            Spacer()

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
        }
        .padding(16)
        .frame(width: 200, height: 140)
        .background(AppTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 10)
    }

    // MARK: - Headline

    private var headlineSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                BrandLogoView(.white, height: 20)
                Text("Plus")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)
            }

            Text(localization.text("paywall.headline"))
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(localization.text("paywall.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Privileges (text only)

    private var privilegesList: some View {
        VStack(alignment: .leading, spacing: 14) {
            privilegeRow(localization.text("paywall.feature.aiCoach"))
            privilegeRow(localization.text("paywall.feature.unlimited"))
            privilegeRow(localization.text("paywall.feature.certificates"))
            privilegeRow(localization.text("paywall.feature.futureContent"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    private func privilegeRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    // MARK: - Plan Picker

    private var planPicker: some View {
        HStack(spacing: 12) {
            planCard(plan: .monthly)
            planCard(plan: .yearly)
        }
    }

    private func planCard(plan: PlusPlan) -> some View {
        let isSelected = selectedPlan == plan
        let isYearly = plan == .yearly
        // Use real StoreKit price if available, else fall back to localized string
        let storeProduct = isYearly ? storeKit.yearlyProduct : storeKit.monthlyProduct
        let displayPrice = storeProduct?.displayPrice
            ?? (isYearly ? localization.text("paywall.yearly") : localization.text("paywall.monthly"))

        return Button {
            withAnimation(.spring(duration: 0.2)) { selectedPlan = plan }
        } label: {
            VStack(spacing: 6) {
                if isYearly {
                    Text(localization.text("paywall.yearly.saveBadge"))
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.13, green: 0.78, blue: 0.43))
                        .clipShape(Capsule())
                } else {
                    Spacer().frame(height: 22)
                }

                Text(isYearly
                     ? localization.text("paywall.yearlyLabel")
                     : localization.text("paywall.monthlyLabel"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))

                // Strikethrough old price (localization only — visual cue)
                Text(isYearly
                     ? localization.text("paywall.yearly.was")
                     : localization.text("paywall.monthly.was"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .strikethrough(true, color: .white.opacity(0.45))

                // Real price from StoreKit
                Text(displayPrice)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                if isYearly {
                    Text(localization.text("paywall.perDay"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    Spacer().frame(height: 14)
                }
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.18 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isSelected ? .white.opacity(0.5) : .white.opacity(0.12),
                        lineWidth: isSelected ? 2 : 0.8
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subscribe Button

    private var subscribeButton: some View {
        VStack(spacing: 8) {
            Button {
                Task { await performPurchase() }
            } label: {
                ZStack {
                    if storeKit.isPurchasing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.black)
                    } else {
                        Text(localization.text("paywall.subscribe"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.black)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(
                    color: .black.opacity(ctaPulse ? 0.35 : 0.15),
                    radius: ctaPulse ? 18 : 8,
                    x: 0,
                    y: ctaPulse ? 8 : 4
                )
                .scaleEffect(ctaPulse ? 1.015 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(storeKit.isPurchasing || storeKit.products.isEmpty)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: ctaPulse)

            Text(localization.text("paywall.cta.sub"))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .alert(localization.text("paywall.purchaseError"), isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { storeKit.purchaseError = nil }
        } message: {
            Text(storeKit.purchaseError ?? "")
        }
        .onChange(of: storeKit.purchaseError) { _, error in
            if error != nil { showErrorAlert = true }
        }
    }

    // MARK: - Footer

    private var restoreAndTerms: some View {
        VStack(spacing: 10) {
            Button(localization.text("paywall.restore")) {
                Task {
                    await storeKit.restorePurchases()
                    if storeKit.isSubscribed {
                        appState.activatePlus()
                        dismiss()
                    }
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.5))

            Text(localization.text("paywall.terms"))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Purchase Action

    private func performPurchase() async {
        let success = await storeKit.purchase(productID: selectedPlan.productID)
        if success {
            appState.activatePlus()
            dismiss()
        }
    }
}
