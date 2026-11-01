import XCTest
import Foundation
import CoreGraphics
import Layout

/// A finger's single tap on a date (1.1, M7A_CONTRACT D4, §4.1–§4.3). Zooms: the overviews of the
/// iPhone (month 0.2871, year 0.2871) and the 13-inch iPad (month 0.7371, year 0.607).
final class DateTapTests: XCTestCase {
    private typealias F = M3aFixtures
    private let iPhone: CGFloat = 0.2871
    private let iPad: CGFloat = 0.607

    func testMinTargetRule() {
        XCTAssertEqual(DateTap.minPoints, 44)
        for small in [false, true] {
            for finger in [false, true] {
                let tag = "small screen \(small), 指でも書く \(finger)"
                XCTAssertEqual(DateTap.minTarget(kind: .month, zoom: 0.5, smallScreen: small, allowFinger: finger), finger ? nil : 88, "month: only with 指でも書く off (\(tag))")
                XCTAssertEqual(DateTap.minTarget(kind: .year, zoom: 0.5, smallScreen: small, allowFinger: finger), small || !finger ? 88 : nil, "year: a small screen or 指でも書く off (\(tag))")
                XCTAssertNil(DateTap.minTarget(kind: .week, zoom: 0.5, smallScreen: small, allowFinger: finger), "week (\(tag))")
                XCTAssertNil(DateTap.minTarget(kind: .day, zoom: 0.5, smallScreen: small, allowFinger: finger), "day (\(tag))")
                for bad: CGFloat in [.nan, 0, -1, .infinity] {
                    for kind in PageKind.allCases {
                        XCTAssertNil(DateTap.minTarget(kind: kind, zoom: bad, smallScreen: small, allowFinger: finger), "\(kind) zoom \(bad) (\(tag))")
                    }
                }
            }
        }
        XCTAssertEqual(DateTap.minTarget(kind: .month, zoom: iPhone, smallScreen: true, allowFinger: false)!, 153.256, accuracy: 1e-3)
        XCTAssertEqual(DateTap.minTarget(kind: .year, zoom: iPad, smallScreen: false, allowFinger: false)!, 72.488, accuracy: 1e-3)
    }

    func testTargetOrderOnTheYearPage() {
        let page = F.yearLayout(F.demo)
        // ① hit(at:): the chips (thick → the event, thin → the day) and the weekday frames come first.
        for chip in page.chips {
            let p = CGPoint(x: chip.frame.midX, y: chip.frame.midY)
            for (small, finger) in [(true, true), (true, false), (false, true), (false, false)] {
                XCTAssertEqual(DateTap.target(layout: page, point: p, zoom: iPhone, smallScreen: small, allowFinger: finger, currentMonth: 10), page.hit(at: p), "chip \(chip.title) \(chip.day)")
            }
        }
        let empty = F.yearLayout([])
        let c107 = empty.cellFrame(month: 10, day: 7)!
        XCTAssertEqual(DateTap.target(layout: empty, point: CGPoint(x: c107.minX + 10, y: c107.minY + 10), zoom: iPad, smallScreen: false, allowFinger: true, currentMonth: 10), .date(F.day(2026, 10, 7)), "the weekday frame")
        // ② the gutter's number → this month's day (whatever the zoom).
        let p15 = CGPoint(x: 20, y: 870)
        for zoom: CGFloat in [iPhone, iPad, 2, .nan, 0] {
            XCTAssertEqual(DateTap.target(layout: empty, point: p15, zoom: zoom, smallScreen: false, allowFinger: true, currentMonth: 10), .date(F.day(2026, 10, 15)), "zoom \(zoom)")
        }
        XCTAssertEqual(DateTap.target(layout: empty, point: p15, zoom: iPad, smallScreen: false, allowFinger: true, currentMonth: 3), .date(F.day(2026, 3, 15)), "the month the screen passes")
        XCTAssertNil(DateTap.target(layout: empty, point: CGPoint(x: 20, y: 30 * 60 + 30), zoom: iPhone, smallScreen: true, allowFinger: true, currentMonth: 11), "31 in November: nothing (M7A-3)")
        // ③ the 44 pt target (a small screen, or 指でも書く off).
        let inCell = CGPoint(x: c107.minX + 70, y: c107.minY + 50)
        XCTAssertEqual(DateTap.target(layout: empty, point: inCell, zoom: iPad, smallScreen: false, allowFinger: false, currentMonth: 10), .date(F.day(2026, 10, 7)), "iPad, 指でも書く off: 44 pt (M7A-2)")
        XCTAssertNil(DateTap.target(layout: empty, point: inCell, zoom: iPad, smallScreen: false, allowFinger: true, currentMonth: 10), "iPad, 指でも書く on: the 1.0 frames")
        XCTAssertEqual(DateTap.target(layout: empty, point: inCell, zoom: iPhone, smallScreen: true, allowFinger: true, currentMonth: 10), .date(F.day(2026, 10, 7)), "iPhone: 44 pt whatever 指でも書く (1.0.1)")
        XCTAssertNil(DateTap.target(layout: empty, point: CGPoint(x: c107.minX + 100, y: c107.minY + 55), zoom: iPad, smallScreen: false, allowFinger: false, currentMonth: 10), "beyond 72.5 lu")
        XCTAssertEqual(DateTap.target(layout: empty, point: inCell, zoom: iPad, smallScreen: false, allowFinger: false, currentMonth: 10), empty.hit(at: inCell, minTarget: 44 / iPad))
        // A zoom that is not a positive number: hit(at:) and the gutter only.
        for bad: CGFloat in [.nan, 0, -1] {
            XCTAssertNil(DateTap.target(layout: empty, point: inCell, zoom: bad, smallScreen: true, allowFinger: false, currentMonth: 10), "zoom \(bad)")
        }
        XCTAssertNil(DateTap.target(layout: empty, point: CGPoint(x: -5, y: 870), zoom: iPhone, smallScreen: true, allowFinger: false, currentMonth: 10), "the left margin")
        XCTAssertNil(DateTap.target(layout: empty, point: CGPoint(x: 700, y: 1861), zoom: iPhone, smallScreen: true, allowFinger: false, currentMonth: 10), "below the paper")
    }

