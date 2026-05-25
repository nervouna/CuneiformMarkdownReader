import Foundation
import Testing
@testable import SimpleMarkdownPreviewerCore

@Suite
struct SpecDocumentAcceptanceTests {
    @Test
    func rendersRepositorySpecDocumentAsAcceptanceMarkdown() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let specURL = root.appendingPathComponent("docs/spec/2026-05-26-minimal-macos-markdown-previewer-design.md")

        let document = try FileIntake().loadMarkdownFile(at: specURL)
        let body = try MarkdownHTMLRenderer().render(document.source, documentURL: specURL)
        let html = try HTMLTemplate().document(
            body: body,
            title: specURL.lastPathComponent,
            preferences: PreviewPreferences()
        )

        #expect(html.contains("<main class=\"markdown-body\">"))
        #expect(html.contains("极简 macOS Markdown 预览器设计"))
        #expect(html.contains("<table>"))
        #expect(html.contains("&lt;script&gt;") == false)
        #expect(!html.contains("href=\"javascript:"))
    }
}
