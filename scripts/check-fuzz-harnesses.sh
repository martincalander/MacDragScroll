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

cat > "$tmp_dir/main.swift" <<'SWIFT'
import Foundation

let corpus = [
    Data(),
    Data("com.example.application".utf8),
    Data("https://github.com/martincalander/MacDragScroll".utf8),
    Data([0x00, 0xFF, 0xC0, 0xAF]),
    Data(repeating: 0x41, count: 8192)
]

for input in corpus {
    PreferenceInputFuzzer.exercise(input)
}
SWIFT

swiftc \
  -sanitize=undefined \
  "$root/Fuzzers/PreferenceInputFuzzer.swift" \
  "$tmp_dir/main.swift" \
  -o "$tmp_dir/preference-input-ubsan"

UBSAN_OPTIONS="halt_on_error=1:print_stacktrace=1" "$tmp_dir/preference-input-ubsan"

echo "Fuzz harness syntax and Undefined Behavior Sanitizer smoke checks passed."
