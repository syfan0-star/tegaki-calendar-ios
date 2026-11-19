// KitChecks: the week memo of 1.3 (docs/M7C_CONTRACT.md §5.2, §10.1, D16, K-1, K-4, K-6, K-10; section
// "week memo (1.3)"). main.swift calls `runWeekMemoChecks()` right after `runSpanInkChecks()`; it uses
// main.swift's `section`, `check`, `checkEqual`, `tokyo`, `day`, `october`, `allDay`, `timed`, `point` and
// `stroke`, and SpanChecks.swift's `SpanFixtures`.
//
// The week memo is the cell `extra` below 24:00 of a week laid out with `WeekLayoutInput.freeMemo` true (the
// app's two callers pass it). Left out, the week is 1.2.3's: 1400 × 1920, one cell, nothing grows, no last
// cell, any floor ignored. The expectations are literals worked out from the contract and from the day's free
// memo (the day's rules at 1,920 instead of 2,400), not read back from the code under test; where an answer
// must not change, it is compared with the week laid out without the memo.
import Foundation
import CoreGraphics
import Layout
import InkModel

// MARK: - Fixtures

enum WeekMemoFixtures {
    /// Wednesday 2026-10-14 10:00 in Tokyo: today is in the week of Monday 10-12 and of Sunday 10-11.
    static let now = october(14, 10)
    /// A box on Tuesday morning, one on Wednesday night, one on Thursday that ends at 24:00 (its bottom is the
    /// grid's), and an all-day event over the weekend (Saturday 10-17 and Sunday 10-18).
    static let events = [timed("wm1", 13, 9, 0, 10, 30), timed("wm2", 14, 22, 0, 23, 30), timed("wm3", 15, 23, 0, 0, 0, endDay: 16),
                         allDay("wma", 17, 19)]
    /// Three weeks of each start: two in October (the second holds today) and the one across the new year.
    static let focuses = [day(2026, 10, 7), day(2026, 10, 14), day(2026, 12, 31)]

    /// The week of `focus`. `memo` nil leaves `freeMemo` out (the default the old callers get); `floor` nil
    /// leaves `extraFloor` out.
    static func week(_ focus: DayKey, _ weekStart: WeekStart = .monday, memo: Bool?, ink: [CellKey: CGFloat] = [:], floor: CGFloat? = nil) -> WeekPageLayout {
        let input: WeekLayoutInput
        switch (memo, floor) {
        case (nil, nil):
            input = WeekLayoutInput(focus: focus, events: events, inkBottoms: ink, now: now, calendar: tokyo, weekStart: weekStart)
        case (nil, let f?):
            input = WeekLayoutInput(focus: focus, events: events, inkBottoms: ink, now: now, calendar: tokyo, weekStart: weekStart, extraFloor: f)
        case (let m?, nil):
            input = WeekLayoutInput(focus: focus, events: events, inkBottoms: ink, now: now, calendar: tokyo, weekStart: weekStart, freeMemo: m)
        case (let m?, let f?):
            input = WeekLayoutInput(focus: focus, events: events, inkBottoms: ink, now: now, calendar: tokyo, weekStart: weekStart, extraFloor: f, freeMemo: m)
        }
        return WeekLayoutEngine.layout(input)
    }

    /// The week pages from each first day, with the memo, the bottom of each page's memo ink and the floor.
    static func memoPages(_ firstDays: [DayKey], weekStart: WeekStart, bottoms: [CGFloat] = [], floor: CGFloat = 0) -> [any PageLayout] {
        firstDays.enumerated().map { i, first in
            let ink: [CellKey: CGFloat] = i < bottoms.count && bottoms[i] > 0 ? [.extra: bottoms[i]] : [:]
            return week(first, weekStart, memo: true, ink: ink, floor: floor)
        }
    }

    static let grid = CGRect(x: 0, y: 0, width: 1400, height: 1920)
    static let memo = CGRect(x: 0, y: 1920, width: 1400, height: 6000)
}

// MARK: - The section

func runWeekMemoChecks() {
    section("week memo (1.3)")
    weekMemoLeftOutChecks()
    weekMemoShapeChecks()
    weekMemoAnswerChecks()
    weekMemoEventChecks()
    weekMemoGrowthChecks()
    weekMemoOverviewChecks()
    weekMemoFloorChecks()
    weekMemoWindowChecks()
    weekMemoNameChecks()
}

// MARK: 1. Left out, the week is 1.2.3's

