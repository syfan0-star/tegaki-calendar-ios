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

// MARK: - M3a: shared fixtures (the screenshot-mode demo events of M3A_CONTRACT §7, October 2026)

func checkClose(_ actual: CGFloat?, _ expected: CGFloat, _ message: String, tolerance: CGFloat = 1e-6) {
    if let a = actual, abs(a - expected) <= tolerance {
        passed += 1
    } else {
        failures.append(message)
        print("FAIL: \(message)\n      got      \(String(describing: actual))\n      expected \(expected)")
    }
}

func checkRect(_ actual: CGRect?, _ expected: CGRect, _ message: String, tolerance: CGFloat = 1e-6) {
    if let a = actual,
       abs(a.minX - expected.minX) <= tolerance, abs(a.minY - expected.minY) <= tolerance,
       abs(a.width - expected.width) <= tolerance, abs(a.height - expected.height) <= tolerance {
        passed += 1
    } else {
        failures.append(message)
        print("FAIL: \(message)\n      got      \(String(describing: actual))\n      expected \(expected)")
    }
}

let demoColors = ["#2563eb", "#16a34a", "#ea580c", "#7c3aed"] // work, family, personal, events

/// The demo events of ScreenshotMode.demoEvents (M2) plus the 7th's additions (M3A_CONTRACT §7).
func demoEvents() -> [LayoutEvent] {
    var out: [LayoutEvent] = []
    func timed(_ title: String, _ d: Int, _ h: Int, _ mi: Int = 0, minutes: Int = 60, cal: Int) {
        let start = october(d, h, mi)
        out.append(LayoutEvent(id: "demo-\(out.count + 1)", title: title, allDay: false, start: start, end: start.addingTimeInterval(TimeInterval(minutes * 60)), colorHex: demoColors[cal], calendarId: "cal\(cal)"))
    }
    func allDay(_ title: String, _ d: Int, days: Int = 1, cal: Int) {
        out.append(LayoutEvent(id: "demo-\(out.count + 1)", title: title, allDay: true, start: october(d), end: october(d + days), colorHex: demoColors[cal], calendarId: "cal\(cal)"))
    }
    allDay("運動会", 3, cal: 3)
    allDay("キャンプ", 4, days: 2, cal: 1)
    allDay("家族旅行", 9, days: 5, cal: 1)
    allDay("資料提出締切", 16, cal: 0)
    allDay("健康診断", 16, cal: 2)
    allDay("ゴミの日", 16, cal: 1)
    allDay("誕生日", 16, cal: 1)
    allDay("出張（大阪）", 21, days: 2, cal: 0)
    allDay("給料日", 25, cal: 2)
    timed("歯医者", 2, 10, cal: 2)
    timed("週次定例", 6, 10, cal: 0)
    timed("資料提出", 8, 15, minutes: 30, cal: 0)
    timed("通院", 9, 14, cal: 2)
    timed("週次定例", 13, 10, cal: 0)
    timed("朝会", 20, 9, minutes: 15, cal: 0)
    timed("週次定例", 20, 10, cal: 0)
    timed("面談", 20, 13, minutes: 30, cal: 0)
    timed("レビュー", 20, 15, cal: 0)
    timed("送別会", 20, 18, minutes: 120, cal: 2)
    timed("飲み会", 23, 19, minutes: 120, cal: 2)
    timed("週次定例", 27, 10, cal: 0)
    timed("ランチ", 28, 11, 30, minutes: 90, cal: 1)
    // The 7th (today in screenshot mode): overlapping timed events and an all-day one.
    allDay("締切", 7, cal: 2)
    timed("打合せ", 7, 10, minutes: 90, cal: 0)
    timed("電話", 7, 10, 30, minutes: 30, cal: 2)
    timed("歯科", 7, 14, cal: 2)
    return out
}

let demo = demoEvents()
/// The screenshot mode's "today": the 7th at 10:00.
let demoNow = october(7, 10)
func demoId(_ title: String) -> String { demo.first { $0.title == title }?.id ?? "?" }

let colW = PaperSpec.weekColumnWidth

// MARK: - PaperSpec and CellKey (M3a)

section("paper spec and cell keys (M3a)")
checkEqual(PaperSpec.weekColumnWidth, 1336.0 / 7, "week column width")
checkEqual(PaperSpec.weekGridHeight, 1920, "week grid height")
checkEqual(PaperSpec.dayGridHeight, 2400, "day grid height")
checkEqual(PaperSpec.dayLaneStep, 24, "day lane step")
checkEqual(PaperSpec.yearLaneStep, 18, "year lane step")
checkEqual(CellKey.allDay(day(2026, 10, 4)).raw, "allday:2026-10-04", "week band key")
checkEqual(CellKey.allDayDay.raw, "allday", "day band key")
checkEqual(CellKey.grid.raw, "grid", "grid key")
checkEqual(CellKey.yearDay(month: 2, day: 30).raw, "02-30", "year key (an impossible date is allowed)")
checkEqual(CellKey.yearDay(month: 12, day: 31).raw, "12-31", "year key 12-31")
checkEqual(CellKey.allDay(day(2026, 10, 4)).allDayDate, day(2026, 10, 4), "allDayDate round trip")
checkEqual(CellKey(raw: "02-30").yearMonthDay?.month, 2, "yearMonthDay month")
checkEqual(CellKey(raw: "02-30").yearMonthDay?.day, 30, "yearMonthDay day")
checkEqual(CellKey.yearDay(month: 7, day: 1).yearMonthDay?.month, 7, "yearMonthDay round trip (month)")
checkEqual(CellKey.yearDay(month: 7, day: 1).yearMonthDay?.day, 1, "yearMonthDay round trip (day)")
checkEqual(CellKey(raw: "02-30").day, nil, "a year key is not a day")
checkEqual(CellKey(raw: "allday:2026-10-04").day, nil, "a band key is not a day")
checkEqual(CellKey(raw: "2026-10-04").allDayDate, nil, "a day key has no allDayDate")
checkEqual(CellKey(raw: "2026-10-04").yearMonthDay == nil, true, "a day key has no yearMonthDay")
checkEqual(CellKey(raw: "13-01").yearMonthDay == nil, true, "month 13 is not a year key")
checkEqual(CellKey(raw: "memo").yearMonthDay == nil, true, "memo is not a year key")
checkEqual(CellKey.grid.isGrid, true, "isGrid")
checkEqual(CellKey.allDayDay.isAllDayDay, true, "isAllDayDay")
checkEqual(CellKey.allDay(day(2026, 10, 4)).isAllDayDay, false, "a week band key is not the day band")
checkEqual(CellKey.memo.isGrid, false, "memo is not grid")

// MARK: - PageNavigation

