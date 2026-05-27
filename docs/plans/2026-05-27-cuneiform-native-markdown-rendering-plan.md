# Cuneiform Native Markdown Rendering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Cuneiform's first visible document path with a native Markdown renderer so opening a Markdown file is not gated on `WKWebView` startup.

**Architecture:** Keep the existing file intake and measurement harness, but split preview rendering into explicit renderer modes: current WebView HTML rendering and a MarkdownUI native rendering spike. MarkdownUI becomes the default only if the measured LaunchServices p50 for the user's real file is `<= 550ms` and no slower than TextEdit by more than 15% in the same run.

**Tech Stack:** Swift 6, SwiftPM, SwiftUI, AppKit, MarkdownUI 2.4.1, existing `swift-markdown` 0.8.0 fallback path, existing startup probe and shell measurement scripts.

---

## Version History

| Date | Version | Notes |
| --- | --- | --- |
| 2026-05-28 | 0.2 | Recorded benchmark outcome: keep MarkdownUI opt-in, keep WebView as default, and open TextKit follow-up plan. |
| 2026-05-27 | 0.1 | Initial native Markdown rendering plan, focused on MarkdownUI spike and measured default switch. |

## Baseline Evidence

Use this evidence from the current app before implementation:

- User file: `/Users/damao/Documents/Knowledge/10-sources/2026-04-19-github-Fincept-Corporation-FinceptTerminal.md`
- File size: `5,534` bytes, `56` lines.
- File content has no fenced code blocks and no Markdown images.
- Current default-open Cuneiform external p50: `564.80ms`.
- Current default-open Cuneiform app-internal p50: `426.27ms`.
- Single-run stage data shows file loading, Markdown parse, and template generation complete in about `1.4ms`.
- The remaining critical path is app startup plus first preview surface creation, especially `WKWebView` first document display.

## Scope

This plan tests and, if justified by measurements, adopts MarkdownUI as Cuneiform's default first-render path. It does not implement a custom `NSTextView`/TextKit renderer in the same change set. If MarkdownUI misses the performance gate, remove the spike dependency and write a follow-up TextKit plan using the same measurement contract.

## File Structure

Modify or create these files:

```text
Package.swift
Sources/SimpleMarkdownPreviewerApp/AppState.swift
Sources/SimpleMarkdownPreviewerApp/ContentView.swift
Sources/SimpleMarkdownPreviewerApp/NativeMarkdownPreview.swift
Sources/SimpleMarkdownPreviewerApp/PreviewRendererMode.swift
Sources/SimpleMarkdownPreviewerApp/PreviewWebView.swift
Tests/ScriptTests/test_native_markdown_renderer_contract.sh
scripts/check.sh
scripts/measure_startup.sh
```

Responsibility map:

- `PreviewRendererMode.swift`: resolves renderer mode from environment. Supported values are `native`, `webview`, and unset default.
- `NativeMarkdownPreview.swift`: SwiftUI wrapper around MarkdownUI. It owns only visual rendering and probe completion for native preview.
- `ContentView.swift`: chooses the preview implementation based on `PreviewRendererMode`.
- `AppState.swift`: keeps the loaded Markdown source in view state so native rendering does not require HTML generation.
- `PreviewWebView.swift`: remains the fallback WebView implementation.
- `scripts/measure_startup.sh`: can run one renderer mode per benchmark and labels the result clearly.
- `test_native_markdown_renderer_contract.sh`: static guardrail so the spike cannot silently fall back to WebView or lose the measurement mode.

## Measurement Contract

Run all measurements against the installed app bundle opened through LaunchServices:

```bash
CUNEIFORM_APP=/Applications/Cuneiform.app ITERATIONS=10 ./scripts/measure_startup.sh /Users/damao/Documents/Knowledge/10-sources/2026-04-19-github-Fincept-Corporation-FinceptTerminal.md
```

The benchmark script must report all three rows:

```text
TextEdit: count=10 ...
Cuneiform external: count=10 ...
Cuneiform app-internal: count=10 ...
```

Acceptance gate for switching default renderer:

- Cuneiform native external p50 is `<= 550ms`.
- Cuneiform native external p50 is within 15% of TextEdit p50 in the same script run.
- Cuneiform native app-internal p50 is lower than current WebView app-internal p50 for the same file.
- The app displays headings, paragraphs, links, inline code, lists, block quotes, and code blocks in the smoke document without crashing.

## Task 1: Add Native Renderer Contract Guardrail

**Files:**

- Create: `Tests/ScriptTests/test_native_markdown_renderer_contract.sh`

- [ ] **Step 1: Write the failing script test**

