// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "proxy-nio",
    platforms: [.macOS("10.15")],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
         .library(
             name: "proxy-nio",
             targets: ["proxy-nio"]),
        .executable(name: "Run", targets: ["Run"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.22.1"),
        .package(url: "https://github.com/apple/swift-log", from: "1.4.0"),
        
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
         .target(
             name: "proxy-nio",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log")
            ]),
        .target(
            name: "Run",
            dependencies: [
                "proxy-nio"
            ]),
        .testTarget(
            name: "proxy-nioTests",
            dependencies: ["proxy-nio"]),
    ]
)
