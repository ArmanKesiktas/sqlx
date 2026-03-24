import Foundation
import XCTest
@testable import SQLAcademy

final class AITutorAPIServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocolStub.handler = nil
    }

    override func tearDown() {
        URLProtocolStub.handler = nil
        super.tearDown()
    }

    func testAuthenticateWithAppleMapsSuccessAndStoresToken() async {
        let tokenStore = InMemoryTokenStore()
        let service = makeService(tokenStore: tokenStore) { request in
            XCTAssertEqual(request.url?.path, "/v1/auth/apple")
            let payload = """
            {
              "accessToken": "backend-token-1",
              "expiresAt": "2030-01-01T00:00:00Z",
              "appleUserID": "apple-user-1",
              "displayName": "Arman"
            }
            """
            return HTTPStubResponse(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: payload.data(using: .utf8) ?? Data()
            )
        }

        let session = await service.authenticateWithApple(identityToken: "id-token", displayName: "Arman")
        XCTAssertEqual(session?.accessToken, "backend-token-1")
        XCTAssertEqual(session?.appleUserID, "apple-user-1")
        XCTAssertEqual(session?.displayName, "Arman")

        let stored = try? tokenStore.load()
        XCTAssertEqual(stored?.accessToken, "backend-token-1")
    }

    func testAuthenticateWithAppleReturnsNilOnFailure() async {
        let tokenStore = InMemoryTokenStore()
        let service = makeService(tokenStore: tokenStore) { _ in
            HTTPStubResponse(statusCode: 401, headers: [:], body: Data())
        }

        let session = await service.authenticateWithApple(identityToken: "invalid", displayName: nil)
        XCTAssertNil(session)
    }

    func testGenerateClearsTokenOnUnauthorized() async throws {
        let tokenStore = InMemoryTokenStore()
        try tokenStore.save(
            AIAuthSession(
                accessToken: "token-123",
                expiresAt: Date().addingTimeInterval(600),
                appleUserID: "apple-user-1",
                displayName: nil
            )
        )

        let service = makeService(tokenStore: tokenStore) { request in
            XCTAssertEqual(request.url?.path, "/v1/ai/generate")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
            return HTTPStubResponse(statusCode: 401, headers: [:], body: Data())
        }

        let text = await service.generate(systemPrompt: "sys", userPrompt: "user")
        XCTAssertNil(text)
        XCTAssertNil(try tokenStore.load())
    }

    private func makeService(
        tokenStore: TokenStoring,
        handler: @escaping (URLRequest) -> HTTPStubResponse
    ) -> AITutorAPIService {
        URLProtocolStub.handler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)
        return AITutorAPIService(
            session: session,
            tokenStore: tokenStore,
            baseURLOverride: URL(string: "https://backend.local")!
        )
    }
}

private struct HTTPStubResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: Data
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> HTTPStubResponse)?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let response = handler(request)
        let urlResponse = HTTPURLResponse(
            url: request.url ?? URL(string: "https://backend.local")!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: response.headers
        )!
        client?.urlProtocol(self, didReceive: urlResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }
}

private final class InMemoryTokenStore: TokenStoring, @unchecked Sendable {
    private var value: AIAuthSession?

    func save(_ session: AIAuthSession) throws {
        value = session
    }

    func load() throws -> AIAuthSession? {
        value
    }

    func clear() throws {
        value = nil
    }
}
