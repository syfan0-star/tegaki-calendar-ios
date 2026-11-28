import UIKit
import XCTest

/// 1.4.3 (docs/R1_4_3_CONTRACT.md §6.5, §7.2, §11.3, §12.1; D1b, the month): the joined months on an iPhone through UIKit,
/// PencilKit and the real SwiftUI screen (build.yml's ui-tests, the iPhone 17; its steps are the `span-my UI:` lines) —
/// what the unit tests of `ScreenPaths`, `SpanSession` and the canvas cannot touch:
/// - `testTheMonthSlidesOnceAndAMemoLineCrossesItsBoundary`: 「指でも書く」 off, one finger slides the month: the paper stops
///   on November, the title changes once (「2026年10月」 → 「2026年11月」) and stays so while the window shifts; 「前の月」 (‹)
///   brings October back on the same canvas. Then, launched again with 「指でも書く」 on and October's left boundary in the
///   middle (`--screenshot-offset-x -0.5`: ‹ › slide by exactly one page from where the paper is, `SpanPlan.shiftAmount`
///   in `InkCanvasView.slide(byPages:)`, so from a page in the middle they cannot bring a boundary there), one finger
///   writes a line in the notes area across the boundary, 150 lu left of it to 190 lu right of it, 250 lu below the
///   separator line. The window's newest stroke (`span.state`'s `last=`) is that line in its owner's `memo` with its
///   points beyond the page (x < 0 when October holds it, x > 1,400 when September does: D15, the page of its centre, here
///   20 lu right of the boundary), whole. 「前の月」 (‹) then slides one month on the same canvas: the session and the
///   canvas's band id (`span~month~<session>`, the joined canvas is `.id(span.id)`) stay, one shift, the title
///   「2026年9月」, and the line is still the window's newest. ‹, not ›: the boundary stays in the middle, and › would
///   bring October's right edge there, inside October's hysteresis (`SpanPlan.focus`: [X − 6 %, X + W + 6 %)), so the
///   focus and the window would not move (D1b's run 46119423355); ‹ brings September's left edge, a page past it.
/// - `testTheSettingSwitchesTheMonthBetweenOnePageAndTheJoinedMonths`: 設定 › ページ › 「前後のページを横につなげる」 off: the
///   month opens on one page (`path=one`, the canvas holds October itself, fewer strokes than the window); on again: the
///   joined window with the strokes it opened with. The switch is screenshot mode's memory only.
/// - `testTheMonthsZoomResetInPortraitIsFitWhenTurned`: 等倍 of a month (§6.1, §6.4 row 1). In portrait a month opens at
///   its fit (open = fit: one page across the column), so 等倍 moves nothing (the zoom and the offset as they were;
///   `InkCanvasView.resetZoom` returns early there and logs no `zoom: reset`, which this test cannot read: iOS 27's
///   `log show` gives NSLog as "<compose failure>", build.yml) and only takes the fit state; turned to landscape, the
///   canvas follows its new width (§6.2: step 4), so the probe's zoom is the landscape column's width ÷ 1,400 lu (1.5 pt
///   across). The control first, in a launch of its own: turned without 等倍, a month is well short of one page across
///   (it keeps its zoom or takes its landscape opening zoom, about 402 or 306 pt of a 750 pt column on the iPhone 17), so
///   the fit in landscape is the press's. The probe's fields are the frozen canvas's (§11.3: none added).
///
/// D1y (§11.3, §5.2, §5.4, §6.4; the year, open question 11 of the plan: two tests, the setting's switch stays the month's as
/// it reads no kind):
/// - `testTheYearSlidesOnceAndALineCrossesItsBoundary`: the month's steps on the year page (2026, the demo's; its neighbours
///   the demo's handwriting without events): 「指でも書く」 off, one finger slides the year, the title changes once
///   (「2026年」 → 「2027年」), 「前の年」 (‹) brings 2026 back on the same canvas. Then 「指でも書く」 on and 2026's left
///   boundary in the middle, one finger on the 20th's row (no demo handwriting, no demo all-day event; the window's rows are
///   2026's, row 16 grown by 36 lu, so the 20th is 1,176…1,236 lu) from 2025's December, 100 lu left of the boundary, into
///   2026's January, 150 lu right of it (§5.2's 12 月 → 1 月; its centre is 2026's day-number column, which is January's).
///   `span.state`'s `last=` is that line in its owner's `.yearDay` cell of the 20th (`12-20` of y-2025 or `01-20` of y-2026),
///   its x in the cell (the store's coordinates; the cell's left edge in its page is 56 + 112 × (month − 1) lu), so the
///   page's x is past the page: x < 0 when 2026 holds it, x > 1,400 when 2025 does; whole (more than its 150 lu right
///   part). 「次の年」 (›) then slides one year on the same canvas (the session and the band's id stay, one shift, 「2027年」,
///   the line still the window's newest).
/// - `testTheYearsZoomResetInPortraitIsFitWhenTurned`: 等倍 of a year. On the iPhone 17 a year opens at its fit in portrait
///   (open = fit: 402 ÷ 1,400 < 569 ÷ 1,860), so 等倍 moves nothing there; turned, one page is the landscape column across
///   (the cap of 3 years, P-B6 イ, raises the lowest zoom and the opening one, never the fit: §6.4). The control, in a launch
///   of its own: turned without 等倍, the year is the capped overview (its opening zoom there, about 0.179 = 750 ÷ 4,200:
///   at most 3 years across, well short of one).
/// A year that is not joined (the fallback of §14.1's decision) has neither: U takes them out then, as the UI tests cannot
/// read `SpanKinds`.
///
/// The app runs in its screenshot mode (no onboarding, no EventKit, nothing saved; the demo month 2026-10, the focus month
/// m1-2026-10, its neighbours each the demo of its own day of the month) with `--screenshot-span on` and
/// `--screenshot-probe`. The canvas's probe `ink-canvas` (`zoom`, the content offset `ox` / `oy` in band points, the band's
/// `pw` / `ph` and `pk` / `ink` strokes) and the screen's `span.state` (`ScreenPaths.stateLabel`: `path`, `session`,
/// `kind`, `focus`, `origin` — the focus page's left edge in the band, lu — `first`, `pages`, `version`, `shifts`, `stops`,
/// `hold`, `last=<page>:<cell>:minx=…:maxx=…`) read the screen out. A band point (lu) is on screen at
/// frame.minX + x · zoom − ox, frame.minY + y · zoom − oy; a page's x is `origin` further in the band. The notes area
/// starts at the separator line, `ph` − 6,000 (`PaperSpec.growMax`: the notes area of a month whose notes end near its top,
/// as the demo's do; every month of the window has it at the same y in the form ア, and the demo's months have the same
/// rows). XCUITest has no two-finger gesture, so a slide here is one finger with 「指でも書く」 off (the two-finger slide and
/// pinch are the owner's check, §15 rows 11 and 13). An iPhone only; elsewhere these skip.
///
/// The waits read once more after their deadline and count their reads (docs/R1_4_1.md :463, R1_4_2_CONTRACT §1.5: a
/// condition met just at the deadline, or on a runner whose reads are slow, is not a failure).
@MainActor
final class SpanMonthYearUITests: XCTestCase {
    private static let september = "m1-2026-09"
    private static let october = "m1-2026-10"
    private static let november = "m1-2026-11"
    /// The month page's width (lu, `ZoomPolicy.paperWidth(.month)`): one page of the band.
    private static let monthWidth: CGFloat = 1400
    /// D1y: the year page's width (lu, `ZoomPolicy.paperWidth(.year)`, `PaperSpec.yearWidth`): one page of the band.
    private static let yearWidth: CGFloat = 1400
    /// D1y: the demo year's rows (lu, `YearLayoutEngine.rowHeight`): 60 each but row 16, 36 more for 10/16's four all-day
    /// events — the window's rows too, as its other years have no events (`yearFloors`), and so its height.
    private static let yearRowHeight: CGFloat = 60
    private static let yearRowGrowth: CGFloat = 36
    private static let yearPaperHeight: CGFloat = 1896
    /// D1y: the row of the line across the years' boundary, and its ends from the boundary (lu): from 2025's December into
    /// 2026's January (its centre +25, 2026's day-number column, January's cell). More than its right part (150 lu) is the
    /// whole line.
    private static let yearLineDay = 20
    private static let yearLineFrom: CGFloat = -100
    private static let yearLineTo: CGFloat = 150
    private static let yearLineWhole: CGFloat = 160
    /// The notes area of the demo's months (lu, `PaperSpec.growMax`): the paper ends this far below the separator line.
    private static let notesHeight: CGFloat = 6000
    /// Where the separator line may be (lu): six rows of at least the 175 lu of an empty row, at most a few grown ones.
    private static let separatorRange: ClosedRange<CGFloat> = 1000...1800
    /// `SpanPlan.focusHysteresis`: the focus moves 6 % of a page past the focus page's edge.
    private static let focusHysteresis: CGFloat = 0.06
    /// How far (pt) one page across may be from the column's width at 等倍.
    private static let fitTolerance: CGFloat = 1.5
    private static let previousMonth = "前の月"
    private static let nextMonth = "次の月"
    private static let previousYear = "前の年"
    private static let nextYear = "次の年"
    private static let resetIdentifier = "header.zoomReset"
    /// A gesture whose synthesis took longer than this (s) beyond its own length met an overloaded simulator
    /// (YearTapUITests): it is tried once more.
    private let slowGesture: TimeInterval = 2.5

