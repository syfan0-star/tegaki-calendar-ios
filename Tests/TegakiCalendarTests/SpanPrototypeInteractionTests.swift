#if SPAN_PROTOTYPE
import Foundation
import Holidays
import InkModel
import Layout
import PencilKit
import UIKit
import XCTest
@testable import TegakiCalendar

/// What the prototype does with the band (docs/M7C_CONTRACT.md §3.6, §3.3 3, §4.5, §4.6, §5.2), checked where
/// no finger or Pencil is needed: the palm's rule and the overview's 24 pt start, the history a shift forgets, the
/// shift keeping the focus page in place, the fling to the next week, a rebuild waiting for the pen, the week memo's
/// cell, its floor and its forms, the synthetic strokes of 「線の数」, the pages they fill and the refill of a window
/// of another size or one that moved past them, the meter and its memory peak, 「上限あり」, 「1 ページずつ」, the week start, the day band with its
/// all-day bands, and the leftovers of earlier launches. Compiled only with
/// `SPAN_PROTOTYPE` (the span-shots job's host, like `PrototypeIsolationTests`); the normal build has none of it.
/// The real canvas's own tests are L's (`InkCanvasSpanTests`, S5).
@MainActor
final class SpanPrototypeInteractionTests: XCTestCase {
    /// 2026-11-11 (a Wednesday), 10:00: the window is the weeks of 10/26 … 11/23, the focus the week of 11/9.
    private let now = DayKey(year: 2026, month: 11, day: 11).startOfDay().addingTimeInterval(10 * 3600)
    /// The 11-inch iPad in portrait (a window of five weeks).
    private let pad = CGSize(width: 834, height: 1194)
    /// An iPhone in landscape (nine weeks, or seven with 「上限あり」).
    private let phoneLandscape = CGSize(width: 874, height: 402)

    // MARK: Helpers

    private func openPrototype(size: CGSize? = nil, isPad: Bool = true) throws -> (model: SpanPrototypeModel, session: SpanPrototypeSession) {
        let model = SpanPrototypeModel(environment: SpanPrototypeEnvironment.makeIsolated(), weekStart: .monday, now: now,
                                       holidays: .japan, events: [])
        model.screenChanged(size ?? pad, isPad: isPad)
        return (model, try XCTUnwrap(model.session))
    }

    /// The prototype canvas over the session's window in a container of the iPad's width, laid out once, with
    /// the focus week in the middle of the screen and the shift going to the model.
    private func attachCanvas(model: SpanPrototypeModel, session: SpanPrototypeSession)
        -> (coordinator: SpanPrototypeCanvas.Coordinator, container: SpanPrototypeContainerView) {
        var view = SpanPrototypeCanvas(layout: session.layout, papers: session.papers, tool: .ink(InkPresets.defaultPen),
                                       allowFinger: false, window: session.window, windowVersion: session.windowVersion,
                                       inbox: session.inbox, epoch: session.epoch)
        view.initialCenterX = session.layout.origin(ofSlot: session.focusSlot) + session.plan.pageWidth / 2
        view.onShift = { [weak model] index in model?.shift(toFocusIndex: index) }
        view.onRebuild = { [weak model] index in model?.runWaitingRebuild(focusIndex: index) }
        view.onInkBoundsChanged = { [weak session] in session?.relayoutPages() }
        let coordinator = SpanPrototypeCanvas.Coordinator(parent: view)
        let container = SpanPrototypeContainerView(papers: session.papers)
        coordinator.attach(container)
        container.frame = CGRect(x: 0, y: 0, width: pad.width, height: 1000)
        container.layoutSubviews()
        return (coordinator, container)
    }

