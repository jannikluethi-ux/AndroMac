# MTP layer

| Type | Role |
|------|------|
| `MTPTransport` | `AndroidTransport` implementation |
| `LibMTPSession` | Production session → `MTPBridge` → libmtp |
| `MockMTPSession` | **Unit tests only** |
| `MTPBridge.h` / `.mm` | C boundary; isolate libmtp |

## Production rule

```text
TransportFactory.mode = .production
  → ADBTransport (if preferred + serial)
  → else MTPTransport(LibMTPSession)   // never MockMTPSession
```

If LibMTP is not linked, `connect()` fails with `MTPError.backendUnavailable`.
No silent mock fallback.

## Tests

```swift
MTPTransport(deviceID: id, session: MockMTPSession())
// or
TransportFactory.makeTransport(for: info, mode: .unitTestMockMTP)
```

## Mac bring-up for real MTP

1. `brew install libmtp`
2. Implement `MTPBridge.mm` with `LIBMTP_*`
3. Bridging header / module map on **AndroMacXPC**
4. Link `libmtp` + `libusb`
5. Wire `LibMTPSession.open()` to `MTPBridgeOpen`
6. Test on Edge 70 File Transfer mode