    // MARK: - Tests

    func testTheMonthSlidesOnceAndAMemoLineCrossesItsBoundary() throws {
        try skipUnlessPhone()
        continueAfterFailure = false
        guard slideAndComeBack(.month) else { return }
        lineAcrossTheBoundaryThenNext()
    }

    func testTheSettingSwitchesTheMonthBetweenOnePageAndTheJoinedMonths() throws {
        try skipUnlessPhone()
        continueAfterFailure = false
        let name = "setting"
        let app = launch([], fingerDraws: true, name, .month)
        defer { app.terminate() }
        guard let joined = waitForJoined(app, name, .month) else { return }
        XCTAssertEqual(joined.state["kind"], "month", "\(name): the month (\(joined.stateRaw))")
        XCTAssertGreaterThan(joined.pages, 1, "\(name): a window of months (\(joined.stateRaw))")

        guard switchPageSpan(in: app, to: false, name) else { return }
        guard let one = waitFor(app, timeout: 20, "\(name): one page", until: { $0.state["path"] == "one" }) else {
            return XCTFail("\(name): the setting off did not open one page (span.state \(stateLabel(app)))")
        }
        keepScreenshot(app, "\(name) — off")
        log("\(name): off: span.state \(one.stateRaw); probe \(one.probe.raw)")
        continueAfterFailure = true
        XCTAssertEqual(one.pages, 1, "\(name): one page")
        XCTAssertEqual(one.state["focus"], Self.october, "\(name): the same month")
        XCTAssertEqual(one.probe.page, Self.october, "\(name): the canvas holds the real page")
        XCTAssertLessThan(one.probe.ink, joined.probe.ink, "\(name): one page holds fewer strokes than the window (\(one.probe.ink) < \(joined.probe.ink))")
        continueAfterFailure = false

        guard switchPageSpan(in: app, to: true, name) else { return }
        guard let again = waitFor(app, timeout: 20, "\(name): joined again", until: {
            $0.state["path"] == "span" && $0.state["focus"] == Self.october && $0.pages > 1
        }) else {
            return XCTFail("\(name): the setting on did not join the months again (span.state \(stateLabel(app)))")
        }
        keepScreenshot(app, "\(name) — on again")
        log("\(name): on again: span.state \(again.stateRaw); probe \(again.probe.raw)")
        continueAfterFailure = true
        XCTAssertEqual(again.state["kind"], "month", "\(name): the month joined")
        XCTAssertEqual(again.pages, joined.pages, "\(name): the same window")
        XCTAssertEqual(again.probe.ink, joined.probe.ink, "\(name): the window's strokes as at the opening (\(again.probe.ink) == \(joined.probe.ink))")
        XCTAssertGreaterThan(again.probe.ink, one.probe.ink, "\(name): the neighbours are back")
    }

    func testTheMonthsZoomResetInPortraitIsFitWhenTurned() throws {
        try skipUnlessPhone()
        continueAfterFailure = true
        defer { XCUIDevice.shared.orientation = .portrait }
        turnWithoutZoomReset(.month)
        turnAfterZoomReset(.month)
    }

    // MARK: - Tests of the year (D1y)

    func testTheYearSlidesOnceAndALineCrossesItsBoundary() throws {
        try skipUnlessPhone()
        continueAfterFailure = false
        guard slideAndComeBack(.year) else { return }
        yearLineAcrossTheBoundaryThenNext()
    }

    func testTheYearsZoomResetInPortraitIsFitWhenTurned() throws {
        try skipUnlessPhone()
        continueAfterFailure = true
        defer { XCUIDevice.shared.orientation = .portrait }
        turnWithoutZoomReset(.year)
        turnAfterZoomReset(.year)
    }

    // MARK: - The slide, the line and the arrows

    /// 「指でも書く」 off: 85 % of a page's width (at most 80 % of the canvas) across the middle, slowly and held at the end
    /// (no coasting), as SpanUITests.testSlideChangesTheTitleOnce does on the week. The paper stops on November (`stops` + 1),
    /// the title changes once and stays so while the window shifts (`shifts` + 1; read every 0.15 s from the lift until the
    /// window settled and 1 s longer). A synthesized drag that moved the paper less than the focus needs (review
    /// C2-SHOTS-2: its first 56.5 pt once did not move the paper) is made once more from there. Then 「前の月」: October on
    /// the same canvas. False when a step that the next one needs did not happen. D1y: the same steps on the year (`kind`),
    /// 2026 → 2027 and 「前の年」 back to 2026.
    private func slideAndComeBack(_ kind: JoinedKind) -> Bool {
        let name = "\(kind.logPrefix)slide"
        let app = launch([], fingerDraws: false, name, kind)
        defer { app.terminate() }
        guard let start = waitForJoined(app, name, kind) else { return false }
        XCTAssertEqual(start.state["kind"], kind.name, "\(name): the \(kind.name) (\(start.stateRaw))")
        XCTAssertEqual(start.state["focus"], kind.focus, "\(name): the focus \(kind.name)")
        let title = titleElement(in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 5), "\(name): the page title")
        let before = title.label
        log("\(name): the title is 「\(before)」")
        XCTAssertTrue(kind.shows(before, kind.focusTitle), "\(name): \(kind.focusWord)'s title (「\(before)」)")

