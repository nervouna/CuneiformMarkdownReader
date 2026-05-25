import Foundation

public struct ResourcePolicy {
    private let documentDirectory: URL

    public init(documentURL: URL) {
        self.documentDirectory = documentURL.deletingLastPathComponent().standardizedFileURL
    }

    public func allowedExternalURL(_ url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased() else {
            return nil
        }
        return ["http", "https", "mailto"].contains(scheme) ? url : nil
    }

    public func localImageURL(for rawPath: String) throws -> URL {
        let lowercased = rawPath.lowercased()
        guard !lowercased.hasPrefix("http:"),
              !lowercased.hasPrefix("https:"),
              !lowercased.hasPrefix("data:"),
              !lowercased.hasPrefix("file:") else {
            throw PreviewError.unsafeResource("remote or absolute image URL")
        }

        let decoded = rawPath.removingPercentEncoding ?? rawPath
        let decodedLowercased = decoded.lowercased()
        guard decodedLowercased.hasSuffix(".png")
            || decodedLowercased.hasSuffix(".jpg")
            || decodedLowercased.hasSuffix(".jpeg")
            || decodedLowercased.hasSuffix(".gif")
            || decodedLowercased.hasSuffix(".webp") else {
            throw PreviewError.unsafeResource("unsupported image type")
        }

        let candidate = documentDirectory.appendingPathComponent(decoded).standardizedFileURL
        let resolved = candidate.resolvingSymlinksInPath()
        let root = documentDirectory.resolvingSymlinksInPath()
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"

        guard resolved.path == root.path || resolved.path.hasPrefix(rootPath) else {
            throw PreviewError.unsafeResource("image outside document directory")
        }
        guard FileManager.default.fileExists(atPath: resolved.path) else {
            throw PreviewError.unsafeResource("image does not exist")
        }

        return resolved
    }
}
