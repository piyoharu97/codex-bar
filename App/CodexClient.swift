import Foundation
import Darwin

struct CodexClient {
    let executable: URL
    func fetch(timeout: TimeInterval = 25) throws -> Snapshot {
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { throw FetchError.executable }
        let process = Process()
        process.executableURL = executable
        process.arguments = ["app-server", "--stdio"]
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        // Never log server output, account details or credentials.
        process.standardError = FileHandle.nullDevice
        try process.run()
        defer {
            try? input.fileHandleForWriting.close()
            if process.isRunning {
                process.terminate()
                let stop = Date().addingTimeInterval(1)
                while process.isRunning && Date() < stop { Thread.sleep(forTimeInterval: 0.02) }
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
            process.waitUntilExit()
            try? output.fileHandleForReading.close()
        }
        let deadline = Date().addingTimeInterval(timeout)
        var buffer = Data()
        var total = 0
        func send(_ object: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: object)
            data.append(10)
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        func response(_ id: Int) throws -> [String: Any] {
            while Date() < deadline {
                if let newline = buffer.firstIndex(of: 10) {
                    let line = buffer.prefix(upTo: newline)
                    buffer.removeSubrange(...newline)
                    guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
                    guard (obj["id"] as? Int) == id else { continue }
                    if obj["error"] != nil { throw FetchError.unavailable }
                    guard let result = obj["result"] as? [String: Any] else { throw FetchError.protocolError }
                    return result
                }
                var fd = pollfd(fd: output.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0)
                let ready = poll(&fd, 1, 200)
                if ready < 0 { if errno == EINTR { continue }; throw FetchError.unavailable }
                if ready == 0 { continue }
                var bytes = [UInt8](repeating: 0, count: 8192)
                let n = Darwin.read(fd.fd, &bytes, bytes.count)
                guard n > 0 else { throw FetchError.unavailable }
                total += n
                guard total <= 2_000_000 else { throw FetchError.protocolError }
                buffer.append(contentsOf: bytes.prefix(n))
            }
            throw FetchError.timeout
        }
        try send(["id": 1, "method": "initialize", "params": ["clientInfo": ["name": "codex_quota_widget", "version": "1.0.0"]]])
        _ = try response(1)
        try send(["method": "initialized", "params": [:]])
        try send(["id": 2, "method": "account/rateLimits/read"])
        let result = try response(2)
        let data = try JSONSerialization.data(withJSONObject: result)
        do { return try JSONDecoder().decode(LimitsResponse.self, from: data).snapshot() }
        catch let error as FetchError { throw error }
        catch { throw FetchError.protocolError }
    }
}
