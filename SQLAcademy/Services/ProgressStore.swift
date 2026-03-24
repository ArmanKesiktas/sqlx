import Foundation

final class ProgressStore {
    private let key = "sqlacademy.userprogress.v1"
    private let userDefaults: UserDefaults
    private let calendar: Calendar

    init(userDefaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.userDefaults = userDefaults
        self.calendar = calendar
    }

    func load() -> UserProgress {
        guard let data = userDefaults.data(forKey: key) else { return .empty }
        return (try? JSONDecoder().decode(UserProgress.self, from: data)) ?? .empty
    }

    func save(_ progress: UserProgress) {
        if let data = try? JSONEncoder().encode(progress) {
            userDefaults.set(data, forKey: key)
        }
    }

    func reset() {
        userDefaults.removeObject(forKey: key)
    }

    func touchDailyActivity(progress: inout UserProgress, now: Date = Date()) {
        defer { progress.lastActiveDate = now }

        // Record today in activityDates for streak calendar
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        progress.activityDates.insert(fmt.string(from: now))

        guard let last = progress.lastActiveDate else {
            progress.streakDays = 1
            return
        }
        if calendar.isDate(last, inSameDayAs: now) {
            return
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(last, inSameDayAs: yesterday) {
            progress.streakDays += 1
        } else {
            progress.streakDays = 1
        }
    }

    @discardableResult
    func applyBadges(progress: inout UserProgress, badges: [Badge]) -> [Badge] {
        var newlyUnlocked: [Badge] = []
        for badge in badges {
            let alreadyHad = progress.badgeIDs.contains(badge.id)
            let qualifies: Bool
            switch badge.rule {
            case .firstChallenge:    qualifies = progress.completedChallengeIDs.count >= 1
            case .fiveChallenges:    qualifies = progress.completedChallengeIDs.count >= 5
            case .tenChallenges:     qualifies = progress.completedChallengeIDs.count >= 10
            case .twentyChallenges:  qualifies = progress.completedChallengeIDs.count >= 20
            case .firstModule:       qualifies = progress.completedModuleIDs.count >= 1
            case .threeModules:      qualifies = progress.completedModuleIDs.count >= 3
            case .allModules:        qualifies = progress.completedModuleIDs.count >= 6
            case .sevenDayStreak:    qualifies = progress.streakDays >= 7
            case .fourteenDayStreak: qualifies = progress.streakDays >= 14
            case .thirtyDayStreak:   qualifies = progress.streakDays >= 30
            case .fiveHundredPoints: qualifies = progress.totalPoints >= 500
            case .thousandPoints:    qualifies = progress.totalPoints >= 1000
            case .twoThousandPoints: qualifies = progress.totalPoints >= 2000
            case .firstTutorLesson:  qualifies = !progress.completedTutorLessonIDs.isEmpty
            case .firstExam:         qualifies = !progress.examHistory.isEmpty
            }
            if qualifies {
                progress.badgeIDs.insert(badge.id)
                if !alreadyHad { newlyUnlocked.append(badge) }
            }
        }
        return newlyUnlocked
    }
}
