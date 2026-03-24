import Foundation

actor AITutorAPIService {
    private let baseURL: URL?
    private let session: URLSession
    private let tokenStore: TokenStoring
    private let now: @Sendable () -> Date

    init(
        bundle: Bundle = .main,
        session: URLSession = .shared,
        tokenStore: TokenStoring = KeychainTokenStore(),
        processInfo: ProcessInfo = .processInfo,
        baseURLOverride: URL? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        let envBaseURL = processInfo.environment["AI_BACKEND_BASE_URL"]?.trimmedNonEmpty
        let plistBaseURL = (bundle.object(forInfoDictionaryKey: "AI_BACKEND_BASE_URL") as? String)?.trimmedNonEmpty
        self.baseURL = baseURLOverride ?? URL(string: envBaseURL ?? plistBaseURL ?? "")
        self.session = session
        self.tokenStore = tokenStore
        self.now = now
    }

    var isConfigured: Bool {
        baseURL != nil
    }

    func authenticateWithApple(identityToken: String, displayName: String?) async -> AIAuthSession? {
        guard let baseURL, !identityToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let requestPayload = AppleAuthRequest(
            identityToken: identityToken,
            displayName: displayName?.trimmedNonEmpty
        )
        guard let url = URL(string: "/v1/auth/apple", relativeTo: baseURL) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(requestPayload)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                return nil
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(AppleAuthResponse.self, from: data)
            let authSession = AIAuthSession(
                accessToken: decoded.accessToken,
                expiresAt: decoded.expiresAt,
                appleUserID: decoded.appleUserID,
                displayName: decoded.displayName
            )
            try? tokenStore.save(authSession)
            return authSession
        } catch {
            return nil
        }
    }

    func generate(systemPrompt: String, messages: [TutorChatMessage]) async -> String? {
        guard let baseURL else { return nil }
        guard let authSession = try? tokenStore.load() else {
            return nil
        }
        if authSession.expiresAt <= now() {
            try? tokenStore.clear()
            return nil
        }

        guard let url = URL(string: "/v1/ai/generate", relativeTo: baseURL) else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
        let apiMessages = messages.map { msg in
            AIChatMessageAPI(
                role: msg.role == .assistant ? "model" : "user",
                text: msg.text
            )
        }
        request.httpBody = try? JSONEncoder().encode(AIGenerateRequest(systemPrompt: systemPrompt, messages: apiMessages))

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return nil }
            if httpResponse.statusCode == 401 {
                try? tokenStore.clear()
                return nil
            }
            guard 200..<300 ~= httpResponse.statusCode else {
                return nil
            }
            let decoded = try JSONDecoder().decode(AIGenerateResponse.self, from: data)
            let trimmed = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } catch {
            return nil
        }
    }

    func clearSession() async {
        try? tokenStore.clear()
    }

    func currentSession() async -> AIAuthSession? {
        try? tokenStore.load()
    }
}

private struct AppleAuthRequest: Codable {
    let identityToken: String
    let displayName: String?
}

private struct AppleAuthResponse: Codable {
    let accessToken: String
    let expiresAt: Date
    let appleUserID: String
    let displayName: String?
}

struct AIChatMessageAPI: Codable {
    let role: String
    let text: String
}

private struct AIGenerateRequest: Codable {
    let systemPrompt: String
    let messages: [AIChatMessageAPI]
}

private struct AIGenerateResponse: Codable {
    let text: String
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
