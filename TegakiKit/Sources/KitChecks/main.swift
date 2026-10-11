// KitChecks: re-runs the key checks of TegakiKit as a plain executable, so they can run on a Mac
// that has only the Command Line Tools (no XCTest). `swift run KitChecks` exits 1 on any failure.
// The XCTest targets (Tests/) cover the same ground plus edge cases and run on CI.
import Foundation
import CoreGraphics
import Layout
import Holidays
import InkModel

// MARK: - Tiny check harness

var failures: [String] = []
var passed = 0

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() {
        passed += 1
    } else {
        failures.append(message)
        print("FAIL: \(message)")
    }
}

func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    if actual == expected {
        passed += 1
    } else {
        failures.append(message)
        print("FAIL: \(message)\n      got      \(actual)\n      expected \(expected)")
    }
}

func section(_ name: String) {
    print("== \(name)")
}

// MARK: - Fixtures (a fixed calendar keeps every date deterministic)

var tokyo = Calendar(identifier: .gregorian)
tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
tokyo.locale = Locale(identifier: "ja_JP")

func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
    var c = DateComponents()
    c.year = y
    c.month = m
    c.day = d
    c.hour = h
    c.minute = mi
    return tokyo.date(from: c)!
}

func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

/// Local midnight of October `n` 2026 (n may exceed 31).
func october(_ n: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
    let base = tokyo.date(byAdding: .day, value: n - 1, to: date(2026, 10, 1))!
    return tokyo.date(byAdding: .minute, value: h * 60 + mi, to: base)!
}

/// All-day event covering [startDay, endDayExclusive) of October 2026.
func allDay(_ id: String, _ startDay: Int, _ endDayExclusive: Int, title: String? = nil) -> LayoutEvent {
    LayoutEvent(id: id, title: title ?? id, allDay: true, start: october(startDay), end: october(endDayExclusive), colorHex: "#33b679", calendarId: "primary")
}

/// Timed event on October `d` 2026 from sh:sm to eh:em (end on `endDay` when given).
func timed(_ id: String, _ d: Int, _ sh: Int, _ sm: Int, _ eh: Int, _ em: Int, endDay: Int? = nil, title: String? = nil) -> LayoutEvent {
    LayoutEvent(id: id, title: title ?? id, allDay: false, start: october(d, sh, sm), end: october(endDay ?? d, eh, em), colorHex: "#039be5", calendarId: "primary")
}

func layout(_ events: [LayoutEvent], ink: [CellKey: CGFloat] = [:], now: Date = date(2026, 10, 12, 12)) -> MonthPageLayout {
    MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 10), events: events, inkBottoms: ink, now: now, calendar: tokyo))
}

/// Deterministic xorshift64* generator.
struct Rng {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2_685_821_657_736_338_717
    }
    mutating func int(_ n: Int) -> Int { Int(next() % UInt64(max(1, n))) }
    mutating func double() -> Double { Double(next() >> 11) / Double(UInt64(1) << 53) }
}

// MARK: - Row height formula

section("row height")
checkEqual(MonthLayoutEngine.rowHeight(laneCount: 0, maxChips: 0, inkBottom: 0), 175, "empty row is the base height")
checkEqual(MonthLayoutEngine.rowHeight(laneCount: 2, maxChips: 1, inkBottom: 0), 175, "28 + 50 + 20 + 40 = 138 < 175")
checkEqual(MonthLayoutEngine.rowHeight(laneCount: 3, maxChips: 3, inkBottom: 0), 203, "28 + 75 + 60 + 40")
checkEqual(MonthLayoutEngine.rowHeight(laneCount: 10, maxChips: 3, inkBottom: 0), 378, "28 + 250 + 60 + 40")
checkEqual(MonthLayoutEngine.rowHeight(laneCount: 0, maxChips: 0, inkBottom: 300), 312, "ink bottom + 12")
checkEqual(MonthLayoutEngine.rowHeight(laneCount: 0, maxChips: 0, inkBottom: 160), 175, "ink bottom 160 + 12 < 175")
checkEqual(MonthLayoutEngine.rowHeight(laneCount: 0, maxChips: 0, inkBottom: 5000), 1200, "capped at 1200")
checkEqual(MonthLayoutEngine.rowHeight(laneCount: 60, maxChips: 3, inkBottom: 0), 1200, "content capped at 1200")
checkEqual(MonthLayoutEngine.rowHeight(laneCount: 0, maxChips: 0, inkBottom: .nan), 175, "NaN ink bottom is ignored")
checkEqual(MonthLayoutEngine.rowHeight(laneCount: 0, maxChips: 0, inkBottom: -50), 175, "negative ink bottom is ignored")
checkEqual(MonthLayoutEngine.memoHeight(inkBottom: 0), 700, "memo minimum")
checkEqual(MonthLayoutEngine.memoHeight(inkBottom: 900), 950, "memo ink bottom + 50")
check(MonthLayoutEngine.shownChipCount(for: 3) == (3, 0), "3 timed events: all shown")
check(MonthLayoutEngine.shownChipCount(for: 4) == (2, 2), "4 timed events: 2 + 「+2件」")
check(MonthLayoutEngine.shownChipCount(for: 9) == (2, 7), "9 timed events: 2 + 「+7件」")

// MARK: - 42-day grid, October 2026

