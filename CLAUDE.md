# SQLAcademy (SQLx) - Project Context

## Overview
iOS SQL learning app built with SwiftUI. Bundle ID: `com.arman.sqlacademy`.
Preparing for App Store submission.

## Architecture
- **UI**: SwiftUI with `@EnvironmentObject` for `AppState` and `LocalizationService`
- **Theme**: `AppTheme` static color tokens via `ThemePalette` struct (light/dark)
- **Data**: JSON-based module content (`modules.json`), career paths (`career_paths.json`), localization via `strings_{lang}.json`
- **Languages**: en, tr, de, es, fr, ar, pt (7 languages)
- **SQL Engine**: `SQLExecutionService` wrapping SQLite for in-app query execution
- **Evaluation**: `ChallengeEvaluationService` for validating user SQL queries
- **Subscriptions**: StoreKit 2 integration
- **Project Gen**: XcodeGen (`project.yml`) — run `xcodegen generate` after adding files

## Tab Structure (5 tabs)
1. **Home** - Continue learning, quick stats
2. **Learn** - Module cards list
3. **Career** - Career path selection & progress (replaced Practice tab)
4. **Challenges** - SQL writing challenges
5. **Profile** - Settings, stats, account

## Module System (7-Phase Learning Flow)
1. **intro** - Title, real-world use case, objectives, outcome
2. **lesson** - Explanation + example queries
3. **miniCheck** - 2 quick MC questions (tagged `questionTag: "miniCheck"`)
4. **guidedExample** - Step-by-step walkthrough (if `guidedSteps` exist)
5. **mainQuiz** - MC, dragFill, outputPrediction, errorDetection questions
6. **writingTask** - Up to 2 SQL writing challenges with progressive hints
7. **summary** - Performance breakdown, score, confetti on pass (>=70%)

## Career Path System
- 6 paths: Data Analyst, BI Analyst, Backend Dev, Data Engineer, Product Analyst, Interview Prep
- Each path maps to a curated subset of the 12 modules
- Progressive module locking (must complete previous to unlock next)
- Milestone system with achievements at module count thresholds
- Path completion celebration overlay with trophy + sound
- Data: `career_paths.json`, Model: `CareerPath` + `CareerMilestone` in AppModels

## Modules (12 total)
m1_select_basics, m2_filter_sort, m3_modify_data, m4_schema_ops, m5_join_basics, m6_groupby_having, m7_subqueries, m8_mini_project, m9_case_when, m10_union, m11_cte, m12_window_functions

## Key Files
- `SQLAcademy/Views/ModuleDetailView.swift` - Main module flow (7 phases) + ConfettiOverlay
- `SQLAcademy/Views/CareerPathListView.swift` - Career path selection screen
- `SQLAcademy/Views/CareerPathDetailView.swift` - Career path detail + progress + milestones
- `SQLAcademy/Views/RootTabView.swift` - Main tab bar (5 tabs)
- `SQLAcademy/Views/HomeView.swift` - Home tab
- `SQLAcademy/Views/LearnView.swift` - Learn tab with module cards
- `SQLAcademy/Views/ChallengesView.swift` - Challenges tab
- `SQLAcademy/Views/ProfileView.swift` - Profile/settings tab
- `SQLAcademy/Views/AppTheme.swift` - Color tokens and theme
- `SQLAcademy/Views/SharedSQLResultView.swift` - SQL result table + hint toggle
- `SQLAcademy/App/AppState.swift` - Global state, progress, iCloud sync
- `SQLAcademy/Models/AppModels.swift` - Core data models
- `SQLAcademy/Services/ContentRepository.swift` - Data loading (modules, career paths, badges)
- `SQLAcademy/Resources/modules.json` - Module content data
- `SQLAcademy/Resources/career_paths.json` - Career path definitions
- `SQLAcademy/Resources/strings_*.json` - Localization files

## Build
```bash
xcodebuild -scheme SQLAcademy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## UI Conventions
- Button styles: `GradientActionButtonStyle()` for primary actions
- Cards: `AcademyCard { }` wrapper with `AppTheme.cardBackground`
- Section titles: `AcademySectionTitle(title:symbol:)`
- Option cards: solid `AppTheme.accentDark` (green) for correct, `AppTheme.error` (red) for wrong, white text
- Unselected options dim to 0.4 opacity after answering
- Hints: orange dropdown style (`Color(red: 0.90, green: 0.55, blue: 0.10)`)
- Writing task editor: `AppTheme.codeEditorBackground` (always dark), white text
- Confetti: Canvas-based burst-from-bottom particle overlay (2 seconds, 100 pieces)
- Haptic: light impact on all buttons, success/error notification on correct/wrong answers
- Sounds: SystemSound 1057 (ding) on correct answer, 1336 on module/path completion

## User Preferences
- User prefers Turkish (primary language for the app)
- Terse responses, no unnecessary summaries
- No shake/bounce animations (feels artificial)
- Keep hint dropdowns simple with orange color
- Progressive hints for writing tasks (extra help after 2+ failures)
- Challenges tab stays (user explicitly said "challenges kalkmayacak")
- Practice (live SQL lab) tab removed, replaced with Career
