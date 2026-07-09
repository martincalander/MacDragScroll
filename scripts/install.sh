#!/usr/bin/env bash
set -euo pipefail

repo="${MAC_DRAG_SCROLL_REPO:-martincalander/MacDragScroll}"
asset="${MAC_DRAG_SCROLL_ASSET:-MacDragScroll.zip}"
install_dir="${INSTALL_DIR:-/Applications}"
app_name="Mac Drag Scroll.app"
download_url="https://github.com/${repo}/releases/latest/download/${asset}"
checksum_url="https://github.com/${repo}/releases/latest/download/SHA256SUMS.txt"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

archive_path="$tmp_dir/$asset"
checksum_path="$tmp_dir/SHA256SUMS.txt"
extract_dir="$tmp_dir/extract"

echo "Downloading Mac Drag Scroll from $download_url"
curl --fail --location --retry 3 --retry-delay 2 --progress-bar "$download_url" --output "$archive_path"

if curl --fail --location --retry 3 --retry-delay 2 --silent --show-error "$checksum_url" --output "$checksum_path"; then
  expected_checksum="$(awk -v asset="$asset" '$2 == asset { print $1; exit }' "$checksum_path")"
  if [[ -n "$expected_checksum" ]]; then
    actual_checksum="$(shasum -a 256 "$archive_path" | awk '{ print $1 }')"
    if [[ "$actual_checksum" != "$expected_checksum" ]]; then
      echo "Checksum mismatch for $asset" >&2
      echo "Expected: $expected_checksum" >&2
      echo "Actual:   $actual_checksum" >&2
      exit 66
    fi
    echo "Verified SHA-256 checksum for $asset"
  else
    echo "Checksum file did not contain $asset; continuing with downloaded archive."
  fi
else
  echo "No checksum file found for latest release; continuing with downloaded archive."
fi

mkdir -p "$extract_dir"
ditto -x -k "$archive_path" "$extract_dir"

source_app="$extract_dir/$app_name"
if [[ ! -d "$source_app" ]]; then
  echo "Downloaded archive did not contain $app_name" >&2
  exit 65
fi

destination_app="$install_dir/$app_name"

if pgrep -x "Mac Drag Scroll" >/dev/null 2>&1; then
  osascript -e 'tell application "Mac Drag Scroll" to quit' >/dev/null 2>&1 || true
  sleep 2
fi

copy_app() {
  rm -rf "$destination_app"
  ditto "$source_app" "$destination_app"
}

if [[ -w "$install_dir" ]]; then
  copy_app
else
  sudo rm -rf "$destination_app"
  sudo ditto "$source_app" "$destination_app"
fi

echo "Installed Mac Drag Scroll to $destination_app"
echo "Open it from Applications and grant Accessibility permission if macOS asks."
