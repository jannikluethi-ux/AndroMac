# Android Finder Bridge — Senior Engineer Specification

## Product
A native macOS utility that exposes connected Android smartphones as first-class Finder Locations.

### Product promise
**Plug in your Android. It appears in Finder.**

## Non-goals
- Electron
- custom Finder replacement
- kernel extension
- macFUSE dependency
- cloud dependency for USB transfer
- mandatory Android companion app
- manual connection workflow

## Recommended stack
- Swift
- SwiftUI for application UI
- File Provider (`NSFileProviderReplicatedExtension`) for Finder integration
- Swift concurrency
- SQLite for local transfer/device state
- Hardened Runtime
- Developer ID signing + notarization

## System architecture

    Finder
       |
       v
    File Provider Extension
       |
       | XPC
       v
    Host Application
       |
       +---- Device Manager
       |
       +---- Transfer Coordinator
       |
       +---- MTP Transport
       |
       +---- ADB Transport
                    |
                    v
              Android Device

The File Provider extension should not own the entire transport lifecycle. Centralize device/session management in the host app and communicate through a carefully defined XPC boundary.

## Transport abstraction

```swift
protocol AndroidTransport: Sendable {
    var deviceID: DeviceID { get }
    func connect() async throws
    func disconnect() async
    func list(_ path: RemotePath) async throws -> [RemoteItem]
    func stat(_ path: RemotePath) async throws -> RemoteMetadata
    func read(_ path: RemotePath,
              range: Range<Int64>?) async throws
              -> AsyncThrowingStream<Data, Error>
    func write(_ path: RemotePath,
               data: AsyncThrowingStream<Data, Error>) async throws
    func createDirectory(_ path: RemotePath) async throws
    func delete(_ path: RemotePath) async throws
    func move(_ source: RemotePath,
              to destination: RemotePath) async throws
}
```

Implement:
- `MTPTransport`
- `ADBTransport`

The rest of the application must not depend directly on either implementation.

## Transport selection

Prefer ADB when it is authorized and usable. Otherwise use MTP when exposed by the phone. If neither is available, surface a useful user-facing explanation.

The user should not need to understand MTP versus ADB.

## Device identity

Do not identify devices only by model name.

Maintain a stable internal identity using the strongest available identifiers:
- Android serial where available
- USB identifiers
- manufacturer/model
- persistent local identifier

Allow a user-facing display name such as `John's Pixel 10`.

## Finder behavior

Expected Finder structure:

    Finder
    └── Locations
        ├── Macintosh HD
        └── Android Phone

Opening the Android location should expose storage/folders such as:

    Internal Storage
    ├── DCIM
    ├── Download
    ├── Documents
    ├── Movies
    ├── Music
    └── Pictures

MVP Finder operations:
- enumerate folders
- read metadata
- copy Android → Mac
- copy Mac → Android
- create folder
- rename/move
- delete
- cancellation
- error propagation

## Device lifecycle

Connected:
USB notification → identify device → establish transport → create/register File Provider domain → Finder becomes usable.

Disconnected:
transport failure/event → invalidate active transfers → update provider → mark device unavailable.

Reconnect:
recognize stable identity → establish transport → revive/register provider domain → Finder usable without restarting Finder or the application.

Do not implement periodic polling as the primary lifecycle mechanism.

## Concurrency

Use Swift concurrency. Suggested actors:
- `DeviceManager`
- `ConnectionSession`
- `TransferCoordinator`
- transport actors

Keep mutable shared state isolated.

## Transfer engine

Transfer model should include:
- ID
- source
- destination
- direction
- bytes transferred
- total bytes
- speed
- state
- error
- start/end timestamps

States:
`queued`, `connecting`, `transferring`, `paused`, `cancelling`, `completed`, `failed`, `cancelled`

All large-file transfers must stream. Do not load entire files into memory.

Support at least 100 MB, 1 GB, 4 GB, 10 GB and 50 GB test cases.

Use temporary destinations and atomic rename patterns where transport semantics permit.

## Reliability matrix

Test:
- cable removed during transfer
- phone locked
- phone screen off
- phone battery dies
- USB mode changes
- ADB authorization revoked
- MTP session dies
- phone reconnects
- Mac sleep/wake
- Finder restart
- application restart
- multiple phones
- identical phone models
- SD card removal
- file deleted during enumeration
- emoji filenames
- CJK filenames
- very large directories
- files >4 GB
- USB 2
- USB 3
- flaky cables

The expected behavior is recovery, not reboot/reinstall.

## Diagnostics

Advanced diagnostics should expose:
- device identity
- manufacturer/model
- Android version
- USB vendor/product IDs
- USB speed
- active transport
- connection state
- provider state
- enumeration time
- first-listing time
- read/write speed
- last errors

Provide a redacted diagnostics export. Never include file contents.

## Security
Default:
- local processing
- no cloud requirement
- no account
- no file-content telemetry

Use least-privilege macOS entitlements, Hardened Runtime, Developer ID signing and notarization.

## Performance targets

Targets to validate experimentally:
- USB insertion → detection: <1s
- detection → Finder provider registration: <2s
- first directory listing: <500ms for normal directories

Do not publish speed claims until benchmarked.

## Repository layout

    AndroidBridge/
    ├── App/
    ├── Device/
    ├── Transport/
    │   ├── MTP/
    │   └── ADB/
    ├── FileProvider/
    ├── Transfer/
    ├── Persistence/
    ├── Diagnostics/
    ├── UI/
    ├── Shared/
    └── Tests/
        ├── Unit/
        ├── Integration/
        └── Hardware/

## Definition of done

A clean Mac can install the app, connect a Pixel or Samsung via USB, unlock/select File Transfer if required, and see the phone under Finder → Locations within a few seconds.

The user can browse DCIM, transfer a 5 GB file in either direction, disconnect/reconnect, and continue without restarting Finder or the application.

The same workflow must work on another Android manufacturer before beta.

## Roadmap

### Phase 1 — MVP
USB discovery, MTP, ADB, File Provider, Finder integration, bidirectional transfers, file operations, reconnect, multi-device, signing/notarization.

### Phase 2
Wireless ADB, automatic imports, transfer profiles, duplicate detection, checksums, media ingestion, background transfers, thumbnails, Quick Look optimization, Spotlight.

### Phase 3
NAS destinations, scheduled/encrypted backups, incremental backups, automated media workflows, CLI, Shortcuts integration, developer API.

## Engineering rule
Build the vertical slice first. Do not spend weeks building infrastructure before proving:

Android → USB → transport → File Provider → Finder → directory listing → 1 GB transfer → integrity verification.
