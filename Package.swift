// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "z0d1akReports",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(
            name: "z0d1akReports",
            targets: ["z0d1akReports"]
        ),
    ],
    targets: [
        .target(
            name: "z0d1akReportsCore"
        ),
        .executableTarget(
            name: "z0d1akReports",
            dependencies: ["z0d1akReportsCore"]
        ),
        .testTarget(
            name: "z0d1akReportsTests",
            dependencies: ["z0d1akReportsCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