        let frame = start.probe.frame
        let page = kind.width * start.probe.zoom
        let distance = min(page * 0.85, frame.width * 0.8)
        guard distance > page * 0.62 else {
            XCTFail("\(name): a page (\(page) pt) is too wide for one drag in the canvas \(frame)")
            return false
        }
        // How far the paper must move for the focus to change (pt): to 6 % of a page past the focus page's right edge.
        let needed = (kind.width * (1 + Self.focusHysteresis) - start.middleInFocus) * start.probe.zoom
        let from = CGPoint(x: frame.midX + distance / 2, y: frame.midY)
        let to = CGPoint(x: frame.midX - distance / 2, y: frame.midY)

        var titles = [before]
        var settled: MonthSnapshot?
        var base = start
        for attempt in 1...2 {
            waitUntilResponsive(canvasElement(in: app))
            let took = drag(in: app, from: from, to: to, velocity: 400, hold: 0.3)
            log("\(name): moved the paper \(from) → \(to) (attempt \(attempt), \(seconds(took)); \(Int(distance)) pt, the focus needs \(Int(needed)))")
            var stayed: MonthSnapshot?
            var previous: MonthSnapshot?
            var settledAt: Date?
            let deadline = Date().addingTimeInterval(20)
            var pastDeadline = false
            while true {
                let shown = title.exists ? title.label : ""
                if !shown.isEmpty, shown != titles.last { titles.append(shown) }
                if let now = snapshot(app) {
                    let alike = previous.map { now.isAlike($0) } ?? false
                    if now.state["focus"] == kind.next, now.shifts > base.shifts, alike {
                        settled = now
                        if settledAt == nil { settledAt = Date() }
                    } else if now.state["focus"] == kind.focus, now.stops > base.stops, alike {
                        // Stopped on the same page: the paper moved less than the focus needs, or the focus did not follow.
                        stayed = now
                        if settledAt == nil { settledAt = Date() }
                    } else {
                        settledAt = nil
                    }
                    previous = now
                }
                if let settledAt, Date().timeIntervalSince(settledAt) >= 1 { break }
                if pastDeadline { break }
                // One read more after the deadline.
                if Date() >= deadline { pastDeadline = true }
                Thread.sleep(forTimeInterval: 0.15)
            }
            if settled != nil { break }
            guard let stayed else { break }
            let moved = stayed.paperMoved(since: base)
            log("\(name): the paper stopped on the same \(kind.name), moved \(Int(moved)) pt of the drag's \(Int(distance)) (the focus needs \(Int(needed)) from the start); span.state \(stayed.stateRaw)")
            guard stayed.paperMoved(since: start) < needed, attempt == 1 else { break }
            log("\(name): the synthesized drag fell \(Int(needed - stayed.paperMoved(since: start))) pt short of the focus's \(Int(needed)) pt; dragging once more from there")
            keepScreenshot(app, "\(name) — short drag")
            base = stayed
        }
        keepScreenshot(app, "\(name) — after")
        log("\(name): the titles \(titles); span.state \(settled?.stateRaw ?? stateLabel(app))")
        guard let settled else {
            let now = snapshot(app)
            let moved = now.map { "; the paper moved \(Int($0.paperMoved(since: start))) pt, the focus needs \(Int(needed))" } ?? ""
            XCTFail("\(name): the paper did not stop on \(kind.nextWord) with the window shifted (span.state \(stateLabel(app)); titles \(titles)\(moved))")
            return false
        }
        attach(settled.stateRaw, "\(name) — span.state")
        // The four checks below are independent: each one reports.
        continueAfterFailure = true
        XCTAssertEqual(titles.count, 2, "\(name): the title changed once (\(titles))")
        XCTAssertTrue(kind.shows(titles.last ?? "", kind.nextTitle), "\(name): to \(kind.nextWord) (\(titles))")
        XCTAssertEqual(settled.stops, base.stops + 1, "\(name): one stop after the drag that moved the focus (\(base.stops) → \(settled.stops))")
        XCTAssertEqual(settled.state["session"], start.state["session"], "\(name): the same window")
        continueAfterFailure = false

