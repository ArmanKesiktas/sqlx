import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case en
    case tr
    case de
    case es
    case fr
    case ar
    case pt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: return "English"
        case .tr: return "Türkçe"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .fr: return "Français"
        case .ar: return "العربية"
        case .pt: return "Português"
        }
    }

    var flag: String {
        switch self {
        case .en: return "🇬🇧"
        case .tr: return "🇹🇷"
        case .de: return "🇩🇪"
        case .es: return "🇪🇸"
        case .fr: return "🇫🇷"
        case .ar: return "🇸🇦"
        case .pt: return "🇧🇷"
        }
    }

    var isRTL: Bool { self == .ar }

    var ttsCode: String {
        switch self {
        case .en: return "en-US"
        case .tr: return "tr-TR"
        case .de: return "de-DE"
        case .es: return "es-ES"
        case .fr: return "fr-FR"
        case .ar: return "ar-XA"
        case .pt: return "pt-BR"
        }
    }
}

enum AppAppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

enum ModuleLevel: String, Codable {
    case beginner
    case intermediate
    case advanced
}

struct LearningModule: Identifiable, Codable {
    let id: String
    let order: Int
    let level: ModuleLevel
    let titleKey: String
    let descriptionKey: String
    let lesson: LessonUnit
    let quiz: [QuizQuestion]
    let challenges: [SQLChallenge]
}

struct LessonUnit: Codable {
    let objectiveKeys: [String]
    let bodyKey: String
    let exampleQueries: [ExampleQuery]
    let realWorldUseCaseKey: String?
    let outcomeKey: String?
    let guidedSteps: [GuidedStep]?
}

struct ExampleQuery: Codable {
    let sql: String
    let explanationKey: String
}

struct GuidedStep: Codable {
    let descriptionKey: String
    let sql: String
}

struct DragFillData: Codable {
    /// SQL template with `___` as blank placeholders, e.g. "SELECT ___ FROM ___"
    let template: String
    /// All draggable token chips shown to the user (correct + distractors)
    let tokens: [String]
    /// The correct tokens in blank order, e.g. ["name", "students"]
    let correctTokens: [String]
}

struct QuizQuestion: Identifiable, Codable {
    let id: String
    let promptKey: String
    let options: [QuizOption]
    let correctOptionID: String
    let explanationKey: String
    /// When non-nil, renders as a drag-fill exercise instead of multiple choice
    let dragFill: DragFillData?
    /// "miniCheck" | "errorDetection" | "outputPrediction" — nil means standard MC
    let questionTag: String?
    /// SQL code to display for errorDetection / outputPrediction questions
    let sqlPreview: String?

    private enum CodingKeys: String, CodingKey {
        case id, promptKey, options, correctOptionID, explanationKey, dragFill
        case questionTag, sqlPreview
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        promptKey = try c.decode(String.self, forKey: .promptKey)
        options = (try? c.decode([QuizOption].self, forKey: .options)) ?? []
        correctOptionID = (try? c.decode(String.self, forKey: .correctOptionID)) ?? ""
        explanationKey = (try? c.decode(String.self, forKey: .explanationKey)) ?? ""
        dragFill = try? c.decode(DragFillData.self, forKey: .dragFill)
        questionTag = try c.decodeIfPresent(String.self, forKey: .questionTag)
        sqlPreview = try c.decodeIfPresent(String.self, forKey: .sqlPreview)
    }
}

struct QuizOption: Identifiable, Codable {
    let id: String
    let textKey: String
}

struct SQLChallenge: Identifiable, Codable {
    let id: String
    let moduleID: String
    let titleKey: String
    let promptKey: String
    let setupSQL: [String]
    let starterSQL: String
    let validation: ChallengeValidation
    let hintKey: String
    let points: Int
}

struct ChallengeValidation: Codable {
    let type: ChallengeValidationType
    let expectedColumns: [String]?
    let expectedRows: [[String]]?
    let table: String?
    let expectedCount: Int?
}