section("page navigation")
checkEqual(PageNavigation.pageId(.day, focus: day(2026, 10, 4)), "d-2026-10-04", "day page id")
checkEqual(PageNavigation.pageId(.week, focus: day(2026, 10, 4)), "w-2026-09-28", "week page id (Sunday → its Monday)")
checkEqual(PageNavigation.pageId(.week, focus: day(2026, 10, 5)), "w-2026-10-05", "week page id (Monday)")
checkEqual(PageNavigation.pageId(.month, focus: day(2026, 10, 31)), "m1-2026-10", "month page id")
checkEqual(PageNavigation.pageId(.year, focus: day(2027, 1, 1)), "y-2027", "year page id")
checkEqual(PageNavigation.pageId(.year, focus: day(2026, 12, 31)), "y-2026", "year page id (Dec 31)")
checkEqual(PageNavigation.mondayOnOrBefore(day(2026, 10, 4)), day(2026, 9, 28), "monday on or before")
do {
    let w = PageNavigation.dayRange(.week, focus: day(2026, 10, 7))
    checkEqual(w.start, day(2026, 10, 5), "week range start")
    checkEqual(w.end.dayNumber - w.start.dayNumber, 7, "week range is 7 days")
    let m = PageNavigation.dayRange(.month, focus: day(2026, 10, 15))
    checkEqual(m.start, day(2026, 9, 28), "month range start")
    checkEqual(m.end, day(2026, 11, 9), "month range end (exclusive)")
    checkEqual(m.end.dayNumber - m.start.dayNumber, 42, "month range is 42 days")
    let y = PageNavigation.dayRange(.year, focus: day(2026, 10, 7))
    checkEqual(y.start, day(2026, 1, 1), "year range start")
    checkEqual(y.end, day(2027, 1, 1), "year range end")
    checkEqual(y.end.dayNumber - y.start.dayNumber, 365, "2026 has 365 days")
    let leap = PageNavigation.dayRange(.year, focus: day(2028, 6, 1))
    checkEqual(leap.end.dayNumber - leap.start.dayNumber, 366, "2028 has 366 days")
    let d = PageNavigation.dayRange(.day, focus: day(2026, 10, 7))
    checkEqual(d.end, day(2026, 10, 8), "day range end")
}
checkEqual(PageNavigation.move(.day, focus: day(2026, 10, 4), by: 1), day(2026, 10, 5), "day +1")
checkEqual(PageNavigation.move(.day, focus: day(2026, 10, 1), by: -1), day(2026, 9, 30), "day −1")
checkEqual(PageNavigation.move(.week, focus: day(2026, 10, 7), by: 1), day(2026, 10, 14), "week +1 keeps the weekday")
checkEqual(PageNavigation.move(.week, focus: day(2026, 10, 7), by: -1), day(2026, 9, 30), "week −1")
checkEqual(PageNavigation.move(.week, focus: day(2026, 12, 30), by: 1), day(2027, 1, 6), "week +1 across the year")
checkEqual(PageNavigation.move(.month, focus: day(2026, 10, 31), by: 1), day(2026, 11, 1), "month +1 is the 1st")
checkEqual(PageNavigation.move(.month, focus: day(2026, 3, 31), by: -1), day(2026, 2, 1), "month −1 from 3/31 is 2/1")
checkEqual(PageNavigation.move(.month, focus: day(2026, 12, 15), by: 1), day(2027, 1, 1), "month +1 from December")
checkEqual(PageNavigation.move(.month, focus: day(2026, 1, 15), by: -1), day(2025, 12, 1), "month −1 from January")
checkEqual(PageNavigation.move(.month, focus: day(2026, 10, 15), by: 0), day(2026, 10, 1), "month 0 normalizes to the 1st")
checkEqual(PageNavigation.move(.month, focus: day(2026, 10, 15), by: -12), day(2025, 10, 1), "month −12")
checkEqual(PageNavigation.move(.year, focus: day(2026, 10, 4), by: 1), day(2027, 1, 1), "year +1 is Jan 1")
checkEqual(PageNavigation.move(.year, focus: day(2028, 2, 29), by: -1), day(2027, 1, 1), "year −1 from a leap day")
checkEqual(PageNavigation.move(.year, focus: day(2026, 10, 4), by: 0), day(2026, 1, 1), "year 0 normalizes to Jan 1")
checkEqual(PageNavigation.title(.day, focus: day(2026, 10, 12)), "2026年10月12日(月) スポーツの日", "day title with a holiday")
checkEqual(PageNavigation.title(.day, focus: day(2026, 10, 4)), "2026年10月4日(日)", "day title without a holiday")
checkEqual(PageNavigation.title(.week, focus: day(2026, 10, 4)), "2026年9月28日〜10月4日", "week title across months")
checkEqual(PageNavigation.title(.week, focus: day(2026, 10, 7)), "2026年10月5日〜10月11日", "week title inside a month (the month on both sides)")
checkEqual(PageNavigation.title(.week, focus: day(2027, 1, 1)), "2026年12月28日〜2027年1月3日", "week title across years")
checkEqual(PageNavigation.title(.month, focus: day(2026, 10, 4)), "2026年10月", "month title")
checkEqual(PageNavigation.title(.year, focus: day(2026, 10, 4)), "2026年", "year title")

// MARK: - TimedEventEngine (expectations copied from the web tests, tests/event-layout.test.mjs)

section("timed event layout")
let webDay = day(2026, 10, 4)

/// layoutTimedEvents result as { id: [startMin, endMin, col, cols] }.
func layoutMap(_ events: [LayoutEvent], _ d: DayKey = webDay) -> [String: [Int]] {
    var out: [String: [Int]] = [:]
    for slot in TimedEventEngine.layout(events: events, day: d, calendar: tokyo) {
        out[slot.event.id] = [slot.startMinute, slot.endMinute, slot.column, slot.columns]
    }
    return out
}

