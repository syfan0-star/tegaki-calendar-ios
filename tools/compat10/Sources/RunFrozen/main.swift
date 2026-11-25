import Foundation

// RunFrozen <fixtures folder>: Compat10Checks on the frozen copy of the 1.0 InkModel (see Package.swift).

guard CommandLine.arguments.count == 2 else {
    print("usage: RunFrozen <fixtures folder>")
    exit(2)
}
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let fixtures = Compat10Checks.run(fixtures: folder) { name, ok in
    if !ok { print("FAIL: \(name)") }
}
// 1.4.2 (docs/R1_4_2_CONTRACT.md §5.3, 0f-24): strokes in the new pen colours, made in code (outside `run`, whose count is
// KitChecks' too); one N for both.
let colours = Compat10Checks.runColours { name, ok in
    if !ok { print("FAIL: \(name)") }
}
let result = (passed: fixtures.passed + colours.passed, failed: fixtures.failed + colours.failed)
print("compat10: \(result.passed + result.failed) checks, \(result.failed) failed")
exit(result.failed == 0 ? 0 : 1)
