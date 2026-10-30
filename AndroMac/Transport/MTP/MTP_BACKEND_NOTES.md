# MTP Backend Notes (Andromac M2)

## Current state

| Piece | Status |
|-------|--------|
| Protocol constants & object model | Done |
| `MTPSession` protocol | Done |
| `MockMTPSession` (Android-like tree + streaming) | Done |
| `MTPTransport` (path resolution, list/read/write/mkdir/delete) | Done |
| Unit tests against mock | Done |
| Real USB MTP (libmtp or pure Swift) | Not yet |

## How to plug in a real backend

Implement `MTPSession` and pass it into `MTPTransport`:

```swift
let session = try await LibMTPSession(deviceSerial: "...")
let transport = MTPTransport(deviceID: id, session: session)
try await transport.connect()
```

### Option A — libmtp (fastest path to real devices)

1. `brew install libmtp` (dev machine only; ship a static/dylib with the app later)
2. Create a C bridging header / Clang module for `libmtp.h`
3. Implement `LibMTPSession: MTPSession` wrapping:
   - `LIBMTP_Get_Connected_Devices` / `LIBMTP_Open_Raw_Device_Uncached`
   - `LIBMTP_Get_Storage_Info`
   - `LIBMTP_Get_Files_And_Folders` or handle-based APIs
   - `LIBMTP_Get_File_To_File_Descriptor` / partial get for streaming
   - `LIBMTP_Send_File_From_File_Descriptor`
4. Watch for macOS issues: exclusive access conflicts with other MTP clients; prefer uncached mode.

### Option B — Pure Swift + IOUSBHost (longer term, no third-party C)

1. Claim the MTP interface (class 6 / Still Image subclass)
2. Speak PTP/MTP containers over bulk endpoints
3. Implement OpenSession, GetObjectHandles, GetObjectInfo, GetPartialObject, SendObject
4. Projects exploring this: EffortlessMetrics/SwiftMTP-dev, custom nusb stacks

### Option C — Hybrid

Use libmtp for M2 device validation; design `MTPSession` so a pure-Swift backend can replace it without changing `MTPTransport` or File Provider code.

## M2 acceptance (from BUILD_PLAN)

- [ ] Pixel + Samsung real listing
- [ ] Unicode filenames
- [ ] >4 GB file test (streaming, not in-memory)

Run mock tests first; then swap in libmtp on a Mac with hardware.

## Known MTP limitations (general)

- One active session per device is typical; competing apps break each other
- Some phones reset the session when the screen locks
- Partial object / >4 GB support varies by manufacturer
- Move/rename is unreliable on some firmwares — prefer copy + delete when needed
- Serial number is the best stable identity; PID changes with USB mode
