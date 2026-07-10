#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLAYWRIGHT_VERSION="1.61.1"
RENDER_RUNTIME="${TMPDIR:-/tmp}/macdragscroll-readme-render"
PLAYWRIGHT_DIR="${RENDER_RUNTIME}/node_modules/playwright"

if [[ ! -d "${PLAYWRIGHT_DIR}" ]]; then
  npm install --prefix "${RENDER_RUNTIME}" "playwright@${PLAYWRIGHT_VERSION}"
fi

PLAYWRIGHT_PATH="${PLAYWRIGHT_DIR}" \
  node "${ROOT_DIR}/scripts/render-readme-demos.mjs"
