#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/Mac\ Drag\ Scroll.app" >&2
  exit 64
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$1"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
FINGERPRINT_PATH="$ROOT_DIR/scripts/release-signing-cert.sha1"
EXPECTED_BUNDLE_ID="com.martincalander.macdragscroll"

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "App Info.plist not found: $INFO_PLIST" >&2
  exit 66
fi

if [[ ! -f "$FINGERPRINT_PATH" ]]; then
  echo "Release certificate fingerprint not found: $FINGERPRINT_PATH" >&2
  exit 66
fi

expected_fingerprint="$(tr -d '[:space:]' < "$FINGERPRINT_PATH" | tr '[:upper:]' '[:lower:]')"
if [[ ! "$expected_fingerprint" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Release certificate fingerprint must be a 40-character SHA-1 value." >&2
  exit 65
fi

actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
if [[ "$actual_bundle_id" != "$EXPECTED_BUNDLE_ID" ]]; then
  echo "Release bundle identifier is $actual_bundle_id, expected $EXPECTED_BUNDLE_ID" >&2
  exit 65
fi

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"

signature_details="$(/usr/bin/codesign -d --verbose=4 "$APP_PATH" 2>&1)"
if grep -q '^Signature=adhoc$' <<< "$signature_details"; then
  echo "Release app is still ad-hoc signed." >&2
  exit 65
fi

if ! grep -Eq '^CodeDirectory .*flags=.*\(runtime\)' <<< "$signature_details"; then
  echo "Release app is missing the hardened runtime signature flag." >&2
  exit 65
fi

expected_requirement="designated => identifier \"$EXPECTED_BUNDLE_ID\" and certificate root = H\"$expected_fingerprint\""
actual_requirement="$(/usr/bin/codesign -d -r- "$APP_PATH" 2>&1 | awk '/^designated =>/ { print; exit }')"
if [[ "$actual_requirement" != "$expected_requirement" ]]; then
  echo "Release designated requirement changed." >&2
  echo "Expected: $expected_requirement" >&2
  echo "Actual:   $actual_requirement" >&2
  exit 65
fi

sparkle_root="$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B"
nested_code=(
  "$sparkle_root/XPCServices/Downloader.xpc"
  "$sparkle_root/XPCServices/Installer.xpc"
  "$sparkle_root/Updater.app"
  "$sparkle_root/Autoupdate"
  "$APP_PATH/Contents/Frameworks/Sparkle.framework"
)

for code_path in "${nested_code[@]}"; do
  if [[ ! -e "$code_path" ]]; then
    echo "Expected nested code is missing: $code_path" >&2
    exit 66
  fi

  /usr/bin/codesign --verify --strict --verbose=1 "$code_path"
  nested_details="$(/usr/bin/codesign -d --verbose=4 "$code_path" 2>&1)"
  if grep -q '^Signature=adhoc$' <<< "$nested_details"; then
    echo "Nested code is still ad-hoc signed: $code_path" >&2
    exit 65
  fi

  nested_requirement="$(/usr/bin/codesign -d -r- "$code_path" 2>&1 | awk '/^designated =>/ { print; exit }')"
  if [[ "$nested_requirement" != *"certificate root = H\"$expected_fingerprint\""* ]]; then
    echo "Nested code does not use the pinned release identity: $code_path" >&2
    echo "Actual: $nested_requirement" >&2
    exit 65
  fi
done

echo "Release signature passed: stable identity $expected_fingerprint."
