#!/usr/bin/env bash
set -euo pipefail

version="${1:-}"
repo="${GITHUB_REPOSITORY:-martincalander/MacDragScroll}"

if [[ -z "$version" ]]; then
  echo "Usage: $0 <version>" >&2
  exit 64
fi

version="${version#v}"
required_secrets=(
  APPLE_ID
  APPLE_APP_SPECIFIC_PASSWORD
  APPLE_TEAM_ID
  MACOS_CERTIFICATE_P12
  MACOS_CERTIFICATE_PASSWORD
  SPARKLE_PRIVATE_KEY
)

echo "Checking release readiness for v${version}"

if ! command -v gh >/dev/null 2>&1; then
  echo "Missing GitHub CLI: gh" >&2
  exit 69
fi

gh auth status >/dev/null

settings="$(xcodebuild -showBuildSettings -project macdragscroll.xcodeproj -scheme macdragscroll -configuration Release 2>/dev/null)"
marketing_version="$(awk -F'= ' '/MARKETING_VERSION =/ { print $2; exit }' <<< "$settings")"
build_number="$(awk -F'= ' '/CURRENT_PROJECT_VERSION =/ { print $2; exit }' <<< "$settings")"

if [[ "$marketing_version" != "$version" ]]; then
  echo "MARKETING_VERSION is $marketing_version, expected $version" >&2
  exit 65
fi

if [[ -z "$build_number" ]]; then
  echo "Could not read CURRENT_PROJECT_VERSION" >&2
  exit 65
fi

echo "App version: ${marketing_version} (${build_number})"

if ! scripts/extract-release-notes.sh "$version" >/tmp/mac-drag-scroll-release-notes-check.md; then
  echo "Missing CHANGELOG.md notes for $version" >&2
  exit 66
fi

if [[ ! -s /tmp/mac-drag-scroll-release-notes-check.md ]]; then
  echo "CHANGELOG.md notes for $version are empty" >&2
  exit 66
fi

echo "Release notes: ok"

unreleased_entries="$(
  awk '
    /^## \[Unreleased\]/ {
      in_unreleased = 1
      next
    }
    /^## / {
      if (in_unreleased) {
        exit
      }
    }
    in_unreleased && /^- / {
      print
    }
  ' CHANGELOG.md
)"

if [[ -n "$unreleased_entries" ]]; then
  echo "CHANGELOG.md still has unreleased bullet items. Move them into v${version} before releasing:" >&2
  echo "$unreleased_entries" >&2
  exit 66
fi

if [[ ! -x scripts/extract-release-notes.sh || ! -x scripts/install.sh ]]; then
  echo "Release scripts must be executable" >&2
  exit 65
fi

if [[ -f packaging/homebrew/Casks/mac-drag-scroll.rb ]]; then
  ruby -c packaging/homebrew/Casks/mac-drag-scroll.rb >/dev/null
fi

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  echo "Warning: no local Developer ID Application signing identity found."
fi

existing_secrets="$(gh secret list --repo "$repo" | awk '{ print $1 }')"
missing=()
for secret in "${required_secrets[@]}"; do
  if ! grep -qx "$secret" <<< "$existing_secrets"; then
    missing+=("$secret")
  fi
done

if (( ${#missing[@]} > 0 )); then
  echo "Missing GitHub secrets for $repo:" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 67
fi

echo "GitHub release secrets: ok"
echo "Ready to tag v${version}"