checkEqual(layoutMap([timed("a", 4, 9, 0, 10, 30), allDay("ad", 4, 5)]), ["a": [540, 630, 0, 1]], "single event; all-day excluded")
checkEqual(TimedEventEngine.layout(events: [], day: webDay, calendar: tokyo).count, 0, "no events")
checkEqual(
    layoutMap([timed("a", 4, 9, 0, 10, 0), timed("b", 4, 10, 0, 11, 0), timed("c", 4, 11, 0, 12, 0)]),
    ["a": [540, 600, 0, 1], "b": [600, 660, 0, 1], "c": [660, 720, 0, 1]],
    "back-to-back events do not overlap"
)
checkEqual(layoutMap([timed("short", 4, 9, 0, 10, 0), timed("long", 4, 9, 0, 11, 0)]), ["long": [540, 660, 0, 2], "short": [540, 600, 1, 2]], "identical starts: longer first")
do {
    let same = TimedEventEngine.layout(events: [timed("x2", 4, 9, 0, 10, 0, title: "B"), timed("x1", 4, 9, 0, 10, 0, title: "A")], day: webDay, calendar: tokyo)
    checkEqual(same.map { "\($0.event.title):\($0.column)/\($0.columns)" }, ["A:0/2", "B:1/2"], "identical events: by title")
    let triple = layoutMap(["p", "q", "r"].map { timed($0, 4, 14, 0, 15, 0) })
    checkEqual(triple, ["p": [840, 900, 0, 3], "q": [840, 900, 1, 3], "r": [840, 900, 2, 3]], "three identical events → three columns")
}
checkEqual(layoutMap([timed("inner", 4, 10, 0, 11, 0), timed("outer", 4, 9, 0, 12, 0)]), ["outer": [540, 720, 0, 2], "inner": [600, 660, 1, 2]], "nested events")
checkEqual(
    layoutMap([timed("outer", 4, 9, 0, 12, 0), timed("inner1", 4, 10, 0, 11, 0), timed("inner2", 4, 10, 30, 11, 30)]),
    ["outer": [540, 720, 0, 3], "inner1": [600, 660, 1, 3], "inner2": [630, 690, 2, 3]],
    "two nested events"
)
checkEqual(
    layoutMap([timed("a", 4, 9, 0, 12, 0), timed("b", 4, 9, 0, 10, 0), timed("c", 4, 10, 0, 11, 0)]),
    ["a": [540, 720, 0, 2], "b": [540, 600, 1, 2], "c": [600, 660, 1, 2]],
    "greedy column reuse"
)
checkEqual(
    layoutMap([timed("a", 4, 9, 0, 10, 0), timed("b", 4, 9, 30, 10, 30), timed("c", 4, 10, 15, 11, 0), timed("d", 4, 11, 0, 12, 0)]),
    ["a": [540, 600, 0, 2], "b": [570, 630, 1, 2], "c": [615, 660, 0, 2], "d": [660, 720, 0, 1]],
    "transitive clusters"
)
do {
    let overnight = timed("overnight", 3, 22, 0, 2, 0, endDay: 4)
    checkEqual(layoutMap([overnight], day(2026, 10, 3)), ["overnight": [1320, 1440, 0, 1]], "overnight: first day clipped at 24:00")
    checkEqual(layoutMap([overnight], day(2026, 10, 4)), ["overnight": [0, 120, 0, 1]], "overnight: second day from 0:00")
    checkEqual(layoutMap([overnight], day(2026, 10, 5)), [:], "overnight: not on the third day")
    let multi = timed("multi", 3, 12, 0, 12, 0, endDay: 5)
    checkEqual(layoutMap([multi], day(2026, 10, 3)), ["multi": [720, 1440, 0, 1]], "multi-day: first day")
    checkEqual(layoutMap([multi], day(2026, 10, 4)), ["multi": [0, 1440, 0, 1]], "multi-day: whole middle day")
    checkEqual(layoutMap([multi], day(2026, 10, 5)), ["multi": [0, 720, 0, 1]], "multi-day: last day")
    let toMidnight = timed("toMidnight", 4, 23, 0, 0, 0, endDay: 5)
    checkEqual(layoutMap([toMidnight], day(2026, 10, 4)), ["toMidnight": [1380, 1440, 0, 1]], "ends at midnight")
    checkEqual(layoutMap([toMidnight], day(2026, 10, 5)), [:], "ending exactly at midnight is not on the next day")
    checkEqual(layoutMap([overnight, timed("early", 4, 1, 0, 3, 0)], day(2026, 10, 4)), ["overnight": [0, 120, 0, 2], "early": [60, 180, 1, 2]], "overnight overlaps an early event")
}
checkEqual(layoutMap([timed("tiny", 4, 9, 0, 9, 5)]), ["tiny": [540, 555, 0, 1]], "15-minute minimum")
checkEqual(layoutMap([timed("zero", 4, 9, 0, 9, 0)]), ["zero": [540, 555, 0, 1]], "zero-length event")
checkEqual(layoutMap([timed("inverted", 4, 9, 0, 8, 0)]), ["inverted": [540, 555, 0, 1]], "inverted event")
checkEqual(layoutMap([timed("lateZero", 4, 23, 55, 23, 55)]), ["lateZero": [1425, 1440, 0, 1]], "near midnight the box stays inside the day")
checkEqual(layoutMap([timed("lateShort", 4, 23, 50, 0, 0, endDay: 5)]), ["lateShort": [1425, 1440, 0, 1]], "23:50–24:00 is 15 minutes")
checkEqual(layoutMap([timed("tiny", 4, 9, 0, 9, 5), timed("next", 4, 9, 10, 10, 0)]), ["tiny": [540, 555, 0, 2], "next": [550, 600, 1, 2]], "the visual minimum counts for overlap")
checkEqual(layoutMap([timed("tiny", 4, 9, 0, 9, 5), timed("next", 4, 9, 15, 10, 0)]), ["tiny": [540, 555, 0, 1], "next": [555, 600, 0, 1]], "…but not at 9:15")
do {
    let events = [timed("c", 4, 15, 0, 16, 0), timed("a", 4, 8, 0, 9, 0), timed("b", 4, 8, 30, 9, 30)]
    checkEqual(TimedEventEngine.layout(events: events, day: webDay, calendar: tokyo).map(\.event.id), ["a", "b", "c"], "output order")
}
do {
    // Random schedules never produce visual collisions (seeded, 300 rounds like the web test).
    var rng = Rng(seed: 42)
    var ok = true
    for _ in 0..<300 {
        let n = 1 + rng.int(12)
        let events = (0..<n).map { i -> LayoutEvent in
            let startMin = rng.int(96) * 15 - 120
            let len = rng.int(16) * 15
            let start = tokyo.date(byAdding: .minute, value: startMin, to: october(4))!
            return LayoutEvent(id: "e\(i)", title: "e\(i)", allDay: false, start: start, end: start.addingTimeInterval(TimeInterval(len * 60)), colorHex: "#039be5", calendarId: "primary")
        }
        let out = TimedEventEngine.layout(events: events, day: webDay, calendar: tokyo)
        for it in out where !(it.startMinute >= 0 && it.endMinute <= 1440 && it.endMinute - it.startMinute >= 15 && it.column >= 0 && it.column < it.columns) { ok = false }
        for i in out.indices {
            for j in out.indices where j > i {
                let a = out[i], b = out[j]
                if a.startMinute < b.endMinute && b.startMinute < a.endMinute {
                    if a.column == b.column || a.columns != b.columns { ok = false }
                }
            }
        }
    }
    check(ok, "random schedules: no collisions, one cluster size per overlap")
}
checkEqual(TimedEventEngine.minutesOfDay(october(4, 9, 5), calendar: tokyo), 545, "minutesOfDay")
checkEqual(TimedEventEngine.timeText(october(4, 9, 5), calendar: tokyo), "9:05", "timeText")
checkEqual(TimedEventEngine.timeRangeText(start: october(4, 9, 0), end: october(4, 10, 30), calendar: tokyo), "9:00〜10:30", "timeRangeText")
do {
    let v = TimedEventEngine.visualMinutes(of: timed("x", 4, 23, 55, 23, 55), day: webDay, calendar: tokyo)
    checkEqual([v.start, v.end], [1425, 1440], "visualMinutes near midnight")
    // boxFrame: a week column with 2 overlap columns (inner 182.857…, gap 2, width 90.428…).
    let box = TimedEventEngine.boxFrame(columnX: 64, columnWidth: colW, startMinute: 600, endMinute: 690, column: 1, columns: 2, hourHeight: 80, padLeft: 2, padRight: 6, gap: 2)
    let inner = colW - 8
    let w = (inner - 2) / 2
    checkClose(w, 90.4285714285, "boxFrame width", tolerance: 1e-6)
    checkRect(box, CGRect(x: 64 + 2 + w + 2, y: 801, width: w, height: 118), "boxFrame of the second column")
    let single = TimedEventEngine.boxFrame(columnX: 64, columnWidth: colW, startMinute: 540, endMinute: 555, column: 0, columns: 1, hourHeight: 80, padLeft: 2, padRight: 6, gap: 2)
    checkRect(single, CGRect(x: 66, y: 721, width: inner, height: 18), "boxFrame of a 15-minute box")
    let narrow = TimedEventEngine.boxFrame(columnX: 0, columnWidth: 40, startMinute: 0, endMinute: 15, column: 1, columns: 8, hourHeight: 80, padLeft: 2, padRight: 6, gap: 2)
    checkClose(narrow.width, 4, "very narrow columns drop the gap", tolerance: 1e-9)
    checkClose(narrow.minX, 6, "narrow column x", tolerance: 1e-9)
    let tiny = TimedEventEngine.boxFrame(columnX: 0, columnWidth: 100, startMinute: 0, endMinute: 2, column: 0, columns: 1, hourHeight: 80, padLeft: 2, padRight: 6, gap: 2)
    checkEqual(tiny.height, 4, "minimum box height")
}

// MARK: - LanePacking

section("lane packing (thinning)")
checkEqual(LanePacking.metrics(laneCount: 30, lane: 22, gap: 3, available: 767), LaneMetrics(lane: 22, step: 25, gap: 3, fontScale: 1), "30 lanes fit (747 ≤ 767)")
checkEqual(LanePacking.metrics(laneCount: 0, lane: 22, gap: 3, available: 767), LaneMetrics(lane: 22, step: 25, gap: 3, fontScale: 1), "no lanes")
do {
    let m = LanePacking.metrics(laneCount: 40, lane: 22, gap: 3, available: 767)
    checkClose(m.step, 770.0 / 40, "40 lanes: step 19.25")
    checkClose(m.gap, 3, "40 lanes: gap kept")
    checkClose(m.lane, 16.25, "40 lanes: lane 16.25")
    checkClose(m.fontScale, 16.25 / 22, "40 lanes: font scale")
    let n = LanePacking.metrics(laneCount: 100, lane: 22, gap: 3, available: 767)
    let step = 767.0 / (100 - 1.0 / 3)
    checkClose(n.step, step, "100 lanes: step = available / (n − 1/3)")
    checkClose(n.gap, step / 3, "100 lanes: gap = step / 3")
    checkClose(n.lane, step - step / 3, "100 lanes: lane")
    checkClose(100 * n.step - n.gap, 767, "100 lanes fill the available height exactly")
}

// MARK: - Week page

