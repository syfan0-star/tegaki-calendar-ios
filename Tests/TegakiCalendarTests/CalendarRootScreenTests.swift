import Access
import Layout
import XCTest
@testable import TegakiCalendar

/// The screen's pure helpers: the height left for the paper under the fixed all-day band (M4C
/// contract §5.1 / §7.3; measured at the overview: lanes 18 pt, gaps 2 pt, padding 3 + 4, so `fitAll`
/// on the screen matches the canvas's paper area), and M5's gate of the 19 operations (M5_CONTRACT
/// §3.1 / §7.6).
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
}
