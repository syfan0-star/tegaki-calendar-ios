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
/// no finger or Pencil is needed: the palm's rule, the history a shift forgets, the shift keeping the focus
/// page in place, the fling to the next week, the week memo's cell and its floor, the synthetic strokes of
/// 「線の数」 and the pages they fill, 「上限あり」, 「1 ページずつ」 and the week start. Compiled only with
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
        let plain = try XCTUnwrap(session.plainLayouts[focusId])
        XCTAssertEqual(plain.size, CGSize(width: 1_400, height: 1_920))
        XCTAssertNil(plain.cells[.extra])
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
}
#endif
