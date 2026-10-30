import Foundation

/// Thin async wrapper around the `adb` CLI (platform-tools).
/// No Android Studio required — only the `adb` binary on PATH or a bundled copy.
public actor ADBClient {
    
    public enum ClientError: Error, LocalizedError, Sendable {
        case adbNotFound
        case deviceUnauthorized(String)
        case deviceOffline(String)
        case commandFailed(Int32, String)
        case parseError(String)
        
        public var errorDescription: String? {
            switch self {
            case .adbNotFound:
                return "adb not found. Install platform-tools or bundle adb with the app."
            case .deviceUnauthorized(let s):
                return "Device \(s) is unauthorized. Unlock the phone and allow USB debugging."
            case .deviceOffline(let s):
                return "Device \(s) is offline."
            case .commandFailed(let code, let out):
                return "adb failed (\(code)): \(out)"
            case .parseError(let m):
                return "adb parse error: \(m)"
            }
        }
    }
    
    private let adbPath: String
    private let serial: String?
    
    public init(serial: String? = nil, adbPath: String? = nil) {
        self.serial = serial
        self.adbPath = adbPath ?? ADBClient.locateADB() ?? "adb"
    }
    
    // MARK: - Discovery
    
    public struct ListedDevice: Sendable {
        public let serial: String
        public let state: String // device | unauthorized | offline
    }
    
    public func listDevices() async throws -> [ListedDevice] {
        let out = try await run(["devices", "-l"])
        var result: [ListedDevice] = []
        for line in out.split(separator: "\n").dropFirst() {
            let parts = line.split(whereSeparator: { $0.isWhitespace })
            guard parts.count >= 2 else { continue }
            result.append(ListedDevice(serial: String(parts[0]), state: String(parts[1])))
        }
        return result
    }
    
    public func ensureReady() async throws {
        let devices = try await listDevices()
        if let serial {
            guard let d = devices.first(where: { $0.serial == serial }) else {
                throw ClientError.deviceOffline(serial)
            }
            if d.state == "unauthorized" { throw ClientError.deviceUnauthorized(serial) }
            if d.state != "device" { throw ClientError.deviceOffline(serial) }
        } else {
            let ready = devices.filter { $0.state == "device" }
            if ready.isEmpty {
                if devices.contains(where: { $0.state == "unauthorized" }) {
                    throw ClientError.deviceUnauthorized("(any)")
                }
                throw ClientError.deviceOffline("(none)")
            }
        }
    }
    
    // MARK: - Shell / filesystem
    
    public func shell(_ command: String) async throws -> String {
        try await run(serialArgs() + ["shell", command])
    }
    
    public func ls(_ remotePath: String) async throws -> String {
        // -1: one per line; avoid interactive flags
        let escaped = shellEscape(remotePath)
        return try await shell("ls -1a \(escaped) 2>/dev/null || ls -1 \(escaped)")
    }
    
    public func statSize(_ remotePath: String) async throws -> Int64? {
        let escaped = shellEscape(remotePath)
        let out = try await shell("stat -c %s \(escaped) 2>/dev/null || wc -c < \(escaped)")
        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return Int64(trimmed)
    }
    
    public func isDirectory(_ remotePath: String) async throws -> Bool {
        let escaped = shellEscape(remotePath)
        let out = try await shell("[ -d \(escaped) ] && echo DIR || echo FILE")
        return out.contains("DIR")
    }
    
    public func mkdir(_ remotePath: String) async throws {
        let escaped = shellEscape(remotePath)
        _ = try await shell("mkdir -p \(escaped)")
    }
    
    public func rm(_ remotePath: String, recursive: Bool = false) async throws {
        let escaped = shellEscape(remotePath)
        let flag = recursive ? "-rf" : "-f"
        _ = try await shell("rm \(flag) \(escaped)")
    }
    
    public func pullStream(_ remotePath: String) async throws -> AsyncThrowingStream<Data, Error> {
        // adb exec-out cat avoids CR/LF mangling of `adb shell cat`
        let args = serialArgs() + ["exec-out", "cat", remotePath]
        return try await runStreaming(args)
    }
    
    public func push(localData: Data, remotePath: String) async throws {
        // Write temp file then adb push (simple, reliable)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("andromac-push-\(UUID().uuidString)")
        try localData.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        _ = try await run(serialArgs() + ["push", tmp.path, remotePath])
    }
    
    public func pushStream(
        _ data: AsyncThrowingStream<Data, Error>,
        remotePath: String
    ) async throws {
        var buffer = Data()
        for try await chunk in data {
            buffer.append(chunk)
        }
        try await push(localData: buffer, remotePath: remotePath)
    }
    
    // MARK: - Process helpers
    
    private func serialArgs() -> [String] {
        if let serial { return ["-s", serial] }
        return []
    }
    
    private func run(_ args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: adbPath)
            proc.arguments = args
            let outPipe = Pipe()
            let errPipe = Pipe()
            proc.standardOutput = outPipe
            proc.standardError = errPipe
            
            do {
                try proc.run()
            } catch {
                cont.resume(throwing: ClientError.adbNotFound)
                return
            }
            
            proc.terminationHandler = { p in
                let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if p.terminationStatus != 0 {
                    cont.resume(throwing: ClientError.commandFailed(p.terminationStatus, err.isEmpty ? out : err))
                } else {
                    cont.resume(returning: out)
                }
            }
        }
    }
    
    private func runStreaming(_ args: [String]) async throws -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: adbPath)
            proc.arguments = args
            let outPipe = Pipe()
            proc.standardOutput = outPipe
            proc.standardError = Pipe()
            
            do {
                try proc.run()
            } catch {
                continuation.finish(throwing: ClientError.adbNotFound)
                return
            }
            
            let handle = outPipe.fileHandleForReading
            handle.readabilityHandler = { h in
                let data = h.availableData
                if data.isEmpty {
                    h.readabilityHandler = nil
                    proc.waitUntilExit()
                    if proc.terminationStatus != 0 {
                        continuation.finish(throwing: ClientError.commandFailed(proc.terminationStatus, "stream failed"))
                    } else {
                        continuation.finish()
                    }
                } else {
                    continuation.yield(data)
                }
            }
            
            continuation.onTermination = { _ in
                if proc.isRunning { proc.terminate() }
            }
        }
    }
    
    private func shellEscape(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
    
    private static func locateADB() -> String? {
        let candidates = [
            "/opt/homebrew/bin/adb",
            "/usr/local/bin/adb",
            "\(NSHomeDirectory())/Library/Android/sdk/platform-tools/adb",
            "/usr/bin/adb"
        ]
        for c in candidates {
            if FileManager.default.isExecutableFile(atPath: c) { return c }
        }
        return nil
    }
}
