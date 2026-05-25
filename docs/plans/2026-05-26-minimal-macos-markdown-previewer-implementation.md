# Minimal macOS Markdown Previewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native, read-only macOS app that opens `.md` and `.markdown` files and shows only the rendered Markdown content.

**Architecture:** Use a Swift Package as the buildable core plus a generated `.app` bundle for Finder/default-app integration. SwiftUI owns the app shell and menus, AppKit handles file open/drop details, `WKWebView` displays a sanitized HTML document, and pure Swift services handle file intake, Markdown rendering, resource policy, and preferences.

**Tech Stack:** Swift 6.3, SwiftPM, SwiftUI, AppKit, WebKit, `swift-markdown` 0.8.0, app-bundled `highlight.js` 11.11.1 assets, XCTest, shell scripts for app bundling and verification.

---

## Verified Dependency Choices

- Markdown parser: `swiftlang/swift-markdown` 0.8.0. The official repository states the parser is powered by GitHub-flavored Markdown's `cmark-gfm`, and the latest visible release is `Swift-Markdown 0.8.0` on 2026-05-07.
- Syntax highlighting: app-bundled `highlight.js` 11.11.1. The official releases page lists `v11.11.1` as latest, and `highlight.js` supports browser/server use with no framework dependency.
- Rejected option: `raspu/Highlightr`. Its own README now states it is no longer actively maintained as of 2026, so it should not be the MVP dependency.

Source links:

- <https://github.com/swiftlang/swift-markdown>
- <https://github.com/highlightjs/highlight.js/releases>
- <https://github.com/raspu/Highlightr>

## File Structure

Create this structure:

```text
Package.swift
Sources/SimpleMarkdownPreviewerApp/main.swift
Sources/SimpleMarkdownPreviewerApp/AppDelegate.swift
Sources/SimpleMarkdownPreviewerApp/AppState.swift
Sources/SimpleMarkdownPreviewerApp/ContentView.swift
Sources/SimpleMarkdownPreviewerApp/PreviewWebView.swift
Sources/SimpleMarkdownPreviewerCore/FileIntake.swift
Sources/SimpleMarkdownPreviewerCore/MarkdownHTMLRenderer.swift
Sources/SimpleMarkdownPreviewerCore/ResourcePolicy.swift
Sources/SimpleMarkdownPreviewerCore/HTMLTemplate.swift
Sources/SimpleMarkdownPreviewerCore/Preferences.swift
Sources/SimpleMarkdownPreviewerCore/PreviewError.swift
Sources/SimpleMarkdownPreviewerCore/Assets/preview.css
Sources/SimpleMarkdownPreviewerCore/Assets/preview.js
Sources/SimpleMarkdownPreviewerCore/Assets/highlight.min.js
Sources/SimpleMarkdownPreviewerCore/Assets/highlight-github.css
Sources/SimpleMarkdownPreviewerCore/Assets/highlight-github-dark.css
Sources/SimpleMarkdownPreviewerCore/Assets/.gitkeep
Tests/SimpleMarkdownPreviewerCoreTests/FileIntakeTests.swift
Tests/SimpleMarkdownPreviewerCoreTests/MarkdownHTMLRendererTests.swift
Tests/SimpleMarkdownPreviewerCoreTests/ResourcePolicyTests.swift
Tests/SimpleMarkdownPreviewerCoreTests/HTMLTemplateTests.swift
Fixtures/Markdown/sample.md
Fixtures/Markdown/assets/local.png
Resources/Info.plist
scripts/build_app.sh
scripts/check.sh
scripts/verify_bundle.sh
```

Responsibility map:

- `SimpleMarkdownPreviewerApp`: macOS lifecycle, menu commands, drag-and-drop, `WKWebView` bridge, and app state.
- `SimpleMarkdownPreviewerCore`: testable file intake, security policy, HTML rendering, CSS/HTML template, and preferences.
- `Resources/Info.plist`: app bundle metadata and document type declarations for `.md` and `.markdown`.
- `scripts`: repeatable build, bundle, and verification commands.

## Task 1: SwiftPM Skeleton and Verification Scripts

**Files:**
- Create: `Package.swift`
- Create: `Sources/SimpleMarkdownPreviewerCore/PreviewError.swift`
- Create: `Sources/SimpleMarkdownPreviewerCore/Assets/.gitkeep`
- Create: `Sources/SimpleMarkdownPreviewerApp/main.swift`
- Create: `scripts/check.sh`
- Create: `scripts/build_app.sh`
- Create: `scripts/verify_bundle.sh`
- Test: command-level verification

- [ ] **Step 1: Create the package manifest**

Add `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SimpleMarkdownPreviewer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SimpleMarkdownPreviewer", targets: ["SimpleMarkdownPreviewerApp"]),
        .library(name: "SimpleMarkdownPreviewerCore", targets: ["SimpleMarkdownPreviewerCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", exact: "0.8.0")
    ],
    targets: [
        .target(
            name: "SimpleMarkdownPreviewerCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            resources: [
                .process("Assets")
            ]
        ),
        .executableTarget(
            name: "SimpleMarkdownPreviewerApp",
            dependencies: ["SimpleMarkdownPreviewerCore"]
        ),
        .testTarget(
            name: "SimpleMarkdownPreviewerCoreTests",
            dependencies: ["SimpleMarkdownPreviewerCore"]
        )
    ]
)
```

