// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BitefluxCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "BitefluxCore", targets: ["BitefluxCore"]),
    ],
    targets: [
        .target(name: "BitefluxCore"),
        .testTarget(name: "BitefluxCoreTests", dependencies: ["BitefluxCore"]),
    ]
)
