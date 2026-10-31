import Access
import InkModel
import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

/// The screen's pure helpers: the height left for the paper under the fixed all-day band (M4C
/// contract §5.1 / §7.3; measured at the overview: lanes 18 pt, gaps 2 pt, padding 3 + 4, so `fitAll`
/// on the screen matches the canvas's paper area), M5's gate of the 19 operations (M5_CONTRACT
/// §3.1 / §7.6), M6's failure texts of the two-format import door (M6_CONTRACT §1.2 / §7.2), and
/// 1.1's (M7A_CONTRACT §7.2) date taps (`DateTap`), the year's gutter numbers, the four toasts, the
/// refused event below 24:00, the starting tool and toolbar, the eraser's note and the log lines.
@MainActor
final class CalendarRootScreenTests: XCTestCase {
    private let week: [DayKey] = (0..<7).map { DayKey(year: 2026, month: 10, day: 5).adding(days: $0) }
    private let wednesday = DayKey(year: 2026, month: 10, day: 7)

    private func band(kind: PageKind, lanes: Int) -> AllDayBandLayout {
        var band = AllDayBandLayout.empty(kind: kind, days: kind == .day ? [wednesday] : week)
        band.laneCount = lanes
        return band
    }

    func testPaperAreaHeightWithoutABand() {
        XCTAssertEqual(CalendarRootScreen.paperAreaHeight(area: 1180, band: nil, kind: .month), 1180)
        XCTAssertEqual(CalendarRootScreen.paperAreaHeight(area: 1180, band: nil, kind: .week), 1180)
        XCTAssertEqual(CalendarRootScreen.paperAreaHeight(area: 580, band: nil, kind: .day), 580)
        // A band without lanes (no all-day events) takes nothing either (M4B-2).
        XCTAssertEqual(CalendarRootScreen.paperAreaHeight(area: 1180, band: band(kind: .week, lanes: 0), kind: .week), 1180)
        XCTAssertEqual(CalendarRootScreen.paperAreaHeight(area: 1180, band: band(kind: .day, lanes: 0), kind: .day), 1180)
    }

    func testPaperAreaHeightUnderAOneLaneBand() {
        // 3 + 18 + 4 = 25 pt (M4C contract §1.2: the CI's week / day have one lane).
        XCTAssertEqual(CalendarRootScreen.paperAreaHeight(area: 1180, band: band(kind: .week, lanes: 1), kind: .week), 1180 - 25, accuracy: 1e-9)
        XCTAssertEqual(CalendarRootScreen.paperAreaHeight(area: 1180, band: band(kind: .day, lanes: 1), kind: .day), 1180 - 25, accuracy: 1e-9)
        // The same on every device (the band's height is fixed at the overview, §1.6).
        XCTAssertEqual(CalendarRootScreen.paperAreaHeight(area: 580, band: band(kind: .week, lanes: 1), kind: .week), 555, accuracy: 1e-9)
        XCTAssertEqual(CalendarRootScreen.paperAreaHeight(area: 230, band: band(kind: .day, lanes: 1), kind: .day), 205, accuracy: 1e-9)
    }

    func testPaperAreaHeightUnderAThreeLaneBand() {
        // 3 + 3 × 18 + 2 × 2 + 4 = 65 pt.
        XCTAssertEqual(CalendarRootScreen.paperAreaHeight(area: 1180, band: band(kind: .week, lanes: 3), kind: .week), 1180 - 65, accuracy: 1e-9)
        XCTAssertEqual(CalendarRootScreen.paperAreaHeight(area: 1180, band: band(kind: .day, lanes: 3), kind: .day), 1180 - 65, accuracy: 1e-9)
        // The 35 % cap: 11 lanes would be 3 + 198 + 20 + 4 = 225 pt, capped at floor(0.35 × 230) = 80.
        XCTAssertEqual(CalendarRootScreen.paperAreaHeight(area: 230, band: band(kind: .week, lanes: 11), kind: .week), 230 - 80, accuracy: 1e-9)
    }

    func testOverviewBandZoomKeepsTheBandAtItsMinimums() {
        // Below 0.667 the lane (22 lu) and the week's gap (3 lu) are at their 18 / 2 pt minimums, and
        // every week / day overview zoom of §1.2 is at most 0.6016, so the estimate equals the band
        // at `fitAll`.
        XCTAssertLessThan(CalendarRootScreen.overviewBandZoom, 2.0 / 3.0)
        XCTAssertLessThan(CalendarRootScreen.overviewBandZoom, 18.0 / 22.0)
        XCTAssertGreaterThan(CalendarRootScreen.overviewBandZoom, 0)
        let atEstimate = AllDayBandMetrics.metrics(kind: .week, laneCount: 3, zoom: CalendarRootScreen.overviewBandZoom, pageHeight: 1180)
        let atFitAll = AllDayBandMetrics.metrics(kind: .week, laneCount: 3, zoom: 0.6016, pageHeight: 1180)
        XCTAssertEqual(atEstimate.lane, 18)
        XCTAssertEqual(atEstimate.gap, 2)
        XCTAssertEqual(atEstimate.visibleHeight, atFitAll.visibleHeight, accuracy: 1e-9)
        XCTAssertEqual(atEstimate.visibleHeight, 65, accuracy: 1e-9)
    }

    // MARK: M5 (M5_CONTRACT §3.1 / §7.6)

