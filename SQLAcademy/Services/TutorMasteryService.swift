import Foundation

struct TutorMiniQuestion: Identifiable, Equatable {
    let id: String
    let prompt: String
    let options: [String]
    let correctOptionIndex: Int
    let explanation: String
}

struct TutorMiniChallenge: Equatable {
    let prompt: String
    let setupSQL: [String]
    let expectedQuery: String
}

struct TutorMasteryPlan: Equatable {
    let mini1: TutorMiniQuestion
    let mini2: TutorMiniQuestion
    let challenge: TutorMiniChallenge
}

struct TutorMasteryChallengeResult: Equatable {
    let isCorrect: Bool
    let feedback: String
    let result: SQLExecutionResult?
}

final class TutorMasteryService {
    private let contextService: TutorContextService

    init(contextService: TutorContextService = TutorContextService()) {
        self.contextService = contextService
    }

    func buildPlan(
        interest: TutorInterest,
        context: TutorSQLContext,
        baseCommand: String
    ) -> TutorMasteryPlan {
        let sanitizedCommand = baseCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        let clausePrompt = "Bu komutta filtreleme yapan ana bölüm hangisi?"
        let clauseOptions = ["WHERE", "ORDER BY", "LIMIT"]
        let clauseCorrectIndex = 0

        let orderingPrompt = "Sonucu büyükten küçüğe sıralamak için hangi değişiklik gerekir?"
        let orderingOptions = [
            "ORDER BY \(context.orderColumn) DESC",
            "ORDER BY \(context.orderColumn) ASC",
            "GROUP BY \(context.orderColumn)"
        ]
        let orderingCorrectIndex = 0

        let challengePrompt = """
        Mini Challenge:
        Aynı iskeleti kullanıp `\(context.filterColumn) = '\(context.filterValue)'` filtresiyle sorguyu çalıştır.
        """

        let mini1 = TutorMiniQuestion(
            id: "mini_1",
            prompt: clausePrompt,
            options: clauseOptions,
            correctOptionIndex: clauseCorrectIndex,
            explanation: "Filtreleme `WHERE` ile yapılır."
        )
        let mini2 = TutorMiniQuestion(
            id: "mini_2",
            prompt: orderingPrompt,
            options: orderingOptions,
            correctOptionIndex: orderingCorrectIndex,
            explanation: "Büyükten küçüğe sıralama için `DESC` kullanılır."
        )
        let challenge = TutorMiniChallenge(
            prompt: challengePrompt,
            setupSQL: contextService.previewSetupSQL(interest: interest, context: context),
            expectedQuery: sanitizedCommand
        )
        return TutorMasteryPlan(mini1: mini1, mini2: mini2, challenge: challenge)
    }

    func evaluateMiniQuestion(_ question: TutorMiniQuestion, answer: String) -> Bool {
        let normalized = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty {
            return false
        }

        let optionLabelMap: [String: Int] = ["a": 0, "b": 1, "c": 2, "1": 0, "2": 1, "3": 2]
        if let mapped = optionLabelMap[normalized], mapped == question.correctOptionIndex {
            return true
        }

        let correctOption = question.options[safe: question.correctOptionIndex] ?? ""
        return normalized == correctOption.lowercased()
    }

    func evaluateChallenge(_ challenge: TutorMiniChallenge, submittedQuery: String) -> TutorMasteryChallengeResult {
        let trimmed = submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return TutorMasteryChallengeResult(
                isCorrect: false,
                feedback: "SQL sorgusu boş olamaz.",
                result: nil
            )
        }

        let actualService = SQLExecutionService()
        let expectedService = SQLExecutionService()
        do {
            try actualService.reset(setupStatements: challenge.setupSQL)
            try expectedService.reset(setupStatements: challenge.setupSQL)

            let actualResult = try actualService.execute(trimmed)
            let expectedResult = try expectedService.execute(challenge.expectedQuery)

            let passed = actualResult.columns == expectedResult.columns
                && actualResult.rows == expectedResult.rows

            return TutorMasteryChallengeResult(
                isCorrect: passed,
                feedback: passed
                    ? "Mini challenge doğru çözüldü."
                    : "Beklenen sonuçla eşleşmedi. Komutu filtre ve sıralama ile tekrar dene.",
                result: actualResult
            )
        } catch {
            return TutorMasteryChallengeResult(
                isCorrect: false,
                feedback: error.localizedDescription,
                result: nil
            )
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
