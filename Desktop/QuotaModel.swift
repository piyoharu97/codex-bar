import SwiftUI
import ServiceManagement
import AppKit

@MainActor final class QuotaModel: ObservableObject {
    @Published var snapshot = Store.read()
    @Published var busy = false
    @Published var path = UserDefaults.standard.string(forKey: "codexPath") ?? ""
    @Published var detail = ""
    @Published private(set) var loginEnabled = false
    @Published private(set) var loginNeedsApproval = false
    @Published private(set) var loginUpdating = false
    @Published private(set) var loginError = ""
    private var timer: Timer?
    init() {
        syncLoginState()
        if path.isEmpty {
            let candidates = ["/opt/homebrew/bin/codex", "/usr/local/bin/codex",
                "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
                "/Applications/Codex.app/Contents/Resources/codex"]
            path = candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? ""
        }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.refresh() } }
        refresh()
    }
    func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.message = "信頼できるOpenAI Codexの実行ファイルを選択してください"
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
            UserDefaults.standard.set(path, forKey: "codexPath")
            refresh()
        }
    }
    func refresh() {
        guard !busy else { return }
        busy = true
        let executable = URL(fileURLWithPath: path)
        Task {
            let result: Result<Snapshot, Error> = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    continuation.resume(returning: Result { try CodexClient(executable: executable).fetch() })
                }
            }
            switch result {
            case .success(let value): snapshot = value; detail = ""
            case .failure(let error):
                // Remove old account data on errors; never show one account's quota after switching login.
                snapshot = Snapshot(error: (error as? FetchError)?.localizedDescription ?? "取得失敗。実行ファイルと接続を確認")
                detail = snapshot.error ?? ""
            }
            do {
                try Store.write(snapshot)
                NotificationCenter.default.post(name: .quotaUpdated, object: nil)
            } catch { detail = "データを保存できません。空き容量とアクセス権を確認" }
            busy = false
        }
    }
    func syncLoginState() {
        let status = SMAppService.mainApp.status
        let enabled = status == .enabled
        let approval = status == .requiresApproval
        if loginEnabled != enabled { loginEnabled = enabled }
        if loginNeedsApproval != approval { loginNeedsApproval = approval }
    }
    func setLoginEnabled(_ enabled: Bool) {
        guard !loginUpdating else { return }
        loginUpdating = true
        loginError = ""
        defer { syncLoginState(); loginUpdating = false }
        do {
            let status = SMAppService.mainApp.status
            if enabled && status != .enabled && status != .requiresApproval {
                try SMAppService.mainApp.register()
            } else if !enabled && (status == .enabled || status == .requiresApproval) {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginError = "ログイン時の起動を変更できませんでした。macOSのログイン項目を確認してください。"
        }
    }
    func loginItem() {
        syncLoginState()
        setLoginEnabled(!loginEnabled)
    }
    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

}

extension Notification.Name { static let quotaUpdated = Notification.Name("quotaUpdated") }