    /// The 19 operations against the three access states: the eleven gated ones stop while read
    /// only, the eight others (the reserved `export` included) are always allowed.
    func testGate() {
        let gated: [GatedAction] = [
            .draw, .erase, .moveSelection, .deleteSelection, .convertSelection, .createEvent, .editEvent, .deleteEvent,
            .undoRedo, .overlayTool, .webImport,
        ]
        let allowed: [GatedAction] = [.eraseAll, .settings, .navigate, .zoom, .receiveCloud, .viewEvent, .pencilToggle, .export]
        XCTAssertEqual(GatedAction.allCases.count, 19)
        XCTAssertEqual(gated.count, 11)
        XCTAssertEqual(allowed.count, 8)
        XCTAssertEqual(Set(gated + allowed), Set(GatedAction.allCases), "every case is in one of the two lists")

        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let states: [AccessState] = [
            .subscribed(Subscription(plan: .yearly, until: now.addingTimeInterval(30 * 86_400), willAutoRenew: true, inGrace: false)),
            .trial(Trial(plan: .monthly, until: now.addingTimeInterval(10 * 86_400), willAutoRenew: true)),
            .readOnly(.expired),
        ]
        for access in states {
            for action in gated {
                XCTAssertEqual(CalendarRootScreen.isAllowed(action, access: access), access.canEdit, "\(action) × \(access)")
                XCTAssertTrue(action.isGated, "\(action)")
            }
            for action in allowed {
                XCTAssertTrue(CalendarRootScreen.isAllowed(action, access: access), "\(action) × \(access)")
                XCTAssertFalse(action.isGated, "\(action)")
            }
        }
        // Every read-only reason stops the gated ones; the billing grace period does not (M5-16).
        for reason in [ReadOnlyReason.notSubscribed, .expired, .billingRetry, .revoked, .unknown] {
            XCTAssertFalse(CalendarRootScreen.isAllowed(.draw, access: .readOnly(reason)), "\(reason)")
            XCTAssertTrue(CalendarRootScreen.isAllowed(.eraseAll, access: .readOnly(reason)), "\(reason)")
        }
        XCTAssertTrue(CalendarRootScreen.isAllowed(.draw, access: .subscribed(Subscription(plan: .yearly, until: now, willAutoRenew: true, inGrace: true))))

        // The words and numbers of the read-only mode (§3.3, M5-13, M5-24).
        XCTAssertEqual(CalendarRootScreen.readOnlyToast, "閲覧専用です。書く・消す・予定を作るには購読が必要です")
        XCTAssertEqual(CalendarRootScreen.readOnlyNoticeText, "閲覧専用です。手書きと予定の作成は購読すると使えます。")
        XCTAssertEqual(CalendarRootScreen.readOnlyNoticeButton, "購読する")
        XCTAssertEqual(CalendarRootScreen.screenshotReadOnlyToastDuration, 20)
        XCTAssertEqual(CalendarRootScreen.blockedInputInterval, 2)
        XCTAssertEqual(CalendarRootScreen.firstRefreshTimeout, 3)
    }

    // MARK: 1.0.1 — the year page's tap target on an iPhone

    /// `usesMinTapTarget(isPhone:width:)`: an iPhone in portrait (390–440 pt) and landscape (750–
    /// 812 pt inside the safe area), and a window narrower than 600 pt; never an iPad at full width.
    func testTheMinimumTapTargetIsForSmallScreensOnly() {
        XCTAssertEqual(CalendarRootScreen.compactWidth, 600)
        for width: CGFloat in [390, 402, 440, 750, 812] {
            XCTAssertTrue(CalendarRootScreen.usesMinTapTarget(isPhone: true, width: width), "iPhone \(width)")
        }
        for width: CGFloat in [320, 375, 507, 599.5] {
            XCTAssertTrue(CalendarRootScreen.usesMinTapTarget(isPhone: false, width: width), "narrow window \(width)")
        }
        for width: CGFloat in [600, 678, 744, 834, 1024, 1366] {
            XCTAssertFalse(CalendarRootScreen.usesMinTapTarget(isPhone: false, width: width), "iPad \(width)")
        }
    }

    // MARK: 1.1 — the date targets of a finger tap (M7A_CONTRACT §4.1 / §4.5)

