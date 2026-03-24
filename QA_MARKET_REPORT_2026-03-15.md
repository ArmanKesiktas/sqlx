# SQLX QA + Market Report

Date: 2026-03-15
Workspace: `/Users/arman/Desktop/sqlx`

## Scope

This report covers:

- local functional verification of the current iOS app
- product strengths and weaknesses from a QA perspective
- current market scan of mobile SQL learning competitors
- recommended product changes and additions

## Test Method

Verified locally with:

- `xcodebuild test -scheme SQLAcademy -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'`

Observed result:

- `29` unit/integration tests passed
- `1` UI test passed
- full automated suite passed on 2026-03-15

Files relevant to verification:

- `SQLAcademyTests/*`
- `SQLAcademyUITests/SQLAcademyUITests.swift`

## What Was Functionally Verified

- onboarding state persistence
- local progress save/load
- badge and streak logic
- module completion threshold at `>= 80`
- multi-question quiz score calculation
- tutor package progress and legacy migration
- practice mode dataset switching
- SQL single statement execution
- SQL multi-statement script execution
- forbidden statement blocking
- challenge evaluation rules
- localization fallback and quiz-flow keys
- app launch and tab bar visibility

## What Was Not Fully Verified End-to-End

- live Gemini API response quality in production conditions
- real Apple Sign In credential lifecycle with a real user account
- full user journey UI automation for Learn, Practice, Challenges, Tutor, and Profile
- accessibility behavior with VoiceOver / Dynamic Type / reduced motion
- low-network, no-network, and API-failure UX on physical devices
- performance under long SQL results and long tutor conversations

## QA Findings

### 1. Critical (Resolved in Sprint 1): Gemini API key was shipped in app configuration

Evidence:

- historical: `project.yml` had `INFOPLIST_KEY_GEMINI_API_KEY` before Sprint 1 hardening

Impact:

- the API key can be extracted from the app bundle
- quota abuse and billing risk
- production release blocker

Recommendation:

- remove the key from client bundle (done in Sprint 1)
- move AI access behind a backend or signed token broker (done with Vapor proxy + access token)

### 2. High: UI automation coverage is too shallow

Current state:

- only one UI test exists
- it checks launch, optional onboarding skip, and tab bar existence

Impact:

- recent regressions like scroll conflicts, onboarding state bugs, challenge flow issues, and input handling can ship unnoticed

Recommendation:

- add UI tests for:
  - onboarding complete path
  - language switch
  - Learn package open and chat start
  - Practice query run and reset
  - Challenge search/filter/open/submit
  - Profile reset flow

### 3. High: Premium branding is ahead of product reality

Current state:

- `AI Native Egitim Plus` is visible
- there is no real gated premium feature set, billing flow, entitlement system, or subscription state

Impact:

- value proposition feels unclear
- users may interpret the label as fake or unfinished

Recommendation:

- either remove premium framing for now
- or ship a real premium package with clear unlocked benefits

### 4. Medium: Tutor completion still depends too much on confirmation, not mastery

Current state:

- tutor lesson completion happens when user reaches the approval/completed phase
- not when the user proves command understanding across varied prompts

Impact:

- completion can overstate learning
- progression quality is weaker than it looks

Recommendation:

- require mini check steps after tutor explanation
- add 2-3 applied questions or query edits before marking lesson complete

### 5. Medium: Home and Learn contain dead affordances

Current state:

- `View more` elements are styled like interactive controls but are plain text in some sections

Impact:

- polish issue
- users may tap non-functional UI

Recommendation:

- make them buttons with real destinations
- or restyle them as passive labels

### 6. Medium: SQL lab is good for learning, but limited for advanced learners

Current state:

