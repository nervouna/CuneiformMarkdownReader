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

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let source = try String(contentsOf: url, encoding: .utf8)
            return MarkdownDocument(url: url, source: source)
        } catch {
            throw PreviewError.unreadableFile(url)
        }
    }
}
