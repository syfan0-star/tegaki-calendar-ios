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
checkEqual(PaperSpec.allDayLaneStep, 25, "all-day lane step (M4b: the fixed band's lu)")
checkEqual(PaperSpec.weekBarInset, 3, "week bar inset (M4b: the fixed band's x)")
checkEqual(PaperSpec.dayChipPadLeft, 4, "day chip pad left (M4b: the fixed band's x)")
checkEqual(PaperSpec.dayChipPadRight, 12, "day chip pad right (M4b: the fixed band's x)")
checkEqual(CellKey.allDay(day(2026, 10, 4)).raw, "allday:2026-10-04", "week band key (read by the migration only)")
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
// The compact header's short titles (M4b, M4B_CONTRACT §5).
checkEqual(PageNavigation.compactTitle(.day, focus: day(2026, 10, 7)), "10月7日(水)", "compact day title")
checkEqual(PageNavigation.compactTitle(.day, focus: day(2026, 10, 12)), "10月12日(月)", "compact day title without the holiday name")
checkEqual(PageNavigation.compactTitle(.day, focus: day(2026, 1, 1)), "1月1日(木)", "compact day title on New Year's Day (no holiday name)")
checkEqual(PageNavigation.compactTitle(.day, focus: day(2026, 10, 17)), "10月17日(土)", "compact day title (Saturday)")
checkEqual(PageNavigation.compactTitle(.week, focus: day(2026, 10, 7)), "10/5〜10/11", "compact week title")
checkEqual(PageNavigation.compactTitle(.week, focus: day(2026, 10, 4)), "9/28〜10/4", "compact week title across months")
checkEqual(PageNavigation.compactTitle(.week, focus: day(2027, 1, 1)), "12/28〜1/3", "compact week title across years (no year)")
checkEqual(PageNavigation.compactTitle(.week, focus: day(2026, 12, 28)), "12/28〜1/3", "compact week title from the Monday 2026-12-28")
checkEqual(PageNavigation.compactTitle(.week, focus: day(2026, 10, 25)), "10/19〜10/25", "compact week title from a Sunday")
checkEqual(PageNavigation.compactTitle(.month, focus: day(2026, 10, 4)), "2026年10月", "compact month title = title")
checkEqual(PageNavigation.compactTitle(.month, focus: day(2026, 12, 31)), "2026年12月", "compact month title (December)")
checkEqual(PageNavigation.compactTitle(.year, focus: day(2026, 10, 4)), "2026年", "compact year title = title")
checkEqual(PageNavigation.compactTitle(.month, focus: day(2026, 10, 4)), PageNavigation.title(.month, focus: day(2026, 10, 4)), "month: compact == title")
checkEqual(PageNavigation.compactTitle(.year, focus: day(2026, 10, 4)), PageNavigation.title(.year, focus: day(2026, 10, 4)), "year: compact == title")

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
do {
    let empty = weekLayout([])
    checkEqual(empty.pageId, "w-2026-10-05", "week page id")
    checkEqual(empty.kind, .week, "kind")
    checkEqual(empty.days, (5...11).map { day(2026, 10, $0) }, "Monday 10/5 … Sunday 10/11")
    checkEqual(empty.size, CGSize(width: 1400, height: 1920), "the paper is the 24-hour grid (M4b: no band on the paper)")
    checkEqual(empty.grid, CGRect(x: 0, y: 0, width: 1400, height: 1920), "the grid starts at the paper's top")
    checkEqual(empty.cells.count, 1, "one cell: the grid")
    checkEqual(empty.cells[.grid], CGRect(x: 0, y: 0, width: 1400, height: 1920), "grid cell")
    checkEqual(empty.cells[.allDay(day(2026, 10, 5))], nil, "no band cell on the paper")
    checkClose(empty.columnFrame(6).maxX, 1400, "last column ends at the right edge", tolerance: 1e-9)
    checkEqual(empty.columnFrame(0), CGRect(x: 64, y: 0, width: colW, height: 1920), "first column frame (y 0)")
    checkEqual(empty.column(atX: 10), nil, "gutter has no column")
    checkEqual(empty.column(atX: 64), 0, "column at the gutter edge")
    checkEqual(empty.column(atX: 1400), 6, "x == 1400 is the last column")
    checkEqual(empty.column(atX: 1401), nil, "right of the paper")
    checkEqual(empty.column(atX: 64 + 2 * colW), 2, "column boundary maps to its own column")
    checkEqual(empty.allDayBars.count, 0, "allDayBars is always empty")
    checkEqual(empty.allDayBand.laneCount, 0, "no lanes in the band")
    checkEqual(empty.allDayBand.bars.count, 0, "no bars in the band")
    checkEqual(empty.allDayBand.tones, [.normal, .normal, .normal, .normal, .normal, .saturday, .sundayOrHoliday], "band tones of the week 10/5")
    checkEqual(empty.allDayBand.todayColumn, 2, "band today column")
    checkEqual(empty.timedBoxes.count, 0, "no boxes")
    checkEqual(empty.dateLabels.count, 7, "7 date labels")
    checkEqual(empty.dateLabels[2].isToday, true, "Wednesday is today")
    checkEqual(empty.dateLabels[2].frame, CGRect(x: 64 + 2 * colW, y: 0, width: colW, height: 0), "date labels have no height")
    checkEqual(empty.dateLabels[5].tone, .saturday, "Saturday tone")
    checkEqual(empty.dateLabels[6].tone, .sundayOrHoliday, "Sunday tone")
    checkEqual(empty.dateLabels.map(\.inMonth), Array(repeating: true, count: 7), "inMonth is always true")
    checkEqual(empty.dateLabels.map(\.tone), empty.allDayBand.tones, "the band's tones are the labels' tones")
    checkEqual(empty.todayColumn, 2, "today column")
    checkEqual(empty.nowLine, NowLine(y: 800, x0: 64 + 2 * colW, x1: 64 + 3 * colW, minute: 600), "now line at 10:00 in Wednesday's column (y 800, no band)")
    checkEqual(empty.minutesToY(600), 800, "minutesToY(600) = 800")
    checkEqual(empty.minutesToY(0), 0, "minutesToY(0) = 0")

    let holidayWeek = weekLayout([], focus: day(2026, 10, 12))
    checkEqual(holidayWeek.dateLabels[0].holidayName, "スポーツの日", "holiday name on 10/12")
    checkEqual(holidayWeek.dateLabels[0].tone, .sundayOrHoliday, "holiday tone")
    checkEqual(holidayWeek.nowLine, nil, "no now line when today is not on the page")
    checkEqual(holidayWeek.todayColumn, nil, "no today column")
    checkEqual(holidayWeek.allDayBand.todayColumn, nil, "no today column in the band")
    checkEqual(holidayWeek.dateLabels.filter(\.isToday).count, 0, "no today mark")

    // Demo events: the band's 3 bars (outside the paper), boxes with 2 overlap columns, isPast.
    let page = weekLayout(demo)
    checkEqual(page.allDayBars.count, 0, "the paper has no bars")
    let band = page.allDayBand
    checkEqual(band.kind, .week, "band kind")
    checkEqual(band.days, page.days, "band days")
    checkEqual(band.laneCount, 1, "one lane")
    checkEqual(band.bars.count, 3, "キャンプ, 締切, 家族旅行")
    checkEqual(band.bars.map(\.title), ["キャンプ", "締切", "家族旅行"], "bars by lane, then start column")
    let bars = Dictionary(uniqueKeysWithValues: band.bars.map { ($0.title, $0) })
    checkEqual(bars["キャンプ"]?.lane, 0, "キャンプ lane 0")
    checkEqual(bars["キャンプ"]?.startCol, 0, "キャンプ starts in column 0")
    checkEqual(bars["キャンプ"]?.endCol, 0, "キャンプ ends in column 0")
    checkEqual(bars["キャンプ"]?.continuesLeft, true, "キャンプ continues left")
    checkEqual(bars["キャンプ"]?.continuesRight, false, "キャンプ ends in the week")
    checkClose(bars["キャンプ"]?.minX, 64, "キャンプ minX (no inset on the open end)")
    checkClose(bars["キャンプ"]?.maxX, 64 + colW - 3, "キャンプ maxX")
    checkEqual(bars["キャンプ"]?.colorHex, demoColors[1], "キャンプ colour")
    checkEqual(bars["締切"]?.lane, 0, "締切 lane 0")
    checkEqual(bars["締切"]?.startCol, 2, "締切 column 2")
    checkEqual(bars["締切"]?.endCol, 2, "締切 ends in column 2")
    checkEqual(bars["締切"]?.continuesLeft, false, "締切 starts in the week")
    checkEqual(bars["締切"]?.continuesRight, false, "締切 ends in the week")
    checkClose(bars["締切"]?.minX, 64 + 2 * colW + 3, "締切 minX")
    checkClose(bars["締切"]?.maxX, 64 + 3 * colW - 3, "締切 maxX")
    checkEqual(bars["締切"]?.eventId, demoId("締切"), "締切 event id")
    checkEqual(bars["締切"]?.id, demoId("締切"), "Identifiable id is the event id")
    checkEqual(bars["締切"]?.colorHex, demoColors[2], "締切 colour")
    checkEqual(bars["家族旅行"]?.lane, 0, "家族旅行 lane 0")
    checkEqual(bars["家族旅行"]?.startCol, 4, "家族旅行 starts Friday")
    checkEqual(bars["家族旅行"]?.endCol, 6, "家族旅行 ends Sunday")
    checkEqual(bars["家族旅行"]?.continuesLeft, false, "家族旅行 starts in the week")
    checkEqual(bars["家族旅行"]?.continuesRight, true, "家族旅行 continues right")
    checkClose(bars["家族旅行"]?.minX, 64 + 4 * colW + 3, "家族旅行 minX")
    checkClose(bars["家族旅行"]?.maxX, 1400, "家族旅行 maxX (open end at the paper's edge)")
    checkEqual(band.todayColumn, 2, "band today column (demo)")
    checkEqual(band.tones.count, 7, "7 tones")
    checkEqual(band.columnMinX.count, 7, "7 column origins")
    checkEqual(band.gutter, 64, "band gutter")
    checkEqual(band.paperWidth, 1400, "band paper width")
    checkEqual(band.columnWidth, colW, "band column width")

    let boxes = Dictionary(uniqueKeysWithValues: page.timedBoxes.map { ($0.eventId, $0) })
    checkEqual(page.timedBoxes.count, 6, "6 timed boxes in the week")
    let colX2 = 64 + 2 * colW
    let inner = colW - 8
    let w2 = (inner - 2) / 2
    checkRect(boxes[demoId("打合せ")]?.frame, CGRect(x: colX2 + 2, y: 801, width: w2, height: 118), "打合せ: column 0 of 2 (y from 0:00)")
    checkRect(boxes[demoId("電話")]?.frame, CGRect(x: colX2 + 2 + w2 + 2, y: 841, width: w2, height: 38), "電話: column 1 of 2")
    checkRect(boxes[demoId("歯科")]?.frame, CGRect(x: colX2 + 2, y: 1121, width: inner, height: 78), "歯科: alone")
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

    // Hit testing: boxes only (the band's bars are the screen's buttons).
    checkEqual(page.hit(at: CGPoint(x: colX2 + 10, y: 810)), .timedBox(demoId("打合せ")), "hit a box")
    checkEqual(page.hit(at: CGPoint(x: colX2 + 2 + w2 + 10, y: 850)), .timedBox(demoId("電話")), "hit the second column")
    checkEqual(page.hit(at: CGPoint(x: colX2 + 10, y: 10)), nil, "the top of the paper is 0:00, not a bar")
    checkEqual(page.hit(at: CGPoint(x: colX2 + 10, y: 100)), nil, "hit empty grid")
    checkEqual(page.hit(at: CGPoint(x: 10, y: 10)), nil, "hit the gutter")
    checkEqual(page.hit(at: CGPoint(x: CGFloat.nan, y: 10)), nil, "NaN hits nothing")

    // Cells and ink cells: everything on the paper is the grid.
    checkEqual(page.cell(at: CGPoint(x: 10, y: 10)), .grid, "the gutter is part of the grid")
    checkEqual(page.cell(at: CGPoint(x: 1400, y: 100)), .grid, "right edge of the grid")
    checkEqual(page.cell(at: CGPoint(x: 100, y: 1920)), nil, "below the paper")
    checkEqual(page.cell(at: CGPoint(x: 100, y: 10)), .grid, "the top of the paper is the grid")
    checkEqual(page.cell(at: CGPoint(x: 1400, y: 0)), .grid, "the top-right corner is the grid")
    checkEqual(page.cell(at: CGPoint(x: -1, y: 100)), nil, "left of the paper")
    checkEqual(page.cell(at: CGPoint(x: 100, y: -1)), nil, "above the paper")
    checkEqual(page.cell(at: CGPoint(x: CGFloat.nan, y: 100)), nil, "NaN is in no cell")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 10, y: 10)), .grid, "ink in the gutter → grid")
    checkEqual(page.inkCell(forCenter: CGPoint(x: -5, y: -5)), .grid, "ink above-left → grid (negative y too)")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 1500, y: 30)), .grid, "ink right of the paper → grid")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 10, y: 500)), .grid, "ink in the time gutter → grid")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 700, y: 5000)), .grid, "ink below the paper → grid")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 300, y: -40)), .grid, "ink above the paper → grid")
    checkEqual(page.inkCell(forCenter: CGPoint(x: CGFloat.nan, y: CGFloat.nan)), .grid, "NaN → grid")
    checkEqual(page.growsWithInk(.grid), false, "the grid never grows")
    checkEqual(page.growsWithInk(.allDay(day(2026, 10, 5))), false, "the former band cell does not grow")
    checkEqual(page.growsWithInk(.allDayDay), false, "the day band key does not grow")
    checkEqual(page.growsWithInk(.memo), false, "memo is not a week cell")

    // Bands and the scroll correction: the grid is the only band, nothing ever moves.
    checkEqual(page.band(atY: 10), PageBand(raw: "grid"), "band: grid at the top")
    checkEqual(page.band(atY: 0), PageBand(raw: "grid"), "band: grid at y 0")
    checkEqual(page.band(atY: 1919.9), PageBand(raw: "grid"), "band: last point")
    checkEqual(page.band(atY: 1920), nil, "band: below")
    checkEqual(page.band(atY: -1), nil, "band: above")
    checkEqual(page.band(atY: .nan), nil, "band: NaN")
    checkEqual(page.bandTop(PageBand(raw: "grid")), 0, "bandTop grid is 0")
    checkEqual(page.bandTop(PageBand(raw: "allday")), nil, "bandTop allday: the paper has no band")
    checkEqual(page.bandTop(PageBand(raw: "memo")), nil, "bandTop of a foreign band")
    checkEqual(page.bandTop(PageBand(raw: "row:0")), nil, "bandTop of a month band")
    let inked = weekLayout(demo, ink: [.allDay(day(2026, 10, 6)): 68, .grid: 5000])
    checkEqual(inked.size.height, 1920, "ink does not grow the paper")
    checkEqual(inked.cells[.grid]?.minY, 0, "the grid stays at the top")
    checkEqual(inked, page, "ink bottoms are not read")
    checkEqual(inked.timedBoxes.first { $0.eventId == demoId("打合せ") }?.frame.minY, 801, "boxes stay")
    checkEqual(inked.nowLine?.y, 800, "the now line stays")
    checkEqual(PageScroll.scrollDelta(old: page, new: inked, topVisibleY: 100), 0, "scrollDelta is always 0")
    checkEqual(PageScroll.scrollDelta(old: page, new: inked, topVisibleY: 10), 0, "scrollDelta at the top")
    checkEqual(PageScroll.scrollDelta(old: inked, new: page, topVisibleY: 500), 0, "scrollDelta the other way")
    checkEqual(PageScroll.scrollDelta(old: page, new: inked, topVisibleY: -5), 0, "above the paper")
    checkEqual(PageScroll.scrollDelta(old: page, new: inked, topVisibleY: 5000), 0, "below the paper")
    checkEqual(PageScroll.scrollDelta(old: page, new: weekLayout(demo, focus: day(2026, 10, 14)), topVisibleY: 700), 0, "another week: the grid is at 0 on both")
    checkEqual(page.sameGeometry(as: inked), true, "ink does not change the geometry")
    checkEqual(page.sameGeometry(as: weekLayout(demo, now: october(7, 11))), true, "only `now` changed")
    checkEqual(page.sameGeometry(as: weekLayout(demo, focus: day(2026, 10, 14))), false, "another week")
    checkEqual(page == weekLayout(demo), true, "Equatable")
    checkEqual(page == weekLayout(demo, now: october(7, 11)), false, "the now line differs")

    // 40 all-day events on Monday: the band takes 40 lanes (no thinning), the paper does not care.
    var pile: [LayoutEvent] = []
    for i in 0..<40 { pile.append(allDay("pile\(i)", 5, 6, title: "p\(i)")) }
    let piled = weekLayout(pile)
    checkEqual(piled.allDayBand.laneCount, 40, "40 lanes in the band")
    checkEqual(piled.allDayBand.bars.count, 40, "40 bars in the band")
    checkEqual(piled.allDayBand.bars.last?.lane, 39, "the last bar is in lane 39")
    checkEqual(piled.size.height, 1920, "the paper does not grow with the band")
    checkEqual(piled.allDayBars.count, 0, "the paper still has no bars")
    checkEqual(piled.sameGeometry(as: page), true, "the band does not change the paper's geometry")

    // Initial scroll (no band above the grid any more: 60 lu less than M3a–M4).
    checkEqual(PageNavigation.initialScrollY(page, now: demoNow, calendar: tokyo), 720, "today at 10:00 → 9:00")
    checkEqual(PageNavigation.initialScrollY(holidayWeek, now: demoNow, calendar: tokyo), 560, "no today → 7:00")
    checkEqual(PageNavigation.initialScrollY(page, now: october(7, 0, 30), calendar: tokyo), 0, "early morning clamps to 0:00")
    checkEqual(PageNavigation.initialScrollY(inked, now: demoNow, calendar: tokyo), 720, "ink does not move the start")
    checkClose(PageNavigation.initialScrollY(page, now: october(7, 23, 59), calendar: tokyo), 22 * 80 + CGFloat(59) * 80 / 60, "23:59 → 22:59")
}

// MARK: - Day page

section("day page")
func dayLayout(_ events: [LayoutEvent], focus: DayKey = day(2026, 10, 7), ink: [CellKey: CGFloat] = [:], now: Date = demoNow) -> DayPageLayout {
    DayLayoutEngine.layout(DayLayoutInput(day: focus, events: events, inkBottoms: ink, now: now, calendar: tokyo))
}
do {
    let page = dayLayout(demo)
    checkEqual(page.pageId, "d-2026-10-07", "day page id")
    checkEqual(page.kind, .day, "kind")
    checkEqual(page.day, day(2026, 10, 7), "day")
    checkEqual(page.isToday, true, "today")
    checkEqual(page.size, CGSize(width: 1000, height: 2400), "1000 × 2400 (M4b: no band on the paper)")
    checkEqual(page.cells.count, 1, "one cell: the grid")
    checkEqual(page.cells[.allDayDay], nil, "no band cell")
    checkEqual(page.cells[.grid], CGRect(x: 0, y: 0, width: 1000, height: 2400), "grid cell")
    checkEqual(page.grid, CGRect(x: 0, y: 0, width: 1000, height: 2400), "grid")
    checkEqual(page.timeline, CGRect(x: 72, y: 0, width: 588, height: 2400), "timeline")
    checkEqual(page.memo, CGRect(x: 660, y: 0, width: 340, height: 2400), "memo area")
    checkEqual(page.allDayBars.count, 0, "the paper has no chips")
    let band = page.allDayBand
    checkEqual(band.kind, .day, "band kind")
    checkEqual(band.days, [day(2026, 10, 7)], "band days")
    checkEqual(band.tones, [.normal], "band tones")
    checkEqual(band.paperWidth, 1000, "band paper width")
    checkEqual(band.gutter, 72, "band gutter")
    checkEqual(band.columnMinX, [72], "band column origin")
    checkEqual(band.columnWidth, 588, "band column width")
    checkEqual(band.laneCount, 1, "one all-day event")
    checkEqual(band.bars.count, 1, "one bar")
    checkEqual(band.bars[0].title, "締切", "bar title")
    checkEqual(band.bars[0].eventId, demoId("締切"), "bar event id")
    checkEqual(band.bars[0].lane, 0, "bar lane")
    checkEqual(band.bars[0].startCol, 0, "bar start column")
    checkEqual(band.bars[0].endCol, 0, "bar end column")
    checkEqual(band.bars[0].minX, 76, "bar minX = 72 + 4")
    checkEqual(band.bars[0].maxX, 648, "bar maxX = 660 − 12")
    checkEqual(band.bars[0].continuesLeft, false, "bar starts today")
    checkEqual(band.bars[0].continuesRight, false, "bar ends today")
    checkEqual(band.todayColumn, 0, "band today column")
    checkEqual(page.dateLabels.count, 1, "one label")
    checkEqual(page.dateLabels[0].frame, CGRect(x: 72, y: 0, width: 588, height: 0), "label without height")
    checkEqual(page.dateLabels[0].isToday, true, "label today")
    checkEqual(page.dateLabels[0].tone, .normal, "label tone")
    checkEqual(page.dateLabels[0].holidayName, nil, "no holiday on 10/7")
    checkEqual(page.nowLine, NowLine(y: 1000, x0: 72, x1: 660, minute: 600), "now line across the timeline (y 1000)")
    checkEqual(page.minutesToY(600), 1000, "minutesToY(600) = 1000")
    checkEqual(page.minutesToY(1440), 2400, "minutesToY(1440) = 2400")

    let boxes = Dictionary(uniqueKeysWithValues: page.timedBoxes.map { ($0.eventId, $0) })
    checkEqual(page.timedBoxes.count, 3, "3 timed boxes on the 7th")
    let w2 = (570.0 - 3) / 2
    checkRect(boxes[demoId("打合せ")]?.frame, CGRect(x: 76, y: 1001, width: w2, height: 148), "打合せ: column 0 of 2 (y from 0:00)")
    checkRect(boxes[demoId("電話")]?.frame, CGRect(x: 76 + w2 + 3, y: 1051, width: w2, height: 48), "電話: column 1 of 2")
    checkRect(boxes[demoId("歯科")]?.frame, CGRect(x: 76, y: 1401, width: 570, height: 98), "歯科: alone")
    checkEqual(boxes[demoId("電話")]?.columns, 2, "2 columns")
    checkEqual(boxes[demoId("電話")]?.column, 1, "電話 is column 1")
    checkEqual(boxes[demoId("電話")]?.timeText, "10:30〜11:00", "time text")
    checkEqual(boxes[demoId("歯科")]?.startMinute, 840, "歯科 starts at 14:00")
    checkEqual(boxes[demoId("歯科")]?.endMinute, 900, "歯科 ends at 15:00")
    checkEqual(page.timedBoxes.filter(\.isPast).count, 0, "nothing is past at 10:00")
    checkEqual(dayLayout(demo, now: october(7, 16)).timedBoxes.filter(\.isPast).count, 3, "everything is past at 16:00")
    let long = dayLayout([timed("long", 6, 20, 0, 9, 0, endDay: 8, title: "長い")])
    checkEqual(long.timedBoxes.count, 1, "a long timed event is one box")
    checkRect(long.timedBoxes[0].frame, CGRect(x: 76, y: 1, width: 570, height: 2398), "the box fills the day")
    checkEqual(long.allDayBand.laneCount, 0, "a timed event is not in the band")

    checkEqual(page.hit(at: CGPoint(x: 100, y: 1010)), .timedBox(demoId("打合せ")), "hit a box")
    checkEqual(page.hit(at: CGPoint(x: 400, y: 1060)), .timedBox(demoId("電話")), "hit the second column")
    checkEqual(page.hit(at: CGPoint(x: 100, y: 10)), nil, "the top of the paper is 0:00, not a chip")
    checkEqual(page.hit(at: CGPoint(x: 800, y: 10)), nil, "the memo area's top hits nothing")
    checkEqual(page.hit(at: CGPoint(x: 800, y: 1000)), nil, "memo area hits nothing")
    checkEqual(page.hit(at: CGPoint(x: 30, y: 1000)), nil, "the gutter hits nothing")
    checkEqual(page.cell(at: CGPoint(x: 900, y: 30)), .grid, "the memo area's top is the grid")
    checkEqual(page.cell(at: CGPoint(x: 30, y: 30)), .grid, "the gutter's top is the grid")
    checkEqual(page.cell(at: CGPoint(x: 900, y: 1000)), .grid, "grid cell (memo area)")
    checkEqual(page.cell(at: CGPoint(x: 1000, y: 0)), .grid, "the top-right corner belongs to the grid")
    checkEqual(page.cell(at: CGPoint(x: 1001, y: 60)), nil, "right of the paper")
    checkEqual(page.cell(at: CGPoint(x: 100, y: 2400)), nil, "below the paper")
    checkEqual(page.cell(at: CGPoint(x: -1, y: 100)), nil, "left of the paper")
    checkEqual(page.cell(at: CGPoint(x: 100, y: -0.1)), nil, "above the paper")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 900, y: 30)), .grid, "ink at the top → grid")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 900, y: 1000)), .grid, "ink in the memo area → grid")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 30, y: 1000)), .grid, "ink in the gutter → grid")
    checkEqual(page.inkCell(forCenter: CGPoint(x: -10, y: -10)), .grid, "ink above the paper → grid (negative y)")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 2000, y: 9000)), .grid, "ink below the paper → grid")
    checkEqual(page.inkCell(forCenter: CGPoint(x: 500, y: CGFloat.nan)), .grid, "NaN → grid")
    checkEqual(page.growsWithInk(.allDayDay), false, "the former band cell does not grow")
    checkEqual(page.growsWithInk(.grid), false, "the grid never grows")
    checkEqual(page.growsWithInk(.memo), false, "memo is not a day cell")
    checkEqual(page.band(atY: 30), PageBand(raw: "grid"), "band grid at the top")
    checkEqual(page.band(atY: 2399), PageBand(raw: "grid"), "band grid at the bottom")
    checkEqual(page.band(atY: 2400), nil, "band below")
    checkEqual(page.band(atY: -1), nil, "band above")
    checkEqual(page.bandTop(PageBand(raw: "grid")), 0, "bandTop grid is 0")
    checkEqual(page.bandTop(PageBand(raw: "allday")), nil, "bandTop allday: the paper has no band")
    checkEqual(page.bandTop(PageBand(raw: "memo")), nil, "bandTop memo")

    let busy = dayLayout(demo + [allDay("a", 7, 8, title: "a"), allDay("b", 1, 20, title: "b")])
    checkEqual(busy.allDayBand.laneCount, 3, "3 all-day events → 3 lanes")
    checkEqual(busy.allDayBand.bars.map(\.title), ["b", "a", "締切"], "earlier start first (b since 10/1), then title")
    checkEqual(busy.allDayBand.bars.map(\.lane), [0, 1, 2], "lane = display order")
    checkEqual(busy.allDayBand.bars[0].continuesLeft, true, "b started before the day")
    checkEqual(busy.allDayBand.bars[0].continuesRight, true, "b continues after the day")
    checkEqual(busy.allDayBand.bars.map(\.minX), [76, 76, 76], "every bar spans the timeline column")
    checkEqual(busy.cells[.grid]?.minY, 0, "the grid stays at the top")
    checkEqual(busy.size.height, 2400, "the paper does not grow with the band")
    checkEqual(busy.nowLine?.y, 1000, "the now line stays")
    checkEqual(PageScroll.scrollDelta(old: page, new: busy, topVisibleY: 500), 0, "scrollDelta is always 0")
    checkEqual(PageScroll.scrollDelta(old: page, new: busy, topVisibleY: 30), 0, "scrollDelta at the top")
    checkEqual(page.sameGeometry(as: busy), true, "the band does not change the geometry")
    checkEqual(page.sameGeometry(as: dayLayout(demo, now: october(7, 15))), true, "only `now` changed")
    checkEqual(page.sameGeometry(as: dayLayout(demo, focus: day(2026, 10, 8))), false, "another day")

    let inked = dayLayout(demo, ink: [.allDayDay: 200, .grid: 9000])
    checkEqual(inked.size.height, 2400, "ink does not grow the paper")
    checkEqual(inked.timeline.minY, 0, "the timeline stays at the top")
    checkEqual(inked.memo.minY, 0, "the memo area stays at the top")
    checkEqual(inked, page, "ink bottoms are not read")
    let tomorrow = dayLayout(demo, focus: day(2026, 10, 8))
    checkEqual(tomorrow.isToday, false, "not today")
    checkEqual(tomorrow.nowLine, nil, "no now line")
    checkEqual(tomorrow.allDayBand.laneCount, 0, "no all-day event on the 8th")
    checkEqual(tomorrow.allDayBand.bars.count, 0, "no bar on the 8th")
    checkEqual(tomorrow.allDayBand.todayColumn, nil, "not today in the band")
    checkEqual(tomorrow.timedBoxes.map(\.title), ["資料提出"], "the 8th's timed event")
    checkEqual(tomorrow.size.height, 2400, "the 8th's paper")
    checkEqual(PageNavigation.initialScrollY(page, now: demoNow, calendar: tokyo), 900, "today at 10:00 → 9:00 (100 lu per hour)")
    checkEqual(PageNavigation.initialScrollY(tomorrow, now: demoNow, calendar: tokyo), 700, "not today → 7:00")
    checkEqual(PageNavigation.initialScrollY(page, now: october(7, 0, 10), calendar: tokyo), 0, "clamped to 0:00")
    checkEqual(PageNavigation.initialScrollY(busy, now: demoNow, calendar: tokyo), 900, "the band does not move the start")
    let holiday = dayLayout([], focus: day(2026, 10, 12))
    checkEqual(holiday.dateLabels[0].holidayName, "スポーツの日", "holiday name")
    checkEqual(holiday.dateLabels[0].tone, .sundayOrHoliday, "holiday tone")
    checkEqual(holiday.allDayBand.tones, [.sundayOrHoliday], "holiday tone in the band")
    checkEqual(dayLayout([], focus: day(2026, 10, 10)).allDayBand.tones, [.saturday], "Saturday tone in the band")
    let trip = dayLayout(demo, focus: day(2026, 10, 11))
    checkEqual(trip.allDayBand.bars.map(\.title), ["家族旅行"], "the trip on Sunday")
    checkEqual(trip.allDayBand.bars[0].continuesLeft, true, "the trip started before")
    checkEqual(trip.allDayBand.bars[0].continuesRight, true, "the trip continues after")
    checkEqual(trip.allDayBand.tones, [.sundayOrHoliday], "Sunday tone in the band")
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

