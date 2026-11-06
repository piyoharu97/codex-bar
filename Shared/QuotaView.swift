import SwiftUI
import AppKit

struct QuotaView: View {
    private let accent = Color(red: 0.66, green: 0.85, blue: 0.96)
    let snapshot: Snapshot
    var date = Date()
    var foreground = Color.white
    var secondary = Color.gray
    var logoLabel = "Codex"
    var logo: Image = {
        if let url = Bundle.main.url(forResource: "CodexLogo", withExtension: "png"),
           let image = NSImage(contentsOf: url) { return Image(nsImage: image) }
        return Image(systemName: "terminal")
    }()
    private var status: String {
        if snapshot.error != nil { return snapshot.updatedAt == nil ? "取得エラー · アプリで確認" : "更新失敗 · 前回値" }
        if snapshot.stale(at: date) { return "古いデータ · アプリで更新" }
        return "残り使用量"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                logo
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .accessibilityLabel(logoLabel)
                Spacer()
                Circle().fill(snapshot.error != nil || snapshot.stale(at: date) ? Color.orange : accent).frame(width: 5, height: 5)
            }
            row("5時間", window: snapshot.fiveHour)
            row("週間", window: snapshot.weekly)
            HStack(spacing: 4) {
                Text(status)
                Spacer(minLength: 0)
                if let updated = snapshot.updatedAt { Text(updated, style: .time) }
            }.font(.system(size: 9)).foregroundStyle(secondary).lineLimit(1)
        }
        .foregroundStyle(foreground)
        .accessibilityElement(children: .combine)
    }
    private func row(_ title: String, window: QuotaWindow?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 11)).foregroundStyle(secondary)
                Spacer()
                Text(window.map { "\(Int($0.remaining.rounded(.down)))%" } ?? "—")
                    .font(.system(size: 18, weight: .medium, design: .rounded)).monospacedDigit()
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(foreground.opacity(0.09))
                    Capsule().fill(window.map { $0.remaining <= 10 ? Color.orange : accent } ?? Color.gray)
                        .frame(width: geometry.size.width * (window?.remaining ?? 0) / 100)
                }
            }.frame(height: 4)
            Text(resetLabel(window)).font(.system(size: 9)).foregroundStyle(secondary).lineLimit(1)
        }
    }
    private func resetLabel(_ window: QuotaWindow?) -> String {
        guard let window else { return "この枠は未提供" }
        guard let reset = window.reset else { return "リセット時刻は未提供" }
        if reset <= date { return "リセット時刻経過 · 更新待ち" }
        return "リセット " + reset.formatted(.dateTime.month().day().hour().minute())
    }
}
