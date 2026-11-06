import Foundation

final class ReleaseFixture: URLProtocol {
    static var statusCode = 200
    static var payload = ""
    static var seenRequest: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.seenRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.payload.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@main struct PublicReleaseFeedTests {
    static func main() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ReleaseFixture.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        ReleaseFixture.payload = #"{"tag_name":"v1.7.1","draft":false,"prerelease":false}"#
        let newer = try await PublicReleaseFeed.fetch(session: session, currentVersion: "1.7.0")
        assert(newer == .update("v1.7.1"))
        assert(ReleaseFixture.seenRequest?.value(forHTTPHeaderField: "Authorization") == nil)
        assert(ReleaseFixture.seenRequest?.value(forHTTPHeaderField: "Cookie") == nil)
        assert(ReleaseFixture.seenRequest?.url == PublicReleaseFeed.endpoint)
        let current = try await PublicReleaseFeed.fetch(session: session, currentVersion: "1.7.1")
        assert(current == .current)
        ReleaseFixture.statusCode = 404
        let missing = try await PublicReleaseFeed.fetch(session: session, currentVersion: "1.7.0")
        assert(missing == .failure("公開済みリリースが見つかりません。"))
        ReleaseFixture.statusCode = 429
        let limited = try await PublicReleaseFeed.fetch(session: session, currentVersion: "1.7.0")
        assert(limited == .failure("GitHubのアクセス制限中です。時間を置いて再試行してください。"))
        ReleaseFixture.statusCode = 200
        ReleaseFixture.payload = #"{"tag_name":"v9.0.0","draft":true,"prerelease":false}"#
        let draft = try await PublicReleaseFeed.fetch(session: session, currentVersion: "1.7.0")
        assert(draft == .failure("リリースのバージョン形式を確認できません。"))
        print("PASS: anonymous update requests, newer/current release, missing release, rate limit, draft rejection")
    }
}
