import AppKit
import MarkdownUI
import SimpleMarkdownPreviewerCore
import SwiftUI

struct NativeMarkdownPreview: View {
    let markdown: String
    let baseURL: URL

    var body: some View {
        ScrollView {
            Markdown(
                markdown,
                baseURL: baseURL,
                imageBaseURL: baseURL
            )
            .markdownTheme(.gitHub)
            .markdownImageProvider(LocalMarkdownImageProvider(baseURL: baseURL))
            .markdownInlineImageProvider(LocalMarkdownInlineImageProvider(baseURL: baseURL))
            .environment(\.openURL, OpenURLAction { url in
                guard let allowed = resourcePolicy(for: baseURL).allowedExternalURL(url) else {
                    return .discarded
                }
                NSWorkspace.shared.open(allowed)
                return .handled
            })
            .textSelection(.enabled)
            .frame(maxWidth: 820, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .onAppear {
                DispatchQueue.main.async {
                    StartupProbe.finish("native.contentReady")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct LocalMarkdownImageProvider: ImageProvider {
    let baseURL: URL

    func makeImage(url: URL?) -> some View {
        if let url,
           let imageURL = try? localImageURL(for: url, baseURL: baseURL),
           let image = NSImage(contentsOf: imageURL) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        }
    }
}

private struct LocalMarkdownInlineImageProvider: InlineImageProvider {
    let baseURL: URL

    func image(with url: URL, label: String) async throws -> Image {
        let imageURL = try localImageURL(for: url, baseURL: baseURL)
        guard let image = NSImage(contentsOf: imageURL) else {
            throw LocalMarkdownImageError.unreadableImage
        }
        return Image(nsImage: image)
    }
}

private enum LocalMarkdownImageError: Error {
    case absoluteFileURL
    case unreadableImage
}

private func localImageURL(for url: URL, baseURL: URL) throws -> URL {
    guard url.baseURL != nil else {
        if url.isFileURL {
            throw LocalMarkdownImageError.absoluteFileURL
        }
        return try resourcePolicy(for: baseURL).localImageURL(for: url.relativeString)
    }

    let rawPath = url.relativeString
    guard !rawPath.hasPrefix("/") else {
        throw LocalMarkdownImageError.absoluteFileURL
    }
    return try resourcePolicy(for: baseURL).localImageURL(for: rawPath)
}

private func resourcePolicy(for baseURL: URL) -> ResourcePolicy {
    ResourcePolicy(documentURL: baseURL.appendingPathComponent("document.md"))
}
