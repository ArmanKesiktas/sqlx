import SwiftUI
import UIKit

private struct ThemePalette {
    let accent: UIColor
    let accentDark: UIColor
    let accentSoft: UIColor
    let secondaryAccent: UIColor
    let warm: UIColor
    let rose: UIColor
    let textPrimary: UIColor
    let textSecondary: UIColor
    let cardBackground: UIColor
    let elevatedCardBackground: UIColor
    let cardBorder: UIColor
    let buttonBorderLight: UIColor
    let solidButtonGreen: UIColor
    let tabBarBackground: UIColor
    let capsuleBackground: UIColor
    let pageGradientStart: UIColor
    let pageGradientMiddle: UIColor
    let pageGradientEnd: UIColor
    let ambientTopRight: UIColor
    let ambientTopLeft: UIColor
    let ambientBottomLeft: UIColor
    let inputBackground: UIColor
    let subtleSurface: UIColor
    let codeBlockBackground: UIColor
    let tableRowBackground: UIColor
    let drawerBackground: UIColor
    let floatingSurface: UIColor
    let success: UIColor
    let error: UIColor
    let warning: UIColor
    let hintBackground: UIColor
    let hintBorder: UIColor
    let hintLabel: UIColor
    let shadow: UIColor
    let pageBackground: UIColor
    let pageBackgroundTop: UIColor
}

