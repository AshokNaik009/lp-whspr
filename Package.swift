// swift-tools-version:5.9
// Platform-independent core logic (Shared/Core), unit-tested with `swift test` on macOS and Linux.
// The iOS app itself is built from project.yml with XcodeGen.
import PackageDescription

let package = Package(
    name: "LeapCore",
    products: [.library(name: "LeapCore", targets: ["LeapCore"])],
    targets: [
        .target(name: "LeapCore", path: "Shared/Core"),
        .testTarget(name: "LeapCoreTests", dependencies: ["LeapCore"], path: "Tests/LeapCoreTests"),
    ]
)
