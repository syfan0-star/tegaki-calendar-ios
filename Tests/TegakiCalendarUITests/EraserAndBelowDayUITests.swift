import ObjectiveC
import UIKit
import XCTest

/// 1.1 fix (TestFlight build 12; the person's checks 4, 5, 6, 6b and 12 of docs/M7A_CONTRACT.md §8 7):
/// the toolbar's eraser goes back to the last pen after it erased a line (§2.4 / §2.5), and handwriting
/// in the day's free memo area below 24:00 does not become an event (§3.7). The unit tests call the
/// canvas's delegate methods themselves, in the order they assume; here the touches go through UIKit,
/// the real PencilKit (a finger with 「指でも書く」 on: simulator touches are direct touches) and the
/// real SwiftUI screen.
///
/// The app runs in its screenshot mode (no onboarding, no EventKit, the demo month 2026-10, nothing
/// saved; the ink is kept in memory) with `--screenshot-probe`: the canvas is then an accessibility
/// element `ink-canvas` whose value reads out (`InkCanvasView.Coordinator.probeValue()`) the zoom and
/// the content offset (paper lu → screen points: frame origin + lu × zoom − offset), the paper size,
/// the strokes PencilKit holds (`pk`) and the ledger's live strokes (`ink`), the tool, and the last
/// canvas events with their times (`trace`: B / E PencilKit began / ended using its tool, C+a-r a
/// drawing change, R<n> the eraser's report of n erased strokes — in build 12's design the end of
/// the settle wait, `R0` when nothing was erased; after the fix only a report that goes out —,
/// O / o / L<n> the lasso …; `InkCanvasView.Coordinator.probeNote` has them all). Every
/// step logs it (`eraser-memo UI:` lines), so a red run says where it stopped. Every toast stays 20 s
/// with the probe, so a slow simulator cannot miss the notice.
///
/// Positions are paper points (lu) mapped with the probe: the month's memo area is the last 6,000 lu of
/// its paper (`PaperGrowth.tailHeight` of the demo memo, 1.1.1), the day's free memo area starts at
/// 2,400. Lines stay near the top of those areas, which are open from the start, so nothing grows under
/// the gestures.
///
/// Two tests (確認 6b and the lasso of 確認 12) need touches the public API cannot make — a closed loop,
/// and a touch 0.1 s after a lift — and use XCTest's own event synthesiser (`TouchSynthesizer`, private
/// classes looked up at run time). They skip themselves when this Xcode does not have them; the event
/// tool (B0) and the preselected strokes (B2, B3: `--screenshot-select`) cover the rest without it.
@MainActor
final class EraserAndBelowDayUITests: XCTestCase {
    /// The height (lu) of the month's memo area with the demo pages (`PaperGrowth.tailHeight`, 1.1.1).
    private let memoHeight: CGFloat = 6000
    /// The top part of the day's free memo area (lu) that has to be on screen for the tests below.
    private let freeMemoProbe: CGFloat = 700
    /// The top of the day's free memo area (lu, `PaperSpec.dayGridHeight`).
    private let dayExtraTop: CGFloat = 2400
    /// A gesture whose synthesis took longer than this (s) beyond its own length met an overloaded
    /// simulator (YearTapUITests, run 41172398011): it is tried once more.
    private let slowGesture: TimeInterval = 2.5
    /// How long the tool may take to go back to the pen after the lift (s). The design is 0.3 s (the
    /// settle wait) in build 12 and at most 0.5 s after the fix (a finger on the week, month and year
    /// pages), and a turn; the rest is a slow CI.
    private let returnTimeout: TimeInterval = 3

    private static let penLabel = "ペン"
    private static let eraserLabel = "消しゴム"
    private static let lassoLabel = "投げなわ"
    private static let eventToolLabel = "予定"
    private static let dockLabel = "ツールバーを出す"
    private static let convertLabel = "予定にする"
    /// The eraser's note while it will go back to the pen (`ToolbarLogic.eraserBarHint`, 2nd line).
    private static let returnNote = "消すとペンに戻ります"
    /// `CalendarRootScreen.eventBelowDayToast` without the 「24 時の下の」 (its space is not matched).
    private static let belowDayNotice = "自由メモ欄では予定を作れません"
    /// The create sheet's buttons (`EventEditorSheet`).
    private static let saveLabel = "保存"
    private static let cancelLabel = "キャンセル"

    // MARK: - A: the toolbar's eraser goes back to the pen (確認 4, 5, 6, 6b)

