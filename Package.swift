// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenAISwift",
    platforms: [
        .macOS(.v12), .iOS(.v15), .tvOS(.v15), .watchOS(.v6)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "OpenAISwift",
            targets: ["OpenAISwift"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        
        .package(url: "https://github.com/mgibson707/swift-eventsource.git", .branch("main")),
        //.package(url: "https://github.com/apple/swift-markdown.git", .branch("main")),

    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "OpenAISwift",
            dependencies: [.product(name: "LDSwiftEventSource", package: "swift-eventsource")]),
        .testTarget(
            name: "OpenAISwiftTests",
            dependencies: ["OpenAISwift", .product(name: "LDSwiftEventSource", package: "swift-eventsource")]),
    ]
)
