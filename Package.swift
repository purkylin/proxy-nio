// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var targets: [PackageDescription.Target] = [
    .target(name: "proxy-nio",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log")]),
    .target(name: "http",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),]),
    .target(name: "Run", dependencies: [
                "proxy-nio",
                .product(name: "Crypto", package: "swift-crypto"),]),
    .testTarget(name: "proxy-nioTests", dependencies: ["proxy-nio"]),
]

let package = Package(
    name: "proxy-nio",
    platforms: [.macOS("10.15")],
    products: [
        .library(name: "proxy-nio", targets: ["proxy-nio"]),
        .library(name: "http", targets: ["http"]),
        .executable(name: "Run", targets: ["Run"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.22.1"),
        .package(url: "https://github.com/apple/swift-log", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-crypto", from: "1.1.2"),
        
    ],
    targets: targets
)
