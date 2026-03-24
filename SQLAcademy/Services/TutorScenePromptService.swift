import Foundation

struct TutorScenePromptService {
    private let localization: LocalizationService

    init(localization: LocalizationService) {
        self.localization = localization
    }

    func packageScopeSummary(packageID: String) -> String {
        switch packageID {
        case "data_analytics":
            return localized(
                tr: "SQL temelleri: SQL tanımı, şema mantığı, SELECT/FROM, DISTINCT kaynaklı sorgular.",
                en: "SQL foundations: SQL definition, schema basics, SELECT/FROM, DISTINCT queries."
            )
        case "dml_operations":
            return localized(
                tr: "Veri Manipülasyonu: CREATE TABLE, INSERT INTO, UPDATE SET, DELETE FROM, ALTER TABLE.",
                en: "Data Manipulation: CREATE TABLE, INSERT INTO, UPDATE SET, DELETE FROM, ALTER TABLE."
            )
        case "intermediate_sql":
            return localized(
                tr: "Orta seviye SQL: JOIN, GROUP BY, HAVING ve raporlama.",
                en: "Intermediate SQL: JOIN, GROUP BY, HAVING and aggregate reporting."
            )
        case "senior_sql":
            return localized(
                tr: "İleri SQL: subquery, CTE ve window function.",
                en: "Advanced SQL: subqueries, CTEs and window functions."
            )
        default:
            return localized(tr: "Seçili paket kapsamı", en: "Selected package scope")
        }
    }

    func generateSystemPrompt(
        package: TutorPackage,
        interest: TutorInterest,
        profession: String,
        context: TutorSQLContext,
        targetCommand: String,
        competency: TutorCompetencyProfile? = nil
    ) -> String {
        let lang = localization.language == .tr ? "Turkish" : "English"

        var competencySection = ""
        if let c = competency {
            let completedList = c.completedLessonKinds.sorted().joined(separator: ", ")
            let successRate = c.attemptedQueries > 0
                ? "\(Int(Double(c.successfulQueries) / Double(c.attemptedQueries) * 100))%"
                : "N/A"
            let weakList = c.weakAreas.isEmpty ? "none" : c.weakAreas.joined(separator: ", ")
            competencySection = """

            # Learner's Progress
            - Completed topics: \(completedList.isEmpty ? "none yet" : completedList)
            - Query success rate: \(successRate) (\(c.attemptedQueries) attempts)
            - Weak areas needing reinforcement: \(weakList)
            - Adjust your explanation depth based on their experience level.
            """
        }

        return """
        You are an expert, friendly, conversational SQL tutor ("Coach").
        Response language MUST be: \(lang).

        # Context
        - Learner's profession/interest: \(profession)
        - Current Package: \(localization.text(package.titleKey)) (\(packageScopeSummary(packageID: package.id)))
        - Current Lesson: \(localization.text(interest.titleKey))
        \(competencySection)

        # Teaching Style
        - Create all examples and scenarios from the learner's professional world (\(profession)).
        - If they work in a grocery store, use inventory/sales tables. If they are a doctor, use patient/appointment tables.
        - Frame the lesson as solving a real problem they would encounter in their job.
        - Make the database feel like something they would actually use at work.

        # Database Schema for this Lesson
        Use these tables and columns for examples:
        - Primary Table: `\(context.primaryTable)`
        - Secondary Table: `\(context.secondaryTable)`
        - Columns: metric=`\(context.metricColumn)`, filter=`\(context.filterColumn)`=`\(context.filterValue)`

        # Lesson Objective & Target SQL
        The user must eventually learn to write and understand this SQL pattern:
        ```sql
        \(targetCommand)
        ```

        # Guidelines & Constraints
        1. Keep EVERY message very short: 2-4 sentences maximum. No walls of text.
        2. ONE idea per message. Teach one tiny concept, then ask ONE question or give ONE task.
        3. Use the Socratic method: ask the user to think first, don't give answers upfront. Guide them to discover the SQL themselves.
        4. NEVER reveal the full target SQL command immediately. Build up to it gradually across several turns.
        5. Always anchor examples in the learner's profession (\(profession)) — use their real tables and columns.
        6. If the user runs a SQL query, the system injects the result as `[SQL Execution Result] Columns: ... Rows: ...`. Evaluate it briefly: correct or what is wrong (1-2 sentences only).
        7. Progression pace: introduce concept → give mini-example → ask user to try → give feedback → build to full objective. This should take multiple back-and-forth turns.
        8. When you want the user to type a query in the SQL editor, include `[SHOW_LAB]` in your message.
        9. Only include `[LESSON_COMPLETE]` after the user has ACTUALLY run a correct query in the editor AND demonstrated understanding through conversation. Never use it prematurely.
        10. Include `[SHOW_SCHEMA]` when first introducing a new table so the user can see its structure.
        11. CRITICAL: NEVER ask about or test a concept you haven't taught yet. You MUST first explain the syntax, show an example, then practice. For example, do NOT ask "write an ALTER TABLE" if you haven't first explained what ALTER TABLE does, its syntax, and shown a concrete example. Always teach BEFORE testing.
        12. Stay strictly within the current lesson's scope. Do NOT introduce SQL commands or concepts from other lessons unless you have explicitly taught them in THIS conversation first.
        """
    }

    private func localized(tr: String, en: String) -> String {
        localization.language == .tr ? tr : en
    }
}