Create `Tests/ScriptTests/test_native_markdown_renderer_contract.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

bash -n scripts/measure_startup.sh

grep -F 'CUNEIFORM_RENDERER' scripts/measure_startup.sh >/dev/null
grep -F 'native.contentReady' Sources/SimpleMarkdownPreviewerApp/NativeMarkdownPreview.swift >/dev/null
grep -F 'PreviewRendererMode' Sources/SimpleMarkdownPreviewerApp/ContentView.swift >/dev/null
grep -F '.product(name: "MarkdownUI", package: "swift-markdown-ui")' Package.swift >/dev/null
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
chmod +x Tests/ScriptTests/test_native_markdown_renderer_contract.sh
Tests/ScriptTests/test_native_markdown_renderer_contract.sh
```

Expected: FAIL because `NativeMarkdownPreview.swift`, `PreviewRendererMode`, and the MarkdownUI dependency do not exist yet.

- [ ] **Step 3: Keep the failing guardrail uncommitted**

Do not commit this test while it is failing. Leave it in the working tree so later tasks can make it pass and commit it with the implementation.

## Task 2: Add MarkdownUI as a Measured Spike Dependency

**Files:**

- Modify: `Package.swift`
- Modify: `Package.resolved`

- [ ] **Step 1: Add MarkdownUI dependency**

In `Package.swift`, update dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/swiftlang/swift-markdown.git", exact: "0.8.0"),
    .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", exact: "2.4.1")
],
```

Update the executable target dependencies:

```swift
.executableTarget(
    name: "SimpleMarkdownPreviewerApp",
    dependencies: [
        "SimpleMarkdownPreviewerCore",
        .product(name: "MarkdownUI", package: "swift-markdown-ui")
    ]
),
```

- [ ] **Step 2: Resolve packages**

Run:

```bash
swift package resolve
```

Expected: resolves `swift-markdown-ui` at `2.4.1` and updates `Package.resolved`.

- [ ] **Step 3: Verify the contract is still failing for missing app code**

Run:

```bash
Tests/ScriptTests/test_native_markdown_renderer_contract.sh
```

Expected: FAIL because `NativeMarkdownPreview.swift` and `PreviewRendererMode` are still missing.

- [ ] **Step 4: Commit the dependency spike**

```bash
git add Package.swift Package.resolved
git commit -m "chore: add MarkdownUI spike dependency"
```

## Task 3: Add Renderer Mode Selection

**Files:**

- Create: `Sources/SimpleMarkdownPreviewerApp/PreviewRendererMode.swift`
- Modify: `Sources/SimpleMarkdownPreviewerApp/ContentView.swift`

- [ ] **Step 1: Create renderer mode resolver**

Create `Sources/SimpleMarkdownPreviewerApp/PreviewRendererMode.swift`:

```swift
import Foundation

enum PreviewRendererMode: Equatable {
    case native
    case webview

    static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> PreviewRendererMode {
        switch environment["CUNEIFORM_RENDERER"]?.lowercased() {
        case "webview":
            return .webview
        case "native":
            return .native
        default:
            return .native
        }
    }
}
```

- [ ] **Step 2: Add renderer mode dependency to ContentView**

Change the start of `ContentView` to:

```swift
struct ContentView: View {
    @Bindable var appState: AppState
    var rendererMode: PreviewRendererMode = .current()
```

In the `.rendered` branch, use `rendererMode` to choose the view. The native view is added in Task 5, so temporarily keep WebView in both cases:

```swift
case .rendered(_, let html, let baseURL):
    switch rendererMode {
    case .native, .webview:
        PreviewWebView(html: html, baseURL: baseURL)
    }
```

- [ ] **Step 3: Verify the app still builds**

Run:

```bash
swift build
```

Expected: PASS.

- [ ] **Step 4: Commit renderer mode selection**

```bash
git add Sources/SimpleMarkdownPreviewerApp/PreviewRendererMode.swift Sources/SimpleMarkdownPreviewerApp/ContentView.swift
git commit -m "feat: add preview renderer mode"
```

## Task 4: Keep Markdown Source in View State

**Files:**

- Modify: `Sources/SimpleMarkdownPreviewerApp/AppState.swift`
- Modify: `Sources/SimpleMarkdownPreviewerApp/ContentView.swift`

- [ ] **Step 1: Extend rendered view state**

In `AppState.ViewState`, replace:

```swift
case rendered(title: String, html: String, baseURL: URL)
```

with:

```swift
case rendered(title: String, source: String, html: String, baseURL: URL)
```

- [ ] **Step 2: Store source with rendered state**

In `renderCurrentDocument()`, replace the rendered assignment with:

```swift
viewState = .rendered(
    title: document.url.lastPathComponent,
    source: document.source,
    html: html,
    baseURL: document.url.deletingLastPathComponent()
)
```

- [ ] **Step 3: Update ContentView pattern match**

In `ContentView`, update the rendered branch:

```swift
case .rendered(_, let source, let html, let baseURL):
    switch rendererMode {
    case .native, .webview:
        PreviewWebView(html: html, baseURL: baseURL)
    }
```

The local variable `source` is intentionally unused until Task 5. If Swift warns, use `_` until Task 5:

```swift
case .rendered(_, _, let html, let baseURL):
```

- [ ] **Step 4: Run focused tests and build**

Run:

```bash
swift test
swift build
```

Expected: PASS.

- [ ] **Step 5: Commit source retention**

```bash
git add Sources/SimpleMarkdownPreviewerApp/AppState.swift Sources/SimpleMarkdownPreviewerApp/ContentView.swift
git commit -m "feat: keep markdown source for native preview"
```

## Task 5: Add MarkdownUI Native Preview

**Files:**

- Create: `Sources/SimpleMarkdownPreviewerApp/NativeMarkdownPreview.swift`
- Modify: `Sources/SimpleMarkdownPreviewerApp/ContentView.swift`

- [ ] **Step 1: Create the native preview view**

Create `Sources/SimpleMarkdownPreviewerApp/NativeMarkdownPreview.swift`:

```swift
import MarkdownUI
import SwiftUI

struct NativeMarkdownPreview: View {
    let markdown: String
    let baseURL: URL

