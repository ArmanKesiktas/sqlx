import SwiftUI
import UIKit

enum BrandLogoVariant {
    case normal
    case black
    case white
    case green

    var assetName: String {
        switch self {
        case .normal:
            return "logo_normal"
        case .black:
            return "logo_black"
        case .white:
            return "logo_white"
        case .green:
            return "logo_green"
        }
    }
}

struct BrandLogoView: View {
    let variant: BrandLogoVariant
    let height: CGFloat

    init(_ variant: BrandLogoVariant, height: CGFloat = 24) {
        self.variant = variant
        self.height = height
    }

    var body: some View {
        if let image = UIImage(named: variant.assetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: height)
                .accessibilityHidden(true)
        } else {
            fallback
        }
    }

    @ViewBuilder
    private var fallback: some View {
        switch variant {
        case .normal:
            Text("SQLX")
                .font(.system(size: max(12, height * 0.6), weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
        case .black:
            Text("SQLX")
                .font(.system(size: max(12, height * 0.6), weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
        case .white:
            Text("SQLX")
                .font(.system(size: max(12, height * 0.6), weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        case .green:
            Text("SQLX")
                .font(.system(size: max(12, height * 0.6), weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.accentDark)
        }
    }
}