    /// A pen stroke of 7 points from `a` to `b` (band lu).
    private func stroke(from a: CGPoint, to b: CGPoint, at date: Date = Date()) -> PKStroke {
        let points = (0..<7).map { i -> PKStrokePoint in
            let f = CGFloat(i) / 6
            return PKStrokePoint(location: CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f),
                                 timeOffset: TimeInterval(i) * 0.01, size: CGSize(width: 3.5, height: 3.5),
                                 opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: date),
                        transform: .identity, mask: nil)
    }

    /// Draws `strokes` on the canvas as the pen would leave them.
    private func draw(_ strokes: [PKStroke], on container: SpanPrototypeContainerView, coordinator: SpanPrototypeCanvas.Coordinator) {
        let canvas = container.canvasView
        canvas.drawing = PKDrawing(strokes: canvas.drawing.strokes + strokes)
        coordinator.canvasViewDrawingDidChange(canvas)
    }

    /// Lets the queued main-actor tasks (the inbox's arrival, a shift check, next-turn deliveries) run.
    private func settle() async {
        for _ in 0..<12 {
            await Task.yield()
        }
    }

    /// Waits until 「線の数」 has written the pages (`fillProgress` back to nil), at most `limit` seconds.
    private func waitForFill(_ model: SpanPrototypeModel, limit: TimeInterval = 20) async throws {
        let started = Date()
        while model.fillProgress != nil, Date().timeIntervalSince(started) < limit {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertNil(model.fillProgress, "the fill ended within \(limit) s")
        await settle()
    }

    // MARK: The palm (§3.6)

    /// The rule: no pan while a Pencil touches, none for 0.5 s after the last one lifted, any pan after that
    /// (and with no Pencil yet). Fails if the hold were shorter or longer, or a Pencil on the paper let a pan
    /// begin.
    func testPalmRuleHoldsWhileThePencilTouchesAndHalfASecondAfter() {
        let lift = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(SpanPrototypePalm.horizontalPanMayBegin(pencilsDown: 0, lastPencilUp: nil, now: lift))
        XCTAssertFalse(SpanPrototypePalm.horizontalPanMayBegin(pencilsDown: 1, lastPencilUp: nil, now: lift))
        XCTAssertFalse(SpanPrototypePalm.horizontalPanMayBegin(pencilsDown: 1, lastPencilUp: lift, now: lift.addingTimeInterval(5)))
        XCTAssertFalse(SpanPrototypePalm.horizontalPanMayBegin(pencilsDown: 0, lastPencilUp: lift, now: lift))
        XCTAssertFalse(SpanPrototypePalm.horizontalPanMayBegin(pencilsDown: 0, lastPencilUp: lift, now: lift.addingTimeInterval(0.49)))
        XCTAssertTrue(SpanPrototypePalm.horizontalPanMayBegin(pencilsDown: 0, lastPencilUp: lift, now: lift.addingTimeInterval(0.5)))
        XCTAssertTrue(SpanPrototypePalm.horizontalPanMayBegin(pencilsDown: 0, lastPencilUp: lift, now: lift.addingTimeInterval(3)))
        XCTAssertTrue(SpanPrototypePalm.horizontalPanMayBegin(pencilsDown: 0, lastPencilUp: lift, now: lift.addingTimeInterval(-1)),
                      "a clock set back does not hold the pan")
        XCTAssertEqual(SpanPrototypePalm.hold, 0.5)
    }

    /// The canvas asks the rule with what its touch observer counted: a Pencil down holds the pan, so does the
    /// half second after it lifted; the held pans are counted. Fails if the canvas's pan did not ask, or asked
    /// with the wrong count or time.
    func testCanvasPanFollowsThePalmRule() throws {
        let (model, session) = try openPrototype()
        let (coordinator, container) = attachCanvas(model: model, session: session)
        defer {
            coordinator.detach()
            model.close()
        }
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        coordinator.now = { clock }
        let ask = try XCTUnwrap(container.canvasView.panMayBegin)
        XCTAssertTrue(ask())
        coordinator.touchObserved(.down(.pencil))
        XCTAssertFalse(ask())
        coordinator.touchObserved(.up(.pencil))
        clock = clock.addingTimeInterval(0.2)
        XCTAssertFalse(ask())
        clock = clock.addingTimeInterval(0.4)
        XCTAssertTrue(ask())
        XCTAssertEqual(coordinator.refusedPans, 2)
    }

    // MARK: The history a shift forgets (§3.3 3)

    /// Two strokes, on the window's first page and on its middle page: forgetting the first page drops its step
    /// (the older one) and keeps the newer; forgetting the middle page drops what is left. Fails if a step of a
    /// page that left survived (↶ would make a copy for a page the window no longer has) or a step of a page
    /// that stays were lost.
    func testPruneHistoryForgetsTheStepsOfLeavingPages() throws {
        let (model, session) = try openPrototype()
        defer { model.close() }
        let ledger = SpanPrototypeLedger(window: session.window, layout: session.layout)
        let first = session.layout.origin(ofSlot: 0)
        let middle = session.layout.origin(ofSlot: session.focusSlot)
        var drawing = ledger.drawing()
        _ = ledger.applyCanvasChange(PKDrawing(strokes: drawing.strokes + [stroke(from: CGPoint(x: first + 300, y: 500), to: CGPoint(x: first + 400, y: 520))]))
        drawing = ledger.drawing()
        _ = ledger.applyCanvasChange(PKDrawing(strokes: drawing.strokes + [stroke(from: CGPoint(x: middle + 300, y: 500), to: CGPoint(x: middle + 400, y: 520),
                                                                                  at: Date().addingTimeInterval(1))]))
        XCTAssertTrue(ledger.canUndo)
        ledger.pruneHistory(touching: [session.pageIds[1]])
        XCTAssertTrue(ledger.canUndo, "a page none of the steps touches changes nothing")
        ledger.pruneHistory(touching: [session.pageIds[0]])
        XCTAssertTrue(ledger.canUndo, "the newer step, on a page that stays, is kept")
        ledger.pruneHistory(touching: [session.pageIds[session.focusSlot]])
        XCTAssertFalse(ledger.canUndo)
    }

    // MARK: The shift and the fling (§3.6)

    /// The next week is put in the middle of the screen and the band comes to rest: the window shifts by one
    /// week around it (the session composes it, the canvas takes it), and the stroke on that week stays where it
    /// was on screen (within 0.5 pt), as does the focus page's edge (`lastShift.drift`). Fails if the window did
    /// not shift, shifted by another number of pages, or x was not moved back by exactly the page that came in.
    func testShiftKeepsTheFocusPageInPlace() async throws {
        let (model, session) = try openPrototype()
        let (coordinator, container) = attachCanvas(model: model, session: session)
        defer {
            coordinator.detach()
            model.close()
        }
        await settle()
        let canvas = container.canvasView
        let middle = session.focusIndex
        let firstBefore = session.layout.firstIndex
        XCTAssertEqual(coordinator.focusIndex, middle, "the band opened with the focus week in the middle")
        let next = session.layout.origin(ofSlot: session.focusSlot + 1)
        draw([stroke(from: CGPoint(x: next + 650, y: 400), to: CGPoint(x: next + 750, y: 430))], on: container, coordinator: coordinator)
        await settle()
        XCTAssertEqual(coordinator.shiftCount, 0, "nothing moved yet")

        let zoom = canvas.zoomScale
        canvas.contentOffset = CGPoint(x: (next + 700) * zoom - pad.width / 2, y: 0)
        XCTAssertEqual(coordinator.focusIndex, middle + 1, "the middle of the screen is on the next week")
        let pk = try XCTUnwrap(canvas.drawing.strokes.first)
        let before = pk.renderBounds.midX * zoom - canvas.contentOffset.x
        coordinator.scrollViewDidEndDecelerating(canvas)
        await settle()

        XCTAssertEqual(coordinator.shiftCount, 1)
        XCTAssertEqual(session.focusIndex, middle + 1)
        XCTAssertEqual(session.layout.firstIndex, firstBefore + 1)
        XCTAssertEqual(coordinator.focusIndex, middle + 1)
        let drift = try XCTUnwrap(coordinator.lastShift?.drift)
        XCTAssertLessThanOrEqual(abs(drift), 0.5)
        XCTAssertEqual(canvas.drawing.strokes.count, 1)
        let after = try XCTUnwrap(canvas.drawing.strokes.first).renderBounds.midX * canvas.zoomScale - canvas.contentOffset.x
        XCTAssertEqual(after, before, accuracy: 0.5, "the stroke stays where it was on screen")
        XCTAssertEqual(session.slots[session.pageIds[session.focusSlot]]?.page.liveStrokes.count, 1, "the stroke's page is the new focus")
    }

    /// A release at 1.2 pt/ms to the right in the overview turns to the next week, centred
    /// (`SpanPlan.flingTarget`); a vertical drag leaves x where UIKit would stop it. Fails if the release were not
    /// handed to the plan, or x were moved on a vertical drag.
    func testFlingTurnsToTheNextWeek() async throws {
        let (model, session) = try openPrototype()
        let (coordinator, container) = attachCanvas(model: model, session: session)
        defer {
            coordinator.detach()
            model.close()
        }
        await settle()
        let canvas = container.canvasView
        let zoom = canvas.zoomScale
        let page = session.plan.pageWidth * zoom
        XCTAssertLessThan(page, pad.width, "the overview shows a week whole (zoom \(zoom))")
        coordinator.scrollViewWillBeginDragging(canvas)
        canvas.contentOffset.x += 30
        var target = CGPoint(x: canvas.contentOffset.x + 40, y: 0)
        coordinator.scrollViewWillEndDragging(canvas, withVelocity: CGPoint(x: 1.2, y: 0), targetContentOffset: &target)
        XCTAssertEqual(target.x, (CGFloat(session.focusSlot + 1) + 0.5) * page - pad.width / 2, accuracy: 0.5)

        coordinator.scrollViewWillBeginDragging(canvas)
        canvas.contentOffset.y += 200
        let x = canvas.contentOffset.x
        var vertical = CGPoint(x: x, y: canvas.contentOffset.y + 300)
        coordinator.scrollViewWillEndDragging(canvas, withVelocity: CGPoint(x: 0, y: 1.5), targetContentOffset: &vertical)
        XCTAssertEqual(vertical.x, x)
    }

    // MARK: The week memo (§5.2)

    /// Below 24:00 a week page is its memo: a stroke centred there belongs to `extra` of the page under it, one
    /// centred below the memo is dropped, no event is made there, the memo is the band `extra` from 1,920 lu,
    /// and the zoom limits still come from the 24 hours. Fails if the memo's strokes went to `grid` (the old
    /// path's cell), the paper's end were not the memo's, or the overview took the memo in.
    func testWeekMemoTakesTheStrokesBelowTwentyFour() throws {
        let (model, session) = try openPrototype()
        defer { model.close() }
        let layout = session.layout
        let slot = session.focusSlot
        let id = session.pageIds[slot]
        let x = layout.origin(ofSlot: slot) + 700
        XCTAssertEqual(layout.size.height, 1_920 + 6_000)
        XCTAssertEqual(layout.drop(center: CGPoint(x: x, y: 1_000)), .keep(page: id, cell: .grid))
        XCTAssertEqual(layout.drop(center: CGPoint(x: x, y: 2_500)), .keep(page: id, cell: .extra))
        XCTAssertEqual(layout.drop(center: CGPoint(x: x, y: 1_920 + 6_000 + 10)), .outsidePaper)
        XCTAssertTrue(layout.growsWithInk(SpanName.prefixed(.extra, page: id)))
        XCTAssertFalse(layout.growsWithInk(SpanName.prefixed(.grid, page: id)))
        let memo = try XCTUnwrap(layout.pages[slot] as? SpanPrototypeWeekMemoLayout)
        XCTAssertEqual(memo.memo, CGRect(x: 0, y: 1_920, width: 1_400, height: 6_000))
        XCTAssertEqual(memo.band(atY: 2_500), .extra)
        XCTAssertEqual(memo.bandTop(.extra), 1_920)
        let calendar = Calendar(identifier: .gregorian)
        XCTAssertNil(memo.eventRange(for: CGRect(x: 300, y: 2_400, width: 100, height: 100), now: now, calendar: calendar))
        XCTAssertNotNil(memo.eventRange(for: CGRect(x: 300, y: 400, width: 100, height: 100), now: now, calendar: calendar))
        XCTAssertNil(memo.dayAt(point: CGPoint(x: 300, y: 2_400)))
        XCTAssertEqual(SpanPrototypeCanvas.Coordinator.overview(of: layout), CGSize(width: 1_400, height: 1_920))
        XCTAssertEqual(session.papers.map(\.size), Array(repeating: CGSize(width: 1_400, height: 1_920), count: session.pageIds.count),
                       "the paper draws the 24 hours of 1.2.3")
    }

    /// A line in the focus week's memo that ends 6,030 lu below 24:00 makes every memo of the window 6,080 lu
    /// tall (`SpanAlign`, D16: the bottoms line up); its stroke is saved on its page in the memo's cell. Fails if
    /// only that week's memo grew, or none did.
    func testWeekMemoGrowsAndLinesUpAcrossTheWindow() async throws {
        let (model, session) = try openPrototype()
        let (coordinator, container) = attachCanvas(model: model, session: session)
        defer {
            coordinator.detach()
            model.close()
        }
        await settle()
        let x = session.layout.origin(ofSlot: session.focusSlot) + 500
        draw([stroke(from: CGPoint(x: x, y: 1_920 + 5_970), to: CGPoint(x: x + 60, y: 1_920 + 6_030))], on: container, coordinator: coordinator)
        await settle()
        XCTAssertEqual(session.saveAll(), [])
        let page = try XCTUnwrap(session.slots[session.pageIds[session.focusSlot]]?.page)
        XCTAssertEqual(page.liveStrokes.map(\.cell), [.extra])
        session.relayoutPages()
        XCTAssertEqual(session.memoFloor, 6_030 + 50, accuracy: 5)
        for case let memo as SpanPrototypeWeekMemoLayout in session.layout.pages {
            XCTAssertEqual(memo.memo.height, session.memoFloor)
        }
        XCTAssertEqual(session.layout.size.height, 1_920 + session.memoFloor)
    }

    // MARK: 「線の数」 (§4.6)

    /// The synthetic strokes: the same page, count and tag give the same strokes; their ids start with "syn-";
    /// a new set takes the old one out of a page (not tombstoned) and leaves the person's strokes. Fails if the
    /// pictures of CI could differ from run to run, or a count left the previous count's strokes behind.
    func testSyntheticStrokesAreTheSameEachTimeAndReplaceTheOldOnes() {
        let a = SpanPrototypeSynthetic.strokes(pageId: "w-2026-11-09", count: 40, tag: 2_500)
        XCTAssertEqual(a, SpanPrototypeSynthetic.strokes(pageId: "w-2026-11-09", count: 40, tag: 2_500))
        XCTAssertNotEqual(a, SpanPrototypeSynthetic.strokes(pageId: "w-2026-11-16", count: 40, tag: 2_500))
        XCTAssertEqual(a.count, 40)
        XCTAssertEqual(Set(a.map(\.id)).count, 40)
        XCTAssertTrue(a.allSatisfy { SpanPrototypeSynthetic.isSynthetic($0.id) && $0.cell == .grid && $0.points.count == 24 })
        XCTAssertEqual(Set(a.map(\.t)).count, 40, "each stroke has its own time (its PencilKit fingerprint)")

        let mine = InkStroke(id: "mine", cell: .grid, tool: .pen, color: "#1f2937", t: 1_791_000_000_000,
                             points: [InkPoint(x: 10, y: 10, dtMs: 0, sizeW: 3, sizeH: 3, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571)])
        var page = InkPage(pageId: "w-2026-11-09", strokes: [mine.id: mine], updatedAt: mine.t)
        page = SpanPrototypeSynthetic.replacing(page, with: a)
        XCTAssertEqual(page.liveStrokeCount, 41)
        let b = SpanPrototypeSynthetic.strokes(pageId: "w-2026-11-09", count: 10, tag: 10_000)
        page = SpanPrototypeSynthetic.replacing(page, with: b)
        XCTAssertEqual(Set(page.liveStrokeIds), Set(b.map(\.id) + ["mine"]))
        XCTAssertTrue(page.deleted.isEmpty)
        page = SpanPrototypeSynthetic.replacing(page, with: [])
        XCTAssertEqual(page.liveStrokeIds, ["mine"])
    }

    /// 「線の数」 of 500: every page of the window and one radius beyond each side is written in the prototype's
    /// folder with 100 synthetic strokes (500 ÷ 5 weeks), the person's stroke stays, the window holds 500 + 1,
    /// and 0 takes them all out again. Fails if the fill wrote outside the prototype's folder, lost what was
    /// written, or a new count left the old strokes.
    func testFillWritesThePagesAndKeepsWhatWasWritten() async throws {
        let (model, session) = try openPrototype()
        let (coordinator, container) = attachCanvas(model: model, session: session)
        await settle()
        let x = session.layout.origin(ofSlot: session.focusSlot) + 300
        draw([stroke(from: CGPoint(x: x, y: 600), to: CGPoint(x: x + 80, y: 640))], on: container, coordinator: coordinator)
        coordinator.detach()
        await settle()
        defer { model.close() }

        let filled = await session.fill(windowTotal: 500)
        XCTAssertTrue(filled)
        XCTAssertEqual(session.windowStrokeCount, 501)
        XCTAssertEqual(session.inbox.latestWindow, session.window,
                       "the safety net's source is the filled window, not the last canvas's (it would merge the old set back)")
        for id in session.pageIds {
            let page = try XCTUnwrap(session.slots[id]?.page)
            XCTAssertEqual(page.liveStrokes.filter { SpanPrototypeSynthetic.isSynthetic($0.id) }.count, 100, id)
        }
        let store = model.environment.store
        let radius = session.windowRadius
        let expected = ((session.focusIndex - 2 * radius)...(session.focusIndex + 2 * radius)).map { "proto-" + session.plan.pageId(at: $0) }
        XCTAssertEqual(Set(store.allPageIds()), Set(expected))

        let emptied = await session.fill(windowTotal: 0)
        XCTAssertTrue(emptied)
        XCTAssertEqual(session.windowStrokeCount, 1)
        XCTAssertEqual(store.load("proto-" + session.pageIds[session.focusSlot]).liveStrokeCount, 1)
        let faults = session.faultCount
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertEqual(session.faultCount, faults, "the safety net recovered nothing")
        XCTAssertEqual(session.windowStrokeCount, 1, "the synthetic strokes stay out")
    }

    /// The meter keeps the last value and the largest since a reset, the session's part of a swap, the longest
    /// frame interval in the second after the last swap only (the one that spans the swap counts), the stroke
    /// count of the slowest page read, and reads the process's memory; the HUD has a line for each kind. Fails
    /// if a value were averaged or kept from before a reset, or frames long after a swap counted.
    func testMeterKeepsTheLastAndTheLargest() throws {
        let meter = SpanPrototypeMeter()
        meter.recordSwap(seconds: 0.120, sessionSeconds: 0.040, drift: 0.2, startedAt: 100)
        meter.recordSwap(seconds: 0.030, sessionSeconds: 0.010, drift: -0.1, startedAt: 200)
        meter.frame(at: 199.99)
        meter.frame(at: 200.20)
        meter.frame(at: 200.21)
        meter.frame(at: 201.5)
        meter.recordPenLift(seconds: 0.004)
        meter.recordPenLift(seconds: 0.002)
        meter.recordEraserChange(removed: 3)
        meter.recordEraserChange(removed: 1)
        meter.recordLoad(seconds: 0.012, strokes: 5_000)
        meter.recordLoad(seconds: 0.001, strokes: 0)
        meter.recordPalmRefused()
        meter.recordTouch(radius: 12)
        meter.recordTouch(radius: 30)
        meter.recordTouch(radius: 8)
        meter.recordRelease(velocity: 0.8)
        meter.recordWindowStrokes(25_001)
        meter.publish()
        let s = meter.snapshot
        XCTAssertEqual(try XCTUnwrap(s.swapMs), 30, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(s.swapMaxMs), 120, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(s.swapSessionMs), 10, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(s.driftPt), -0.1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(s.frameGapMs), 210, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(s.liftMs), 2, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(s.liftMaxMs), 4, accuracy: 0.001)
        XCTAssertEqual(s.erased, 1)
        XCTAssertEqual(s.erasedMax, 3)
        XCTAssertEqual(try XCTUnwrap(s.loadMs), 1, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(s.loadMaxMs), 12, accuracy: 0.001)
        XCTAssertEqual(s.loadMaxStrokes, 5_000)
        XCTAssertEqual(s.palmRefused, 1)
        XCTAssertEqual(s.touchRadius, 8)
        XCTAssertEqual(s.touchRadiusMax, 30)
        XCTAssertEqual(try XCTUnwrap(s.releaseVelocity), 0.8, accuracy: 1e-6)
        XCTAssertEqual(s.windowStrokes, 25_001)
        XCTAssertGreaterThan(try XCTUnwrap(s.memoryMB), 1, "the process's footprint is read")
        XCTAssertEqual(SpanPrototypeMeter.lines(s).count, 10)
        meter.reset()
        meter.publish()
        XCTAssertNil(meter.snapshot.swapMs)
        XCTAssertNil(meter.snapshot.loadMaxMs)
        XCTAssertEqual(meter.snapshot.palmRefused, 0)
    }

    // MARK: The toggles (§4.5, §4.6 ⑤)

    /// On an iPhone in landscape 「上限あり」 makes the window 7 weeks and the lowest zoom show at most 3, and
    /// 「今のまま」 brings back 9 weeks; on an iPad it changes nothing. Fails if the cap reached another device or
    /// did not reach the window.
    func testLandscapeCapOnlyOnAnIPhoneInLandscape() throws {
        let (phone, phoneSession) = try openPrototype(size: phoneLandscape, isPad: false)
        defer { phone.close() }
        XCTAssertEqual(phoneSession.pageIds.count, 9)
        XCTAssertNil(phone.maxVisiblePages)
        phone.setLandscapeCap(true)
        XCTAssertEqual(phoneSession.pageIds.count, 7)
        XCTAssertEqual(phone.maxVisiblePages, 3)
        phone.setLandscapeCap(false)
        XCTAssertEqual(phoneSession.pageIds.count, 9)
        XCTAssertNil(phone.maxVisiblePages)

        let (pad, padSession) = try openPrototype()
        defer { pad.close() }
        pad.setLandscapeCap(true)
        XCTAssertEqual(padSession.pageIds.count, 5)
        XCTAssertNil(pad.maxVisiblePages)
    }

    /// 「1 ページずつ」 keeps the focus week and its plain 1.2.3 layout (no memo cell); the week start opens a new
    /// session of the other shape around the same day (K-11) and closes the old one. Fails if the old versions'
    /// view had the memo, or a window mixed the two shapes.
    func testSinglePageAndWeekStart() throws {
        let (model, session) = try openPrototype()
        defer { model.close() }
        model.setSinglePage(true)
        XCTAssertTrue(model.singlePage)
        let focusId = session.plan.pageId(at: try XCTUnwrap(model.focusPageIndex))
        XCTAssertEqual(focusId, "w-2026-11-09")
        let plain = try XCTUnwrap(session.plainPapers[focusId])
        XCTAssertEqual(plain.size, CGSize(width: 1_400, height: 1_920))
        XCTAssertNil(plain.layout.cells[.extra])
        XCTAssertEqual(plain.kind, .week)
        model.setSinglePage(false)

        model.setWeekStart(.sunday)
        let sunday = try XCTUnwrap(model.session)
        XCTAssertFalse(sunday === session)
        XCTAssertTrue(session.isClosed)
        XCTAssertEqual(sunday.weekStart, .sunday)
        XCTAssertEqual(sunday.number, 2)
        XCTAssertEqual(sunday.pageIds[sunday.focusSlot], "w-2026-11-08")
        XCTAssertTrue(sunday.pageIds.allSatisfy { DayKey(ymd: String($0.dropFirst(2)))?.weekday == 0 }, "\(sunday.pageIds)")
    }

    // MARK: Review fixes (2026-11-12)

    /// ISO-3 (§3.6 回転・Split View では、止まったときに窓を決め直す): the iPad turns while the pen is on the paper. The
    /// window waits; a stroke finished meanwhile reaches its page; once the pen is up and settled the canvas takes the
    /// window of the new orientation (7 weeks), composed after the stroke arrived, so the stroke stays drawn and ↶ takes
    /// it away. Fails on the code before the fix: the window was composed at once (5 → 7 while the pen was down), and the
    /// canvas then drew the page without the stroke and its ↶ did nothing.
    func testRebuildWaitsForThePenAndKeepsTheStroke() async throws {
        let (model, session) = try openPrototype()
        let (coordinator, container) = attachCanvas(model: model, session: session)
        defer {
            coordinator.detach()
            model.close()
        }
        await settle()
        let canvas = container.canvasView
        XCTAssertEqual(session.pageIds.count, 5)
        coordinator.canvasViewDidBeginUsingTool(canvas)
        XCTAssertTrue(coordinator.holdsRebuild)
        model.screenChanged(CGSize(width: pad.height, height: pad.width), isPad: true)
        XCTAssertEqual(session.pageIds.count, 5, "the window waits while the pen is on the paper")
        XCTAssertTrue(session.inbox.rebuildWaiting)
        let x = session.layout.origin(ofSlot: session.focusSlot) + 300
        draw([stroke(from: CGPoint(x: x, y: 600), to: CGPoint(x: x + 80, y: 640))], on: container, coordinator: coordinator)
        await settle()
        XCTAssertEqual(session.pageIds.count, 5, "still waiting: the pen has not lifted")
        coordinator.canvasViewDidEndUsingTool(canvas)
        // The settle wait (0.3 s) and the shift check after it.
        try await Task.sleep(for: .milliseconds(700))
        await settle()

        XCTAssertFalse(session.inbox.rebuildWaiting)
        XCTAssertEqual(coordinator.rebuildCount, 1)
        XCTAssertEqual(session.plan.orientation, .landscape)
        XCTAssertEqual(session.pageIds.count, 7, "the window of the 11-inch iPad in landscape")
        XCTAssertEqual(session.windowStrokeCount, 1, "the stroke reached its page")
        XCTAssertEqual(canvas.drawing.strokes.count, 1, "the stroke written while the window waited is drawn")
        XCTAssertEqual(coordinator.ledger.page.liveStrokes.count, 1)
        XCTAssertTrue(coordinator.ledger.canUndo)
        XCTAssertNotNil(coordinator.ledger.undo(), "↶ finds the stroke")
        XCTAssertTrue(coordinator.ledger.page.liveStrokes.isEmpty)
        XCTAssertEqual(session.faultCount, 0, "no delta for a page outside the window, no recovery by the safety net")
    }

    /// B1: 「線の数」 of 900 on an iPhone in portrait (5 weeks: 180 each); turned to landscape (9 weeks) the window is
    /// filled again to hold 900 (100 each), not 9 × 180 = 1,620; 「上限あり」 (7 weeks) and back to portrait likewise.
    /// Fails on the code before the fix: nothing filled the window again after the rotation.
    func testFillFollowsTheWindowsPageCount() async throws {
        let phonePortrait = CGSize(width: phoneLandscape.height, height: phoneLandscape.width)
        let (model, session) = try openPrototype(size: phonePortrait, isPad: false)
        defer { model.close() }
        XCTAssertEqual(session.pageIds.count, 5)
        model.setStrokeTotal(900)
        try await waitForFill(model)
        XCTAssertEqual(session.windowStrokeCount, 900)
        let filled = model.environment.filled
        XCTAssertEqual(filled.fill(of: session.pageIds[session.focusSlot]), SpanPrototypeFilledPages.Fill(total: 900, perPage: 180))
        XCTAssertFalse(session.windowNeedsFill(total: 900))

        model.screenChanged(phoneLandscape, isPad: false)
        XCTAssertEqual(session.pageIds.count, 9)
        XCTAssertNotNil(model.fillProgress, "a window of another page count is filled again")
        try await waitForFill(model)
        XCTAssertEqual(filled.fill(of: session.pageIds[0]), SpanPrototypeFilledPages.Fill(total: 900, perPage: 100))
        XCTAssertFalse(session.windowNeedsFill(total: 900))
        XCTAssertEqual(session.windowStrokeCount, 900)

        model.setLandscapeCap(true)
        XCTAssertEqual(session.pageIds.count, 7)
        try await waitForFill(model)
        XCTAssertTrue((900..<907).contains(session.windowStrokeCount), "7 × ⌈900 ÷ 7⌉ = \(session.windowStrokeCount)")

        model.setLandscapeCap(false)
        model.screenChanged(phonePortrait, isPad: false)
        try await waitForFill(model)
        XCTAssertEqual(session.pageIds.count, 5)
        XCTAssertEqual(session.windowStrokeCount, 900)
        XCTAssertEqual(model.strokeTotal, 900)
    }

    /// B1-R (§4.6 ④: 選んで、横に動かしたとき): 「線の数」 of 500 on the 11-inch iPad in portrait (5 weeks, 100 each, written
    /// on the window's weeks and two beyond each side, 9 in all). One and two weeks to the right the window is within
    /// them and nothing is written; three weeks on it holds a week the fill did not reach, so the weeks that lack the
    /// set are written (those 3 only, the measurements kept) and the window holds 500 again. Then 0, and back to the
    /// left: a week that still holds the set of 500 comes into the window and is emptied. A week start of its own
    /// session likewise. Fails on the code before the fix: three weeks on the window held 400 (seven on, none), and
    /// back on the left it held 100 with 0 chosen.
    func testFillFollowsTheWindowSideways() async throws {
        let (model, session) = try openPrototype()
        defer { model.close() }
        let store = model.environment.store
        let filled = model.environment.filled
        let start = session.focusIndex
        XCTAssertEqual(session.pageIds.count, 5)
        model.setStrokeTotal(500)
        try await waitForFill(model)
        XCTAssertEqual(session.windowStrokeCount, 500)
        XCTAssertEqual(store.allPageIds().count, 9)

        for step in 1...2 {
            XCTAssertNotNil(model.shift(toFocusIndex: start + step))
            XCTAssertNil(model.fillProgress, "\(step) week(s) on: the window is within the weeks filled")
            XCTAssertEqual(session.windowStrokeCount, 500)
        }
        // A reading taken before the window moves on (the fill after the move keeps it).
        model.meter.recordLoad(seconds: 0.5, strokes: 100)
        XCTAssertNotNil(model.shift(toFocusIndex: start + 3))
        XCTAssertNotNil(model.fillProgress, "the window holds a week the fill did not reach")
        try await waitForFill(model)
        XCTAssertEqual(session.focusIndex, start + 3)
        XCTAssertEqual(session.windowStrokeCount, 500)
        XCTAssertEqual(store.allPageIds().count, 12, "only the 3 weeks that lacked the set were written")
        XCTAssertEqual(filled.fill(of: session.plan.pageId(at: start + 7)), SpanPrototypeFilledPages.Fill(total: 500, perPage: 100))
        model.meter.publish()
        XCTAssertEqual(try XCTUnwrap(model.meter.snapshot.loadMaxMs), 500, accuracy: 0.001, "the measurements of the same choice stay")

        model.setStrokeTotal(0)
        try await waitForFill(model)
        XCTAssertEqual(session.windowStrokeCount, 0)
        XCTAssertEqual(filled.fill(of: session.plan.pageId(at: start - 2))?.total, 500, "beyond the reach of the 0")
        for focus in [start + 2, start + 1] {
            XCTAssertNotNil(model.shift(toFocusIndex: focus))
            XCTAssertNil(model.fillProgress)
        }
        XCTAssertNotNil(model.shift(toFocusIndex: start))
        XCTAssertNotNil(model.fillProgress, "a week that still holds the set of 500 came into the window")
        try await waitForFill(model)
        XCTAssertEqual(session.windowStrokeCount, 0)
        XCTAssertNil(filled.fill(of: session.plan.pageId(at: start - 2)))
        XCTAssertNil(filled.fill(of: session.plan.pageId(at: start - 4)))

        // A week start of its own (a session of its own pages), 500 there, 0, and back: the Monday weeks hold 0.
        model.setStrokeTotal(500)
        try await waitForFill(model)
        model.setWeekStart(.sunday)
        try await waitForFill(model)
        let sunday = try XCTUnwrap(model.session)
        XCTAssertEqual(sunday.windowStrokeCount, 500)
        model.setStrokeTotal(0)
        try await waitForFill(model)
        model.setWeekStart(.monday)
        XCTAssertNotNil(model.fillProgress, "the Monday weeks still hold the set of 500")
        try await waitForFill(model)
        let monday = try XCTUnwrap(model.session)
        XCTAssertEqual(monday.weekStart, .monday)
        XCTAssertEqual(monday.windowStrokeCount, 0)
        XCTAssertEqual(monday.faultCount + sunday.faultCount + session.faultCount, 0)
    }

    /// B4, B2 (§4.5 週と日の帯, §4.6 the widest window, §3.8): the day band on an iPhone in landscape is 15 days of
    /// 1,000 × 8,400 lu (the 24 hours and the free memo), each its own day paper; the all-day bands are packed over the
    /// 15 days at once, so a three-day trip has a bar on each of its days, on one lane, squared off where it goes on;
    /// 「1 ページずつ」 shows the day as 1.2.3 does. The kind switch opens the day band on today from the week band.
    /// Fails if the prototype had weeks only, or the bands were packed page by page.
    func testDayBandWithItsAllDayBands() throws {
        let start = DayKey(year: 2026, month: 11, day: 10).startOfDay()
        let trip = LayoutEvent(id: "trip", title: "旅行", allDay: true, start: start, end: start.addingTimeInterval(3 * 86_400),
                               colorHex: "#2563eb", calendarId: "sample")
        let model = SpanPrototypeModel(environment: SpanPrototypeEnvironment.makeIsolated(), weekStart: .monday, now: now,
                                       holidays: .japan, events: [trip], kind: .day)
        defer { model.close() }
        model.screenChanged(phoneLandscape, isPad: false)
        let session = try XCTUnwrap(model.session)
        XCTAssertEqual(session.plan.kind, .day)
        XCTAssertEqual(session.pageIds.count, 15)
        XCTAssertEqual(session.pageIds[session.focusSlot], "d-2026-11-11")
        XCTAssertEqual(session.layout.size, CGSize(width: 15 * 1_000, height: 2_400 + 6_000))
        for page in session.layout.pages {
            XCTAssertTrue(page is DayPageLayout)
            XCTAssertEqual(page.size, CGSize(width: 1_000, height: 8_400))
        }
        XCTAssertTrue(session.papers.allSatisfy { $0.kind == .day })
        XCTAssertEqual(SpanPrototypeCanvas.Coordinator.overview(of: session.layout), CGSize(width: 1_000, height: 2_400))

        XCTAssertEqual(session.bands.count, 15)
        XCTAssertEqual(Set(session.bands.map(\.laneCount)), [1], "one lane count for the whole window")
        let withBars = session.bands.indices.filter { !session.bands[$0].bars.isEmpty }
        XCTAssertEqual(withBars.map { session.pageIds[$0] }, ["d-2026-11-10", "d-2026-11-11", "d-2026-11-12"])
        let bars = withBars.map { session.bands[$0].bars[0] }
        XCTAssertEqual(Set(bars.map(\.lane)), [0])
        XCTAssertEqual(bars.map(\.continuesLeft), [false, true, true])
        XCTAssertEqual(bars.map(\.continuesRight), [true, true, false])

        let plain = try XCTUnwrap(session.plainPapers["d-2026-11-11"])
        XCTAssertEqual(plain.kind, .day)
        XCTAssertEqual(plain.size, CGSize(width: 1_000, height: 8_400))
        XCTAssertNotNil(plain.allDayBand)

        // From the week band: the day band opens on today (the focus week holds it), as a new session.
        let (weeks, weekSession) = try openPrototype()
        defer { weeks.close() }
        weeks.setKind(.day)
        let days = try XCTUnwrap(weeks.session)
        XCTAssertFalse(days === weekSession)
        XCTAssertTrue(weekSession.isClosed)
        XCTAssertEqual(days.plan.kind, .day)
        XCTAssertEqual(days.pageIds[days.focusSlot], "d-2026-11-11")
        XCTAssertEqual(days.pageIds.count, 7, "the 11-inch iPad's day window in portrait")
    }

    /// B5 (B_DESIGN.md §3.6 2, §3.16 約 24 pt): in the overview a finger's sideways move starts the band only after
    /// 24 pt; up and down starts at once (10 pt, more vertical than sideways); nothing that is not finite starts it.
    func testOverviewPanStartsAfterTwentyFourPoints() {
        XCTAssertEqual(SpanPrototypePalm.overviewPanStart, 24)
        XCTAssertFalse(SpanPrototypePalm.overviewPanMayStart(translation: .zero))
        XCTAssertFalse(SpanPrototypePalm.overviewPanMayStart(translation: CGSize(width: 12, height: 3)))
        XCTAssertFalse(SpanPrototypePalm.overviewPanMayStart(translation: CGSize(width: -23.9, height: 0)))
        XCTAssertTrue(SpanPrototypePalm.overviewPanMayStart(translation: CGSize(width: 24, height: 0)))
        XCTAssertTrue(SpanPrototypePalm.overviewPanMayStart(translation: CGSize(width: -30, height: 8)))
        XCTAssertFalse(SpanPrototypePalm.overviewPanMayStart(translation: CGSize(width: 15, height: 12)), "more sideways than up: 24 pt")
        XCTAssertTrue(SpanPrototypePalm.overviewPanMayStart(translation: CGSize(width: 4, height: 10)), "up and down as before")
        XCTAssertFalse(SpanPrototypePalm.overviewPanMayStart(translation: CGSize(width: CGFloat.nan, height: 0)))
    }

    /// B6 (§4.6 ずらした瞬間のメモリの山): after a swap the memory is read at every frame for a second, so its peak is
    /// kept; a frame long after the swap is not read. Fails if only the sample right after the swap and the 0.5 s
    /// samples counted (the peak would be 100 here).
    func testMeterKeepsTheMemoryPeakOfTheFramesAfterASwap() {
        let meter = SpanPrototypeMeter()
        var readings: [UInt64] = [100_000_000, 300_000_000, 120_000_000, 999_000_000]
        meter.readMemory = { readings.isEmpty ? nil : readings.removeFirst() }
        meter.recordSwap(seconds: 0.05, sessionSeconds: 0.01, drift: 0, startedAt: 500)
        meter.frame(at: 500.016)
        meter.frame(at: 500.033)
        meter.frame(at: 502)
        meter.publish()
        XCTAssertEqual(try XCTUnwrap(meter.snapshot.memoryPeakMB), 300, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(meter.snapshot.memoryMB), 120, accuracy: 0.001)
        XCTAssertEqual(readings, [999_000_000], "the frame two seconds later read nothing")
    }

    /// ISO-4: a folder an earlier launch left (the app ended while the prototype was open) is removed when the
    /// prototype opens; this launch's folders and anything else under the folder stay. Fails if leftovers piled up.
    func testLeftoverFoldersOfEarlierLaunchesAreRemoved() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("span-leftover-test-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        let old = base.appendingPathComponent(SpanPrototypeEnvironment.folderPrefix + "0123abcd-" + UUID().uuidString.lowercased(), isDirectory: true)
        let older = base.appendingPathComponent(SpanPrototypeEnvironment.folderPrefix + UUID().uuidString.lowercased(), isDirectory: true)
        let other = base.appendingPathComponent("something-else", isDirectory: true)
        for folder in [old, older, other] {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data("x".utf8).write(to: folder.appendingPathComponent("proto-w-2026-11-09.json"))
        }
        let first = SpanPrototypeEnvironment.makeIsolated(base: base)
        try first.store.save(InkPage(pageId: "proto-w-2026-11-09"))
        XCTAssertFalse(fm.fileExists(atPath: old.path), "an earlier launch's folder is gone")
        XCTAssertFalse(fm.fileExists(atPath: older.path), "the folder of a version before the fix is gone")
        XCTAssertTrue(fm.fileExists(atPath: other.path))
        let second = SpanPrototypeEnvironment.makeIsolated(base: base)
        XCTAssertTrue(fm.fileExists(atPath: first.folder.path), "a folder of this launch stays")
        XCTAssertTrue(first.folder.lastPathComponent.hasPrefix(SpanPrototypeEnvironment.folderPrefix + SpanPrototypeEnvironment.launch + "-"))
        first.discard()
        second.discard()
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: base.path), ["something-else"])
    }

    /// B3 (PLAN_WEEK_MEMO.md Q2): the third form of the memo continues the week's columns: the gutter's line, the six
    /// lines between the days, and the tints of today (Wednesday 11/11) and the weekend (11/14, 11/15), as the paper.
    func testWeekdaysMemoContinuesTheColumns() throws {
        let (model, session) = try openPrototype()
        defer { model.close() }
        let memo = try XCTUnwrap(session.layout.pages[session.focusSlot] as? SpanPrototypeWeekMemoLayout)
        let columns = memo.columns
        XCTAssertEqual(columns.gutter, PaperSpec.weekGutter)
        XCTAssertEqual(columns.lines.count, 6)
        XCTAssertEqual(columns.lines.first ?? 0, PaperSpec.weekGutter + PaperSpec.weekColumnWidth, accuracy: 0.001)
        XCTAssertEqual(columns.tints.map(\.today), [true, false, false])
        XCTAssertEqual(columns.tints.map(\.x), [2, 5, 6].map { memo.week.columnFrame($0).minX })
        XCTAssertEqual(SpanPrototypeMemoStyle.allCases, [.ruled, .grid, .weekdays])
        XCTAssertEqual(SpanPrototypeShot.Scene.memoWeekdays.memoStyle, .weekdays)
        XCTAssertEqual(SpanPrototypeShot.Scene.dayBoundary.kind, .day)
    }
}
#endif
