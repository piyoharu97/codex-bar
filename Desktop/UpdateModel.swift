import Foundation
import SwiftUI
import Security
import LocalAuthentication
import UserNotifications
import AppKit

// The token is never stored in preferences, files, logs, or the app bundle.
enum UpdateTokenStore {
    static let service = "Codex bar GitHub Updates"
    static let account = "piyoharu97/codex-bar"
    static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
    static func exists() -> Bool {
        var q = query; q[kSecReturnAttributes as String] = true
        let context = LAContext(); context.interactionNotAllowed = true
        q[kSecUseAuthenticationContext as String] = context
        var result: CFTypeRef?
        return SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess
    }
    static func load() throws -> String {
        var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, let value = String(data: data, encoding: .utf8) else { throw UpdateError.token }
        return value
    }
    static func save(_ token: String) throws {
        let values: [String: Any] = [kSecValueData as String: Data(token.utf8)]
        let result = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if result == errSecItemNotFound {
            var q = query; q[kSecValueData as String] = Data(token.utf8)
            q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw UpdateError.token }
        } else if result != errSecSuccess { throw UpdateError.token }
    }
    static func remove() { SecItemDelete(query as CFDictionary) }
}
enum UpdateError: Error { case token }
struct GitHubRelease: Decodable {
    let tag_name: String
    let draft: Bool
    let prerelease: Bool
}
final class GitHubNoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
@MainActor final class UpdateModel: ObservableObject {
    static let releasesURL = URL(string: "https://github.com/piyoharu97/codex-bar/releases/latest")!
    static let tokenURL = URL(string: "https://github.com/settings/personal-access-tokens/new")!
    @Published var hasToken = UpdateTokenStore.exists()
    @Published var busy = false
    @Published var status = "GitHubの読み取り用トークンを設定すると更新を確認できます。"
    @Published var latestTag: String?
    @Published var notificationAllowed = false
    @Published var automaticChecks: Bool {
        didSet {
            UserDefaults.standard.set(automaticChecks, forKey: "automaticUpdateChecks")
            if automaticChecks { checkIfDue() }
        }
    }
    private let session: URLSession
    private var timer: Timer?
    var updateAvailable: Bool { latestTag != nil }
    init() {
        automaticChecks = UserDefaults.standard.bool(forKey: "automaticUpdateChecks")
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 25
        session = URLSession(configuration: config, delegate: GitHubNoRedirectDelegate(), delegateQueue: nil)
        if hasToken { status = "更新を確認できます。" }
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkIfDue() }
        }
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationAllowed = settings.authorizationStatus == .authorized
        }
        checkIfDue()
    }
    func saveToken(_ value: String) {
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, token.count <= 512, !token.contains(where: { $0.isWhitespace }) else {
            status = "GitHubの読み取り用トークンを入力してください。"; return
        }
        do {
            try UpdateTokenStore.save(token)
            hasToken = true
            if UserDefaults.standard.object(forKey: "automaticUpdateChecks") == nil { automaticChecks = true }
            check(manual: true)
        } catch { status = "キーチェーンへ保存できませんでした。" }
    }
    func removeToken() {
        UpdateTokenStore.remove(); hasToken = UpdateTokenStore.exists()
        automaticChecks = false; latestTag = nil
        status = hasToken ? "トークンを削除できませんでした。" : "読み取り用トークンを削除しました。"
    }
    func checkIfDue() {
        guard automaticChecks && hasToken else { return }
        let last = UserDefaults.standard.object(forKey: "lastUpdateAttempt") as? Date ?? .distantPast
        if Date().timeIntervalSince(last) >= 86400 { check() }
    }
    func check(manual: Bool = false) {
        guard !busy else { return }
        guard hasToken else { status = "GitHubの読み取り用トークンを設定してください。"; return }
        busy = true
        UserDefaults.standard.set(Date(), forKey: "lastUpdateAttempt")
        Task {
            defer { busy = false }
            do {
                let token = try UpdateTokenStore.load()
                var request = URLRequest(url: URL(string: "https://api.github.com/repos/piyoharu97/codex-bar/releases/latest")!)
                request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("Codex-bar-updater", forHTTPHeaderField: "User-Agent")
                request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { status = "GitHubの応答を確認できません。"; return }
                switch http.statusCode {
                case 200: break
                case 401: status = "トークンの有効期限・権限を確認してください。"; return
                case 403, 429: status = "読み取り権限またはGitHubのアクセス制限を確認してください。"; return
                case 404: status = "公開済みリリースがないか、このトークンに閲覧権限がありません。"; return
                default: status = "GitHubに接続できませんでした。時間を置いて再試行してください。"; return
                }
                guard data.count <= 2_000_000 else { status = "GitHubの応答を確認できません。"; return }
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                guard !release.draft, !release.prerelease,
                      let remote = ReleaseVersion(release.tag_name),
                      let current = ReleaseVersion(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") else {
                    status = "リリースのバージョン形式を確認できません。"; return
                }
                if remote > current {
                    latestTag = release.tag_name
                    status = "新しいバージョン \(release.tag_name) があります。"
                    if !manual { await notifyOnce(release.tag_name) }
                } else {
                    latestTag = nil; status = "最新バージョンを使用しています。"
                }
            } catch {
                status = "更新を確認できませんでした。ネット接続とキーチェーンを確認してください。"
            }
        }
    }
    func allowNotifications() {
        Task {
            do {
                notificationAllowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                if !notificationAllowed { status = "通知はmacOSのシステム設定で許可できます。" }
            } catch { status = "通知を設定できませんでした。" }
        }
    }
    private func notifyOnce(_ tag: String) async {
        guard notificationAllowed, UserDefaults.standard.string(forKey: "lastNotifiedRelease") != tag else { return }
        let content = UNMutableNotificationContent()
        content.title = "Codex barのアップデート"
        content.body = "\(tag) を利用できます。設定から配布ページを開いて更新してください。"
        let request = UNNotificationRequest(identifier: "CodexBarUpdate", content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
            UserDefaults.standard.set(tag, forKey: "lastNotifiedRelease")
        } catch { /* A missing notification permission must not interrupt quota display. */ }
    }
    func openReleases() { NSWorkspace.shared.open(Self.releasesURL) }
    func openTokenSettings() { NSWorkspace.shared.open(Self.tokenURL) }
}
