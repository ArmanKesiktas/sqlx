import Vapor

func routes(_ app: Application) throws {
    app.get { _ in
        "ok"
    }

    let v1 = app.grouped("v1")
    v1.post("auth", "apple") { req async throws -> AppleAuthResponse in
        let payload = try req.content.decode(AppleAuthRequest.self)
        guard let identityToken = payload.identityToken.trimmedNonEmpty else {
            throw Abort(.badRequest, reason: "identityToken is required.")
        }

        let claims: AppleIdentityClaims
        do {
            claims = try await app.appleTokenValidator.validate(identityToken: identityToken)
        } catch {
            throw Abort(.unauthorized, reason: "Apple identity token is invalid.")
        }

        let displayName = payload.displayName?.trimmedNonEmpty
        let issued = await app.accessTokenStore.issueToken(
            appleUserID: claims.appleUserID,
            displayName: displayName,
            ttlSeconds: app.backendConfiguration.tokenTTLSeconds
        )
        return AppleAuthResponse(
            accessToken: issued.token,
            expiresAt: issued.expiresAt,
            appleUserID: issued.appleUserID,
            displayName: issued.displayName
        )
    }

    v1.post("ai", "generate") { req async throws -> AIGenerateResponse in
        guard let bearerToken = req.headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized, reason: "Missing bearer token.")
        }
        guard await app.accessTokenStore.validate(token: bearerToken) != nil else {
            throw Abort(.unauthorized, reason: "Invalid access token.")
        }

        let payload = try req.content.decode(AIGenerateRequest.self)
        let text: String
        do {
            text = try await app.aiGenerator.generate(
                systemPrompt: payload.systemPrompt,
                messages: payload.messages
            )
        } catch let error as AIGenerateError {
            switch error {
            case .notConfigured:
                throw Abort(.serviceUnavailable, reason: "AI provider is not configured.")
            case .badResponse, .emptyResponse:
                throw Abort(.badGateway, reason: "AI provider request failed.")
            }
        } catch {
            throw Abort(.badGateway, reason: "AI provider request failed.")
        }
        return AIGenerateResponse(text: text)
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
