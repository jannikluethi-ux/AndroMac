# MTP Dependency Audit

## Chosen stack

| Item | Value |
|------|--------|
| Library | **libmtp** |
| Typical install (Mac) | `brew install libmtp` |
| License | **LGPL-2.1-or-later** |
| Transitive | **libusb** (LGPL-2.1) |
| Apple Silicon | Supported via Homebrew bottles |
| Intel Mac | Supported via Homebrew bottles |
| Build system | Autotools / CMake upstream; Homebrew formula |
| Linkage (recommended) | **Dynamic** (`libmtp.dylib`) for LGPL compliance |
| Runtime | Ship dylib inside app bundle or require Homebrew (dev only) |

## Version

Not pinned in-repo yet — on Mac run:

```bash
brew info libmtp
pkg-config --modversion libmtp
```

Record exact version in HARDWARE_TEST_REPORT after first successful link.

## Distribution / notarization

- Dynamic link + include dylibs in `Frameworks/` or `lib/` with `@rpath`
- LGPL: allow user replacement of library; document in About / LICENSE
- Notarize app after codesign of main binary, XPC, extension, and embedded dylibs
- Do **not** statically link LGPL into a closed-source binary without legal review

## Integration status

| Step | Status |
|------|--------|
| Dependency chosen | libmtp |
| License documented | Yes |
| MTPBridge.h API | Present (stub) |
| MTPBridge.mm real calls | **Not implemented** |
| Linked in Xcode target | **BLOCKED BY ENVIRONMENT** / not yet |
| Physical open on Edge 70 | **UNVERIFIED** |

## Blocker

Real MTP cannot be exercised until a Mac links libmtp and implements `MTPBridge.mm`. Until then production `LibMTPSession.open()` returns `backendUnavailable` (by design).
