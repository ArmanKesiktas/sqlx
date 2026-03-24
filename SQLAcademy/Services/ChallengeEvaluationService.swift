import Foundation

struct ChallengeEvaluationOutcome {
    let passed: Bool
    let messageKey: String
    let executionResult: SQLExecutionResult?
}

final class ChallengeEvaluationService {
    func evaluate(challenge: SQLChallenge, query: String, sqlService: SQLExecutionService) -> ChallengeEvaluationOutcome {
        do {
            try sqlService.reset(setupStatements: challenge.setupSQL)
            let result = try sqlService.execute(query)
            let isValid = validate(result: result, challenge: challenge, sqlService: sqlService)
            return ChallengeEvaluationOutcome(
                passed: isValid,
                messageKey: isValid ? "challenge.pass" : "challenge.fail",
                executionResult: result
            )
        } catch {
            return ChallengeEvaluationOutcome(
                passed: false,
                messageKey: "challenge.error",
                executionResult: nil
            )
        }
    }

    private func validate(result: SQLExecutionResult, challenge: SQLChallenge, sqlService: SQLExecutionService) -> Bool {
        switch challenge.validation.type {
        case .queryResult:
            guard
                let expectedColumns = challenge.validation.expectedColumns,
                let expectedRows = challenge.validation.expectedRows
            else { return false }
            let normalizedColumns = result.columns.map { $0.lowercased() }
            if normalizedColumns != expectedColumns.map({ $0.lowercased() }) {
                return false
            }
            return result.rows == expectedRows

        case .tableRowCount:
            guard
                let table = challenge.validation.table,
                let expectedCount = challenge.validation.expectedCount
            else { return false }
            let countResult = try? sqlService.execute("SELECT COUNT(*) AS c FROM \(table);", validateSafety: false)
            guard let value = countResult?.rows.first?.first, let count = Int(value) else {
                return false
            }
            return count == expectedCount
        }
    }
}
