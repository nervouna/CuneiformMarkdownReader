import Foundation

public enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark
}

public struct PreviewPreferences: Equatable {
    public var fontScale: Double
    public var appearanceMode: AppearanceMode

    public init(fontScale: Double = 1.0, appearanceMode: AppearanceMode = .system) {
        self.fontScale = fontScale
        self.appearanceMode = appearanceMode
    }
}
