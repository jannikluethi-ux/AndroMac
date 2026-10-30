import Foundation
import IOKit
import IOKit.usb

/// Central actor that owns device discovery and lifecycle.
/// Primary discovery is event-driven via IOKit USB notifications (no polling).
public actor DeviceManager {
    
    public static let shared = DeviceManager()
    
    private var devices: [DeviceID: DeviceInfo] = [:]
    private var states: [DeviceID: ConnectionState] = [:]
    /// locationID → DeviceID for fast detach lookup
    private var locationToDeviceID: [UInt32: DeviceID] = [:]
    private var observers: [UUID: @Sendable (DeviceEvent) -> Void] = [:]
    
    private let usbDiscovery = USBDiscovery()
    private var discoveryStarted = false
    
    public enum DeviceEvent: Sendable {
        case connected(DeviceInfo)
        case disconnected(DeviceID)
        case stateChanged(DeviceID, ConnectionState)
    }
    
    private init() {}
    
    // MARK: - Observation
    
    public func addObserver(_ handler: @escaping @Sendable (DeviceEvent) -> Void) -> UUID {
        let id = UUID()
        observers[id] = handler
        return id
    }
    
    public func removeObserver(_ id: UUID) {
        observers.removeValue(forKey: id)
    }
    
    private func notify(_ event: DeviceEvent) {
        for handler in observers.values {
            handler(event)
        }
    }
    
    // MARK: - Public API
    
    public func knownDevices() -> [DeviceInfo] {
        Array(devices.values)
    }
    
    public func state(for id: DeviceID) -> ConnectionState {
        states[id] ?? .disconnected
    }
    
    public func updateState(_ id: DeviceID, to newState: ConnectionState) {
        states[id] = newState
        notify(.stateChanged(id, newState))
    }
    
    // MARK: - Discovery (IOKit)
    
    /// Start listening for USB device attach/detach.
    /// Call once from the host app at launch.
    public func startUSBDiscovery() {
        guard !discoveryStarted else { return }
        discoveryStarted = true
        
        usbDiscovery.onEvent = { [weak self] event in
            Task { [weak self] in
                await self?.handleUSBEvent(event)
            }
        }
        usbDiscovery.start()
        log("USB discovery started (IOKit)")
    }
    
    public func stopUSBDiscovery() {
        usbDiscovery.stop()
        discoveryStarted = false
        log("USB discovery stopped")
    }
    
    // MARK: - Event handling
    
    private func handleUSBEvent(_ event: USBDiscovery.Event) {
        switch event {
        case .attached(let snap):
            handleUSBAttach(snap)
        case .detached(let locationID):
            handleUSBDetach(locationID: locationID)
        }
    }
    
    private func handleUSBAttach(_ snap: USBDiscovery.USBDeviceSnapshot) {
        let id = DeviceInfo.makeStableID(
            serial: snap.serial,
            usbSerial: snap.serial,
            vendorID: snap.vendorID,
            productID: snap.productID,
            model: snap.productName
        )
        
        let profile = DeviceProfile.match(
            manufacturer: snap.vendorName,
            model: snap.productName,
            vendorID: snap.vendorID
        )
        let displayName = profile?.displayNameTemplate
            ?? snap.productName
            ?? snap.vendorName.map { "\($0) Device" }
            ?? "Android Device"
        
        let info = DeviceInfo(
            id: id,
            displayName: displayName,
            manufacturer: snap.vendorName ?? profile?.manufacturerMatch,
            model: snap.productName ?? profile?.modelMatch,
            serial: snap.serial,
            usbVendorID: snap.vendorID,
            usbProductID: snap.productID,
            usbSerial: snap.serial
        )
        
        devices[id] = info
        states[id] = .connected
        if snap.locationID != 0 {
            locationToDeviceID[snap.locationID] = id
        }
        
        notify(.connected(info))
        log("Device attached: \(info.displayName) vid=\(String(format: "%04x", snap.vendorID)) pid=\(String(format: "%04x", snap.productID)) (\(id))")
    }
    
    private func handleUSBDetach(locationID: UInt32) {
        guard let id = locationToDeviceID.removeValue(forKey: locationID) else {
            log("Detach for unknown locationID \(locationID)")
            return
        }
        devices.removeValue(forKey: id)
        states[id] = .disconnected
        notify(.disconnected(id))
        log("Device detached: \(id)")
    }
    
    // MARK: - Logging helper
    
    private func log(_ message: String) {
        print("[DeviceManager] \(message)")
    }
}
