#!/usr/bin/env swift
//
// tests.swift — typed test runner for ChromiumKit.
//
// Runs the HelloChromium example's test targets against the real app. Fetches
// the CEF framework first if vendor/cef/ is missing (one-time ~265MB download).
//
//   scripts/tests.swift            # list subcommands
//   scripts/tests.swift ui         # all UI tests
//   scripts/tests.swift unit       # all unit tests
//   scripts/tests.swift ui --help  # per-subcommand help
//
import Foundation

// MARK: - Paths

let root = URL(fileURLWithPath: #filePath)
    .resolvingSymlinksInPath()
    .deletingLastPathComponent() // scripts/
    .deletingLastPathComponent() // repo root
let project = root.appendingPathComponent("Examples/HelloChromium/HelloChromium.xcodeproj")
let cefFramework = root.appendingPathComponent("vendor/cef/Release/Chromium Embedded Framework.framework")
let fetchScript = root.appendingPathComponent("scripts/fetch-cef.sh")

// MARK: - Process helper

/// Run a command, streaming its output to our terminal, and return its exit code.
@discardableResult
func run(_ launchPath: String, _ arguments: [String], cwd: URL? = nil) -> Int32 {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: launchPath)
    proc.arguments = arguments
    if let cwd { proc.currentDirectoryURL = cwd }
    do {
        try proc.run()
    } catch {
        FileHandle.standardError.write(Data("error: failed to launch \(launchPath): \(error)\n".utf8))
        return 127
    }
    proc.waitUntilExit()
    return proc.terminationStatus
}

/// CEF isn't in git. The Xcode embed step needs the framework on disk — fetch once.
func ensureCEF() -> Int32 {
    if FileManager.default.fileExists(atPath: cefFramework.path) { return 0 }
    print("==> vendor/cef missing — fetching CEF (one-time, ~265MB download)")
    return run("/bin/bash", [fetchScript.path])
}

/// Build + run one test target, optionally narrowed to a `Class` or `Class/method`.
func xcodebuildTest(target: String, filter: String?) -> Int32 {
    if case let code = ensureCEF(), code != 0 { return code }
    let onlyTesting = filter.map { "\(target)/\($0)" } ?? target
    print("==> xcodebuild test (\(onlyTesting))")
    return run("/usr/bin/xcodebuild", [
        "test",
        "-project", project.path,
        "-scheme", "HelloChromium",
        "-destination", "platform=macOS",
        "-only-testing:\(onlyTesting)",
    ])
}

// MARK: - Subcommand model

struct Subcommand {
    let name: String
    let summary: String        // one line, shown in the top-level list
    let usage: String          // argument shape, shown in `<cmd> --help`
    let discussion: String     // longer help body
    let examples: [String]
    let run: (_ args: [String]) -> Int32

    func printHelp() {
        print("""
        \(summary)

        USAGE
          scripts/tests.swift \(name) \(usage)

        \(discussion)

        EXAMPLES
        """)
        for ex in examples { print("  \(ex)") }
    }
}

/// A test subcommand: bare target run, or narrowed by an optional `Class[/method]` arg.
func testSubcommand(
    name: String, target: String, summary: String, suiteHint: String, examples: [String]
) -> Subcommand {
    Subcommand(
        name: name,
        summary: summary,
        usage: "[TestClass[/testMethod]]",
        discussion: """
        Runs the \(target) target. \(suiteHint)

        With no argument the whole target runs. Pass a test-class name to run just
        that class, or Class/method to run a single test.
        """,
        examples: examples
    ) { args in
        // Reject stray flags so typos surface instead of silently running everything.
        let positionals = args.filter { !$0.hasPrefix("-") }
        if let bad = args.first(where: { $0.hasPrefix("-") }) {
            FileHandle.standardError.write(Data("error: unknown option '\(bad)' (try: scripts/tests.swift \(name) --help)\n".utf8))
            return 2
        }
        if positionals.count > 1 {
            FileHandle.standardError.write(Data("error: expected at most one test filter, got \(positionals.count)\n".utf8))
            return 2
        }
        return xcodebuildTest(target: target, filter: positionals.first)
    }
}

let subcommands: [Subcommand] = [
    testSubcommand(
        name: "ui",
        target: "HelloChromiumUITests",
        summary: "Run the XCUITest suite (launches the real app + CEF).",
        suiteHint: "These launch HelloChromium, spin up CEF's multi-process engine, "
            + "load live pages, and drive the UI — so a GUI login session is required.",
        examples: [
            "scripts/tests.swift ui",
            "scripts/tests.swift ui AddressBarUITests",
            "scripts/tests.swift ui AddressBarUITests/testEscapeCancelsEdit",
        ]
    ),
    testSubcommand(
        name: "unit",
        target: "HelloChromiumUnitTests",
        summary: "Run the unit-test target (fast, no UI automation).",
        suiteHint: "Lifecycle/retain-cycle checks that don't drive the app window.",
        examples: [
            "scripts/tests.swift unit",
            "scripts/tests.swift unit ChromiumWebViewLifecycleTests",
        ]
    ),
]

// MARK: - Top-level dispatch

func printTopLevelHelp() {
    print("""
    tests.swift — typed test runner for ChromiumKit.

    USAGE
      scripts/tests.swift <command> [args]

    COMMANDS
    """)
    let width = subcommands.map(\.name.count).max() ?? 0
    for cmd in subcommands {
        let pad = String(repeating: " ", count: width - cmd.name.count)
        print("  \(cmd.name)\(pad)  \(cmd.summary)")
    }
    print("""

    Run 'scripts/tests.swift <command> --help' for details on a command.
    The first run fetches CEF (~265MB) into vendor/cef/; later runs reuse it.
    """)
}

let argv = Array(CommandLine.arguments.dropFirst())

guard let first = argv.first else {
    printTopLevelHelp()
    exit(0)
}

if first == "-h" || first == "--help" || first == "help" {
    // `help` / `help <cmd>` and the bare flags.
    if let target = argv.dropFirst().first, let cmd = subcommands.first(where: { $0.name == target }) {
        cmd.printHelp()
    } else {
        printTopLevelHelp()
    }
    exit(0)
}

guard let cmd = subcommands.first(where: { $0.name == first }) else {
    FileHandle.standardError.write(Data("error: unknown command '\(first)' (try: scripts/tests.swift --help)\n".utf8))
    exit(2)
}

let rest = Array(argv.dropFirst())
if rest.contains("-h") || rest.contains("--help") {
    cmd.printHelp()
    exit(0)
}

exit(cmd.run(rest))
