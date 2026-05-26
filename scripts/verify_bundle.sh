#!/usr/bin/env bash
set -euo pipefail

INFO=".build/app/Cuneiform.app/Contents/Info.plist"
APP=".build/app/Cuneiform.app"

test -f "$INFO"
test -x "$APP/Contents/MacOS/Cuneiform"
test ! -e ".build/app/SimpleMarkdownPreviewer.app"
test -f "$APP/Contents/Resources/Cuneiform.icns"
test -f "$APP/Contents/Resources/PreviewAssets/preview.css"
if /usr/bin/find "$APP/Contents/Resources" -name "*.bundle" -print -quit | grep -q .; then
  echo "Unexpected nested bundle in app resources" >&2
  exit 1
fi
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO" | grep -qx "io.damao.cuneiform"
/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$INFO" | grep -qx "Cuneiform"
/usr/libexec/PlistBuddy -c "Print :CFBundleName" "$INFO" | grep -qx "Cuneiform"
/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$INFO" | grep -qx "Cuneiform"
codesign --verify --deep --strict "$APP"
/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0:CFBundleTypeExtensions:0" "$INFO" | grep -qx "md"
/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0:CFBundleTypeExtensions:1" "$INFO" | grep -qx "markdown"
/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0:LSItemContentTypes:0" "$INFO" | grep -qx "net.daringfireball.markdown"
/usr/libexec/PlistBuddy -c "Print :UTImportedTypeDeclarations:0:UTTypeIdentifier" "$INFO" | grep -qx "net.daringfireball.markdown"
/usr/libexec/PlistBuddy -c "Print :UTImportedTypeDeclarations:0:UTTypeTagSpecification:public.filename-extension:0" "$INFO" | grep -qx "md"
/usr/libexec/PlistBuddy -c "Print :UTImportedTypeDeclarations:0:UTTypeTagSpecification:public.filename-extension:1" "$INFO" | grep -qx "markdown"
