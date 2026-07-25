// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Workbench",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "Workbench", targets: ["Workbench"])
    ],
    targets: [
        .executableTarget(
            name: "Workbench",
            path: "Sources/Workbench"
        ),
        .testTarget(
            name: "WorkbenchTests",
            dependencies: ["Workbench"],
            path: "tests/WorkbenchTests"
        )
    ]
)
