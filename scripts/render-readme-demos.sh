#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${ROOT_DIR}/docs/assets/source"
PLAYWRIGHT_DIR="${SOURCE_DIR}/node_modules/playwright"
PLAYWRIGHT_CLI="${SOURCE_DIR}/node_modules/.bin/playwright"

npm ci --prefix "${SOURCE_DIR}" --ignore-scripts --no-audit --no-fund

"${PLAYWRIGHT_CLI}" install chromium

PLAYWRIGHT_PATH="${PLAYWRIGHT_DIR}" \
  node "${ROOT_DIR}/scripts/render-readme-demos.mjs"
