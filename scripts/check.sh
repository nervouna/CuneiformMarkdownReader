#!/usr/bin/env bash
set -euo pipefail

swift test
swift build
if [[ -f Resources/Info.plist ]]; then
  Tests/ScriptTests/test_build_app_script.sh
  Tests/ScriptTests/test_startup_measure_script.sh
  ./scripts/build_app.sh
  ./scripts/verify_bundle.sh
  ./scripts/package_dmg.sh --output .build/release-test/Cuneiform-verified.dmg
  Tests/ScriptTests/test_release_dmg.sh
fi
