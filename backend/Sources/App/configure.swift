import Foundation
import Vapor

public func configure(_ app: Application) throws {
    let config = BackendConfiguration(environment: app.environment)

    let jsonEncoder = JSONEncoder()
    jsonEncoder.dateEncodingStrategy = .iso8601
    let jsonDecoder = JSONDecoder()
    jsonDecoder.dateDecodingStrategy = .iso8601
    ContentConfiguration.global.use(encoder: jsonEncoder, for: .json)
    ContentConfiguration.global.use(decoder: jsonDecoder, for: .json)

    app.backendConfiguration = config
    app.accessTokenStore = AccessTokenStore()
    app.appleTokenValidator = AppleIdentityTokenValidator(
        expectedAudience: config.appleAudience
    )
    app.aiGenerator = GeminiAPIClient(
        apiKey: config.geminiAPIKey,
        model: config.geminiModel
    )

    try routes(app)
}

struct BackendConfiguration: Sendable {
    let appleAudience: String
    let tokenTTLSeconds: TimeInterval
    let geminiAPIKey: String?
    let geminiModel: String

    init(environment: Environment) {
        self.appleAudience = Environment.get("APPLE_AUDIENCE") ?? "com.arman.sqlacademy"
        self.tokenTTLSeconds = TimeInterval(Environment.get("ACCESS_TOKEN_TTL_SECONDS").flatMap(Double.init) ?? 3600)
        self.geminiAPIKey = Environment.get("GEMINI_API_KEY")?.trimmedNonEmpty
        self.geminiModel = Environment.get("GEMINI_MODEL")?.trimmedNonEmpty ?? "gemini-2.0-flash"

        if environment != .testing, geminiAPIKey == nil {
            print("Warning: GEMINI_API_KEY is not configured. AI generate endpoint will return 503.")
        }
    }
}

extension Application {
    private struct BackendConfigurationKey: StorageKey {
        typealias Value = BackendConfiguration
    }

    private struct AccessTokenStoreKey: StorageKey {
        typealias Value = AccessTokenStore
    }

    private struct AppleTokenValidatorKey: StorageKey {
        typealias Value = AppleIdentityTokenValidating
    }

    private struct AIGeneratorKey: StorageKey {
        typealias Value = AIGenerating
    }

    var backendConfiguration: BackendConfiguration {
        get {
            guard let value = storage[BackendConfigurationKey.self] else {
                fatalError("BackendConfiguration not configured")
            }
            return value
        }
        set { storage[BackendConfigurationKey.self] = newValue }
    }

    var accessTokenStore: AccessTokenStore {
        get {
            guard let value = storage[AccessTokenStoreKey.self] else {
                fatalError("AccessTokenStore not configured")
            }
            return value
        }
        set { storage[AccessTokenStoreKey.self] = newValue }
    }

    var appleTokenValidator: AppleIdentityTokenValidating {
        get {
            guard let value = storage[AppleTokenValidatorKey.self] else {
                fatalError("AppleIdentityTokenValidating not configured")
            }
            return value
        }
        set { storage[AppleTokenValidatorKey.self] = newValue }
    }

    var aiGenerator: AIGenerating {
        get {
            guard let value = storage[AIGeneratorKey.self] else {
                fatalError("AIGenerating not configured")
            }
            return value
        }
        set { storage[AIGeneratorKey.self] = newValue }
    }
}

extension String {
    fileprivate var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
