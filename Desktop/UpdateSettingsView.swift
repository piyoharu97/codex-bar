import SwiftUI

struct UpdateSettingsView: View {
    @ObservedObject var updater: UpdateModel
    @State private var token = ""
    @State private var editingToken = false
    var body: some View {
        GroupBox("アップデート") {
            VStack(alignment: .leading, spacing: 12) {
                Text(updater.status).font(.caption).foregroundStyle(updater.updateAvailable ? Color(red: 0.66, green: 0.85, blue: 0.96) : .secondary)
                HStack {
                    Button(updater.busy ? "確認中…" : "更新を確認") { updater.check(manual: true) }
                        .disabled(updater.busy || !updater.hasToken)
                    Button(updater.updateAvailable ? "新しいバージョンを開く" : "GitHubの配布ページ") { updater.openReleases() }
                }
                Toggle("更新を自動で確認", isOn: $updater.automaticChecks).toggleStyle(PaleBlueSwitchStyle())
                    .disabled(!updater.hasToken)
                Text("1日1回確認します。インストールは配布ページから手動で行います。")
                    .font(.caption).foregroundStyle(.secondary)
                if !updater.notificationAllowed { Button("更新通知を許可…") { updater.allowNotifications() } }
                if updater.hasToken && !editingToken {
                    HStack {
                        Text("GitHubトークン：キーチェーンに保存済み").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("変更…") { editingToken = true }
                        Button("削除") { updater.removeToken() }
                    }
                } else {
                    Text("非公開GitHubへのアクセス用です。このリポジトリだけのContents読み取り権限を指定し、Macごとに設定してください。")
                        .font(.caption).foregroundStyle(.secondary)
                    SecureField("GitHubの読み取り用トークン", text: $token)
                    HStack {
                        Button("保存して確認") { updater.saveToken(token); token = ""; editingToken = false }
                            .disabled(token.isEmpty || updater.busy)
                        Button("GitHubでトークンを作成") { updater.openTokenSettings() }
                    }
                }
            }.padding(8)
        }
    }
}