    /// 確認 5 and 6: 赤・太 → a line → 消しゴム (its note says it returns to the pen) → over blank paper
    /// (nothing erased: it stays the eraser) → across the line, from 120 lu above it to 120 lu below it:
    /// the line goes, and 「ペン」 is selected again within 3 s, with 赤・太.
    func testToolbarEraserReturnsToTheRedThickPenAfterErasingALine() throws {
        continueAfterFailure = false
        let name = "A1 cross"
        let app = launchApp(["--screenshot-page", "month"])
        guard let start = waitForCanvas(app, name) else { return }

        choose(Self.penLabel, in: app, name)
        choose("赤", in: app, name)
        choose("太さ: 太", in: app, name)
        let redThick = "pen:#dc2626:6"
        XCTAssertNotNil(waitForProbe(app, timeout: 3, "\(name): 赤・太 chosen") { $0.tool == redThick },
                        "\(name): the toolbar chose 赤・太 (\(probe(app)?.tool ?? "?"))")

        let memoTop = start.paperSize.height - memoHeight
        let line = Line(from: CGPoint(x: 500, y: memoTop + 150), to: CGPoint(x: 900, y: memoTop + 150))
        guard drawLine(line, in: app, name) != nil else { return }

        choose(Self.eraserLabel, in: app, name)
        XCTAssertTrue(app.buttons[Self.eraserLabel].isSelected, "\(name): 「消しゴム」 is selected")
        XCTAssertTrue(element(in: app, labelContaining: Self.returnNote).waitForExistence(timeout: 3),
                      "\(name): the eraser's note says 「（消すとペンに戻ります）」 (the toolbar's eraser, the setting on)")

        // 確認 6: an eraser stroke over blank paper erases nothing and leaves the eraser.
        guard let blankBefore = settledProbe(app) else { return XCTFail("\(name): no probe") }
        let blank = Line(from: CGPoint(x: 500, y: memoTop + 420), to: CGPoint(x: 900, y: memoTop + 420))
        let blankTook = drag(in: app, from: blankBefore.screen(blank.from), to: blankBefore.screen(blank.to), velocity: 150)
        Thread.sleep(forTimeInterval: 1.5)
        let blankAfter = probe(app)
        log("\(name): blank eraser stroke took \(seconds(blankTook)); probe \(blankAfter?.raw ?? "-")")
        XCTAssertEqual(blankAfter?.pk, blankBefore.pk, "\(name): the blank eraser stroke erased nothing")
        XCTAssertTrue(app.buttons[Self.eraserLabel].isSelected, "\(name) (確認 6): nothing erased → still the eraser")

        // 確認 5: across the line.
        let outcome = eraseAndWatch(line, with: .cross, in: app, name) { app.buttons[Self.penLabel].isSelected }
        assertErasedAndReturned(outcome, name)
        let final = probe(app)
        XCTAssertEqual(final?.tool, redThick, "\(name): back on 赤・太 (\(final?.tool ?? "?"))")
        XCTAssertTrue(app.buttons["赤"].isSelected, "\(name): the bar shows 赤")
        XCTAssertTrue(app.buttons["太さ: 太"].isSelected, "\(name): the bar shows 太")
        restoreDefaultPen(in: app, name)
    }

    /// The eraser touches the line first (the way a Pencil is put on a word): ① a stroke that starts
    /// on the line and follows it, ② a tap on the line. Each erases a fresh line with the default pen
    /// and must go back to 「ペン」 within 3 s; when the simulator's PencilKit erases nothing on the tap
    /// (seen in CI), the eraser must stay instead. Both trials run even when the first one fails.
    func testToolbarEraserReturnsToThePenWhenItStartsOnTheLine() throws {
        continueAfterFailure = true
        let app = launchApp(["--screenshot-page", "month"])
        guard let start = waitForCanvas(app, "A2") else { return }
        let memoTop = start.paperSize.height - memoHeight
        for (index, gesture) in [EraseGesture.along, .tap].enumerated() {
            let name = "A2 \(gesture.rawValue)"
            let y = memoTop + 120 + CGFloat(index) * 120
            let line = Line(from: CGPoint(x: 500, y: y), to: CGPoint(x: 900, y: y))
            if !app.buttons[Self.penLabel].isSelected {
                choose(Self.penLabel, in: app, name)
            }
            guard drawLine(line, in: app, name) != nil else {
                XCTFail("\(name): the line could not be drawn; the trial is skipped")
                continue
            }
            choose(Self.eraserLabel, in: app, name)
            let outcome = eraseAndWatch(line, with: gesture, in: app, name) { app.buttons[Self.penLabel].isSelected }
            if gesture == .tap, !outcome.erasedOnCanvas {
                // The simulator's PencilKit erased nothing on a finger's tap (CI run 41243566032, before the
                // fix as well): nothing went, so the toolbar's eraser staying is right — that is checked.
                log("\(name): PencilKit erased nothing on the tap; the eraser must stay")
                XCTAssertFalse(app.buttons[Self.penLabel].isSelected, "\(name): nothing was erased, so the toolbar's eraser stays")
                XCTAssertTrue(app.buttons[Self.eraserLabel].isSelected, "\(name): the eraser is still chosen")
                continue
            }
            assertErasedAndReturned(outcome, name)
        }
    }

    /// 確認 4: the toolbar folded into the round button → a line with the pen → the button's mark →
    /// 消しゴム on the peeking bar → across the line. The bar folds as the eraser touches the paper, the
    /// line goes, and the round button's mark is the pen again within 3 s.
    func testEraserChosenFromTheFoldedToolbarReturnsToThePen() throws {
        continueAfterFailure = false
        let name = "A3 dock"
        let app = launchApp(["--screenshot-page", "month", "--screenshot-toolbar", "collapsed"])
        guard let start = waitForCanvas(app, name) else { return }
        let dock = app.buttons[Self.dockLabel]
        XCTAssertTrue(dock.waitForExistence(timeout: 5), "\(name): the round button")
        let penMark = dock.value as? String ?? ""
        log("\(name): the round button's mark is 「\(penMark)」")
        XCTAssertTrue(penMark.hasPrefix(Self.penLabel), "\(name): it starts with the pen (\(penMark))")

        let memoTop = start.paperSize.height - memoHeight
        let line = Line(from: CGPoint(x: 500, y: memoTop + 150), to: CGPoint(x: 900, y: memoTop + 150))
        guard drawLine(line, in: app, name) != nil else { return }

        dock.tap()
        let eraser = app.buttons[Self.eraserLabel]
        XCTAssertTrue(eraser.waitForExistence(timeout: 3), "\(name): the bar peeks with 「消しゴム」")
        choose(Self.eraserLabel, in: app, name)
        XCTAssertTrue(element(in: app, labelContaining: Self.returnNote).waitForExistence(timeout: 3),
                      "\(name): the eraser's note says 「（消すとペンに戻ります）」")

        let outcome = eraseAndWatch(line, with: .cross, in: app, name) {
            dock.exists && (dock.value as? String) == penMark
        }
        let folded = dock.exists && !app.buttons[Self.eraserLabel].exists
        log("\(name): after the eraser stroke the bar is \(folded ? "folded" : "still out"); the mark is 「\(dock.value as? String ?? "-")」")
        XCTAssertTrue(folded, "\(name) (確認 4): the bar folded when the eraser touched the paper")
        assertErasedAndReturned(outcome, name)
    }