    func testMonthTargetOnlyWhenFingerDrawingIsOff() {
        let page = F.monthLayout([])
        let d14 = F.day(2026, 10, 14)
        let cell = page.cells[.day(d14)]! // (400, 350, 200, 175)
        let upper = CGPoint(x: cell.midX, y: cell.minY + 40) // below the 1.0 date frame, inside every 44 pt target (≥ 59.7 lu)
        let onDigits = CGPoint(x: cell.minX + 20, y: cell.minY + 12) // inside the 192 × 24 date frame
        for small in [true, false] {
            for zoom: CGFloat in [iPhone, 0.5314, 0.7371] {
                XCTAssertEqual(DateTap.target(layout: page, point: upper, zoom: zoom, smallScreen: small, allowFinger: false, currentMonth: 10), .date(d14), "off: 44 pt (zoom \(zoom), small \(small))")
                XCTAssertNil(DateTap.target(layout: page, point: upper, zoom: zoom, smallScreen: small, allowFinger: true, currentMonth: 10), "on: the 1.0 frame only (M7A-1)")
                XCTAssertEqual(DateTap.target(layout: page, point: onDigits, zoom: zoom, smallScreen: small, allowFinger: true, currentMonth: 10), .date(d14), "on: the digits")
                XCTAssertEqual(DateTap.target(layout: page, point: onDigits, zoom: zoom, smallScreen: small, allowFinger: false, currentMonth: 10), .date(d14), "off: the digits")
            }
        }
        XCTAssertNil(DateTap.target(layout: page, point: CGPoint(x: cell.midX, y: cell.maxY - 2), zoom: 0.7371, smallScreen: false, allowFinger: false, currentMonth: 10), "the bottom of the cell is for writing")
        XCTAssertNil(DateTap.target(layout: page, point: CGPoint(x: 700, y: 1100), zoom: iPhone, smallScreen: true, allowFinger: false, currentMonth: 10), "the memo area")
        for bad: CGFloat in [.nan, 0, -1] {
            XCTAssertNil(DateTap.target(layout: page, point: upper, zoom: bad, smallScreen: true, allowFinger: false, currentMonth: 10), "zoom \(bad): hit(at:) only")
            XCTAssertEqual(DateTap.target(layout: page, point: onDigits, zoom: bad, smallScreen: true, allowFinger: false, currentMonth: 10), .date(d14))
        }
        // Chips first.
        let busy = F.monthLayout(F.demo)
        for chip in busy.timedChips {
            let p = CGPoint(x: chip.frame.midX, y: chip.frame.midY)
            XCTAssertEqual(DateTap.target(layout: busy, point: p, zoom: iPhone, smallScreen: true, allowFinger: false, currentMonth: 10), busy.hit(at: p), "chip \(chip.day)")
        }
    }

