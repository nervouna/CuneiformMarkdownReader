// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Cuneiform",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Cuneiform", targets: ["SimpleMarkdownPreviewerApp"]),
        .library(name: "SimpleMarkdownPreviewerCore", targets: ["SimpleMarkdownPreviewerCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", exact: "0.8.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", exact: "2.4.1")
    ],
    targets: [
        .target(
            name: "SimpleMarkdownPreviewerCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            resources: [
                .process("Assets")
            ]
        ),
        .executableTarget(
            name: "SimpleMarkdownPreviewerApp",
            dependencies: [
                "SimpleMarkdownPreviewerCore",
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ]
        ),
        .testTarget(
            name: "SimpleMarkdownPreviewerCoreTests",
            dependencies: ["SimpleMarkdownPreviewerCore"]
        )
    ]
)