/// Monday and Sunday × three weeks × floor {0, 7000, NaN} × memo ink or none: a week laid out without
/// `freeMemo` (or with it false) is 1.2.3's week, `==`: 1400 × 1920, one cell, no `extra`. Fails if the default
/// became true (before the frozen tests would) or a floor or memo ink reached a week without the memo.
func weekMemoLeftOutChecks() {
    for ws in WeekStart.allCases {
        for focus in WeekMemoFixtures.focuses {
            let plain = WeekMemoFixtures.week(focus, ws, memo: nil)
            let label = "week memo: a \(ws) week of \(focus) without the memo"
            checkEqual(plain.size, CGSize(width: 1400, height: 1920), "\(label) is 1400 × 1920 (1.2.3)")
            checkEqual(plain.cells, [.grid: WeekMemoFixtures.grid], "\(label) has the grid as its one cell")
            checkEqual(plain.extra, .zero, "\(label) has no extra")
            check(WeekMemoFixtures.week(focus, ws, memo: false) == plain, "\(label): freeMemo false is the same as leaving it out")
            for floor in [CGFloat(0), 7000, .nan] {
                for ink in [[:], [CellKey.extra: 6950, .grid: 1500]] as [[CellKey: CGFloat]] {
                    check(WeekMemoFixtures.week(focus, ws, memo: nil, ink: ink, floor: floor) == plain,
                          "\(label), floor \(floor) and \(ink.isEmpty ? "no ink" : "memo ink at 6,950") is 1.2.3's week, ==")
                }
            }
        }
    }
}

// MARK: 2. The shape of the week with its memo

/// 1400 × 7920, the grid (0, 0, 1400, 1920), the memo (0, 1920, 1400, 6000), the cells grid and extra; the boxes,
/// labels, now line, band, page id, days and today are the week's without the memo (K-4: only the memo is added);
/// the floor and the memo ink set its height as on the day (SpanChecks' table at 1,920).
func weekMemoShapeChecks() {
    for ws in WeekStart.allCases {
        for focus in WeekMemoFixtures.focuses {
            let plain = WeekMemoFixtures.week(focus, ws, memo: nil)
            let memo = WeekMemoFixtures.week(focus, ws, memo: true)
            let label = "week memo: the \(ws) week of \(focus) with the memo"
            checkEqual(memo.size, CGSize(width: 1400, height: 7920), "\(label) is 1400 × 7,920")
            checkEqual(memo.grid, WeekMemoFixtures.grid, "\(label): the grid is (0, 0, 1400, 1920)")
            checkEqual(memo.extra, WeekMemoFixtures.memo, "\(label): the memo is (0, 1920, 1400, 6000)")
            checkEqual(memo.cells, [.grid: WeekMemoFixtures.grid, .extra: WeekMemoFixtures.memo], "\(label): the cells are the grid and the memo")
            check(memo.pageId == plain.pageId && memo.days == plain.days && memo.allDayBand == plain.allDayBand && memo.timedBoxes == plain.timedBoxes
                  && memo.dateLabels == plain.dateLabels && memo.nowLine == plain.nowLine && memo.todayColumn == plain.todayColumn
                  && memo.allDayBars == plain.allDayBars && (0..<7).allSatisfy { memo.columnFrame($0) == plain.columnFrame($0) },
                  "\(label): nothing but the memo is added (K-4)")
            check(!memo.sameGeometry(as: plain), "\(label) is another geometry than the week without it")
        }
    }
    let focus = day(2026, 10, 14)
    // The pageIds the memo weeks keep (K-11: one memo per week start).
    checkEqual(WeekMemoFixtures.week(focus, .monday, memo: true).pageId, "w-2026-10-12", "week memo: the Monday week's memo is on w-2026-10-12")
    checkEqual(WeekMemoFixtures.week(focus, .sunday, memo: true).pageId, "w-2026-10-11", "week memo: the Sunday week's memo is on w-2026-10-11")
    // Ink in the grid never grows anything; ink and floors that stay within 6,000 give the same week.
    let memo = WeekMemoFixtures.week(focus, memo: true)
    for bottom in [nil, CGFloat(0), 3000, 5950] as [CGFloat?] {
        var ink: [CellKey: CGFloat] = [.grid: 1900]
        if let bottom { ink[.extra] = bottom }
        for floor in [CGFloat(0), 5000, 6000, -100, .nan, .infinity, -.infinity] {
            check(WeekMemoFixtures.week(focus, memo: true, ink: ink, floor: floor) == memo,
                  "week memo: memo ink \(bottom.map { "\($0)" } ?? "none") and floor \(floor) give the 6,000 lu memo")
        }
    }
    let heights: [(String, CGFloat?, CGFloat?, CGFloat)] = [
        ("memo ink at 5,951 → 6,001", 5951, nil, 6001),
        ("floor 7,000 → 7,000", nil, 7000, 7000),
        ("memo ink at 7,150 → 7,200", 7150, nil, 7200),
        ("the page's own 7,200 beats floor 7,000", 7150, 7000, 7200),
        ("floor 7,300 beats the page's own 7,200", 7150, 7300, 7300),
        ("memo ink not finite counts as 0", .infinity, nil, 6000),
        ("negative memo ink counts as 0", -40, nil, 6000),
    ]
    for (name, bottom, floor, height) in heights {
        let w = WeekMemoFixtures.week(focus, memo: true, ink: bottom.map { [.extra: $0] } ?? [:], floor: floor)
        checkEqual(w.extra, CGRect(x: 0, y: 1920, width: 1400, height: height), "week memo: \(name) (extra)")
        checkEqual(w.size, CGSize(width: 1400, height: 1920 + height), "week memo: \(name) (the paper)")
        checkEqual(w.cells[.extra], w.extra, "week memo: \(name) (the extra cell follows)")
        checkEqual(w.cells[.grid], WeekMemoFixtures.grid, "week memo: \(name) (the grid stays)")
    }
    check(WeekMemoFixtures.week(focus, memo: true, ink: [.extra: 100]).sameGeometry(as: memo),
          "week memo: memo ink inside the 6,000 lu keeps the geometry")
}

