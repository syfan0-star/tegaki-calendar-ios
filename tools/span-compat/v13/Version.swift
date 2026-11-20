import Foundation
import CoreGraphics
import InkModel
import Layout

// tools/span-compat, the part for 1.3 (commit 955fe678ec9f999ac45fac1b372f246e43c02f95, build 26, on sale since
// 2026-11-20; CI: `git archive 955fe67 TegakiKit` at v13; docs/M7D_CONTRACT.md §5.3). Its pages are laid out as its
// screen lays them out: the week with its memo below 24:00 (`WeekLayoutInput.freeMemo`: the `extra` cell 1.3 gave
// the week; without it the week is 1.2.3's), and the week's and the day's last cell with the floor of a window
// (`extraFloor` from `SpanAlign`, as `SpanSession.layoutPages` passes it on the joined path). A week page of a
// Sunday is laid out with the Sunday start, the others with the Monday start (K-11), as v123. Only this version has
// an extra check (`versionExtraChecks`): 1.3's guard of the save.

let versionName = "1.3 (955fe67)"
let versionFolder = "v13"

/// What 1.3 draws of each fixture (the live strokes of the cells its layout has: the day's `grid` and `extra`, the
/// week's `grid` and its memo `extra`, the month's day cells and `memo`, the year's day cells), counted from the
/// files. A new fixture needs its row here (and in AppTests/Real13LedgerTests.swift's `drawnBy13`).
let expectedDrawn: [String: Int?] = [
    "d-2026-11-03.overhang-right.json": 2,    // grid and extra
    "m1-2026-11.overhang-right.json": 2,      // memo and the day cell 2026-11-08
    "w-2026-11-02.overhang-left.json": 1,
    "y-2026.overhang.json": 2,                // 01-20 and 12-20
    "w-2026-11-16.move-source.json": 1,       // the moved stroke's tombstone is not a stroke
    "w-2026-11-23.move-destination.json": 1,
    "d-2026-11-09.extra-cross.json": 1,       // extra
    "d-2026-11-10.extra-cross.json": 1,       // extra
    "w-2026-12-14.week-memo.json": 4,         // the two grid strokes and the week memo's two (extra): 1.3's week has the memo
    "w-2026-12-21.week-memo-neighbor.json": 1, // the week memo's one (extra)
    "w-2026-12-20.week-memo-sunday.json": 1,  // the Sunday start opens it; the week memo's one (extra)
    "w-2026-11-08.sunday-overhang.json": 2,   // the Sunday start opens it; both grid strokes
    "m1-2026-11.overlap-day.json": 2,         // the day cells 2026-11-30 and 2026-12-01
    "m1-2026-12.overlap-day.json": 2,
    "w-2026-11-30.photo-text.json": 1,        // the photo and the text label are not strokes
    "w-2026-12-07.photo-text-neighbor.json": 1,
]

/// 1.3's layout of the page, as its screen makes it (no event, the page's ink bottoms, Japan's holidays). The floor
/// of the last cell is the one a window whose tallest page is this one gives (`SpanAlign.dayFloors` /
/// `weekFloors` of its `extra` bottom, `.redecide` as at an opening); the one-page path passes none (0). Neither is
/// ever above what the page's own ink needs, so both give the same cells.
func versionLayout(_ ref: PageRef, page: InkPage) -> (pageId: String, cells: [CellKey: CGRect]) {
    let ink = page.inkBottoms()
    let extraBottoms = [ink[.extra] ?? 0]
    switch ref {
    case .day(let d):
        let floor = SpanAlign.dayFloors(previous: .none, extraInkBottoms: extraBottoms, change: .redecide).dayExtra
        let l = DayLayoutEngine.layout(DayLayoutInput(day: d, events: [], inkBottoms: ink, now: probeNow, calendar: tokyo, extraFloor: floor))
        return (l.pageId, l.cells)
    case .week(let d):
        let start: WeekStart = d.weekday == 0 ? .sunday : .monday
        let floor = SpanAlign.weekFloors(previous: .none, extraInkBottoms: extraBottoms, change: .redecide).weekExtra
        let l = WeekLayoutEngine.layout(WeekLayoutInput(focus: d, events: [], inkBottoms: ink, now: probeNow, calendar: tokyo, weekStart: start,
                                                        extraFloor: floor, freeMemo: true))
        return (l.pageId, l.cells)
    case .month(let ym):
        let l = MonthLayoutEngine.layout(MonthLayoutInput(month: ym, events: [], inkBottoms: ink, now: probeNow, calendar: tokyo))
        return (l.pageId, l.cells)
    case .year(let y):
        let l = YearLayoutEngine.layout(YearLayoutInput(year: y, events: [], inkBottoms: ink, now: probeNow, calendar: tokyo))
        return (l.pageId, l.cells)
    }
}

/// 1.3 only (docs/M7D_CONTRACT.md §5.3 2): every fixture page through 1.3's guard of the save
/// (`SpanGuard.checkForSave`, what `PageSlot.persist` runs before every save on both paths) must come out `.ok`:
/// nothing stripped, nothing dropped, the page id of the form 1.3 writes, so a 1.3 device that saves the page again
/// loses nothing. And through its guard of the ways out (`checkForTransfer`: its import, export and the page of a
/// PDF): no window name. A fixture that holds a window name ("<pageId>|…", "span~…") fails here.
func versionExtraChecks(pages: [InkPage]) {
    var repaired = 0
    for (index, page) in pages.enumerated() {
        let label = "\(page.pageId) (fixture page \(index + 1) of \(pages.count))"
        switch SpanGuard.checkForSave(page) {
        case .ok:
            check(true, "\(label): 1.3's SpanGuard.checkForSave saves it as it is")
        case .repaired(_, let stripped, let dropped):
            repaired += 1
            check(false, "\(label): 1.3's SpanGuard.checkForSave repairs it (stripped \(stripped), dropped \(dropped)): a 1.3 device saving it again changes it")
        case .refused:
            repaired += 1
            check(false, "\(label): 1.3's SpanGuard.checkForSave refuses its page id")
        }
        check(SpanGuard.checkForTransfer(page), "\(label): 1.3's SpanGuard.checkForTransfer passes it (no window name)")
    }
    print("SpanGuard of \(versionName): \(pages.count) pages through checkForSave and checkForTransfer, \(repaired) repaired or refused")
}