section("grid October 2026")
do {
    let page = layout([])
    checkEqual(page.rows.count, 6, "always 6 rows")
    checkEqual(page.rows[0].days.first, day(2026, 9, 28), "grid starts on Monday 9/28")
    checkEqual(page.rows[0].days[3], day(2026, 10, 1), "10/1 is the 4th cell")
    checkEqual(page.rows[5].days.last, day(2026, 11, 8), "grid ends on Sunday 11/8")
    checkEqual(page.rows.map(\.days.count), [7, 7, 7, 7, 7, 7], "7 days per row")
    checkEqual(page.rows[0].days.map(\.weekday), [1, 2, 3, 4, 5, 6, 0], "Monday ... Sunday")
    checkEqual(page.cells.count, 43, "42 days + memo")
    checkEqual(page.size, CGSize(width: 1400, height: 1750), "empty month: 6 × 175 + 700 (the web page's 1750)")
    checkEqual(page.rows.map { $0.frame.minY }, [0, 175, 350, 525, 700, 875], "rows stack")
    checkEqual(page.memo, CGRect(x: 0, y: 1050, width: 1400, height: 700), "memo below the grid")
    checkEqual(page.cells[.day(day(2026, 10, 1))], CGRect(x: 600, y: 0, width: 200, height: 175), "cell rect of 10/1")
    checkEqual(page.cells[.memo], page.memo, "memo cell")
    checkEqual(page.dateLabels.count, 42, "a label per day")
    checkEqual(page.allDayBars.count, 0, "no bars")
    checkEqual(page.timedChips.count, 0, "no chips")

    let labels = Dictionary(uniqueKeysWithValues: page.dateLabels.map { ($0.day, $0) })
    checkEqual(labels[day(2026, 10, 12)]?.holidayName, "スポーツの日", "holiday name on 10/12")
    checkEqual(labels[day(2026, 10, 12)]?.tone, .sundayOrHoliday, "holiday tone")
    checkEqual(labels[day(2026, 10, 12)]?.isToday, true, "today mark")
    checkEqual(labels[day(2026, 10, 11)]?.tone, .sundayOrHoliday, "Sunday tone")
    checkEqual(labels[day(2026, 10, 10)]?.tone, .saturday, "Saturday tone")
    checkEqual(labels[day(2026, 10, 9)]?.tone, .normal, "weekday tone")
    checkEqual(labels[day(2026, 9, 30)]?.inMonth, false, "9/30 is outside the month")
    checkEqual(labels[day(2026, 10, 1)]?.inMonth, true, "10/1 is inside the month")
    checkEqual(labels[day(2026, 10, 1)]?.frame, CGRect(x: 604, y: 4, width: 192, height: 24), "date label frame")
    checkEqual(page.dateLabels.filter(\.isToday).count, 1, "exactly one today")

    checkEqual(page.cell(at: CGPoint(x: 650, y: 10)), .day(day(2026, 10, 1)), "cell(at:) in row 0")
    checkEqual(page.cell(at: CGPoint(x: 1400, y: 180)), .day(day(2026, 10, 11)), "right edge belongs to the last column")
    checkEqual(page.cell(at: CGPoint(x: 100, y: 1100)), .memo, "memo area")
    checkEqual(page.cell(at: CGPoint(x: -1, y: 10)), nil, "left of the paper")
    checkEqual(page.cell(at: CGPoint(x: 10, y: 1750)), nil, "below the paper")
    checkEqual(page.cell(at: CGPoint(x: 10, y: 1749)), .memo, "last point of the memo area")
    checkEqual(MonthLayoutEngine.paperPoint(of: .day(day(2026, 10, 6)), in: page), CGPoint(x: 200, y: 175), "paperPoint")
    checkEqual(MonthLayoutEngine.cellRelative(CGPoint(x: 250, y: 200), cell: .day(day(2026, 10, 6)), in: page), CGPoint(x: 50, y: 25), "cellRelative")
}

// MARK: - Lane packing (expectations copied from the web tests, tests/event-layout.test.mjs)

section("all-day lane packing")
let weekDays = (4...10).map { day(2026, 10, $0) } // Sun 10/4 – Sat 10/10, as in the web tests

func lanes(_ events: [LayoutEvent], days: [DayKey] = weekDays) -> [String: [Int]] {
    var out: [String: [Int]] = [:]
    for span in MonthLayoutEngine.packAllDayLanes(events: events, days: days, calendar: tokyo) {
        out[span.event.id] = [span.startCol, span.endCol, span.lane]
    }
    return out
}

func laneOrder(_ events: [LayoutEvent], days: [DayKey] = weekDays) -> [[Any]] {
    MonthLayoutEngine.packAllDayLanes(events: events, days: days, calendar: tokyo).map { [$0.event.id, $0.startCol, $0.endCol, $0.lane] }
}

