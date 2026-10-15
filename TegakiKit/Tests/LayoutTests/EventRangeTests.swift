import XCTest
import Foundation
import CoreGraphics
import Layout

/// Rect → event range and event range → rect on the four pages (M3B_CONTRACT §1 / §6.1). The
/// expectations are the web version's tests/page-geometry.test.mjs (Monday-start grids). Since M4b
/// the week / day grid starts at the paper's top (`g == 0`): the all-day band is not on the paper
/// (M4B_CONTRACT §2.3), so an all-day range has no snap rect there. The same checks run in KitChecks.
final class EventRangeTests: XCTestCase {
    private typealias F = M3aFixtures
    private var tokyo: Calendar { F.tokyo }
    private var colW: CGFloat { PaperSpec.weekColumnWidth }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = M3aFixtures.tokyo
        f.timeZone = M3aFixtures.tokyo.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    /// "2026-10-04 09:00–2026-10-04 10:30" (+ " allDay") in the fixed calendar.
    private func fmt(_ r: EventRange?) -> String {
        guard let r = r else { return "nil" }
        return "\(Self.formatter.string(from: r.start))–\(Self.formatter.string(from: r.end))" + (r.allDay ? " allDay" : "")
    }

    /// The day the range starts on ("2026-10-04"), or "nil".
    private func ymd(_ r: EventRange?) -> String {
        r.map { DayKey($0.start, calendar: tokyo).description } ?? "nil"
    }

    /// A rect from two corners; a reversed drag gives a negative size (the engines normalize it).
    private func rect(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
        CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    private func assertRect(_ actual: CGRect?, _ expected: CGRect, _ message: String = "", tolerance: CGFloat = 1e-6, file: StaticString = #filePath, line: UInt = #line) {
        guard let a = actual else {
            XCTFail("\(message): nil, expected \(expected)", file: file, line: line)
            return
        }
        XCTAssertEqual(a.minX, expected.minX, accuracy: tolerance, "\(message): minX", file: file, line: line)
        XCTAssertEqual(a.minY, expected.minY, accuracy: tolerance, "\(message): minY", file: file, line: line)
        XCTAssertEqual(a.width, expected.width, accuracy: tolerance, "\(message): width", file: file, line: line)
        XCTAssertEqual(a.height, expected.height, accuracy: tolerance, "\(message): height", file: file, line: line)
    }

    private func timed(_ d: DayKey, _ start: Int, _ end: Int) -> EventRange {
        EventRange.timed(d, startMinute: start, endMinute: end, calendar: tokyo)
    }

    private func allDay(_ d: DayKey) -> EventRange {
        EventRange.allDay(d, calendar: tokyo)
    }

    private func range(_ start: Date, _ end: Date) -> EventRange {
        EventRange(start: start, end: end, allDay: false)
    }

    /// Deterministic xorshift64* generator.
    private struct Rng {
        var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
        mutating func next() -> UInt64 {
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27
            return state &* 2_685_821_657_736_338_717
        }
        mutating func double() -> Double { Double(next() >> 11) / Double(UInt64(1) << 53) }
    }

    // MARK: EventRange and EventGeometry

    func testEventRangeConstructors() {
        let d4 = F.day(2026, 10, 4)
        XCTAssertEqual(fmt(allDay(d4)), "2026-10-04 00:00–2026-10-05 00:00 allDay")
        XCTAssertTrue(allDay(d4).isValid)
        XCTAssertTrue(allDay(d4).allDay)
        let t = timed(d4, 540, 630)
        XCTAssertEqual(fmt(t), "2026-10-04 09:00–2026-10-04 10:30")
        XCTAssertEqual(t.start, F.date(2026, 10, 4, 9), "wall-clock time")
        XCTAssertFalse(t.allDay)
        XCTAssertEqual(fmt(timed(d4, 1380, 1440)), "2026-10-04 23:00–2026-10-05 00:00", "endMinute 1440 is the next midnight")
        XCTAssertEqual(fmt(timed(d4, 0, 60)), "2026-10-04 00:00–2026-10-04 01:00")
        XCTAssertFalse(timed(d4, 600, 600).isValid, "zero length")
        XCTAssertFalse(range(F.date(2026, 10, 4, 10), F.date(2026, 10, 4, 9)).isValid, "end before start")
        XCTAssertEqual(EventGeometry.tapMaxHeight, 12)
        XCTAssertEqual(EventGeometry.minDragMinutes, 30)
        XCTAssertEqual(EventGeometry.defaultDurationMinutes, 60)
        XCTAssertEqual(EventGeometry.dayMinutes, 1440)
    }

    func testRoundMinutes() {
        XCTAssertEqual(EventGeometry.roundMinutes(547.5, step: 15), 555, "0.5 rounds up")
        XCTAssertEqual(EventGeometry.roundMinutes(552.49, step: 15), 555)
        XCTAssertEqual(EventGeometry.roundMinutes(547.49, step: 15), 540)
        XCTAssertEqual(EventGeometry.roundMinutes(540.0000001, step: 15), 540)
        XCTAssertEqual(EventGeometry.roundMinutes(540.000000001, step: 15, .ceil), 540, "within 1e-9 of a multiple counts as that multiple (ceil)")
        XCTAssertEqual(EventGeometry.roundMinutes(539.999999999, step: 15, .floor), 540, "… (floor)")
        XCTAssertEqual(EventGeometry.roundMinutes(547, step: 30, .floor), 540)
        XCTAssertEqual(EventGeometry.roundMinutes(541, step: 30, .ceil), 570)
        XCTAssertEqual(EventGeometry.roundMinutes(0, step: 15), 0)
        XCTAssertEqual(EventGeometry.roundMinutes(1440, step: 15), 1440)
        XCTAssertEqual(EventGeometry.roundMinutes(7.5, step: 15), 15)
        XCTAssertEqual(EventGeometry.roundMinutes(7.49, step: 15), 0)
    }

    func testMinutesForYAndNormalized() {
        XCTAssertEqual(EventGeometry.minutes(forY: 150, hourHeight: 100), 90)
        XCTAssertEqual(EventGeometry.minutes(forY: 80, hourHeight: 80), 60)
        XCTAssertEqual(EventGeometry.minutes(forY: -5, hourHeight: 100), 0, "clamped at 0")
        XCTAssertEqual(EventGeometry.minutes(forY: 3000, hourHeight: 100), 1440, "clamped at 1440")
        XCTAssertEqual(EventGeometry.minutes(forY: CGFloat.nan, hourHeight: 100), 0, "NaN → 0")
        for m in stride(from: 0, through: 1440, by: 5) {
            XCTAssertEqual(EventGeometry.minutes(forY: CGFloat(m) * 80 / 60, hourHeight: 80), Double(m), accuracy: 1e-9)
            XCTAssertEqual(EventGeometry.minutes(forY: CGFloat(m) * 100 / 60, hourHeight: 100), Double(m), accuracy: 1e-9)
        }
        XCTAssertEqual(EventGeometry.normalized(rect(300, 1050, 100, 900)), CGRect(x: 100, y: 900, width: 200, height: 150), "a reversed drag")
        XCTAssertEqual(EventGeometry.normalized(rect(100, 900, 300, 1050)), CGRect(x: 100, y: 900, width: 200, height: 150))
        XCTAssertNil(EventGeometry.normalized(CGRect(x: 0, y: CGFloat.nan, width: 10, height: 10)))
        XCTAssertNil(EventGeometry.normalized(CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 10)))
    }