        let back = app.buttons[kind.previousButton]
        guard back.waitForExistence(timeout: 5) else {
            XCTFail("\(name): no 「\(kind.previousButton)」")
            return false
        }
        waitUntilResponsive(back)
        back.tap()
        log("\(name): tapped 「\(kind.previousButton)」")
        guard let again = waitFor(app, timeout: 20, "\(name): \(kind.focusWord) again with the window shifted", until: {
            $0.state["focus"] == kind.focus && $0.shifts > settled.shifts
        }) else {
            XCTFail("\(name): 「\(kind.previousButton)」 did not bring \(kind.focusWord) back with the window shifted (span.state \(stateLabel(app)))")
            return false
        }
        let shown = titleElement(in: app).label
        log("\(name): back: the title is 「\(shown)」; span.state \(again.stateRaw)")
        continueAfterFailure = true
        XCTAssertEqual(again.state["path"], "span", "\(name): still the joined path")
        XCTAssertEqual(again.state["session"], start.state["session"], "\(name): the same canvas after ‹ (the session did not change)")
        XCTAssertEqual(again.probe.page, start.probe.page, "\(name): the canvas's band is the same after ‹ (its id \(start.probe.page))")
        XCTAssertTrue(kind.shows(shown, kind.focusTitle), "\(name): \(kind.focusWord)'s title after ‹ (「\(shown)」)")
        continueAfterFailure = false
        return true
    }

    /// 「指でも書く」 on, October's left boundary in the middle: one finger from x −150 to +190 lu of October at 250 lu below
    /// the separator line, the newest stroke read from `span.state`, then 「前の月」 on the same canvas (the type's comment
    /// says why not 「次の月」).
    private func lineAcrossTheBoundaryThenNext() {
        let name = "memo line"
        let app = launch(["--screenshot-offset-x", "-0.5"], fingerDraws: true, name, .month)
        defer { app.terminate() }
        guard let start = waitForJoined(app, name, .month) else { return }
        XCTAssertEqual(start.state["focus"], Self.october, "\(name): the focus month")
        let separator = start.probe.paperHeight - Self.notesHeight
        guard Self.separatorRange.contains(separator) else {
            return XCTFail("\(name): the separator line at \(separator) lu (the paper \(start.probe.paperHeight) − \(Self.notesHeight)) is not a month's (probe \(start.probe.raw))")
        }
        let y = separator + 250
        let from = start.probe.screen(CGPoint(x: start.origin - 150, y: y))
        let to = start.probe.screen(CGPoint(x: start.origin + 190, y: y))
        let boundary = start.probe.screen(CGPoint(x: start.origin, y: y))
        log("\(name): the separator line at \(separator) lu; the boundary at \(boundary) (the canvas's middle \(start.probe.frame.midX)); the line \(from) → \(to)")
        let inside = start.probe.frame.insetBy(dx: 4, dy: 4)
        guard inside.contains(from), inside.contains(to) else {
            return XCTFail("\(name): the line \(from) → \(to) is outside the canvas \(start.probe.frame) (probe \(start.probe.raw))")
        }

        let length = hypot(to.x - from.x, to.y - from.y)
        var drawn: MonthSnapshot?
        for attempt in 1...2 {
            waitUntilResponsive(canvasElement(in: app))
            let took = drag(in: app, from: from, to: to, velocity: 250)
            drawn = waitFor(app, timeout: 6, "\(name): the line") {
                $0.probe.pk == start.probe.pk + 1 && $0.probe.ink == start.probe.ink + 1 && $0.state["last"] != start.state["last"]
            }
            log("\(name): drew (attempt \(attempt), \(seconds(took))): \(drawn != nil ? "1 stroke more" : "NOT drawn")")
            if drawn != nil || took <= length / 250 + 0.2 + slowGesture { break }
            log("\(name): RETRY the line (the simulator was overloaded)")
        }
        keepScreenshot(app, "\(name) — after")
        guard let drawn else {
            return XCTFail("\(name): a finger stroke with the pen did not add a line (probe \(probe(app)?.raw ?? "-"); span.state \(stateLabel(app)))")
        }
        attach(drawn.stateRaw, "\(name) — span.state")
        guard let last = MonthNewest(drawn.state["last"] ?? "-") else {
            return XCTFail("\(name): span.state has no newest stroke (\(drawn.stateRaw))")
        }
        log("\(name): the newest stroke is in \(last.pageId) \(last.cell), x \(last.minX) … \(last.maxX) of its page")
        continueAfterFailure = true
        XCTAssertTrue([Self.october, Self.september].contains(last.pageId), "\(name): one of the two months holds the line (\(last.pageId))")
        XCTAssertEqual(last.cell, "memo", "\(name): in the notes area (\(drawn.state["last"] ?? "-"))")
        if last.pageId == Self.september {
            XCTAssertGreaterThan(last.maxX, Self.monthWidth, "\(name): September keeps the points right of its page (\(last.minX) … \(last.maxX))")
        } else {
            XCTAssertLessThan(last.minX, 0, "\(name): October keeps the points left of its page (\(last.minX) … \(last.maxX))")
        }
        XCTAssertGreaterThan(last.maxX - last.minX, 250, "\(name): the whole line, not a part of it (\(last.minX) … \(last.maxX))")
        continueAfterFailure = false

        let back = app.buttons[Self.previousMonth]
        guard back.waitForExistence(timeout: 5) else { return XCTFail("\(name): no 「\(Self.previousMonth)」") }
        waitUntilResponsive(back)
        back.tap()
        log("\(name): tapped 「\(Self.previousMonth)」")
        guard let after = waitFor(app, timeout: 20, "\(name): September with the window shifted", until: {
            $0.state["focus"] == Self.september && $0.shifts > drawn.shifts
        }) else {
            return XCTFail("\(name): the window did not move to September and shift (span.state \(stateLabel(app)))")
        }
        keepScreenshot(app, "\(name) — previous month")
        attach(after.stateRaw, "\(name) — span.state after ‹")
        let shown = titleElement(in: app).label
        log("\(name): after ‹: the title is 「\(shown)」; span.state \(after.stateRaw)")
        continueAfterFailure = true
        XCTAssertEqual(after.state["path"], "span", "\(name): still the joined path")
        XCTAssertEqual(after.state["session"], drawn.state["session"], "\(name): the same canvas (the session did not change)")
        XCTAssertEqual(after.probe.page, drawn.probe.page, "\(name): the canvas's band is the same (its id \(drawn.probe.page))")
        XCTAssertEqual(after.shifts, drawn.shifts + 1, "\(name): one shift after the stop")
        XCTAssertEqual(after.state["last"], drawn.state["last"], "\(name): the line is still the window's newest, kept by its page")
        XCTAssertTrue(Self.isMonth(2026, 9, shown), "\(name): September's title (「\(shown)」)")
    }

    /// D1y: 「指でも書く」 on, 2026's left boundary in the middle: one finger on the 20th's row from 100 lu left of the boundary
    /// (2025's December) to 150 lu right of it (2026's January), the newest stroke read from `span.state`, then 「次の年」 on
    /// the same canvas.
    private func yearLineAcrossTheBoundaryThenNext() {
        let kind = JoinedKind.year
        let name = "year line"
        let app = launch(["--screenshot-offset-x", "-0.5"], fingerDraws: true, name, kind)
        defer { app.terminate() }
        guard let opened = waitForJoined(app, name, kind) else { return }
        XCTAssertEqual(opened.state["focus"], kind.focus, "\(name): the focus year")
        // The rows the line's y comes from: the demo year's, the window's once 2026's events are read.
        guard let start = waitFor(app, timeout: 20, "\(name): the demo year's rows", until: {
            abs($0.probe.paperHeight - Self.yearPaperHeight) < 0.5 && $0.state["focus"] == kind.focus
        }) else {
            return XCTFail("\(name): the window of years is not \(Self.yearPaperHeight) lu tall (the demo's rows: 60 lu, row 16 "
                           + "\(Self.yearRowHeight + Self.yearRowGrowth)) (probe \(probe(app)?.raw ?? "-"); span.state \(stateLabel(app)))")
        }
        let row = Self.yearRowTop(day: Self.yearLineDay)
        let y = row + Self.yearRowHeight / 2
        let from = start.probe.screen(CGPoint(x: start.origin + Self.yearLineFrom, y: y))
        let to = start.probe.screen(CGPoint(x: start.origin + Self.yearLineTo, y: y))
        let boundary = start.probe.screen(CGPoint(x: start.origin, y: y))
        log("\(name): the \(Self.yearLineDay)th's row at \(row)…\(row + Self.yearRowHeight) lu; the boundary at \(boundary) (the canvas's middle "
            + "\(start.probe.frame.midX)); the line \(from) → \(to)")
        let inside = start.probe.frame.insetBy(dx: 4, dy: 4)
        guard inside.contains(from), inside.contains(to) else {
            return XCTFail("\(name): the line \(from) → \(to) is outside the canvas \(start.probe.frame) (probe \(start.probe.raw))")
        }

        let length = hypot(to.x - from.x, to.y - from.y)
        var drawn: MonthSnapshot?
        for attempt in 1...2 {
            waitUntilResponsive(canvasElement(in: app))
            let took = drag(in: app, from: from, to: to, velocity: 250)
            drawn = waitFor(app, timeout: 6, "\(name): the line") {
                $0.probe.pk == start.probe.pk + 1 && $0.probe.ink == start.probe.ink + 1 && $0.state["last"] != start.state["last"]
            }
            log("\(name): drew (attempt \(attempt), \(seconds(took))): \(drawn != nil ? "1 stroke more" : "NOT drawn")")
            if drawn != nil || took <= length / 250 + 0.2 + slowGesture { break }
            log("\(name): RETRY the line (the simulator was overloaded)")
        }
        keepScreenshot(app, "\(name) — after")
        guard let drawn else {
            return XCTFail("\(name): a finger stroke with the pen did not add a line (probe \(probe(app)?.raw ?? "-"); span.state \(stateLabel(app)))")
        }
        attach(drawn.stateRaw, "\(name) — span.state")
        guard let last = MonthNewest(drawn.state["last"] ?? "-") else {
            return XCTFail("\(name): span.state has no newest stroke (\(drawn.stateRaw))")
        }
        // `last=`'s x is the cell's (the store's coordinates): the page's x is the cell's left edge more.
        let december = Self.yearCellX(month: 12)
        let january = Self.yearCellX(month: 1)
        let cellX = last.pageId == kind.previous ? december : january
        log("\(name): the newest stroke is in \(last.pageId) \(last.cell), x \(last.minX) … \(last.maxX) of its cell, "
            + "\(cellX + last.minX) … \(cellX + last.maxX) of its page")
        continueAfterFailure = true
        XCTAssertTrue([kind.previous, kind.focus].contains(last.pageId), "\(name): one of the two years holds the line (\(last.pageId))")
        if last.pageId == kind.previous {
            XCTAssertEqual(last.cell, Self.yearCell(month: 12), "\(name): 2025's December the \(Self.yearLineDay)th (\(drawn.state["last"] ?? "-"))")
            XCTAssertGreaterThan(december + last.maxX, Self.yearWidth,
                                 "\(name): 2025 keeps the points right of its page (x \(december + last.minX) … \(december + last.maxX) of the page)")
        } else {
            XCTAssertEqual(last.cell, Self.yearCell(month: 1),
                           "\(name): 2026's January the \(Self.yearLineDay)th, the day-number column's (\(drawn.state["last"] ?? "-"))")
            XCTAssertLessThan(january + last.minX, 0,
                              "\(name): 2026 keeps the points left of its page (x \(january + last.minX) … \(january + last.maxX) of the page)")
        }
        XCTAssertGreaterThan(last.maxX - last.minX, Self.yearLineWhole,
                             "\(name): the whole line, not the part on one side of the boundary (\(last.minX) … \(last.maxX))")
        continueAfterFailure = false

        let next = app.buttons[kind.nextButton]
        guard next.waitForExistence(timeout: 5) else { return XCTFail("\(name): no 「\(kind.nextButton)」") }
        waitUntilResponsive(next)
        next.tap()
        log("\(name): tapped 「\(kind.nextButton)」")
        guard let after = waitFor(app, timeout: 20, "\(name): 2027 with the window shifted", until: {
            $0.state["focus"] == kind.next && $0.shifts > drawn.shifts
        }) else {
            return XCTFail("\(name): the window did not move to 2027 and shift (span.state \(stateLabel(app)))")
        }
        keepScreenshot(app, "\(name) — next year")
        attach(after.stateRaw, "\(name) — span.state after ›")
        let shown = titleElement(in: app).label
        log("\(name): after ›: the title is 「\(shown)」; span.state \(after.stateRaw)")
        continueAfterFailure = true
        XCTAssertEqual(after.state["path"], "span", "\(name): still the joined path")
        XCTAssertEqual(after.state["session"], drawn.state["session"], "\(name): the same canvas (the session did not change)")
        XCTAssertEqual(after.probe.page, drawn.probe.page, "\(name): the canvas's band is the same (its id \(drawn.probe.page))")
        XCTAssertEqual(after.shifts, drawn.shifts + 1, "\(name): one shift after the stop")
        XCTAssertEqual(after.state["last"], drawn.state["last"], "\(name): the line is still the window's newest, kept by its page")
        XCTAssertTrue(kind.shows(shown, kind.nextTitle), "\(name): 2027's title (「\(shown)」)")
    }

    /// D1y: the top of the demo year's row of `day` (lu): 60 lu rows, row 16 grown (`yearRowGrowth`).
    private static func yearRowTop(day: Int) -> CGFloat {
        CGFloat(day - 1) * yearRowHeight + (day > 16 ? yearRowGrowth : 0)
    }

    /// D1y: the left edge of `month`'s column in its year page (lu, `PaperSpec`): the 56 lu day-number column, then 112 lu a month.
    private static func yearCellX(month: Int) -> CGFloat {
        56 + CGFloat(month - 1) * 112
    }

    /// D1y: the year cell of `month` on the line's row as `span.state` names it (`CellKey.yearDay(month:day:).raw`: "MM-DD").
    private static func yearCell(month: Int) -> String {
        String(format: "%02d-%02d", month, yearLineDay)
    }

    // MARK: - 等倍 and the turn

    /// The control: portrait, then landscape without 等倍. The month is not one page across the landscape column. D1y: nor
    /// the year, which is the capped overview there (at most `capPages` years across).
    private func turnWithoutZoomReset(_ kind: JoinedKind) {
        let name = "\(kind.logPrefix)turned without 等倍"
        let app = launch([], fingerDraws: false, name, kind)
        defer {
            app.terminate()
            XCUIDevice.shared.orientation = .portrait
        }
        guard let portrait = waitForJoined(app, name, kind) else { return }
        XCUIDevice.shared.orientation = .landscapeLeft
        log("\(name): turned to landscape")
        guard let turned = waitFor(app, timeout: 30, "\(name): landscape", until: { $0.probe.isLandscape }) else {
            return XCTFail("\(name): the canvas never settled in landscape (probe \(probe(app)?.raw ?? "-"))")
        }
        let across = kind.width * turned.probe.zoom
        keepScreenshot(app, "\(name) — landscape")
        log("\(name): portrait zoom \(portrait.probe.zoom) column \(portrait.probe.frame.width); landscape zoom \(turned.probe.zoom) "
            + "column \(turned.probe.frame.width), one page \(across) pt; span.state \(turned.stateRaw)")
        XCTAssertLessThan(across, turned.probe.frame.width - 100,
                          "\(name): without 等倍 a \(kind.name) is not one page across the landscape column (\(across) of \(turned.probe.frame.width) pt)")
        if let cap = kind.capPages {
            // The cap is the lowest zoom (`ZoomPolicy.cappedBounds`): one page at least the column ÷ the cap across.
            let least = turned.probe.frame.width / cap
            log("\(name): the cap of \(Int(cap)) \(kind.plural): one page at least \(least) pt across; \(abs(across - least) <= Self.fitTolerance ? "at the cap" : "above the cap")")
            XCTAssertGreaterThanOrEqual(across, least - Self.fitTolerance,
                                        "\(name): at most \(Int(cap)) \(kind.plural) across the landscape column (one page \(across) pt, the cap's \(least))")
        }
        XCTAssertEqual(turned.state["focus"], kind.focus, "\(name): the focus stays")
    }

    /// Portrait at open = fit: 等倍 moves nothing; then landscape: one page across the column. D1y: the year too (the cap
    /// never changes the fit, §6.4).
    private func turnAfterZoomReset(_ kind: JoinedKind) {
        let name = "\(kind.logPrefix)等倍 then turned"
        let app = launch([], fingerDraws: false, name, kind)
        defer {
            app.terminate()
            XCUIDevice.shared.orientation = .portrait
        }
        guard let portrait = waitForJoined(app, name, kind) else { return }
        let open = portrait.probe.zoom
        let fit = portrait.probe.frame.width / kind.width
        log("\(name): portrait zoom \(open), fit \(fit) (the column \(portrait.probe.frame.width) ÷ 1,400)")
        XCTAssertEqual(open, fit, accuracy: 0.0005, "\(name): in portrait a \(kind.name) opens at its fit (open = fit, §6.4 row 1)")
        let reset = app.buttons[Self.resetIdentifier]
        guard reset.waitForExistence(timeout: 5) else {
            return XCTFail("\(name): no \(Self.resetIdentifier). Elements:\n\(app.debugDescription)")
        }
        waitUntilResponsive(reset)
        log("\(name): 等倍 \(reset.label) \(reset.frame)")
        reset.tap()
        // Nothing moves: two reads alike at least 1 s after the tap (no condition but the settling).
        Thread.sleep(forTimeInterval: 1)
        guard let pressed = waitFor(app, timeout: 8, "\(name): after 等倍 in portrait", until: { _ in true }) else {
            return XCTFail("\(name): the canvas never settled after 等倍 (probe \(probe(app)?.raw ?? "-"))")
        }
        log("\(name): after 等倍 zoom \(pressed.probe.zoom) offset \(pressed.probe.offset) (before \(portrait.probe.offset))")
        XCTAssertEqual(pressed.probe.zoom, open, accuracy: 0.0001, "\(name): 等倍 at open = fit leaves the zoom")
        XCTAssertEqual(pressed.probe.offset.x, portrait.probe.offset.x, accuracy: 0.5, "\(name): 等倍 at open = fit leaves x")
        XCTAssertEqual(pressed.probe.offset.y, portrait.probe.offset.y, accuracy: 0.5, "\(name): 等倍 at open = fit leaves y")
        XCTAssertEqual(pressed.state["session"], portrait.state["session"], "\(name): the same window")

        XCUIDevice.shared.orientation = .landscapeLeft
        log("\(name): turned to landscape")
        let atFit = waitFor(app, timeout: 30, "\(name): landscape at fit", until: {
            $0.probe.isLandscape && abs(kind.width * $0.probe.zoom - $0.probe.frame.width) <= Self.fitTolerance
        })
        let turned = atFit ?? waitFor(app, timeout: 10, "\(name): landscape", until: { $0.probe.isLandscape })
        keepScreenshot(app, "\(name) — landscape")
        guard let turned else {
            return XCTFail("\(name): the canvas never settled in landscape (probe \(probe(app)?.raw ?? "-"))")
        }
        let across = kind.width * turned.probe.zoom
        log("\(name): landscape zoom \(turned.probe.zoom), one page \(across) pt across the column \(turned.probe.frame.width) "
            + "(fit \(turned.probe.frame.width / kind.width)); span.state \(turned.stateRaw)")
        XCTAssertEqual(across, turned.probe.frame.width, accuracy: Self.fitTolerance,
                       "\(name): 等倍 pressed in portrait is one page across the landscape column (zoom = the column ÷ 1,400)")
        XCTAssertEqual(turned.state["focus"], kind.focus, "\(name): the focus stays")
        XCTAssertEqual(turned.state["session"], portrait.state["session"], "\(name): the same window, decided anew (§3.6)")
    }

    // MARK: - Launching and reading

    private func skipUnlessPhone() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "the joined month's and year's UI tests are for an iPhone")
    }

    /// The month page of 2026-10 joined (D1y: or the year page of 2026, `kind`), in Japanese, 「指でも書く」 as asked and
    /// already chosen (YearTapUITests), in portrait (a test turns the device afterwards).
    private func launch(_ extra: [String], fingerDraws: Bool, _ name: String, _ kind: JoinedKind) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", kind.name,
            "--screenshot-span", "on", "--screenshot-probe",
            "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
            "-allowFingerDrawing", fingerDraws ? "YES" : "NO", "-allowFingerDrawingChosen", "YES",
        ] + extra
        app.launch()
        log("\(name): launched (finger \(fingerDraws ? "draws" : "moves the paper")) \(extra.joined(separator: " "))")
        return app
    }

    private func canvasElement(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "ink-canvas").firstMatch
    }

    private func stateElement(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "span.state").firstMatch
    }

    private func titleElement(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "page.title").firstMatch
    }

    private func probe(_ app: XCUIApplication) -> MonthProbe? {
        let canvas = canvasElement(in: app)
        guard canvas.exists, let raw = canvas.value as? String else { return nil }
        return MonthProbe(raw: raw, frame: canvas.frame)
    }

    private func stateLabel(_ app: XCUIApplication) -> String {
        let state = stateElement(in: app)
        return state.exists ? state.label : "-"
    }

    /// `span.state` and the probe now; nil while either is missing or the canvas has no zoom yet.
    private func snapshot(_ app: XCUIApplication) -> MonthSnapshot? {
        let label = stateLabel(app)
        guard label != "-", let probe = probe(app), probe.isReady else { return nil }
        return MonthSnapshot(stateRaw: label, probe: probe)
    }

    /// Polls every 0.3 s until `until` holds on two reads in a row that agree (`isAlike`: the window settled, its
    /// neighbours read). The deadline is `timeout` s; it reads once more after it, and the reads are counted: at least
    /// `reads` in all, so a runner slow to answer the queries gets as many as a quick one. nil (logged) otherwise.
    private func waitFor(_ app: XCUIApplication, timeout: TimeInterval, reads: Int = 6, _ what: String,
                         until: (MonthSnapshot) -> Bool) -> MonthSnapshot? {
        let deadline = Date().addingTimeInterval(timeout)
        var previous: MonthSnapshot?
        var last: MonthSnapshot?
        var count = 0
        var pastDeadline = false
        while true {
            let now = snapshot(app)
            count += 1
            if let now {
                last = now
                if until(now), let previous, until(previous), now.isAlike(previous) { return now }
            }
            previous = now
            if pastDeadline, count >= reads { break }
            if Date() >= deadline { pastDeadline = true }
            Thread.sleep(forTimeInterval: 0.3)
        }
        log("\(what): not within \(seconds(timeout)) and \(count) reads; span.state \(last?.stateRaw ?? "-"); probe \(last?.probe.raw ?? "-")")
        return nil
    }

    /// The canvas and the joined window, settled (`path=span`, more than one page, two reads alike), after a simulator
    /// that answers quickly. Fails (with the element tree) and gives nil otherwise.
    private func waitForJoined(_ app: XCUIApplication, _ name: String, _ kind: JoinedKind) -> MonthSnapshot? {
        let canvas = canvasElement(in: app)
        guard canvas.waitForExistence(timeout: 30) || canvas.exists else {
            log("\(name): no 「ink-canvas」 element. Elements:\n\(app.debugDescription)")
            XCTFail("\(name): the canvas probe (--screenshot-probe) is missing")
            return nil
        }
        log("\(name): waited \(waitUntilResponsive(canvas)) s for the app to answer quickly")
        guard let start = waitFor(app, timeout: 30, "\(name): the joined \(kind.plural)", until: { snapshot in
            snapshot.state["path"] == "span" && snapshot.pages > 1
        }) else {
            log("\(name): Elements:\n\(app.debugDescription)")
            XCTFail("\(name): the screen did not settle on the joined path (span.state \(stateLabel(app)))")
            return nil
        }
        log("\(name): window=\(app.windows.firstMatch.frame) canvas=\(start.probe.frame) span.state \(start.stateRaw); probe \(start.probe.raw)")
        keepScreenshot(app, "\(name) — start")
        return start
    }

    /// 設定 → 「前後のページを横につなげる」 to `on` (the form is moved up until the switch is well inside the window) →
    /// 完了 (SpanUITests' steps). False (failed) when a step did not happen.
    private func switchPageSpan(in app: XCUIApplication, to on: Bool, _ name: String) -> Bool {
        let settings = app.buttons["設定"]
        guard settings.waitForExistence(timeout: 5) else {
            XCTFail("\(name): the header's 「設定」")
            return false
        }
        waitUntilResponsive(settings)
        settings.tap()
        let done = app.buttons["完了"]
        guard done.waitForExistence(timeout: 10) || done.exists else {
            XCTFail("\(name): the settings sheet did not open")
            return false
        }
        let toggle = app.descendants(matching: .any).matching(identifier: "settings.pageSpan").firstMatch
        let window = app.windows.firstMatch.frame
        for attempt in 1...10 {
            let above = toggle.exists && toggle.frame.minY <= window.minY + 120
            if toggle.exists, toggle.isHittable, !above, toggle.frame.maxY < window.maxY - 80 { break }
            // Up by 35 % of the window while the switch is below (less than the band it is looked for in, so it is not
            // passed over), down by 20 % when it went under the sheet's bar.
            let (a, b): (CGFloat, CGFloat) = above ? (0.45, 0.65) : (0.75, 0.4)
            drag(in: app, from: CGPoint(x: window.midX, y: window.minY + window.height * a),
                 to: CGPoint(x: window.midX, y: window.minY + window.height * b), velocity: 600, hold: 0.3)
            log("\(name): moved the settings \(above ? "down" : "up") (attempt \(attempt)); the switch \(toggle.exists ? "at \(toggle.frame)" : "not in the tree yet")")
        }
        guard toggle.exists, toggle.isHittable else {
            keepScreenshot(app, "\(name) — no switch")
            XCTFail("\(name): 「前後のページを横につなげる」 is not on the settings sheet")
            return false
        }
        let was = isOn(toggle)
        log("\(name): 「前後のページを横につなげる」 at \(toggle.frame) is \(was.map { $0 ? "on" : "off" } ?? "unread") (\(String(describing: toggle.value)))")
        XCTAssertEqual(was, !on, "\(name): the switch shows the path the screen is on")
        // The switch sits at the row's right end (a tap in the row's middle lands on its title).
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: -36, dy: 0)).tap()
        var turned = waitUntil(timeout: 3) { self.isOn(toggle) == on }
        if !turned {
            log("\(name): the tap at the switch's end did not turn it (\(String(describing: toggle.value))); tapping its middle")
            toggle.tap()
            turned = waitUntil(timeout: 3) { self.isOn(toggle) == on }
        }
        keepScreenshot(app, "\(name) — the switch \(on ? "on" : "off")")
        XCTAssertTrue(turned, "\(name): the switch turned \(on ? "on" : "off") (\(String(describing: toggle.value)))")
        done.tap()
        let closed = waitUntil(timeout: 5) { !done.exists }
        log("\(name): switched \(on ? "on" : "off"), the sheet \(closed ? "closed" : "is STILL UP")")
        XCTAssertTrue(closed, "\(name): 完了 closed the settings")
        return turned && closed
    }

    private func isOn(_ toggle: XCUIElement) -> Bool? {
        if let text = toggle.value as? String { return text == "1" ? true : text == "0" ? false : nil }
        if let number = toggle.value as? NSNumber { return number.boolValue }
        return nil
    }

    /// The ja month title (`PageNavigation.title` / `compactTitle`: 「2026年10月」 either way).
    private static func isMonth(_ year: Int, _ month: Int, _ title: String) -> Bool {
        title.contains("\(year)年\(month)月")
    }

    /// D1y: what the slide and the turns read of the kind they open — the month's (October, 1.4.3 D1b) or the year's (2026):
    /// `span.state`'s `kind=` and `--screenshot-page`'s value, the page ids, the arrows, the ja titles, one page's width and
    /// the cap of an iPhone in landscape (`SpanPlan.overviewCapPages`: the year 3, the month none). On the main actor, as the
    /// class whose constants it reads.
    @MainActor
    private struct JoinedKind {
        let name: String
        /// The window's pages in the logs ("months", "years").
        let plural: String
        /// What the steps' names start with in the logs: nothing for the month (D1b's names), "year " for the year.
        let logPrefix: String
        let previous: String
        let focus: String
        let next: String
        /// The focus page and the next in the messages.
        let focusWord: String
        let nextWord: String
        let previousButton: String
        let nextButton: String
        /// What the page title holds on the focus page and on the next (`PageNavigation.title` / `compactTitle`).
        let focusTitle: String
        let nextTitle: String
        let width: CGFloat
        let capPages: CGFloat?

        static let month = JoinedKind(name: "month", plural: "months", logPrefix: "", previous: SpanMonthYearUITests.september,
                                      focus: SpanMonthYearUITests.october, next: SpanMonthYearUITests.november,
                                      focusWord: "October", nextWord: "November", previousButton: SpanMonthYearUITests.previousMonth,
                                      nextButton: SpanMonthYearUITests.nextMonth, focusTitle: "2026年10月", nextTitle: "2026年11月",
                                      width: SpanMonthYearUITests.monthWidth, capPages: nil)
        static let year = JoinedKind(name: "year", plural: "years", logPrefix: "year ", previous: "y-2025", focus: "y-2026", next: "y-2027",
                                     focusWord: "2026", nextWord: "2027", previousButton: SpanMonthYearUITests.previousYear,
                                     nextButton: SpanMonthYearUITests.nextYear, focusTitle: "2026年", nextTitle: "2027年",
                                     width: SpanMonthYearUITests.yearWidth, capPages: 3)

        /// Whether `title` is the page title `expected`: the month's (「2026年10月」, `isMonth`) in it; the year's (「2026年」,
        /// `DateText.yearTitle`) in it with no month.
        func shows(_ title: String, _ expected: String) -> Bool {
            title.contains(expected) && (name != "year" || !title.contains("月"))
        }
    }

    // MARK: - Gestures, waiting, logs (as SpanUITests)

    /// One finger: down at `from` (screen points), 0.05 s still, to `to` at `velocity` pt/s, `hold` s still, up.
    /// Returns how long the synthesis took.
    @discardableResult
    private func drag(in app: XCUIApplication, from: CGPoint, to: CGPoint, velocity: CGFloat, hold: TimeInterval = 0.05) -> TimeInterval {
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let start = origin.withOffset(CGVector(dx: from.x, dy: from.y))
        let end = origin.withOffset(CGVector(dx: to.x, dy: to.y))
        let started = Date()
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: XCUIGestureVelocity(rawValue: velocity), thenHoldForDuration: hold)
        return Date().timeIntervalSince(started)
    }

    /// Whether `condition` held within `timeout` (polled every 0.15 s), read once more after the deadline.
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.15)
        }
        return condition()
    }

    /// Waits (at most `timeout` seconds) until a query of `element` answers within 1 s (a freshly booted simulator
    /// can be busy for a minute or two). Returns the seconds waited, rounded.
    @discardableResult
    private func waitUntilResponsive(_ element: XCUIElement, timeout: TimeInterval = 60) -> Int {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            let queried = Date()
            _ = element.frame
            if Date().timeIntervalSince(queried) < 1 { break }
            Thread.sleep(forTimeInterval: 1)
        }
        return Int(Date().timeIntervalSince(start).rounded())
    }

    private func keepScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func attach(_ text: String, _ name: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func seconds(_ value: TimeInterval) -> String {
        String(format: "%.2f s", value)
    }

    private func log(_ line: String) {
        print("span-my UI: \(line)")
        NSLog("span-my UI: %@", line)
    }
}

