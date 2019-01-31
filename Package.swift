// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReplicantSwiftServer",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(name: "TunObjC", targets: ["TunObjC"]),
        .library(name: "ReplicantSwiftServerCore", targets: ["ReplicantSwiftServerCore"]),
        //.executable(name: "ReplicantSwiftServer", targets: ["ReplicantSwiftServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/OperatorFoundation/Transport.git", from: "0.1.0"),
        .package(url: "https://github.com/OperatorFoundation/Shapeshifter-Swift-Transports.git", from: "0.3.10"),
        .package(url: "https://github.com/OperatorFoundation/Flower.git", from: "0.0.6")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "TunObjC",
            dependencies: []),
        .target(
            name: "ReplicantSwiftServerCore",
            dependencies: ["Replicant", "Transport", "Flower", "TunObjC"]),
        .target(
            name: "ReplicantSwiftServer",
            dependencies: ["ReplicantSwiftServerCore"]),
        .testTarget(
            name: "ReplicantSwiftServerTests",
            dependencies: ["ReplicantSwiftServerCore"]),
    ]
)
