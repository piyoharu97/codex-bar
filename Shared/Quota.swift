import Foundation

struct QuotaWindow: Codable, Sendable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Double?
    var remaining: Double { max(0, min(100, 100 - usedPercent)) }
    var reset: Date? { resetsAt.map(Date.init(timeIntervalSince1970:)) }
}
struct QuotaBucket: Decodable {
    let limitId: String?
    let primary: QuotaWindow?
    let secondary: QuotaWindow?
}
struct LimitsResponse: Decodable {
    let rateLimits: QuotaBucket?
    let rateLimitsByLimitId: [String: QuotaBucket]?
    func snapshot(now: Date = Date()) throws -> Snapshot {
        // Never silently substitute a model-specific bucket for the Codex account bucket.
        let bucket: QuotaBucket?
        if let map = rateLimitsByLimitId, !map.isEmpty { bucket = map["codex"] }
        else if rateLimits?.limitId == nil || rateLimits?.limitId == "codex" { bucket = rateLimits }
        else { bucket = nil }
        guard let bucket else { throw FetchError.unsupported }
        let windows = [bucket.primary, bucket.secondary].compactMap { $0 }
        guard windows.allSatisfy({ $0.usedPercent.isFinite && (0...100).contains($0.usedPercent) }) else {
            throw FetchError.protocolError
        }
        return Snapshot(updatedAt: now,
                        fiveHour: windows.first { $0.windowDurationMins == 300 },
                        weekly: windows.first { $0.windowDurationMins == 10080 },
                        error: nil)
    }
}
struct Snapshot: Codable, Sendable {
    var updatedAt: Date?
    var fiveHour: QuotaWindow?
    var weekly: QuotaWindow?
    var error: String?
    static let empty = Snapshot(error: "アプリを開いて初回更新")
    func stale(at date: Date) -> Bool { updatedAt.map { date.timeIntervalSince($0) > 1800 } ?? true }
}
enum FetchError: Error, LocalizedError {
    case executable, timeout, protocolError, unavailable, unsupported
    var errorDescription: String? {
        switch self {
        case .executable: return "Codex実行ファイルを選択してください"
        case .timeout: return "取得がタイムアウトしました。接続を確認"
        case .protocolError: return "Codexの応答形式を確認できません。CLIを更新"
        case .unavailable: return "取得できません。CodexのChatGPTログインと接続を確認"
        case .unsupported: return "Codex共通枠が返されません。このアカウントでは未提供"
        }
    }
}
