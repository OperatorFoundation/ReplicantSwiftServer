// swift-tools-version:5.3
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
        .executable(name: "ReplicantSwiftServer", targets: ["ReplicantSwiftServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/OperatorFoundation/Flow.git", from: "0.2.3"),
        .package(url: "https://github.com/OperatorFoundation/Flower.git", from: "0.1.1"),
        .package(url: "https://github.com/OperatorFoundation/InternetProtocols.git", from:"1.1.0"),
        .package(url: "https://github.com/OperatorFoundation/Transport.git", from: "2.3.0"),
        .package(url: "https://github.com/OperatorFoundation/Transmission.git", from: "0.1.12"),
        .package(url: "https://github.com/OperatorFoundation/Tun.git", from: "0.0.5"),
        .package(url: "https://github.com/OperatorFoundation/ReplicantSwift.git", from: "0.8.3"),
        .package(url: "https://github.com/OperatorFoundation/Routing.git", from:"0.0.4"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.

        .target(
            name: "ReplicantSwiftServerCore",
            dependencies: ["ReplicantSwift", "Transport", "Flower", "Tun", "Flow", "InternetProtocols", "Routing",
               .product(name: "TransmissionLinux", package: "Transmission", condition: .when(platforms: [.linux]))
            ]
        ),
        .target(
            name: "ReplicantSwiftServer",
            dependencies: ["ReplicantSwiftServerCore"]),
        .testTarget(
            name: "ReplicantSwiftServerTests",
            dependencies: ["ReplicantSwiftServerCore"]),
    ],
    swiftLanguageVersions: [.v5]
)
