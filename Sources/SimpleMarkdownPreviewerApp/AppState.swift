import Foundation
import Observation
import SimpleMarkdownPreviewerCore

@Observable
final class AppState {
    enum ViewState: Equatable {
        case empty
        case loading
        case rendered(title: String, html: String, baseURL: URL)
        case error(String)
    }

    var viewState: ViewState = .empty
    var preferences = PreviewPreferences()
    private var currentDocument: MarkdownDocument?

    private let fileIntake = FileIntake()
    private let renderer = MarkdownHTMLRenderer()
    private let template = HTMLTemplate()

    func open(_ url: URL) {
        viewState = .loading
        do {
            let document = try fileIntake.loadMarkdownFile(at: url)
            currentDocument = document
            try renderCurrentDocument()
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }

    func reload() {
        guard let currentDocument else { return }
        open(currentDocument.url)
    }

    func updatePreferences(_ update: (inout PreviewPreferences) -> Void) {
        update(&preferences)
        do {
            try renderCurrentDocument()
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }

    private func renderCurrentDocument() throws {
        guard let document = currentDocument else {
            viewState = .empty
            return
        }

        let body = try renderer.render(document.source, documentURL: document.url)
        let html = try template.document(
            body: body,
            title: document.url.lastPathComponent,
            preferences: preferences
        )
        viewState = .rendered(
            title: document.url.lastPathComponent,
            html: html,
            baseURL: document.url.deletingLastPathComponent()
        )
    }
}