enum ChallengeValidationType: String, Codable {
    case queryResult
    case tableRowCount
}

struct UserProgress: Codable {
    var completedModuleIDs: Set<String>
    var quizScores: [String: Int]
    var completedChallengeIDs: Set<String>
    var startedTutorPackageIDs: Set<String>
    var completedTutorLessonIDs: Set<String>
    var tutorCurrentSceneIndexByPackageID: [String: Int]
    var tutorLastVisitedSceneIDByPackageID: [String: String]
    var tutorCompletedLabSceneIDs: Set<String>
    var tutorProfessionByPackageID: [String: String]
    var tutorMasteryStatusByLessonID: [String: MasteryStatus]
    var tutorCompetencyByPackageID: [String: TutorCompetencyProfile]
    var dailyMissionStateByDate: [String: [DailyMissionState]]
    var reviewQueue: [ReviewItem]
    var examHistory: [ExamAttempt]
    var certificateRecords: [CertificateRecord]
    var lastNotificationPromptDate: Date?
    var lastICloudSyncDate: Date?
    var hasCompletedOnboarding: Bool
    var displayName: String
    var appleUserID: String?
    var isAppleSignedIn: Bool
    var appearanceMode: AppAppearanceMode
    var totalPoints: Int
    var streakDays: Int
    var lastActiveDate: Date?
    var activityDates: Set<String>
    var badgeIDs: Set<String>
    var isPlus: Bool

    init(
        completedModuleIDs: Set<String>,
        quizScores: [String: Int],
        completedChallengeIDs: Set<String>,
        startedTutorPackageIDs: Set<String>,
        completedTutorLessonIDs: Set<String>,
        tutorCurrentSceneIndexByPackageID: [String: Int],
        tutorLastVisitedSceneIDByPackageID: [String: String],
        tutorCompletedLabSceneIDs: Set<String>,
        tutorProfessionByPackageID: [String: String],
        tutorMasteryStatusByLessonID: [String: MasteryStatus],
        tutorCompetencyByPackageID: [String: TutorCompetencyProfile],
        dailyMissionStateByDate: [String: [DailyMissionState]],
        reviewQueue: [ReviewItem],
        examHistory: [ExamAttempt],
        certificateRecords: [CertificateRecord],
        lastNotificationPromptDate: Date?,
        lastICloudSyncDate: Date?,
        hasCompletedOnboarding: Bool,
        displayName: String,
        appleUserID: String?,
        isAppleSignedIn: Bool,
        appearanceMode: AppAppearanceMode,
        totalPoints: Int,
        streakDays: Int,
        lastActiveDate: Date?,
        activityDates: Set<String> = [],
        badgeIDs: Set<String>,
        isPlus: Bool = false
    ) {
        self.completedModuleIDs = completedModuleIDs
        self.quizScores = quizScores
        self.completedChallengeIDs = completedChallengeIDs
        self.startedTutorPackageIDs = startedTutorPackageIDs
        self.completedTutorLessonIDs = completedTutorLessonIDs
        self.tutorCurrentSceneIndexByPackageID = tutorCurrentSceneIndexByPackageID
        self.tutorLastVisitedSceneIDByPackageID = tutorLastVisitedSceneIDByPackageID
        self.tutorCompletedLabSceneIDs = tutorCompletedLabSceneIDs
        self.tutorProfessionByPackageID = tutorProfessionByPackageID
        self.tutorMasteryStatusByLessonID = tutorMasteryStatusByLessonID
        self.tutorCompetencyByPackageID = tutorCompetencyByPackageID
        self.dailyMissionStateByDate = dailyMissionStateByDate
        self.reviewQueue = reviewQueue
        self.examHistory = examHistory
        self.certificateRecords = certificateRecords
        self.lastNotificationPromptDate = lastNotificationPromptDate
        self.lastICloudSyncDate = lastICloudSyncDate
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.displayName = displayName
        self.appleUserID = appleUserID
        self.isAppleSignedIn = isAppleSignedIn
        self.appearanceMode = appearanceMode
        self.totalPoints = totalPoints
        self.streakDays = streakDays
        self.lastActiveDate = lastActiveDate
        self.activityDates = activityDates
        self.badgeIDs = badgeIDs
        self.isPlus = isPlus
    }

