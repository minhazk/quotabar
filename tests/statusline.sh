#!/bin/bash
# Test fixture output while denying ALL file writes, preserving real user caches.
set -euo pipefail
APP="${1:?usage: tests/statusline.sh <LeftBar.app>}"
BIN="$APP/Contents/MacOS/LeftBar"
check() {
  local got
  got="$(printf '%s' "$1" | sandbox-exec -p '(version 1)(allow default)(deny file-write*)' "$BIN" --statusline)"
  [[ "$got" == "$2" ]] || { printf 'FAIL: got %s, expected %s\n' "$got" "$2" >&2; exit 1; }
  echo "ok   $got"
}
check '{"model":{"display_name":"Claude Example"},"rate_limits":{"seven_day":{"used_percentage":0},"five_hour":{"used_percentage":23}}}' 'Claude Example · 7d 100% left · 5h 77% left'
check '{"rate_limits":{"seven_day":{"used_percentage":100},"five_hour":{"used_percentage":99.8}}}' 'Claude · 7d 0% left · 5h <1% left'
check '{"rate_limits":{"seven_day":{"used_percentage":63,"resets_at":"2000-01-01T00:00:00Z"}}}' 'Claude · 7d —% left'
check '{"rate_limits":{"seven_day":{"used_percentage":101}}}' 'Claude'
echo 'PASS: status line'
