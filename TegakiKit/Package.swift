// swift-tools-version:5.9
// TegakiKit: the pure (Foundation-only) part of てがきカレンダー.
//
// DayKit    — DayKey / YearMonth (calendar-day arithmetic shared by every other target)
// Holidays  — Japanese national holidays (rule based, 2000–2099)
// Layout    — month page geometry: row heights, cell rects, all-day lanes, chips, hit testing
// InkModel  — InkPage / InkStroke, CRDT merge, JSON codec, LZFSE compression
// KitChecks — an executable that re-runs the key checks on a Mac without Xcode (XCTest is not
//             shipped with the Command Line Tools), see docs/M2_CONTRACT.md §0 and §8.
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
    ],
    targets: [
        .target(name: "DayKit"),
        .target(name: "Holidays", dependencies: ["DayKit"]),
        .target(name: "Layout", dependencies: ["DayKit", "Holidays"]),
        .target(name: "InkModel", dependencies: ["Layout"]),
        .executableTarget(name: "KitChecks", dependencies: ["Layout", "Holidays", "InkModel"]),
        .testTarget(name: "LayoutTests", dependencies: ["Layout"]),
        .testTarget(name: "HolidaysTests", dependencies: ["Holidays", "Layout"]),
        .testTarget(name: "InkModelTests", dependencies: ["InkModel"]),
    ],
    swiftLanguageVersions: [.v5]
)
