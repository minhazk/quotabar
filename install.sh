#!/bin/bash
# Build and install this checkout. No downloads, CLI configuration changes, or data removal.
set -euo pipefail
cd "$(dirname "$0")"
[[ "$(uname -s)" == Darwin ]] || { echo 'QuotaBar needs macOS.' >&2; exit 1; }
[[ $# -eq 0 ]] || { echo 'usage: bash install.sh (builds and installs this checkout)' >&2; exit 2; }
scripts/build-app.sh build
if [[ -w /Applications ]]; then DEST=/Applications; else DEST="$HOME/Applications"; fi
mkdir -p "$DEST"
APP="$DEST/QuotaBar.app"
pkill -x -u "$(id -u)" QuotaBar 2>/dev/null || true
sleep 0.5
if [[ -e "$APP" || -L "$APP" ]]; then
  [[ ! -L "$APP" ]] || { echo 'Refusing to replace a symlink.' >&2; exit 1; }
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" == io.github.minhazk.quotabar ]] || { echo 'Existing app has a different bundle ID.' >&2; exit 1; }
  BACKUP="$DEST/QuotaBar.backup-$(date +%Y%m%d-%H%M%S)-$$.app"
  mv "$APP" "$BACKUP"
  echo "Previous app preserved at $BACKUP"
fi
if ! ditto build/QuotaBar.app "$APP" || ! codesign --verify --strict "$APP"; then
  echo "Install failed. Previous bundle, if any, is preserved at ${BACKUP:-none}." >&2
  exit 1
fi
open -n "$APP"
echo "Installed $APP"
