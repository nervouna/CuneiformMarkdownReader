import Foundation

public enum PreviewError: Error, Equatable, LocalizedError {
    case unsupportedFileType(String)
    case unreadableFile(URL)
    case unsafeResource(String)
    case renderFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let ext):
            "不支持的文件类型：\(ext)"
        case .unreadableFile:
            "无法读取该文件。"
        case .unsafeResource(let reason):
            "已拦截不安全资源：\(reason)"
        case .renderFailed(let reason):
            "Markdown 渲染失败：\(reason)"
        }
    }
}