// MARK: - M3b: rect → event range, event range → rect (M3B_CONTRACT §1 / §6.1; expectations from
// the web tests/page-geometry.test.mjs, shifted by the band height where a page has one)

section("event geometry (M3b)")

/// "2026-10-04 09:00–2026-10-04 10:30" (+ " allDay") in the fixed calendar, for readable failures.
let rangeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.calendar = tokyo
    f.timeZone = tokyo.timeZone
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f
}()

func fmt(_ r: EventRange?) -> String {
    guard let r = r else { return "nil" }
    return "\(rangeFormatter.string(from: r.start))–\(rangeFormatter.string(from: r.end))" + (r.allDay ? " allDay" : "")
}

/// The day the range starts on ("2026-10-04"), or "nil".
func ymd(_ r: EventRange?) -> String {
    r.map { DayKey($0.start, calendar: tokyo).description } ?? "nil"
}

/// A rect from two corners; a reversed drag gives a negative size (the engines normalize it).
func rect(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
    CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
}

do {
    let d4 = day(2026, 10, 4)
    let allDay4 = EventRange.allDay(d4, calendar: tokyo)
    checkEqual(fmt(allDay4), "2026-10-04 00:00–2026-10-05 00:00 allDay", "EventRange.allDay")
    checkEqual(allDay4.isValid, true, "allDay is valid")
    let t = EventRange.timed(d4, startMinute: 540, endMinute: 630, calendar: tokyo)
    checkEqual(fmt(t), "2026-10-04 09:00–2026-10-04 10:30", "EventRange.timed(540, 630)")
    checkEqual(t.start, date(2026, 10, 4, 9), "timed start is the wall-clock time")
    checkEqual(t.allDay, false, "timed is not all-day")
    checkEqual(fmt(EventRange.timed(d4, startMinute: 1380, endMinute: 1440, calendar: tokyo)), "2026-10-04 23:00–2026-10-05 00:00", "endMinute 1440 is the next midnight")
    checkEqual(fmt(EventRange.timed(d4, startMinute: 0, endMinute: 60, calendar: tokyo)), "2026-10-04 00:00–2026-10-04 01:00", "startMinute 0")
    checkEqual(EventRange.timed(d4, startMinute: 600, endMinute: 600, calendar: tokyo).isValid, false, "zero length is invalid")
    checkEqual(EventRange(start: date(2026, 10, 4, 10), end: date(2026, 10, 4, 9), allDay: false).isValid, false, "end before start is invalid")
}

do {
    checkEqual(EventGeometry.tapMaxHeight, 12, "tapMaxHeight")
    checkEqual(EventGeometry.minDragMinutes, 30, "minDragMinutes")
    checkEqual(EventGeometry.defaultDurationMinutes, 60, "defaultDurationMinutes")
    checkEqual(EventGeometry.dayMinutes, 1440, "dayMinutes")
    checkEqual(EventGeometry.roundMinutes(547.5, step: 15), 555, "roundMinutes 547.5 → 555 (0.5 rounds up)")
    checkEqual(EventGeometry.roundMinutes(552.49, step: 15), 555, "roundMinutes 552.49 → 555")
    checkEqual(EventGeometry.roundMinutes(547.49, step: 15), 540, "roundMinutes 547.49 → 540")
    checkEqual(EventGeometry.roundMinutes(540.0000001, step: 15), 540, "roundMinutes 540.0000001 → 540")
    checkEqual(EventGeometry.roundMinutes(540.000000001, step: 15, .ceil), 540, "roundMinutes: within 1e-9 of a multiple counts as that multiple (ceil)")
    checkEqual(EventGeometry.roundMinutes(539.999999999, step: 15, .floor), 540, "roundMinutes: within 1e-9 of a multiple counts as that multiple (floor)")
    checkEqual(EventGeometry.roundMinutes(547, step: 30, .floor), 540, "roundMinutes floor")
    checkEqual(EventGeometry.roundMinutes(541, step: 30, .ceil), 570, "roundMinutes ceil")
    checkEqual(EventGeometry.roundMinutes(0, step: 15), 0, "roundMinutes 0")
    checkEqual(EventGeometry.roundMinutes(1440, step: 15), 1440, "roundMinutes 1440")
    checkEqual(EventGeometry.roundMinutes(7.5, step: 15), 15, "roundMinutes 7.5 → 15")
    checkEqual(EventGeometry.roundMinutes(7.49, step: 15), 0, "roundMinutes 7.49 → 0")
    checkEqual(EventGeometry.minutes(forY: 150, hourHeight: 100), 90, "minutes(forY:) day")
    checkEqual(EventGeometry.minutes(forY: 80, hourHeight: 80), 60, "minutes(forY:) week")
    checkEqual(EventGeometry.minutes(forY: -5, hourHeight: 100), 0, "minutes(forY:) clamped at 0")
    checkEqual(EventGeometry.minutes(forY: 3000, hourHeight: 100), 1440, "minutes(forY:) clamped at 1440")
    checkEqual(EventGeometry.minutes(forY: CGFloat.nan, hourHeight: 100), 0, "minutes(forY:) NaN → 0")
    checkEqual(EventGeometry.normalized(rect(300, 1050, 100, 900)), CGRect(x: 100, y: 900, width: 200, height: 150), "normalized: a reversed drag")
    checkEqual(EventGeometry.normalized(rect(100, 900, 300, 1050)), CGRect(x: 100, y: 900, width: 200, height: 150), "normalized: unchanged")
    checkEqual(EventGeometry.normalized(CGRect(x: 0, y: CGFloat.nan, width: 10, height: 10)), nil, "normalized: NaN → nil")
    checkEqual(EventGeometry.normalized(CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 10)), nil, "normalized: infinite → nil")

    func slot(_ y0: CGFloat, _ y1: CGFloat) -> [Int] {
        let s = EventGeometry.timelineSlot(minY: y0, maxY: y1, hourHeight: 100)
        return [s.startMinute, s.endMinute]
    }
    checkEqual(slot(900, 1050), [540, 630], "slot 9:00–10:30")
    checkEqual(slot(910, 1060), [540, 630], "slot: nearest 15 (down)")
    checkEqual(slot(915, 1065), [555, 645], "slot: nearest 15 (up)")
    checkEqual(slot(900, 950), [540, 570], "slot: exactly 30 min stays")
    checkEqual(slot(905, 925), [540, 600], "slot: shorter than 30 min → 1 hour")
    checkEqual(slot(1050, 900), [540, 630], "slot: minY/maxY in either order")
    checkEqual(slot(1398, 1504), [840, 900], "slot: slightly past the hour lines → the lines")
    checkEqual(slot(1403, 1495), [840, 900], "slot: slightly short of the hour lines → the lines")
    checkEqual(slot(1400, 1513), [840, 915], "slot: past 7.5 min the next line wins")
    checkEqual(slot(1275, 1275), [750, 810], "slot: tap → the half hour under the point")
    checkEqual(slot(1270, 1281.9), [750, 810], "slot: height 11.9 is a tap")
    checkEqual(slot(1270, 1282), [765, 825], "slot: height 12 is a drag")
    checkEqual(slot(2300, 2500), [1380, 1440], "slot: end clamped at 24:00")
    checkEqual(slot(2390, 2390), [1410, 1440], "slot: tap at 23:54")
    checkEqual(slot(2380, 2400), [1425, 1440], "slot: short drag at the bottom: +1h then clamp")
    checkEqual(slot(2400, 2400), [1380, 1440], "slot: tap exactly at 24:00 never yields 0 min")
    checkEqual(slot(2500, 2600), [1380, 1440], "slot: rect entirely below the page")
    checkEqual(slot(-100, -50), [0, 60], "slot: above the page clamps to 0:00")
    let w = EventGeometry.timelineSlot(minY: 1117, maxY: 1206, hourHeight: 80)
    checkEqual([w.startMinute, w.endMinute], [840, 900], "slot (week, hourHeight 80): 13:57.75 → 15:04.5 is 14:00–15:00")
}

// MARK: Day page

section("rect → event range: day page")
do {
    let page = dayLayout([], focus: day(2026, 10, 4))
    let g = page.grid.minY
    checkEqual(g, 0, "the band is not on the paper (M4b): the grid starts at 0 and the web expectations apply unshifted")
    func ev(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> String {
        fmt(page.eventRange(for: rect(x0, y0 + g, x1, y1 + g), now: demoNow, calendar: tokyo))
    }
    checkEqual(ev(100, 900, 300, 1050), "2026-10-04 09:00–2026-10-04 10:30", "day: 9:00–10:30")
    checkEqual(ev(100, 910, 300, 1060), "2026-10-04 09:00–2026-10-04 10:30", "day: nearest 15 (down)")
    checkEqual(ev(100, 915, 300, 1065), "2026-10-04 09:15–2026-10-04 10:45", "day: nearest 15 (up)")
    checkEqual(ev(100, 900, 300, 950), "2026-10-04 09:00–2026-10-04 09:30", "day: exactly 30 min stays")
    checkEqual(ev(100, 905, 300, 925), "2026-10-04 09:00–2026-10-04 10:00", "day: shorter than 30 min → 1 hour")
    checkEqual(ev(300, 1050, 100, 900), "2026-10-04 09:00–2026-10-04 10:30", "day: a reversed drag is normalized")
    checkEqual(ev(100, 1398, 300, 1504), "2026-10-04 14:00–2026-10-04 15:00", "day: slightly past the hour lines")
    checkEqual(ev(100, 1403, 300, 1495), "2026-10-04 14:00–2026-10-04 15:00", "day: slightly short of the hour lines")
    checkEqual(ev(100, 1400, 300, 1513), "2026-10-04 14:00–2026-10-04 15:15", "day: past 7.5 min the next line wins")
    checkEqual(ev(700, 900, 950, 1050), "2026-10-04 09:00–2026-10-04 10:30", "day: the memo area still means the day")
    checkEqual(ev(0, 900, 40, 1050), "2026-10-04 09:00–2026-10-04 10:30", "day: the time gutter still means the day")
    checkEqual(ev(200, 1275, 200, 1275), "2026-10-04 12:30–2026-10-04 13:30", "day: tap → the half hour under the point")
    checkEqual(ev(200, 1270, 205, 1281.9), "2026-10-04 12:30–2026-10-04 13:30", "day: height 11.9 is a tap")
    checkEqual(ev(200, 1270, 205, 1282), "2026-10-04 12:45–2026-10-04 13:45", "day: height 12 is a drag")
    checkEqual(ev(200, 2300, 300, 2500), "2026-10-04 23:00–2026-10-05 00:00", "day: end clamped to 24:00")
    checkEqual(ev(200, 2390, 200, 2390), "2026-10-04 23:30–2026-10-05 00:00", "day: tap at 23:54")
    checkEqual(ev(200, 2380, 300, 2400), "2026-10-04 23:45–2026-10-05 00:00", "day: short drag at the bottom")
    checkEqual(ev(200, 2400, 200, 2400), "2026-10-04 23:00–2026-10-05 00:00", "day: tap exactly at 24:00")
    checkEqual(ev(200, 2500, 300, 2600), "2026-10-04 23:00–2026-10-05 00:00", "day: rect entirely below the page")
    checkEqual(ev(200, -100, 300, -50), "2026-10-04 00:00–2026-10-04 01:00", "day: above the page clamps to 0:00")
    checkEqual(fmt(page.eventRange(for: rect(200, 0, 300, 20), now: demoNow, calendar: tokyo)), "2026-10-04 00:00–2026-10-04 01:00", "day: the paper's top is 0:00 (no band above the grid): a 20 lu drag there is 0:00–0:12 → one hour")
    checkEqual(page.eventRange(for: CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1), now: demoNow, calendar: tokyo), nil, "day: a NaN rect → nil")
    checkEqual(page.eventRange(for: CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 1), now: demoNow, calendar: tokyo), nil, "day: an infinite rect → nil")
    if let dev = page.eventRange(for: rect(100, 900 + g, 300, 1050 + g), now: demoNow) {
        checkEqual(DayKey(dev.start, calendar: DayKey.deviceCalendar), day(2026, 10, 4), "day: the device-calendar overload keeps the day")
        checkEqual(TimedEventEngine.minutesOfDay(dev.start, calendar: DayKey.deviceCalendar), 540, "day: the device-calendar overload: 9:00 device time")
        checkEqual(TimedEventEngine.minutesOfDay(dev.end, calendar: DayKey.deviceCalendar), 630, "day: the device-calendar overload: 10:30 device time")
        checkEqual(page.snapRect(for: dev) != nil, true, "day: the device-calendar snapRect overload")
    } else {
        check(false, "day: the device-calendar overload returned nil")
    }

    let nine = EventRange.timed(day(2026, 10, 4), startMinute: 540, endMinute: 630, calendar: tokyo)
    checkRect(page.snapRect(for: nine, calendar: tokyo), CGRect(x: 72, y: g + 900, width: 588, height: 150), "day snapRect 9:00–10:30 = the timeline column")
    checkRect(page.previewRect(for: rect(700, 910 + g, 950, 1060 + g), now: demoNow, calendar: tokyo), CGRect(x: 72, y: g + 900, width: 588, height: 150), "day previewRect: a memo-area drag → the timeline column")
    checkEqual(page.snapRect(for: .allDay(day(2026, 10, 4), calendar: tokyo), calendar: tokyo), nil, "day snapRect all-day → nil (the band is not on the paper)")
    checkEqual(page.snapRect(for: .allDay(day(2026, 10, 5), calendar: tokyo), calendar: tokyo), nil, "day snapRect: another day → nil")
    checkEqual(page.snapRect(for: .timed(day(2026, 10, 5), startMinute: 540, endMinute: 600, calendar: tokyo), calendar: tokyo), nil, "day snapRect: timed on another day → nil")
    checkEqual(page.snapRect(for: EventRange(start: date(2026, 10, 3, 22), end: date(2026, 10, 4, 2), allDay: false), calendar: tokyo), nil, "day snapRect: starts the day before → nil")
    checkRect(page.snapRect(for: EventRange(start: date(2026, 10, 4, 23), end: date(2026, 10, 5, 2), allDay: false), calendar: tokyo), CGRect(x: 72, y: g + 2300, width: 588, height: 100), "day snapRect: ends the next day → clipped to 24:00")
    checkRect(page.snapRect(for: EventRange(start: date(2026, 10, 4, 23), end: date(2026, 10, 5, 0), allDay: false), calendar: tokyo), CGRect(x: 72, y: g + 2300, width: 588, height: 100), "day snapRect: ends exactly at midnight")
    checkEqual(page.snapRect(for: EventRange(start: date(2026, 10, 4, 10), end: date(2026, 10, 4, 10), allDay: false), calendar: tokyo), nil, "day snapRect: zero length → nil")
    checkEqual(page.snapRect(for: EventRange(start: date(2026, 10, 4, 10), end: date(2026, 10, 4, 9), allDay: false), calendar: tokyo), nil, "day snapRect: inverted → nil")
    checkRect(page.snapRect(for: EventRange(start: date(2026, 10, 4, 10, 5), end: date(2026, 10, 4, 10, 35), allDay: false), calendar: tokyo), CGRect(x: 72, y: g + 1000 + 500 / 60, width: 588, height: 50), "day snapRect: minutes that are not on the 15 grid are drawn where they are")
    // All-day events go to the fixed band: the grid stays at the paper's top and the rects do not move.
    let busy = dayLayout([allDay("a", 4, 5), allDay("b", 4, 5), allDay("c", 4, 5), allDay("d", 4, 5)], focus: day(2026, 10, 4))
    checkEqual(busy.grid.minY, 0, "a busy band does not move the grid")
    checkEqual(busy.allDayBand.laneCount, 4, "the 4 all-day events are in the fixed band")
    checkEqual(fmt(busy.eventRange(for: rect(100, 900 + busy.grid.minY, 300, 1050 + busy.grid.minY), now: demoNow, calendar: tokyo)), "2026-10-04 09:00–2026-10-04 10:30", "day: y is relative to the grid's top")
    checkRect(busy.snapRect(for: nine, calendar: tokyo), CGRect(x: 72, y: 900, width: 588, height: 150), "day snapRect 9:00–10:30 is at y 900 whatever the band holds")
}

// MARK: Week page

