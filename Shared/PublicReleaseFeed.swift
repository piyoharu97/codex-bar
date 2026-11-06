import Foundation

enum ReleaseCheckResult: Equatable {
    case update(String)
    case current
    case failure(String)
}
struct GitHubRelease: Decodable {
    let tag_name: String
    let draft: Bool
    let prerelease: Bool
}
enum PublicReleaseFeed {
    static let endpoint = URL(string: "https://api.github.com/repos/piyoharu97/codex-bar/releases/latest")!
    static func request() -> URLRequest {
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Codex-bar-updater", forHTTPHeaderField: "User-Agent")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        // Public Releases never require or receive credentials from the app.
        return request
    }
    static func fetch(session: URLSession, currentVersion: String) async throws -> ReleaseCheckResult {
        let (data, response) = try await session.data(for: request())
        guard let http = response as? HTTPURLResponse else { return .failure("GitHubの応答を確認できません。") }
        switch http.statusCode {
        case 200: break
        case 403, 429: return .failure("GitHubのアクセス制限中です。時間を置いて再試行してください。")
        case 404: return .failure("公開済みリリースが見つかりません。")
        default: return .failure("GitHubに接続できませんでした。時間を置いて再試行してください。")
        }
        guard data.count <= 2_000_000 else { return .failure("GitHubの応答を確認できません。") }
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard !release.draft, !release.prerelease,
              let remote = ReleaseVersion(release.tag_name), let current = ReleaseVersion(currentVersion) else {
            return .failure("リリースのバージョン形式を確認できません。")
        }
        return remote > current ? .update(release.tag_name) : .current
    }
}
