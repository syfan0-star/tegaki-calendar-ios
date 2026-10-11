import XCTest
import Foundation
import CoreGraphics
import Layout

/// Timed-event overlap layout (M3A_CONTRACT §1.4). Expectations are copied from the web version's
/// tests/event-layout.test.mjs (layoutTimedEvents): `[startMin, endMin, col, cols]` per event id.
final class TimedEventEngineTests: XCTestCase {
    private typealias F = M3aFixtures
    private var tokyo: Calendar { F.tokyo }
    private let webDay = M3aFixtures.day(2026, 10, 4)

    private func timed(_ id: String, _ d: Int, _ sh: Int, _ sm: Int, _ eh: Int, _ em: Int, endDay: Int? = nil, title: String? = nil) -> LayoutEvent {
        F.timed(id, d, sh, sm, eh, em, endDay: endDay, title: title)
    }

    private func layoutMap(_ events: [LayoutEvent], _ day: DayKey? = nil) -> [String: [Int]] {
        var out: [String: [Int]] = [:]
        for slot in TimedEventEngine.layout(events: events, day: day ?? webDay, calendar: tokyo) {
            out[slot.event.id] = [slot.startMinute, slot.endMinute, slot.column, slot.columns]
        }
        return out
    }

    func testSingleEventAndAllDayExclusion() {
        XCTAssertEqual(layoutMap([timed("a", 4, 9, 0, 10, 30), F.allDay("ad", 4, 5)]), ["a": [540, 630, 0, 1]])
        XCTAssertEqual(TimedEventEngine.layout(events: [], day: webDay, calendar: tokyo).count, 0)
        XCTAssertEqual(layoutMap([F.allDay("ad", 1, 20)]), [:], "a long all-day event is never a box")
    }

    func testBackToBackEventsDoNotOverlap() {
        XCTAssertEqual(
            layoutMap([timed("a", 4, 9, 0, 10, 0), timed("b", 4, 10, 0, 11, 0), timed("c", 4, 11, 0, 12, 0)]),
            ["a": [540, 600, 0, 1], "b": [600, 660, 0, 1], "c": [660, 720, 0, 1]]
        )
    }

    func testIdenticalStartsLongerFirstThenTitle() {
        XCTAssertEqual(layoutMap([timed("short", 4, 9, 0, 10, 0), timed("long", 4, 9, 0, 11, 0)]), ["long": [540, 660, 0, 2], "short": [540, 600, 1, 2]])
        let same = TimedEventEngine.layout(events: [timed("x2", 4, 9, 0, 10, 0, title: "B"), timed("x1", 4, 9, 0, 10, 0, title: "A")], day: webDay, calendar: tokyo)
        XCTAssertEqual(same.map { "\($0.event.title):\($0.column)/\($0.columns)" }, ["A:0/2", "B:1/2"])
        let triple = layoutMap(["p", "q", "r"].map { timed($0, 4, 14, 0, 15, 0) })
        XCTAssertEqual(triple, ["p": [840, 900, 0, 3], "q": [840, 900, 1, 3], "r": [840, 900, 2, 3]])
        // Same title → by id.
        let byId = TimedEventEngine.layout(events: [timed("b", 4, 9, 0, 10, 0, title: "同じ"), timed("a", 4, 9, 0, 10, 0, title: "同じ")], day: webDay, calendar: tokyo)
        XCTAssertEqual(byId.map(\.event.id), ["a", "b"])
    }

    func testNestedEvents() {
        XCTAssertEqual(layoutMap([timed("inner", 4, 10, 0, 11, 0), timed("outer", 4, 9, 0, 12, 0)]), ["outer": [540, 720, 0, 2], "inner": [600, 660, 1, 2]])
        XCTAssertEqual(
            layoutMap([timed("outer", 4, 9, 0, 12, 0), timed("inner1", 4, 10, 0, 11, 0), timed("inner2", 4, 10, 30, 11, 30)]),
            ["outer": [540, 720, 0, 3], "inner1": [600, 660, 1, 3], "inner2": [630, 690, 2, 3]]
        )
    }

    func testGreedyColumnReuseAndTransitiveClusters() {
        XCTAssertEqual(
            layoutMap([timed("a", 4, 9, 0, 12, 0), timed("b", 4, 9, 0, 10, 0), timed("c", 4, 10, 0, 11, 0)]),
            ["a": [540, 720, 0, 2], "b": [540, 600, 1, 2], "c": [600, 660, 1, 2]],
            "c reuses b's column"
        )
        XCTAssertEqual(
            layoutMap([timed("a", 4, 9, 0, 10, 0), timed("b", 4, 9, 30, 10, 30), timed("c", 4, 10, 15, 11, 0), timed("d", 4, 11, 0, 12, 0)]),
            ["a": [540, 600, 0, 2], "b": [570, 630, 1, 2], "c": [615, 660, 0, 2], "d": [660, 720, 0, 1]],
            "a–b–c share a cluster through b; d is separate"
        )
    }

