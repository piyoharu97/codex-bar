import SwiftUI
import AppKit

struct DesktopSettingsView: View {
    @AppStorage("widgetBackground") private var background = WidgetBackground.dark.rawValue
    @AppStorage("iconChoice") private var iconChoice = IconChoice.codex.rawValue
    @ObservedObject var model: QuotaModel
    @ObservedObject var updater: UpdateModel
    let applicationName: () -> String
    let chooseApplication: () -> Void
    let openCodex: () -> Void
    @State private var selectionRevision = 0
    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "バージョン \(info["CFBundleShortVersionString"] as? String ?? "—")（\(info["CFBundleVersion"] as? String ?? "—")）"
    }
    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(nsImage: (IconChoice(rawValue: iconChoice) ?? .codex).appIcon ?? NSImage())
                    .resizable().frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Codex bar").font(.title2.weight(.semibold))
                    Text(version).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            GroupBox("アイコン") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("ロゴ", selection: $iconChoice) {
                        ForEach(IconChoice.allCases) { choice in Text(choice.title).tag(choice.rawValue) }
                    }.pickerStyle(.segmented).labelsHidden()
                    Text("ウィジェットとメニューバーに反映します。FinderのアイコンはCodexで固定です。")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(8)
            }
            GroupBox("ウィジェットの背景") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("背景", selection: $background) {
                        ForEach(WidgetBackground.allCases) { style in Text(style.title).tag(style.rawValue) }
                    }.pickerStyle(.segmented).labelsHidden()
                    Text((WidgetBackground(rawValue: background) ?? .dark).detail)
                        .font(.caption).foregroundStyle(.secondary)
                    Text("変更はすぐに反映されます。グラスの見え方は壁紙やmacOSの透明度設定で変わります。")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(8)
            }
            GroupBox("クリックで開くアプリ") {
                HStack {
                    Text(applicationName()).lineLimit(1)
                    Spacer()
                    Button("変更…") { chooseApplication(); selectionRevision += 1 }
                    Button("開く") { openCodex() }
                }.padding(8).id(selectionRevision)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("ログイン時に起動", isOn: Binding(
                        get: { model.loginEnabled },
                        set: { model.setLoginEnabled($0) }))
                        .toggleStyle(PaleBlueSwitchStyle())
                        .disabled(model.loginUpdating)
                    if model.loginNeedsApproval {
                        Text("macOSのログイン項目で許可すると有効になります。")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("ログイン項目を開く") { model.openLoginSettings() }
                    }
                    if !model.loginError.isEmpty {
                        Text(model.loginError).font(.caption).foregroundStyle(.orange)
                        Button("ログイン項目を開く") { model.openLoginSettings() }
                    }
                }.padding(8)
            }
            UpdateSettingsView(updater: updater)
            HStack {
                Button(model.busy ? "更新中…" : "今すぐ更新") { model.refresh() }.disabled(model.busy)

                Spacer()
            }
            if !model.detail.isEmpty { Text(model.detail).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true) }
            Text("クリック：Codexを開く　／　右クリック：設定\nドラッグ：移動　／　使用量は5分ごとに自動取得")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24)
        }.frame(width: 500, height: min(720, max(420, (NSScreen.main?.visibleFrame.height ?? 820) - 100)))
        .preferredColorScheme(.dark)
        .tint(Color(red: 0.66, green: 0.85, blue: 0.96))
        .onAppear { model.syncLoginState() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.syncLoginState() }
    }
}

// Draw the switch in the product accent while keeping native Toggle accessibility.
struct PaleBlueSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 10) {
                configuration.label
                Spacer()
                Text(configuration.isOn ? "オン" : "オフ").font(.caption).foregroundStyle(.secondary)
                Capsule()
                    .fill(configuration.isOn ? Color(red: 0.66, green: 0.85, blue: 0.96) : Color.white.opacity(0.16))
                    .frame(width: 38, height: 22)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(.white).frame(width: 18, height: 18).padding(2)
                            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                    }
            }.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.14), value: configuration.isOn)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.switch)
        }
    }
}
