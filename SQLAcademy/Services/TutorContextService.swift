import Foundation

struct TutorSQLContext: Equatable {
    let primaryTable: String
    let secondaryTable: String
    let metricColumn: String
    let dimensionColumn: String
    let filterColumn: String
    let filterValue: String
    let orderColumn: String
    let joinPrimaryColumn: String
    let joinSecondaryColumn: String
}

private actor TutorContextCache {
    private var cache: [String: TutorSQLContext] = [:]

    func get(_ key: String) -> TutorSQLContext? {
        cache[key]
    }

    func set(_ key: String, value: TutorSQLContext) {
        cache[key] = value
    }
}

struct TutorContextService {
    private let aiContextCache = TutorContextCache()

    func requestAIGeneratedContext(
        profession: String,
        lessonKind: TutorLessonKind,
        interest: TutorInterest,
        aiService: any TutorAIProviding
    ) async -> TutorSQLContext {
        let cacheKey = "\(profession.lowercased())_\(lessonKind.rawValue)"
        if let cached = await aiContextCache.get(cacheKey) {
            return cached
        }

        let fb = fallbackContext(profession: profession, interest: interest)

        let prompt = """
        You are a database schema designer. Given a profession and a SQL lesson type, generate a realistic database context as JSON.
        The profession is: \(profession)
        The SQL pattern to teach is: \(lessonKind.rawValue)

        Return ONLY a JSON object with these fields:
        {
          "primaryTable": "table_name",
          "secondaryTable": "related_table_name",
          "metricColumn": "numeric_column",
          "dimensionColumn": "grouping_column",
          "filterColumn": "filter_column",
          "filterValue": "example_value",
          "orderColumn": "sort_column",
          "joinPrimaryColumn": "fk_column",
          "joinSecondaryColumn": "pk_column"
        }

        Make table and column names relevant to the profession "\(profession)".
        Use snake_case, lowercase, no SQL keywords. Keep names short (max 30 chars).
        Return ONLY the JSON, no explanation.
        """

        let messages = [TutorChatMessage(id: UUID(), role: .user, text: "Generate context", result: nil, sceneID: nil, ctaOptions: [], tone: .neutral)]
        if let response = await aiService.generate(systemPrompt: prompt, messages: messages) {
            let parsed = parseGeneratedContext(response, fallback: fb)
            await aiContextCache.set(cacheKey, value: parsed)
            return parsed
        }

        return fb
    }

