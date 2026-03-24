# SQLX (SQLAcademy) Project Analysis Report

This document provides a comprehensive overview of the **SQLX (SQLAcademy)** project architecture, structure, and functionality. It is designed to help AI agents (and developers) quickly onboard and understand the codebase.

## 1. Project Overview

**SQLX** (internal name: `SQLAcademy`) is an iOS application designed to teach SQL through interactive gamified learning, integrated with an AI tutor. The application allows users to write and execute SQL queries against local mock datasets, earn badges/points, and chat with an AI for guidance. 

The project consists of two main parts:
1. **Frontend**: A native iOS application built with SwiftUI (`SQLAcademy`).
2. **Backend**: A server-side Swift application built with the Vapor framework (`backend`).

---

## 2. Directory Structure

```text
/Users/arman/Desktop/sqlx
├── backend/                   # Vapor backend (Server-Side Swift)
│   ├── Package.swift          # Swift Package Manager definition
│   └── Sources/App/           # Backend application code (routes, configuration)
├── SQLAcademy/                # Native iOS Application
│   ├── App/                   # App entry points and global state (SQLAcademyApp, AppState)
│   ├── Models/                # Data models
│   ├── ViewModels/            # UI logic and view states
│   ├── Views/                 # SwiftUI Views
│   ├── Services/              # Core business logic, APIs, and persistence
│   └── Resources/             # Assets, JSON configs, Entitlements
├── project.yml                # XcodeGen configuration to generate the .xcodeproj
└── QA_MARKET_REPORT_...md     # Market report/QA notes
```

---

## 3. Backend Architecture (`backend/`)

The backend is built with **Vapor 4** and serves primarily as an authentication gateway and a proxy for AI generation, hiding sensitive API keys from the iOS client.

### Key Components:
- **`configure.swift` & `routes.swift`**: Defines the configuration (reading from `Environment`) and the API routes under `/v1/`.
- **Authentication (`/v1/auth/apple`)**: 
  - Receives an Apple Identity Token from the iOS client.
  - Validates it using `jwt-kit`.
  - Issues a custom access token (JWT/Bearer) via `AccessTokenStore`.
- **AI Proxy (`/v1/ai/generate`)**: 
  - Requires Bearer token authorization.
  - Receives `systemPrompt` and `userPrompt`.
  - Forwards the request to the configured AI provider (Google Gemini API via `GeminiAPIClient`).
  - Returns the generated text response back to the client.

This design ensures the `GEMINI_API_KEY` remains strictly on the server.

---

## 4. iOS App Architecture (`SQLAcademy/`)

The iOS app uses **SwiftUI** with a centralized state pattern (similar to Redux or global EnvironmentObject). 

### 4.1 State Management
- `AppState.swift`: The central source of truth, implemented as an `@MainActor final class AppState: ObservableObject`.
- It holds all in-memory arrays of `modules`, `badges`, `tutorPackages`, and the `UserProgress` object.
- Functions inside `AppState` act as mutations (e.g., `completeChallenge`, `startExam`, `handleAppleSignIn`).

### 4.2 Data Storage and Persistence
- `ProgressStore.swift`: Handles saving the `UserProgress` struct locally overriding `UserDefaults`.
- `BackupSyncService.swift`: Allows syncing progress to and from iCloud. It can export and import JSON payloads.
- **Content is Static**: `ContentRepository.swift` loads learning materials statically. `modules` are loaded from `modules.json` (inside `Resources`), while Tutor Packages and SQL setups (e.g., `ecommerce`, `software`, `construction` mock datasets) are defined directly in Swift code.

### 4.3 Core Services
- **`AITutorAPIService.swift`**: Contacts the Vapor backend. Handles Apple Auth login (`/v1/auth/apple`) and subsequent authenticated AI prompt generation requests (`/v1/ai/generate`). Stores Session JWTs in the Keychain.
- **`ExamEngineService.swift`**: Manages the logic for taking mock exams based on modules and challenges.
- **`ChallengeEvaluationService.swift`**: Interprets the user's SQL inputs.
- **`CertificateService.swift`**: Generates PDF certificates for users who pass Tutor Mastery levels or exams.
- **`RetentionService.swift`**: Manages spaced repetition features ("Daily Review / Retentions") and Daily Missions. 

### 4.4 Build System
The project uses **XcodeGen**. The `project.yml` file defines the targets (`SQLAcademy`, `SQLAcademyTests`, `SQLAcademyUITests`), deployment target (`iOS 17.0`), configurations, and `Info.plist` properties (such as injecting `AI_BACKEND_BASE_URL` locally).

---

## 5. Main Workflows

### 5.1 Onboarding & Authentication
1. The app boots into `AuthEntryView` or `PostAuthOnboardingView`.
2. User signs in with Apple (or skips as local guest).
3. If Apple Sign-in is used, `AppState` triggers `AITutorAPIService` which sends the identity token to the Vapor backend.
4. Backend issues an access token, enabling the AI Tutor feature.

### 5.2 Learning & Challenges
1. `RootTabView` provides navigation to Learn, Practice, Tutor, and Profile views.
2. In practice mode, users are given a prompt and a local SQLite dataset (created via `ContentRepository.swift` SQL commands).
3. The user executes SQL. The results are shown in a `SharedSQLResultView`.
4. Tests are validated by comparing query results or row counts. Points and badges are updated in `AppState` and persisted via `ProgressStore`.

### 5.3 AI Tutor interaction
1. Within a learning module or practice scene, users can interact with the AI Tutor.
2. `AITutorAPIService` uses the proxy backend to send customized system/user prompts to the Gemini model.
3. The responses are streamed/returned and surfaced in the tutor chat view.

---

## 6. Recommendations for Agents Contributing to this Codebase

- **UI Updates**: Keep purely presentational changes within the `Views/` directory. Use `@EnvironmentObject var appState: AppState` instead of passing heavy state through `init`.
- **Backend API Additions**: Any new backend endpoints should be added to `backend/Sources/App/routes.swift`. If adding new environment variables, update `BackendConfiguration` in `configure.swift`.
- **Database/Content Addition**: Do not look for a remote DB for courses. Content is inside `ContentRepository.swift` or `modules.json`. To add a new exam or tutor package, edit `ContentRepository.swift`.
- **State Modifications**: Always add logic to manipulate `UserProgress` inside `AppState.swift` methods, do not bypass it. This guarantees that `persistProgress()` is called and iCloud + UserDefaults stay correctly synced.

---
**Date Analyzed**: 2026-03-18
**Analyzed by**: Antigravity Assistant
