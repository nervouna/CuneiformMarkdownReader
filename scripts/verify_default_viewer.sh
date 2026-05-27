#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/.build/app/Cuneiform.app}"
EXPECTED_BUNDLE_ID="io.damao.cuneiform"

if [[ ! -d "$APP" ]]; then
  echo "App bundle not found: $APP" >&2
  exit 1
fi

actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
if [[ "$actual_bundle_id" != "$EXPECTED_BUNDLE_ID" ]]; then
  echo "Bundle id mismatch for $APP. Expected $EXPECTED_BUNDLE_ID, got $actual_bundle_id." >&2
  exit 1
fi

canonical_app="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]).rstrip("/"))' "$APP")"
registered_paths="$(
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -dump |
    awk -v target="$canonical_app" -v bundle_id="$EXPECTED_BUNDLE_ID" '
      /^path:/ {
        path = $0
        sub(/^path:[[:space:]]*/, "", path)
        sub(/[[:space:]]+\(0x[0-9a-fA-F]+\)$/, "", path)
      }
      /^identifier:/ {
        identifier = $2
        if (identifier == bundle_id) {
          print path
        }
      }
    '
)"
if ! grep -Fx "$canonical_app" <<<"$registered_paths" >/dev/null; then
  echo "LaunchServices has no registration for $EXPECTED_BUNDLE_ID at $APP." >&2
  echo "Run ./scripts/build_app.sh or register the bundle with lsregister before measuring." >&2
  exit 1
fi

swift_file="$(mktemp "${TMPDIR:-/tmp}/cuneiform-default-handler.XXXXXX.swift")"
sample_file="$(mktemp "${TMPDIR:-/tmp}/cuneiform-default-handler.XXXXXX.md")"
trap 'rm -f "$swift_file"' EXIT
trap 'rm -f "$swift_file" "$sample_file"' EXIT
printf '# Cuneiform default handler probe\n' > "$sample_file"
cat > "$swift_file" <<'SWIFT'
import CoreServices
import Foundation

let fileURL = URL(fileURLWithPath: CommandLine.arguments[1])
var error: Unmanaged<CFError>?
let appURL = LSCopyDefaultApplicationURLForURL(fileURL as CFURL, .viewer, &error)?
    .takeRetainedValue() as URL?
print(appURL?.path ?? "")
SWIFT

default_app_path="$(swift "$swift_file" "$sample_file")"
canonical_default_app="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]).rstrip("/"))' "$default_app_path" 2>/dev/null || true)"
if [[ "$canonical_default_app" != "$canonical_app" ]]; then
  echo "Default Markdown viewer resolves to ${default_app_path:-unset}, not $APP." >&2
  if [[ -n "$registered_paths" ]]; then
    echo "Registered $EXPECTED_BUNDLE_ID paths:" >&2
    sed 's/^/  /' <<<"$registered_paths" >&2
  fi
  exit 1
fi

echo "Default Markdown viewer verified: $EXPECTED_BUNDLE_ID at $APP"
