#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash -n install.sh scripts/*.sh
scripts/check-build-identities.sh
jq -e . .bestpractices.json >/dev/null

while IFS= read -r plist; do
  plutil -lint "$plist" >/dev/null
done < <(find macdragscroll -name '*.plist' -type f -print)

localization_files=(macdragscroll/*.lproj/Localizable.strings)
ruby - macdragscroll/en.lproj/Localizable.strings "${localization_files[@]}" <<'RUBY'
entry_pattern = /^\s*"((?:\\.|[^"])*)"\s*=\s*"((?:\\.|[^"])*)"\s*;\s*$/
format_pattern = /%(?:\d+\$)?[-+ #0]*(?:\d+|\*)?(?:\.\d+|\.\*)?(?:hh|h|ll|l|q|z|t|j)?[@diuoxXfFeEgGaAcCsSp]/

parse_strings = lambda do |path|
  entries = {}
  counts = Hash.new(0)

  File.foreach(path) do |line|
    match = line.match(entry_pattern)
    next unless match

    key = match[1]
    counts[key] += 1
    entries[key] = match[2]
  end

  duplicates = counts.select { |_, count| count > 1 }.keys.sort
  abort "#{path} has duplicate localization keys: #{duplicates.join(", ")}" unless duplicates.empty?
  entries
end

english_path = ARGV.shift
english = parse_strings.call(english_path)
abort "#{english_path} has no localization entries" if english.empty?

ARGV.each do |path|
  translated = parse_strings.call(path)
  missing = (english.keys - translated.keys).sort
  extra = (translated.keys - english.keys).sort

  unless missing.empty? && extra.empty?
    abort "#{path} localization keys differ from English (missing: #{missing.join(", ")}; extra: #{extra.join(", ")})"
  end

  english.each do |key, value|
    expected_formats = value.scan(format_pattern).map { |format| format[-1] }.sort
    actual_formats = translated.fetch(key).scan(format_pattern).map { |format| format[-1] }.sort
    next if actual_formats == expected_formats

    abort "#{path} key #{key} has format specifiers #{actual_formats.inspect}; expected #{expected_formats.inspect}"
  end
end
RUBY

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

project_sparkle_version="$(
  sed -nE 's/^[[:space:]]*version = ([0-9]+\.[0-9]+\.[0-9]+);$/\1/p' \
    macdragscroll.xcodeproj/project.pbxproj
)"
resolved_sparkle_version="$(
  jq -er '.pins[] | select(.identity == "sparkle") | .state.version' "$package_resolved"
)"
workflow_sparkle_version="$(
  sed -nE 's/^[[:space:]]*SPARKLE_VERSION: "([0-9]+\.[0-9]+\.[0-9]+)"$/\1/p' \
    .github/workflows/release.yml
)"
workflow_sparkle_checksum="$(
  sed -nE 's/^[[:space:]]*SPARKLE_ARCHIVE_SHA256: "([0-9a-f]+)"$/\1/p' \
    .github/workflows/release.yml
)"

if [[ "$project_sparkle_version" != "$resolved_sparkle_version" ||
      "$project_sparkle_version" != "$workflow_sparkle_version" ]]; then
  echo "Sparkle versions must match across the Xcode project, Package.resolved, and release workflow." >&2
  echo "Project:  ${project_sparkle_version:-missing}" >&2
  echo "Resolved: ${resolved_sparkle_version:-missing}" >&2
  echo "Workflow: ${workflow_sparkle_version:-missing}" >&2
  exit 1
fi

if [[ ! "$workflow_sparkle_checksum" =~ ^[0-9a-f]{64}$ ]]; then
  echo "The release workflow must pin the Sparkle tools archive with a full SHA-256 checksum." >&2
  exit 1
fi

npm_manifest="docs/assets/source/package.json"
npm_lock="docs/assets/source/package-lock.json"
playwright_version="$(
  jq -er '.devDependencies.playwright | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+([-.][0-9A-Za-z.-]+)?$"))' \
    "$npm_manifest"
)"

jq -e --arg playwright_version "$playwright_version" '
  .lockfileVersion == 3 and
  .packages[""].devDependencies.playwright == $playwright_version and
  .packages["node_modules/playwright"].version == $playwright_version and
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
