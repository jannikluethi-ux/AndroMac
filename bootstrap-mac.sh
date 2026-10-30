#!/bin/bash
# AndroMac Mac bootstrap — run on macOS only.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "BLOCKED BY ENVIRONMENT — macOS required."
  echo "This builder host is $(uname -s). Unzip AndroMac onto a Mac and rerun."
  exit 2
fi

command -v xcodebuild >/dev/null 2>&1 || { echo "ERROR: Install Xcode."; exit 3; }
command -v xcodegen >/dev/null 2>&1 || { echo "ERROR: Install XcodeGen: brew install xcodegen"; exit 4; }
test -f "$ROOT/project.yml" || { echo "ERROR: project.yml missing in $ROOT"; exit 5; }

echo "== AndroMac bootstrap =="
xcodebuild -version
cd "$ROOT"
xcodegen generate
echo
echo "Generated AndroMac.xcodeproj"
echo "Next: open AndroMac.xcodeproj and build the AndroMac target."
echo "Do not treat mock MTP as a physical pass."
