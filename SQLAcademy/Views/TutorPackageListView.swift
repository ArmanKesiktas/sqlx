import SwiftUI

struct TutorPackageListView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localization: LocalizationService

    let titleKey: String

    var body: some View {
        ZStack {
            AcademyBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(localization.text(titleKey))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineSpacing(-6)

                    ForEach(appState.tutorPackages) { package in
                        NavigationLink {
                        TutorView(
                            package: package,
                                localization: localization,
                                packageProgress: {
                                    appState.tutorPackageProgress(packageID: package.id)
                                },
                                isLessonCompleted: { interestID in
                                    appState.isTutorLessonCompleted(packageID: package.id, interestID: interestID)
                                },
                                storedProfession: appState.tutorProfession(packageID: package.id),
                                initialSceneIndex: appState.resumeTutorPackage(packageID: package.id),
                                competency: appState.tutorCompetency(packageID: package.id),
                                isLabSceneCompleted: { sceneID in
                                    appState.isTutorLabSceneCompleted(sceneID: sceneID)
                                },
                                onStartPackage: {
                                    appState.startTutorPackage(package.id)
                                },
                                onRestartPackage: { sceneIDs in
                                    appState.restartTutorPackage(packageID: package.id, sceneIDs: sceneIDs)
                                },
                                onSaveSceneProgress: { sceneIndex, sceneID in
                                    appState.saveTutorSceneProgress(packageID: package.id, sceneIndex: sceneIndex, sceneID: sceneID)
                                },
                                onMarkLabSceneCompleted: { sceneID in
                                    appState.markTutorLabSceneCompleted(sceneID: sceneID)
                                },
                                onApprove: { points in
                                    appState.addPoints(points)
                                },
                                onProfessionSaved: { profession in
                                    appState.setTutorProfession(packageID: package.id, profession: profession)
                                },
                                onLessonCompleted: { interestID, evidenceSQL, masteryScore in
                                    appState.completeTutorLesson(
                                        packageID: package.id,
                                        interestID: interestID,
                                        masteryScore: masteryScore,
                                        evidenceSQL: evidenceSQL
                                    )
                                },
                                onMasteryStarted: { interestID in
                                    appState.startTutorMastery(packageID: package.id, interestID: interestID)
                                },
                                onMiniTaskEvaluated: { interestID, isCorrect in
                                    appState.submitTutorMiniTask(packageID: package.id, interestID: interestID, isCorrect: isCorrect)
                                },
                                onMiniChallengeEvaluated: { interestID, isCorrect in
                                    appState.submitTutorMiniChallenge(packageID: package.id, interestID: interestID, isCorrect: isCorrect)
                                },
                                onCompetencyUpdated: { competency in
                                    appState.updateTutorCompetency(packageID: package.id, competency: competency)
                                }
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label(localization.text(package.titleKey), systemImage: package.icon)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("\(Int(appState.tutorPackageProgress(packageID: package.id) * 100))%")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.white.opacity(0.86))
                                }
                                Text(localization.text(package.descriptionKey))
                                    .font(.subheadline)
                                    .foregroundStyle(Color.white.opacity(0.9))
                                    .lineLimit(3)
                                ProgressView(value: appState.tutorPackageProgress(packageID: package.id))
                                    .tint(Color.white.opacity(0.94))
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.heroGradient)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(AppTheme.buttonBorderLight.opacity(0.9), lineWidth: 1.2)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: AppTheme.accentDark.opacity(0.18), radius: 14, x: 0, y: 8)
                        }
                        .accessibilityIdentifier("tutor.package.\(package.id)")
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
