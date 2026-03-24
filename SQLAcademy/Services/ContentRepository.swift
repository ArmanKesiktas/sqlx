import Foundation

final class ContentRepository {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func loadModules() -> [LearningModule] {
        guard let url = resourceURL(forResource: "modules", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let modules = try? JSONDecoder().decode([LearningModule].self, from: data) else {
            return []
        }
        return modules.sorted { $0.order < $1.order }
    }

    func loadCareerPaths() -> [CareerPath] {
        guard let url = resourceURL(forResource: "career_paths", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let paths = try? JSONDecoder().decode([CareerPath].self, from: data) else {
            return []
        }
        return paths
    }

    func loadModulesWithBonusChallenges(bonusCount: Int = 30) -> [LearningModule] {
        let modules = loadModules()
        guard !modules.isEmpty, bonusCount > 0 else { return modules }

        let bonus = bonusChallenges(using: modules, count: bonusCount)
        let groupedBonus = Dictionary(grouping: bonus, by: \.moduleID)

        return modules.map { module in
            LearningModule(
                id: module.id,
                order: module.order,
                level: module.level,
                titleKey: module.titleKey,
                descriptionKey: module.descriptionKey,
                lesson: module.lesson,
                quiz: module.quiz,
                challenges: module.challenges + (groupedBonus[module.id] ?? [])
            )
        }
    }

    func badges() -> [Badge] {
        [
            Badge(id: "first_challenge", titleKey: "badge.firstChallenge.title", descriptionKey: "badge.firstChallenge.desc", rule: .firstChallenge),
            Badge(id: "five_challenges", titleKey: "badge.fiveChallenges.title", descriptionKey: "badge.fiveChallenges.desc", rule: .fiveChallenges),
            Badge(id: "ten_challenges", titleKey: "badge.tenChallenges.title", descriptionKey: "badge.tenChallenges.desc", rule: .tenChallenges),
            Badge(id: "twenty_challenges", titleKey: "badge.twentyChallenges.title", descriptionKey: "badge.twentyChallenges.desc", rule: .twentyChallenges),
            Badge(id: "first_module", titleKey: "badge.firstModule.title", descriptionKey: "badge.firstModule.desc", rule: .firstModule),
            Badge(id: "three_modules", titleKey: "badge.threeModules.title", descriptionKey: "badge.threeModules.desc", rule: .threeModules),
            Badge(id: "all_modules", titleKey: "badge.allModules.title", descriptionKey: "badge.allModules.desc", rule: .allModules),
            Badge(id: "seven_day_streak", titleKey: "badge.sevenDayStreak.title", descriptionKey: "badge.sevenDayStreak.desc", rule: .sevenDayStreak),
            Badge(id: "fourteen_day_streak", titleKey: "badge.fourteenDayStreak.title", descriptionKey: "badge.fourteenDayStreak.desc", rule: .fourteenDayStreak),
            Badge(id: "thirty_day_streak", titleKey: "badge.thirtyDayStreak.title", descriptionKey: "badge.thirtyDayStreak.desc", rule: .thirtyDayStreak),
            Badge(id: "five_hundred_points", titleKey: "badge.fiveHundredPoints.title", descriptionKey: "badge.fiveHundredPoints.desc", rule: .fiveHundredPoints),
            Badge(id: "thousand_points", titleKey: "badge.thousandPoints.title", descriptionKey: "badge.thousandPoints.desc", rule: .thousandPoints),
            Badge(id: "two_thousand_points", titleKey: "badge.twoThousandPoints.title", descriptionKey: "badge.twoThousandPoints.desc", rule: .twoThousandPoints),
            Badge(id: "first_tutor_lesson", titleKey: "badge.firstTutorLesson.title", descriptionKey: "badge.firstTutorLesson.desc", rule: .firstTutorLesson),
            Badge(id: "first_exam", titleKey: "badge.firstExam.title", descriptionKey: "badge.firstExam.desc", rule: .firstExam)
        ]
    }

    func practiceSetupSQL() -> [String] {
        practiceSampleSetupSQL(for: .ecommerce)
    }

    func practiceBlankSetupSQL() -> [String] {
        []
    }

    func practiceSampleSetupSQL(for sample: PracticeSampleDataset) -> [String] {
        switch sample {
        case .ecommerce:
            return [
                """
                CREATE TABLE customers (
                    id INTEGER PRIMARY KEY,
                    name TEXT,
                    city TEXT
                );
                """,
                """
                CREATE TABLE orders (
                    id INTEGER PRIMARY KEY,
                    customer_id INTEGER,
                    total REAL
                );
                """,
                "INSERT INTO customers (id, name, city) VALUES (1, 'Ada', 'Istanbul');",
                "INSERT INTO customers (id, name, city) VALUES (2, 'Lina', 'Ankara');",
                "INSERT INTO customers (id, name, city) VALUES (3, 'Mark', 'Izmir');",
                "INSERT INTO orders (id, customer_id, total) VALUES (1, 1, 120.0);",
                "INSERT INTO orders (id, customer_id, total) VALUES (2, 1, 80.0);",
                "INSERT INTO orders (id, customer_id, total) VALUES (3, 2, 150.0);"
            ]

        case .software:
            return [
                """
                CREATE TABLE services (
                    id INTEGER PRIMARY KEY,
                    name TEXT,
                    team TEXT
                );
                """,
                """
                CREATE TABLE incidents (
                    id INTEGER PRIMARY KEY,
                    service_id INTEGER,
                    severity TEXT,
                    response_minutes INTEGER
                );
                """,
                "INSERT INTO services (id, name, team) VALUES (1, 'auth', 'backend');",
                "INSERT INTO services (id, name, team) VALUES (2, 'payments', 'backend');",
                "INSERT INTO services (id, name, team) VALUES (3, 'search', 'platform');",
                "INSERT INTO incidents (id, service_id, severity, response_minutes) VALUES (1, 1, 'high', 34);",
                "INSERT INTO incidents (id, service_id, severity, response_minutes) VALUES (2, 1, 'low', 14);",
                "INSERT INTO incidents (id, service_id, severity, response_minutes) VALUES (3, 2, 'high', 56);",
                "INSERT INTO incidents (id, service_id, severity, response_minutes) VALUES (4, 3, 'medium', 41);"
            ]

        case .construction:
            return [
                """
                CREATE TABLE sites (
                    id INTEGER PRIMARY KEY,
                    name TEXT,
                    city TEXT
                );
                """,
                """
                CREATE TABLE tasks (
                    id INTEGER PRIMARY KEY,
                    site_id INTEGER,
                    task_type TEXT,
                    duration_minutes INTEGER
                );
                """,
                "INSERT INTO sites (id, name, city) VALUES (1, 'project_a', 'Istanbul');",
                "INSERT INTO sites (id, name, city) VALUES (2, 'project_b', 'Ankara');",
                "INSERT INTO tasks (id, site_id, task_type, duration_minutes) VALUES (1, 1, 'concrete', 220);",
                "INSERT INTO tasks (id, site_id, task_type, duration_minutes) VALUES (2, 1, 'safety_check', 45);",
                "INSERT INTO tasks (id, site_id, task_type, duration_minutes) VALUES (3, 2, 'concrete', 195);"
            ]
        }
    }

    func tutorPackages() -> [TutorPackage] {
        [
            TutorPackage(
                id: "data_analytics",
                titleKey: "tutor.package.analytics.title",
                descriptionKey: "tutor.package.analytics.desc",
                icon: "chart.line.uptrend.xyaxis",
                interests: [
                    TutorInterest(
                        id: "sql_intro_definition",
                        titleKey: "tutor.interest.sqlIntro.definition.title",
                        descriptionKey: "tutor.interest.sqlIntro.definition.desc",
                        tableName: "database_concepts",
                        selectColumn: "concept_score",
                        whereColumn: "concept_group",
                        whereValue: "relational",
                        orderColumn: "concept_score"
                    ),
                    TutorInterest(
                        id: "sql_intro_schema",
                        titleKey: "tutor.interest.sqlIntro.schema.title",
                        descriptionKey: "tutor.interest.sqlIntro.schema.desc",
                        tableName: "schema_elements",
                        selectColumn: "field_count",
                        whereColumn: "entity_type",
                        whereValue: "table",
                        orderColumn: "field_count"
                    ),
                    TutorInterest(
                        id: "sql_intro_queries",
                        titleKey: "tutor.interest.sqlIntro.queries.title",
                        descriptionKey: "tutor.interest.sqlIntro.queries.desc",
                        tableName: "relational_queries",
                        selectColumn: "query_count",
                        whereColumn: "query_type",
                        whereValue: "basic_select",
                        orderColumn: "query_count"
                    ),
                    TutorInterest(
                        id: "sql_intro_clauses",
                        titleKey: "tutor.interest.sqlIntro.clauses.title",
                        descriptionKey: "tutor.interest.sqlIntro.clauses.desc",
                        tableName: "clause_usage",
                        selectColumn: "usage_score",
                        whereColumn: "clause_group",
                        whereValue: "core",
                        orderColumn: "usage_score"
                    ),
                    TutorInterest(
                        id: "sql_intro_variants",
                        titleKey: "tutor.interest.sqlIntro.variants.title",
                        descriptionKey: "tutor.interest.sqlIntro.variants.desc",
                        tableName: "sql_engines",
                        selectColumn: "compatibility_score",
                        whereColumn: "engine_family",
                        whereValue: "mainstream",
                        orderColumn: "compatibility_score"
                    )
                ]
            ),
            TutorPackage(
                id: "dml_operations",
                titleKey: "tutor.package.dml.title",
                descriptionKey: "tutor.package.dml.desc",
                icon: "square.and.pencil",
                interests: [
                    TutorInterest(
                        lessonKind: .createTable,
                        id: "create_table_basics",
                        titleKey: "tutor.interest.dml.createTable.title",
                        descriptionKey: "tutor.interest.dml.createTable.desc",
                        tableName: "new_table",
                        selectColumn: "id",
                        whereColumn: "status",
                        whereValue: "active",
                        orderColumn: "id"
                    ),
                    TutorInterest(
                        lessonKind: .insertInto,
                        id: "insert_fundamentals",
                        titleKey: "tutor.interest.dml.insert.title",
                        descriptionKey: "tutor.interest.dml.insert.desc",
                        tableName: "records",
                        selectColumn: "id",
                        whereColumn: "category",
                        whereValue: "new",
                        orderColumn: "id"
                    ),
                    TutorInterest(
                        lessonKind: .updateSet,
                        id: "update_fundamentals",
                        titleKey: "tutor.interest.dml.update.title",
                        descriptionKey: "tutor.interest.dml.update.desc",
                        tableName: "records",
                        selectColumn: "value",
                        whereColumn: "status",
                        whereValue: "pending",
                        orderColumn: "value"
                    ),
                    TutorInterest(
                        lessonKind: .deleteFrom,
                        id: "delete_fundamentals",
                        titleKey: "tutor.interest.dml.delete.title",
                        descriptionKey: "tutor.interest.dml.delete.desc",
                        tableName: "records",
                        selectColumn: "id",
                        whereColumn: "status",
                        whereValue: "archived",
                        orderColumn: "id"
                    ),
                    TutorInterest(
                        lessonKind: .alterTable,
                        id: "alter_table_basics",
                        titleKey: "tutor.interest.dml.alter.title",
                        descriptionKey: "tutor.interest.dml.alter.desc",
                        tableName: "existing_table",
                        selectColumn: "id",
                        whereColumn: "type",
                        whereValue: "standard",
                        orderColumn: "id"
                    )
                ]
            ),
            TutorPackage(
                id: "intermediate_sql",
                titleKey: "tutor.package.intermediate.title",
                descriptionKey: "tutor.package.intermediate.desc",
                icon: "link",
                interests: [
                    TutorInterest(
                        lessonKind: .joinAggregate,
                        id: "join_fundamentals",
                        titleKey: "tutor.interest.intermediate.join.title",
                        descriptionKey: "tutor.interest.intermediate.join.desc",
                        tableName: "joined_metrics",
                        selectColumn: "metric_value",
                        whereColumn: "segment_type",
                        whereValue: "core",
                        orderColumn: "metric_value"
                    ),
                    TutorInterest(
                        lessonKind: .groupHaving,
                        id: "group_having",
                        titleKey: "tutor.interest.intermediate.group.title",
                        descriptionKey: "tutor.interest.intermediate.group.desc",
                        tableName: "group_metrics",
                        selectColumn: "metric_value",
                        whereColumn: "segment_type",
                        whereValue: "core",
                        orderColumn: "metric_value"
                    ),
                    TutorInterest(
                        lessonKind: .joinAggregate,
                        id: "aggregate_patterns",
                        titleKey: "tutor.interest.intermediate.aggregate.title",
                        descriptionKey: "tutor.interest.intermediate.aggregate.desc",
                        tableName: "aggregate_metrics",
                        selectColumn: "metric_value",
                        whereColumn: "segment_type",
                        whereValue: "core",
                        orderColumn: "metric_value"
                    )
                ]
            ),
            TutorPackage(
                id: "senior_sql",
                titleKey: "tutor.package.senior.title",
                descriptionKey: "tutor.package.senior.desc",
                icon: "cpu",
                interests: [
                    TutorInterest(
                        lessonKind: .subquery,
                        id: "subquery_design",
                        titleKey: "tutor.interest.senior.subquery.title",
                        descriptionKey: "tutor.interest.senior.subquery.desc",
                        tableName: "subquery_metrics",
                        selectColumn: "metric_value",
                        whereColumn: "segment_type",
                        whereValue: "core",
                        orderColumn: "metric_value"
                    ),
                    TutorInterest(
                        lessonKind: .cte,
                        id: "cte_workflow",
                        titleKey: "tutor.interest.senior.cte.title",
                        descriptionKey: "tutor.interest.senior.cte.desc",
                        tableName: "cte_metrics",
                        selectColumn: "metric_value",
                        whereColumn: "segment_type",
                        whereValue: "core",
                        orderColumn: "metric_value"
                    ),
                    TutorInterest(
                        lessonKind: .window,
                        id: "window_functions",
                        titleKey: "tutor.interest.senior.window.title",
                        descriptionKey: "tutor.interest.senior.window.desc",
                        tableName: "window_metrics",
                        selectColumn: "metric_value",
                        whereColumn: "segment_type",
                        whereValue: "core",
                        orderColumn: "metric_value"
                    )
                ]
            )
        ]
    }

    private func bonusChallenges(using modules: [LearningModule], count: Int) -> [SQLChallenge] {
        guard !modules.isEmpty else { return [] }

        return (1...count).map { index in
            let module = modules[(index - 1) % modules.count]
            let challengeID = "bonus_\(module.id)_\(index)"
            let tableName = "bonus_dataset_\(index)"
            let isDeleteChallenge = index % 3 == 0

            if isDeleteChallenge {
                return SQLChallenge(
                    id: challengeID,
                    moduleID: module.id,
                    titleKey: "Ek Görev / Bonus Challenge \(String(format: "%02d", index))",
                    promptKey: "Ek görev: category = 'obsolete' satırlarını sil ve tabloda 2 satır bırak. / Delete obsolete rows and keep 2 rows.",
                    setupSQL: [
                        "CREATE TABLE \(tableName) (id INTEGER PRIMARY KEY, category TEXT, score INTEGER);",
                        "INSERT INTO \(tableName) (id, category, score) VALUES (1, 'focus', 92);",
                        "INSERT INTO \(tableName) (id, category, score) VALUES (2, 'obsolete', 15);",
                        "INSERT INTO \(tableName) (id, category, score) VALUES (3, 'focus', 77);"
                    ],
                    starterSQL: "DELETE FROM \(tableName) WHERE category = 'obsolete';",
                    validation: ChallengeValidation(
                        type: .tableRowCount,
                        expectedColumns: nil,
                        expectedRows: nil,
                        table: tableName,
                        expectedCount: 2
                    ),
                    hintKey: "İpucu: DELETE FROM ... WHERE category = 'obsolete'; / Hint: use DELETE + WHERE.",
                    points: 40 + ((index % 5) * 10)
                )
            }

            let targetCategory = index % 2 == 0 ? "focus" : "core"
            let expectedTopID = index % 2 == 0 ? "2" : "1"
            return SQLChallenge(
                id: challengeID,
                moduleID: module.id,
                titleKey: "Ek Görev / Bonus Challenge \(String(format: "%02d", index))",
                promptKey: "Ek görev: category = '\(targetCategory)' için en yüksek score değerine sahip id satırını getir. / Return id with highest score for '\(targetCategory)'.",
                setupSQL: [
                    "CREATE TABLE \(tableName) (id INTEGER PRIMARY KEY, category TEXT, score INTEGER);",
                    "INSERT INTO \(tableName) (id, category, score) VALUES (1, 'core', 95);",
                    "INSERT INTO \(tableName) (id, category, score) VALUES (2, 'focus', 99);",
                    "INSERT INTO \(tableName) (id, category, score) VALUES (3, 'focus', 42);",
                    "INSERT INTO \(tableName) (id, category, score) VALUES (4, 'core', 55);"
                ],
                starterSQL: "SELECT id FROM \(tableName) WHERE category = '\(targetCategory)' ORDER BY score DESC LIMIT 1;",
                validation: ChallengeValidation(
                    type: .queryResult,
                    expectedColumns: ["id"],
                    expectedRows: [[expectedTopID]],
                    table: nil,
                    expectedCount: nil
                ),
                hintKey: "İpucu: WHERE + ORDER BY score DESC + LIMIT 1 / Hint: filter, sort, limit.",
                points: 40 + ((index % 5) * 10)
            )
        }
    }

    private func resourceURL(forResource name: String, withExtension ext: String) -> URL? {
        for bundle in resourceBundles() {
            if let url = bundle.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    private func resourceBundles() -> [Bundle] {
        var bundles: [Bundle] = [
            bundle,
            .main,
            Bundle(for: ResourceBundleMarker.self)
        ]
        bundles.append(contentsOf: Bundle.allBundles)
        bundles.append(contentsOf: Bundle.allFrameworks)

        var seen: Set<String> = []
        return bundles.filter { candidate in
            let path = candidate.bundleURL.path
            if seen.contains(path) {
                return false
            }
            seen.insert(path)
            return true
        }
    }
}

private final class ResourceBundleMarker {}
