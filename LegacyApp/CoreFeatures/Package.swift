// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CoreFeatures",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Authentication", targets: ["Authentication"]),
        .library(name: "Dashboard", targets: ["Dashboard"]),
        .library(name: "Settings", targets: ["Settings"]),
    ],
    targets: [
        .target(name: "Authentication"),
        .target(name: "Dashboard"),
        .target(name: "Settings"),
    ]
)
