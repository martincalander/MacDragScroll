#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

read_setting() {
  local settings="$1"
  local key="$2"
  awk -F'= ' -v key="$key" '$1 ~ "^[[:space:]]*" key "[[:space:]]*$" { print $2; exit }' <<< "$settings"
}

release_settings="$(xcodebuild -showBuildSettings -project macdragscroll.xcodeproj -scheme macdragscroll -configuration Release 2>/dev/null)"
debug_settings="$(xcodebuild -showBuildSettings -project macdragscroll.xcodeproj -scheme macdragscroll -configuration Debug 2>/dev/null)"

release_bundle_id="$(read_setting "$release_settings" PRODUCT_BUNDLE_IDENTIFIER)"
debug_bundle_id="$(read_setting "$debug_settings" PRODUCT_BUNDLE_IDENTIFIER)"
release_display_name="$(read_setting "$release_settings" APP_DISPLAY_NAME)"
debug_display_name="$(read_setting "$debug_settings" APP_DISPLAY_NAME)"

if [[ "$release_bundle_id" != "com.martincalander.macdragscroll" ]]; then
  echo "Unexpected Release bundle identifier: $release_bundle_id" >&2
  exit 65
fi

if [[ "$debug_bundle_id" != "com.martincalander.macdragscroll.development" ]]; then
  echo "Unexpected Debug bundle identifier: $debug_bundle_id" >&2
  exit 65
fi

if [[ "$release_bundle_id" == "$debug_bundle_id" ]]; then
  echo "Debug and Release must not share a TCC identity." >&2
  exit 65
fi

if [[ "$release_display_name" != "Mac Drag Scroll" ]]; then
  echo "Unexpected Release display name: $release_display_name" >&2
  exit 65
fi

if [[ "$debug_display_name" != "Mac Drag Scroll Dev" ]]; then
  echo "Unexpected Debug display name: $debug_display_name" >&2
  exit 65
fi

fingerprint="$(tr -d '[:space:]' < scripts/release-signing-cert.sha1)"
if [[ ! "$fingerprint" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Release signing fingerprint is invalid." >&2
  exit 65
fi

echo "Build identities passed: production and development are isolated."
