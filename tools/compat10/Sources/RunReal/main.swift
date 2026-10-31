import Foundation
import InkModel

// RunReal <fixtures folder>: Compat10Checks on the real 1.0 InkModel (see Package.swift).

guard CommandLine.arguments.count == 2 else {
    print("usage: RunReal <fixtures folder>")
    exit(2)
}
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let result = Compat10Checks.run(fixtures: folder) { name, ok in
    if !ok { print("FAIL: \(name)") }
}
print("compat10: \(result.passed + result.failed) checks, \(result.failed) failed")

// Only here, outside the count above: the streamed reader of 1.0 (`InkImport`, not part of the copy)
// reads the 1.1 export exactly as `AppExport.parse` does.
var importFailures = 0
if let data = try? Data(contentsOf: folder.appendingPathComponent(Compat10Checks.export11)),
   let whole = try? AppExport.parse(json: JSONValue.parse(data)),
   case .app(let streamed, let skipped)? = try? InkImport.parse(data) {
    if streamed != whole || skipped != 0 {
        print("FAIL: \(Compat10Checks.export11): 1.0's InkImport reads what AppExport.parse reads")
        importFailures += 1
    }
    let outcome = InkImport.pages(.app(streamed, skipped: skipped))
    if outcome.pages != whole.pages || outcome.pageCount != 3 || !outcome.isAppExport {
        print("FAIL: \(Compat10Checks.export11): 1.0's import would merge the 3 pages")
        importFailures += 1
    }
} else {
    print("FAIL: \(Compat10Checks.export11): 1.0's InkImport reads it")
    importFailures += 1
}
print("compat10 (real only): InkImport 2 checks, \(importFailures) failed")
exit(result.failed == 0 && importFailures == 0 ? 0 : 1)