enum AppTheme {
    private static let lightPalette = ThemePalette(
        accent: UIColor(red: 0.17, green: 0.67, blue: 0.35, alpha: 1),
        accentDark: UIColor(red: 0.10, green: 0.49, blue: 0.25, alpha: 1),
        accentSoft: UIColor(red: 0.72, green: 0.90, blue: 0.76, alpha: 1),
        secondaryAccent: UIColor(red: 0.96, green: 0.68, blue: 0.33, alpha: 1),
        warm: UIColor(red: 0.99, green: 0.84, blue: 0.58, alpha: 1),
        rose: UIColor(red: 0.91, green: 0.53, blue: 0.39, alpha: 1),
        textPrimary: UIColor(red: 0.07, green: 0.10, blue: 0.13, alpha: 1),
        textSecondary: UIColor(red: 0.34, green: 0.40, blue: 0.45, alpha: 1),
        cardBackground: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.94),
        elevatedCardBackground: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.97),
        cardBorder: UIColor(red: 0.72, green: 0.78, blue: 0.80, alpha: 0.62),
        buttonBorderLight: UIColor(red: 0.70, green: 0.89, blue: 0.73, alpha: 1),
        solidButtonGreen: UIColor(red: 0.23, green: 0.74, blue: 0.38, alpha: 1),
        tabBarBackground: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.96),
        capsuleBackground: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.52),
        pageGradientStart: UIColor(red: 0.92, green: 0.97, blue: 0.90, alpha: 1),
        pageGradientMiddle: UIColor(red: 0.98, green: 0.98, blue: 0.94, alpha: 1),
        pageGradientEnd: UIColor(red: 0.99, green: 0.95, blue: 0.86, alpha: 1),
        ambientTopRight: UIColor(red: 0.72, green: 0.90, blue: 0.76, alpha: 0.40),
        ambientTopLeft: UIColor(red: 0.96, green: 0.68, blue: 0.33, alpha: 0.22),
        ambientBottomLeft: UIColor(red: 0.99, green: 0.84, blue: 0.58, alpha: 0.20),
        inputBackground: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92),
        subtleSurface: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.72),
        codeBlockBackground: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.90),
        tableRowBackground: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.65),
        drawerBackground: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95),
        floatingSurface: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85),
        success: UIColor(red: 0.10, green: 0.49, blue: 0.25, alpha: 1),
        error: UIColor(red: 0.84, green: 0.30, blue: 0.28, alpha: 1),
        warning: UIColor(red: 0.76, green: 0.47, blue: 0.08, alpha: 1),
        hintBackground: UIColor(red: 1.0, green: 0.95, blue: 0.82, alpha: 1),
        hintBorder: UIColor(red: 0.76, green: 0.60, blue: 0.20, alpha: 0.60),
        hintLabel: UIColor(red: 0.56, green: 0.36, blue: 0.04, alpha: 1),
        shadow: UIColor.black.withAlphaComponent(0.06),
        pageBackground: UIColor(red: 0.96, green: 0.95, blue: 0.94, alpha: 1),
        pageBackgroundTop: UIColor(red: 0.86, green: 0.85, blue: 0.84, alpha: 1)
    )

    private static let darkPalette = ThemePalette(
        accent: UIColor(red: 0.27, green: 0.78, blue: 0.45, alpha: 1),
        accentDark: UIColor(red: 0.18, green: 0.60, blue: 0.35, alpha: 1),
        accentSoft: UIColor(red: 0.23, green: 0.34, blue: 0.27, alpha: 1),
        secondaryAccent: UIColor(red: 0.93, green: 0.67, blue: 0.34, alpha: 1),
        warm: UIColor(red: 0.70, green: 0.53, blue: 0.22, alpha: 1),
        rose: UIColor(red: 0.93, green: 0.47, blue: 0.42, alpha: 1),
        textPrimary: UIColor(red: 0.93, green: 0.95, blue: 0.92, alpha: 1),
        textSecondary: UIColor(red: 0.67, green: 0.72, blue: 0.68, alpha: 1),
        cardBackground: UIColor(red: 0.10, green: 0.13, blue: 0.11, alpha: 0.95),
        elevatedCardBackground: UIColor(red: 0.12, green: 0.16, blue: 0.14, alpha: 0.97),
        cardBorder: UIColor(red: 0.28, green: 0.33, blue: 0.31, alpha: 0.88),
        buttonBorderLight: UIColor(red: 0.38, green: 0.60, blue: 0.42, alpha: 1),
        solidButtonGreen: UIColor(red: 0.21, green: 0.72, blue: 0.39, alpha: 1),
        tabBarBackground: UIColor(red: 0.09, green: 0.11, blue: 0.10, alpha: 0.94),
        capsuleBackground: UIColor(red: 0.17, green: 0.20, blue: 0.18, alpha: 0.88),
        pageGradientStart: UIColor(red: 0.06, green: 0.08, blue: 0.07, alpha: 1),
        pageGradientMiddle: UIColor(red: 0.08, green: 0.10, blue: 0.09, alpha: 1),
        pageGradientEnd: UIColor(red: 0.11, green: 0.11, blue: 0.09, alpha: 1),
        ambientTopRight: UIColor(red: 0.18, green: 0.31, blue: 0.22, alpha: 0.55),
        ambientTopLeft: UIColor(red: 0.42, green: 0.27, blue: 0.11, alpha: 0.22),
        ambientBottomLeft: UIColor(red: 0.33, green: 0.24, blue: 0.12, alpha: 0.25),
        inputBackground: UIColor(red: 0.12, green: 0.15, blue: 0.14, alpha: 0.98),
        subtleSurface: UIColor(red: 0.15, green: 0.18, blue: 0.16, alpha: 0.88),
        codeBlockBackground: UIColor(red: 0.09, green: 0.11, blue: 0.10, alpha: 0.98),
        tableRowBackground: UIColor(red: 0.16, green: 0.19, blue: 0.18, alpha: 0.95),
        drawerBackground: UIColor(red: 0.11, green: 0.14, blue: 0.12, alpha: 0.97),
        floatingSurface: UIColor(red: 0.18, green: 0.21, blue: 0.19, alpha: 0.96),
        success: UIColor(red: 0.27, green: 0.78, blue: 0.45, alpha: 1),
        error: UIColor(red: 0.93, green: 0.47, blue: 0.42, alpha: 1),
        warning: UIColor(red: 0.93, green: 0.70, blue: 0.30, alpha: 1),
        hintBackground: UIColor(red: 0.22, green: 0.18, blue: 0.08, alpha: 1),
        hintBorder: UIColor(red: 0.55, green: 0.42, blue: 0.14, alpha: 0.70),
        hintLabel: UIColor(red: 0.93, green: 0.70, blue: 0.30, alpha: 1),
        shadow: UIColor.black.withAlphaComponent(0.26),
        pageBackground: UIColor(red: 0.14, green: 0.14, blue: 0.15, alpha: 1),
        pageBackgroundTop: UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
    )

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }

    private static func color(_ keyPath: KeyPath<ThemePalette, UIColor>) -> Color {
        dynamicColor(
            light: lightPalette[keyPath: keyPath],
            dark: darkPalette[keyPath: keyPath]
        )
    }

    static var accent: Color { color(\.accent) }
    static var accentDark: Color { color(\.accentDark) }
    static var accentSoft: Color { color(\.accentSoft) }
    static var secondaryAccent: Color { color(\.secondaryAccent) }
    static var warm: Color { color(\.warm) }
    static var rose: Color { color(\.rose) }
    static var textPrimary: Color { color(\.textPrimary) }
    static var textSecondary: Color { color(\.textSecondary) }
    static var cardBackground: Color { color(\.cardBackground) }
    static var elevatedCardBackground: Color { color(\.elevatedCardBackground) }
    static var cardBorder: Color { color(\.cardBorder) }
    static var buttonBorderLight: Color { color(\.buttonBorderLight) }
    static var solidButtonGreen: Color { color(\.solidButtonGreen) }
    static var tabBarBackground: Color { color(\.tabBarBackground) }
    static var capsuleBackground: Color { color(\.capsuleBackground) }
    static var inputBackground: Color { color(\.inputBackground) }
    static var subtleSurface: Color { color(\.subtleSurface) }
    static var codeBlockBackground: Color { color(\.codeBlockBackground) }
    static var tableRowBackground: Color { color(\.tableRowBackground) }
    static var drawerBackground: Color { color(\.drawerBackground) }
    static var floatingSurface: Color { color(\.floatingSurface) }
    static var success: Color { color(\.success) }
    static var error: Color { color(\.error) }
    static var warning: Color { color(\.warning) }
    static var hintBackground: Color { color(\.hintBackground) }
    static var hintBorder: Color { color(\.hintBorder) }
    static var hintLabel: Color { color(\.hintLabel) }
    static var cardShadow: Color { color(\.shadow) }
    static var pageBackground: Color { color(\.pageBackground) }
    static var pageBackgroundTop: Color { color(\.pageBackgroundTop) }
    static var ambientTopRight: Color { color(\.ambientTopRight) }
    static var ambientTopLeft: Color { color(\.ambientTopLeft) }
    static var ambientBottomLeft: Color { color(\.ambientBottomLeft) }

    /// Always-dark background for the SQL code editor (same in light & dark mode)
    static var codeEditorBackground: Color {
        Color(uiColor: UIColor(red: 0.11, green: 0.13, blue: 0.15, alpha: 1))
    }

    // SQL syntax highlighting colors (fixed — always on dark editor background)
    static let sqlKeyword = Color(red: 0.35, green: 0.65, blue: 1.0)
    static let sqlString = Color(red: 1.0, green: 0.65, blue: 0.3)
    static let sqlNumber = Color(red: 0.55, green: 0.85, blue: 0.55)
    static let sqlOperator = Color(red: 0.75, green: 0.55, blue: 0.85)
    static let sqlPlainText = Color(red: 0.85, green: 0.88, blue: 0.90)
    static let sqlLineNumber = Color(red: 0.40, green: 0.44, blue: 0.48)

    static var pageGradient: LinearGradient {
        LinearGradient(
            colors: [
                color(\.pageGradientStart),
                color(\.pageGradientMiddle),
                color(\.pageGradientEnd)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [accentDark, accent],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var buttonGradient: LinearGradient {
        LinearGradient(
            colors: [accentDark, accent],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var secondaryButtonGradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.85), accentSoft.opacity(0.92)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct AcademyBackground: View {
    var body: some View {
        LinearGradient(
            colors: [AppTheme.pageBackgroundTop, AppTheme.pageBackground],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct AcademyCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(AppTheme.textPrimary)
            .background(AppTheme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1.1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: AppTheme.cardShadow, radius: 20, x: 0, y: 8)
    }
}

struct AcademySectionSurface<Content: View>: View {
    let content: Content
    var padding: CGFloat

    init(padding: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(AppTheme.textPrimary)
            .background(AppTheme.subtleSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.cardBorder.opacity(0.72), lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct AcademySectionBlock<Content: View>: View {
    let title: String
    let symbol: String
    let content: Content

    init(title: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AcademySectionTitle(title: title, symbol: symbol)
            content
        }
    }
}

struct AcademySectionTitle: View {
    let title: String
    var symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(AppTheme.textSecondary)
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.0)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}

struct GradientActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(AppTheme.buttonGradient)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }
}

struct SecondaryGradientActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(AppTheme.secondaryButtonGradient)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.accentDark.opacity(0.22), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }
}

struct SolidGreenActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(AppTheme.solidButtonGreen)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.buttonBorderLight, lineWidth: 1.2)
            )
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }
}

extension View {
    func academyBackground() -> some View {
        background(AcademyBackground())
    }

    func academyTitleStyle() -> some View {
        self
            .font(.system(size: 26, weight: .semibold, design: .rounded))
            .foregroundStyle(AppTheme.textPrimary)
    }
}
