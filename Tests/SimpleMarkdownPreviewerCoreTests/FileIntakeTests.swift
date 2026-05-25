import Foundation
import Testing
@testable import SimpleMarkdownPreviewerCore

@Suite
struct FileIntakeTests {
    @Test
    func acceptsMarkdownExtensionsCaseInsensitively() {
        #expect(FileIntake.isSupportedMarkdownFile(URL(fileURLWithPath: "/tmp/a.md")))
        #expect(FileIntake.isSupportedMarkdownFile(URL(fileURLWithPath: "/tmp/a.MARKDOWN")))
        #expect(!FileIntake.isSupportedMarkdownFile(URL(fileURLWithPath: "/tmp/a.txt")))
    }

    @Test
    func readsUTF8MarkdownFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
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
