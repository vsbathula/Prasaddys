// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Prasaddys",
    platforms: [
        .iOS(.v15),     // Minimum iOS version
        .macOS(.v12),   // Minimum macOS version
        .tvOS(.v16)     // Minimum tvOS version
        // .watchOS(.v8) // Add if you need watchOS support
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Prasaddys",
            targets: ["Prasaddys"]),
    ],
    dependencies: [
            // Dependencies declare other packages that this package depends on.
             .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.9.0")),
        ],
    targets: [
            // Targets are the basic building blocks of a package, defining a module or a test suite.
            // Targets can depend on other targets in this package and products from dependencies.
            .target(
                name: "Prasaddys",
                dependencies: ["Alamofire"],
                path: "Sources/prasaddys",
                ),
            .testTarget(
                name: "PrasaddysTests",
                dependencies: ["Prasaddys"])
        ]
)
