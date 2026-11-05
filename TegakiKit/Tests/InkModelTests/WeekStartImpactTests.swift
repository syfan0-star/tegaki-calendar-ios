import XCTest
import Foundation
import CoreGraphics
import InkModel

/// `WeekStartImpact` and the week's words of `StrokeBudget` (docs/M7B_CONTRACT.md §10.1, §10.2, D17).
final class WeekStartImpactTests: XCTestCase {
    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

    private func stroke(_ id: String, _ cell: CellKey) -> InkStroke {
        let points = (0..<4).map { InkPoint(x: 20 + CGFloat($0) * 5, y: 100, dtMs: 8 * $0, sizeW: 2, sizeH: 2, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.5) }
        return InkStroke(id: id, cell: cell, tool: .pen, color: "#1f2937", t: 1_780_000_000_000, dev: "ipad-12", points: points)
    }

    /// 2026-11: the Monday grid has 10/26…10/31, the Sunday grid has 12/7…12/12.
    private var page: InkPage {
        var p = InkPage(pageId: "m1-2026-11")
        p.add(stroke("both", .day(day(2026, 11, 14))))
        p.add(stroke("sunOnly", .day(day(2026, 12, 12))))
        p.add(stroke("sunOnly2", .day(day(2026, 12, 7))))
        p.add(stroke("monOnly", .day(day(2026, 10, 26))))
        p.add(stroke("memo", .memo))
        return p
    }

    func testHiddenStrokesOfTheMonth() {
        XCTAssertEqual(WeekStartImpact.hiddenStrokeIds(in: page, weekStart: .monday), ["sunOnly", "sunOnly2"])
        XCTAssertEqual(WeekStartImpact.hiddenStrokeIds(in: page, weekStart: .sunday), ["monOnly"])
        var erased = page
        erased.remove(ids: ["monOnly"], at: 1_780_000_100_000)
        XCTAssertEqual(WeekStartImpact.hiddenStrokeIds(in: erased, weekStart: .sunday), [], "an erased stroke is not hidden")
        var week = InkPage(pageId: "w-2026-11-01")
        week.add(stroke("g", .grid))
        XCTAssertEqual(WeekStartImpact.hiddenStrokeIds(in: week, weekStart: .monday), [], "only a month page hides strokes")
        var day = InkPage(pageId: "d-2026-11-01")
        day.add(stroke("g", .grid))
        XCTAssertEqual(WeekStartImpact.hiddenStrokeIds(in: day, weekStart: .sunday), [])
        var memoOnly = InkPage(pageId: "m1-2026-11")
        memoOnly.add(stroke("memo", .memo))
        XCTAssertEqual(WeekStartImpact.hiddenStrokeIds(in: memoOnly, weekStart: .sunday), [], "the memo is on both")
    }

    func testNothingHiddenOnMondayForMondayInk() {
        for (y, m) in [(2026, 10), (2026, 11), (2027, 2), (2000, 1), (2099, 12)] {
            var p = InkPage(pageId: YearMonth(year: y, month: m).inkPageId)
            for (i, d) in MonthLayout.grid(year: y, month: m).days.enumerated() { p.add(stroke("s\(i)", .day(d))) }
            XCTAssertEqual(WeekStartImpact.hiddenStrokeIds(in: p, weekStart: .monday), [], "\(y)-\(m): 1.1's ink is never hidden on Monday (J-4)")
            let hidden = WeekStartImpact.hiddenStrokeIds(in: p, weekStart: .sunday)
            XCTAssertEqual(hidden.count, DayKey(year: y, month: m, day: 1).weekday == 0 ? 6 : 1, "\(y)-\(m): the pale cells of the Monday grid only")
        }
    }

    func testWeekPagesByForm() {
        let empty = WeekStartImpact.weekPages([])
        XCTAssertEqual(empty.monday, 0)
        XCTAssertEqual(empty.sunday, 0)
        let counts = WeekStartImpact.weekPages(["w-2026-11-02", "w-2026-11-09", "w-2026-11-01", "w-2026-11-04", "wb-2026-11-02", "m1-2026-11", "d-2026-11-01", "y-2026", "w-2026-13-01", ""])
        XCTAssertEqual(counts.monday, 2)
        XCTAssertEqual(counts.sunday, 1)
    }

    func testSundayLabel() {
        XCTAssertEqual(StrokeBudget.pageLabel("w-2026-11-01"), "週のページ（2026年11月1日〜11月7日）")
        XCTAssertEqual(StrokeBudget.pageLabel("w-2026-11-01", language: .ja), "週のページ（2026年11月1日〜11月7日）")
        XCTAssertEqual(StrokeBudget.pageLabel("w-2026-11-02"), "週のページ（2026年11月2日〜11月8日）", "a Monday page")
        XCTAssertEqual(StrokeBudget.pageLabel("w-2026-12-27"), "週のページ（2026年12月27日〜2027年1月2日）", "across the year end")
        XCTAssertEqual(["w-2026-11-01"].map(StrokeBudget.pageLabel), ["週のページ（2026年11月1日〜11月7日）"], "the form .map uses")
        XCTAssertEqual(AppExport.pdfFileName(kind: .week, focus: day(2026, 11, 4), weekStart: .sunday), "てがきカレンダー 2026年11月1日〜11月7日 週.pdf")
        XCTAssertEqual(AppExport.pdfFileName(kind: .week, focus: day(2026, 11, 4)), "てがきカレンダー 2026年11月2日〜11月8日 週.pdf", "Monday by default")
    }
}