    var body: some View {
        ScrollView {
            Markdown(
                markdown,
                baseURL: baseURL,
                imageBaseURL: baseURL
            )
            .markdownTheme(.gitHub)
            .textSelection(.enabled)
            .frame(maxWidth: 820, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .onAppear {
                DispatchQueue.main.async {
                    StartupProbe.finish("native.contentReady")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
```

- [ ] **Step 2: Route native mode to MarkdownUI**

In `ContentView`, update the rendered branch:

```swift
case .rendered(_, let source, let html, let baseURL):
    switch rendererMode {
    case .native:
        NativeMarkdownPreview(markdown: source, baseURL: baseURL)
    case .webview:
        PreviewWebView(html: html, baseURL: baseURL)
    }
```

- [ ] **Step 3: Run build and tests**

Run:

```bash
swift test
swift build
```

Expected: PASS.

- [ ] **Step 4: Commit native preview**

```bash
git add Sources/SimpleMarkdownPreviewerApp/NativeMarkdownPreview.swift Sources/SimpleMarkdownPreviewerApp/ContentView.swift
git commit -m "feat: add MarkdownUI native preview"
```

## Task 6: Teach the Startup Harness About Renderer Modes

**Files:**

- Modify: `scripts/measure_startup.sh`
- Modify: `scripts/check.sh`
- Create: `Tests/ScriptTests/test_native_markdown_renderer_contract.sh`

- [ ] **Step 1: Add renderer mode to the probe environment**

In `measure_cuneiform_once()`, after setting startup probe env vars, add:

```bash
if [[ -n "${CUNEIFORM_RENDERER:-}" ]]; then
  launchctl setenv CUNEIFORM_RENDERER "$CUNEIFORM_RENDERER"
fi
```

In `cleanup_probe_env()`, add:

```bash
launchctl unsetenv CUNEIFORM_RENDERER >/dev/null 2>&1 || true
```

- [ ] **Step 2: Accept either WebView or native content-ready labels**

Replace `wait_for_probe_finish()` with:

```bash
wait_for_probe_finish() {
  local log="$1"
  for _ in $(seq 1 1000); do
    if awk '/webview.contentReady|native.contentReady/ { found=1 } END { exit found ? 0 : 1 }' "$log"; then
      return 0
    fi
    sleep 0.01
  done
  return 1
}
```

Replace `probe_internal_time()` with:

```bash
probe_internal_time() {
  local log="$1"
  awk '/webview.contentReady|native.contentReady/ { value=$2 } END { sub(/ms$/, "", value); print value }' "$log"
}
```

- [ ] **Step 3: Label the selected renderer in output**

Before the final summaries, add:

```bash
echo "Cuneiform renderer: ${CUNEIFORM_RENDERER:-native}"
```

Outcome note: this default label was later changed to `webview` after Task 7 showed MarkdownUI should remain opt-in.

- [ ] **Step 4: Add the guardrail to the full check script**

In `scripts/check.sh`, add this line next to the existing script contract tests:

```bash
Tests/ScriptTests/test_native_markdown_renderer_contract.sh
```

- [ ] **Step 5: Verify script contract**

Run:

```bash
Tests/ScriptTests/test_native_markdown_renderer_contract.sh
Tests/ScriptTests/test_startup_measure_script.sh
```

Expected: both PASS.

- [ ] **Step 6: Commit measurement support**

```bash
git add scripts/measure_startup.sh scripts/check.sh Tests/ScriptTests/test_native_markdown_renderer_contract.sh
git commit -m "test: measure native renderer startup"
```

## Task 7: Measure MarkdownUI Against WebView and TextEdit

**Files:**

- No planned file edits. This task records benchmark evidence and decides whether to continue to Task 8 or Task 9.

- [ ] **Step 1: Run full verification before measurement**

Run:

```bash
./scripts/check.sh
```

Expected: PASS.

- [ ] **Step 2: Install the checked app bundle for LaunchServices testing**

Run:

```bash
ditto .build/app/Cuneiform.app /Applications/Cuneiform.app
scripts/verify_default_viewer.sh /Applications/Cuneiform.app
```

Expected: default Markdown viewer resolves to `/Applications/Cuneiform.app`.

- [ ] **Step 3: Measure native renderer**

Run:

```bash
CUNEIFORM_RENDERER=native CUNEIFORM_APP=/Applications/Cuneiform.app ITERATIONS=10 ./scripts/measure_startup.sh /Users/damao/Documents/Knowledge/10-sources/2026-04-19-github-Fincept-Corporation-FinceptTerminal.md
```

Expected: script prints TextEdit, Cuneiform external, and Cuneiform app-internal summaries.

- [ ] **Step 4: Measure WebView fallback**

Run:

```bash
CUNEIFORM_RENDERER=webview CUNEIFORM_APP=/Applications/Cuneiform.app ITERATIONS=10 ./scripts/measure_startup.sh /Users/damao/Documents/Knowledge/10-sources/2026-04-19-github-Fincept-Corporation-FinceptTerminal.md
```

Expected: script prints comparable summaries for the fallback renderer.

- [ ] **Step 5: Decide default**

Use this decision table:

| Result | Action |
| --- | --- |
| Native p50 `<= 550ms` and within 15% of TextEdit | Keep MarkdownUI and continue to Task 8. |
| Native beats WebView internally but misses the default-switch gate | Keep the spike behind `CUNEIFORM_RENDERER=native`, do not switch default, and write a TextKit follow-up plan. |
| Native is not faster than WebView internally | Remove MarkdownUI changes in a new cleanup commit and write a TextKit follow-up plan. |

Do not claim the renderer switch is successful without saving the benchmark output in the implementation notes or final response.

### Task 7 Outcome

Benchmark output from the checked `/Applications/Cuneiform.app` bundle:

- Native run:
  - TextEdit: count=10 min=109.61ms p50=123.73ms p95=143.91ms max=143.91ms
  - Cuneiform external: count=10 min=321.52ms p50=331.71ms p95=613.19ms max=613.19ms
  - Cuneiform app-internal: count=10 min=213.35ms p50=220.87ms p95=226.54ms max=226.54ms
- WebView run:
  - TextEdit: count=10 min=112.59ms p50=124.44ms p95=134.86ms max=134.86ms
  - Cuneiform external: count=10 min=439.79ms p50=454.14ms p95=513.78ms max=513.78ms
  - Cuneiform app-internal: count=10 min=330.03ms p50=340.51ms p95=395.02ms max=395.02ms

TextEdit window detection used the process-visible lower-bound fallback. Native meets the `<= 550ms` external p50 gate and beats WebView internally, but it does not come within 15% of TextEdit in the same run. The implemented decision is:

- Keep MarkdownUI available behind `CUNEIFORM_RENDERER=native`.
- Keep unset and unknown renderer modes on WebView.
- Do not execute Task 8.
- Do not execute Task 9 because native is faster than WebView internally.
- Continue with `docs/plans/2026-05-28-cuneiform-textkit-rendering-follow-up-plan.md`.

## Task 8: Make Native the Default Renderer if the Gate Passes

Outcome note: Task 8 was not executed. Task 7 showed MarkdownUI did not pass the default-switch gate, so unset and unknown renderer modes now remain on WebView.

**Files:**

- Modify: `Sources/SimpleMarkdownPreviewerApp/PreviewRendererMode.swift`
- Modify: `README.md`

- [ ] **Step 1: Confirm native is already the unset default**

Verify `PreviewRendererMode.current()` returns `.native` when `CUNEIFORM_RENDERER` is unset:

```swift
default:
    return .native
```

- [ ] **Step 2: Document the fallback environment switch**

Add this short troubleshooting note to `README.md`:

````markdown
### Renderer fallback

Cuneiform uses the native Markdown renderer by default. To compare or debug the legacy WebView renderer from Terminal:

```bash
CUNEIFORM_RENDERER=webview /Applications/Cuneiform.app/Contents/MacOS/Cuneiform path/to/file.md
```
````

- [ ] **Step 3: Run full verification**

Run:

```bash
./scripts/check.sh
```

Expected: PASS.

- [ ] **Step 4: Commit default renderer documentation**

```bash
git add Sources/SimpleMarkdownPreviewerApp/PreviewRendererMode.swift README.md
git commit -m "doc: document native renderer fallback"
```

## Task 9: Cleanup if MarkdownUI Misses the Gate

**Files:**

- Modify: `Package.swift`
- Modify: `Package.resolved`
- Delete: `Sources/SimpleMarkdownPreviewerApp/NativeMarkdownPreview.swift`
- Delete: `Sources/SimpleMarkdownPreviewerApp/PreviewRendererMode.swift`
- Modify: `Sources/SimpleMarkdownPreviewerApp/AppState.swift`
- Modify: `Sources/SimpleMarkdownPreviewerApp/ContentView.swift`
- Modify: `scripts/measure_startup.sh`
- Modify: `scripts/check.sh`
- Delete: `Tests/ScriptTests/test_native_markdown_renderer_contract.sh`

- [ ] **Step 1: Remove MarkdownUI spike code**

Undo the native-renderer files and restore `ContentView` to direct WebView rendering:

```swift
case .rendered(_, let html, let baseURL):
    PreviewWebView(html: html, baseURL: baseURL)
```

Restore `AppState.ViewState`:

```swift
case rendered(title: String, html: String, baseURL: URL)
```

- [ ] **Step 2: Remove MarkdownUI dependency**

Remove this dependency from `Package.swift`:

```swift
.package(url: "https://github.com/gonzalezreal/swift-markdown-ui", exact: "2.4.1")
```

Remove this executable target dependency:

```swift
.product(name: "MarkdownUI", package: "swift-markdown-ui")
```

Run:

```bash
swift package resolve
```

- [ ] **Step 3: Remove native measurement additions**

Remove `CUNEIFORM_RENDERER` handling and `native.contentReady` matching from `scripts/measure_startup.sh`.

Remove this line from `scripts/check.sh`:

```bash
Tests/ScriptTests/test_native_markdown_renderer_contract.sh
```

- [ ] **Step 4: Run full verification**

Run:

```bash
./scripts/check.sh
```

Expected: PASS.

- [ ] **Step 5: Commit cleanup**

```bash
git add Package.swift Package.resolved Sources/SimpleMarkdownPreviewerApp/AppState.swift Sources/SimpleMarkdownPreviewerApp/ContentView.swift scripts/measure_startup.sh scripts/check.sh
git rm Sources/SimpleMarkdownPreviewerApp/NativeMarkdownPreview.swift Sources/SimpleMarkdownPreviewerApp/PreviewRendererMode.swift Tests/ScriptTests/test_native_markdown_renderer_contract.sh
git commit -m "chore: remove unsuccessful MarkdownUI spike"
```

## Verification Checklist

Before declaring the plan implemented:

- [ ] `swift test` passes.
- [ ] `swift build` passes.
- [ ] `./scripts/check.sh` passes.
- [ ] `/Applications/Cuneiform.app` matches the checked release app bundle used for measurement.
- [ ] `scripts/verify_default_viewer.sh /Applications/Cuneiform.app` passes.
- [ ] Native renderer measurement is run with the user's real file.
- [ ] WebView fallback measurement is run with the same file.
- [ ] Final response reports TextEdit p50, Cuneiform native p50, Cuneiform WebView p50, and whether native passed the default-switch gate.

## Known Risks

- MarkdownUI is in maintenance mode. This plan treats it as a measured spike, not a permanent architectural commitment without data.
- SwiftUI native rendering may still be slower than TextKit for long documents. If the spike misses the gate, the next plan should target `swift-markdown` AST to `NSTextView`/TextKit.
- `onAppear` is an approximate content-ready probe for SwiftUI. If native results are close to the gate, add a visual screenshot or Accessibility-based confirmation before making release claims.
- MarkdownUI visual output will not exactly match the current GitHub CSS from the WebView renderer. Performance is the priority for this plan.