    func fallbackContext(profession: String, interest: TutorInterest) -> TutorSQLContext {
        let domain = resolveDomain(for: profession)

        switch (domain, interest.lessonKind) {
        case (.software, .selectWhereLimit):
            return makeContext(
                primaryTable: "service_tickets",
                secondaryTable: "team_directory",
                metricColumn: "resolution_minutes",
                dimensionColumn: "team_name",
                filterColumn: "team",
                filterValue: "backend",
                orderColumn: "resolution_minutes",
                joinPrimaryColumn: "team_id",
                joinSecondaryColumn: "id"
            )
        case (.construction, .selectWhereLimit):
            return makeContext(
                primaryTable: "site_tasks",
                secondaryTable: "site_crews",
                metricColumn: "completion_minutes",
                dimensionColumn: "crew_name",
                filterColumn: "zone",
                filterValue: "blok_a",
                orderColumn: "completion_minutes",
                joinPrimaryColumn: "crew_id",
                joinSecondaryColumn: "id"
            )
        case (.software, .joinAggregate):
            return makeContext(
                primaryTable: "deploy_logs",
                secondaryTable: "service_owners",
                metricColumn: "incident_count",
                dimensionColumn: "owner_team",
                filterColumn: "region",
                filterValue: "tr",
                orderColumn: "incident_count",
                joinPrimaryColumn: "owner_id",
                joinSecondaryColumn: "id"
            )
        case (.construction, .joinAggregate):
            return makeContext(
                primaryTable: "material_usage",
                secondaryTable: "construction_sites",
                metricColumn: "used_tons",
                dimensionColumn: "site_name",
                filterColumn: "city",
                filterValue: "istanbul",
                orderColumn: "used_tons",
                joinPrimaryColumn: "site_id",
                joinSecondaryColumn: "id"
            )
        case (.software, .groupHaving):
            return makeContext(
                primaryTable: "bug_reports",
                secondaryTable: "release_calendar",
                metricColumn: "bug_count",
                dimensionColumn: "service_name",
                filterColumn: "severity",
                filterValue: "high",
                orderColumn: "bug_count",
                joinPrimaryColumn: "release_id",
                joinSecondaryColumn: "id"
            )
        case (.construction, .groupHaving):
            return makeContext(
                primaryTable: "safety_events",
                secondaryTable: "shift_plan",
                metricColumn: "event_count",
                dimensionColumn: "site_name",
                filterColumn: "risk_level",
                filterValue: "high",
                orderColumn: "event_count",
                joinPrimaryColumn: "shift_id",
                joinSecondaryColumn: "id"
            )
        case (.software, .subquery):
            return makeContext(
                primaryTable: "query_metrics",
                secondaryTable: "database_cluster",
                metricColumn: "latency_ms",
                dimensionColumn: "service_name",
                filterColumn: "environment",
                filterValue: "prod",
                orderColumn: "latency_ms",
                joinPrimaryColumn: "cluster_id",
                joinSecondaryColumn: "id"
            )
        case (.construction, .subquery):
            return makeContext(
                primaryTable: "equipment_runtime",
                secondaryTable: "machine_catalog",
                metricColumn: "downtime_minutes",
                dimensionColumn: "machine_name",
                filterColumn: "site_code",
                filterValue: "a1",
                orderColumn: "downtime_minutes",
                joinPrimaryColumn: "machine_id",
                joinSecondaryColumn: "id"
            )
        case (.software, .cte):
            return makeContext(
                primaryTable: "api_calls",
                secondaryTable: "product_modules",
                metricColumn: "response_ms",
                dimensionColumn: "module_name",
                filterColumn: "channel",
                filterValue: "mobile",
                orderColumn: "response_ms",
                joinPrimaryColumn: "module_id",
                joinSecondaryColumn: "id"
            )
        case (.construction, .cte):
            return makeContext(
                primaryTable: "inspection_logs",
                secondaryTable: "zone_catalog",
                metricColumn: "inspection_score",
                dimensionColumn: "zone_name",
                filterColumn: "status",
                filterValue: "open",
                orderColumn: "inspection_score",
                joinPrimaryColumn: "zone_id",
                joinSecondaryColumn: "id"
            )
        case (.software, .window):
            return makeContext(
                primaryTable: "feature_events",
                secondaryTable: "release_channels",
                metricColumn: "active_users",
                dimensionColumn: "feature_name",
                filterColumn: "platform",
                filterValue: "ios",
                orderColumn: "active_users",
                joinPrimaryColumn: "channel_id",
                joinSecondaryColumn: "id"
            )
        case (.construction, .window):
            return makeContext(
                primaryTable: "daily_output",
                secondaryTable: "task_catalog",
                metricColumn: "completed_units",
                dimensionColumn: "task_name",
                filterColumn: "shift",
                filterValue: "day",
                orderColumn: "completed_units",
                joinPrimaryColumn: "task_id",
                joinSecondaryColumn: "id"
            )
        case (.general, _):
            return makeContext(
                primaryTable: interest.tableName,
                secondaryTable: "\(interest.tableName)_dim",
                metricColumn: interest.selectColumn,
                dimensionColumn: "segment_name",
                filterColumn: interest.whereColumn,
                filterValue: interest.whereValue,
                orderColumn: interest.orderColumn,
                joinPrimaryColumn: "segment_id",
                joinSecondaryColumn: "id"
            )
        case (.software, _), (.construction, _):
            return makeContext(
                primaryTable: interest.tableName,
                secondaryTable: "\(interest.tableName)_dim",
                metricColumn: interest.selectColumn,
                dimensionColumn: "segment_name",
                filterColumn: interest.whereColumn,
                filterValue: interest.whereValue,
                orderColumn: interest.orderColumn,
                joinPrimaryColumn: "segment_id",
                joinSecondaryColumn: "id"
            )
        }
    }