section("rect → event range: week page")
do {
    let page = weekLayout([]) // Mon 10/5 – Sun 10/11 2026
    let g = page.grid.minY
    checkEqual(g, 0, "the band is not on the paper (M4b): the grid starts at 0")
    func center(_ i: Int) -> CGFloat { PaperSpec.weekGutter + (CGFloat(i) + 0.5) * colW }
    func ev(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> String {
        fmt(page.eventRange(for: rect(x0, y0 + g, x1, y1 + g), now: demoNow, calendar: tokyo))
    }
    func at(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> String {
        ymd(page.eventRange(for: rect(x0, y0 + g, x1, y1 + g), now: demoNow, calendar: tokyo))
    }
    checkEqual(ev(700, 720, 760, 840), "2026-10-08 09:00–2026-10-08 10:30", "week: x 700 is column 3 (Thursday)")
    checkEqual(ev(center(3), 1117, center(3), 1206), "2026-10-08 14:00–2026-10-08 15:00", "week: slightly past the hour lines")
    checkRect(page.previewRect(for: rect(center(3), 1117 + g, center(3), 1206 + g), now: demoNow, calendar: tokyo), CGRect(x: page.columnFrame(3).minX, y: g + 1120, width: colW, height: 80), "week previewRect 14:00–15:00")
    checkRect(page.snapRect(for: .timed(day(2026, 10, 8), startMinute: 840, endMinute: 900, calendar: tokyo), calendar: tokyo), CGRect(x: page.columnFrame(3).minX, y: g + 1120, width: colW, height: 80), "week snapRect 14:00–15:00")
    checkEqual(ev(center(2), 1000, center(2), 1000), "2026-10-07 12:30–2026-10-07 13:30", "week: tap at 12:30")
    checkEqual(at(0, 720, 60, 840), "2026-10-05", "week: the gutter → Monday (column 0)")
    checkEqual(at(1450, 720, 1500, 840), "2026-10-11", "week: right of the paper → Sunday (column 6)")
    checkEqual(at(1300, 720, 1390, 840), "2026-10-11", "week: column 6 is Sunday")
    checkEqual(at(-100, 720, -50, 840), "2026-10-05", "week: left of the paper → Monday")
    checkEqual(ev(700, 1800, 760, 2000), "2026-10-08 22:30–2026-10-09 00:00", "week: end clamped at 24:00")
    checkEqual(ev(700, -100, 760, -50), "2026-10-08 00:00–2026-10-08 01:00", "week: above the grid clamps to 0:00")
    checkEqual(fmt(page.eventRange(for: rect(700, 0, 760, 30), now: demoNow, calendar: tokyo)), "2026-10-08 00:00–2026-10-08 00:30", "week: the paper's top is 0:00 (no band above the grid): a 30 lu drag there is 0:00–0:30")
    for i in 0..<7 {
        checkEqual(at(center(i) - 20, 720, center(i) + 20, 840), page.days[i].description, "week: column \(i)")
    }
    let c1 = page.columnFrame(1)
    checkEqual(at(c1.minX - 10, 720, c1.minX + 30, 840), "2026-10-06", "week: a rect over two columns → the column under its centre (right)")
    checkEqual(at(c1.minX - 30, 720, c1.minX + 10, 840), "2026-10-05", "week: … (left)")
    checkEqual(page.nearestColumn(atX: 0), 0, "nearestColumn 0")
    checkEqual(page.nearestColumn(atX: 63.9), 0, "nearestColumn in the gutter")
    checkEqual(page.nearestColumn(atX: 64), 0, "nearestColumn 64")
    checkEqual(page.nearestColumn(atX: 64 + colW), 1, "nearestColumn: the left edge of column 1")
    checkEqual(page.nearestColumn(atX: 64 + colW - 0.001), 0, "nearestColumn: just left of it")
    checkEqual(page.nearestColumn(atX: 1400), 6, "nearestColumn 1400")
    checkEqual(page.nearestColumn(atX: 5000), 6, "nearestColumn far right")
    checkEqual(page.nearestColumn(atX: -100), 0, "nearestColumn far left")
    checkEqual(page.nearestColumn(atX: CGFloat.nan), 0, "nearestColumn NaN → 0")
    checkRect(page.previewRect(for: rect(700, 725 + g, 760, 845 + g), now: demoNow, calendar: tokyo), CGRect(x: page.columnFrame(3).minX, y: g + 720, width: colW, height: 120), "week previewRect: 9:03.75 → 9:00, 10:33.75 → 10:30")
    checkRect(page.previewRect(for: rect(10, 1900 + g, 20, 1900 + g), now: demoNow, calendar: tokyo), CGRect(x: 64, y: g + 1880, width: colW, height: 40), "week previewRect: gutter tap at 23:45 → column 0, 23:30–24:00")
    checkEqual(page.snapRect(for: .allDay(day(2026, 10, 7), calendar: tokyo), calendar: tokyo), nil, "week snapRect all-day → nil (the band is not on the paper)")
    checkEqual(page.snapRect(for: .allDay(day(2026, 10, 12), calendar: tokyo), calendar: tokyo), nil, "week snapRect: next week → nil")
    checkEqual(page.snapRect(for: .allDay(day(2026, 10, 4), calendar: tokyo), calendar: tokyo), nil, "week snapRect: the Sunday before → nil")
    checkEqual(page.snapRect(for: .timed(day(2026, 10, 12), startMinute: 540, endMinute: 600, calendar: tokyo), calendar: tokyo), nil, "week snapRect: timed next week → nil")
    checkRect(page.snapRect(for: EventRange(start: date(2026, 10, 11, 23), end: date(2026, 10, 12, 2), allDay: false), calendar: tokyo), CGRect(x: page.columnFrame(6).minX, y: g + 1840, width: colW, height: 80), "week snapRect: ends after Sunday → clipped to 24:00")
    checkEqual(page.snapRect(for: EventRange(start: date(2026, 10, 7, 10), end: date(2026, 10, 7, 10), allDay: false), calendar: tokyo), nil, "week snapRect: zero length → nil")
    checkEqual(page.snapRect(for: EventRange(start: date(2026, 10, 4, 23), end: date(2026, 10, 5, 2), allDay: false), calendar: tokyo), nil, "week snapRect: starts before the week → nil")
}

// MARK: Month page

section("rect → event range: month page")
do {
    let page = layout([]) // October 2026, Monday start: grid 9/28 – 11/8, rows of 175, memo from 1050
    checkEqual(page.memo.minY, 1050, "memo starts at 1050")
    checkEqual(page.size.height, 1750, "page height 1750")
    let now14 = date(2026, 10, 14, 22, 30)
    func ev(_ r: CGRect, now: Date = now14) -> String { fmt(page.eventRange(for: r, now: now, calendar: tokyo)) }
    func at(_ r: CGRect, now: Date = now14) -> String { ymd(page.eventRange(for: r, now: now, calendar: tokyo)) }
    checkEqual(ev(rect(850, 20, 950, 140)), "2026-10-02 00:00–2026-10-03 00:00 allDay", "month: row 0 col 4 = 10/02, all-day")
    checkEqual(at(rect(410, 360, 490, 380)), "2026-10-14", "month: row 2 col 2 = 10/14")
    checkEqual(at(rect(150, 150, 250, 200)), "2026-10-06", "month: centre (200, 175) → the next cell (row 1, col 1)")
    checkEqual(at(rect(-100, -100, -50, -50)), "2026-09-28", "month: outside top-left → 9/28")
    checkEqual(at(rect(1450, 1000, 1500, 1040)), "2026-11-08", "month: outside right → row 5 col 6 = 11/08")
    checkEqual(at(rect(1250, 900, 1250, 900)), "2026-11-08", "month: a tap in row 5 col 6")
    checkEqual(at(rect(1400, 1049.9, 1400, 1049.9)), "2026-11-08", "month: the right edge belongs to the last column")
    checkEqual(at(rect(0, 0, 0, 0)), "2026-09-28", "month: a tap at the origin")
    // The memo area means today when today is in the month, else the 1st.
    let memo = rect(300, 1300, 700, 1420)
    checkEqual(ev(memo), "2026-10-14 00:00–2026-10-15 00:00 allDay", "memo: today (10/14)")
    checkRect(page.previewRect(for: memo, now: now14, calendar: tokyo), CGRect(x: 400, y: 350, width: 200, height: 175), "memo preview: 10/14 = row 2 col 2")
    checkEqual(at(memo, now: date(2026, 11, 3)), "2026-10-01", "memo: today in a neighbouring month on the grid → the 1st")
    checkEqual(at(memo, now: date(2026, 9, 29)), "2026-10-01", "memo: today in September → the 1st")
    checkEqual(at(memo, now: date(2025, 10, 14)), "2026-10-01", "memo: the same month of another year → the 1st")
    checkRect(page.previewRect(for: memo, now: date(2027, 1, 1), calendar: tokyo), CGRect(x: 600, y: 0, width: 200, height: 175), "memo preview: 10/1 = row 0 col 3")
    checkEqual(at(memo, now: date(2026, 10, 31, 23, 59)), "2026-10-31", "memo: the last day of the month")
    checkEqual(at(memo, now: date(2026, 10, 1, 0, 0)), "2026-10-01", "memo: the first instant of the month")
    checkEqual(at(rect(100, 1040, 100, 1060)), "2026-10-14", "memo: a centre exactly at memo.minY is the memo")
    checkEqual(at(rect(100, 1040, 100, 1059.8)), "2026-11-02", "memo: just above it is the last row")
    for r in [rect(50, 1100, 50, 1100), rect(1390, 1749, 1395, 1750), rect(700, 1800, 720, 1900), rect(1450, 1100, 1500, 1200), rect(-50, 2000, -40, 2001)] {
        checkEqual(at(r, now: date(2026, 10, 6)), "2026-10-06", "memo: taps, the page bottom and below the page \(r)")
    }
    // snapRect: the cell of the range's first day (a timed range too), nil off the grid.
    checkRect(page.snapRect(for: .allDay(day(2026, 10, 14), calendar: tokyo), calendar: tokyo), CGRect(x: 400, y: 350, width: 200, height: 175), "month snapRect 10/14")
    checkRect(page.snapRect(for: .timed(day(2026, 10, 14), startMinute: 540, endMinute: 600, calendar: tokyo), calendar: tokyo), CGRect(x: 400, y: 350, width: 200, height: 175), "month snapRect: a timed range → its day's cell")
    checkRect(page.snapRect(for: .allDay(day(2026, 9, 28), calendar: tokyo), calendar: tokyo), CGRect(x: 0, y: 0, width: 200, height: 175), "month snapRect 9/28 (first cell)")
    checkRect(page.snapRect(for: .allDay(day(2026, 11, 8), calendar: tokyo), calendar: tokyo), CGRect(x: 1200, y: 875, width: 200, height: 175), "month snapRect 11/8 (last cell)")
    checkEqual(page.snapRect(for: .allDay(day(2026, 11, 9), calendar: tokyo), calendar: tokyo), nil, "month snapRect: 11/9 is off the grid")
    checkEqual(page.snapRect(for: .allDay(day(2026, 9, 27), calendar: tokyo), calendar: tokyo), nil, "month snapRect: 9/27 is off the grid")
    checkRect(page.previewRect(for: rect(850, 20, 950, 140), now: now14, calendar: tokyo), CGRect(x: 800, y: 0, width: 200, height: 175), "month previewRect 10/02")
    checkRect(page.previewRect(for: rect(-50, 1000, -40, 1001), now: now14, calendar: tokyo), CGRect(x: 0, y: 875, width: 200, height: 175), "month previewRect: outside left → row 5 col 0")
    checkRect(page.previewRect(for: rect(-50, 2000, -40, 2001), now: date(2027, 3, 1), calendar: tokyo), CGRect(x: 600, y: 0, width: 200, height: 175), "month previewRect: below the page → the memo day (10/1 = row 0 col 3)")
    checkEqual(page.eventRange(for: CGRect(x: 0, y: CGFloat.nan, width: 1, height: 1), now: now14, calendar: tokyo), nil, "month: a NaN rect → nil")
    // A grown row moves the cells below it; the rects follow the layout.
    let inked = layout([], ink: [.day(day(2026, 10, 7)): 300])
    let cell14 = inked.cells[.day(day(2026, 10, 14))]!
    check(cell14.minY > 350, "ink on 10/7 moves row 2 down")
    checkEqual(ymd(inked.eventRange(for: cell14.insetBy(dx: 20, dy: 20), now: now14, calendar: tokyo)), "2026-10-14", "month: a grown row moves the cells")
    checkRect(inked.previewRect(for: cell14.insetBy(dx: 20, dy: 20), now: now14, calendar: tokyo), cell14, "month: … and the preview follows")
    checkEqual(ymd(inked.eventRange(for: rect(300, inked.memo.minY + 10, 700, inked.memo.minY + 50), now: now14, calendar: tokyo)), "2026-10-14", "month: the memo area moved too")
    // February 2026 (Monday start: grid 1/26 – 3/8): the memo day is the 1st when today is in October.
    let feb = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 2), events: [], inkBottoms: [:], now: now14, calendar: tokyo))
    checkEqual(ymd(feb.eventRange(for: memo, now: now14, calendar: tokyo)), "2026-02-01", "February page: memo → 2/1")
    checkEqual(ymd(feb.eventRange(for: memo, now: date(2026, 2, 20), calendar: tokyo)), "2026-02-20", "February page: memo → today when today is in February")
    checkEqual(ymd(feb.eventRange(for: rect(0, 0, 10, 10), now: now14, calendar: tokyo)), "2026-01-26", "February page: first cell is 1/26")
    checkRect(feb.snapRect(for: .allDay(day(2026, 2, 1), calendar: tokyo), calendar: tokyo), CGRect(x: 1200, y: 0, width: 200, height: 175), "February page: 2/1 is row 0 col 6")
}

// MARK: Year page

section("rect → event range: year page")
do {
    let y2026 = yearLayout([], year: 2026)
    let y2028 = yearLayout([], year: 2028)
    func center(_ page: YearPageLayout, _ m: Int, _ d: Int) -> CGPoint {
        let c = page.cellFrame(month: m, day: d)!
        return CGPoint(x: c.midX, y: c.midY)
    }
    func tap(_ page: YearPageLayout, _ m: Int, _ d: Int) -> String {
        let c = center(page, m, d)
        return ymd(page.eventRange(for: rect(c.x, c.y, c.x, c.y), now: demoNow, calendar: tokyo))
    }
    func at(_ page: YearPageLayout, _ r: CGRect) -> String { ymd(page.eventRange(for: r, now: demoNow, calendar: tokyo)) }
    // Every day of a common and a leap year: a drag over the cell and a tap → that day, all-day; the preview is the cell.
    for page in [y2026, y2028] {
        for m in 1...12 {
            for d in 1...DayKey.daysInMonth(year: page.year, month: m) {
                let c = center(page, m, d)
                let cell = page.cellFrame(month: m, day: d)!
                let key = DayKey(year: page.year, month: m, day: d)
                let expected = "\(key) 00:00–\(key.adding(days: 1)) 00:00 allDay"
                for r in [rect(c.x - 40, c.y - 20, c.x + 30, c.y + 25), rect(c.x, c.y, c.x, c.y)] {
                    let ev = page.eventRange(for: r, now: demoNow, calendar: tokyo)
                    checkEqual(fmt(ev), expected, "year \(page.year) \(m)/\(d) \(r)")
                    checkRect(ev.flatMap { page.snapRect(for: $0, calendar: tokyo) }, cell, "year \(page.year) \(m)/\(d) snapRect")
                }
            }
        }
    }
    // Dates that do not exist become the month's last day.
    checkEqual(tap(y2026, 2, 29), "2026-02-28", "year: 2/29 of a common year → 2/28")
    checkEqual(tap(y2026, 2, 30), "2026-02-28", "year: 2/30 → 2/28")
    checkEqual(tap(y2026, 2, 31), "2026-02-28", "year: 2/31 → 2/28")
    checkEqual(tap(y2028, 2, 29), "2028-02-29", "year: 2/29 of a leap year exists")
    checkEqual(tap(y2028, 2, 30), "2028-02-29", "year: 2/30 → 2/29 in 2028")
    checkEqual(tap(y2028, 2, 31), "2028-02-29", "year: 2/31 → 2/29 in 2028")
    checkEqual(tap(y2026, 4, 31), "2026-04-30", "year: 4/31 → 4/30")
    checkEqual(tap(y2026, 6, 31), "2026-06-30", "year: 6/31 → 6/30")
    checkEqual(tap(y2026, 9, 31), "2026-09-30", "year: 9/31 → 9/30")
    checkEqual(tap(y2026, 11, 31), "2026-11-30", "year: 11/31 → 11/30")
    let c231 = center(y2026, 2, 31)
    checkRect(y2026.previewRect(for: rect(c231.x, c231.y, c231.x, c231.y), now: demoNow, calendar: tokyo), CGRect(x: 168, y: 27 * 60, width: 112, height: 60), "year preview: 2/31 → 2/28's cell")
    let c231leap = center(y2028, 2, 31)
    checkRect(y2028.previewRect(for: rect(c231leap.x, c231leap.y, c231leap.x, c231leap.y), now: demoNow, calendar: tokyo), CGRect(x: 168, y: 28 * 60, width: 112, height: 60), "year preview: 2/31 → 2/29's cell in 2028")
    checkRect(y2026.snapRect(for: .allDay(day(2026, 2, 28), calendar: tokyo), calendar: tokyo), y2026.cellFrame(month: 2, day: 28)!, "year snapRect(2/28) = cellFrame(2, 28)")
    checkRect(y2026.snapRect(for: .timed(day(2026, 7, 7), startMinute: 540, endMinute: 600, calendar: tokyo), calendar: tokyo), y2026.cellFrame(month: 7, day: 7)!, "year snapRect: a timed range → its day's cell")
    checkEqual(y2026.snapRect(for: .allDay(day(2027, 1, 1), calendar: tokyo), calendar: tokyo), nil, "year snapRect: another year → nil")
    checkEqual(y2026.snapRect(for: .allDay(day(2025, 12, 31), calendar: tokyo), calendar: tokyo), nil, "year snapRect: the year before → nil")
    // The gutter → January; beyond the right edge → December; above / below the page → day 1 / 31 (clamped to the month).
    checkEqual(at(y2026, rect(0, 130, 40, 150)), "2026-01-03", "year: the day-number gutter → January")
    checkEqual(at(y2026, rect(-100, 130, -50, 150)), "2026-01-03", "year: left of the paper → January")
    checkEqual(at(y2026, rect(1450, 130, 1500, 150)), "2026-12-03", "year: right of the paper → December")
    checkEqual(at(y2026, rect(300, -100, 320, -50)), "2026-03-01", "year: above the paper → day 1")
    checkEqual(at(y2026, rect(300, 1900, 320, 2000)), "2026-03-31", "year: below the paper → day 31")
    checkEqual(at(y2026, rect(400, 1900, 420, 2000)), "2026-04-30", "year: below the paper in April → 4/30")
    checkEqual(at(y2026, rect(200, 5000, 200, 5000)), "2026-02-28", "year: far below in February → 2/28")
    checkEqual(at(y2026, rect(1400, 1860, 1400, 1860)), "2026-12-31", "year: the bottom-right corner → 12/31")
    checkEqual(at(y2026, rect(56 + 112 * 4 - 30, 300, 56 + 112 * 4 + 50, 380)), "2026-05-06", "year: a rect over two cells → the one under its centre")
    checkEqual(y2026.eventRange(for: CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1), now: demoNow, calendar: tokyo), nil, "year: a NaN rect → nil")
    // Rows that grew (events / ink) move the cells: the rect follows the layout.
    let inked = yearLayout([], year: 2026, ink: [.yearDay(month: 3, day: 5): 200])
    let cell = inked.cellFrame(month: 7, day: 20)!
    check(cell.minY > 19 * 60, "ink on 3/5 moves row 20 down")
    checkEqual(ymd(inked.eventRange(for: cell.insetBy(dx: 10, dy: 10), now: demoNow, calendar: tokyo)), "2026-07-20", "year: a grown row moves the cells")
    checkRect(inked.previewRect(for: cell.insetBy(dx: 10, dy: 10), now: demoNow, calendar: tokyo), cell, "year: … and the preview follows")
}

// MARK: Randomized invariant: eventRange(snapRect(eventRange(r))) == eventRange(r)

section("event range ↔ snap rect (randomized)")
do {
    var rng = Rng(seed: 20_261_004)
    let now = date(2026, 10, 14, 9) // the October page's memo area means 10/14; the other months' the 1st
    let feb = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 2), events: [], inkBottoms: [:], now: now, calendar: tokyo))
    let pages: [(String, any PageLayout)] = [
        ("day", dayLayout([], focus: day(2026, 10, 4))),
        ("week", weekLayout([])),
        ("month-2026-10", layout([])),
        ("month-2026-02", feb),
        ("year-2026", yearLayout([], year: 2026)),
        ("year-2028", yearLayout([], year: 2028)),
    ]
    for (name, page) in pages {
        let W = page.size.width
        let H = page.size.height
        for i in 0..<300 {
            // Coordinates up to 100 lu beyond the paper, 30 % tap-sized rects, some tall ones, either drag direction.
            let x0 = CGFloat(rng.double()) * (W + 200) - 100
            let y0 = CGFloat(rng.double()) * (H + 200) - 100
            let tall = rng.double() < 0.3 ? CGFloat(rng.double()) * 20 : CGFloat(rng.double()) * H * 0.4
            let r = rect(x0, y0, x0 + CGFloat(rng.double()) * 300 - 150, y0 + (rng.double() < 0.5 ? tall : -tall))
            let label = "\(name) #\(i) \(r)"
            guard let ev = page.eventRange(for: r, now: now, calendar: tokyo) else {
                check(false, "\(label): eventRange is nil")
                continue
            }
            check(ev.isValid, "\(label): valid range")
            guard let snap = page.snapRect(for: ev, calendar: tokyo) else {
                check(false, "\(label): snapRect is nil for \(fmt(ev))")
                continue
            }
            check(snap.width > 0 && snap.height > 0, "\(label): the snapped rect has an area")
            checkEqual(page.eventRange(for: snap, now: now, calendar: tokyo), ev, "\(label): idempotent (\(fmt(ev)) from \(snap))")
            let startDay = DayKey(ev.start, calendar: tokyo)
            if page.kind == .month || page.kind == .year {
                check(ev.allDay, "\(label): all-day")
                checkEqual(ev.start, startDay.startOfDay(in: tokyo), "\(label): starts at midnight")
                checkEqual(DayKey(ev.end, calendar: tokyo), startDay.adding(days: 1), "\(label): one day long")
            } else {
                check(!ev.allDay, "\(label): timed")
                let startMin = TimedEventEngine.minutesOfDay(ev.start, calendar: tokyo)
                let endMin = DayKey(ev.end, calendar: tokyo) == startDay ? TimedEventEngine.minutesOfDay(ev.end, calendar: tokyo) : 1440
                check(DayKey(ev.end, calendar: tokyo) == startDay || ev.end == startDay.adding(days: 1).startOfDay(in: tokyo), "\(label): ends on the day or at the next midnight")
                check(startMin % 15 == 0 && endMin % 15 == 0, "\(label): on the 15-minute grid (\(startMin)–\(endMin))")
                check(endMin - startMin >= 15, "\(label): at least 15 minutes (\(startMin)–\(endMin))")
                check(startMin >= 0 && endMin <= 1440, "\(label): within the day")
            }
            if let m = page as? MonthPageLayout {
                let cy = min(max(r.standardized.midY, 0), H)
                if cy >= m.memo.minY {
                    let memoDay = m.month == YearMonth(year: 2026, month: 10) ? "2026-10-14" : m.month.firstDay.description
                    checkEqual(startDay.description, memoDay, "\(label): memo day")
                }
                checkEqual(m.cells[.day(startDay)], snap, "\(label): the snapped rect is the day's cell")
            } else if let y = page as? YearPageLayout {
                checkEqual(startDay.year, y.year, "\(label): same year")
                check(startDay.isValid, "\(label): an existing date")
                checkEqual(y.cellFrame(month: startDay.month, day: startDay.day), snap, "\(label): the snapped rect is the date's cell")
            } else if let w = page as? WeekPageLayout {
                let col = w.days.firstIndex(of: startDay)
                check(col != nil, "\(label): the day is in the week")
                let startMin = TimedEventEngine.minutesOfDay(ev.start, calendar: tokyo)
                let endMin = DayKey(ev.end, calendar: tokyo) == startDay ? TimedEventEngine.minutesOfDay(ev.end, calendar: tokyo) : 1440
                checkRect(snap, CGRect(x: w.columnFrame(col ?? 0).minX, y: w.minutesToY(startMin), width: colW, height: w.minutesToY(endMin) - w.minutesToY(startMin)), "\(label): column × snapped minutes")
            } else if let d = page as? DayPageLayout {
                checkEqual(startDay, d.day, "\(label): the page's day")
                let startMin = TimedEventEngine.minutesOfDay(ev.start, calendar: tokyo)
                let endMin = DayKey(ev.end, calendar: tokyo) == startDay ? TimedEventEngine.minutesOfDay(ev.end, calendar: tokyo) : 1440
                checkRect(snap, CGRect(x: 72, y: d.minutesToY(startMin), width: 588, height: d.minutesToY(endMin) - d.minutesToY(startMin)), "\(label): timeline column × snapped minutes")
            }
        }
    }
}

// MARK: - M3b: lasso geometry (M3B_CONTRACT §2 / §6.1; expectations from the web
// tests/ink-geometry.test.mjs and tests/surface.test.mjs)

section("lasso geometry (M3b)")

/// A point list from flat [x0, y0, x1, y1, …] (the web tests' polygon format).
func pts(_ v: [CGFloat]) -> [CGPoint] {
    stride(from: 0, to: v.count - 1, by: 2).map { CGPoint(x: v[$0], y: v[$0 + 1]) }
}

do {
    checkEqual(LassoGeometry.minStep, 2, "minStep")
    checkEqual(LassoGeometry.minExtent, 4, "minExtent")
    checkEqual(LassoGeometry.simplifyEpsilon, 1, "simplifyEpsilon")
    checkEqual(LassoGeometry.maxVertices, 512, "maxVertices")
    checkEqual(LassoGeometry.snapshotPadding, 12, "snapshotPadding")
    checkEqual(LassoGeometry.snapshotMaxZoom, 4, "snapshotMaxZoom")

    let square = pts([0, 0, 10, 0, 10, 10, 0, 10])
    checkEqual(LassoGeometry.pointInPolygon(CGPoint(x: 5, y: 5), square), true, "pointInPolygon: inside the square")
    checkEqual(LassoGeometry.pointInPolygon(CGPoint(x: 15, y: 5), square), false, "pointInPolygon: right of the square")
    checkEqual(LassoGeometry.pointInPolygon(CGPoint(x: -1, y: -1), square), false, "pointInPolygon: outside top-left")
    let concave = pts([0, 0, 10, 0, 10, 10, 5, 3, 0, 10]) // a notch from the bottom
    checkEqual(LassoGeometry.pointInPolygon(CGPoint(x: 5, y: 8), concave), false, "pointInPolygon: in the notch")
    checkEqual(LassoGeometry.pointInPolygon(CGPoint(x: 5, y: 1), concave), true, "pointInPolygon: inside the concave polygon")
    var star: [CGPoint] = [] // a self-intersecting five-pointed star
    for i in 0..<5 {
        let a = CGFloat(i) * 4 * .pi / 5 - .pi / 2
        star.append(CGPoint(x: cos(a) * 10, y: sin(a) * 10))
    }
    checkEqual(LassoGeometry.pointInPolygon(CGPoint(x: 0, y: 0), star), false, "pointInPolygon: the star's centre is outside under even-odd")
    checkEqual(LassoGeometry.pointInPolygon(CGPoint(x: 0, y: -8), star), true, "pointInPolygon: a tip of the star is inside")
    checkEqual(LassoGeometry.pointInPolygon(CGPoint(x: 1, y: 1), pts([0, 0, 5, 5])), false, "pointInPolygon: 2 vertices → false")
    checkEqual(LassoGeometry.pointInPolygon(CGPoint(x: 1, y: 1), []), false, "pointInPolygon: empty → false")
    checkEqual(LassoGeometry.pointInPolygon(CGPoint(x: CGFloat.nan, y: 1), square), false, "pointInPolygon: a NaN point → false")
}

do {
    let lasso = pts([0, 0, 100, 0, 100, 100, 0, 100])
    checkEqual(LassoGeometry.strokeInLasso(points: pts([10, 10, 20, 20, 200, 200, 300, 300]), polygon: lasso), true, "strokeInLasso: 2 of 4 inside")
    checkEqual(LassoGeometry.strokeInLasso(points: pts([10, 10, 200, 20, 200, 200]), polygon: lasso), false, "strokeInLasso: 1 of 3 inside")
    checkEqual(LassoGeometry.strokeInLasso(points: pts([50, 50]), polygon: lasso), true, "strokeInLasso: one point inside")
    checkEqual(LassoGeometry.strokeInLasso(points: pts([150, 50]), polygon: lasso), false, "strokeInLasso: one point outside")
    checkEqual(LassoGeometry.strokeInLasso(points: [], polygon: lasso), false, "strokeInLasso: no points")
    checkEqual(LassoGeometry.strokeInLasso(points: pts([50, 50]), polygon: pts([0, 0, 1, 1])), false, "strokeInLasso: a degenerate lasso")
    checkEqual(LassoGeometry.strokeInLasso(points: [CGPoint(x: 50, y: 50), CGPoint(x: CGFloat.nan, y: 0), CGPoint(x: 500, y: 500)], polygon: lasso), true, "strokeInLasso: non-finite points are not counted")
    checkEqual(LassoGeometry.strokeInLasso(points: [CGPoint(x: CGFloat.nan, y: 0), CGPoint(x: 0, y: CGFloat.infinity)], polygon: lasso), false, "strokeInLasso: only non-finite points → false")
    checkEqual(LassoGeometry.strokeInLasso(points: pts([50, 50]), polygon: lasso, bounds: CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1)), true, "strokeInLasso: a non-finite bounds is ignored")
    checkEqual(LassoGeometry.strokeInLasso(points: pts([50, 50]), polygon: lasso, bounds: CGRect(x: 0, y: 0, width: 100, height: 100)), true, "strokeInLasso: with the polygon's bounds")
    checkEqual(LassoGeometry.strokeInLasso(points: pts([50, 50, 150, 50, 250, 50]), polygon: lasso, bounds: CGRect(x: 0, y: 0, width: 100, height: 100)), false, "strokeInLasso: 1 of 3 with bounds")
    // Randomized: precomputed bounds and the early exits give the same answer as counting every point.
    var rng = Rng(seed: 42)
    for k in 0..<200 {
        var poly: [CGPoint] = []
        let n = 3 + rng.int(12)
        for i in 0..<n {
            let a = 2 * CGFloat.pi * CGFloat(i) / CGFloat(n)
            let radius = 20 + CGFloat(rng.double()) * 80
            poly.append(CGPoint(x: 100 + radius * cos(a), y: 100 + radius * sin(a)))
        }
        var points: [CGPoint] = []
        let m = 1 + rng.int(20)
        for _ in 0..<m {
            let x: CGFloat = rng.double() < 0.05 ? CGFloat.nan : CGFloat(rng.double()) * 220 - 10
            points.append(CGPoint(x: x, y: CGFloat(rng.double()) * 220 - 10))
        }
        var valid = 0
        var inside = 0
        for p in points where p.x.isFinite && p.y.isFinite {
            valid += 1
            if LassoGeometry.pointInPolygon(p, poly) { inside += 1 }
        }
        let want = valid > 0 && inside * 2 >= valid
        checkEqual(LassoGeometry.strokeInLasso(points: points, polygon: poly), want, "random lasso #\(k)")
        checkEqual(LassoGeometry.strokeInLasso(points: points, polygon: poly, bounds: LassoGeometry.bounds(of: poly)), want, "random lasso #\(k) with bounds")
    }
}

