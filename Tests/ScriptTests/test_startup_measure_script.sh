#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

bash -n scripts/measure_startup.sh
grep -F 'launchctl setenv CUNEIFORM_STARTUP_PROBE 1' scripts/measure_startup.sh >/dev/null
grep -F 'TextEdit.app' scripts/measure_startup.sh >/dev/null
grep -F 'p50' scripts/measure_startup.sh >/dev/null
grep -F 'p95' scripts/measure_startup.sh >/dev/null
grep -F 'Cuneiform external' scripts/measure_startup.sh >/dev/null
grep -F 'Cuneiform app-internal' scripts/measure_startup.sh >/dev/null
grep -F 'APP="${CUNEIFORM_APP:-$ROOT/.build/app/Cuneiform.app}"' scripts/measure_startup.sh >/dev/null
grep -F 'open -n -a "$APP" "$FILE"' scripts/measure_startup.sh >/dev/null
grep -F 'wait_for_probe_finish "$log"' scripts/measure_startup.sh >/dev/null
grep -F 'webview.contentReady' scripts/measure_startup.sh >/dev/null
grep -F 'verify_default_viewer.sh' scripts/measure_startup.sh >/dev/null
grep -F 'bash -n scripts/verify_default_viewer.sh' Tests/ScriptTests/test_startup_measure_script.sh >/dev/null
grep -F 'TextEdit is already running' scripts/measure_startup.sh >/dev/null
! grep -F 'open -W -n "$FILE"' scripts/measure_startup.sh >/dev/null
bash -n scripts/verify_default_viewer.sh