    /// 確認 6b: erase a line, lift, and touch again 0.1 s later (inside the 0.3 s settle wait) on a
    /// second line. Whatever that second touch does — with the current design it is still the eraser
    /// and takes the second line; with a fix that goes back at the lift it writes — the tool must end
    /// on the pen. Needs the event synthesiser (one event, two touches at fixed times).
    func testTouchingAgainRightAfterErasingStillEndsOnThePen() throws {
        if let missing = TouchSynthesizer.missing {
            throw XCTSkip("6b needs XCTest's event synthesiser (missing: \(missing))")
        }
        continueAfterFailure = false
        let name = "A4 6b"
        let app = launchApp(["--screenshot-page", "month"])
        guard let start = waitForCanvas(app, name) else { return }
        let memoTop = start.paperSize.height - memoHeight
        let first = Line(from: CGPoint(x: 500, y: memoTop + 120), to: CGPoint(x: 900, y: memoTop + 120))
        let second = Line(from: CGPoint(x: 500, y: memoTop + 240), to: CGPoint(x: 900, y: memoTop + 240))
        guard drawLine(first, in: app, name) != nil, drawLine(second, in: app, name) != nil else { return }
        choose(Self.eraserLabel, in: app, name)
        guard let before = settledProbe(app) else { return XCTFail("\(name): no probe") }
        waitUntilResponsive(canvasElement(in: app))

        // Along the first line for 0.45 s, lift, 0.10 s later along the second one for 0.45 s.
        let erase = TouchSynthesizer.Path(points: points(along: first, from: 0.1, to: 0.9, count: 24).map(before.screen), start: 0, duration: 0.45)
        let again = TouchSynthesizer.Path(points: points(along: second, from: 0.1, to: 0.9, count: 24).map(before.screen), start: 0.55, duration: 0.45)
        let started = Date()
        try TouchSynthesizer.perform([erase, again], name: "erase then touch again", in: self)
        let took = Date().timeIntervalSince(started)
        let returned = waitUntil(timeout: returnTimeout) { app.buttons[Self.penLabel].isSelected }
        let after = probe(app)
        keepScreenshot(app, "\(name) — after")
        attach(after?.raw ?? "-", "\(name) — probe")
        let delta = (after?.ink ?? before.ink) - before.ink
        let what: String
        switch delta {
        case -2: what = "the first touch erased the first line and the second touch, still the eraser, the second line"
        case 0: what = "the first touch erased the first line and the second touch wrote (the tool was back at the lift)"
        default: what = "unexpected (ink \(delta >= 0 ? "+" : "")\(delta))"
        }
        log("\(name): the event took \(seconds(took)); \(what); back on the pen \(returned.map { "after \(seconds($0))" } ?? "NOT within \(seconds(returnTimeout))"); probe \(after?.raw ?? "-")")
        XCTAssertTrue(delta == -2 || delta == 0, "\(name): the first touch erased its line (\(what))")
        XCTAssertNotNil(returned, "\(name) (確認 6b): back on the pen after the touches (tool \(after?.tool ?? "?"); trace \(after?.trace ?? "-"))")
    }

    // MARK: - B: handwriting below 24:00 does not become an event (確認 12)

    /// The 予定 tool dragged inside the free memo area: the notice, and no create sheet. Public API only.
    func testEventToolBelow24ShowsTheNotice() throws {
        continueAfterFailure = false
        let name = "B0 event tool"
        let app = launchApp(dayBottomArguments)
        guard let start = waitForCanvas(app, name), freeMemoIsVisible(start, name) else { return }
        choose(Self.eventToolLabel, in: app, name)
        XCTAssertNotNil(waitForProbe(app, timeout: 3, "\(name): the 予定 tool") { $0.tool == "event" })
        guard let now = settledProbe(app) else { return XCTFail("\(name): no probe") }
        let from = now.screen(CGPoint(x: 300, y: dayExtraTop + 100))
        let to = now.screen(CGPoint(x: 600, y: dayExtraTop + 250))
        let took = drag(in: app, from: from, to: to, velocity: 200)
        log("\(name): dragged \(from) → \(to) in \(seconds(took)); probe \(probe(app)?.raw ?? "-")")
        expectTheNoticeAndNoSheet(in: app, name)
    }

    /// 確認 12 as the person did it, with a finger: write below 24:00 → 投げなわ → a loop around the
    /// writing → 「予定にする」 → the notice, and no create sheet. Needs the event synthesiser (a loop).
    func testLassoAroundHandwritingBelow24ShowsTheNotice() throws {
        if let missing = TouchSynthesizer.missing {
            throw XCTSkip("the lasso needs XCTest's event synthesiser (missing: \(missing)); B2 covers the menu")
        }
        continueAfterFailure = false
        let name = "B1 lasso"
        let app = launchApp(dayBottomArguments)
        guard let start = waitForCanvas(app, name), freeMemoIsVisible(start, name) else { return }
        let line = Line(from: CGPoint(x: 330, y: dayExtraTop + 160), to: CGPoint(x: 670, y: dayExtraTop + 160))
        guard drawLine(line, in: app, name) != nil else { return }

        choose(Self.lassoLabel, in: app, name)
        XCTAssertNotNil(waitForProbe(app, timeout: 3, "\(name): the lasso") { $0.tool == "lasso" })
        guard let now = settledProbe(app) else { return XCTFail("\(name): no probe") }
        waitUntilResponsive(canvasElement(in: app))
        let loop = rectangleLoop(CGRect(x: 270, y: dayExtraTop + 80, width: 460, height: 170), step: 12).map(now.screen)
        try TouchSynthesizer.perform([TouchSynthesizer.Path(points: loop, start: 0, duration: 1.2)], name: "lasso", in: self)
        let menu = app.buttons[Self.convertLabel]
        let appeared = menu.waitForExistence(timeout: 4)
        log("\(name): the menu \(appeared ? "appeared" : "did NOT appear"); probe \(probe(app)?.raw ?? "-")")
        keepScreenshot(app, "\(name) — selected")
        XCTAssertTrue(appeared, "\(name): the lasso selected the writing below 24:00 and 「予定にする」 appeared (trace \(probe(app)?.trace ?? "-"))")
        guard appeared else { return }
        convertAndExpectTheNotice(menu, in: app, name)
    }

