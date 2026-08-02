// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Voice",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Voice", targets: ["Voice"])
    ],
    targets: [
        .executableTarget(
            name: "Voice",
            dependencies: [],
            path: "Sources/Voice",
            resources: [.process("Assets.xcassets")]
        ),
        .testTarget(
            name: "VoiceTests",
            dependencies: ["Voice"],
            path: "Tests/VoiceTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