// MARK: - What the screen reads out

/// `key=value` pairs joined by `;` (the probe and `span.state`); a value may hold `=` and `:` (`last=`).
private func monthFields(_ raw: String) -> [String: String] {
    var values: [String: String] = [:]
    for part in raw.split(separator: ";") {
        guard let equals = part.firstIndex(of: "=") else { continue }
        values[String(part[..<equals])] = String(part[part.index(after: equals)...])
    }
    return values
}

/// The canvas's probe (`InkCanvasView.Coordinator.probeValue()`): on the joined path `page=` is the band's own id,
/// `ox` / `oy` and `pw` / `ph` are the band's, `pk` / `ink` the band's strokes.
private struct MonthProbe {
    let raw: String
    /// The canvas on screen.
    let frame: CGRect
    let values: [String: String]

    init(raw: String, frame: CGRect) {
        self.raw = raw
        self.frame = frame
        values = monthFields(raw)
    }

    private func number(_ key: String) -> CGFloat? {
        values[key].flatMap { Double($0) }.map { CGFloat($0) }
    }

    var page: String { values["page"] ?? "" }
    var zoom: CGFloat { number("zoom") ?? 0 }
    var offset: CGPoint { CGPoint(x: number("ox") ?? 0, y: number("oy") ?? 0) }
    var pk: Int { values["pk"].flatMap { Int($0) } ?? -1 }
    var ink: Int { values["ink"].flatMap { Int($0) } ?? -1 }
    /// The band's height, lu.
    var paperHeight: CGFloat { number("ph") ?? 0 }
    var isReady: Bool { zoom > 0 && frame.width > 0 && frame.height > 0 }
    /// The canvas is wider than tall (the device turned).
    var isLandscape: Bool { frame.width > frame.height }

