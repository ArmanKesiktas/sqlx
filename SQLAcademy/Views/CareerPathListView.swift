import SwiftUI

struct CareerPathListView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localization: LocalizationService

    private var isTR: Bool { localization.language == .tr }

    var body: some View {
        ZStack {
            AcademyBackground()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 6) {
                        Text(isTR ? "Kariyer Yolunu Sec" : "Choose Your Career Path")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(isTR ? "SQL'i bir amacla ogren. Hedefine uygun yolu sec." : "Learn SQL with purpose. Pick the path that fits your goal.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 8)

                    // Career cards
                    ForEach(appState.careerPaths) { path in
                        NavigationLink {
                            CareerPathDetailView(careerPath: path)
                        } label: {
                            CareerPathCard(path: path)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(localization.text("tab.career"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Career Path Card

private struct CareerPathCard: View {
    let path: CareerPath
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localization: LocalizationService

    private var isTR: Bool { localization.language == .tr }

    private var completedCount: Int {
        path.moduleIDs.filter { appState.progress.completedModuleIDs.contains($0) }.count
    }

    private var totalCount: Int { path.moduleIDs.count }

    private var progress: Double {
        totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
    }

    private var isComplete: Bool { completedCount == totalCount && totalCount > 0 }

    private var difficultyColor: Color {
        switch path.difficulty {
        case .beginner: return AppTheme.accent
        case .intermediate: return AppTheme.secondaryAccent
        case .advanced: return AppTheme.rose
        }
    }

    private var difficultyText: String {
        switch path.difficulty {
        case .beginner: return isTR ? "Baslangic" : "Beginner"
        case .intermediate: return isTR ? "Orta" : "Intermediate"
        case .advanced: return isTR ? "Ileri" : "Advanced"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isComplete ? AppTheme.accent.opacity(0.15) : AppTheme.accent.opacity(0.08))
                        .frame(width: 50, height: 50)
                    Image(systemName: path.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(isComplete ? AppTheme.accent : AppTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(localization.text(path.titleKey))
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    Text(localization.text(path.descriptionKey))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
            }

            // Badges row
            HStack(spacing: 8) {
                // Difficulty badge
                Text(difficultyText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(difficultyColor, in: Capsule())

                // Module count
                Label("\(totalCount) \(isTR ? "modul" : "modules")", systemImage: "book")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                // Duration
                Label("\(path.estimatedHours) \(isTR ? "saat" : "hrs")", systemImage: "clock")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                if isComplete {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(AppTheme.accent)
                        .font(.system(size: 16))
                }
            }

            // Progress bar
            if completedCount > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(completedCount)/\(totalCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isComplete ? AppTheme.accent : AppTheme.textSecondary)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isComplete ? AppTheme.accent : AppTheme.textSecondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppTheme.cardBorder.opacity(0.3))
                                .frame(height: 6)
                            Capsule()
                                .fill(isComplete ? AppTheme.accent : AppTheme.secondaryAccent)
                                .frame(width: geo.size.width * progress, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground.opacity(isComplete ? 0.95 : 0.85))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isComplete ? AppTheme.accent.opacity(0.3) : AppTheme.cardBorder.opacity(0.5), lineWidth: 1)
        )
    }
}
