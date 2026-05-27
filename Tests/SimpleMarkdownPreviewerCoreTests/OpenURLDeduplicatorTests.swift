import Foundation
import Testing
@testable import SimpleMarkdownPreviewerCore

@Suite
struct OpenURLDeduplicatorTests {
    @Test
    func returnsStandardizedURLOnlyOnce() {
        var deduplicator = OpenURLDeduplicator()
        let first = URL(fileURLWithPath: "/tmp/folder/../document.md")
        let duplicate = URL(fileURLWithPath: "/tmp/document.md")

        #expect(deduplicator.nextURLToOpen(first) == URL(fileURLWithPath: "/tmp/document.md"))
        #expect(deduplicator.nextURLToOpen(duplicate) == nil)
    }

    @Test
    func resetAllowsTheSameURLAgain() {
        var deduplicator = OpenURLDeduplicator()
        let url = URL(fileURLWithPath: "/tmp/document.md")

        #expect(deduplicator.nextURLToOpen(url) == url)
        #expect(deduplicator.nextURLToOpen(url) == nil)

        deduplicator.reset()

        #expect(deduplicator.nextURLToOpen(url) == url)
    }
}
