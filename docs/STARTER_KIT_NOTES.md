# Starter kit applied

The Mac Starter Kit was a **minimal** skeleton. It was **not** used to wipe the existing AndroMac tree.

## Kept from starter kit
- `bootstrap-mac.sh` (adapted to this repo layout)
- `docs/MAC_FIRST_RUN.md`
- ObjC MTP boundary: `MTPBridgeObjC.h` / `MTPBridgeObjC.mm`

## Not applied (would regress)
- Tiny `AndroidTransport` (no list/read/write)
- Stub File Provider that only throws `noSuchItem`
- Alternate `project.yml` that drops Device/Transfer/Diagnostics sources
- Sync `DeviceStore` replacing `AppModel` + `DeviceManager`

Existing architecture stays: IOKit discovery, XPC list/read/write, live File Provider enumerator, production vs mock MTP split.
