#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/Mac Drag Scroll.app" >&2
  exit 64
fi

APP_PATH="$1"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXPECTED_MINIMUM="14.0"

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "App Info.plist not found: $INFO_PLIST" >&2
  exit 66
fi

executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST")"
binary="$APP_PATH/Contents/MacOS/$executable_name"

if [[ ! -f "$binary" ]]; then
  echo "App executable not found: $binary" >&2
  exit 66
fi

minimum_system="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$INFO_PLIST")"
if [[ "$minimum_system" != "$EXPECTED_MINIMUM" ]]; then
  echo "Expected LSMinimumSystemVersion $EXPECTED_MINIMUM, got $minimum_system" >&2
  exit 65
fi

mach_o_count=0
architecture_failures=()
deployment_target_failures=()
local_library_failures=()
while IFS= read -r -d '' candidate; do
  if ! file -b "$candidate" | grep -q 'Mach-O'; then
    continue
  fi

  mach_o_count=$((mach_o_count + 1))
  if ! lipo "$candidate" -verify_arch arm64 x86_64 >/dev/null 2>&1; then
    architecture_failures+=("${candidate#"$APP_PATH"/}")
  fi

  declared_minimums="$(vtool -show-build "$candidate" | awk '$1 == "minos" { print $2 }' | sort -u)"
  while IFS= read -r declared_minimum; do
    [[ -n "$declared_minimum" ]] || continue
    if ! awk -v actual="$declared_minimum" -v maximum="$EXPECTED_MINIMUM" 'BEGIN {
      split(actual, a, ".")
      split(maximum, m, ".")
      for (i = 1; i <= 3; i++) {
        av = (a[i] == "" ? 0 : a[i] + 0)
        mv = (m[i] == "" ? 0 : m[i] + 0)
        if (av < mv) exit 0
        if (av > mv) exit 1
      }
      exit 0
    }'; then
      deployment_target_failures+=("${candidate#"$APP_PATH"/} (macOS $declared_minimum)")
    fi
  done <<< "$declared_minimums"

  if otool -L "$candidate" | grep -Eq '^[[:space:]]+/(Applications/Xcode|Users|opt/homebrew|usr/local)/'; then
    local_library_failures+=("${candidate#"$APP_PATH"/}")
  fi
done < <(find "$APP_PATH" -type f -print0)

if [[ "$mach_o_count" -eq 0 ]]; then
  echo "App bundle contains no Mach-O binaries." >&2
  exit 65
fi

if [[ "${#architecture_failures[@]}" -gt 0 ]]; then
  echo "Every executable component must contain arm64 and x86_64 slices:" >&2
  printf '  - %s\n' "${architecture_failures[@]}" >&2
  exit 65
fi

if [[ "${#deployment_target_failures[@]}" -gt 0 ]]; then
  echo "Mach-O components must not require a macOS version newer than $EXPECTED_MINIMUM:" >&2
  printf '  - %s\n' "${deployment_target_failures[@]}" >&2
  exit 65
fi

if [[ "${#local_library_failures[@]}" -gt 0 ]]; then
  echo "Mach-O components link machine-local library paths:" >&2
  printf '  - %s\n' "${local_library_failures[@]}" >&2
  exit 65
fi

echo "Compatibility passed: macOS $EXPECTED_MINIMUM+, $mach_o_count universal Mach-O components."