    static let empty = UserProgress(
        completedModuleIDs: [],
        quizScores: [:],
        completedChallengeIDs: [],
        startedTutorPackageIDs: [],
        completedTutorLessonIDs: [],
        tutorCurrentSceneIndexByPackageID: [:],
        tutorLastVisitedSceneIDByPackageID: [:],
        tutorCompletedLabSceneIDs: [],
        tutorProfessionByPackageID: [:],
        tutorMasteryStatusByLessonID: [:],
        tutorCompetencyByPackageID: [:],
        dailyMissionStateByDate: [:],
        reviewQueue: [],
        examHistory: [],
        certificateRecords: [],
        lastNotificationPromptDate: nil,
        lastICloudSyncDate: nil,
        hasCompletedOnboarding: false,
        displayName: "",
        appleUserID: nil,
        isAppleSignedIn: false,
        appearanceMode: .system,
        totalPoints: 0,
        streakDays: 0,
        lastActiveDate: nil,
        badgeIDs: [],
        isPlus: false
    )

    private enum CodingKeys: String, CodingKey {
        case completedModuleIDs
        case quizScores
        case completedChallengeIDs
        case startedTutorPackageIDs
        case completedTutorLessonIDs
        case tutorCurrentSceneIndexByPackageID
        case tutorLastVisitedSceneIDByPackageID
        case tutorCompletedLabSceneIDs
        case tutorProfessionByPackageID
        case tutorMasteryStatusByLessonID
        case tutorCompetencyByPackageID
        case dailyMissionStateByDate
        case reviewQueue
        case examHistory
        case certificateRecords
        case lastNotificationPromptDate
        case lastICloudSyncDate
        case hasCompletedOnboarding
        case displayName
        case appleUserID
        case isAppleSignedIn
        case appearanceMode
        case totalPoints
        case streakDays
        case lastActiveDate
        case activityDates
        case badgeIDs
        case isPlus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        completedModuleIDs = try container.decodeIfPresent(Set<String>.self, forKey: .completedModuleIDs) ?? []
        quizScores = try container.decodeIfPresent([String: Int].self, forKey: .quizScores) ?? [:]
        completedChallengeIDs = try container.decodeIfPresent(Set<String>.self, forKey: .completedChallengeIDs) ?? []
        startedTutorPackageIDs = try container.decodeIfPresent(Set<String>.self, forKey: .startedTutorPackageIDs) ?? []
        completedTutorLessonIDs = try container.decodeIfPresent(Set<String>.self, forKey: .completedTutorLessonIDs) ?? []
        tutorCurrentSceneIndexByPackageID = try container.decodeIfPresent([String: Int].self, forKey: .tutorCurrentSceneIndexByPackageID) ?? [:]
        tutorLastVisitedSceneIDByPackageID = try container.decodeIfPresent([String: String].self, forKey: .tutorLastVisitedSceneIDByPackageID) ?? [:]
        tutorCompletedLabSceneIDs = try container.decodeIfPresent(Set<String>.self, forKey: .tutorCompletedLabSceneIDs) ?? []
        tutorProfessionByPackageID = try container.decodeIfPresent([String: String].self, forKey: .tutorProfessionByPackageID) ?? [:]
        tutorMasteryStatusByLessonID = try container.decodeIfPresent([String: MasteryStatus].self, forKey: .tutorMasteryStatusByLessonID) ?? [:]
        tutorCompetencyByPackageID = try container.decodeIfPresent([String: TutorCompetencyProfile].self, forKey: .tutorCompetencyByPackageID) ?? [:]
        dailyMissionStateByDate = try container.decodeIfPresent([String: [DailyMissionState]].self, forKey: .dailyMissionStateByDate) ?? [:]
        reviewQueue = try container.decodeIfPresent([ReviewItem].self, forKey: .reviewQueue) ?? []
        examHistory = try container.decodeIfPresent([ExamAttempt].self, forKey: .examHistory) ?? []
        certificateRecords = try container.decodeIfPresent([CertificateRecord].self, forKey: .certificateRecords) ?? []
        lastNotificationPromptDate = try container.decodeIfPresent(Date.self, forKey: .lastNotificationPromptDate)
        lastICloudSyncDate = try container.decodeIfPresent(Date.self, forKey: .lastICloudSyncDate)
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        appleUserID = try container.decodeIfPresent(String.self, forKey: .appleUserID)
        isAppleSignedIn = try container.decodeIfPresent(Bool.self, forKey: .isAppleSignedIn) ?? false
        appearanceMode = try container.decodeIfPresent(AppAppearanceMode.self, forKey: .appearanceMode) ?? .system
        totalPoints = try container.decodeIfPresent(Int.self, forKey: .totalPoints) ?? 0
        streakDays = try container.decodeIfPresent(Int.self, forKey: .streakDays) ?? 0
        lastActiveDate = try container.decodeIfPresent(Date.self, forKey: .lastActiveDate)
        activityDates = try container.decodeIfPresent(Set<String>.self, forKey: .activityDates) ?? []
        badgeIDs = try container.decodeIfPresent(Set<String>.self, forKey: .badgeIDs) ?? []
        isPlus = try container.decodeIfPresent(Bool.self, forKey: .isPlus) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(completedModuleIDs, forKey: .completedModuleIDs)
        try container.encode(quizScores, forKey: .quizScores)
        try container.encode(completedChallengeIDs, forKey: .completedChallengeIDs)
        try container.encode(startedTutorPackageIDs, forKey: .startedTutorPackageIDs)
        try container.encode(completedTutorLessonIDs, forKey: .completedTutorLessonIDs)
        try container.encode(tutorCurrentSceneIndexByPackageID, forKey: .tutorCurrentSceneIndexByPackageID)
        try container.encode(tutorLastVisitedSceneIDByPackageID, forKey: .tutorLastVisitedSceneIDByPackageID)
        try container.encode(tutorCompletedLabSceneIDs, forKey: .tutorCompletedLabSceneIDs)
        try container.encode(tutorProfessionByPackageID, forKey: .tutorProfessionByPackageID)
        try container.encode(tutorMasteryStatusByLessonID, forKey: .tutorMasteryStatusByLessonID)
        try container.encode(tutorCompetencyByPackageID, forKey: .tutorCompetencyByPackageID)
        try container.encode(dailyMissionStateByDate, forKey: .dailyMissionStateByDate)
        try container.encode(reviewQueue, forKey: .reviewQueue)
        try container.encode(examHistory, forKey: .examHistory)
        try container.encode(certificateRecords, forKey: .certificateRecords)
        try container.encodeIfPresent(lastNotificationPromptDate, forKey: .lastNotificationPromptDate)
        try container.encodeIfPresent(lastICloudSyncDate, forKey: .lastICloudSyncDate)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(appleUserID, forKey: .appleUserID)
        try container.encode(isAppleSignedIn, forKey: .isAppleSignedIn)
        try container.encode(appearanceMode, forKey: .appearanceMode)
        try container.encode(totalPoints, forKey: .totalPoints)
        try container.encode(streakDays, forKey: .streakDays)
        try container.encodeIfPresent(lastActiveDate, forKey: .lastActiveDate)
        try container.encode(activityDates, forKey: .activityDates)
        try container.encode(badgeIDs, forKey: .badgeIDs)
        try container.encode(isPlus, forKey: .isPlus)
    }
}

