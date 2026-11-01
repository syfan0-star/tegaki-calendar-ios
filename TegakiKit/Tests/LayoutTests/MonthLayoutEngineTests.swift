import XCTest
import Foundation
import CoreGraphics
import Layout

/// Month page geometry (M2_CONTRACT §1, DESIGN §2.2). Lane-packing expectations are copied from the
/// web version's tests/event-layout.test.mjs (allDayRowsForRange).
final class MonthLayoutEngineTests: XCTestCase {
    private static let tokyo: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        c.locale = Locale(identifier: "ja_JP")
        return c
    }()

    private var tokyo: Calendar { Self.tokyo }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y
        c.month = m
        c.day = d
        c.hour = h
        c.minute = mi
        return tokyo.date(from: c)!
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

    /// Local time on October `n` 2026 (n may exceed 31).
    private func october(_ n: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        let base = tokyo.date(byAdding: .day, value: n - 1, to: date(2026, 10, 1))!
        return tokyo.date(byAdding: .minute, value: h * 60 + mi, to: base)!
    }

    private func allDay(_ id: String, _ startDay: Int, _ endDayExclusive: Int, title: String? = nil) -> LayoutEvent {
        LayoutEvent(id: id, title: title ?? id, allDay: true, start: october(startDay), end: october(endDayExclusive), colorHex: "#33b679", calendarId: "primary")
    }

    private func timed(_ id: String, _ d: Int, _ sh: Int, _ sm: Int, _ eh: Int, _ em: Int, endDay: Int? = nil, title: String? = nil) -> LayoutEvent {
        LayoutEvent(id: id, title: title ?? id, allDay: false, start: october(d, sh, sm), end: october(endDay ?? d, eh, em), colorHex: "#039be5", calendarId: "primary")
    }

    private func layout(_ events: [LayoutEvent], ink: [CellKey: CGFloat] = [:], now: Date? = nil) -> MonthPageLayout {
        MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 10), events: events, inkBottoms: ink, now: now ?? date(2026, 10, 12, 12), calendar: tokyo))
    }

    /// Sun 10/4 – Sat 10/10, the week of the web tests.
    private var weekDays: [DayKey] { (4...10).map { day(2026, 10, $0) } }

    private func lanes(_ events: [LayoutEvent], days: [DayKey]? = nil) -> [String: [Int]] {
        var out: [String: [Int]] = [:]
        for span in MonthLayoutEngine.packAllDayLanes(events: events, days: days ?? weekDays, calendar: tokyo) {
            out[span.event.id] = [span.startCol, span.endCol, span.lane]
        }
        return out
    }

    // MARK: Row height

    func testRowHeightFormula() {
        XCTAssertEqual(MonthLayoutEngine.rowHeight(laneCount: 0, maxChips: 0, inkBottom: 0), 175)
        XCTAssertEqual(MonthLayoutEngine.rowHeight(laneCount: 2, maxChips: 1, inkBottom: 0), 175, "138 < 175")
        XCTAssertEqual(MonthLayoutEngine.rowHeight(laneCount: 3, maxChips: 3, inkBottom: 0), 203)
        XCTAssertEqual(MonthLayoutEngine.rowHeight(laneCount: 10, maxChips: 3, inkBottom: 0), 378)
        XCTAssertEqual(MonthLayoutEngine.rowHeight(laneCount: 0, maxChips: 0, inkBottom: 300), 312)
        XCTAssertEqual(MonthLayoutEngine.rowHeight(laneCount: 0, maxChips: 0, inkBottom: 160), 175)
        XCTAssertEqual(MonthLayoutEngine.rowHeight(laneCount: 0, maxChips: 0, inkBottom: 5000), 1200)
        XCTAssertEqual(MonthLayoutEngine.rowHeight(laneCount: 60, maxChips: 3, inkBottom: 0), 1200)
        XCTAssertEqual(MonthLayoutEngine.rowHeight(laneCount: 0, maxChips: 0, inkBottom: .nan), 175)
        XCTAssertEqual(MonthLayoutEngine.rowHeight(laneCount: 0, maxChips: 0, inkBottom: .infinity), 175)
        XCTAssertEqual(MonthLayoutEngine.rowHeight(laneCount: -3, maxChips: -1, inkBottom: -50), 175)
        XCTAssertEqual(MonthLayoutEngine.memoHeight(inkBottom: 0), 700)
        XCTAssertEqual(MonthLayoutEngine.memoHeight(inkBottom: 900), 1500, "1.1: 400 lu steps (PaperGrowth.tailHeight)")
    }

    func testShownChipCount() {
        XCTAssertTrue(MonthLayoutEngine.shownChipCount(for: 0) == (0, 0))
        XCTAssertTrue(MonthLayoutEngine.shownChipCount(for: 1) == (1, 0))
        XCTAssertTrue(MonthLayoutEngine.shownChipCount(for: 3) == (3, 0))
        XCTAssertTrue(MonthLayoutEngine.shownChipCount(for: 4) == (2, 2))
        XCTAssertTrue(MonthLayoutEngine.shownChipCount(for: 9) == (2, 7))
        XCTAssertTrue(MonthLayoutEngine.shownChipCount(for: -2) == (0, 0))
    }

    // MARK: Grid

    func testEmptyOctober2026() {
        let page = layout([])
        XCTAssertEqual(page.rows.count, 6)
        XCTAssertEqual(page.rows[0].days.first, day(2026, 9, 28))
        XCTAssertEqual(page.rows[0].days[3], day(2026, 10, 1))
        XCTAssertEqual(page.rows[5].days.last, day(2026, 11, 8))
        XCTAssertEqual(page.rows.map(\.index), [0, 1, 2, 3, 4, 5])
        XCTAssertEqual(page.cells.count, 43)
        XCTAssertEqual(page.size, CGSize(width: 1400, height: 1750), "same height as the web page")
        XCTAssertEqual(page.rows.map { $0.frame.minY }, [0, 175, 350, 525, 700, 875])
        XCTAssertEqual(page.rows.map { $0.frame.width }, Array(repeating: 1400, count: 6))
        XCTAssertEqual(page.memo, CGRect(x: 0, y: 1050, width: 1400, height: 700))
        XCTAssertEqual(page.cells[.day(day(2026, 10, 1))], CGRect(x: 600, y: 0, width: 200, height: 175))
        XCTAssertEqual(page.cells[.day(day(2026, 11, 8))], CGRect(x: 1200, y: 875, width: 200, height: 175))
        XCTAssertEqual(page.cells[.memo], page.memo)
        XCTAssertEqual(page.dateLabels.count, 42)
        XCTAssertTrue(page.allDayBars.isEmpty)
        XCTAssertTrue(page.timedChips.isEmpty)
    }

    func testDateLabels() {
        let page = layout([])
        let labels = Dictionary(uniqueKeysWithValues: page.dateLabels.map { ($0.day, $0) })
        XCTAssertEqual(labels[day(2026, 10, 12)]?.holidayName, "スポーツの日")
        XCTAssertEqual(labels[day(2026, 10, 12)]?.tone, .sundayOrHoliday)
        XCTAssertEqual(labels[day(2026, 10, 12)]?.isToday, true)
        XCTAssertEqual(labels[day(2026, 10, 11)]?.tone, .sundayOrHoliday)
        XCTAssertEqual(labels[day(2026, 10, 11)]?.holidayName, nil)
        XCTAssertEqual(labels[day(2026, 10, 10)]?.tone, .saturday)
        XCTAssertEqual(labels[day(2026, 10, 9)]?.tone, .normal)
        XCTAssertEqual(labels[day(2026, 9, 30)]?.inMonth, false)
        XCTAssertEqual(labels[day(2026, 10, 1)]?.inMonth, true)
        XCTAssertEqual(labels[day(2026, 11, 1)]?.inMonth, false)
        XCTAssertEqual(labels[day(2026, 10, 1)]?.frame, CGRect(x: 604, y: 4, width: 192, height: 24))
        XCTAssertEqual(page.dateLabels.filter(\.isToday).count, 1)
        // `now` outside the month: no today mark.
        XCTAssertEqual(layout([], now: date(2026, 12, 1)).dateLabels.filter(\.isToday).count, 0)
        // The today mark follows the layout's calendar, not the device's.
        let lateNight = layout([], now: date(2026, 10, 5, 23, 30))
        XCTAssertEqual(lateNight.dateLabels.first(where: \.isToday)?.day, day(2026, 10, 5))
    }

    func testCellAt() {
        let page = layout([])
        XCTAssertEqual(page.cell(at: CGPoint(x: 650, y: 10)), .day(day(2026, 10, 1)))
        XCTAssertEqual(page.cell(at: CGPoint(x: 0, y: 0)), .day(day(2026, 9, 28)))
        XCTAssertEqual(page.cell(at: CGPoint(x: 1400, y: 180)), .day(day(2026, 10, 11)), "right edge belongs to the last column")
        XCTAssertEqual(page.cell(at: CGPoint(x: 199.9, y: 174.9)), .day(day(2026, 9, 28)))
        XCTAssertEqual(page.cell(at: CGPoint(x: 200, y: 175)), .day(day(2026, 10, 6)))
        XCTAssertEqual(page.cell(at: CGPoint(x: 100, y: 1100)), .memo)
        XCTAssertEqual(page.cell(at: CGPoint(x: 10, y: 1749)), .memo)
        XCTAssertNil(page.cell(at: CGPoint(x: -1, y: 10)))
        XCTAssertNil(page.cell(at: CGPoint(x: 1401, y: 10)))
        XCTAssertNil(page.cell(at: CGPoint(x: 10, y: -1)))
        XCTAssertNil(page.cell(at: CGPoint(x: 10, y: 1750)))
        XCTAssertNil(page.cell(at: CGPoint(x: CGFloat.nan, y: 10)))
    }

    func testDayAt() {
        // M4c, M4C_CONTRACT §4.3: the double tap's target is the cell's day (a day outside the month
        // too); the memo area, the outside (the centring margins) and NaN are nil.
        let page = layout([])
        XCTAssertEqual(page.dayAt(point: CGPoint(x: 650, y: 10)), day(2026, 10, 1))
        XCTAssertEqual(page.dayAt(point: CGPoint(x: 500, y: 225)), day(2026, 10, 7), "column 2 of row 1")
        XCTAssertEqual(page.dayAt(point: CGPoint(x: 0, y: 0)), day(2026, 9, 28), "outside the month, still a day")
        XCTAssertEqual(page.dayAt(point: CGPoint(x: 1400, y: 180)), day(2026, 10, 11), "x 1400 belongs to the last column")
        XCTAssertEqual(page.dayAt(point: CGPoint(x: 199.9, y: 174.9)), day(2026, 9, 28))
        XCTAssertEqual(page.dayAt(point: CGPoint(x: 200, y: 175)), day(2026, 10, 6), "a cell boundary belongs to the next cell")
        XCTAssertEqual(page.dayAt(point: CGPoint(x: 100, y: 1049.9)), day(2026, 11, 2), "the last row")
        XCTAssertEqual(page.dayAt(point: CGPoint(x: 1400, y: 1049.9)), day(2026, 11, 8), "the grid's last cell")
        XCTAssertNil(page.dayAt(point: CGPoint(x: 100, y: 1050)), "the memo area")
        XCTAssertNil(page.dayAt(point: CGPoint(x: 100, y: 1100)))
        XCTAssertNil(page.dayAt(point: CGPoint(x: 10, y: 1749)))
        XCTAssertNil(page.dayAt(point: CGPoint(x: -1, y: 10)), "a centring margin (negative lu)")
        XCTAssertNil(page.dayAt(point: CGPoint(x: 1401, y: 10)))
        XCTAssertNil(page.dayAt(point: CGPoint(x: 10, y: -1)))
        XCTAssertNil(page.dayAt(point: CGPoint(x: 10, y: 1750)))
        XCTAssertNil(page.dayAt(point: CGPoint(x: CGFloat.nan, y: 10)))
        XCTAssertNil(page.dayAt(point: CGPoint(x: 10, y: CGFloat.nan)))
        XCTAssertNil(page.dayAt(point: CGPoint(x: CGFloat.infinity, y: 10)))
        let busy = layout(M3aFixtures.demo)
        XCTAssertEqual(busy.dayAt(point: CGPoint(x: 500, y: busy.memo.minY - 1)), day(2026, 11, 4), "the last row ends at memo.minY")
        XCTAssertNil(busy.dayAt(point: CGPoint(x: 500, y: busy.memo.minY)))
        XCTAssertEqual(busy.dayAt(point: CGPoint(x: 500, y: busy.rows[1].frame.minY + 10)), day(2026, 10, 7), "under a grown row")
        for (key, rect) in busy.cells where !key.isMemo {
            XCTAssertEqual(busy.dayAt(point: CGPoint(x: rect.midX, y: rect.midY)), key.day, "the centre of \(key)")
        }
        XCTAssertNil(busy.dayAt(point: CGPoint(x: busy.memo.midX, y: busy.memo.midY)))
        var rng = M3aFixtures.Rng(seed: 0x4D34_6300)
        for _ in 0..<40 {
            let p = CGPoint(x: CGFloat(rng.int(1500)) - 50, y: CGFloat(rng.int(1900)) - 50)
            XCTAssertEqual(busy.dayAt(point: p), busy.cell(at: p)?.day, "dayAt == cell(at:)?.day at \(p)")
        }
        XCTAssertEqual((page as any PageLayout).dayAt(point: CGPoint(x: 650, y: 10)), day(2026, 10, 1), "dynamic dispatch through any PageLayout")
    }

    func testPaperPointAndCellRelative() {
        let page = layout([])
        XCTAssertEqual(MonthLayoutEngine.paperPoint(of: .day(day(2026, 10, 6)), in: page), CGPoint(x: 200, y: 175))
        XCTAssertEqual(MonthLayoutEngine.paperPoint(of: .memo, in: page), CGPoint(x: 0, y: 1050))
        XCTAssertEqual(MonthLayoutEngine.paperPoint(of: CellKey(raw: "nope"), in: page), .zero)
        XCTAssertEqual(MonthLayoutEngine.cellRelative(CGPoint(x: 250, y: 200), cell: .day(day(2026, 10, 6)), in: page), CGPoint(x: 50, y: 25))
        XCTAssertEqual(MonthLayoutEngine.cellRelative(CGPoint(x: 30, y: 1060), cell: .memo, in: page), CGPoint(x: 30, y: 10))
    }

    // MARK: Lane packing (web vectors)

    func testLaneColumnsAndClipping() {
        XCTAssertEqual(lanes([allDay("single", 6, 7)]), ["single": [2, 2, 0]])
        XCTAssertEqual(lanes([allDay("before", 1, 6)]), ["before": [0, 1, 0]], "starts before the week")
        XCTAssertEqual(lanes([allDay("after", 9, 15)]), ["after": [5, 6, 0]], "continues after the week")
        XCTAssertEqual(lanes([allDay("whole", 1, 20)]), ["whole": [0, 6, 0]])
        XCTAssertEqual(lanes([allDay("endsAtStart", 3, 4), allDay("startsAtEnd", 11, 12)]), [:], "exclusive ends")
        XCTAssertEqual(lanes([allDay("lastDay", 10, 11)]), ["lastDay": [6, 6, 0]])
    }

    func testLanesIgnoreTimedEvents() {
        let twoDays = timed("48h", 4, 0, 0, 0, 0, endDay: 6)
        XCTAssertEqual(lanes([twoDays, allDay("ad", 5, 6)]), ["ad": [1, 1, 0]])
    }

    func testLanesStackAndReuseFreeLanes() {
        XCTAssertEqual(
            lanes([allDay("A", 5, 8), allDay("B", 6, 7), allDay("C", 8, 9), allDay("D", 7, 8)]),
            ["A": [1, 3, 0], "B": [2, 2, 1], "D": [3, 3, 1], "C": [4, 4, 0]]
        )
        XCTAssertEqual(lanes([allDay("X", 4, 6), allDay("Y", 6, 8)]), ["X": [0, 1, 0], "Y": [2, 3, 0]], "adjacent spans share a lane")
    }

    func testLongerSpanFirstInTheSameColumn() {
        let out = MonthLayoutEngine.packAllDayLanes(events: [allDay("short", 4, 5), allDay("long", 4, 8), allDay("mid", 4, 6)], days: weekDays, calendar: tokyo)
        XCTAssertEqual(out.map { "\($0.event.id):\($0.lane)" }, ["long:0", "mid:1", "short:2"])
        let clipped = MonthLayoutEngine.packAllDayLanes(events: [allDay("today", 4, 5), allDay("since", 1, 6)], days: weekDays, calendar: tokyo)
        XCTAssertEqual(clipped.map { "\($0.event.id):\($0.startCol),\($0.endCol),\($0.lane)" }, ["since:0,1,0", "today:0,0,1"])
    }

    func testLanesSortedByLaneThenColumnAndBadInput() {
        let out = MonthLayoutEngine.packAllDayLanes(events: [allDay("r0b", 9, 10), allDay("r1", 4, 6), allDay("r0a", 4, 7)], days: weekDays, calendar: tokyo)
        XCTAssertEqual(out.map { "\($0.event.id):\($0.lane),\($0.startCol)" }, ["r0a:0,0", "r0b:0,5", "r1:1,0"])
        XCTAssertTrue(MonthLayoutEngine.packAllDayLanes(events: [allDay("a", 4, 5)], days: [], calendar: tokyo).isEmpty)
        XCTAssertTrue(MonthLayoutEngine.packAllDayLanes(events: [], days: weekDays, calendar: tokyo).isEmpty)
        let inverted = LayoutEvent(id: "inv", title: "inv", allDay: true, start: october(6), end: october(5), colorHex: "#000000", calendarId: "c")
        XCTAssertEqual(lanes([inverted]), ["inv": [2, 2, 0]], "an inverted all-day event is a single day")
    }

    func testSingleDayRangeAndRandomNoOverlap() {
        XCTAssertEqual(lanes([allDay("a", 1, 10), allDay("b", 4, 5)], days: [day(2026, 10, 4)]), ["a": [0, 0, 0], "b": [0, 0, 1]])

        var state: UInt64 = 7
        func rand(_ n: Int) -> Int {
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27
            return Int((state &* 2_685_821_657_736_338_717) % UInt64(n))
        }
        for round in 0..<300 {
            let count = 1 + rand(10)
            let events = (0..<count).map { i -> LayoutEvent in
                let s = 1 + rand(14)
                return allDay("e\(i)", s, s + 1 + rand(5))
            }
            let out = MonthLayoutEngine.packAllDayLanes(events: events, days: weekDays, calendar: tokyo)
            for span in out {
                XCTAssertTrue(span.startCol >= 0 && span.startCol <= span.endCol && span.endCol <= 6, "round \(round)")
            }
            for i in out.indices {
                for j in out.indices where j > i && out[i].lane == out[j].lane {
                    XCTAssertTrue(out[i].endCol < out[j].startCol || out[j].endCol < out[i].startCol, "round \(round): overlap in lane \(out[i].lane)")
                }
            }
        }
    }

    // MARK: Bars and chips in the page

    func testBarsAndChipsGeometry() {
        let trip = allDay("trip", 5, 8, title: "出張") // Mon–Wed of row 1
        let dentist = allDay("dentist", 6, 7, title: "歯医者") // overlaps → lane 1
        let meeting = timed("meeting", 6, 9, 0, 10, 0, title: "会議")
        let page = layout([trip, dentist, meeting])

        XCTAssertEqual(page.rows[1].laneCount, 2)
        XCTAssertEqual(page.rows[1].maxChips, 1)
        XCTAssertEqual(page.rows[1].frame.height, 175)
        XCTAssertEqual(page.rows[0].laneCount, 0)

        let bars = Dictionary(uniqueKeysWithValues: page.allDayBars.map { ($0.eventId, $0) })
        XCTAssertEqual(bars["trip"]?.frame, CGRect(x: 4, y: 203, width: 592, height: 22))
        XCTAssertEqual(bars["trip"]?.lane, 0)
        XCTAssertEqual(bars["trip"]?.row, 1)
        XCTAssertEqual(bars["trip"]?.continuesLeft, false)
        XCTAssertEqual(bars["trip"]?.continuesRight, false)
        XCTAssertEqual(bars["trip"]?.colorHex, "#33b679")
        XCTAssertEqual(bars["trip"]?.title, "出張")
        XCTAssertEqual(bars["dentist"]?.frame, CGRect(x: 204, y: 228, width: 192, height: 22))

        XCTAssertEqual(page.timedChips.count, 1)
        let chip = page.timedChips[0]
        XCTAssertEqual(chip.frame, CGRect(x: 204, y: 253, width: 192, height: 20))
        XCTAssertEqual(chip.timeText, "9:00")
        XCTAssertEqual(chip.title, "会議")
        XCTAssertEqual(chip.eventId, "meeting")
        XCTAssertEqual(chip.day, day(2026, 10, 6))
        XCTAssertEqual(chip.colorHex, "#039be5")
        XCTAssertEqual(chip.moreCount, 0)
        XCTAssertFalse(chip.isMore)
    }

    func testWeekCrossingEventSplitsIntoTwoBars() {
        let page = layout([allDay("long", 9, 15, title: "長い")])
        let bars = page.allDayBars.sorted { $0.row < $1.row }
        XCTAssertEqual(bars.count, 2)
        XCTAssertEqual(bars[0].row, 1)
        XCTAssertEqual(bars[0].frame.minX, 804)
        XCTAssertEqual(bars[0].frame.maxX, 1396)
        XCTAssertFalse(bars[0].continuesLeft)
        XCTAssertTrue(bars[0].continuesRight)
        XCTAssertEqual(bars[1].row, 2)
        XCTAssertEqual(bars[1].frame.minX, 4)
        XCTAssertEqual(bars[1].frame.maxX, 596, "Mon 10/12 – Wed 10/14")
        XCTAssertTrue(bars[1].continuesLeft)
        XCTAssertFalse(bars[1].continuesRight)
    }

    func testTimedChipCapAndOrder() {
        let four = [timed("e14", 6, 14, 0, 15, 0), timed("e09", 6, 9, 0, 10, 0), timed("e11", 6, 11, 0, 12, 0), timed("e08", 6, 8, 30, 9, 0)]
        let page = layout(four)
        let chips = page.timedChips.filter { $0.day == day(2026, 10, 6) }
        XCTAssertEqual(chips.count, 3)
        XCTAssertEqual(chips.map(\.timeText), ["8:30", "9:00", ""])
        XCTAssertEqual(chips.map { $0.eventId ?? "-" }, ["e08", "e09", "-"])
        XCTAssertEqual(chips[2].title, "+2件")
        XCTAssertEqual(chips[2].moreCount, 2)
        XCTAssertTrue(chips[2].isMore)
        XCTAssertEqual(chips[2].frame, CGRect(x: 204, y: 243, width: 192, height: 20))
        XCTAssertEqual(page.rows[1].maxChips, 3)

        let chips3 = layout(Array(four.prefix(3))).timedChips.filter { $0.day == day(2026, 10, 6) }
        XCTAssertEqual(chips3.map(\.timeText), ["9:00", "11:00", "14:00"])

        // Same start: longer first, then title, then id.
        let sameStart = [timed("b", 6, 9, 0, 9, 30, title: "い"), timed("a", 6, 9, 0, 9, 30, title: "あ"), timed("c", 6, 9, 0, 12, 0, title: "う")]
        XCTAssertEqual(layout(sameStart).timedChips.map { $0.eventId ?? "" }, ["c", "a", "b"])
    }

    func testOvernightChipTimeTexts() {
        let overnight = timed("night", 6, 21, 0, 11, 0, endDay: 7)
        XCTAssertEqual(layout([overnight]).timedChips.sorted { $0.day < $1.day }.map(\.timeText), ["21:00", "〜11:00"])
        let threeDays = timed("3d", 6, 21, 0, 11, 0, endDay: 8)
        let chips = layout([threeDays]).timedChips.sorted { $0.day < $1.day }
        XCTAssertEqual(chips.map(\.timeText), ["21:00", "", "〜11:00"])
        XCTAssertEqual(chips.map(\.day), [day(2026, 10, 6), day(2026, 10, 7), day(2026, 10, 8)])
        // Ends exactly at midnight: only the first day.
        let tillMidnight = timed("mid", 6, 22, 0, 0, 0, endDay: 7)
        XCTAssertEqual(layout([tillMidnight]).timedChips.map(\.day), [day(2026, 10, 6)])
        // Zero-length event: the instant.
        let instant = timed("zero", 6, 10, 0, 10, 0)
        XCTAssertEqual(layout([instant]).timedChips.map(\.timeText), ["10:00"])
        XCTAssertEqual(MonthLayoutEngine.formatTime(date(2026, 10, 6, 13, 5), calendar: tokyo), "13:05")
        XCTAssertEqual(MonthLayoutEngine.formatTime(date(2026, 10, 6, 0, 0), calendar: tokyo), "0:00")
    }

    func testBusyRowGrowsAndPushesRowsBelow() {
        var busy: [LayoutEvent] = []
        for i in 0..<3 { busy.append(allDay("ad\(i)", 13, 15, title: "ad\(i)")) }
        for i in 0..<5 { busy.append(timed("t\(i)", 13, 8 + i, 0, 9 + i, 0)) }
        let page = layout(busy)
        XCTAssertEqual(page.rows[2].laneCount, 3)
        XCTAssertEqual(page.rows[2].maxChips, 3)
        XCTAssertEqual(page.rows[2].frame.height, 203)
        XCTAssertEqual(page.rows[3].frame.minY, 553)
        XCTAssertEqual(page.rows[1].frame, CGRect(x: 0, y: 175, width: 1400, height: 175), "rows above are untouched")
        XCTAssertEqual(page.size.height, 175 * 5 + 203 + 700)
        XCTAssertEqual(page.memo.minY, 175 * 5 + 203)
        // Chips sit below the last lane.
        let firstChip = page.timedChips.first { $0.eventId == "t0" }
        XCTAssertEqual(firstChip?.frame.minY, 350 + 28 + 75)
    }

    // MARK: Hit testing

    func testHitTestingPriority() {
        let trip = allDay("trip", 5, 8)
        let meeting = timed("meeting", 6, 9, 0, 10, 0)
        var many: [LayoutEvent] = []
        for i in 0..<5 { many.append(timed("m\(i)", 7, 8 + i, 0, 9 + i, 0)) }
        let page = layout([trip, meeting] + many)
        XCTAssertEqual(page.hit(at: CGPoint(x: 300, y: 203 + 25 + 10)), .timedChip("meeting"))
        XCTAssertEqual(page.hit(at: CGPoint(x: 100, y: 203 + 10)), .allDayBar("trip"))
        XCTAssertEqual(page.hit(at: CGPoint(x: 10, y: 185)), .date(day(2026, 10, 5)))
        XCTAssertEqual(page.hit(at: CGPoint(x: 500, y: 203 + 25 + 40 + 5)), .moreChips(day(2026, 10, 7)))
        XCTAssertEqual(page.hit(at: CGPoint(x: 500, y: 203 + 25 + 5)), .timedChip("m0"))
        XCTAssertNil(page.hit(at: CGPoint(x: 100, y: 175 + 150)))
        XCTAssertNil(page.hit(at: CGPoint(x: 100, y: 1100)))
        XCTAssertNil(page.hit(at: CGPoint(x: -10, y: -10)))
        XCTAssertNil(page.hit(at: CGPoint(x: CGFloat.nan, y: 10)))
        XCTAssertEqual(page.hit(at: CGPoint(x: 100, y: 10)), .date(day(2026, 9, 28)))
    }

    // MARK: Ink bottoms and scroll delta

    func testInkBottomsGrowRowsAndMemo() {
        let plain = layout([])
        let inked = layout([], ink: [.day(day(2026, 10, 14)): 300, .memo: 900])
        XCTAssertEqual(inked.rows[2].frame.height, 312)
        XCTAssertEqual(inked.rows[3].frame.minY, 662)
        XCTAssertEqual(inked.rows[1].frame, plain.rows[1].frame)
        XCTAssertEqual(inked.memo.minY, 1187)
        XCTAssertEqual(inked.memo.height, 1500, "1.1: 900 → 1,500")
        XCTAssertEqual(inked.size.height, 1187 + 1500)
        XCTAssertEqual(inked.cells[.day(day(2026, 10, 20))]?.minY, 662)
        XCTAssertEqual(inked.cells[.day(day(2026, 10, 14))]?.height, 312)

        // The row never shrinks below the ink even when events disappear.
        let withEvents = layout([timed("a", 13, 9, 0, 10, 0), timed("b", 13, 10, 0, 11, 0), timed("c", 13, 11, 0, 12, 0)], ink: [.day(day(2026, 10, 13)): 250])
        XCTAssertEqual(withEvents.rows[2].frame.height, 262)
        // Ink below the cap.
        XCTAssertEqual(layout([], ink: [.day(day(2026, 10, 13)): 5000]).rows[2].frame.height, 1200)
    }

    // MARK: The memo area grows in steps (1.1, M7A_CONTRACT §3.2)

    func testMemoGrowsInSteps() {
        for (b, h) in [(0, 700), (300, 700), (301, 1100), (700, 1100), (701, 1500), (1100, 1500), (5500, 5900), (5600, 6000), (5601, 6000), (5950, 6000), (5990, 6040), (6420, 6470)] as [(CGFloat, CGFloat)] {
            XCTAssertEqual(MonthLayoutEngine.memoHeight(inkBottom: b), h, "memo ink bottom \(b)")
            XCTAssertEqual(MonthLayoutEngine.memoHeight(inkBottom: b), PaperGrowth.tailHeight(inkBottom: b))
            let page = layout([], ink: [.memo: b])
            XCTAssertEqual(page.memo, CGRect(x: 0, y: 1050, width: 1400, height: h), "the memo area's rect (ink \(b))")
            XCTAssertEqual(page.size, CGSize(width: 1400, height: 1050 + h))
            XCTAssertEqual(page.cells[.memo], page.memo)
        }
        XCTAssertEqual(MonthLayoutEngine.memoHeight(inkBottom: 64.5), 700, "the screenshot month's dot (0-1)")
        XCTAssertEqual(MonthLayoutEngine.memoHeight(inkBottom: .nan), 700)
        XCTAssertEqual(MonthLayoutEngine.memoHeight(inkBottom: -40), 700)
        let plain = layout([])
        let grown = layout([], ink: [.memo: 500])
        XCTAssertEqual(MonthLayoutEngine.scrollDelta(old: plain, new: grown, topVisibleY: 1100), 0, "the memo area's top does not move")
        XCTAssertEqual(MonthLayoutEngine.scrollDelta(old: plain, new: grown, topVisibleY: 600), 0)
        XCTAssertEqual(ZoomPolicy.overviewSize(grown), CGSize(width: 1400, height: 1050), "the overview is the 6 rows")
        XCTAssertTrue(PaperGrowth.onlyTailHeightChanged(old: plain, new: grown))
        XCTAssertFalse(PaperGrowth.onlyTailHeightChanged(old: plain, new: layout([], ink: [.day(day(2026, 10, 14)): 300])), "a row grew")
    }

    // MARK: The finger's tap target (1.1, M7A_CONTRACT §4.2)

    func testHitWithMinTarget() {
        let page = layout([])
        let d14 = day(2026, 10, 14)
        let cell = page.cells[.day(d14)]!
        XCTAssertEqual(cell, CGRect(x: 400, y: 350, width: 200, height: 175))
        // iPhone portrait, mini, 11 inch, 13 inch, iPhone landscape (the month's overview zooms).
        for zoom: CGFloat in [0.2871, 0.5314, 0.5957, 0.7371, 0.2190] {
            let m = 44 / zoom
            let h = min(175, max(28, m))
            XCTAssertEqual(page.hit(at: CGPoint(x: cell.minX + 1, y: cell.minY + h - 0.01), minTarget: m), .date(d14), "zoom \(zoom): the bottom-left of the target")
            XCTAssertEqual(page.hit(at: CGPoint(x: cell.maxX - 0.01, y: cell.minY + h - 0.01), minTarget: m), .date(d14), "zoom \(zoom): the bottom-right")
            XCTAssertEqual(page.hit(at: CGPoint(x: cell.midX, y: cell.minY + 30), minTarget: m), .date(d14), "zoom \(zoom): just below the 1.0 date frame")
            if h < 175 {
                XCTAssertNil(page.hit(at: CGPoint(x: cell.midX, y: cell.minY + h + 0.01), minTarget: m), "zoom \(zoom): below the target")
                XCTAssertEqual(h * zoom, 44, accuracy: 1e-9, "zoom \(zoom): 44 pt on screen")
            } else {
                XCTAssertEqual(page.hit(at: CGPoint(x: cell.midX, y: cell.maxY - 0.01), minTarget: m), .date(d14), "zoom \(zoom): the whole cell (iPhone landscape)")
            }
        }
        // At 1.57× and more the target is back to the date row (28 lu).
        XCTAssertEqual(page.hit(at: CGPoint(x: 590, y: 377.9), minTarget: 20), .date(d14))
        XCTAssertNil(page.hit(at: CGPoint(x: 590, y: 378.1), minTarget: 20))
        // A day outside the month counts; the memo area and the outside of the paper do not.
        XCTAssertEqual(page.hit(at: CGPoint(x: 50, y: 100), minTarget: 153.3), .date(day(2026, 9, 28)))
        XCTAssertEqual(page.hit(at: CGPoint(x: 1399, y: 900), minTarget: 153.3), .date(day(2026, 11, 8)), "the grid's last cell")
        XCTAssertNil(page.hit(at: CGPoint(x: 700, y: 1060), minTarget: 153.3), "the memo area")
        XCTAssertNil(page.hit(at: CGPoint(x: -5, y: 10), minTarget: 153.3))
        XCTAssertNil(page.hit(at: CGPoint(x: 700, y: -1), minTarget: 153.3))
        XCTAssertNil(page.hit(at: CGPoint(x: 700, y: 1750), minTarget: 153.3))
        XCTAssertNil(page.hit(at: CGPoint(x: CGFloat.nan, y: 10), minTarget: 153.3))
        // A minTarget that is not a positive number: the same as hit(at:).
        for bad: CGFloat in [.nan, .infinity, 0, -10] {
            for p in [CGPoint(x: 500, y: 390), CGPoint(x: 500, y: 360), CGPoint(x: 700, y: 1100)] {
                XCTAssertEqual(page.hit(at: p, minTarget: bad), page.hit(at: p), "minTarget \(bad) at \(p)")
            }
        }
        // Chips and bars come first (the event opens, not the day).
        let trip = allDay("trip", 5, 8)
        let meeting = timed("meeting", 6, 9, 0, 10, 0)
        var many: [LayoutEvent] = []
        for i in 0..<5 { many.append(timed("m\(i)", 7, 8 + i, 0, 9 + i, 0)) }
        let busy = layout([trip, meeting] + many)
        XCTAssertEqual(busy.hit(at: CGPoint(x: 300, y: 203 + 25 + 10), minTarget: 153.3), .timedChip("meeting"))
        XCTAssertEqual(busy.hit(at: CGPoint(x: 100, y: 203 + 10), minTarget: 153.3), .allDayBar("trip"))
        XCTAssertEqual(busy.hit(at: CGPoint(x: 500, y: 203 + 25 + 40 + 5), minTarget: 153.3), .moreChips(day(2026, 10, 7)))
        XCTAssertEqual(busy.hit(at: CGPoint(x: 100, y: 175 + 150), minTarget: 153.3), .date(day(2026, 10, 5)), "below the chips, inside the target")
        XCTAssertNil(busy.hit(at: CGPoint(x: 100, y: 175 + 160), minTarget: 153.3), "below the target (153.3 lu)")
    }

    func testScrollDelta() {
        let plain = layout([])
        let inked = layout([], ink: [.day(day(2026, 10, 14)): 300, .memo: 900])
        XCTAssertEqual(MonthLayoutEngine.scrollDelta(old: plain, new: inked, topVisibleY: 600), 137)
        XCTAssertEqual(MonthLayoutEngine.scrollDelta(old: plain, new: inked, topVisibleY: 100), 0)
        XCTAssertEqual(MonthLayoutEngine.scrollDelta(old: plain, new: inked, topVisibleY: 360), 0)
        XCTAssertEqual(MonthLayoutEngine.scrollDelta(old: plain, new: inked, topVisibleY: 1100), 137)
        XCTAssertEqual(MonthLayoutEngine.scrollDelta(old: inked, new: plain, topVisibleY: 700), -137)
        XCTAssertEqual(MonthLayoutEngine.scrollDelta(old: plain, new: inked, topVisibleY: -5), 0)
        XCTAssertEqual(MonthLayoutEngine.scrollDelta(old: plain, new: plain, topVisibleY: 600), 0)
        XCTAssertEqual(MonthLayoutEngine.scrollDelta(old: plain, new: inked, topVisibleY: 5000), 137, "below the paper: the memo area")
    }

    func testLayoutIsEquatableAndStable() {
        let a = layout([allDay("x", 5, 7), timed("y", 6, 9, 0, 10, 0)])
        let b = layout([timed("y", 6, 9, 0, 10, 0), allDay("x", 5, 7)])
        XCTAssertEqual(a, b, "input order does not matter")
        XCTAssertNotEqual(a, layout([]))
    }
}
