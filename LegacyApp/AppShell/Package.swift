// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppShell",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "AppEntry", targets: ["AppEntry"]),
        .library(name: "AppCoordinator", targets: ["AppCoordinator"]),
    ],
    targets: [
        .target(name: "AppEntry", dependencies: ["AppCoordinator"]),
        .target(name: "AppCoordinator"),
    ]
)
