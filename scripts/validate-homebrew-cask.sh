#!/usr/bin/env bash
set -euo pipefail

cask_path="${1:-packaging/homebrew/Casks/mac-drag-scroll.rb}"
cask_token="${2:-mac-drag-scroll}"

if [[ ! -f "$cask_path" ]]; then
  echo "Cask not found: $cask_path" >&2
  exit 66
fi

ruby -c "$cask_path" >/dev/null

cask_version="$(ruby -ne 'puts $1 if /^\s*version "([^"]+)"/' "$cask_path")"
cask_checksum="$(ruby -ne 'puts $1 if /^\s*sha256 "([0-9a-f]+)"/' "$cask_path")"
if [[ -z "$cask_version" || ! "$cask_checksum" =~ ^[0-9a-f]{64}$ ]]; then
  echo "Cask must use a version and an exact 64-character SHA-256 checksum." >&2
  exit 65
fi

published_checksum="$(
  curl --fail --location --retry 3 --silent --show-error \
    "https://github.com/martincalander/MacDragScroll/releases/download/v${cask_version}/SHA256SUMS.txt" |
    awk '$2 == "MacDragScroll.zip" { print $1; exit }'
)"
if [[ "$cask_checksum" != "$published_checksum" ]]; then
  echo "Cask checksum does not match the published MacDragScroll.zip checksum for v${cask_version}." >&2
  echo "Cask:      $cask_checksum" >&2
  echo "Published: ${published_checksum:-missing}" >&2
  exit 65
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found; checked Ruby syntax only."
  exit 0
fi

tap_user="macdragscroll-audit-$$"
tap_repo="tap"
tap_name="${tap_user}/${tap_repo}"
tap_root="$(brew --repo)/Library/Taps/${tap_user}/homebrew-${tap_repo}"

cleanup() {
  brew untap --force "$tap_name" >/dev/null 2>&1 || true
  rm -rf "$tap_root"
}
trap cleanup EXIT

brew untap --force "$tap_name" >/dev/null 2>&1 || true
rm -rf "$tap_root"
brew tap-new --no-git "$tap_name" >/dev/null
mkdir -p "$tap_root/Casks"
cp "$cask_path" "$tap_root/Casks/${cask_token}.rb"

brew audit --cask --strict "${tap_name}/${cask_token}"
brew style --cask "${tap_name}/${cask_token}"
