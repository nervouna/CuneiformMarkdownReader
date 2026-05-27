import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var appState: AppState
    var rendererMode: PreviewRendererMode = .current()

    var body: some View {
        Group {
            switch appState.viewState {
            case .empty:
                Text("打开或拖入 Markdown 文件")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .rendered(_, _, let html, let baseURL):
                switch rendererMode {
                case .native, .webview:
                    PreviewWebView(html: html, baseURL: baseURL)
                }
            case .error(let message):
                Text(message)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }
                Task { @MainActor in
                    appState.open(url)
                }
            }
            return true
        }
    }
}