section("week page")
func weekLayout(_ events: [LayoutEvent], focus: DayKey = day(2026, 10, 7), ink: [CellKey: CGFloat] = [:], now: Date = demoNow) -> WeekPageLayout {
    WeekLayoutEngine.layout(WeekLayoutInput(focus: focus, events: events, inkBottoms: ink, now: now, calendar: tokyo))
}
checkEqual(WeekLayoutEngine.bandHeight(laneCount: 1, inkBottom: 0), 60, "band: 1 lane → base")
checkEqual(WeekLayoutEngine.bandHeight(laneCount: 2, inkBottom: 0), 80, "band: 2 lanes → 80")
checkEqual(WeekLayoutEngine.bandHeight(laneCount: 0, inkBottom: 100), 112, "band: ink + 12")
checkEqual(WeekLayoutEngine.bandHeight(laneCount: 40, inkBottom: 0), 800, "band: capped at 800")
checkEqual(WeekLayoutEngine.bandHeight(laneCount: 0, inkBottom: 5000), 800, "band: ink capped at 800")
checkEqual(WeekLayoutEngine.bandHeight(laneCount: 0, inkBottom: .nan), 60, "band: NaN ink ignored")
do {
    let empty = weekLayout([])
    checkEqual(empty.pageId, "w-2026-10-05", "week page id")
    checkEqual(empty.kind, .week, "kind")
    checkEqual(empty.days, (5...11).map { day(2026, 10, $0) }, "Monday 10/5 … Sunday 10/11")
    checkEqual(empty.size, CGSize(width: 1400, height: 1980), "empty week: 60 + 1920")
    checkEqual(empty.cells.count, 8, "7 band cells + grid")
    checkEqual(empty.cells[.allDay(day(2026, 10, 5))], CGRect(x: 64, y: 0, width: colW, height: 60), "Monday's band cell")
    checkEqual(empty.cells[.grid], CGRect(x: 0, y: 60, width: 1400, height: 1920), "grid cell")
    checkClose(empty.columnFrame(6).maxX, 1400, "last column ends at the right edge", tolerance: 1e-9)
    checkEqual(empty.columnFrame(0), CGRect(x: 64, y: 60, width: colW, height: 1920), "first column frame")
    checkEqual(empty.column(atX: 10), nil, "gutter has no column")
    checkEqual(empty.column(atX: 64), 0, "column at the gutter edge")
    checkEqual(empty.column(atX: 1400), 6, "x == 1400 is the last column")
    checkEqual(empty.column(atX: 1401), nil, "right of the paper")
    checkEqual(empty.column(atX: 64 + 2 * colW), 2, "column boundary maps to its own column")
    checkEqual(empty.laneCount, 0, "no lanes")
    checkEqual(empty.laneMetrics, LaneMetrics(lane: 22, step: 25, gap: 3, fontScale: 1), "plain lane metrics")
    checkEqual(empty.allDayBars.count, 0, "no bars")
    checkEqual(empty.timedBoxes.count, 0, "no boxes")
    checkEqual(empty.dateLabels.count, 7, "7 date labels")
    checkEqual(empty.dateLabels[2].isToday, true, "Wednesday is today")
    checkEqual(empty.dateLabels[2].frame, CGRect(x: 64 + 2 * colW, y: 0, width: colW, height: 0), "date labels have no height")
    checkEqual(empty.dateLabels[5].tone, .saturday, "Saturday tone")
    checkEqual(empty.dateLabels[6].tone, .sundayOrHoliday, "Sunday tone")
    checkEqual(empty.dateLabels.map(\.inMonth), Array(repeating: true, count: 7), "inMonth is always true")
    checkEqual(empty.todayColumn, 2, "today column")
    checkEqual(empty.nowLine, NowLine(y: 60 + 800, x0: 64 + 2 * colW, x1: 64 + 3 * colW, minute: 600), "now line at 10:00 in Wednesday's column")
    checkEqual(empty.minutesToY(600), 860, "minutesToY")

    let holidayWeek = weekLayout([], focus: day(2026, 10, 12))
    checkEqual(holidayWeek.dateLabels[0].holidayName, "スポーツの日", "holiday name on 10/12")
    checkEqual(holidayWeek.dateLabels[0].tone, .sundayOrHoliday, "holiday tone")
    checkEqual(holidayWeek.nowLine, nil, "no now line when today is not on the page")
    checkEqual(holidayWeek.todayColumn, nil, "no today column")
    checkEqual(holidayWeek.dateLabels.filter(\.isToday).count, 0, "no today mark")

    // Demo events: bars in one lane, boxes with 2 overlap columns, isPast.
    let page = weekLayout(demo)
    checkEqual(page.laneCount, 1, "one lane")
    checkEqual(page.band.height, 60, "band stays 60 with one lane")
    let bars = Dictionary(uniqueKeysWithValues: page.allDayBars.map { ($0.title, $0) })
    checkEqual(page.allDayBars.count, 3, "キャンプ, 締切, 家族旅行")
    checkRect(bars["キャンプ"]?.frame, CGRect(x: 64, y: 3, width: colW - 3, height: 22), "キャンプ: Monday, open left end")
    checkEqual(bars["キャンプ"]?.continuesLeft, true, "キャンプ continues left")
    checkEqual(bars["キャンプ"]?.continuesRight, false, "キャンプ ends in the week")
    checkRect(bars["締切"]?.frame, CGRect(x: 64 + 2 * colW + 3, y: 3, width: colW - 6, height: 22), "締切: Wednesday")
    checkRect(bars["家族旅行"]?.frame, CGRect(x: 64 + 4 * colW + 3, y: 3, width: 3 * colW - 3, height: 22), "家族旅行: Friday–Sunday, open right end")
    checkEqual(bars["家族旅行"]?.continuesRight, true, "家族旅行 continues right")
    checkEqual(bars["家族旅行"]?.continuesLeft, false, "家族旅行 starts in the week")
    checkEqual(page.allDayBars.map(\.lane), [0, 0, 0], "all bars in lane 0")
    checkEqual(page.allDayBars.map(\.row), [0, 0, 0], "row is always 0")

    let boxes = Dictionary(uniqueKeysWithValues: page.timedBoxes.map { ($0.eventId, $0) })
    checkEqual(page.timedBoxes.count, 6, "6 timed boxes in the week")
    let colX2 = 64 + 2 * colW
    let inner = colW - 8
    let w2 = (inner - 2) / 2
    checkRect(boxes[demoId("打合せ")]?.frame, CGRect(x: colX2 + 2, y: 60 + 801, width: w2, height: 118), "打合せ: column 0 of 2")
    checkRect(boxes[demoId("電話")]?.frame, CGRect(x: colX2 + 2 + w2 + 2, y: 60 + 841, width: w2, height: 38), "電話: column 1 of 2")
    checkRect(boxes[demoId("歯科")]?.frame, CGRect(x: colX2 + 2, y: 60 + 1121, width: inner, height: 78), "歯科: alone")
    checkEqual(boxes[demoId("打合せ")]?.columns, 2, "打合せ cluster has 2 columns")
    checkEqual(boxes[demoId("電話")]?.column, 1, "電話 is column 1")
    checkEqual(boxes[demoId("歯科")]?.columns, 1, "歯科 cluster has 1 column")
    checkEqual(boxes[demoId("打合せ")]?.timeText, "10:00〜11:30", "box time text")
    checkEqual(boxes[demoId("打合せ")]?.startText, "10:00", "box start text")
    checkEqual(boxes[demoId("打合せ")]?.day, day(2026, 10, 7), "box day")
    checkEqual(boxes[demoId("打合せ")]?.startMinute, 600, "box start minute")
    checkEqual(boxes[demoId("打合せ")]?.endMinute, 690, "box end minute")
    checkEqual(page.timedBoxes.filter(\.isPast).map(\.day), [day(2026, 10, 6)], "only Tuesday's 週次定例 is past at Wednesday 10:00")
    checkEqual(boxes[demoId("打合せ")]?.isPast, false, "a running event is not past")

    // Hit testing: boxes → bars → nil.
    checkEqual(page.hit(at: CGPoint(x: colX2 + 10, y: 60 + 810)), .timedBox(demoId("打合せ")), "hit a box")
    checkEqual(page.hit(at: CGPoint(x: colX2 + 2 + w2 + 10, y: 60 + 850)), .timedBox(demoId("電話")), "hit the second column")
    checkEqual(page.hit(at: CGPoint(x: colX2 + 10, y: 10)), .allDayBar(demoId("締切")), "hit a bar")
    checkEqual(page.hit(at: CGPoint(x: colX2 + 10, y: 60 + 100)), nil, "hit empty grid")
    checkEqual(page.hit(at: CGPoint(x: 10, y: 10)), nil, "hit the gutter")
    var overlapping = page
    overlapping.allDayBars.append(AllDayBar(eventId: "fake-bar", frame: CGRect(x: colX2, y: 60 + 800, width: colW, height: 40), row: 0, lane: 0, continuesLeft: false, continuesRight: false, colorHex: "#000000", title: "x"))
    checkEqual(overlapping.hit(at: CGPoint(x: colX2 + 10, y: 60 + 810)), .timedBox(demoId("打合せ")), "a box wins over a bar at the same point")

    // Cells and ink cells.
    checkEqual(page.cell(at: CGPoint(x: 10, y: 10)), nil, "the band's gutter belongs to no cell")
    checkEqual(page.cell(at: CGPoint(x: 1400, y: 100)), .grid, "right edge of the grid")
    checkEqual(page.cell(at: CGPoint(x: 100, y: 1980)), nil, "below the paper")
    checkEqual(page.cell(at: CGPoint(x: 100, y: 10)), .allDay(day(2026, 10, 5)), "Monday's band")
    checkEqual(page.cell(at: CGPoint(x: 1400, y: 10)), .allDay(day(2026, 10, 11)), "right edge of the band is Sunday")
    checkEqual(page.cell(at: CGPoint(x: -1, y: 100)), nil, "left of the paper")
    checkEqual(page.cell(at: CGPoint(x: 100, y: -1)), nil, "above the paper")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 10, y: 10)), .allDay(day(2026, 10, 5)), "ink in the gutter → Monday's band")
    checkEqual(page.inkCell(forCenter: CGPoint(x: -5, y: -5)), .allDay(day(2026, 10, 5)), "ink above-left → Monday's band")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 1500, y: 30)), .allDay(day(2026, 10, 11)), "ink right of the band → Sunday's band")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 10, y: 500)), .grid, "ink in the time gutter → grid")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 700, y: 5000)), .grid, "ink below the paper → grid")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 300, y: 59.9)), .allDay(day(2026, 10, 6)), "ink just above the grid → Tuesday's band")
    checkEqual(page.growsWithInk(.allDay(day(2026, 10, 5))), true, "band cells grow")
    checkEqual(page.growsWithInk(.grid), false, "the grid never grows")
    checkEqual(page.growsWithInk(.allDay(day(2026, 10, 12))), false, "a day outside the week")
    checkEqual(page.growsWithInk(.memo), false, "memo is not a week cell")

    // Bands and the scroll correction.
    checkEqual(page.band(atY: 10), PageBand(raw: "allday"), "band: allday")
    checkEqual(page.band(atY: 60), PageBand(raw: "grid"), "band: grid starts at bandH")
    checkEqual(page.band(atY: 1979.9), PageBand(raw: "grid"), "band: last point")
    checkEqual(page.band(atY: 1980), nil, "band: below")
    checkEqual(page.band(atY: -1), nil, "band: above")
    checkEqual(page.bandTop(PageBand(raw: "allday")), 0, "bandTop allday")
    checkEqual(page.bandTop(PageBand(raw: "grid")), 60, "bandTop grid")
    checkEqual(page.bandTop(PageBand(raw: "memo")), nil, "bandTop of a foreign band")
    let inked = weekLayout(demo, ink: [.allDay(day(2026, 10, 6)): 68, .grid: 5000])
    checkEqual(inked.band.height, 80, "band grows to ink 68 + 12; grid ink is ignored")
    checkEqual(inked.size.height, 2000, "paper grows with the band")
    checkEqual(inked.cells[.grid]?.minY, 80, "grid moves down")
    checkEqual(inked.timedBoxes.first { $0.eventId == demoId("打合せ") }?.frame.minY, 80 + 801, "boxes move with the grid")
    checkEqual(inked.nowLine?.y, 80 + 800, "now line moves with the grid")
    checkEqual(PageScroll.scrollDelta(old: page, new: inked, topVisibleY: 100), 20, "a grid point moves down by 20")
    checkEqual(PageScroll.scrollDelta(old: page, new: inked, topVisibleY: 10), 0, "a band point stays")
    checkEqual(PageScroll.scrollDelta(old: inked, new: page, topVisibleY: 500), -20, "shrinking moves up")
    checkEqual(PageScroll.scrollDelta(old: page, new: inked, topVisibleY: -5), 0, "above the paper")
    checkEqual(PageScroll.scrollDelta(old: page, new: inked, topVisibleY: 5000), 0, "below the paper")
    checkEqual(page.sameGeometry(as: inked), false, "different band heights")
    checkEqual(page.sameGeometry(as: weekLayout(demo, now: october(7, 11))), true, "only `now` changed")
    checkEqual(page.sameGeometry(as: weekLayout(demo, focus: day(2026, 10, 14))), false, "another week")
    checkEqual(page == weekLayout(demo), true, "Equatable")

    // Thinning at the cap: 40 lanes on Monday.
    var pile: [LayoutEvent] = []
    for i in 0..<40 { pile.append(allDay("pile\(i)", 5, 6, title: "p\(i)")) }
    let capped = weekLayout(pile)
    checkEqual(capped.laneCount, 40, "40 lanes")
    checkEqual(capped.band.height, 800, "band capped at 800")
    checkClose(capped.laneMetrics.step, 19.25, "thinned step")
    checkClose(capped.laneMetrics.lane, 16.25, "thinned lane")
    checkClose(capped.allDayBars.last?.frame.minY, 3 + 39 * 19.25, "last bar's y")
    checkClose(capped.allDayBars.last?.frame.maxY, 3 + 39 * 19.25 + 16.25, "last bar ends above the ink margin")

    // Initial scroll.
    checkEqual(PageNavigation.initialScrollY(page, now: demoNow, calendar: tokyo), 60 + 720, "today at 10:00 → 9:00")
    checkEqual(PageNavigation.initialScrollY(holidayWeek, now: demoNow, calendar: tokyo), 60 + 560, "no today → 7:00")
    checkEqual(PageNavigation.initialScrollY(page, now: october(7, 0, 30), calendar: tokyo), 60, "early morning clamps to 0:00")
    checkEqual(PageNavigation.initialScrollY(inked, now: demoNow, calendar: tokyo), 80 + 720, "the band height is included")
}