    func testTimelineSlot() {
        func slot(_ y0: CGFloat, _ y1: CGFloat) -> [Int] {
            let s = EventGeometry.timelineSlot(minY: y0, maxY: y1, hourHeight: 100)
            return [s.startMinute, s.endMinute]
        }
        XCTAssertEqual(slot(900, 1050), [540, 630])
        XCTAssertEqual(slot(910, 1060), [540, 630], "nearest 15 (down)")
        XCTAssertEqual(slot(915, 1065), [555, 645], "nearest 15 (up)")
        XCTAssertEqual(slot(900, 950), [540, 570], "exactly 30 min stays")
        XCTAssertEqual(slot(905, 925), [540, 600], "shorter than 30 min → 1 hour")
        XCTAssertEqual(slot(1050, 900), [540, 630], "minY / maxY in either order")
        XCTAssertEqual(slot(1398, 1504), [840, 900], "slightly past the hour lines")
        XCTAssertEqual(slot(1403, 1495), [840, 900], "slightly short of the hour lines")
        XCTAssertEqual(slot(1400, 1513), [840, 915], "past 7.5 min the next line wins")
        XCTAssertEqual(slot(1275, 1275), [750, 810], "tap → the half hour under the point")
        XCTAssertEqual(slot(1270, 1281.9), [750, 810], "height 11.9 is a tap")
        XCTAssertEqual(slot(1270, 1282), [765, 825], "height 12 is a drag")
        XCTAssertEqual(slot(2300, 2500), [1380, 1440], "end clamped at 24:00")
        XCTAssertEqual(slot(2390, 2390), [1410, 1440], "tap at 23:54")
        XCTAssertEqual(slot(2380, 2400), [1425, 1440], "short drag at the bottom")
        XCTAssertEqual(slot(2400, 2400), [1380, 1440], "tap exactly at 24:00 never yields 0 min")
        XCTAssertEqual(slot(2500, 2600), [1380, 1440], "rect entirely below the page")
        XCTAssertEqual(slot(-100, -50), [0, 60], "above the page clamps to 0:00")
        let w = EventGeometry.timelineSlot(minY: 1117, maxY: 1206, hourHeight: 80)
        XCTAssertEqual([w.startMinute, w.endMinute], [840, 900], "week (hourHeight 80): 13:57.75 → 15:04.5 is 14:00–15:00")
    }

    // MARK: Day page

