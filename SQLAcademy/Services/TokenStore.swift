import Foundation
import Security

struct AIAuthSession: Codable, Equatable {
    let accessToken: String
    let expiresAt: Date
    let appleUserID: String
    let displayName: String?
}

protocol TokenStoring: Sendable {
    func save(_ session: AIAuthSession) throws
    func load() throws -> AIAuthSession?
    func clear() throws
}

enum TokenStoreError: Error {
    case unexpectedData
    case osStatus(OSStatus)
}

final class KeychainTokenStore: TokenStoring, @unchecked Sendable {
    private let service: String
    private let account: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        service: String = "com.arman.sqlacademy.ai",
        account: String = "access_token"
    ) {
        self.service = service
        self.account = account
    }

    func save(_ session: AIAuthSession) throws {
        let data = try encoder.encode(session)
        let query = baseQuery()
        let updateAttributes: [String: Any] = [kSecValueData as String: data]
        let status: OSStatus
        if try loadData() != nil {
            status = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        } else {
            var insertQuery = query
            insertQuery[kSecValueData as String] = data
            status = SecItemAdd(insertQuery as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw TokenStoreError.osStatus(status)
        }
    }

    func load() throws -> AIAuthSession? {
        guard let data = try loadData() else { return nil }
        do {
            return try decoder.decode(AIAuthSession.self, from: data)
        } catch {
            throw TokenStoreError.unexpectedData
        }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenStoreError.osStatus(status)
        }
    }

    private func loadData() throws -> Data? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else {
            throw TokenStoreError.osStatus(status)
        }
        guard let data = item as? Data else {
            throw TokenStoreError.unexpectedData
        }
        return data
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
