#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:---verify}"
case "$MODE" in run|--verify|--logs|--telemetry|--debug) ;; *) echo "usage: $0 [run|--verify|--logs|--telemetry|--debug]" >&2; exit 2;; esac
pkill -x -u "$(id -u)" QuotaBar 2>/dev/null || true
scripts/build-app.sh build
APP="$PWD/build/QuotaBar.app"
case "$MODE" in
  --debug) exec lldb -- "$APP/Contents/MacOS/QuotaBar" ;;
  *) /usr/bin/open -n "$APP" ;;
esac
case "$MODE" in
  --verify) sleep 1; pgrep -x -u "$(id -u)" QuotaBar >/dev/null; echo "QuotaBar launched from $APP" ;;
  --logs|--telemetry) exec /usr/bin/log stream --info --style compact --predicate 'process == "QuotaBar"' ;;
esac
