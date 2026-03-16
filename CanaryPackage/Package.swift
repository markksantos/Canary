// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CanaryPackage",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CanaryEngine", targets: ["CanaryEngine"]),
        .library(name: "CanaryUI", targets: ["CanaryUI"]),
    ],
    targets: [
        .target(
            name: "CanaryEngine",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .target(
            name: "CanaryUI",
            dependencies: ["CanaryEngine"]
        ),
        .testTarget(
            name: "CanaryEngineTests",
            dependencies: ["CanaryEngine"]
        ),
    ]
)
