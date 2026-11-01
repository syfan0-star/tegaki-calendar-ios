// swift-tools-version:5.9
// TegakiKit: the pure (Foundation-only) part of てがきカレンダー.
//
// DayKit    — DayKey / YearMonth (calendar-day arithmetic shared by every other target)
// Holidays  — Japanese national holidays (rule based, 2000–2099)
// Layout    — month page geometry: row heights, cell rects, all-day lanes, chips, hit testing
// InkModel  — InkPage / InkStroke, CRDT merge, JSON codec, LZFSE compression
// Access    — subscription plans, the access state machine, cache rules, paywall words and URLs
//             (M5; Foundation only, depends on nothing else, not even DayKit)
// KitChecks — an executable that re-runs the key checks on a Mac without Xcode (XCTest is not
//             shipped with the Command Line Tools), see docs/M2_CONTRACT.md §0 and §8.
//
// The compatibility test with 1.0 (K-7, docs/M7A_CONTRACT.md §1.4; none of these is a product, so
// the app never links them):
// Compat10       — the frozen copy of the 1.0 InkModel (commit a21e469) with every type renamed
//                  …V10, plus LedgerV10 / LayoutFactsV10 and Checks/Compat10Checks.swift. Foundation,
//                  CoreGraphics and Compression only: it must not depend on any TegakiKit module, or
//                  the changes of a new version would flow into the copy. Nobody edits the copy;
//                  tools/compat10/freeze.py --check proves it is what a21e469 gives.
// CompatFixtures — writes K's golden fixtures (Tests/Fixtures/compat11) with the new code.
// Compat10Tests  — XCTest of the two above (and of the new code against the copy).
//
// `import Layout` (or `import Holidays`) re-exports DayKit, so app code only needs the three
// products named in the contract.
import PackageDescription

let package = Package(
    name: "TegakiKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DayKit", targets: ["DayKit"]),
        .library(name: "Layout", targets: ["Layout"]),
        .library(name: "Holidays", targets: ["Holidays"]),
        .library(name: "InkModel", targets: ["InkModel"]),
        .library(name: "Access", targets: ["Access"]),
    ],
    targets: [
        .target(name: "DayKit"),
        .target(name: "Holidays", dependencies: ["DayKit"]),
        .target(name: "Layout", dependencies: ["DayKit", "Holidays"]),
        .target(name: "InkModel", dependencies: ["Layout"]),
        .target(name: "Access"),
        .target(name: "Compat10", path: "Tests/Compat10",
                exclude: ["FROZEN.sha256", "ORIGIN.sha256", "ORIGIN.ranges"]),
        .target(name: "CompatFixtures", dependencies: ["InkModel", "Layout"], path: "Tests/CompatFixtures"),
        .executableTarget(name: "KitChecks", dependencies: ["Layout", "Holidays", "InkModel", "Access", "Compat10", "CompatFixtures"]),
        .testTarget(name: "LayoutTests", dependencies: ["Layout"]),
        .testTarget(name: "HolidaysTests", dependencies: ["Holidays", "Layout"]),
        .testTarget(name: "InkModelTests", dependencies: ["InkModel"]),
        .testTarget(name: "AccessTests", dependencies: ["Access"]),
        .testTarget(name: "Compat10Tests", dependencies: ["Compat10", "CompatFixtures", "InkModel", "Layout"], path: "Tests/Compat10Tests"),
    ],
    swiftLanguageVersions: [.v5]
)
