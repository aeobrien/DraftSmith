// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "DraftSmith",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DraftSmith", targets: ["DraftSmith"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.15.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "2.30.3"),
    ],
    targets: [
        .executableTarget(
            name: "DraftSmith",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            ],
            path: "Sources/DraftSmith"
        ),
        .testTarget(
            name: "DraftSmithTests",
            dependencies: ["DraftSmith"],
            path: "Tests/DraftSmithTests"
        ),
    ]
)