    /// 確認 12 without the gesture: the demo stroke of the free memo area selected at the start
    /// (`--screenshot-select`) → 「予定にする」 → the notice, and no create sheet.
    func testPreselectedHandwritingBelow24ShowsTheNotice() throws {
        continueAfterFailure = false
        let name = "B2 preselected below 24:00"
        let app = launchApp(dayBottomArguments + ["--screenshot-grown", "--screenshot-select", "demo-stroke-day-extra"])
        guard waitForCanvas(app, name) != nil else { return }
        let menu = app.buttons[Self.convertLabel]
        let appeared = menu.waitForExistence(timeout: 8)
        log("\(name): the menu \(appeared ? "appeared" : "did NOT appear"); probe \(probe(app)?.raw ?? "-")")
        keepScreenshot(app, "\(name) — selected")
        XCTAssertTrue(appeared, "\(name): the selection's menu")
        guard appeared else { return }
        convertAndExpectTheNotice(menu, in: app, name)
    }

    /// The control of B2: a stroke above 24:00 (the memo column at 1:00) selected the same way →
    /// 「予定にする」 opens the create sheet (so B2's "nothing but the notice" is not a menu that does
    /// nothing at all). The sheet is cancelled.
    func testPreselectedHandwritingAbove24OpensTheCreateSheet() throws {
        continueAfterFailure = false
        let name = "B3 preselected above 24:00"
        let app = launchApp(["--screenshot-page", "day", "--screenshot-select", "demo-stroke-day-wave1"])
        guard waitForCanvas(app, name) != nil else { return }
        let menu = app.buttons[Self.convertLabel]
        XCTAssertTrue(menu.waitForExistence(timeout: 8), "\(name): the selection's menu")
        waitUntilResponsive(menu)
        menu.tap()
        let sheet = app.buttons[Self.saveLabel].waitForExistence(timeout: 5)
        let notice = element(in: app, labelContaining: Self.belowDayNotice).exists
        keepScreenshot(app, "\(name) — after 予定にする")
        log("\(name): create sheet \(sheet ? "opened" : "did NOT open"); notice \(notice ? "shown" : "none"); probe \(probe(app)?.raw ?? "-")")
        XCTAssertTrue(sheet, "\(name): 「予定にする」 opened the create sheet")
        XCTAssertFalse(notice, "\(name): no below-24:00 notice for a stroke above 24:00")
        if sheet {
            app.buttons[Self.cancelLabel].tap()
        }
    }

    // MARK: - Launching and the probe

    /// The day page at twice its opening zoom, scrolled to just above the free memo area below 24:00:
    /// the first 700 lu of it (about 315 pt on an iPhone 17) are in the canvas. (Its end, 6,000 lu
    /// further down since 1.1.1, is only blank paper.)
    private var dayBottomArguments: [String] {
        ["--screenshot-page", "day", "--screenshot-zoom", "2", "--screenshot-offset", "0,2380"]
    }

