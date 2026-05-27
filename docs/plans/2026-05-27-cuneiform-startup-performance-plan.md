# Cuneiform Startup Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Cuneiform consistently launch Markdown documents at TextEdit-class speed, with a target of `p50 <= 550ms` from LaunchServices open to document content visible.

**Architecture:** Treat startup performance as a measured product contract, not an assumed code property. Add an explicit startup measurement harness, verify that the measured app is the release bundle the user actually opens, remove duplicate open work, then run a gated `WKWebView` prewarm experiment and keep it only if it improves measured launch time.

**Tech Stack:** Swift 6, SwiftPM, AppKit, SwiftUI, WebKit, shell scripts, LaunchServices `open`, `osascript`/System Events for external launch timing, env-gated app probes for precise Cuneiform document-visible timing.

---

## Baseline Evidence

Use the current observed numbers as the initial baseline:

- TextEdit via LaunchServices to first window visible: `516.97ms`, `527.46ms`, `527.80ms`.
- Cuneiform release via LaunchServices external wall clock: about `0.50s`.
- Cuneiform app-internal `main.entry -> webview.didFinish`: about `380ms`.
- Markdown file load + render + template generation: under `2ms`.
- `WKWebView` creation and first load: about `140ms`.

The likely bottleneck is AppKit/WebKit/LaunchServices startup, not Markdown rendering.

## File Structure

Modify or create these files:

```text
Sources/SimpleMarkdownPreviewerApp/AppDelegate.swift
Sources/SimpleMarkdownPreviewerApp/AppState.swift
Sources/SimpleMarkdownPreviewerApp/ContentView.swift
Sources/SimpleMarkdownPreviewerApp/PreviewWebView.swift
Sources/SimpleMarkdownPreviewerApp/StartupProbe.swift
Tests/SimpleMarkdownPreviewerCoreTests/HTMLTemplateTests.swift
Tests/ScriptTests/test_build_app_script.sh
Tests/ScriptTests/test_startup_measure_script.sh
scripts/build_app.sh
scripts/check.sh
scripts/measure_startup.sh
scripts/verify_default_viewer.sh
```

Responsibility map:

- `StartupProbe.swift`: env-gated diagnostic probe. It must do nothing unless `CUNEIFORM_STARTUP_PROBE=1`.
- `AppDelegate.swift`: app lifecycle, default/open-file routing, and duplicate-open prevention.
- `AppState.swift`: document loading and render state. It should remain the source of truth for the current document.
- `ContentView.swift` and `PreviewWebView.swift`: persistent preview surface and optional WebKit prewarm experiment.
- `scripts/measure_startup.sh`: repeatable benchmark comparing Cuneiform and TextEdit with p50/p95 output.
- `scripts/verify_default_viewer.sh`: confirms LaunchServices default handler points at the expected Cuneiform bundle id.
- script tests: keep measurement and build-script regressions checkable without running GUI timing in the default suite.

## Measurement Contract

The plan uses two measurement modes:

- **External baseline:** `open -n -a <app> <file>` to first visible window for TextEdit and Cuneiform.
- **Cuneiform precise mode:** env-gated probe logs `webview.didFinish` when WebView finishes the first document load, then exits if `CUNEIFORM_STARTUP_PROBE_QUIT=1`.

Acceptance threshold:

- Primary: Cuneiform release bundle `p50 <= 550ms` over 10 LaunchServices launches on the test machine.
- Secondary: Cuneiform `p50` should be within 15% of TextEdit measured in the same run.
- Diagnostic: `p95` should be reported, but not used as a hard gate until more machines are sampled.

## Task 1: Release Bundle Guardrail

**Files:**
- Modify: `scripts/build_app.sh`
- Modify: `scripts/check.sh`
- Create: `Tests/ScriptTests/test_build_app_script.sh`

- [ ] **Step 1: Write the failing script test**

Add `Tests/ScriptTests/test_build_app_script.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

grep -Fx 'swift build -c release' scripts/build_app.sh >/dev/null
grep -Fx 'BIN_DIR="$(swift build -c release --show-bin-path)"' scripts/build_app.sh >/dev/null
! grep -Ex 'swift build$' scripts/build_app.sh >/dev/null
```

- [ ] **Step 2: Run the test to verify it fails before the build script change**

Run:

```bash
chmod +x Tests/ScriptTests/test_build_app_script.sh
Tests/ScriptTests/test_build_app_script.sh
```

