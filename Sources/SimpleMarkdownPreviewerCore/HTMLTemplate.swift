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
          <style>\(highlightLightCSS)</style>
          <style>
          @media (prefers-color-scheme: dark) { \(highlightDarkCSS) }
          body.theme-dark { \(highlightDarkCSS) }
          body.theme-light { \(highlightLightCSS) }
          </style>
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
