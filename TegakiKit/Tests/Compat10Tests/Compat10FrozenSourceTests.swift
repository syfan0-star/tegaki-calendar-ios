import Foundation
import XCTest
import CompatFixtures

/// The frozen copy of the 1.0 InkModel is never edited (M7A_CONTRACT §1.4): every copy has the digest
/// written in FROZEN.sha256 (the copies only; Checks/ is not frozen), and every copy is listed there.
/// CI's step "Frozen 1.0 copy" runs `shasum -a 256 -c FROZEN.sha256` on the same file.
final class Compat10FrozenSourceTests: XCTestCase {
    func testFrozenFilesMatchTheirDigests() throws {
        let frozen = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Compat10Tests/
            .deletingLastPathComponent()   // Tests/
            .appendingPathComponent("Compat10", isDirectory: true)
        let text = try String(contentsOf: frozen.appendingPathComponent("FROZEN.sha256"), encoding: .utf8)
        let lines = text.split(separator: "\n").map { $0.split(separator: " ", omittingEmptySubsequences: true).map(String.init) }
        XCTAssertEqual(lines.count, 11, "the 9 mechanical copies, LedgerV10.swift and LayoutFactsV10.swift")
        for line in lines {
            XCTAssertEqual(line.count, 2, "\(line): <sha256>  <file>")
            guard line.count == 2 else { continue }
            let data = try Data(contentsOf: frozen.appendingPathComponent(line[1]))
            XCTAssertEqual(CompatFixtures.sha256Hex(data), line[0], "\(line[1]) changed after it was frozen")
        }
        let copies = try FileManager.default.contentsOfDirectory(atPath: frozen.path).filter { $0.hasSuffix(".swift") }.sorted()
        XCTAssertEqual(copies, lines.compactMap(\.last).sorted(), "every copy (Checks/ aside) is in FROZEN.sha256")
        XCTAssertFalse(lines.contains { $0.last?.hasPrefix("Checks") == true }, "Checks/ is not frozen")
    }
}