Expected before implementation: exits non-zero if `scripts/build_app.sh` still uses debug `swift build`.

- [ ] **Step 3: Update the app build script**

In `scripts/build_app.sh`, make the build commands release-only:

```bash
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
```

- [ ] **Step 4: Wire the guardrail into the existing check script**

In `scripts/check.sh`, run the script test before bundle construction:

```bash
if [[ -f Resources/Info.plist ]]; then
  Tests/ScriptTests/test_build_app_script.sh
  ./scripts/build_app.sh
  ./scripts/verify_bundle.sh
  ./scripts/package_dmg.sh --output .build/release-test/Cuneiform-verified.dmg
  Tests/ScriptTests/test_release_dmg.sh
fi
```

- [ ] **Step 5: Verify and commit**

Run:

```bash
Tests/ScriptTests/test_build_app_script.sh
./scripts/build_app.sh
```

Expected: both commands exit `0`, and `.build/app/Cuneiform.app/Contents/MacOS/Cuneiform` is produced from the release build.

Commit:

```bash
git add scripts/build_app.sh scripts/check.sh Tests/ScriptTests/test_build_app_script.sh
git commit -m "fix: build Cuneiform app in release mode"
```

## Task 2: Startup Measurement Harness

**Files:**
- Create: `Sources/SimpleMarkdownPreviewerApp/StartupProbe.swift`
- Modify: `Sources/SimpleMarkdownPreviewerApp/SimpleMarkdownPreviewerApp.swift`
- Modify: `Sources/SimpleMarkdownPreviewerApp/AppState.swift`
- Modify: `Sources/SimpleMarkdownPreviewerApp/PreviewWebView.swift`
- Create: `scripts/measure_startup.sh`
- Create: `Tests/ScriptTests/test_startup_measure_script.sh`

- [ ] **Step 1: Add a script test for the benchmark script contract**

Create `Tests/ScriptTests/test_startup_measure_script.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

bash -n scripts/measure_startup.sh
grep -F 'CUNEIFORM_STARTUP_PROBE=1' scripts/measure_startup.sh >/dev/null
grep -F 'TextEdit.app' scripts/measure_startup.sh >/dev/null
grep -F 'p50' scripts/measure_startup.sh >/dev/null
grep -F 'p95' scripts/measure_startup.sh >/dev/null
```

- [ ] **Step 2: Run the script test to verify it fails before the script exists**

Run:

```bash
chmod +x Tests/ScriptTests/test_startup_measure_script.sh
Tests/ScriptTests/test_startup_measure_script.sh
```

Expected: fails because `scripts/measure_startup.sh` is missing.

- [ ] **Step 3: Add the env-gated startup probe**

Create `Sources/SimpleMarkdownPreviewerApp/StartupProbe.swift`:

```swift
import AppKit
import Foundation

enum StartupProbe {
    private static let clock = ContinuousClock()
    private static let start = clock.now
    private static let enabled = ProcessInfo.processInfo.environment["CUNEIFORM_STARTUP_PROBE"] == "1"
    private static let autoTerminate = ProcessInfo.processInfo.environment["CUNEIFORM_STARTUP_PROBE_QUIT"] == "1"

    static func mark(_ label: String) {
        guard enabled else { return }
        let elapsed = start.duration(to: clock.now)
        let milliseconds = Double(elapsed.components.seconds) * 1_000
            + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000
        write(String(format: "startup_probe %.2fms %@\n", milliseconds, label))
    }

    @MainActor
    static func finish(_ label: String) {
        mark(label)
        guard enabled, autoTerminate else { return }
        NSApp.terminate(nil)
    }

    private static func write(_ line: String) {
        if let logPath = ProcessInfo.processInfo.environment["CUNEIFORM_STARTUP_PROBE_LOG"] {
            if FileManager.default.fileExists(atPath: logPath),
               let handle = FileHandle(forWritingAtPath: logPath) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            } else {
                try? line.write(toFile: logPath, atomically: true, encoding: .utf8)
            }
        } else {
            FileHandle.standardError.write(Data(line.utf8))
        }
    }
}
```

- [ ] **Step 4: Add probe marks at stable lifecycle boundaries**

Add these calls:

```swift
// SimpleMarkdownPreviewerApp.main()
StartupProbe.mark("main.entry")
StartupProbe.mark("nsapplication.shared")
StartupProbe.mark("after.finishLaunching")
StartupProbe.mark("before.run")

// AppState.open and renderCurrentDocument()
StartupProbe.mark("appState.open.begin")
StartupProbe.mark("file.loaded")
StartupProbe.mark("markdown.render.end")
StartupProbe.mark("template.end")
StartupProbe.mark("viewState.rendered.set")

// PreviewWebView
StartupProbe.mark("webview.make.begin")
StartupProbe.mark("webview.make.end")
StartupProbe.mark("webview.loadHTML.begin")
StartupProbe.finish("webview.didFinish")
```

The exact placement should match the existing lifecycle code and avoid changing behavior when the probe env var is absent.

- [ ] **Step 5: Add the benchmark script**

Create `scripts/measure_startup.sh`:

```bash
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

measure_textedit_once() {
  local start end visible
  start="$(perl -MTime::HiRes=time -e 'printf "%.6f", time')"
  open -n -a /System/Applications/TextEdit.app "$FILE"
  for _ in $(seq 1 500); do
    visible="$(osascript -e 'tell application "System Events" to exists window 1 of process "TextEdit"' 2>/dev/null || true)"
    if [[ "$visible" == "true" ]]; then
      end="$(perl -MTime::HiRes=time -e 'printf "%.6f", time')"
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

cleanup_probe_env() {
  launchctl unsetenv CUNEIFORM_STARTUP_PROBE >/dev/null 2>&1 || true
  launchctl unsetenv CUNEIFORM_STARTUP_PROBE_QUIT >/dev/null 2>&1 || true
  launchctl unsetenv CUNEIFORM_STARTUP_PROBE_LOG >/dev/null 2>&1 || true
}

measure_cuneiform_once() {
  local log start end internal
  log="$LOG_DIR/cuneiform-$(uuidgen).log"
  : > "$log"
  launchctl setenv CUNEIFORM_STARTUP_PROBE 1
  launchctl setenv CUNEIFORM_STARTUP_PROBE_QUIT 1
  launchctl setenv CUNEIFORM_STARTUP_PROBE_LOG "$log"
  trap cleanup_probe_env RETURN
  start="$(perl -MTime::HiRes=time -e 'printf "%.6f", time')"
  open -W -n "$FILE" >/dev/null
  end="$(perl -MTime::HiRes=time -e 'printf "%.6f", time')"
  internal="$(awk '/webview.didFinish/ { value=$2 } END { sub(/ms$/, "", value); print value }' "$log")"
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
```

- [ ] **Step 6: Verify script syntax and probe build**

Run:

```bash
chmod +x scripts/measure_startup.sh Tests/ScriptTests/test_startup_measure_script.sh
Tests/ScriptTests/test_startup_measure_script.sh
swift build
```

Expected: script test exits `0`; `swift build` exits `0`.

- [ ] **Step 7: Commit**

```bash
git add Sources/SimpleMarkdownPreviewerApp scripts/measure_startup.sh Tests/ScriptTests/test_startup_measure_script.sh
git commit -m "test: add startup performance measurement harness"
```

## Task 3: Default Bundle and Handler Verification

**Files:**
- Create: `scripts/verify_default_viewer.sh`
- Modify: `scripts/measure_startup.sh`

- [ ] **Step 1: Add the default viewer verification script**

Create `scripts/verify_default_viewer.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/.build/app/Cuneiform.app}"
EXPECTED_BUNDLE_ID="io.damao.cuneiform"

if [[ ! -d "$APP" ]]; then
  echo "App bundle not found: $APP" >&2
  exit 1
fi

actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
if [[ "$actual_bundle_id" != "$EXPECTED_BUNDLE_ID" ]]; then
  echo "Bundle id mismatch for $APP. Expected $EXPECTED_BUNDLE_ID, got $actual_bundle_id." >&2
  exit 1
fi

resolved_path="$(osascript -e "POSIX path of (path to application id \"$EXPECTED_BUNDLE_ID\")" 2>/dev/null || true)"
canonical_app="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]).rstrip(\"/\") + \"/\")' "$APP")"
canonical_resolved="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]).rstrip(\"/\") + \"/\")' "$resolved_path" 2>/dev/null || true)"
if [[ "$canonical_resolved" != "$canonical_app" ]]; then
  echo "LaunchServices resolves $EXPECTED_BUNDLE_ID to ${resolved_path:-unresolved}, not $APP." >&2
  echo "Open or install the release bundle before measuring Finder/default-handler behavior." >&2
  exit 1
fi

swift_file="$(mktemp "${TMPDIR:-/tmp}/cuneiform-default-handler.XXXXXX.swift")"
trap 'rm -f "$swift_file"' EXIT
cat > "$swift_file" <<'SWIFT'
import CoreServices
import Foundation

let contentType = "net.daringfireball.markdown" as CFString
let handler = LSCopyDefaultRoleHandlerForContentType(contentType, .viewer)?
    .takeRetainedValue() as String?
print(handler ?? "")
SWIFT

default_handler="$(swift "$swift_file")"
if [[ "$default_handler" != "$EXPECTED_BUNDLE_ID" ]]; then
  echo "Default Markdown viewer mismatch. Expected $EXPECTED_BUNDLE_ID, got ${default_handler:-unset}." >&2
  exit 1
fi

echo "Default Markdown viewer verified: $default_handler at $APP"
```

