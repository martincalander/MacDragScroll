#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  scripts/set-apple-release-secrets.sh <developer-id.p12> <p12-password> <apple-id> <app-specific-password> [team-id]

Example:
  scripts/set-apple-release-secrets.sh ~/Desktop/DeveloperIDApplication.p12 "$P12_PASSWORD" martin@example.com "$APP_PASSWORD"

This stores release secrets in GitHub Actions for martincalander/MacDragScroll.
USAGE
}

if [[ $# -lt 4 || $# -gt 5 ]]; then
  usage
  exit 64
fi

p12_path="$1"
p12_password="$2"
apple_id="$3"
app_specific_password="$4"
team_id="${5:-K59U5BDYA9}"
repo="${GITHUB_REPOSITORY:-martincalander/MacDragScroll}"

if [[ ! -f "$p12_path" ]]; then
  echo "Certificate file not found: $p12_path" >&2
  exit 66
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "Missing GitHub CLI: gh" >&2
  exit 69
fi

gh auth status >/dev/null

base64 -i "$p12_path" | gh secret set MACOS_CERTIFICATE_P12 --repo "$repo"
printf "%s" "$p12_password" | gh secret set MACOS_CERTIFICATE_PASSWORD --repo "$repo"
printf "%s" "$apple_id" | gh secret set APPLE_ID --repo "$repo"
printf "%s" "$app_specific_password" | gh secret set APPLE_APP_SPECIFIC_PASSWORD --repo "$repo"
printf "%s" "$team_id" | gh secret set APPLE_TEAM_ID --repo "$repo"

echo "Apple release secrets set for $repo"
