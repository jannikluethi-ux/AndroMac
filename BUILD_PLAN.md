# Build Plan

## M0 — Project bootstrap
- Create macOS app target.
- Create File Provider extension target.
- Configure signing identifiers and app groups/XPC architecture.
- Establish CI build.
- Add structured logging.

## M1 — USB/device discovery
Deliverable: connected Android devices are detected and identified.

Acceptance:
- connect/disconnect events work
- multiple devices are represented independently
- stable identity is persisted

## M2 — MTP proof of concept
Deliverable: list Android storage and stream a file.

Acceptance:
- Pixel + Samsung
- Unicode filenames
- >4 GB file test

## M3 — ADB proof of concept
Deliverable: authorized ADB device can list/read/write through the transport abstraction.

Acceptance:
- no Android Studio required
- ADB errors are mapped into useful application errors

## M4 — File Provider proof of concept
Deliverable: static/mock provider appears in Finder and supports enumeration.

## M5 — Finder vertical slice
Connect real Android storage to File Provider.

Acceptance:
- phone appears under Finder → Locations
- browse root/DCIM
- no custom file browser needed

## M6 — Read transfer
Drag a large file Android → Mac.

Acceptance:
- streaming
- progress
- cancellation
- integrity check

## M7 — Write transfer
Drag Mac → Android.

Acceptance:
- temporary destination
- atomic finalization where possible
- failure recovery

## M8 — Recovery
Test sleep/wake, disconnect/reconnect, Finder restart, transport failure.

## M9 — Multi-device
Two or more phones simultaneously.

## M10 — Production hardening
Signing, notarization, crash handling, diagnostics, installer, QA matrix.

## Go/no-go gate
Do not start Phase 2 until M1–M10 pass on at least three manufacturers.
