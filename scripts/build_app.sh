#!/usr/bin/env bash
set -euo pipefail

APP_DIR=".build/app/Cuneiform.app"
LEGACY_APP_DIR=".build/app/SimpleMarkdownPreviewer.app"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
EXECUTABLE="$BIN_DIR/Cuneiform"
rm -rf "$APP_DIR" "$LEGACY_APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/Cuneiform"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp Resources/Cuneiform.icns "$APP_DIR/Contents/Resources/Cuneiform.icns"
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"
RESOURCE_BUNDLE="$(find "$BIN_DIR" -maxdepth 1 \( -name "*SimpleMarkdownPreviewerCore*.resources" -o -name "*SimpleMarkdownPreviewerCore*.bundle" \) -print -quit)"
test -n "$RESOURCE_BUNDLE"
mkdir -p "$APP_DIR/Contents/Resources/PreviewAssets"
cp -R "$RESOURCE_BUNDLE"/. "$APP_DIR/Contents/Resources/PreviewAssets/"
codesign --force --deep --sign - "$APP_DIR" >/dev/null
