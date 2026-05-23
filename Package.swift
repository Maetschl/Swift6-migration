// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Swift6MigrationAnalyzer",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "603.0.1"
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            from: "1.5.0"
        )
    ],
    targets: [
        .target(
            name: "Swift6MigrationAnalyzerCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ]
        ),
        .executableTarget(
            name: "swift6-analyzer",
            dependencies: [
                "Swift6MigrationAnalyzerCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "Swift6MigrationAnalyzerTests",
            dependencies: [
                "Swift6MigrationAnalyzerCore"
            ]
        )
    ]
)
