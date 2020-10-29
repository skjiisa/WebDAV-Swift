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
        .package(url: "https://github.com/yahoojapan/SwiftyXMLParser.git", .upToNextMajor(from: "5.2.1"))
    ],
    targets: [
        .target(
            name: "WebDAV",
            dependencies: ["SwiftyXMLParser"]),
        .testTarget(
            name: "WebDAVTests",
            dependencies: ["WebDAV"]),
    ]
)
