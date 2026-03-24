import Foundation

enum BackupSyncError: Error {
    case invalidPayload
}

final class BackupSyncService {
    private let iCloudStore: NSUbiquitousKeyValueStore
    private let key = "sqlx.progress.backup.v2"

    init(iCloudStore: NSUbiquitousKeyValueStore = .default) {
        self.iCloudStore = iCloudStore
    }

    func exportJSON(progress: UserProgress) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(progress)
    }

    func importJSON(data: Data) throws -> UserProgress {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let progress = try? decoder.decode(UserProgress.self, from: data) else {
            throw BackupSyncError.invalidPayload
        }
        return progress
    }

    func syncToICloud(progress: UserProgress) {
        guard let payload = try? exportJSON(progress: progress) else { return }
        iCloudStore.set(payload, forKey: key)
        iCloudStore.synchronize()
    }

    func restoreFromICloud(localProgress: UserProgress) -> UserProgress? {
        guard let payload = iCloudStore.data(forKey: key),
              let remote = try? importJSON(data: payload) else {
            return nil
        }
        return merge(local: localProgress, remote: remote)
    }

    func merge(local: UserProgress, remote: UserProgress) -> UserProgress {
        var merged = local
        let localDate = local.lastActiveDate ?? .distantPast
        let remoteDate = remote.lastActiveDate ?? .distantPast

        let localWeight = progressWeight(local)
        let remoteWeight = progressWeight(remote)
        let remoteWins = remoteDate > localDate || (remoteDate == localDate && remoteWeight > localWeight)

        let base = remoteWins ? remote : local
        merged.displayName = !base.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? base.displayName
            : merged.displayName
        merged.appleUserID = base.appleUserID ?? merged.appleUserID
        merged.isAppleSignedIn = local.isAppleSignedIn || remote.isAppleSignedIn
        merged.hasCompletedOnboarding = local.hasCompletedOnboarding || remote.hasCompletedOnboarding
        merged.appearanceMode = base.appearanceMode

        merged.completedModuleIDs = local.completedModuleIDs.union(remote.completedModuleIDs)
        merged.completedChallengeIDs = local.completedChallengeIDs.union(remote.completedChallengeIDs)
        merged.startedTutorPackageIDs = local.startedTutorPackageIDs.union(remote.startedTutorPackageIDs)
        merged.completedTutorLessonIDs = local.completedTutorLessonIDs.union(remote.completedTutorLessonIDs)
        merged.tutorCompletedLabSceneIDs = local.tutorCompletedLabSceneIDs.union(remote.tutorCompletedLabSceneIDs)
        merged.badgeIDs = local.badgeIDs.union(remote.badgeIDs)

        merged.totalPoints = max(local.totalPoints, remote.totalPoints)
        merged.streakDays = max(local.streakDays, remote.streakDays)
        merged.lastActiveDate = max(localDate, remoteDate)

        merged.quizScores = local.quizScores
        for (id, score) in remote.quizScores {
            merged.quizScores[id] = max(score, merged.quizScores[id] ?? 0)
        }

        merged.tutorProfessionByPackageID = local.tutorProfessionByPackageID
        for (id, value) in remote.tutorProfessionByPackageID where merged.tutorProfessionByPackageID[id] == nil {
            merged.tutorProfessionByPackageID[id] = value
        }

        merged.tutorCurrentSceneIndexByPackageID = local.tutorCurrentSceneIndexByPackageID
        for (id, value) in remote.tutorCurrentSceneIndexByPackageID {
            merged.tutorCurrentSceneIndexByPackageID[id] = max(value, merged.tutorCurrentSceneIndexByPackageID[id] ?? 0)
        }

        merged.tutorLastVisitedSceneIDByPackageID = local.tutorLastVisitedSceneIDByPackageID
        for (id, value) in remote.tutorLastVisitedSceneIDByPackageID where merged.tutorLastVisitedSceneIDByPackageID[id] == nil || remoteWins {
            merged.tutorLastVisitedSceneIDByPackageID[id] = value
        }

        merged.tutorMasteryStatusByLessonID = local.tutorMasteryStatusByLessonID
        for (id, status) in remote.tutorMasteryStatusByLessonID {
            let existing = merged.tutorMasteryStatusByLessonID[id] ?? .empty
            let existingDate = existing.lastUpdatedAt ?? .distantPast
            let incomingDate = status.lastUpdatedAt ?? .distantPast
            if incomingDate >= existingDate {
                merged.tutorMasteryStatusByLessonID[id] = status
            }
        }

        merged.tutorCompetencyByPackageID = local.tutorCompetencyByPackageID
        for (id, remote) in remote.tutorCompetencyByPackageID {
            let existing = merged.tutorCompetencyByPackageID[id] ?? .empty
            if remote.attemptedQueries >= existing.attemptedQueries {
                merged.tutorCompetencyByPackageID[id] = remote
            }
        }

        merged.dailyMissionStateByDate = local.dailyMissionStateByDate
        for (dateKey, states) in remote.dailyMissionStateByDate {
            let localStates = merged.dailyMissionStateByDate[dateKey] ?? []
            let localCompleted = localStates.filter(\.isCompleted).count
            let remoteCompleted = states.filter(\.isCompleted).count
            if remoteCompleted >= localCompleted {
                merged.dailyMissionStateByDate[dateKey] = states
            }
        }

        var reviewMap = Dictionary(uniqueKeysWithValues: local.reviewQueue.map { ($0.id, $0) })
        for item in remote.reviewQueue {
            reviewMap[item.id] = item
        }
        merged.reviewQueue = Array(reviewMap.values).sorted { $0.dueDate < $1.dueDate }

        var examMap = Dictionary(uniqueKeysWithValues: local.examHistory.map { ($0.id, $0) })
        for attempt in remote.examHistory {
            examMap[attempt.id] = attempt
        }
        merged.examHistory = Array(examMap.values).sorted { $0.finishedAt > $1.finishedAt }

        var certificateMap = Dictionary(uniqueKeysWithValues: local.certificateRecords.map { ($0.id, $0) })
        for record in remote.certificateRecords {
            certificateMap[record.id] = record
        }
        merged.certificateRecords = Array(certificateMap.values).sorted { $0.issuedAt > $1.issuedAt }

        merged.lastNotificationPromptDate = max(local.lastNotificationPromptDate ?? .distantPast, remote.lastNotificationPromptDate ?? .distantPast)
        if merged.lastNotificationPromptDate == .distantPast {
            merged.lastNotificationPromptDate = nil
        }
        merged.lastICloudSyncDate = Date()
        return merged
    }

    private func progressWeight(_ progress: UserProgress) -> Int {
        (progress.completedModuleIDs.count * 1000)
            + (progress.completedChallengeIDs.count * 100)
            + (progress.completedTutorLessonIDs.count * 10)
            + progress.totalPoints
    }
}