    func parseGeneratedContext(_ generated: String, fallback: TutorSQLContext) -> TutorSQLContext {
        guard let data = extractJSONObject(from: generated)?.data(using: .utf8),
              let raw = try? JSONDecoder().decode(TutorContextPayload.self, from: data) else {
            return fallback
        }

        return makeContext(
            primaryTable: sanitizeIdentifier(raw.primaryTable, fallback: fallback.primaryTable),
            secondaryTable: sanitizeIdentifier(raw.secondaryTable, fallback: fallback.secondaryTable),
            metricColumn: sanitizeIdentifier(raw.metricColumn, fallback: fallback.metricColumn),
            dimensionColumn: sanitizeIdentifier(raw.dimensionColumn, fallback: fallback.dimensionColumn),
            filterColumn: sanitizeIdentifier(raw.filterColumn, fallback: fallback.filterColumn),
            filterValue: sanitizeFilterValue(raw.filterValue, fallback: fallback.filterValue),
            orderColumn: sanitizeIdentifier(raw.orderColumn, fallback: fallback.orderColumn),
            joinPrimaryColumn: sanitizeIdentifier(raw.joinPrimaryColumn, fallback: fallback.joinPrimaryColumn),
            joinSecondaryColumn: sanitizeIdentifier(raw.joinSecondaryColumn, fallback: fallback.joinSecondaryColumn)
        )
    }

    func buildCommand(interest: TutorInterest, context: TutorSQLContext) -> String {
        if let foundationCommand = foundationCommand(for: interest, context: context) {
            return foundationCommand
        }

        switch interest.lessonKind {
        case .selectWhereLimit:
            return """
            SELECT \(context.metricColumn)
            FROM \(context.primaryTable)
            WHERE \(context.filterColumn) = '\(escaped(context.filterValue))'
            ORDER BY \(context.orderColumn) DESC
            LIMIT 10;
            """

        case .joinAggregate:
            return """
            SELECT d.\(context.dimensionColumn), SUM(f.\(context.metricColumn)) AS total_metric
            FROM \(context.primaryTable) f
            JOIN \(context.secondaryTable) d ON f.\(context.joinPrimaryColumn) = d.\(context.joinSecondaryColumn)
            WHERE d.\(context.filterColumn) = '\(escaped(context.filterValue))'
            GROUP BY d.\(context.dimensionColumn)
            ORDER BY total_metric DESC
            LIMIT 10;
            """

        case .groupHaving:
            return """
            SELECT \(context.dimensionColumn), SUM(\(context.metricColumn)) AS total_metric
            FROM \(context.primaryTable)
            GROUP BY \(context.dimensionColumn)
            HAVING SUM(\(context.metricColumn)) > 100
            ORDER BY total_metric DESC
            LIMIT 10;
            """

        case .subquery:
            return """
            SELECT \(context.dimensionColumn), \(context.metricColumn)
            FROM \(context.primaryTable)
            WHERE \(context.metricColumn) > (
                SELECT AVG(\(context.metricColumn))
                FROM \(context.primaryTable)
            )
            AND \(context.filterColumn) = '\(escaped(context.filterValue))'
            ORDER BY \(context.metricColumn) DESC
            LIMIT 10;
            """

        case .cte:
            return """
            WITH scoped_data AS (
                SELECT \(context.dimensionColumn), \(context.metricColumn)
                FROM \(context.primaryTable)
                WHERE \(context.filterColumn) = '\(escaped(context.filterValue))'
            )
            SELECT \(context.dimensionColumn), AVG(\(context.metricColumn)) AS avg_metric
            FROM scoped_data
            GROUP BY \(context.dimensionColumn)
            ORDER BY avg_metric DESC
            LIMIT 10;
            """

        case .window:
            return """
            SELECT \(context.dimensionColumn),
                   \(context.metricColumn),
                   RANK() OVER (ORDER BY \(context.metricColumn) DESC) AS metric_rank
            FROM \(context.primaryTable)
            WHERE \(context.filterColumn) = '\(escaped(context.filterValue))'
            ORDER BY metric_rank
            LIMIT 10;
            """

        case .createTable:
            return """
            CREATE TABLE \(context.primaryTable) (
                id INTEGER PRIMARY KEY,
                \(context.filterColumn) TEXT NOT NULL,
                \(context.metricColumn) INTEGER DEFAULT 0
            );
            """

        case .insertInto:
            return """
            INSERT INTO \(context.primaryTable) (id, \(context.filterColumn), \(context.metricColumn))
            VALUES (1, '\(escaped(context.filterValue))', 100);
            """

        case .updateSet:
            return """
            UPDATE \(context.primaryTable)
            SET \(context.metricColumn) = 200
            WHERE \(context.filterColumn) = '\(escaped(context.filterValue))';
            """

        case .deleteFrom:
            return """
            DELETE FROM \(context.primaryTable)
            WHERE \(context.filterColumn) = '\(escaped(context.filterValue))';
            """

        case .alterTable:
            return """
            ALTER TABLE \(context.primaryTable)
            ADD COLUMN new_column TEXT DEFAULT '';
            """
        }
    }

