// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Workbench",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "Workbench", targets: ["WorkbenchApp"]),
        .library(name: "WorkbenchCore", targets: ["WorkbenchCore"]),
        .library(name: "WorkbenchAgents", targets: ["WorkbenchAgents"]),
        .library(name: "WorkbenchUI", targets: ["WorkbenchUI"])
    ],
    targets: [
        .executableTarget(
            name: "WorkbenchApp",
            dependencies: ["WorkbenchCore", "WorkbenchAgents", "WorkbenchUI"],
            path: "Sources/WorkbenchApp"
        ),
        .target(
            name: "WorkbenchCore",
            path: "Sources/WorkbenchCore"
        ),
        .target(
            name: "WorkbenchAgents",
            dependencies: ["WorkbenchCore"],
            path: "Sources/WorkbenchAgents"
        ),
        .target(
            name: "WorkbenchUI",
            dependencies: ["WorkbenchCore", "WorkbenchAgents"],
            path: "Sources/WorkbenchUI"
        ),
        .testTarget(
            name: "WorkbenchTests",
            dependencies: ["WorkbenchCore", "WorkbenchAgents", "WorkbenchUI"],
            path: "tests/WorkbenchTests"
        )
    ]
)