checkEqual(lanes([allDay("single", 6, 7)]), ["single": [2, 2, 0]], "single day")
checkEqual(lanes([allDay("before", 1, 6)]), ["before": [0, 1, 0]], "starts before the week")
checkEqual(lanes([allDay("after", 9, 15)]), ["after": [5, 6, 0]], "continues after the week")
checkEqual(lanes([allDay("whole", 1, 20)]), ["whole": [0, 6, 0]], "covers the whole week")
checkEqual(lanes([allDay("endsAtStart", 3, 4), allDay("startsAtEnd", 11, 12)]), [:], "exclusive ends")
checkEqual(lanes([allDay("lastDay", 10, 11)]), ["lastDay": [6, 6, 0]], "last day of the week")
checkEqual(lanes([timed("48h", 4, 0, 0, 0, 0, endDay: 6), allDay("ad", 5, 6)]), ["ad": [1, 1, 0]], "long timed events are excluded")
checkEqual(
    lanes([allDay("A", 5, 8), allDay("B", 6, 7), allDay("C", 8, 9), allDay("D", 7, 8)]),
    ["A": [1, 3, 0], "B": [2, 2, 1], "D": [3, 3, 1], "C": [4, 4, 0]],
    "overlapping spans stack and free lanes are reused"
)
checkEqual(lanes([allDay("X", 4, 6), allDay("Y", 6, 8)]), ["X": [0, 1, 0], "Y": [2, 3, 0]], "adjacent spans share a lane")
checkEqual(
    laneOrder([allDay("short", 4, 5), allDay("long", 4, 8), allDay("mid", 4, 6)]).map { "\($0[0]):\($0[3])" },
    ["long:0", "mid:1", "short:2"],
    "longer span first in the same start column"
)
checkEqual(
    laneOrder([allDay("today", 4, 5), allDay("since", 1, 6)]).map { "\($0[0]):\($0[1]),\($0[2]),\($0[3])" },
    ["since:0,1,0", "today:0,0,1"],
    "a span clipped at the week start counts from column 0"
)
checkEqual(
    laneOrder([allDay("r0b", 9, 10), allDay("r1", 4, 6), allDay("r0a", 4, 7)]).map { "\($0[0]):\($0[3]),\($0[1])" },
    ["r0a:0,0", "r0b:0,5", "r1:1,0"],
    "sorted by lane then column"
)
checkEqual(lanes([allDay("a", 4, 5)], days: []), [:], "no days")
do {
    let inverted = LayoutEvent(id: "inv", title: "inv", allDay: true, start: october(6), end: october(5), colorHex: "#000000", calendarId: "c")
    checkEqual(lanes([inverted]), ["inv": [2, 2, 0]], "an inverted all-day event is a single day")
}
checkEqual(lanes([allDay("a", 1, 10), allDay("b", 4, 5)], days: [day(2026, 10, 4)]), ["a": [0, 0, 0], "b": [0, 0, 1]], "single-day range")

do {
    // Random no-overlap check (seeded, 300 rounds like the web test).
    var rng = Rng(seed: 7)
    var overlapFree = true
    var inRange = true
    for _ in 0..<300 {
        let count = 1 + rng.int(10)
        let events = (0..<count).map { i -> LayoutEvent in
            let s = 1 + rng.int(14)
            return allDay("e\(i)", s, s + 1 + rng.int(5))
        }
        let out = MonthLayoutEngine.packAllDayLanes(events: events, days: weekDays, calendar: tokyo)
        for span in out where !(span.startCol >= 0 && span.startCol <= span.endCol && span.endCol <= 6) { inRange = false }
        for i in out.indices {
            for j in out.indices where j > i && out[i].lane == out[j].lane {
                if !(out[i].endCol < out[j].startCol || out[j].endCol < out[i].startCol) { overlapFree = false }
            }
        }
    }
    check(inRange, "random spans stay inside the week")
    check(overlapFree, "random spans never overlap within a lane")
}

// MARK: - Bars, chips and hit testing

