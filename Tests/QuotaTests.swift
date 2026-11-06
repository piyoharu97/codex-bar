import Foundation
@main struct QuotaTests {
    static func main() throws {
        func parse(_ json: String) throws -> Snapshot {
            try JSONDecoder().decode(LimitsResponse.self, from: Data(json.utf8)).snapshot()
        }
        let reversed = try parse(#"{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":40,"windowDurationMins":10080,"resetsAt":1900000000},"secondary":{"usedPercent":12.5,"windowDurationMins":300}}}}"#)
        assert(reversed.fiveHour?.remaining == 87.5)
        assert(reversed.weekly?.remaining == 60)
        assert(reversed.weekly?.reset == Date(timeIntervalSince1970: 1900000000))
        let weekly = try parse(#"{"rateLimits":{"primary":{"usedPercent":100,"windowDurationMins":10080},"secondary":null}}"#)
        assert(weekly.fiveHour == nil && weekly.weekly?.remaining == 0)
        let unknown = try parse(#"{"rateLimits":{"primary":{"usedPercent":0,"windowDurationMins":15}}}"#)
        assert(unknown.fiveHour == nil && unknown.weekly == nil)
        do {
            _ = try parse(#"{"rateLimitsByLimitId":{"other":{"primary":{"usedPercent":3,"windowDurationMins":300}}}}"#)
            fatalError("Must not substitute a model bucket")
        } catch FetchError.unsupported { }
        do {
            _ = try parse(#"{"rateLimits":{"primary":{"usedPercent":101,"windowDurationMins":300}}}"#)
            fatalError("Invalid percentage must fail")
        } catch FetchError.protocolError { }
        assert(Snapshot(updatedAt: Date(timeIntervalSince1970: 0)).stale(at: Date(timeIntervalSince1970: 1801)))
        if CommandLine.arguments.count > 1 {
            let url = URL(fileURLWithPath: CommandLine.arguments[1])
            let snapshot = try CodexClient(executable: url).fetch(timeout: 2)
            assert(snapshot.fiveHour?.remaining == 75 && snapshot.weekly?.remaining == 60)
        }
        print("PASS: window mapping, missing windows, timestamp, bucket selection, validation, stale state, RPC fixture")
    }
}
