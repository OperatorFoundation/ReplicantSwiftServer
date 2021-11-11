// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReplicantSwiftServer",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(name: "ReplicantSwiftServerCore", targets: ["ReplicantSwiftServerCore"]),
        .executable(name: "ReplicantSwiftServer", targets: ["ReplicantSwiftServer"]),
        .executable(name: "PacketCapture", targets: ["PacketCapture"])
    ],
    dependencies: [
        .package(url: "https://github.com/OperatorFoundation/Flower.git", from: "2.0.2"),
        .package(url: "https://github.com/OperatorFoundation/InternetProtocols.git", from:"2.1.1"),
        .package(url: "https://github.com/OperatorFoundation/Transport.git", from: "2.3.9"),
        .package(url: "https://github.com/OperatorFoundation/Transmission.git", from: "1.0.4"),
        .package(url: "https://github.com/OperatorFoundation/TransmissionTransport.git", from: "1.0.0"),
        .package(url: "https://github.com/OperatorFoundation/Tun.git", from: "0.1.0"),
        .package(url: "https://github.com/OperatorFoundation/ReplicantSwift.git", from: "0.13.6"),
        .package(url: "https://github.com/OperatorFoundation/Routing.git", from:"0.0.9"),
        .package(url: "https://github.com/OperatorFoundation/SwiftHexTools.git", from:"1.2.4"),
        .package(url: "https://github.com/OperatorFoundation/Gardener.git", from:"0.0.48"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.4.4"),
        .package(url: "https://github.com/OperatorFoundation/SwiftQueue.git", from: "0.1.2"),
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
        "InternetProtocols",
        "Routing",
        "SwiftHexTools",
        "TransmissionTransport",
        .product(name: "Transmission", package: "Transmission")
            ]
        ),
        .target(
            name: "ReplicantSwiftServer",
            dependencies: ["ReplicantSwiftServerCore"]),
        .target(
            name: "PacketCapture",
            dependencies: ["Gardener", "SwiftQueue", .product(name: "ArgumentParser", package: "swift-argument-parser")]),
        .testTarget(
            name: "ReplicantSwiftServerTests",
            dependencies: ["ReplicantSwiftServerCore"]),
    ],
    swiftLanguageVersions: [.v5]
)
