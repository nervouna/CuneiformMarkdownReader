#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

grep -Fx 'swift build -c release' scripts/build_app.sh >/dev/null
grep -Fx 'BIN_DIR="$(swift build -c release --show-bin-path)"' scripts/build_app.sh >/dev/null
! grep -Ex 'swift build$' scripts/build_app.sh >/dev/null
