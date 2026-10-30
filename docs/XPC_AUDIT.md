# XPC Audit

## Intended path

```text
Finder → AndroMacFileProvider → NSXPCConnection (com.andromac.bridge)
       → BridgeXPCService → ConnectionSessionStore → AndroidTransport
```

## Protocol

`AndroidBridgeXPCProtocol` (`Shared/XPC/AndroidBridgeXPCProtocol.swift`):

| Method | Payload |
|--------|---------|
| listDevices | `[Data]` JSON `XPCDeviceDescriptor` |
| listDirectory | deviceID, path → `[Data]` JSON `XPCRemoteItem` |
| metadata | deviceID, path → `Data` JSON `XPCRemoteMetadata` |
| fetchToTempFile | deviceID, path → temp file path string |
| writeFromFile | deviceID, path, localFilePath |
| createDirectory / deleteItem | deviceID, path |

## Boundary rules (architecture)

**Must not cross XPC:** USB handles, MTP C pointers, `io_service_t`, adb process internals.

**Does cross XPC:** String device IDs, path strings, Codable JSON blobs, file paths for temp transfer files.

## Client / service

| Piece | Location |
|-------|----------|
| Client | `AndroidBridgeXPCClient` — used by File Provider |
| Service | `BridgeXPCService` + `AndroMacXPCMain` |
| Service name | `com.andromac.bridge` |

## Lifecycle

- Host app starts USB discovery; on connect creates `ConnectionSession` and registers File Provider domain
- Extension connects to XPC service for each enumeration/fetch
- On disconnect: session removed, domain unregistered

## Errors

Errors returned as `Error` on reply blocks; client maps to thrown Swift errors. Not yet mapped to NSFileProviderError codes systematically — **technical debt**.

## Reconnect

Domain re-register on attach; session recreated on next transport request. **UNVERIFIED** on hardware.

## Status

| Check | Result |
|-------|--------|
| Typed serializable API | Implemented in source |
| No raw handles in protocol | PASS (source review) |
| Service runs on Mac | **BLOCKED BY ENVIRONMENT** |
| Extension → service round-trip | **BLOCKED BY ENVIRONMENT** |
