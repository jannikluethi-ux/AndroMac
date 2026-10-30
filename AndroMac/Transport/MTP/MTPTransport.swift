import Foundation

/// MTP transport over an `MTPSession` (LibMTPSession in production; MockMTPSession in tests only).
public actor MTPTransport: AndroidTransport {
    
    public let deviceID: DeviceID
    private let session: any MTPSession
    private var connected = false
    private let pathResolver = MTPPathResolver()
    
    /// Cache: path string → object handle (invalidated on mutations)
    private var pathCache: [String: MTPObjectHandle] = [:]
    private var rootStorage: MTPStorageID?
    
    /// Pass `LibMTPSession` for production or `MockMTPSession` for unit tests. No silent mock default.
    public init(deviceID: DeviceID, session: any MTPSession) {
        self.deviceID = deviceID
        self.session = session
    }
    
    // MARK: - AndroidTransport
    
    public func connect() async throws {
        guard !connected else { return }
        try await session.open()
        let storages = try await session.storageIDs()
        guard let first = storages.first else {
            throw AndroidBridgeError.mtpError("No MTP storage found")
        }
        rootStorage = first
        pathCache.removeAll()
        connected = true
        log("MTP connected (\(deviceID)) storage=\(first)")
    }
    
    public func disconnect() async {
        await session.close()
        connected = false
        pathCache.removeAll()
        rootStorage = nil
        log("MTP disconnected (\(deviceID))")
    }
    
    public func list(_ path: RemotePath) async throws -> [RemoteItem] {
        try requireConnected()
        let parentHandle = try await resolveHandle(for: path)
        let storage = try requireStorage()
        
        let handles = try await session.objectHandles(
            storage: storage,
            parent: parentHandle,
            format: nil
        )
        
        var items: [RemoteItem] = []
        for handle in handles {
            let info = try await session.objectInfo(handle)
            let childPath = join(path, info.filename)
            pathCache[normalize(childPath)] = handle
            
            items.append(RemoteItem(
                id: String(handle.value),
                name: info.filename,
                path: RemotePath(childPath),
                kind: info.isDirectory ? .directory : .file,
                size: info.isDirectory ? nil : Int64(info.objectCompressedSize),
                modified: info.modificationDate,
                isHidden: info.filename.hasPrefix(".")
            ))
        }
        
        items.sort {
            if $0.kind != $1.kind {
                return $0.kind == .directory
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return items
    }
    
    public func stat(_ path: RemotePath) async throws -> RemoteMetadata {
        try requireConnected()
        let handle = try await resolveHandle(for: path)
        let info = try await session.objectInfo(handle)
        return RemoteMetadata(
            path: path,
            kind: info.isDirectory ? .directory : .file,
            size: info.isDirectory ? nil : Int64(info.objectCompressedSize),
            modified: info.modificationDate,
            created: info.captureDate
        )
    }
    
    public func read(
        _ path: RemotePath,
        range: Range<Int64>?
    ) async throws -> AsyncThrowingStream<Data, Error> {
        try requireConnected()
        let handle = try await resolveHandle(for: path)
        let info = try await session.objectInfo(handle)
        guard !info.isDirectory else {
            throw AndroidBridgeError.mtpError("Cannot read a directory")
        }
        
        let byteRange: Range<UInt64>? = range.map { r in
            UInt64(max(0, r.lowerBound))..<UInt64(max(0, r.upperBound))
        }
        
        return try await session.readObject(handle, range: byteRange)
    }
    
    public func write(
        _ path: RemotePath,
        data: AsyncThrowingStream<Data, Error>
    ) async throws {
        try requireConnected()
        let storage = try requireStorage()
        
        let components = pathResolver.components(of: path)
        guard let filename = components.last else {
            throw AndroidBridgeError.mtpError("Invalid write path")
        }
        let parentPath = components.dropLast().isEmpty
            ? "/"
            : "/" + components.dropLast().joined(separator: "/")
        let parentHandle = try await resolveHandle(for: RemotePath(parentPath))
        
        var buffer = Data()
        for try await chunk in data {
            buffer.append(chunk)
        }
        
        let handle = try await session.sendObjectInfo(
            storage: storage,
            parent: parentHandle,
            filename: filename,
            size: UInt64(buffer.count),
            format: .undefined
        )
        
        let stream = AsyncThrowingStream<Data, Error> { cont in
            cont.yield(buffer)
            cont.finish()
        }
        try await session.sendObject(handle, data: stream)
        
        pathCache[normalize(path.rawValue)] = handle
        log("Wrote \(filename) (\(buffer.count) bytes)")
    }
    
    public func createDirectory(_ path: RemotePath) async throws {
        try requireConnected()
        let storage = try requireStorage()
        let components = pathResolver.components(of: path)
        guard let name = components.last else {
            throw AndroidBridgeError.mtpError("Invalid directory path")
        }
        let parentPath = components.dropLast().isEmpty
            ? "/"
            : "/" + components.dropLast().joined(separator: "/")
        let parentHandle = try await resolveHandle(for: RemotePath(parentPath))
        
        let handle = try await session.createFolder(
            storage: storage,
            parent: parentHandle,
            name: name
        )
        pathCache[normalize(path.rawValue)] = handle
    }
    
    public func delete(_ path: RemotePath) async throws {
        try requireConnected()
        let handle = try await resolveHandle(for: path)
        try await session.deleteObject(handle)
        pathCache.removeValue(forKey: normalize(path.rawValue))
    }
    
    public func move(_ source: RemotePath, to destination: RemotePath) async throws {
        throw AndroidBridgeError.unsupportedOperation
    }
    
    // MARK: - Path → handle resolution
    
    private func resolveHandle(for path: RemotePath) async throws -> MTPObjectHandle {
        let key = normalize(path.rawValue)
        if key == "/" || key.isEmpty {
            return MTPObjectHandle(0xFFFFFFFF)
        }
        if let cached = pathCache[key] {
            return cached
        }
        
        var current = MTPObjectHandle(0xFFFFFFFF)
        var built = ""
        let storage = try requireStorage()
        
        for component in pathResolver.components(of: path) {
            built += "/" + component
            let builtKey = normalize(built)
            if let cached = pathCache[builtKey] {
                current = cached
                continue
            }
            
            let children = try await session.objectHandles(
                storage: storage,
                parent: current,
                format: nil
            )
            var found: MTPObjectHandle?
            for h in children {
                let info = try await session.objectInfo(h)
                if info.filename == component {
                    found = h
                    pathCache[builtKey] = h
                    break
                }
            }
            guard let next = found else {
                throw AndroidBridgeError.pathNotFound(path)
            }
            current = next
        }
        return current
    }
    
    private func join(_ parent: RemotePath, _ name: String) -> String {
        let p = normalize(parent.rawValue)
        if p == "/" { return "/\(name)" }
        return "\(p)/\(name)"
    }
    
    private func normalize(_ path: String) -> String {
        var p = path
        if p.isEmpty { return "/" }
        if !p.hasPrefix("/") { p = "/" + p }
        while p.count > 1 && p.hasSuffix("/") {
            p.removeLast()
        }
        return p
    }
    
    private func requireConnected() throws {
        guard connected else { throw AndroidBridgeError.notConnected }
    }
    
    private func requireStorage() throws -> MTPStorageID {
        guard let s = rootStorage else { throw AndroidBridgeError.notConnected }
        return s
    }
    
    private func log(_ message: String) {
        print("[MTPTransport] \(message)")
    }
}
