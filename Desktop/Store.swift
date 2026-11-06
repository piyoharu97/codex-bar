import Foundation

enum Store {
    static func url() throws -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CodexQuotaDesktop", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        return root.appendingPathComponent("quota.json")
    }
    static func read() -> Snapshot {
        guard let url = try? url(), let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return .empty }
        return snapshot
    }
    static func write(_ snapshot: Snapshot) throws {
        let url = try url()
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
