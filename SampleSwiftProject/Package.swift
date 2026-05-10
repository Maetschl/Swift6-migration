// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SampleSwiftProject",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "AppCore", targets: ["AppCore"]),
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "UI", targets: ["UI"]),
        .library(name: "Analytics", targets: ["Analytics"]),
        .library(name: "Shared", targets: ["Shared"]),
    ],
    targets: [
        .target(name: "AppCore", dependencies: ["Networking", "Shared"]),
        .target(name: "Networking", dependencies: ["Shared"]),
        .target(name: "UI", dependencies: ["AppCore"]),
        .target(name: "Analytics", dependencies: ["Shared"]),
        .target(name: "Shared"),
    ]
)
