import Foundation

public struct OpenURLDeduplicator {
    private var openedURLs: Set<URL> = []

    public init() {}

    public mutating func nextURLToOpen(_ url: URL) -> URL? {
        let standardizedURL = url.standardizedFileURL
        guard openedURLs.insert(standardizedURL).inserted else {
            return nil
        }
        return standardizedURL
    }

    public mutating func reset() {
        openedURLs.removeAll()
    }
}