    func testEventsCrossingMidnightAreClippedPerDay() {
        let overnight = timed("overnight", 3, 22, 0, 2, 0, endDay: 4)
        XCTAssertEqual(layoutMap([overnight], F.day(2026, 10, 3)), ["overnight": [1320, 1440, 0, 1]])
        XCTAssertEqual(layoutMap([overnight], F.day(2026, 10, 4)), ["overnight": [0, 120, 0, 1]])
        XCTAssertEqual(layoutMap([overnight], F.day(2026, 10, 5)), [:])
        let multi = timed("multi", 3, 12, 0, 12, 0, endDay: 5)
        XCTAssertEqual(layoutMap([multi], F.day(2026, 10, 3)), ["multi": [720, 1440, 0, 1]])
        XCTAssertEqual(layoutMap([multi], F.day(2026, 10, 4)), ["multi": [0, 1440, 0, 1]])
        XCTAssertEqual(layoutMap([multi], F.day(2026, 10, 5)), ["multi": [0, 720, 0, 1]])
        let toMidnight = timed("toMidnight", 4, 23, 0, 0, 0, endDay: 5)
        XCTAssertEqual(layoutMap([toMidnight], F.day(2026, 10, 4)), ["toMidnight": [1380, 1440, 0, 1]])
        XCTAssertEqual(layoutMap([toMidnight], F.day(2026, 10, 5)), [:], "ending exactly at midnight is not on the next day")
        XCTAssertEqual(layoutMap([overnight, timed("early", 4, 1, 0, 3, 0)], F.day(2026, 10, 4)), ["overnight": [0, 120, 0, 2], "early": [60, 180, 1, 2]])
    }

    func testFifteenMinuteVisualMinimum() {
        XCTAssertEqual(layoutMap([timed("tiny", 4, 9, 0, 9, 5)]), ["tiny": [540, 555, 0, 1]])
        XCTAssertEqual(layoutMap([timed("zero", 4, 9, 0, 9, 0)]), ["zero": [540, 555, 0, 1]])
        XCTAssertEqual(layoutMap([timed("inverted", 4, 9, 0, 8, 0)]), ["inverted": [540, 555, 0, 1]])
        XCTAssertEqual(layoutMap([timed("lateZero", 4, 23, 55, 23, 55)]), ["lateZero": [1425, 1440, 0, 1]], "near midnight the box stays inside the day")
        XCTAssertEqual(layoutMap([timed("lateShort", 4, 23, 50, 0, 0, endDay: 5)]), ["lateShort": [1425, 1440, 0, 1]])
        XCTAssertEqual(layoutMap([timed("tiny", 4, 9, 0, 9, 5), timed("next", 4, 9, 10, 10, 0)]), ["tiny": [540, 555, 0, 2], "next": [550, 600, 1, 2]], "the minimum counts for overlap")
        XCTAssertEqual(layoutMap([timed("tiny", 4, 9, 0, 9, 5), timed("next", 4, 9, 15, 10, 0)]), ["tiny": [540, 555, 0, 1], "next": [555, 600, 0, 1]])
        let v = TimedEventEngine.visualMinutes(of: timed("x", 4, 23, 55, 23, 55), day: webDay, calendar: tokyo)
        XCTAssertEqual(v.start, 1425)
        XCTAssertEqual(v.end, 1440)
    }

    func testOutputOrder() {
        let events = [timed("c", 4, 15, 0, 16, 0), timed("a", 4, 8, 0, 9, 0), timed("b", 4, 8, 30, 9, 30)]
        XCTAssertEqual(TimedEventEngine.layout(events: events, day: webDay, calendar: tokyo).map(\.event.id), ["a", "b", "c"])
    }