section("bars, chips, hit testing")
do {
    // Row 1 = Mon 10/5 ... Sun 10/11.
    let trip = allDay("trip", 5, 8, title: "出張") // Mon–Wed
    let dentist = allDay("dentist", 6, 7, title: "歯医者") // Tue, overlaps trip → lane 1
    let meeting = timed("meeting", 6, 9, 0, 10, 0, title: "会議")
    let page = layout([trip, dentist, meeting])

    checkEqual(page.rows[1].laneCount, 2, "two lanes in row 1")
    checkEqual(page.rows[1].maxChips, 1, "one chip in row 1")
    checkEqual(page.rows[1].frame.height, 175, "28 + 50 + 20 + 40 = 138 → base 175")
    checkEqual(page.rows[0].laneCount, 0, "row 0 untouched")

    let bars = Dictionary(uniqueKeysWithValues: page.allDayBars.map { ($0.eventId, $0) })
    checkEqual(bars["trip"]?.frame, CGRect(x: 4, y: 175 + 28, width: 592, height: 22), "trip bar frame")
    checkEqual(bars["trip"]?.lane, 0, "trip lane")
    checkEqual(bars["trip"]?.row, 1, "trip row")
    checkEqual(bars["trip"]?.continuesLeft, false, "trip starts in the row")
    checkEqual(bars["trip"]?.continuesRight, false, "trip ends in the row")
    checkEqual(bars["dentist"]?.frame, CGRect(x: 204, y: 175 + 28 + 25, width: 192, height: 22), "dentist bar frame (lane 1)")
    checkEqual(bars["trip"]?.title, "出張", "bar title")

    checkEqual(page.timedChips.count, 1, "one chip")
    let chip = page.timedChips[0]
    checkEqual(chip.frame, CGRect(x: 204, y: 175 + 28 + 50, width: 192, height: 20), "chip below the lanes")
    checkEqual(chip.timeText, "9:00", "chip time")
    checkEqual(chip.title, "会議", "chip title")
    checkEqual(chip.eventId, "meeting", "chip event")
    checkEqual(chip.day, day(2026, 10, 6), "chip day")
    checkEqual(chip.moreCount, 0, "ordinary chip")

    checkEqual(page.hit(at: CGPoint(x: 300, y: 175 + 28 + 50 + 10)), .timedChip("meeting"), "hit chip")
    checkEqual(page.hit(at: CGPoint(x: 100, y: 175 + 28 + 10)), .allDayBar("trip"), "hit bar lane 0")
    checkEqual(page.hit(at: CGPoint(x: 300, y: 175 + 28 + 25 + 10)), .allDayBar("dentist"), "hit bar lane 1")
    checkEqual(page.hit(at: CGPoint(x: 10, y: 175 + 10)), .date(day(2026, 10, 5)), "hit date label")
    checkEqual(page.hit(at: CGPoint(x: 100, y: 175 + 150)), nil, "hit empty ink area")
    checkEqual(page.hit(at: CGPoint(x: 100, y: 10)), .date(day(2026, 9, 28)), "hit date in row 0")
    checkEqual(page.hit(at: CGPoint(x: 100, y: 1100)), nil, "memo hits nothing")

    // A week-spanning event splits into two bars with open ends.
    let long = allDay("long", 9, 15, title: "長い")
    let page2 = layout([long])
    let longBars = page2.allDayBars.filter { $0.eventId == "long" }.sorted { $0.row < $1.row }
    checkEqual(longBars.count, 2, "two bars for a week-crossing event")
    checkEqual(longBars[0].row, 1, "first bar in row 1")
    checkEqual(longBars[0].frame.minX, 4 * 200 + 4, "first bar starts Friday")
    checkEqual(longBars[0].frame.maxX, 1400 - 4, "first bar runs to the right edge")
    checkEqual(longBars[0].continuesRight, true, "first bar continues right")
    checkEqual(longBars[0].continuesLeft, false, "first bar starts here")
    checkEqual(longBars[1].row, 2, "second bar in row 2")
    checkEqual(longBars[1].frame.minX, 4, "second bar starts Monday")
    checkEqual(longBars[1].frame.maxX, 3 * 200 - 4, "second bar ends Wednesday 10/14 (end 10/15 is exclusive)")
    checkEqual(longBars[1].continuesLeft, true, "second bar continues left")
    checkEqual(longBars[1].continuesRight, false, "second bar ends here")
}

do {
    // Chip cap, ordering and 「+n件」 (Web 版と同じ: 3 件までは全部、4 件以上は 2 件＋「+n件」).
    let four = [timed("e14", 6, 14, 0, 15, 0), timed("e09", 6, 9, 0, 10, 0), timed("e11", 6, 11, 0, 12, 0), timed("e08", 6, 8, 30, 9, 0)]
    let page = layout(four)
    let chips = page.timedChips.filter { $0.day == day(2026, 10, 6) }
    checkEqual(chips.count, 3, "4 events → 3 chips")
    checkEqual(chips.map(\.timeText), ["8:30", "9:00", ""], "earliest two, then the more chip")
    checkEqual(chips.map { $0.eventId ?? "-" }, ["e08", "e09", "-"], "chip ids")
    checkEqual(chips[2].title, "+2件", "more chip title")
    checkEqual(chips[2].moreCount, 2, "more count")
    checkEqual(chips[2].frame, CGRect(x: 204, y: 175 + 28 + 40, width: 192, height: 20), "more chip is the third slot")
    checkEqual(page.rows[1].maxChips, 3, "maxChips counts the more chip")
    checkEqual(page.rows[1].frame.height, 175, "28 + 0 + 60 + 40 = 128 → 175")
    checkEqual(page.hit(at: CGPoint(x: 300, y: 175 + 28 + 40 + 5)), .moreChips(day(2026, 10, 6)), "hit the more chip")

    let three = Array(four.prefix(3))
    let chips3 = layout(three).timedChips.filter { $0.day == day(2026, 10, 6) }
    checkEqual(chips3.map(\.timeText), ["9:00", "11:00", "14:00"], "3 events → all shown in start order")

    // Overnight event: "9:00" on the first day, "〜11:00" on the next, "" when it covers a whole day.
    let overnight = timed("night", 6, 21, 0, 11, 0, endDay: 7)
    let nightChips = layout([overnight]).timedChips.sorted { $0.day < $1.day }
    checkEqual(nightChips.map(\.timeText), ["21:00", "〜11:00"], "overnight event time texts")
    let threeDays = timed("3d", 6, 21, 0, 11, 0, endDay: 8)
    let threeDayChips = layout([threeDays]).timedChips.sorted { $0.day < $1.day }
    checkEqual(threeDayChips.map(\.timeText), ["21:00", "", "〜11:00"], "a day fully covered has no time text")
    checkEqual(threeDayChips.map(\.day), [day(2026, 10, 6), day(2026, 10, 7), day(2026, 10, 8)], "a chip per day")

    // Rows with many lanes and chips grow; the rows below move down by the same amount.
    var busy: [LayoutEvent] = []
    for i in 0..<3 { busy.append(allDay("ad\(i)", 13, 15, title: "ad\(i)")) } // Tue 10/13–Wed 10/14 in row 2
    for i in 0..<5 { busy.append(timed("t\(i)", 13, 8 + i, 0, 9 + i, 0)) }
    let busyPage = layout(busy)
    checkEqual(busyPage.rows[2].laneCount, 3, "three stacked lanes")
    checkEqual(busyPage.rows[2].maxChips, 3, "chips capped at 3")
    checkEqual(busyPage.rows[2].frame.height, 28 + 75 + 60 + 40, "row grows to 203")
    checkEqual(busyPage.rows[3].frame.minY, 175 * 2 + 203, "next row moves down")
    checkEqual(busyPage.rows[1].frame.minY, 175, "rows above are untouched")
    checkEqual(busyPage.size.height, 175 * 5 + 203 + 700, "paper grows")
}