    private func launchApp(_ extra: [String]) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-probe",
            "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
            // UserDefaults' argument domain (YearTapUITests): 「指でも書く」 on and already chosen, so a
            // simulator finger draws and erases.
            "-allowFingerDrawing", "YES", "-allowFingerDrawingChosen", "YES",
        ] + extra
        app.launch()
        log("launched \(extra.joined(separator: " "))")
        return app
    }

    private func canvasElement(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "ink-canvas").firstMatch
    }

    /// The canvas's probe now; nil when the element or its value is missing.
    private func probe(_ app: XCUIApplication) -> CanvasProbe? {
        let canvas = canvasElement(in: app)
        guard canvas.exists, let raw = canvas.value as? String else { return nil }
        return CanvasProbe(raw: raw, frame: canvas.frame)
    }

    /// The probe once it has a zoom and two reads 0.4 s apart agree on the zoom, the offset and the
    /// frame (the first layout and the screenshot offset are applied); the last read at the timeout.
    private func settledProbe(_ app: XCUIApplication, timeout: TimeInterval = 10) -> CanvasProbe? {
        let deadline = Date().addingTimeInterval(timeout)
        var last: CanvasProbe?
        while Date() < deadline {
            if let now = probe(app), now.isReady {
                if let previous = last, previous.zoom == now.zoom, previous.offset == now.offset, previous.frame == now.frame {
                    return now
                }
                last = now
            }
            Thread.sleep(forTimeInterval: 0.4)
        }
        return last
    }

    /// Polls the probe (every 0.2 s, at most `timeout` s) until `until` holds; nil (logged) otherwise.
    private func waitForProbe(_ app: XCUIApplication, timeout: TimeInterval, _ what: String, until: (CanvasProbe) -> Bool) -> CanvasProbe? {
        let deadline = Date().addingTimeInterval(timeout)
        var last: CanvasProbe?
        repeat {
            if let now = probe(app) {
                last = now
                if until(now) { return now }
            }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
        log("\(what): not within \(seconds(timeout)); last probe \(last?.raw ?? "none")")
        return nil
    }

    /// Waits for the canvas (the probe element with a zoom), then for a simulator that answers
    /// quickly. Fails (with the element tree) and returns nil when there is no probe: the app was
    /// built without `--screenshot-probe`'s support.
    private func waitForCanvas(_ app: XCUIApplication, _ name: String) -> CanvasProbe? {
        let canvas = canvasElement(in: app)
        guard canvas.waitForExistence(timeout: 30) else {
            log("\(name): no 「ink-canvas」 element. Elements:\n\(app.debugDescription)")
            XCTFail("\(name): the canvas probe (--screenshot-probe) is missing")
            return nil
        }
        log("\(name): waited \(waitUntilResponsive(canvas)) s for the app to answer quickly")
        guard let settled = settledProbe(app), settled.isReady else {
            XCTFail("\(name): the canvas never reported a zoom (\(probe(app)?.raw ?? "-"))")
            return nil
        }
        log("\(name): window=\(app.windows.firstMatch.frame) canvas=\(settled.frame) visible paper=\(settled.visiblePaper) probe \(settled.raw)")
        keepScreenshot(app, "\(name) — start")
        return settled
    }

    /// The top of the free memo area (2,400 … 2,400 + 700 lu) is inside the canvas (`dayBottomArguments`).
    private func freeMemoIsVisible(_ probe: CanvasProbe, _ name: String) -> Bool {
        let top = probe.screen(CGPoint(x: 0, y: dayExtraTop)).y
        let bottom = probe.screen(CGPoint(x: 0, y: dayExtraTop + freeMemoProbe)).y
        let visible = top >= probe.frame.minY - 0.5 && bottom <= probe.frame.maxY + 0.5 && probe.paperSize.height >= dayExtraTop + freeMemoProbe - 0.5
        log("\(name): the free memo area is \(top)…\(bottom) pt in the canvas \(probe.frame.minY)…\(probe.frame.maxY)")
        XCTAssertTrue(visible, "\(name): the free memo area below 24:00 is on screen (\(top)…\(bottom) in \(probe.frame))")
        return visible
    }

    // MARK: - Gestures

    private struct Line {
        var from: CGPoint
        var to: CGPoint

        func point(at t: CGFloat) -> CGPoint {
            CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
        }
    }

    private enum EraseGesture: String {
        /// From 120 lu above the line's middle to 120 lu below it, slowly: the eraser touches the
        /// paper first and meets the line on the way.
        case cross
        /// From 10 % of the line to 90 % along it: the eraser touches the line at once.
        case along
        /// One tap on the line's middle.
        case tap
    }

    private func points(along line: Line, from a: CGFloat, to b: CGFloat, count: Int) -> [CGPoint] {
        (0..<count).map { line.point(at: a + (b - a) * CGFloat($0) / CGFloat(max(count - 1, 1))) }
    }

    /// A closed loop around `rect` (paper lu), clockwise from the top-left corner, a point every
    /// `step` lu, ending back at the start.
    private func rectangleLoop(_ rect: CGRect, step: CGFloat) -> [CGPoint] {
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                       CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY),
                       CGPoint(x: rect.minX, y: rect.minY)]
        var out: [CGPoint] = [corners[0]]
        for (a, b) in zip(corners, corners.dropFirst()) {
            let length = hypot(b.x - a.x, b.y - a.y)
            let n = max(1, Int((length / step).rounded(.up)))
            for i in 1...n {
                let t = CGFloat(i) / CGFloat(n)
                out.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        return out
    }

    /// One finger: down at `from` (screen points), 0.05 s still, to `to` at `velocity` pt/s, `hold` s
    /// still, up. Returns how long the synthesis took.
    @discardableResult
    private func drag(in app: XCUIApplication, from: CGPoint, to: CGPoint, velocity: CGFloat, hold: TimeInterval = 0.05) -> TimeInterval {
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let start = origin.withOffset(CGVector(dx: from.x, dy: from.y))
        let end = origin.withOffset(CGVector(dx: to.x, dy: to.y))
        let started = Date()
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: XCUIGestureVelocity(rawValue: velocity), thenHoldForDuration: hold)
        return Date().timeIntervalSince(started)
    }

    @discardableResult
    private func tap(in app: XCUIApplication, at point: CGPoint) -> TimeInterval {
        let started = Date()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(CGVector(dx: point.x, dy: point.y)).tap()
        return Date().timeIntervalSince(started)
    }

    /// Draws `line` (paper lu) with the current pen: one more stroke in PencilKit (`pk`) and in the
    /// ledger (`ink`). Tried once more after an overloaded synthesis. nil (failed) otherwise.
    private func drawLine(_ line: Line, in app: XCUIApplication, _ name: String) -> CanvasProbe? {
        guard let before = settledProbe(app) else {
            XCTFail("\(name): no probe before drawing")
            return nil
        }
        let from = before.screen(line.from)
        let to = before.screen(line.to)
        guard before.frame.insetBy(dx: 4, dy: 4).contains(from), before.frame.insetBy(dx: 4, dy: 4).contains(to) else {
            XCTFail("\(name): the line \(from) → \(to) is outside the canvas \(before.frame)")
            return nil
        }
        let length = hypot(to.x - from.x, to.y - from.y)
        for attempt in 1...2 {
            waitUntilResponsive(canvasElement(in: app))
            let took = drag(in: app, from: from, to: to, velocity: 250)
            let drawn = waitForProbe(app, timeout: 4, "\(name): the line") { $0.pk == before.pk + 1 && $0.ink == before.ink + 1 }
            log("\(name): drew \(from) → \(to) (attempt \(attempt), \(seconds(took))): \(drawn != nil ? "1 stroke more" : "NOT drawn"); probe \(probe(app)?.raw ?? "-")")
            if let drawn { return drawn }
            if took <= length / 250 + 0.2 + slowGesture { break }
            log("\(name): RETRY the line (the simulator was overloaded)")
        }
        keepScreenshot(app, "\(name) — the line was not drawn")
        XCTFail("\(name): a finger stroke with the pen did not add a line (probe \(probe(app)?.raw ?? "-"))")
        return nil
    }

    /// What one eraser trial saw.
    private struct EraseOutcome {
        var before: CanvasProbe
        /// The stroke left PencilKit (`pk` − 1) / the ledger (`ink` − 1) within the wait.
        var erasedOnCanvas = false
        var erasedInLedger = false
        /// Seconds from the end of the gesture until `isBack` held; nil = not within `returnTimeout`.
        var returnedAfter: TimeInterval?
        var gestureSeconds: TimeInterval = 0
        var after: CanvasProbe?
    }

    /// Erases `line` with `gesture` (tried once more when an overloaded synthesis erased nothing),
    /// then watches for `isBack` (the pen selected again) for `returnTimeout` s, reading the probe on
    /// the way. Keeps a screenshot and the last probe.
    private func eraseAndWatch(_ line: Line, with gesture: EraseGesture, in app: XCUIApplication, _ name: String,
                               isBack: () -> Bool) -> EraseOutcome {
        guard let before = settledProbe(app) else {
            XCTFail("\(name): no probe before erasing")
            return EraseOutcome(before: CanvasProbe(raw: "", frame: .zero))
        }
        var outcome = EraseOutcome(before: before)
        for attempt in 1...2 {
            waitUntilResponsive(canvasElement(in: app))
            let took: TimeInterval
            let expected: TimeInterval
            switch gesture {
            case .cross:
                let middle = line.point(at: 0.5)
                let from = before.screen(CGPoint(x: middle.x, y: middle.y - 120))
                let to = before.screen(CGPoint(x: middle.x, y: middle.y + 120))
                took = drag(in: app, from: from, to: to, velocity: 80)
                expected = hypot(to.x - from.x, to.y - from.y) / 80
            case .along:
                let from = before.screen(line.point(at: 0.1))
                let to = before.screen(line.point(at: 0.9))
                took = drag(in: app, from: from, to: to, velocity: 120)
                expected = hypot(to.x - from.x, to.y - from.y) / 120
            case .tap:
                took = tap(in: app, at: before.screen(line.point(at: 0.5)))
                expected = 0.2
            }
            outcome.gestureSeconds = took
            let lifted = Date()
            var back: TimeInterval?
            while Date().timeIntervalSince(lifted) < returnTimeout {
                if back == nil, isBack() {
                    back = Date().timeIntervalSince(lifted)
                }
                if let now = probe(app) {
                    outcome.after = now
                    outcome.erasedOnCanvas = now.pk == before.pk - 1
                    outcome.erasedInLedger = now.ink == before.ink - 1
                }
                if back != nil, outcome.erasedOnCanvas, outcome.erasedInLedger { break }
                Thread.sleep(forTimeInterval: 0.15)
            }
            outcome.returnedAfter = back
            log("\(name): \(gesture.rawValue) (attempt \(attempt), \(seconds(took))): canvas \(outcome.erasedOnCanvas ? "erased" : "NOT erased"), ledger \(outcome.erasedInLedger ? "erased" : "NOT erased"), back on the pen \(back.map { "after \(seconds($0))" } ?? "NOT within \(seconds(returnTimeout))"); probe \(outcome.after?.raw ?? "-")")
            if outcome.erasedOnCanvas || took <= expected + 0.2 + slowGesture { break }
            log("\(name): RETRY the eraser (the simulator was overloaded and nothing was erased)")
        }
        keepScreenshot(app, "\(name) — after the eraser")
        attach(outcome.after?.raw ?? "-", "\(name) — probe")
        return outcome
    }

    /// The message tells what went wrong: the gesture (nothing erased: a problem of this test's
    /// geometry, or PencilKit not erasing on that gesture — staying the eraser is then right, so the
    /// return is not asked), the ledger (PencilKit erased, the ledger did not see it), the return (the
    /// bug of 確認 4 / 5 / 6b).
    private func assertErasedAndReturned(_ outcome: EraseOutcome, _ name: String) {
        let trace = outcome.after?.trace ?? "-"
        guard outcome.erasedOnCanvas else {
            XCTFail("\(name): the eraser did not take the line off PencilKit's drawing — the gesture missed it (this test's problem, not the return's; trace \(trace))")
            return
        }
        XCTAssertTrue(outcome.erasedInLedger, "\(name): PencilKit erased the line but the ledger kept it (trace \(trace))")
        XCTAssertNotNil(outcome.returnedAfter, "\(name): the toolbar's eraser went back to the pen within \(seconds(returnTimeout)) of the lift (tool \(outcome.after?.tool ?? "?"); trace \(trace))")
    }

    // MARK: - The toolbar

    /// Taps the toolbar's button `label`, first bringing it into view: on an iPhone the bar's row is
    /// wider than the screen (the pen's colours and widths are to the right of the tools).
    private func choose(_ label: String, in app: XCUIApplication, _ name: String) {
        let button = app.buttons[label]
        guard button.waitForExistence(timeout: 5) else {
            XCTFail("\(name): the toolbar has no 「\(label)」")
            return
        }
        reveal(button, in: app)
        button.tap()
        log("\(name): chose 「\(label)」 (selected=\(button.isSelected)); tool \(probe(app)?.tool ?? "?")")
    }

    /// Drags the bar's row sideways (slowly, then held, so it does not coast) until `button` lies in
    /// the row's visible part — left of 「しまう」 and its 12 pt fade (`ToolbarLogic.Row.fadeWidth`),
    /// which sit outside the row — at most 4 times. A tap that landed on 「しまう」 would fold the bar.
    private func reveal(_ button: XCUIElement, in app: XCUIApplication) {
        let screen = app.windows.firstMatch.frame
        let collapse = app.buttons["ツールバーをしまう"]
        for attempt in 1...4 {
            let right = collapse.exists ? collapse.frame.minX - 18 : screen.maxX - 28
            let left = screen.minX + 16
            let frame = button.frame
            if button.isHittable, frame.minX >= left, frame.maxX <= right { return }
            let room = screen.width * 0.5
            let dx = frame.maxX > right
                ? -min(frame.maxX - right + 24, room)
                : min(left - frame.minX + 24, room)
            let startX = dx < 0 ? screen.minX + screen.width * 0.6 : screen.minX + screen.width * 0.2
            drag(in: app, from: CGPoint(x: startX, y: frame.midY), to: CGPoint(x: startX + dx, y: frame.midY), velocity: 300, hold: 0.3)
            log("toolbar: moved the row by \(dx) pt for 「\(button.label)」 (attempt \(attempt), it was at \(frame), the row ends at \(right))")
        }
    }

    /// Puts 黒・中 back (the toolbar remembers the pen in UserDefaults, which the next test reads).
    private func restoreDefaultPen(in app: XCUIApplication, _ name: String) {
        guard app.buttons[Self.penLabel].isSelected else { return }
        choose("黒", in: app, name)
        choose("太さ: 中", in: app, name)
    }

    // MARK: - The notice

    /// 「予定にする」 → the notice 「24 時の下の自由メモ欄では予定を作れません」, and no create sheet.
    private func convertAndExpectTheNotice(_ menu: XCUIElement, in app: XCUIApplication, _ name: String) {
        waitUntilResponsive(menu)
        log("\(name): 「予定にする」 at \(menu.frame) hittable=\(menu.isHittable)")
        menu.tap()
        expectTheNoticeAndNoSheet(in: app, name)
    }

    /// The notice is in the element tree and on the screen (its frame inside the window: an element
    /// that exists but lies outside, or under the bar, would pass `exists` while the person sees
    /// nothing — the frame and the bar's top are logged for the screenshot), and no create sheet.
    private func expectTheNoticeAndNoSheet(in app: XCUIApplication, _ name: String) {
        let notice = element(in: app, labelContaining: Self.belowDayNotice)
        let shown = notice.waitForExistence(timeout: 5)
        let sheet = app.buttons[Self.saveLabel].waitForExistence(timeout: shown ? 0.5 : 1)
        let window = app.windows.firstMatch.frame
        let frame = shown ? notice.frame : .zero
        let pen = app.buttons[Self.penLabel]
        keepScreenshot(app, "\(name) — after")
        log("\(name): notice \(shown ? "shown at \(frame)" : "NOT shown"); window \(window); the bar's 「ペン」 \(pen.exists ? "\(pen.frame)" : "-"); create sheet \(sheet ? "OPENED" : "none"); probe \(probe(app)?.raw ?? "-")")
        XCTAssertTrue(shown, "\(name) (確認 12): 「24 時の下の自由メモ欄では予定を作れません」 is shown")
        if shown {
            XCTAssertTrue(window.insetBy(dx: -0.5, dy: -0.5).contains(frame) && frame.width > 0 && frame.height > 0,
                          "\(name): the notice lies on the screen (\(frame) in \(window))")
        }
        XCTAssertFalse(sheet, "\(name): no create sheet for handwriting below 24:00")
        if sheet {
            app.buttons[Self.cancelLabel].tap()
        }
    }

    private func element(in app: XCUIApplication, labelContaining text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    // MARK: - Waiting, logs, attachments (as YearTapUITests)

    /// Seconds until `condition` held (polled every 0.15 s), nil after `timeout`.
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> TimeInterval? {
        let start = Date()
        repeat {
            if condition() { return Date().timeIntervalSince(start) }
            Thread.sleep(forTimeInterval: 0.15)
        } while Date().timeIntervalSince(start) < timeout
        return nil
    }

    /// Waits (at most `timeout` seconds) until a query of `element` answers within 1 s: a freshly
    /// booted simulator can be busy for a minute or two (run 41172398011: 5–10 s per query). Returns
    /// the seconds waited, rounded.
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
        print("eraser-memo UI: \(line)")
        NSLog("eraser-memo UI: %@", line)
    }
}

