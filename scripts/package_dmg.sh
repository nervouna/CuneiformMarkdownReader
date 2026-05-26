#!/usr/bin/env bash
set -euo pipefail

APP=".build/app/Cuneiform.app"
OUTPUT=".build/release/Cuneiform.dmg"
VOLUME_NAME="Cuneiform"
SKIP_VERIFY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --app" >&2
        exit 2
      fi
      APP="$2"
      shift 2
      ;;
    --output)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --output" >&2
        exit 2
      fi
      OUTPUT="$2"
      shift 2
      ;;
    --skip-verify)
      SKIP_VERIFY=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "$APP" ]]; then
  echo "App bundle not found: $APP" >&2
  exit 1
fi

if [[ "$SKIP_VERIFY" -eq 0 ]]; then
  codesign --verify --deep --strict "$APP"
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cuneiform-dmg.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

DMG_ROOT="$WORK_DIR/dmg-root"
mkdir -p "$DMG_ROOT"
cp -R "$APP" "$DMG_ROOT/Cuneiform.app"
ln -s /Applications "$DMG_ROOT/Applications"

mkdir -p "$(dirname "$OUTPUT")"
rm -f "$OUTPUT"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$OUTPUT" >/dev/null

if [[ "$SKIP_VERIFY" -eq 0 ]]; then
  hdiutil verify "$OUTPUT" >/dev/null
fi

echo "Created $OUTPUT"