do {
    checkEqual(LassoGeometry.closedPolygon(pts([0, 0, 10, 0, 10, 10])), pts([0, 0, 10, 0, 10, 10, 0, 0]), "closedPolygon closes the path")
    checkEqual(LassoGeometry.closedPolygon(pts([0, 0, 10, 0, 10, 10, 0, 0])), pts([0, 0, 10, 0, 10, 10, 0, 0]), "closedPolygon: already closed")
    checkEqual(LassoGeometry.closedPolygon(pts([0, 0, 1, 1])), nil, "closedPolygon: 2 vertices → nil")
    checkEqual(LassoGeometry.closedPolygon(pts([0, 0, 1, 1, 2, 0])), nil, "closedPolygon: smaller than 4 lu in both directions → a tap")
    checkEqual(LassoGeometry.closedPolygon(pts([0, 0, 5, 0, 5, 1])), pts([0, 0, 5, 0, 5, 1, 0, 0]), "closedPolygon: 4 lu in one direction is enough")
    checkEqual(LassoGeometry.closedPolygon([CGPoint(x: CGFloat.nan, y: 0), CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 10)]), pts([0, 0, 10, 0, 10, 10, 0, 0]), "closedPolygon: non-finite points are dropped")
    checkEqual(LassoGeometry.closedPolygon([]), nil, "closedPolygon: empty → nil")

    // A hand-drawn circle: one vertex every ~2 lu (as the lasso stores them), closed.
    let R: CGFloat = 500
    let n = Int(ceil(2 * CGFloat.pi * R / 2))
    var circle: [CGPoint] = []
    for i in 0..<n {
        let a = 2 * CGFloat.pi * CGFloat(i) / CGFloat(n)
        circle.append(CGPoint(x: 700 + R * cos(a), y: 900 + R * sin(a)))
    }
    let closed = LassoGeometry.closedPolygon(circle)!
    checkEqual(closed.count, n + 1, "closed circle has n + 1 vertices")
    let simple = LassoGeometry.simplified(closed, epsilon: 1)
    check(simple.count < 120, "simplified circle has fewer than 120 vertices (\(simple.count))")
    check(simple.count >= 8, "simplified circle has at least 8 vertices (\(simple.count))")
    checkEqual(simple.first, closed.first, "simplified: the first vertex is kept")
    checkEqual(simple.last, closed.last, "simplified: the last vertex is kept (still closed)")
    func segmentDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let vx = b.x - a.x
        let vy = b.y - a.y
        let len2 = vx * vx + vy * vy
        let t = len2 > 0 ? min(max(((p.x - a.x) * vx + (p.y - a.y) * vy) / len2, 0), 1) : 0
        return hypot(p.x - a.x - t * vx, p.y - a.y - t * vy)
    }
    var worst: CGFloat = 0
    for p in closed {
        var best = CGFloat.infinity
        for j in 1..<simple.count { best = min(best, segmentDistance(p, simple[j - 1], simple[j])) }
        worst = max(worst, best)
    }
    check(worst <= 1 + 1e-9, "simplified: every dropped vertex is within 1 lu of the outline (worst \(worst))")
    let sq = pts([0, 0, 10, 0, 10, 10, 0, 10, 0, 0])
    checkEqual(LassoGeometry.simplified(sq, epsilon: 1), sq, "simplified: a square (5 vertices) is unchanged")
    let sliver = pts([0, 0, 50, 0.2, 100, 0, 50, -0.2, 0, 0, 0.1, 0])
    checkEqual(LassoGeometry.simplified(sliver, epsilon: 1), sliver, "simplified: would collapse below 3 vertices → unchanged")
    checkEqual(LassoGeometry.simplified([], epsilon: 1), [], "simplified: empty")
    checkEqual(LassoGeometry.simplified(closed, epsilon: 0), closed, "simplified: ε 0 → unchanged")
    checkEqual(LassoGeometry.simplified(closed, epsilon: CGFloat.nan), closed, "simplified: ε NaN → unchanged")
    check(LassoGeometry.simplified(closed, epsilon: 4).count < simple.count, "simplified: a larger ε drops more vertices (\(LassoGeometry.simplified(closed, epsilon: 4).count) < \(simple.count))")
    checkEqual(LassoGeometry.lassoPolygon(circle), simple, "lassoPolygon = closedPolygon → simplified(ε 1)")
    checkEqual(LassoGeometry.lassoPolygon(pts([0, 0, 1, 1, 2, 0])), nil, "lassoPolygon: a tap → nil")
    checkEqual(LassoGeometry.lassoPolygon(pts([0, 0, 10, 0, 10, 10])), pts([0, 0, 10, 0, 10, 10, 0, 0]), "lassoPolygon: a triangle")
    // A very wiggly lasso (4000 vertices jittering ±1.5 lu) is simplified more coarsely (ε 2, 4, 8) until it has ≤ 512 vertices.
    var wiggly: [CGPoint] = []
    for i in 0..<4000 {
        let a = 2 * CGFloat.pi * CGFloat(i) / 4000
        let radius: CGFloat = i % 2 == 0 ? 601.5 : 598.5
        wiggly.append(CGPoint(x: 700 + radius * cos(a), y: 900 + radius * sin(a)))
    }
    let wigglyClosed = LassoGeometry.closedPolygon(wiggly)!
    check(LassoGeometry.simplified(wigglyClosed, epsilon: 1).count > 512, "ε 1 keeps the jitter (\(LassoGeometry.simplified(wigglyClosed, epsilon: 1).count) vertices)")
    let coarse = LassoGeometry.lassoPolygon(wiggly)!
    check(coarse.count <= 512, "lassoPolygon: ≤ 512 vertices (\(coarse.count))")
    checkEqual(coarse.first, coarse.last, "lassoPolygon: still closed")
    var expectedCoarse = LassoGeometry.simplified(wigglyClosed, epsilon: 1)
    var eps: CGFloat = 2
    while expectedCoarse.count > LassoGeometry.maxVertices && eps <= 8 {
        expectedCoarse = LassoGeometry.simplified(wigglyClosed, epsilon: eps)
        eps *= 2
    }
    check(eps > 2, "lassoPolygon: a coarser ε was needed (stopped at ε \(eps / 2))")
    checkEqual(coarse, expectedCoarse, "lassoPolygon: the first of ε 2, 4, 8 that fits")
    checkEqual(LassoGeometry.strokeInLasso(points: pts([700, 900, 710, 910]), polygon: coarse), true, "lassoPolygon: the centre is still inside")
}

do {
    checkEqual(LassoGeometry.union([]), nil, "union: nothing → nil")
    checkEqual(LassoGeometry.union([CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1)]), nil, "union: non-finite rects are ignored")
    let a = CGRect(x: 0, y: 0, width: 10, height: 10)
    checkEqual(LassoGeometry.union([a, CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1), CGRect(x: -5, y: 3, width: 9, height: 17)]), CGRect(x: -5, y: 0, width: 15, height: 20), "union")
    checkEqual(LassoGeometry.union([a]), a, "union of one")
    checkEqual(LassoGeometry.union([CGRect(x: 10, y: 10, width: -10, height: -10)]), a, "union: a negative size is standardized")
    checkEqual(LassoGeometry.bounds(of: pts([0, 0, 10, 0, 10, 10, 0, 10])), a, "bounds(of:)")
    checkEqual(LassoGeometry.bounds(of: [CGPoint(x: 3, y: 4)]), CGRect(x: 3, y: 4, width: 0, height: 0), "bounds of one point")
    checkEqual(LassoGeometry.bounds(of: []), nil, "bounds of nothing")
    checkEqual(LassoGeometry.bounds(of: [CGPoint(x: CGFloat.nan, y: 4)]), nil, "bounds of a NaN point")

    let page = CGSize(width: 1400, height: 1920)
    let box = CGRect(x: 100, y: 100, width: 100, height: 50)
    checkEqual(LassoGeometry.clampedMoveDelta(bbox: box, dx: 50, dy: -20, pageSize: page), CGVector(dx: 50, dy: -20), "clampedMoveDelta: a move that stays on the paper")
    checkEqual(LassoGeometry.clampedMoveDelta(bbox: box, dx: -500, dy: 5000, pageSize: page), CGVector(dx: -100, dy: 1770), "clampedMoveDelta: clamped to the edges")
    let out = CGRect(x: -3, y: 10, width: 53, height: 10) // already sticking out on the left
    checkEqual(LassoGeometry.clampedMoveDelta(bbox: out, dx: 0, dy: 0, pageSize: page), CGVector(dx: 0, dy: 0), "clampedMoveDelta: never pushes a box in")
    checkEqual(LassoGeometry.clampedMoveDelta(bbox: out, dx: -10, dy: 0, pageSize: page), CGVector(dx: 0, dy: 0), "clampedMoveDelta: may not go further out")
    checkEqual(LassoGeometry.clampedMoveDelta(bbox: out, dx: 10, dy: 0, pageSize: page), CGVector(dx: 10, dy: 0), "clampedMoveDelta: may come back in")
    checkEqual(LassoGeometry.clampedMoveDelta(bbox: CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1), dx: 3, dy: 4, pageSize: page), CGVector(dx: 3, dy: 4), "clampedMoveDelta: a non-finite box is not clamped")
    checkEqual(LassoGeometry.clampedMoveDelta(bbox: box, dx: CGFloat.nan, dy: 4, pageSize: page), CGVector(dx: 0, dy: 4), "clampedMoveDelta: a NaN delta counts as 0")
    checkEqual(LassoGeometry.clampedMoveDelta(bbox: box, dx: 5000, dy: 5000, pageSize: CGSize(width: 0, height: 0)), CGVector(dx: 5000, dy: 5000), "clampedMoveDelta: an empty page does not clamp")

    let l = LassoGeometry.snapshotLayout(bbox: CGRect(x: 100, y: 100, width: 376, height: 36))!
    checkRect(l.rect, CGRect(x: 88, y: 88, width: 400, height: 60), "snapshotLayout: padded by 12 lu")
    checkClose(l.zoom, 1.2, "snapshotLayout: zoom 1.2")
    checkEqual(l.size, CGSize(width: 480, height: 72), "snapshotLayout: size 480 × 72")
    let tiny = LassoGeometry.snapshotLayout(bbox: CGRect(x: 0, y: 0, width: 2, height: 2))!
    checkEqual(tiny.zoom, 4, "snapshotLayout: never enlarged more than 4×")
    check(tiny.size.width <= 480 && tiny.size.height <= 240, "snapshotLayout: tiny fits")
    checkEqual(tiny.size, CGSize(width: 104, height: 104), "snapshotLayout: tiny is 26 × 4")
    let tall = LassoGeometry.snapshotLayout(bbox: CGRect(x: 0, y: 0, width: 100, height: 2000))!
    check(tall.size.height <= 240 && tall.size.width >= 1, "snapshotLayout: a tall box fits the height")
    checkEqual(tall.size.height, 240, "snapshotLayout: a tall box uses the full height")
    check(LassoGeometry.snapshotLayout(bbox: CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1)) == nil, "snapshotLayout: a non-finite box → nil")
    let custom = LassoGeometry.snapshotLayout(bbox: CGRect(x: 0, y: 0, width: 100, height: 100), pad: 0, maxSize: CGSize(width: 50, height: 50))!
    checkEqual(custom.zoom, 0.5, "snapshotLayout: custom maxSize")
    checkEqual(custom.size, CGSize(width: 50, height: 50), "snapshotLayout: custom size")
}

// MARK: InkStroke in paper coordinates

section("ink stroke paper geometry (M3b)")
do {
    let s = stroke("s1") // (10, 20), (30.1, 40), (50, 90), nib 3.5
    let origin = CGPoint(x: 200, y: 350)
    let pp = s.paperPoints(cellOrigin: origin)
    checkEqual(pp.count, 3, "paperPoints: one per control point")
    checkEqual(pp[0], CGPoint(x: 210, y: 370), "paperPoints adds the cell origin")
    checkClose(pp[1].x, 230.1, "paperPoints x (2)")
    checkClose(pp[1].y, 390, "paperPoints y (2)")
    checkEqual(pp[2], CGPoint(x: 250, y: 440), "paperPoints (3)")
    checkRect(s.paperBounds(cellOrigin: origin), CGRect(x: 208.25, y: 368.25, width: 43.5, height: 73.5), "paperBounds: the points grown by half the nib (1.75)")
    checkRect(s.paperBounds(cellOrigin: .zero), CGRect(x: 8.25, y: 18.25, width: 43.5, height: 73.5), "paperBounds at the origin")
    let marker = stroke("m", tool: .marker, points: [point(0, 0, size: 18), point(100, 0, size: 18)])
    checkRect(marker.paperBounds(cellOrigin: origin), CGRect(x: 191, y: 341, width: 118, height: 18), "paperBounds: a marker's 18 lu nib")
    let mixed = stroke("x", points: [point(0, 0, size: 2), point(10, 10, size: 6)])
    checkRect(mixed.paperBounds(cellOrigin: .zero), CGRect(x: -3, y: -3, width: 16, height: 16), "paperBounds: the largest nib of the stroke")
    let dot = stroke("d", points: [point(5, 5, size: 2)])
    checkRect(dot.paperBounds(cellOrigin: .zero), CGRect(x: 4, y: 4, width: 2, height: 2), "paperBounds: a dot is the nib's square")
    let empty = stroke("e", points: [])
    checkEqual(empty.paperBounds(cellOrigin: origin), nil, "paperBounds: no points → nil")
    checkEqual(empty.paperPoints(cellOrigin: origin), [], "paperPoints: no points → []")

    let moved = s.translated(by: CGVector(dx: 250, dy: 10), from: origin, to: .day(day(2026, 10, 5)), newCellOrigin: CGPoint(x: 400, y: 350), at: 1_760_200_000_000)
    check(moved.id != s.id, "translated: a new id")
    checkEqual(InkStroke.isValidId(moved.id), true, "translated: a valid id")
    checkEqual(moved.cell, .day(day(2026, 10, 5)), "translated: the new cell")
    checkEqual(moved.t, 1_760_200_000_000, "translated: t = at")
    checkEqual(moved.dev, "ipad-1", "translated: dev is kept")
    checkEqual(moved.tool, s.tool, "translated: tool is kept")
    checkEqual(moved.color, s.color, "translated: color is kept")
    checkEqual(moved.points.map(\.x), [60, 80.1, 100], "translated: x relative to the new cell (250 − 200 = +50)")
    checkEqual(moved.points.map(\.y), [30, 50, 100], "translated: y (+10)")
    checkEqual(moved.points.map(\.dtMs), s.points.map(\.dtMs), "translated: dt is kept")
    checkEqual(moved.points.map(\.sizeW), s.points.map(\.sizeW), "translated: nib is kept")
    checkEqual(moved.points.map(\.force), s.points.map(\.force), "translated: force is kept")
    let before = s.paperPoints(cellOrigin: origin)
    let after = moved.paperPoints(cellOrigin: CGPoint(x: 400, y: 350))
    for (b, a) in zip(before, after) {
        checkClose(a.x - b.x, 250, "translated: paper x moved by dx", tolerance: 0.051)
        checkClose(a.y - b.y, 10, "translated: paper y moved by dy", tolerance: 0.051)
    }
    checkEqual(s.points.map(\.x), [10, 30.1, 50], "translated: the original is untouched")
    let named = s.translated(by: .zero, from: origin, to: s.cell, newCellOrigin: origin, id: "clone-1", at: 5)
    checkEqual(named.id, "clone-1", "translated: an explicit id")
    checkEqual(named.points, s.points, "translated: zero delta, same cell → the same points")
    checkEqual(named.t, 5, "translated: t = at (explicit id)")
    let fine = s.translated(by: CGVector(dx: 0.04, dy: 0.06), from: origin, to: s.cell, newCellOrigin: origin, at: 5)
    checkEqual(fine.points.map(\.x), [10, 30.1, 50], "translated: 0.04 rounds away (0.1 lu grid)")
    checkEqual(fine.points.map(\.y), [20.1, 40.1, 90.1], "translated: 0.06 rounds up")
}

// MARK: - Web import (M4)

section("web import (M4)")

/// M4_CONTRACT §1.4 見本 1 (the same text as the web version's tests/fixtures/tegaki-web-export-sample.json).
let webExportSample = #"""
{ "format": "tegaki-web-export", "v": 1, "exportedAt": "2026-10-14T09:41:00.000+09:00", "app": "web/1.0.6", "includesDemo": false,
  "pages": [
    { "v": 1, "pageId": "m1-2026-10", "updatedAt": 1760000002000, "deleted": {},
      "strokes": {
        "a1": { "id": "a1", "tool": "pen", "color": "#1f2937", "size": 3.5, "pts": [410, 360, 0.4, 450, 380, 0.6, 490, 370, 0.8], "t": 1760000001000 },
        "b2": { "id": "b2", "tool": "highlighter", "color": "#fde047", "size": 18, "pts": [100, 1100, 0.5, 300, 1100, 0.5], "t": 1760000002000 } } },
    { "v": 1, "pageId": "w-2026-10-05", "updatedAt": 1760000003000, "deleted": {},
      "strokes": { "c3": { "id": "c3", "tool": "pen", "color": "#2563eb", "size": 6, "pts": [700, 720, 0.5, 760, 840, 0.5], "t": 1760000003000 } } },
    { "v": 1, "pageId": "d-2026-10-07", "updatedAt": 1760000004000, "deleted": { "zz": 1760000000500 },
      "strokes": { "d4": { "id": "d4", "tool": "pen", "color": "#1f2937", "size": 2, "pts": [100, 900, 1, 300, 1050, 1], "t": 1760000004000 } } },
    { "v": 1, "pageId": "y-2026", "updatedAt": 1760000005000, "deleted": {},
      "strokes": { "e5": { "id": "e5", "tool": "pen", "color": "#1f2937", "size": 3.5, "pts": [1000, 540, 0.6, 1050, 560, 0.6], "t": 1760000005000 } } },
    { "v": 1, "pageId": "m-2026-09", "updatedAt": 1760000006000, "deleted": {},
      "strokes": { "f6": { "id": "f6", "tool": "pen", "color": "#1f2937", "size": 3.5, "pts": [10, 10, 0.5, 20, 20, 0.5], "t": 1760000006000 } } },
    { "v": 1, "pageId": "d-2026-10-08", "updatedAt": 0, "deleted": {}, "strokes": {} }
  ] }
"""#

/// M4_CONTRACT §1.4 見本 2 (tests/fixtures/tegaki-web-export-expected.json).
let webExportExpected = #"""
{ "format": "tegaki-web-export", "v": 1, "exportedAt": "2026-10-14T09:41:00.000+09:00", "app": "web/1.0.6", "includesDemo": false,
  "pages": [
    { "v": 1, "pageId": "d-2026-10-07", "updatedAt": 1760000004000, "deleted": { "zz": 1760000000500 },
      "strokes": { "d4": { "id": "d4", "tool": "pen", "color": "#1f2937", "size": 2, "pts": [100, 900, 1, 300, 1050, 1], "t": 1760000004000 } } },
    { "v": 1, "pageId": "m1-2026-10", "updatedAt": 1760000002000, "deleted": {},
      "strokes": {
        "a1": { "id": "a1", "tool": "pen", "color": "#1f2937", "size": 3.5, "pts": [410, 360, 0.4, 450, 380, 0.6, 490, 370, 0.8], "t": 1760000001000 },
        "b2": { "id": "b2", "tool": "highlighter", "color": "#fde047", "size": 18, "pts": [100, 1100, 0.5, 300, 1100, 0.5], "t": 1760000002000 } } },
    { "v": 1, "pageId": "w-2026-10-05", "updatedAt": 1760000003000, "deleted": {},
      "strokes": { "c3": { "id": "c3", "tool": "pen", "color": "#2563eb", "size": 6, "pts": [700, 720, 0.5, 760, 840, 0.5], "t": 1760000003000 } } },
    { "v": 1, "pageId": "y-2026", "updatedAt": 1760000005000, "deleted": {},
      "strokes": { "e5": { "id": "e5", "tool": "pen", "color": "#1f2937", "size": 3.5, "pts": [1000, 540, 0.6, 1050, 560, 0.6], "t": 1760000005000 } } }
  ] }
