// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "mac-Taskbar-Thumbnail-Reorder",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "MacTaskbarThumbnailReorder",
            path: "Sources/MacTaskbarThumbnailReorder",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics")
            ]
        )
    ]
)
