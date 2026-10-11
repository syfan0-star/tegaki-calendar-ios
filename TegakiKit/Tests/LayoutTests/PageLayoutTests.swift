import XCTest
import Foundation
import CoreGraphics
import Layout

// MARK: - Shared fixtures of the M3a layout tests (M3A_CONTRACT §8.1)

/// A fixed calendar, October 2026 helpers and the screenshot-mode demo events (M3A_CONTRACT §7),
/// shared by the week / day / year / navigation / timed-event tests.
enum M3aFixtures {
    static let tokyo: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        c.locale = Locale(identifier: "ja_JP")
        return c
    }()

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y
        c.month = m
        c.day = d
        c.hour = h
        c.minute = mi
        return tokyo.date(from: c)!
    }

    static func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

    /// Local time on October `n` 2026 (n may exceed 31).
    static func october(_ n: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        let base = tokyo.date(byAdding: .day, value: n - 1, to: date(2026, 10, 1))!
        return tokyo.date(byAdding: .minute, value: h * 60 + mi, to: base)!
    }

    static func allDay(_ id: String, _ startDay: Int, _ endDayExclusive: Int, title: String? = nil) -> LayoutEvent {
        LayoutEvent(id: id, title: title ?? id, allDay: true, start: october(startDay), end: october(endDayExclusive), colorHex: "#33b679", calendarId: "primary")
    }

    static func timed(_ id: String, _ d: Int, _ sh: Int, _ sm: Int, _ eh: Int, _ em: Int, endDay: Int? = nil, title: String? = nil) -> LayoutEvent {
        LayoutEvent(id: id, title: title ?? id, allDay: false, start: october(d, sh, sm), end: october(endDay ?? d, eh, em), colorHex: "#039be5", calendarId: "primary")
    }

    static let demoColors = ["#2563eb", "#16a34a", "#ea580c", "#7c3aed"] // work, family, personal, events

    /// The demo events of ScreenshotMode.demoEvents (M2) plus the 7th's additions (M3A_CONTRACT §7).
    static let demo: [LayoutEvent] = {
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
    }()

    /// The screenshot mode's "today": the 7th at 10:00.
    static let demoNow: Date = october(7, 10)

    static func demoId(_ title: String) -> String { demo.first { $0.title == title }?.id ?? "?" }

    static let colW = PaperSpec.weekColumnWidth

    static func weekLayout(_ events: [LayoutEvent], focus: DayKey = day(2026, 10, 7), ink: [CellKey: CGFloat] = [:], now: Date = demoNow) -> WeekPageLayout {
        WeekLayoutEngine.layout(WeekLayoutInput(focus: focus, events: events, inkBottoms: ink, now: now, calendar: tokyo))
    }

    static func dayLayout(_ events: [LayoutEvent], focus: DayKey = day(2026, 10, 7), ink: [CellKey: CGFloat] = [:], now: Date = demoNow) -> DayPageLayout {
        DayLayoutEngine.layout(DayLayoutInput(day: focus, events: events, inkBottoms: ink, now: now, calendar: tokyo))
    }

    static func yearLayout(_ events: [LayoutEvent], year: Int = 2026, ink: [CellKey: CGFloat] = [:], now: Date = demoNow) -> YearPageLayout {
        YearLayoutEngine.layout(YearLayoutInput(year: year, events: events, inkBottoms: ink, now: now, calendar: tokyo))
    }

    static func monthLayout(_ events: [LayoutEvent], ink: [CellKey: CGFloat] = [:], now: Date? = nil) -> MonthPageLayout {
        MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 10), events: events, inkBottoms: ink, now: now ?? date(2026, 10, 12, 12), calendar: tokyo))
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
    }
}

/// `XCTAssertEqual` for rects whose coordinates carry floating-point noise (190.857… wide columns).
func assertRect(_ actual: CGRect?, _ expected: CGRect, accuracy: CGFloat = 1e-6, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
    guard let a = actual else {
        XCTFail("nil rect, expected \(expected). \(message)", file: file, line: line)
        return
    }
    XCTAssertEqual(a.minX, expected.minX, accuracy: accuracy, "minX. \(message)", file: file, line: line)
    XCTAssertEqual(a.minY, expected.minY, accuracy: accuracy, "minY. \(message)", file: file, line: line)
    XCTAssertEqual(a.width, expected.width, accuracy: accuracy, "width. \(message)", file: file, line: line)
    XCTAssertEqual(a.height, expected.height, accuracy: accuracy, "height. \(message)", file: file, line: line)
}

// MARK: - PageLayout protocol, PaperSpec, CellKey, the month page as a PageLayout, LanePacking

final class PageLayoutTests: XCTestCase {
    private typealias F = M3aFixtures

