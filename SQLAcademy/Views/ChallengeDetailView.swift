import SwiftUI

struct ChallengeDetailView: View {
    let challenge: SQLChallenge

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localization: LocalizationService

    @State private var query: String
    @State private var feedbackKey: String?
    @State private var result: SQLExecutionResult?

    init(challenge: SQLChallenge) {
        self.challenge = challenge
        _query = State(initialValue: "")
    }

    var body: some View {
        ZStack {
            AcademyBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    AcademyCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(localization.text(challenge.titleKey))
                                .academyTitleStyle()
                            Text(localization.text(challenge.promptKey))
                                .font(.subheadline)
                            HintToggleView(hintText: localization.text(challenge.hintKey))
                        }
                    }

                    AcademyCard {
                        ZStack(alignment: .topLeading) {
                            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(localization.text("challenge.editorPlaceholder"))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 18)
                            }

                            TextEditor(text: $query)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(AppTheme.textPrimary)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 160)
                                .padding(8)
                                .background(AppTheme.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppTheme.accent.opacity(0.25), lineWidth: 1)
                                )
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            runPreview()
                        } label: {
                            Label(localization.text("challenge.run"), systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GradientActionButtonStyle())

                        Button {
                            checkSolution()
                        } label: {
                            Label(localization.text("challenge.check"), systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GradientActionButtonStyle())
                    }

                    AcademyCard {
                        if let feedbackKey {
                            Text(localization.text(feedbackKey))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(feedbackKey == "challenge.pass" ? AppTheme.success : AppTheme.error)
                        }

                        if let result {
                            SQLResultView(result: result)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(localization.text("tab.challenges"))
        .toolbar(.visible, for: .navigationBar)
    }

    private func checkSolution() {
        let service = SQLExecutionService()
        let outcome = appState.challengeEvaluator.evaluate(challenge: challenge, query: query, sqlService: service)
        feedbackKey = outcome.messageKey
        result = outcome.executionResult
        if outcome.passed {
            appState.completeChallenge(challenge)
        }
    }

    private func runPreview() {
        let service = SQLExecutionService()
        do {
            try service.reset(setupStatements: challenge.setupSQL)
            result = try service.execute(query)
            feedbackKey = nil
        } catch {
            feedbackKey = "challenge.error"
            result = nil
        }
    }
}