- [ ] **Step 2: Add the first compile target**

Add `Sources/SimpleMarkdownPreviewerCore/PreviewError.swift`:

```swift
import Foundation

public enum PreviewError: Error, Equatable, LocalizedError {
    case unsupportedFileType(String)
    case unreadableFile(URL)
    case unsafeResource(String)
    case renderFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let ext):
            return "Unsupported file type: \(ext)"
        case .unreadableFile:
            return "The file could not be read."
        case .unsafeResource(let reason):
            return "Blocked unsafe resource: \(reason)"
        case .renderFailed(let reason):
            return "Markdown rendering failed: \(reason)"
        }
    }
}
```

Add an empty resource placeholder so SwiftPM can process the target resource directory before real assets are added:

```bash
mkdir -p Sources/SimpleMarkdownPreviewerCore/Assets
touch Sources/SimpleMarkdownPreviewerCore/Assets/.gitkeep
```

Add `Sources/SimpleMarkdownPreviewerApp/main.swift`:

```swift
import SwiftUI

@main
struct SimpleMarkdownPreviewerApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Open or drop a Markdown file")
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
```

- [ ] **Step 3: Add verification scripts**

Add `scripts/check.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

swift test
swift build
if [[ -f Resources/Info.plist ]]; then
  ./scripts/build_app.sh
  ./scripts/verify_bundle.sh
fi
```

Add `scripts/build_app.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_DIR=".build/app/SimpleMarkdownPreviewer.app"
EXECUTABLE=".build/debug/SimpleMarkdownPreviewer"

swift build
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/SimpleMarkdownPreviewer"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
find .build/debug -maxdepth 1 -name "*SimpleMarkdownPreviewerCore*.resources" -exec cp -R {} "$APP_DIR/Contents/Resources/" \;
```

Add `scripts/verify_bundle.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

INFO=".build/app/SimpleMarkdownPreviewer.app/Contents/Info.plist"
APP=".build/app/SimpleMarkdownPreviewer.app"
test -f "$INFO"
test -x "$APP/Contents/MacOS/SimpleMarkdownPreviewer"
find "$APP/Contents/Resources" -name "preview.css" -print -quit | grep -q "preview.css"
/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0:CFBundleTypeExtensions:0" "$INFO" | grep -qx "md"
/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0:CFBundleTypeExtensions:1" "$INFO" | grep -qx "markdown"
```

- [ ] **Step 4: Make scripts executable and run the first check**

Run:

```bash
chmod +x scripts/check.sh scripts/build_app.sh scripts/verify_bundle.sh
swift test
```

Expected: `swift test` passes with zero tests or discovered tests once test files exist.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources scripts
git commit -m "chore(project): scaffold Swift package"
```

## Task 2: Bundle Metadata and Document Type Declarations

**Files:**
- Create: `Resources/Info.plist`
- Modify: `scripts/build_app.sh`
- Test: `scripts/verify_bundle.sh`

- [ ] **Step 1: Add failing bundle verification**

Run:

```bash
./scripts/build_app.sh
./scripts/verify_bundle.sh
```

Expected: FAIL because `Resources/Info.plist` does not exist.

- [ ] **Step 2: Add app bundle metadata**

Add `Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>SimpleMarkdownPreviewer</string>
    <key>CFBundleIdentifier</key>
    <string>com.damao.SimpleMarkdownPreviewer</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>SimpleMarkdownPreviewer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Markdown Document</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>md</string>
                <string>markdown</string>
            </array>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
        </dict>
    </array>
</dict>
</plist>
```

- [ ] **Step 3: Verify bundle metadata**

Run:

```bash
./scripts/build_app.sh
./scripts/verify_bundle.sh
```

Expected: PASS and both document extensions print successfully through `PlistBuddy`.

- [ ] **Step 4: Commit**

```bash
git add Resources/Info.plist scripts/build_app.sh scripts/verify_bundle.sh
git commit -m "chore(bundle): declare markdown document types"
```

## Task 3: File Intake

**Files:**
- Create: `Sources/SimpleMarkdownPreviewerCore/FileIntake.swift`
- Create: `Tests/SimpleMarkdownPreviewerCoreTests/FileIntakeTests.swift`

- [ ] **Step 1: Write failing tests**

Add `Tests/SimpleMarkdownPreviewerCoreTests/FileIntakeTests.swift`:

```swift
import Foundation
import Testing
@testable import SimpleMarkdownPreviewerCore

@Suite
struct FileIntakeTests {
    @Test
    func acceptsMarkdownExtensionsCaseInsensitively() throws {
        #expect(FileIntake.isSupportedMarkdownFile(URL(fileURLWithPath: "/tmp/a.md")))
        #expect(FileIntake.isSupportedMarkdownFile(URL(fileURLWithPath: "/tmp/a.MARKDOWN")))
        #expect(!FileIntake.isSupportedMarkdownFile(URL(fileURLWithPath: "/tmp/a.txt")))
    }

    @Test
    func readsUTF8MarkdownFile() throws {
        let directory = try #require(FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first)
        let file = directory.appendingPathComponent("sample.md")
        try "# Title".write(to: file, atomically: true, encoding: .utf8)

        let intake = FileIntake()
        let document = try intake.loadMarkdownFile(at: file)

        #expect(document.url == file)
        #expect(document.source == "# Title")
    }

