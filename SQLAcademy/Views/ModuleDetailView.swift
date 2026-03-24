import SwiftUI
import AudioToolbox

struct ModuleDetailView: View {
    let module: LearningModule

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localization: LocalizationService

    // MARK: - Phase

    enum Phase: Equatable {
        case intro          // Module intro: title, real-world use case, objectives, outcome
        case lesson         // Explanation + example queries combined
        case miniCheck      // First 2 "miniCheck" tagged questions (quick easy MC)
        case guidedExample  // Guided step-by-step walkthrough (if guidedSteps exist)
        case mainQuiz       // Remaining quiz questions (MC, dragFill, outputPrediction, errorDetection)
        case writingTask    // Writing challenges (up to 2)
        case summary        // Performance breakdown, score, key takeaways
    }

    @State private var phase: Phase = .intro
    @Environment(\.dismiss) private var dismiss

    // Writing task state (challenge 1)
    @State private var writingQuery = ""
    @State private var writingResult: SQLExecutionResult?
    @State private var writingFeedbackKey: String?
    @State private var writingPassed = false
    @State private var writingFailCount = 0

    // Writing task 2 state (challenge 2)
    @State private var writingTaskIndex = 0
    @State private var writingTask2Query = ""
    @State private var writingTask2Result: SQLExecutionResult?
    @State private var writingTask2FeedbackKey: String?
    @State private var writingTask2Passed = false

    // Quiz state (shared between miniCheck and mainQuiz)
    @State private var currentQuestionIndex = 0
    @State private var selectedOptionID: String?
    @State private var answeredCorrectly: Bool?
    @State private var answerResults: [Bool] = []

    // Separate score tracking
    @State private var miniCheckCorrectCount = 0
    @State private var mainQuizCorrectCount = 0
    @State private var quizScore = 0

    // Drag-fill state
    @State private var dragFillAnswers: [String?] = []
    @State private var dragFillChecked = false

    // Guided example state
    @State private var guidedStepIndex = 0

    // Answer animation state
    @State private var showConfetti = false

    private var isTR: Bool { localization.language == .tr }

    // Computed question sets
    private var miniCheckQuestions: [QuizQuestion] {
        module.quiz.filter { $0.questionTag == "miniCheck" }.prefix(2).map { $0 }
    }

    private var mainQuizQuestions: [QuizQuestion] {
        module.quiz.filter { $0.questionTag != "miniCheck" }
    }

    private var hasGuidedSteps: Bool {
        guard let steps = module.lesson.guidedSteps else { return false }
        return !steps.isEmpty
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AcademyBackground()
            VStack(spacing: 0) {
                phaseProgressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                Divider().opacity(0.3)
                phaseContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if showConfetti {
                ConfettiOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .navigationTitle(localization.text(module.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    // MARK: - Progress Bar

    private var currentStepIndex: Int {
        switch phase {
        case .intro:         return 0
        case .lesson:        return 1
        case .miniCheck:     return 2
        case .guidedExample: return 3
        case .mainQuiz:      return 4
        case .writingTask:   return 5
        case .summary:       return 6
        }
    }

    private var phaseProgressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<6, id: \.self) { idx in
                Capsule()
                    .fill(idx < currentStepIndex ? AppTheme.accent : (idx == currentStepIndex ? AppTheme.accent.opacity(0.6) : AppTheme.accent.opacity(0.14)))
                    .frame(height: 5)
                    .animation(.easeInOut(duration: 0.3), value: currentStepIndex)
            }
        }
    }

    // MARK: - Phase Router

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .intro:         introContent
        case .lesson:        lessonContent
        case .miniCheck:     miniCheckContent
        case .guidedExample: guidedExampleContent
        case .mainQuiz:      mainQuizContent
        case .writingTask:   writingTaskContent
        case .summary:       summaryContent
        }
    }

    // MARK: - Intro Phase

