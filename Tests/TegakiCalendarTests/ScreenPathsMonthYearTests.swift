@_spi(SpanLedger) import InkModel
import Layout
import XCTest
@testable import TegakiCalendar

// 1.4.3 (docs/R1_4_3_CONTRACT.md §3.2, §3.6, §3.7, §3.8, §4.5, §4.7, §12.4, §11.2 row S, §11.5 MS1, MS2, MS5, MP1; 0g-9,
// 0g-18, 0g-19, 0g-32): the screen's calls of the month on both paths through `ScreenPaths`, over a live `SyncEngine`
// (`SessionTestBed`, as ScreenPathsSpanTests drives the weeks: a temporary store, the fake cloud, `TestSleeper`, a fixed
// clock). The month joins with the setting on (`SpanKinds.joined`), stays on one page with it off, after stage 2 and with
// `--screenshot-single-page`; its focus keeps the day of the month; 「今日」 brings today's cell on screen and, once the paper is
// on today's month, today as the focus (review UX-3); the paper and the PDF of a window page and the heading's window are the
// month's.
//
// The year joins with D1y: every expectation of the year is read from `SpanKinds.joined.contains(.year)` (§11.2), so the
// fallback of 0g-3 (the month alone) needs no change here.
//
// The pages: Monday weeks, five months around 11/16/2026 on the 11-inch iPad in portrait (R = 2): 2026-09 … 2027-01.

@MainActor
final class ScreenPathsMonthYearTests: XCTestCase {
    private var bed: SessionTestBed!
    private var faults: [String] = []
    private var savedOnFault: ((String) -> Void)!
    private var savedDefaults: UserDefaults!
    private var scratch: UserDefaults!
    private var suiteName = ""
    private var setting = true
    private var one: OnePageSession!
    private var paths: ScreenPaths!
    private var stageTwo: [PageKind] = []

    private let sep = "m1-2026-09"
    private let oct = "m1-2026-10"
    private let nov = "m1-2026-11"
    private let dec = "m1-2026-12"
    private let jan = "m1-2027-01"
    private let nov16 = DayKey(year: 2026, month: 11, day: 16)
    private let nov18 = DayKey(year: 2026, month: 11, day: 18)
    private let ipad = ScreenPaths.Device(deviceClass: .iPad11, orientation: .portrait)
    /// The 11-inch iPad's portrait paper area under the band (the month's `SpanPlan.referenceViewport`, rounded down).
    private let portrait = CGSize(width: 834, height: 1_005)
    private let landscape = CGSize(width: 1_210, height: 640)
    /// The photos' day with `--screenshot-month 2026-10` (a Wednesday).
    private let oct7 = DayKey(year: 2026, month: 10, day: 7)
    /// Review UX-3's window: five months around 2027-01-15 (2026-11 … 2027-03), today 2026-11-28 two months back.
    private let feb = "m1-2027-02"
    private let mar = "m1-2027-03"
    private let jan15 = DayKey(year: 2027, month: 1, day: 15)
    private let nov28 = DayKey(year: 2026, month: 11, day: 28)

    override func setUp() async throws {
        bed = try SessionTestBed("ScreenPathsMonthYearTests")
        faults = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
        suiteName = "ScreenPathsMonthYearTests-\(UUID().uuidString)"
        scratch = UserDefaults(suiteName: suiteName)
        savedDefaults = AppSettings.defaults
        AppSettings.defaults = scratch
        setting = true
        stageTwo = []
        paths = makePaths()
        one = paths.onePage
    }

    override func tearDown() async throws {
        AppSettings.defaults = savedDefaults
        scratch?.removePersistentDomain(forName: suiteName)
        SpanSession.onFault = savedOnFault
        paths = nil
        one = nil
        bed?.tearDown()
        bed = nil
    }

    // MARK: Helpers (ScreenPathsSpanTests' own, TESTS_1_3: copied, that file is not touched)