    func testDayPage() {
        let page = F.dayLayout([], focus: F.day(2026, 10, 4))
        let g = page.grid.minY
        XCTAssertEqual(g, 0, "the band is not on the paper (M4b): the grid starts at 0")
        func ev(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> String {
            fmt(page.eventRange(for: rect(x0, y0 + g, x1, y1 + g), now: F.demoNow, calendar: tokyo))
        }
        XCTAssertEqual(ev(100, 900, 300, 1050), "2026-10-04 09:00–2026-10-04 10:30")
        XCTAssertEqual(ev(100, 910, 300, 1060), "2026-10-04 09:00–2026-10-04 10:30", "nearest 15 (down)")
        XCTAssertEqual(ev(100, 915, 300, 1065), "2026-10-04 09:15–2026-10-04 10:45", "nearest 15 (up)")
        XCTAssertEqual(ev(100, 900, 300, 950), "2026-10-04 09:00–2026-10-04 09:30", "exactly 30 min stays")
        XCTAssertEqual(ev(100, 905, 300, 925), "2026-10-04 09:00–2026-10-04 10:00", "shorter than 30 min → 1 hour")
        XCTAssertEqual(ev(300, 1050, 100, 900), "2026-10-04 09:00–2026-10-04 10:30", "a reversed drag is normalized")
        XCTAssertEqual(ev(100, 1398, 300, 1504), "2026-10-04 14:00–2026-10-04 15:00", "slightly past the hour lines")
        XCTAssertEqual(ev(100, 1403, 300, 1495), "2026-10-04 14:00–2026-10-04 15:00", "slightly short of the hour lines")
        XCTAssertEqual(ev(100, 1400, 300, 1513), "2026-10-04 14:00–2026-10-04 15:15", "past 7.5 min the next line wins")
        XCTAssertEqual(ev(700, 900, 950, 1050), "2026-10-04 09:00–2026-10-04 10:30", "the memo area still means the day")
        XCTAssertEqual(ev(0, 900, 40, 1050), "2026-10-04 09:00–2026-10-04 10:30", "the time gutter still means the day")
        XCTAssertEqual(ev(200, 1275, 200, 1275), "2026-10-04 12:30–2026-10-04 13:30", "tap → the half hour under the point")
        XCTAssertEqual(ev(200, 1270, 205, 1281.9), "2026-10-04 12:30–2026-10-04 13:30", "height 11.9 is a tap")
        XCTAssertEqual(ev(200, 1270, 205, 1282), "2026-10-04 12:45–2026-10-04 13:45", "height 12 is a drag")
        XCTAssertEqual(ev(200, 2300, 300, 2500), "2026-10-04 23:00–2026-10-05 00:00", "end clamped to 24:00")
        XCTAssertEqual(ev(200, 2390, 200, 2390), "2026-10-04 23:30–2026-10-05 00:00", "tap at 23:54")
        XCTAssertEqual(ev(200, 2380, 300, 2400), "2026-10-04 23:45–2026-10-05 00:00", "short drag at the bottom")
        XCTAssertEqual(ev(200, 2400, 200, 2400), "2026-10-04 23:00–2026-10-05 00:00", "tap exactly at 24:00")
        XCTAssertEqual(ev(200, 2500, 300, 2600), "2026-10-04 23:00–2026-10-05 00:00", "rect entirely below the page")
        XCTAssertEqual(ev(200, -100, 300, -50), "2026-10-04 00:00–2026-10-04 01:00", "above the page clamps to 0:00")
        XCTAssertEqual(fmt(page.eventRange(for: rect(200, 0, 300, 20), now: F.demoNow, calendar: tokyo)), "2026-10-04 00:00–2026-10-04 01:00", "the paper's top is 0:00 (no band): a 20 lu drag there is 0:00–0:12 → one hour")
        XCTAssertNil(page.eventRange(for: CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1), now: F.demoNow, calendar: tokyo), "a NaN rect")
        XCTAssertNil(page.eventRange(for: CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 1), now: F.demoNow, calendar: tokyo), "an infinite rect")
        // The device-calendar overloads (the device time zone may differ from the fixture's).
        let dev = page.eventRange(for: rect(100, 900 + g, 300, 1050 + g), now: F.demoNow)
        XCTAssertNotNil(dev)
        if let dev = dev {
            XCTAssertEqual(DayKey(dev.start, calendar: DayKey.deviceCalendar), F.day(2026, 10, 4))
            XCTAssertEqual(TimedEventEngine.minutesOfDay(dev.start, calendar: DayKey.deviceCalendar), 540)
            XCTAssertEqual(TimedEventEngine.minutesOfDay(dev.end, calendar: DayKey.deviceCalendar), 630)
            XCTAssertNotNil(page.snapRect(for: dev))
            XCTAssertNotNil(page.previewRect(for: rect(100, 900 + g, 300, 1050 + g), now: F.demoNow))
        }
    }

    func testDayPageSnapRect() {
        let page = F.dayLayout([], focus: F.day(2026, 10, 4))
        let g = page.grid.minY
        let d4 = F.day(2026, 10, 4)
        assertRect(page.snapRect(for: timed(d4, 540, 630), calendar: tokyo), CGRect(x: 72, y: g + 900, width: 588, height: 150), "9:00–10:30 = the timeline column")
        assertRect(page.previewRect(for: rect(700, 910 + g, 950, 1060 + g), now: F.demoNow, calendar: tokyo), CGRect(x: 72, y: g + 900, width: 588, height: 150), "a memo-area drag previews in the timeline column")
        XCTAssertNil(page.snapRect(for: allDay(d4), calendar: tokyo), "all-day → nil (the band is not on the paper)")
        XCTAssertNil(page.snapRect(for: allDay(F.day(2026, 10, 5)), calendar: tokyo), "another day")
        XCTAssertNil(page.snapRect(for: timed(F.day(2026, 10, 5), 540, 600), calendar: tokyo), "timed on another day")
        XCTAssertNil(page.snapRect(for: range(F.date(2026, 10, 3, 22), F.date(2026, 10, 4, 2)), calendar: tokyo), "starts the day before")
        assertRect(page.snapRect(for: range(F.date(2026, 10, 4, 23), F.date(2026, 10, 5, 2)), calendar: tokyo), CGRect(x: 72, y: g + 2300, width: 588, height: 100), "ends the next day → clipped to 24:00")
        assertRect(page.snapRect(for: range(F.date(2026, 10, 4, 23), F.date(2026, 10, 5, 0)), calendar: tokyo), CGRect(x: 72, y: g + 2300, width: 588, height: 100), "ends exactly at midnight")
        XCTAssertNil(page.snapRect(for: range(F.date(2026, 10, 4, 10), F.date(2026, 10, 4, 10)), calendar: tokyo), "zero length")
        XCTAssertNil(page.snapRect(for: range(F.date(2026, 10, 4, 10), F.date(2026, 10, 4, 9)), calendar: tokyo), "inverted")
        assertRect(page.snapRect(for: range(F.date(2026, 10, 4, 10, 5), F.date(2026, 10, 4, 10, 35)), calendar: tokyo), CGRect(x: 72, y: g + 1000 + 500 / 60, width: 588, height: 50), "minutes off the 15 grid are drawn where they are")
        // All-day events go to the fixed band: the grid stays at the paper's top and the rects do not move.
        let busy = F.dayLayout([F.allDay("a", 4, 5), F.allDay("b", 4, 5), F.allDay("c", 4, 5), F.allDay("d", 4, 5)], focus: d4)
        XCTAssertEqual(busy.grid.minY, 0, "a busy band does not move the grid")
        XCTAssertEqual(busy.allDayBand.laneCount, 4)
        XCTAssertEqual(fmt(busy.eventRange(for: rect(100, 900 + busy.grid.minY, 300, 1050 + busy.grid.minY), now: F.demoNow, calendar: tokyo)), "2026-10-04 09:00–2026-10-04 10:30", "y is relative to the grid's top")
        assertRect(busy.snapRect(for: timed(d4, 540, 630), calendar: tokyo), CGRect(x: 72, y: 900, width: 588, height: 150))
    }

    // MARK: Week page

    func testWeekPage() {
        let page = F.weekLayout([]) // Mon 10/5 – Sun 10/11 2026
        let g = page.grid.minY
        XCTAssertEqual(g, 0, "the band is not on the paper (M4b): the grid starts at 0")
        func center(_ i: Int) -> CGFloat { PaperSpec.weekGutter + (CGFloat(i) + 0.5) * colW }
        func ev(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> String {
            fmt(page.eventRange(for: rect(x0, y0 + g, x1, y1 + g), now: F.demoNow, calendar: tokyo))
        }
        func at(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> String {
            ymd(page.eventRange(for: rect(x0, y0 + g, x1, y1 + g), now: F.demoNow, calendar: tokyo))
        }
        XCTAssertEqual(ev(700, 720, 760, 840), "2026-10-08 09:00–2026-10-08 10:30", "x 700 is column 3 (Thursday)")
        XCTAssertEqual(ev(center(3), 1117, center(3), 1206), "2026-10-08 14:00–2026-10-08 15:00", "slightly past the hour lines")
        assertRect(page.previewRect(for: rect(center(3), 1117 + g, center(3), 1206 + g), now: F.demoNow, calendar: tokyo), CGRect(x: page.columnFrame(3).minX, y: g + 1120, width: colW, height: 80), "the live preview shows 14:00–15:00")
        XCTAssertEqual(ev(center(2), 1000, center(2), 1000), "2026-10-07 12:30–2026-10-07 13:30", "tap at 12:30")
        XCTAssertEqual(at(0, 720, 60, 840), "2026-10-05", "the gutter → Monday")
        XCTAssertEqual(at(1450, 720, 1500, 840), "2026-10-11", "right of the paper → Sunday")
        XCTAssertEqual(at(1300, 720, 1390, 840), "2026-10-11", "column 6 is Sunday")
        XCTAssertEqual(at(-100, 720, -50, 840), "2026-10-05", "left of the paper → Monday")
        XCTAssertEqual(ev(700, 1800, 760, 2000), "2026-10-08 22:30–2026-10-09 00:00", "end clamped at 24:00")
        XCTAssertEqual(ev(700, -100, 760, -50), "2026-10-08 00:00–2026-10-08 01:00", "above the grid clamps to 0:00")
        XCTAssertEqual(fmt(page.eventRange(for: rect(700, 0, 760, 30), now: F.demoNow, calendar: tokyo)), "2026-10-08 00:00–2026-10-08 00:30", "the paper's top is 0:00 (no band): a 30 lu drag there is 0:00–0:30")
        for i in 0..<7 {
            XCTAssertEqual(at(center(i) - 20, 720, center(i) + 20, 840), page.days[i].description, "column \(i)")
        }
        let c1 = page.columnFrame(1)
        XCTAssertEqual(at(c1.minX - 10, 720, c1.minX + 30, 840), "2026-10-06", "a rect over two columns → the column under its centre")
        XCTAssertEqual(at(c1.minX - 30, 720, c1.minX + 10, 840), "2026-10-05")
        XCTAssertEqual(page.nearestColumn(atX: 0), 0)
        XCTAssertEqual(page.nearestColumn(atX: 63.9), 0, "in the gutter")
        XCTAssertEqual(page.nearestColumn(atX: 64), 0)
        XCTAssertEqual(page.nearestColumn(atX: 64 + colW), 1, "the left edge of column 1")
        XCTAssertEqual(page.nearestColumn(atX: 64 + colW - 0.001), 0)
        XCTAssertEqual(page.nearestColumn(atX: 1400), 6)
        XCTAssertEqual(page.nearestColumn(atX: 5000), 6)
        XCTAssertEqual(page.nearestColumn(atX: -100), 0)
        XCTAssertEqual(page.nearestColumn(atX: CGFloat.nan), 0)
        for i in 0..<7 {
            let frame = page.columnFrame(i)
            XCTAssertEqual(page.nearestColumn(atX: frame.midX), i)
            XCTAssertEqual(page.nearestColumn(atX: frame.minX), i)
            XCTAssertEqual(page.nearestColumn(atX: frame.maxX - 0.001), i)
        }
    }

    func testWeekPageSnapRect() {
        let page = F.weekLayout([])
        let g = page.grid.minY
        assertRect(page.snapRect(for: timed(F.day(2026, 10, 8), 840, 900), calendar: tokyo), CGRect(x: page.columnFrame(3).minX, y: g + 1120, width: colW, height: 80), "14:00–15:00 on Thursday")
        assertRect(page.previewRect(for: rect(700, 725 + g, 760, 845 + g), now: F.demoNow, calendar: tokyo), CGRect(x: page.columnFrame(3).minX, y: g + 720, width: colW, height: 120), "9:03.75 → 9:00, 10:33.75 → 10:30")
        assertRect(page.previewRect(for: rect(10, 1900 + g, 20, 1900 + g), now: F.demoNow, calendar: tokyo), CGRect(x: 64, y: g + 1880, width: colW, height: 40), "gutter tap at 23:45 → column 0, 23:30–24:00")
        XCTAssertNil(page.snapRect(for: allDay(F.day(2026, 10, 7)), calendar: tokyo), "all-day → nil (the band is not on the paper)")
        XCTAssertNil(page.snapRect(for: allDay(F.day(2026, 10, 12)), calendar: tokyo), "next week")
        XCTAssertNil(page.snapRect(for: allDay(F.day(2026, 10, 4)), calendar: tokyo), "the Sunday before")
        XCTAssertNil(page.snapRect(for: timed(F.day(2026, 10, 12), 540, 600), calendar: tokyo), "timed next week")
        assertRect(page.snapRect(for: range(F.date(2026, 10, 11, 23), F.date(2026, 10, 12, 2)), calendar: tokyo), CGRect(x: page.columnFrame(6).minX, y: g + 1840, width: colW, height: 80), "ends after Sunday → clipped to 24:00")
        XCTAssertNil(page.snapRect(for: range(F.date(2026, 10, 7, 10), F.date(2026, 10, 7, 10)), calendar: tokyo), "zero length")
        XCTAssertNil(page.snapRect(for: range(F.date(2026, 10, 4, 23), F.date(2026, 10, 5, 2)), calendar: tokyo), "starts before the week")
        for i in 0..<7 {
            assertRect(page.snapRect(for: timed(page.days[i], 60, 120), calendar: tokyo), CGRect(x: page.columnFrame(i).minX, y: g + 80, width: colW, height: 80), "1:00–2:00 in column \(i)")
        }
    }

    // MARK: Month page

    func testMonthPage() {
        let page = F.monthLayout([]) // October 2026, Monday start: grid 9/28 – 11/8, rows of 175, memo from 1050
        XCTAssertEqual(page.memo.minY, 1050)
        XCTAssertEqual(page.size.height, 1750)
        let now14 = F.date(2026, 10, 14, 22, 30)
        func ev(_ r: CGRect) -> String { fmt(page.eventRange(for: r, now: now14, calendar: tokyo)) }
        func at(_ r: CGRect) -> String { ymd(page.eventRange(for: r, now: now14, calendar: tokyo)) }
        XCTAssertEqual(ev(rect(850, 20, 950, 140)), "2026-10-02 00:00–2026-10-03 00:00 allDay", "row 0 col 4 = 10/02")
        XCTAssertEqual(at(rect(410, 360, 490, 380)), "2026-10-14", "row 2 col 2")
        XCTAssertEqual(at(rect(150, 150, 250, 200)), "2026-10-06", "centre (200, 175) → the next cell (row 1, col 1)")
        XCTAssertEqual(at(rect(-100, -100, -50, -50)), "2026-09-28", "outside top-left")
        XCTAssertEqual(at(rect(1450, 1000, 1500, 1040)), "2026-11-08", "outside right → row 5 col 6")
        XCTAssertEqual(at(rect(1250, 900, 1250, 900)), "2026-11-08", "a tap in row 5 col 6")
        XCTAssertEqual(at(rect(1400, 1049.9, 1400, 1049.9)), "2026-11-08", "the right edge belongs to the last column")
        XCTAssertEqual(at(rect(0, 0, 0, 0)), "2026-09-28", "a tap at the origin")
        XCTAssertNil(page.eventRange(for: CGRect(x: 0, y: CGFloat.nan, width: 1, height: 1), now: now14, calendar: tokyo), "a NaN rect")
        // Every cell: a rect inside it means its day.
        for (key, cell) in page.cells {
            guard let d = key.day else { continue }
            XCTAssertEqual(at(cell.insetBy(dx: 30, dy: 30)), d.description)
            XCTAssertEqual(at(rect(cell.minX, cell.minY, cell.minX, cell.minY)), d.description, "the top-left corner belongs to the cell")
            assertRect(page.previewRect(for: cell.insetBy(dx: 30, dy: 30), now: now14, calendar: tokyo), cell)
        }
    }

    func testMonthPageMemo() {
        let page = F.monthLayout([])
        let now14 = F.date(2026, 10, 14, 22, 30)
        let memo = rect(300, 1300, 700, 1420) // a lasso around writing in the memo area
        func at(_ r: CGRect, now: Date) -> String { ymd(page.eventRange(for: r, now: now, calendar: tokyo)) }
        XCTAssertEqual(fmt(page.eventRange(for: memo, now: now14, calendar: tokyo)), "2026-10-14 00:00–2026-10-15 00:00 allDay", "today when today is in the month")
        assertRect(page.previewRect(for: memo, now: now14, calendar: tokyo), CGRect(x: 400, y: 350, width: 200, height: 175), "10/14 = row 2 col 2")
        XCTAssertEqual(at(memo, now: F.date(2026, 11, 3)), "2026-10-01", "today in a neighbouring month on the grid → the 1st")
        XCTAssertEqual(at(memo, now: F.date(2026, 9, 29)), "2026-10-01")
        XCTAssertEqual(at(memo, now: F.date(2025, 10, 14)), "2026-10-01", "the same month of another year")
        assertRect(page.previewRect(for: memo, now: F.date(2027, 1, 1), calendar: tokyo), CGRect(x: 600, y: 0, width: 200, height: 175), "10/1 = row 0 col 3")
        XCTAssertEqual(at(memo, now: F.date(2026, 10, 31, 23, 59)), "2026-10-31", "the last day of the month")
        XCTAssertEqual(at(memo, now: F.date(2026, 10, 1, 0, 0)), "2026-10-01", "the first instant of the month")
        XCTAssertEqual(at(rect(100, 1040, 100, 1060), now: now14), "2026-10-14", "a centre exactly at memo.minY is the memo")
        XCTAssertEqual(at(rect(100, 1040, 100, 1059.8), now: now14), "2026-11-02", "just above it is the last row")
        for r in [rect(50, 1100, 50, 1100), rect(1390, 1749, 1395, 1750), rect(700, 1800, 720, 1900), rect(1450, 1100, 1500, 1200), rect(-50, 2000, -40, 2001)] {
            XCTAssertEqual(at(r, now: F.date(2026, 10, 6)), "2026-10-06", "taps, the page bottom and below the page: \(r)")
        }
        assertRect(page.previewRect(for: rect(-50, 2000, -40, 2001), now: F.date(2027, 3, 1), calendar: tokyo), CGRect(x: 600, y: 0, width: 200, height: 175), "below the page → the memo day's cell")
        // A grown row moves the memo area too.
        let inked = F.monthLayout([], ink: [.day(F.day(2026, 10, 7)): 300])
        XCTAssertGreaterThan(inked.memo.minY, 1050)
        XCTAssertEqual(ymd(inked.eventRange(for: rect(300, inked.memo.minY + 10, 700, inked.memo.minY + 50), now: now14, calendar: tokyo)), "2026-10-14")
        XCTAssertEqual(ymd(inked.eventRange(for: rect(300, 1050, 700, 1060), now: now14, calendar: tokyo)), "2026-11-04", "what used to be the memo area is now the last row (row 5, col 2)")
        // February 2026 (Monday start: grid 1/26 – 3/8): the memo day is the 1st when today is in October.
        let feb = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 2), events: [], inkBottoms: [:], now: now14, calendar: tokyo))
        XCTAssertEqual(ymd(feb.eventRange(for: memo, now: now14, calendar: tokyo)), "2026-02-01")
        XCTAssertEqual(ymd(feb.eventRange(for: memo, now: F.date(2026, 2, 20), calendar: tokyo)), "2026-02-20")
        XCTAssertEqual(ymd(feb.eventRange(for: rect(0, 0, 10, 10), now: now14, calendar: tokyo)), "2026-01-26")
        assertRect(feb.snapRect(for: allDay(F.day(2026, 2, 1)), calendar: tokyo), CGRect(x: 1200, y: 0, width: 200, height: 175), "2/1 is row 0 col 6")
    }

    func testMonthPageSnapRect() {
        let page = F.monthLayout([])
        let now14 = F.date(2026, 10, 14, 22, 30)
        assertRect(page.snapRect(for: allDay(F.day(2026, 10, 14)), calendar: tokyo), CGRect(x: 400, y: 350, width: 200, height: 175))
        assertRect(page.snapRect(for: timed(F.day(2026, 10, 14), 540, 600), calendar: tokyo), CGRect(x: 400, y: 350, width: 200, height: 175), "a timed range → its day's cell")
        assertRect(page.snapRect(for: allDay(F.day(2026, 9, 28)), calendar: tokyo), CGRect(x: 0, y: 0, width: 200, height: 175), "the first cell")
        assertRect(page.snapRect(for: allDay(F.day(2026, 11, 8)), calendar: tokyo), CGRect(x: 1200, y: 875, width: 200, height: 175), "the last cell")
        XCTAssertNil(page.snapRect(for: allDay(F.day(2026, 11, 9)), calendar: tokyo), "off the grid")
        XCTAssertNil(page.snapRect(for: allDay(F.day(2026, 9, 27)), calendar: tokyo), "off the grid")
        assertRect(page.previewRect(for: rect(850, 20, 950, 140), now: now14, calendar: tokyo), CGRect(x: 800, y: 0, width: 200, height: 175))
        assertRect(page.previewRect(for: rect(-50, 1000, -40, 1001), now: now14, calendar: tokyo), CGRect(x: 0, y: 875, width: 200, height: 175), "outside left → row 5 col 0")
        // A grown row moves the cells below it; the rects follow the layout.
        let inked = F.monthLayout([], ink: [.day(F.day(2026, 10, 7)): 300])
        let cell14 = inked.cells[.day(F.day(2026, 10, 14))]!
        XCTAssertGreaterThan(cell14.minY, 350, "ink on 10/7 moves row 2 down")
        XCTAssertEqual(ymd(inked.eventRange(for: cell14.insetBy(dx: 20, dy: 20), now: now14, calendar: tokyo)), "2026-10-14")
        assertRect(inked.previewRect(for: cell14.insetBy(dx: 20, dy: 20), now: now14, calendar: tokyo), cell14)
        assertRect(inked.snapRect(for: allDay(F.day(2026, 10, 14)), calendar: tokyo), cell14)
    }

    // MARK: Year page

    func testYearPageEveryDay() {
        for page in [F.yearLayout([], year: 2026), F.yearLayout([], year: 2028)] {
            for m in 1...12 {
                for d in 1...DayKey.daysInMonth(year: page.year, month: m) {
                    let cell = page.cellFrame(month: m, day: d)!
                    let key = DayKey(year: page.year, month: m, day: d)
                    let expected = "\(key) 00:00–\(key.adding(days: 1)) 00:00 allDay"
                    for r in [rect(cell.midX - 40, cell.midY - 20, cell.midX + 30, cell.midY + 25), rect(cell.midX, cell.midY, cell.midX, cell.midY)] {
                        let ev = page.eventRange(for: r, now: F.demoNow, calendar: tokyo)
                        XCTAssertEqual(fmt(ev), expected, "\(page.year) \(m)/\(d) \(r)")
                        assertRect(ev.flatMap { page.snapRect(for: $0, calendar: tokyo) }, cell, "\(page.year) \(m)/\(d) snapRect")
                    }
                    assertRect(page.snapRect(for: allDay(key), calendar: tokyo), cell)
                }
            }
        }
    }

    func testYearPageInvalidDatesAndEdges() {
        let y2026 = F.yearLayout([], year: 2026)
        let y2028 = F.yearLayout([], year: 2028)
        func center(_ page: YearPageLayout, _ m: Int, _ d: Int) -> CGPoint {
            let c = page.cellFrame(month: m, day: d)!
            return CGPoint(x: c.midX, y: c.midY)
        }
        func tap(_ page: YearPageLayout, _ m: Int, _ d: Int) -> String {
            let c = center(page, m, d)
            return ymd(page.eventRange(for: rect(c.x, c.y, c.x, c.y), now: F.demoNow, calendar: tokyo))
        }
        func at(_ page: YearPageLayout, _ r: CGRect) -> String { ymd(page.eventRange(for: r, now: F.demoNow, calendar: tokyo)) }
        XCTAssertEqual(tap(y2026, 2, 29), "2026-02-28", "2/29 of a common year → 2/28")
        XCTAssertEqual(tap(y2026, 2, 30), "2026-02-28")
        XCTAssertEqual(tap(y2026, 2, 31), "2026-02-28")
        XCTAssertEqual(tap(y2028, 2, 29), "2028-02-29", "2/29 of a leap year exists")
        XCTAssertEqual(tap(y2028, 2, 30), "2028-02-29")
        XCTAssertEqual(tap(y2028, 2, 31), "2028-02-29")
        XCTAssertEqual(tap(y2026, 4, 31), "2026-04-30")
        XCTAssertEqual(tap(y2026, 6, 31), "2026-06-30")
        XCTAssertEqual(tap(y2026, 9, 31), "2026-09-30")
        XCTAssertEqual(tap(y2026, 11, 31), "2026-11-30")
        let c231 = center(y2026, 2, 31)
        assertRect(y2026.previewRect(for: rect(c231.x, c231.y, c231.x, c231.y), now: F.demoNow, calendar: tokyo), CGRect(x: 168, y: 27 * 60, width: 112, height: 60), "2/31 previews 2/28's cell")
        let c231leap = center(y2028, 2, 31)
        assertRect(y2028.previewRect(for: rect(c231leap.x, c231leap.y, c231leap.x, c231leap.y), now: F.demoNow, calendar: tokyo), CGRect(x: 168, y: 28 * 60, width: 112, height: 60), "2/31 previews 2/29's cell in 2028")
        assertRect(y2026.snapRect(for: allDay(F.day(2026, 2, 28)), calendar: tokyo), y2026.cellFrame(month: 2, day: 28)!)
        assertRect(y2026.snapRect(for: timed(F.day(2026, 7, 7), 540, 600), calendar: tokyo), y2026.cellFrame(month: 7, day: 7)!, "a timed range → its day's cell")
        XCTAssertNil(y2026.snapRect(for: allDay(F.day(2027, 1, 1)), calendar: tokyo), "another year")
        XCTAssertNil(y2026.snapRect(for: allDay(F.day(2025, 12, 31)), calendar: tokyo), "the year before")
        // The gutter → January; beyond the right edge → December; above / below → day 1 / 31 (clamped to the month).
        XCTAssertEqual(at(y2026, rect(0, 130, 40, 150)), "2026-01-03", "the day-number gutter → January")
        XCTAssertEqual(at(y2026, rect(-100, 130, -50, 150)), "2026-01-03", "left of the paper")
        XCTAssertEqual(at(y2026, rect(1450, 130, 1500, 150)), "2026-12-03", "right of the paper → December")
        XCTAssertEqual(at(y2026, rect(300, -100, 320, -50)), "2026-03-01", "above the paper → day 1")
        XCTAssertEqual(at(y2026, rect(300, 1900, 320, 2000)), "2026-03-31", "below the paper → day 31")
        XCTAssertEqual(at(y2026, rect(400, 1900, 420, 2000)), "2026-04-30", "below the paper in April → 4/30")
        XCTAssertEqual(at(y2026, rect(200, 5000, 200, 5000)), "2026-02-28", "far below in February → 2/28")
        XCTAssertEqual(at(y2026, rect(1400, 1860, 1400, 1860)), "2026-12-31", "the bottom-right corner")
        XCTAssertEqual(at(y2026, rect(56 + 112 * 4 - 30, 300, 56 + 112 * 4 + 50, 380)), "2026-05-06", "a rect over two cells → the one under its centre")
        XCTAssertNil(y2026.eventRange(for: CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1), now: F.demoNow, calendar: tokyo), "a NaN rect")
        // Rows that grew (ink) move the cells: the rect follows the layout.
        let inked = F.yearLayout([], year: 2026, ink: [.yearDay(month: 3, day: 5): 200])
        let cell = inked.cellFrame(month: 7, day: 20)!
        XCTAssertGreaterThan(cell.minY, 19 * 60, "ink on 3/5 moves row 20 down")
        XCTAssertEqual(ymd(inked.eventRange(for: cell.insetBy(dx: 10, dy: 10), now: F.demoNow, calendar: tokyo)), "2026-07-20")
        assertRect(inked.previewRect(for: cell.insetBy(dx: 10, dy: 10), now: F.demoNow, calendar: tokyo), cell)
    }

    // MARK: Randomized invariant: eventRange(snapRect(eventRange(r))) == eventRange(r)

    func testSnapRectIsConsistentWithEventRange() {
        var rng = Rng(seed: 20_261_004)
        let now = F.date(2026, 10, 14, 9) // the October page's memo area means 10/14; the other months' the 1st
        let feb = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 2), events: [], inkBottoms: [:], now: now, calendar: tokyo))
        let pages: [(String, any PageLayout)] = [
            ("day", F.dayLayout([], focus: F.day(2026, 10, 4))),
            ("week", F.weekLayout([])),
            ("month-2026-10", F.monthLayout([])),
            ("month-2026-02", feb),
            ("year-2026", F.yearLayout([], year: 2026)),
            ("year-2028", F.yearLayout([], year: 2028)),
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
                    XCTFail("\(label): eventRange is nil")
                    continue
                }
                XCTAssertTrue(ev.isValid, label)
                guard let snap = page.snapRect(for: ev, calendar: tokyo) else {
                    XCTFail("\(label): snapRect is nil for \(fmt(ev))")
                    continue
                }
                XCTAssertTrue(snap.width > 0 && snap.height > 0, "\(label): the snapped rect has an area")
                XCTAssertEqual(page.eventRange(for: snap, now: now, calendar: tokyo), ev, "\(label): idempotent (\(fmt(ev)) from \(snap))")
                let startDay = DayKey(ev.start, calendar: tokyo)
                let startMin = TimedEventEngine.minutesOfDay(ev.start, calendar: tokyo)
                let endMin = DayKey(ev.end, calendar: tokyo) == startDay ? TimedEventEngine.minutesOfDay(ev.end, calendar: tokyo) : 1440
                if page.kind == .month || page.kind == .year {
                    XCTAssertTrue(ev.allDay, label)
                    XCTAssertEqual(ev.start, startDay.startOfDay(in: tokyo), "\(label): starts at midnight")
                    XCTAssertEqual(DayKey(ev.end, calendar: tokyo), startDay.adding(days: 1), "\(label): one day long")
                } else {
                    XCTAssertFalse(ev.allDay, label)
                    XCTAssertTrue(DayKey(ev.end, calendar: tokyo) == startDay || ev.end == startDay.adding(days: 1).startOfDay(in: tokyo), "\(label): ends on the day or at the next midnight")
                    XCTAssertEqual(startMin % 15, 0, label)
                    XCTAssertEqual(endMin % 15, 0, label)
                    XCTAssertGreaterThanOrEqual(endMin - startMin, 15, label)
                    XCTAssertTrue(startMin >= 0 && endMin <= 1440, label)
                }
                if let m = page as? MonthPageLayout {
                    let cy = min(max(r.standardized.midY, 0), H)
                    if cy >= m.memo.minY {
                        let memoDay = m.month == YearMonth(year: 2026, month: 10) ? "2026-10-14" : m.month.firstDay.description
                        XCTAssertEqual(startDay.description, memoDay, "\(label): memo day")
                    }
                    XCTAssertEqual(m.cells[.day(startDay)], snap, "\(label): the snapped rect is the day's cell")
                } else if let y = page as? YearPageLayout {
                    XCTAssertEqual(startDay.year, y.year, label)
                    XCTAssertTrue(startDay.isValid, "\(label): an existing date")
                    XCTAssertEqual(y.cellFrame(month: startDay.month, day: startDay.day), snap, "\(label): the snapped rect is the date's cell")
                } else if let w = page as? WeekPageLayout {
                    guard let col = w.days.firstIndex(of: startDay) else {
                        XCTFail("\(label): the day is not in the week")
                        continue
                    }
                    assertRect(snap, CGRect(x: w.columnFrame(col).minX, y: w.minutesToY(startMin), width: colW, height: w.minutesToY(endMin) - w.minutesToY(startMin)), "\(label): column × snapped minutes")
                } else if let d = page as? DayPageLayout {
                    XCTAssertEqual(startDay, d.day, label)
                    assertRect(snap, CGRect(x: 72, y: d.minutesToY(startMin), width: 588, height: d.minutesToY(endMin) - d.minutesToY(startMin)), "\(label): timeline column × snapped minutes")
                }
            }
        }
    }
}
