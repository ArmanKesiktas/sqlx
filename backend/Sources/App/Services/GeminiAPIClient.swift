import Foundation

protocol AIGenerating: Sendable {
    func generate(systemPrompt: String, messages: [AIChatMessage]) async throws -> String
}

struct AIChatMessage: Codable, Sendable {
    enum Role: String, Codable, Sendable {
        case user
        case model
    }
    let role: Role
    let text: String
}

enum AIGenerateError: Error {
    case notConfigured
    case badResponse
    case emptyResponse
}

struct GeminiAPIClient: AIGenerating {
    private let apiKey: String?
    private let model: String
    private let session: URLSession

    init(
        apiKey: String?,
        model: String,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    func generate(systemPrompt: String, messages: [AIChatMessage]) async throws -> String {
        guard let apiKey, !apiKey.isEmpty else {
            throw AIGenerateError.notConfigured
        }

        var components = URLComponents(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        )
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components?.url else {
            throw AIGenerateError.badResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            GeminiGenerateRequest(
                systemInstruction: GeminiContent(role: "user", parts: [GeminiPart(text: systemPrompt)]),
                contents: messages.map { msg in
                    GeminiContent(role: msg.role.rawValue, parts: [GeminiPart(text: msg.text)])
                }
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw AIGenerateError.badResponse
        }
        let decoded = try JSONDecoder().decode(GeminiGenerateResponse.self, from: data)
        let text = decoded.candidates?
            .first?
            .content?
            .parts?
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let text, !text.isEmpty else {
            throw AIGenerateError.emptyResponse
        }
        return text
    }
}

private struct GeminiGenerateRequest: Codable {
    let systemInstruction: GeminiContent?
    let contents: [GeminiContent]
}

private struct GeminiContent: Codable {
    let role: String?
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
