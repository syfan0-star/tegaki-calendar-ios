import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §4.3, §6.1, 0f-21): the memo paper reaches the papers already made. A new `PaperView` asks
/// for no redraw (`displayRequestCount` 0, which the frozen PaperViewTests count on) and starts with the pattern in force; a
/// change (`MemoPaperStyle.set`, the settings' path) makes the one page's paper and the joined window's paper (a `span`, which
/// the canvas makes from the layouts alone and does not make again for a setting) take the new pattern and ask for one redraw
/// each; the notice of the same pattern asks for none (mutation MM2: a paper that does not follow the notice fails here).
@MainActor
final class MemoPaperRedrawTests: XCTestCase {
    private let today = DayKey(year: 2026, month: 10, day: 7)
    private var now: Date { today.startOfDay(in: DayKey.deviceCalendar).addingTimeInterval(10 * 3600) }

    override func setUp() async throws {
        MemoPaperStyle.current = .ruled
    }

    override func tearDown() async throws {
        // Through `set`, so every paper still alive (the host app's too) is ruled again.
        MemoPaperStyle.set(.ruled)
    }

    private func dayPage(_ day: Int) -> PaperContent {
        .day(DayPaperContent(layout: DayLayoutEngine.layout(DayLayoutInput(day: DayKey(year: 2026, month: 10, day: day), events: [],
                                                                            inkBottoms: [:], now: now))))
    }

    private func monthPage() -> PaperContent {
        let layout = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 10), events: [], inkBottoms: [:], now: now))
        return .month(MonthPaperContent(layout: layout, labels: layout.dateLabels, bars: [], chips: [], holidayNames: [:]))
    }

    /// The one page's paper and the joined window's (three days), both shown once.
    private func papers() throws -> (one: PaperView, joined: PaperView) {
        let one = PaperView(content: monthPage())
        one.show(visible: CGRect(x: 0, y: 0, width: 402, height: 600), zoom: 0.5, contentSize: CGSize(width: 700, height: 3600))
        let pages = [7, 8, 9].map(dayPage)
        var lanes = AllDayBandLanes()
        let bands = lanes.bands(.day, days: pages.flatMap { PaperSpan.days(of: $0) }, events: [], now: now, holidays: .japan)
        let span = try XCTUnwrap(PaperSpan(pages: pages, bands: bands, focus: 1))
        let joined = PaperView(content: pages[1])
        joined.span = span
        joined.show(visible: CGRect(x: 1000, y: 2200, width: 1000, height: 400), zoom: 1, contentSize: span.size)
        return (one, joined)
    }

    func testANewPaperAsksForNoRedrawAndTakesThePatternInForce() {
        let ruled = PaperView(content: monthPage())
        XCTAssertEqual(ruled.displayRequestCount, 0, "init asks for no redraw (PaperViewTests counts them)")
        XCTAssertEqual(ruled.memoPaper, .ruled)
        MemoPaperStyle.set(.dots)
        let dots = PaperView(content: dayPage(8))
        XCTAssertEqual(dots.displayRequestCount, 0)
        XCTAssertEqual(dots.memoPaper, .dots, "made after the change: the pattern in force")
        XCTAssertEqual(ruled.memoPaper, .dots, "made before: told")
    }

    func testAChangeRedrawsTheOnePageAndTheJoinedWindowOnce() throws {
        let (one, joined) = try papers()
        XCTAssertEqual(one.memoPaper, .ruled)
        XCTAssertEqual(joined.memoPaper, .ruled)
        var counts = (one.displayRequestCount, joined.displayRequestCount)

        MemoPaperStyle.set(.dots)
        XCTAssertEqual(one.memoPaper, .dots)
        XCTAssertEqual(joined.memoPaper, .dots)
        XCTAssertEqual(one.displayRequestCount, counts.0 + 1, "the one page: one redraw")
        XCTAssertEqual(joined.displayRequestCount, counts.1 + 1, "the joined window: one redraw")
        XCTAssertNotNil(joined.span, "the window stays the window")
        counts = (one.displayRequestCount, joined.displayRequestCount)

        // The notice of the pattern already in force asks for nothing.
        NotificationCenter.default.post(name: MemoPaperStyle.didChange, object: nil)
        XCTAssertEqual(one.displayRequestCount, counts.0, "the same pattern: no redraw")
        XCTAssertEqual(joined.displayRequestCount, counts.1)
        MemoPaperStyle.set(.dots)
        XCTAssertEqual(one.displayRequestCount, counts.0, "set of the same pattern posts nothing")
        XCTAssertEqual(joined.displayRequestCount, counts.1)

        MemoPaperStyle.set(.plain)
        XCTAssertEqual(one.memoPaper, .plain)
        XCTAssertEqual(joined.memoPaper, .plain)
        XCTAssertEqual(one.displayRequestCount, counts.0 + 1)
        XCTAssertEqual(joined.displayRequestCount, counts.1 + 1)

        MemoPaperStyle.set(.ruled)
        XCTAssertEqual(one.memoPaper, .ruled)
        XCTAssertEqual(joined.memoPaper, .ruled)
        XCTAssertEqual(one.displayRequestCount, counts.0 + 2)
        XCTAssertEqual(joined.displayRequestCount, counts.1 + 2)
    }

    /// The settings' path (`MemoPaperSettingsSection.changed`, outside screenshot mode: stored, then set) reaches the papers.
    func testTheSettingsReachThePapers() throws {
        let suite = "test-memo-paper-redraw-\(UUID())"
        let scratch = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { scratch.removePersistentDomain(forName: suite) }
        let (one, joined) = try papers()
        let counts = (one.displayRequestCount, joined.displayRequestCount)
        MemoPaperSettingsSection.changed(to: .plain, screenshot: false, scratch)
        XCTAssertEqual(scratch.string(forKey: AppSettings.memoPaperKey), "plain")
        XCTAssertEqual(one.memoPaper, .plain)
        XCTAssertEqual(joined.memoPaper, .plain)
        XCTAssertEqual(one.displayRequestCount, counts.0 + 1)
        XCTAssertEqual(joined.displayRequestCount, counts.1 + 1)
    }

    /// Setting the property itself: a different value redraws once, the same value not at all (`content`'s and `span`'s rule).
    func testThePropertyRedrawsOnlyOnAChange() {
        let view = PaperView(content: monthPage())
        view.memoPaper = .ruled
        XCTAssertEqual(view.displayRequestCount, 0)
        view.memoPaper = .dots
        XCTAssertEqual(view.displayRequestCount, 1)
        view.memoPaper = .dots
        XCTAssertEqual(view.displayRequestCount, 1)
        view.memoPaper = .plain
        XCTAssertEqual(view.displayRequestCount, 2)
    }
}
