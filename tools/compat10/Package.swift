// swift-tools-version:5.9
// The compatibility checks of K-7 against the REAL 1.0 (docs/M7A_CONTRACT.md §1.4, §7.4 compat-v1.0).
//
// RunReal   — Compat10Checks (copied from TegakiKit/Tests/Compat10/Checks) and LedgerV10 (copied from
//             TegakiKit/Tests/Compat10) on the real InkModel / Layout / DayKit of commit
//             a21e4692109e504701b507ad9c695181fdecddfd, checked out at ../../v10 (CI: the second
//             checkout, `path: v10`). Aliases.swift points the 13 V10 names at the real types and
//             builds cellsV10 / memoHeightV10 from the real 1.0 layout engines.
// RunFrozen — the same checks on the frozen copy (all of TegakiKit/Tests/Compat10, LayoutFactsV10.swift
//             included), copied in.
//
// The copies are made by run.sh (Sources/*/Copied-*.swift, ignored by git). Both print
// `compat10: N checks, F failed`; run.sh fails unless the two N are equal, F is 0 for both and
// N ≥ EXPECTED_MIN. AppTests/Real10LedgerTests.swift is not part of this package: CI copies it into
// the 1.0 app's unit tests (v10/Tests/TegakiCalendarTests) and runs it on the simulator.
import PackageDescription

let package = Package(
    name: "Compat10Runner",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../v10/TegakiKit"),
    ],
    targets: [
        .executableTarget(
            name: "RunReal",
            dependencies: [
                .product(name: "InkModel", package: "TegakiKit"),
                .product(name: "Layout", package: "TegakiKit"),
                .product(name: "DayKit", package: "TegakiKit"),
            ],
            path: "Sources/RunReal"
        ),
        .executableTarget(name: "RunFrozen", path: "Sources/RunFrozen"),
    ],
    swiftLanguageVersions: [.v5]
)
