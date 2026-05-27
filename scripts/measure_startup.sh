#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/app/Cuneiform.app"
FILE="${1:-$ROOT/README.md}"
ITERATIONS="${ITERATIONS:-10}"
LOG_DIR="${TMPDIR:-/tmp}/cuneiform-startup"
mkdir -p "$LOG_DIR"

if [[ ! -d "$APP" ]]; then
  echo "App bundle not found: $APP" >&2
  echo "Run ./scripts/build_app.sh first." >&2
  exit 1
fi

if [[ "$(osascript -e 'application "TextEdit" is running')" == "true" ]]; then
  echo "TextEdit is already running. Close TextEdit before measuring to avoid false samples or closing user documents." >&2
  exit 1
fi

cleanup_probe_env() {
  launchctl unsetenv CUNEIFORM_STARTUP_PROBE >/dev/null 2>&1 || true
  launchctl unsetenv CUNEIFORM_STARTUP_PROBE_QUIT >/dev/null 2>&1 || true
  launchctl unsetenv CUNEIFORM_STARTUP_PROBE_LOG >/dev/null 2>&1 || true
}
trap cleanup_probe_env EXIT

now_seconds() {
  perl -MTime::HiRes=time -e 'printf "%.6f", time'
}

measure_textedit_once() {
  local start end visible
  start="$(now_seconds)"
  open -n -a /System/Applications/TextEdit.app "$FILE"
  for _ in $(seq 1 500); do
    visible="$(osascript -e 'tell application "System Events" to exists window 1 of process "TextEdit"' 2>/dev/null || true)"
    if [[ "$visible" == "true" ]]; then
      end="$(now_seconds)"
      osascript -e 'tell application "TextEdit" to quit saving no' >/dev/null 2>&1 || true
      perl -e 'printf "%.2f\n", ($ARGV[1] - $ARGV[0]) * 1000' "$start" "$end"
      return 0
    fi
    sleep 0.01
  done
  osascript -e 'tell application "TextEdit" to quit saving no' >/dev/null 2>&1 || true
  echo "TextEdit timeout" >&2
  return 1
}

wait_for_probe_finish() {
  local log="$1"
  for _ in $(seq 1 1000); do
    if awk '/webview.didFinish/ { found=1 } END { exit found ? 0 : 1 }' "$log"; then
      return 0
    fi
    sleep 0.01
  done
  return 1
}

probe_internal_time() {
  local log="$1"
  awk '/webview.didFinish/ { value=$2 } END { sub(/ms$/, "", value); print value }' "$log"
}

measure_cuneiform_once() {
  local log start end internal
  log="$LOG_DIR/cuneiform-$(uuidgen).log"
  : > "$log"
  cleanup_probe_env
  launchctl setenv CUNEIFORM_STARTUP_PROBE 1
  launchctl setenv CUNEIFORM_STARTUP_PROBE_QUIT 1
  launchctl setenv CUNEIFORM_STARTUP_PROBE_LOG "$log"
  start="$(now_seconds)"
  open -n -a "$APP" "$FILE" >/dev/null
  if ! wait_for_probe_finish "$log"; then
    cleanup_probe_env
    echo "Cuneiform probe did not report webview.didFinish. Log: $log" >&2
    return 1
  fi
  end="$(now_seconds)"
  cleanup_probe_env
  internal="$(probe_internal_time "$log")"
  if [[ -z "$internal" ]]; then
    echo "Cuneiform probe did not report webview.didFinish. Log: $log" >&2
    return 1
  fi
  perl -e 'printf "%.2f %.2f\n", ($ARGV[1] - $ARGV[0]) * 1000, $ARGV[2]' "$start" "$end" "$internal"
}

summarize() {
  local name="$1"
  local file="$2"
  python3 - "$name" "$file" <<'PY'
import statistics
import sys

name, path = sys.argv[1], sys.argv[2]
values = [float(line.strip()) for line in open(path) if line.strip()]
values.sort()

def percentile(p):
    index = round((len(values) - 1) * p)
    return values[index]

print(f"{name}: count={len(values)} min={values[0]:.2f}ms p50={statistics.median(values):.2f}ms p95={percentile(0.95):.2f}ms max={values[-1]:.2f}ms")
PY
}

textedit_values="$LOG_DIR/textedit-values.txt"
cuneiform_values="$LOG_DIR/cuneiform-values.txt"
cuneiform_internal_values="$LOG_DIR/cuneiform-internal-values.txt"
: > "$textedit_values"
: > "$cuneiform_values"
: > "$cuneiform_internal_values"

for _ in $(seq 1 "$ITERATIONS"); do
  measure_textedit_once >> "$textedit_values"
  sample="$(measure_cuneiform_once)"
  awk '{ print $1 }' <<<"$sample" >> "$cuneiform_values"
  awk '{ print $2 }' <<<"$sample" >> "$cuneiform_internal_values"
done

summarize "TextEdit" "$textedit_values"
summarize "Cuneiform external" "$cuneiform_values"
summarize "Cuneiform app-internal" "$cuneiform_internal_values"