// MARK: - Ink bottoms grow rows; scroll delta

section("ink bottoms and scroll delta")
do {
    let plain = layout([])
    let inked = layout([], ink: [.day(day(2026, 10, 14)): 300, .memo: 900])
    checkEqual(inked.rows[2].frame.height, 312, "ink bottom 300 + 12 grows row 2")
    checkEqual(inked.rows[3].frame.minY, 525 + 137, "row 3 moves down by 137")
    checkEqual(inked.rows[1].frame, plain.rows[1].frame, "row 1 unchanged")
    checkEqual(inked.memo.minY, 1050 + 137, "memo moves down")
    checkEqual(inked.memo.height, 950, "memo grows with its ink")
    checkEqual(inked.size.height, 1050 + 137 + 950, "paper height")
    checkEqual(inked.cells[.day(day(2026, 10, 20))]?.minY, 525 + 137, "cell rects follow the rows")

    checkEqual(MonthLayoutEngine.scrollDelta(old: plain, new: inked, topVisibleY: 600), 137, "a row below the change moves down")
    checkEqual(MonthLayoutEngine.scrollDelta(old: plain, new: inked, topVisibleY: 100), 0, "a row above the change stays")
    checkEqual(MonthLayoutEngine.scrollDelta(old: plain, new: inked, topVisibleY: 360), 0, "the changed row itself keeps its top")
    checkEqual(MonthLayoutEngine.scrollDelta(old: plain, new: inked, topVisibleY: 1100), 137, "the memo area moves down")
    checkEqual(MonthLayoutEngine.scrollDelta(old: inked, new: plain, topVisibleY: 700), -137, "shrinking moves up")
    checkEqual(MonthLayoutEngine.scrollDelta(old: plain, new: inked, topVisibleY: -5), 0, "above the paper")

    // The row never shrinks below the ink even when events disappear.
    let withEvents = layout([timed("a", 13, 9, 0, 10, 0), timed("b", 13, 10, 0, 11, 0), timed("c", 13, 11, 0, 12, 0)], ink: [.day(day(2026, 10, 13)): 250])
    checkEqual(withEvents.rows[2].frame.height, 262, "ink (250 + 12) wins over chips (128) and base (175)")
}

// MARK: - InkModel

section("ink model")

func point(_ x: Double, _ y: Double, dt: Int = 0, size: Double = 3.5, force: Double = 0.5) -> InkPoint {
    InkPoint(x: CGFloat(x), y: CGFloat(y), dtMs: dt, sizeW: CGFloat(size), sizeH: CGFloat(size), opacity: 1, force: CGFloat(force), azimuth: 1.5708, altitude: 0.7854)
}

func stroke(_ id: String, cell: CellKey = .day(day(2026, 10, 4)), tool: InkTool = .pen, color: String = "#1f2937", t: Int = 1_760_150_400_123, dev: String? = "ipad-1", points: [InkPoint]? = nil) -> InkStroke {
    InkStroke(id: id, cell: cell, tool: tool, color: color, t: t, dev: dev, points: points ?? [point(10, 20), point(30.06, 40.04, dt: 16), point(50, 90, dt: 32)])
}

do {
    // Rounding on construction.
    let p = InkPoint(x: 10.04, y: 20.06, dtMs: 5, sizeW: 3.456, sizeH: 3.454, opacity: 0.999, force: 0.123, azimuth: 1.23456, altitude: 0.98765)
    checkEqual(p.x, 10.0, "x rounded to 0.1")
    checkEqual(p.y, 20.1, "y rounded to 0.1")
    checkEqual(p.sizeW, 3.46, "size rounded to 0.01")
    checkEqual(p.sizeH, 3.45, "size rounded to 0.01 (down)")
    checkEqual(p.opacity, 1.0, "opacity rounded to 0.01")
    checkEqual(p.force, 0.12, "force rounded to 0.01")
    checkEqual(p.azimuth, 1.235, "azimuth rounded to 0.001")
    checkEqual(p.altitude, 0.988, "altitude rounded to 0.001")
    checkEqual(InkPoint.points(fromFlat: InkPoint.flat([p])), [p], "flat round trip")
    checkEqual(InkPoint.points(fromFlat: [1, 2, 3]).count, 0, "a partial point is ignored")
    checkEqual(InkPoint.points(fromFlat: [Double.nan, 2, 0, 1, 1, 1, 1, 0, 0, 5, 6, 0, 1, 1, 1, 1, 0, 0]).count, 1, "a bad point is dropped")

    checkEqual(InkStroke.normalizeColor("#ABC"), "#aabbcc", "short colour expands")
    checkEqual(InkStroke.normalizeColor("#1F2937"), "#1f2937", "colour lower-cased")
    checkEqual(InkStroke.normalizeColor("red"), nil, "named colour rejected")
    checkEqual(stroke("x", color: "garbage").color, "#1f2937", "bad colour → tool default")
    checkEqual(stroke("x", tool: .marker, color: "").color, "#fde047", "marker default colour")
    checkEqual(stroke("x", t: 1_760_150_400_123).inkStart, Date(timeIntervalSince1970: 1_760_150_400.123), "inkStart derives from t")
}

