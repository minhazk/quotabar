#!/bin/bash
# Build LeftBar.app from this checkout. Used by install.sh and by the release workflow.
#   scripts/build-app.sh <out-dir> [--universal]
# Produces <out-dir>/LeftBar.app, ad-hoc signed. Needs Command Line Tools (or Xcode for --universal).
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:?usage: build-app.sh <out-dir> [--universal]}"
VERSION="$(cat VERSION)"

if [[ "${2:-}" == "--universal" ]]; then
  # Some SwiftPM backends reuse a shared Products/Release directory across architectures.
  # Preserve each executable immediately after building it before the next architecture overwrites it.
  ARCH_DIR="$(mktemp -d)"
  trap 'rm -rf "$ARCH_DIR"' EXIT
  for a in arm64 x86_64; do
    swift build -j 2 -c release --arch "$a"
    cp "$(swift build -j 2 -c release --arch "$a" --show-bin-path)/LeftBar" "$ARCH_DIR/LeftBar-$a"
  done
  BIN="$ARCH_DIR/LeftBar"
  lipo -create -output "$BIN" \
    "$ARCH_DIR/LeftBar-arm64" "$ARCH_DIR/LeftBar-x86_64"
  lipo -info "$BIN"
else
  swift build -j 2 -c release
  BIN="$(swift build -j 2 -c release --show-bin-path)/LeftBar"
fi

APP="$OUT/LeftBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/marks"
cp "$BIN" "$APP/Contents/MacOS/LeftBar"
cp Resources/marks/*.svg "$APP/Contents/Resources/marks/"
cp Resources/cli.sb "$APP/Contents/Resources/cli.sb"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>io.github.minhazk.leftbar</string>
  <key>CFBundleName</key><string>LeftBar</string>
  <key>CFBundleDisplayName</key><string>LeftBar</string>
  <key>CFBundleExecutable</key><string>LeftBar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Ad-hoc signature: no Apple Developer ID (see README → Security). It still seals the bundle, so
# `codesign --verify --strict` detects any byte changed after the build.
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"
echo "built $APP ($VERSION)"
