#!/usr/bin/env bash
set -euo pipefail

cask_path="${1:-packaging/homebrew/Casks/mac-drag-scroll.rb}"
cask_token="${2:-mac-drag-scroll}"

if [[ ! -f "$cask_path" ]]; then
  echo "Cask not found: $cask_path" >&2
  exit 66
fi

ruby -c "$cask_path" >/dev/null

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found; checked Ruby syntax only."
  exit 0
fi

tap_user="macdragscroll-audit"
tap_repo="tap"
tap_name="${tap_user}/${tap_repo}"
tap_root="$(brew --repo)/Library/Taps/${tap_user}/homebrew-${tap_repo}"

cleanup() {
  rm -rf "$tap_root"
}
trap cleanup EXIT

rm -rf "$tap_root"
brew tap-new --no-git "$tap_name" >/dev/null
mkdir -p "$tap_root/Casks"
cp "$cask_path" "$tap_root/Casks/${cask_token}.rb"

brew audit --cask --strict "${tap_name}/${cask_token}"
brew style --cask "${tap_name}/${cask_token}"
