import CoreServices
import Testing
@testable import SimpleMarkdownPreviewerCore

@Suite
struct DefaultMarkdownViewerServiceTests {
    @Test
    func setsCurrentBundleAsMarkdownViewerAndVerifiesResult() throws {
        let registry = RecordingDefaultApplicationRegistry(defaultHandler: "com.example.preview")
        let service = DefaultMarkdownViewerService(
            registry: registry,
            bundleIdentifier: { "com.example.preview" }
        )

        let result = try service.setCurrentAppAsDefaultMarkdownViewer()

        #expect(result.contentType == DefaultMarkdownViewerService.markdownContentType)
        #expect(result.bundleIdentifier == "com.example.preview")
        #expect(registry.setCalls == [
            .init(
                contentType: DefaultMarkdownViewerService.markdownContentType,
                role: LSRolesMask.viewer.rawValue,
                bundleIdentifier: "com.example.preview"
            )
        ])
        #expect(registry.defaultHandlerRequests == [
            .init(
                contentType: DefaultMarkdownViewerService.markdownContentType,
                role: LSRolesMask.viewer.rawValue
            )
        ])
    }

    @Test
    func reportsSetFailureStatusWithoutVerifying() {
        let registry = RecordingDefaultApplicationRegistry(setStatus: -10814)
        let service = DefaultMarkdownViewerService(
            registry: registry,
            bundleIdentifier: { "com.example.preview" }
        )

        #expect(throws: DefaultMarkdownViewerError.setFailed(status: -10814)) {
            _ = try service.setCurrentAppAsDefaultMarkdownViewer()
        }
        #expect(registry.defaultHandlerRequests.isEmpty)
    }

    @Test
    func reportsVerificationMismatch() {
        let registry = RecordingDefaultApplicationRegistry(defaultHandler: "com.other.app")
        let service = DefaultMarkdownViewerService(
            registry: registry,
            bundleIdentifier: { "com.example.preview" }
        )

        #expect(
            throws: DefaultMarkdownViewerError.verificationFailed(
                expected: "com.example.preview",
                actual: "com.other.app"
            )
        ) {
            _ = try service.setCurrentAppAsDefaultMarkdownViewer()
        }
    }

    @Test
    func requiresBundleIdentifier() {
        let registry = RecordingDefaultApplicationRegistry()
        let service = DefaultMarkdownViewerService(
            registry: registry,
            bundleIdentifier: { nil }
        )

        #expect(throws: DefaultMarkdownViewerError.missingBundleIdentifier) {
            _ = try service.setCurrentAppAsDefaultMarkdownViewer()
        }
        #expect(registry.setCalls.isEmpty)
    }
}

private final class RecordingDefaultApplicationRegistry: DefaultApplicationRegistry {
    struct SetCall: Equatable {
        var contentType: String
        var role: UInt32
        var bundleIdentifier: String
    }

    struct DefaultHandlerRequest: Equatable {
        var contentType: String
        var role: UInt32
    }

    private let setStatus: OSStatus
    private let defaultHandler: String?
    private(set) var setCalls: [SetCall] = []
    private(set) var defaultHandlerRequests: [DefaultHandlerRequest] = []

    init(setStatus: OSStatus = noErr, defaultHandler: String? = nil) {
        self.setStatus = setStatus
        self.defaultHandler = defaultHandler
    }

    func setDefaultRoleHandler(contentType: String, role: UInt32, bundleIdentifier: String) -> OSStatus {
        setCalls.append(.init(contentType: contentType, role: role, bundleIdentifier: bundleIdentifier))
        return setStatus
    }

    func defaultRoleHandler(contentType: String, role: UInt32) -> String? {
        defaultHandlerRequests.append(.init(contentType: contentType, role: role))
        return defaultHandler
    }
}
