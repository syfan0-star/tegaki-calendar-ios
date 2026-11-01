import Foundation
import XCTest
import Compat10
import CompatFixtures
import InkModel
import Layout

/// A 1.0 device in use (F12): showing a 1.1 page does not rewrite it, a 1.0 edit of `grid` keeps
/// `extra`, and fetching an identical page queues nothing.
final class Compat10SessionTests: XCTestCase {
    private let support = Compat10TestSupport.self

    func testDisplayingANewPageOn10DoesNotRewriteIt() throws {
        for name in support.pageNames where !support.isLegacy(name) && !CompatFixtures.largeNames.contains(name) {
            let page = try XCTUnwrap(support.page10(name), name)
            XCTAssertFalse(LedgerV10.displayWouldSave(loaded: page), "\(name): opening it on 1.0 does not save or send it")
            XCTAssertNil(LedgerV10.applyRemoteWouldSave(page: page, updated: page), "\(name): the same page from iCloud is ignored")
            XCTAssertEqual(support.bytes10(BandMigrationV10.migrate(page)), support.data(name).flatMap { try? JSONValueV10.parse($0).serializedData() },
                           "\(name): what the 1.0 screen holds is the file")
        }
    }

    func testEditingGridOn10KeepsExtra() throws {
        // Rebuild the from10 fixture with the frozen 1.0 copy: read the 1.1 page, add the two grid
        // strokes and erase one grid stroke exactly as the 1.0 device did.
        var page = try XCTUnwrap(support.page10(CompatFixtures.dayPage))
        let original = page
        let edit = CompatFixtures.dayFrom10Edit()
        for spec in edit.adds {
            let points = InkPointV10.points(fromFlat: spec.pts)
            page.add(InkStrokeV10(id: spec.id, cell: CellKeyV10(raw: spec.cell), tool: try XCTUnwrap(InkToolV10(rawValue: spec.tool)),
                                  color: spec.color, t: spec.t, dev: spec.dev, points: points))
        }
        XCTAssertTrue(edit.adds.allSatisfy { $0.cell == "grid" }, "1.0 writes only into grid on a day page")
        page.remove(ids: edit.removes, at: edit.at)
        XCTAssertEqual(support.bytes10(page), support.data(CompatFixtures.dayFrom10), "the from10 fixture is what 1.0 writes")

        let before = support.strokesJSON10(original)
        let after = support.strokesJSON10(page)
        let extra = CellKeyV10(raw: "extra")
        for (id, stroke) in original.strokes where stroke.cell == extra {
            XCTAssertEqual(after[id], before[id], "extra \(id) unchanged by the 1.0 edit")
        }
        for id in original.unknownStrokes.keys { XCTAssertEqual(after[id], before[id], "unknown \(id) unchanged") }
        // The 1.0 screen keeps the edited page when the older 1.1 page comes back from iCloud: nothing new.
        XCTAssertTrue(LedgerV10.applyRemoteWouldSave(page: page, updated: original) == nil)
        // The 1.1 device receives the 1.0 edit and keeps everything of both.
        let received = InkPage.merge(try XCTUnwrap(support.page11(CompatFixtures.dayPage)), try XCTUnwrap(support.page11(CompatFixtures.dayFrom10)))
        XCTAssertEqual(support.bytes11(received), support.bytes10(InkPageV10.merge(original, page)))
        XCTAssertEqual(received.liveStrokes.filter { $0.cell == .extra }.count, 8)
    }

    func testMergeRemoteOn10DoesNotMarkDirtyForAnIdenticalPage() throws {
        for name in [CompatFixtures.dayPage, CompatFixtures.dayMoved, CompatFixtures.monthPage, CompatFixtures.monthFrom10] {
            let page = try XCTUnwrap(support.page10(name), name)
            let same = LedgerV10.mergeRemoteOutcome(local: page, remote: page)
            XCTAssertFalse(same.writesFile, "\(name): the file is not written again")
            XCTAssertFalse(same.marksDirty, "\(name): nothing is sent back")
            XCTAssertEqual(same.merged, page)
            // The first fetch on a device without the page: written, not sent back.
            let first = LedgerV10.mergeRemoteOutcome(local: InkPageV10.empty(pageId: page.pageId), remote: page)
            XCTAssertTrue(first.writesFile, name)
            XCTAssertFalse(first.marksDirty, "\(name): the merge is the remote page")
            XCTAssertEqual(support.bytes10(first.merged), support.bytes10(page))
        }
        // A page only this 1.0 device has (an extra stroke of its own) is sent back.
        let day = try XCTUnwrap(support.page10(CompatFixtures.dayPage))
        let from10 = try XCTUnwrap(support.page10(CompatFixtures.dayFrom10))
        XCTAssertTrue(LedgerV10.mergeRemoteOutcome(local: from10, remote: day).marksDirty)
    }
}