    @Test
    func rejectsUnsupportedFiles() throws {
        let intake = FileIntake()
        let file = URL(fileURLWithPath: "/tmp/sample.txt")

        #expect(throws: PreviewError.unsupportedFileType("txt")) {
            _ = try intake.loadMarkdownFile(at: file)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter FileIntakeTests
```

Expected: FAIL because `FileIntake` and `MarkdownDocument` do not exist.

- [ ] **Step 3: Implement minimal file intake**

Add `Sources/SimpleMarkdownPreviewerCore/FileIntake.swift`:

```swift
import Foundation

public struct MarkdownDocument: Equatable {
    public let url: URL
    public let source: String

    public init(url: URL, source: String) {
        self.url = url
        self.source = source
    }
}

public struct FileIntake {
    public init() {}

    public static func isSupportedMarkdownFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "md" || ext == "markdown"
    }

    public func loadMarkdownFile(at url: URL) throws -> MarkdownDocument {
        guard Self.isSupportedMarkdownFile(url) else {
            throw PreviewError.unsupportedFileType(url.pathExtension.lowercased())
        }

        do {
            let source = try String(contentsOf: url, encoding: .utf8)
            return MarkdownDocument(url: url, source: source)
        } catch {
            throw PreviewError.unreadableFile(url)
        }
    }
}
```

- [ ] **Step 4: Verify tests pass**

Run:

```bash
swift test --filter FileIntakeTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SimpleMarkdownPreviewerCore/FileIntake.swift Tests/SimpleMarkdownPreviewerCoreTests/FileIntakeTests.swift
git commit -m "feat(core): add markdown file intake"
```

## Task 4: Resource and Link Security Policy

**Files:**
- Create: `Sources/SimpleMarkdownPreviewerCore/ResourcePolicy.swift`
- Create: `Tests/SimpleMarkdownPreviewerCoreTests/ResourcePolicyTests.swift`

- [ ] **Step 1: Write failing policy tests**

Add `Tests/SimpleMarkdownPreviewerCoreTests/ResourcePolicyTests.swift`:

```swift
import Foundation
import Testing
@testable import SimpleMarkdownPreviewerCore

@Suite
struct ResourcePolicyTests {
    @Test
    func allowsHttpHttpsAndMailtoLinks() {
        let policy = ResourcePolicy(documentURL: URL(fileURLWithPath: "/tmp/doc.md"))
        #expect(policy.allowedExternalURL(URL(string: "https://example.com")!) != nil)
        #expect(policy.allowedExternalURL(URL(string: "http://example.com")!) != nil)
        #expect(policy.allowedExternalURL(URL(string: "mailto:test@example.com")!) != nil)
    }

    @Test
    func blocksUnsafeSchemes() {
        let policy = ResourcePolicy(documentURL: URL(fileURLWithPath: "/tmp/doc.md"))
        #expect(policy.allowedExternalURL(URL(string: "javascript:alert(1)")!) == nil)
        #expect(policy.allowedExternalURL(URL(string: "file:///etc/passwd")!) == nil)
        #expect(policy.allowedExternalURL(URL(string: "x-custom://value")!) == nil)
    }

    @Test
    func allowsOnlyLocalImagesUnderDocumentDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let assets = root.appendingPathComponent("assets")
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let image = assets.appendingPathComponent("local.png")
        FileManager.default.createFile(atPath: image.path, contents: Data([0x89, 0x50, 0x4E, 0x47]))
        let escaped = outside.appendingPathComponent("escaped.png")
        FileManager.default.createFile(atPath: escaped.path, contents: Data([0x89, 0x50, 0x4E, 0x47]))
        let symlink = assets.appendingPathComponent("linked.png")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: escaped)

        let policy = ResourcePolicy(documentURL: root.appendingPathComponent("doc.md"))

        #expect(try policy.localImageURL(for: "assets/local.png") == image.standardizedFileURL)
        #expect(throws: PreviewError.self) {
            _ = try policy.localImageURL(for: "../outside.png")
        }
        #expect(throws: PreviewError.self) {
            _ = try policy.localImageURL(for: "assets/%2E%2E/%2E%2E/outside.png")
        }
        #expect(throws: PreviewError.self) {
            _ = try policy.localImageURL(for: "assets/linked.png")
        }
        #expect(throws: PreviewError.self) {
            _ = try policy.localImageURL(for: "https://example.com/a.png")
        }
        #expect(throws: PreviewError.self) {
            _ = try policy.localImageURL(for: "data:image/png;base64,AAAA")
        }
        #expect(throws: PreviewError.self) {
            _ = try policy.localImageURL(for: "assets/vector.svg")
        }
        #expect(throws: PreviewError.self) {
            _ = try policy.localImageURL(for: "assets/missing.png")
        }
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter ResourcePolicyTests
```

Expected: FAIL because `ResourcePolicy` does not exist.

- [ ] **Step 3: Implement policy**

Add `Sources/SimpleMarkdownPreviewerCore/ResourcePolicy.swift`:

```swift
import Foundation

public struct ResourcePolicy {
    private let documentDirectory: URL

    public init(documentURL: URL) {
        self.documentDirectory = documentURL.deletingLastPathComponent().standardizedFileURL
    }

    public func allowedExternalURL(_ url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased() else { return nil }
        return ["http", "https", "mailto"].contains(scheme) ? url : nil
    }

