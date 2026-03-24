import Foundation
import JWTKit
import Vapor

protocol AppleIdentityTokenValidating: Sendable {
    func validate(identityToken: String) async throws -> AppleIdentityClaims
}

enum AppleTokenValidationError: Error {
    case malformedToken
    case missingKeyID
    case unknownKeyID
    case invalidIssuer
    case invalidAudience
}

struct AppleIdentityTokenValidator: AppleIdentityTokenValidating {
    private let expectedAudience: String
    private let jwksProvider: AppleJWKSProviding
    private let now: @Sendable () -> Date

    init(
        expectedAudience: String,
        jwksProvider: AppleJWKSProviding = AppleJWKSProvider(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.expectedAudience = expectedAudience
        self.jwksProvider = jwksProvider
        self.now = now
    }

    func validate(identityToken: String) async throws -> AppleIdentityClaims {
        let header: AppleJWTHeader = try decodeJWTPart(token: identityToken, at: 0)
        guard let kid = header.kid?.trimmedNonEmpty else {
            throw AppleTokenValidationError.missingKeyID
        }

        let keys = try await jwksProvider.jwks()
        guard let jwk = keys.keys.first(where: { $0.keyIdentifier == JWKIdentifier(string: kid) }) else {
            throw AppleTokenValidationError.unknownKeyID
        }

        let signers = JWTSigners()
        try signers.use(jwk: jwk)
        let payload = try signers.verify(identityToken, as: AppleIdentityPayload.self)

        guard payload.issuer.value == "https://appleid.apple.com" else {
            throw AppleTokenValidationError.invalidIssuer
        }
        guard payload.audience.value.contains(expectedAudience) else {
            throw AppleTokenValidationError.invalidAudience
        }
        try payload.expiration.verifyNotExpired(currentDate: now())

        return AppleIdentityClaims(
            appleUserID: payload.subject.value,
            issuer: payload.issuer.value,
            audience: payload.audience.value.first ?? expectedAudience,
            expiresAt: payload.expiration.value
        )
    }
}

protocol AppleJWKSProviding: Sendable {
    func jwks() async throws -> JWKS
}

final class AppleJWKSProvider: AppleJWKSProviding, @unchecked Sendable {
    private let session: URLSession
    private var cache: (jwks: JWKS, fetchedAt: Date)?
    private let cacheTTL: TimeInterval
    private let cacheLock = NSLock()

    init(session: URLSession = .shared, cacheTTL: TimeInterval = 900) {
        self.session = session
        self.cacheTTL = cacheTTL
    }

    func jwks() async throws -> JWKS {
        let now = Date()
        if let cached = cachedJWKS(now: now) {
            return cached
        }

        let url = URL(string: "https://appleid.apple.com/auth/keys")!
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw Abort(.badGateway, reason: "Unable to fetch Apple JWKS.")
        }
        let jwks = try JSONDecoder().decode(JWKS.self, from: data)
        storeCachedJWKS(jwks, at: now)
        return jwks
    }

    private func cachedJWKS(now: Date) -> JWKS? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        guard let cache, now.timeIntervalSince(cache.fetchedAt) < cacheTTL else {
            return nil
        }
        return cache.jwks
    }

    private func storeCachedJWKS(_ jwks: JWKS, at date: Date) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache = (jwks: jwks, fetchedAt: date)
    }
}

private struct AppleJWTHeader: Decodable {
    let kid: String?
}

private struct AppleIdentityPayload: JWTPayload {
    let issuer: IssuerClaim
    let audience: AudienceClaim
    let expiration: ExpirationClaim
    let subject: SubjectClaim

    enum CodingKeys: String, CodingKey {
        case issuer = "iss"
        case audience = "aud"
        case expiration = "exp"
        case subject = "sub"
    }

    func verify(using _: JWTSigner) throws { }
}

private func decodeJWTPart<T: Decodable>(token: String, at index: Int) throws -> T {
    let components = token.split(separator: ".")
    guard components.count >= 2, index < components.count else {
        throw AppleTokenValidationError.malformedToken
    }
    var base64 = String(components[index])
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    let remainder = base64.count % 4
    if remainder > 0 {
        base64 += String(repeating: "=", count: 4 - remainder)
    }
    guard let data = Data(base64Encoded: base64) else {
        throw AppleTokenValidationError.malformedToken
    }
    return try JSONDecoder().decode(T.self, from: data)
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