do {
    // add / remove / liveStrokes order / inkBottoms.
    var page = InkPage.empty(pageId: "m1-2026-10")
    page.add(stroke("pen-late", t: 300))
    page.add(stroke("marker", tool: .marker, t: 500, points: [point(0, 100, size: 18), point(5, 120, size: 18)]))
    page.add(stroke("pen-early", t: 100))
    page.add(stroke("memo", cell: .memo, t: 200, points: [point(0, 50), point(10, 60.5)]))
    checkEqual(page.liveStrokes.map(\.id), ["marker", "pen-early", "memo", "pen-late"], "markers first, then pens by t")
    checkEqual(page.updatedAt, 500, "updatedAt follows the latest t")
    let bottoms = page.inkBottoms()
    checkEqual(bottoms[.day(day(2026, 10, 4))], 129, "max(90 + 1.75, 120 + 9)")
    checkEqual(bottoms[.memo], 62.25, "memo bottom 60.5 + 1.75")

    page.remove(ids: ["pen-late", "ghost"], at: 900)
    checkEqual(page.liveStrokes.map(\.id), ["marker", "pen-early", "memo"], "removed stroke is gone")
    checkEqual(page.deleted, ["pen-late": 900, "ghost": 900], "tombstones, also for unknown ids")
    checkEqual(page.updatedAt, 900, "updatedAt follows removal")
    page.add(stroke("pen-late", t: 1000))
    check(page.strokes["pen-late"] == nil, "a tombstoned id never comes back")
    page.remove(ids: ["ghost"], at: 100)
    checkEqual(page.deleted["ghost"], 900, "an earlier removal time does not lower the tombstone")
    page.add(stroke("empty", points: []))
    check(page.strokes["empty"] == nil, "a stroke without points is ignored")
    page.add(stroke(""))
    check(page.strokes[""] == nil, "an empty id is ignored")

    // JSON round trip, unknown items.
    var original = InkPage.empty(pageId: "m1-2026-10")
    original.add(stroke("a"))
    original.add(stroke("b", tool: .marker, color: "#FDE047", t: 7, dev: nil))
    original.remove(ids: ["c"], at: 1_760_150_500_000)
    let data = try InkPageCodec.encode(original)
    let text = String(decoding: data, as: UTF8.self)
    check(text.hasPrefix("{\"deleted\":{\"c\":1760150500000},\"pageId\":\"m1-2026-10\",\"strokes\":{\"a\":{\"cell\":\"2026-10-04\",\"color\":\"#1f2937\",\"dev\":\"ipad-1\",\"id\":\"a\",\"pts\":[10,20,0,3.5,3.5,1,0.5,1.571,0.785,"), "JSON shape: sorted keys, flat pts: \(text.prefix(160))")
    check(text.hasSuffix(",\"updatedAt\":1760150500000,\"v\":1}"), "JSON tail")
    check(!text.contains("\"dev\":null"), "nil dev is omitted")
    let decoded = try InkPageCodec.decode(data)
    checkEqual(decoded, original, "decode(encode(page)) == page")
    checkEqual(try InkPageCodec.encode(decoded), data, "re-encoding is byte-identical")

    let foreign = """
    {"v":7,"pageId":"m1-2026-10","future":{"a":[1,2.5,"x",null,true]},"strokes":{
      "k":{"id":"k","cell":"2026-10-05","tool":"pen","color":"#ABC","t":10,"pts":[1,2,0,3,3,1,0.5,0,0]},
      "u":{"id":"u","cell":"memo","tool":"crayon","color":"#000000","t":11,"pts":[1,2,0,3,3,1,0.5,0,0],"wax":true},
      "broken":{"id":"broken","tool":"pen","pts":[]},
      "nocell":{"id":"nocell","tool":"pen","pts":[1,2,0,3,3,1,0.5,0,0]},
      "keyed":{"cell":"2026-10-06","tool":"marker","pts":[1,2,0,3,3,1,0.5,0,0]},
      "dead":{"id":"dead","cell":"2026-10-06","tool":"pen","pts":[1,2,0,3,3,1,0.5,0,0]}
    },"deleted":{"dead":123,"":5},"updatedAt":99}
    """
    let parsed = try InkPageCodec.decode(Data(foreign.utf8))
    checkEqual(parsed.v, 7, "unknown v kept")
    checkEqual(parsed.pageId, "m1-2026-10", "pageId")
    checkEqual(Set(parsed.strokes.keys), ["k", "keyed"], "broken strokes dropped, tombstoned dropped, key used as fallback id")
    checkEqual(parsed.strokes["k"]?.color, "#aabbcc", "colour normalized on read")
    checkEqual(parsed.strokes["keyed"]?.tool, .marker, "fallback id stroke")
    checkEqual(parsed.unknownStrokes.keys.sorted(), ["u"], "unknown tool kept aside")
    checkEqual(parsed.unknownStrokes["u"]?["wax"], .bool(true), "unknown stroke kept verbatim")
    checkEqual(parsed.unknown["future"], .object(["a": .array([.number(1), .number(2.5), .string("x"), .null, .bool(true)])]), "unknown top-level item kept")
    checkEqual(parsed.deleted, ["dead": 123], "invalid tombstone ids dropped")
    checkEqual(parsed.updatedAt, 99, "updatedAt")
    checkEqual(parsed.liveStrokes.count, 2, "unknown strokes are not drawn")
    let rewritten = String(decoding: try InkPageCodec.encode(parsed), as: UTF8.self)
    check(rewritten.contains("\"future\":{\"a\":[1,2.5,\"x\",null,true]}"), "unknown item written back")
    check(rewritten.contains("\"tool\":\"crayon\""), "unknown stroke written back")
    check(rewritten.contains("\"wax\":true"), "unknown stroke fields written back")
    check(rewritten.contains("\"v\":7"), "v written back")
    checkEqual(try InkPageCodec.decode(Data(rewritten.utf8)), parsed, "second round trip is stable")

    check((try? InkPageCodec.decode(Data("not json".utf8))) == nil, "invalid JSON throws")
    check((try? InkPageCodec.decode(Data("[1,2]".utf8))) == nil, "a non-object throws")
    check((try? InkPageCodec.decode(Data())) == nil, "empty data throws")
    checkEqual(try InkPageCodec.decode(Data("{}".utf8)), InkPage.empty(pageId: ""), "an empty object is an empty page")

    // Compression round trip.
    let compressed = try InkPageCodec.compress(data)
    check(!compressed.isEmpty, "compressed data is not empty")
    checkEqual(try InkPageCodec.decompress(compressed), data, "decompress(compress(data)) == data")
    checkEqual(try InkPageCodec.decode(try InkPageCodec.decompress(try InkPageCodec.compress(try InkPageCodec.encode(original)))), original, "full file round trip")
    checkEqual(try InkPageCodec.decompress(try InkPageCodec.compress(Data())), Data(), "empty data round trip")
    var big = Data()
    for i in 0..<200_000 { big.append(UInt8(truncatingIfNeeded: i &* 31)) }
    let bigCompressed = try InkPageCodec.compress(big)
    checkEqual(try InkPageCodec.decompress(bigCompressed), big, "large data round trip (multiple chunks)")
    check((try? InkPageCodec.decompress(Data("definitely not lzfse".utf8))) == nil, "garbage does not decompress")
    check((try? InkPageCodec.decompress(compressed.prefix(compressed.count / 2))) == nil, "a truncated stream does not decompress")
} catch {
    check(false, "ink model threw: \(error)")
}