// MARK: 3. The answers around 24:00

/// x {−10, 0, 63.9, 64, 700, 1399.9, 1400, 1400.1} × y {−10, 0, 1919.9, 1920, 1920.1, 5000, 7919.9, 7920, 9000}:
/// `cell(at:)`, `inkCell(forCenter:)`, `band(atY:)`, `dayAt(point:)` and `hit(at:)` of the Monday and the Sunday
/// week holding today, with and without the memo; `growsWithInk`, `bandTop`. Fails if a centre below 24:00 were
/// not the memo's, a double tap in the memo opened a day, or a week without the memo changed an answer.
func weekMemoAnswerChecks() {
    let xs: [CGFloat] = [-10, 0, 63.9, 64, 700, 1399.9, 1400, 1400.1]
    let ys: [CGFloat] = [-10, 0, 1919.9, 1920, 1920.1, 5000, 7919.9, 7920, 9000]
    // The day column of each x by hand: (x − 64) ÷ 190.857…, the gutter and the outside have none, 1400 is the last.
    let columns: [CGFloat: Int] = [64: 0, 700: 3, 1399.9: 6, 1400: 6]
    let cases: [(WeekStart, [DayKey])] = [(.monday, (12...18).map { day(2026, 10, $0) }), (.sunday, (11...17).map { day(2026, 10, $0) })]
    let focus = day(2026, 10, 14)
    for (ws, days) in cases {
        let plain = WeekMemoFixtures.week(focus, ws, memo: nil)
        let memo = WeekMemoFixtures.week(focus, ws, memo: true)
        checkEqual(memo.days, days, "week memo answers: the \(ws) week's days")
        for x in xs {
            for y in ys {
                let p = CGPoint(x: x, y: y)
                let onPaperX = x >= 0 && x <= 1400
                let day = (y >= 0 && y < 1920) ? columns[x].map { days[$0] } : nil
                let hitAbove = plain.hit(at: p)
                // With the memo.
                let cell: CellKey? = onPaperX && y >= 0 && y < 7920 ? (y < 1920 ? .grid : .extra) : nil
                let ink: CellKey = y >= 1920 ? .extra : .grid
                let band: PageBand? = y >= 0 && y < 7920 ? (y < 1920 ? .grid : .extra) : nil
                let hit: HitTarget? = y >= 1920 ? nil : hitAbove
                if ws == .monday {
                    let at = "week memo answers: Monday week at (\(x), \(y))"
                    checkEqual(memo.cell(at: p), cell, "\(at): cell")
                    checkEqual(memo.inkCell(forCenter: p), ink, "\(at): inkCell")
                    checkEqual(memo.band(atY: y), band, "\(at): band")
                    checkEqual(memo.dayAt(point: p), day, "\(at): dayAt")
                    checkEqual(memo.hit(at: p), hit, "\(at): hit")
                } else {
                    check(memo.cell(at: p) == cell && memo.inkCell(forCenter: p) == ink && memo.band(atY: y) == band
                          && memo.dayAt(point: p) == day && memo.hit(at: p) == hit,
                          "week memo answers: Sunday week at (\(x), \(y)): cell \(cell.map(\.raw) ?? "nil"), inkCell \(ink.raw), band \(band.map { "\($0)" } ?? "nil"), dayAt \(day.map { "\($0)" } ?? "nil"), hit \(hit.map { "\($0)" } ?? "nil")")
                }
                // Without the memo: 1.2.3's answers.
                let plainCell: CellKey? = onPaperX && y >= 0 && y < 1920 ? .grid : nil
                let plainBand: PageBand? = y >= 0 && y < 1920 ? .grid : nil
                check(plain.cell(at: p) == plainCell && plain.inkCell(forCenter: p) == .grid && plain.band(atY: y) == plainBand
                      && plain.dayAt(point: p) == day,
                      "week memo answers: the \(ws) week without the memo at (\(x), \(y)) answers as 1.2.3's")
            }
        }
        // Not finite: the grid, never nil; nothing else.
        check(memo.inkCell(forCenter: CGPoint(x: 700, y: CGFloat.nan)) == .grid && memo.inkCell(forCenter: CGPoint(x: CGFloat.nan, y: 3000)) == .extra
              && memo.cell(at: CGPoint(x: CGFloat.nan, y: 3000)) == nil && memo.band(atY: .nan) == nil && memo.dayAt(point: CGPoint(x: 700, y: CGFloat.nan)) == nil,
              "week memo answers: the \(ws) week: a y that is not finite is the grid's ink, no cell, band or day")
        check(memo.hit(at: CGPoint(x: 700, y: 1919.9)) == plain.hit(at: CGPoint(x: 700, y: 1919.9)),
              "week memo answers: the \(ws) week: a tap just above 24:00 hits what the week without the memo hits")
        // Growth and bands.
        check(memo.growsWithInk(.extra) && !memo.growsWithInk(.grid) && !memo.growsWithInk(.memo) && !memo.growsWithInk(.day(day(2026, 10, 14))),
              "week memo answers: the \(ws) week: only extra grows with ink")
        check(!plain.growsWithInk(.extra) && !plain.growsWithInk(.grid), "week memo answers: the \(ws) week without the memo grows nothing (1.2.3)")
        check(memo.bandTop(.grid) == 0 && memo.bandTop(.extra) == 1920 && memo.bandTop(.memo) == nil,
              "week memo answers: the \(ws) week: bandTop grid 0, extra 1920, memo nil")
        check(plain.bandTop(.grid) == 0 && plain.bandTop(.extra) == nil, "week memo answers: the \(ws) week without the memo has no extra band")
        let grown = WeekMemoFixtures.week(focus, ws, memo: true, ink: [.extra: 6500])
        check(PageScroll.scrollDelta(old: memo, new: grown, topVisibleY: 3000) == 0 && PageScroll.scrollDelta(old: memo, new: grown, topVisibleY: 500) == 0,
              "week memo answers: the \(ws) week: the memo's growth scrolls nothing")
    }
}

