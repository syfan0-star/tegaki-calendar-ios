import Foundation
import XCTest
import Compat10
import CompatFixtures
import InkModel
import Layout

/// `merge` (F4): a 1.0 page and a 1.1 page merge without losing `extra`, `memo` or unknown items, and
/// the merge of 1.0 and the merge of 1.1 give the same bytes, whatever the pages are.
final class Compat10MergeTests: XCTestCase {
    private let support = Compat10TestSupport.self

    func testMergeWith10PageKeepsExtraAndMemo() throws {
        // The day page and what a 1.0 device made of it.
        let day = try XCTUnwrap(support.page10(CompatFixtures.dayPage))
        let from10 = try XCTUnwrap(support.page10(CompatFixtures.dayFrom10))
        let merged = InkPageV10.merge(day, from10)
        XCTAssertEqual(merged, InkPageV10.merge(from10, day))
        let extra = CellKeyV10(raw: "extra")
        XCTAssertEqual(merged.strokes.values.filter { $0.cell == extra }.count, 8)
        XCTAssertEqual(merged.strokes.values.filter { $0.cell == .grid }.count, 7)
        XCTAssertEqual(merged.unknownStrokes.count, 1)
        let before = support.strokesJSON10(day)
        let after = support.strokesJSON10(merged)
        for (id, stroke) in day.strokes where stroke.cell == extra {
            XCTAssertEqual(after[id], before[id], "extra \(id) unchanged")
        }
        XCTAssertEqual(after[day.unknownStrokes.keys.first ?? ""], before[day.unknownStrokes.keys.first ?? ""], "the unknown stroke unchanged")

        // The month page and a memo stroke written on 1.0.
        let month = try XCTUnwrap(support.page10(CompatFixtures.monthPage))
        var edited = month
        let points = (0..<3).map { InkPointV10(x: 40 + CGFloat($0) * 9, y: 6100, dtMs: $0 * 8, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571) }
        edited.add(InkStrokeV10(id: "a-1.0-memo-stroke", cell: .memo, tool: .pen, color: "#2563eb", t: CompatFixtures.baseTime + 500, dev: CompatFixtures.device10, points: points))
        let monthMerged = InkPageV10.merge(month, edited)
        XCTAssertEqual(monthMerged.strokes.count, month.strokes.count + 1)
        let monthBefore = support.strokesJSON10(month)
        let monthAfter = support.strokesJSON10(monthMerged)
        for (id, json) in monthBefore { XCTAssertEqual(monthAfter[id], json, "\(id) unchanged") }
        // 1.1 reads the 1.0 memo line 6,100 deep: it stays visible (b + 50), it is not a new stroke.
        let page11 = try InkPageCodec.decode(XCTUnwrap(support.bytes10(monthMerged)))
        let layout = CompatFixtures.monthLayout(2026, 11, ink: page11.inkBottoms())
        XCTAssertEqual(layout.memo.height, 6100 + 1.75 + 50)
    }

    func testMergeIsByteIdenticalIn10AndNow() throws {
        var rng = CompatFixtures.SeededIds(seed: 0xC0FF_EE10_0500)
        for pair in 0..<500 {
            let a = randomPage(&rng, pair: pair, side: 0)
            let b = randomPage(&rng, pair: pair, side: 1)
            let a10 = try XCTUnwrap(support.to10(a))
            let b10 = try XCTUnwrap(support.to10(b))
            let bytes10 = support.bytes10(InkPageV10.merge(a10, b10))
            let bytes11 = support.bytes11(InkPage.merge(a, b))
            XCTAssertNotNil(bytes10)
            XCTAssertEqual(bytes10, bytes11, "pair \(pair): 1.0 and 1.1 merge to the same bytes")
            XCTAssertEqual(support.bytes10(InkPageV10.merge(b10, a10)), bytes10, "pair \(pair): 1.0's merge commutes")
            XCTAssertEqual(support.bytes11(InkPage.merge(b, a)), bytes11, "pair \(pair): 1.1's merge commutes")
            // Reading the merge of 1.0 with the new reader and merging once more changes nothing.
            let again = try InkPageCodec.decode(XCTUnwrap(bytes10))
            XCTAssertEqual(support.bytes11(InkPage.merge(again, InkPage.merge(a, b))), bytes11, "pair \(pair): idempotent")
            if pair == 0 { XCTAssertGreaterThan(a.strokes.count + b.strokes.count, 0) }
        }
    }

    /// One side of a seeded pair: strokes from a shared pool of ids (the same id may carry different
    /// contents on the two sides), cells `grid` / `extra` / `memo` / a day / a year cell / one 1.1 does
    /// not know, an unknown tool now and then, tombstones, unknown top-level items and `v` 2 sometimes.
    private func randomPage(_ rng: inout CompatFixtures.SeededIds, pair: Int, side: Int) -> InkPage {
        func roll(_ n: UInt64) -> Int { Int(rng.nextUInt64() % n) }
        let pageIds = ["d-2026-11-02", "m1-2026-11", "y-2026", "w-2026-11-02"]
        let pageId = roll(10) == 0 ? pageIds[roll(4)] : pageIds[pair % 4]
        let cells = ["grid", "extra", "memo", "2026-11-03", "03-05", "zz-later"]
        let pool = (0..<12).map { String(format: "%08x-0000-4000-8000-%012x", pair, $0) }
        var page = InkPage(v: roll(15) == 0 ? 2 : 1, pageId: pageId)
        for _ in 0..<roll(9) {
            let id = pool[roll(UInt64(pool.count))]
            let count = 1 + roll(4)
            let points = (0..<count).map { i in
                InkPoint(x: CGFloat(roll(14_000)) / 10, y: CGFloat(roll(80_000)) / 10, dtMs: i * 8,
                         sizeW: CGFloat(1 + roll(30)) / 4, sizeH: CGFloat(1 + roll(30)) / 4, opacity: 1, force: CGFloat(roll(100)) / 100,
                         azimuth: CGFloat(roll(6283)) / 1000, altitude: CGFloat(roll(1571)) / 1000)
            }
            let t = CompatFixtures.baseTime + roll(4)
            if roll(8) == 0 {
                page.unknownStrokes[id] = .object([
                    "id": .string(id), "cell": .string(cells[roll(UInt64(cells.count))]), "tool": .string(roll(2) == 0 ? "tape" : "brush"),
                    "t": .number(Double(t)), "pts": .array(InkPoint.flat(points).map { .number($0) }), "later": .number(Double(roll(9))),
                ])
                page.updatedAt = max(page.updatedAt, t)
            } else {
                page.add(InkStroke(id: id, cell: CellKey(raw: cells[roll(UInt64(cells.count))]), tool: roll(3) == 0 ? .marker : .pen,
                                   color: ["#1f2937", "#dc2626", "#fde047"][roll(3)], t: t, dev: roll(2) == 0 ? nil : "dev-\(side)", points: points))
            }
        }
        if roll(3) == 0 {
            page.remove(ids: [pool[roll(UInt64(pool.count))], pool[roll(UInt64(pool.count))]], at: CompatFixtures.baseTime + 10 + roll(5))
        }
        if roll(4) == 0 {
            page.unknown["later-\(roll(3))"] = roll(2) == 0 ? .string("side \(side)") : .object(["n": .number(Double(roll(5)))])
        }
        page.updatedAt = max(page.updatedAt, CompatFixtures.baseTime + roll(20))
        return page
    }
}
