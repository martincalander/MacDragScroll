#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/Mac Drag Scroll.app" >&2
  exit 64
fi

APP_PATH="$1"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXPECTED_MINIMUM="14.0"

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "App Info.plist not found: $INFO_PLIST" >&2
  exit 66
fi

executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST")"
binary="$APP_PATH/Contents/MacOS/$executable_name"

if [[ ! -f "$binary" ]]; then
  echo "App executable not found: $binary" >&2
  exit 66
fi

minimum_system="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$INFO_PLIST")"
if [[ "$minimum_system" != "$EXPECTED_MINIMUM" ]]; then
  echo "Expected LSMinimumSystemVersion $EXPECTED_MINIMUM, got $minimum_system" >&2
  exit 65
fi

if ! lipo "$binary" -verify_arch arm64 x86_64; then
  echo "Release executable must contain arm64 and x86_64 slices." >&2
  exit 65
fi

declared_minimums="$(vtool -show-build "$binary" | awk '$1 == "minos" { print $2 }' | sort -u)"
if [[ "$declared_minimums" != "$EXPECTED_MINIMUM" ]]; then
  echo "Expected every Mach-O slice to target macOS $EXPECTED_MINIMUM; got:" >&2
  echo "$declared_minimums" >&2
  exit 65
fi

if otool -L "$binary" | grep -E '/(Applications/Xcode|Users|opt/homebrew|usr/local)/'; then
  echo "Release executable links a machine-local library path." >&2
  exit 65
fi

echo "Compatibility passed: macOS $EXPECTED_MINIMUM+, arm64 and x86_64."
