#!/usr/bin/env bash
set -euo pipefail

swift test
swift build
if [[ -f Resources/Info.plist ]]; then
  ./scripts/build_app.sh
  ./scripts/verify_bundle.sh
fi
