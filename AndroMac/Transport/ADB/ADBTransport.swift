import Foundation

/// ADB transport. Prefer when the device has authorized ADB.
/// Uses platform-tools `adb` — no Android Studio required.
public actor ADBTransport: AndroidTransport {
    
    public let deviceID: DeviceID
    private let client: ADBClient
    private var isConnected = false
    /// Android path prefix for "shared storage" (most phones)
    private let storageRoot = "/sdcard"
    
    public init(deviceID: DeviceID, serial: String? = nil) {
        self.deviceID = deviceID
        self.client = ADBClient(serial: serial)
    }
    
    public func connect() async throws {
        guard !isConnected else { return }
        do {
            try await client.ensureReady()
        } catch let e as ADBClient.ClientError {
            throw mapError(e)
        }
        isConnected = true
        log("ADB connected for \(deviceID)")
    }
    
    public func disconnect() async {
        isConnected = false
        log("ADB disconnected for \(deviceID)")
    }
    
    public func list(_ path: RemotePath) async throws -> [RemoteItem] {
        try requireConnected()
        let remote = toAndroidPath(path)
        do {
            let listing = try await client.ls(remote)
            var items: [RemoteItem] = []
            for name in listing.split(separator: "\n").map(String.init) {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed == "." || trimmed == ".." { continue }
                let childRemote = remote == "/" ? "/\(trimmed)" : "\(remote)/\(trimmed)"
                let childPath = fromAndroidPath(childRemote)
                let isDir = (try? await client.isDirectory(childRemote)) ?? false
                var size: Int64? = nil
                if !isDir {
                    size = try? await client.statSize(childRemote)
                }
                items.append(RemoteItem(
                    id: childPath.rawValue,
                    name: trimmed,
                    path: childPath,
                    kind: isDir ? .directory : .file,
                    size: size,
                    modified: nil,
                    isHidden: trimmed.hasPrefix(".")
                ))
            }
            items.sort {
                if $0.kind != $1.kind { return $0.kind == .directory }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return items
        } catch let e as ADBClient.ClientError {
            throw mapError(e)
        }
    }
    
    public func stat(_ path: RemotePath) async throws -> RemoteMetadata {
        try requireConnected()
        let remote = toAndroidPath(path)
        do {
            let isDir = try await client.isDirectory(remote)
            let size = isDir ? nil : try await client.statSize(remote)
            return RemoteMetadata(
                path: path,
                kind: isDir ? .directory : .file,
                size: size
            )
        } catch let e as ADBClient.ClientError {
            throw mapError(e)
        }
    }
    
    public func read(
        _ path: RemotePath,
        range: Range<Int64>?
    ) async throws -> AsyncThrowingStream<Data, Error> {
        try requireConnected()
        // Range not implemented via simple cat; full stream for M3
        let remote = toAndroidPath(path)
        do {
            return try await client.pullStream(remote)
        } catch let e as ADBClient.ClientError {
            throw mapError(e)
        }
    }
    
    public func write(
        _ path: RemotePath,
        data: AsyncThrowingStream<Data, Error>
    ) async throws {
        try requireConnected()
        let remote = toAndroidPath(path)
        do {
            try await client.pushStream(data, remotePath: remote)
        } catch let e as ADBClient.ClientError {
            throw mapError(e)
        }
    }
    
    public func createDirectory(_ path: RemotePath) async throws {
        try requireConnected()
        let remote = toAndroidPath(path)
        do {
            try await client.mkdir(remote)
        } catch let e as ADBClient.ClientError {
            throw mapError(e)
        }
    }
    
    public func delete(_ path: RemotePath) async throws {
        try requireConnected()
        let remote = toAndroidPath(path)
        do {
            let isDir = try await client.isDirectory(remote)
            try await client.rm(remote, recursive: isDir)
        } catch let e as ADBClient.ClientError {
            throw mapError(e)
        }
    }
    
    public func move(_ source: RemotePath, to destination: RemotePath) async throws {
        try requireConnected()
        let s = toAndroidPath(source)
        let d = toAndroidPath(destination)
        do {
            _ = try await client.shell("mv \(shellQuote(s)) \(shellQuote(d))")
        } catch let e as ADBClient.ClientError {
            throw mapError(e)
        }
    }
    
    // MARK: - Path mapping
    
    /// App paths are like /DCIM/... → /sdcard/DCIM/...
    private func toAndroidPath(_ path: RemotePath) -> String {
        let p = path.rawValue
        if p == "/" || p.isEmpty { return storageRoot }
        if p.hasPrefix("/sdcard") { return p }
        return storageRoot + (p.hasPrefix("/") ? p : "/" + p)
    }
    
    private func fromAndroidPath(_ android: String) -> RemotePath {
        if android == storageRoot { return RemotePath.root }
        if android.hasPrefix(storageRoot + "/") {
            return RemotePath(String(android.dropFirst(storageRoot.count)))
        }
        return RemotePath(android)
    }
    
    private func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
    
    private func requireConnected() throws {
        guard isConnected else { throw AndroidBridgeError.notConnected }
    }
    
    private func mapError(_ e: ADBClient.ClientError) -> AndroidBridgeError {
        switch e {
        case .adbNotFound:
            return .adbError("adb binary not found")
        case .deviceUnauthorized:
            return .permissionDenied
        case .deviceOffline:
            return .deviceNotFound
        case .commandFailed(_, let msg):
            return .adbError(msg)
        case .parseError(let msg):
            return .adbError(msg)
        }
    }
    
    private func log(_ message: String) {
        print("[ADBTransport] \(message)")
    }
}
