import Foundation
import CoreGraphics
import InkModel
import Layout

// tools/span-compat, the part for 1.2.3 (commit 43fe36666a2120e8a23adf4fc76244151a395e6f, the version on sale
// when 1.3 starts; CI: `git archive 43fe366 TegakiKit` at v123). Its week pages follow the owner's week start
// (K-11): a week page of a Sunday is laid out with the Sunday start, the others with the Monday start, as a 1.2.3
// device of each setting opens them. The day page has the `extra` cell.

let versionName = "1.2.3 (43fe366)"
let versionFolder = "v123"

/// What 1.2.3 draws of each fixture (the live strokes of the cells its layout has), written out from the files.
/// A new fixture needs its row here.
let expectedDrawn: [String: Int?] = [
    "d-2026-11-03.overhang-right.json": 2,    // grid and extra
    "m1-2026-11.overhang-right.json": 2,
    "w-2026-11-02.overhang-left.json": 1,
    "y-2026.overhang.json": 2,
    "w-2026-11-16.move-source.json": 1,
    "w-2026-11-23.move-destination.json": 1,
    "d-2026-11-09.extra-cross.json": 1,
    "d-2026-11-10.extra-cross.json": 1,
    "w-2026-11-08.sunday-overhang.json": 2,   // 1.2.x opens the Sunday week (with the Sunday start) and draws both
    "m1-2026-11.overlap-day.json": 2,
    "m1-2026-12.overlap-day.json": 2,
    "w-2026-11-30.photo-text.json": 1,        // the photo and the text label are not strokes
    "w-2026-12-07.photo-text-neighbor.json": 1,
]

/// 1.2.3's layout of the page, as its screen makes it (no event, the page's ink bottoms, Japan's holidays).
func versionLayout(_ ref: PageRef, page: InkPage) -> (pageId: String, cells: [CellKey: CGRect]) {
    let ink = page.inkBottoms()
    switch ref {
    case .day(let d):
        let l = DayLayoutEngine.layout(DayLayoutInput(day: d, events: [], inkBottoms: ink, now: probeNow, calendar: tokyo))
        return (l.pageId, l.cells)
    case .week(let d):
        let start: WeekStart = d.weekday == 0 ? .sunday : .monday
        let l = WeekLayoutEngine.layout(WeekLayoutInput(focus: d, events: [], inkBottoms: ink, now: probeNow, calendar: tokyo, weekStart: start))
        return (l.pageId, l.cells)
    case .month(let ym):
        let l = MonthLayoutEngine.layout(MonthLayoutInput(month: ym, events: [], inkBottoms: ink, now: probeNow, calendar: tokyo))
        return (l.pageId, l.cells)
    case .year(let y):
        let l = YearLayoutEngine.layout(YearLayoutInput(year: y, events: [], inkBottoms: ink, now: probeNow, calendar: tokyo))
        return (l.pageId, l.cells)
    }
}
