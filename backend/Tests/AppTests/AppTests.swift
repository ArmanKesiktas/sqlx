import XCTest
import XCTVapor
@testable import App

final class AppTests: XCTestCase {
    func testAuthAppleReturnsTokenForValidIdentityToken() async throws {
        try await withApp(
            validator: MockAppleValidator(result: .success(validClaims)),
            generator: MockAIGenerator(result: .success("ok"))
        ) { app in
            let request = AppleAuthRequest(identityToken: "valid-id-token", displayName: "Arman")
            try await app.test(.POST, "/v1/auth/apple", beforeRequest: { req in
                try req.content.encode(request)
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let payload = try res.content.decode(AppleAuthResponse.self)
                XCTAssertFalse(payload.accessToken.isEmpty)
                XCTAssertEqual(payload.appleUserID, "apple-user-1")
                XCTAssertEqual(payload.displayName, "Arman")
            })
        }
    }

    func testAuthAppleRejectsInvalidIdentityToken() async throws {
        try await withApp(
            validator: MockAppleValidator(result: .failure(MockError.invalid)),
            generator: MockAIGenerator(result: .success("ok"))
        ) { app in
            let request = AppleAuthRequest(identityToken: "invalid", displayName: nil)
            try await app.test(.POST, "/v1/auth/apple", beforeRequest: { req in
                try req.content.encode(request)
            }, afterResponse: { res async in
                XCTAssertEqual(res.status, .unauthorized)
            })
        }
    }

    func testAIGenerateRequiresAuth() async throws {
        try await withApp(
            validator: MockAppleValidator(result: .success(validClaims)),
            generator: MockAIGenerator(result: .success("ok"))
        ) { app in
            let request = AIGenerateRequest(systemPrompt: "sys", messages: [AIChatMessage(role: .user, text: "usr")])
            try await app.test(.POST, "/v1/ai/generate", beforeRequest: { req in
                try req.content.encode(request)
            }, afterResponse: { res async in
                XCTAssertEqual(res.status, .unauthorized)
            })
        }
    }

    func testAIGenerateReturnsOutputWhenTokenIsValid() async throws {
        try await withApp(
            validator: MockAppleValidator(result: .success(validClaims)),
            generator: MockAIGenerator(result: .success("generated text"))
        ) { app in
            let session = await app.accessTokenStore.issueToken(
                appleUserID: "apple-user-1",
                displayName: nil,
                ttlSeconds: 300
            )

            let request = AIGenerateRequest(systemPrompt: "sys", messages: [AIChatMessage(role: .user, text: "usr")])
            try await app.test(.POST, "/v1/ai/generate", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: session.token)
                try req.content.encode(request)
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let payload = try res.content.decode(AIGenerateResponse.self)
                XCTAssertEqual(payload.text, "generated text")
            })
        }
    }

    func testAIGenerateReturnsBadGatewayOnProviderFailure() async throws {
        try await withApp(
            validator: MockAppleValidator(result: .success(validClaims)),
            generator: MockAIGenerator(result: .failure(AIGenerateError.badResponse))
        ) { app in
            let session = await app.accessTokenStore.issueToken(
                appleUserID: "apple-user-1",
                displayName: nil,
                ttlSeconds: 300
            )

            let request = AIGenerateRequest(systemPrompt: "sys", messages: [AIChatMessage(role: .user, text: "usr")])
            try await app.test(.POST, "/v1/ai/generate", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: session.token)
                try req.content.encode(request)
            }, afterResponse: { res async in
                XCTAssertEqual(res.status, .badGateway)
            })
        }
    }

    private func withApp(
        validator: some AppleIdentityTokenValidating,
        generator: some AIGenerating,
        _ body: (Application) async throws -> Void
    ) async throws {
        let app = try await Application.make(.testing)
        do {
            try configure(app)
            app.appleTokenValidator = validator
            app.aiGenerator = generator
            try await body(app)
            try await app.asyncShutdown()
        } catch {
            try? await app.asyncShutdown()
            throw error
        }
    }

    private struct MockAppleValidator: AppleIdentityTokenValidating, @unchecked Sendable {
        let result: Result<AppleIdentityClaims, Error>

        func validate(identityToken: String) async throws -> AppleIdentityClaims {
            switch result {
            case .success(let claims):
                return claims
            case .failure(let error):
                throw error
            }
        }
    }

    private struct MockAIGenerator: AIGenerating, @unchecked Sendable {
        let result: Result<String, Error>

        func generate(systemPrompt: String, messages: [AIChatMessage]) async throws -> String {
            switch result {
            case .success(let value):
                return value
            case .failure(let error):
                throw error
            }
        }
    }

    private enum MockError: Error {
        case invalid
    }

    private var validClaims: AppleIdentityClaims {
        AppleIdentityClaims(
            appleUserID: "apple-user-1",
            issuer: "https://appleid.apple.com",
            audience: "com.arman.sqlacademy",
            expiresAt: Date().addingTimeInterval(600)
        )
    }
}