enum MasteryState: String, Codable {
    case notStarted
    case inProgress
    case passed
    case failed
}

struct MasteryStatus: Codable, Equatable {
    var state: MasteryState
    var score: Int
    var attempts: Int
    var lastUpdatedAt: Date?

    static let empty = MasteryStatus(state: .notStarted, score: 0, attempts: 0, lastUpdatedAt: nil)
}

enum DailyMissionKind: String, Codable, CaseIterable {
    case moduleQuiz
    case challenge
    case tutorMastery
    case review
}

struct DailyMission: Codable, Equatable {
    let id: String
    let kind: DailyMissionKind
    let targetID: String
    let title: String
    let detail: String
    let points: Int
}

struct DailyMissionState: Codable, Equatable, Identifiable {
    let mission: DailyMission
    var isCompleted: Bool
    var completedAt: Date?

    var id: String { mission.id }
}

struct ReviewItem: Codable, Equatable, Identifiable {
    let id: String
    let topicID: String
    let source: String
    let dueDate: Date
    let createdAt: Date
}

enum ExamLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case senior

    var id: String { rawValue }
}

enum ExamQuestionKind: String, Codable {
    case multipleChoice
    case sqlWriting
}

struct ExamQuestion: Codable, Equatable, Identifiable {
    let id: String
    let moduleID: String
    let prompt: String
    let kind: ExamQuestionKind
    let options: [String]
    let correctAnswer: String
    let expectedKeywords: [String]
}