// MARK: - Day page

section("day page")
func dayLayout(_ events: [LayoutEvent], focus: DayKey = day(2026, 10, 7), ink: [CellKey: CGFloat] = [:], now: Date = demoNow) -> DayPageLayout {
    DayLayoutEngine.layout(DayLayoutInput(day: focus, events: events, inkBottoms: ink, now: now, calendar: tokyo))
}
checkEqual(DayLayoutEngine.bandHeight(laneCount: 3, inkBottom: 0), 102, "band: 3 × 24 + 30")
checkEqual(DayLayoutEngine.bandHeight(laneCount: 1, inkBottom: 0), 60, "band: 1 lane → base")
checkEqual(DayLayoutEngine.bandHeight(laneCount: 0, inkBottom: 100), 112, "band: ink + 12")
checkEqual(DayLayoutEngine.bandHeight(laneCount: 40, inkBottom: 0), 800, "band: capped")
do {
    let page = dayLayout(demo)
    checkEqual(page.pageId, "d-2026-10-07", "day page id")
    checkEqual(page.kind, .day, "kind")
    checkEqual(page.day, day(2026, 10, 7), "day")
    checkEqual(page.isToday, true, "today")
    checkEqual(page.size, CGSize(width: 1000, height: 2460), "1000 × (60 + 2400)")
    checkEqual(page.cells.count, 2, "allday + grid")
    checkEqual(page.cells[.allDayDay], CGRect(x: 0, y: 0, width: 1000, height: 60), "band cell spans the full width")
    checkEqual(page.cells[.grid], CGRect(x: 0, y: 60, width: 1000, height: 2400), "grid cell")
    checkEqual(page.timeline, CGRect(x: 72, y: 60, width: 588, height: 2400), "timeline")
    checkEqual(page.memo, CGRect(x: 660, y: 60, width: 340, height: 2400), "memo area")
    checkEqual(page.laneCount, 1, "one all-day event")
    checkEqual(page.laneMetrics, LaneMetrics(lane: 22, step: 24, gap: 2, fontScale: 1), "plain day lanes")
    checkEqual(page.allDayBars.count, 1, "one chip")
    checkEqual(page.allDayBars[0].frame, CGRect(x: 76, y: 2, width: 572, height: 22), "chip inside the timeline column")
    checkEqual(page.allDayBars[0].title, "締切", "chip title")
    checkEqual(page.allDayBars[0].continuesLeft, false, "chip starts today")
    checkEqual(page.allDayBars[0].continuesRight, false, "chip ends today")
    checkEqual(page.dateLabels.count, 1, "one label")
    checkEqual(page.dateLabels[0].frame, CGRect(x: 72, y: 0, width: 588, height: 0), "label without height")
    checkEqual(page.dateLabels[0].isToday, true, "label today")
    checkEqual(page.nowLine, NowLine(y: 60 + 1000, x0: 72, x1: 660, minute: 600), "now line across the timeline")
    checkEqual(page.minutesToY(600), 1060, "minutesToY")

    let boxes = Dictionary(uniqueKeysWithValues: page.timedBoxes.map { ($0.eventId, $0) })
    checkEqual(page.timedBoxes.count, 3, "3 timed boxes on the 7th")
    let w2 = (570.0 - 3) / 2
    checkRect(boxes[demoId("打合せ")]?.frame, CGRect(x: 76, y: 60 + 1001, width: w2, height: 148), "打合せ: column 0 of 2")
    checkRect(boxes[demoId("電話")]?.frame, CGRect(x: 76 + w2 + 3, y: 60 + 1051, width: w2, height: 48), "電話: column 1 of 2")
    checkRect(boxes[demoId("歯科")]?.frame, CGRect(x: 76, y: 60 + 1401, width: 570, height: 98), "歯科: alone")
    checkEqual(boxes[demoId("電話")]?.columns, 2, "2 columns")
    checkEqual(boxes[demoId("電話")]?.timeText, "10:30〜11:00", "time text")
    checkEqual(page.timedBoxes.filter(\.isPast).count, 0, "nothing is past at 10:00")
    checkEqual(dayLayout(demo, now: october(7, 16)).timedBoxes.filter(\.isPast).count, 3, "everything is past at 16:00")

    checkEqual(page.hit(at: CGPoint(x: 100, y: 60 + 1010)), .timedBox(demoId("打合せ")), "hit a box")
    checkEqual(page.hit(at: CGPoint(x: 100, y: 10)), .allDayBar(demoId("締切")), "hit the chip")
    checkEqual(page.hit(at: CGPoint(x: 800, y: 10)), nil, "the memo part of the band has no chip")
    checkEqual(page.hit(at: CGPoint(x: 800, y: 1000)), nil, "memo area hits nothing")
    checkEqual(page.cell(at: CGPoint(x: 900, y: 30)), .allDayDay, "band cell")
    checkEqual(page.cell(at: CGPoint(x: 30, y: 30)), .allDayDay, "band cell includes the gutter")
    checkEqual(page.cell(at: CGPoint(x: 900, y: 1000)), .grid, "grid cell (memo area)")
    checkEqual(page.cell(at: CGPoint(x: 1000, y: 60)), .grid, "right edge belongs to the grid")
    checkEqual(page.cell(at: CGPoint(x: 1001, y: 60)), nil, "right of the paper")
    checkEqual(page.cell(at: CGPoint(x: 100, y: 2460)), nil, "below the paper")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 900, y: 30)), .allDayDay, "ink in the band")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 900, y: 1000)), .grid, "ink in the memo area → grid")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 30, y: 1000)), .grid, "ink in the gutter → grid")
    checkEqual(page.inkCell(forCenter: CGPoint(x: -10, y: -10)), .allDayDay, "ink above the paper → band")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 2000, y: 9000)), .grid, "ink below the paper → grid")
    checkEqual(page.growsWithInk(.allDayDay), true, "the band grows")
    checkEqual(page.growsWithInk(.grid), false, "the grid never grows")
    checkEqual(page.band(atY: 30), PageBand(raw: "allday"), "band allday")
    checkEqual(page.band(atY: 2459), PageBand(raw: "grid"), "band grid")
    checkEqual(page.band(atY: 2460), nil, "band below")
    checkEqual(page.bandTop(PageBand(raw: "grid")), 60, "bandTop grid")

    let busy = dayLayout(demo + [allDay("a", 7, 8, title: "a"), allDay("b", 1, 20, title: "b")])
    checkEqual(busy.laneCount, 3, "3 all-day events")
    checkEqual(busy.band.height, 102, "band grows to 102")
    checkEqual(busy.allDayBars.map(\.title), ["b", "a", "締切"], "earlier start first (b since 10/1), then title")
    checkEqual(busy.allDayBars.map(\.lane), [0, 1, 2], "lane = display order")
    checkEqual(busy.allDayBars.map(\.frame.minY), [2, 26, 50], "chips stack by 24")
    checkEqual(busy.allDayBars[0].continuesLeft, true, "b started before the day")
    checkEqual(busy.allDayBars[0].continuesRight, true, "b continues after the day")
    checkEqual(busy.cells[.grid]?.minY, 102, "grid below the taller band")
    checkEqual(PageScroll.scrollDelta(old: page, new: busy, topVisibleY: 500), 42, "grid moves down by 42")
    checkEqual(PageScroll.scrollDelta(old: page, new: busy, topVisibleY: 30), 0, "band stays")
    checkEqual(page.sameGeometry(as: busy), false, "different band heights")
    checkEqual(page.sameGeometry(as: dayLayout(demo, now: october(7, 15))), true, "only `now` changed")

    let inked = dayLayout(demo, ink: [.allDayDay: 200, .grid: 9000])
    checkEqual(inked.band.height, 212, "band grows with its ink; grid ink is ignored")
    checkEqual(inked.size.height, 2612, "paper height")
    let tomorrow = dayLayout(demo, focus: day(2026, 10, 8))
    checkEqual(tomorrow.isToday, false, "not today")
    checkEqual(tomorrow.nowLine, nil, "no now line")
    checkEqual(tomorrow.allDayBars.count, 0, "no chip on the 8th")
    checkEqual(tomorrow.timedBoxes.map(\.title), ["資料提出"], "the 8th's timed event")
    checkEqual(PageNavigation.initialScrollY(page, now: demoNow, calendar: tokyo), 60 + 900, "today at 10:00 → 9:00 (100 lu per hour)")
    checkEqual(PageNavigation.initialScrollY(tomorrow, now: demoNow, calendar: tokyo), 60 + 700, "not today → 7:00")
    let holiday = dayLayout([], focus: day(2026, 10, 12))
    checkEqual(holiday.dateLabels[0].holidayName, "スポーツの日", "holiday name")
    checkEqual(holiday.dateLabels[0].tone, .sundayOrHoliday, "holiday tone")
}