- safety model allows `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `CREATE`, `DROP`, `ALTER`, `WITH`
- blocks sensitive keywords
- runs in-memory SQLite only

Impact:

- strong beginner safety
- but advanced learners may hit limitations quickly

Recommendation:

- keep beginner-safe mode
- add an advanced sandbox mode with explicit warnings and richer SQL coverage

### 7. Medium: No recovery/sync path for serious users

Current state:

- progress is device-local
- Apple Sign In is local-only, without backend sync

Impact:

- reinstall/device-change loses learning continuity
- this is acceptable for MVP, weak for retention

Recommendation:

- add optional cloud sync in a later phase
- at minimum add export/import for local progress backup

### 8. Low: Typewriter tutor effect may become slow in real usage

Current state:

- tutor messages render character-by-character

Impact:

- visually nice
- can become frustrating for long responses or accessibility users

Recommendation:

- keep the effect for short replies
- auto-skip animation for longer messages or when Reduce Motion is enabled

## Product Strengths

- strong offline-first architecture
- native SwiftUI implementation, not a web wrapper
- localized TR/EN base is already in place
- SQL lab runs on-device and supports sample datasets plus blank DB
- tutor differentiates by adapting examples to profession context
- challenge search/filter exists already
- automated logic coverage for core services is solid
- recent classic modules quiz flow is materially better than one-shot completion

## Product Weaknesses

- premium story is not operational yet
- no certificate, portfolio, interview, or job-readiness layer
- weak automated coverage for real user flows
- no reminders, daily mission loop, or habit engine beyond streak storage
- no social/community layer
- AI feature safety and economics are not production-ready
- no strong differentiation yet in advanced SQL or hiring outcomes

## Market Snapshot

### Broad coding-app competitors

#### Mimo

Observed from App Store and official site:

- structured learning paths across SQL and other languages
- AI-assisted learning/build workflow
- mobile IDE
- certificates
- streaks and leaderboards
- project/portfolio framing

Sources:

- https://apps.apple.com/us/app/mimo-learn-coding-programming/id1133960732
- https://mimo.org/courses/learn-sql
- https://mimo.org/certifications/sql-certification

#### Sololearn

Observed from App Store and official course page:

- large course catalog
- strong community angle
- AI support
- spaced repetition and learning-science positioning
- large user base
- visible monetization friction in user reviews

Sources:

- https://apps.apple.com/us/app/sololearn-learn-to-code/id1210079064
- https://www.sololearn.com/en/learn/courses/sql-introduction

#### DataCamp

Observed from App Store and official site:

- data-first brand
- daily 5-minute challenges
- mobile practice with real-time feedback
- large course library
- SQL certification path
- stronger career-readiness signal than general coding apps

Sources:

- https://apps.apple.com/us/app/datacamp-learn-coding-ai/id1263413087
- https://www.datacamp.com/mobile
- https://www.datacamp.com/certification/sql-associate/

### SQL-only / mobile-first niche competitors

#### SQL Practice

Observed positioning:

- SQL-only
- daily practice
- instant feedback
- streak motivation

Sources:

- https://sqlpractice.app/
- https://apps.apple.com/us/app/sql-practice-learn-database/id6749337619

#### SQL Prep

Observed positioning:

- interview prep
- daily challenges
- 500+ challenges
- AI hints
- streaks, XP, reminders, and leaderboard-style game loop

Source:

- https://apps.apple.com/us/app/sql-prep/id6752492649

## Market Conclusions

The market leaders cluster around four patterns:

- bite-sized daily learning
- practical exercises with instant feedback
- progression systems like streaks, XP, leaderboards, or certificates
- career framing such as interview prep, projects, or certification

SQLX already has one real differentiator:

- profession-contextual SQL teaching in Turkish, inside a native offline iOS product

But it is currently behind the market in four areas:

- career signal
- habit/retention loops
- community or competitive motivation
- production-grade AI and premium infrastructure

## Highest-Value Additions

### P0

- remove client-side Gemini key and proxy AI through backend
- expand UI automation to full main flows
- add crash/error telemetry
- make all dead affordances either functional or visually passive

### P1

- add daily missions, reminders, and weekly learning goals
- add topic mastery engine with larger question banks and spaced repetition
- add real post-tutor competency checks before completion
- add detailed challenge hints, partial scoring, and stepwise validation

### P2

- add interview mode
- add exam mode
- add shareable completion certificates
- add role-based paths:
  - data analyst
  - backend developer
  - product / ops analyst

### P3

- add community explanations or solution discussions
- add leaderboard / friend streaks
- add cloud sync and multi-device continuity
- add advanced SQL sandbox with optional unsafe-mode controls

## What I Would Change First

If the goal is product-market fit rather than just feature count, the best next sequence is:

1. secure AI architecture
2. deepen learning quality in tutor + quizzes
3. build a real daily retention loop
4. add interview/certificate value
5. only then introduce real premium monetization

## Recommendation Summary

SQLX should not try to beat Mimo or Sololearn at being a general coding app.

It should position itself as:

- the native mobile SQL coach
- Turkish-first, but globally usable
- strong on practical querying
- strong on role-contextual examples
- strong on interview and analyst/backend preparation

That is the cleanest path to a defensible product.
