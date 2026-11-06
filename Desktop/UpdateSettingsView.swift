import SwiftUI

struct UpdateSettingsView: View {
    @ObservedObject var updater: UpdateModel
    var body: some View {
        GroupBox("アップデート") {
            VStack(alignment: .leading, spacing: 12) {
                Text(updater.status).font(.caption).foregroundStyle(updater.updateAvailable ? Color(red: 0.66, green: 0.85, blue: 0.96) : .secondary)
                HStack {
                    Button(updater.busy ? "確認中…" : "更新を確認") { updater.check(manual: true) }
                        .disabled(updater.busy)
                    Button(updater.updateAvailable ? "新しいバージョンを開く" : "GitHubの配布ページ") { updater.openReleases() }
                }
                Toggle("更新を自動で確認", isOn: $updater.automaticChecks).toggleStyle(PaleBlueSwitchStyle())
                Text("1日1回確認します。インストールは配布ページから手動で行います。")
                    .font(.caption).foregroundStyle(.secondary)
                if !updater.notificationAllowed { Button("更新通知を許可…") { updater.allowNotifications() } }
                Text("GitHubへのログイン・トークン設定は不要です。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(8)
        }
    }
}