// MARK: 4. No event in the memo

/// `startsBelowDay`: the day's ten rects at 1,920 (true only from 24:00 down, a finite rect), always false on a
/// week without the memo; `eventRange` itself is unchanged. Fails if the memo's guard were missing, or a week
/// without the memo refused its 23:00 event.
func weekMemoEventChecks() {
    let focus = day(2026, 10, 14)
    let rects: [(String, CGRect, Bool)] = [
        ("minY 1,919.9", CGRect(x: 100, y: 1919.9, width: 200, height: 100), false),
        ("minY 1,920", CGRect(x: 100, y: 1920, width: 200, height: 100), true),
        ("a tap below 24:00", CGRect(x: 700, y: 2400, width: 0, height: 0), true),
        ("a drag upward from the memo", CGRect(x: 100, y: 2000, width: 100, height: -300), false),
        ("an upward drag that stays below 24:00", CGRect(x: 100, y: 2100, width: 100, height: -150), true),
        ("NaN", CGRect(x: 100, y: CGFloat.nan, width: 100, height: 100), false),
        ("∞", CGRect(x: 100, y: CGFloat.infinity, width: 100, height: 100), false),
        ("CGRect.null", .null, false),
        ("a rect across 24:00", CGRect(x: 100, y: 1000, width: 100, height: 2000), false),
        ("a rect at the memo's bottom right, past the paper", CGRect(x: 1300, y: 7900, width: 200, height: 100), true),
    ]
    for ws in WeekStart.allCases {
        let plain = WeekMemoFixtures.week(focus, ws, memo: nil)
        let memo = WeekMemoFixtures.week(focus, ws, memo: true)
        for (name, rect, expected) in rects {
            checkEqual(memo.startsBelowDay(rect), expected, "week memo events: the \(ws) week: startsBelowDay, \(name)")
            checkEqual(plain.startsBelowDay(rect), false, "week memo events: the \(ws) week without the memo: startsBelowDay, \(name) → false (1.2.3)")
            check(memo.eventRange(for: rect, now: WeekMemoFixtures.now, calendar: tokyo) == plain.eventRange(for: rect, now: WeekMemoFixtures.now, calendar: tokyo),
                  "week memo events: the \(ws) week: eventRange of \(name) is unchanged")
        }
    }
    checkEqual(WeekMemoFixtures.week(focus, memo: true).eventRange(for: CGRect(x: 700, y: 3000, width: 100, height: 100), now: WeekMemoFixtures.now, calendar: tokyo),
               .timed(day(2026, 10, 15), startMinute: 1380, endMinute: 1440, calendar: tokyo),
               "week memo events: a rect in the memo still snaps to Thursday 23:00–24:00 (the screen refuses it first)")
}

// MARK: 5. Growth: the week's last cell

