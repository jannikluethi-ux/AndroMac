# File Provider Audit

## Production enumeration path

Source of truth: `AndroMacFileProvider/AndroMacFileProvider.swift`

```text
Finder enumerate
  → LiveEnumerator
  → ItemPathMapper (deviceID + path components)
  → AndroidBridgeXPCClient.list
  → BridgeXPCService → transport.list
  → ProviderItem[] → Finder
```

**Mock directory list is not used in the production enumerator.**  
`LiveEnumerator` replaced earlier M4 mock folders.

Caveat: until XPC + real transport work on a Mac, Finder would show errors or empty results — not a fake success UI.

## Identifiers

| Concept | Implementation |
|---------|----------------|
| Domain ID | `andromac.<sanitized-device-id>` via `DomainRegistrar` |
| Root item | `.rootContainer` |
| Child items | Percent-encoded path segments (`ItemPathMapper`) |
| Device ID | Parsed from domain identifier (best-effort reverse of sanitization) |

## ItemPath

`ItemPath { deviceID, components[] }` → `RemotePath` (`/a/b/c`).

## Gaps (source review)

1. Domain ID sanitization (`:` → `-`) may not round-trip all DeviceID forms
2. Working set / sync anchors minimal (no incremental change tracking)
3. `fetchContents` uses temp files via XPC (correct for streaming server-side; extension receives path)
4. No NSFileProviderError mapping for offline device

## Status

| Check | Result |
|-------|--------|
| Live enumerator (not mock) in source | PASS |
| XPC-only I/O from extension | PASS (source) |
| Appears under Finder → Locations | **BLOCKED BY ENVIRONMENT** |
| Real DCIM contents | **BLOCKED BY ENVIRONMENT** |
