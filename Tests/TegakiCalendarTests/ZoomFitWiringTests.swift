import InkModel
import Layout
import XCTest
@testable import TegakiCalendar

// 1.4.1's rework (docs/R1_4_1_CONTRACT.md §16.3.4, §16.3.7, §16.5, §16.6; role S): the screen's side of 等倍 on the week and
// the day, one page's width across the paper's column (`ZoomPolicy.Bounds.fit`). A kind kept at 等倍 (`zoomFit.<kind>`, or
// `--screenshot-zoom fit` in screenshot mode) opens at its fit: the joined path's first frame (`ScreenPaths.bandZoom` /
// `bandViewport` with `fit:`: the focus page's edges at the column's edges, offsetX = origin · fit) and 「今日」 before a
// report (`zoomedIn` / `today` with `fit:`: zoomed in wherever the fit is above the opening zoom, not where they are the same,
// as the answer is once the canvas reported). Screenshot mode's `--screenshot-zoom fit` and `ScreenshotMode.zoomFit`. The
// screen's View is not run by XCTest (C3-M3), so its wires are read from the source, in code only
// (`WeekMemoSpanTests.codeOnly`; the screen's comments name the same calls): both canvases get `initialFit: currentFit` and
// keep what they say through `AppSettings.setZoomFit` outside screenshot mode. The windows are opened through `ScreenPaths`
// over a live `SyncEngine` (SessionTestBed), as CappedOverviewWideTests does; no real sleep.
@MainActor
final class ZoomFitWiringTests: XCTestCase {
    private var bed: SessionTestBed!
    private var faults: [String] = []
    private var savedOnFault: ((String) -> Void)!
    private var savedDefaults: UserDefaults!
    private var scratch: UserDefaults!
    private var suiteName = ""
    private var paths: ScreenPaths!