    func previewSetupSQL(interest: TutorInterest, context: TutorSQLContext) -> [String] {
        switch interest.lessonKind {
        case .selectWhereLimit:
            if context.orderColumn == context.metricColumn {
                return [
                    "CREATE TABLE \(context.primaryTable) (id INTEGER PRIMARY KEY, \(context.filterColumn) TEXT, \(context.metricColumn) INTEGER);",
                    "INSERT INTO \(context.primaryTable) (id, \(context.filterColumn), \(context.metricColumn)) VALUES (1, '\(escaped(context.filterValue))', 140);",
                    "INSERT INTO \(context.primaryTable) (id, \(context.filterColumn), \(context.metricColumn)) VALUES (2, '\(escaped(context.filterValue))', 100);",
                    "INSERT INTO \(context.primaryTable) (id, \(context.filterColumn), \(context.metricColumn)) VALUES (3, 'other', 45);"
                ]
            }
            return [
                "CREATE TABLE \(context.primaryTable) (id INTEGER PRIMARY KEY, \(context.filterColumn) TEXT, \(context.metricColumn) INTEGER, \(context.orderColumn) INTEGER);",
                "INSERT INTO \(context.primaryTable) (id, \(context.filterColumn), \(context.metricColumn), \(context.orderColumn)) VALUES (1, '\(escaped(context.filterValue))', 140, 140);",
                "INSERT INTO \(context.primaryTable) (id, \(context.filterColumn), \(context.metricColumn), \(context.orderColumn)) VALUES (2, '\(escaped(context.filterValue))', 100, 100);",
                "INSERT INTO \(context.primaryTable) (id, \(context.filterColumn), \(context.metricColumn), \(context.orderColumn)) VALUES (3, 'other', 45, 45);"
            ]

        case .joinAggregate:
            return [
                "CREATE TABLE \(context.secondaryTable) (\(context.joinSecondaryColumn) INTEGER PRIMARY KEY, \(context.dimensionColumn) TEXT, \(context.filterColumn) TEXT);",
                "CREATE TABLE \(context.primaryTable) (id INTEGER PRIMARY KEY, \(context.joinPrimaryColumn) INTEGER, \(context.metricColumn) INTEGER);",
                "INSERT INTO \(context.secondaryTable) (\(context.joinSecondaryColumn), \(context.dimensionColumn), \(context.filterColumn)) VALUES (1, 'alpha', '\(escaped(context.filterValue))');",
                "INSERT INTO \(context.secondaryTable) (\(context.joinSecondaryColumn), \(context.dimensionColumn), \(context.filterColumn)) VALUES (2, 'beta', 'other');",
                "INSERT INTO \(context.primaryTable) (id, \(context.joinPrimaryColumn), \(context.metricColumn)) VALUES (1, 1, 90);",
                "INSERT INTO \(context.primaryTable) (id, \(context.joinPrimaryColumn), \(context.metricColumn)) VALUES (2, 1, 60);",
                "INSERT INTO \(context.primaryTable) (id, \(context.joinPrimaryColumn), \(context.metricColumn)) VALUES (3, 2, 30);"
            ]

        case .groupHaving:
            return [
                "CREATE TABLE \(context.primaryTable) (id INTEGER PRIMARY KEY, \(context.dimensionColumn) TEXT, \(context.metricColumn) INTEGER, \(context.filterColumn) TEXT);",
                "INSERT INTO \(context.primaryTable) (id, \(context.dimensionColumn), \(context.metricColumn), \(context.filterColumn)) VALUES (1, 'group_a', 70, '\(escaped(context.filterValue))');",
                "INSERT INTO \(context.primaryTable) (id, \(context.dimensionColumn), \(context.metricColumn), \(context.filterColumn)) VALUES (2, 'group_a', 45, '\(escaped(context.filterValue))');",
                "INSERT INTO \(context.primaryTable) (id, \(context.dimensionColumn), \(context.metricColumn), \(context.filterColumn)) VALUES (3, 'group_b', 20, 'other');"
            ]

        case .subquery:
            return [
                "CREATE TABLE \(context.primaryTable) (id INTEGER PRIMARY KEY, \(context.dimensionColumn) TEXT, \(context.metricColumn) INTEGER, \(context.filterColumn) TEXT);",
                "INSERT INTO \(context.primaryTable) (id, \(context.dimensionColumn), \(context.metricColumn), \(context.filterColumn)) VALUES (1, 'segment_a', 150, '\(escaped(context.filterValue))');",
                "INSERT INTO \(context.primaryTable) (id, \(context.dimensionColumn), \(context.metricColumn), \(context.filterColumn)) VALUES (2, 'segment_b', 80, '\(escaped(context.filterValue))');",
                "INSERT INTO \(context.primaryTable) (id, \(context.dimensionColumn), \(context.metricColumn), \(context.filterColumn)) VALUES (3, 'segment_c', 30, 'other');"
            ]

        case .cte:
            return [
                "CREATE TABLE \(context.primaryTable) (id INTEGER PRIMARY KEY, \(context.dimensionColumn) TEXT, \(context.metricColumn) INTEGER, \(context.filterColumn) TEXT);",
                "INSERT INTO \(context.primaryTable) (id, \(context.dimensionColumn), \(context.metricColumn), \(context.filterColumn)) VALUES (1, 'segment_a', 120, '\(escaped(context.filterValue))');",
                "INSERT INTO \(context.primaryTable) (id, \(context.dimensionColumn), \(context.metricColumn), \(context.filterColumn)) VALUES (2, 'segment_a', 90, '\(escaped(context.filterValue))');",
                "INSERT INTO \(context.primaryTable) (id, \(context.dimensionColumn), \(context.metricColumn), \(context.filterColumn)) VALUES (3, 'segment_b', 40, 'other');"
            ]

        case .window:
            return [
                "CREATE TABLE \(context.primaryTable) (id INTEGER PRIMARY KEY, \(context.dimensionColumn) TEXT, \(context.metricColumn) INTEGER, \(context.filterColumn) TEXT);",
                "INSERT INTO \(context.primaryTable) (id, \(context.dimensionColumn), \(context.metricColumn), \(context.filterColumn)) VALUES (1, 'segment_a', 220, '\(escaped(context.filterValue))');",
                "INSERT INTO \(context.primaryTable) (id, \(context.dimensionColumn), \(context.metricColumn), \(context.filterColumn)) VALUES (2, 'segment_b', 140, '\(escaped(context.filterValue))');",
                "INSERT INTO \(context.primaryTable) (id, \(context.dimensionColumn), \(context.metricColumn), \(context.filterColumn)) VALUES (3, 'segment_c', 70, 'other');"
            ]

        case .createTable:
            return [] // No pre-existing tables needed — user creates from scratch

        case .insertInto:
            return [
                "CREATE TABLE \(context.primaryTable) (id INTEGER PRIMARY KEY, \(context.filterColumn) TEXT, \(context.metricColumn) INTEGER);"
            ]

        case .updateSet:
            return [
                "CREATE TABLE \(context.primaryTable) (id INTEGER PRIMARY KEY, \(context.filterColumn) TEXT, \(context.metricColumn) INTEGER);",
                "INSERT INTO \(context.primaryTable) (id, \(context.filterColumn), \(context.metricColumn)) VALUES (1, '\(escaped(context.filterValue))', 50);",
                "INSERT INTO \(context.primaryTable) (id, \(context.filterColumn), \(context.metricColumn)) VALUES (2, 'other', 30);",
                "INSERT INTO \(context.primaryTable) (id, \(context.filterColumn), \(context.metricColumn)) VALUES (3, '\(escaped(context.filterValue))', 75);"
            ]

        case .deleteFrom:
            return [
                "CREATE TABLE \(context.primaryTable) (id INTEGER PRIMARY KEY, \(context.filterColumn) TEXT, \(context.metricColumn) INTEGER);",
                "INSERT INTO \(context.primaryTable) (id, \(context.filterColumn), \(context.metricColumn)) VALUES (1, '\(escaped(context.filterValue))', 50);",
                "INSERT INTO \(context.primaryTable) (id, \(context.filterColumn), \(context.metricColumn)) VALUES (2, 'active', 80);",
                "INSERT INTO \(context.primaryTable) (id, \(context.filterColumn), \(context.metricColumn)) VALUES (3, '\(escaped(context.filterValue))', 20);"
            ]

        case .alterTable:
            return [
                "CREATE TABLE \(context.primaryTable) (id INTEGER PRIMARY KEY, \(context.filterColumn) TEXT, \(context.metricColumn) INTEGER);",
                "INSERT INTO \(context.primaryTable) (id, \(context.filterColumn), \(context.metricColumn)) VALUES (1, '\(escaped(context.filterValue))', 100);"
            ]
        }
    }

