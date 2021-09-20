// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReplicantSwiftServer",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(name: "ReplicantSwiftServerCore", targets: ["ReplicantSwiftServerCore"]),
        .executable(name: "ReplicantSwiftServer", targets: ["ReplicantSwiftServer"]),
        .executable(name: "PacketCapture", targets: ["PacketCapture"])
    ],
    dependencies: [
        .package(url: "https://github.com/OperatorFoundation/Flow.git", from: "0.3.1"),
        .package(url: "https://github.com/OperatorFoundation/Flower.git", from: "0.1.17"),
        .package(url: "https://github.com/OperatorFoundation/InternetProtocols.git", from:"1.1.4"),
        .package(url: "https://github.com/OperatorFoundation/Transport.git", from: "2.3.7"),
        .package(url: "https://github.com/OperatorFoundation/TransmissionLinux.git", from: "0.3.5"),
        .package(url: "https://github.com/OperatorFoundation/TransmissionTransport.git", from: "0.2.9"),
        .package(url: "https://github.com/OperatorFoundation/Tun.git", from: "0.0.12"),
        .package(url: "https://github.com/OperatorFoundation/ReplicantSwift.git", from: "0.10.3"),
        .package(url: "https://github.com/OperatorFoundation/Routing.git", from:"0.0.9"),
        .package(url: "https://github.com/OperatorFoundation/SwiftHexTools.git", from:"1.2.3"),
        .package(url: "https://github.com/OperatorFoundation/Gardener.git", from:"0.0.47"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.4.4"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.

        .target(
            name: "ReplicantSwiftServerCore",
            dependencies: [
        "ReplicantSwift",
        "Transport",
        "Flower",
        "Tun",
        "Flow",
        "InternetProtocols",
        "Routing",
        "SwiftHexTools",
        "TransmissionTransport",
        .product(name: "TransmissionLinux", package: "TransmissionLinux")
            ]
        ),
        .target(
            name: "ReplicantSwiftServer",
            dependencies: ["ReplicantSwiftServerCore"]),
        .target(
            name: "PacketCapture",
            dependencies: ["Gardener", "ReplicantSwiftServer", "ReplicantSwiftServerCore"]),
        .testTarget(
            name: "ReplicantSwiftServerTests",
            dependencies: ["ReplicantSwiftServerCore"]),
    ],
    swiftLanguageVersions: [.v5]
)
