#!/usr/bin/env bash
set -euo pipefail

INFO=".build/app/SimpleMarkdownPreviewer.app/Contents/Info.plist"
APP=".build/app/SimpleMarkdownPreviewer.app"

test -f "$INFO"
test -x "$APP/Contents/MacOS/SimpleMarkdownPreviewer"
test -f "$APP/Contents/Resources/SimpleMarkdownPreviewer_SimpleMarkdownPreviewerCore.bundle/preview.css"
codesign --verify --deep --strict "$APP"
/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0:CFBundleTypeExtensions:0" "$INFO" | grep -qx "md"
/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0:CFBundleTypeExtensions:1" "$INFO" | grep -qx "markdown"
