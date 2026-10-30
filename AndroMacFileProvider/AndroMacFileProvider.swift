import FileProvider
import UniformTypeIdentifiers

/// Thin File Provider adapter. All device I/O goes through XPC.
public class AndroMacFileProvider: NSObject, NSFileProviderReplicatedExtension {
    
    private let domain: NSFileProviderDomain
    private let manager: NSFileProviderManager?
    private let xpc = AndroidBridgeXPCClient()
    
    /// Device ID encoded in the domain identifier: `andromac.<device-id>`
    private var deviceID: String {
        let raw = domain.identifier.rawValue
        if raw.hasPrefix("andromac.") {
            return String(raw.dropFirst("andromac.".count))
                .replacingOccurrences(of: "-", with: ":")
        }
        return raw
    }
    
    required public init(domain: NSFileProviderDomain) {
        self.domain = domain
        self.manager = NSFileProviderManager(for: domain)
        super.init()
        PipelineMetrics.shared.mark("provider_init", deviceID: deviceID)
    }
    
    public func invalidate() {}
    
    public func item(
        for identifier: NSFileProviderItemIdentifier,
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) -> Progress {
        let progress = Progress(totalUnitCount: 1)
        if identifier == .rootContainer {
            completionHandler(
                ProviderItem.root(displayName: domain.displayName),
                nil
            )
            progress.completedUnitCount = 1
            return progress
        }
        
        let path = ItemPathMapper.itemPath(
            from: identifier,
            deviceID: DeviceID(deviceID)
        )
        Task {
            do {
                PipelineMetrics.shared.mark("metadata_start", deviceID: deviceID)
                let meta = try await xpc.metadata(
                    deviceID: deviceID,
                    path: path.remotePath.rawValue
                )
                let item = ProviderItem(
                    identifier: identifier,
                    parent: ItemPathMapper.identifier(for: path.parent),
                    filename: path.components.last ?? domain.displayName,
                    isDirectory: meta.isDirectory,
                    size: meta.size
                )
                completionHandler(item, nil)
            } catch {
                completionHandler(nil, error)
            }
            progress.completedUnitCount = 1
        }
        return progress
    }
    
    public func enumerator(
        for containerItemIdentifier: NSFileProviderItemIdentifier,
        request: NSFileProviderRequest
    ) throws -> NSFileProviderEnumerator {
        LiveEnumerator(
            container: containerItemIdentifier,
            deviceID: deviceID,
            xpc: xpc
        )
    }
    
    public func fetchContents(
        for itemIdentifier: NSFileProviderItemIdentifier,
        version requestedVersion: NSFileProviderItemVersion?,
        request: NSFileProviderRequest,
        completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void
    ) -> Progress {
        let progress = Progress(totalUnitCount: 1)
        let path = ItemPathMapper.itemPath(
            from: itemIdentifier,
            deviceID: DeviceID(deviceID)
        )
        Task {
            do {
                PipelineMetrics.shared.mark("transfer_start", deviceID: deviceID)
                let url = try await xpc.fetchToTempFile(
                    deviceID: deviceID,
                    path: path.remotePath.rawValue
                )
                PipelineMetrics.shared.mark("transfer_end", deviceID: deviceID)
                let item = ProviderItem(
                    identifier: itemIdentifier,
                    parent: ItemPathMapper.identifier(for: path.parent),
                    filename: path.components.last ?? "file",
                    isDirectory: false,
                    size: (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
                )
                completionHandler(url, item, nil)
            } catch {
                completionHandler(nil, nil, error)
            }
            progress.completedUnitCount = 1
        }
        return progress
    }
    
    public func createItem(
        basedOn itemTemplate: NSFileProviderItem,
        fields: NSFileProviderItemFields,
        contents url: URL?,
        options: NSFileProviderCreateItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    ) -> Progress {
        let progress = Progress(totalUnitCount: 1)
        let name = itemTemplate.filename
        let parentID = itemTemplate.parentItemIdentifier
        let parentPath = ItemPathMapper.itemPath(from: parentID, deviceID: DeviceID(deviceID))
        let child = parentPath.child(name)
        
        Task {
            do {
                if itemTemplate.contentType?.conforms(to: .folder) == true {
                    try await xpc.createDirectory(
                        deviceID: deviceID,
                        path: child.remotePath.rawValue
                    )
                } else if let url {
                    try await xpc.writeFromFile(
                        deviceID: deviceID,
                        path: child.remotePath.rawValue,
                        localFile: url
                    )
                }
                let item = ProviderItem(
                    identifier: ItemPathMapper.identifier(for: child),
                    parent: parentID,
                    filename: name,
                    isDirectory: itemTemplate.contentType?.conforms(to: .folder) == true,
                    size: nil
                )
                completionHandler(item, [], false, nil)
            } catch {
                completionHandler(nil, [], false, error)
            }
            progress.completedUnitCount = 1
        }
        return progress
    }
    
    public func modifyItem(
        _ item: NSFileProviderItem,
        baseVersion version: NSFileProviderItemVersion,
        changedFields: NSFileProviderItemFields,
        contents newContents: URL?,
        options: NSFileProviderModifyItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    ) -> Progress {
        let progress = Progress(totalUnitCount: 1)
        completionHandler(nil, [], false, NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError))
        progress.completedUnitCount = 1
        return progress
    }
    