// MARK: - The canvas probe

/// The value of the canvas's accessibility element with `--screenshot-probe`
/// (`InkCanvasView.Coordinator.probeValue()`): `key=value` pairs joined by `;`.
private struct CanvasProbe {
    let raw: String
    /// The canvas (the container) on screen.
    let frame: CGRect
    let values: [String: String]

    init(raw: String, frame: CGRect) {
        self.raw = raw
        self.frame = frame
        var values: [String: String] = [:]
        for part in raw.split(separator: ";") {
            guard let equals = part.firstIndex(of: "=") else { continue }
            values[String(part[..<equals])] = String(part[part.index(after: equals)...])
        }
        self.values = values
    }

    private func number(_ key: String) -> CGFloat? {
        values[key].flatMap { Double($0) }.map { CGFloat($0) }
    }

    var zoom: CGFloat { number("zoom") ?? 0 }
    /// The canvas's content offset (pt; negative while the paper is centred).
    var offset: CGPoint { CGPoint(x: number("ox") ?? 0, y: number("oy") ?? 0) }
    /// The paper (lu).
    var paperSize: CGSize { CGSize(width: number("pw") ?? 0, height: number("ph") ?? 0) }
    /// Strokes on PencilKit's drawing (what is on screen).
    var pk: Int { values["pk"].flatMap { Int($0) } ?? -1 }
    /// Live strokes in the ledger (what is saved).
    var ink: Int { values["ink"].flatMap { Int($0) } ?? -1 }
    var tool: String { values["tool"] ?? "" }
    var trace: String { values["trace"] ?? "" }
    var isReady: Bool { zoom > 0 && frame.width > 0 && frame.height > 0 }

