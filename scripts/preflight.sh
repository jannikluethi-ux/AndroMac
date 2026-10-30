#!/usr/bin/env bash
# AndroMac preflight — run on a Mac before build/validation.
# Does not install dependencies; prints remediation commands.
set -euo pipefail

PASS=0
FAIL=0
WARN=0

ok()   { echo "  $1"; PASS=$((PASS+1)); }
bad()  { echo "  $1"; FAIL=$((FAIL+1)); }
warn() { echo "  $1"; WARN=$((WARN+1)); }

echo "AndroMac Preflight"
echo "=================="
echo

# macOS
if [[ "$(uname -s)" == "Darwin" ]]; then
  ok "macOS              PASS ($(sw_vers -productVersion 2>/dev/null || echo unknown))"
else
  bad "macOS              FAIL (running on $(uname -s) — need macOS)"
fi

# Architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" || "$ARCH" == "x86_64" ]]; then
  ok "Architecture       PASS ($ARCH)"
else
  warn "Architecture       WARN ($ARCH)"
fi

# Xcode
if command -v xcodebuild >/dev/null 2>&1; then
  XV=$(xcodebuild -version 2>/dev/null | head -1)
  ok "Xcode              PASS ($XV)"
else
  bad "Xcode              FAIL — install Xcode from App Store, then: xcode-select --install"
fi

# xcode-select
if command -v xcode-select >/dev/null 2>&1; then
  XP=$(xcode-select -p 2>/dev/null || echo "not set")
  if [[ "$XP" == *"Xcode.app"* ]] || [[ "$XP" == *"CommandLineTools"* ]]; then
    ok "xcode-select       PASS ($XP)"
  else
    warn "xcode-select       WARN ($XP) — run: sudo xcode-select -s /Applications/Xcode.app"
  fi
else
  bad "xcode-select       FAIL"
fi

# Swift
if command -v swift >/dev/null 2>&1; then
  ok "Swift              PASS ($(swift --version 2>/dev/null | head -1))"
else
  bad "Swift              FAIL — install Xcode / toolchain"
fi

# XcodeGen
if command -v xcodegen >/dev/null 2>&1; then
  ok "XcodeGen           PASS ($(xcodegen --version 2>/dev/null | head -1))"
else
  warn "XcodeGen           WARN — install: brew install xcodegen"
fi

# Homebrew
if command -v brew >/dev/null 2>&1; then
  ok "Homebrew           PASS"
else
  warn "Homebrew           WARN — https://brew.sh (needed for xcodegen/libmtp)"
fi

# LibMTP
if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists libmtp 2>/dev/null; then
  ok "LibMTP             PASS ($(pkg-config --modversion libmtp))"
elif [[ -f /opt/homebrew/lib/libmtp.dylib ]] || [[ -f /usr/local/lib/libmtp.dylib ]]; then
  ok "LibMTP             PASS (dylib found)"
else
  warn "LibMTP             WARN — not found. Real MTP needs: brew install libmtp"
fi

# adb (optional for ADB transport)
if command -v adb >/dev/null 2>&1; then
  ok "ADB                PASS ($(command -v adb))"
else
  warn "ADB                WARN — optional; brew install android-platform-tools"
fi

# Signing
if command -v security >/dev/null 2>&1; then
  IDENTS=$(security find-identity -v -p codesigning 2>/dev/null | grep -c "Apple Development\|Developer ID" || true)
  if [[ "${IDENTS:-0}" -gt 0 ]]; then
    ok "Signing            PASS ($IDENTS identity/identities)"
  else
    warn "Signing            WARN — no Apple Development / Developer ID identity"
  fi
else
  warn "Signing            WARN — cannot query keychain"
fi

# project.yml
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/project.yml" ]]; then
  ok "project.yml        PASS ($ROOT/project.yml)"
else
  bad "project.yml        FAIL — missing at repo root"
fi

# Source directories
for d in AndroMac AndroMacFileProvider AndroMacXPC AndroMacTests Config; do
  if [[ -d "$ROOT/$d" ]]; then
    ok "sources            PASS ($d/)"
  else
    bad "sources            FAIL (missing $d/)"
  fi
done

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "Result: READY ($PASS pass, $WARN warn, $FAIL fail)"
  exit 0
else
  echo "Result: NOT READY ($PASS pass, $WARN warn, $FAIL fail)"
  echo
  echo "Remediation (Mac):"
  echo "  1. Install Xcode + open once to accept license"
  echo "  2. brew install xcodegen libmtp"
  echo "  3. Optional: brew install android-platform-tools"
  echo "  4. cd AndroMac && ./scripts/validate-mac.sh"
  exit 1
fi