    public func deleteItem(
        identifier: NSFileProviderItemIdentifier,
        baseVersion version: NSFileProviderItemVersion,
        options: NSFileProviderDeleteItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (Error?) -> Void
    ) -> Progress {
        let progress = Progress(totalUnitCount: 1)
        let path = ItemPathMapper.itemPath(from: identifier, deviceID: DeviceID(deviceID))
        Task {
            do {
                try await xpc.deleteItem(deviceID: deviceID, path: path.remotePath.rawValue)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
            progress.completedUnitCount = 1
        }
        return progress
    }
}

// MARK: - Live enumerator (no mock folders)

final class LiveEnumerator: NSObject, NSFileProviderEnumerator {
    private let container: NSFileProviderItemIdentifier
    private let deviceID: String
    private let xpc: AndroidBridgeXPCClient
    
    init(container: NSFileProviderItemIdentifier, deviceID: String, xpc: AndroidBridgeXPCClient) {
        self.container = container
        self.deviceID = deviceID
        self.xpc = xpc
        super.init()
    }
    
    func invalidate() {}
    
    func enumerateItems(
        for observer: NSFileProviderEnumerationObserver,
        startingAt page: NSFileProviderPage
    ) {
        let path = ItemPathMapper.itemPath(
            from: container,
            deviceID: DeviceID(deviceID)
        )
        Task {
            do {
                PipelineMetrics.shared.mark("enum_start", deviceID: deviceID)
                let items = try await xpc.list(
                    deviceID: deviceID,
                    path: path.remotePath.rawValue
                )
                PipelineMetrics.shared.mark("enum_end", deviceID: deviceID)
                
                let providerItems: [NSFileProviderItem] = items.map { remote in
                    let child = path.child(remote.name)
                    return ProviderItem(
                        identifier: ItemPathMapper.identifier(for: child),
                        parent: container,
                        filename: remote.name,
                        isDirectory: remote.isDirectory,
                        size: remote.size
                    )
                }
                observer.didEnumerate(providerItems)
                observer.finishEnumerating(upTo: nil)
            } catch {
                observer.finishEnumeratingWithError(error)
            }
        }
    }
    
    func enumerateChanges(
        for observer: NSFileProviderChangeObserver,
        from syncAnchor: NSFileProviderSyncAnchor
    ) {
        observer.finishEnumeratingChanges(upTo: syncAnchor, moreComing: false)
    }
    
    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        completionHandler(nil)
    }
}

// MARK: - Provider item

struct ProviderItem: NSFileProviderItem {
    var itemIdentifier: NSFileProviderItemIdentifier
    var parentItemIdentifier: NSFileProviderItemIdentifier
    var filename: String
    var contentType: UTType
    var capabilities: NSFileProviderItemCapabilities
    var documentSize: NSNumber?
    
    init(
        identifier: NSFileProviderItemIdentifier,
        parent: NSFileProviderItemIdentifier,
        filename: String,
        isDirectory: Bool,
        size: Int64?
    ) {
        self.itemIdentifier = identifier
        self.parentItemIdentifier = parent
        self.filename = filename
        self.contentType = isDirectory ? .folder : .data
        self.capabilities = isDirectory
            ? [.allowsContentEnumerating, .allowsReading, .allowsAddingSubItems, .allowsDeleting]
            : [.allowsReading, .allowsDeleting, .allowsWriting]
        self.documentSize = size.map { NSNumber(value: $0) }
    }
    
    static func root(displayName: String) -> ProviderItem {
        ProviderItem(
            identifier: .rootContainer,
            parent: .rootContainer,
            filename: displayName,
            isDirectory: true,
            size: nil
        )
    }
}
