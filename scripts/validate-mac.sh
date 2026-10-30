#!/usr/bin/env bash
# AndroMac validate-mac — generate project, build, unit-test on a Mac.
# Never pretends to run USB/Finder tests without hardware.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== 1. Preflight ==="
if ! bash "$ROOT/scripts/preflight.sh"; then
  echo "Preflight failed. Fix issues above before continuing."
  exit 1
fi

echo
echo "=== 2. Generate Xcode project ==="
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen missing — brew install xcodegen"
  exit 1
fi
xcodegen generate
if [[ ! -d AndroMac.xcodeproj ]]; then
  echo "FAILED: AndroMac.xcodeproj not created"
  exit 1
fi
echo "Generated AndroMac.xcodeproj"

echo
echo "=== 3. Build ==="
xcodebuild \
  -project AndroMac.xcodeproj \
  -scheme AndroMac \
  -configuration Debug \
  -destination 'platform=macOS' \
  build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  | tee /tmp/andromac-build.log \
  | tail -40

echo
echo "=== 4. Unit tests ==="
xcodebuild \
  -project AndroMac.xcodeproj \
  -scheme AndroMac \
  -configuration Debug \
  -destination 'platform=macOS' \
  test \
  -only-testing:AndroMacTests \
  CODE_SIGN_IDENTITY="-" \
  2>&1 | tee /tmp/andromac-test.log | tail -40

echo
echo "=== 5. Physical device steps (manual) ==="
cat <<'STEPS'
These are NOT automated. On the Mac with Edge 70:

  1. Unlock phone, use a data USB-C cable
  2. Select USB mode: File transfer (MTP)
  3. Optional: enable USB debugging for ADB path
  4. Run AndroMac from Xcode
  5. Confirm status shows connected device
  6. Open Finder → Locations → phone name
  7. Open DCIM — must show real photos, not mock names only
  8. Copy one file to Desktop; sha256sum both if possible
  9. Unplug and replug; Finder should recover without restart
 10. Fill docs/HARDWARE_TEST_REPORT.md with measured times

Do not mark physical tests VERIFIED until observed.
STEPS

echo
echo "validate-mac.sh finished (build/test only). Physical USB/Finder: manual."
