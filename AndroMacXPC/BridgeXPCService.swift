import Foundation

/// XPC service implementation. Owns access to DeviceManager + transports.
/// File Provider never touches USB/MTP directly.
public final class BridgeXPCService: NSObject, AndroidBridgeXPCProtocol {
    
    private let sessions = ConnectionSessionStore.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    public func listDevices(with reply: @escaping ([Data]?, Error?) -> Void) {
        Task {
            let devices = await DeviceManager.shared.knownDevices()
            let payload = devices.compactMap { try? encoder.encode(XPCDeviceDescriptor(from: $0)) }
            reply(payload, nil)
        }
    }
    
    public func listDirectory(
        deviceID: String,
        path: String,
        with reply: @escaping ([Data]?, Error?) -> Void
    ) {
        Task {
            do {
                let transport = try await sessions.transport(for: DeviceID(deviceID))
                let items = try await transport.list(RemotePath(path))
                let payload = items.compactMap { try? encoder.encode(XPCRemoteItem(from: $0)) }
                reply(payload, nil)
            } catch {
                reply(nil, error)
            }
        }
    }
    
    public func metadata(
        deviceID: String,
        path: String,
        with reply: @escaping (Data?, Error?) -> Void
    ) {
        Task {
            do {
                let transport = try await sessions.transport(for: DeviceID(deviceID))
                let meta = try await transport.stat(RemotePath(path))
                reply(try encoder.encode(XPCRemoteMetadata(from: meta)), nil)
            } catch {
                reply(nil, error)
            }
        }
    }
    
    public func fetchToTempFile(
        deviceID: String,
        path: String,
        with reply: @escaping (String?, Error?) -> Void
    ) {
        Task {
            do {
                let transport = try await sessions.transport(for: DeviceID(deviceID))
                let remote = RemotePath(path)
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("andromac-\(UUID().uuidString)")
                _ = try await TransferCoordinator.shared.pull(
                    from: remote,
                    to: tmp,
                    using: transport
                )
                reply(tmp.path, nil)
            } catch {
                reply(nil, error)
            }
        }
    }
    
    public func writeFromFile(
        deviceID: String,
        path: String,
        localFilePath: String,
        with reply: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                let transport = try await sessions.transport(for: DeviceID(deviceID))
                let url = URL(fileURLWithPath: localFilePath)
                _ = try await TransferCoordinator.shared.push(
                    from: url,
                    to: RemotePath(path),
                    using: transport
                )
                reply(nil)
            } catch {
                reply(error)
            }
        }
    }
    
    public func createDirectory(
        deviceID: String,
        path: String,
        with reply: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                let transport = try await sessions.transport(for: DeviceID(deviceID))
                try await transport.createDirectory(RemotePath(path))
                reply(nil)
            } catch {
                reply(error)
            }
        }
    }
    
    public func deleteItem(
        deviceID: String,
        path: String,
        with reply: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                let transport = try await sessions.transport(for: DeviceID(deviceID))
                try await transport.delete(RemotePath(path))
                reply(nil)
            } catch {
                reply(error)
            }
        }
    }
}

// MARK: - XPC listener entry

@main
struct AndroMacXPCMain {
    static func main() {
        let delegate = ServiceDelegate()
        let listener = NSXPCListener.service()
        listener.delegate = delegate
        listener.resume()
        RunLoop.current.run()
    }
}

final class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: AndroidBridgeXPCProtocol.self)
        newConnection.exportedObject = BridgeXPCService()
        newConnection.resume()
        return true
    }
}