- [ ] **Step 2: Run the script**

Run:

```bash
chmod +x scripts/verify_default_viewer.sh
scripts/verify_default_viewer.sh .build/app/Cuneiform.app
```

Expected: exits `0` only when `.build/app/Cuneiform.app` has bundle id `io.damao.cuneiform`, LaunchServices resolves that bundle id to this same bundle path, and the Markdown viewer role is set to `io.damao.cuneiform`; otherwise prints a clear diagnostic.

- [ ] **Step 3: Call the verification from the benchmark script**

Near the top of `scripts/measure_startup.sh`, after checking `.build/app/Cuneiform.app`, add:

```bash
"$ROOT/scripts/verify_default_viewer.sh" "$APP" >/dev/null
```

- [ ] **Step 4: Verify**

Run:

```bash
scripts/verify_default_viewer.sh
bash -n scripts/measure_startup.sh
```

Expected: both commands exit `0`.

- [ ] **Step 5: Commit**

```bash
git add scripts/verify_default_viewer.sh scripts/measure_startup.sh
git commit -m "test: verify measured Cuneiform bundle identity"
```

## Task 4: Duplicate Open Prevention

**Files:**
- Modify: `Sources/SimpleMarkdownPreviewerApp/AppDelegate.swift`
- Test: manual probe via `CUNEIFORM_STARTUP_PROBE=1`

- [ ] **Step 1: Add URL de-duplication state**

In `AppDelegate`, add:

```swift
private var openedURLs: Set<URL> = []
```

- [ ] **Step 2: Add a single open routing helper**

Add this helper to `AppDelegate`:

```swift
private func routeOpenURL(_ url: URL) {
    let standardizedURL = url.standardizedFileURL
    guard openedURLs.insert(standardizedURL).inserted else {
        return
    }

    if let openURLHandler {
        openURLHandler(standardizedURL)
    } else {
        pendingOpenURLs.append(standardizedURL)
    }
}
```

- [ ] **Step 3: Use the helper in `application(_:openFiles:)`**

Replace the loop body with:

```swift
for filename in filenames {
    routeOpenURL(URL(fileURLWithPath: filename))
}
sender.reply(toOpenOrPrint: .success)
```

- [ ] **Step 4: Use the helper for command-line file arguments**

Replace:

```swift
if let firstPath = CommandLine.arguments.dropFirst().first {
    appState.open(URL(fileURLWithPath: firstPath))
}
```

with:

```swift
if let firstPath = CommandLine.arguments.dropFirst().first {
    routeOpenURL(URL(fileURLWithPath: firstPath))
}
```

- [ ] **Step 5: Verify duplicate opens are gone**

Run the app once with the startup probe:

```bash
CUNEIFORM_STARTUP_PROBE=1 CUNEIFORM_STARTUP_PROBE_QUIT=1 \
  .build/app/Cuneiform.app/Contents/MacOS/Cuneiform README.md
```

Expected: the probe output contains only one `appState.open.begin` for `README.md`.

- [ ] **Step 6: Run tests and commit**

Run:

```bash
swift test
```

Expected: all tests pass.

Commit:

```bash
git add Sources/SimpleMarkdownPreviewerApp/AppDelegate.swift
git commit -m "fix: ignore duplicate startup open requests"
```

## Task 5: Conditional Syntax Highlighting and Asset Caching

**Files:**
- Modify: `Sources/SimpleMarkdownPreviewerCore/HTMLTemplate.swift`
- Modify: `Tests/SimpleMarkdownPreviewerCoreTests/HTMLTemplateTests.swift`