    /// A band point (lu) on screen (pt).
    func screen(_ band: CGPoint) -> CGPoint {
        CGPoint(x: frame.minX + band.x * zoom - offset.x, y: frame.minY + band.y * zoom - offset.y)
    }
}

/// One read of `span.state` (`ScreenPaths.stateLabel`) with the probe of the same moment.
private struct MonthSnapshot {
    let stateRaw: String
    let state: [String: String]
    let probe: MonthProbe

    init(stateRaw: String, probe: MonthProbe) {
        self.stateRaw = stateRaw
        state = monthFields(stateRaw)
        self.probe = probe
    }

    private func count(_ key: String) -> Int { state[key].flatMap { Int($0) } ?? -1 }

    /// The focus page's left edge in the band (lu); 0 on one page.
    var origin: CGFloat { state["origin"].flatMap { Double($0) }.map { CGFloat($0) } ?? 0 }

    /// The middle of the canvas from the focus page's left edge (lu): `SpanPlan.focus`'s midX, `(ox + width / 2) / zoom`,
    /// less `origin`.
    var middleInFocus: CGFloat {
        guard probe.zoom > 0 else { return 0 }
        return (probe.offset.x + probe.frame.width / 2) / probe.zoom - origin
    }

    /// How far the paper moved to the left since `earlier` (pt on screen), across a shift too: the middle's place in the
    /// focus page, plus a page for each month (D1y: or year) the focus moved on — a month and a year are both 1,400 lu wide.
    func paperMoved(since earlier: MonthSnapshot) -> CGFloat {
        let pages = MonthSnapshot.pages(from: earlier.state["focus"], to: state["focus"])
        return (middleInFocus + CGFloat(pages) * 1400 - earlier.middleInFocus) * probe.zoom
    }

