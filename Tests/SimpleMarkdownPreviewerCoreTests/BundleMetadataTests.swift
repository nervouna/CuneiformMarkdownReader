import Foundation
import Testing
@testable import SimpleMarkdownPreviewerCore

@Suite
struct BundleMetadataTests {
    @Test
    func declaresCuneiformBundleIdentity() throws {
        let plist = try infoPlist()

        #expect(plist["CFBundleName"] as? String == "Cuneiform")
        #expect(plist["CFBundleExecutable"] as? String == "Cuneiform")
        #expect(plist["CFBundleIdentifier"] as? String == "io.damao.cuneiform")
    }

    @Test
    func declaresMarkdownContentTypeForLaunchServices() throws {
        let plist = try infoPlist()
        let declarations = try #require(plist["UTImportedTypeDeclarations"] as? [[String: Any]])
        let markdownDeclaration = try #require(
            declarations.first { declaration in
                declaration["UTTypeIdentifier"] as? String == DefaultMarkdownViewerService.markdownContentType
            }
        )
        let conformsTo = try #require(markdownDeclaration["UTTypeConformsTo"] as? [String])
        let tagSpecification = try #require(markdownDeclaration["UTTypeTagSpecification"] as? [String: Any])
        let extensions = try #require(tagSpecification["public.filename-extension"] as? [String])

        #expect(conformsTo.contains("public.plain-text"))
        #expect(extensions.contains("md"))
        #expect(extensions.contains("markdown"))
        #expect(tagSpecification["public.mime-type"] as? String == "text/markdown")
    }

    @Test
    func documentTypeClaimsMarkdownContentTypeAsViewer() throws {
        let plist = try infoPlist()
        let documentTypes = try #require(plist["CFBundleDocumentTypes"] as? [[String: Any]])
        let markdownDocument = try #require(
            documentTypes.first { documentType in
                guard let contentTypes = documentType["LSItemContentTypes"] as? [String] else {
                    return false
                }
                return contentTypes.contains(DefaultMarkdownViewerService.markdownContentType)
            }
        )

        #expect(markdownDocument["CFBundleTypeRole"] as? String == "Viewer")
    }

    private func infoPlist() throws -> [String: Any] {
        let packageDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let plistURL = packageDirectory.appendingPathComponent("Resources/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try #require(plist as? [String: Any])
    }
}