do {
    // Merge laws on random pages (deterministic seed).
    let cells: [CellKey] = [.day(day(2026, 10, 4)), .day(day(2026, 10, 5)), .memo]
    let colors = ["#1f2937", "#dc2626", "#2563eb", "#fde047"]
    var rng = Rng(seed: 12_345)

    func randomStroke(_ id: String, _ rng: inout Rng) -> InkStroke {
        let count = 1 + rng.int(5)
        let points = (0..<count).map { i in point(rng.double() * 200, rng.double() * 175, dt: i * 16, size: 2 + rng.double() * 16, force: rng.double()) }
        return InkStroke(id: id, cell: cells[rng.int(cells.count)], tool: rng.int(2) == 0 ? .pen : .marker, color: colors[rng.int(colors.count)], t: 1 + rng.int(1000), dev: rng.int(2) == 0 ? nil : "dev\(rng.int(3))", points: points)
    }

    func randomPage(_ rng: inout Rng, pool: [InkStroke]) -> InkPage {
        var page = InkPage.empty(pageId: rng.int(5) == 0 ? "" : "m1-2026-10")
        for _ in 0..<rng.int(8) {
            var s = pool[rng.int(pool.count)]
            if rng.int(6) == 0 { s.t += 1 + rng.int(3) } // a divergent copy: the deterministic pick must agree everywhere
            page.add(s)
        }
        for _ in 0..<rng.int(4) {
            page.remove(ids: ["s\(rng.int(12))"], at: 1 + rng.int(2000))
        }
        if rng.int(3) == 0 { page.unknown["x\(rng.int(3))"] = .number(Double(rng.int(10))) }
        if rng.int(3) == 0 {
            let id = "u\(rng.int(3))"
            page.unknownStrokes[id] = .object(["id": .string(id), "cell": .string("memo"), "tool": .string("crayon"), "pts": .array([.number(Double(rng.int(9)))])])
        }
        if rng.int(5) == 0 { page.v = 1 + rng.int(3) }
        return page
    }

    var commutative = true
    var associative = true
    var idempotent = true
    var absorbing = true
    var neutral = true
    var roundTrips = true
    var tombstonesWin = true
    for _ in 0..<300 {
        let pool = (0..<12).map { randomStroke("s\($0)", &rng) }
        let a = randomPage(&rng, pool: pool)
        let b = randomPage(&rng, pool: pool)
        let c = randomPage(&rng, pool: pool)
        let ab = InkPage.merge(a, b)
        if ab != InkPage.merge(b, a) { commutative = false }
        if InkPage.merge(ab, c) != InkPage.merge(a, InkPage.merge(b, c)) { associative = false }
        if InkPage.merge(a, a) != a || InkPage.merge(ab, ab) != ab { idempotent = false }
        if InkPage.merge(ab, a) != ab { absorbing = false }
        if InkPage.merge(a, InkPage.empty(pageId: "")) != a { neutral = false }
        for id in ab.deleted.keys where ab.strokes[id] != nil || ab.unknownStrokes[id] != nil { tombstonesWin = false }
        if (try? InkPageCodec.decode(try InkPageCodec.encode(ab))) != ab { roundTrips = false }
    }
    check(commutative, "merge is commutative")
    check(associative, "merge is associative")
    check(idempotent, "merge is idempotent")
    check(absorbing, "merge absorbs an already merged input")
    check(neutral, "the empty page is neutral")
    check(tombstonesWin, "a tombstoned id is never live")
    check(roundTrips, "merged pages survive the JSON round trip")

    // The web test's hand-made case.
    var a = InkPage.empty(pageId: "p")
    a.add(stroke("1", t: 100))
    a.add(stroke("2", t: 100))
    a.remove(ids: ["3"], at: 150)
    var b = InkPage.empty(pageId: "p")
    b.add(stroke("2", t: 100), at: 300)
    b.add(stroke("3", t: 100), at: 300)
    b.add(stroke("4", t: 100), at: 300)
    b.remove(ids: ["1"], at: 120)
    b.remove(ids: ["3"], at: 140)
    let m = InkPage.merge(a, b)
    checkEqual(m.strokes.keys.sorted(), ["2", "4"], "union of strokes minus tombstones")
    checkEqual(m.deleted, ["1": 120, "3": 150], "union of tombstones, later time wins")
    checkEqual(m.updatedAt, 300, "updatedAt max")
    checkEqual(m.pageId, "p", "pageId kept")
}

