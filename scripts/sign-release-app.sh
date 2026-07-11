#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 /path/to/Mac\ Drag\ Scroll.app <signing-identity> [keychain]" >&2
  exit 64
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$1"
SIGNING_IDENTITY="$2"
SIGNING_KEYCHAIN="${3:-}"
ENTITLEMENTS_PATH="$ROOT_DIR/macdragscroll/macdragscroll.entitlements"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 66
fi

if [[ ! -f "$ENTITLEMENTS_PATH" ]]; then
  echo "App entitlements not found: $ENTITLEMENTS_PATH" >&2
  exit 66
fi

keychain_arguments=()
if [[ -n "$SIGNING_KEYCHAIN" ]]; then
  if [[ ! -f "$SIGNING_KEYCHAIN" ]]; then
    echo "Signing keychain not found: $SIGNING_KEYCHAIN" >&2
    exit 66
  fi
  keychain_arguments=(--keychain "$SIGNING_KEYCHAIN")
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

  /usr/bin/codesign \
    --force \
    --sign "$SIGNING_IDENTITY" \
    "${keychain_arguments[@]}" \
    --timestamp=none \
    --generate-entitlement-der \
    --preserve-metadata=identifier,entitlements,flags,runtime \
    "$code_path"
done

/usr/bin/codesign \
  --force \
  --sign "$SIGNING_IDENTITY" \
  "${keychain_arguments[@]}" \
  --timestamp=none \
  --options runtime \
  --generate-entitlement-der \
  --entitlements "$ENTITLEMENTS_PATH" \
  "$APP_PATH"

"$ROOT_DIR/scripts/verify-release-signature.sh" "$APP_PATH"