struct ExamAttempt: Codable, Equatable, Identifiable {
    let id: String
    let level: ExamLevel
    let startedAt: Date
    let finishedAt: Date
    let score: Int
    let passed: Bool
    let questionCount: Int
    let correctCount: Int
    let weakTopicIDs: [String]
}

struct CertificateRecord: Codable, Equatable, Identifiable {
    let id: String
    let packageID: String
    let interestID: String
    let title: String
    let subtitle: String
    let masteryScore: Int
    let issuedAt: Date
    let summarySQL: [String]
}

struct Badge: Identifiable, Codable {
    let id: String
    let titleKey: String
    let descriptionKey: String
    let rule: BadgeRule
}

enum BadgeRule: String, Codable {
    case firstChallenge
    case fiveChallenges
    case tenChallenges
    case twentyChallenges
    case firstModule
    case threeModules
    case allModules
    case sevenDayStreak
    case fourteenDayStreak
    case thirtyDayStreak
    case fiveHundredPoints
    case thousandPoints
    case twoThousandPoints
    case firstTutorLesson
    case firstExam
}

struct SQLExecutionResult: Equatable {
    let columns: [String]
    let rows: [[String]]
    let rowsAffected: Int
}

struct TutorCompetencyProfile: Codable, Equatable {
    var completedLessonKinds: Set<String>
    var attemptedQueries: Int
    var successfulQueries: Int
    var weakAreas: [String]
    var strongAreas: [String]

    static let empty = TutorCompetencyProfile(
        completedLessonKinds: [],
        attemptedQueries: 0,
        successfulQueries: 0,
        weakAreas: [],
        strongAreas: []
    )
}

struct TutorPackage: Identifiable {
    let id: String
    let titleKey: String
    let descriptionKey: String
    let icon: String
    let interests: [TutorInterest]
}

struct TutorInterest: Identifiable {
    let lessonKind: TutorLessonKind
    let id: String
    let titleKey: String
    let descriptionKey: String?
    let tableName: String
    let selectColumn: String
    let whereColumn: String
    let whereValue: String
    let orderColumn: String

