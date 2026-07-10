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

var corpus = [
    Data(),
    Data("com.example.application".utf8),
    Data("https://github.com/martincalander/MacDragScroll".utf8),
    Data([0x00, 0xFF, 0xC0, 0xAF]),
    Data(repeating: 0x41, count: 8192)
]

var state: UInt64 = 0x4D_44_53_46_55_5A_5A
for index in 0..<64 {
    let length = (index * 67) % 4096
    var bytes = [UInt8]()
    bytes.reserveCapacity(length)

    for _ in 0..<length {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        bytes.append(UInt8(truncatingIfNeeded: state >> 24))
    }

    corpus.append(Data(bytes))
}

for input in corpus {
    PreferenceInputFuzzer.exercise(input)
}
SWIFT

guard_malloc="/usr/lib/libgmalloc.dylib"
guard_log="$tmp_dir/guard-malloc.log"

if [[ ! -f "$guard_malloc" ]]; then
  echo "Guard Malloc is unavailable: $guard_malloc" >&2
  exit 69
fi

swiftc "$root/Fuzzers/PreferenceInputFuzzer.swift" "$tmp_dir/main.swift" -o "$tmp_dir/preference-input-guarded"

if ! DYLD_PRINT_LIBRARIES=1 \
  DYLD_INSERT_LIBRARIES="$guard_malloc" \
  MallocStackLogging=1 \
  "$tmp_dir/preference-input-guarded" 2> "$guard_log"; then
  cat "$guard_log" >&2
  exit 1
fi

if ! grep -q "$guard_malloc" "$guard_log"; then
  cat "$guard_log" >&2
  echo "Guard Malloc was not loaded into the fuzz process." >&2
  exit 1
fi

echo "Fuzz harness syntax and Guard Malloc stress checks passed."
