# MTP Integration Audit

**Status: MOCK / STUB — not real LibMTP**

## Classification

| Component | Status |
|-----------|--------|
| `MockMTPSession` | In-memory fake Android tree (DCIM, Download, 1 MB file) |
| `LibMTPSession` | Placeholder; `open()` always throws `backendUnavailable` |
| `MTPTransport` | Real path logic; defaults to `MockMTPSession` |
| libmtp linked | **NO** |
| C/ObjC++ bridge | **NOT PRESENT** |

Evidence: `TransportFactory.makeTransport` uses `MockMTPSession()` when `useMockMTPIfLibUnavailable: true` (default).

## Required for REAL LIBMTP

1. `brew install libmtp` (LGPL-2.1 — review packaging/notarization)
2. Add:
   ```text
   Transport/MTP/
     MTPBridge.h
     MTPBridge.mm   // wraps LIBMTP_* 
   ```
3. Link `libmtp` + `libusb` in AndroMacXPC (and host if needed)
4. Implement `LibMTPSession` with uncached open, list, get/send object
5. Set `useMockMTPIfLibUnavailable: false` only after `open()` works on Edge 70
6. Apply Motorola/Android device flags as needed

## License / packaging notes

- libmtp is LGPL-2.1-or-later — dynamic linking preferred; document obligations
- Verify Apple Silicon + Intel bottles via Homebrew
- Notarization: ship dylibs inside app bundle with correct rpath

## Verification rule

Do **not** mark MTP as VERIFIED until:

- LibMTP session opens on physical Edge 70
- `list("/")` returns real storage folders from the phone
- Read of a real DCIM file succeeds

Until then: **UNVERIFIED / MOCK**.
