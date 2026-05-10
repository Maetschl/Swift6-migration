// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SharedKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Extensions", targets: ["Extensions"]),
        .library(name: "Models", targets: ["Models"]),
    ],
    targets: [
        .target(name: "DesignSystem"),
        .target(name: "Extensions"),
        .target(name: "Models"),
    ]
)