    func testRandomSchedulesNeverCollide() {
        var rng = F.Rng(seed: 42)
        for round in 0..<300 {
            let n = 1 + rng.int(12)
            let events = (0..<n).map { i -> LayoutEvent in
                let startMin = rng.int(96) * 15 - 120 // may start the previous day
                let len = rng.int(16) * 15            // may be zero-length
                let start = tokyo.date(byAdding: .minute, value: startMin, to: F.october(4))!
                return LayoutEvent(id: "e\(i)", title: "e\(i)", allDay: false, start: start, end: start.addingTimeInterval(TimeInterval(len * 60)), colorHex: "#039be5", calendarId: "primary")
            }
            let out = TimedEventEngine.layout(events: events, day: webDay, calendar: tokyo)
            for it in out {
                XCTAssertTrue(it.startMinute >= 0 && it.endMinute <= 1440 && it.endMinute - it.startMinute >= 15, "round \(round): \(it.event.id) range")
                XCTAssertTrue(it.column >= 0 && it.column < it.columns, "round \(round): \(it.event.id) column")
            }
            for i in out.indices {
                for j in out.indices where j > i {
                    let a = out[i], b = out[j]
                    if a.startMinute < b.endMinute && b.startMinute < a.endMinute {
                        XCTAssertNotEqual(a.column, b.column, "round \(round): \(a.event.id) and \(b.event.id) collide")
                        XCTAssertEqual(a.columns, b.columns, "round \(round): overlapping events share a cluster")
                    }
                }
            }
        }
    }

    func testTimeTexts() {
        XCTAssertEqual(TimedEventEngine.minutesOfDay(F.october(4, 9, 5), calendar: tokyo), 545)
        XCTAssertEqual(TimedEventEngine.minutesOfDay(F.october(4, 0, 0), calendar: tokyo), 0)
        XCTAssertEqual(TimedEventEngine.timeText(F.october(4, 9, 5), calendar: tokyo), "9:05")
        XCTAssertEqual(TimedEventEngine.timeText(F.october(4, 13, 0), calendar: tokyo), "13:00")
        XCTAssertEqual(TimedEventEngine.timeRangeText(start: F.october(4, 9, 0), end: F.october(4, 10, 30), calendar: tokyo), "9:00〜10:30")
    }

    func testBoxFrame() {
        let colW = PaperSpec.weekColumnWidth
        let inner = colW - 8
        let w = (inner - 2) / 2
        XCTAssertEqual(inner, 182.857142857, accuracy: 1e-6)
        XCTAssertEqual(w, 90.4285714285, accuracy: 1e-6)
        let box = TimedEventEngine.boxFrame(columnX: 64, columnWidth: colW, startMinute: 600, endMinute: 690, column: 1, columns: 2, hourHeight: 80, padLeft: 2, padRight: 6, gap: 2)
        assertRect(box, CGRect(x: 64 + 2 + w + 2, y: 801, width: w, height: 118), "second of two columns")
        let first = TimedEventEngine.boxFrame(columnX: 64, columnWidth: colW, startMinute: 600, endMinute: 690, column: 0, columns: 2, hourHeight: 80, padLeft: 2, padRight: 6, gap: 2)
        assertRect(first, CGRect(x: 66, y: 801, width: w, height: 118), "first of two columns")
        let single = TimedEventEngine.boxFrame(columnX: 64, columnWidth: colW, startMinute: 540, endMinute: 555, column: 0, columns: 1, hourHeight: 80, padLeft: 2, padRight: 6, gap: 2)
        assertRect(single, CGRect(x: 66, y: 721, width: inner, height: 18), "a 15-minute box")
        let narrow = TimedEventEngine.boxFrame(columnX: 0, columnWidth: 40, startMinute: 0, endMinute: 15, column: 1, columns: 8, hourHeight: 80, padLeft: 2, padRight: 6, gap: 2)
        XCTAssertEqual(narrow.width, 4, accuracy: 1e-9, "very narrow columns drop the gap")
        XCTAssertEqual(narrow.minX, 6, accuracy: 1e-9)
        let tiny = TimedEventEngine.boxFrame(columnX: 0, columnWidth: 100, startMinute: 0, endMinute: 2, column: 0, columns: 1, hourHeight: 80, padLeft: 2, padRight: 6, gap: 2)
        XCTAssertEqual(tiny.height, 4, "minimum height")
        let clamped = TimedEventEngine.boxFrame(columnX: 0, columnWidth: 100, startMinute: 0, endMinute: 60, column: 9, columns: 0, hourHeight: 80, padLeft: 2, padRight: 6, gap: 2)
        assertRect(clamped, CGRect(x: 2, y: 1, width: 92, height: 78), "bad column / columns are clamped")
        let day = TimedEventEngine.boxFrame(columnX: 72, columnWidth: 588, startMinute: 600, endMinute: 690, column: 1, columns: 2, hourHeight: 100, padLeft: 4, padRight: 14, gap: 3)
        assertRect(day, CGRect(x: 76 + 283.5 + 3, y: 1001, width: 283.5, height: 148), "the day page's column")
    }
}