    public func localImageURL(for rawPath: String) throws -> URL {
        guard !rawPath.lowercased().hasPrefix("http:"),
              !rawPath.lowercased().hasPrefix("https:"),
              !rawPath.lowercased().hasPrefix("data:"),
              !rawPath.lowercased().hasPrefix("file:") else {
            throw PreviewError.unsafeResource("remote or absolute image URL")
        }

        let decoded = rawPath.removingPercentEncoding ?? rawPath
        guard decoded.lowercased().hasSuffix(".png")
            || decoded.lowercased().hasSuffix(".jpg")
            || decoded.lowercased().hasSuffix(".jpeg")
            || decoded.lowercased().hasSuffix(".gif")
            || decoded.lowercased().hasSuffix(".webp") else {
            throw PreviewError.unsafeResource("unsupported image type")
        }

        let candidate = documentDirectory.appendingPathComponent(decoded).standardizedFileURL
        let resolved = candidate.resolvingSymlinksInPath()
        let root = documentDirectory.resolvingSymlinksInPath()
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"

        guard resolved.path == root.path || resolved.path.hasPrefix(rootPath) else {
            throw PreviewError.unsafeResource("image outside document directory")
        }
        guard FileManager.default.fileExists(atPath: resolved.path) else {
            throw PreviewError.unsafeResource("image does not exist")
        }

        return resolved
    }
}
```

- [ ] **Step 4: Verify policy tests pass**

Run:

```bash
swift test --filter ResourcePolicyTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SimpleMarkdownPreviewerCore/ResourcePolicy.swift Tests/SimpleMarkdownPreviewerCoreTests/ResourcePolicyTests.swift
git commit -m "feat(core): add resource security policy"
```

## Task 5: HTML Template and Assets

**Files:**
- Create: `Sources/SimpleMarkdownPreviewerCore/HTMLTemplate.swift`
- Create: `Sources/SimpleMarkdownPreviewerCore/Assets/preview.css`
- Create: `Sources/SimpleMarkdownPreviewerCore/Assets/preview.js`
- Create: `Sources/SimpleMarkdownPreviewerCore/Assets/highlight.min.js`
- Create: `Sources/SimpleMarkdownPreviewerCore/Assets/highlight-github.css`
- Create: `Sources/SimpleMarkdownPreviewerCore/Assets/highlight-github-dark.css`
- Create: `Tests/SimpleMarkdownPreviewerCoreTests/HTMLTemplateTests.swift`

- [ ] **Step 1: Vendor highlight assets**

Download `highlight.min.js`, `github.css`, and `github-dark.css` from the official `highlight.js` 11.11.1 release or source tree. Save them as:

```text
Sources/SimpleMarkdownPreviewerCore/Assets/highlight.min.js
Sources/SimpleMarkdownPreviewerCore/Assets/highlight-github.css
Sources/SimpleMarkdownPreviewerCore/Assets/highlight-github-dark.css
```

Keep files unmodified except filename normalization. Do not load them from a CDN at runtime.

Use the `11.11.1` tag, not `main`. One acceptable download path is:

```bash
curl -L -o Sources/SimpleMarkdownPreviewerCore/Assets/highlight.min.js https://raw.githubusercontent.com/highlightjs/highlight.js/11.11.1/build/highlight.min.js
curl -L -o Sources/SimpleMarkdownPreviewerCore/Assets/highlight-github.css https://raw.githubusercontent.com/highlightjs/highlight.js/11.11.1/src/styles/github.css
curl -L -o Sources/SimpleMarkdownPreviewerCore/Assets/highlight-github-dark.css https://raw.githubusercontent.com/highlightjs/highlight.js/11.11.1/src/styles/github-dark.css
```

- [ ] **Step 2: Write failing template tests**

Add `Tests/SimpleMarkdownPreviewerCoreTests/HTMLTemplateTests.swift`:

```swift
import Testing
@testable import SimpleMarkdownPreviewerCore

@Suite
struct HTMLTemplateTests {
    @Test
    func wrapsBodyWithContentSecurityPolicyAndReaderStyles() throws {
        let html = try HTMLTemplate().document(body: "<h1>Hello</h1>", title: "Doc", preferences: PreviewPreferences())

        #expect(html.contains("<meta http-equiv=\"Content-Security-Policy\""))
        #expect(html.contains("default-src 'none'"))
        #expect(html.contains("<main class=\"markdown-body\">"))
        #expect(html.contains("<h1>Hello</h1>"))
        #expect(html.contains("window.hljs"))
        #expect(html.contains("highlightAll"))
    }
}
```

- [ ] **Step 3: Add reader CSS**

Add `Sources/SimpleMarkdownPreviewerCore/Assets/preview.css`:

```css
:root {
  color-scheme: light dark;
  --page-bg: Canvas;
  --text: CanvasText;
  --muted: color-mix(in srgb, CanvasText 62%, Canvas 38%);
  --border: color-mix(in srgb, CanvasText 18%, Canvas 82%);
  --code-bg: color-mix(in srgb, CanvasText 6%, Canvas 94%);
}

html, body {
  margin: 0;
  min-height: 100%;
  background: var(--page-bg);
  color: var(--text);
  font: -apple-system-body;
  font-size: calc(16px * var(--font-scale, 1));
}

body.theme-light {
  color-scheme: light;
}

body.theme-dark {
  color-scheme: dark;
}

