import Foundation
import XCTest
import Compat10
import CompatFixtures
import InkModel
import Layout

/// The read caps of 1.0 (F8, K-9): 20,000 strokes (unknown tools counted) in key order and 200,000
/// tombstones. 1.1 reads up to 60,000 strokes, so what a 1.0 device truncated comes back whole on a
/// 1.1 device (M7A_CONTRACT §1.3, §5.1).
final class Compat10BudgetTests: XCTestCase {
    private let support = Compat10TestSupport.self

    func test15000StrokesSurvive10() throws {
        let page10 = try XCTUnwrap(support.page10(CompatFixtures.n15000))
        XCTAssertEqual(page10.strokes.count, 15_000)
        XCTAssertTrue(page10.unknownStrokes.isEmpty)
        XCTAssertEqual(support.bytes10(page10), support.data(CompatFixtures.n15000), "1.0 writes all of it back")
        let page11 = try XCTUnwrap(support.page11(CompatFixtures.n15000))
        XCTAssertEqual(page11.budgetCount, 15_000)
        XCTAssertTrue(StrokeBudget.crossesNotice(from: 14_999, to: page11.budgetCount))
        XCTAssertEqual(Set(page11.strokes.values.map(\.cell)).count, 372)
    }

    func test20000CapKeepsTheSmallestIds() throws {
        let raw = try XCTUnwrap(JSONValueV10.parse(XCTUnwrap(support.data(CompatFixtures.n20500)))["strokes"]?.objectValue)
        XCTAssertEqual(raw.count, 20_500)
        let page10 = try XCTUnwrap(support.page10(CompatFixtures.n20500))
        let kept = Set(page10.strokes.keys).union(page10.unknownStrokes.keys)
        XCTAssertEqual(kept.count, InkPageV10.maxStrokes)
        XCTAssertEqual(kept, Set(raw.keys.sorted().prefix(20_000)), "the first 20,000 ids in key order")
        XCTAssertTrue(page10.deleted.isEmpty, "no tombstone for what was dropped")
        // Every 1.0 device drops the same ones (the order is the ids' order, not a dictionary's).
        let again = try XCTUnwrap(support.page10(CompatFixtures.n20500))
        XCTAssertEqual(Set(again.strokes.keys).union(again.unknownStrokes.keys), kept)
    }

    func testUnknownToolStrokesCountTowardTheCap() throws {
        let raw = try XCTUnwrap(JSONValueV10.parse(XCTUnwrap(support.data(CompatFixtures.n20500)))["strokes"]?.objectValue)
        let tape = Set(raw.filter { InkStrokeV10.toolName(of: $0.value) == "tape" }.keys)
        XCTAssertEqual(tape.count, 200)
        let page10 = try XCTUnwrap(support.page10(CompatFixtures.n20500))
        let smallest = Set(raw.keys.sorted().prefix(20_000))
        XCTAssertEqual(Set(page10.unknownStrokes.keys), tape.intersection(smallest))
        XCTAssertEqual(page10.strokes.count, 20_000 - tape.intersection(smallest).count, "the unknown tools take places of the cap")
        for (id, json) in page10.unknownStrokes { XCTAssertEqual(json.serialized(), raw[id]?.serialized(), "\(id) kept as it was") }
        // 1.1 counts them in its budget.
        XCTAssertEqual(support.page11(CompatFixtures.n20500)?.budgetCount, 20_500)
        XCTAssertEqual(support.page11(CompatFixtures.n20500)?.liveStrokeCount, 20_300)
    }

    func testTombstoneCapKeeps200000() throws {
        let raw = try XCTUnwrap(JSONValueV10.parse(XCTUnwrap(support.data(CompatFixtures.tomb200500)))["deleted"]?.objectValue)
        XCTAssertEqual(raw.count, 200_500)
        let page10 = try XCTUnwrap(support.page10(CompatFixtures.tomb200500))
        XCTAssertEqual(page10.deleted.count, InkPageV10.maxTombstones)
        XCTAssertTrue(Set(page10.deleted.keys).isSubset(of: Set(raw.keys)), "a subset (which one is not fixed, F8)")
        XCTAssertTrue(page10.strokes.isEmpty)
        XCTAssertEqual(support.page11(CompatFixtures.tomb200500)?.deleted.count, InkPage.maxTombstones, "1.1 keeps the same cap")
    }

    func testNewDeviceRestoresWhat10Truncated() throws {
        let file = try XCTUnwrap(support.data(CompatFixtures.n20500))
        let page11 = try InkPageCodec.decode(file)
        XCTAssertEqual(page11.budgetCount, 20_500)
        // A 1.0 device reads it and writes it back (it edits nothing of it): 20,000, no tombstone.
        let page10 = try InkPageCodecV10.decode(file)
        let written = try XCTUnwrap(support.bytes10(page10))
        let truncated = try InkPageCodec.decode(written)
        XCTAssertEqual(truncated.budgetCount, 20_000)
        XCTAssertTrue(truncated.deleted.isEmpty)
        // The 1.1 device merges what came back with what it has: everything again.
        let restored = InkPage.merge(page11, truncated)
        XCTAssertEqual(restored.budgetCount, 20_500)
        XCTAssertTrue(restored.deleted.isEmpty)
        XCTAssertEqual(try InkPageCodec.encode(restored), file, "the original bytes")
        XCTAssertTrue(restored.contentDiffers(from: truncated), "different from 1.0's, so 1.1 marks it and sends it again")
        // Even a 1.0 device that adds a stroke keeps the cap's 20,000 and creates no tombstone.
        var edited = page10
        let points = [InkPointV10(x: 10, y: 10, dtMs: 0, sizeW: 2, sizeH: 2, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571)]
        edited.add(InkStrokeV10(id: "00000000-0000-4000-8000-000000000000", cell: .yearDay(month: 1, day: 1), tool: .pen, color: "#1f2937",
                                t: CompatFixtures.baseTime + 30_000, dev: CompatFixtures.device10, points: points))
        let back = try InkPageCodec.decode(XCTUnwrap(support.bytes10(edited)))
        XCTAssertTrue(back.deleted.isEmpty)
        XCTAssertEqual(InkPage.merge(page11, back).budgetCount, 20_501)
    }

    func testDecodeTimeOf15000Strokes() throws {
        let file = try XCTUnwrap(support.data(CompatFixtures.n15000))
        // Measured only (F13); never a failure.
        measure {
            _ = try? InkPageCodecV10.decode(file)
        }
    }
}
