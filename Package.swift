// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WebDAV",
    products: [
        .library(
            name: "WebDAV",
            targets: ["WebDAV"]),
    ],
    dependencies: [
        .package(url: "https://github.com/drmohundro/SWXMLHash.git", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/3lvis/Networking.git", .upToNextMajor(from: "5.1.0"))
    ],
    targets: [
        .target(
            name: "WebDAV",
            dependencies: ["SWXMLHash", "Networking"]),
        .testTarget(
            name: "WebDAVTests",
            dependencies: ["WebDAV"]),
    ]
)
