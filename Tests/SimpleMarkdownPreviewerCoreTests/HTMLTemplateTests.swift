import Testing
@testable import SimpleMarkdownPreviewerCore

@Suite
struct HTMLTemplateTests {
    @Test
    func wrapsBodyWithContentSecurityPolicyAndReaderStyles() throws {
        let html = try HTMLTemplate().document(
            body: "<h1>Hello</h1>",
            title: "Doc",
            preferences: PreviewPreferences()
        )

        #expect(html.contains("<meta http-equiv=\"Content-Security-Policy\""))
        #expect(html.contains("default-src 'none'"))
        #expect(html.contains("<main class=\"markdown-body\">"))
        #expect(html.contains("<h1>Hello</h1>"))
        #expect(html.contains("window.hljs"))
        #expect(html.contains("highlightAll"))
    }
}
