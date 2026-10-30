# Code review — Andromac (post M0–M4)

Date: 2026-09-17

## Fixes applied in this pass

1. **DeviceProfile.match** — Logic could skip valid matches; rewritten to clear priority: model → manufacturer → VID.
2. **TransferCoordinator.push** — Nested `Task` mutated local `record` and called `publish` unsafely; progress now updates via actor-isolated `updateProgress`.
3. **AndromacFileProvider** — Removed force-unwrap on `NSFileProviderManager`; manager is optional.
4. **DomainRegistrar** — Register/unregister tolerate “already exists” / missing domain instead of failing the UI.
5. **ContentView** — Stale M1/M2 status text; show `lastError`; import AppKit for Quit.
6. **USBDiscovery** — Removed duplicate Qualcomm VID entry.

## Remaining known issues (not blockers for scaffold)

| Issue | Severity | Notes |
|-------|----------|--------|
| No Xcode project / SPM package | High for build | Must create targets on Mac |
| No XPC host ↔ extension | High for M5 | File Provider still mock-only |
| LibMTPSession always throws | Expected | Wire libmtp on Mac |
| ADB push buffers whole file | Medium | Uses temp file; OK for PoC, not ideal for 50GB |
| USBDiscovery `Unmanaged.passUnretained` | Medium | Host must keep discovery alive for app lifetime |
| `deinit { stop() }` async | Low | Stop may not finish before deinit |
| Tests `@testable import Andromac` | Medium | Needs real module name from Xcode target |
| NSFileProviderItem conformance | Medium | May need extra properties on newer SDKs |
| No entitlement / Info.plist samples | Medium | Required for USB + File Provider |
| Reconnect same device re-adds domain | Low | Softened with catch |

## Architecture gaps vs SPEC

- [ ] XPC boundary (extension must not own USB/MTP)
- [ ] Persistence (SQLite for device identity / transfer journal)
- [ ] Structured logging (OSLog)
- [ ] Cancellation tokens on transfers
- [ ] Integrity check (checksum) after pull
- [ ] Hardened Runtime + Developer ID notes in build docs

## Suggested next coding order

1. Xcode project + shared framework target for Shared/Device/Transport
2. XPC service protocol for list/stat/read/write
3. Point File Provider enumerator at XPC (M5)
4. Real MTP via libmtp on Edge 70
5. End-to-end DCIM browse + 1 GB transfer
EOF