import Foundation

public struct HTMLTemplate {
    public init() {}

    public func document(body: String, title: String, preferences: PreviewPreferences) throws -> String {
        let safeTitle = title.htmlEscaped()
        let themeClass = "theme-\(preferences.appearanceMode.rawValue)"
        let fontScale = String(format: "%.2f", preferences.fontScale)
        let previewCSS = try Self.previewCSS()
        let syntaxHighlighting = try Self.syntaxHighlightingMarkup(for: body)

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
        \(syntaxHighlighting)
        </head>
        <body class="\(themeClass)">
          <main class="markdown-body">
        \(body)
          </main>
        </body>
        </html>
        """
    }

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

    private static func assetText(_ name: String, extension ext: String) throws -> String {
        guard let url = assetURL(name, extension: ext) else {
            throw PreviewError.renderFailed("Missing asset \(name).\(ext)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func assetURL(_ name: String, extension ext: String) -> URL? {
        if let url = Bundle.main.url(
            forResource: name,
            withExtension: ext,
            subdirectory: "PreviewAssets"
        ) {
            return url
        }
        return Bundle.module.url(forResource: name, withExtension: ext)
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
