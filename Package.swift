// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CEFKit",
    platforms: [.macOS(.v12)],
    products: [
        // Full surface for the host app — links Chromium Embedded Framework.
        .library(name: "CEFKit", targets: ["CEFKit"]),
        // Minimal surface for helper sub-process executables. Does NOT pull in
        // the CCEF binary framework, so SPM/clang doesn't bake a host-shaped
        // @executable_path/../Frameworks/... load command into the helper.
        // The helper dlopens the framework at runtime via CefScopedLibraryLoader.
        .library(name: "CEFKitHelper", targets: ["CEFKitHelper"]),
    ],
    targets: [
        // Prebuilt Chromium Embedded Framework, distributed as an XCFramework
        // attached to a GitHub Release. SPM downloads + caches it on resolution.
        // CEF 144.0.28+ga64d412+chromium-144.0.7559.255 (arm64 only).
        .binaryTarget(
            name: "CCEF",
            url: "https://github.com/breath103/CEFKit/releases/download/v0.1.0/CEF.xcframework.zip",
            checksum: "a73c43f8e4ad477c12d3e47cf93a1d0791a688f6e28acd6c010469bc58ecb5e1"
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

        // Public Swift API: re-exports + sugar (typed/async evaluateJavaScript,
        // CEFConfiguration convenience init). Marquee type is CEFWebView.
        .target(
            name: "CEFKit",
            dependencies: ["CEFViewObjC", "CCEF"],
            path: "Sources/CEFKit"
        ),

        // Helper sub-process facade — no CCEF dep.
        .target(
            name: "CEFKitHelper",
            dependencies: ["CEFViewObjC"],
            path: "Sources/CEFKitHelper"
        ),

        .testTarget(
            name: "CEFKitTests",
            dependencies: ["CEFKit"],
            path: "Tests/CEFKitTests"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
