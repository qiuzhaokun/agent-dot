// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentDot",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "AgentDotCore", targets: ["AgentDotCore"]),
        .executable(name: "AgentDotTests", targets: ["AgentDotTests"]),
        .executable(name: "dot-hook", targets: ["DotHook"]),
        .executable(name: "AgentDotUpdater", targets: ["AgentDotUpdater"]),
        .executable(name: "AgentDot", targets: ["AgentDotApp"])
    ],
    targets: [
        .target(name: "AgentDotCore"),
        .executableTarget(
            name: "AgentDotTests",
            dependencies: ["AgentDotCore"],
            path: "Tests/AgentDotCoreTests"
        ),
        .executableTarget(name: "DotHook", dependencies: ["AgentDotCore"]),
        .executableTarget(name: "AgentDotUpdater", dependencies: ["AgentDotCore"]),
        .executableTarget(name: "AgentDotApp", dependencies: ["AgentDotCore"])
    ],
    swiftLanguageModes: [.v5]
)
