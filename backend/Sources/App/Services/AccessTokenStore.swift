import Foundation

struct AccessTokenSession: Sendable {
    let token: String
    let appleUserID: String
    let expiresAt: Date
    let displayName: String?
}

actor AccessTokenStore {
    private var sessionsByToken: [String: AccessTokenSession] = [:]

    func issueToken(
        appleUserID: String,
        displayName: String?,
        ttlSeconds: TimeInterval,
        now: Date = Date()
    ) -> AccessTokenSession {
        let expiry = now.addingTimeInterval(ttlSeconds)
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let session = AccessTokenSession(
            token: token,
            appleUserID: appleUserID,
            expiresAt: expiry,
            displayName: displayName
        )
        sessionsByToken[token] = session
        return session
    }

    func validate(token: String, now: Date = Date()) -> AccessTokenSession? {
        guard let session = sessionsByToken[token] else { return nil }
        if session.expiresAt <= now {
            sessionsByToken[token] = nil
            return nil
        }
        return session
    }

    func revoke(token: String) {
        sessionsByToken[token] = nil
    }
}
