import Foundation

struct ExamSession: Equatable, Identifiable {
    let id: String
    let level: ExamLevel
    let questions: [ExamQuestion]
    let startedAt: Date
    let endAt: Date
    var answers: [String: String]
}

final class ExamEngineService {
    private let examDurationSeconds: TimeInterval

    init(examDurationSeconds: TimeInterval = 25 * 60) {
        self.examDurationSeconds = examDurationSeconds
    }

    func makeSession(
        level: ExamLevel,
        modules: [LearningModule],
        localize: (String) -> String,
        now: Date = Date()
    ) -> ExamSession {
        let levelModules = modulesForLevel(level, modules: modules)
        let mcBank = levelModules.flatMap { module in
            module.quiz.map { question in
                ExamQuestion(
                    id: "mc_\(question.id)",
                    moduleID: module.id,
                    prompt: localize(question.promptKey),
                    kind: .multipleChoice,
                    options: question.options.map { localize($0.textKey) },
                    correctAnswer: localize(question.options.first(where: { $0.id == question.correctOptionID })?.textKey ?? ""),
                    expectedKeywords: []
                )
            }
        }
        let writingBank = writingQuestions(level: level, modules: levelModules)

        var selected = Array(mcBank.shuffled().prefix(17))
        let writing = Array(writingBank.shuffled().prefix(3))
        selected.append(contentsOf: writing)

        while selected.count < 20, let fallback = (mcBank + writingBank).randomElement() {
            selected.append(fallback)
        }
        selected = Array(selected.prefix(20)).shuffled()

        return ExamSession(
            id: UUID().uuidString,
            level: level,
            questions: selected,
            startedAt: now,
            endAt: now.addingTimeInterval(examDurationSeconds),
            answers: [:]
        )
    }

    func submitAnswer(_ answer: String, for questionID: String, in session: inout ExamSession) {
        session.answers[questionID] = answer
    }

    func evaluate(_ session: ExamSession, finishedAt: Date = Date()) -> ExamAttempt {
        let total = session.questions.count
        let correct = session.questions.reduce(0) { partial, question in
            let answer = session.answers[question.id] ?? ""
            return partial + (isCorrect(answer: answer, for: question) ? 1 : 0)
        }

        let score = total == 0 ? 0 : Int((Double(correct) / Double(total)) * 100.0)
        let weakTopics = Set(
            session.questions.compactMap { question -> String? in
                let answer = session.answers[question.id] ?? ""
                return isCorrect(answer: answer, for: question) ? nil : question.moduleID
            }
        )

        return ExamAttempt(
            id: UUID().uuidString,
            level: session.level,
            startedAt: session.startedAt,
            finishedAt: finishedAt,
            score: score,
            passed: score >= 80,
            questionCount: total,
            correctCount: correct,
            weakTopicIDs: Array(weakTopics).sorted()
        )
    }

    private func modulesForLevel(_ level: ExamLevel, modules: [LearningModule]) -> [LearningModule] {
        switch level {
        case .beginner:
            return modules.filter { $0.level == .beginner }
        case .intermediate:
            return modules
        case .senior:
            return modules.filter { $0.level == .intermediate }
        }
    }

    private func writingQuestions(level: ExamLevel, modules: [LearningModule]) -> [ExamQuestion] {
        let defaultModuleID = modules.first?.id ?? "general_sql"
        switch level {
        case .beginner:
            return [
                ExamQuestion(
                    id: "sqlw_beginner_select",
                    moduleID: defaultModuleID,
                    prompt: "Write an SQL query that selects all columns from a table and filters rows with a WHERE condition.",
                    kind: .sqlWriting,
                    options: [],
                    correctAnswer: "",
                    expectedKeywords: ["SELECT", "FROM", "WHERE"]
                ),
                ExamQuestion(
                    id: "sqlw_beginner_order",
                    moduleID: defaultModuleID,
                    prompt: "Write a query that sorts results by one column in descending order.",
                    kind: .sqlWriting,
                    options: [],
                    correctAnswer: "",
                    expectedKeywords: ["SELECT", "FROM", "ORDER BY", "DESC"]
                ),
                ExamQuestion(
                    id: "sqlw_beginner_limit",
                    moduleID: defaultModuleID,
                    prompt: "Write a query that returns only the first 5 rows.",
                    kind: .sqlWriting,
                    options: [],
                    correctAnswer: "",
                    expectedKeywords: ["SELECT", "FROM", "LIMIT"]
                )
            ]
        case .intermediate:
            return [
                ExamQuestion(
                    id: "sqlw_intermediate_join",
                    moduleID: defaultModuleID,
                    prompt: "Write a JOIN query between customers and orders tables.",
                    kind: .sqlWriting,
                    options: [],
                    correctAnswer: "",
                    expectedKeywords: ["SELECT", "FROM", "JOIN", "ON"]
                ),
                ExamQuestion(
                    id: "sqlw_intermediate_group",
                    moduleID: defaultModuleID,
                    prompt: "Write a query using GROUP BY and COUNT.",
                    kind: .sqlWriting,
                    options: [],
                    correctAnswer: "",
                    expectedKeywords: ["SELECT", "COUNT", "FROM", "GROUP BY"]
                ),
                ExamQuestion(
                    id: "sqlw_intermediate_having",
                    moduleID: defaultModuleID,
                    prompt: "Write a query that filters grouped results with HAVING.",
                    kind: .sqlWriting,
                    options: [],
                    correctAnswer: "",
                    expectedKeywords: ["GROUP BY", "HAVING"]
                )
            ]
        case .senior:
            return [
                ExamQuestion(
                    id: "sqlw_senior_subquery",
                    moduleID: defaultModuleID,
                    prompt: "Write a query that uses a subquery in WHERE.",
                    kind: .sqlWriting,
                    options: [],
                    correctAnswer: "",
                    expectedKeywords: ["SELECT", "WHERE", "SELECT"]
                ),
                ExamQuestion(
                    id: "sqlw_senior_cte",
                    moduleID: defaultModuleID,
                    prompt: "Write a query that starts with WITH (CTE).",
                    kind: .sqlWriting,
                    options: [],
                    correctAnswer: "",
                    expectedKeywords: ["WITH", "SELECT"]
                ),
                ExamQuestion(
                    id: "sqlw_senior_window",
                    moduleID: defaultModuleID,
                    prompt: "Write a query that uses a window function with OVER().",
                    kind: .sqlWriting,
                    options: [],
                    correctAnswer: "",
                    expectedKeywords: ["SELECT", "OVER", "FROM"]
                )
            ]
        }
    }

    private func isCorrect(answer: String, for question: ExamQuestion) -> Bool {
        let normalized = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }

        switch question.kind {
        case .multipleChoice:
            if normalized == question.correctAnswer.lowercased() {
                return true
            }
            let labels: [String: Int] = ["a": 0, "b": 1, "c": 2, "1": 0, "2": 1, "3": 2]
            if let idx = labels[normalized], question.options.indices.contains(idx) {
                return question.options[idx].lowercased() == question.correctAnswer.lowercased()
            }
            return false
        case .sqlWriting:
            let upper = answer.uppercased()
            return question.expectedKeywords.allSatisfy { upper.contains($0) }
        }
    }
}
