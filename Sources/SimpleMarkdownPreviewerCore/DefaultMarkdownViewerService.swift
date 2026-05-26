import CoreServices
import Foundation

public protocol DefaultApplicationRegistry {
    func setDefaultRoleHandler(contentType: String, role: UInt32, bundleIdentifier: String) -> OSStatus
    func defaultRoleHandler(contentType: String, role: UInt32) -> String?
}

public struct SystemDefaultApplicationRegistry: DefaultApplicationRegistry {
    public init() {}

    public func setDefaultRoleHandler(contentType: String, role: UInt32, bundleIdentifier: String) -> OSStatus {
        LSSetDefaultRoleHandlerForContentType(
            contentType as CFString,
            LSRolesMask(rawValue: role),
            bundleIdentifier as CFString
        )
    }

    public func defaultRoleHandler(contentType: String, role: UInt32) -> String? {
        LSCopyDefaultRoleHandlerForContentType(
            contentType as CFString,
            LSRolesMask(rawValue: role)
        )?.takeRetainedValue() as String?
    }
}

public struct DefaultMarkdownViewerResult: Equatable {
    public let contentType: String
    public let bundleIdentifier: String
}

public enum DefaultMarkdownViewerError: Error, Equatable, LocalizedError {
    case missingBundleIdentifier
    case setFailed(status: Int32)
    case verificationFailed(expected: String, actual: String?)

    public var errorDescription: String? {
        switch self {
        case .missingBundleIdentifier:
            "无法读取当前 app 的 bundle identifier。请先从 .app bundle 启动。"
        case let .setFailed(status):
            "无法设置默认 Markdown 阅读器。Launch Services 返回状态码 \(status)。"
        case let .verificationFailed(expected, actual):
            "设置后校验失败。期望 \(expected)，实际 \(actual ?? "未设置")。"
        }
    }
}

public struct DefaultMarkdownViewerService {
    public static let markdownContentType = "net.daringfireball.markdown"
    static let viewerRole = LSRolesMask.viewer.rawValue

    private let registry: DefaultApplicationRegistry
    private let bundleIdentifier: () -> String?

    public init(
        registry: DefaultApplicationRegistry = SystemDefaultApplicationRegistry(),
        bundleIdentifier: @escaping () -> String? = { Bundle.main.bundleIdentifier }
    ) {
        self.registry = registry
        self.bundleIdentifier = bundleIdentifier
    }

    public func setCurrentAppAsDefaultMarkdownViewer() throws -> DefaultMarkdownViewerResult {
        guard let bundleIdentifier = bundleIdentifier(), !bundleIdentifier.isEmpty else {
            throw DefaultMarkdownViewerError.missingBundleIdentifier
        }

        let status = registry.setDefaultRoleHandler(
            contentType: Self.markdownContentType,
            role: Self.viewerRole,
            bundleIdentifier: bundleIdentifier
        )
        guard status == noErr else {
            throw DefaultMarkdownViewerError.setFailed(status: status)
        }

        let actual = registry.defaultRoleHandler(
            contentType: Self.markdownContentType,
            role: Self.viewerRole
        )
        guard actual == bundleIdentifier else {
            throw DefaultMarkdownViewerError.verificationFailed(
                expected: bundleIdentifier,
                actual: actual
            )
        }

        return DefaultMarkdownViewerResult(
            contentType: Self.markdownContentType,
            bundleIdentifier: bundleIdentifier
        )
    }
}