/// `PaperGrowth.tail` (the memo, or nil without it), `drop` (6,000 below 24:00 kept, 6,000.5 beyond the cap, beside
/// the paper outside), `onlyTailHeightChanged`, `needsMoreRoom`. Fails if the week were left out of `tail`.
func weekMemoGrowthChecks() {
    let focus = day(2026, 10, 14)
    for ws in WeekStart.allCases {
        let plain = WeekMemoFixtures.week(focus, ws, memo: nil)
        let memo = WeekMemoFixtures.week(focus, ws, memo: true)
        let label = "week memo growth: the \(ws) week"
        checkEqual(PaperGrowth.tail(of: memo)?.key, .extra, "\(label): tail → extra")
        checkEqual(PaperGrowth.tail(of: memo)?.rect, WeekMemoFixtures.memo, "\(label): tail rect (0, 1920, 1400, 6000)")
        check(PaperGrowth.tail(of: plain) == nil, "\(label) without the memo: tail → nil (1.2.3)")
        let drops: [(CGFloat, CGFloat, PaperGrowth.Drop?)] = [
            (700, 1000, nil), (700, 1919.9, nil), (700, 1920, nil), (700, 2500, nil), (700, 1920 + 6000, nil),
            (700, 1920 + 6000.5, .beyondCap), (0, 7921, .beyondCap), (1400, 9000, .beyondCap),
            (-1, 3000, .outsidePaper), (1400.1, 3000, .outsidePaper), (-1, 9000, .outsidePaper), (700, -0.5, .outsidePaper),
            (CGFloat.nan, 3000, .outsidePaper), (700, CGFloat.infinity, .outsidePaper),
        ]
        for (x, y, expected) in drops {
            checkEqual(PaperGrowth.drop(center: CGPoint(x: x, y: y), in: memo), expected, "\(label): drop at (\(x), \(y))")
        }
        checkEqual(PaperGrowth.drop(center: CGPoint(x: 700, y: 2500), in: plain), .outsidePaper, "\(label) without the memo: below 24:00 is outside the paper (1.2.3)")
        checkEqual(PaperGrowth.drop(center: CGPoint(x: 700, y: 9000), in: plain), .outsidePaper, "\(label) without the memo: far below is outside the paper (1.2.3)")
        // A deep line from an old device made the memo longer: the cap stays 6,000 below 24:00.
        let deep = WeekMemoFixtures.week(focus, ws, memo: true, ink: [.extra: 6420])
        checkEqual(deep.size.height, 1920 + 6470, "\(label): memo ink at 6,420 makes the paper 1920 + 6,470")
        checkEqual(PaperGrowth.drop(center: CGPoint(x: 700, y: 1920 + 6100), in: deep), .beyondCap, "\(label): inside the longer paper, below the cap → beyondCap")
        checkEqual(PaperGrowth.drop(center: CGPoint(x: 700, y: 1920 + 5999), in: deep), nil, "\(label): inside the longer paper, above the cap → keep")

        let taller = WeekMemoFixtures.week(focus, ws, memo: true, ink: [.extra: 6050])
        checkEqual(taller.extra.height, 6100, "\(label): memo ink at 6,050 → 6,100")
        check(PaperGrowth.onlyTailHeightChanged(old: memo, new: taller), "\(label): 6,000 → 6,100 is a tail-only change")
        check(PaperGrowth.onlyTailHeightChanged(old: taller, new: memo), "\(label): 6,100 → 6,000 is a tail-only change")
        check(!PaperGrowth.onlyTailHeightChanged(old: memo, new: memo), "\(label): nothing changed → false")
        check(!PaperGrowth.onlyTailHeightChanged(old: memo, new: WeekMemoFixtures.week(focus, ws, memo: true, ink: [.extra: 300])), "\(label): ink inside the 6,000 → false")
        check(!PaperGrowth.onlyTailHeightChanged(old: plain, new: WeekMemoFixtures.week(focus, ws, memo: nil, ink: [.extra: 6050])), "\(label) without the memo → false")
        check(!PaperGrowth.onlyTailHeightChanged(old: plain, new: memo) && !PaperGrowth.onlyTailHeightChanged(old: memo, new: plain),
              "\(label): adding or taking away the memo is no tail-only change")
        check(!PaperGrowth.onlyTailHeightChanged(old: memo, new: WeekMemoFixtures.week(day(2026, 10, 21), ws, memo: true, ink: [.extra: 6050])),
              "\(label): another week → false")
    }
    check(PaperGrowth.isTail(.extra) && !PaperGrowth.isTail(.grid), "week memo growth: extra is a last cell, the grid is not")
    checkEqual(PaperGrowth.needsMoreRoom(cell: .extra, cellHeight: 6000, inkBottom: 5951), true, "week memo growth: needsMoreRoom(extra, 6000, 5951)")
    checkEqual(PaperGrowth.needsMoreRoom(cell: .extra, cellHeight: 6000, inkBottom: 5950), false, "week memo growth: needsMoreRoom(extra, 6000, 5950)")
    checkEqual(PaperGrowth.needsMoreRoom(cell: .grid, cellHeight: 1920, inkBottom: 1950), true, "week memo growth: the grid keeps the rule of the other cells")
}

// MARK: 6. The overview is the 24 hours

