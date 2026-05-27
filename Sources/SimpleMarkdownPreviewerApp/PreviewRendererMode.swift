import Foundation

enum PreviewRendererMode: Equatable {
    case native
    case webview

    static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> PreviewRendererMode {
        switch environment["CUNEIFORM_RENDERER"]?.lowercased() {
        case "webview":
            return .webview
        case "native":
            return .native
        default:
            return .native
        }
    }
}
