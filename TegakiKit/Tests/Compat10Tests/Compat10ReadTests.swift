import Foundation
import XCTest
import Compat10
import CompatFixtures
import InkModel
import Layout

/// Reading and writing back (M7A_CONTRACT §1.4): 1.0 reads every 1.1 fixture and writes it back
/// unchanged, 1.1 reads what 1.0 writes, and a missing large fixture is a failure, not a skip.
final class Compat10ReadTests: XCTestCase {
    private let support = Compat10TestSupport.self

    func testEveryFixtureRoundTripsByteIdenticalThrough10() throws {
        var failures: [String] = []
        let result = Compat10Checks.run(fixtures: support.folder) { name, ok in if !ok { failures.append(name) } }
        XCTAssertEqual(result.failed, 0, "Compat10Checks: \(failures)")
        XCTAssertGreaterThan(result.passed, 200)

        for name in support.pageNames where !CompatFixtures.largeNames.contains(name) || name == CompatFixtures.n15000 {
            let data = try XCTUnwrap(support.data(name), name)
            let json = try JSONValueV10.parse(data)
            let page = try XCTUnwrap(support.page10(name), name)
            let back = try XCTUnwrap(support.bytes10(page), name)
            XCTAssertEqual(back, json.serializedData(), "\(name): 1.0 writes back every item it read")
            if CompatFixtures.smallNames.contains(name) || CompatFixtures.largeNames.contains(name) {
                XCTAssertEqual(back, data, "\(name): K's fixture comes back from 1.0 byte for byte")
            }
        }
        // The export, written again by 1.0.
        let export = try XCTUnwrap(support.data(CompatFixtures.export11))
        let document = try AppExportV10.parse(json: JSONValueV10.parse(export))
        XCTAssertEqual(AppExportV10.encode(document), export)
    }

    func testNewReaderReadsWhat10Writes() throws {
        for name in support.pageNames {
            let page10 = try XCTUnwrap(support.page10(name), name)
            let written = try XCTUnwrap(support.bytes10(page10), name)
            let page11 = try InkPageCodec.decode(written)
            XCTAssertEqual(try InkPageCodec.encode(page11), written, "\(name): 1.1 writes what 1.0 wrote, byte for byte")
            XCTAssertEqual(page11.budgetCount, page10.liveStrokeCount + page10.unknownStrokes.count, "\(name): the same strokes")
            XCTAssertEqual(Set(page11.deleted.keys), Set(page10.deleted.keys), "\(name): the same tombstones")
        }
        // The new reader reads the 1.1 files themselves without the 1.0 caps.
        XCTAssertEqual(support.page11(CompatFixtures.n20500)?.budgetCount, 20_500)
        XCTAssertEqual(support.page10(CompatFixtures.n20500).map { $0.strokes.count + $0.unknownStrokes.count }, 20_000)
    }

    func testMissingLargeFixtureCountsAsAFailure() throws {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("TegakiKit-Compat10Tests-missing-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: folder) }
        try CompatFixtures.prepare(from: CompatFixtures.committedFolder, into: folder, skippingLarge: [CompatFixtures.n20500])
        XCTAssertFalse(fm.fileExists(atPath: folder.appendingPathComponent(CompatFixtures.n20500).path))
        var failures: [String] = []
        let result = Compat10Checks.run(fixtures: folder) { name, ok in if !ok { failures.append(name) } }
        XCTAssertGreaterThanOrEqual(result.failed, 1)
        XCTAssertTrue(failures.contains { $0.hasPrefix(CompatFixtures.n20500) }, "\(failures)")

        // A changed byte of a large fixture is a failure too.
        let tomb = folder.appendingPathComponent(CompatFixtures.tomb200500)
        var bytes = try Data(contentsOf: tomb)
        bytes[bytes.count - 2] = bytes[bytes.count - 2] == UInt8(ascii: "1") ? UInt8(ascii: "2") : UInt8(ascii: "1")
        try bytes.write(to: tomb)
        failures = []
        _ = Compat10Checks.run(fixtures: folder) { name, ok in if !ok { failures.append(name) } }
        XCTAssertTrue(failures.contains("\(CompatFixtures.tomb200500): sha256 is the one in digests.json"), "\(failures)")
    }
}
