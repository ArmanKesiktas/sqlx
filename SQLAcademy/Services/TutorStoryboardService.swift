import Foundation

struct TutorStoryboardService {
    private let localization: LocalizationService

    init(localization: LocalizationService) {
        self.localization = localization
    }

    func storyboard(for package: TutorPackage) -> TutorPackageStoryboard {
        let sceneList = package.interests.enumerated().flatMap { index, interest in
            lessonScenes(for: interest, lessonNumber: index + 1)
        }
        return TutorPackageStoryboard(packageID: package.id, scenes: sceneList)
    }

    private func lessonScenes(for interest: TutorInterest, lessonNumber: Int) -> [TutorScene] {
        let lessonTitle = localization.text(interest.titleKey)
        let objective = interest.descriptionKey.map(localization.text) ?? lessonTitle
        let lessonPrefix = localized(
            tr: "Ders \(lessonNumber)",
            en: "Lesson \(lessonNumber)"
        )

        return [
            TutorScene(
                id: "\(interest.id)_intro",
                interestID: interest.id,
                interestIndex: lessonNumber - 1,
                kind: .introText,
                stepTitle: "\(lessonPrefix) • \(lessonTitle)",
                objective: objective,
                ctas: [nextCTA()],
                autoOpenDrawer: lessonNumber == 1,
                requiresSuccessfulLabRun: false,
                masteryIndex: nil
            ),
            TutorScene(
                id: "\(interest.id)_concept",
                interestID: interest.id,
                interestIndex: lessonNumber - 1,
                kind: .conceptCard,
                stepTitle: localized(tr: "Mantik cizgisi", en: "Logic line"),
                objective: objective,
                ctas: [nextCTA()],
                autoOpenDrawer: true,
                requiresSuccessfulLabRun: false,
                masteryIndex: nil
            ),
            TutorScene(
                id: "\(interest.id)_checkin",
                interestID: interest.id,
                interestIndex: lessonNumber - 1,
                kind: .checkIn,
                stepTitle: localized(tr: "Hızlı kontrol", en: "Quick check-in"),
                objective: objective,
                ctas: [
                    TutorSceneCTA(id: "affirm", title: localized(tr: "Anladım", en: "I got it"), role: .affirm, requiresSuccessfulLabRun: false),
                    TutorSceneCTA(id: "explain_again", title: localized(tr: "Yeniden açıkla", en: "Explain again"), role: .explainAgain, requiresSuccessfulLabRun: false)
                ],
                autoOpenDrawer: false,
                requiresSuccessfulLabRun: false,
                masteryIndex: nil
            ),
            TutorScene(
                id: "\(interest.id)_scenario",
                interestID: interest.id,
                interestIndex: lessonNumber - 1,
                kind: .exampleScenario,
                stepTitle: localized(tr: "Saha brifi", en: "Field brief"),
                objective: objective,
                ctas: [nextCTA()],
                autoOpenDrawer: true,
                requiresSuccessfulLabRun: false,
                masteryIndex: nil
            ),
            TutorScene(
                id: "\(interest.id)_demo",
                interestID: interest.id,
                interestIndex: lessonNumber - 1,
                kind: .miniLabDemo,
                stepTitle: localized(tr: "Sorgu plani", en: "Query blueprint"),
                objective: objective,
                ctas: [tryLabCTA()],
                autoOpenDrawer: true,
                requiresSuccessfulLabRun: false,
                masteryIndex: nil
            ),
            TutorScene(
                id: "\(interest.id)_lab",
                interestID: interest.id,
                interestIndex: lessonNumber - 1,
                kind: .miniLabTry,
                stepTitle: localized(tr: "Canli prova", en: "Live drill"),
                objective: objective,
                ctas: [continueCTA(requiresLabRun: true)],
                autoOpenDrawer: true,
                requiresSuccessfulLabRun: true,
                masteryIndex: nil
            ),
            TutorScene(
                id: "\(interest.id)_output",
                interestID: interest.id,
                interestIndex: lessonNumber - 1,
                kind: .outputExplain,
                stepTitle: localized(tr: "Sonuc okuma", en: "Result readout"),
                objective: objective,
                ctas: [nextCTA()],
                autoOpenDrawer: true,
                requiresSuccessfulLabRun: false,
                masteryIndex: nil
            ),
            TutorScene(
                id: "\(interest.id)_mastery_1",
                interestID: interest.id,
                interestIndex: lessonNumber - 1,
                kind: .masteryMiniQuestion,
                stepTitle: localized(tr: "Mastery 1/3", en: "Mastery 1/3"),
                objective: objective,
                ctas: [],
                autoOpenDrawer: false,
                requiresSuccessfulLabRun: false,
                masteryIndex: 1
            ),
            TutorScene(
                id: "\(interest.id)_mastery_2",
                interestID: interest.id,
                interestIndex: lessonNumber - 1,
                kind: .masteryMiniQuestion,
                stepTitle: localized(tr: "Mastery 2/3", en: "Mastery 2/3"),
                objective: objective,
                ctas: [],
                autoOpenDrawer: false,
                requiresSuccessfulLabRun: false,
                masteryIndex: 2
            ),
            TutorScene(
                id: "\(interest.id)_mastery_challenge",
                interestID: interest.id,
                interestIndex: lessonNumber - 1,
                kind: .masteryChallenge,
                stepTitle: localized(tr: "Mastery 3/3", en: "Mastery 3/3"),
                objective: objective,
                ctas: [],
                autoOpenDrawer: true,
                requiresSuccessfulLabRun: false,
                masteryIndex: nil
            ),
            TutorScene(
                id: "\(interest.id)_wrap",
                interestID: interest.id,
                interestIndex: lessonNumber - 1,
                kind: .lessonWrapUp,
                stepTitle: localized(tr: "Kalin desen", en: "Pattern carry"),
                objective: objective,
                ctas: [continueCTA(requiresLabRun: false)],
                autoOpenDrawer: true,
                requiresSuccessfulLabRun: false,
                masteryIndex: nil
            )
        ]
    }

    private func nextCTA() -> TutorSceneCTA {
        TutorSceneCTA(
            id: UUID().uuidString,
            title: localized(tr: "Devam et", en: "Continue"),
            role: .next,
            requiresSuccessfulLabRun: false
        )
    }

    private func tryLabCTA() -> TutorSceneCTA {
        TutorSceneCTA(
            id: UUID().uuidString,
            title: localized(tr: "Dene", en: "Try it"),
            role: .tryLab,
            requiresSuccessfulLabRun: false
        )
    }

    private func continueCTA(requiresLabRun: Bool) -> TutorSceneCTA {
        TutorSceneCTA(
            id: UUID().uuidString,
            title: localized(tr: "Hazırım", en: "I am ready"),
            role: .continueJourney,
            requiresSuccessfulLabRun: requiresLabRun
        )
    }

    private func localized(tr: String, en: String) -> String {
        localization.language == .tr ? tr : en
    }
}