    /// A paper point (lu) on screen (pt).
    func screen(_ paper: CGPoint) -> CGPoint {
        CGPoint(x: frame.minX + paper.x * zoom - offset.x, y: frame.minY + paper.y * zoom - offset.y)
    }

    /// The part of the paper (lu) the canvas shows.
    var visiblePaper: CGRect {
        guard zoom > 0 else { return .zero }
        return CGRect(x: offset.x / zoom, y: offset.y / zoom, width: frame.width / zoom, height: frame.height / zoom)
    }
}

// MARK: - Touches the public API cannot make

/// One-finger paths of any shape and timing, sent through XCTest's own event synthesiser. XCUITest's
/// public gestures only press and drag in a straight line, which can neither draw a lasso (a closed
/// loop) nor put a touch 0.1 s after a lift (確認 6b). This uses the private classes
/// `XCPointerEventPath` and `XCSynthesizedEventRecord` and `XCUIDevice.eventSynthesizer` — what
/// WebDriverAgent (Appium) drives — looked up at run time; `missing` names the first piece this
/// Xcode does not have (the tests then skip). Test code only: nothing of it reaches the app.
@MainActor
private enum TouchSynthesizer {
    struct Path {
        /// Screen points (the app's portrait window); the first is the touch-down.
        var points: [CGPoint]
        /// Seconds from the start of the event to the touch-down.
        var start: TimeInterval
        /// Seconds from the touch-down to the lift; the moves are spread evenly over it.
        var duration: TimeInterval
    }

