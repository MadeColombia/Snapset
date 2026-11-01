// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SnapsetUI",
    platforms: [.iOS(.v18)],
    products: [.library(name: "SnapsetUI", targets: ["SnapsetUI"])],
    targets: [
        .target(name: "SnapsetUI"),
        .testTarget(name: "SnapsetUITests", dependencies: ["SnapsetUI"]),
    ]
)
