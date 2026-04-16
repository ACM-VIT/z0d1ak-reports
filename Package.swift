// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "z0d1akReports",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(
            name: "z0d1ak",
            targets: ["z0d1ak"]
        ),
    ],
    targets: [
        .target(
            name: "z0d1akReportsCore"
        ),
        .executableTarget(
            name: "z0d1ak",
            dependencies: ["z0d1akReportsCore"],
            path: "Sources/z0d1akReports"
        ),
        .testTarget(
            name: "z0d1akReportsTests",
            dependencies: ["z0d1akReportsCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