"""#

func webDoc(_ text: String) throws -> WebImport.Document { try WebImport.parse(Data(text.utf8)) }

func webStroke(_ id: String, tool: WebImport.Stroke.Tool = .pen, color: String = "#1f2937", size: Double = 3.5, t: Int = 1_760_000_001_000, points: [(Double, Double, Double)]) -> WebImport.Stroke {
    WebImport.Stroke(id: id, tool: tool, color: color, size: size, points: points.map { WebImport.Point(x: $0.0, y: $0.1, p: $0.2) }, t: t)
}

func webParseError(_ text: String) -> WebImport.ParseError? {
    do {
        _ = try webDoc(text)
        return nil
    } catch let e as WebImport.ParseError {
        return e
    } catch {
        return nil
    }
}

/// A one-page export around `strokes` (a JSON object text).
func webExportText(pageId: String = "d-2026-10-07", strokes: String, deleted: String = "{}", updatedAt: Int = 1_760_000_004_000) -> String {
    #"{ "format": "tegaki-web-export", "v": 1, "pages": [ { "v": 1, "pageId": "\#(pageId)", "updatedAt": \#(updatedAt), "deleted": \#(deleted), "strokes": \#(strokes) } ] }"#
}

do {
    // 見本 1: six pages as written, strokes sorted by id.
    let doc = try webDoc(webExportSample)
    checkEqual(doc.pages.count, 6, "sample 1 has 6 pages")
    checkEqual(doc.pages.map(\.pageId), ["m1-2026-10", "w-2026-10-05", "d-2026-10-07", "y-2026", "m-2026-09", "d-2026-10-08"], "sample 1 pages in document order")
    checkEqual(doc.exportedAt, "2026-10-14T09:41:00.000+09:00", "exportedAt is kept as text")
    checkEqual(doc.app, "web/1.0.6", "app is kept")
    checkEqual(doc.includesDemo, false, "includesDemo")
    checkEqual(doc.pages.map(\.strokes.count), [2, 1, 1, 1, 1, 0], "stroke count per page")
    let month = doc.pages[0]
    checkEqual(month.strokes.map(\.id), ["a1", "b2"], "strokes sorted by id")
    checkEqual(month.updatedAt, 1_760_000_002_000, "page updatedAt")
    checkEqual(month.deleted, [:], "no tombstones on the month page")
    let a1 = month.strokes[0]
    checkEqual(a1.tool, .pen, "a1 tool")
    checkEqual(a1.color, "#1f2937", "a1 color")
    checkEqual(a1.size, 3.5, "a1 size")
    checkEqual(a1.t, 1_760_000_001_000, "a1 t")
    checkEqual(a1.points, [WebImport.Point(x: 410, y: 360, p: 0.4), WebImport.Point(x: 450, y: 380, p: 0.6), WebImport.Point(x: 490, y: 370, p: 0.8)], "a1 points")
    let b2 = month.strokes[1]
    checkEqual(b2.tool, .highlighter, "b2 tool")
    checkEqual(b2.color, "#fde047", "b2 color")
    checkEqual(b2.size, 18, "b2 size")
    checkEqual(b2.points.count, 2, "b2 points")
    checkEqual(doc.pages[2].deleted, ["zz": 1_760_000_000_500], "tombstone zz is read")
    checkEqual(doc.pages[2].strokes[0].size, 2, "d4 size")
    checkEqual(doc.pages[2].strokes[0].points.map(\.p), [1, 1], "d4 pressure 1")
    checkEqual(doc.pages[5].strokes, [], "the empty page has no strokes")
    checkEqual(doc.pages[5].updatedAt, 0, "the empty page's updatedAt")

    // 見本 2: four pages.
    let expected = try webDoc(webExportExpected)
    checkEqual(expected.pages.count, 4, "sample 2 has 4 pages")
    checkEqual(expected.pages.map(\.pageId), ["d-2026-10-07", "m1-2026-10", "w-2026-10-05", "y-2026"], "sample 2 pages sorted by id")
    checkEqual(expected.pages[1], month, "the month page reads the same from both samples")
    checkEqual(expected.pages[0], doc.pages[2], "the day page reads the same from both samples")

    // Reasons to throw: only format and v.
    checkEqual(webParseError(#"{ "format": "something-else", "v": 1, "pages": [] }"#), .notAnExport, "wrong format → notAnExport")
    checkEqual(webParseError(#"{ "v": 1, "pages": [] }"#), .notAnExport, "missing format → notAnExport")
    checkEqual(webParseError(#"[1, 2, 3]"#), .notAnExport, "an array → notAnExport")
    checkEqual(webParseError(#""tegaki-web-export""#), .notAnExport, "a bare string → notAnExport")
    checkEqual(webParseError(#"{ "format": "tegaki-web-export", "v": 2, "pages": [] }"#), .unsupportedVersion(2), "v 2 → unsupportedVersion(2)")
    checkEqual(webParseError(#"{ "format": "tegaki-web-export", "v": 7 }"#), .unsupportedVersion(7), "v 7 → unsupportedVersion(7)")
    checkEqual(webParseError(#"{ "format": "tegaki-web-export", "v": 1, "pages": ["#), .invalidJSON, "truncated JSON → invalidJSON")
    checkEqual(webParseError("not json at all"), .invalidJSON, "text → invalidJSON")
    checkEqual(webParseError(""), .invalidJSON, "empty data → invalidJSON")
    checkEqual(webParseError(#"{ "format": "tegaki-web-export" }"#), nil, "missing v counts as 1 and missing pages as none")
    checkEqual(try webDoc(#"{ "format": "tegaki-web-export" }"#).pages.count, 0, "no pages")
    checkEqual(try webDoc(#"{ "format": "tegaki-web-export", "v": 1, "pages": "x", "includesDemo": true, "app": 5 }"#).includesDemo, true, "includesDemo true")
    checkEqual(try webDoc(#"{ "format": "tegaki-web-export", "v": 1, "pages": "x", "app": 5 }"#).app, nil, "a non-string app is nil")
    checkEqual(try webDoc(#"{ "format": "tegaki-web-export", "v": 1, "pages": [1, "x", null] }"#).pages.count, 0, "pages that are not objects are dropped")
} catch {
    check(false, "web import parse threw: \(error)")
}

do {
    // Broken strokes are dropped, the rest normalised (web deserializePage).
    let good = ##""ok": { "id": "ok", "tool": "pen", "color": "#1f2937", "size": 3.5, "pts": [1, 2, 0.5, 3, 4, 0.5], "t": 5 }"##
    func strokes(_ extra: String, deleted: String = "{}") throws -> [WebImport.Stroke] {
        try webDoc(webExportText(strokes: "{ \(good), \(extra) }", deleted: deleted)).pages[0].strokes
    }
    checkEqual(try strokes(#""bad": { "id": "bad", "tool": "brush", "pts": [1, 2, 0.5] }"#).map(\.id), ["ok"], "unknown tool is dropped")
    checkEqual(try strokes(#""bad": { "id": "bad", "pts": [1, 2, 0.5] }"#).map(\.id), ["ok"], "missing tool is dropped")
    checkEqual(try strokes(#""bad": { "id": "bad", "tool": "pen", "pts": [1, 2] }"#).map(\.id), ["ok"], "two numbers are not a point")
    checkEqual(try strokes(#""bad": { "id": "bad", "tool": "pen", "pts": [] }"#).map(\.id), ["ok"], "no points → dropped")
    checkEqual(try strokes(#""bad": { "id": "bad", "tool": "pen" }"#).map(\.id), ["ok"], "missing pts → dropped")
    checkEqual(try strokes(#""": { "id": "", "tool": "pen", "pts": [1, 2, 0.5] }"#).map(\.id), ["ok"], "empty id (and empty key) → dropped")
    let long = String(repeating: "x", count: 129)
    checkEqual(try strokes(#""\#(long)": { "id": "\#(long)", "tool": "pen", "pts": [1, 2, 0.5] }"#).map(\.id), ["ok"], "129-character id → dropped")
    let max = String(repeating: "x", count: 128)
    checkEqual(try strokes(#""\#(max)": { "id": "\#(max)", "tool": "pen", "pts": [1, 2, 0.5] }"#).map(\.id), ["ok", max], "128-character id is fine")
    checkEqual(try strokes(#""key": { "tool": "pen", "pts": [1, 2, 0.5] }"#).map(\.id), ["key", "ok"], "a missing id falls back to the key")
    checkEqual(try strokes(#""key": { "id": 7, "tool": "pen", "pts": [1, 2, 0.5] }"#).map(\.id), ["key", "ok"], "a non-string id falls back to the key")
    checkEqual(try strokes(#""bad": 5"#).map(\.id), ["ok"], "a stroke that is not an object is dropped")
    checkEqual(try strokes(#""gone": { "id": "gone", "tool": "pen", "pts": [1, 2, 0.5] }"#, deleted: #"{ "gone": 10 }"#).map(\.id), ["ok"], "a tombstoned stroke is dropped")
    checkEqual(try webDoc(webExportText(strokes: "{ \(good) }", deleted: #"{ "": 1, "a": "x", "b": -5, "c": 1e20 }"#)).pages[0].deleted, ["a": 0, "b": 0, "c": 0], "tombstones: bad ids dropped, garbage times are 0")
    checkEqual(try webDoc(webExportText(strokes: #"[{ "id": "l1", "tool": "pen", "pts": [1, 2, 0.5] }, { "tool": "pen", "pts": [1, 2, 0.5] }]"#)).pages[0].strokes.map(\.id), ["l1"], "an array of strokes is read (no key to fall back to)")

    // Pressure.
    func points(_ pts: String, tool: String = "pen", size: String = "3.5") throws -> WebImport.Stroke? {
        try webDoc(webExportText(strokes: #"{ "s": { "id": "s", "tool": "\#(tool)", "size": \#(size), "pts": \#(pts) } }"#)).pages[0].strokes.first
    }
    checkEqual(try points("[0, 0, -1, 10, 10, 2]")?.points.map(\.p), [0, 1], "pressure clamped to 0…1")
    checkEqual(try points(#"[0, 0, "x", 10, 10, null]"#)?.points.map(\.p), [0.5, 0.5], "non-numeric pressure → 0.5")
    checkEqual(try points("[0, 0, 0.123, 10, 10, 0.456]")?.points.map(\.p), [0.12, 0.46], "pressure rounded to 0.01")
    checkEqual(try points("[0.04, 0.06, 0.5, 10.15, 10.14, 0.5]")?.points.map { [$0.x, $0.y] }, [[0, 0.1], [10.2, 10.1]], "coordinates rounded to 0.1")
    checkEqual(try points("[1, 1, 0.5, 1, 1, 0.7, 1, 1, 0.9, 2, 2, 0.5]")?.points.count, 2, "consecutive equal points are dropped")
    checkEqual(try points("[1, 1, 0.5, 2, 2, 0.5, 1, 1, 0.5]")?.points.count, 3, "a return to an earlier point is kept")
    checkEqual(try points("[1, 1, 0.5, 100001, 5, 0.5, 2, 2, 0.5]")?.points.count, 2, "|x| > 100000 is dropped")
    checkEqual(try points("[1, 1, 0.5, 5, -100000.05, 0.5, 2, 2, 0.5]")?.points.count, 2, "|y| > 100000 is dropped")
    checkEqual(try points("[1, 1, 0.5, 100000, -100000, 0.5]")?.points.count, 2, "|coordinate| = 100000 is kept")
    checkEqual(try points(#"[1, 1, 0.5, "a", 5, 0.5, 2, 2, 0.5]"#)?.points.count, 2, "a non-numeric coordinate drops the point")
    checkEqual(try points("[1, 1, 0.5, 2, 2, 0.5, 3, 3]")?.points.count, 2, "a trailing partial point is ignored")
    checkEqual(try points("[100001, 1, 0.5]"), nil, "a stroke whose only point is absurd is dropped")

    // Size.
    checkEqual(try points("[0, 0, 0.5]", size: "0.05")?.size, 0.1, "size 0.05 → 0.1")
    checkEqual(try points("[0, 0, 0.5]", size: "500")?.size, 200, "size 500 → 200")
    checkEqual(try points("[0, 0, 0.5]", size: "2.345")?.size, 2.35, "size rounded to 0.01")
    checkEqual(try points("[0, 0, 0.5]", size: "\"x\"")?.size, 3.5, "non-numeric size → pen default")
    checkEqual(try points("[0, 0, 0.5]", size: "0")?.size, 3.5, "size 0 → pen default (not 0.1)")
    checkEqual(try points("[0, 0, 0.5]", size: "-3")?.size, 3.5, "negative size → pen default")
    checkEqual(try points("[0, 0, 0.5]", tool: "highlighter", size: "null")?.size, 18, "highlighter: non-numeric size → 18")
    checkEqual(try points("[0, 0, 0.5]", tool: "highlighter", size: "0")?.size, 18, "highlighter: size 0 → 18")
    checkEqual(try points("[0, 0, 0.5]", tool: "highlighter", size: "12")?.size, 12, "highlighter: a size is kept")
    checkEqual(WebImport.normalizeSize(nil, tool: .pen), 3.5, "normalizeSize nil → 3.5")
    checkEqual(WebImport.normalizeSize(.infinity, tool: .highlighter), 18, "normalizeSize ∞ → 18")
    checkEqual(WebImport.normalizeSize(6, tool: .pen), 6, "normalizeSize 6")

    // Colour and time.
    func stroke(_ body: String) throws -> WebImport.Stroke? {
        try webDoc(webExportText(strokes: #"{ "s": { "id": "s", "pts": [0, 0, 0.5], \#(body) } }"#)).pages[0].strokes.first
    }
    checkEqual(try stroke(##""tool": "pen", "color": "#ABC""##)?.color, "#aabbcc", "colour expanded and lower-cased")
    checkEqual(try stroke(#""tool": "pen", "color": "red""#)?.color, "#1f2937", "bad colour → pen default")
    checkEqual(try stroke(#""tool": "highlighter""#)?.color, "#fde047", "missing colour → highlighter default")
    checkEqual(try stroke(#""tool": "pen", "t": -5"#)?.t, 0, "negative t → 0")
    checkEqual(try stroke(#""tool": "pen", "t": "x""#)?.t, 0, "non-numeric t → 0")
    checkEqual(try stroke(#""tool": "pen", "t": 1760000001000.4"#)?.t, 1_760_000_001_000, "t rounded")
    checkEqual(try stroke(#""tool": "pen""#)?.t, 0, "missing t → 0")
    checkEqual(try webDoc(webExportText(strokes: "{ \(good) }", updatedAt: -1)).pages[0].updatedAt, 0, "negative updatedAt → 0")
    checkEqual(try webDoc(#"{ "format": "tegaki-web-export", "v": 1, "pages": [ { "strokes": {} } ] }"#).pages[0].pageId, "", "a page without pageId reads as \"\"")
} catch {
    check(false, "web import normalisation threw: \(error)")
}

do {
    // PageId.parse: the four forms and their raw strings.
    checkEqual(WebImport.PageId.parse("m1-2026-10"), .month(YearMonth(year: 2026, month: 10)), "m1- month")
    checkEqual(WebImport.PageId.parse("w-2026-10-05"), .week(day(2026, 10, 5)), "w- Monday week")
    checkEqual(WebImport.PageId.parse("d-2026-10-07"), .day(day(2026, 10, 7)), "d- day")
    checkEqual(WebImport.PageId.parse("y-2026"), .year(2026), "y- year")
    checkEqual(WebImport.PageId.parse("m1-2026-10")?.raw, "m1-2026-10", "raw month")
    checkEqual(WebImport.PageId.parse("w-2026-10-05")?.raw, "w-2026-10-05", "raw week")
    checkEqual(WebImport.PageId.parse("d-2026-10-07")?.raw, "d-2026-10-07", "raw day")
    checkEqual(WebImport.PageId.parse("y-2026")?.raw, "y-2026", "raw year")
    checkEqual(WebImport.PageId.parse("m-2026-09"), nil, "m- (Sunday-start month) → nil")
    checkEqual(WebImport.PageId.parse("w-2026-10-04"), nil, "w- of a Sunday → nil")
    checkEqual(WebImport.PageId.parse("w-2026-10-06"), nil, "w- of a Tuesday → nil")
    checkEqual(WebImport.PageId.parse("y-26"), nil, "y-26 → nil")
    checkEqual(WebImport.PageId.parse(""), nil, "empty → nil")
    checkEqual(WebImport.PageId.parse("m1-2026-13"), nil, "month 13 → nil")
    checkEqual(WebImport.PageId.parse("m1-2026-1"), nil, "unpadded month → nil")
    checkEqual(WebImport.PageId.parse("d-2026-02-30"), nil, "impossible date → nil")
    checkEqual(WebImport.PageId.parse("d-2026-10-7"), nil, "unpadded day → nil")
    checkEqual(WebImport.PageId.parse("x-2026"), nil, "unknown prefix → nil")
    checkEqual(WebImport.PageId.parse("y-2026x"), nil, "trailing junk → nil")
    checkEqual(WebImport.PageId.parse("y-２０２６"), nil, "full-width digits → nil")
    checkEqual(WebImport.PageId.parse("w-2025-12-29"), .week(day(2025, 12, 29)), "a Monday across the year end")
    checkEqual(WebImport.PageId.parse("y-0999"), .year(999), "y-0999 → 999")
    checkEqual(WebImport.PageId.year(999).raw, "y-0999", "raw pads the year")

    // cell(for:center:): month.
    let october = WebImport.PageId.month(YearMonth(year: 2026, month: 10))
    var r = WebImport.cell(for: october, center: CGPoint(x: 450, y: 370))
    checkEqual(r.cell, .day(day(2026, 10, 14)), "a1: row 2, column 2 → 10/14")
    checkEqual(r.origin, CGPoint(x: 400, y: 350), "a1 origin")
    r = WebImport.cell(for: october, center: CGPoint(x: 200, y: 1100))
    checkEqual(r.cell, .memo, "b2: y ≥ 1050 → memo")
    checkEqual(r.origin, CGPoint(x: 0, y: 1050), "memo origin")
    r = WebImport.cell(for: october, center: CGPoint(x: -5, y: -5))
    checkEqual(r.cell, .day(day(2026, 9, 28)), "outside top-left → row 0 column 0 = 9/28")
    checkEqual(r.origin, .zero, "9/28 origin")
    r = WebImport.cell(for: october, center: CGPoint(x: 1400, y: 1049.9))
    checkEqual(r.cell, .day(day(2026, 11, 8)), "(1400, 1049.9) → row 5 column 6 = 11/8")
    checkEqual(r.origin, CGPoint(x: 1200, y: 875), "11/8 origin")
    r = WebImport.cell(for: october, center: CGPoint(x: 700, y: 1050))
    checkEqual(r.cell, .memo, "(700, 1050) → memo")
    r = WebImport.cell(for: october, center: CGPoint(x: CGFloat.nan, y: CGFloat.nan))
    checkEqual(r.cell, .day(day(2026, 9, 28)), "NaN centre counts as (0, 0)")
    r = WebImport.cell(for: october, center: CGPoint(x: 350, y: 175))
    checkEqual(r.cell, .day(day(2026, 10, 6)), "(350, 175) is on row 1 (10/6)")
    r = WebImport.cell(for: october, center: CGPoint(x: 199.9999999999, y: 174.9999999999))
    checkEqual(r.cell, .day(day(2026, 10, 6)), "1e-9 below a boundary still counts as the next cell")
    r = WebImport.cell(for: october, center: CGPoint(x: 5000, y: 100))
    checkEqual(r.cell, .day(day(2026, 10, 4)), "far right → column 6 (10/4)")
    r = WebImport.cell(for: WebImport.PageId.month(YearMonth(year: 2026, month: 2)), center: CGPoint(x: 100, y: 100))
    checkEqual(r.cell, .day(day(2026, 1, 26)), "February 2026 starts on Monday 1/26")

    // Week and day: always grid.
    r = WebImport.cell(for: .week(day(2026, 10, 5)), center: CGPoint(x: 730, y: 780))
    checkEqual(r.cell, .grid, "week → grid")
    checkEqual(r.origin, .zero, "week origin (0, 0)")
    r = WebImport.cell(for: .week(day(2026, 10, 5)), center: CGPoint(x: -100, y: 99999))
    checkEqual(r.cell, .grid, "week → grid wherever")
    r = WebImport.cell(for: .day(day(2026, 10, 7)), center: CGPoint(x: 200, y: 975))
    checkEqual(r.cell, .grid, "day → grid")
    checkEqual(r.origin, .zero, "day origin (0, 0)")
    r = WebImport.cell(for: .day(day(2026, 10, 7)), center: CGPoint(x: 900, y: 2300))
    checkEqual(r.cell, .grid, "day memo area → grid too")

    // Year.
    let year = WebImport.PageId.year(2026)
    r = WebImport.cell(for: year, center: CGPoint(x: 1025, y: 550))
    checkEqual(r.cell, .yearDay(month: 9, day: 10), "e5: month 8 → 9月, day 10")
    checkEqual(r.origin, CGPoint(x: 952, y: 540), "e5 origin (56 + 112 × 8, 60 × 9)")
    r = WebImport.cell(for: year, center: CGPoint(x: 10, y: 30))
    checkEqual(r.cell, .yearDay(month: 1, day: 1), "the date gutter → 01-01")
    checkEqual(r.origin, CGPoint(x: 56, y: 0), "01-01 origin")
    r = WebImport.cell(for: year, center: CGPoint(x: 1399, y: 1859))
    checkEqual(r.cell, .yearDay(month: 12, day: 31), "(1399, 1859) → 12-31")
    checkEqual(r.origin, CGPoint(x: 1288, y: 1800), "12-31 origin")
    r = WebImport.cell(for: year, center: CGPoint(x: 1399, y: 5000))
    checkEqual(r.cell, .yearDay(month: 12, day: 31), "below the paper → 12-31")
    r = WebImport.cell(for: year, center: CGPoint(x: 5000, y: -50))
    checkEqual(r.cell, .yearDay(month: 12, day: 1), "right of the paper, above → 12-01")
    r = WebImport.cell(for: year, center: CGPoint(x: 168 + 50, y: 1745))
    checkEqual(r.cell, .yearDay(month: 2, day: 30), "the 2/30 cell exists")
    checkEqual(r.origin, CGPoint(x: 168, y: 1740), "2/30 origin")
    r = WebImport.cell(for: year, center: CGPoint(x: 56, y: 0))
    checkEqual(r.cell, .yearDay(month: 1, day: 1), "(56, 0) → 01-01")
    r = WebImport.cell(for: year, center: CGPoint(x: 168, y: 60))
    checkEqual(r.cell, .yearDay(month: 2, day: 2), "(168, 60) → 02-02 (boundaries belong to the next cell)")

    // Nib size.
    checkClose(WebImport.nibSize(tool: .pen, size: 3.5, pressure: 0.4), 2.66, "nib 3.5 × (0.4 + 0.36)", tolerance: 1e-9)
    checkClose(WebImport.nibSize(tool: .pen, size: 3.5, pressure: 0.6), 3.29, "nib 3.5 × (0.4 + 0.54)", tolerance: 1e-9)
    checkClose(WebImport.nibSize(tool: .pen, size: 3.5, pressure: 0.8), 3.92, "nib 3.5 × (0.4 + 0.72)", tolerance: 1e-9)
    checkClose(WebImport.nibSize(tool: .pen, size: 2, pressure: 1), 2.6, "nib 2 × 1.3", tolerance: 1e-9)
    checkClose(WebImport.nibSize(tool: .pen, size: 6, pressure: 0.5), 5.1, "nib 6 × 0.85", tolerance: 1e-9)
    checkClose(WebImport.nibSize(tool: .pen, size: 3.5, pressure: 0), 1.4, "nib at zero pressure", tolerance: 1e-9)
    checkEqual(WebImport.nibSize(tool: .highlighter, size: 18, pressure: 0.5), 18, "highlighter nib = size")
    checkEqual(WebImport.nibSize(tool: .highlighter, size: 18, pressure: 1), 18, "highlighter ignores pressure")
    checkEqual(WebImport.nibSize(tool: .highlighter, size: 10, pressure: 0), 10, "highlighter nib follows size")
    checkEqual(WebImport.highlighterWidth, 18, "highlighterWidth constant")
    checkEqual(WebImport.format, "tegaki-web-export", "format constant")
    checkEqual(WebImport.supportedVersion, 1, "supportedVersion constant")
    checkEqual(WebImport.deviceId, "web", "deviceId constant")
    checkEqual(WebImport.pointStepMs, 8, "pointStepMs constant")
}

do {
    // convert(stroke:): every attribute of the §1.4 table.
    let doc = try webDoc(webExportSample)
    let october = WebImport.PageId.month(YearMonth(year: 2026, month: 10))
    let a1 = WebImport.convert(stroke: doc.pages[0].strokes[0], page: october)
    checkEqual(a1?.id, "a1", "a1: id kept")
    checkEqual(a1?.cell, .day(day(2026, 10, 14)), "a1: cell 2026-10-14")
    checkEqual(a1?.tool, .pen, "a1: pen")
    checkEqual(a1?.color, "#1f2937", "a1: color")
    checkEqual(a1?.t, 1_760_000_001_000, "a1: t")
    checkEqual(a1?.dev, "web", "a1: dev web")
    checkEqual(a1?.points.count, 3, "a1: 3 points")
    checkEqual(a1?.points.map(\.x), [10, 50, 90], "a1: x relative to the cell")
    checkEqual(a1?.points.map(\.y), [10, 30, 20], "a1: y relative to the cell")
    checkEqual(a1?.points.map(\.dtMs), [0, 8, 16], "a1: dtMs 8 × n")
    checkEqual(a1?.points.map(\.sizeW), [2.66, 3.29, 3.92], "a1: sizeW")
    checkEqual(a1?.points.map(\.sizeH), [2.66, 3.29, 3.92], "a1: sizeH")
    checkEqual(a1?.points.map(\.force), [0.4, 0.6, 0.8], "a1: force = p")
    checkEqual(a1?.points.map(\.opacity), [1, 1, 1], "a1: opacity 1")
    checkEqual(a1?.points.map(\.azimuth), [0, 0, 0], "a1: azimuth 0")
    checkEqual(a1?.points.map(\.altitude), [1.571, 1.571, 1.571], "a1: altitude π/2 → 1.571")
    checkEqual(a1?.inkStart, Date(timeIntervalSince1970: 1_760_000_001), "a1: inkStart from t")
    let b2 = WebImport.convert(stroke: doc.pages[0].strokes[1], page: october)
    checkEqual(b2?.cell, .memo, "b2: memo")
    checkEqual(b2?.tool, .marker, "b2: highlighter → marker")
    checkEqual(b2?.color, "#fde047", "b2: color")
    checkEqual(b2?.points.map(\.x), [100, 300], "b2: x")
    checkEqual(b2?.points.map(\.y), [50, 50], "b2: y − 1050")
    checkEqual(b2?.points.map(\.sizeW), [18, 18], "b2: nib 18")
    checkEqual(b2?.points.map(\.force), [0.5, 0.5], "b2: force")
    checkEqual(b2?.t, 1_760_000_002_000, "b2: t")
    let c3 = WebImport.convert(stroke: doc.pages[1].strokes[0], page: .week(day(2026, 10, 5)))
    checkEqual(c3?.cell, .grid, "c3: grid")
    checkEqual(c3?.color, "#2563eb", "c3: color")
    checkEqual(c3?.points.map(\.x), [700, 760], "c3: x unchanged")
    checkEqual(c3?.points.map(\.y), [720, 840], "c3: y unchanged")
    checkEqual(c3?.points.map(\.sizeW), [5.1, 5.1], "c3: nib 6 × 0.85")
    checkEqual(c3?.dev, "web", "c3: dev")
    let d4 = WebImport.convert(stroke: doc.pages[2].strokes[0], page: .day(day(2026, 10, 7)))
    checkEqual(d4?.cell, .grid, "d4: grid")
    checkEqual(d4?.points.map(\.x), [100, 300], "d4: x")
    checkEqual(d4?.points.map(\.y), [900, 1050], "d4: y")
    checkEqual(d4?.points.map(\.sizeW), [2.6, 2.6], "d4: nib 2 × 1.3")
    checkEqual(d4?.points.map(\.force), [1, 1], "d4: force 1")
    let e5 = WebImport.convert(stroke: doc.pages[3].strokes[0], page: .year(2026))
    checkEqual(e5?.cell, .yearDay(month: 9, day: 10), "e5: 09-10")
    checkEqual(e5?.points.map(\.x), [48, 98], "e5: x − 952")
    checkEqual(e5?.points.map(\.y), [0, 20], "e5: y − 540")
    checkEqual(e5?.points.map(\.sizeW), [3.29, 3.29], "e5: nib")
    checkEqual(e5?.t, 1_760_000_005_000, "e5: t")

    // Edge cases of convert(stroke:).
    checkEqual(WebImport.convert(stroke: webStroke("", points: [(1, 1, 0.5)]), page: october), nil, "an empty id → nil")
    checkEqual(WebImport.convert(stroke: webStroke(String(repeating: "y", count: 129), points: [(1, 1, 0.5)]), page: october), nil, "a 129-character id → nil")
    checkEqual(WebImport.convert(stroke: webStroke("p", points: []), page: october), nil, "no points → nil")
    let odd = WebImport.convert(stroke: webStroke("odd", color: "nope", t: -7, points: [(1, 2, 0.5)]), page: october)
    checkEqual(odd?.color, "#1f2937", "a bad colour → the tool default")
    checkEqual(odd?.t, 0, "a negative t → 0")
    checkEqual(odd?.points.map(\.x), [1], "a single point converts")
    let hl = WebImport.convert(stroke: webStroke("hl", tool: .highlighter, color: "bad", size: 18, points: [(1, 2, 0.5)]), page: october)
    checkEqual(hl?.color, "#fde047", "a bad highlighter colour → marker default")
    checkEqual(hl?.tool, .marker, "highlighter → marker")
    let fine = WebImport.convert(stroke: webStroke("fine", size: 3.5, points: [(410.04, 360.06, 0.123)]), page: october)
    checkEqual(fine?.points.first?.x, 10, "x rounded to 0.1 (InkPoint)")
    checkEqual(fine?.points.first?.y, 10.1, "y rounded to 0.1")
    checkEqual(fine?.points.first?.force, 0.12, "force rounded to 0.01")
    checkClose(fine?.points.first?.sizeW, 1.79, "nib 3.5 × (0.4 + 0.9 × 0.123) = 1.787 → 1.79", tolerance: 1e-9)
    // The centre decides the cell, not the first point: a stroke from 10/13 into 10/15 whose centre is on 10/14.
    let span = WebImport.convert(stroke: webStroke("span", points: [(300, 400, 0.5), (580, 400, 0.5)]), page: october)
    checkEqual(span?.cell, .day(day(2026, 10, 14)), "the bounding-box centre (440, 400) decides the cell")
    checkEqual(span?.points.map(\.x), [-100, 180], "points outside the cell keep their offset")
    let many = WebImport.convert(stroke: webStroke("many", points: (0..<50).map { (Double($0), 5, 0.5) }), page: .week(day(2026, 10, 5)))
    checkEqual(many?.points.map(\.dtMs), (0..<50).map { 8 * $0 }, "dtMs grows 8 ms per point")

    // convert(_:) on 見本 1.
    let conv = WebImport.convert(doc)
    checkEqual(conv.pages.count, 4, "sample 1 converts to 4 pages")
    checkEqual(conv.pageCount, 4, "pageCount")
    checkEqual(conv.strokeCount, 5, "strokeCount 5")
    checkEqual(conv.skipped, [WebImport.Skipped(pageId: "m-2026-09", reason: .legacyPageId), WebImport.Skipped(pageId: "d-2026-10-08", reason: .noStrokes)], "skipped pages and reasons")
    checkEqual(conv.pages.map(\.pageId), ["m1-2026-10", "w-2026-10-05", "d-2026-10-07", "y-2026"], "pages in document order")
    checkEqual(conv.pages.map(\.liveStrokeCount), [2, 1, 1, 1], "live strokes per page")
    checkEqual(conv.pages.map(\.updatedAt), [1_760_000_002_000, 1_760_000_003_000, 1_760_000_004_000, 1_760_000_005_000], "updatedAt from the web")
    checkEqual(conv.pages.map(\.v), [1, 1, 1, 1], "v 1")
    checkEqual(conv.pages[2].deleted, ["zz": 1_760_000_000_500], "the day page keeps the tombstone zz")
    checkEqual(conv.pages[2].strokes["d4"] != nil, true, "d4 is still there next to the tombstone")
    checkEqual(conv.pages[0].liveStrokeIds, ["a1", "b2"], "month page ids")
    checkEqual(conv.pages[0].strokes["a1"], a1, "the month page's a1 is the converted stroke")
    checkEqual(conv.pages[0].strokes["b2"], b2, "the month page's b2")
    checkEqual(conv.pages[1].strokes["c3"], c3, "the week page's c3")
    checkEqual(conv.pages[2].strokes["d4"], d4, "the day page's d4")
    checkEqual(conv.pages[3].strokes["e5"], e5, "the year page's e5")
    check(conv.pages.allSatisfy { $0.strokes.values.allSatisfy { $0.dev == "web" } }, "every stroke has dev web")
    check(conv.pages.allSatisfy { $0.unknown.isEmpty && $0.unknownStrokes.isEmpty }, "nothing unknown")
    checkEqual(conv.pages[0].liveStrokes.map(\.id), ["b2", "a1"], "draw order: marker first")

    // 見本 2 converts to the same pages.
    let conv2 = WebImport.convert(try webDoc(webExportExpected))
    checkEqual(conv2.pages.count, 4, "sample 2 converts to 4 pages")
    checkEqual(conv2.strokeCount, 5, "sample 2 strokeCount 5")
    checkEqual(conv2.skipped, [], "sample 2 skips nothing")
    checkEqual(conv2.pages.map(\.pageId), ["d-2026-10-07", "m1-2026-10", "w-2026-10-05", "y-2026"], "sample 2 pages in its order")
    checkEqual(conv.pages.sorted { $0.pageId < $1.pageId }, conv2.pages, "sorted by pageId the two conversions are equal")
    check(conv.pages.sorted { $0.pageId < $1.pageId } != conv.pages, "(document order differs from sorted order)")

    // Importing twice does not duplicate; a stroke erased on the iPad does not come back.
    for page in conv.pages {
        checkEqual(InkPage.merge(page, page).liveStrokeCount, page.liveStrokeCount, "merge(convert, convert) keeps the count on \(page.pageId)")
        checkEqual(InkPage.merge(page, page), page, "merge(convert, convert) is the same page on \(page.pageId)")
    }
    var local = conv.pages[0]
    local.remove(ids: ["a1"], at: 1_760_000_009_000)
    local.add(stroke("ipad-stroke", t: 1_760_000_010_000))
    let again = InkPage.merge(local, conv.pages[0])
    checkEqual(again.liveStrokeIds, ["b2", "ipad-stroke"], "a1 erased on the iPad stays erased after a re-import")
    checkEqual(again.deleted["a1"], 1_760_000_009_000, "the tombstone survives")
    checkEqual(again.updatedAt, 1_760_000_010_000, "updatedAt is the max")
    checkEqual(InkPage.merge(conv.pages[0], local), again, "merge is commutative here too")
    checkEqual(InkPage.merge(again, conv.pages[0]), again, "a third import changes nothing")
    let wiped = InkPage.merge(InkPage(pageId: "d-2026-10-07", deleted: ["d4": 1]), conv.pages[2])
    checkEqual(wiped.liveStrokeCount, 0, "a tombstone wins over the imported stroke")
    checkEqual(wiped.deleted, ["d4": 1, "zz": 1_760_000_000_500], "tombstones unite")
    checkEqual(conv.pages[2].contentDiffers(from: wiped), true, "contentDiffers after the tombstone")
    checkEqual(conv.pages[2].contentDiffers(from: InkPage.merge(conv.pages[2], conv.pages[2])), false, "contentDiffers: the same content")

    // updatedAt = max(web updatedAt, the strokes' t).
    let early = WebImport.convert(page: WebImport.Page(pageId: "d-2026-10-07", strokes: [webStroke("s", t: 100, points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 5))
    checkEqual(early?.updatedAt, 100, "updatedAt = stroke t when the page's is older")
    let late = WebImport.convert(page: WebImport.Page(pageId: "d-2026-10-07", strokes: [webStroke("s", t: 100, points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 200))
    checkEqual(late?.updatedAt, 200, "updatedAt = the page's when it is later")
    let two = WebImport.convert(page: WebImport.Page(pageId: "d-2026-10-07", strokes: [webStroke("s", t: 100, points: [(1, 1, 0.5)]), webStroke("u", t: 300, points: [(2, 2, 0.5)])], deleted: ["s": 50], updatedAt: 200))
    checkEqual(two?.updatedAt, 300, "updatedAt = the latest stroke")
    checkEqual(two?.deleted, ["s": 50], "web tombstones are carried over as they are")
    checkEqual(two?.strokes.count, 2, "the strokes are not removed by the carried-over tombstone")
    checkEqual(two?.liveStrokeIds, ["u"], "but the tombstoned one is not live")
    checkEqual(two?.jsonValue["strokes"]?.objectValue?.keys.sorted(), ["u"], "and it is not written")
    let zero = WebImport.convert(page: WebImport.Page(pageId: "d-2026-10-07", strokes: [webStroke("s", t: 0, points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 0))
    checkEqual(zero?.updatedAt, 0, "all zero stays 0")
    checkEqual(zero?.strokes["s"]?.t, 0, "t 0 is kept")

    // convert(page:) nil cases.
    checkEqual(WebImport.convert(page: WebImport.Page(pageId: "m-2026-09", strokes: [webStroke("s", points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 1)), nil, "legacy id → nil")
    checkEqual(WebImport.convert(page: WebImport.Page(pageId: "d-2026-10-08", strokes: [], deleted: ["zz": 1], updatedAt: 1)), nil, "no strokes (only tombstones) → nil")
    checkEqual(WebImport.convert(page: WebImport.Page(pageId: "d-2026-10-08", strokes: [webStroke("", points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 1)), nil, "only an unconvertible stroke → nil")
    let reasons = WebImport.convert(WebImport.Document(exportedAt: nil, app: nil, includesDemo: false, pages: [
        WebImport.Page(pageId: "m-2026-09", strokes: [webStroke("s", points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 1),
        WebImport.Page(pageId: "w-2026-10-04", strokes: [webStroke("s", points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 1),
        WebImport.Page(pageId: "w-2026-10-06", strokes: [webStroke("s", points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 1),
        WebImport.Page(pageId: "", strokes: [webStroke("s", points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 1),
        WebImport.Page(pageId: "q-2026", strokes: [webStroke("s", points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 1),
        WebImport.Page(pageId: "y-2026", strokes: [], deleted: [:], updatedAt: 1),
        WebImport.Page(pageId: "y-2026", strokes: [webStroke("s", points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 1),
    ]))
    checkEqual(reasons.skipped.map(\.reason), [.legacyPageId, .legacyPageId, .unknownPageId, .unknownPageId, .unknownPageId, .noStrokes], "skip reasons: m-, Sunday w-, Tuesday w-, empty, unknown prefix, empty page")
    checkEqual(reasons.skipped.map(\.pageId), ["m-2026-09", "w-2026-10-04", "w-2026-10-06", "", "q-2026", "y-2026"], "skipped ids")
    checkEqual(reasons.pageCount, 1, "one page survives")
    checkEqual(reasons.strokeCount, 1, "one stroke survives")
    checkEqual(WebImport.convert(WebImport.Document(exportedAt: nil, app: nil, includesDemo: true, pages: [])), WebImport.Conversion(pages: [], skipped: [], strokeCount: 0, pageCount: 0), "an empty document converts to nothing")

    // Round trip through the codec: the imported page is an ordinary page.
    let data = try InkPageCodec.encode(conv.pages[0])
    checkEqual(try InkPageCodec.decode(data), conv.pages[0], "an imported page survives the codec")
    let compressed = try InkPageCodec.compress(data)
    checkEqual(try InkPageCodec.decode(try InkPageCodec.decompress(compressed)), conv.pages[0], "and the compression")
} catch {
    check(false, "web import conversion threw: \(error)")
}

// MARK: - Sync state (M4)

section("sync state (M4)")

do {
    let empty = SyncState.empty
    checkEqual(empty.v, 1, "empty: v 1")
    checkEqual(empty.dirty, [], "empty: no dirty pages")
    checkEqual(empty.zoneToken, nil, "empty: no token")
    checkEqual(empty.zoneReady, false, "empty: zone not ready")
    checkEqual(empty.subscriptionReady, false, "empty: subscription not ready")
    checkEqual(empty.account, nil, "empty: no account")
    checkEqual(empty.pendingAccount, nil, "empty: no pending account")
    checkEqual(empty.pendingCloudErase, false, "empty: no pending erase")
    checkEqual(empty.seen, [:], "empty: nothing seen")
    checkEqual(empty.lastSyncAt, nil, "empty: never synced")
    checkEqual(empty.webImportedAt, nil, "empty: never imported")
    checkEqual(empty.isDirty, false, "empty: not dirty")
    checkEqual(empty.jsonValue.serialized(), #"{"account":null,"dirty":[],"lastSyncAt":null,"pendingAccount":null,"pendingCloudErase":false,"seen":{},"subscriptionReady":false,"v":1,"webImportedAt":null,"zoneReady":false,"zoneToken":null}"#, "empty: JSON with sorted keys")
    checkEqual(SyncState(json: empty.jsonValue), empty, "empty: round trip")
    checkEqual(SyncState(json: .object([:])), empty, "{} reads as empty")
    checkEqual(SyncState(json: .array([])), empty, "an array reads as empty")
    checkEqual(SyncState(json: .null), empty, "null reads as empty")
    checkEqual(SyncState.currentVersion, 1, "currentVersion")
    checkEqual(SyncState.knownKeys.count, 11, "11 known keys")
    checkEqual(SyncState.knownKeys, ["v", "dirty", "zoneToken", "zoneReady", "subscriptionReady", "account", "pendingAccount", "pendingCloudErase", "seen", "lastSyncAt", "webImportedAt"], "the known keys of §1.1")

    // The §1.1 example.
    let example = #"""
    { "v": 1, "dirty": ["m1-2026-10", "w-2026-10-05"],
      "zoneToken": "YnBsaXN0MDDUAQID", "zoneReady": true, "subscriptionReady": true,
      "account": "_0123456789abcdef0123456789abcdef", "pendingAccount": null, "pendingCloudErase": false,
      "seen": { "m1-2026-10": { "tag": "jx3pq", "sys": "YnBsaXN0MDDUAQID" } },
      "lastSyncAt": 1760150500000, "webImportedAt": 1760150000000 }
    """#
    let state = try SyncStateCodec.decode(Data(example.utf8))
    checkEqual(state.v, 1, "example: v")
    checkEqual(state.dirty, ["m1-2026-10", "w-2026-10-05"], "example: dirty in order")
    checkEqual(state.zoneToken, Data(base64Encoded: "YnBsaXN0MDDUAQID"), "example: token decoded from base64")
    checkEqual(state.zoneReady, true, "example: zoneReady")
    checkEqual(state.subscriptionReady, true, "example: subscriptionReady")
    checkEqual(state.account, "_0123456789abcdef0123456789abcdef", "example: account")
    checkEqual(state.pendingAccount, nil, "example: pendingAccount null")
    checkEqual(state.pendingCloudErase, false, "example: pendingCloudErase")
    checkEqual(state.seen, ["m1-2026-10": SeenRecord(changeTag: "jx3pq", systemFields: Data(base64Encoded: "YnBsaXN0MDDUAQID"))], "example: seen")
    checkEqual(state.lastSyncAt, 1_760_150_500_000, "example: lastSyncAt")
    checkEqual(state.webImportedAt, 1_760_150_000_000, "example: webImportedAt")
    checkEqual(state.unknown, [:], "example: nothing unknown")
    checkEqual(state.isDirty, true, "example: dirty")
    checkEqual(SyncState(json: state.jsonValue), state, "example: jsonValue → init(json:) round trip")
    checkEqual(try SyncStateCodec.decode(try SyncStateCodec.encode(state)), state, "example: codec round trip")
    checkEqual(try JSONValue.parse(try SyncStateCodec.encode(state)), state.jsonValue, "example: encode writes jsonValue")
    let text = String(decoding: try SyncStateCodec.encode(state), as: UTF8.self)
    check(text.hasPrefix(#"{"account":"_0123456789abcdef0123456789abcdef","dirty":["m1-2026-10","w-2026-10-05"],"lastSyncAt":1760150500000,"#), "example: keys sorted, numbers plain")
    check(text.contains(#""seen":{"m1-2026-10":{"sys":"YnBsaXN0MDDUAQID","tag":"jx3pq"}}"#), "example: seen written with base64")
    check(text.contains(#""zoneToken":"YnBsaXN0MDDUAQID""#), "example: token written as base64")
    checkEqual(state.jsonValue["pendingAccount"], .null, "nil is written as null")

    // Unknown keys are written back; broken items are dropped.
    let odd = SyncState(json: try JSONValue.parse(Data(#"""
    { "v": 3, "future": { "x": [1, 2] }, "note": "hi", "dirty": ["a", "b", "a", 5, "", "c", "b"],
      "zoneToken": "***not base64***", "zoneReady": "yes", "account": "", "pendingAccount": "_other",
      "seen": { "ok": { "tag": "t1" }, "noTag": { "sys": "AAAA" }, "emptyTag": { "tag": "" }, "notObject": "x", "badSys": { "tag": "t2", "sys": "%%%" }, "": { "tag": "t3" } },
      "lastSyncAt": -5, "webImportedAt": "soon", "pendingCloudErase": true }
    """#.utf8)))
    checkEqual(odd.v, 3, "unknown version is kept")
    checkEqual(odd.unknown, ["future": .object(["x": .array([.number(1), .number(2)])]), "note": .string("hi")], "unknown keys are kept")
    checkEqual(odd.jsonValue["future"], .object(["x": .array([.number(1), .number(2)])]), "unknown keys are written back")
    checkEqual(odd.jsonValue["v"], .number(3), "the version is written back")
    checkEqual(odd.dirty, ["a", "b", "c"], "dirty: duplicates, non-strings and empty ids dropped, order kept")
    checkEqual(odd.zoneToken, nil, "a token that is not base64 → nil")
    checkEqual(odd.zoneReady, false, "a non-bool zoneReady → false")
    checkEqual(odd.account, nil, "an empty account → nil")
    checkEqual(odd.pendingAccount, "_other", "pendingAccount")
    checkEqual(odd.seen.keys.sorted(), ["badSys", "ok"], "seen: items without a tag, with an empty tag, not an object or with an empty page id are dropped")
    checkEqual(odd.seen["ok"], SeenRecord(changeTag: "t1"), "seen: sys is optional")
    checkEqual(odd.seen["badSys"], SeenRecord(changeTag: "t2", systemFields: nil), "seen: sys that is not base64 → nil")
    checkEqual(odd.jsonValue["seen"]?["ok"], .object(["tag": .string("t1"), "sys": .null]), "seen without sys is written with null")
    checkEqual(odd.lastSyncAt, nil, "a negative lastSyncAt → nil")
    checkEqual(odd.webImportedAt, nil, "a non-numeric webImportedAt → nil")
    checkEqual(odd.pendingCloudErase, true, "pendingCloudErase true")
    checkEqual(SyncState(json: odd.jsonValue), odd, "odd: round trip")
    checkEqual(SeenRecord(changeTag: "x").systemFields, nil, "SeenRecord default systemFields nil")

    // markDirty / clearDirty.
    var s = SyncState.empty
    s.markDirty("b")
    s.markDirty("a")
    s.markDirty("b")
    checkEqual(s.dirty, ["b", "a"], "markDirty keeps the order and ignores duplicates")
    s.markDirty("")
    checkEqual(s.dirty, ["b", "a"], "markDirty ignores an empty id")
    checkEqual(s.isDirty, true, "isDirty after markDirty")
    s.clearDirty("b")
    checkEqual(s.dirty, ["a"], "clearDirty removes the id")
    s.clearDirty("zzz")
    checkEqual(s.dirty, ["a"], "clearDirty of an unknown id is a no-op")
    s.clearDirty("a")
    checkEqual(s.isDirty, false, "not dirty once cleared")
    checkEqual(SyncState(dirty: ["x", "x", "y"]).dirty, ["x", "y"], "init dedupes dirty")

    // adoptAccount.
    var adopted = state
    adopted.unknown["keep"] = .bool(true)
    adopted.pendingAccount = "_new"
    adopted.pendingCloudErase = true
    adopted.adoptAccount("_new", allLocalPageIds: ["d-2026-10-07", "m1-2026-10", "d-2026-10-07"])
    checkEqual(adopted.account, "_new", "adoptAccount: account")
    checkEqual(adopted.pendingAccount, nil, "adoptAccount: pendingAccount cleared")
    checkEqual(adopted.zoneToken, nil, "adoptAccount: token dropped")
    checkEqual(adopted.seen, [:], "adoptAccount: seen dropped")
    checkEqual(adopted.zoneReady, false, "adoptAccount: zone to be made again")
    checkEqual(adopted.subscriptionReady, false, "adoptAccount: subscription to be made again")
    checkEqual(adopted.dirty, ["d-2026-10-07", "m1-2026-10"], "adoptAccount: every local page is dirty (deduped)")
    checkEqual(adopted.webImportedAt, 1_760_150_000_000, "adoptAccount: webImportedAt kept")
    checkEqual(adopted.unknown["keep"], .bool(true), "adoptAccount: unknown kept")
    checkEqual(adopted.lastSyncAt, state.lastSyncAt, "adoptAccount: lastSyncAt kept")
    checkEqual(adopted.pendingCloudErase, true, "adoptAccount: pendingCloudErase kept")

    // resetAfterErase.
    var erased = state
    erased.resetAfterErase(cloudPending: true)
    checkEqual(erased.dirty, [], "resetAfterErase: nothing dirty")
    checkEqual(erased.seen, [:], "resetAfterErase: nothing seen")
    checkEqual(erased.zoneToken, nil, "resetAfterErase: token dropped")
    checkEqual(erased.pendingCloudErase, true, "resetAfterErase: cloud erase pending")
    checkEqual(erased.webImportedAt, nil, "resetAfterErase: webImportedAt cleared")
    checkEqual(erased.account, state.account, "resetAfterErase: account kept")
    checkEqual(erased.zoneReady, true, "resetAfterErase: zoneReady kept")
    checkEqual(erased.subscriptionReady, true, "resetAfterErase: subscriptionReady kept")
    checkEqual(erased.lastSyncAt, state.lastSyncAt, "resetAfterErase: lastSyncAt kept")
    var erasedOnline = state
    erasedOnline.resetAfterErase(cloudPending: false)
    checkEqual(erasedOnline.pendingCloudErase, false, "resetAfterErase(false): nothing pending")

    // resetAfterZoneLoss.
    var lost = state
    lost.pendingCloudErase = true
    lost.resetAfterZoneLoss(allLocalPageIds: ["y-2026", "m1-2026-10"])
    checkEqual(lost.zoneToken, nil, "resetAfterZoneLoss: token dropped")
    checkEqual(lost.seen, [:], "resetAfterZoneLoss: seen dropped")
    checkEqual(lost.zoneReady, false, "resetAfterZoneLoss: zone to be made again")
    checkEqual(lost.subscriptionReady, false, "resetAfterZoneLoss: subscription to be made again")
    checkEqual(lost.dirty, ["y-2026", "m1-2026-10"], "resetAfterZoneLoss: every local page is dirty")
    checkEqual(lost.account, state.account, "resetAfterZoneLoss: account kept")
    checkEqual(lost.pendingCloudErase, true, "resetAfterZoneLoss: pendingCloudErase kept")
    checkEqual(lost.webImportedAt, state.webImportedAt, "resetAfterZoneLoss: webImportedAt kept")
    checkEqual(lost.pendingAccount, nil, "resetAfterZoneLoss: pendingAccount unchanged")

    // Codec errors.
    var threw = false
    do { _ = try SyncStateCodec.decode(Data("{ not json".utf8)) } catch { threw = true }
    checkEqual(threw, true, "decode throws for broken JSON")
    threw = false
    do { _ = try SyncStateCodec.decode(Data()) } catch { threw = true }
    checkEqual(threw, true, "decode throws for empty data")
    checkEqual(try SyncStateCodec.decode(Data("[]".utf8)), .empty, "decode of a non-object is empty")
    checkEqual(try SyncStateCodec.decode(Data("{\"v\":1}".utf8)), .empty, "decode of {\"v\":1} is empty")
    let keys = state.jsonValue.objectValue?.keys.sorted()
    checkEqual(keys, ["account", "dirty", "lastSyncAt", "pendingAccount", "pendingCloudErase", "seen", "subscriptionReady", "v", "webImportedAt", "zoneReady", "zoneToken"], "every known key is written")
    let bytes = try SyncStateCodec.encode(state)
    let sorted = try JSONValue.parse(bytes).serializedData()
    checkEqual(bytes, sorted, "encode is already the sorted, compact form")
    var token = state
    token.zoneToken = Data([0, 1, 2, 255])
    checkEqual(token.jsonValue["zoneToken"], .string("AAEC/w=="), "token base64")
    checkEqual(SyncState(json: token.jsonValue).zoneToken, Data([0, 1, 2, 255]), "token base64 round trip")

    // InkPage additions for sync (§3.6): liveStrokeIds / contentDiffers.
    var pa = InkPage(pageId: "m1-2026-10")
    pa.add(stroke("z"))
    pa.add(stroke("b"))
    pa.add(stroke("m"))
    checkEqual(pa.liveStrokeIds, ["b", "m", "z"], "liveStrokeIds is sorted")
    var pb = pa
    pb.updatedAt += 5
    pb.unknown["x"] = .bool(true)
    check(pa != pb, "== sees updatedAt / unknown")
    checkEqual(pa.contentDiffers(from: pb), false, "contentDiffers ignores updatedAt and unknown")
    checkEqual(pa.contentDiffers(from: pa), false, "contentDiffers: same page")
    pb.remove(ids: ["m"], at: 1_760_000_002_000)
    checkEqual(pb.liveStrokeIds, ["b", "z"], "liveStrokeIds after a removal")
    checkEqual(pa.contentDiffers(from: pb), true, "contentDiffers: a removed stroke")
    checkEqual(pb.contentDiffers(from: pa), true, "contentDiffers is symmetric")
    var pc = pa
    pc.deleted["ghost"] = 1
    checkEqual(pa.contentDiffers(from: pc), true, "contentDiffers: a tombstone for an id not on the page")
    var pd = pa
    pd.add(stroke("new"))
    checkEqual(pa.contentDiffers(from: pd), true, "contentDiffers: an added stroke")
    var pe = pa
    pe.strokes["z"] = stroke("z", t: 1)
    checkEqual(pa.contentDiffers(from: pe), false, "contentDiffers does not compare the strokes' contents")
    checkEqual(InkPage(pageId: "x").contentDiffers(from: InkPage(pageId: "y")), false, "contentDiffers does not compare the pageId")
    let unknownStroke = InkPage(json: .object(["pageId": .string("m1-2026-10"), "strokes": .object(["u": .object(["id": .string("u"), "tool": .string("brush"), "pts": .array([])])])]))
    checkEqual(unknownStroke.liveStrokeIds, [], "a stroke of an unknown tool is not a live stroke of this version")
    checkEqual(unknownStroke.contentDiffers(from: InkPage(pageId: "m1-2026-10")), true, "but it is content that differs (it is written back)")
} catch {
    check(false, "sync state threw: \(error)")
}

// MARK: - Sync backoff (M4)

section("sync backoff (M4)")

do {
    checkEqual((0...7).map { SyncBackoff.delay(afterFailures: $0) }, [15, 30, 60, 120, 240, 300, 300, 300], "delay doubles from 15 s and caps at 300 s")
    checkEqual(SyncBackoff.delay(afterFailures: -3), 15, "negative failures count as 0")
    checkEqual(SyncBackoff.delay(afterFailures: 30), 300, "30 failures → 300")
    checkEqual(SyncBackoff.delay(afterFailures: 1_000_000), 300, "huge failures → 300 (no overflow)")
    var b = SyncBackoff()
    checkEqual(b.failures, 0, "starts at 0")
    checkEqual(b.nextDelay, 15, "first retry after 15 s")
    b.recordFailure()
    checkEqual(b.failures, 1, "one failure")
    checkEqual(b.nextDelay, 30, "then 30 s")
    b.recordFailure()
    b.recordFailure()
    checkEqual(b.nextDelay, 120, "three failures → 120 s")
    checkEqual(b.nextDelay(serverHint: 600), 600, "a longer server hint wins")
    checkEqual(b.nextDelay(serverHint: 1), 120, "a shorter server hint loses")
    checkEqual(b.nextDelay(serverHint: nil), 120, "no hint → nextDelay")
    checkEqual(SyncBackoff().nextDelay(serverHint: 600), 600, "serverHint 600 at 0 failures = 600")
    checkEqual(SyncBackoff().nextDelay(serverHint: 1), 15, "serverHint 1 at 0 failures = 15")
    checkEqual(SyncBackoff().nextDelay(serverHint: .nan), 15, "a NaN hint is ignored")
    for _ in 0..<100 { b.recordFailure() }
    checkEqual(b.failures, 30, "failures cap at 30")
    checkEqual(b.nextDelay, 300, "capped delay")
    b.reset()
    checkEqual(b.failures, 0, "reset → 0")
    checkEqual(b.nextDelay, 15, "reset → 15 s")
    checkEqual(SyncBackoff(failures: 2).nextDelay, 60, "init with failures")
    checkEqual(SyncBackoff(failures: 99).failures, 30, "init caps at 30")
    checkEqual(SyncBackoff(failures: -1).failures, 0, "init floors at 0")
    checkEqual(SyncBackoff(failures: 2), SyncBackoff(failures: 2), "Equatable")
    checkEqual(SyncBackoff.debounce, 1.5, "debounce 1.5 s")
    checkEqual(SyncBackoff.minimum, 15, "minimum 15 s")
    checkEqual(SyncBackoff.maximum, 300, "maximum 300 s")
    checkEqual(SyncBackoff.maxConflictRetries, 3, "3 conflict retries")
    checkEqual(SyncBackoff.pageFetchCooldown, 30, "page fetch cooldown 30 s")
    checkEqual(SyncBackoff.notificationBudget, 20, "notification budget 20 s")
}

// MARK: - M4b: zoom policy (M4B_CONTRACT §1.1)

section("zoom policy (M4b)")
do {
    checkClose(ZoomPolicy.readableZoom(.month), 0.5, "readable zoom: month 100 / 200", tolerance: 1e-4)
    checkClose(ZoomPolicy.readableZoom(.week), 0.47156, "readable zoom: week 90 / 190.857", tolerance: 1e-4)
    checkClose(ZoomPolicy.readableZoom(.day), 0.56122, "readable zoom: day 330 / 588", tolerance: 1e-4)
    checkClose(ZoomPolicy.readableZoom(.year), 1.33929, "readable zoom: year 150 / 112", tolerance: 1e-4)
    checkEqual(ZoomPolicy.keyColumnWidth(.month), 200, "key column: month")
    checkEqual(ZoomPolicy.keyColumnWidth(.week), 1336.0 / 7, "key column: week")
    checkEqual(ZoomPolicy.keyColumnWidth(.day), 588, "key column: day (the timeline)")
    checkEqual(ZoomPolicy.keyColumnWidth(.year), 112, "key column: year")
    checkEqual(ZoomPolicy.readableColumnPoints(.month), 100, "readable points: month")
    checkEqual(ZoomPolicy.readableColumnPoints(.week), 90, "readable points: week")
    checkEqual(ZoomPolicy.readableColumnPoints(.day), 330, "readable points: day")
    checkEqual(ZoomPolicy.readableColumnPoints(.year), 150, "readable points: year (M4B-22)")
    checkEqual(ZoomPolicy.paperWidth(.month), 1400, "paper width: month")
    checkEqual(ZoomPolicy.paperWidth(.week), 1400, "paper width: week")
    checkEqual(ZoomPolicy.paperWidth(.day), 1000, "paper width: day")
    checkEqual(ZoomPolicy.paperWidth(.year), 1400, "paper width: year")
    checkEqual(ZoomPolicy.fitTolerance, 0.95, "fit tolerance")

    // The table of §1.1 (portrait widths, the Split View edge cases and the landscape 13 inch).
    let readableWeek: CGFloat = 90 / (1336.0 / 7)
    let readableDay: CGFloat = 330.0 / 588
    let readableYear: CGFloat = 150.0 / 112
    let table: [(width: CGFloat, month: CGFloat, week: CGFloat, day: CGFloat, year: CGFloat)] = [
        (375, 0.5, readableWeek, readableDay, readableYear),
        (390, 0.5, readableWeek, readableDay, readableYear),
        (402, 0.5, readableWeek, readableDay, readableYear),
        (664, 0.5, 664.0 / 1400, 0.664, readableYear),          // 1 pt below the 5 % boundary: the month jumps to readable
        (665, 0.475, 665.0 / 1400, 0.665, readableYear),        // exactly 95 % of readable: fit is kept
        (667, 667.0 / 1400, 667.0 / 1400, 0.667, readableYear), // iPhone SE landscape
        (678, 678.0 / 1400, 678.0 / 1400, 0.678, readableYear), // 13 inch 2/3 Split View
        (690, 690.0 / 1400, 690.0 / 1400, 0.69, readableYear),
        (744, 744.0 / 1400, 744.0 / 1400, 0.744, readableYear), // iPad mini
        (834, 834.0 / 1400, 834.0 / 1400, 0.834, readableYear), // iPad 11 inch
        (1024, 1024.0 / 1400, 1024.0 / 1400, 1.024, readableYear), // iPad 13 inch
        (1133, 1133.0 / 1400, 1133.0 / 1400, 1.133, readableYear),
        (1210, 1210.0 / 1400, 1210.0 / 1400, 1.21, readableYear),
        (1366, 1366.0 / 1400, 1366.0 / 1400, 1.366, readableYear), // 13 inch landscape: the year still scrolls
    ]
    for row in table {
        let expected: [(PageKind, CGFloat)] = [(.month, row.month), (.week, row.week), (.day, row.day), (.year, row.year)]
        for (kind, minZ) in expected {
            let fit = row.width / ZoomPolicy.paperWidth(kind)
            let paper = ZoomPolicy.paperWidth(kind)
            checkClose(ZoomPolicy.fitZoom(kind, viewportWidth: row.width), fit, "fitZoom \(kind) at \(row.width)", tolerance: 1e-9)
            checkClose(ZoomPolicy.minZoom(kind, viewportWidth: row.width), minZ, "minZoom \(kind) at \(row.width)", tolerance: 1e-4)
            let maxZ = ZoomPolicy.maxZoom(kind, viewportWidth: row.width)
            checkClose(maxZ, max(4 * fit, 2 * minZ), "maxZoom \(kind) at \(row.width) = max(4 × fit, 2 × min)", tolerance: 1e-4)
            check(ZoomPolicy.minZoom(kind, viewportWidth: row.width) >= fit - 1e-12, "minZoom ≥ fit (\(kind) at \(row.width))")
            check(maxZ >= 2 * ZoomPolicy.minZoom(kind, viewportWidth: row.width) - 1e-12 && maxZ >= 4 * fit - 1e-12, "maxZoom ≥ 2 × min and ≥ 4 × fit (\(kind) at \(row.width))")
            let visible = ZoomPolicy.visibleWidth(kind, viewportWidth: row.width)
            check(visible <= paper, "visibleWidth ≤ paper width (\(kind) at \(row.width))")
            checkClose(visible, min(paper, row.width / minZ), "visibleWidth \(kind) at \(row.width)", tolerance: 0.5)
            checkEqual(ZoomPolicy.bounds(kind, viewportWidth: row.width), ZoomPolicy.Bounds(fit: ZoomPolicy.fitZoom(kind, viewportWidth: row.width), min: ZoomPolicy.minZoom(kind, viewportWidth: row.width), max: maxZ), "bounds \(kind) at \(row.width)")
        }
    }
    // The lu that fit at minZoom (the table's last column).
    let visibleTable: [(width: CGFloat, month: CGFloat, week: CGFloat, day: CGFloat, year: CGFloat)] = [
        (402, 804, 852, 716, 300),
        (390, 780, 827, 695, 291),
        (744, 1400, 1400, 1000, 555),
        (834, 1400, 1400, 1000, 623),
        (1024, 1400, 1400, 1000, 765),
        (1366, 1400, 1400, 1000, 1020),
        (678, 1400, 1400, 1000, 506),
        (690, 1400, 1400, 1000, 515),
        (667, 1400, 1400, 1000, 498),
        (664, 1328, 1400, 1000, 496),
    ]
    for row in visibleTable {
        checkClose(ZoomPolicy.visibleWidth(.month, viewportWidth: row.width), row.month, "visible lu: month at \(row.width)", tolerance: 1)
        checkClose(ZoomPolicy.visibleWidth(.week, viewportWidth: row.width), row.week, "visible lu: week at \(row.width)", tolerance: 1)
        checkClose(ZoomPolicy.visibleWidth(.day, viewportWidth: row.width), row.day, "visible lu: day at \(row.width)", tolerance: 1)
        checkClose(ZoomPolicy.visibleWidth(.year, viewportWidth: row.width), row.year, "visible lu: year at \(row.width)", tolerance: 1)
    }
    checkEqual(ZoomPolicy.visibleWidth(.month, viewportWidth: 744), 1400, "visibleWidth is exactly the paper's width when fit is the minimum")
    checkEqual(ZoomPolicy.visibleWidth(.day, viewportWidth: 1024), 1000, "visibleWidth is exactly the paper's width (day)")
    // The 5 % boundary and the maxZoom examples.
    check(ZoomPolicy.minZoom(.month, viewportWidth: 664) > ZoomPolicy.fitZoom(.month, viewportWidth: 664), "664 pt month: readable beats fit")
    checkEqual(ZoomPolicy.minZoom(.month, viewportWidth: 665), ZoomPolicy.fitZoom(.month, viewportWidth: 665), "665 pt month: fit is kept (the exact boundary)")
    checkEqual(ZoomPolicy.minZoom(.week, viewportWidth: 744), ZoomPolicy.fitZoom(.week, viewportWidth: 744), "iPad mini week: fit")
    checkClose(ZoomPolicy.maxZoom(.month, viewportWidth: 402), 1.1486, "iPhone month maxZoom = 4 × fit", tolerance: 1e-3)
    checkClose(ZoomPolicy.maxZoom(.year, viewportWidth: 402), 2.6786, "iPhone year maxZoom = 2 × min", tolerance: 1e-3)
    checkClose(ZoomPolicy.maxZoom(.year, viewportWidth: 1024), 2.9257, "13 inch year maxZoom = 4 × fit", tolerance: 1e-3)
    checkClose(ZoomPolicy.maxZoom(.week, viewportWidth: 402), 1.1486, "iPhone week maxZoom = 4 × fit", tolerance: 1e-3)
    checkClose(ZoomPolicy.maxZoom(.day, viewportWidth: 402), 1.608, "iPhone day maxZoom = 4 × fit", tolerance: 1e-3)
    // Bounds.
    let b = ZoomPolicy.Bounds(fit: 0.3, min: 0.5, max: 1.2)
    checkEqual(b.fit, 0.3, "Bounds.fit")
    checkEqual(b.min, 0.5, "Bounds.min")
    checkEqual(b.max, 1.2, "Bounds.max")
    checkEqual(b.clamped(.nan), 0.5, "clamped: NaN → min")
    checkEqual(b.clamped(0.1), 0.5, "clamped: below → min")
    checkEqual(b.clamped(5), 1.2, "clamped: above → max")
    checkEqual(b.clamped(0.8), 0.8, "clamped: inside → itself")
    checkEqual(b.clamped(0.5), 0.5, "clamped: min → min")
    checkEqual(b.clamped(1.2), 1.2, "clamped: max → max")
    checkEqual(b.clamped(.infinity), 1.2, "clamped: +∞ → max")
    checkEqual(b.clamped(-.infinity), 0.5, "clamped: −∞ → min")
    checkEqual(b, ZoomPolicy.Bounds(fit: 0.3, min: 0.5, max: 1.2), "Bounds is Equatable")
    checkEqual(b == ZoomPolicy.Bounds(fit: 0.3, min: 0.5, max: 1.3), false, "Bounds inequality")
    let iphoneMonth = ZoomPolicy.bounds(.month, viewportWidth: 402)
    checkEqual(iphoneMonth.clamped(0.2), 0.5, "iPhone month: a pinch below minZoom clamps to 0.5")
    checkClose(iphoneMonth.clamped(3), iphoneMonth.max, "iPhone month: above maxZoom clamps to max")
    // Widths that are not usable: fit and min fall back to readable.
    for kind in PageKind.allCases {
        let readable = ZoomPolicy.readableZoom(kind)
        for bad in [CGFloat.nan, 0, -1, .infinity, -.infinity] {
            checkEqual(ZoomPolicy.fitZoom(kind, viewportWidth: bad), readable, "fitZoom \(kind) at \(bad) → readable")
            checkEqual(ZoomPolicy.minZoom(kind, viewportWidth: bad), readable, "minZoom \(kind) at \(bad) → readable")
            checkEqual(ZoomPolicy.maxZoom(kind, viewportWidth: bad), 4 * readable, "maxZoom \(kind) at \(bad) → 4 × readable")
            checkEqual(ZoomPolicy.visibleWidth(kind, viewportWidth: bad), 0, "visibleWidth \(kind) at \(bad) → 0")
        }
    }
    // PaperViewport.
    let v = PaperViewport(offsetX: 100, zoom: 0.5, width: 402)
    checkEqual(v.x(ofPaper: 400), 100, "x(ofPaper:) = lu × zoom − offsetX")
    checkEqual(v.x(ofPaper: 0), -100, "x(ofPaper: 0) = −offsetX")
    checkEqual(v.x(ofPaper: 1400), 600, "x(ofPaper: 1400)")
    checkEqual(v.width(ofPaper: 200), 100, "width(ofPaper:) = lu × zoom")
    checkEqual(v.width(ofPaper: 0), 0, "width(ofPaper: 0)")
    checkEqual(v.offsetX, 100, "offsetX")
    checkEqual(v.zoom, 0.5, "zoom")
    checkEqual(v.width, 402, "width")
    checkEqual(PaperViewport.zero, PaperViewport(offsetX: 0, zoom: 1, width: 0), ".zero")
    checkEqual(PaperViewport.zero.x(ofPaper: 50), 50, ".zero maps lu to pt 1:1")
    checkEqual(PaperViewport.zero.width, 0, ".zero has width 0 (the views substitute `initial`)")
    checkEqual(v == PaperViewport.zero, false, "PaperViewport inequality")
    checkEqual(v, PaperViewport(offsetX: 100, zoom: 0.5, width: 402), "PaperViewport is Equatable")
    checkEqual(PaperViewport.initial(.month, viewportWidth: 402), PaperViewport(offsetX: 0, zoom: 0.5, width: 402), "initial(.month, 402) = (0, 0.5, 402)")
    checkClose(PaperViewport.initial(.year, viewportWidth: 1024).zoom, readableYear, "initial(.year, 1024).zoom = readable")
    checkEqual(PaperViewport.initial(.year, viewportWidth: 1024).width, 1024, "initial(.year, 1024).width")
    checkEqual(PaperViewport.initial(.year, viewportWidth: 1024).offsetX, 0, "initial offsetX is 0")
    checkEqual(PaperViewport.initial(.week, viewportWidth: 744).zoom, 744.0 / 1400, "initial(.week, 744).zoom = fit")
    checkEqual(PaperViewport.initial(.month, viewportWidth: 0), PaperViewport(offsetX: 0, zoom: 0.5, width: 0), "initial at width 0: readable zoom, width 0")
    checkEqual(PaperViewport.initial(.month, viewportWidth: .nan), PaperViewport(offsetX: 0, zoom: 0.5, width: 0), "initial at NaN: no NaN in the viewport")
    checkEqual(PaperViewport.initial(.month, viewportWidth: -3), PaperViewport(offsetX: 0, zoom: 0.5, width: 0), "initial at a negative width")
    checkEqual(PaperViewport.initial(.month, viewportWidth: 402).x(ofPaper: 1400), 700, "the first frame: the paper's right edge at 700 pt")
}

// MARK: - M4b: initial horizontal position (M4B_CONTRACT §1.2)

section("initial scroll x (M4b)")
do {
    func sx(_ page: any PageLayout, _ now: Date, _ visible: CGFloat) -> CGFloat {
        PageNavigation.initialScrollX(page, now: now, calendar: tokyo, visibleWidth: visible)
    }
    let month = layout([]) // October 2026: the grid is 9/28 … 11/8
    checkEqual(sx(month, demoNow, 804), 0, "month: Wednesday's column (ends at 600) fits in 804 → 0")
    checkEqual(sx(month, october(8), 804), 0, "month: Thursday's column (ends at 800) fits")
    checkEqual(sx(month, october(9), 804), 196, "month: Friday → 1000 − 804")
    checkEqual(sx(month, october(10), 804), 396, "month: Saturday → 1200 − 804")
    checkEqual(sx(month, october(11), 804), 596, "month: Sunday → 1400 − 804")
    checkEqual(sx(month, october(11), 780), 620, "month: Sunday on a 390 pt iPhone → 1400 − 780")
    checkEqual(sx(month, date(2026, 11, 8), 804), 596, "month: 11/8, the grid's last cell (Sunday)")
    checkEqual(sx(month, date(2026, 9, 28), 804), 0, "month: 9/28, the grid's first cell")
    checkEqual(sx(month, date(2026, 12, 25), 804), 0, "month: today not on the grid → 0")
    checkEqual(sx(month, date(2025, 10, 11), 804), 0, "month: the same date of another year → 0")
    checkEqual(sx(month, october(11), 1400), 0, "month: everything visible → 0")
    checkEqual(sx(month, october(11), 2000), 0, "month: a viewport wider than the paper → 0")
    checkEqual(sx(month, october(11), 1399), 1, "month: 1 lu short → 1")
    let week = weekLayout([])
    checkEqual(sx(week, demoNow, 852), 0, "week: Wednesday's column (ends at 636.6) fits in 852 → 0")
    checkEqual(sx(week, october(8), 852), 0, "week: Thursday's column (ends at 827.4) fits")
    checkClose(sx(week, october(9), 852), 64 + 5 * colW - 852, "week: Friday → 166.3")
    checkClose(sx(week, october(10), 852), 64 + 6 * colW - 852, "week: Saturday → 357.1")
    checkClose(sx(week, october(11), 852), 64 + 7 * colW - 852, "week: Sunday → 548")
    checkClose(sx(week, october(11), 852), 548, "week: Sunday → 548 (the number of §1.2)", tolerance: 0.5)
    checkEqual(sx(week, october(12), 852), 0, "week: today not in the week → 0")
    checkEqual(sx(weekLayout([], focus: day(2026, 10, 12)), demoNow, 852), 0, "week: another week's page → 0")
    checkEqual(sx(week, october(11), 1400), 0, "week: everything visible → 0")
    checkEqual(sx(week, october(11), 1600), 0, "week: a viewport wider than the paper → 0")
    let year = yearLayout([])
    checkEqual(sx(year, demoNow, 300.2), 1064, "year: October's column on an iPhone (1064 < 1400 − 300.2)")
    checkClose(sx(year, demoNow, 764.6), 1400 - 764.6, "year: 13 inch → clamped to the paper's right edge (635.4)")
    checkClose(sx(year, demoNow, 555.5), 1400 - 555.5, "year: iPad mini → 844.5")
    checkEqual(sx(year, demoNow, 1400), 0, "year: everything visible → 0")
    checkEqual(sx(year, date(2026, 1, 15), 300.2), 56, "year: January → the gutter's width")
    checkEqual(sx(year, date(2026, 2, 1), 300.2), 168, "year: February → 56 + 112")
    checkClose(sx(year, date(2026, 12, 15), 300.2), 1400 - 300.2, "year: December → clamped to the right edge")
    checkEqual(sx(year, date(2026, 6, 1), 1400), 0, "year: June, everything visible → 0")
    checkEqual(sx(year, date(2025, 10, 7), 300.2), 0, "year: last year → 0")
    checkEqual(sx(year, date(2027, 10, 7), 300.2), 0, "year: next year → 0")
    checkEqual(sx(yearLayout([], year: 2027), demoNow, 300.2), 0, "year: another year's page → 0")
    let dayPage = dayLayout([])
    checkEqual(sx(dayPage, demoNow, 716), 0, "day: always 0 (iPhone)")
    checkEqual(sx(dayPage, demoNow, 1000), 0, "day: always 0 (everything visible)")
    checkEqual(sx(dayPage, demoNow, 100), 0, "day: always 0 (narrow)")
    checkEqual(sx(dayLayout([], focus: day(2026, 10, 8)), demoNow, 716), 0, "day: not today → 0")
    for bad in [CGFloat.nan, 0, -5, .infinity] {
        checkEqual(sx(month, october(11), bad), 0, "month: visibleWidth \(bad) → 0")
        checkEqual(sx(week, october(11), bad), 0, "week: visibleWidth \(bad) → 0")
        checkEqual(sx(year, demoNow, bad), 0, "year: visibleWidth \(bad) → 0")
        checkEqual(sx(dayPage, demoNow, bad), 0, "day: visibleWidth \(bad) → 0")
    }
    checkEqual(PageNavigation.initialScrollX(dayPage, now: demoNow, visibleWidth: 716), 0, "the device-calendar overload (day)")
    // With the real `ZoomPolicy.visibleWidth` of the devices.
    checkEqual(sx(month, october(11), ZoomPolicy.visibleWidth(.month, viewportWidth: 402)), 596, "iPhone 17 month, Sunday → 596")
    checkClose(sx(week, october(11), ZoomPolicy.visibleWidth(.week, viewportWidth: 402)), 548, "iPhone 17 week, Sunday → 548", tolerance: 1)
    checkEqual(sx(year, demoNow, ZoomPolicy.visibleWidth(.year, viewportWidth: 402)), 1064, "iPhone 17 year → 1064")
    checkClose(sx(year, demoNow, ZoomPolicy.visibleWidth(.year, viewportWidth: 1024)), 635.4, "13 inch year → 635.4", tolerance: 1)
    checkClose(sx(year, demoNow, ZoomPolicy.visibleWidth(.year, viewportWidth: 744)), 844.5, "iPad mini year → 844.5", tolerance: 1)
    checkEqual(sx(month, october(11), ZoomPolicy.visibleWidth(.month, viewportWidth: 744)), 0, "iPad mini month: fit → 0")
}

// MARK: - M4b: the fixed all-day band (M4B_CONTRACT §2.1 / §2.2)

section("all-day band (M4b)")
do {
    let monday = day(2026, 10, 5)
    let band = AllDayBandEngine.week(monday: monday, events: demo, now: demoNow, calendar: tokyo)
    checkEqual(band, weekLayout(demo).allDayBand, "the engine and the week page agree")
    checkEqual(band.kind, .week, "kind")
    checkEqual(band.days, (5...11).map { day(2026, 10, $0) }, "days")
    checkEqual(band.tones, [.normal, .normal, .normal, .normal, .normal, .saturday, .sundayOrHoliday], "tones of 10/5 … 10/11")
    checkEqual(band.tones[5], .saturday, "10/10 → .saturday")
    checkEqual(band.tones[6], .sundayOrHoliday, "10/11 → .sundayOrHoliday")
    checkEqual(band.paperWidth, 1400, "paper width")
    checkEqual(band.gutter, 64, "gutter")
    checkEqual(band.columnWidth, colW, "column width")
    checkEqual(band.columnMinX.count, 7, "7 column origins")
    for i in 0..<7 {
        checkClose(band.columnMinX[i], 64 + CGFloat(i) * colW, "columnMinX[\(i)]")
    }
    checkEqual(band.laneCount, 1, "one lane")
    checkEqual(band.todayColumn, 2, "today column")
    checkEqual(band.bars.map(\.title), ["キャンプ", "締切", "家族旅行"], "bars by lane, then start column")
    checkEqual(band.bars.map(\.id), band.bars.map(\.eventId), "Identifiable: id == eventId")
    let expected: [(title: String, lane: Int, startCol: Int, endCol: Int, left: Bool, right: Bool, minX: CGFloat, maxX: CGFloat, color: String)] = [
        ("キャンプ", 0, 0, 0, true, false, 64, 64 + colW - 3, demoColors[1]),
        ("締切", 0, 2, 2, false, false, 64 + 2 * colW + 3, 64 + 3 * colW - 3, demoColors[2]),
        ("家族旅行", 0, 4, 6, false, true, 64 + 4 * colW + 3, 1400, demoColors[1]),
    ]
    for (i, e) in expected.enumerated() {
        let bar = band.bars[i]
        checkEqual(bar.title, e.title, "bar \(i) title")
        checkEqual(bar.eventId, demoId(e.title), "\(e.title) event id")
        checkEqual(bar.lane, e.lane, "\(e.title) lane")
        checkEqual(bar.startCol, e.startCol, "\(e.title) start column")
        checkEqual(bar.endCol, e.endCol, "\(e.title) end column")
        checkEqual(bar.continuesLeft, e.left, "\(e.title) continuesLeft")
        checkEqual(bar.continuesRight, e.right, "\(e.title) continuesRight")
        checkClose(bar.minX, e.minX, "\(e.title) minX")
        checkClose(bar.maxX, e.maxX, "\(e.title) maxX")
        checkEqual(bar.colorHex, e.color, "\(e.title) colour")
    }
    checkEqual(AllDayBandEngine.week(monday: day(2026, 10, 7), events: demo, now: demoNow, calendar: tokyo), band, "a non-Monday is normalized to its Monday")
    checkEqual(AllDayBandEngine.week(monday: day(2026, 10, 11), events: demo, now: demoNow, calendar: tokyo), band, "a Sunday is normalized to its Monday")
    let none = AllDayBandEngine.week(monday: monday, events: [], now: demoNow, calendar: tokyo)
    checkEqual(none.laneCount, 0, "empty week: no lanes")
    checkEqual(none.bars.count, 0, "empty week: no bars")
    checkEqual(none.todayColumn, 2, "empty week: today column is still set")
    checkEqual(none.tones, band.tones, "empty week: the same tones")
    checkEqual(none.days, band.days, "empty week: the same days")
    checkEqual(none == band, false, "a band with bars differs from an empty one")
    checkEqual(AllDayBandEngine.week(monday: monday, events: [timed("t", 7, 9, 0, 10, 0)], now: demoNow, calendar: tokyo).laneCount, 0, "a timed event is not in the band")
    let blank = AllDayBandLayout.empty(kind: .week, days: band.days)
    checkEqual(blank.kind, .week, "empty(): kind")
    checkEqual(blank.laneCount, 0, "empty(): no lanes")
    checkEqual(blank.bars.count, 0, "empty(): no bars")
    checkEqual(blank.todayColumn, nil, "empty(): no today column")
    checkEqual(blank.tones, band.tones, "empty(): tones from the days")
    checkEqual(blank.columnMinX, band.columnMinX, "empty(): column origins")
    checkEqual(blank.gutter, 64, "empty(): gutter")
    checkEqual(blank.paperWidth, 1400, "empty(): paper width")
    checkEqual(blank.columnWidth, colW, "empty(): column width")
    checkEqual(AllDayBandLayout.empty(kind: .month, days: band.days).gutter, 64, "empty(): any kind but .day takes the week's geometry")
    // Lanes: a second event over Wednesday, and a pile of 40 (no thinning).
    let stacked = AllDayBandEngine.week(monday: monday, events: demo + [allDay("x", 6, 9, title: "重なる")], now: demoNow, calendar: tokyo)
    checkEqual(stacked.laneCount, 2, "two lanes")
    checkEqual(stacked.bars.map(\.title), ["キャンプ", "重なる", "家族旅行", "締切"], "lane 0 first, then lane 1, each by start column")
    checkEqual(stacked.bars.map(\.lane), [0, 0, 0, 1], "the longer span takes lane 0 and 締切 moves to lane 1; 家族旅行 (from Friday) still fits in lane 0")
    checkEqual(stacked.bars[1].startCol, 1, "重なる starts Tuesday")
    checkEqual(stacked.bars[1].endCol, 3, "重なる (10/6 … 10/9 exclusive) ends Thursday")
    checkClose(stacked.bars[1].minX, 64 + colW + 3, "重なる minX")
    checkClose(stacked.bars[1].maxX, 64 + 4 * colW - 3, "重なる maxX")
    checkEqual(stacked.bars[3].lane, 1, "締切 is in lane 1")
    checkEqual(stacked.bars[3].startCol, 2, "締切 is still on Wednesday")
    var pile: [LayoutEvent] = []
    for i in 0..<40 { pile.append(allDay("pile\(i)", 5, 6, title: "p\(i)")) }
    let piled = AllDayBandEngine.week(monday: monday, events: pile, now: demoNow, calendar: tokyo)
    checkEqual(piled.laneCount, 40, "40 lanes, no thinning")
    checkEqual(piled.bars.count, 40, "40 bars")
    checkEqual(piled.bars.map(\.lane), Array(0..<40), "one lane each, in order")
    checkEqual(Set(piled.bars.map(\.startCol)), [0], "all on Monday")
    checkEqual(Set(piled.bars.map(\.endCol)), [0], "all end on Monday")
    // The holiday week (10/12 スポーツの日).
    let holidayWeek = AllDayBandEngine.week(monday: day(2026, 10, 12), events: demo, now: demoNow, calendar: tokyo)
    checkEqual(holidayWeek.tones, [.sundayOrHoliday, .normal, .normal, .normal, .normal, .saturday, .sundayOrHoliday], "tones of the week of 10/12")
    checkEqual(holidayWeek.todayColumn, nil, "no today column in another week")
    checkEqual(holidayWeek.days.first, day(2026, 10, 12), "the week starts on the holiday")
    checkEqual(holidayWeek.bars.map(\.title), ["家族旅行", "ゴミの日", "健康診断", "誕生日", "資料提出締切"], "the trip's tail, then the four events of 10/16 (one lane each, by title)")
    checkEqual(holidayWeek.bars.map(\.lane), [0, 0, 1, 2, 3], "the first 10/16 event shares lane 0 with the tail (which ends Tuesday)")
    checkEqual(holidayWeek.laneCount, 4, "4 lanes in the week of 10/12")
    checkEqual(Set(holidayWeek.bars.dropFirst().map(\.startCol)), [4], "the 10/16 events are in column 4 (Friday)")
    checkEqual(holidayWeek.bars[0].startCol, 0, "the tail starts Monday")
    checkEqual(holidayWeek.bars[0].endCol, 1, "the tail ends Tuesday 10/13")
    checkEqual(holidayWeek.bars[0].continuesLeft, true, "the tail continues left")
    checkEqual(holidayWeek.bars[0].continuesRight, false, "the tail ends in the week")
    checkClose(holidayWeek.bars[0].minX, 64, "the tail's minX (open end)")
    checkClose(holidayWeek.bars[0].maxX, 64 + 2 * colW - 3, "the tail's maxX")
    checkEqual(weekLayout([], focus: day(2026, 10, 12)).allDayBand.tones, holidayWeek.tones, "the week page carries the same tones")
    // The day band.
    let dayBand = AllDayBandEngine.day(day(2026, 10, 7), events: demo, now: demoNow, calendar: tokyo)
    checkEqual(dayBand, dayLayout(demo).allDayBand, "the engine and the day page agree")
    checkEqual(dayBand.kind, .day, "day: kind")
    checkEqual(dayBand.days, [day(2026, 10, 7)], "day: days")
    checkEqual(dayBand.tones, [.normal], "day 10/7: tones")
    checkEqual(dayBand.paperWidth, 1000, "day: paper width")
    checkEqual(dayBand.gutter, 72, "day: gutter")
    checkEqual(dayBand.columnMinX, [72], "day: column origin")
    checkEqual(dayBand.columnWidth, 588, "day: column width")
    checkEqual(dayBand.laneCount, 1, "day: one lane")
    checkEqual(dayBand.todayColumn, 0, "day: today column")
    checkEqual(dayBand.bars.count, 1, "day: one bar")
    checkEqual(dayBand.bars[0].title, "締切", "day: 締切")
    checkEqual(dayBand.bars[0].eventId, demoId("締切"), "day: event id")
    checkEqual(dayBand.bars[0].minX, 76, "day: minX 72 + 4")
    checkEqual(dayBand.bars[0].maxX, 648, "day: maxX 660 − 12")
    checkEqual(dayBand.bars[0].lane, 0, "day: lane 0")
    checkEqual(dayBand.bars[0].startCol, 0, "day: start column 0")
    checkEqual(dayBand.bars[0].endCol, 0, "day: end column 0")
    checkEqual(dayBand.bars[0].continuesLeft, false, "day: starts today")
    checkEqual(dayBand.bars[0].continuesRight, false, "day: ends today")
    checkEqual(dayBand.bars[0].colorHex, demoColors[2], "day: colour")
    let sunday = AllDayBandEngine.day(day(2026, 10, 11), events: demo, now: demoNow, calendar: tokyo)
    checkEqual(sunday.tones, [.sundayOrHoliday], "day 10/11: tones")
    checkEqual(sunday.todayColumn, nil, "day 10/11: not today")
    checkEqual(sunday.bars.map(\.title), ["家族旅行"], "day 10/11: the trip")
    checkEqual(sunday.bars[0].continuesLeft, true, "day 10/11: the trip started before")
    checkEqual(sunday.bars[0].continuesRight, true, "day 10/11: the trip continues after")
    checkEqual(AllDayBandEngine.day(day(2026, 10, 12), events: [], now: demoNow, calendar: tokyo).tones, [.sundayOrHoliday], "day 10/12 (holiday): tones")
    checkEqual(AllDayBandEngine.day(day(2026, 10, 10), events: [], now: demoNow, calendar: tokyo).tones, [.saturday], "day 10/10: tones")
    checkEqual(AllDayBandEngine.day(day(2026, 10, 8), events: demo, now: demoNow, calendar: tokyo).laneCount, 0, "day 10/8: nothing all-day")
    let busy = AllDayBandEngine.day(day(2026, 10, 7), events: demo + [allDay("a", 7, 8, title: "a"), allDay("b", 1, 20, title: "b")], now: demoNow, calendar: tokyo)
    checkEqual(busy.laneCount, 3, "busy day: 3 lanes")
    checkEqual(busy.bars.map(\.title), ["b", "a", "締切"], "busy day: earlier start first, then title")
    checkEqual(busy.bars.map(\.lane), [0, 1, 2], "busy day: lane = display order")
    checkEqual(busy.bars.map(\.minX), [76, 76, 76], "busy day: every bar spans the timeline column")
    checkEqual(busy.bars[0].continuesLeft, true, "busy day: b started before")
    checkEqual(busy.bars[0].continuesRight, true, "busy day: b continues after")
    let blankDay = AllDayBandLayout.empty(kind: .day, days: [day(2026, 10, 7)])
    checkEqual(blankDay.kind, .day, "empty(.day): kind")
    checkEqual(blankDay.tones, [.normal], "empty(.day): tones")
    checkEqual(blankDay.gutter, 72, "empty(.day): gutter")
    checkEqual(blankDay.paperWidth, 1000, "empty(.day): paper width")
    checkEqual(blankDay.columnMinX, [72], "empty(.day): column origin")
    checkEqual(blankDay.columnWidth, 588, "empty(.day): column width")
    checkEqual(blankDay.laneCount, 0, "empty(.day): no lanes")
    checkEqual(blankDay.todayColumn, nil, "empty(.day): no today column")

    // Metrics (pt) of the fixed band.
    typealias M = AllDayBandMetrics
    checkEqual(M.minLanePoints, 18, "min lane 18 pt")
    checkEqual(M.minGapPoints, 2, "min gap 2 pt")
    checkEqual(M.minTextPoints, 11, "min text 11 pt")
    checkEqual(M.topPadPoints, 3, "top pad 3 pt")
    checkEqual(M.bottomPadPoints, 4, "bottom pad 4 pt")
    checkEqual(M.labelPoints, 10, "「終日」 10 pt")
    checkEqual(M.heightCap, 0.35, "height cap 35 %")
    checkEqual(M.gapLu(.week), 3, "week gap 3 lu")
    checkEqual(M.gapLu(.day), 2, "day gap 2 lu")
    checkEqual(M.textLu(.week), 13, "week text 13 lu")
    checkEqual(M.textLu(.day), 14, "day text 14 lu")
    let iphone = M.metrics(kind: .week, laneCount: 1, zoom: 0.4716, pageHeight: 630)
    checkEqual(iphone.lane, 18, "iPhone week: lane floor 18 (10.4 lu × zoom)")
    checkEqual(iphone.gap, 2, "iPhone week: gap floor 2")
    checkEqual(iphone.text, 11, "iPhone week: text floor 11")
    checkEqual(iphone.contentHeight, 25, "iPhone week, 1 lane: 3 + 18 + 4 = 25")
    checkEqual(iphone.visibleHeight, 25, "iPhone week, 1 lane: all visible")
    checkEqual(iphone.scrollsInside, false, "iPhone week, 1 lane: no inner scroll")
    checkEqual(iphone.laneTop(0), 3, "laneTop(0) = top pad")
    checkEqual(iphone.laneTop(1), 23, "laneTop(1) = 3 + 20")
    checkEqual(iphone.laneTop(2), 43, "laneTop(2) = 3 + 40")
    checkEqual(iphone, M.Metrics(lane: 18, gap: 2, text: 11, contentHeight: 25, visibleHeight: 25, scrollsInside: false), "Metrics is Equatable (memberwise init)")
    let one = M.metrics(kind: .week, laneCount: 1, zoom: 1, pageHeight: 800)
    checkEqual(one.lane, 22, "zoom 1: lane 22")
    checkEqual(one.gap, 3, "zoom 1: gap 3")
    checkEqual(one.text, 13, "zoom 1: text 13")
    checkEqual(one.contentHeight, 29, "zoom 1, 1 lane: 3 + 22 + 4 = 29")
    checkEqual(one.laneTop(1), 28, "zoom 1: laneTop(1) = 3 + 25")
    let ipad = M.metrics(kind: .week, laneCount: 3, zoom: 0.7314, pageHeight: 1000)
    checkEqual(ipad.lane, 18, "13 inch week: lane floor 18 (16.1)")
    checkClose(ipad.gap, 2.1942, "13 inch week: gap 3 × 0.7314", tolerance: 1e-3)
    checkEqual(ipad.text, 11, "13 inch week: text floor 11 (9.5)")
    checkClose(ipad.contentHeight, 65.39, "13 inch week, 3 lanes: 3 + 54 + 4.39 + 4", tolerance: 1e-2)
    checkClose(ipad.visibleHeight, 65.39, "13 inch week, 3 lanes: all visible", tolerance: 1e-2)
    checkEqual(ipad.scrollsInside, false, "13 inch week, 3 lanes: no inner scroll")
    checkClose(ipad.laneTop(2), 3 + 2 * (18 + 3 * 0.7314), "13 inch week: laneTop(2)", tolerance: 1e-6)
    let ten = M.metrics(kind: .week, laneCount: 10, zoom: 0.4716, pageHeight: 630)
    checkEqual(ten.contentHeight, 205, "10 lanes: 3 + 180 + 18 + 4 = 205")
    checkEqual(ten.visibleHeight, 205, "10 lanes: under the cap (220)")
    checkEqual(ten.scrollsInside, false, "10 lanes: no inner scroll")
    let eleven = M.metrics(kind: .week, laneCount: 11, zoom: 0.4716, pageHeight: 630)
    checkEqual(eleven.contentHeight, 225, "11 lanes: 3 + 198 + 20 + 4 = 225")
    checkEqual(eleven.visibleHeight, 220, "11 lanes: capped at floor(0.35 × 630)")
    checkEqual(eleven.scrollsInside, true, "11 lanes: inner scroll")
    let zero = M.metrics(kind: .week, laneCount: 0, zoom: 0.4716, pageHeight: 630)
    checkEqual(zero.contentHeight, 0, "0 lanes: content 0")
    checkEqual(zero.visibleHeight, 0, "0 lanes: visible 0")
    checkEqual(zero.scrollsInside, false, "0 lanes: no inner scroll")
    checkEqual(zero.lane, 18, "0 lanes: the lane size does not depend on the count")
    checkEqual(M.metrics(kind: .week, laneCount: -2, zoom: 0.4716, pageHeight: 630), zero, "a negative lane count counts as 0")
    let dayMetrics = M.metrics(kind: .day, laneCount: 1, zoom: 0.5612, pageHeight: 600)
    checkEqual(dayMetrics.lane, 18, "iPhone day: lane floor 18")
    checkEqual(dayMetrics.gap, 2, "iPhone day: gap 2 lu × 0.5612 = 1.1 → floor 2")
    checkEqual(dayMetrics.text, 11, "iPhone day: text 14 × 0.5612 = 7.9 → floor 11")
    checkEqual(dayMetrics.contentHeight, 25, "iPhone day, 1 lane: 25")
    let dayBig = M.metrics(kind: .day, laneCount: 2, zoom: 2, pageHeight: 2000)
    checkEqual(dayBig.lane, 44, "day zoom 2: lane 44")
    checkEqual(dayBig.gap, 4, "day zoom 2: gap 4")
    checkEqual(dayBig.text, 28, "day zoom 2: text 28")
    checkEqual(dayBig.contentHeight, 99, "day zoom 2, 2 lanes: 3 + 88 + 4 + 4 = 99")
    let weekBig = M.metrics(kind: .week, laneCount: 2, zoom: 2, pageHeight: 2000)
    checkEqual(weekBig.gap, 6, "week zoom 2: gap 6")
    checkEqual(weekBig.text, 26, "week zoom 2: text 26")
    checkEqual(weekBig.contentHeight, 101, "week zoom 2, 2 lanes: 3 + 88 + 6 + 4 = 101")
    for bad in [CGFloat.nan, 0, -1, .infinity] {
        checkEqual(M.metrics(kind: .week, laneCount: 1, zoom: bad, pageHeight: 800), one, "zoom \(bad) counts as 1")
    }
    for bad in [CGFloat.nan, 0, -100, .infinity] {
        let m = M.metrics(kind: .week, laneCount: 1, zoom: 1, pageHeight: bad)
        checkEqual(m.visibleHeight, 0, "pageHeight \(bad) counts as 0: nothing visible")
        checkEqual(m.contentHeight, 29, "pageHeight \(bad): the content height is unaffected")
        checkEqual(m.scrollsInside, true, "pageHeight \(bad): the content does not fit")
    }
    let capped = M.metrics(kind: .week, laneCount: 5, zoom: 1, pageHeight: 100)
    checkEqual(capped.contentHeight, 129, "5 lanes at zoom 1: 3 + 110 + 12 + 4 = 129")
    checkEqual(capped.visibleHeight, 35, "capped at floor(0.35 × 100) = 35")
    checkEqual(capped.scrollsInside, true, "capped: inner scroll")
    checkEqual(M.metrics(kind: .week, laneCount: 11, zoom: 0.4716, pageHeight: 631).visibleHeight, 220, "the cap is floored (0.35 × 631 = 220.85)")
    checkEqual(M.metrics(kind: .month, laneCount: 1, zoom: 1, pageHeight: 800), one, "any kind but .day takes the week's lu")
}

// MARK: - M4b: moving the band's handwriting onto the grid (M4B_CONTRACT §3.1 / §3.5)

section("band migration (M4b)")
do {
    let wed = day(2026, 10, 7)
    var old = InkPage.empty(pageId: "w-2026-10-05")
    old.add(stroke("a1", cell: .allDay(wed), points: [point(12, 40), point(17, 43, dt: 16), point(22, 40, dt: 32)]))
    old.add(stroke("a2", cell: .allDay(day(2026, 10, 5)), tool: .marker, color: "#fde047", t: 1_760_150_400_200, dev: nil, points: [point(5, -5, size: 18), point(10, 2, dt: 16, size: 18)]))
    old.add(stroke("a3", cell: .grid, points: [point(300, 500)]))
    old.add(stroke("a4", cell: .allDay(day(2026, 10, 19)), points: [point(0, 0)]))
    old.add(stroke("a5", cell: CellKey(raw: "allday:xx"), points: [point(1, 1)]))
    old.remove(ids: ["zz"], at: 1_760_000_000_500)
    let updatedAt = old.updatedAt
    check(BandMigration.needsMigration(old), "the week page needs migration")
    let new = BandMigration.migrate(old)
    check(!BandMigration.needsMigration(new), "the migrated page needs nothing")
    checkEqual(new.pageId, "w-2026-10-05", "pageId kept")
    checkEqual(new.updatedAt, updatedAt, "updatedAt unchanged")
    checkEqual(new.deleted, ["zz": 1_760_000_000_500], "tombstones unchanged")
    checkEqual(new.v, old.v, "v unchanged")
    checkEqual(new.unknown, old.unknown, "unknown items unchanged")
    checkEqual(new.strokes.count, 5, "5 strokes")
    checkEqual(new.liveStrokeIds, ["a1", "a2", "a3", "a4", "a5"], "ids kept")
    checkEqual(new == old, false, "the page changed")
    func expectMoved(_ id: String, _ xs: [CGFloat], _ ys: [CGFloat]) {
        guard let o = old.strokes[id], let n = new.strokes[id] else {
            check(false, "\(id) exists before and after")
            return
        }
        checkEqual(n.cell, .grid, "\(id) → grid")
        checkEqual(n.id, o.id, "\(id): id kept")
        checkEqual(n.t, o.t, "\(id): t kept")
        checkEqual(n.dev, o.dev, "\(id): dev kept")
        checkEqual(n.tool, o.tool, "\(id): tool kept")
        checkEqual(n.color, o.color, "\(id): colour kept")
        checkEqual(n.points.count, o.points.count, "\(id): the number of points is kept")
        checkEqual(n.points.count, xs.count, "\(id): expected point count")
        for (i, p) in n.points.enumerated() where i < xs.count {
            checkClose(p.x, xs[i], "\(id) point \(i): x", tolerance: 0.11)
            checkClose(p.y, ys[i], "\(id) point \(i): y", tolerance: 0.11)
            checkEqual(p.dtMs, o.points[i].dtMs, "\(id) point \(i): dt kept")
            checkEqual(p.sizeW, o.points[i].sizeW, "\(id) point \(i): size kept")
            checkEqual(p.force, o.points[i].force, "\(id) point \(i): force kept")
        }
    }
    expectMoved("a1", [12 + 64 + 2 * colW, 17 + 64 + 2 * colW, 22 + 64 + 2 * colW], [40, 43, 40])
    expectMoved("a2", [69, 74], [-5, 2])
    expectMoved("a4", [64 + 6 * colW], [0])
    expectMoved("a5", [65], [1])
    checkClose(new.strokes["a1"]?.points.first?.x, 457.7, "a1: 12 + 64 + 2 × 190.857 = 457.714 → 457.7", tolerance: 0.11)
    checkEqual(new.strokes["a3"], old.strokes["a3"], "a grid stroke is untouched")
    checkEqual(BandMigration.migrate(new), new, "idempotent: migrate(migrate(p)) == migrate(p)")
    do {
        let decoded = try InkPageCodec.decode(try InkPageCodec.encode(new))
        checkEqual(decoded, new, "the migrated page survives the JSON round trip")
        checkEqual(BandMigration.migrate(try InkPageCodec.decode(try InkPageCodec.encode(old))), new, "migrating the decoded old page gives the same result")
        checkEqual(BandMigration.needsMigration(decoded), false, "the decoded migrated page needs nothing")
    } catch {
        check(false, "band migration codec threw: \(error)")
    }
    // Single strokes.
    checkEqual(BandMigration.migrated(old.strokes["a3"]!, pageId: "w-2026-10-05"), nil, "a grid stroke is not a target")
    checkEqual(BandMigration.migrated(old.strokes["a1"]!, pageId: "m1-2026-10"), nil, "not on a month page")
    checkEqual(BandMigration.migrated(old.strokes["a1"]!, pageId: "y-2026"), nil, "not on a year page")
    checkEqual(BandMigration.migrated(old.strokes["a1"]!, pageId: ""), nil, "not without a page id")
    checkEqual(BandMigration.migrated(old.strokes["a1"]!, pageId: "w-2026-10-05")?.cell, .grid, "a1 alone → grid")
    checkEqual(BandMigration.migrated(old.strokes["a1"]!, pageId: "w-2026-10-05"), new.strokes["a1"], "a1 alone == a1 in the migrated page")
    checkClose(BandMigration.migrated(stroke("s", cell: .allDay(day(2026, 10, 9)), points: [point(0, 0)]), pageId: "w-2026-10-07")?.points.first?.x, 64 + 2 * colW, "a non-Monday page id: 10/9 − 10/7 = column 2", tolerance: 0.11)
    checkClose(BandMigration.migrated(stroke("s", cell: .allDay(wed), points: [point(0, 0)]), pageId: "w-xxxx")?.points.first?.x, 64, "a broken week page id → column 0", tolerance: 0.11)
    checkClose(BandMigration.migrated(stroke("s", cell: .allDay(day(2026, 9, 1)), points: [point(0, 0)]), pageId: "w-2026-10-05")?.points.first?.x, 64, "a day before the week → column 0", tolerance: 0.11)
    checkClose(BandMigration.migrated(stroke("s", cell: .allDay(day(2026, 10, 11)), points: [point(0, 0)]), pageId: "w-2026-10-05")?.points.first?.x, 64 + 6 * colW, "Sunday → column 6", tolerance: 0.11)
    checkClose(BandMigration.migrated(stroke("s", cell: .allDayDay, points: [point(3, 4)]), pageId: "w-2026-10-05")?.points.first?.x, 67, "the day key on a week page (broken data) → column 0", tolerance: 0.11)
    checkEqual(BandMigration.migrated(stroke("s", cell: .allDay(wed), points: [point(3, 4)]), pageId: "d-2026-10-07")?.points.first?.x, 3, "a week key on a day page (broken data): x unchanged")
    checkEqual(BandMigration.migrated(stroke("s", cell: .allDayDay, points: [point(3, 4)]), pageId: "d-2026-10-07")?.cell, .grid, "the day key on a day page → grid")
    checkEqual(BandMigration.migrated(stroke("s", cell: .memo), pageId: "d-2026-10-07"), nil, "memo is not a band cell")
    checkEqual(BandMigration.migrated(stroke("s", cell: .yearDay(month: 1, day: 1)), pageId: "w-2026-10-05"), nil, "a year key is not a band cell")
    // isBandCell.
    checkEqual(BandMigration.isBandCell(.allDayDay), true, "isBandCell: allday")
    checkEqual(BandMigration.isBandCell(.allDay(wed)), true, "isBandCell: allday:2026-10-07")
    checkEqual(BandMigration.isBandCell(CellKey(raw: "allday:xx")), true, "isBandCell: a broken allday: key")
    checkEqual(BandMigration.isBandCell(CellKey(raw: "allday:")), true, "isBandCell: allday: without a date")
    checkEqual(BandMigration.isBandCell(.grid), false, "isBandCell: grid")
    checkEqual(BandMigration.isBandCell(.memo), false, "isBandCell: memo")
    checkEqual(BandMigration.isBandCell(.day(wed)), false, "isBandCell: a day key")
    checkEqual(BandMigration.isBandCell(CellKey(raw: "alldays")), false, "isBandCell: a key that merely starts with the letters")
    checkEqual(BandMigration.isBandCell(CellKey(raw: "02-30")), false, "isBandCell: a year key")
    checkEqual(BandMigration.isBandCell(CellKey(raw: "")), false, "isBandCell: empty")
    // The day page: only the cell changes.
    var dOld = InkPage.empty(pageId: "d-2026-10-07")
    dOld.add(stroke("b1", cell: .allDayDay, color: "#2563eb", points: [point(800, 30)]))
    dOld.add(stroke("b2", cell: .allDayDay, points: [point(100, -20), point(120, -10, dt: 16)]))
    dOld.add(stroke("b3", cell: .grid, points: [point(100, 500)]))
    check(BandMigration.needsMigration(dOld), "the day page needs migration")
    let dNew = BandMigration.migrate(dOld)
    check(!BandMigration.needsMigration(dNew), "the migrated day page needs nothing")
    checkEqual(dNew.strokes["b1"]?.cell, .grid, "b1 → grid")
    checkEqual(dNew.strokes["b1"]?.points, dOld.strokes["b1"]?.points, "b1: points unchanged (800, 30)")
    checkEqual(dNew.strokes["b1"]?.color, "#2563eb", "b1: colour kept")
    checkEqual(dNew.strokes["b2"]?.cell, .grid, "b2 → grid")
    checkEqual(dNew.strokes["b2"]?.points, dOld.strokes["b2"]?.points, "b2: points unchanged (the negative y is kept, M4B-26)")
    checkEqual(dNew.strokes["b2"]?.points.first?.y, -20, "b2: y −20 stays")
    checkEqual(dNew.strokes["b3"], dOld.strokes["b3"], "b3 (grid) untouched")
    checkEqual(dNew.updatedAt, dOld.updatedAt, "day: updatedAt unchanged")
    checkEqual(dNew.liveStrokeIds, ["b1", "b2", "b3"], "day: ids kept")
    checkEqual(BandMigration.migrate(dNew), dNew, "day: idempotent")
    // Month and year pages are never touched, even with band keys (broken data).
    var monthPage = InkPage.empty(pageId: "m1-2026-10")
    monthPage.add(stroke("c1", cell: .allDay(wed), points: [point(1, 2)]))
    checkEqual(BandMigration.needsMigration(monthPage), false, "a month page needs nothing")
    checkEqual(BandMigration.migrate(monthPage), monthPage, "a month page is returned as it is")
    checkEqual(BandMigration.migrate(monthPage).strokes["c1"]?.cell, .allDay(wed), "c1 keeps its key")
    var yearPage = InkPage.empty(pageId: "y-2026")
    yearPage.add(stroke("d1", cell: .allDayDay, points: [point(1, 2)]))
    checkEqual(BandMigration.needsMigration(yearPage), false, "a year page needs nothing")
    checkEqual(BandMigration.migrate(yearPage), yearPage, "a year page is returned as it is")
    // Nothing to move → the same page (==); unknown-tool strokes and tombstoned strokes are not read.
    var clean = InkPage.empty(pageId: "w-2026-10-05")
    clean.add(stroke("g1", cell: .grid))
    clean.unknownStrokes["u1"] = .object(["id": .string("u1"), "cell": .string("allday:2026-10-07"), "tool": .string("crayon"), "pts": .array([.number(1)])])
    checkEqual(BandMigration.needsMigration(clean), false, "a page without band strokes needs nothing")
    checkEqual(BandMigration.migrate(clean), clean, "it is returned as it is")
    checkEqual(BandMigration.migrate(clean).unknownStrokes, clean.unknownStrokes, "an unknown-tool stroke in a band cell is not touched")
    let dead = InkPage(pageId: "w-2026-10-05", strokes: ["t1": stroke("t1", cell: .allDay(wed))], deleted: ["t1": 5])
    checkEqual(BandMigration.needsMigration(dead), false, "a tombstoned band stroke is not live")
    checkEqual(BandMigration.migrate(dead), dead, "a tombstoned band stroke is not moved")
    checkEqual(BandMigration.migrate(InkPage.empty(pageId: "w-2026-10-05")), InkPage.empty(pageId: "w-2026-10-05"), "an empty page")
    checkEqual(BandMigration.needsMigration(InkPage.empty(pageId: "d-2026-10-07")), false, "an empty day page")
    // Merge (the rule is unchanged, M4B_CONTRACT §3.2): the moved stroke wins because "grid" > "allday…".
    check(InkPage.compareStrokes(old.strokes["a1"]!, new.strokes["a1"]!) < 0, "compareStrokes(old a1, new a1) < 0 ('a' < 'g')")
    check(InkPage.compareStrokes(new.strokes["a1"]!, old.strokes["a1"]!) > 0, "compareStrokes(new a1, old a1) > 0")
    check(InkPage.compareStrokes(old.strokes["a2"]!, new.strokes["a2"]!) < 0, "compareStrokes(old a2, new a2) < 0 (a marker without dev)")
    check(InkPage.compareStrokes(old.strokes["a5"]!, new.strokes["a5"]!) < 0, "compareStrokes(old a5, new a5) < 0 (a broken key)")
    check(InkPage.compareStrokes(dOld.strokes["b2"]!, dNew.strokes["b2"]!) < 0, "same points, only the cell differs: the new form still wins")
    let merged = InkPage.merge(old, new)
    checkEqual(merged, InkPage.merge(new, old), "merge(old, new) == merge(new, old)")
    checkEqual(merged, new, "merge(old, new) == new")
    check(merged.liveStrokes.allSatisfy { $0.cell == .grid }, "every live stroke is in the new form")
    checkEqual(merged.liveStrokes.count, 5, "5 live strokes after the merge")
    checkEqual(InkPage.merge(old, old), old, "merge(old, old) == old")
    checkEqual(InkPage.merge(new, new), new, "merge(new, new) == new")
    checkEqual(InkPage.merge(dOld, dNew), dNew, "day: merge(old, new) == new")
    checkEqual(InkPage.merge(dNew, dOld), dNew, "day: merge(new, old) == new")
    check(InkPage.merge(dOld, dNew).liveStrokes.allSatisfy { $0.cell == .grid }, "day: every live stroke is in the new form")
    checkEqual(InkPage.merge(dOld, dOld), dOld, "day: merge(old, old) == old")
    checkEqual(BandMigration.migrate(merged), merged, "a merged page needs no migration")
    checkEqual(InkPage.merge(merged, old), new, "a 0.5.0 device's copy of the old form does not come back")
    var erased = new
    erased.remove(ids: ["a1"], at: 1_760_150_500_000)
    checkEqual(InkPage.merge(old, erased).strokes["a1"], nil, "a tombstone on the moved id removes the old form too")
    checkEqual(InkPage.merge(old, erased).deleted["a1"], 1_760_150_500_000, "the tombstone survives the merge")
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