    func testGutterIsTheWholeRowOnASmallScreen() {
        let page = F.yearLayout([])
        let edge = CGPoint(x: 20, y: 842) // the top edge of row 15, outside the number (870 ± 14)
        XCTAssertEqual(DateTap.target(layout: page, point: edge, zoom: iPhone, smallScreen: true, allowFinger: true, currentMonth: 10), .date(F.day(2026, 10, 15)), "iPhone, 指でも書く on: the whole row (16 × 17 pt)")
        XCTAssertEqual(DateTap.target(layout: page, point: edge, zoom: iPhone, smallScreen: true, allowFinger: false, currentMonth: 10), .date(F.day(2026, 10, 15)), "iPhone, off")
        XCTAssertEqual(DateTap.target(layout: page, point: edge, zoom: iPad, smallScreen: false, allowFinger: false, currentMonth: 10), .date(F.day(2026, 10, 15)), "iPad, off: the whole row")
        XCTAssertNil(DateTap.target(layout: page, point: edge, zoom: iPad, smallScreen: false, allowFinger: true, currentMonth: 10), "iPad, on: the number only")
        XCTAssertEqual(DateTap.target(layout: page, point: CGPoint(x: 20, y: 870), zoom: iPad, smallScreen: false, allowFinger: true, currentMonth: 10), .date(F.day(2026, 10, 15)), "iPad, on: on the number")
        XCTAssertEqual(DateTap.target(layout: page, point: CGPoint(x: 20, y: 884), zoom: iPad, smallScreen: false, allowFinger: true, currentMonth: 10), .date(F.day(2026, 10, 15)))
        XCTAssertNil(DateTap.target(layout: page, point: CGPoint(x: 20, y: 885), zoom: iPad, smallScreen: false, allowFinger: true, currentMonth: 10))
        // On screen: the whole row 56 × 60 lu, the number 56 × 28 lu.
        XCTAssertEqual(56 * iPhone, 16.08, accuracy: 0.01)
        XCTAssertEqual(60 * iPhone, 17.23, accuracy: 0.01)
        XCTAssertEqual(28 * iPhone, 8.04, accuracy: 0.01)
        // A day the month does not have, and the leap day.
        XCTAssertNil(DateTap.target(layout: page, point: CGPoint(x: 20, y: 30 * 60 + 30), zoom: iPhone, smallScreen: true, allowFinger: true, currentMonth: 11))
        XCTAssertEqual(DateTap.target(layout: F.yearLayout([], year: 2028), point: CGPoint(x: 20, y: 28 * 60 + 30), zoom: iPhone, smallScreen: true, allowFinger: true, currentMonth: 2), .date(F.day(2028, 2, 29)))
        XCTAssertNil(DateTap.target(layout: page, point: CGPoint(x: 20, y: 28 * 60 + 30), zoom: iPhone, smallScreen: true, allowFinger: true, currentMonth: 2))
    }

    func testWeekAndDayAreUnchanged() {
        let week = F.weekLayout(F.demo)
        let day = F.dayLayout(F.demo)
        var rng = M3aFixtures.Rng(seed: 0x0D47_E7A9)
        for _ in 0..<60 {
            let p = CGPoint(x: CGFloat(rng.int(1500)) - 50, y: CGFloat(rng.int(3300)) - 50)
            for (small, finger) in [(true, true), (true, false), (false, true), (false, false)] {
                for zoom: CGFloat in [0.2233, 0.4654, 2, .nan] {
                    XCTAssertEqual(DateTap.target(layout: week, point: p, zoom: zoom, smallScreen: small, allowFinger: finger, currentMonth: 10), week.hit(at: p), "week \(p)")
                    XCTAssertEqual(DateTap.target(layout: day, point: p, zoom: zoom, smallScreen: small, allowFinger: finger, currentMonth: 10), day.hit(at: p), "day \(p)")
                }
            }
        }
        for box in week.timedBoxes {
            XCTAssertEqual(DateTap.target(layout: week, point: CGPoint(x: box.frame.midX, y: box.frame.midY), zoom: 0.5, smallScreen: false, allowFinger: false, currentMonth: 10), .timedBox(box.eventId))
        }
        for box in day.timedBoxes {
            XCTAssertEqual(DateTap.target(layout: day, point: CGPoint(x: box.frame.midX, y: box.frame.midY), zoom: 0.5, smallScreen: true, allowFinger: true, currentMonth: 10), .timedBox(box.eventId))
        }
        XCTAssertNil(DateTap.target(layout: day, point: CGPoint(x: 300, y: 2600), zoom: 0.5, smallScreen: true, allowFinger: false, currentMonth: 10), "the day's free memo area")
    }
}
