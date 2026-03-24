import Foundation
import Vapor

struct AppleAuthRequest: Content {
    let identityToken: String
    let displayName: String?
}

struct AppleAuthResponse: Content {
    let accessToken: String
    let expiresAt: Date
    let appleUserID: String
    let displayName: String?
}

struct AIGenerateRequest: Content {
    let systemPrompt: String
    let messages: [AIChatMessage]
}

struct AIGenerateResponse: Content {
    let text: String
}

struct AppleIdentityClaims: Sendable {
    let appleUserID: String
    let issuer: String
    let audience: String
    let expiresAt: Date
}
