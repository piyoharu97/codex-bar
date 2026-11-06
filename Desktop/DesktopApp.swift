import SwiftUI
import AppKit
import ServiceManagement
import UserNotifications

struct DesktopFace: View {
    @ObservedObject var model: QuotaModel
    @AppStorage("widgetBackground") private var background = WidgetBackground.dark.rawValue
    @AppStorage("iconChoice") private var iconChoice = IconChoice.codex.rawValue
    let openCodex: () -> Void
    let openSettings: () -> Void
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            QuotaView(snapshot: model.snapshot, date: context.date,
                      foreground: background == WidgetBackground.glass.rawValue ? Color(white: 0.1) : .white,
                      secondary: background == WidgetBackground.glass.rawValue ? Color.black.opacity(0.62) : .gray,
                      logoLabel: (IconChoice(rawValue: iconChoice) ?? .codex).title,
                      logo: (IconChoice(rawValue: iconChoice) ?? .codex).logo)
                .padding(18).frame(width: 210, height: 190)
                .background { DesktopBackground(style: WidgetBackground(rawValue: background) ?? .dark) }
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .preferredColorScheme(.dark)
                .overlay { CardInteraction(openCodex: openCodex, openSettings: openSettings) }
                .help("クリックでCodex · 右クリックで設定 · ドラッグで移動")
        }
    }
}
@MainActor final class DesktopDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    var window: NSWindow!
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow?
    var model: QuotaModel!
    var updater: UpdateModel!
    var menuTimer: Timer?
    var menuIsOpen = false
    private var appliedIconChoice = ""
    func menuWillOpen(_ menu: NSMenu) { menuIsOpen = true }
    func menuDidClose(_ menu: NSMenu) { menuIsOpen = false }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "").count > 1 {
            NSApp.terminate(nil); return
        }
        NSApp.setActivationPolicy(.accessory)
        model = QuotaModel()
        UNUserNotificationCenter.current().delegate = self
        updater = UpdateModel()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 210, height: 190),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = "Codex bar"
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = false
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.hidesOnDeactivate = false
        window.contentView = NSHostingView(rootView: DesktopFace(model: model,
            openCodex: { [weak self] in self?.openCodex() },
            openSettings: { [weak self] in self?.showSettings() }))
        window.delegate = self
        if !window.setFrameUsingName("CodexQuotaDesktopPosition") { resetPosition() }
        ensureVisible()
        window.setFrameAutosaveName("CodexQuotaDesktopPosition")
        window.orderFrontRegardless()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        applyIconChoice()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.applyIconChoice() }
            }
        statusItem.button?.toolTip = "Codex bar"
        rebuildMenu()
        menuTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.rebuildMenu() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.ensureVisible() } }
    }
    func applyIconChoice() {
        let choice = IconChoice(rawValue: UserDefaults.standard.string(forKey: "iconChoice") ?? "") ?? .codex
        guard appliedIconChoice != choice.rawValue, let icon = choice.appIcon else { return }
        appliedIconChoice = choice.rawValue
        NSApp.applicationIconImage = icon
        if let menuIcon = icon.copy() as? NSImage {
            menuIcon.size = NSSize(width: 22, height: 22)
            menuIcon.isTemplate = false
            statusItem.button?.image = menuIcon
        }
    }
    func ensureVisible() {
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { resetPosition() }
    }
    @objc func resetPosition() {
        guard let screen = NSScreen.main else { return }
        window.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 238, y: screen.visibleFrame.maxY - 218))
        window.orderFrontRegardless()
    }
    func rebuildMenu() {
        if menuIsOpen { return }
        model.syncLoginState()
        applyIconChoice()
        let menu = NSMenu()
        menu.delegate = self
        func item(_ title: String, _ action: Selector?, enabled: Bool = true) {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
            entry.target = self; entry.isEnabled = enabled; menu.addItem(entry)
        }
        item("Codex bar · " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""), nil, enabled: false)
        item("Codexを開く", #selector(openCodex))
        item("設定…", #selector(showSettings))
        if let latest = updater.latestTag { item("新しいバージョン " + latest, #selector(openReleases)) }
        item("アップデートを確認…", #selector(checkUpdates))
        if let updated = model.snapshot.updatedAt { item("最終取得 " + updated.formatted(date: .omitted, time: .shortened), nil, enabled: false) }
        if !model.detail.isEmpty { item(model.detail, nil, enabled: false) }
        menu.addItem(.separator())
        item(model.busy ? "更新中…" : "今すぐ更新", #selector(refresh), enabled: !model.busy)
        item(window.isVisible ? "デスクトップ表示を隠す" : "デスクトップに表示", #selector(toggle))
        item("位置をリセット", #selector(resetPosition))
        item("Codex実行ファイルを選択…", #selector(choose))
        let loginEntry = NSMenuItem(title: "ログイン時に起動", action: #selector(login), keyEquivalent: "")
        loginEntry.target = self
        loginEntry.state = model.loginEnabled ? .on : .off
        menu.addItem(loginEntry)
        menu.addItem(.separator())
        item("終了", #selector(quit))
        statusItem.menu = menu
    }
    func codexURL() -> URL? {
        if let path = UserDefaults.standard.string(forKey: "codexApplicationPath") {
            return FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex")
    }
    func codexName() -> String {
        guard let url = codexURL() else { return "Codexが見つかりません" }
        return Bundle(url: url)?.bundleIdentifier == "com.openai.codex" ? "Codex" : url.deletingPathExtension().lastPathComponent
    }
    @objc func openCodex() {
        guard let url = codexURL() else {
            model.detail = "起動するCodexアプリを「変更…」から選んでください"; showSettings(); return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { [weak self] _, error in
            if error != nil {
                Task { @MainActor in self?.model.detail = "アプリを開けません。設定で起動先を選び直してください"; self?.showSettings() }
            }
        }
    }
    func chooseApplication() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "クリックで開くCodexアプリを選択"
        if panel.runModal() == .OK, let url = panel.url, url.pathExtension == "app" {
            UserDefaults.standard.set(url.path, forKey: "codexApplicationPath")
            model.detail = ""
        }
    }
    @objc func showSettings() {
        if settingsWindow == nil {
            let view = DesktopSettingsView(model: model, updater: updater,
                applicationName: { [weak self] in self?.codexName() ?? "Codex" },
                chooseApplication: { [weak self] in self?.chooseApplication() },
                openCodex: { [weak self] in self?.openCodex() })
            let controller = NSHostingController(rootView: view)
            let settings = NSWindow(contentViewController: controller)
            settings.title = "Codex bar 設定"
            settings.styleMask = [.titled, .closable, .miniaturizable]
            settings.isReleasedWhenClosed = false
            settings.appearance = NSAppearance(named: .darkAqua)
            settings.center()
            settingsWindow = settings
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func openReleases() { updater.openReleases() }
    @objc func checkUpdates() { showSettings(); updater.check(manual: true) }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in NSWorkspace.shared.open(UpdateModel.releasesURL) }
        completionHandler()
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    @objc func refresh() { model.refresh() }
    @objc func toggle() { if window.isVisible { window.orderOut(nil) } else { window.orderFrontRegardless() }; rebuildMenu() }
    @objc func choose() { NSApp.activate(ignoringOtherApps: true); model.choose() }
    @objc func login() { model.loginItem(); rebuildMenu() }
    @objc func quit() { NSApp.terminate(nil) }
}
@main struct DesktopMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = DesktopDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