// MARK: - Year page

section("year page")
func yearLayout(_ events: [LayoutEvent], year: Int = 2026, ink: [CellKey: CGFloat] = [:], now: Date = demoNow) -> YearPageLayout {
    YearLayoutEngine.layout(YearLayoutInput(year: year, events: events, inkBottoms: ink, now: now, calendar: tokyo))
}
checkEqual(YearLayoutEngine.rowHeight(laneCount: 0, inkBottom: 0), 60, "row: base")
checkEqual(YearLayoutEngine.rowHeight(laneCount: 1, inkBottom: 0), 60, "row: 1 lane → 42 → base")
checkEqual(YearLayoutEngine.rowHeight(laneCount: 4, inkBottom: 0), 96, "row: 16 + 72 + 8")
checkEqual(YearLayoutEngine.rowHeight(laneCount: 0, inkBottom: 100), 112, "row: ink + 12")
checkEqual(YearLayoutEngine.rowHeight(laneCount: 40, inkBottom: 0), 400, "row: capped")
checkEqual(YearLayoutEngine.rowHeight(laneCount: 0, inkBottom: 5000), 400, "row: ink capped")
do {
    let plain = yearLayout([])
    checkEqual(plain.pageId, "y-2026", "year page id")
    checkEqual(plain.kind, .year, "kind")
    checkEqual(plain.year, 2026, "year")
    checkEqual(plain.rows.count, 31, "31 rows")
    checkEqual(plain.cells.count, 372, "12 × 31 cells")
    checkEqual(plain.invalidCells.map(\.raw), ["02-29", "02-30", "02-31", "04-31", "06-31", "09-31", "11-31"], "impossible dates of 2026")
    checkEqual(yearLayout([], year: 2028).invalidCells.map(\.raw), ["02-30", "02-31", "04-31", "06-31", "09-31", "11-31"], "2028 has a 2/29")
    checkEqual(plain.dateLabels.count, 365, "a label per existing day")
    checkEqual(yearLayout([], year: 2028).dateLabels.count, 366, "366 labels in a leap year")
    checkEqual(plain.size, CGSize(width: 1400, height: 1860), "31 × 60")
    checkEqual(plain.rows.map(\.frame.minY).prefix(3).map { $0 }, [0, 60, 120], "rows stack")
    checkEqual(plain.rows[30].dayNumber, 31, "last row is day 31")
    checkEqual(plain.cellFrame(month: 10, day: 7), CGRect(x: 56 + 9 * 112, y: 6 * 60, width: 112, height: 60), "cell of 10/7")
    checkEqual(plain.cellFrame(month: 1, day: 1), CGRect(x: 56, y: 0, width: 112, height: 60), "cell of 1/1")
    checkEqual(plain.cellFrame(month: 2, day: 30), CGRect(x: 168, y: 29 * 60, width: 112, height: 60), "2/30 has a cell too")
    checkEqual(plain.cellFrame(month: 13, day: 1), nil, "month 13 has no cell")
    checkEqual(plain.cellFrame(month: 1, day: 32), nil, "day 32 has no cell")
    checkEqual(plain.columnFrame(month: 12), CGRect(x: 56 + 11 * 112, y: 0, width: 112, height: 1860), "December's column")
    checkEqual(plain.chips.count, 0, "no chips")
    checkEqual(plain.allDayBars.count, 0, "no bars on the year page")
    checkEqual(plain.timedBoxes.count, 0, "no boxes on the year page")
    checkEqual(plain.nowLine, nil, "no now line on the year page")
    checkEqual(plain.todayCell, CellKey(raw: "10-07"), "today's cell")
    checkEqual(yearLayout([], year: 2025).todayCell, nil, "today is not in 2025")
    let labels = Dictionary(uniqueKeysWithValues: plain.dateLabels.map { ($0.day, $0) })
    checkEqual(labels[day(2026, 10, 7)]?.frame, CGRect(x: 56 + 9 * 112, y: 360, width: 40, height: 28), "weekday letter tap area")
    checkEqual(labels[day(2026, 10, 7)]?.isToday, true, "today label")
    checkEqual(labels[day(2026, 10, 12)]?.holidayName, "スポーツの日", "holiday name")
    checkEqual(labels[day(2026, 10, 12)]?.tone, .sundayOrHoliday, "holiday tone")
    checkEqual(labels[day(2026, 10, 10)]?.tone, .saturday, "Saturday tone")
    checkEqual(labels[day(2026, 1, 1)]?.holidayName, "元日", "New Year's Day")
    checkEqual(plain.dateLabels.filter(\.isToday).count, 1, "one today")

    checkEqual(plain.cell(at: CGPoint(x: 30, y: 100)), nil, "the day-number gutter belongs to no cell")
    checkEqual(plain.cell(at: CGPoint(x: 56, y: 100)), CellKey(raw: "01-02"), "January, day 2")
    checkEqual(plain.cell(at: CGPoint(x: 1400, y: 100)), CellKey(raw: "12-02"), "right edge is December")
    checkEqual(plain.cell(at: CGPoint(x: 100, y: 1860)), nil, "below the paper")
    checkEqual(plain.cell(at: CGPoint(x: 1401, y: 100)), nil, "right of the paper")
    checkEqual(plain.cell(at: CGPoint(x: 56 + 112, y: 100)), CellKey(raw: "02-02"), "column boundary maps to its own column")
    checkEqual(plain.cell(at: CGPoint(x: 200, y: 1800)), CellKey(raw: "02-31"), "an impossible date is a cell")
    checkEqual(plain.inkCell(forCenter: CGPoint(x: 30, y: 100)), CellKey(raw: "01-02"), "ink in the gutter → January")
    checkEqual(plain.inkCell(forCenter: CGPoint(x: -10, y: -10)), CellKey(raw: "01-01"), "ink above-left → 1/1")
    checkEqual(plain.inkCell(forCenter: CGPoint(x: 1500, y: 100)), CellKey(raw: "12-02"), "ink right of the paper → December")
    checkEqual(plain.inkCell(forCenter: CGPoint(x: 100, y: 5000)), CellKey(raw: "01-31"), "ink below the paper → day 31")
    checkEqual(plain.inkCell(forCenter: CGPoint(x: 500, y: 100)), CellKey(raw: "04-02"), "ink inside → its cell")
    checkEqual(plain.growsWithInk(CellKey(raw: "02-30")), true, "every year cell grows")
    checkEqual(plain.growsWithInk(.memo), false, "memo is not a year cell")
    checkEqual(plain.growsWithInk(.grid), false, "grid is not a year cell")
    checkEqual(plain.row(atY: 0), 1, "row 1")
    checkEqual(plain.row(atY: 1859.9), 31, "row 31")
    checkEqual(plain.row(atY: 1860), nil, "below the rows")
    checkEqual(plain.band(atY: 100), PageBand(raw: "row:2"), "band row:2")
    checkEqual(plain.bandTop(PageBand(raw: "row:2")), 60, "bandTop row:2")
    checkEqual(plain.bandTop(PageBand(raw: "row:0")), nil, "there is no row 0")
    checkEqual(plain.bandTop(PageBand(raw: "row:32")), nil, "there is no row 32")
    checkEqual(plain.hit(at: CGPoint(x: 56 + 9 * 112 + 5, y: 365)), .date(day(2026, 10, 7)), "hit the weekday letter")
    checkEqual(plain.hit(at: CGPoint(x: 168 + 5, y: 29 * 60 + 5)), nil, "an impossible date has no weekday letter")
    checkEqual(plain.hit(at: CGPoint(x: 56 + 9 * 112 + 100, y: 400)), nil, "empty cell")

    // Demo events: the 16th grows, multi-day chips share a lane.
    let page = yearLayout(demo)
    checkEqual(page.rows[15].frame.height, 96, "10/16 has 4 all-day events → 16 + 4 × 18 + 8")
    checkEqual(page.rows[15].laneCount, 4, "4 lanes on the 16th")
    checkEqual(page.rows[16].frame.minY, plain.rows[16].frame.minY + 36, "the rows below move down by 36")
    checkEqual(page.cells[CellKey(raw: "02-16")]?.height, 96, "February's 16th cell is as tall")
    checkEqual(page.cellFrame(month: 10, day: 7), CGRect(x: 56 + 9 * 112, y: 6 * 60, width: 112, height: 60), "10/7 stays 60 with one lane")
    checkEqual(page.size.height, 1860 + 36, "paper grows by 36")
    let trip = page.chips.filter { $0.title == "家族旅行" }.sorted { $0.day < $1.day }
    checkEqual(trip.count, 5, "家族旅行 9–13: five chips")
    checkEqual(trip.map(\.day.day), [9, 10, 11, 12, 13], "one chip per day")
    checkEqual(Set(trip.map(\.lane)).count, 1, "all in the same lane")
    checkEqual(trip[0].continuesUp, false, "9th: starts there")
    checkEqual(trip[0].continuesDown, true, "9th: continues down")
    checkEqual(trip[2].continuesUp, true, "11th: continues up")
    checkEqual(trip[2].continuesDown, true, "11th: continues down")
    checkEqual(trip[4].continuesUp, true, "13th: continues up")
    checkEqual(trip[4].continuesDown, false, "13th: ends there")
    checkEqual(trip[0].linkToY, trip[1].frame.minY, "9th links to the 10th's chip")
    checkEqual(trip[3].linkToY, trip[4].frame.minY, "12th links to the 13th's chip")
    checkEqual(trip[4].linkToY, nil, "13th links nowhere")
    let cellX10 = 56.0 + 9 * 112
    checkRect(trip[0].frame, CGRect(x: cellX10 + 50.4, y: 8 * 60 + 16, width: 58.6, height: 16), "chip in the right 55 % of the cell")
    checkEqual(trip[0].isThin, false, "not thin")
    checkEqual(trip[0].fontScale, 1, "full font")
    let sixteenth = page.chips.filter { $0.day == day(2026, 10, 16) }.sorted { $0.lane < $1.lane }
    checkEqual(sixteenth.count, 4, "four chips on the 16th")
    checkEqual(sixteenth.map(\.lane), [0, 1, 2, 3], "four lanes")
    checkClose(sixteenth[3].frame.minY, page.rows[15].frame.minY + 16 + 3 * 18, "4th lane y")
    checkEqual(sixteenth.map(\.title), ["ゴミの日", "健康診断", "誕生日", "資料提出締切"], "same day and length → by title (Unicode order)")
    checkEqual(page.chips.count, 16, "運動会, キャンプ×2, 家族旅行×5, the 16th×4, 出張×2, 給料日, 締切")
    checkEqual(page.chips.filter { $0.title == "歯医者" }.count, 0, "timed events are not on the year page")
    let deadline = page.chips.first { $0.title == "締切" }
    checkEqual(page.hit(at: CGPoint(x: cellX10 + 55, y: 360 + 20)), .allDayBar(deadline?.eventId ?? "?"), "hit a chip")
    checkEqual(page.hit(at: CGPoint(x: cellX10 + 5, y: 365)), .date(day(2026, 10, 7)), "hit the weekday letter next to a chip")
    checkEqual(page.band(atY: page.rows[16].frame.minY + 5), PageBand(raw: "row:17"), "band of the 17th")
    checkEqual(PageScroll.scrollDelta(old: plain, new: page, topVisibleY: 1000), 36, "a point on the 17th moves down")
    checkEqual(PageScroll.scrollDelta(old: plain, new: page, topVisibleY: 930), 0, "a point on the 16th stays")
    checkEqual(PageScroll.scrollDelta(old: plain, new: page, topVisibleY: 100), 0, "a point above stays")
    checkEqual(PageScroll.scrollDelta(old: page, new: plain, topVisibleY: 1800), -36, "shrinking moves up")
    checkEqual(plain.sameGeometry(as: page), false, "different row heights")
    checkEqual(plain.sameGeometry(as: yearLayout([], now: october(20, 9))), true, "only `now` changed")
    checkEqual(plain.sameGeometry(as: yearLayout([], year: 2027)), false, "another year")

    // Ink grows a row (the deepest of the 12 cells of the row).
    let inked = yearLayout([], ink: [CellKey(raw: "03-05"): 100, CellKey(raw: "07-05"): 150, CellKey(raw: "02-30"): 90])
    checkEqual(inked.rows[4].frame.height, 162, "row 5: ink 150 + 12")
    checkEqual(inked.rows[29].frame.height, 102, "an impossible date's ink grows its row too")
    checkEqual(inked.rows[5].frame.minY, 300 + 102, "rows below move down")

    // Thinning at the cap: 40 all-day events on 10/20; another month's chip on the same row stays 16.
    var pile: [LayoutEvent] = [LayoutEvent(id: "march", title: "3月", allDay: true, start: date(2026, 3, 20), end: date(2026, 3, 21), colorHex: "#000000", calendarId: "c")]
    for i in 0..<40 { pile.append(allDay("pile\(i)", 20, 21, title: "p\(i)")) }
    let capped = yearLayout(pile)
    checkEqual(capped.rows[19].frame.height, 400, "row 20 capped at 400")
    checkEqual(capped.rows[19].laneCount, 40, "40 lanes")
    let thin = capped.chips.filter { $0.day == day(2026, 10, 20) }.sorted { $0.lane < $1.lane }
    checkEqual(thin.count, 40, "40 chips")
    let step = 378.0 / 40
    checkClose(thin[1].frame.minY - thin[0].frame.minY, step, "thinned step 378 / 40")
    checkClose(thin[0].frame.height, step - 2, "thinned lane")
    checkEqual(thin.allSatisfy(\.isThin), true, "lanes below 12 are thin")
    checkClose(thin[0].fontScale, (step - 2) / 16, "font scale of a thin chip")
    checkClose(thin[39].frame.maxY, capped.rows[19].frame.minY + 16 + 39 * step + step - 2, "last chip stays inside the row")
    let march = capped.chips.first { $0.eventId == "march" }
    checkEqual(march?.frame.height, 16, "March's chip on the same row is not thinned")
    checkEqual(march?.isThin, false, "March's chip is not thin")
    checkEqual(march?.frame.minY, capped.rows[19].frame.minY + 16, "March's chip y")
    checkEqual(capped.hit(at: CGPoint(x: cellX10 + 55, y: capped.rows[19].frame.minY + 17)), .date(day(2026, 10, 20)), "a thin chip opens the day")
    checkEqual(capped.hit(at: CGPoint(x: 56 + 2 * 112 + 55, y: capped.rows[19].frame.minY + 17)), .allDayBar("march"), "a normal chip opens the event")

    // monthSpans and initial scroll.
    let spans = YearLayoutEngine.monthSpans(events: demo, year: 2026, month: 10, calendar: tokyo)
    checkEqual(spans.first { $0.event.title == "家族旅行" }.map { [$0.startCol, $0.endCol, $0.lane] }, [8, 12, 0], "家族旅行 spans day indices 8…12")
    checkEqual(spans.filter { $0.startCol == 15 }.map(\.lane).sorted(), [0, 1, 2, 3], "four lanes on the 16th")
    checkEqual(YearLayoutEngine.monthSpans(events: demo, year: 2026, month: 9, calendar: tokyo).count, 0, "nothing in September")
    checkEqual(PageNavigation.initialScrollY(page, now: demoNow, calendar: tokyo), page.rows[4].frame.minY, "today 10/7 → the row of the 5th")
    checkEqual(PageNavigation.initialScrollY(page, now: date(2026, 1, 1, 9), calendar: tokyo), 0, "today 1/1 → top")
    checkEqual(PageNavigation.initialScrollY(page, now: date(2025, 10, 7, 9), calendar: tokyo), 0, "another year → top")
    checkEqual(PageNavigation.initialScrollY(page, now: date(2026, 10, 31, 9), calendar: tokyo), page.rows[28].frame.minY, "today 10/31 → the row of the 29th")
}

