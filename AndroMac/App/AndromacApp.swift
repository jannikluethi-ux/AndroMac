import SwiftUI

@main
struct AndromacApp: App {
    @StateObject private var appModel = AppModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        
        MenuBarExtra("Andromac", systemImage: "cable.connector") {
            MenuBarView()
                .environmentObject(appModel)
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var devices: [DeviceInfo] = []
    @Published var statusMessage: String = "Waiting for Android device…"
    @Published var lastError: String?
    
    private var observerID: UUID?
    
    init() {
        Task {
            await DeviceManager.shared.startUSBDiscovery()
            observerID = await DeviceManager.shared.addObserver { [weak self] event in
                Task { @MainActor in
                    self?.handle(event)
                }
            }
            await refreshDevices()
        }
    }
    
    private func handle(_ event: DeviceManager.DeviceEvent) {
        switch event {
        case .connected(let info):
            statusMessage = "Connected: \(info.displayName)"
            lastError = nil
            PipelineMetrics.shared.mark("usb_detected", deviceID: info.id.value)
            Task {
                // Establish transport session (host-side)
                let session = await ConnectionSessionStore.shared.session(for: info)
                do {
                    _ = try await session.ensureConnected()
                    PipelineMetrics.shared.mark("session_ready", deviceID: info.id.value)
                } catch {
                    lastError = "Transport: \(error.localizedDescription)"
                }
                do {
                    try await DomainRegistrar.register(device: info)
                    PipelineMetrics.shared.mark("provider_registered", deviceID: info.id.value)
                } catch {
                    lastError = "File Provider domain: \(error.localizedDescription)"
                }
                await refreshDevices()
            }
        case .disconnected(let id):
            statusMessage = "Disconnected: \(id)"
            Task {
                await ConnectionSessionStore.shared.remove(id)
                try? await DomainRegistrar.unregister(deviceID: id)
                await refreshDevices()
            }
        case .stateChanged(_, let state):
            statusMessage = "State: \(state.rawValue)"
        }
    }
    
    func refreshDevices() async {
        devices = await DeviceManager.shared.knownDevices()
    }
}
