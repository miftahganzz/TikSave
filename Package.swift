// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "tiksave",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "tiksave", targets: ["TikSaveCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "TikSaveCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/TikSaveCLI"
        )
    ]
)
