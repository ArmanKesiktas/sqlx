import XCTest
@testable import SQLAcademy

final class TokenStoreTests: XCTestCase {
    func testKeychainTokenStoreSaveLoadAndClear() throws {
        let store = KeychainTokenStore(
            service: "com.arman.sqlacademy.tests",
            account: "token-\(UUID().uuidString)"
        )
        let session = AIAuthSession(
            accessToken: "access-token",
            expiresAt: Date().addingTimeInterval(300),
            appleUserID: "apple-user-123",
            displayName: "Arman"
        )

        try store.save(session)
        let loaded = try store.load()

        XCTAssertEqual(loaded?.accessToken, session.accessToken)
        XCTAssertEqual(loaded?.appleUserID, session.appleUserID)
        XCTAssertEqual(loaded?.displayName, session.displayName)

        try store.clear()
        XCTAssertNil(try store.load())
    }
}