/// `ZoomPolicy.overviewSize` of a memo week is 1400 × 1920 (K-6), and the four zoom scales of a memo week and of a
/// week without it are the same on ten paper areas. Fails if the overview took the memo in (the lower limit would
/// drop to about a quarter).
func weekMemoOverviewChecks() {
    let focus = day(2026, 10, 14)
    let plain = WeekMemoFixtures.week(focus, memo: nil)
    let memo = WeekMemoFixtures.week(focus, memo: true)
    let deep = WeekMemoFixtures.week(focus, memo: true, ink: [.extra: 7000])
    checkEqual(ZoomPolicy.overviewSize(memo), CGSize(width: 1400, height: 1920), "week memo overview: the 24 hours (K-6)")
    checkEqual(ZoomPolicy.overviewSize(deep), CGSize(width: 1400, height: 1920), "week memo overview: a long memo does not count")
    checkEqual(ZoomPolicy.overviewSize(plain), CGSize(width: 1400, height: 1920), "week memo overview: the week without the memo (1.2.3)")
    checkEqual(ZoomPolicy.overviewSize(memo), ZoomPolicy.baseSize(.week), "week memo overview: the base size")
    // The week's paper areas (pt): SpanPlan's reference for the four classes in both orientations (the iPhone is
    // the iPhone 17), and the iPhone 18 Pro Max (the width of main.swift's table; the height its year's less one lane).
    var viewports: [(String, CGSize)] = []
    for orientation in SpanOrientation.allCases {
        for device in [SpanDeviceClass.iPad13, .iPad11, .iPadMini, .iPhone] {
            viewports.append(("\(device) \(orientation)", SpanPlan.referenceViewport(.week, deviceClass: device, orientation: orientation)))
        }
    }
    viewports += [("iPhone 18 Pro Max portrait", CGSize(width: 440, height: 622)), ("iPhone 18 Pro Max landscape", CGSize(width: 832, height: 221))]
    checkEqual(viewports.count, 10, "week memo overview: ten paper areas")
    for (name, viewport) in viewports {
        let a = ZoomPolicy.bounds(.week, overview: ZoomPolicy.overviewSize(memo), viewport: viewport)
        let b = ZoomPolicy.bounds(.week, overview: ZoomPolicy.overviewSize(plain), viewport: viewport)
        let c = ZoomPolicy.bounds(.week, overview: ZoomPolicy.overviewSize(deep), viewport: viewport)
        check(a == b && c == b, "week memo overview: \(name): min, open, fit and max are the week's without the memo")
        checkEqual(a.min, a.open, "week memo overview: \(name): the memo week opens at its lower limit")
    }
}

// MARK: 7. The week's floor

/// `SpanAlign.weekFloors`: the day's eleven rules on the week (from ink bottoms), `dayExtra` kept, and a window
/// through a deep line, a shift, deciding again and an erase. Fails if `weekFloors` kept the floor as it was or
/// moved the day's.
func weekMemoFloorChecks() {
    let rules: [(String, CGFloat, [CGFloat], SpanAlign.Change, CGFloat)] = [
        ("a shift never lowers", 7000, [0, 0, 0], .shift, 7000),
        ("a shift raises", 6000, [0, 6750], .shift, 6800),
        ("a shift to no page keeps", 6000, [], .shift, 6000),
        ("ink that grew raises", 7000, [0, 7150], .inkGrew, 7200),
        ("ink that grew elsewhere keeps", 7000, [0], .inkGrew, 7000),
        ("erasing lowers to the tallest", 7000, [0, 6450], .inkShrank, 6500),
        ("erasing lowers to 6,000", 7000, [0], .inkShrank, 6000),
        ("deciding again takes the tallest", 9000, [0, 6050], .redecide, 6100),
        ("deciding again without pages is 0", 9000, [], .redecide, 0),
        ("a previous floor that is not finite counts as 0", .nan, [0], .shift, 6000),
        ("an ink bottom that is not finite counts as 0", 0, [.infinity, 0], .redecide, 6000),
    ]
    for (name, previous, bottoms, change, expected) in rules {
        checkEqual(SpanAlign.weekFloors(previous: SpanAlign.Floors(dayExtra: 7777, weekExtra: previous), extraInkBottoms: bottoms, change: change),
                   SpanAlign.Floors(dayExtra: 7777, weekExtra: expected), "week memo floor: \(name) (the day's floor is kept)")
    }
    checkEqual(SpanAlign.dayFloors(previous: SpanAlign.Floors(dayExtra: 0, weekExtra: 6500), extraInkBottoms: [6950], change: .redecide),
               SpanAlign.Floors(dayExtra: 7000, weekExtra: 6500), "week memo floor: the day's floors keep the week's")
    // A window of weeks: a line at 6,950 lines them up at 7,000; the deep week leaves (the floor stays), the window
    // is decided again (its tallest), and an erase in the window brings it down.
    var floors = SpanAlign.weekFloors(previous: .none, extraInkBottoms: [0, 6950, 0], change: .redecide)
    checkEqual(floors.weekExtra, 7000, "week memo floor: a window with a line at 6,950 lu lines up at 7,000")
    floors = SpanAlign.weekFloors(previous: floors, extraInkBottoms: [0, 0, 0], change: .shift)
    checkEqual(floors.weekExtra, 7000, "week memo floor: the deep week left the window: the floor stays 7,000")
    floors = SpanAlign.weekFloors(previous: floors, extraInkBottoms: [0, 0, 0], change: .redecide)
    checkEqual(floors.weekExtra, 6000, "week memo floor: decided again from the window: its tallest, 6,000")
    floors = SpanAlign.weekFloors(previous: SpanAlign.Floors(weekExtra: 7000), extraInkBottoms: [0, 120, 0], change: .inkShrank)
    checkEqual(floors.weekExtra, 6000, "week memo floor: erasing in the window brings it down to 6,000")
    checkEqual(floors.floor(for: .week), 6000, "week memo floor: floor(for: .week) is weekExtra")
}

// MARK: 8. Joined memo weeks