    private func foundationCommand(for interest: TutorInterest, context: TutorSQLContext) -> String? {
        switch interest.id {
        case "sql_intro_definition":
            return """
            SELECT \(context.filterColumn) AS data_model,
                   \(context.metricColumn) AS example_metric
            FROM \(context.primaryTable)
            WHERE \(context.filterColumn) = '\(escaped(context.filterValue))'
            ORDER BY \(context.orderColumn) DESC
            LIMIT 5;
            """
        case "sql_intro_schema":
            return """
            SELECT \(context.filterColumn) AS schema_element,
                   \(context.metricColumn) AS field_count
            FROM \(context.primaryTable)
            WHERE \(context.filterColumn) = '\(escaped(context.filterValue))'
            ORDER BY \(context.metricColumn) DESC
            LIMIT 5;
            """
        case "sql_intro_queries":
            return """
            SELECT \(context.metricColumn)
            FROM \(context.primaryTable)
            WHERE \(context.filterColumn) = '\(escaped(context.filterValue))'
            ORDER BY \(context.orderColumn) DESC
            LIMIT 10;
            """
        case "sql_intro_clauses":
            return """
            SELECT DISTINCT \(context.filterColumn) AS \(context.dimensionColumn)
            FROM \(context.primaryTable)
            ORDER BY \(context.filterColumn) ASC
            LIMIT 5;
            """
        case "sql_intro_variants":
            return """
            SELECT \(context.filterColumn) AS syntax_family,
                   \(context.metricColumn) AS compatibility_score
            FROM \(context.primaryTable)
            ORDER BY \(context.metricColumn) DESC
            LIMIT 5;
            """
        default:
            return nil
        }
    }

