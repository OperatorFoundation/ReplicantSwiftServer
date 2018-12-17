// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReplicantSwiftServer",
    dependencies: [
        .package(url: "https://github.com/OperatorFoundation/Transport.git", from: "0.1.0"),
        .package(url: "https://github.com/OperatorFoundation/Shapeshifter-Swift-Transports.git", from: "0.3.2"),
        .package(url: "https://github.com/Bouke/INI", from: "1.0.2")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "ReplicantSwiftServer",
            dependencies: ["Replicant", "Transport"]),
        .testTarget(
            name: "ReplicantSwiftServerTests",
            dependencies: ["ReplicantSwiftServer", "INI"]),
    ]
)
