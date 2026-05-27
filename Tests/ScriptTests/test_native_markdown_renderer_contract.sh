#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

bash -n scripts/measure_startup.sh

grep -F 'CUNEIFORM_RENDERER' scripts/measure_startup.sh >/dev/null
grep -F 'return .native' Sources/SimpleMarkdownPreviewerApp/PreviewRendererMode.swift >/dev/null
grep -F 'Cuneiform renderer: ${CUNEIFORM_RENDERER:-native}' scripts/measure_startup.sh >/dev/null
grep -F 'webview.contentReady or native.contentReady' scripts/measure_startup.sh >/dev/null
grep -F 'native.contentReady' Sources/SimpleMarkdownPreviewerApp/NativeMarkdownPreview.swift >/dev/null
grep -F 'PreviewRendererMode' Sources/SimpleMarkdownPreviewerApp/ContentView.swift >/dev/null
grep -F '.product(name: "MarkdownUI", package: "swift-markdown-ui")' Package.swift >/dev/null
