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
            targets: ["ContentBlockerConverter", "FilterEngine"]),
        .executable(
            name: "ConverterTool",
            targets: ["CommandLineWrapper"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/gumob/PunycodeSwift.git", .exact("3.0.0")),
        .package(url: "https://github.com/apple/swift-argument-parser", .exact("1.5.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "CommandLineWrapper",
            dependencies: ["ContentBlockerConverter", "ArgumentParser"]),
        .target(
            name: "ContentBlockerConverter",
            dependencies: ["Punycode"]),
        .target(
            name: "FilterEngine",
            dependencies: ["ContentBlockerConverter"]),
        .testTarget(
            name: "ContentBlockerConverterTests",
            dependencies: ["ContentBlockerConverter"]),
        .testTarget(
            name: "FilterEngineTests",
            dependencies: ["FilterEngine"])
    ]
)
