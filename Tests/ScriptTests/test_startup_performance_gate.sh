#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

bash -n scripts/gate_startup_performance.sh

grep -F 'CUNEIFORM_STARTUP_P50_MAX_MS="${CUNEIFORM_STARTUP_P50_MAX_MS:-400}"' scripts/gate_startup_performance.sh >/dev/null
grep -F 'ITERATIONS="${ITERATIONS:-20}"' scripts/gate_startup_performance.sh >/dev/null
grep -F 'APP="/Applications/Cuneiform.app"' scripts/gate_startup_performance.sh >/dev/null
grep -F 'scripts/measure_startup.sh' scripts/gate_startup_performance.sh >/dev/null
grep -F 'CUNEIFORM_STARTUP_GATE_TESTING' scripts/gate_startup_performance.sh >/dev/null
grep -F 'Cuneiform external' scripts/gate_startup_performance.sh >/dev/null
grep -F 'p50=' scripts/gate_startup_performance.sh >/dev/null
grep -F 'exit 1' scripts/gate_startup_performance.sh >/dev/null
grep -F 'Tests/ScriptTests/test_startup_performance_gate.sh' scripts/check.sh >/dev/null

mkdir -p "$TMP_DIR/app"
cat > "$TMP_DIR/measure_startup.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${CUNEIFORM_RENDERER:-}" ]]; then
  echo "CUNEIFORM_RENDERER leaked into the release gate measurement." >&2
  exit 64
fi

p50="${MOCK_CUNEIFORM_EXTERNAL_P50:-399.50}"
echo "Cuneiform renderer: native"
echo "TextEdit: count=20 min=300.00ms p50=320.00ms p95=340.00ms max=350.00ms"
echo "Cuneiform external: count=20 min=350.00ms p50=${p50}ms p95=410.00ms max=420.00ms"
echo "Cuneiform app-internal: count=20 min=250.00ms p50=280.00ms p95=310.00ms max=320.00ms"
SH
chmod +x "$TMP_DIR/measure_startup.sh"

CUNEIFORM_STARTUP_GATE_TESTING=1 \
  CUNEIFORM_STARTUP_GATE_APP="$TMP_DIR/app" \
  CUNEIFORM_MEASURE_STARTUP_SCRIPT="$TMP_DIR/measure_startup.sh" \
  scripts/gate_startup_performance.sh README.md > "$TMP_DIR/pass-output.txt"

grep -F 'Cuneiform startup gate passed: external p50 399.50ms <= 400.00ms' "$TMP_DIR/pass-output.txt" >/dev/null

if CUNEIFORM_STARTUP_GATE_TESTING=1 \
  CUNEIFORM_STARTUP_GATE_APP="$TMP_DIR/app" \
  CUNEIFORM_MEASURE_STARTUP_SCRIPT="$TMP_DIR/measure_startup.sh" \
  MOCK_CUNEIFORM_EXTERNAL_P50=400.01 \
  scripts/gate_startup_performance.sh README.md > "$TMP_DIR/fail-output.txt" 2>&1; then
  echo "Expected startup gate to fail when Cuneiform external p50 exceeds the threshold." >&2
  exit 1
fi

grep -F 'Cuneiform startup gate failed: external p50 400.01ms > 400.00ms' "$TMP_DIR/fail-output.txt" >/dev/null