/// Three memo weeks of each start as one `SpanLayout`: 4200 × 7920, six cells, the boundaries (D15: x 1400 goes
/// right) at 24:00, the cap per page, growth by the prefixed name, the bands, the floor of one deep line lining
/// up every page as a tail-only change, and the event target in the memo. Fails if the memo cells were not on
/// every page or the floor did not reach them.
func weekMemoWindowChecks() {
    let cases: [(WeekStart, [DayKey])] = [(.monday, [5, 12, 19].map { day(2026, 10, $0) }), (.sunday, [4, 11, 18].map { day(2026, 10, $0) })]
    for (ws, firsts) in cases {
        let plan = SpanFixtures.plan(.week, ws)
        let ids = firsts.map { "w-\($0)" }
        let span = SpanFixtures.window(WeekMemoFixtures.memoPages(firsts, weekStart: ws), plan: plan)
        let label = "week memo window: \(ws) weeks"
        check(span.pages.map(\.pageId) == ids, "\(label): the pages \(ids)")
        checkEqual(span.size, CGSize(width: 4200, height: 7920), "\(label): 4200 × 7920")
        var cells: [CellKey: CGRect] = [:]
        for (i, id) in ids.enumerated() {
            cells[CellKey(raw: id + "|grid")] = CGRect(x: 1400 * CGFloat(i), y: 0, width: 1400, height: 1920)
            cells[CellKey(raw: id + "|extra")] = CGRect(x: 1400 * CGFloat(i), y: 1920, width: 1400, height: 6000)
        }
        checkEqual(span.cells, cells, "\(label): six cells, a grid and a memo per page")
        let points: [(CGFloat, CGFloat, Int, String)] = [
            (1399.9, 1919.9, 0, "grid"), (1399.9, 1920, 0, "extra"), (1400, 1919.9, 1, "grid"), (1400, 1920, 1, "extra"),
            (1400.1, 1919.9, 1, "grid"), (1400.1, 1920, 1, "extra"), (2799.9, 1920, 1, "extra"), (2800, 1919.9, 2, "grid"),
            (2800, 1920, 2, "extra"), (64, 7919.9, 0, "extra"), (4200, 100, 2, "grid"), (4200, 7920, 2, "extra"),
        ]
        for (x, y, slot, cell) in points {
            checkEqual(span.inkCell(forCenter: CGPoint(x: x, y: y)).raw, "\(ids[slot])|\(cell)", "\(label): inkCell at (\(x), \(y))")
            checkEqual(span.drop(center: CGPoint(x: x, y: y)), .keep(page: ids[slot], cell: CellKey(raw: cell)), "\(label): drop at (\(x), \(y)) keeps it")
        }
        let drops: [(CGFloat, CGFloat, SpanDrop)] = [
            (700, 7920.5, .belowCap), (2100, 7920.5, .belowCap), (3500, 9000, .belowCap),
            (4200.1, 100, .outsidePaper), (-1, 3000, .outsidePaper), (2100, -0.5, .outsidePaper),
        ]
        for (x, y, expected) in drops {
            checkEqual(span.drop(center: CGPoint(x: x, y: y)), expected, "\(label): drop at (\(x), \(y))")
        }
        check(span.growsWithInk(CellKey(raw: ids[1] + "|extra")) && !span.growsWithInk(CellKey(raw: ids[1] + "|grid")) && !span.growsWithInk(.extra),
              "\(label): the prefixed memo grows, its grid does not, a bare name does not")
        check(span.band(atY: 2000) == .extra && span.band(atY: 1919.9) == .grid && span.bandTop(.extra) == 1920 && span.bandTop(.grid) == 0,
              "\(label): the bands of the middle page (extra from 1920)")
        check(span.cell(at: CGPoint(x: 2100, y: 3000))?.raw == ids[1] + "|extra" && span.dayAt(point: CGPoint(x: 2100, y: 3000)) == nil
              && span.hit(at: CGPoint(x: 2100, y: 3000)) == nil && span.dayAt(point: CGPoint(x: 2100, y: 100)) != nil,
              "\(label): in the memo of the middle page: its cell, no day, no hit; above 24:00 a day")
        if let target = span.eventTarget(at: CGPoint(x: 2100, y: 3000)) {
            check(target.pageId == ids[1] && target.local == CGPoint(x: 700, y: 3000), "\(label): the event target in the memo is the middle page at (700, 3000)")
            check((span.pages[1] as? WeekPageLayout)?.startsBelowDay(CGRect(origin: target.local, size: CGSize(width: 50, height: 50))) == true,
                  "\(label): that page refuses an event there")
        } else {
            check(false, "\(label): the event target in the memo")
        }
        let plainSpan = SpanFixtures.window(SpanFixtures.weekPages(firsts, weekStart: ws, events: WeekMemoFixtures.events, now: WeekMemoFixtures.now), plan: plan)
        let rect = CGRect(x: 2000, y: 3000, width: 200, height: 100)
        check(span.eventRange(for: rect, now: WeekMemoFixtures.now, calendar: tokyo) == plainSpan.eventRange(for: rect, now: WeekMemoFixtures.now, calendar: tokyo),
              "\(label): eventRange in the memo is unchanged")
        check(plainSpan.size == CGSize(width: 4200, height: 1920) && plainSpan.inkCell(forCenter: CGPoint(x: 700, y: 2500)).raw == ids[0] + "|grid",
              "\(label): the same weeks without the memo are 1.2.3's (4200 × 1920, below 24:00 the grid)")

        // One page with a line at 6,950: the floor lines every page up at 7,000, a tail-only change both ways.
        let floors = SpanAlign.weekFloors(previous: .none, extraInkBottoms: [6950, 0, 0], change: .redecide)
        checkEqual(floors.weekExtra, 7000, "\(label): the floor of a line at 6,950 on the first page")
        let lined = SpanLayout(pages: WeekMemoFixtures.memoPages(firsts, weekStart: ws, bottoms: [6950, 0, 0], floor: floors.weekExtra),
                               plan: plan, firstIndex: span.firstIndex, floors: floors)
        check(lined.pages.allSatisfy { ($0 as? WeekPageLayout)?.extra.height == 7000 && $0.size.height == 8920 } && lined.size == CGSize(width: 4200, height: 8920),
              "\(label): every page's memo is 7,000 (the paper 1920 + 7,000)")
        check(lined.onlyTailHeightChanged(from: span) && span.onlyTailHeightChanged(from: lined), "\(label): lining up is a tail-only change, both ways")
        checkEqual(lined.drop(center: CGPoint(x: 2100, y: 7920.5)), .belowCap, "\(label): with the floor the cap is still 6,000 below 24:00 on each page")
        checkEqual(lined.drop(center: CGPoint(x: 2100, y: 7920)), .keep(page: ids[1], cell: .extra), "\(label): with the floor, 6,000 below 24:00 is kept")
        let uneven = SpanFixtures.window(WeekMemoFixtures.memoPages(firsts, weekStart: ws, bottoms: [6950, 0, 0]), plan: plan)
        check(uneven.pages.map(\.size.height) == [8920, 7920, 7920] && uneven.size.height == 8920,
              "\(label): without the floor only the deep page is longer (the window is as tall as it)")
    }
}

