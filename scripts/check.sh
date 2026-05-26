#!/usr/bin/env bash
set -euo pipefail

swift test
swift build
if [[ -f Resources/Info.plist ]]; then
  ./scripts/build_app.sh
  ./scripts/verify_bundle.sh
  ./scripts/package_dmg.sh --output .build/release-test/Cuneiform-verified.dmg
  Tests/ScriptTests/test_release_dmg.sh
fi