    /// `tapTarget(layout:point:zoom:smallScreen:allowFinger:currentMonth:)` is `DateTap.target`. The
    /// 8 cases: a small screen or not × 「指でも書く」 on or off × an iPhone's or an iPad's overview
    /// zoom, on the year, the month, the week and the day.
    /// - Year: the middle of 10/7 is a date unless 「指でも書く」 is on on a large screen (1.0.1's
    ///   small-screen rule plus M7A-2). Its weekday letter is a date in every case.
    /// - Year gutter: the number 15 opens this month's 15th in every case; the edge of its row
    ///   (outside the number) does on an iPhone even with 「指でも書く」, not on a large screen with it.
    ///   11/31 is nothing.
    /// - Month: the top 40 % of the 14th's cell is a date with 「指でも書く」 off at the iPhone's
    ///   overview, nothing with it on (M7A-1). The date number is a date in every case.
    /// - Week and day: exactly `hit(at:)`.
    /// - A zoom that is not a positive number leaves the month and the year at `hit(at:)` (and the
    ///   gutter). `leavesPage`: a date and 「+n件」 leave the page; bars, chips, boxes and nothing do not.
    func testTapTargetRules() throws {
        let now = wednesday.startOfDay().addingTimeInterval(10 * 3600)
        let calendar = DayKey.deviceCalendar
        func at(_ day: DayKey, _ hour: Int) -> Date { day.startOfDay(in: calendar).addingTimeInterval(TimeInterval(hour) * 3600) }
        let events = [
            LayoutEvent(id: "trip", title: "旅行", allDay: true, start: at(wednesday, 0), end: at(wednesday.adding(days: 2), 0), colorHex: "#2563eb", calendarId: "c"),
            LayoutEvent(id: "meeting", title: "打合せ", allDay: false, start: at(wednesday, 10), end: at(wednesday, 11), colorHex: "#16a34a", calendarId: "c"),
        ]
        let year = YearLayoutEngine.layout(YearLayoutInput(year: 2026, events: [], inkBottoms: [:], now: now))
        let month = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 10), events: [], inkBottoms: [:], now: now))
        let busyMonth = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 10), events: events, inkBottoms: [:], now: now))
        let week = WeekLayoutEngine.layout(WeekLayoutInput(focus: wednesday, events: events, inkBottoms: [:], now: now))
        let day = DayLayoutEngine.layout(DayLayoutInput(day: wednesday, events: events, inkBottoms: [:], now: now))
        XCTAssertEqual(CalendarRootScreen.minTapTarget, 44)
        XCTAssertEqual(CalendarRootScreen.minTapTarget, DateTap.minPoints)
        func target(_ layout: any PageLayout, _ p: CGPoint, zoom: CGFloat, small: Bool, finger: Bool, month: Int = 10) -> HitTarget? {
            CalendarRootScreen.tapTarget(layout: layout, point: p, zoom: zoom, smallScreen: small, allowFinger: finger, currentMonth: month)
        }
        func centre(_ r: CGRect?) -> CGPoint? { r.map { CGPoint(x: $0.midX, y: $0.midY) } }

        // The year: 10/7 is column 10 (x 1064…1176) × row 7 (y 360…420); 1.0's 40 × 28 letter frame.
        let middle = CGPoint(x: 1120, y: 390)
        let letter = CGPoint(x: 1069, y: 365)
        XCTAssertNil(year.hit(at: middle), "1.0: the middle of the cell is outside the 40 × 28 target")
        let row15 = year.rows[14].frame
        let row31 = year.rows[30].frame
        let number15 = CGPoint(x: 28, y: row15.midY)
        let edge15 = CGPoint(x: 28, y: row15.minY + 2)
        let number31 = CGPoint(x: 28, y: row31.midY)
        XCTAssertGreaterThan(abs(edge15.y - row15.midY), 14, "the edge of the row is outside the number (± 14 lu)")
        let fifteenth = DayKey(year: 2026, month: 10, day: 15)

        // The month: the 14th (a Wednesday without events), its date number, the top 40 % of its cell
        // outside the number, a point just under the number, and the memo area.
        let d14 = DayKey(year: 2026, month: 10, day: 14)
        let cell14 = try XCTUnwrap(month.cells[.day(d14)])
        let number14 = try XCTUnwrap(centre(month.dateLabels.first { $0.day == d14 }?.frame))
        let top40 = CGPoint(x: cell14.minX + 150, y: cell14.minY + 0.4 * cell14.height - 1)
        let underNumber = CGPoint(x: cell14.minX + 150, y: cell14.minY + 40)
        let memo = try XCTUnwrap(centre(month.memo))
        XCTAssertNil(month.hit(at: top40), "1.0: the top 40 % is outside the date frame")
        XCTAssertNil(month.hit(at: underNumber))

        // The zooms of the two screens: the overview of an iPhone 17 (402 pt: year 402 / 1400, month
        // 0.2871) and of a 13-inch iPad (year 0.6065, month 0.7371).
        struct Screen { var name: String; var yearZoom: CGFloat; var monthZoom: CGFloat; var isPhone: Bool }
        let screens = [
            Screen(name: "iPhone", yearZoom: 402.0 / 1400, monthZoom: 0.2871, isPhone: true),
            Screen(name: "iPad 13", yearZoom: 0.6065, monthZoom: 0.7371, isPhone: false),
        ]
        // The top 40 % is inside 44 pt at the iPhone's month zoom (153 lu), outside at the iPad's (60 lu).
        XCTAssertLessThan(top40.y - cell14.minY, 44 / 0.2871)
        XCTAssertGreaterThan(top40.y - cell14.minY, 44 / 0.7371)
        XCTAssertLessThan(underNumber.y - cell14.minY, 44 / 0.7371)

        var cases = 0
        for screen in screens {
            for small in [true, false] {
                for finger in [true, false] {
                    cases += 1
                    let name = "\(screen.name) small \(small) finger \(finger)"
                    // Year.
                    let yearTarget: HitTarget? = (small || !finger) ? .date(wednesday) : nil
                    XCTAssertEqual(target(year, middle, zoom: screen.yearZoom, small: small, finger: finger), yearTarget, "\(name): the middle of 10/7")
                    XCTAssertEqual(target(year, letter, zoom: screen.yearZoom, small: small, finger: finger), .date(wednesday), "\(name): the weekday letter of 10/7")
                    XCTAssertEqual(target(year, number15, zoom: screen.yearZoom, small: small, finger: finger), .date(fifteenth), "\(name): the gutter's 15")
                    XCTAssertEqual(target(year, edge15, zoom: screen.yearZoom, small: small, finger: finger),
                                   finger && !small ? nil : .date(fifteenth), "\(name): the edge of row 15 in the gutter")
                    XCTAssertNil(target(year, number31, zoom: screen.yearZoom, small: small, finger: finger, month: 11), "\(name): 11/31 does not exist")
                    XCTAssertEqual(target(year, number31, zoom: screen.yearZoom, small: small, finger: finger, month: 10),
                                   .date(DayKey(year: 2026, month: 10, day: 31)), "\(name): 10/31")
                    // Month.
                    XCTAssertEqual(target(month, number14, zoom: screen.monthZoom, small: small, finger: finger), .date(d14), "\(name): the date number")
                    XCTAssertEqual(target(month, underNumber, zoom: screen.monthZoom, small: small, finger: finger),
                                   finger ? nil : .date(d14), "\(name): just under the number")
                    XCTAssertEqual(target(month, top40, zoom: screen.monthZoom, small: small, finger: finger),
                                   !finger && screen.isPhone ? .date(d14) : nil, "\(name): the top 40 % of the cell")
                    XCTAssertNil(target(month, memo, zoom: screen.monthZoom, small: small, finger: finger), "\(name): the memo area")
                    // A bar and a chip stay first (they open the edit sheet).
                    for p in [centre(busyMonth.allDayBars.first?.frame), centre(busyMonth.timedChips.first?.frame)].compactMap({ $0 }) {
                        XCTAssertEqual(target(busyMonth, p, zoom: screen.monthZoom, small: small, finger: finger), busyMonth.hit(at: p), "\(name): month at \(p)")
                        XCTAssertNotNil(busyMonth.hit(at: p))
                    }
                    // Week and day: `hit(at:)` unchanged.
                    let weekPoints = [
                        centre(week.dateLabels.first { $0.day == wednesday }?.frame),
                        centre(week.cells.values.first),
                        centre(week.timedBoxes.first?.frame),
                        CGPoint(x: 700, y: 1900),
                    ].compactMap { $0 }
                    XCTAssertGreaterThanOrEqual(weekPoints.count, 3)
                    for p in weekPoints {
                        XCTAssertEqual(target(week, p, zoom: screen.monthZoom, small: small, finger: finger), week.hit(at: p), "\(name): week at \(p)")
                    }
                    let dayPoints = [centre(day.timedBoxes.first?.frame), CGPoint(x: 500, y: 1000), CGPoint(x: 30, y: 2700), CGPoint(x: 500, y: 2700)].compactMap { $0 }
                    XCTAssertEqual(dayPoints.count, 4)
                    for p in dayPoints {
                        XCTAssertEqual(target(day, p, zoom: screen.monthZoom, small: small, finger: finger), day.hit(at: p), "\(name): day at \(p)")
                    }
                    XCTAssertEqual(target(day, dayPoints[0], zoom: screen.monthZoom, small: small, finger: finger), .timedBox("meeting"))
                }
            }
        }
        XCTAssertEqual(cases, 8)

        // 1.0.1 on an iPhone (a small screen): the year's whole cell in portrait and landscape, not at
        // the readable zoom (the middle of a cell is for writing there).
        for finger in [true, false] {
            for zoom: CGFloat in [402.0 / 1400, 390.0 / 1400, 440.0 / 1400, 0.1098, 0.1237] {
                XCTAssertEqual(target(year, middle, zoom: zoom, small: true, finger: finger), .date(wednesday), "an iPhone's overview \(zoom), finger \(finger)")
            }
            XCTAssertNil(target(year, middle, zoom: ZoomPolicy.readableZoom(.year), small: true, finger: finger), "zoomed in, finger \(finger)")
        }
        // The middle of 3/16 (the cell of YearTapUITests): a date on an iPhone in both settings.
        let march16 = CGPoint(x: 56 + 2 * 112 + 56, y: year.rows[15].frame.midY)
        for finger in [true, false] {
            XCTAssertEqual(target(year, march16, zoom: 402.0 / 1400, small: true, finger: finger), .date(DayKey(year: 2026, month: 3, day: 16)))
        }
        // A zoom that is not a positive number: the year is `hit(at:)` plus the gutter, the month `hit(at:)`.
        for bad: CGFloat in [0, -1, .nan, .infinity] {
            for small in [true, false] {
                for finger in [true, false] {
                    XCTAssertEqual(target(year, middle, zoom: bad, small: small, finger: finger), year.hit(at: middle), "zoom \(bad)")
                    XCTAssertEqual(target(year, letter, zoom: bad, small: small, finger: finger), .date(wednesday), "zoom \(bad): the weekday letter")
                    XCTAssertEqual(target(year, number15, zoom: bad, small: small, finger: finger), .date(fifteenth), "zoom \(bad): the gutter")
                    XCTAssertEqual(target(month, underNumber, zoom: bad, small: small, finger: finger), month.hit(at: underNumber), "zoom \(bad): month")
                    XCTAssertEqual(target(month, number14, zoom: bad, small: small, finger: finger), .date(d14), "zoom \(bad): the month's number")
                }
            }
        }

        // Which taps leave the page (the dot of 「指でも書く」 is removed only for these).
        XCTAssertTrue(CalendarRootScreen.leavesPage(.date(wednesday)))
        XCTAssertTrue(CalendarRootScreen.leavesPage(.moreChips(wednesday)))
        XCTAssertFalse(CalendarRootScreen.leavesPage(.allDayBar("trip")))
        XCTAssertFalse(CalendarRootScreen.leavesPage(.timedChip("meeting")))
        XCTAssertFalse(CalendarRootScreen.leavesPage(.timedBox("meeting")))
        XCTAssertFalse(CalendarRootScreen.leavesPage(nil))
    }

    /// P-13 (M7A_CONTRACT §4.3 / §4.5, M7A-3): a tap on the year page's left gutter number opens that
    /// day of this month (`currentMonth`, the screen's `now`), whatever the zoom. It leaves the page,
    /// so 「指でも書く」's dot of the tap is removed (`tapLeavesPage`, the same rule). A day the month
    /// does not have is nothing and stays on the page. The edge of a row: on an iPhone the whole row
    /// counts (「指でも書く」 on too); on a large screen with 「指でも書く」 only the number. Neither
    /// the paper's left margin nor January's column is the gutter.
    func testLeavesPageForGutterDates() {
        let now = wednesday.startOfDay().addingTimeInterval(10 * 3600)
        let year = YearLayoutEngine.layout(YearLayoutInput(year: 2026, events: [], inkBottoms: [:], now: now))
        let leap = YearLayoutEngine.layout(YearLayoutInput(year: 2028, events: [], inkBottoms: [:], now: now))
        func target(_ layout: any PageLayout, _ p: CGPoint, zoom: CGFloat = 402.0 / 1400, small: Bool = true, finger: Bool = true, month: Int) -> HitTarget? {
            CalendarRootScreen.tapTarget(layout: layout, point: p, zoom: zoom, smallScreen: small, allowFinger: finger, currentMonth: month)
        }
        func number(_ d: Int, in layout: YearPageLayout) -> CGPoint { CGPoint(x: 28, y: layout.rows[d - 1].frame.midY) }

        for small in [true, false] {
            for finger in [true, false] {
                for zoom: CGFloat in [402.0 / 1400, 0.6065, 1, ZoomPolicy.readableZoom(.year), 0, .nan] {
                    let hit = target(year, number(15, in: year), zoom: zoom, small: small, finger: finger, month: 10)
                    XCTAssertEqual(hit, .date(DayKey(year: 2026, month: 10, day: 15)), "small \(small) finger \(finger) zoom \(zoom)")
                    XCTAssertTrue(CalendarRootScreen.leavesPage(hit), "small \(small) finger \(finger) zoom \(zoom)")
                }
            }
        }
        // This month decides (the screen passes `DayKey(now).month`).
        XCTAssertEqual(target(year, number(15, in: year), month: 1), .date(DayKey(year: 2026, month: 1, day: 15)))
        XCTAssertEqual(target(year, number(1, in: year), month: 12), .date(DayKey(year: 2026, month: 12, day: 1)))
        XCTAssertEqual(target(year, number(31, in: year), month: 12), .date(DayKey(year: 2026, month: 12, day: 31)))
        // A day this month does not have: nothing happens and the page stays (M7A-3).
        for (d, m) in [(31, 11), (31, 4), (30, 2), (29, 2)] {
            let hit = target(year, number(d, in: year), month: m)
            XCTAssertNil(hit, "\(m)/\(d) of 2026")
            XCTAssertFalse(CalendarRootScreen.leavesPage(hit), "\(m)/\(d) of 2026")
        }
        XCTAssertEqual(target(leap, number(29, in: leap), month: 2), .date(DayKey(year: 2028, month: 2, day: 29)), "a leap year")
        XCTAssertNil(target(leap, number(30, in: leap), month: 2))
        // The edge of row 15 (outside the number).
        let edge = CGPoint(x: 28, y: year.rows[14].frame.minY + 2)
        XCTAssertEqual(target(year, edge, small: true, finger: true, month: 10), .date(DayKey(year: 2026, month: 10, day: 15)), "an iPhone with 「指でも書く」: the whole row")
        XCTAssertTrue(CalendarRootScreen.leavesPage(target(year, edge, small: true, finger: true, month: 10)))
        let large = target(year, edge, zoom: 0.6065, small: false, finger: true, month: 10)
        XCTAssertNil(large, "a large screen with 「指でも書く」: the number only (writing beside it stays writing)")
        XCTAssertFalse(CalendarRootScreen.leavesPage(large))
        XCTAssertEqual(target(year, edge, zoom: 0.6065, small: false, finger: false, month: 10), .date(DayKey(year: 2026, month: 10, day: 15)), "「指でも書く」 off: the whole row")
        // Not the gutter: the paper's left margin (x < 0) and January's column (x ≥ 56, January's own date).
        XCTAssertNil(target(year, CGPoint(x: -5, y: year.rows[14].frame.midY), month: 10))
        XCTAssertEqual(target(year, CGPoint(x: 60, y: year.rows[14].frame.minY + 5), month: 10), .date(DayKey(year: 2026, month: 1, day: 15)), "January's cell is January's date")
    }

    // MARK: 1.1 — toasts, events below 24:00, the toolbar (M7A_CONTRACT §2 / §3.7 / §5.2 / §6.2)

    /// The four new toasts of §6.2, character for character, and their durations: the memo limit
    /// and the event below 24:00 3 s, the 15,000 notice 6 s without the error colour, the 19,000
    /// refusal an error toast (6 s). The numbers in the sentences are `StrokeBudget`'s.
    func testToastTexts() {
        XCTAssertEqual(CalendarRootScreen.growthCapToast, "メモ欄はここまでです")
        XCTAssertEqual(CalendarRootScreen.eventBelowDayToast, "24 時の下の自由メモ欄では予定を作れません")
        XCTAssertEqual(CalendarRootScreen.strokeBudgetManyToast, "このページに書いた線が 15,000 本を超えました。1 ページに書ける線は 19,000 本までです。")
        XCTAssertEqual(CalendarRootScreen.strokeBudgetFullToast, "このページはいっぱいです（線 19,000 本）。線を消すと、また書けます。")
        XCTAssertEqual(CalendarRootScreen.strokeBudgetNoticeDuration, 6)
        XCTAssertEqual(CalendarRootScreen.strokeBudgetNoticeDuration, ToastView.errorDuration)
        XCTAssertEqual(ToastView.duration, 3)
        XCTAssertTrue(CalendarRootScreen.strokeBudgetManyToast.contains(StrokeBudget.countText(StrokeBudget.noticeAt)))
        XCTAssertTrue(CalendarRootScreen.strokeBudgetManyToast.contains(StrokeBudget.countText(StrokeBudget.refuseAt)))
        XCTAssertTrue(CalendarRootScreen.strokeBudgetFullToast.contains("線 " + StrokeBudget.countText(StrokeBudget.refuseAt)))
        XCTAssertEqual(CalendarRootScreen.blockedInputInterval, 2, "the refusal toast comes at most every 2 s")
        for text in [CalendarRootScreen.growthCapToast, CalendarRootScreen.eventBelowDayToast,
                     CalendarRootScreen.strokeBudgetManyToast, CalendarRootScreen.strokeBudgetFullToast,
                     CalendarRootScreen.readOnlyToast, CalendarRootScreen.readOnlyNoticeText] {
            XCTAssertFalse(text.contains("iPad"), text)
        }
    }

    /// §3.7 / 0-4: on the day page a rect that starts at or below 24:00 (`startsBelowDay`, asked
    /// before `eventRange`) is refused — the screen shows the toast and opens nothing. A rect from
    /// 2,399.9, an upward drag across 24:00 and the other pages make the event `eventRange` gives
    /// (unchanged: below 24:00 it would still snap to 23:00).
    func testEventBelowTheDayIsRefused() {
        let now = wednesday.startOfDay().addingTimeInterval(10 * 3600)
        let day = DayLayoutEngine.layout(DayLayoutInput(day: wednesday, events: [], inkBottoms: [:], now: now))
        XCTAssertEqual(day.grid.maxY, 2400)
        func plan(_ layout: any PageLayout, _ rect: CGRect) -> CalendarRootScreen.NewEventPlan {
            CalendarRootScreen.newEventPlan(layout: layout, rect: rect, now: now)
        }
        // Refused: from 24:00, a tap of the 予定 tool deep in the free memo area, a drag that stays below.
        for rect in [CGRect(x: 100, y: 2400, width: 200, height: 100), CGRect(x: 500, y: 2900, width: 0, height: 0),
                     CGRect(x: 100, y: 2600, width: 100, height: -150), CGRect(x: 20, y: 2406, width: 960, height: 600)] {
            XCTAssertEqual(plan(day, rect), .refusedBelowDay, "\(rect)")
            XCTAssertNotNil(day.eventRange(for: rect, now: now), "\(rect): eventRange alone would make a 23:00 event")
        }
        // Made: from 2,399.9 a 23:00 event, as `eventRange` gives it.
        let justAbove = CGRect(x: 100, y: 2399.9, width: 200, height: 100)
        XCTAssertEqual(plan(day, justAbove), .create(day.eventRange(for: justAbove, now: now)))
        XCTAssertEqual(plan(day, justAbove), .create(.timed(wednesday, startMinute: 23 * 60, endMinute: 24 * 60)))
        // An upward drag from the free memo area across 24:00: 22:00–24:00.
        let upward = CGRect(x: 100, y: 2500, width: 100, height: -300)
        XCTAssertEqual(plan(day, upward), .create(.timed(wednesday, startMinute: 22 * 60, endMinute: 24 * 60)))
        // A rect in the day (10:00) and one across 24:00 are unchanged.
        let ten = CGRect(x: 100, y: 1000, width: 200, height: 100)
        XCTAssertEqual(plan(day, ten), .create(day.eventRange(for: ten, now: now)))
        let across = CGRect(x: 100, y: 1000, width: 100, height: 2000)
        XCTAssertEqual(plan(day, across), .create(day.eventRange(for: across, now: now)))
        // Not finite: nothing to make (as before).
        XCTAssertEqual(plan(day, CGRect(x: 100, y: CGFloat.nan, width: 100, height: 100)), .create(nil))
        // The other pages never refuse, however low the rect (the month's memo area, the week, the year).
        let month = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 10), events: [], inkBottoms: [:], now: now))
        let week = WeekLayoutEngine.layout(WeekLayoutInput(focus: wednesday, events: [], inkBottoms: [:], now: now))
        let year = YearLayoutEngine.layout(YearLayoutInput(year: 2026, events: [], inkBottoms: [:], now: now))
        let pages: [any PageLayout] = [month, week, year]
        for layout in pages {
            for rect in [CGRect(x: 100, y: 2400, width: 200, height: 100), CGRect(x: 300, y: 1300, width: 50, height: 50)] {
                XCTAssertEqual(plan(layout, rect), .create(layout.eventRange(for: rect, now: now)), "\(layout.kind) \(rect)")
            }
        }
    }

    /// 0-13 and §7.3: what the screen starts with. Normal use: the remembered pen (also the last ink)
    /// and the stored `toolbar.collapsed`. Screenshot mode never reads the memories: the default pen,
    /// `--screenshot-tool` (the eraser as the toolbar's), `--screenshot-toolbar` (bottom left / right)
    /// and the lasso of the `lasso` sheet first.
    func testStartToolAndToolbar() throws {
        let red = InkStyle(tool: .pen, colorHex: "#dc2626", width: 6)
        let normal = CalendarRootScreen.startState(collapsedStored: false, rememberedPen: red)
        XCTAssertEqual(normal, CalendarRootScreen.StartState(tool: .ink(red), lastInkTool: .ink(red), toolbarMode: .expanded, eraserOrigin: nil, screenshotEdge: nil))
        XCTAssertEqual(CalendarRootScreen.startState(collapsedStored: true, rememberedPen: red).toolbarMode, .collapsed)
        // The remembered pen of a device that chose 赤・太 (T's `rememberedPen`, the toolbar's keys).
        let suite = "CalendarRootScreenTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("#dc2626", forKey: ToolbarPalette.penColorKey)
        defaults.set(6.0, forKey: ToolbarPalette.penWidthKey)
        XCTAssertEqual(CalendarRootScreen.startState(collapsedStored: false, rememberedPen: ToolbarPalette.rememberedPen(defaults)).tool, .ink(red))

        func shot(_ extra: [String]) throws -> CalendarRootScreen.StartState {
            CalendarRootScreen.startState(shot: try XCTUnwrap(ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-10"] + extra)))
        }
        let pen = CanvasTool.ink(ToolbarPalette.defaultPen)
        XCTAssertEqual(try shot([]), CalendarRootScreen.StartState(tool: pen, lastInkTool: pen, toolbarMode: .expanded, eraserOrigin: nil, screenshotEdge: .leading))
        XCTAssertEqual(try shot(["--screenshot-toolbar", "collapsed"]).toolbarMode, .collapsed)
        XCTAssertEqual(try shot(["--screenshot-toolbar", "collapsed"]).screenshotEdge, .leading)
        XCTAssertEqual(try shot(["--screenshot-toolbar", "collapsed-right"]).toolbarMode, .collapsed)
        XCTAssertEqual(try shot(["--screenshot-toolbar", "collapsed-right"]).screenshotEdge, .trailing)
        XCTAssertEqual(try shot(["--screenshot-toolbar", "bogus"]).toolbarMode, .expanded)
        let eraser = try shot(["--screenshot-tool", "eraser"])
        XCTAssertEqual(eraser.tool, .eraser)
        XCTAssertEqual(eraser.eraserOrigin, .toolbar)
        XCTAssertEqual(eraser.lastInkTool, pen)
        XCTAssertEqual(CalendarRootScreen.eraserReturnTarget(tool: eraser.tool, origin: eraser.eraserOrigin, setting: true, lastInk: eraser.lastInkTool), pen,
                       "the tool-eraser photo's note: 「（消すとペンに戻ります）」")
        XCTAssertEqual(try shot(["--screenshot-tool", "marker"]).tool, .ink(InkPresets.defaultMarker))
        XCTAssertNil(try shot(["--screenshot-tool", "marker"]).eraserOrigin)
        XCTAssertEqual(try shot(["--screenshot-tool", "lasso"]).tool, .lasso)
        XCTAssertEqual(try shot(["--screenshot-tool", "event"]).tool, .eventRect)
        XCTAssertEqual(try shot(["--screenshot-sheet", "lasso", "--screenshot-tool", "eraser"]).tool, .lasso, "the lasso sheet wins")
        XCTAssertNil(try shot(["--screenshot-sheet", "lasso", "--screenshot-tool", "eraser"]).eraserOrigin)
    }

    /// §2.4: the bar's eraser note names the ink it returns to only for the toolbar's eraser with the
    /// setting on — and then `toolAfterErase` (what `eraseEnded` applies) returns to that same ink.
    func testEraserReturnTarget() {
        let red = CanvasTool.ink(InkStyle(tool: .pen, colorHex: "#dc2626", width: 6))
        let marker = CanvasTool.ink(InkPresets.defaultMarker)
        XCTAssertEqual(CalendarRootScreen.eraserReturnTarget(tool: .eraser, origin: .toolbar, setting: true, lastInk: red), red)
        XCTAssertEqual(CalendarRootScreen.eraserReturnTarget(tool: .eraser, origin: .toolbar, setting: true, lastInk: marker), marker)
        XCTAssertEqual(ToolbarLogic.eraserHint(returnsTo: CalendarRootScreen.eraserReturnTarget(tool: .eraser, origin: .toolbar, setting: true, lastInk: red)),
                       "触れた線をまるごと消します（消すとペンに戻ります）")
        XCTAssertEqual(ToolbarLogic.eraserHint(returnsTo: CalendarRootScreen.eraserReturnTarget(tool: .eraser, origin: .toolbar, setting: true, lastInk: marker)),
                       "触れた線をまるごと消します（消すとマーカーに戻ります）")
        XCTAssertEqual(ToolbarLogic.eraserHint(returnsTo: CalendarRootScreen.eraserReturnTarget(tool: .eraser, origin: .pencil, setting: true, lastInk: red)),
                       "触れた線をまるごと消します")
        let tools: [CanvasTool] = [.eraser, red, marker, .lasso, .eventRect]
        let origins: [EraserOrigin?] = [.toolbar, .pencil, nil]
        for tool in tools {
            for origin in origins {
                for setting in [true, false] {
                    for lastInk in [red, marker] {
                        let target = CalendarRootScreen.eraserReturnTarget(tool: tool, origin: origin, setting: setting, lastInk: lastInk)
                        let returns = tool == .eraser && origin == .toolbar && setting
                        XCTAssertEqual(target, returns ? lastInk : nil, "\(tool) \(String(describing: origin)) \(setting)")
                        XCTAssertEqual(ToolbarLogic.toolAfterErase(origin: origin, erased: 1, setting: setting, current: tool, lastInk: lastInk), target,
                                       "the note and the return agree: \(tool) \(String(describing: origin)) \(setting)")
                    }
                }
            }
        }
    }

    /// §2.2: the screenshot mode's log lines that C copies to docs/M7A.md (`toolbar: safeArea=` and
    /// `toolbar: paperArea=`), two decimals.
    func testToolbarLogLines() {
        XCTAssertEqual(CalendarRootScreen.safeAreaLogLine(UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0)), "toolbar: safeArea=24.00,0.00,20.00,0.00")
        XCTAssertEqual(CalendarRootScreen.safeAreaLogLine(UIEdgeInsets(top: 0, left: 62, bottom: 21, right: 62)), "toolbar: safeArea=0.00,62.00,21.00,62.00")
        XCTAssertEqual(CalendarRootScreen.paperAreaLogLine(CGSize(width: 1032, height: 1180.333), mode: .collapsed), "toolbar: paperArea=1032.00x1180.33 mode=collapsed")
        XCTAssertEqual(CalendarRootScreen.paperAreaLogLine(CGSize(width: 402, height: 591), mode: .expanded), "toolbar: paperArea=402.00x591.00 mode=expanded")
    }

    // MARK: M6 (M6_CONTRACT §1.2 / §7.2)

    /// The `.failed` text of the import door's parse errors (`InkImport.parse` throws the same
    /// `WebImport.ParseError` as before): the two-format wording of `notAnExport`, the version, and
    /// 「ファイルを読めませんでした」 for invalid JSON and for any error that is not a parse error.
    func testImportFailureTexts() {
        XCTAssertEqual(CalendarRootScreen.importFailureText(WebImport.ParseError.notAnExport), WebImportSheet.notAnExportText)
        XCTAssertEqual(CalendarRootScreen.importFailureText(WebImport.ParseError.notAnExport), "このファイルは手書きの書き出し（Web 版またはこのアプリ）ではありません")
        XCTAssertEqual(CalendarRootScreen.importFailureText(WebImport.ParseError.unsupportedVersion(2)), WebImportSheet.unsupportedVersionText(2))
        XCTAssertEqual(CalendarRootScreen.importFailureText(WebImport.ParseError.unsupportedVersion(2)), "このファイルは新しい形式です（v2）。アプリを更新してください")
        XCTAssertEqual(CalendarRootScreen.importFailureText(WebImport.ParseError.invalidJSON), WebImportSheet.invalidJSONText)
        XCTAssertEqual(CalendarRootScreen.importFailureText(WebImport.ParseError.invalidJSON), "ファイルを読めませんでした")
        let unrelated = NSError(domain: "CalendarRootScreenTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "x"])
        XCTAssertEqual(CalendarRootScreen.importFailureText(unrelated), WebImportSheet.invalidJSONText)
        XCTAssertEqual(CalendarRootScreen.importFailureText(CancellationError()), WebImportSheet.invalidJSONText)
        // The door's own errors are the same type and values (K's `InkImport.parse`).
        XCTAssertThrowsError(try InkImport.parse(Data("not json".utf8))) { error in
            XCTAssertEqual(error as? WebImport.ParseError, .invalidJSON)
            XCTAssertEqual(CalendarRootScreen.importFailureText(error), WebImportSheet.invalidJSONText)
        }
        XCTAssertThrowsError(try InkImport.parse(Data(#"{"format":"something-else","v":1}"#.utf8))) { error in
            XCTAssertEqual(error as? WebImport.ParseError, .notAnExport)
            XCTAssertEqual(CalendarRootScreen.importFailureText(error), WebImportSheet.notAnExportText)
        }
        XCTAssertThrowsError(try InkImport.parse(Data(#"{"format":"tegaki-app-export","v":2,"pages":[]}"#.utf8))) { error in
            XCTAssertEqual(error as? WebImport.ParseError, .unsupportedVersion(2))
            XCTAssertEqual(CalendarRootScreen.importFailureText(error), WebImportSheet.unsupportedVersionText(2))
        }
    }
}