    /// The pages from one page id to another of the same kind: months (`m1-YYYY-MM`) or, D1y, years (`y-YYYY`); 0 when
    /// either is neither or the two are not of the same kind.
    static func pages(from: String?, to: String?) -> Int {
        func index(_ id: String?) -> (kind: String, number: Int)? {
            guard let id else { return nil }
            if id.hasPrefix("m1-") {
                let parts = id.dropFirst(3).split(separator: "-")
                guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else { return nil }
                return ("month", year * 12 + month - 1)
            }
            if id.hasPrefix("y-"), let year = Int(id.dropFirst(2)) {
                return ("year", year)
            }
            return nil
        }
        guard let a = index(from), let b = index(to), a.kind == b.kind else { return 0 }
        return b.number - a.number
    }

    var pages: Int { count("pages") }
    var shifts: Int { count("shifts") }
    var stops: Int { count("stops") }

    /// The same window and the same paper: `span.state` as a whole (its version moves with each page read), the
    /// probe's zoom, offset, frame and strokes.
    func isAlike(_ other: MonthSnapshot) -> Bool {
        stateRaw == other.stateRaw && probe.zoom == other.probe.zoom && probe.offset == other.probe.offset
            && probe.frame == other.probe.frame && probe.pk == other.probe.pk && probe.ink == other.probe.ink
    }
}

/// `last=<page>:<cell>:minx=<lu>:maxx=<lu>`: the window's newest stroke, its x range in its own cell.
private struct MonthNewest {
    let pageId: String
    let cell: String
    let minX: CGFloat
    let maxX: CGFloat

    init?(_ raw: String) {
        let parts = raw.split(separator: ":").map(String.init)
        guard parts.count >= 4, let minPart = parts.first(where: { $0.hasPrefix("minx=") }),
              let maxPart = parts.first(where: { $0.hasPrefix("maxx=") }),
              let minX = Double(minPart.dropFirst(5)), let maxX = Double(maxPart.dropFirst(5)) else { return nil }
        pageId = parts[0]
        cell = parts[1]
        self.minX = CGFloat(minX)
        self.maxX = CGFloat(maxX)
    }
}
