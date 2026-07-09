#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <version>" >&2
  exit 64
fi

version="${1#v}"
changelog="${CHANGELOG_FILE:-CHANGELOG.md}"

if [[ ! -f "$changelog" ]]; then
  echo "Changelog not found: $changelog" >&2
  exit 66
fi

awk -v version="$version" '
  BEGIN {
    in_section = 0
    found = 0
  }
  /^## / {
    if (in_section) {
      exit
    }
    heading = $0
    if (heading ~ "^## \\[?" version "\\]?([[:space:]]|-|$)") {
      in_section = 1
      found = 1
      next
    }
  }
  in_section {
    print
  }
  END {
    if (!found) {
      exit 1
    }
  }
' "$changelog" | sed '/./,$!d'