    func testPaperSpecConstants() {
        XCTAssertEqual(PaperSpec.weekColumnWidth, 1336.0 / 7)
        XCTAssertEqual(PaperSpec.weekGridHeight, 1920)
        XCTAssertEqual(PaperSpec.dayGridHeight, 2400)
        XCTAssertEqual(PaperSpec.dayLaneStep, 24)
        XCTAssertEqual(PaperSpec.yearLaneStep, 18)
        XCTAssertEqual(PaperSpec.allDayLaneStep, 25)
    }

    func testCellKeys() {
        XCTAssertEqual(CellKey.allDay(F.day(2026, 10, 4)).raw, "allday:2026-10-04")
        XCTAssertEqual(CellKey.allDayDay.raw, "allday")
        XCTAssertEqual(CellKey.grid.raw, "grid")
        XCTAssertEqual(CellKey.yearDay(month: 2, day: 30).raw, "02-30")
        XCTAssertEqual(CellKey.yearDay(month: 12, day: 31).raw, "12-31")
        XCTAssertEqual(CellKey.allDay(F.day(2026, 10, 4)).allDayDate, F.day(2026, 10, 4))
        XCTAssertEqual(CellKey(raw: "02-30").yearMonthDay?.month, 2)
        XCTAssertEqual(CellKey(raw: "02-30").yearMonthDay?.day, 30)
        XCTAssertEqual(CellKey.yearDay(month: 7, day: 1).yearMonthDay?.month, 7)
        XCTAssertEqual(CellKey.yearDay(month: 7, day: 1).yearMonthDay?.day, 1)
        XCTAssertNil(CellKey(raw: "02-30").day)
        XCTAssertNil(CellKey(raw: "allday:2026-10-04").day)
        XCTAssertNil(CellKey(raw: "2026-10-04").allDayDate)
        XCTAssertNil(CellKey(raw: "2026-10-04").yearMonthDay)
        XCTAssertNil(CellKey(raw: "13-01").yearMonthDay)
        XCTAssertNil(CellKey(raw: "memo").yearMonthDay)
        XCTAssertNil(CellKey(raw: "allday:").allDayDate)
        XCTAssertTrue(CellKey.grid.isGrid)
        XCTAssertTrue(CellKey.allDayDay.isAllDayDay)
        XCTAssertFalse(CellKey.allDay(F.day(2026, 10, 4)).isAllDayDay)
        XCTAssertFalse(CellKey.memo.isGrid)
        // The persistence format is the plain string.
        let data = try? JSONEncoder().encode([CellKey.allDay(F.day(2026, 10, 4)), .grid, .yearDay(month: 2, day: 30)])
        XCTAssertEqual(data.map { String(decoding: $0, as: UTF8.self) }, "[\"allday:2026-10-04\",\"grid\",\"02-30\"]")
    }

    func testPageBand() {
        XCTAssertEqual(PageBand.row(3).raw, "row:3")
        XCTAssertEqual(PageBand.row(3).rowIndex, 3)
        XCTAssertNil(PageBand.memo.rowIndex)
        XCTAssertEqual(PageBand.allDay.raw, "allday")
        XCTAssertEqual(PageBand.grid.raw, "grid")
    }

    func testMonthPageConformance() {
        let plain = F.monthLayout([])
        XCTAssertEqual(plain.kind, .month)
        XCTAssertEqual(plain.pageId, "m1-2026-10")
        XCTAssertEqual(plain.month, YearMonth(year: 2026, month: 10))
        XCTAssertEqual(plain.timedBoxes.count, 0)
        XCTAssertNil(plain.nowLine)
        XCTAssertEqual(plain.inkCell(forCenter: CGPoint(x: 650, y: 10)), .day(F.day(2026, 10, 1)))
        XCTAssertEqual(plain.inkCell(forCenter: CGPoint(x: -5, y: 10)), .day(F.day(2026, 9, 28)), "left of the paper → the nearest cell")
        XCTAssertEqual(plain.inkCell(forCenter: CGPoint(x: 1500, y: 200)), .day(F.day(2026, 10, 11)), "right of the paper → the last column")
        XCTAssertEqual(plain.inkCell(forCenter: CGPoint(x: 100, y: -20)), .day(F.day(2026, 9, 28)), "above the paper → row 0")
        XCTAssertEqual(plain.inkCell(forCenter: CGPoint(x: 100, y: 5000)), .memo, "below the paper → memo")
        XCTAssertEqual(plain.inkCell(forCenter: CGPoint(x: 100, y: 1100)), .memo)
        XCTAssertEqual(plain.inkCell(forCenter: CGPoint(x: CGFloat.nan, y: CGFloat.nan)), .day(F.day(2026, 9, 28)), "NaN clamps to the top-left cell")
        XCTAssertTrue(plain.growsWithInk(.memo))
        XCTAssertTrue(plain.growsWithInk(.day(F.day(2026, 10, 1))))
        XCTAssertFalse(plain.growsWithInk(.grid))
        XCTAssertFalse(plain.growsWithInk(.day(F.day(2026, 12, 1))))
        XCTAssertEqual(plain.band(atY: 10), PageBand(raw: "row:0"))
        XCTAssertEqual(plain.band(atY: 1049.9), PageBand(raw: "row:5"))
        XCTAssertEqual(plain.band(atY: 1100), PageBand(raw: "memo"))
        XCTAssertNil(plain.band(atY: 1750))
        XCTAssertNil(plain.band(atY: -1))
        XCTAssertEqual(plain.bandTop(PageBand(raw: "row:3")), 525)
        XCTAssertEqual(plain.bandTop(PageBand(raw: "memo")), 1050)
        XCTAssertNil(plain.bandTop(PageBand(raw: "row:6")))
        XCTAssertNil(plain.bandTop(PageBand(raw: "allday")))
    }

