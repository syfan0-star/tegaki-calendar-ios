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
    "w-2026-12-14.week-memo.json": 2,         // the two grid strokes; 1.2.3's week has no memo cell (extra), so the memo's are kept
    "w-2026-12-21.week-memo-neighbor.json": 0, // the week memo (extra) only
    "w-2026-12-20.week-memo-sunday.json": 0,  // the Sunday start opens it; its one stroke is the memo's (extra)
    "w-2026-11-08.sunday-overhang.json": 2,   // 1.2.x opens the Sunday week (with the Sunday start) and draws both
    "m1-2026-11.overlap-day.json": 2,
    "m1-2026-12.overlap-day.json": 2,
    "w-2026-11-30.photo-text.json": 1,        // the photo and the text label are not strokes
    "w-2026-12-07.photo-text-neighbor.json": 1,
]

/// 1.4.3 (docs/R1_4_3_CONTRACT.md §8.3, 0g-30): what 1.2.3 draws of each compat-span-143 fixture (the month and the year
/// joined sideways), written out from the files. Every file holds one live stroke in a cell 1.2.3's layout has:
/// its month, laid out with the Monday start here as every month, has those day cells and the memo, its year all
/// 372 cells. So it draws it, overhanging or not; a row 1.4.3 lengthened grows here from the page's own ink.
/// The Sunday-start month (fixture 11) holds a memo line only, which every week start draws. A new fixture of that folder
/// needs its row here.
let expectedDrawn143: [String: Int?] = [
    "m1-2026-11.memo-left.json": 1,           // 8: memo, x −160 … 260
    "m1-2026-10.move-source.json": 1,         // 9: the stroke left on 2026-11-01; the moved one's tombstone is not a stroke
    "m1-2026-11.move-destination.json": 1,    // 9: the copy on 2026-11-01
    "y-2026.december-right.json": 1,          // 10: 12-10, past the right edge
    "y-2027.date-column.json": 1,             // 10: 01-20, x −128 … 70
    "m1-2026-11.memo-sunday.json": 1,         // 11: memo (shape sunday)
    "y-2026.row-floor.json": 1,               // 12: 06-15, 350 lu down its row
    "m1-2026-11.last-row.json": 1,            // 13: 2026-12-03, 600 lu down row 6
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

/// The checks only one version has (docs/M7D_CONTRACT.md §5.3 2: v13's runs 1.3's guard of the save over every
/// fixture page). 1.2.3 has none: Probe/main.swift calls this once, after the files.
func versionExtraChecks(pages: [InkPage]) {}
