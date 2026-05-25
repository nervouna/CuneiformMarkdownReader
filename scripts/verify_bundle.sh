#!/usr/bin/env bash
set -euo pipefail

INFO=".build/app/SimpleMarkdownPreviewer.app/Contents/Info.plist"
APP=".build/app/SimpleMarkdownPreviewer.app"

test -f "$INFO"
test -x "$APP/Contents/MacOS/SimpleMarkdownPreviewer"
test -f "$APP/Contents/Resources/PreviewAssets/preview.css"
if /usr/bin/find "$APP/Contents/Resources" -name "*.bundle" -print -quit | grep -q .; then
  echo "Unexpected nested bundle in app resources" >&2
  exit 1
fi
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO" | grep -qx "com.damao.simple-markdown-previewer"
codesign --verify --deep --strict "$APP"
/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0:CFBundleTypeExtensions:0" "$INFO" | grep -qx "md"
/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0:CFBundleTypeExtensions:1" "$INFO" | grep -qx "markdown"
