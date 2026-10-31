import Access
import InkModel
import Layout
import XCTest
@testable import TegakiCalendar

/// The screen's pure helpers: the height left for the paper under the fixed all-day band (M4C
/// contract §5.1 / §7.3; measured at the overview: lanes 18 pt, gaps 2 pt, padding 3 + 4, so `fitAll`
/// on the screen matches the canvas's paper area), M5's gate of the 19 operations (M5_CONTRACT
/// §3.1 / §7.6), and M6's failure texts of the two-format import door (M6_CONTRACT §1.2 / §7.2).
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

    /// `tapTarget(layout:point:zoom:smallScreen:)`: on a small screen the year page's date area is at
    /// least 44 pt on screen (the middle of 10/7 opens the day at an iPhone's overview, in portrait and
    /// in landscape, not at the readable zoom); a zoom that is not a positive number falls back to
    /// `hit(at:)`. A large screen (an iPad) is `hit(at:)` at every zoom, and so are the month and the
    /// week on both. `leavesPage`: a date and 「+n件」 leave the page, bars, chips, boxes and nothing do not.
    func testTapTargetUsesTheOnScreenMinimumOnlyOnTheYearPageOfASmallScreen() {
        let now = wednesday.startOfDay().addingTimeInterval(10 * 3600)
        let year = YearLayoutEngine.layout(YearLayoutInput(year: 2026, events: [], inkBottoms: [:], now: now))
        let middle = CGPoint(x: 1120, y: 390)
        let letter = CGPoint(x: 1069, y: 365)
        XCTAssertEqual(CalendarRootScreen.minTapTarget, 44)
        XCTAssertNil(year.hit(at: middle), "1.0: the middle of the cell is outside the 40 × 28 target")
        for zoom: CGFloat in [402.0 / 1400, 390.0 / 1400, 440.0 / 1400, 0.1098, 0.1237] {
            XCTAssertEqual(CalendarRootScreen.tapTarget(layout: year, point: middle, zoom: zoom, smallScreen: true), .date(wednesday), "an iPhone's overview \(zoom): the whole cell")
        }
        XCTAssertNil(CalendarRootScreen.tapTarget(layout: year, point: middle, zoom: ZoomPolicy.readableZoom(.year), smallScreen: true), "zoomed in: the middle of the cell is for writing")
        for bad: CGFloat in [0, -1, .nan, .infinity] {
            XCTAssertEqual(CalendarRootScreen.tapTarget(layout: year, point: middle, zoom: bad, smallScreen: true), year.hit(at: middle), "zoom \(bad)")
            XCTAssertEqual(CalendarRootScreen.tapTarget(layout: year, point: letter, zoom: bad, smallScreen: true), year.hit(at: letter), "zoom \(bad): the weekday letter")
        }
        XCTAssertEqual(CalendarRootScreen.tapTarget(layout: year, point: letter, zoom: 0, smallScreen: true), .date(wednesday))
        // An iPad (a large screen): exactly 1.0's target at its overviews (13-inch 0.6065, 11-inch 0.5190,
        // mini 0.4784), at the readable zoom and at an iPhone-sized zoom.
        let yearPoints = [middle, letter, CGPoint(x: 1109, y: 372), CGPoint(x: 1134, y: 410), CGPoint(x: 20, y: 390), CGPoint(x: 224, y: 1770)]
        for p in yearPoints {
            for zoom: CGFloat in [0.6065, 0.5190, 0.4784, ZoomPolicy.readableZoom(.year), 402.0 / 1400] {
                XCTAssertEqual(CalendarRootScreen.tapTarget(layout: year, point: p, zoom: zoom, smallScreen: false), year.hit(at: p), "iPad: year at \(p), zoom \(zoom)")
            }
        }

        // The month and the week: exactly `hit(at:)` (date numbers, empty cells, the memo area, bars,
        // chips and boxes), whatever the zoom and the screen.
        let calendar = DayKey.deviceCalendar
        func at(_ day: DayKey, _ hour: Int) -> Date { day.startOfDay(in: calendar).addingTimeInterval(TimeInterval(hour) * 3600) }
        let events = [
            LayoutEvent(id: "trip", title: "旅行", allDay: true, start: at(wednesday, 0), end: at(wednesday.adding(days: 2), 0), colorHex: "#2563eb", calendarId: "c"),
            LayoutEvent(id: "meeting", title: "打合せ", allDay: false, start: at(wednesday, 10), end: at(wednesday, 11), colorHex: "#16a34a", calendarId: "c"),
        ]
        let month = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 10), events: events, inkBottoms: [:], now: now))
        let week = WeekLayoutEngine.layout(WeekLayoutInput(focus: wednesday, events: events, inkBottoms: [:], now: now))
        func centre(_ r: CGRect?) -> CGPoint? { r.map { CGPoint(x: $0.midX, y: $0.midY) } }
        let monthPoints = [
            centre(month.dateLabels.first { $0.day == wednesday }?.frame),
            centre(month.cells[.day(wednesday)]).map { CGPoint(x: $0.x + 40, y: $0.y + 60) },
            centre(month.memo),
            centre(month.allDayBars.first?.frame),
            centre(month.timedChips.first?.frame),
        ].compactMap { $0 }
        XCTAssertEqual(monthPoints.count, 5)
        XCTAssertNotNil(month.hit(at: monthPoints[0]), "the date number of 10/7 opens the day")
        let weekPoints = [
            centre(week.dateLabels.first { $0.day == wednesday }?.frame),
            centre(week.cells.values.first),
            centre(week.timedBoxes.first?.frame),
            CGPoint(x: 700, y: 1900),
        ].compactMap { $0 }
        XCTAssertGreaterThanOrEqual(weekPoints.count, 3)
        let pages: [(any PageLayout, [CGPoint])] = [(month, monthPoints), (week, weekPoints)]
        for (layout, points) in pages {
            for p in points {
                for zoom: CGFloat in [402.0 / 1400, 1, 3] {
                    for small in [true, false] {
                        XCTAssertEqual(CalendarRootScreen.tapTarget(layout: layout, point: p, zoom: zoom, smallScreen: small), layout.hit(at: p), "\(layout.kind) at \(p), zoom \(zoom), small \(small)")
                    }
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
