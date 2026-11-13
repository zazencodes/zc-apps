// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PrettyDraw",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PrettyDrawKit", swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "PrettyDraw", dependencies: ["PrettyDrawKit"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "pretty-draw-render", dependencies: ["PrettyDrawKit"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "PrettyDrawKitTests", dependencies: ["PrettyDrawKit"], swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