.markdown-body {
  box-sizing: border-box;
  max-width: 860px;
  margin: 0 auto;
  padding: 42px 32px 72px;
  line-height: 1.62;
  overflow-wrap: break-word;
}

h1, h2, h3, h4, h5, h6 {
  line-height: 1.22;
  margin: 1.6em 0 0.55em;
}

p, ul, ol, blockquote, pre, table {
  margin: 0 0 1em;
}

blockquote {
  margin-left: 0;
  padding-left: 1em;
  color: var(--muted);
  border-left: 3px solid var(--border);
}

pre {
  overflow-x: auto;
  padding: 14px 16px;
  border-radius: 8px;
  background: var(--code-bg);
}

code {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
}

table {
  display: block;
  overflow-x: auto;
  border-collapse: collapse;
}

th, td {
  padding: 6px 10px;
  border: 1px solid var(--border);
}

img {
  max-width: 100%;
  height: auto;
}
```

Add `Sources/SimpleMarkdownPreviewerCore/Assets/preview.js`:

```javascript
document.addEventListener("DOMContentLoaded", () => {
  if (window.hljs) {
    window.hljs.highlightAll();
  }
});
```

- [ ] **Step 4: Implement template**

Add `Sources/SimpleMarkdownPreviewerCore/HTMLTemplate.swift`:

```swift
import Foundation

public struct HTMLTemplate {
    public init() {}