    init(
        lessonKind: TutorLessonKind = .selectWhereLimit,
        id: String,
        titleKey: String,
        descriptionKey: String? = nil,
        tableName: String,
        selectColumn: String,
        whereColumn: String,
        whereValue: String,
        orderColumn: String
    ) {
        self.lessonKind = lessonKind
        self.id = id
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.tableName = tableName
        self.selectColumn = selectColumn
        self.whereColumn = whereColumn
        self.whereValue = whereValue
        self.orderColumn = orderColumn
    }
}

enum TutorLessonKind: String {
    case selectWhereLimit
    case joinAggregate
    case groupHaving
    case subquery
    case cte
    case window
    case insertInto
    case updateSet
    case deleteFrom
    case alterTable
    case createTable
}

struct TutorPackageStoryboard: Equatable {
    let packageID: String
    let scenes: [TutorScene]
}

struct TutorScene: Identifiable, Equatable {
    let id: String
    let interestID: String
    let interestIndex: Int
    let kind: TutorSceneKind
    let stepTitle: String
    let objective: String
    let ctas: [TutorSceneCTA]
    let autoOpenDrawer: Bool
    let requiresSuccessfulLabRun: Bool
    let masteryIndex: Int?
}

enum TutorSceneKind: String, Equatable {
    case introText
    case conceptCard
    case checkIn
    case exampleScenario
    case miniLabDemo
    case miniLabTry
    case outputExplain
    case masteryMiniQuestion
    case masteryChallenge
    case lessonWrapUp
}

struct TutorSceneCTA: Identifiable, Equatable {
    enum Role: String, Equatable {
        case next
        case affirm
        case explainAgain
        case tryLab
        case continueJourney
        case openDrawer
        case optionAnswer
    }

    let id: String
    let title: String
    let role: Role
    let requiresSuccessfulLabRun: Bool
}

enum TutorCanvasMode: String, Equatable {
    case motion
    case context
    case miniLab
    case output
    case review
}

struct TutorCanvasContent: Equatable {
    let mode: TutorCanvasMode
    let title: String
    let subtitle: String
    let detailLines: [String]
    let codeSample: String?
    let footer: String?
}

struct TutorSessionState: Equatable {
    let currentSceneIndex: Int
    let totalSceneCount: Int
    let suggestedDrawerExpanded: Bool
    let currentCanvasMode: TutorCanvasMode
    let hasRunSceneLab: Bool

    static let empty = TutorSessionState(
        currentSceneIndex: 0,
        totalSceneCount: 0,
        suggestedDrawerExpanded: true,
        currentCanvasMode: .motion,
        hasRunSceneLab: false
    )
}

// MARK: - Career Paths

struct CareerPath: Identifiable, Codable {
    let id: String
    let titleKey: String
    let descriptionKey: String
    let targetAudienceKey: String
    let icon: String
    let difficulty: ModuleLevel
    let estimatedHours: Int
    let moduleIDs: [String]
    let milestones: [CareerMilestone]
}

struct CareerMilestone: Codable {
    let moduleCount: Int
    let titleKey: String
    let descriptionKey: String
}

enum PracticeDatasetMode: String, CaseIterable, Identifiable {
    case blank
    case sample

    var id: String { rawValue }
}

enum PracticeSampleDataset: String, CaseIterable, Identifiable {
    case ecommerce
    case software
    case construction

    var id: String { rawValue }
}

struct PracticeDatasetTablePreview: Identifiable, Equatable {
    let id: String
    let tableName: String
    let schema: SQLExecutionResult
    let sample: SQLExecutionResult

    init(tableName: String, schema: SQLExecutionResult, sample: SQLExecutionResult) {
        self.id = tableName
        self.tableName = tableName
        self.schema = schema
        self.sample = sample
    }
}

struct TutorChatMessage: Identifiable {
    enum Role {
        case assistant
        case user
    }

    enum Tone: String {
        case neutral
        case guiding
        case celebratory
    }

    let id: UUID
    let role: Role
    var text: String
    var result: SQLExecutionResult?
    var sceneID: String?
    var ctaOptions: [String]
    var tone: Tone
}