- [ ] **Step 1: Write the failing tests**

Add to `HTMLTemplateTests`:

```swift
@Test
func omitsSyntaxHighlightingForPlainDocuments() throws {
    let html = try HTMLTemplate().document(
        body: "<h1>Hello</h1>",
        title: "Doc",
        preferences: PreviewPreferences()
    )

    #expect(!html.contains("window.hljs"))
    #expect(!html.contains("highlightAll"))
}

@Test
func includesSyntaxHighlightingOnlyWhenCodeBlocksArePresent() throws {
    let html = try HTMLTemplate().document(
        body: "<pre><code class=\"language-swift\">let value = 1</code></pre>",
        title: "Doc",
        preferences: PreviewPreferences()
    )

    #expect(html.contains("window.hljs"))
    #expect(html.contains("highlightAll"))
}
```

- [ ] **Step 2: Run the tests to verify the plain-document test fails**

Run:

```bash
swift test --filter HTMLTemplateTests
```

Expected before implementation: `omitsSyntaxHighlightingForPlainDocuments` fails because `highlight.js` is always injected.

- [ ] **Step 3: Implement lazy syntax highlighting assets**

In `HTMLTemplate`, cache base CSS separately from syntax assets:

```swift
private struct SyntaxAssets {
    let highlightLightCSS: String
    let highlightDarkCSS: String
    let highlightJS: String
    let previewJS: String
}

private static let cachedPreviewCSS: Result<String, Error> = Result(catching: {
    try assetText("preview", extension: "css")
})

private static let cachedSyntaxAssets: Result<SyntaxAssets, Error> = Result(catching: {
    try SyntaxAssets(
        highlightLightCSS: assetText("highlight-github", extension: "css"),
        highlightDarkCSS: assetText("highlight-github-dark", extension: "css"),
        highlightJS: assetText("highlight.min", extension: "js"),
        previewJS: assetText("preview", extension: "js")
    )
})

private static func previewCSS() throws -> String {
    try cachedPreviewCSS.get()
}

private static func syntaxHighlightingMarkup(for body: String) throws -> String {
    guard body.contains("<pre><code") else { return "" }

    let assets = try cachedSyntaxAssets.get()
    return """
      <style>\(assets.highlightLightCSS)</style>
      <style>
      @media (prefers-color-scheme: dark) { \(assets.highlightDarkCSS) }
      body.theme-dark { \(assets.highlightDarkCSS) }
      body.theme-light { \(assets.highlightLightCSS) }
      </style>
      <script>\(assets.highlightJS)</script>
      <script>\(assets.previewJS)</script>
    """
}
```

Use `previewCSS()` and `syntaxHighlightingMarkup(for:)` inside `document(...)`.

- [ ] **Step 4: Verify**

Run:

```bash
swift test --filter HTMLTemplateTests
```

Expected: all `HTMLTemplateTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/SimpleMarkdownPreviewerCore/HTMLTemplate.swift Tests/SimpleMarkdownPreviewerCoreTests/HTMLTemplateTests.swift
git commit -m "fix: avoid loading syntax assets for plain documents"
```

## Task 6: Persistent WebView Prewarm Experiment

**Files:**
- Modify: `Sources/SimpleMarkdownPreviewerApp/ContentView.swift`
- Modify: `Sources/SimpleMarkdownPreviewerApp/PreviewWebView.swift`
- Modify: `Sources/SimpleMarkdownPreviewerApp/AppState.swift`

- [ ] **Step 1: Record the pre-change benchmark**

Run:

```bash
./scripts/build_app.sh
ITERATIONS=10 ./scripts/measure_startup.sh README.md
```

Expected: output includes TextEdit and Cuneiform `p50`/`p95`. Save the output in the task notes before changing WebView behavior.

- [ ] **Step 2: Add stable document payload accessors**

In `AppState.ViewState`, keep existing cases. Add computed properties to `AppState`:

```swift
var renderedDocument: (html: String, baseURL: URL)? {
    guard case let .rendered(_, html, baseURL) = viewState else {
        return nil
    }
    return (html, baseURL)
}

var errorMessage: String? {
    guard case let .error(message) = viewState else {
        return nil
    }
    return message
}
```

- [ ] **Step 3: Make `PreviewWebView` persistent**

Change `PreviewWebView` to accept optional content:

```swift
struct PreviewWebView: NSViewRepresentable {
    let html: String?
    let baseURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard let html, let baseURL else { return }
        guard context.coordinator.lastLoadedHTML != html else { return }
        context.coordinator.lastLoadedHTML = html
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastLoadedHTML: String?

        @MainActor
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated else {
                decisionHandler(.allow)
                return
            }

            if let url = navigationAction.request.url,
               ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
        }

        @MainActor
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard lastLoadedHTML != nil else { return }
            StartupProbe.finish("webview.didFinish")
        }
    }
}
```

- [ ] **Step 4: Keep the WebView mounted under placeholder overlays**

Update `ContentView.body` to always mount `PreviewWebView`:

```swift
var body: some View {
    ZStack {
        PreviewWebView(
            html: appState.renderedDocument?.html,
            baseURL: appState.renderedDocument?.baseURL
        )

        switch appState.viewState {
        case .empty:
            Text("打开或拖入 Markdown 文件")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
        case .rendered:
            EmptyView()
        case .error(let message):
            Text(message)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
        }
    }
    .frame(minWidth: 720, minHeight: 480)
    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }
            Task { @MainActor in
                appState.open(url)
            }
        }
        return true
    }
}
```

- [ ] **Step 5: Verify functional behavior**

Run:

```bash
swift test
./scripts/build_app.sh
```

Expected: tests pass and `.build/app/Cuneiform.app` builds.

- [ ] **Step 6: Benchmark the experiment**

Run:

```bash
ITERATIONS=10 ./scripts/measure_startup.sh README.md
```

Expected: Cuneiform `p50 <= 550ms`. Compare against the pre-change benchmark from Step 1. Keep the change only if `p50` or `p95` improves without visual regressions.

- [ ] **Step 7: Commit or revert based on the data**

If the benchmark improves:

```bash
git add Sources/SimpleMarkdownPreviewerApp
git commit -m "fix: prewarm preview web view on startup"
```

If the benchmark does not improve:

```bash
git restore Sources/SimpleMarkdownPreviewerApp/ContentView.swift \
  Sources/SimpleMarkdownPreviewerApp/PreviewWebView.swift \
  Sources/SimpleMarkdownPreviewerApp/AppState.swift
```

## Task 7: Final Startup Gate and Full Verification

**Files:**
- Modify: `README.md` if user-facing performance notes are needed
- Existing verification scripts only otherwise

- [ ] **Step 1: Run the startup benchmark**

Run:

```bash
./scripts/build_app.sh
ITERATIONS=10 ./scripts/measure_startup.sh README.md
```

Expected:

```text
TextEdit: count=10 ... p50=<number>ms p95=<number>ms ...
Cuneiform external: count=10 ... p50=<number>ms p95=<number>ms ...
Cuneiform app-internal: count=10 ... p50=<number>ms p95=<number>ms ...
```

Acceptance:

```text
Cuneiform external p50 <= 550ms
Cuneiform external p50 <= TextEdit p50 * 1.15
```

- [ ] **Step 2: Run full project verification**

Run:

```bash
./scripts/check.sh
```

Expected: Swift tests, Swift build, app bundle verification, and DMG packaging checks all pass.

- [ ] **Step 3: Simplify pass**

Review:

```bash
git diff --stat
git diff -- Sources scripts Tests README.md
```

Remove:

- probe code paths that run without `CUNEIFORM_STARTUP_PROBE=1`;
- measurement output committed to the repo;
- unrelated formatting churn;
- unused helpers introduced during the WebView experiment.

- [ ] **Step 4: Request pre-commit review**

Use `superpowers:requesting-code-review` before committing final implementation changes.

- [ ] **Step 5: Commit final measurement and verification updates**

```bash
git add .
git commit -m "test: add Cuneiform startup performance gate"
```

## Plan Self-Review

- Spec coverage: The plan covers the stated goal, measurement reproducibility, release bundle correctness, duplicate open prevention, WebView prewarm, and final acceptance.
- Placeholder scan: No `TBD`, `TODO`, or unspecified implementation steps remain.
- Type consistency: `StartupProbe`, `AppState.renderedDocument`, `PreviewWebView(html:baseURL:)`, and shell script names are used consistently across tasks.
- Scope check: Native renderer or background resident architecture is intentionally out of scope. Those are fallback product decisions if TextEdit-class cold launch cannot be held after this plan.
