// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ContentBlockerConverter",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "ContentBlockerConverter",
            targets: ["ContentBlockerConverter", "FilterEngine"]),
        .executable(
            name: "ConverterTool",
            targets: ["CommandLineWrapper"]),
        .executable(
            name: "FileLockTester",
            targets: ["FileLockTester"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/gumob/PunycodeSwift.git", .exact("3.0.0")),
        .package(url: "https://github.com/apple/swift-argument-parser", .exact("1.5.0")),
        .package(url: "https://github.com/apple/swift-collections.git", .exact("1.1.4"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .executableTarget(
            name: "CommandLineWrapper",
            dependencies: [
                "FilterEngine",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        .target(
            name: "ContentBlockerConverter",
            dependencies: [
                .product(name: "Punycode", package: "PunycodeSwift")
            ]),
        .target(
            name: "FilterEngine",
            dependencies: [
                "ContentBlockerConverter",
                .product(name: "Collections", package: "swift-collections")
            ]),
        .executableTarget(
            name: "FileLockTester",
            dependencies: [ "FilterEngine" ]),
        .testTarget(
            name: "ContentBlockerConverterTests",
            dependencies: ["ContentBlockerConverter"],
            resources: [.copy("Resources/test-rules.txt")]),
        .testTarget(
            name: "FilterEngineTests",
            dependencies: ["FilterEngine"],
            resources: [
                .copy("Resources/advanced-rules.txt"),
                .copy("Resources/reference-rules.bin"),
                .copy("Resources/reference-engine.bin")
            ])
    ]
)
