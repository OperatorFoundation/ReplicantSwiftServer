// swift-tools-version:5.5
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
        .package(url: "https://github.com/OperatorFoundation/Flower.git", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/InternetProtocols.git", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Transmission.git", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/TransmissionTransport.git", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Tun.git", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/ReplicantSwift.git", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Routing.git", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/SwiftHexTools.git", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Gardener.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.2"),
        .package(url: "https://github.com/OperatorFoundation/SwiftQueue.git", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Net.git", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.

        .target(
            name: "ReplicantSwiftServerCore",
            dependencies: [
                "ReplicantSwift",
                "Flower",
                "Tun",
                "InternetProtocols",
                "Routing",
                "SwiftHexTools",
                "TransmissionTransport",
                "Net",
                "Transmission"
            ]
        ),
        .executableTarget(
            name: "ReplicantSwiftServer",
            dependencies: ["ReplicantSwiftServerCore", .product(name: "ArgumentParser", package: "swift-argument-parser")]),
        .executableTarget(
            name: "PacketCapture",
            dependencies: ["Gardener", "SwiftQueue", .product(name: "ArgumentParser", package: "swift-argument-parser")]),
        .testTarget(
            name: "ReplicantSwiftServerTests",
            dependencies: ["ReplicantSwiftServerCore"]),
    ],
    swiftLanguageVersions: [.v5]
)
