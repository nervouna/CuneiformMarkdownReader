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
