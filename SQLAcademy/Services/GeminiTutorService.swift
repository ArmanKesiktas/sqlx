import Foundation

protocol TutorAIProviding: Sendable {
    func generate(systemPrompt: String, messages: [TutorChatMessage]) async -> String?
}

actor GeminiTutorService {
    private let aiTutorAPIService: AITutorAPIService
    private let directGeminiAPIKey: String?
    private let directGeminiModel: String
    private let session: URLSession

    init(
        aiTutorAPIService: AITutorAPIService = AITutorAPIService(),
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo,
        session: URLSession = .shared
    ) {
        self.aiTutorAPIService = aiTutorAPIService
        let envKey = processInfo.environment["GEMINI_API_KEY"]?.trimmedNonEmpty
        let plistKey = (bundle.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String)?.trimmedNonEmpty
        let hardcodedTestingKey = "AIzaSyDs4mIDWGpmn9bNiOWP6RrxiTUoQ76Idko"
        self.directGeminiAPIKey = envKey ?? plistKey ?? hardcodedTestingKey
        let envModel = processInfo.environment["GEMINI_MODEL"]?.trimmedNonEmpty
        let plistModel = (bundle.object(forInfoDictionaryKey: "GEMINI_MODEL") as? String)?.trimmedNonEmpty
        self.directGeminiModel = envModel ?? plistModel ?? "gemini-flash-latest"
        self.session = session
    }

    var isConfigured: Bool {
        get async {
            await aiTutorAPIService.isConfigured || directGeminiAPIKey != nil
        }
    }

    func generate(systemPrompt: String, messages: [TutorChatMessage]) async -> String? {
        if let text = await aiTutorAPIService.generate(systemPrompt: systemPrompt, messages: messages) {
            return text
        }
        return await generateDirectGemini(systemPrompt: systemPrompt, messages: messages)
    }

    private func generateDirectGemini(systemPrompt: String, messages: [TutorChatMessage]) async -> String? {
        guard let apiKey = directGeminiAPIKey else { return nil }

        var components = URLComponents(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(directGeminiModel):generateContent"
        )
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let apiMessages = messages.map { msg in
            GeminiContent(
                role: msg.role == .assistant ? "model" : "user",
                parts: [GeminiPart(text: msg.text)]
            )
        }

        request.httpBody = try? JSONEncoder().encode(
            GeminiGenerateRequest(
                systemInstruction: GeminiContent(role: "user", parts: [GeminiPart(text: systemPrompt)]),
                contents: apiMessages
            )
        )

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                return nil
            }
            let decoded = try JSONDecoder().decode(GeminiGenerateResponse.self, from: data)
            let text = decoded.candidates?
                .first?
                .content?
                .parts?
                .compactMap(\.text)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let text, !text.isEmpty else { return nil }
            return text
        } catch {
            return nil
        }
    }
}

extension GeminiTutorService: TutorAIProviding {}

private struct GeminiGenerateRequest: Codable {
    let systemInstruction: GeminiContent?
    let contents: [GeminiContent]
}

private struct GeminiContent: Codable {
    var role: String? = nil
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String?
}

private struct GeminiGenerateResponse: Codable {
    let candidates: [GeminiCandidate]?
}

private struct GeminiCandidate: Codable {
    let content: GeminiContentResponse?
}

private struct GeminiContentResponse: Codable {
    let parts: [GeminiPart]?
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
