import Foundation
import SwiftUI
import UserNotifications
import AppKit

final class GitHubNoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
@MainActor final class UpdateModel: ObservableObject {
    static let releasesURL = URL(string: "https://github.com/piyoharu97/codex-bar/releases/latest")!
    @Published var busy = false
    @Published var status = "「更新を確認」から最新版を確認できます。"
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
        automaticChecks = UserDefaults.standard.object(forKey: "automaticUpdateChecks") as? Bool ?? true
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        config.httpCookieStorage = nil
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 25
        session = URLSession(configuration: config, delegate: GitHubNoRedirectDelegate(), delegateQueue: nil)
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkIfDue() }
        }
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationAllowed = settings.authorizationStatus == .authorized
        }
        checkIfDue()
    }
    func checkIfDue() {
        guard automaticChecks else { return }
        let last = UserDefaults.standard.object(forKey: "lastUpdateAttempt") as? Date ?? .distantPast
        if Date().timeIntervalSince(last) >= 86400 { check() }
    }
    func check(manual: Bool = false) {
        guard !busy else { return }
        busy = true
        UserDefaults.standard.set(Date(), forKey: "lastUpdateAttempt")
        Task {
            defer { busy = false }
            do {
                let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                switch try await PublicReleaseFeed.fetch(session: session, currentVersion: current) {
                case .update(let tag):
                    latestTag = tag
                    status = "新しいバージョン \(tag) があります。"
                    if !manual { await notifyOnce(tag) }
                case .current:
                    latestTag = nil
                    status = "最新バージョンを使用しています。"
                case .failure(let message):
                    status = message
                }
            } catch {
                status = "更新を確認できませんでした。ネット接続を確認してください。"
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
}
