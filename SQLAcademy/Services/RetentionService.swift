import Foundation

final class RetentionService {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func todayKey(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: now)
    }

    func currentDailyMissions(
        progress: inout UserProgress,
        modules: [LearningModule],
        challenges: [SQLChallenge],
        packages: [TutorPackage],
        localize: (String) -> String,
        now: Date = Date()
    ) -> [DailyMissionState] {
        let key = todayKey(now: now)
        if let existing = progress.dailyMissionStateByDate[key] {
            return existing
        }

        var states: [DailyMissionState] = []

        if let module = modules.first(where: { !progress.completedModuleIDs.contains($0.id) }) ?? modules.first {
            let mission = DailyMission(
                id: "mission_module_\(key)_\(module.id)",
                kind: .moduleQuiz,
                targetID: module.id,
                title: localize("retention.mission.module.title"),
                detail: localize(module.titleKey),
                points: 20
            )
            states.append(DailyMissionState(mission: mission, isCompleted: false, completedAt: nil))
        }

        if let challenge = challenges.first(where: { !progress.completedChallengeIDs.contains($0.id) }) ?? challenges.first {
            let mission = DailyMission(
                id: "mission_challenge_\(key)_\(challenge.id)",
                kind: .challenge,
                targetID: challenge.id,
                title: localize("retention.mission.challenge.title"),
                detail: localize(challenge.titleKey),
                points: 25
            )
            states.append(DailyMissionState(mission: mission, isCompleted: false, completedAt: nil))
        }

        let dueReview = dueReviewItems(progress: progress, now: now).first
        if let dueReview {
            let mission = DailyMission(
                id: "mission_review_\(key)_\(dueReview.id)",
                kind: .review,
                targetID: dueReview.topicID,
                title: localize("retention.mission.review.title"),
                detail: dueReview.topicID,
                points: 20
            )
            states.append(DailyMissionState(mission: mission, isCompleted: false, completedAt: nil))
        } else if let package = packages.first {
            let lessonID = package.interests.first?.id ?? "lesson"
            let mission = DailyMission(
                id: "mission_tutor_\(key)_\(package.id)_\(lessonID)",
                kind: .tutorMastery,
                targetID: "\(package.id):\(lessonID)",
                title: localize("retention.mission.tutor.title"),
                detail: localize(package.titleKey),
                points: 30
            )
            states.append(DailyMissionState(mission: mission, isCompleted: false, completedAt: nil))
        }

        let trimmed = Array(states.prefix(3))
        progress.dailyMissionStateByDate[key] = trimmed
        return trimmed
    }

    func completeMission(progress: inout UserProgress, missionID: String, now: Date = Date()) -> DailyMissionState? {
        let key = todayKey(now: now)
        guard var states = progress.dailyMissionStateByDate[key],
              let index = states.firstIndex(where: { $0.mission.id == missionID }) else {
            return nil
        }
        guard !states[index].isCompleted else {
            return states[index]
        }

        states[index].isCompleted = true
        states[index].completedAt = now
        progress.dailyMissionStateByDate[key] = states

        if states[index].mission.kind == .review {
            removeReviewItem(progress: &progress, topicID: states[index].mission.targetID)
        }
        return states[index]
    }

    func scheduleReviewItems(
        progress: inout UserProgress,
        topicID: String,
        source: String,
        baseDate: Date = Date()
    ) {
        for dayOffset in [1, 3, 7] {
            guard let dueDate = calendar.date(byAdding: .day, value: dayOffset, to: baseDate) else { continue }
            let id = "\(topicID)|\(todayKey(now: dueDate))"
            if progress.reviewQueue.contains(where: { $0.id == id }) {
                continue
            }
            progress.reviewQueue.append(
                ReviewItem(
                    id: id,
                    topicID: topicID,
                    source: source,
                    dueDate: dueDate,
                    createdAt: baseDate
                )
            )
        }
        progress.reviewQueue.sort { $0.dueDate < $1.dueDate }
    }

    func dueReviewItems(progress: UserProgress, now: Date = Date()) -> [ReviewItem] {
        progress.reviewQueue.filter {
            calendar.startOfDay(for: $0.dueDate) <= calendar.startOfDay(for: now)
        }
    }

    func removeReviewItem(progress: inout UserProgress, topicID: String) {
        if let idx = progress.reviewQueue.firstIndex(where: { $0.topicID == topicID }) {
            progress.reviewQueue.remove(at: idx)
        }
    }
}
