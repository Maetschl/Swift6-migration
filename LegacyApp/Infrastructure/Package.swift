// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Infrastructure",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "Logging", targets: ["Logging"]),
    ],
    targets: [
        .target(name: "Networking"),
        .target(name: "Persistence"),
        .target(name: "Logging"),
    ]
)
