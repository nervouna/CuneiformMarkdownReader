#!/usr/bin/env bash
set -euo pipefail

APP_DIR=".build/app/SimpleMarkdownPreviewer.app"

swift build
BIN_DIR="$(swift build --show-bin-path)"
EXECUTABLE="$BIN_DIR/SimpleMarkdownPreviewer"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/SimpleMarkdownPreviewer"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"
find "$BIN_DIR" -maxdepth 1 \( -name "*SimpleMarkdownPreviewerCore*.resources" -o -name "*SimpleMarkdownPreviewerCore*.bundle" \) -exec cp -R {} "$APP_DIR/Contents/Resources/" \;
codesign --force --deep --sign - "$APP_DIR" >/dev/null
