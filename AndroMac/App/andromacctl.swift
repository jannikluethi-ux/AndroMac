import Foundation

/// Internal diagnostic CLI entry (developer-only).
/// Wire as a second command-line target or invoke via `swift run` once packaged.
///
/// Commands:
///   andromacctl devices
///   andromacctl ls <deviceID> /
///   andromacctl pull <deviceID> /path ./local
///   andromacctl push <deviceID> ./local /path
enum AndroMacCTL {
    
    static func run(args: [String]) async {
        guard args.count >= 1 else {
            print("Usage: andromacctl devices|ls|pull|push|metrics")
            return
        }
        switch args[0] {
        case "devices":
            await DeviceManager.shared.startUSBDiscovery()
            try? await Task.sleep(nanoseconds: 500_000_000)
            let list = await DeviceManager.shared.knownDevices()
            for d in list {
                print("\(d.id.value)\t\(d.displayName)\tvid=\(d.usbVendorID.map { String(format: "%04x", $0) } ?? "?")")
            }
        case "metrics":
            print(PipelineMetrics.shared.report())
        case "ls":
            guard args.count >= 3 else { print("ls <deviceID> <path>"); return }
            do {
                let t = try await ConnectionSessionStore.shared.transport(for: DeviceID(args[1]))
                let items = try await t.list(RemotePath(args[2]))
                for i in items {
                    print("\(i.kind == .directory ? "DIR" : "FILE")\t\(i.name)\t\(i.size.map(String.init) ?? "-")")
                }
            } catch {
                print("Error: \(error)")
            }
        default:
            print("Unknown command \(args[0])")
        }
    }
}
