# ANDROMAC MAC BRING-UP REPORT

Date: 2026-09-17  
Environment: Linux builder (no macOS/Xcode/USB)

## SOURCE

| Item | Status |
|------|--------|
| Architecture | PARTIALLY VERIFIED (source complete) |
| MTP production path | PARTIALLY VERIFIED — LibMTPSession only; no mock fallback |
| MTP real libmtp | UNVERIFIED — MTPBridge.mm still stub |
| ADB | PARTIALLY VERIFIED (CLI client source) |
| XPC | PARTIALLY VERIFIED (source audit) |
| File Provider live path | PARTIALLY VERIFIED (source audit) |

## BUILD

| Item | Status |
|------|--------|
| Xcode project | BLOCKED BY ENVIRONMENT (project.yml ready) |
| Build | BLOCKED BY ENVIRONMENT |
| Unit tests | BLOCKED BY ENVIRONMENT |

## MTP

| Item | Status |
|------|--------|
| Real implementation | UNVERIFIED |
| Physical device | BLOCKED BY ENVIRONMENT |
| Enumeration | BLOCKED BY ENVIRONMENT |
| Read / Write | BLOCKED BY ENVIRONMENT |

## FINDER

| Item | Status |
|------|--------|
| Location | BLOCKED BY ENVIRONMENT |
| Real storage / DCIM | BLOCKED BY ENVIRONMENT |

## TRANSFERS

| Item | Status |
|------|--------|
| Android → Mac | BLOCKED BY ENVIRONMENT |
| Mac → Android | BLOCKED BY ENVIRONMENT |
| Integrity helper | PARTIALLY VERIFIED (source) |

## RECOVERY / MULTI-DEVICE

UNVERIFIED / NOT RUN

## PERFORMANCE

NOT MEASURED

## SOFTWARE CHANGES THIS PHASE

1. `TransportFactory` — modes `.production` / `.unitTestMockMTP`; no silent mock
2. `MTPTransport` — requires explicit session (no default Mock)
3. Tests updated to pass `MockMTPSession` explicitly
4. `ConnectionSession` uses production mode
5. `docs/MTP_DEPENDENCY.md`, `MAC_BRINGUP.md`, baseline audit
6. MTP README with production rules

## BLOCKERS

1. No Mac in builder environment
2. MTPBridge.mm not implemented against libmtp
3. No physical Edge 70 attached

## NEXT ACTION

On a real Mac:

```bash
cd AndroMac
./scripts/preflight.sh
./scripts/validate-mac.sh
# implement MTPBridge.mm + link libmtp
# Edge 70 File transfer → Finder Locations → verified transfer
```

**Gates A–F remain unmet until Mac/hardware proof.**

Milestone remains:

> Edge 70 appears in Finder → Locations and a real file survives a verified round-trip transfer.