    private func makePaths(screenshot: Bool = false, shot: ScreenshotMode.Config? = nil) -> ScreenPaths {
        let sleeper = bed.sessionSleeper
        let made = ScreenPaths(sync: bed.engine,
                               onePage: OnePageSession(sync: bed.engine, sleep: { await sleeper.sleep($0) },
                                                       clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) }),
                               screenshot: screenshot,
                               shot: shot,
                               settingOn: { [weak self] in self?.setting ?? true },
                               defaults: scratch,
                               sleep: { await sleeper.sleep($0) },
                               clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) })
        made.onStageTwo = { [weak self] in self?.stageTwo.append($0) }
        bed.engine.onRemoteUpdate = { [weak made] page in
            guard let made else { return }
            _ = made.remoteUpdated(page, shownPageId: made.onePage.page.pageId)
        }
        bed.engine.onRemoteDelete = { [weak made] id in
            guard let made else { return }
            _ = made.remoteDeleted(id, shownPageId: made.onePage.page.pageId)
        }
        return made
    }

    private func opening(_ kind: PageKind = .month, focus: DayKey? = nil, weekStart: WeekStart = .monday,
                         device: ScreenPaths.Device?? = .none, now: Date? = nil) -> ScreenPaths.Opening {
        ScreenPaths.Opening(kind: kind, focus: focus ?? nov16, weekStart: weekStart, device: device ?? ipad, paperArea: nil,
                            context: SpanSession.PaperContext(now: now ?? bed.now, calendar: SessionTestBed.tokyo))
    }

    /// The month window at 11/16 (or `o`) opened through `ScreenPaths` and read (the canvas starts `prefetch` as it attaches).
    @discardableResult
    private func openWindow(_ o: ScreenPaths.Opening? = nil, file: StaticString = #filePath, line: UInt = #line) async throws -> SpanSession {
        XCTAssertEqual(paths.open(o ?? opening()), .joined, file: file, line: line)
        let session = try XCTUnwrap(paths.span, file: file, line: line)
        await session.prefetch()
        return session
    }

    private func at(_ month: Int, _ day: Int, _ hour: Int, year: Int = 2026) throws -> Date {
        try XCTUnwrap(SessionTestBed.tokyo.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
    }

    /// The band x (lu) of the middle of the page `offset` pages from the focus page.
    private func middle(of session: SpanSession, slots offset: Int = 0) -> CGFloat {
        let w = session.plan.pageWidth
        return CGFloat(session.focusSlot + offset) * w + w / 2
    }

    /// The month page `pageId` of the window and its origin (band lu).
    private func month(_ pageId: String, of session: SpanSession, file: StaticString = #filePath,
                       line: UInt = #line) throws -> (page: MonthPageLayout, origin: CGFloat) {
        let slot = try XCTUnwrap(session.layout.slot(ofPage: pageId), pageId, file: file, line: line)
        let page = try XCTUnwrap(session.layout.pages[slot] as? MonthPageLayout, pageId, file: file, line: line)
        return (page, session.layout.origin(ofSlot: slot))
    }

    /// Screenshot mode's arguments of the photos of 2026-10 (its day: Wednesday 10/7) and `extra`.
    private func shotConfig(_ extra: [String]) throws -> ScreenshotMode.Config {
        try XCTUnwrap(ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "month"] + extra))
    }

    /// 1.3's formula of the focus (the week's and the day's, and the year's until it joins).
    private func formula(_ focus: DayKey, _ kind: PageKind, _ weekStart: WeekStart, movedTo pageFirstDay: DayKey) -> DayKey {
        let shown = PageNavigation.dayRange(kind, focus: focus, weekStart: weekStart)
        return focus.adding(days: pageFirstDay.dayNumber - shown.start.dayNumber)
    }

    /// The band x (lu) of the middle of the month page `pageId` of the window, wherever the focus is now.
    private func middle(of session: SpanSession, page pageId: String, file: StaticString = #filePath, line: UInt = #line) throws -> CGFloat {
        try month(pageId, of: session, file: file, line: line).origin + session.plan.pageWidth / 2
    }

    /// The paper slides to `midX` as the screen follows it (`CalendarRootScreen.spanFocusMoved`): the focus page moves
    /// (`SpanSession.scrolled`) and the screen's focus with it, through `ScreenPaths.carriedFocus`.
    private func followSlide(_ session: SpanSession, to midX: CGFloat, focus: inout DayKey, kind: PageKind = .month) {
        guard session.scrolled(midX: midX) else { return }
        focus = paths.carriedFocus(focus, kind: kind, weekStart: .monday, movedTo: session.focusDay)
    }

    /// The paper stops at `midX` as the screen takes it (`CalendarRootScreen.spanStopped`): `ScreenPaths.stopped` with the
    /// screen's focus, which the screen then sets (`focusMoved`).
    @discardableResult
    private func takeStop(_ session: SpanSession, at midX: CGFloat, focus: inout DayKey, kind: PageKind = .month) -> ScreenPaths.Stopped {
        let stopped = paths.stopped(session.stopped(midX: midX), focus: focus, kind: kind, weekStart: .monday, boundary: {})
        focus = stopped.focus
        return stopped
    }

    /// Where the window's canvas takes the paper for 「今日」's `rect` (`InkCanvasView`'s `reveal`: 1.1.1's
    /// `ZoomPolicy.revealOffset` from the screen's `viewport`, then the clamp to the band; past the fit nothing centres it):
    /// the offset's x (pt) and the middle of the screen (band lu, what `SpanSession.scrolled` and `stopped` read).
    private func canvasReveal(_ rect: CGRect, from viewport: PaperViewport, in session: SpanSession) -> (x: CGFloat, midX: CGFloat) {
        let zoom = viewport.zoom
        let offset = ZoomPolicy.revealOffset(rect: rect, zoom: zoom, viewport: CGSize(width: viewport.width, height: portrait.height),
                                             current: CGPoint(x: viewport.offsetX, y: 0))
        let x = min(max(offset.x, 0), max(0, session.layout.size.width * zoom - viewport.width))
        return (x, (x + viewport.width / 2) / zoom)
    }

    // MARK: §3.2 — the path

    /// MS1, §3.2, 0g-9: the month joins with the setting on (`SpanKinds.joined`), in screenshot mode only with its own setting
    /// (`--screenshot-span on`) and never with `--screenshot-single-page`; the setting off, stage 2 and the old versions' view
    /// keep it on one page. A joined month waits for the window scene as the week does (1.3's month opened on one page at
    /// once). The year: as `SpanKinds.joined` says.
    func testTheMonthOpensOnItsPath() async throws {
        XCTAssertTrue(ScreenPaths.joins(kind: .month, setting: true, screenshot: false, screenshotSpan: false, fallenBack: []))
        XCTAssertFalse(ScreenPaths.joins(kind: .month, setting: false, screenshot: false, screenshotSpan: true, fallenBack: []), "off")
        XCTAssertFalse(ScreenPaths.joins(kind: .month, setting: true, screenshot: true, screenshotSpan: false, fallenBack: []),
                       "screenshot mode's default")
        XCTAssertTrue(ScreenPaths.joins(kind: .month, setting: false, screenshot: true, screenshotSpan: true, fallenBack: []),
                      "screenshot mode's own setting")
        XCTAssertFalse(ScreenPaths.joins(kind: .month, setting: true, screenshot: false, screenshotSpan: false, fallenBack: [.month]),
                       "stage 2")
        XCTAssertTrue(ScreenPaths.joins(kind: .month, setting: true, screenshot: false, screenshotSpan: false, fallenBack: [.week, .day]),
                      "another kind's stage 2 is its own")
        XCTAssertFalse(ScreenPaths.joins(kind: .month, setting: true, screenshot: true, screenshotSpan: true, singlePage: true, fallenBack: []),
                       "--screenshot-single-page, the old versions' view")
        XCTAssertTrue(ScreenPaths.joins(kind: .month, setting: true, screenshot: false, screenshotSpan: false, singlePage: true, fallenBack: []),
                      "no screenshot argument outside screenshot mode")

        XCTAssertEqual(paths.open(opening()), .joined)
        XCTAssertEqual(paths.path, .joined)
        let session = try XCTUnwrap(paths.span)
        XCTAssertEqual(session.kind, .month)
        XCTAssertEqual(session.focusPageId, nov)
        XCTAssertEqual(session.pageIds, [sep, oct, nov, dec, jan])
        XCTAssertEqual(session.deviceClass, .iPad11)
        setting = false
        XCTAssertEqual(paths.open(opening()), .onePage)
        XCTAssertEqual(paths.path, .onePage)
        XCTAssertNil(paths.span)
        XCTAssertEqual(one.page.pageId, nov)
        setting = true
        XCTAssertEqual(paths.open(opening(.year)), SpanKinds.joined.contains(.year) ? .joined : .onePage, "the year: the set's answer")

        // C3-m11: no window of a guessed device.
        XCTAssertEqual(paths.open(opening(device: .some(nil))), .waiting)
        XCTAssertEqual(paths.path, .erasing)
        XCTAssertTrue(paths.waitingForScene)
        XCTAssertNil(paths.span)
        XCTAssertEqual(paths.open(opening()), .joined)
        XCTAssertFalse(paths.waitingForScene)

        // Screenshot mode: the one page unless its own setting is on; never with --screenshot-single-page.
        let on = makePaths(screenshot: true, shot: try shotConfig(["--screenshot-span", "on"]))
        XCTAssertTrue(on.screenshotSpan)
        XCTAssertEqual(on.open(opening(focus: oct7)), .joined)
        XCTAssertEqual(on.span?.focusPageId, oct)
        let plain = makePaths(screenshot: true, shot: try shotConfig([]))
        XCTAssertEqual(plain.open(opening(focus: oct7)), .onePage, "the photos of 1.4.2 stay on one page")
        XCTAssertEqual(plain.onePage.page.pageId, oct)
        let single = makePaths(screenshot: true, shot: try shotConfig(["--screenshot-span", "on", "--screenshot-single-page"]))
        XCTAssertEqual(single.open(opening(focus: oct7)), .onePage)
        XCTAssertEqual(faults, [])
    }

    /// §3.2: stage 2 works for the month as for the week (it does not look at the kind): a window of months estimated over the
    /// iPhone's cap as it opens falls back to one page for the month alone, once in this run, until the setting is turned on
    /// again; the week still joins.
    func testStageTwoSendsTheMonthToOnePage() async throws {
        let iPhone = ScreenPaths.Device(deviceClass: .iPhone, orientation: .portrait)
        let plan = SpanPlan(kind: .month, weekStart: .monday, deviceClass: .iPhone, orientation: .portrait, overviewCap: true)
        let focus = plan.index(containing: nov16)
        XCTAssertGreaterThanOrEqual(plan.radius, 1)
        // Each neighbour's file is estimated over the cap's share (`SpanPlan.estimatedStrokes`: 250 bytes a stroke).
        let share = SpanPlan.windowStrokeCap.iPhone / (2 * plan.radius) + 100
        for index in (focus - plan.radius)...(focus + plan.radius) where index != focus {
            try Data(repeating: 0x41, count: share * SpanPlan.bytesPerStroke).write(to: bed.store.url(for: plan.pageId(at: index)))
        }
        XCTAssertEqual(paths.open(opening(device: iPhone)), .fellBack)
        XCTAssertEqual(paths.path, .onePage)
        XCTAssertEqual(one.page.pageId, nov)
        XCTAssertEqual(paths.fallenBack, [.month])
        XCTAssertEqual(stageTwo, [.month], "N-8 once on this device for the month")
        XCTAssertEqual(paths.open(opening(device: iPhone)), .onePage, "the same run: one page")
        XCTAssertEqual(paths.open(opening(.week, device: iPhone)), .joined, "the week is its own kind")
        paths.settingChanged(true)
        XCTAssertEqual(paths.fallenBack, [])
    }

    // MARK: §3.6 — the focus

    /// MS2, §3.6, 0g-18: a month window's focus moves to the page's month keeping the day of the month, or the month's last day
    /// (1.3's formula counted from the grid's first day and stayed in the same month: 10/31 → 12/4, 11/30 → 11/5); the week and
    /// the day keep 1.3's formula, and the year keeps it until it joins (its rule, 2/29 → 2/28, comes with it). The screen's
    /// stop on a month window gives the new focus and remembers it.
    func testTheMonthsFocusKeepsTheDayOfTheMonth() async throws {
        let oct31 = DayKey(year: 2026, month: 10, day: 31)
        let nov1 = DayKey(year: 2026, month: 11, day: 1)
        for weekStart in WeekStart.allCases {
            XCTAssertEqual(ScreenPaths.focus(oct31, kind: .month, weekStart: weekStart, movedTo: nov1), DayKey(year: 2026, month: 11, day: 30),
                           "\(weekStart): 10/31 → November")
            XCTAssertEqual(ScreenPaths.focus(DayKey(year: 2026, month: 11, day: 30), kind: .month, weekStart: weekStart,
                                             movedTo: DayKey(year: 2026, month: 10, day: 1)),
                           DayKey(year: 2026, month: 10, day: 30), "\(weekStart): 11/30 → October")
            XCTAssertEqual(ScreenPaths.focus(DayKey(year: 2027, month: 1, day: 31), kind: .month, weekStart: weekStart,
                                             movedTo: DayKey(year: 2027, month: 2, day: 1)),
                           DayKey(year: 2027, month: 2, day: 28), "\(weekStart): 1/31 → February, its last day")
        }
        XCTAssertEqual(ScreenPaths.focus(DayKey(year: 2028, month: 1, day: 31), kind: .month, weekStart: .monday,
                                         movedTo: DayKey(year: 2028, month: 2, day: 1)),
                       DayKey(year: 2028, month: 2, day: 29), "a leap year's February")
        XCTAssertEqual(ScreenPaths.focus(DayKey(year: 2026, month: 12, day: 31), kind: .month, weekStart: .monday,
                                         movedTo: DayKey(year: 2027, month: 1, day: 1)),
                       DayKey(year: 2027, month: 1, day: 31), "across the new year")
        XCTAssertEqual(ScreenPaths.focus(DayKey(year: 2027, month: 3, day: 31), kind: .month, weekStart: .monday,
                                         movedTo: DayKey(year: 2026, month: 11, day: 1)),
                       DayKey(year: 2026, month: 11, day: 30), "back several months")
        XCTAssertEqual(ScreenPaths.focus(nov18, kind: .month, weekStart: .monday, movedTo: nov1), nov18, "the same page keeps the focus")
        XCTAssertNotEqual(ScreenPaths.focus(oct31, kind: .month, weekStart: .monday, movedTo: nov1), formula(oct31, .month, .monday, movedTo: nov1),
                          "not 1.3's formula")

        // The week and the day: 1.3's formula (the frozen ScreenPathsSpanTests' answers).
        let cases: [(DayKey, PageKind, WeekStart, DayKey)] = [
            (nov18, .week, .monday, DayKey(year: 2026, month: 11, day: 23)),
            (nov18, .week, .monday, DayKey(year: 2026, month: 11, day: 2)),
            (nov18, .week, .sunday, DayKey(year: 2026, month: 11, day: 22)),
            (oct31, .week, .monday, DayKey(year: 2026, month: 11, day: 2)),
            (nov16, .day, .monday, nov18),
            (oct31, .day, .sunday, nov1),
        ]
        for (focus, kind, weekStart, moved) in cases {
            XCTAssertEqual(ScreenPaths.focus(focus, kind: kind, weekStart: weekStart, movedTo: moved),
                           formula(focus, kind, weekStart, movedTo: moved), "\(kind) \(focus) → \(moved)")
        }
        // The year: its rule once it joins, 1.3's formula until then.
        let y2027 = DayKey(year: 2027, month: 1, day: 1)
        for focus in [DayKey(year: 2028, month: 12, day: 31), DayKey(year: 2028, month: 2, day: 29), DayKey(year: 2028, month: 7, day: 14)] {
            let moved = ScreenPaths.focus(focus, kind: .year, weekStart: .monday, movedTo: y2027)
            if SpanKinds.joined.contains(.year) {
                XCTAssertEqual(moved.year, 2027, "\(focus)")
                XCTAssertEqual(moved.month, focus.month, "\(focus): the same month")
                XCTAssertEqual(moved.day, min(focus.day, DayKey.daysInMonth(year: 2027, month: focus.month)), "\(focus): the same day, 2/29 → 2/28")
            } else {
                XCTAssertEqual(moved, formula(focus, .year, .monday, movedTo: y2027), "\(focus): 1.3's formula until the year joins")
            }
        }

        // The screen's stop: a window opened at 10/31 slides to November.
        let session = try await openWindow(opening(focus: oct31))
        XCTAssertEqual(session.focusPageId, oct)
        let stop = session.stopped(midX: middle(of: session, slots: 1))
        XCTAssertEqual(stop.focusDay, nov1, "the focus page's first day")
        var moved: [DayKey] = []
        let stopped = paths.stopped(stop, focus: oct31, kind: .month, weekStart: .monday, focusMoved: { moved.append($0) }, boundary: {})
        XCTAssertEqual(stopped.focus, DayKey(year: 2026, month: 11, day: 30))
        XCTAssertEqual(moved, [DayKey(year: 2026, month: 11, day: 30)])
        XCTAssertEqual(stopped.visitEnded?.pageId, oct)
        XCTAssertFalse(stopped.fallBack)
        XCTAssertEqual(scratch.string(forKey: AppSettings.lastFocusKey), "2026-11-30", "remembered (`lastFocusDate`)")
        XCTAssertEqual(scratch.string(forKey: AppSettings.lastKindKey), PageKind.month.rawValue)
        XCTAssertEqual(faults, [])
    }

    // MARK: §3.7 — 「今日」

    /// MS5, §3.7, 0g-19: the rect 「今日」 reveals on a month page zoomed in is today's cell (1.1.1's `PageNavigation.todayRect`
    /// of the page) with the page's origin added, not the page's width from its top (1.4.2's answer for a page that is not a
    /// week or a day); on another page of the window, that page's cell.
    func testTheMonthsTodayRectIsTodaysCell() async throws {
        let session = try await openWindow()
        let zoomed = PaperViewport(offsetX: 2 * 1_400 * 1.2, zoom: 1.2, width: 834)
        let now = try at(11, 18, 10)
        let november = try month(nov, of: session)
        let rect = try XCTUnwrap(ScreenPaths.todayRect(layout: session.layout, pageId: nov, now: now, calendar: SessionTestBed.tokyo,
                                                       viewport: zoomed, area: portrait))
        let cell = try XCTUnwrap(november.page.cells[.day(nov18)])
        XCTAssertEqual(rect, cell.offsetBy(dx: november.origin, dy: 0))
        XCTAssertEqual(november.origin, 2 * 1_400)
        XCTAssertEqual(rect.minX, november.origin + 2 * 200, accuracy: 1e-9, "Wednesday: the third column of a Monday week")
        XCTAssertEqual(rect.minY, november.page.rows[3].frame.minY, accuracy: 1e-9, "the row of 11/16–11/22")
        XCTAssertEqual(rect.width, 200, accuracy: 1e-9)
        XCTAssertEqual(rect.height, november.page.rows[3].frame.height, accuracy: 1e-9)
        XCTAssertLessThan(rect.width, november.page.size.width, "not the page's width")
        XCTAssertEqual(PageNavigation.todayRect(november.page, now: now, calendar: SessionTestBed.tokyo), cell, "1.1.1's rect of the one page")

        let december = try month(dec, of: session)
        let dec3 = DayKey(year: 2026, month: 12, day: 3)
        let decRect = try XCTUnwrap(ScreenPaths.todayRect(layout: session.layout, pageId: dec, now: try at(12, 3, 9),
                                                          calendar: SessionTestBed.tokyo, viewport: zoomed, area: portrait))
        XCTAssertEqual(decRect, try XCTUnwrap(december.page.cells[.day(dec3)]).offsetBy(dx: december.origin, dy: 0))
        XCTAssertEqual(decRect.minY, 0, accuracy: 1e-9, "12/3 is in December's first row (11/30–12/6)")
        XCTAssertEqual(faults, [])
    }

    /// §3.7, 0g-19, open question 10's default (S's decision): far → a new window; near at the overview → a slide; today's page
    /// already the focus at the overview → the request with no x (`monthTodayRequest`, `InkCanvasView.nowLineRevealRect`): y to
    /// the cell's top less 1.1.1's margin when the cell's bottom is off the screen, decided by the canvas; zoomed in → today's
    /// cell (on today's page, which need not be the focus). 等倍 on a landscape iPad (its fit above the opening zoom) is not
    /// zoomed in past the page's width (review UX-1): the overview's answers there (testTodayAtTheMonthsFitSlidesByPages).
    /// The one page keeps 1.1.1's 「今日」 (nil here).
    func testTodayOnAWindowOfMonths() async throws {
        let session = try await openWindow()
        let november = try month(nov, of: session)
        let december = try month(dec, of: session)
        let now = try at(11, 18, 10)
        let cell = try XCTUnwrap(november.page.cells[.day(nov18)])
        let far = DayKey(year: 2027, month: 6, day: 10)
        XCTAssertEqual(paths.today(far, now: now, viewport: nil, area: portrait, ratio: 1), .reopen(far))
        let dec3 = DayKey(year: 2026, month: 12, day: 3)
        XCTAssertEqual(paths.today(dec3, now: try at(12, 3, 9), viewport: nil, area: portrait, ratio: 1), .slide(1))
        XCTAssertEqual(paths.today(DayKey(year: 2026, month: 9, day: 10), now: try at(9, 10, 9), viewport: nil, area: portrait, ratio: 1),
                       .slide(-2))

        // Today's page is the focus at the overview: y alone, decided by the canvas.
        let bounds = session.layout.plan.zoomBounds(overview: InkCanvasView.bandOverview(session.layout), viewport: portrait)
        let overview = PaperViewport(offsetX: november.origin * bounds.open, zoom: bounds.open, width: portrait.width)
        for viewport in [overview, nil] as [PaperViewport?] {
            guard case .reveal(let request)? = paths.today(nov18, now: now, viewport: viewport, area: portrait, ratio: 1) else {
                return XCTFail("\(String(describing: viewport)): the overview's request")
            }
            XCTAssertTrue(request.origin.x.isNaN, "no x: x never moves")
            let lines = try XCTUnwrap(InkCanvasView.nowLineRevealLines(request), "the canvas reads it as the y-only request")
            XCTAssertEqual(lines.top, cell.minY - ZoomPolicy.revealMargin / bounds.open, accuracy: 1e-9, "the cell's top less the margin")
            XCTAssertEqual(lines.nowLine, cell.maxY, accuracy: 1e-9, "moves only while the cell's bottom is off the screen")
            XCTAssertNotNil(paths.revealRect(request, for: session), "for this window's canvas")
        }
        XCTAssertNotNil(ScreenPaths.monthTodayRequest(layout: session.layout, pageId: nov, now: now, calendar: SessionTestBed.tokyo,
                                                      zoom: bounds.open))
        XCTAssertNil(ScreenPaths.monthTodayRequest(layout: session.layout, pageId: jan, now: now, calendar: SessionTestBed.tokyo,
                                                   zoom: bounds.open), "a page that does not hold today")

        // Zoomed in: today's cell, on today's page.
        let zoomed = PaperViewport(offsetX: november.origin * 1.2, zoom: 1.2, width: portrait.width)
        guard case .reveal(let rect)? = paths.today(nov18, now: now, viewport: zoomed, area: portrait, ratio: 1) else {
            return XCTFail("zoomed in: today's cell")
        }
        XCTAssertEqual(rect, cell.offsetBy(dx: november.origin, dy: 0))
        guard case .reveal(let decRect)? = paths.today(dec3, now: try at(12, 3, 9), viewport: zoomed, area: portrait, ratio: 1) else {
            return XCTFail("zoomed in on another page of the window: its cell, not a slide")
        }
        XCTAssertEqual(decRect, try XCTUnwrap(december.page.cells[.day(dec3)]).offsetBy(dx: december.origin, dy: 0))
        XCTAssertTrue(ScreenPaths.zoomedIn(layout: session.layout, viewport: nil, area: portrait, ratio: 2))

        // A landscape iPad at the opening zoom (640 / 1,050; its 等倍 is testTodayAtTheMonthsFitSlidesByPages').
        guard case .reveal(let open)? = paths.today(nov18, now: now, viewport: nil, area: landscape, ratio: 1) else {
            return XCTFail("at the opening zoom: the y-only request")
        }
        XCTAssertNotNil(InkCanvasView.nowLineRevealLines(open))

        setting = false
        paths.open(opening())
        XCTAssertNil(paths.today(nov18, now: now, viewport: nil, area: portrait, ratio: 1), "the one page: 1.1.1's 「今日」")
        XCTAssertEqual(faults, [])
    }

    /// Review UX-1 (docs/R1_4_3_CONTRACT.md §1.2, §3.7): 等倍 on a landscape iPad — fit (1,210 / 1,400) above the opening zoom
    /// (640 / 1,050), so `zoomedIn` — puts one month across the screen, edge to edge. 「今日」 there is the overview's: another
    /// month of the window is a slide by pages (1.1.1's `reveal` of the cell would stop the band 8 pt into the month before,
    /// across two months, the focus and the title left where they were), and today's page already the focus is the y-only
    /// request, an edge column (Monday 11/16) too: x never moves. Before a report (`fit`), once the canvas reported the fit,
    /// and between the opening zoom and the fit. Past the fit (a pinch on from 等倍) it is today's cell, as zoomed in.
    func testTodayAtTheMonthsFitSlidesByPages() async throws {
        let session = try await openWindow()
        let november = try month(nov, of: session)
        let december = try month(dec, of: session)
        let wide = session.layout.plan.zoomBounds(overview: InkCanvasView.bandOverview(session.layout), viewport: landscape)
        XCTAssertGreaterThan(wide.fit, wide.open + 0.1)
        XCTAssertEqual(wide.clamped(wide.fit), wide.fit, "the fit is inside the limits")
        let atFit = PaperViewport(offsetX: november.origin * wide.fit, zoom: wide.fit, width: landscape.width)
        let between = PaperViewport(offsetX: november.origin * wide.fit, zoom: (wide.open + wide.fit) / 2, width: landscape.width)
        let past = PaperViewport(offsetX: november.origin * wide.fit * 1.5, zoom: wide.fit * 1.5, width: landscape.width)
        XCTAssertTrue(ScreenPaths.zoomedIn(layout: session.layout, viewport: nil, area: landscape, ratio: 1, fit: true))
        XCTAssertFalse(ScreenPaths.zoomedPastFit(layout: session.layout, viewport: nil, area: landscape, ratio: 1, fit: true))
        XCTAssertFalse(ScreenPaths.zoomedPastFit(layout: session.layout, viewport: atFit, area: landscape, ratio: 1))
        XCTAssertFalse(ScreenPaths.zoomedPastFit(layout: session.layout, viewport: between, area: landscape, ratio: 1))
        XCTAssertFalse(ScreenPaths.zoomedPastFit(layout: session.layout, viewport: nil, area: landscape, ratio: 1), "the opening zoom")
        XCTAssertTrue(ScreenPaths.zoomedPastFit(layout: session.layout, viewport: past, area: landscape, ratio: 1))
        XCTAssertTrue(ScreenPaths.zoomedPastFit(layout: session.layout, viewport: nil, area: landscape, ratio: 2), "a stored ratio past the fit")
        XCTAssertFalse(ScreenPaths.zoomedPastFit(layout: session.layout, viewport: nil, area: landscape, ratio: 2, fit: true),
                       "等倍 wins over the stored ratio, as the canvas opens")

        let dec3 = DayKey(year: 2026, month: 12, day: 3)
        let decNow = try at(12, 3, 9)
        for (name, viewport, fit) in [("fit", nil, true), ("reported", atFit, true), ("reported, no fit", atFit, false),
                                      ("between", between, false)] as [(String, PaperViewport?, Bool)] {
            XCTAssertEqual(paths.today(dec3, now: decNow, viewport: viewport, area: landscape, ratio: 1, fit: fit), .slide(1),
                           "\(name): another month of the window, a slide")
            XCTAssertEqual(paths.today(DayKey(year: 2026, month: 9, day: 10), now: try at(9, 10, 9), viewport: viewport, area: landscape,
                                       ratio: 1, fit: fit), .slide(-2), name)
            for (day, now) in [(nov18, try at(11, 18, 10)), (nov16, try at(11, 16, 10))] {
                let cell = try XCTUnwrap(november.page.cells[.day(day)])
                guard case .reveal(let request)? = paths.today(day, now: now, viewport: viewport, area: landscape, ratio: 1, fit: fit) else {
                    return XCTFail("\(name) \(day): the y-only request")
                }
                XCTAssertTrue(request.origin.x.isNaN, "\(name) \(day): no x, x never moves")
                let lines = try XCTUnwrap(InkCanvasView.nowLineRevealLines(request), "\(name) \(day)")
                let zoom = viewport?.zoom ?? wide.fit
                XCTAssertEqual(lines.top, max(0, cell.minY - ZoomPolicy.revealMargin / zoom), accuracy: 1e-9, "\(name) \(day)")
                XCTAssertEqual(lines.nowLine, cell.maxY, accuracy: 1e-9, "\(name) \(day)")
            }
        }
        XCTAssertEqual(november.page.cells[.day(nov16)]?.minX, 0, "11/16 is the first column of a Monday week")

        guard case .reveal(let decRect)? = paths.today(dec3, now: decNow, viewport: past, area: landscape, ratio: 1) else {
            return XCTFail("past the fit: today's cell")
        }
        XCTAssertEqual(decRect, try XCTUnwrap(december.page.cells[.day(dec3)]).offsetBy(dx: december.origin, dy: 0))
        XCTAssertEqual(faults, [])
    }

    /// Review UX-2 (a) (docs/R1_4_3_CONTRACT.md §3.7, §6.4): 「今日」 far away opens a new window of months at today (`.reopen`,
    /// the screen's `show`), and `reopenedToday` hands its canvas a rect for its first layout (1.1.1's `reveal`) bound to the
    /// new window: at the overview and at 等倍 a rect of no width at the middle of the focus page (which the opening keeps on
    /// screen) with today's cell's height, so y alone moves; past the fit the cell, as 1.1.1's one page. nil when the focus
    /// page does not hold today, for a week (1.3's) and on the one page (1.1.1's own lines).
    func testTodayFarAwayBringsTheNewMonthsCellOnScreen() async throws {
        let far = DayKey(year: 2027, month: 6, day: 30)
        let farNow = try at(6, 30, 10, year: 2027)
        let old = try await openWindow()
        XCTAssertNil(paths.reopenedToday(now: farNow), "no 「今日」 yet")
        XCTAssertEqual(paths.today(far, now: farNow, viewport: nil, area: landscape, ratio: 1, fit: true), .reopen(far))
        XCTAssertNil(paths.reopenedToday(now: farNow, area: landscape, ratio: 1, fit: true), "the window shown does not hold today")

        let session = try await openWindow(opening(focus: far, now: farNow))
        XCTAssertNotEqual(session.id, old.id)
        let june = try month("m1-2027-06", of: session)
        let cell = try XCTUnwrap(june.page.cells[.day(far)])
        // The screen's call: the inputs of the 「今日」 above (landscape, ratio 1, 等倍), kept across the screen's `show`, once.
        let kept = try XCTUnwrap(paths.reopenedToday(now: farNow), "the inputs kept with .reopen")
        XCTAssertEqual(kept, paths.reopenedToday(now: farNow, area: landscape, ratio: 1, fit: true))
        XCTAssertNil(paths.reopenedToday(now: farNow), "taken once")
        let again = paths.today(far, now: farNow, viewport: nil, area: landscape, ratio: 1, fit: true)
        XCTAssertNotNil(again)
        if case .reopen? = again { XCTFail("today's page is the focus now: not far") }
        XCTAssertNil(paths.reopenedToday(now: farNow), "a 「今日」 that did not reopen keeps nothing")
        for (name, area, ratio, fit) in [("landscape 等倍", landscape, CGFloat(1), true), ("landscape open", landscape, 1, false),
                                         ("portrait", portrait, 1, false), ("portrait 等倍", portrait, 1, true)]
            as [(String, CGSize, CGFloat, Bool)] {
            let rect = try XCTUnwrap(paths.reopenedToday(now: farNow, area: area, ratio: ratio, fit: fit), name)
            XCTAssertEqual(rect.minX, june.origin + session.plan.pageWidth / 2, accuracy: 1e-9, "\(name): the focus page's middle")
            XCTAssertEqual(rect.width, 0, "\(name): no width, so x never moves")
            XCTAssertEqual(rect.minY, cell.minY, accuracy: 1e-9, name)
            XCTAssertEqual(rect.height, cell.height, accuracy: 1e-9, name)
            XCTAssertEqual(paths.revealRect(rect, for: session), rect, "\(name): for the new window's canvas")
            XCTAssertNil(paths.revealRect(rect, for: old), "\(name): never the old window's")
        }
        let zoomed = try XCTUnwrap(paths.reopenedToday(now: farNow, area: landscape, ratio: 2), "past the fit")
        XCTAssertEqual(zoomed, cell.offsetBy(dx: june.origin, dy: 0), "today's cell, as 1.1.1's one page")
        XCTAssertEqual(ScreenPaths.monthOpeningTodayRect(layout: session.layout, pageId: session.focusPageId, now: farNow,
                                                         calendar: SessionTestBed.tokyo, pastFit: true), zoomed)
        XCTAssertNil(ScreenPaths.monthOpeningTodayRect(layout: session.layout, pageId: session.focusPageId, now: try at(11, 18, 10),
                                                       calendar: SessionTestBed.tokyo, pastFit: false), "a page that does not hold today")

        XCTAssertEqual(paths.open(opening(.week, focus: far, now: farNow)), .joined)
        XCTAssertNil(paths.reopenedToday(now: farNow, area: landscape, ratio: 1, fit: true), "the week: 1.3's")
        setting = false
        paths.open(opening(focus: far, now: farNow))
        XCTAssertNil(paths.reopenedToday(now: farNow, area: landscape, ratio: 1), "the one page: 1.1.1's own")
        XCTAssertEqual(faults, [])
    }

    /// §4.5, 0g-15: the window's tables overlap by a week or two and today's mark is on both (11/30 is November's last day and
    /// a pale day of December's first row), on the window's paper too; 「今日」 zoomed in goes to the cell of the page that holds
    /// the day as its own (November), not to December's copy.
    func testTodaysMarkIsOnBothTablesOfTheWindow() async throws {
        let now = try at(11, 30, 10)
        let session = try await openWindow(opening(now: now))
        let nov30 = DayKey(year: 2026, month: 11, day: 30)
        for (id, inMonth) in [(nov, true), (dec, false)] {
            let page = try month(id, of: session).page
            let label = try XCTUnwrap(page.dateLabels.first { $0.day == nov30 }, id)
            XCTAssertTrue(label.isToday, id)
            XCTAssertEqual(label.inMonth, inMonth, id)
            XCTAssertEqual(page.dateLabels.filter(\.isToday).map(\.day), [nov30], "\(id): one mark")
            XCTAssertNotNil(PageNavigation.todayRect(page, now: now, calendar: SessionTestBed.tokyo), id)
        }
        for id in [sep, oct, jan] {
            XCTAssertEqual(try month(id, of: session).page.dateLabels.filter(\.isToday), [], "\(id): no mark")
        }
        let window = try XCTUnwrap(PaperSpan.window(for: session.layout, focus: session.focusSlot))
        let marked = window.pages.compactMap { content -> String? in
            guard case .month(let paper) = content, paper.labels.contains(where: \.isToday) else { return nil }
            return paper.layout.pageId
        }
        XCTAssertEqual(marked, [nov, dec], "the paper draws both marks")

        let november = try month(nov, of: session)
        let zoomed = PaperViewport(offsetX: november.origin * 1.2, zoom: 1.2, width: portrait.width)
        guard case .reveal(let rect)? = paths.today(nov30, now: now, viewport: zoomed, area: portrait, ratio: 1) else {
            return XCTFail("zoomed in: today's cell")
        }
        XCTAssertEqual(rect, try XCTUnwrap(november.page.cells[.day(nov30)]).offsetBy(dx: november.origin, dy: 0), "November's own day")
        XCTAssertEqual(faults, [])
    }

    // MARK: §3.6, §3.7 — 「今日」's focus (review UX-3)

    /// Review UX-3 (1) (1.4.2's one page, whose 「今日」 opened the month at today): 「今日」 on a window of months slides to
    /// today's month (2027-01-15 → 2026-11-28, two months back); the month on the way keeps the day of the month (§3.6), and
    /// once the paper is on today's month the screen's focus is today — mid-slide (the screen's `spanFocusMoved`) and at the
    /// stop, which remembers it — so 週 then opens today's week. A stop that is the first to reach today's month brings it too.
    func testTodayFromAnotherMonthStopsWithTodayAsTheFocus() async throws {
        let now = try at(11, 28, 10)
        let session = try await openWindow(opening(focus: jan15))
        XCTAssertEqual(session.pageIds, [nov, dec, jan, feb, mar])
        var focus = jan15
        XCTAssertEqual(paths.today(nov28, now: now, viewport: nil, area: portrait, ratio: 1), .slide(-2))
        XCTAssertNil(paths.todayFocus(nov28), "another page: the stop's")
        followSlide(session, to: try middle(of: session, page: dec), focus: &focus)
        XCTAssertEqual(focus, DayKey(year: 2026, month: 12, day: 15), "the month on the way keeps the day of the month")
        followSlide(session, to: try middle(of: session, page: nov), focus: &focus)
        XCTAssertEqual(focus, nov28, "today's month brings today, mid-slide")
        let stopped = takeStop(session, at: try middle(of: session, page: nov), focus: &focus)
        XCTAssertEqual(stopped.focus, nov28, "and the stop keeps it")
        XCTAssertEqual(stopped.visitEnded?.pageId, jan)
        XCTAssertEqual(scratch.string(forKey: AppSettings.lastFocusKey), "2026-11-28", "remembered (`lastFocusDate`)")
        XCTAssertEqual(scratch.string(forKey: AppSettings.lastKindKey), PageKind.month.rawValue)

        // The stop itself the first to reach today's month (no focus move told before it).
        let december = DayKey(year: 2026, month: 12, day: 15)
        let other = try await openWindow(opening(focus: december))
        var shown = december
        XCTAssertEqual(paths.today(nov28, now: now, viewport: nil, area: portrait, ratio: 1), .slide(-1))
        takeStop(other, at: try middle(of: other, page: nov), focus: &shown)
        XCTAssertEqual(shown, nov28)
        XCTAssertEqual(scratch.string(forKey: AppSettings.lastFocusKey), "2026-11-28")

        // 週 from there opens today's week (the carry's 11/15 would open 11/9–11/15).
        XCTAssertEqual(paths.open(opening(.week, focus: shown)), .joined)
        XCTAssertEqual(paths.span?.focusDay, DayKey(year: 2026, month: 11, day: 23))
        XCTAssertEqual(faults, [])
    }

    /// Review UX-3 (1): a long slide stops between its legs (`InkCanvasView`'s `slide(byPages:)` goes the most pages that end
    /// inside the band, the rest once the window shifted: on a landscape iPad at the month's overview, today two months
    /// away). The stop on the way keeps the day of the month and holds 「今日」's mark another `todayMarkGrace` from there, so
    /// the next leg, on the shifted window, still brings today (1.5 graces after 「今日」, 0.75 after the stop on the way).
    func testTodaysLongSlideKeepsTodayAcrossItsLegs() async throws {
        let session = try await openWindow(opening(focus: jan15))
        var focus = jan15
        XCTAssertEqual(paths.today(nov28, now: try at(11, 28, 10), viewport: nil, area: portrait, ratio: 1), .slide(-2))
        followSlide(session, to: try middle(of: session, page: dec), focus: &focus)
        bed.now = bed.now.addingTimeInterval(ScreenPaths.todayMarkGrace * 0.75)
        let first = takeStop(session, at: try middle(of: session, page: dec), focus: &focus)
        XCTAssertEqual(first.focus, DayKey(year: 2026, month: 12, day: 15), "the stop on the way keeps the day of the month")
        XCTAssertEqual(scratch.string(forKey: AppSettings.lastFocusKey), "2026-12-15")
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex))
        XCTAssertEqual(session.pageIds, [oct, nov, dec, jan, feb])
        await session.prefetch()

        bed.now = bed.now.addingTimeInterval(ScreenPaths.todayMarkGrace * 0.75)
        followSlide(session, to: try middle(of: session, page: nov), focus: &focus)
        XCTAssertEqual(focus, nov28, "the next leg: today's month brings today")
        takeStop(session, at: try middle(of: session, page: nov), focus: &focus)
        XCTAssertEqual(focus, nov28)
        XCTAssertEqual(scratch.string(forKey: AppSettings.lastFocusKey), "2026-11-28")
        XCTAssertEqual(faults, [])
    }

    /// Review UX-3 (5): 「今日」's mark never outlives its slide. A finger that takes the paper the other way (a stop on
    /// February, not on the way to November) ends it at once; a finger that stops the slide on the way (December) lets it go
    /// `todayMarkGrace` later; after either, a scroll by hand to November keeps the carry (11/15), not the stale today. And
    /// once 「今日」 has stopped on today's month (12/31 here), away (November's last day, 11/30) and back by hand is the
    /// carry's 12/30, not 「今日」's 12/31.
    func testAStopElsewhereEndsTodaysMark() async throws {
        let nov15 = DayKey(year: 2026, month: 11, day: 15)
        let now = try at(11, 28, 10)

        let away = try await openWindow(opening(focus: jan15))
        var focus = jan15
        XCTAssertEqual(paths.today(nov28, now: now, viewport: nil, area: portrait, ratio: 1), .slide(-2))
        followSlide(away, to: try middle(of: away, page: feb), focus: &focus)
        takeStop(away, at: try middle(of: away, page: feb), focus: &focus)
        XCTAssertEqual(focus, DayKey(year: 2027, month: 2, day: 15))
        for page in [jan, dec, nov] {
            followSlide(away, to: try middle(of: away, page: page), focus: &focus)
        }
        XCTAssertEqual(focus, nov15, "by hand to November: the carry")
        takeStop(away, at: try middle(of: away, page: nov), focus: &focus)
        XCTAssertEqual(focus, nov15)
        XCTAssertEqual(scratch.string(forKey: AppSettings.lastFocusKey), "2026-11-15")

        let interrupted = try await openWindow(opening(focus: jan15))
        var held = jan15
        XCTAssertEqual(paths.today(nov28, now: now, viewport: nil, area: portrait, ratio: 1), .slide(-2))
        followSlide(interrupted, to: try middle(of: interrupted, page: dec), focus: &held)
        takeStop(interrupted, at: try middle(of: interrupted, page: dec), focus: &held)
        XCTAssertEqual(held, DayKey(year: 2026, month: 12, day: 15))
        bed.now = bed.now.addingTimeInterval(ScreenPaths.todayMarkGrace + 1)
        followSlide(interrupted, to: try middle(of: interrupted, page: nov), focus: &held)
        XCTAssertEqual(held, nov15, "a later scroll by hand: the carry")
        takeStop(interrupted, at: try middle(of: interrupted, page: nov), focus: &held)
        XCTAssertEqual(held, nov15)

        let dec31 = DayKey(year: 2026, month: 12, day: 31)
        let done = try await openWindow(opening(focus: jan15))
        var day = jan15
        XCTAssertEqual(paths.today(dec31, now: try at(12, 31, 10), viewport: nil, area: portrait, ratio: 1), .slide(-1))
        takeStop(done, at: try middle(of: done, page: dec), focus: &day)
        XCTAssertEqual(day, dec31, "「今日」's stop")
        followSlide(done, to: try middle(of: done, page: nov), focus: &day)
        XCTAssertEqual(day, DayKey(year: 2026, month: 11, day: 30), "November's last day")
        takeStop(done, at: try middle(of: done, page: nov), focus: &day)
        followSlide(done, to: try middle(of: done, page: dec), focus: &day)
        XCTAssertEqual(day, DayKey(year: 2026, month: 12, day: 30), "back by hand: the carry")
        takeStop(done, at: try middle(of: done, page: dec), focus: &day)
        XCTAssertEqual(day, DayKey(year: 2026, month: 12, day: 30))
        XCTAssertEqual(scratch.string(forKey: AppSettings.lastFocusKey), "2026-12-30")
        XCTAssertEqual(faults, [])
    }

    /// Review UX-3 (5): ◀ ▶ (`move`), the next 「今日」 (whatever it answers: today's page the focus after midnight, or far
    /// away) and every opening anew (a kind switch, a week start switch, the same page opened again) let 「今日」's mark go: a
    /// scroll by hand to November afterwards keeps the carry (11/15 from 1/15), not the earlier 「今日」's 11/28.
    func testArrowsOpeningsAndTodayAgainEndTodaysMark() async throws {
        let nov15 = DayKey(year: 2026, month: 11, day: 15)
        let now = try at(11, 28, 10)

        let arrows = try await openWindow(opening(focus: jan15))
        var focus = jan15
        XCTAssertEqual(paths.today(nov28, now: now, viewport: nil, area: portrait, ratio: 1), .slide(-2))
        XCTAssertEqual(paths.move(by: -1), .slide(pages: -1))
        for page in [dec, nov] {
            followSlide(arrows, to: try middle(of: arrows, page: page), focus: &focus)
        }
        XCTAssertEqual(focus, nov15, "◀: the carry")

        let again = try await openWindow(opening(focus: jan15))
        XCTAssertEqual(paths.today(nov28, now: now, viewport: nil, area: portrait, ratio: 1), .slide(-2))
        let jan2 = DayKey(year: 2027, month: 1, day: 2)
        guard case .reveal? = paths.today(jan2, now: try at(1, 2, 10, year: 2027), viewport: nil, area: portrait, ratio: 1) else {
            return XCTFail("after midnight, today's page the focus: the y-only request")
        }
        var shown = try XCTUnwrap(paths.todayFocus(jan2), "the screen's focus is today")
        XCTAssertEqual(shown, jan2)
        for page in [dec, nov] {
            followSlide(again, to: try middle(of: again, page: page), focus: &shown)
        }
        XCTAssertEqual(shown, DayKey(year: 2026, month: 11, day: 2), "the second 「今日」 let the first one's mark go")

        let far = DayKey(year: 2027, month: 6, day: 30)
        let reopened = try await openWindow(opening(focus: jan15))
        var day = jan15
        XCTAssertEqual(paths.today(nov28, now: now, viewport: nil, area: portrait, ratio: 1), .slide(-2))
        XCTAssertEqual(paths.today(far, now: try at(6, 30, 10, year: 2027), viewport: nil, area: portrait, ratio: 1), .reopen(far))
        for page in [dec, nov] {
            followSlide(reopened, to: try middle(of: reopened, page: page), focus: &day)
        }
        XCTAssertEqual(day, nov15, "far away: no mark")

        for (name, steps) in [("a kind switch", [opening(.week, focus: jan15), opening(focus: jan15)]),
                              ("a week start switch", [opening(focus: jan15, weekStart: .sunday)]),
                              ("the same page opened again", [opening(focus: jan15)])] {
            try await openWindow(opening(focus: jan15))
            XCTAssertEqual(paths.today(nov28, now: now, viewport: nil, area: portrait, ratio: 1), .slide(-2), name)
            for o in steps {
                paths.open(o)
            }
            let window = try XCTUnwrap(paths.span, name)
            await window.prefetch()
            var carried = jan15
            for slot in [1, 0] {
                followSlide(window, to: try middle(of: window, page: window.pageIds[slot]), focus: &carried)
            }
            XCTAssertEqual(carried, nov15, name)
        }
        XCTAssertEqual(faults, [])
    }

    /// Review UX-3 (3), (4): 「今日」 on a window of months whose focus page already holds today (11/28 on November) — the
    /// y-only request at the overview, the cell zoomed in past the fit — slides nothing and no stop comes, so the screen
    /// makes today the focus at once (`todayFocus`, which `goToday` applies and remembers); a stop on the same month
    /// afterwards keeps it. Another month of the window is the stop's (nil); far away `.reopen`'s new window opens at today
    /// (its focus page holds it); the week (1.3's: its focus stays on its page) and the one page have none.
    func testTodayOnTheFocusMonthMakesTodayTheFocus() async throws {
        let now = try at(11, 28, 10)
        let session = try await openWindow()
        guard case .reveal? = paths.today(nov28, now: now, viewport: nil, area: portrait, ratio: 1) else {
            return XCTFail("the overview: the y-only request")
        }
        XCTAssertEqual(paths.todayFocus(nov28), nov28)
        let november = try month(nov, of: session)
        let zoomed = PaperViewport(offsetX: november.origin * 1.2, zoom: 1.2, width: portrait.width)
        guard case .reveal? = paths.today(nov28, now: now, viewport: zoomed, area: portrait, ratio: 1) else {
            return XCTFail("zoomed in past the fit: the cell")
        }
        XCTAssertEqual(paths.todayFocus(nov28), nov28)
        var focus = nov28
        takeStop(session, at: try middle(of: session, page: nov), focus: &focus)
        XCTAssertEqual(focus, nov28, "a stop on the same month keeps today")
        XCTAssertNil(paths.todayFocus(DayKey(year: 2026, month: 12, day: 3)), "another month: the stop's")

        let far = DayKey(year: 2027, month: 6, day: 30)
        let farNow = try at(6, 30, 10, year: 2027)
        XCTAssertEqual(paths.today(far, now: farNow, viewport: nil, area: portrait, ratio: 1), .reopen(far))
        XCTAssertNil(paths.todayFocus(far), "far away: `.reopen` opens at today")
        let reopened = try await openWindow(opening(focus: far, now: farNow))
        XCTAssertEqual(reopened.focusPageId, "m1-2027-06")
        XCTAssertEqual(paths.todayFocus(far), far, "the new window's focus page holds today")

        XCTAssertEqual(paths.open(opening(.week, focus: nov16)), .joined)
        XCTAssertNil(paths.todayFocus(nov18), "the week keeps its focus (1.3)")
        setting = false
        paths.open(opening())
        XCTAssertNil(paths.todayFocus(nov28), "the one page: 1.1.1's 「今日」")
        XCTAssertEqual(faults, [])
    }

    /// Review UX-3 (2): zoomed in past the fit, 「今日」 toward another month of the window reveals today's cell there (12/3);
    /// once the paper's focus page is December the focus is today, and the stop remembers it. A reveal that left the focus
    /// page where it was (the cell already on screen: no stop comes) lets the mark go `todayMarkGrace` later, so a scroll by
    /// hand to December then keeps the carry (12/16 from 11/16).
    func testTodayZoomedInPastTheFitTowardAnotherMonth() async throws {
        let dec3 = DayKey(year: 2026, month: 12, day: 3)
        let decNow = try at(12, 3, 9)
        let session = try await openWindow()
        let november = try month(nov, of: session)
        let zoomed = PaperViewport(offsetX: november.origin * 1.2, zoom: 1.2, width: portrait.width)
        guard case .reveal(let rect)? = paths.today(dec3, now: decNow, viewport: zoomed, area: portrait, ratio: 1) else {
            return XCTFail("zoomed in past the fit: today's cell")
        }
        XCTAssertNil(paths.todayFocus(dec3), "another month: the stop's")
        var focus = nov16
        followSlide(session, to: rect.midX, focus: &focus)
        XCTAssertEqual(session.focusPageId, dec)
        XCTAssertEqual(focus, dec3, "December the focus page: today")
        takeStop(session, at: rect.midX, focus: &focus)
        XCTAssertEqual(focus, dec3)
        XCTAssertEqual(scratch.string(forKey: AppSettings.lastFocusKey), "2026-12-03")

        let again = try await openWindow()
        var shown = nov16
        guard case .reveal? = paths.today(dec3, now: decNow, viewport: zoomed, area: portrait, ratio: 1) else {
            return XCTFail("zoomed in past the fit: today's cell")
        }
        bed.now = bed.now.addingTimeInterval(ScreenPaths.todayMarkGrace + 1)
        followSlide(again, to: try middle(of: again, page: dec), focus: &shown)
        XCTAssertEqual(shown, DayKey(year: 2026, month: 12, day: 16), "after the grace: the carry")
        XCTAssertEqual(faults, [])
    }

    /// Review UX3-R1: zoomed in past the fit on the 11-inch iPad in portrait (fit 834 / 1,400), 「今日」 toward the month next
    /// door with today in an edge column — Saturday 11/28 back from December, Monday 11/2 on from October, at zooms 0.7 and
    /// 1.2. 1.1.1's least movement of the cell (the canvas's `reveal`: `ZoomPolicy.revealOffset`, the clamp to the band) puts
    /// the cell at the edge of the screen it comes in from and leaves the middle of the screen within the old month's 6 %
    /// (`SpanPlan.focus`), so no stop on November would come. The rect (`monthTodayRevealRect`) puts the middle on November
    /// past the hysteresis, the cell still on screen with 1.1.1's margin and its y the cell's; the stop there brings today and
    /// remembers it. A middle column keeps the cell's own rect (12/3: testTodayZoomedInPastTheFitTowardAnotherMonth).
    func testTodayPastTheFitToAnEdgeColumnLandsOnTodaysMonth() async throws {
        let nov2 = DayKey(year: 2026, month: 11, day: 2)
        for (name, start, startPage, today, now) in [
            ("back from December", DayKey(year: 2026, month: 12, day: 16), dec, nov28, try at(11, 28, 10)),
            ("on from October", DayKey(year: 2026, month: 10, day: 16), oct, nov2, try at(11, 2, 10)),
        ] as [(String, DayKey, String, DayKey, Date)] {
            for zoom in [0.7, 1.2] as [CGFloat] {
                let step = "\(name) at \(zoom)"
                let session = try await openWindow(opening(focus: start))
                let november = try month(nov, of: session)
                let cell = try XCTUnwrap(november.page.cells[.day(today)], step).offsetBy(dx: november.origin, dy: 0)
                let viewport = PaperViewport(offsetX: try month(startPage, of: session).origin * zoom, zoom: zoom, width: portrait.width)
                XCTAssertTrue(ScreenPaths.zoomedPastFit(layout: session.layout, viewport: viewport, area: portrait, ratio: 1), step)

                let least = canvasReveal(cell, from: viewport, in: session)
                XCTAssertEqual(session.plan.focus(midX: least.midX, previous: session.focusSlot), session.focusSlot,
                               "\(step): the cell's least movement leaves the old month the focus page")
                guard case .reveal(let rect)? = paths.today(today, now: now, viewport: viewport, area: portrait, ratio: 1) else {
                    return XCTFail("\(step): zoomed in past the fit, a reveal")
                }
                XCTAssertEqual(rect.minY, cell.minY, accuracy: 1e-9, "\(step): y as the cell's")
                XCTAssertEqual(rect.height, cell.height, accuracy: 1e-9, step)
                let shown = canvasReveal(rect, from: viewport, in: session)
                let w = session.plan.pageWidth
                XCTAssertGreaterThan(shown.midX, november.origin + SpanPlan.focusHysteresis * w, "\(step): past the hysteresis")
                XCTAssertLessThan(shown.midX, november.origin + w - SpanPlan.focusHysteresis * w, step)
                XCTAssertLessThanOrEqual(shown.x, cell.minX * zoom - ZoomPolicy.revealMargin + 1e-6, "\(step): the cell on screen")
                XCTAssertGreaterThanOrEqual(shown.x + portrait.width, cell.maxX * zoom + ZoomPolicy.revealMargin - 1e-6, step)

                var focus = start
                followSlide(session, to: shown.midX, focus: &focus)
                XCTAssertEqual(session.focusPageId, nov, step)
                XCTAssertEqual(focus, today, "\(step): November the focus page, today")
                let stopped = takeStop(session, at: shown.midX, focus: &focus)
                XCTAssertEqual(stopped.focus, today, step)
                XCTAssertEqual(stopped.visitEnded?.pageId, startPage, step)
                XCTAssertEqual(scratch.string(forKey: AppSettings.lastFocusKey), today == nov28 ? "2026-11-28" : "2026-11-02", step)
            }
        }
        XCTAssertEqual(faults, [])
    }

    /// Review T-2: the forward long slide (2026-09-16 on to 2026-11-28, two months ahead: `.slide(2)`) stops on the way (October)
    /// between its legs as the backward one does (testTodaysLongSlideKeepsTodayAcrossItsLegs), and keeps 「今日」's mark there;
    /// a stop on the page 「今日」 was pressed on (the paper not moved yet) is on the way too, in both directions
    /// (`todayStopped(on:)`: the start page in, today's page out).
    func testTodaysForwardLongSlideAndAStopOnItsStartPageKeepTheMark() async throws {
        let sep16 = DayKey(year: 2026, month: 9, day: 16)
        let session = try await openWindow(opening(focus: sep16))
        XCTAssertEqual(session.pageIds, ["m1-2026-07", "m1-2026-08", sep, oct, nov])
        var focus = sep16
        XCTAssertEqual(paths.today(nov28, now: try at(11, 28, 10), viewport: nil, area: portrait, ratio: 1), .slide(2))
        let atStart = takeStop(session, at: try middle(of: session, page: sep), focus: &focus)
        XCTAssertEqual(atStart.focus, sep16, "the start page keeps its day")
        XCTAssertNil(atStart.visitEnded)
        followSlide(session, to: try middle(of: session, page: oct), focus: &focus)
        XCTAssertEqual(focus, DayKey(year: 2026, month: 10, day: 16), "the month on the way keeps the day of the month")
        bed.now = bed.now.addingTimeInterval(ScreenPaths.todayMarkGrace * 0.75)
        let first = takeStop(session, at: try middle(of: session, page: oct), focus: &focus)
        XCTAssertEqual(first.focus, DayKey(year: 2026, month: 10, day: 16), "the stop on the way keeps the day of the month")
        XCTAssertEqual(first.visitEnded?.pageId, sep)
        XCTAssertEqual(scratch.string(forKey: AppSettings.lastFocusKey), "2026-10-16")
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex))
        XCTAssertEqual(session.pageIds, ["m1-2026-08", sep, oct, nov, dec])
        await session.prefetch()

        bed.now = bed.now.addingTimeInterval(ScreenPaths.todayMarkGrace * 0.75)
        followSlide(session, to: try middle(of: session, page: nov), focus: &focus)
        XCTAssertEqual(focus, nov28, "the next leg: today's month brings today")
        takeStop(session, at: try middle(of: session, page: nov), focus: &focus)
        XCTAssertEqual(focus, nov28)
        XCTAssertEqual(scratch.string(forKey: AppSettings.lastFocusKey), "2026-11-28")

        // Backward (2027-01-15 back to 2026-11-28): a stop on January right after 「今日」.
        let back = try await openWindow(opening(focus: jan15))
        var day = jan15
        XCTAssertEqual(paths.today(nov28, now: try at(11, 28, 10), viewport: nil, area: portrait, ratio: 1), .slide(-2))
        takeStop(back, at: try middle(of: back, page: jan), focus: &day)
        XCTAssertEqual(day, jan15, "the start page keeps its day")
        followSlide(back, to: try middle(of: back, page: dec), focus: &day)
        XCTAssertEqual(day, DayKey(year: 2026, month: 12, day: 15))
        followSlide(back, to: try middle(of: back, page: nov), focus: &day)
        XCTAssertEqual(day, nov28, "the start page's stop kept the mark")
        XCTAssertEqual(faults, [])
    }

    /// Review UX-3: the week and the day keep their answers after 「今日」. The week slides to today's week (Thursday 11/26,
    /// one week on from Wednesday 11/18) and its stop keeps the weekday (11/25), 1.3's carry (the frozen
    /// ScreenPathsSpanTests); on its page 「今日」 changes no focus (`todayFocus` nil). The day's stop is the day (1.3's formula).
    func testTheWeekAndTheDayKeepTheirFocusAfterToday() async throws {
        let nov26 = DayKey(year: 2026, month: 11, day: 26)
        let week = try await openWindow(opening(.week, focus: nov18))
        var focus = nov18
        XCTAssertEqual(paths.today(nov26, now: try at(11, 26, 10), viewport: nil, area: portrait, ratio: 1), .slide(1))
        followSlide(week, to: middle(of: week, slots: 1), focus: &focus, kind: .week)
        XCTAssertEqual(focus, DayKey(year: 2026, month: 11, day: 25), "1.3's carry: the weekday")
        takeStop(week, at: middle(of: week), focus: &focus, kind: .week)
        XCTAssertEqual(focus, DayKey(year: 2026, month: 11, day: 25))
        XCTAssertEqual(focus, formula(nov18, .week, .monday, movedTo: DayKey(year: 2026, month: 11, day: 23)))
        XCTAssertEqual(scratch.string(forKey: AppSettings.lastFocusKey), "2026-11-25")
        XCTAssertNil(paths.todayFocus(nov26), "the week's page holds today: its focus stays")

        let nov17 = DayKey(year: 2026, month: 11, day: 17)
        let days = try await openWindow(opening(.day, focus: nov16))
        var shown = nov16
        XCTAssertEqual(paths.today(nov17, now: try at(11, 17, 10), viewport: nil, area: portrait, ratio: 1), .slide(1))
        takeStop(days, at: middle(of: days, slots: 1), focus: &shown, kind: .day)
        XCTAssertEqual(shown, nov17)
        XCTAssertEqual(shown, formula(nov16, .day, .monday, movedTo: nov17))
        XCTAssertNil(paths.todayFocus(nov17))
        XCTAssertEqual(faults, [])
    }

    /// Reviews UX3-R2, T-1: the screen's half of UX-3. XCTest does not run the screen's View (C3-M3), so its wires are read
    /// from the source in code only (`WeekMemoSpanTests.codeOnly`: comments and strings blanked), as ZoomFitWiringTests,
    /// OnePageRevealTests and ScreenPathsSpanTests read theirs. The slide in between follows the stop's rule
    /// (`spanFocusMoved` → `ScreenPaths.carriedFocus`); 「今日」's `.reveal` and `.stay` (today's month already the focus) make
    /// today the focus and remember it (`focusOnToday`: `paths.todayFocus`, then `remember()`); and the screen never
    /// carries the focus itself (`ScreenPaths.focus` is 0 in its code). The mid-slide half of case (1) and all of case (3)
    /// rest on these lines: going back to `ScreenPaths.focus` in `spanFocusMoved`, dropping `focusOnToday(today)` from either
    /// case or dropping `remember()` fails here.
    func testTheScreenWiresTodaysFocus() throws {
        let code = try Self.screenCode()
        let flat = code.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        func count(_ text: String) -> Int { flat.components(separatedBy: text).count - 1 }

        XCTAssertEqual(try Self.body(of: "func spanFocusMoved() {", in: code),
                       "guard let span = paths.span else { return } let next = paths.carriedFocus(focus, kind: kind, weekStart: weekStart, "
                       + "movedTo: span.focusDay) if next != focus { focus = next } }", "the slide in between: the stop's rule")
        XCTAssertEqual(try Self.body(of: "private func focusOnToday(_ today: DayKey) {", in: code),
                       "guard let day = paths.todayFocus(today) else { return } if day != focus { focus = day } remember() }",
                       "today's month already the focus: today, remembered")
        let goToday = try Self.body(of: "private func goToday() {", in: code)
        XCTAssertTrue(goToday.contains("case .reveal(let rect): revealRect = rect revealTrigger += 1 focusOnToday(today) "
                                       + "case .stay: focusOnToday(today) }"), "「今日」's .reveal and .stay: \(goToday)")
        XCTAssertEqual(count("focusOnToday(today)"), 2, "only those two")
        XCTAssertEqual(count("paths.todayFocus("), 1)
        XCTAssertEqual(count("paths.carriedFocus("), 1, "the stop's own call is ScreenPaths.stopped's")
        XCTAssertEqual(count("ScreenPaths.focus("), 0, "the screen never carries the focus itself")

        // Review UX-2 (a)'s wire: far away, the new window's first layout gets `reopenedToday`'s rect, made from the inputs
        // `paths.today` kept with its `.reopen` (the fit is passed once; the frozen ZoomFitWiringTests counts its three wires).
        XCTAssertTrue(goToday.contains("case .reopen(let day): show(kind: kind, focus: day) "
                                       + "if let rect = paths.reopenedToday(now: ScreenshotMode.current?.today ?? Date()) "
                                       + "{ revealRect = rect revealTrigger += 1 }"), "far away: \(goToday)")
        XCTAssertEqual(count("paths.reopenedToday("), 1)
        XCTAssertEqual(count("ratio: currentRatio, fit: currentFit)"), 3, "ZoomFitWiringTests' count (frozen)")
    }

    // MARK: §4.7 — the paper and the PDF; §3.8 — the heading

    /// §4.7, 0g-32, 0g-53: the paper of a window page (`ScreenPaths.paper(of:)`, one argument) is the month's, made by the one
    /// place (`PaperSpan.paperContent`), so the joined month's PDF (`pdfInput`) is its focus page with the memo stroke that
    /// reaches in from the left month (the real page has no window name); `focusPaper` follows. The week and the day are
    /// 1.3's; the year: as `SpanKinds.joined` says. The one page keeps 1.2.3's PDF (nil here).
    func testThePaperAndThePDFOfAWindowOfMonths() async throws {
        let session = try await openWindow()
        let november = try month(nov, of: session)
        let paper = try XCTUnwrap(ScreenPaths.paper(of: november.page))
        XCTAssertEqual(paper.kind, .month)
        XCTAssertEqual(paper, PaperSpan.paperContent(of: november.page))
        guard case .month(let content) = paper else { return XCTFail("a month's paper") }
        XCTAssertEqual(content.layout, november.page)
        XCTAssertEqual(content.labels, november.page.dateLabels)
        XCTAssertEqual(paths.focusPaper, paper, "the focus page's paper")

        let ledger = JoinedLedgerStandIn(session)
        let memo = try XCTUnwrap(session.layout.cells[SpanName.prefixed(.memo, page: oct)])
        XCTAssertEqual(memo.maxX, november.origin, accuracy: 1e-9)
        // Owned by October (its centre is left of the boundary), reaching 200 lu into November's memo.
        let crossing = try XCTUnwrap(ledger.draw([CGPoint(x: november.origin - 300, y: memo.minY + 200),
                                                  CGPoint(x: november.origin - 50, y: memo.minY + 205),
                                                  CGPoint(x: november.origin + 200, y: memo.minY + 200)]))
        XCTAssertEqual(crossing.cell, SpanName.prefixed(.memo, page: oct))
        let own = try XCTUnwrap(ledger.draw(on: nov, cell: .day(nov18), x: 40, y: 80))
        ledger.put()
        let input = try XCTUnwrap(paths.pdfInput(), "the joined month's PDF")
        XCTAssertEqual(input.page.pageId, nov)
        XCTAssertTrue(SpanGuard.checkForTransfer(input.page))
        XCTAssertFalse(input.page.strokes.keys.contains { $0.contains("|") })
        XCTAssertEqual(input.page.liveStrokeIds, [try XCTUnwrap(SpanName.split(own.id)?.local)])
        XCTAssertEqual(input.neighborInk.map(\.pageId), [oct])
        XCTAssertEqual(input.neighborInk.first?.stroke.id, SpanName.split(crossing.id)?.local)
        XCTAssertEqual(input.focus, DayKey(year: 2026, month: 11, day: 1))
        XCTAssertEqual(input.paper.layout.pageId, nov)
        XCTAssertEqual(input.paper.kind, .month)

        // Every kind: the paper of a page as the set says.
        for (number, kind) in [PageKind.week, .day, .year].enumerated() {
            let other = bed.session(kind, focus: nov16, number: 10 + number)
            await other.prefetch()
            let page = other.layout.pages[other.focusSlot]
            XCTAssertEqual(ScreenPaths.paper(of: page) != nil, SpanKinds.joined.contains(kind), "\(kind)")
            if kind == .week {
                XCTAssertEqual(ScreenPaths.paper(of: page), .week(WeekPaperContent(layout: try XCTUnwrap(page as? WeekPageLayout))), "1.3's")
            }
            if kind == .day {
                XCTAssertEqual(ScreenPaths.paper(of: page), .day(DayPaperContent(layout: try XCTUnwrap(page as? DayPageLayout))), "1.3's")
            }
        }

        setting = false
        paths.open(opening())
        XCTAssertNil(paths.pdfInput(), "the one page's PDF is 1.2.3's")
        XCTAssertNil(paths.focusPaper)
        XCTAssertEqual(faults, [])
    }

    /// MP1, §3.8, 0g-20: the heading's window of a month window is made (1.4.2 made none: `PaperSpan(layout:bands:focus:)` is
    /// nil for a month) and is `PaperSpan.window` of the session's layout: the pages alone, no all-day band; `headingSpan` has
    /// the focus of now. A shifted window waits for its viewport as the week's does.
    func testTheHeadingOfAWindowOfMonths() async throws {
        let session = try await openWindow()
        let heading = try XCTUnwrap(paths.heading, "the heading of a month window")
        XCTAssertEqual(heading.version, session.windowVersion)
        XCTAssertEqual(heading.firstIndex, session.layout.firstIndex)
        XCTAssertEqual(heading.span, PaperSpan.window(for: session.layout, focus: session.focusSlot))
        XCTAssertEqual(heading.span.kind, .month)
        XCTAssertEqual(heading.span.bands, [], "no all-day band")
        XCTAssertEqual(heading.span.pages.map(\.layout.pageId), session.pageIds)
        XCTAssertEqual(paths.headingSpan?.focus, session.focusSlot)
        XCTAssertEqual(paths.headingSpan?.bands, [])

        let v1 = PaperViewport(offsetX: 2 * 1_400 * 0.5957, zoom: 0.5957, width: 834)
        paths.viewportArrived(v1)
        session.contextChanged()
        XCTAssertEqual(paths.heading?.version, session.windowVersion, "the first page did not move: at once")
        XCTAssertEqual(paths.heading?.viewport, v1)
        _ = session.stopped(midX: middle(of: session, slots: 1))
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex))
        let v2 = PaperViewport(offsetX: v1.offsetX - 1_400 * 0.5957, zoom: 0.5957, width: 834)
        paths.viewportArrived(v2)
        let shifted = try XCTUnwrap(paths.heading)
        XCTAssertEqual(shifted.version, session.windowVersion)
        XCTAssertEqual(shifted.span, PaperSpan.window(for: session.layout, focus: session.focusSlot))
        XCTAssertEqual(shifted.span.pages.map(\.layout.pageId), [oct, nov, dec, jan, "m1-2027-02"])
        XCTAssertEqual(shifted.viewport, v2)
        XCTAssertEqual(faults, [])
    }

    // MARK: §12.4 — the old versions' view of a month

    /// §12.4, 0g-31: `--screenshot-single-page` opens a month on one page with its own half of the memo's crossing sample
    /// (`--screenshot-span-crossing all`: the focus month's stroke, which runs off its left edge; never the left month's) and,
    /// on the month right of the photos' month, the tall rows (`--screenshot-month-tall`); without those two arguments the
    /// strokes of 1.2.3's demo page (as the frozen ScreenPathsSpanTests checks). Nil without the argument and in normal use;
    /// the year: as `SpanKinds.joined` says.
    func testTheOldVersionsOnePageOfAMonth() throws {
        let demo = ScreenshotMode.demoPage(kind: .month, focus: oct7, grown: false, empty: false, tallYear: false, weekStart: .monday,
                                           storeInk: false)
        let ids = ScreenshotMode.monthCrossingStrokeIds

        let plain = try shotConfig(["--screenshot-span", "on", "--screenshot-single-page"])
        let plainPage = try XCTUnwrap(ScreenPaths.singlePageDemo(plain, opening(focus: oct7)))
        XCTAssertEqual(plainPage.pageId, oct)
        XCTAssertEqual(Set(plainPage.liveStrokeIds), Set(demo.liveStrokeIds), "without the new arguments: 1.2.3's demo")

        let all = try shotConfig(["--screenshot-span", "on", "--screenshot-single-page", "--screenshot-span-crossing", "all"])
        XCTAssertTrue(all.spanCrossingAll)
        let page = try XCTUnwrap(ScreenPaths.singlePageDemo(all, opening(focus: oct7)))
        XCTAssertEqual(Set(page.liveStrokeIds), Set(demo.liveStrokeIds).union([ids.focus]), "its own half")
        XCTAssertFalse(page.liveStrokeIds.contains(ids.left), "never the left month's")
        let half = try XCTUnwrap(page.strokes[ids.focus])
        XCTAssertEqual(half.cell, .memo)
        XCTAssertLessThan(half.points.map(\.x).min() ?? 0, 0, "it runs off the left edge")

        // Through the path: one page with that page.
        let single = makePaths(screenshot: true, shot: all)
        XCTAssertEqual(single.open(opening(focus: oct7)), .onePage)
        XCTAssertEqual(Set(single.onePage.page.liveStrokeIds), Set(page.liveStrokeIds))

        // The month right of the photos' month with --screenshot-month-tall: its tall rows (the neighbour's own ids).
        let tall = try shotConfig(["--screenshot-span", "on", "--screenshot-single-page", "--screenshot-month-tall"])
        let right = try XCTUnwrap(ScreenPaths.singlePageDemo(tall, opening(focus: nov16)))
        XCTAssertEqual(right.pageId, nov)
        XCTAssertTrue(Set(right.liveStrokeIds).isSuperset(of: ["demo-stroke-month-tall-1", "demo-stroke-month-tall-2", "demo-stroke-month-tall-3"]))
        XCTAssertFalse(Set(try XCTUnwrap(ScreenPaths.singlePageDemo(tall, opening(focus: oct7))).liveStrokeIds)
            .contains("demo-stroke-month-tall-1"), "the photos' own month has none")

        XCTAssertNil(ScreenPaths.singlePageDemo(try shotConfig(["--screenshot-span", "on", "--screenshot-span-crossing", "all"]),
                                                opening(focus: oct7)), "no --screenshot-single-page")
        XCTAssertNil(ScreenPaths.singlePageDemo(nil, opening(focus: oct7)), "normal use")
        XCTAssertEqual(ScreenPaths.singlePageDemo(plain, opening(.year, focus: oct7)) != nil, SpanKinds.joined.contains(.year), "the year")
        // The week keeps 1.3's page (its crossing demo's halves).
        let week = try XCTUnwrap(ScreenPaths.singlePageDemo(all, opening(.week, focus: oct7)))
        XCTAssertTrue(Set(week.liveStrokeIds).isSuperset(of: ScreenshotMode.crossingDemoStrokeIds(.week).focus))
        XCTAssertFalse(week.liveStrokeIds.contains(ids.focus), "the month's sample is the month's")
    }

    // MARK: The source (the screen's wires)

    /// CalendarRootScreen.swift in code only (comments and strings blanked, `WeekMemoSpanTests.codeOnly`).
    private static func screenCode() throws -> String {
        let url = repository.appendingPathComponent("Sources/TegakiCalendar/Views/CalendarRootScreen.swift")
        return String(WeekMemoSpanTests.codeOnly(try String(contentsOf: url, encoding: .utf8)))
    }

    /// The body of the function of `code` whose head (to its "{") is `head`, to its closing "}", every run of white space one
    /// space (the shape of ScreenPathsSpanTests' helper, which is private there).
    private static func body(of head: String, in code: String) throws -> String {
        let start = try XCTUnwrap(code.range(of: head), "\(head) is in CalendarRootScreen.swift")
        XCTAssertNil(code.range(of: head, range: start.upperBound..<code.endIndex), "\(head) is there once")
        var depth = 1
        var end = start.upperBound
        while end < code.endIndex, depth > 0 {
            if code[end] == "{" { depth += 1 } else if code[end] == "}" { depth -= 1 }
            end = code.index(after: end)
        }
        return code[start.upperBound..<end].split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static let repository = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
}
