#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/Mac\ Drag\ Scroll.app" >&2
  exit 64
fi

APP_PATH="$1"
BINARY="$APP_PATH/Contents/MacOS/Mac Drag Scroll"
LOG_PATH="$(mktemp /tmp/macdragscroll-launch.XXXXXX.log)"
PROFILE_PATH="${LOG_PATH%.log}.profraw"
APP_PID=""

cleanup() {
  if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" >/dev/null 2>&1; then
    kill -TERM "$APP_PID" >/dev/null 2>&1 || true
    wait "$APP_PID" >/dev/null 2>&1 || true
  fi
  rm -f "$LOG_PATH" "$PROFILE_PATH"
}
trap cleanup EXIT

if [[ ! -x "$BINARY" ]]; then
  echo "App executable not found: $BINARY" >&2
  exit 66
fi

LLVM_PROFILE_FILE="$PROFILE_PATH" "$BINARY" >"$LOG_PATH" 2>&1 &
APP_PID=$!

for _ in {1..30}; do
  if ! kill -0 "$APP_PID" >/dev/null 2>&1; then
    status=0
    wait "$APP_PID" || status=$?
    APP_PID=""
    cat "$LOG_PATH" >&2
    echo "Signed app exited during launch with status $status." >&2
    exit 65
  fi
  sleep 0.1
done

kill -TERM "$APP_PID" >/dev/null 2>&1 || true
wait "$APP_PID" >/dev/null 2>&1 || true
APP_PID=""

echo "Launch passed: signed app remained active for 3 seconds."
