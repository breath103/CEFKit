// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CEFView",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "CEFView", targets: ["CEFView"]),
    ],
    targets: [
        // Prebuilt Chromium Embedded Framework, downloaded as XCFramework.
        // For now points at the local artifacts/ output; switch to a remote URL
        // + checksum in Phase 6 when we publish a GitHub release.
        .binaryTarget(
            name: "CCEF",
            path: "artifacts/CEF.xcframework"
        ),

        // CEF's libcef_dll wrapper. Vendored from the CEF binary distribution
        // (BSD-licensed). Compiled in-tree on the consumer machine.
        .target(
            name: "CEFWrapper",
            path: "Sources/CEFWrapper",
            exclude: [
                "libcef_dll/CMakeLists.txt",
            ],
            sources: ["libcef_dll"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("."),
                .define("__STDC_CONSTANT_MACROS"),
                .define("__STDC_FORMAT_MACROS"),
                .define("USING_CEF_SHARED"),
                .define("WRAPPING_CEF_SHARED"),
                .unsafeFlags(["-Wno-undefined-var-template", "-Wno-deprecated-declarations"]),
            ]
        ),

        // Obj-C++ glue: owns CefBrowser, implements CefClient handlers,
        // exposes a thin Obj-C surface that Swift can import.
        .target(
            name: "CEFViewObjC",
            dependencies: ["CEFWrapper"],
            path: "Sources/CEFViewObjC",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("../CEFWrapper"),
                .define("__STDC_CONSTANT_MACROS"),
                .define("__STDC_FORMAT_MACROS"),
                .define("USING_CEF_SHARED"),
            ]
        ),

        // Public Swift API: CEFView (NSView) + SwiftUI representable.
        .target(
            name: "CEFView",
            dependencies: ["CEFViewObjC", "CCEF"],
            path: "Sources/CEFView"
        ),

        .testTarget(
            name: "CEFViewTests",
            dependencies: ["CEFView"],
            path: "Tests/CEFViewTests"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
