// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ContentBlockerConverter",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "ContentBlockerConverter",
            type: .static,
            targets: ["ContentBlockerConverter", "ContentBlockerEngine"]),
        .executable(
            name: "ConverterTool",
            targets: ["CommandLineWrapper"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/gumob/PunycodeSwift.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.4.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "CommandLineWrapper",
            dependencies: ["ContentBlockerConverter", "Shared", "ArgumentParser"]),
        .target(
            name: "ContentBlockerConverter",
            dependencies: ["Punnycode", "Shared"]),
        .target(
            name: "ContentBlockerEngine",
            dependencies: ["ContentBlockerConverter", "Shared"]),
        .target(
            name: "Shared"),
        .testTarget(
            name: "ContentBlockerConverterTests",
            dependencies: ["ContentBlockerConverter"]),
        .testTarget(
            name: "ContentBlockerEngineTests",
            dependencies: ["ContentBlockerEngine"]
        )
    ]
)