    private static let pathClass: AnyClass? = NSClassFromString("XCPointerEventPath")
    private static let recordClass: AnyClass? = NSClassFromString("XCSynthesizedEventRecord")
    private static let allocSelector = NSSelectorFromString("alloc")
    private static let touchInitSelector = NSSelectorFromString("initForTouchAtPoint:offset:")
    private static let moveSelector = NSSelectorFromString("moveToPoint:atOffset:")
    private static let liftSelector = NSSelectorFromString("liftUpAtOffset:")
    private static let recordInitSelector = NSSelectorFromString("initWithName:interfaceOrientation:")
    private static let addPathSelector = NSSelectorFromString("addPointerEventPath:")
    private static let synthesizerSelector = NSSelectorFromString("eventSynthesizer")
    private static let synthesizeSelector = NSSelectorFromString("synthesizeEvent:completion:")

    private typealias AllocIMP = @convention(c) (AnyClass, Selector) -> OpaquePointer?
    private typealias TouchInitIMP = @convention(c) (OpaquePointer, Selector, CGPoint, Double) -> OpaquePointer?
    private typealias MoveIMP = @convention(c) (OpaquePointer, Selector, CGPoint, Double) -> Void
    private typealias LiftIMP = @convention(c) (OpaquePointer, Selector, Double) -> Void
    private typealias RecordInitIMP = @convention(c) (OpaquePointer, Selector, OpaquePointer, Int) -> OpaquePointer?

    /// The first missing piece, or nil when everything is there.
    static var missing: String? {
        guard let pathClass else { return "XCPointerEventPath" }
        guard let recordClass else { return "XCSynthesizedEventRecord" }
        for selector in [touchInitSelector, moveSelector, liftSelector] where class_getInstanceMethod(pathClass, selector) == nil {
            return "XCPointerEventPath." + NSStringFromSelector(selector)
        }
        for selector in [recordInitSelector, addPathSelector] where class_getInstanceMethod(recordClass, selector) == nil {
            return "XCSynthesizedEventRecord." + NSStringFromSelector(selector)
        }
        guard let synthesizer = synthesizer() else { return "XCUIDevice.eventSynthesizer" }
        guard synthesizer.responds(to: synthesizeSelector) else { return "synthesizeEvent:completion:" }
        return nil
    }

    private static func synthesizer() -> NSObject? {
        let device = XCUIDevice.shared
        guard device.responds(to: synthesizerSelector) else { return nil }
        return device.perform(synthesizerSelector)?.takeUnretainedValue() as? NSObject
    }

    /// Sends `paths` as one event (each path's touches at their own times) and waits until XCTest
    /// says they were delivered.
    static func perform(_ paths: [Path], name: String, in testCase: XCTestCase, timeout: TimeInterval = 30) throws {
        if let missing { throw XCTSkip("XCTest's event synthesiser is missing \(missing)") }
        guard let record = makeRecord(name: name), let synthesizer = synthesizer() else {
            throw XCTSkip("XCTest's event record could not be made")
        }
        for path in paths {
            guard let made = makePath(path) else { throw XCTSkip("XCTest's pointer path could not be made") }
            _ = record.perform(addPathSelector, with: made)
        }
        let delivered = XCTestExpectation(description: name)
        var failure: NSError?
        let completion: @convention(block) (ObjCBool, NSError?) -> Void = { _, error in
            failure = error
            delivered.fulfill()
        }
        _ = synthesizer.perform(synthesizeSelector, with: record, with: unsafeBitCast(completion, to: AnyObject.self))
        testCase.wait(for: [delivered], timeout: timeout)
        if let failure {
            XCTFail("synthesizing \(name) failed: \(failure)")
        }
    }

    /// `[cls alloc]`: +1, handed on to an initialiser (which consumes it).
    private static func alloc(_ cls: AnyClass) -> OpaquePointer? {
        guard let meta = object_getClass(cls), let imp = class_getMethodImplementation(meta, allocSelector) else { return nil }
        return unsafeBitCast(imp, to: AllocIMP.self)(cls, allocSelector)
    }

    /// The +1 object an initialiser returned, owned by Swift from here on.
    private static func take(_ pointer: OpaquePointer) -> NSObject? {
        Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(pointer)).takeRetainedValue() as? NSObject
    }

    private static func makeRecord(name: String) -> NSObject? {
        guard let cls = recordClass, let raw = alloc(cls), let imp = class_getMethodImplementation(cls, recordInitSelector) else { return nil }
        let title = name as NSString
        let made = withExtendedLifetime(title) {
            unsafeBitCast(imp, to: RecordInitIMP.self)(raw, recordInitSelector, OpaquePointer(Unmanaged.passUnretained(title).toOpaque()),
                                                       UIInterfaceOrientation.portrait.rawValue)
        }
        return made.flatMap(take)
    }

    private static func makePath(_ path: Path) -> NSObject? {
        guard let cls = pathClass, let first = path.points.first, let raw = alloc(cls),
              let initIMP = class_getMethodImplementation(cls, touchInitSelector),
              let made = unsafeBitCast(initIMP, to: TouchInitIMP.self)(raw, touchInitSelector, first, path.start),
              let object = take(made),
              let moveIMP = class_getMethodImplementation(cls, moveSelector),
              let liftIMP = class_getMethodImplementation(cls, liftSelector) else { return nil }
        let pointer = OpaquePointer(Unmanaged.passUnretained(object).toOpaque())
        let move = unsafeBitCast(moveIMP, to: MoveIMP.self)
        let steps = max(path.points.count - 1, 1)
        for (index, point) in path.points.enumerated().dropFirst() {
            move(pointer, moveSelector, point, path.start + path.duration * Double(index) / Double(steps))
        }
        unsafeBitCast(liftIMP, to: LiftIMP.self)(pointer, liftSelector, path.start + path.duration)
        return withExtendedLifetime(object) { object }
    }
}
