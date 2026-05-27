import AppKit
import SwiftUI
import WebKit

struct PreviewWebView: NSViewRepresentable {
    let html: String
    let baseURL: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        StartupProbe.mark("webview.make.begin")
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        StartupProbe.mark("webview.make.end")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        StartupProbe.mark("webview.loadHTML.begin")
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private var didAllowInitialNavigation = false

        @MainActor
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            if !didAllowInitialNavigation {
                didAllowInitialNavigation = true
                decisionHandler(.allow)
                return
            }

            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
        }

        @MainActor
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard StartupProbe.isEnabled else { return }
            webView.evaluateJavaScript(
                "new Promise(resolve => requestAnimationFrame(() => resolve(document.body.innerText.length)))"
            ) { _, _ in
                StartupProbe.finish("webview.contentReady")
            }
        }
    }
}
