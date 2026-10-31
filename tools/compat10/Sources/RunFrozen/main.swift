import Foundation

// RunFrozen <fixtures folder>: Compat10Checks on the frozen copy of the 1.0 InkModel (see Package.swift).

guard CommandLine.arguments.count == 2 else {
    print("usage: RunFrozen <fixtures folder>")
    exit(2)
}
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let result = Compat10Checks.run(fixtures: folder) { name, ok in
    if !ok { print("FAIL: \(name)") }
}
print("compat10: \(result.passed + result.failed) checks, \(result.failed) failed")
exit(result.failed == 0 ? 0 : 1)