    public func document(body: String, title: String, preferences: PreviewPreferences) throws -> String {
        let safeTitle = title.htmlEscaped()
        let themeClass = "theme-\(preferences.appearanceMode.rawValue)"
        let fontScale = String(format: "%.2f", preferences.fontScale)
        let previewCSS = try Self.assetText("preview", extension: "css")
        let highlightLightCSS = try Self.assetText("highlight-github", extension: "css")
        let highlightDarkCSS = try Self.assetText("highlight-github-dark", extension: "css")
        let highlightJS = try Self.assetText("highlight.min", extension: "js")
        let previewJS = try Self.assetText("preview", extension: "js")
        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src file:; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
          <title>\(safeTitle)</title>
          <style>:root { --font-scale: \(fontScale); }</style>
          <style>\(previewCSS)</style>
          <style media="(prefers-color-scheme: light)">\(highlightLightCSS)</style>
          <style media="(prefers-color-scheme: dark)">\(highlightDarkCSS)</style>
          <script>\(highlightJS)</script>
          <script>\(previewJS)</script>
        </head>
        <body class="\(themeClass)">
          <main class="markdown-body">
        \(body)
          </main>
        </body>
        </html>
        """
    }

    private static func assetText(_ name: String, extension ext: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
            throw PreviewError.renderFailed("Missing asset \(name).\(ext)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

extension String {
    func htmlEscaped() -> String {
        var escaped = self
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&#39;")
        return escaped
    }
}
```

- [ ] **Step 5: Verify template tests pass**

Run:

```bash
swift test --filter HTMLTemplateTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/SimpleMarkdownPreviewerCore/HTMLTemplate.swift Sources/SimpleMarkdownPreviewerCore/Assets Tests/SimpleMarkdownPreviewerCoreTests/HTMLTemplateTests.swift
git commit -m "feat(core): add preview HTML template"
```

## Task 6: Markdown to Safe HTML Rendering

**Files:**
- Create: `Sources/SimpleMarkdownPreviewerCore/MarkdownHTMLRenderer.swift`
- Create: `Tests/SimpleMarkdownPreviewerCoreTests/MarkdownHTMLRendererTests.swift`

- [ ] **Step 1: Write failing renderer tests**

Add `Tests/SimpleMarkdownPreviewerCoreTests/MarkdownHTMLRendererTests.swift`:

```swift
import Foundation
import Testing
@testable import SimpleMarkdownPreviewerCore

@Suite
struct MarkdownHTMLRendererTests {
    @Test
    func rendersCoreMarkdownElements() throws {
        let renderer = MarkdownHTMLRenderer()
        let documentURL = URL(fileURLWithPath: "/tmp/doc.md")
        let markdown = """
        # Title

        - [x] Done
        - [ ] Todo

        | A | B |
        | - | - |
        | 1 | 2 |

        ```swift
        let value = 1
        ```
        """

        let html = try renderer.render(markdown, documentURL: documentURL)

        #expect(html.contains("<h1>Title</h1>"))
        #expect(html.contains("task-list-item"))
        #expect(html.contains("<table>"))
        #expect(html.contains("language-swift"))
    }

    @Test
    func escapesRawHTMLAndBlocksUnsafeLinks() throws {
        let renderer = MarkdownHTMLRenderer()
        let documentURL = URL(fileURLWithPath: "/tmp/doc.md")
        let markdown = """
        <script>alert(1)</script>
        [bad](javascript:alert(1))
        [good](https://example.com)
        """

        let html = try renderer.render(markdown, documentURL: documentURL)

        #expect(html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
        #expect(!html.contains("javascript:alert"))
        #expect(html.contains("href=\"https://example.com\""))
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter MarkdownHTMLRendererTests
```

Expected: FAIL because `MarkdownHTMLRenderer` does not exist.

- [ ] **Step 3: Implement renderer**

Add `Sources/SimpleMarkdownPreviewerCore/MarkdownHTMLRenderer.swift`:

```swift
import Foundation
import Markdown

public struct MarkdownHTMLRenderer {
    public init() {}

    public func render(_ source: String, documentURL: URL) throws -> String {
        let policy = ResourcePolicy(documentURL: documentURL)
        let document = Document(parsing: source)
        var visitor = SafeHTMLVisitor(policy: policy)
        return visitor.visit(document)
    }
}

private struct SafeHTMLVisitor: MarkupVisitor {
    typealias Result = String

    let policy: ResourcePolicy

    mutating func defaultVisit(_ markup: Markup) -> String {
        markup.children.map { visit($0) }.joined()
    }

    mutating func visitDocument(_ document: Document) -> String {
        document.children.map { visit($0) }.joined(separator: "\n")
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let level = min(max(heading.level, 1), 6)
        return "<h\(level)>" + defaultVisit(heading) + "</h\(level)>"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        "<p>" + defaultVisit(paragraph) + "</p>"
    }

    mutating func visitText(_ text: Text) -> String {
        text.string.htmlEscaped()
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        "<br>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        "<em>" + defaultVisit(emphasis) + "</em>"
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        "<strong>" + defaultVisit(strong) + "</strong>"
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        "<del>" + defaultVisit(strikethrough) + "</del>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<code>" + inlineCode.code.htmlEscaped() + "</code>"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let language = codeBlock.language?.htmlEscaped() ?? "plaintext"
        return "<pre><code class=\"language-\(language)\">\(codeBlock.code.htmlEscaped())</code></pre>"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        "<blockquote>" + defaultVisit(blockQuote) + "</blockquote>"
    }

    mutating func visitTable(_ table: Table) -> String {
        "<table>" + defaultVisit(table) + "</table>"
    }

    mutating func visitTableHead(_ tableHead: TableHead) -> String {
        "<thead>" + defaultVisit(tableHead) + "</thead>"
    }

    mutating func visitTableBody(_ tableBody: TableBody) -> String {
        "<tbody>" + defaultVisit(tableBody) + "</tbody>"
    }

    mutating func visitTableRow(_ tableRow: TableRow) -> String {
        "<tr>" + defaultVisit(tableRow) + "</tr>"
    }

    mutating func visitTableCell(_ tableCell: TableCell) -> String {
        let tag = tableCell.parent is TableHead ? "th" : "td"
        return "<\(tag)>" + defaultVisit(tableCell) + "</\(tag)>"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        "<ul>" + defaultVisit(unorderedList) + "</ul>"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        "<ol>" + defaultVisit(orderedList) + "</ol>"
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        let checkbox = listItem.checkbox.map { checked in
            "<input type=\"checkbox\" disabled\(checked == .checked ? " checked" : "")> "
        } ?? ""
        let className = listItem.checkbox == nil ? "" : " class=\"task-list-item\""
        return "<li\(className)>" + checkbox + defaultVisit(listItem) + "</li>"
    }

    mutating func visitLink(_ link: Link) -> String {
        guard let destination = link.destination,
              let url = URL(string: destination),
              let allowed = policy.allowedExternalURL(url) else {
            return defaultVisit(link)
        }
        return "<a href=\"\(allowed.absoluteString.htmlEscaped())\">" + defaultVisit(link) + "</a>"
    }

    mutating func visitImage(_ image: Image) -> String {
        guard let source = image.source,
              let url = try? policy.localImageURL(for: source) else {
            return ""
        }
        let alt = defaultVisit(image).htmlEscaped()
        return "<img src=\"\(url.absoluteString.htmlEscaped())\" alt=\"\(alt)\">"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String {
        html.rawHTML.htmlEscaped()
    }

    mutating func visitInlineHTML(_ html: InlineHTML) -> String {
        html.rawHTML.htmlEscaped()
    }
}
```

If any `swift-markdown` symbol differs at compile time, keep the public behavior and tests unchanged, then adjust only the visitor method signatures to match the installed package documentation.

- [ ] **Step 4: Verify renderer tests pass**

Run:

```bash
swift test --filter MarkdownHTMLRendererTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SimpleMarkdownPreviewerCore/MarkdownHTMLRenderer.swift Tests/SimpleMarkdownPreviewerCoreTests/MarkdownHTMLRendererTests.swift
git commit -m "feat(core): render safe markdown HTML"
```

## Task 7: App State, Menus, and File Opening

**Files:**
- Create: `Sources/SimpleMarkdownPreviewerApp/AppState.swift`
- Create: `Sources/SimpleMarkdownPreviewerApp/AppDelegate.swift`
- Modify: `Sources/SimpleMarkdownPreviewerApp/main.swift`
- Create: `Sources/SimpleMarkdownPreviewerCore/Preferences.swift`

- [ ] **Step 1: Add state and preferences**

Add `Sources/SimpleMarkdownPreviewerCore/Preferences.swift`:

```swift
import Foundation

public enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark
}

public struct PreviewPreferences: Equatable {
    public var fontScale: Double
    public var appearanceMode: AppearanceMode

    public init(fontScale: Double = 1.0, appearanceMode: AppearanceMode = .system) {
        self.fontScale = fontScale
        self.appearanceMode = appearanceMode
    }
}
```

Add `Sources/SimpleMarkdownPreviewerApp/AppState.swift`:

```swift
import Foundation
import Observation
import SimpleMarkdownPreviewerCore

@Observable
final class AppState {
    enum ViewState: Equatable {
        case empty
        case loading
        case rendered(title: String, html: String, baseURL: URL)
        case error(String)
    }

    var viewState: ViewState = .empty
    var preferences = PreviewPreferences()
    private var currentDocument: MarkdownDocument?

    private let fileIntake = FileIntake()
    private let renderer = MarkdownHTMLRenderer()
    private let template = HTMLTemplate()

    func open(_ url: URL) {
        viewState = .loading
        do {
            let document = try fileIntake.loadMarkdownFile(at: url)
            currentDocument = document
            try renderCurrentDocument()
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }

    func reload() {
        guard let currentDocument else { return }
        open(currentDocument.url)
    }

    func updatePreferences(_ update: (inout PreviewPreferences) -> Void) {
        update(&preferences)
        do {
            try renderCurrentDocument()
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }

    private func renderCurrentDocument() throws {
        guard let document = currentDocument else {
            viewState = .empty
            return
        }
        do {
            let body = try renderer.render(document.source, documentURL: document.url)
            let html = try template.document(body: body, title: document.url.lastPathComponent, preferences: preferences)
            viewState = .rendered(
                title: document.url.lastPathComponent,
                html: html,
                baseURL: document.url.deletingLastPathComponent()
            )
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 2: Add app delegate for Finder open events**

Add `Sources/SimpleMarkdownPreviewerApp/AppDelegate.swift`:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pendingOpenURLs: [URL] = []
    var openURLHandler: ((URL) -> Void)? {
        didSet {
            guard let openURLHandler else { return }
            pendingOpenURLs.forEach(openURLHandler)
            pendingOpenURLs.removeAll()
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for filename in filenames {
            let url = URL(fileURLWithPath: filename)
            if let openURLHandler {
                openURLHandler(url)
            } else {
                pendingOpenURLs.append(url)
            }
        }
        sender.reply(toOpenOrPrint: .success)
    }
}
```

- [ ] **Step 3: Wire menus in the app entry point**

Replace `Sources/SimpleMarkdownPreviewerApp/main.swift` with:

```swift
import AppKit
import SimpleMarkdownPreviewerCore
import SwiftUI
import UniformTypeIdentifiers

@main
struct SimpleMarkdownPreviewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .onAppear {
                    appDelegate.openURLHandler = appState.open
                    if let firstPath = CommandLine.arguments.dropFirst().first {
                        appState.open(URL(fileURLWithPath: firstPath))
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [
                        UTType(filenameExtension: "md")!,
                        UTType(filenameExtension: "markdown")!
                    ]
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    if panel.runModal() == .OK, let url = panel.url {
                        appState.open(url)
                    }
                }
                .keyboardShortcut("o")
            }
            CommandMenu("View") {
                Button("Reload") {
                    appState.reload()
                }
                .keyboardShortcut("r")

                Button("Increase Text Size") {
                    appState.updatePreferences { preferences in
                        preferences.fontScale = min(preferences.fontScale + 0.1, 1.6)
                    }
                }
                .keyboardShortcut("+")

                Button("Decrease Text Size") {
                    appState.updatePreferences { preferences in
                        preferences.fontScale = max(preferences.fontScale - 0.1, 0.8)
                    }
                }
                .keyboardShortcut("-")

                Divider()

                Picker("Appearance", selection: Binding(
                    get: { appState.preferences.appearanceMode },
                    set: { mode in
                        appState.updatePreferences { preferences in
                            preferences.appearanceMode = mode
                        }
                    }
                )) {
                    Text("System").tag(AppearanceMode.system)
                    Text("Light").tag(AppearanceMode.light)
                    Text("Dark").tag(AppearanceMode.dark)
                }
            }
        }
    }
}
```

Keep `FileIntake` as the final validation layer even though the open panel filters `.md` and `.markdown`.

- [ ] **Step 4: Build**

Run:

```bash
swift build
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SimpleMarkdownPreviewerApp Sources/SimpleMarkdownPreviewerCore/Preferences.swift
git commit -m "feat(app): handle markdown open commands"
```

## Task 8: Preview View and Drag-and-Drop

**Files:**
- Create: `Sources/SimpleMarkdownPreviewerApp/ContentView.swift`
- Create: `Sources/SimpleMarkdownPreviewerApp/PreviewWebView.swift`
- Modify: `Sources/SimpleMarkdownPreviewerApp/main.swift`

- [ ] **Step 1: Add WKWebView bridge**

Add `Sources/SimpleMarkdownPreviewerApp/PreviewWebView.swift`:

```swift
import SwiftUI
import WebKit

struct PreviewWebView: NSViewRepresentable {
    let html: String
    let baseURL: URL

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
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
        }
    }
}
```

- [ ] **Step 2: Add content view**

Add `Sources/SimpleMarkdownPreviewerApp/ContentView.swift`:

```swift
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var appState: AppState

    var body: some View {
        Group {
            switch appState.viewState {
            case .empty:
                Text("打开或拖入 Markdown 文件")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .rendered(_, let html, let baseURL):
                PreviewWebView(html: html, baseURL: baseURL)
            case .error(let message):
                Text(message)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}
```

- [ ] **Step 3: Build and smoke test**

Run:

```bash
swift build
```

Expected: PASS.

Manual smoke:

```bash
./scripts/build_app.sh
open .build/app/SimpleMarkdownPreviewer.app
```

Expected: window opens with the empty-state text. Do not claim drag-and-drop verified until tested visually.

- [ ] **Step 4: Commit**

```bash
git add Sources/SimpleMarkdownPreviewerApp/ContentView.swift Sources/SimpleMarkdownPreviewerApp/PreviewWebView.swift
git commit -m "feat(app): show markdown preview web view"
```

## Task 9: Fixtures and End-to-End Verification

**Files:**
- Create: `Fixtures/Markdown/sample.md`
- Create: `Fixtures/Markdown/assets/local.png`
- Modify: `scripts/check.sh`
- Modify: `scripts/verify_bundle.sh`

- [ ] **Step 1: Add sample Markdown fixture**

Add `Fixtures/Markdown/sample.md`:

````markdown
# Sample Markdown

This file verifies **bold**, *italic*, ~~strikethrough~~, [safe link](https://example.com), and blocked HTML:

<script>alert("blocked")</script>

- [x] Render task lists
- [ ] Keep the UI read-only

| Area | Expected |
| --- | --- |
| Table | Renders |
| Code | Highlights |

```swift
let answer = 42
print(answer)
```

![Local image](assets/local.png)
````

Add a tiny PNG fixture at `Fixtures/Markdown/assets/local.png`. Use a 1x1 PNG generated by Preview, `sips`, or another local tool; do not embed secrets or downloaded images.

- [ ] **Step 2: Confirm bundle verification covers executable and resources**

Ensure `scripts/verify_bundle.sh` contains these checks from Task 1:

```bash
APP=".build/app/SimpleMarkdownPreviewer.app"
test -x "$APP/Contents/MacOS/SimpleMarkdownPreviewer"
find "$APP/Contents/Resources" -name "preview.css" -print -quit | grep -q "preview.css"
```

- [ ] **Step 3: Run full verification**

Run:

```bash
./scripts/check.sh
```

Expected: PASS for tests, build, bundle creation, and bundle metadata verification.

- [ ] **Step 4: Manual visual verification**

Run:

```bash
./scripts/build_app.sh
open .build/app/SimpleMarkdownPreviewer.app --args "$(pwd)/Fixtures/Markdown/sample.md"
```

Then manually verify:

- The content area shows only rendered Markdown after opening.
- Toggle Light, Dark, and System appearance from the View menu and confirm contrast remains readable.
- Increase and decrease text size from the View menu and confirm the document reflows without overlap.
- Resize the window to narrow, wide, and full-screen widths and confirm line length, table scrolling, and image scaling remain usable.
- Code block is highlighted.
- Table scrolls or fits without layout overlap.
- Local image renders.
- A larger local image scales down to the content width while preserving aspect ratio.
- A long Markdown file remains scrollable and does not introduce content-area toolbar chrome.
- Raw `<script>` appears as text or is absent, but never executes.
- Clicking `https://example.com` opens the system browser and does not navigate inside the preview.
- Dragging `Fixtures/Markdown/sample.md` into the window reloads the preview.

- [ ] **Step 5: Commit**

```bash
git add Fixtures scripts
git commit -m "test(fixtures): add markdown preview smoke fixture"
```

## Task 10: Final Quality Gate

**Files:**
- Modify only files required by issues found during verification.

- [ ] **Step 1: Run full checks**

Run:

```bash
./scripts/check.sh
```

Expected: PASS.

- [ ] **Step 2: Inspect app bundle document registration**

Run:

```bash
/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes" .build/app/SimpleMarkdownPreviewer.app/Contents/Info.plist
```

Expected: output includes both `md` and `markdown` in `CFBundleTypeExtensions`.

- [ ] **Step 3: Manual Finder default-app check**

In Finder:

- Select a `.md` file.
- Use `Get Info > Open with > SimpleMarkdownPreviewer`.
- Click `Change All...`.
- Double-click the file.

Expected: SimpleMarkdownPreviewer opens and renders the document. Repeat with `.markdown`.

- [ ] **Step 4: Pre-commit review and simplify pass**

Before any final merge or release commit, use `superpowers:requesting-code-review`, then remove avoidable complexity, duplication, dead code, and unrelated churn.

- [ ] **Step 5: Commit final verification docs if added**

If manual verification notes are recorded, commit them separately:

```bash
git add docs
git commit -m "doc(verification): record markdown previewer smoke results"
```

## Coverage Matrix

| Spec requirement | Plan coverage |
| --- | --- |
| Rendered content only | Tasks 7, 8, 9 |
| Default `.md` app | Tasks 2, 10 |
| Default `.markdown` app | Tasks 2, 10 |
| Drag-and-drop | Task 8 |
| File picker | Task 7 |
| GFM tables and task lists | Task 6 |
| Code highlighting | Tasks 5, 6, 9 |
| Local relative images | Tasks 4, 6, 9 |
| Links open externally | Tasks 4, 8, 9 |
| Raw HTML and scripts blocked | Tasks 4, 5, 6, 9 |
| macOS typography and layout | Tasks 5, 8, 9 |

## Known Implementation Risks

- `swift-markdown` visitor method names may differ slightly from the snippets. Keep the tests and behavior fixed; adjust method signatures against the installed 0.8.0 API during Task 6.
- `WKWebView` loads generated HTML with the Markdown document directory as `baseURL`; CSS and JavaScript are inlined from bundled assets, so document-local images can resolve without allowing unrelated bundle paths.
- Finder default-app validation cannot be fully automated without changing user LaunchServices state. Treat Task 10 Finder checks as manual evidence.