    private enum ProfessionDomain {
        case software
        case construction
        case general
    }

    private func resolveDomain(for profession: String) -> ProfessionDomain {
        let normalized = profession.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if normalized.contains("insaat")
            || normalized.contains("construction")
            || normalized.contains("isci")
            || normalized.contains("worker")
            || normalized.contains("santiye") {
            return .construction
        }
        if normalized.contains("bilgisayar")
            || normalized.contains("yazilim")
            || normalized.contains("software")
            || normalized.contains("developer")
            || normalized.contains("muhendis")
            || normalized.contains("engineer")
            || normalized.contains("backend")
            || normalized.contains("frontend") {
            return .software
        }
        return .general
    }

    private func makeContext(
        primaryTable: String,
        secondaryTable: String,
        metricColumn: String,
        dimensionColumn: String,
        filterColumn: String,
        filterValue: String,
        orderColumn: String,
        joinPrimaryColumn: String,
        joinSecondaryColumn: String
    ) -> TutorSQLContext {
        TutorSQLContext(
            primaryTable: sanitizeIdentifier(primaryTable, fallback: "activity_data"),
            secondaryTable: sanitizeIdentifier(secondaryTable, fallback: "dimension_data"),
            metricColumn: sanitizeIdentifier(metricColumn, fallback: "metric_value"),
            dimensionColumn: sanitizeIdentifier(dimensionColumn, fallback: "segment_name"),
            filterColumn: sanitizeIdentifier(filterColumn, fallback: "segment_type"),
            filterValue: sanitizeFilterValue(filterValue, fallback: "core"),
            orderColumn: sanitizeIdentifier(orderColumn, fallback: "metric_value"),
            joinPrimaryColumn: sanitizeIdentifier(joinPrimaryColumn, fallback: "dimension_id"),
            joinSecondaryColumn: sanitizeIdentifier(joinSecondaryColumn, fallback: "id")
        )
    }

