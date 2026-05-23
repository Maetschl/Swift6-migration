// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Swift6MigrationAnalyzer",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "Swift6MigrationAnalyzer",
            targets: ["Swift6MigrationAnalyzer"]
        ),
        .executable(
            name: "Swift6MigrationAnalyzerMacApp",
            targets: ["Swift6MigrationAnalyzerMacApp"]
        )
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
        .executableTarget(
            name: "Swift6MigrationAnalyzerMacApp",
            dependencies: [
                "Swift6MigrationAnalyzerCore"
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
