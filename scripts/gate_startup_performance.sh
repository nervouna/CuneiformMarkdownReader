#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="/Applications/Cuneiform.app"
FILE="${1:-$ROOT/README.md}"
ITERATIONS="${ITERATIONS:-20}"
CUNEIFORM_STARTUP_P50_MAX_MS="${CUNEIFORM_STARTUP_P50_MAX_MS:-400}"
MEASURE_STARTUP_SCRIPT="$ROOT/scripts/measure_startup.sh"
OUTPUT="${TMPDIR:-/tmp}/cuneiform-startup-gate-$(uuidgen).txt"

if [[ "${CUNEIFORM_STARTUP_GATE_TESTING:-}" == "1" ]]; then
  APP="${CUNEIFORM_STARTUP_GATE_APP:-$APP}"
  MEASURE_STARTUP_SCRIPT="${CUNEIFORM_MEASURE_STARTUP_SCRIPT:-$MEASURE_STARTUP_SCRIPT}"
fi

if [[ ! -d "$APP" ]]; then
  echo "App bundle not found: $APP" >&2
  echo "Install the checked release bundle to /Applications/Cuneiform.app before running this gate." >&2
  exit 1
fi

if ! [[ "$ITERATIONS" =~ ^[0-9]+$ ]] || [[ "$ITERATIONS" -lt 1 ]]; then
  echo "ITERATIONS must be a positive integer: $ITERATIONS" >&2
  exit 1
fi

if ! [[ "$CUNEIFORM_STARTUP_P50_MAX_MS" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "CUNEIFORM_STARTUP_P50_MAX_MS must be numeric: $CUNEIFORM_STARTUP_P50_MAX_MS" >&2
  exit 1
fi

env -u CUNEIFORM_RENDERER \
  CUNEIFORM_APP="$APP" \
  ITERATIONS="$ITERATIONS" \
  "$MEASURE_STARTUP_SCRIPT" "$FILE" | tee "$OUTPUT"

cuneiform_external_p50="$(
  python3 - "$OUTPUT" <<'PY'
import re
import sys

path = sys.argv[1]
for line in open(path, encoding="utf-8"):
    if line.startswith("Cuneiform external:"):
        match = re.search(r"p50=([0-9.]+)ms", line)
        if match:
            print(match.group(1))
            raise SystemExit(0)

print("Could not find Cuneiform external p50 in measurement output.", file=sys.stderr)
raise SystemExit(1)
PY
)"

python3 - "$cuneiform_external_p50" "$CUNEIFORM_STARTUP_P50_MAX_MS" <<'PY'
import sys

p50 = float(sys.argv[1])
limit = float(sys.argv[2])

if p50 > limit:
    print(f"Cuneiform startup gate failed: external p50 {p50:.2f}ms > {limit:.2f}ms", file=sys.stderr)
    raise SystemExit(1)

print(f"Cuneiform startup gate passed: external p50 {p50:.2f}ms <= {limit:.2f}ms")
PY