    func testPageScrollAgreesWithMonthScrollDelta() {
        let plain = F.monthLayout([])
        let inked = F.monthLayout([], ink: [.day(F.day(2026, 10, 14)): 300, .memo: 900])
        for y in [600, 100, 360, 1100, -5] as [CGFloat] {
            XCTAssertEqual(PageScroll.scrollDelta(old: plain, new: inked, topVisibleY: y), MonthLayoutEngine.scrollDelta(old: plain, new: inked, topVisibleY: y), "y = \(y)")
        }
        XCTAssertEqual(PageScroll.scrollDelta(old: plain, new: inked, topVisibleY: 600), 137)
        XCTAssertEqual(PageScroll.scrollDelta(old: inked, new: plain, topVisibleY: 700), -137)
        XCTAssertEqual(PageScroll.scrollDelta(old: plain, new: inked, topVisibleY: 5000), 0, "outside the paper (PageScroll)")
        XCTAssertEqual(MonthLayoutEngine.scrollDelta(old: plain, new: inked, topVisibleY: 5000), 137, "the M2 rule is kept for the month engine")
        XCTAssertEqual(PageScroll.scrollDelta(old: plain, new: inked, topVisibleY: .nan), 0)
        // A band missing from `new` moves nothing.
        XCTAssertEqual(PageScroll.scrollDelta(old: plain, new: F.weekLayout([]), topVisibleY: 1100), 0)
    }

    func testSameGeometry() {
        let plain = F.monthLayout([])
        XCTAssertTrue(plain.sameGeometry(as: F.monthLayout([])))
        XCTAssertFalse(plain.sameGeometry(as: F.monthLayout([], ink: [.memo: 900])))
        XCTAssertTrue(plain.sameGeometry(as: F.monthLayout([], now: F.date(2026, 10, 20, 9))), "`now` does not change the geometry")
        XCTAssertFalse(plain.sameGeometry(as: F.weekLayout([])), "another kind")
        let week = F.weekLayout(F.demo)
        XCTAssertTrue(week.sameGeometry(as: F.weekLayout(F.demo, now: F.october(7, 11))))
        XCTAssertFalse(week.sameGeometry(as: F.weekLayout(F.demo, ink: [.allDay(F.day(2026, 10, 6)): 68])))
        XCTAssertFalse(week.sameGeometry(as: F.weekLayout(F.demo, focus: F.day(2026, 10, 14))))
        let erased: any PageLayout = plain
        XCTAssertEqual(erased.cell(at: CGPoint(x: 650, y: 10)), .day(F.day(2026, 10, 1)))
        XCTAssertEqual(erased.pageId, "m1-2026-10")
    }

    func testLanePacking() {
        XCTAssertEqual(LanePacking.metrics(laneCount: 30, lane: 22, gap: 3, available: 767), LaneMetrics(lane: 22, step: 25, gap: 3, fontScale: 1), "30 lanes fit (747 ≤ 767)")
        XCTAssertEqual(LanePacking.metrics(laneCount: 0, lane: 22, gap: 3, available: 767), LaneMetrics(lane: 22, step: 25, gap: 3, fontScale: 1))
        XCTAssertEqual(LaneMetrics.plain(lane: 16, gap: 2), LaneMetrics(lane: 16, step: 18, gap: 2, fontScale: 1))
        let m = LanePacking.metrics(laneCount: 40, lane: 22, gap: 3, available: 767)
        XCTAssertEqual(m.step, 770.0 / 40, accuracy: 1e-9)
        XCTAssertEqual(m.gap, 3, accuracy: 1e-9)
        XCTAssertEqual(m.lane, 16.25, accuracy: 1e-9)
        XCTAssertEqual(m.fontScale, 16.25 / 22, accuracy: 1e-9)
        let n = LanePacking.metrics(laneCount: 100, lane: 22, gap: 3, available: 767)
        let step = 767.0 / (100 - 1.0 / 3)
        XCTAssertEqual(n.step, step, accuracy: 1e-9, "step = available / (n − 1/3)")
        XCTAssertEqual(n.gap, step / 3, accuracy: 1e-9)
        XCTAssertEqual(n.lane, step - step / 3, accuracy: 1e-9)
        XCTAssertEqual(100 * n.step - n.gap, 767, accuracy: 1e-9, "fills the available height exactly")
        XCTAssertLessThan(n.fontScale, 1)
    }
}
