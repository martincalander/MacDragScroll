#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="${TMPDIR:-/tmp}/mac-drag-scroll-fuzz-check"

rm -rf "$tmp_dir"
mkdir -p "$tmp_dir"

while IFS= read -r -d '' harness; do
  name="$(basename "$harness" .swift)"
  swiftc -D FUZZING -parse-as-library -emit-object "$harness" -o "$tmp_dir/${name}.o"
done < <(find "$root/Fuzzers" -name '*.swift' -print0 | sort -z)

echo "Fuzz harness syntax checks passed."
