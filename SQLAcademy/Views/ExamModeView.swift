import SwiftUI

struct ExamModeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localization: LocalizationService

    @Environment(\.dismiss) private var dismiss

    @State private var selectedLevel: ExamLevel = .beginner
    @State private var currentQuestionIndex = 0
    @State private var writingAnswer = ""
    @State private var now = Date()
    @State private var didAutoFinish = false
    @State private var showExitConfirmation = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AcademyBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(localization.text("exam.title"))
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineSpacing(-6)
                        .minimumScaleFactor(0.8)

                    if let session = appState.currentExamSession {
                        activeExamView(session)
                    } else {
                        startExamView
                    }

                    if let attempt = appState.lastExamAttempt {
                        resultCard(attempt)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(appState.currentExamSession != nil)
        .toolbar {
            if appState.currentExamSession != nil {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showExitConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text(localization.text("module.back"))
                        }
                        .font(.subheadline.weight(.medium))
                    }
                }
            }
        }
        .alert(localization.text("exam.exitTitle"), isPresented: $showExitConfirmation) {
            Button(localization.text("exam.exitConfirm"), role: .destructive) {
                appState.cancelExam()
                currentQuestionIndex = 0
                writingAnswer = ""
                dismiss()
            }
            Button(localization.text("exam.exitCancel"), role: .cancel) {}
        } message: {
            Text(localization.text("exam.exitMessage"))
        }
        .onReceive(timer) { tick in
            now = tick
            guard appState.currentExamSession != nil else { return }
            let remaining = appState.remainingExamSeconds(now: tick)
            guard remaining == 0, !didAutoFinish else { return }
            didAutoFinish = true
            appState.finishExam()
            currentQuestionIndex = 0
            writingAnswer = ""
        }
        .onChange(of: appState.currentExamSession?.id) { _, newValue in
            now = Date()
            didAutoFinish = false
            if newValue == nil {
                currentQuestionIndex = 0
                writingAnswer = ""
            }
        }
    }

    private var startExamView: some View {
        AcademyCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(localization.text("exam.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)

                Picker(localization.text("exam.level"), selection: $selectedLevel) {
                    ForEach(ExamLevel.allCases) { level in
                        Text(localizedLevel(level)).tag(level)
                    }
                }
                .pickerStyle(.segmented)

                Button(localization.text("exam.start")) {
                    appState.startExam(level: selectedLevel)
                    currentQuestionIndex = 0
                    writingAnswer = ""
                    didAutoFinish = false
                    now = Date()
                }
                .buttonStyle(GradientActionButtonStyle())
            }
        }
    }

    private func activeExamView(_ session: ExamSession) -> some View {
        Group {
            if session.questions.indices.contains(currentQuestionIndex) {
                let question = session.questions[currentQuestionIndex]
                let remaining = appState.remainingExamSeconds(now: now)
                let answeredCount = session.questions.reduce(0) { partial, question in
                    let answer = session.answers[question.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return partial + (answer.isEmpty ? 0 : 1)
                }
                let progressValue = session.questions.isEmpty ? 0 : Double(answeredCount) / Double(session.questions.count)
                let totalSeconds = max(1, Int(session.endAt.timeIntervalSince(session.startedAt)))
                let remainingRatio = Double(max(0, remaining)) / Double(totalSeconds)
                let selectedAnswer = session.answers[question.id]

                VStack(spacing: 12) {
                    AcademyCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Label(localization.text("exam.remaining"), systemImage: "timer")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Spacer()
                                Text(format(seconds: remaining))
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundStyle(remaining < 180 ? AppTheme.rose : AppTheme.textPrimary)
                            }

                            ProgressView(value: remainingRatio)
                                .tint(remaining < 180 ? AppTheme.rose : AppTheme.accentDark)

                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 8) {
                                    examMetricCard(
                                        icon: "list.number",
                                        title: localization.text("exam.metricQuestion"),
                                        value: "\(currentQuestionIndex + 1)/\(session.questions.count)"
                                    )
                                    examMetricCard(
                                        icon: "timer",
                                        title: localization.text("exam.metricRemaining"),
                                        value: format(seconds: remaining),
                                        isUrgent: remaining < 180
                                    )
                                    examMetricCard(
                                        icon: "checkmark.circle",
                                        title: localization.text("exam.metricAnswered"),
                                        value: "\(answeredCount)/\(session.questions.count)"
                                    )
                                }

                                VStack(spacing: 8) {
                                    examMetricCard(
                                        icon: "list.number",
                                        title: localization.text("exam.metricQuestion"),
                                        value: "\(currentQuestionIndex + 1)/\(session.questions.count)"
                                    )
                                    examMetricCard(
                                        icon: "timer",
                                        title: localization.text("exam.metricRemaining"),
                                        value: format(seconds: remaining),
                                        isUrgent: remaining < 180
                                    )
                                    examMetricCard(
                                        icon: "checkmark.circle",
                                        title: localization.text("exam.metricAnswered"),
                                        value: "\(answeredCount)/\(session.questions.count)"
                                    )
                                }
                            }

                            ProgressView(value: progressValue)
                                .tint(AppTheme.accentDark)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(session.questions.enumerated()), id: \.offset) { index, indexedQuestion in
                                let answer = session.answers[indexedQuestion.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                Button {
                                    currentQuestionIndex = index
                                    writingAnswer = session.answers[indexedQuestion.id] ?? ""
                                } label: {
                                    Text("\(index + 1)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(questionMarkerTextColor(index: index, isAnswered: !answer.isEmpty))
                                        .frame(width: 34, height: 34)
                                        .background(questionMarkerBackground(index: index, isAnswered: !answer.isEmpty))
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(questionMarkerBorderColor(index: index, isAnswered: !answer.isEmpty), lineWidth: 1.2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
                    }

                    AcademyCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(question.kind == .multipleChoice ? localization.text("exam.multipleChoice") : localization.text("exam.sqlWriting"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Spacer()
                            }

                            Text(question.prompt)
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)

                            if question.kind == .multipleChoice {
                                VStack(spacing: 10) {
                                    ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                                        Button {
                                            appState.submitExamAnswer(questionID: question.id, answer: option)
                                        } label: {
                                            HStack(spacing: 10) {
                                                Text("\(optionLabel(for: index)).")
                                                    .font(.caption.weight(.semibold))
                                                Text(option)
                                                    .multilineTextAlignment(.leading)
                                                Spacer()
                                                if selectedAnswer == option {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(AppTheme.accentDark)
                                                }
                                            }
                                            .foregroundStyle(AppTheme.textPrimary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 14)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(selectedAnswer == option ? AppTheme.accentSoft.opacity(0.32) : AppTheme.inputBackground)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(selectedAnswer == option ? AppTheme.accentDark : AppTheme.cardBorder, lineWidth: 1.2)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            } else {
                                TextEditor(text: Binding(
                                    get: {
                                        session.answers[question.id] ?? writingAnswer
                                    },
                                    set: { value in
                                        writingAnswer = value
                                        appState.submitExamAnswer(questionID: question.id, answer: value)
                                    }
                                ))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(AppTheme.textPrimary)
                                .frame(minHeight: 140)
                                .padding(10)
                                .background(AppTheme.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                                )
                            }

                            HStack {
                                if currentQuestionIndex > 0 {
                                    Button(localization.text("module.previous")) {
                                        currentQuestionIndex -= 1
                                        let previousID = session.questions[currentQuestionIndex].id
                                        writingAnswer = session.answers[previousID] ?? ""
                                    }
                                    .buttonStyle(SolidGreenActionButtonStyle())
                                }

                                Spacer()

                                if currentQuestionIndex < session.questions.count - 1 {
                                    Button(localization.text("module.next")) {
                                        currentQuestionIndex += 1
                                        let nextID = session.questions[currentQuestionIndex].id
                                        writingAnswer = session.answers[nextID] ?? ""
                                    }
                                    .buttonStyle(GradientActionButtonStyle())
                                } else {
                                    Button(localization.text("exam.finish")) {
                                        appState.finishExam()
                                        currentQuestionIndex = 0
                                        writingAnswer = ""
                                    }
                                    .buttonStyle(GradientActionButtonStyle())
                                }
                            }
                        }
                    }
                }
            } else {
                AcademyCard {
                    Text(localization.text("exam.noQuestion"))
                }
            }
        }
    }

    private func resultCard(_ attempt: ExamAttempt) -> some View {
        AcademyCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(localization.text("exam.resultTitle"))
                    .font(.headline)
                Text("\(localization.text("module.score")): \(attempt.score)%")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(attempt.passed ? AppTheme.accentDark : AppTheme.rose)
                Text(String(format: localization.text("exam.correctCount"), attempt.correctCount, attempt.questionCount))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Text(attempt.passed ? localization.text("exam.passed") : localization.text("exam.failed"))
                    .font(.subheadline.weight(.semibold))
                if !attempt.weakTopicIDs.isEmpty {
                    Text(localization.text("exam.weakTopics"))
                        .font(.subheadline.weight(.semibold))
                    ForEach(attempt.weakTopicIDs, id: \.self) { topic in
                        Text("• \(topic)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
    }

    private func examMetricCard(icon: String, title: String, value: String, isUrgent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .multilineTextAlignment(.leading)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(isUrgent ? AppTheme.rose : AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(isUrgent ? AppTheme.rose.opacity(0.14) : AppTheme.subtleSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isUrgent ? AppTheme.rose.opacity(0.45) : AppTheme.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func questionMarkerBackground(index: Int, isAnswered: Bool) -> Color {
        if currentQuestionIndex == index {
            return AppTheme.accentDark
        }
        return isAnswered ? AppTheme.accentSoft.opacity(0.55) : AppTheme.capsuleBackground
    }

    private func questionMarkerBorderColor(index: Int, isAnswered: Bool) -> Color {
        if currentQuestionIndex == index {
            return AppTheme.accentDark
        }
        return isAnswered ? AppTheme.buttonBorderLight : AppTheme.cardBorder
    }

    private func questionMarkerTextColor(index: Int, isAnswered: Bool) -> Color {
        if currentQuestionIndex == index {
            return .white
        }
        return isAnswered ? AppTheme.accentDark : AppTheme.textSecondary
    }

    private func localizedLevel(_ level: ExamLevel) -> String {
        switch level {
        case .beginner:
            return localization.text("exam.level.beginner")
        case .intermediate:
            return localization.text("exam.level.intermediate")
        case .senior:
            return localization.text("exam.level.senior")
        }
    }

    private func format(seconds: Int) -> String {
        let minutes = seconds / 60
        let rem = seconds % 60
        return String(format: "%02d:%02d", minutes, rem)
    }

    private func optionLabel(for index: Int) -> String {
        String(Character(UnicodeScalar(65 + index) ?? Unicode.Scalar("A")))
    }
}
