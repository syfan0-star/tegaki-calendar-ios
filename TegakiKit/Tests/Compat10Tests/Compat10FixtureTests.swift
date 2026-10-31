import Foundation
import XCTest
import CompatFixtures

/// K's committed fixtures are exactly what the new code writes (M7A_CONTRACT §1.4, §7.2). With
/// TEGAKI_UPDATE_FIXTURES=1 the test writes them again instead (`CompatFixtures.write(to:)`, the same
/// as `KitChecks --write-compat-fixtures`). Only K's fixtures and digests.json are compared or
/// written; `ledger-*.json` (P) and `screenshot-*.json` (U) are never touched (0-23).
final class Compat10FixtureTests: XCTestCase {
    func testFixturesAreWhatTheNewCodeWrites() throws {
        let folder = CompatFixtures.committedFolder
        if ProcessInfo.processInfo.environment["TEGAKI_UPDATE_FIXTURES"] == "1" {
            let results = try CompatFixtures.write(to: folder)
            for (name, result) in results { print("Compat10FixtureTests: \(result.rawValue) \(name)") }
            return
        }
        let files = CompatFixtures.make() + [(name: CompatFixtures.digests, data: CompatFixtures.digestsData())]
        XCTAssertEqual(files.map(\.name), CompatFixtures.smallNames + [CompatFixtures.digests])
        for (name, data) in files {
            let committed = try? Data(contentsOf: folder.appendingPathComponent(name))
            XCTAssertNotNil(committed, "\(name) is committed")
            XCTAssertTrue(committed == data, "\(name) differs from what CompatFixtures.make() writes (TEGAKI_UPDATE_FIXTURES=1 writes it again)")
        }
        // The large fixtures are not committed: only their digests (the .gitignore of the folder).
        let ignore = (try? String(contentsOf: folder.appendingPathComponent(".gitignore"), encoding: .utf8)) ?? ""
        for name in CompatFixtures.largeNames {
            XCTAssertTrue(ignore.split(separator: "\n").contains(Substring(name)), "\(name) is ignored by git")
        }
        // The same ids and times every run: two makes give the same bytes.
        XCTAssertTrue(CompatFixtures.make().map(\.data) == files.dropLast().map(\.data))
        let ids = CompatFixtures.SeededIds(seed: 7)
        var a = ids
        var b = ids
        let first = a.next()
        XCTAssertEqual(first, b.next())
        XCTAssertEqual(first, first.lowercased())
        XCTAssertNotNil(UUID(uuidString: first), "a UUID form")
    }
}
