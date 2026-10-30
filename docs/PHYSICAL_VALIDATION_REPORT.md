# ANDROMAC PHYSICAL VALIDATION REPORT

Generated: 2026-09-17  
Environment: Linux builder sandbox (no macOS, no USB, no Xcode)

---

## PROJECT

| Item | Status |
|------|--------|
| Xcode project generated | **BLOCKED BY ENVIRONMENT** — `project.yml` ready; run `xcodegen generate` on Mac |
| Xcode build | **BLOCKED BY ENVIRONMENT** |
| Unit tests | **BLOCKED BY ENVIRONMENT** — sources present; not executed |
| Preflight script | **VERIFIED** (script exists; reports NOT READY on Linux) |
| validate-mac.sh | **VERIFIED** (script exists; does not fake hardware tests) |

---

## MTP

| Item | Status |
|------|--------|
| Real LibMTP | **UNVERIFIED** — still **MOCK / STUB** (`MockMTPSession` default) |
| LibMTPSession.open | **FAILED** by design until linked (throws backendUnavailable) |
| Enumeration (real phone) | **BLOCKED BY ENVIRONMENT** |
| Read (real phone) | **BLOCKED BY ENVIRONMENT** |
| Write (real phone) | **BLOCKED BY ENVIRONMENT** |

See `docs/MTP_INTEGRATION.md`.

---

## FINDER

| Item | Status |
|------|--------|
| Live enumerator in source (not mock folders) | **PARTIALLY VERIFIED** (code review) |
| Provider registered | **BLOCKED BY ENVIRONMENT** |
| Finder Location | **BLOCKED BY ENVIRONMENT** |
| Real DCIM enumeration | **BLOCKED BY ENVIRONMENT** |

See `docs/FILE_PROVIDER_AUDIT.md`.

---

## XPC

| Item | Status |
|------|--------|
| Typed serializable protocol | **PARTIALLY VERIFIED** (source audit) |
| No raw handles in API | **PARTIALLY VERIFIED** (source audit) |
| Runtime extension → service | **BLOCKED BY ENVIRONMENT** |

See `docs/XPC_AUDIT.md`.

---

## TRANSFERS

| Item | Status |
|------|--------|
| Streaming coordinator (source) | **PARTIALLY VERIFIED** |
| Android → Mac on hardware | **BLOCKED BY ENVIRONMENT** |
| Mac → Android on hardware | **BLOCKED BY ENVIRONMENT** |
| SHA-256 helper (source) | **PARTIALLY VERIFIED** |
| SHA-256 on real transfer | **UNVERIFIED** |

---

## RECOVERY

| Item | Status |
|------|--------|
| Disconnect | **UNVERIFIED** |
| Reconnect | **UNVERIFIED** |

---

## MULTI-DEVICE

| Item | Status |
|------|--------|
| Device A (Edge 70) | **NOT RUN** |
| Device B (other OEM) | **NOT RUN** |

---

## PERFORMANCE

| Metric | Value |
|--------|-------|
| Detection | NOT MEASURED |
| Provider registration | NOT MEASURED |
| First enumeration | NOT MEASURED |
| Transfer throughput | NOT MEASURED |

---

## BLOCKERS

1. Builder runs on **Linux** — cannot execute Xcode, IOKit, File Provider, or USB.
2. **LibMTP not integrated** — production path still uses mock session.
3. No physical **Motorola Edge 70** attached to this environment.
4. No signed macOS build artifact produced.

---

## TECHNICAL DEBT

- Domain ID ↔ DeviceID sanitization round-trip
- XPC JSON-over-Data encoding (simple but heavy)
- ADB push still uses temp file (contained in transport)
- NSFileProviderError mapping incomplete
- LibMTP bridge (MTPBridge.h/mm) not implemented

---

## NEXT PHASE

Only after a human/Mac lab runs `./scripts/validate-mac.sh` and fills `HARDWARE_TEST_REPORT.md`:

1. Wire real LibMTP behind `LibMTPSession`
2. Complete Task 13 Finder vertical slice on Edge 70
3. Measure timings; run integrity on 100 MB / 1 GB
4. Second manufacturer
5. Then production hardening (M10)

**Do not start Phase 2 features until physical vertical slice is VERIFIED.**

---

## Definition of done for this phase

```text
Actual Android phone in Finder + real files transferred
```

**Status: NOT MET** — architecture ready; physical proof outstanding.