// MARK: - Holidays 2025–2027 (vectors from the 内閣府 syukujitsu.csv, as in the web tests)

section("holidays 2025–2027")
let holidayVectors: [Int: [(String, String)]] = [
    2025: [("2025-01-01", "元日"), ("2025-01-13", "成人の日"), ("2025-02-11", "建国記念の日"), ("2025-02-23", "天皇誕生日"), ("2025-02-24", "振替休日"), ("2025-03-20", "春分の日"), ("2025-04-29", "昭和の日"), ("2025-05-03", "憲法記念日"), ("2025-05-04", "みどりの日"), ("2025-05-05", "こどもの日"), ("2025-05-06", "振替休日"), ("2025-07-21", "海の日"), ("2025-08-11", "山の日"), ("2025-09-15", "敬老の日"), ("2025-09-23", "秋分の日"), ("2025-10-13", "スポーツの日"), ("2025-11-03", "文化の日"), ("2025-11-23", "勤労感謝の日"), ("2025-11-24", "振替休日")],
    2026: [("2026-01-01", "元日"), ("2026-01-12", "成人の日"), ("2026-02-11", "建国記念の日"), ("2026-02-23", "天皇誕生日"), ("2026-03-20", "春分の日"), ("2026-04-29", "昭和の日"), ("2026-05-03", "憲法記念日"), ("2026-05-04", "みどりの日"), ("2026-05-05", "こどもの日"), ("2026-05-06", "振替休日"), ("2026-07-20", "海の日"), ("2026-08-11", "山の日"), ("2026-09-21", "敬老の日"), ("2026-09-22", "国民の休日"), ("2026-09-23", "秋分の日"), ("2026-10-12", "スポーツの日"), ("2026-11-03", "文化の日"), ("2026-11-23", "勤労感謝の日")],
    2027: [("2027-01-01", "元日"), ("2027-01-11", "成人の日"), ("2027-02-11", "建国記念の日"), ("2027-02-23", "天皇誕生日"), ("2027-03-21", "春分の日"), ("2027-03-22", "振替休日"), ("2027-04-29", "昭和の日"), ("2027-05-03", "憲法記念日"), ("2027-05-04", "みどりの日"), ("2027-05-05", "こどもの日"), ("2027-07-19", "海の日"), ("2027-08-11", "山の日"), ("2027-09-20", "敬老の日"), ("2027-09-23", "秋分の日"), ("2027-10-11", "スポーツの日"), ("2027-11-03", "文化の日"), ("2027-11-23", "勤労感謝の日")],
]
for (year, expected) in holidayVectors.sorted(by: { $0.key < $1.key }) {
    let actual = JapaneseHolidays.holidays(ofYear: year).map { "\($0.day) \($0.name)" }
    checkEqual(actual, expected.map { "\($0.0) \($0.1)" }, "holidays of \(year)")
    for (ymd, name) in expected {
        checkEqual(JapaneseHolidays.name(of: DayKey(ymd: ymd)!), name, "\(ymd) is \(name)")
    }
}
checkEqual(JapaneseHolidays.name(of: day(2026, 10, 4)), nil, "an ordinary Sunday is not a holiday")
checkEqual(JapaneseHolidays.names(for: MonthLayout.grid(year: 2026, month: 10).days).count, 2, "10/12 スポーツの日 and 11/3 文化の日 on the October 2026 grid (9/28–11/8)")

// MARK: - Summary

print("")
if failures.isEmpty {
    print("KitChecks: all \(passed) checks passed")
    exit(0)
} else {
    print("KitChecks: \(failures.count) of \(passed + failures.count) checks FAILED")
    for f in failures { print("  - \(f)") }
    exit(1)
}