    private var introContent: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    // Header
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.accent.opacity(0.12))
                                .frame(width: 52, height: 52)
                            Image(systemName: "book.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(isTR ? "MODÜL GİRİŞİ" : "MODULE INTRO")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.accent)
                                .tracking(1.4)
                            Text(localization.text(module.titleKey))
                                .font(.title3.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }

                    // Real-world use case card
                    if let rwKey = module.lesson.realWorldUseCaseKey {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.yellow)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(isTR ? "Gerçek dünya kullanımı:" : "Real-world use:")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .tracking(0.4)
                                Text(localization.text(rwKey))
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.yellow.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                    }

                    // Objectives
                    VStack(alignment: .leading, spacing: 14) {
                        Text(isTR ? "Bu modülde öğreneceklerin" : "What you'll learn")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .tracking(0.5)

                        ForEach(module.lesson.objectiveKeys, id: \.self) { key in
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.accent.opacity(0.12))
                                        .frame(width: 30, height: 30)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppTheme.accent)
                                }
                                Text(localization.text(key))
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 6)
                            }
                        }
                    }

                    // Outcome banner
                    if let outcomeKey = module.lesson.outcomeKey {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.success)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(isTR ? "Bu modülden sonra:" : "After this module:")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppTheme.success.opacity(0.8))
                                Text(localization.text(outcomeKey))
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.success.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppTheme.success.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }

            stickyButton(
                label: isTR ? "Konuya Başla" : "Start Lesson",
                icon: "arrow.right"
            ) {
                phase = .lesson
            }
        }
    }

    // MARK: - Lesson Phase (explanation + examples combined)

    private var lessonContent: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {

                    // Header
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.accent.opacity(0.12))
                                .frame(width: 48, height: 48)
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(isTR ? "KONU ANLATIMI" : "LESSON")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.accent)
                                .tracking(1.4)
                            Text(localization.text(module.titleKey))
                                .font(.title3.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }

                    // Body text
                    Text(localization.text(module.lesson.bodyKey))
                        .font(.body)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineSpacing(6)

                    // Divider
                    Rectangle()
                        .fill(AppTheme.cardBorder.opacity(0.5))
                        .frame(height: 1)

                    // Example Queries section
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 10) {
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(AppTheme.accent)
                            Text(isTR ? "ÖRNEK SORGULAR" : "EXAMPLE QUERIES")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.accent)
                                .tracking(1.4)
                        }

                        ForEach(Array(module.lesson.exampleQueries.enumerated()), id: \.offset) { idx, example in
                            VStack(alignment: .leading, spacing: 10) {
                                Text("\(isTR ? "Örnek" : "Example") \(idx + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .tracking(0.5)

                                Text(example.sql)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .padding(18)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AppTheme.codeBlockBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(AppTheme.accent.opacity(0.22), lineWidth: 1)
                                    )

                                Text(localization.text(example.explanationKey))
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }

            stickyButton(
                label: isTR ? "Devam" : "Continue",
                icon: "arrow.right"
            ) {
                advanceFromLesson()
            }
        }
    }

    private func advanceFromLesson() {
        if !miniCheckQuestions.isEmpty {
            currentQuestionIndex = 0
            selectedOptionID = nil
            answeredCorrectly = nil
            answerResults = []
            dragFillAnswers = []
            dragFillChecked = false
            phase = .miniCheck
        } else if hasGuidedSteps {
            guidedStepIndex = 0
            phase = .guidedExample
        } else {
            startMainQuiz()
        }
    }

    // MARK: - Mini Check Phase

    private var miniCheckContent: some View {
        let questions = miniCheckQuestions

        return VStack(spacing: 0) {
            if questions.isEmpty {
                Spacer()
                Text(isTR ? "Mini kontrol sorusu bulunamadı." : "No mini-check questions found.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
            } else if currentQuestionIndex < questions.count {
                let question = questions[currentQuestionIndex]

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {

                        // Header
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.accent)
                                Text(isTR ? "HIZLI KONTROL" : "QUICK CHECK")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(AppTheme.accent)
                                    .tracking(1.4)
                                Spacer()
                                Text("\(currentQuestionIndex + 1)/\(questions.count)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Text(isTR ? "Isınmak için 2 kolay soru" : "2 easy questions to warm up")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)

                            // Mini progress capsules
                            HStack(spacing: 6) {
                                ForEach(0..<questions.count, id: \.self) { idx in
                                    Capsule()
                                        .fill(quizCapsuleColor(for: idx, in: answerResults))
                                        .frame(width: 32, height: 5)
                                }
                            }
                            .padding(.top, 2)
                        }

                        // Question prompt
                        Text(localization.text(question.promptKey))
                            .font(.title3.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)

                        // Options (MC only for miniCheck)
                        multipleChoiceOptions(question: question)

                        // Feedback
                        if let correct = answeredCorrectly {
                            quizFeedbackBanner(correct: correct, explanationKey: question.explanationKey)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 16)
                }

                // Next button
                if answeredCorrectly != nil {
                    if currentQuestionIndex + 1 < questions.count {
                        stickyButton(
                            label: isTR ? "Sonraki Soru" : "Next Question",
                            icon: "arrow.right"
                        ) {
                            currentQuestionIndex += 1
                            selectedOptionID = nil
                            answeredCorrectly = nil
                        }
                    } else {
                        // All mini-check done
                        stickyButton(
                            label: isTR ? "Harika! Devam Et" : "Great! Keep Going",
                            icon: "arrow.right"
                        ) {
                            advanceFromMiniCheck()
                        }
                    }
                }
            }
        }
    }

    private func advanceFromMiniCheck() {
        if hasGuidedSteps {
            guidedStepIndex = 0
            phase = .guidedExample
        } else {
            startMainQuiz()
        }
    }

    // MARK: - Guided Example Phase

    private var guidedExampleContent: some View {
        let steps = module.lesson.guidedSteps ?? []

        return VStack(spacing: 0) {
            if steps.isEmpty {
                Spacer()
                Text(isTR ? "Rehberli örnek bulunamadı." : "No guided steps found.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
            } else {
                let step = steps[guidedStepIndex]

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {

                        // Header
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppTheme.accent.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "map.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(AppTheme.accent)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(isTR ? "REHBERLİ ÖRNEK" : "GUIDED EXAMPLE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(AppTheme.accent)
                                    .tracking(1.4)
                                Text(isTR ? "Sorguyu adım adım oluştur" : "Follow the steps to build a query")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            Text("\(isTR ? "Adım" : "Step") \(guidedStepIndex + 1)/\(steps.count)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        // Step progress
                        HStack(spacing: 6) {
                            ForEach(0..<steps.count, id: \.self) { idx in
                                Capsule()
                                    .fill(idx <= guidedStepIndex ? AppTheme.accent : AppTheme.accent.opacity(0.18))
                                    .frame(height: 5)
                                    .animation(.easeInOut(duration: 0.25), value: guidedStepIndex)
                            }
                        }

                        // Step description
                        Text(localization.text(step.descriptionKey))
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)

                        // SQL code block
                        Text(step.sql)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.codeBlockBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }

                // Navigation buttons
                Divider().opacity(0.25)
                HStack(spacing: 12) {
                    if guidedStepIndex > 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                guidedStepIndex -= 1
                            }
                        } label: {
                            Label(isTR ? "Önceki" : "Previous", systemImage: "chevron.left")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GradientActionButtonStyle())
                    }

                    if guidedStepIndex + 1 < steps.count {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                guidedStepIndex += 1
                            }
                        } label: {
                            Label(isTR ? "Sonraki Adım" : "Next Step", systemImage: "chevron.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GradientActionButtonStyle())
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.28)) {
                                startMainQuiz()
                            }
                        } label: {
                            Label(isTR ? "Anladım!" : "Got it!", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GradientActionButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
    }

    private func startMainQuiz() {
        currentQuestionIndex = 0
        selectedOptionID = nil
        answeredCorrectly = nil
        answerResults = []
        dragFillAnswers = []
        dragFillChecked = false
        phase = .mainQuiz
    }

    // MARK: - Main Quiz Phase

    private var mainQuizContent: some View {
        let questions = mainQuizQuestions

        return VStack(spacing: 0) {
            if questions.isEmpty {
                Spacer()
                Text(isTR ? "Bu modülde soru bulunmuyor." : "No questions in this module.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
            } else if currentQuestionIndex < questions.count {
                let question = questions[currentQuestionIndex]

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {

                        // Progress header
                        VStack(spacing: 8) {
                            HStack(alignment: .center) {
                                Text("\(isTR ? "Soru" : "Question") \(currentQuestionIndex + 1)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("/ \(questions.count)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Spacer()
                            }
                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(AppTheme.cardBorder.opacity(0.3))
                                    Capsule()
                                        .fill(AppTheme.accent)
                                        .frame(width: geo.size.width * CGFloat(currentQuestionIndex + 1) / CGFloat(questions.count))
                                        .animation(.easeInOut(duration: 0.3), value: currentQuestionIndex)
                                }
                            }
                            .frame(height: 5)
                        }

                        // SQL Preview for errorDetection / outputPrediction
                        if let sqlPreview = question.sqlPreview {
                            let isError = question.questionTag == "errorDetection"
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: isError ? "exclamationmark.triangle.fill" : "eye.fill")
                                        .font(.caption.bold())
                                        .foregroundStyle(isError ? AppTheme.error : AppTheme.accent)
                                    Text(isError
                                         ? (isTR ? "Sorgudaki Hata" : "Error in Query")
                                         : (isTR ? "Çıktıyı Tahmin Et" : "Predict the Output"))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(isError ? AppTheme.error : AppTheme.accent)
                                        .tracking(1)
                                }
                                Text(sqlPreview)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AppTheme.codeBlockBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(isError ? AppTheme.error.opacity(0.4) : AppTheme.accent.opacity(0.3), lineWidth: 1.5)
                                    )
                            }
                        }

                        // Question prompt
                        Text(localization.text(question.promptKey))
                            .font(.title3.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)

                        if let df = question.dragFill {
                            dragFillView(df: df, explanationKey: question.explanationKey)
                        } else {
                            multipleChoiceOptions(question: question)

                            if let correct = answeredCorrectly {
                                quizFeedbackBanner(correct: correct, explanationKey: question.explanationKey)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 16)
                }
                .onAppear { initDragFill(for: questions[currentQuestionIndex]) }
                .onChange(of: currentQuestionIndex) { _, idx in
                    if idx < questions.count { initDragFill(for: questions[idx]) }
                }

                // Next button
                let canAdvance: Bool = {
                    if questions[currentQuestionIndex].dragFill != nil {
                        return dragFillChecked
                    } else {
                        return answeredCorrectly != nil
                    }
                }()
                if canAdvance {
                    stickyButton(
                        label: currentQuestionIndex + 1 < questions.count
                            ? (isTR ? "Sonraki Soru" : "Next Question")
                            : (isTR ? "Yazma Görevine Geç" : "Go to Writing Task"),
                        icon: "arrow.right"
                    ) {
                        if currentQuestionIndex + 1 < questions.count {
                            currentQuestionIndex += 1
                            selectedOptionID = nil
                            answeredCorrectly = nil
                        } else {
                            writingTaskIndex = 0
                            phase = .writingTask
                        }
                    }
                }
            }
        }
    }

    // MARK: - Writing Task Phase

    private var writingTaskContent: some View {
        let challenges = module.challenges
        let challengeIndex = writingTaskIndex
        let isSecondChallenge = challengeIndex == 1

        return VStack(spacing: 0) {
            if challenges.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "hammer")
                        .font(.title)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(isTR ? "Bu modülde yazma görevi bulunmuyor." : "No writing tasks in this module.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
                Spacer()
                stickyButton(
                    label: isTR ? "Sonuçları Gör" : "See Results",
                    icon: "chart.bar.fill"
                ) {
                    finishWritingAndSummarize()
                }
            } else if challengeIndex < challenges.count {
                let challenge = challenges[challengeIndex]
                let currentQuery: Binding<String> = isSecondChallenge ? $writingTask2Query : $writingQuery
                let currentResult: SQLExecutionResult? = isSecondChallenge ? writingTask2Result : writingResult
                let currentFeedbackKey: String? = isSecondChallenge ? writingTask2FeedbackKey : writingFeedbackKey
                let currentPassed: Bool = isSecondChallenge ? writingTask2Passed : writingPassed

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {

                        // Header
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(AppTheme.secondaryAccent.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "pencil.line")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(AppTheme.secondaryAccent)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(isTR ? "YAZMA GÖREVİ" : "WRITING TASK")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(AppTheme.secondaryAccent)
                                        .tracking(1.4)
                                    if challenges.count > 1 {
                                        Text("\(challengeIndex + 1)/\(min(challenges.count, 2))")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(AppTheme.secondaryAccent)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(AppTheme.secondaryAccent.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(localization.text(challenge.titleKey))
                                    .font(.title3.bold())
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                        }

                        // Task description
                        Text(localization.text(challenge.promptKey))
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineSpacing(5)

                        // Show setup table (so user can see the data)
                        if !challenge.setupSQL.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(isTR ? "TABLO VERİLERİ" : "TABLE DATA")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .tracking(1.2)
                                let service = SQLExecutionService()
                                let _ = try? service.reset(setupStatements: challenge.setupSQL)
                                let tableResult = try? service.execute("SELECT * FROM " + (challenge.validation.table ?? challenge.setupSQL.first(where: { $0.uppercased().contains("CREATE TABLE") }).flatMap { sql in
                                    let parts = sql.components(separatedBy: " ")
                                    if let idx = parts.firstIndex(where: { $0.uppercased() == "TABLE" }), idx + 1 < parts.count {
                                        return parts[idx + 1].replacingOccurrences(of: "(", with: "")
                                    }
                                    return nil
                                } ?? ""))
                                if let tableResult {
                                    SQLResultView(result: tableResult)
                                        .padding(10)
                                        .background(AppTheme.subtleSurface)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }

                        // Hint
                        HintToggleView(hintText: localization.text(challenge.hintKey))

                        // Progressive hints based on fail count
                        if writingFailCount >= 2 && !isSecondChallenge {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "lightbulb.max.fill")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryAccent)
                                    Text(isTR ? "Ek İpucu" : "Extra Hint")
                                        .font(.caption.bold())
                                        .foregroundStyle(AppTheme.secondaryAccent)
                                }
                                if writingFailCount >= 2 {
                                    Text(isTR
                                         ? "Doğru sütunları ve tablo adını kontrol et. \(challenge.validation.expectedColumns?.joined(separator: ", ") ?? "") sütunlarını döndürmen gerekiyor."
                                         : "Check your column names and table. You need to return: \(challenge.validation.expectedColumns?.joined(separator: ", ") ?? "")")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                if writingFailCount >= 3 {
                                    Text(isTR
                                         ? "Beklenen satır sayısı: \(challenge.validation.expectedRows?.count ?? 0)"
                                         : "Expected row count: \(challenge.validation.expectedRows?.count ?? 0)")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.secondaryAccent.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        // SQL Editor label
                        Text(isTR ? "SQL SORGUNUZ" : "YOUR SQL")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .tracking(1.2)

                        ZStack(alignment: .topLeading) {
                            if currentQuery.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(isTR ? "Sorgunuzu buraya yazın..." : "Write your query here...")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.25))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: currentQuery)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.92))
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 130)
                                .padding(8)
                        }
                        .background(AppTheme.codeEditorBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppTheme.accent.opacity(0.40), lineWidth: 1.5)
                        )

                        // Feedback banner
                        if let feedbackKey = currentFeedbackKey {
                            HStack(spacing: 10) {
                                Image(systemName: currentPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(currentPassed ? AppTheme.success : AppTheme.error)
                                    .font(.subheadline)
                                Text(localization.text(feedbackKey))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(currentPassed ? AppTheme.success : AppTheme.error)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background((currentPassed ? AppTheme.success : AppTheme.error).opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        // Result table
                        if let result = currentResult {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(isTR ? "SONUÇ" : "RESULT")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .tracking(1.2)
                                SQLResultView(result: result)
                            }
                            .padding(14)
                            .background(AppTheme.subtleSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }

                // Bottom actions
                Divider().opacity(0.25)
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Button {
                            if isSecondChallenge {
                                runWritingTask2(challenge: challenge)
                            } else {
                                runWritingTask(challenge: challenge)
                            }
                        } label: {
                            Label(isTR ? "Çalıştır" : "Run", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GradientActionButtonStyle())

                        Button {
                            if isSecondChallenge {
                                checkWritingTask2(challenge: challenge)
                            } else {
                                checkWritingTask(challenge: challenge)
                            }
                        } label: {
                            Label(isTR ? "Kontrol Et" : "Check", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GradientActionButtonStyle())
                    }

                    if currentPassed {
                        // Show next challenge or see results
                        if !isSecondChallenge && challenges.count > 1 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    writingTaskIndex = 1
                                }
                            } label: {
                                Label(isTR ? "Sonraki Göreve Geç" : "Try Next Challenge", systemImage: "arrow.right")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GradientActionButtonStyle())
                        } else {
                            Button {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    finishWritingAndSummarize()
                                }
                            } label: {
                                Label(isTR ? "Sonuçları Gör" : "See Results", systemImage: "chart.bar.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GradientActionButtonStyle())
                        }
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.28)) {
                                finishWritingAndSummarize()
                            }
                        } label: {
                            Text(isTR ? "Atla →" : "Skip →")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
    }

    private func finishWritingAndSummarize() {
        let miniTotal = miniCheckQuestions.count
        let mainTotal = mainQuizQuestions.count
        let total = miniTotal + mainTotal
        let correct = miniCheckCorrectCount + mainQuizCorrectCount
        quizScore = total > 0 ? Int(Double(correct) / Double(total) * 100) : 0
        appState.submitQuiz(moduleID: module.id, score: quizScore)
        phase = .summary
        if quizScore >= 70 {
            showConfetti = true
            // "New photo memory" celebration sound
            AudioServicesPlaySystemSound(1336)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showConfetti = false
            }
        }
    }

    // MARK: - Summary Phase

    private var summaryContent: some View {
        let miniTotal = miniCheckQuestions.count
        let mainTotal = mainQuizQuestions.count
        let totalQuestions = miniTotal + mainTotal
        let totalCorrect = miniCheckCorrectCount + mainQuizCorrectCount
        let passed = quizScore >= 70
        let excellent = quizScore >= 80

        return VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {

                    // Trophy / result icon
                    ZStack {
                        Circle()
                            .fill((passed ? AppTheme.success : AppTheme.error).opacity(0.12))
                            .frame(width: 100, height: 100)
                        Image(systemName: passed ? "trophy.fill" : "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(passed ? AppTheme.accent : AppTheme.error)
                    }
                    .padding(.top, 24)

                    // Title
                    VStack(spacing: 6) {
                        Text(isTR ? "Modül Tamamlandı" : "Module Complete")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(excellent
                             ? (isTR ? "Mükemmel! Bu konuya hakimsin." : "Excellent! You've mastered this topic.")
                             : passed
                                ? (isTR ? "Güzel çalışma! Biraz daha pratik yapabilirsin." : "Good effort! A bit more practice will help.")
                                : (isTR ? "Örnekleri tekrar gözden geçir ve dene." : "Review the examples and try again."))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Performance card
                    VStack(alignment: .leading, spacing: 16) {
                        Text(isTR ? "PERFORMANSIN" : "YOUR PERFORMANCE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .tracking(1.2)

                        // Quiz score row
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(isTR ? "Quiz Puanı" : "Quiz Score")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                if miniTotal > 0 {
                                    Text("\(isTR ? "Mini kontrol" : "Mini check"): \(miniCheckCorrectCount)/\(miniTotal)")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            Spacer()
                            Text("\(totalCorrect)/\(totalQuestions)")
                                .font(.title3.bold())
                                .foregroundStyle(passed ? AppTheme.success : AppTheme.error)
                        }

                        Divider().opacity(0.3)

                        // Writing task row
                        HStack {
                            Text(isTR ? "Yazma Görevi" : "Writing Task")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            let writingDone = writingPassed || writingTask2Passed
                            HStack(spacing: 4) {
                                Image(systemName: writingDone ? "checkmark.circle.fill" : "minus.circle.fill")
                                    .foregroundStyle(writingDone ? AppTheme.success : AppTheme.textSecondary)
                                Text(writingDone
                                     ? (isTR ? "Tamamlandı" : "Completed")
                                     : (isTR ? "Atlandı" : "Skipped"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(writingDone ? AppTheme.success : AppTheme.textSecondary)
                            }
                        }

                        Divider().opacity(0.3)

                        // Key takeaway
                        if let firstObj = module.lesson.objectiveKeys.first {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(isTR ? "Önemli Çıkarım" : "Key Takeaway")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .tracking(0.4)
                                Text(localization.text(firstObj))
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        // Score percentage bar
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(quizScore)%")
                                .font(.caption.bold())
                                .foregroundStyle(passed ? AppTheme.success : AppTheme.error)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(AppTheme.cardBorder.opacity(0.3))
                                        .frame(height: 8)
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(passed ? AppTheme.success : AppTheme.error)
                                        .frame(width: geo.size.width * CGFloat(quizScore) / 100.0, height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                    .padding(18)
                    .background(AppTheme.cardBackground.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppTheme.cardBorder.opacity(0.5), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
            }

            // Bottom buttons
            VStack(spacing: 10) {
                if passed {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        Label(isTR ? "Bitir" : "Finish", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GradientActionButtonStyle())
                } else {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.3)) { startMainQuiz() }
                    } label: {
                        Label(isTR ? "Quiz'i Tekrar Dene" : "Retry Quiz",
                              systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GradientActionButtonStyle())
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.3)) { resetAll() }
                } label: {
                    Text(isTR ? "Baştan Başla" : "Start Over")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.subtleSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                } label: {
                    Text(isTR ? "Modüllere Dön" : "Back to Modules")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Shared Multiple Choice Options

    @ViewBuilder
    private func multipleChoiceOptions(question: QuizQuestion) -> some View {
        VStack(spacing: 12) {
            // Invisible correct-flash overlay handled per option
            ForEach(question.options) { option in
                Button {
                    guard answeredCorrectly == nil else { return }
                    selectedOptionID = option.id
                    let correct = option.id == question.correctOptionID
                    answeredCorrectly = correct
                    answerResults.append(correct)
                    // Track to the right bucket
                    if question.questionTag == "miniCheck" {
                        if correct { miniCheckCorrectCount += 1 }
                    } else {
                        if correct { mainQuizCorrectCount += 1 }
                    }
                    // Haptic + sound
                    if correct {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        AudioServicesPlaySystemSound(1057) // ding
                    } else {
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(circleColor(optionID: option.id, correctID: question.correctOptionID))
                                .frame(width: 32, height: 32)
                            if let answered = answeredCorrectly, selectedOptionID == option.id {
                                Image(systemName: answered ? "checkmark" : "xmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            } else if answeredCorrectly != nil, option.id == question.correctOptionID {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            } else {
                                Text(option.id.uppercased())
                                    .font(.caption.bold())
                                    .foregroundStyle(selectedOptionID == option.id ? .white : AppTheme.textSecondary)
                            }
                        }
                        Text(localization.text(option.textKey))
                            .font(.subheadline)
                            .foregroundStyle(optionTextColor(optionID: option.id, correctID: question.correctOptionID))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(optionFill(optionID: option.id, correctID: question.correctOptionID))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(optionBorder(optionID: option.id, correctID: question.correctOptionID), lineWidth: answeredCorrectly != nil ? 0 : 1.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(answeredCorrectly != nil)
                .opacity(optionRowOpacity(optionID: option.id, correctID: question.correctOptionID))
                .animation(.easeOut(duration: 0.3), value: answeredCorrectly != nil)
            }
        }
    }

    // MARK: - Sticky Bottom Button

    @ViewBuilder
    private func stickyButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Divider().opacity(0.25)
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.28)) { action() }
        } label: {
            Label(label, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GradientActionButtonStyle())
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 28)
    }

    // MARK: - Drag-Fill

    private func initDragFill(for question: QuizQuestion) {
        guard let df = question.dragFill else {
            dragFillAnswers = []
            dragFillChecked = false
            return
        }
        let blankCount = df.template.components(separatedBy: "___").count - 1
        dragFillAnswers = Array(repeating: nil, count: blankCount)
        dragFillChecked = false
    }

    @ViewBuilder
    private func dragFillView(df: DragFillData, explanationKey: String) -> some View {
        let parts = df.template.components(separatedBy: "___")
        let blankCount = parts.count - 1
        let usedTokens = dragFillAnswers.compactMap { $0 }
        let isAllFilled = dragFillAnswers.allSatisfy { $0 != nil }
        let result: Bool? = dragFillChecked ? (dragFillAnswers.compactMap { $0 } == df.correctTokens) : nil

        VStack(alignment: .leading, spacing: 16) {
            // Code block with inline blanks
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    dragFillCodeBlock(parts: parts, blankCount: blankCount)
                }
            }
            .padding(14)
            .background(AppTheme.codeEditorBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Token chips
            if !dragFillChecked {
                dragFillTokenRow(df: df, usedTokens: usedTokens)
            }

            // Check button
            if isAllFilled && !dragFillChecked {
                Button(isTR ? "Kontrol Et" : "Check") {
                    let correct = dragFillAnswers.compactMap { $0 } == df.correctTokens
                    dragFillChecked = true
                    answeredCorrectly = correct
                    answerResults.append(correct)
                    mainQuizCorrectCount += correct ? 1 : 0
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(GradientActionButtonStyle())
            }

            // Feedback
            if let correct = result {
                quizFeedbackBanner(correct: correct, explanationKey: explanationKey)
            }
        }
    }

    @ViewBuilder
    private func dragFillCodeBlock(parts: [String], blankCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(buildCodeLines(parts: parts).enumerated()), id: \.offset) { _, line in
                HStack(spacing: 0) {
                    ForEach(Array(line.enumerated()), id: \.offset) { _, segment in
                        if segment.isBlank {
                            let idx = segment.blankIndex
                            blankBox(index: idx)
                        } else {
                            Text(segment.text)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
            }
        }
    }

    private struct CodeSegment {
        let text: String
        let isBlank: Bool
        let blankIndex: Int
    }

    private func buildCodeLines(parts: [String]) -> [[CodeSegment]] {
        var lines: [[CodeSegment]] = [[]]
        var blankIdx = 0
        for (i, part) in parts.enumerated() {
            let subLines = part.components(separatedBy: "\n")
            for (j, sub) in subLines.enumerated() {
                if j > 0 { lines.append([]) }
                if !sub.isEmpty {
                    lines[lines.count - 1].append(CodeSegment(text: sub, isBlank: false, blankIndex: -1))
                }
            }
            if i < parts.count - 1 {
                lines[lines.count - 1].append(CodeSegment(text: "", isBlank: true, blankIndex: blankIdx))
                blankIdx += 1
            }
        }
        return lines
    }

    @ViewBuilder
    private func blankBox(index: Int) -> some View {
        let placed = index < dragFillAnswers.count ? dragFillAnswers[index] : nil
        let borderColor: Color = {
            if dragFillChecked {
                if index < dragFillAnswers.count, dragFillAnswers[index] != nil {
                    return AppTheme.accent
                }
            }
            return placed != nil ? AppTheme.accent : AppTheme.accent.opacity(0.4)
        }()

        Button {
            guard !dragFillChecked, index < dragFillAnswers.count, dragFillAnswers[index] != nil else { return }
            dragFillAnswers[index] = nil
        } label: {
            Text(placed ?? "       ")
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundStyle(placed != nil ? AppTheme.accentDark : Color.clear)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(placed != nil ? AppTheme.accent.opacity(0.18) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(borderColor, style: StrokeStyle(lineWidth: 1.5, dash: placed == nil ? [4] : []))
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(dragFillChecked)
    }

    @ViewBuilder
    private func dragFillTokenRow(df: DragFillData, usedTokens: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isTR ? "Token'lara dokunarak boşlukları doldur" : "Tap tokens to fill the blanks")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 72, maximum: 160), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(df.tokens, id: \.self) { token in
                    let isUsed = usedTokens.contains(token) &&
                        (usedTokens.filter { $0 == token }.count >=
                         df.tokens.filter { $0 == token }.count)
                    Button {
                        guard !isUsed else { return }
                        if let emptyIdx = dragFillAnswers.firstIndex(where: { $0 == nil }) {
                            dragFillAnswers[emptyIdx] = token
                        }
                    } label: {
                        Text(token)
                            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                            .foregroundStyle(isUsed ? AppTheme.textSecondary : AppTheme.accentDark)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(isUsed
                                ? AppTheme.subtleSurface
                                : AppTheme.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(isUsed
                                        ? AppTheme.cardBorder
                                        : AppTheme.accent.opacity(0.4),
                                        lineWidth: 1.2)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isUsed)
                }
            }
        }
    }

    @ViewBuilder
    private func quizFeedbackBanner(correct: Bool, explanationKey: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(correct ? AppTheme.success : AppTheme.error)
                .font(.title3)
            VStack(alignment: .leading, spacing: 5) {
                Text(correct
                     ? (isTR ? "Doğru!" : "Correct!")
                     : (isTR ? "Yanlış" : "Wrong"))
                    .font(.subheadline.bold())
                    .foregroundStyle(correct ? AppTheme.success : AppTheme.error)
                Text(localization.text(explanationKey))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((correct ? AppTheme.success : AppTheme.error).opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Helpers

    private func resetAll() {
        writingQuery = ""
        writingResult = nil
        writingFeedbackKey = nil
        writingPassed = false
        writingTaskIndex = 0
        writingTask2Query = ""
        writingTask2Result = nil
        writingTask2FeedbackKey = nil
        writingTask2Passed = false
        currentQuestionIndex = 0
        selectedOptionID = nil
        answeredCorrectly = nil
        miniCheckCorrectCount = 0
        mainQuizCorrectCount = 0
        quizScore = 0
        answerResults = []
        dragFillAnswers = []
        dragFillChecked = false
        guidedStepIndex = 0
        phase = .intro
    }

    // Capsule color for quiz progress indicator
    private func quizCapsuleColor(for index: Int, in results: [Bool]) -> Color {
        if index < results.count {
            return results[index] ? AppTheme.success : AppTheme.error
        } else if index == currentQuestionIndex {
            return AppTheme.accentDark
        } else {
            return AppTheme.cardBorder.opacity(0.5)
        }
    }

    private func circleColor(optionID: String, correctID: String) -> Color {
        guard answeredCorrectly != nil else {
            return selectedOptionID == optionID ? AppTheme.accent : AppTheme.cardBorder.opacity(0.5)
        }
        if optionID == correctID { return .white.opacity(0.25) }
        if optionID == selectedOptionID { return .white.opacity(0.25) }
        return AppTheme.cardBorder.opacity(0.5)
    }

    private func optionFill(optionID: String, correctID: String) -> Color {
        guard answeredCorrectly != nil else {
            return selectedOptionID == optionID
                ? AppTheme.accent.opacity(0.12)
                : AppTheme.cardBackground.opacity(0.85)
        }
        if optionID == correctID { return AppTheme.accentDark }
        if optionID == selectedOptionID { return AppTheme.error }
        return AppTheme.cardBackground.opacity(0.85)
    }

    private func optionTextColor(optionID: String, correctID: String) -> Color {
        guard answeredCorrectly != nil else { return AppTheme.textPrimary }
        if optionID == correctID { return .white }
        if optionID == selectedOptionID { return .white }
        return AppTheme.textPrimary
    }

    private func optionRowOpacity(optionID: String, correctID: String) -> Double {
        guard answeredCorrectly != nil else { return 1.0 }
        if optionID == correctID { return 1.0 }
        if optionID == selectedOptionID { return 1.0 }
        return 0.4
    }

    private func optionBorder(optionID: String, correctID: String) -> Color {
        guard answeredCorrectly != nil else {
            return selectedOptionID == optionID
                ? AppTheme.accent.opacity(0.7)
                : AppTheme.cardBorder.opacity(0.6)
        }
        return .clear
    }

    // Writing task SQL helpers
    private func runWritingTask(challenge: SQLChallenge) {
        let service = SQLExecutionService()
        do {
            try service.reset(setupStatements: challenge.setupSQL)
            writingResult = try service.execute(writingQuery)
            writingFeedbackKey = nil
        } catch {
            writingFeedbackKey = "challenge.error"
            writingResult = nil
        }
    }

    private func checkWritingTask(challenge: SQLChallenge) {
        let service = SQLExecutionService()
        let outcome = appState.challengeEvaluator.evaluate(
            challenge: challenge, query: writingQuery, sqlService: service
        )
        writingFeedbackKey = outcome.messageKey
        writingResult = outcome.executionResult
        writingPassed = outcome.passed
        if outcome.passed {
            appState.completeChallenge(challenge)
        } else {
            writingFailCount += 1
        }
    }

    private func runWritingTask2(challenge: SQLChallenge) {
        let service = SQLExecutionService()
        do {
            try service.reset(setupStatements: challenge.setupSQL)
            writingTask2Result = try service.execute(writingTask2Query)
            writingTask2FeedbackKey = nil
        } catch {
            writingTask2FeedbackKey = "challenge.error"
            writingTask2Result = nil
        }
    }

    private func checkWritingTask2(challenge: SQLChallenge) {
        let service = SQLExecutionService()
        let outcome = appState.challengeEvaluator.evaluate(
            challenge: challenge, query: writingTask2Query, sqlService: service
        )
        writingTask2FeedbackKey = outcome.messageKey
        writingTask2Result = outcome.executionResult
        writingTask2Passed = outcome.passed
        if outcome.passed { appState.completeChallenge(challenge) }
    }
}

// MARK: - Confetti Overlay (burst from bottom)

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let angle: Double      // launch angle in radians
    let speed: Double       // launch speed
    let color: Color
    let size: CGFloat
    let spinRate: Double
    let initialRotation: Double
}

struct ConfettiOverlay: View {
    @State private var startDate: Date?
    private let pieces: [ConfettiPiece]
    private let gravity: Double = 900

    private static let colors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink, .mint, .cyan
    ]

    init() {
        pieces = (0..<100).map { _ in
            ConfettiPiece(
                angle: Double.random(in: -(.pi * 0.85)...(-(.pi * 0.15))),
                speed: Double.random(in: 600...1200),
                color: Self.colors.randomElement()!,
                size: CGFloat.random(in: 6...12),
                spinRate: Double.random(in: 4...12),
                initialRotation: Double.random(in: 0...(.pi * 2))
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = startDate.map { timeline.date.timeIntervalSince($0) } ?? 0
            Canvas { context, size in
                let originX = size.width / 2
                let originY = size.height
                for piece in pieces {
                    let t = elapsed
                    let vx = cos(piece.angle) * piece.speed
                    let vy = sin(piece.angle) * piece.speed
                    let px = originX + CGFloat(vx * t)
                    let py = originY + CGFloat(vy * t + 0.5 * gravity * t * t)
                    guard py > -20 && py < size.height + 40 && px > -20 && px < size.width + 20 else { continue }

                    // Fade out in last 0.5s
                    let alpha = min(1.0, max(0.0, (2.0 - t) / 0.5))
                    guard alpha > 0 else { continue }

                    let w = piece.size
                    let h = piece.size * 0.6
                    let rect = CGRect(x: px - w / 2, y: py - h / 2, width: w, height: h)
                    var xform = CGAffineTransform.identity
                    xform = xform.translatedBy(x: rect.midX, y: rect.midY)
                    xform = xform.rotated(by: piece.initialRotation + t * piece.spinRate)
                    xform = xform.translatedBy(x: -rect.midX, y: -rect.midY)

                    let path = Path(roundedRect: rect, cornerRadius: 2).applying(xform)
                    context.fill(path, with: .color(piece.color.opacity(alpha)))
                }
            }
        }
        .onAppear { startDate = Date() }
        .allowsHitTesting(false)
    }
}
