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
  if [[ -n "${staged_app:-}" && -w "$install_dir" ]]; then
    rm -rf "$staged_app"
  fi
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
staged_app="$install_dir/.${app_name}.installing.$$"
backup_app="$install_dir/.${app_name}.previous.$$"

if pgrep -x "Mac Drag Scroll" >/dev/null 2>&1; then
  osascript -e 'tell application "Mac Drag Scroll" to quit' >/dev/null 2>&1 || true
  sleep 2
fi

copy_app() {
  rm -rf "$staged_app" "$backup_app"
  if ! ditto "$source_app" "$staged_app"; then
    rm -rf "$staged_app"
    echo "Install failed while staging $app_name." >&2
    return 1
  fi

  if [[ -e "$destination_app" || -L "$destination_app" ]]; then
    if ! mv "$destination_app" "$backup_app"; then
      rm -rf "$staged_app"
      echo "Install failed while preparing to replace $destination_app." >&2
      return 1
    fi
  fi

  if mv "$staged_app" "$destination_app"; then
    rm -rf "$backup_app"
    return 0
  fi

  if [[ -e "$backup_app" || -L "$backup_app" ]]; then
    mv "$backup_app" "$destination_app" || true
  fi
  rm -rf "$staged_app"
  echo "Install failed while replacing $destination_app; restored the previous app if possible." >&2
  return 1
}

copy_app_with_sudo() {
  sudo rm -rf "$staged_app" "$backup_app"
  if ! sudo ditto "$source_app" "$staged_app"; then
    sudo rm -rf "$staged_app"
    echo "Install failed while staging $app_name." >&2
    return 1
  fi

  if [[ -e "$destination_app" || -L "$destination_app" ]]; then
    if ! sudo mv "$destination_app" "$backup_app"; then
      sudo rm -rf "$staged_app"
      echo "Install failed while preparing to replace $destination_app." >&2
      return 1
    fi
  fi

  if sudo mv "$staged_app" "$destination_app"; then
    sudo rm -rf "$backup_app"
    return 0
  fi

  if [[ -e "$backup_app" || -L "$backup_app" ]]; then
    sudo mv "$backup_app" "$destination_app" || true
  fi
  sudo rm -rf "$staged_app"
  echo "Install failed while replacing $destination_app; restored the previous app if possible." >&2
  return 1
}

if [[ -w "$install_dir" ]]; then
  copy_app
else
  copy_app_with_sudo
fi

echo "Installed Mac Drag Scroll to $destination_app"
echo "Open it from Applications and grant Accessibility and Input Monitoring permissions if macOS asks."
