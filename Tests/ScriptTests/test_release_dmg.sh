#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

rm -rf .build/release-test
mkdir -p .build/release-test/Cuneiform.app/Contents/MacOS
cat > .build/release-test/Cuneiform.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Cuneiform</string>
    <key>CFBundleIdentifier</key>
    <string>io.damao.cuneiform</string>
    <key>CFBundleName</key>
    <string>Cuneiform</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
PLIST
printf '#!/usr/bin/env bash\nexit 0\n' > .build/release-test/Cuneiform.app/Contents/MacOS/Cuneiform
chmod +x .build/release-test/Cuneiform.app/Contents/MacOS/Cuneiform

scripts/package_dmg.sh \
  --app .build/release-test/Cuneiform.app \
  --output .build/release-test/Cuneiform-test.dmg \
  --skip-verify

test -f .build/release-test/Cuneiform-test.dmg

MOUNT_POINT=".build/release-test/mount"
mkdir -p "$MOUNT_POINT"
hdiutil attach .build/release-test/Cuneiform-test.dmg -nobrowse -readonly -mountpoint "$MOUNT_POINT" >/dev/null
trap 'hdiutil detach "$MOUNT_POINT" >/dev/null' EXIT

test -d "$MOUNT_POINT/Cuneiform.app"
test -L "$MOUNT_POINT/Applications"
test "$(readlink "$MOUNT_POINT/Applications")" = "/Applications"
