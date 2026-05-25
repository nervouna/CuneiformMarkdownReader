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