    private func sanitizeIdentifier(_ raw: String?, fallback: String) -> String {
        guard let raw else { return fallback }
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()
        guard !normalized.isEmpty else { return fallback }
        let pattern = "^[a-z_][a-z0-9_]{0,47}$"
        guard normalized.range(of: pattern, options: .regularExpression) != nil else { return fallback }

        let forbiddenTokens: Set<String> = [
            "select", "drop", "delete", "insert", "update", "pragma", "attach",
            "detach", "vacuum", "alter", "create", "from", "where", "join", "with"
        ]
        let segments = Set(normalized.split(separator: "_").map(String.init))
        if !segments.isDisjoint(with: forbiddenTokens) {
            return fallback
        }
        return normalized
    }

    private func sanitizeFilterValue(_ raw: String?, fallback: String) -> String {
        guard let raw else { return fallback }
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "'", with: "")
            .lowercased()
        guard !normalized.isEmpty else { return fallback }
        return normalized
    }

    private func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            return nil
        }
        return String(text[start...end])
    }

    private func escaped(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}

private struct TutorContextPayload: Codable {
    let primaryTable: String?
    let secondaryTable: String?
    let metricColumn: String?
    let dimensionColumn: String?
    let filterColumn: String?
    let filterValue: String?
    let orderColumn: String?
    let joinPrimaryColumn: String?
    let joinSecondaryColumn: String?
}