// MARK: 9. The memo's name

/// K-1: `extra` is no band cell; a `w-` page with memo strokes (Monday and Sunday) saves and transfers as it is;
/// K-10: the memo week's page id and cells hold no "|" and no "~"; a prefixed memo name stripped is the bare
/// name's last cell. Fails if a week memo stroke were refused or migrated.
func weekMemoNameChecks() {
    check(!BandMigration.isBandCell(.extra), "week memo names: K-1 extra is no band cell")
    for (ws, id) in [(WeekStart.monday, "w-2026-10-12"), (.sunday, "w-2026-10-11")] {
        let memo = WeekMemoFixtures.week(day(2026, 10, 14), ws, memo: true)
        checkEqual(memo.pageId, id, "week memo names: the \(ws) memo week is \(id)")
        check(!memo.pageId.contains("|") && !memo.pageId.contains("~") && memo.cells.keys.allSatisfy { !$0.raw.contains("|") && !$0.raw.contains("~") && !SpanName.isPrefixed($0.raw) },
              "week memo names: K-10 the \(ws) memo week's id and cells have no | and no ~")
        let a = stroke("wm-a", cell: .extra, points: [point(100, 50), point(300, 120, dt: 16)])
        let b = stroke("wm-b~w1", cell: .extra, t: 1_760_150_400_456, points: [point(900, 5800), point(1000, 5940, dt: 16)])
        let g = stroke("wm-g", cell: .grid, t: 1_760_150_400_789, points: [point(700, 1860), point(720, 1970, dt: 16)])
        let page = InkPage(pageId: id, strokes: [a.id: a, b.id: b, g.id: g], updatedAt: 1_760_150_400_789)
        checkEqual(SpanGuard.checkForSave(page), .ok, "week memo names: the \(ws) page \(id) with memo strokes saves as it is")
        check(SpanGuard.checkForTransfer(page), "week memo names: the \(ws) page \(id) with memo strokes transfers")
        checkEqual(page.inkBottoms()[.extra], 5941.75, "week memo names: the memo ink bottom of \(id) is cell-relative: 5,940 + half the 3.5 nib")
        check(!BandMigration.needsMigration(page) && BandMigration.migrate(page) == page,
              "week memo names: BandMigration leaves the page \(id) with memo strokes as it is")
    }
    let prefixed = SpanName.prefixed(.extra, page: "w-2026-10-12")
    checkEqual(prefixed.raw, "w-2026-10-12|extra", "week memo names: the prefixed memo name")
    check(SpanName.strip(prefixed) == .extra && PaperGrowth.isTail(SpanName.strip(prefixed))
          && PaperGrowth.needsMoreRoom(cell: SpanName.strip(prefixed), cellHeight: 6000, inkBottom: 5951) == PaperGrowth.needsMoreRoom(cell: .extra, cellHeight: 6000, inkBottom: 5951),
          "week memo names: stripped, the prefixed memo is the bare name's last cell")
}
