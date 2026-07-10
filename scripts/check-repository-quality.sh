#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash -n install.sh scripts/*.sh
jq -e . .bestpractices.json >/dev/null

while IFS= read -r plist; do
  plutil -lint "$plist" >/dev/null
done < <(find macdragscroll -name '*.plist' -type f -print)

ruby -e '
  require "yaml"
  Dir[".github/**/*.{yml,yaml}"].sort.each do |path|
    YAML.safe_load(File.read(path), aliases: true)
  end
'

package_resolved="macdragscroll.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
jq -e '
  .version == 3 and
  (.pins | length > 0) and
  all(.pins[];
    (.location | startswith("https://")) and
    (.state.revision | test("^[0-9a-f]{40}$")) and
    (.state.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+"))
  )
' "$package_resolved" >/dev/null

npm_lock="docs/assets/source/package-lock.json"
jq -e '
  .lockfileVersion == 3 and
  .packages["node_modules/playwright"].version == "1.61.1" and
  ([.packages | to_entries[] |
    select(.key != "") |
    select(.value.resolved? | type == "string") |
    select((.value.integrity? // "") | startswith("sha512-") | not)
  ] | length == 0)
' "$npm_lock" >/dev/null

unpinned_actions="$({
  sed -nE 's/^[[:space:]]*uses:[[:space:]]*([^[:space:]#]+).*$/\1/p' .github/workflows/*.yml
} | while IFS= read -r action; do
  if [[ "$action" == ./* ]] || [[ "$action" == docker://*@sha256:* ]]; then
    continue
  fi

  if [[ "$action" =~ @[[:xdigit:]]{40}$ ]]; then
    continue
  fi

  printf '%s\n' "$action"
done)"

if [[ -n "$unpinned_actions" ]]; then
  echo "GitHub Actions must be pinned to full commit SHAs:" >&2
  echo "$unpinned_actions" >&2
  exit 1
fi

if git grep -n -E '^[<]{7}|^[>]{7}' -- . ':!docs/assets/source/package-lock.json'; then
  echo "Merge conflict markers found." >&2
  exit 1
fi

if git grep -n -E 'permissions:[[:space:]]*write-all|pull_request_target:' -- .github/workflows; then
  echo "Unsafe broad workflow permissions or pull_request_target found." >&2
  exit 1
fi

echo "Repository quality checks passed."