    private let nov16 = DayKey(year: 2026, month: 11, day: 16)
    private let nov18 = DayKey(year: 2026, month: 11, day: 18)
    private let dec3 = DayKey(year: 2026, month: 12, day: 3)
    private let iPad = ScreenPaths.Device(deviceClass: .iPad11, orientation: .portrait)
    private let phonePortrait = ScreenPaths.Device(deviceClass: .iPhone, orientation: .portrait)
    private let phoneLandscape = ScreenPaths.Device(deviceClass: .iPhone, orientation: .landscape)
    private let base = ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "week"]

    override func setUp() async throws {
        bed = try SessionTestBed("ZoomFitWiringTests")
        faults = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
        suiteName = "ZoomFitWiringTests-\(UUID().uuidString)"
        scratch = UserDefaults(suiteName: suiteName)
        savedDefaults = AppSettings.defaults
        AppSettings.defaults = scratch
        let sleeper = bed.sessionSleeper
        paths = ScreenPaths(sync: bed.engine,
                            onePage: OnePageSession(sync: bed.engine, sleep: { await sleeper.sleep($0) },
                                                    clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) }),
                            screenshot: false, shot: nil, settingOn: { true }, defaults: scratch,
                            sleep: { await sleeper.sleep($0) },
                            clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) })
    }

    override func tearDown() async throws {
        XCTAssertEqual(faults, [], "no fault of the window's bookkeeping")
        AppSettings.defaults = savedDefaults
        scratch?.removePersistentDomain(forName: suiteName)
        SpanSession.onFault = savedOnFault
        paths = nil
        bed?.tearDown()
        bed = nil
    }

    private func at(_ month: Int, _ day: Int, _ hour: Int) throws -> Date {
        try XCTUnwrap(SessionTestBed.tokyo.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)))
    }

    /// The window of `kind` at `focus` opened through `ScreenPaths` for `device` and the paper area `area`, read.
    private func openWindow(_ kind: PageKind, focus: DayKey, device: ScreenPaths.Device, area: CGSize, now: Date,
                            file: StaticString = #filePath, line: UInt = #line) async throws -> SpanSession {
        let opening = ScreenPaths.Opening(kind: kind, focus: focus, weekStart: .monday, device: device, paperArea: area,
                                          context: SpanSession.PaperContext(now: now, calendar: SessionTestBed.tokyo))
        XCTAssertEqual(paths.open(opening), .joined, file: file, line: line)
        let session = try XCTUnwrap(paths.span, file: file, line: line)
        await session.prefetch()
        return session
    }

    // MARK: ScreenPaths

    /// A window of a kind kept at 等倍 opens at the fit, column width ÷ one page's width (the cap of an iPhone in landscape
    /// never changes it), with the focus page's left and right edges at the column's: `bandZoom` and `bandViewport` with
    /// `fit` (the stored ratio is not read), the canvas's start (`bandStart` at the fit's visible width: the page's own
    /// left edge) and no opening offset (the fit is never the capped overview). Without `fit` everything is as before.
    /// Before a report `zoomedIn` says what the reported fit will say: zoomed in wherever the fit is above the opening zoom
    /// (the iPads, an iPhone in landscape: 3 and 5 times the cap), not where they are the same (an iPhone 18 Pro Max's
    /// portrait week, 440 × 622: open = fit = 0.314286); a reported viewport decides whatever `fit` says.
    func testTheWindowOpensAtTheFitWithTheFocusPageAcross() async throws {
        let now = try at(11, 18, 15)
        let cases: [(PageKind, DayKey, ScreenPaths.Device, CGSize, Bool, String)] = [
            (.week, nov16, iPad, CGSize(width: 834, height: 955), true, "iPad 11 portrait week"),
            (.day, nov18, iPad, CGSize(width: 834, height: 951), true, "iPad 11 portrait day"),
            (.week, nov16, phoneLandscape, CGSize(width: 874, height: 205), true, "iPhone landscape week (the cap)"),
            (.day, nov18, phoneLandscape, CGSize(width: 874, height: 205), true, "iPhone landscape day (the cap)"),
            (.week, nov16, phonePortrait, CGSize(width: 440, height: 622), false, "18 Pro Max portrait week (open = fit)"),
        ]
        for (kind, focus, device, area, above, name) in cases {
            let session = try await openWindow(kind, focus: focus, device: device, area: area, now: now)
            let layout = session.layout
            let page = ZoomPolicy.paperWidth(kind)
            let fit = area.width / page
            let bounds = session.plan.zoomBounds(overview: InkCanvasView.bandOverview(layout), viewport: area)
            XCTAssertEqual(bounds.fit, fit, accuracy: 1e-12, "\(name): the column's width over one page's")
            if above {
                XCTAssertGreaterThan(fit, bounds.open * ScreenPaths.overviewRatio, "\(name): the fit is above the opening zoom")
            } else {
                XCTAssertEqual(fit, bounds.open, accuracy: 1e-12, "\(name): the fit is the opening zoom")
            }

            let zoom = ScreenPaths.bandZoom(layout: layout, area: area, ratio: 1, fit: true)
            XCTAssertEqual(zoom, fit, accuracy: 1e-12, name)
            XCTAssertEqual(ScreenPaths.bandZoom(layout: layout, area: area, ratio: 3, fit: true), fit, accuracy: 1e-12,
                           "\(name): the ratio is not read")
            XCTAssertEqual(ScreenPaths.bandZoom(layout: layout, area: area, ratio: 1), bounds.open, accuracy: 1e-12, "\(name): as before")
            XCTAssertEqual(ScreenPaths.bandZoom(layout: layout, area: area, ratio: 1, fit: false), bounds.open, accuracy: 1e-12, name)

            let origin = try XCTUnwrap(session.origin(ofPage: session.focusPageId), name)
            let first = ScreenPaths.bandViewport(layout: layout, focusPageId: session.focusPageId, now: now, calendar: SessionTestBed.tokyo,
                                                 area: area, ratio: 1, fit: true)
            XCTAssertEqual(first.zoom, fit, accuracy: 1e-12, name)
            XCTAssertEqual(first.width, area.width, name)
            XCTAssertEqual(first.offsetX, origin * fit, accuracy: 1e-6, "\(name): the focus page's left edge at the column's")
            XCTAssertEqual((origin + page) * fit - first.offsetX, area.width, accuracy: 1e-6, "\(name): its right edge at the column's")
            let plain = ScreenPaths.bandViewport(layout: layout, focusPageId: session.focusPageId, now: now, calendar: SessionTestBed.tokyo,
                                                 area: area, ratio: 1)
            XCTAssertEqual(plain, ScreenPaths.bandViewport(layout: layout, focusPageId: session.focusPageId, now: now,
                                                           calendar: SessionTestBed.tokyo, area: area, ratio: 1, fit: false), name)
            XCTAssertEqual(plain.zoom, bounds.open, accuracy: 1e-12, "\(name): without fit, the opening zoom as before")

            // The canvas's opening (`joinedCanvas`): its start at the fit's visible width, and no offset of its own.
            let start = ScreenPaths.bandStart(layout: layout, focusPageId: session.focusPageId, now: now, calendar: SessionTestBed.tokyo,
                                              visibleWidth: ZoomPolicy.visibleWidth(kind, viewportWidth: area.width, zoom: zoom))
            XCTAssertEqual(start.x, origin, accuracy: 1e-9, "\(name): the canvas opens the focus page at its left edge")
            XCTAssertEqual(start.y, PageNavigation.initialScrollY(layout.pages[session.focusSlot], now: now, calendar: SessionTestBed.tokyo),
                           accuracy: 1e-9, "\(name): the canvas's initialScrollY")
            XCTAssertFalse(ScreenPaths.atCappedOverview(layout: layout, width: area.width, zoom: zoom), "\(name): never the capped overview")
            XCTAssertNil(ScreenPaths.shotPaperOffset(layout: layout, focusPageId: session.focusPageId, pages: nil, offset: nil,
                                                     viewportWidth: area.width, zoom: zoom), "\(name): no opening offset")

            XCTAssertEqual(ScreenPaths.zoomedIn(layout: layout, viewport: nil, area: area, ratio: 1, fit: true), above, name)
            XCTAssertFalse(ScreenPaths.zoomedIn(layout: layout, viewport: nil, area: area, ratio: 1), "\(name): as before")
            XCTAssertFalse(ScreenPaths.zoomedIn(layout: layout, viewport: nil, area: area, ratio: 1, fit: false), name)
            XCTAssertEqual(ScreenPaths.zoomedIn(layout: layout, viewport: first, area: area, ratio: 1), above,
                           "\(name): the same answer once the canvas reported the fit")
            XCTAssertFalse(ScreenPaths.zoomedIn(layout: layout, viewport: PaperViewport(offsetX: 0, zoom: bounds.open, width: area.width),
                                                area: area, ratio: 1, fit: true), "\(name): a report at the opening zoom decides")
        }
    }

    /// 「今日」 before a report (`goToday` passes `fit: currentFit`): on an iPad 11's week kept at 等倍 a day of another page of
    /// the window is revealed (its column from an hour before now, at the fit's zoom) instead of slid to, and today's page
    /// already the focus is revealed instead of left alone, as when zoomed in (1.2.3's rule). Where the fit is the opening
    /// zoom (the 18 Pro Max's portrait week) nothing changes: a slide and `.stay`. A reported viewport decides as before.
    func testTodayCountsAKindAtTheFitAsZoomedIn() async throws {
        let area = CGSize(width: 834, height: 955)
        let fit: CGFloat = 834.0 / 1400
        let session = try await openWindow(.week, focus: nov16, device: iPad, area: area, now: try at(11, 18, 15))
        let decNow = try at(12, 3, 10)
        XCTAssertEqual(paths.today(dec3, now: decNow, viewport: nil, area: area, ratio: 1), .slide(2), "not at 等倍: a slide (1.3)")
        XCTAssertEqual(paths.today(dec3, now: decNow, viewport: nil, area: area, ratio: 1, fit: false), .slide(2))
        guard case .reveal(let column)? = paths.today(dec3, now: decNow, viewport: nil, area: area, ratio: 1, fit: true) else {
            return XCTFail("at 等倍: a reveal, not a slide")
        }
        let slot = try XCTUnwrap(session.layout.slot(ofPage: "w-2026-11-30"))
        let week = try XCTUnwrap(session.layout.pages[slot] as? WeekPageLayout)
        let thursday = week.columnFrame(3).offsetBy(dx: session.layout.origin(ofSlot: slot), dy: 0)
        XCTAssertEqual(column.minX, thursday.minX, accuracy: 1e-9)
        XCTAssertEqual(column.width, thursday.width, accuracy: 1e-9)
        XCTAssertEqual(column.minY, PageNavigation.initialScrollY(week, now: decNow, calendar: SessionTestBed.tokyo) + ZoomPolicy.revealMargin / fit,
                       accuracy: 1e-9, "an hour before now, at the fit's zoom")
        XCTAssertEqual(column.height, area.height / fit, accuracy: 1e-9, "one screen high at the fit")

        let novNow = try at(11, 18, 15)
        XCTAssertEqual(paths.today(nov18, now: novNow, viewport: nil, area: area, ratio: 1), .stay, "today's page at the overview (1.2.3)")
        guard case .reveal(let wednesday)? = paths.today(nov18, now: novNow, viewport: nil, area: area, ratio: 1, fit: true) else {
            return XCTFail("today's page at 等倍: a reveal")
        }
        let focus = try XCTUnwrap(session.layout.pages[session.focusSlot] as? WeekPageLayout)
        XCTAssertEqual(wednesday.minX, focus.columnFrame(2).minX + session.layout.origin(ofSlot: session.focusSlot), accuracy: 1e-9)
        XCTAssertEqual(wednesday.minY, 14 * 80 + ZoomPolicy.revealMargin / fit, accuracy: 1e-9, "14:00, an hour before now")
        let overview = PaperViewport(offsetX: 1_200, zoom: 0.4974, width: 834)
        XCTAssertEqual(paths.today(nov18, now: novNow, viewport: overview, area: area, ratio: 1, fit: true), .stay,
                       "a report at the overview decides")

        let phoneArea = CGSize(width: 440, height: 622)
        _ = try await openWindow(.week, focus: nov16, device: phonePortrait, area: phoneArea, now: novNow)
        XCTAssertEqual(paths.today(dec3, now: decNow, viewport: nil, area: phoneArea, ratio: 1, fit: true), .slide(2), "open = fit: a slide")
        XCTAssertEqual(paths.today(nov18, now: novNow, viewport: nil, area: phoneArea, ratio: 1, fit: true), .stay, "open = fit: nothing")
    }

    // MARK: Screenshot mode

    /// `--screenshot-zoom fit` (§16.3.7): `zoomFit` true and the ratio 1 (`parseZoomRatio` reads the word as nil); the rest of
    /// the config is the same value. A number reads as before (the ratio, `zoomFit` false), and only the word itself is 等倍.
    func testScreenshotZoomFit() throws {
        let plain = try XCTUnwrap(ScreenshotMode.parse(base))
        XCTAssertFalse(plain.zoomFit, "without the argument")
        XCTAssertEqual(plain.zoomRatio, 1)
        var fit = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-zoom", "fit"]))
        XCTAssertTrue(fit.zoomFit)
        XCTAssertEqual(fit.zoomRatio, 1, "the ratio stays 1")
        XCTAssertEqual(fit.page, .week)
        fit.zoomFit = false
        XCTAssertEqual(fit, plain, "nothing else changes")
        XCTAssertTrue(try XCTUnwrap(ScreenshotMode.parse(["--screenshot-zoom", "fit"] + base)).zoomFit, "anywhere in the arguments")
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-zoom", "fit"]), "never active without --screenshot-mode")
        XCTAssertNil(ScreenshotMode.parseZoomRatio(ScreenshotMode.zoomFitValue))
        XCTAssertEqual(ScreenshotMode.zoomFitValue, "fit")

        let two = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-zoom", "2"]))
        XCTAssertFalse(two.zoomFit, "a number is a ratio")
        XCTAssertEqual(two.zoomRatio, 2)
        XCTAssertEqual(try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-zoom", "1.5"])).zoomRatio, 1.5, accuracy: 1e-9)
        for other in ["Fit", "FIT", "fit ", "fitted", "fit2", "", "abc", "0", "inf"] {
            let config = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-zoom", other]), other)
            XCTAssertFalse(config.zoomFit, "zoom \(other)")
            XCTAssertEqual(config.zoomRatio, 1, "zoom \(other)")
        }
        XCTAssertFalse(try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-zoom"])).zoomFit, "no value")
        // With a sheet (the month page) the argument is still read; the month has no 等倍 state (`zoomFit(_:kind:stored:)`).
        let sheet = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-sheet", "settings", "--screenshot-zoom", "fit"]))
        XCTAssertEqual(sheet.page, .month)
        XCTAssertTrue(sheet.zoomFit)
        XCTAssertFalse(ScreenshotMode.zoomFit(sheet, kind: sheet.page, stored: true))
    }

    /// Whether a page opens at 等倍 (the screen's `currentFit` after `ZoomReset.followsFit`): in screenshot mode
    /// `--screenshot-zoom fit` on a week or a day, whatever is stored (the memory is not read there, so a simulator that kept
    /// a value cannot change a photo); in normal use the stored value as it is.
    func testZoomFitReadsTheArgumentInScreenshotModeAndTheStoreOtherwise() throws {
        let plain = try XCTUnwrap(ScreenshotMode.parse(base))
        let fit = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-zoom", "fit"]))
        for kind in PageKind.allCases {
            let follows = kind == .week || kind == .day
            XCTAssertEqual(ZoomReset.followsFit(kind), follows, "\(kind)")
            for stored in [false, true] {
                XCTAssertEqual(ScreenshotMode.zoomFit(nil, kind: kind, stored: stored), stored, "\(kind): normal use, \(stored) stored")
                XCTAssertFalse(ScreenshotMode.zoomFit(plain, kind: kind, stored: stored), "\(kind): screenshot mode without fit")
                XCTAssertEqual(ScreenshotMode.zoomFit(fit, kind: kind, stored: stored), follows, "\(kind): --screenshot-zoom fit")
            }
        }
    }

    // MARK: The screen's wires (read from the source)

    /// `CalendarRootScreen` in code only: `currentFit` is §16.3.4's formula; the two canvases (the one page's and the
    /// window's) get `initialFit: currentFit` and keep `onZoomFitChange`'s answer through `AppSettings.setZoomFit` outside
    /// screenshot mode, both right after `zoomResetTrigger` (InkCanvasView's order); the first frame (`initialViewport`,
    /// `estimatedZoom`, `joinedInitialViewport`), the window's zoom and 「今日」 pass the fit too.
    func testTheScreenWiresTheFitIntoBothCanvases() throws {
        let url = Self.repository.appendingPathComponent("Sources/TegakiCalendar/Views/CalendarRootScreen.swift")
        let code = String(WeekMemoSpanTests.codeOnly(try String(contentsOf: url, encoding: .utf8)))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        func count(_ text: String) -> Int { code.components(separatedBy: text).count - 1 }

        XCTAssertEqual(count("private var currentFit: Bool { ZoomReset.followsFit(kind) && ScreenshotMode.zoomFit(ScreenshotMode.current, "
                             + "kind: kind, stored: AppSettings.zoomFit(for: kind)) }"), 1, "currentFit (§16.3.4)")
        XCTAssertEqual(count("initialFit: currentFit"), 2, "both canvases open at the fit")
        XCTAssertEqual(count("AppSettings.setZoomFit(fit, for: kind)"), 2, "both canvases' answers are kept")
        XCTAssertEqual(count("zoomResetTrigger: zoomResetTrigger, initialFit: currentFit, onZoomFitChange: { fit in "
                             + "guard !ScreenshotMode.isActive else { return } AppSettings.setZoomFit(fit, for: kind) } )"), 2,
                       "the last arguments of both canvases, never written in screenshot mode")
        XCTAssertEqual(count("AppSettings.setZoomFit("), 2, "nothing else writes it")
        XCTAssertTrue(code.contains("private func initialViewport(width: CGFloat) -> PaperViewport { if currentFit { "
                                    + "return PaperViewport.initial(kind, viewportWidth: width) }"), "the one page's first frame")
        XCTAssertTrue(code.contains("private func estimatedZoom(viewportWidth: CGFloat) -> CGFloat { if currentFit { "
                                    + "return ZoomPolicy.fitZoom(kind, viewportWidth: viewportWidth) }"), "the one page's initialScrollX")
        XCTAssertTrue(code.contains("area: CGSize(width: width, height: paperArea.height), ratio: currentRatio, fit: currentFit)"),
                      "the window's first frame")
        XCTAssertTrue(code.contains("let zoom = ScreenPaths.bandZoom(layout: span.layout, area: area, ratio: currentRatio, fit: currentFit)"),
                      "the window's zoom (its start and its offset)")
        XCTAssertTrue(code.contains("area: paperArea, ratio: currentRatio, fit: currentFit) {"), "「今日」")
        XCTAssertEqual(count("ratio: currentRatio, fit: currentFit)"), 3)
        // 1.4's wires of the ratio stay (§5.6).
        XCTAssertEqual(count("onZoomRatioChange: { ratio in guard !ScreenshotMode.isActive else { return } "
                             + "AppSettings.setZoomRatio(ratio, for: kind) }"), 2)
        XCTAssertEqual(count("initialZoomRatio: currentRatio,"), 2)
    }

    private static let repository = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
}