// MARK: - Month page as a PageLayout

section("month page as a PageLayout")
do {
    let plain = layout([])
    checkEqual(plain.kind, .month, "kind")
    checkEqual(plain.pageId, "m1-2026-10", "month page id")
    checkEqual(plain.month, YearMonth(year: 2026, month: 10), "month from the grid")
    checkEqual(plain.timedBoxes.count, 0, "no boxes on the month page")
    checkEqual(plain.nowLine, nil, "no now line on the month page")
    checkEqual(plain.inkCell(forCenter: CGPoint(x: 650, y: 10)), .day(day(2026, 10, 1)), "ink inside → its cell")
    checkEqual(plain.inkCell(forCenter: CGPoint(x: -5, y: 10)), .day(day(2026, 9, 28)), "ink left of the paper → the nearest cell")
    checkEqual(plain.inkCell(forCenter: CGPoint(x: 1500, y: 200)), .day(day(2026, 10, 11)), "ink right of the paper → the last column")
    checkEqual(plain.inkCell(forCenter: CGPoint(x: 100, y: -20)), .day(day(2026, 9, 28)), "ink above the paper → row 0")
    checkEqual(plain.inkCell(forCenter: CGPoint(x: 100, y: 5000)), .memo, "ink below the paper → memo")
    checkEqual(plain.inkCell(forCenter: CGPoint(x: 100, y: 1100)), .memo, "ink in the memo area")
    checkEqual(plain.growsWithInk(.memo), true, "memo grows")
    checkEqual(plain.growsWithInk(.day(day(2026, 10, 1))), true, "day cells grow")
    checkEqual(plain.growsWithInk(.grid), false, "grid is not a month cell")
    checkEqual(plain.band(atY: 10), PageBand(raw: "row:0"), "band row:0")
    checkEqual(plain.band(atY: 1049.9), PageBand(raw: "row:5"), "band row:5")
    checkEqual(plain.band(atY: 1100), PageBand(raw: "memo"), "band memo")
    checkEqual(plain.band(atY: 1750), nil, "band below")
    checkEqual(plain.band(atY: -1), nil, "band above")
    checkEqual(plain.bandTop(PageBand(raw: "row:3")), 525, "bandTop row:3")
    checkEqual(plain.bandTop(PageBand(raw: "memo")), 1050, "bandTop memo")
    checkEqual(plain.bandTop(PageBand(raw: "row:6")), nil, "no row 6")
    checkEqual(plain.bandTop(PageBand(raw: "allday")), nil, "no allday band")
    let inked = layout([], ink: [.day(day(2026, 10, 14)): 300, .memo: 900])
    checkEqual(PageScroll.scrollDelta(old: plain, new: inked, topVisibleY: 600), 137, "PageScroll agrees with MonthLayoutEngine.scrollDelta")
    checkEqual(PageScroll.scrollDelta(old: plain, new: inked, topVisibleY: 1100), 137, "memo band")
    checkEqual(PageScroll.scrollDelta(old: plain, new: inked, topVisibleY: 360), 0, "the changed row keeps its top")
    checkEqual(plain.sameGeometry(as: layout([])), true, "same input → same geometry")
    checkEqual(plain.sameGeometry(as: inked), false, "ink changes the geometry")
    checkEqual(plain.sameGeometry(as: layout([], now: date(2026, 10, 20, 9))), true, "`now` does not change the geometry")
    checkEqual(plain.sameGeometry(as: weekLayout([])), false, "another kind")
    let erased: any PageLayout = plain
    checkEqual(erased.cell(at: CGPoint(x: 650, y: 10)), .day(day(2026, 10, 1)), "works through the existential")
}

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
