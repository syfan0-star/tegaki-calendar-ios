import Foundation
import CoreGraphics
import InkModel
import Layout

// tools/span-compat, the part for <1.1.1> (the commit in tools/l10n/ja-baseline-ref.txt, 9cbc3c9; CI: the checkout
// at v11, as tools/weekstart-compat). Its layout engines take no week start (every week starts on Monday); the
// day page has the `extra` cell (the free memo below 24:00, open to 6,000 lu since 1.1.1).

let versionName = "<1.1.1> (9cbc3c9)"
let versionFolder = "v11"

/// What <1.1.1> draws of each fixture (the live strokes of the cells its layout has), written out from the files;
/// nil: <1.1.1> never opens that page (a Sunday-start week, F2). A new fixture needs its row here.
let expectedDrawn: [String: Int?] = [
    "d-2026-11-03.overhang-right.json": 2,    // grid and extra
    "m1-2026-11.overhang-right.json": 2,
    "w-2026-11-02.overhang-left.json": 1,
    "y-2026.overhang.json": 2,
    "w-2026-11-16.move-source.json": 1,
    "w-2026-11-23.move-destination.json": 1,
    "d-2026-11-09.extra-cross.json": 1,       // the free memo is drawn since 1.1
    "d-2026-11-10.extra-cross.json": 1,
    "w-2026-11-08.sunday-overhang.json": nil, // a Sunday week: <1.1.1> opens w-2026-11-02 for that day
    "m1-2026-11.overlap-day.json": 2,
    "m1-2026-12.overlap-day.json": 2,
    "w-2026-11-30.photo-text.json": 1,        // the photo and the text label are not strokes
    "w-2026-12-07.photo-text-neighbor.json": 1,
]

/// <1.1.1>'s layout of the page, as its screen makes it (no event, the page's ink bottoms).
func versionLayout(_ ref: PageRef, page: InkPage) -> (pageId: String, cells: [CellKey: CGRect]) {
    let ink = page.inkBottoms()
    switch ref {
    case .day(let d):
        let l = DayLayoutEngine.layout(DayLayoutInput(day: d, events: [], inkBottoms: ink, now: probeNow, calendar: tokyo))
        return (l.pageId, l.cells)
    case .week(let d):
        let l = WeekLayoutEngine.layout(WeekLayoutInput(focus: d, events: [], inkBottoms: ink, now: probeNow, calendar: tokyo))
        return (l.pageId, l.cells)
    case .month(let ym):
        let l = MonthLayoutEngine.layout(MonthLayoutInput(month: ym, events: [], inkBottoms: ink, now: probeNow, calendar: tokyo))
        return (l.pageId, l.cells)
    case .year(let y):
        let l = YearLayoutEngine.layout(YearLayoutInput(year: y, events: [], inkBottoms: ink, now: probeNow, calendar: tokyo))
        return (l.pageId, l.cells)
    }
}
