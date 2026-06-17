// swift-tools-version: 5.9
// HelloCEF — a standalone consumer of the CEFKit package.
// Lives inside the CEFKit repo as a reference; structurally identical to
// what a real third-party consumer would write.

import PackageDescription

let package = Package(
    name: "HelloCEF",
    platforms: [.macOS(.v12)],
    dependencies: [
        // In a real consumer this would be:
        //   .package(url: "https://github.com/breath103/CEFKit.git", from: "0.1.0"),
        // We pin name: explicitly because the parent directory is currently
        // "CEF" (legacy) — once renamed to "CEFKit" the name: arg can be dropped.
        .package(name: "CEFKit", path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "HelloCEF",
            dependencies: [.product(name: "CEFKit", package: "CEFKit")],
            path: "Sources/HelloCEF"
        ),
        .executableTarget(
            name: "HelloCEFHelper",
            dependencies: [.product(name: "CEFKitHelper", package: "CEFKit")],
            path: "Sources/HelloCEFHelper"
        ),
    ]
)
