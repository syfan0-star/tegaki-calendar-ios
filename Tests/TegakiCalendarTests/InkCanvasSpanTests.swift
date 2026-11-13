@_spi(SpanLedger) import InkModel
import Layout
import PencilKit
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

// 1.3 (docs/M7C_CONTRACT.md §10.2 row L, §3.6, §3.4, §3.3, §3.16, D15, D16, D21): the canvas with a window of joined
// pages (`InkCanvasView.span`), built as `makeUIView` builds it (`InkCanvasContainerView` with an `InkBandCanvasView`,
// `Coordinator.attach`), over a `SpanSession` of the live `SyncEngine` of `SessionTestBed` (a temporary `InkPageStore`,
// `InMemoryCloudDatabase`). No real sleep anywhere (§3.16, §10.2): the session's timers wait on the bed's
// `sessionSleeper`, the canvas's 0.5 s watch on `canvasSleeper` (two sleepers, never advanced together; docs/R1_2_3.md
// §4.3), the clock is the bed's fixed `now`, and the end of 1.2.3's 0.3 s settle wait is called
// (`endSettleWaitForTesting`) instead of waited for. PencilKit's reports are stood in for as the 1.2.3 tests do
// (`canvasViewDrawingDidChange`, Begin / End, `touchObserved`); a fling, a pinch and a stop are the delegate calls UIKit
// would make (XCTest cannot fling).
//
// The pages: iPad 11 portrait, five Monday weeks around 11/16 (R = 2): 11/02 … 11/30; the paper area 834 × 955 pt, the
// overview's zoom 0.4974, one week 696.35 pt (docs/M7C.md S1).

@MainActor
final class InkCanvasSpanTests: XCTestCase {
    private var bed: SessionTestBed!
    private var faults: [String] = []
    private var savedOnFault: ((String) -> Void)!
    private var canvasSleeper: TestSleeper!
    private var rigs: [SpanRig] = []
    private var strokeClock: TimeInterval = 0

    private let w1026 = "w-2026-10-26"
    private let w1102 = "w-2026-11-02"
    private let w1109 = "w-2026-11-09"
    private let w1116 = "w-2026-11-16"
    private let w1123 = "w-2026-11-23"
    private let w1130 = "w-2026-11-30"
    private let w1207 = "w-2026-12-07"
    private let nov16 = DayKey(year: 2026, month: 11, day: 16)
    private let d1115 = "d-2026-11-15"
    private let d1116 = "d-2026-11-16"
    private let d1117 = "d-2026-11-17"
    private let pen = CanvasTool.ink(InkPresets.defaultPen)

    override func setUp() async throws {
        bed = try SessionTestBed("InkCanvasSpanTests")
        faults = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
        canvasSleeper = TestSleeper()
        rigs = []
        strokeClock = 0
    }

    override func tearDown() async throws {
        // The watches first lose their canvas (`detach` moves their generation on), then wake and end: a watch is
        // never woken with its canvas attached and a clock that does not move.
        for rig in rigs {
            rig.coordinator.detach()
        }
        await canvasSleeper?.advance()
        rigs = []
        XCTAssertEqual(faults, [], "no fault of the window's bookkeeping")
        SpanSession.onFault = savedOnFault
        bed?.tearDown()
        bed = nil
    }

    // MARK: The rig

    /// What the canvas told its owner.
    private final class SpanProbe {
        var viewports: [PaperViewport] = []
        /// `session.windowVersion` when each viewport arrived (the heading pairs the two, §3.6).
        var viewportVersions: [Int] = []
        var pageBudget: [(pageId: String, event: StrokeBudget.Event)] = []
        var pageCaps: [String] = []
        var oldBudget = 0
        var oldCaps = 0
        var stops: [SpanSession.Stop] = []
        var inkBounds = 0
    }

    @MainActor
    private struct SpanRig {
        let coordinator: InkCanvasView.Coordinator
        let container: InkCanvasContainerView
        let probe: SpanProbe
        let session: SpanSession
        var canvas: PKCanvasView { container.canvasView }
        var ledger: InkLedger { coordinator.ledger }
        var zoom: CGFloat { container.canvasView.zoomScale }
        /// One page on screen (pt).
        var page: CGFloat { session.plan.pageWidth * container.canvasView.zoomScale }
    }

    private static func paper(of layout: any PageLayout) -> PaperContent {
        if let week = layout as? WeekPageLayout { return .week(WeekPaperContent(layout: week)) }
        if let day = layout as? DayPageLayout { return .day(DayPaperContent(layout: day)) }
        fatalError("only weeks and days are joined")
    }

    /// The canvas as the screen (wave 3) builds it for a session.
    private func makeView(_ session: SpanSession, probe: SpanProbe, tool: CanvasTool, undoTrigger: Int = 0,
                          command: CanvasCommand? = nil, commandTrigger: Int = 0, isSheetOpen: Bool = false,
                          slidePages: Int = 0, slideTrigger: Int = 0, paper: PaperContent? = nil) -> InkCanvasView {
        let focus = session.layout.pages[min(max(0, session.focusSlot), session.layout.pages.count - 1)]
        let sleeper = canvasSleeper!
        let bed = bed!
        return InkCanvasView(
            layout: session.layout,
            paper: paper ?? Self.paper(of: focus),
            tool: tool,
            allowFinger: false,
            page: .constant(InkPage(pageId: session.layout.pageId)),
            initialScrollY: 0,
            onTap: { _, _ in },
            onInkBoundsChanged: { probe.inkBounds += 1 },
            undoTrigger: undoTrigger,
            redoTrigger: 0,
            command: command,
            commandTrigger: commandTrigger,
            onViewportChange: { [weak session] viewport in
                probe.viewports.append(viewport)
                probe.viewportVersions.append(session?.windowVersion ?? -1)
            },
            onStrokeBudget: { _ in probe.oldBudget += 1 },
            onGrowthCapReached: { probe.oldCaps += 1 },
            span: session,
            sleep: { await sleeper.sleep($0) },
            clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) },
            onPageStrokeBudget: { probe.pageBudget.append((pageId: $0, event: $1)) },
            onPageGrowthCapReached: { probe.pageCaps.append($0) },
            isSheetOpen: isSheetOpen,
            slidePages: slidePages,
            slideTrigger: slideTrigger,
            onSpanStop: { probe.stops.append($0) }
        )
    }

    /// The canvas attached to its container as `makeUIView` does, laid out once in the paper area and settled.
    private func attach(_ session: SpanSession, tool: CanvasTool? = nil, width: CGFloat = 834, height: CGFloat = 955) async -> SpanRig {
        let probe = SpanProbe()
        let view = makeView(session, probe: probe, tool: tool ?? pen)
        let coordinator = InkCanvasView.Coordinator(parent: view)
        let container = InkCanvasContainerView(paperView: PaperView(content: view.paper), canvasView: InkBandCanvasView())
        coordinator.attach(container)
        container.frame = CGRect(x: 0, y: 0, width: width, height: height)
        container.layoutSubviews()
        await settle()
        let rig = SpanRig(coordinator: coordinator, container: container, probe: probe, session: session)
        rigs.append(rig)
        return rig
    }

    /// `update(from:)` with the rig's session and these inputs.
    private func update(_ rig: SpanRig, tool: CanvasTool? = nil, undoTrigger: Int = 0, command: CanvasCommand? = nil,
                        commandTrigger: Int = 0, isSheetOpen: Bool = false, slidePages: Int = 0, slideTrigger: Int = 0,
                        paper: PaperContent? = nil) {
        rig.coordinator.update(from: makeView(rig.session, probe: rig.probe, tool: tool ?? rig.coordinator.parent.tool,
                                              undoTrigger: undoTrigger, command: command, commandTrigger: commandTrigger,
                                              isSheetOpen: isSheetOpen, slidePages: slidePages, slideTrigger: slideTrigger,
                                              paper: paper))
    }

    /// The queued main-actor work (the next-turn deliveries, the inbox's arrival, the sink, the prefetch's turns).
    private func settle(_ turns: Int = 24) async {
        for _ in 0..<turns {
            await Task.yield()
        }
    }

    // MARK: Pages and strokes

    /// A week session around 11/16 (or a day session of `radius` around it) whose pages are read, `stored` written
    /// to the store first.
    private func open(_ kind: PageKind = .week, radius: Int? = nil, number: Int = 1, stored: [InkPage] = []) async throws -> SpanSession {
        for page in stored {
            try bed.store.save(page)
        }
        let session = bed.session(kind, focus: nov16, number: number, radius: radius)
        await session.prefetch()
        return session
    }

    /// A page with a short grid stroke for each id, at (x, y + 60 i) of the grid (cell-relative).
    private func page(_ pageId: String, _ ids: [String], x: CGFloat = 300, y: CGFloat = 400) -> InkPage {
        var page = InkPage.empty(pageId: pageId)
        for (i, id) in ids.enumerated() {
            page.add(bed.stroke(id, cell: .grid, x: x, y: y + CGFloat(i) * 60, t: 1_790_000_001_000 + i))
        }
        return page
    }

    /// `count` strokes in a cell no layout has (counted by the budget, never drawn), as `InkCanvasViewTests` does.
    private func budgetPage(_ pageId: String, count: Int) -> InkPage {
        var page = InkPage.empty(pageId: pageId)
        let point = InkPoint(x: 1, y: 1, dtMs: 0, sizeW: 2, sizeH: 2, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571)
        for i in 0..<count {
            page.add(InkStroke(id: "budget-\(i)", cell: CellKey(raw: "zz-budget"), tool: .pen, color: "#1f2937",
                               t: 1_790_000_000_000 + i, points: [point]))
        }
        return page
    }

    /// A pen stroke through `points` (band lu), each with its own creation date (its own fingerprint).
    private func makeStroke(through points: [CGPoint], nib: CGFloat = 3.5) -> PKStroke {
        strokeClock += 1
        let controlPoints = points.enumerated().map { i, p in
            PKStrokePoint(location: p, timeOffset: TimeInterval(i) * 0.01, size: CGSize(width: nib, height: nib),
                          opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: PKInk(.pen, color: .black),
                        path: PKStrokePath(controlPoints: controlPoints, creationDate: Date(timeIntervalSince1970: 1_790_000_000 + strokeClock)),
                        transform: .identity, mask: nil)
    }

    /// A short stroke whose bounds are centred near (x, y) of the band.
    private func shortStroke(at x: CGFloat, _ y: CGFloat) -> PKStroke {
        makeStroke(through: (0..<5).map { CGPoint(x: x - 20 + CGFloat($0) * 10, y: y + CGFloat($0 % 2)) })
    }

    /// A new stroke on the canvas, reported as PencilKit reports it.
    private func draw(_ stroke: PKStroke, on rig: SpanRig) {
        rig.canvas.drawing = PKDrawing(strokes: rig.canvas.drawing.strokes + [stroke])
        rig.coordinator.canvasViewDrawingDidChange(rig.canvas)
    }

    /// The canvas's stroke of window name `name`, if it shows it.
    private func shown(_ name: String, on rig: SpanRig) -> PKStroke? {
        rig.canvas.drawing.strokes.first { rig.ledger.id(of: $0) == name }
    }

    /// Where each stroke the canvas shows is on the screen (pt): its render bounds × zoom − the offset.
    private func screenRects(_ rig: SpanRig) -> [String: CGRect] {
        var out: [String: CGRect] = [:]
        let zoom = rig.zoom
        let offset = rig.canvas.contentOffset
        for pk in rig.canvas.drawing.strokes {
            guard let name = rig.ledger.id(of: pk) else { continue }
            let r = pk.renderBounds
            out[name] = CGRect(x: r.minX * zoom - offset.x, y: r.minY * zoom - offset.y, width: r.width * zoom, height: r.height * zoom)
        }
        return out
    }

    /// The band x (lu) of a window page's left edge.
    private func origin(_ pageId: String, _ session: SpanSession, file: StaticString = #filePath, line: UInt = #line) -> CGFloat {
        guard let x = session.origin(ofPage: pageId) else {
            XCTFail("\(pageId) is not in the window", file: file, line: line)
            return 0
        }
        return x
    }

    /// The window's cell rect of `cell` on `pageId`.
    private func cell(_ cell: CellKey, of pageId: String, _ session: SpanSession, file: StaticString = #filePath, line: UInt = #line) -> CGRect {
        guard let rect = session.layout.cells[SpanName.prefixed(cell, page: pageId)] else {
            XCTFail("no \(cell.raw) on \(pageId)", file: file, line: line)
            return .zero
        }
        return rect
    }

    /// The paper moved by `pages` page widths as a finger leaves it (no end of the movement told), the focus
    /// following on the next turn.
    private func scroll(_ rig: SpanRig, pages: CGFloat) async {
        rig.canvas.contentOffset.x += pages * rig.page
        rig.coordinator.scrollViewDidScroll(rig.canvas)
        await settle()
    }

    private func touch(_ rig: SpanRig) {
        rig.coordinator.canvasViewDidBeginUsingTool(rig.canvas)
    }

    private func lift(_ rig: SpanRig) {
        rig.coordinator.canvasViewDidEndUsingTool(rig.canvas)
    }

    private func pageIds(of span: PaperSpan?) -> [String] {
        span?.pages.map { $0.layout.pageId } ?? []
    }

    // MARK: §10.2 row L — the twelve

    /// §3.6 ずらしの手順: the paper moved one week to the right and stopped; the window shifts (11/09 … 12/07) and nothing on
    /// the screen moves — every stroke the canvas showed before is where it was (0.5 pt), x went back by exactly one week
    /// (696.35 pt), the paper is the new window's in the same turn, the band has no side margin, and the viewport reaches
    /// the owner in that very turn with the new `windowVersion` (版つき). The page that left takes its strokes out of the
    /// ledger. Without the x correction (`windowShift`) every stroke moves a week; without the paper of the window the
    /// paper is a page off; without `deliverViewportNow` the viewport comes a turn later.
    func testShiftKeepsVisibleStrokesInPlace() async throws {
        let session = try await open(stored: [page(w1102, ["a"]), page(w1109, ["b", "c"]), page(w1116, ["d", "e"]), page(w1123, ["f", "g"])])
        let rig = await attach(session)
        XCTAssertEqual(rig.zoom, 0.4974, accuracy: 1e-4)
        XCTAssertEqual(rig.page, 696.35, accuracy: 0.05)
        XCTAssertEqual(rig.canvas.contentInset.left, 0, "the band has no side margin")
        XCTAssertEqual(rig.canvas.contentInset.right, 0)
        XCTAssertEqual(rig.canvas.contentOffset.x, 2.5 * rig.page - 417, accuracy: 0.5, "the focus week opens in the middle")
        XCTAssertEqual(pageIds(of: rig.container.paperView.span), [w1102, w1109, w1116, w1123, w1130], "the window's paper")
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 7)

        await scroll(rig, pages: 1)
        XCTAssertEqual(session.focusPageId, w1123, "the focus followed the middle of the screen")
        let before = screenRects(rig)
        XCTAssertEqual(before.count, 7)
        let x = rig.canvas.contentOffset.x
        let version = session.windowVersion
        let delivered = rig.probe.viewports.count

        XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .done)
        // The same turn: nothing awaited since the shift.
        XCTAssertEqual(session.pageIds, [w1109, w1116, w1123, w1130, w1207])
        XCTAssertGreaterThan(session.windowVersion, version)
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion, "the canvas took the window")
        XCTAssertEqual(rig.canvas.contentOffset.x, x - rig.page, accuracy: 0.5, "x went back by one week")
        XCTAssertEqual(rig.canvas.contentInset.left, 0)
        XCTAssertEqual(pageIds(of: rig.container.paperView.span), session.pageIds, "the paper is the new window's")
        XCTAssertEqual(rig.probe.viewports.count, delivered + 1, "the viewport in the same turn")
        XCTAssertEqual(rig.probe.viewports.last?.offsetX ?? .nan, rig.canvas.contentOffset.x, accuracy: 0.001)
        XCTAssertEqual(rig.probe.viewportVersions.last, session.windowVersion, "with the new window's version")
        let after = screenRects(rig)
        for (name, rect) in before where !name.hasPrefix(w1102) {
            guard let moved = after[name] else {
                XCTFail("\(name) is no longer shown")
                continue
            }
            XCTAssertEqual(moved.minX, rect.minX, accuracy: 0.5, name)
            XCTAssertEqual(moved.minY, rect.minY, accuracy: 0.5, name)
            XCTAssertEqual(moved.width, rect.width, accuracy: 0.5, name)
        }
        XCTAssertFalse(rig.ledger.page.strokes.keys.contains { $0.hasPrefix(w1102) }, "the page that left left the ledger")
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 6)
        XCTAssertEqual(rig.coordinator.spanShiftCount, 1)
    }

    /// §3.6 ずらす条件: with the focus a week off the window's middle, the window does not shift while the pen is on the
    /// paper, while the settle wait runs, during a fling, during a pinch, while a lasso selection is kept, or while a
    /// sheet covers the paper; each time the condition is gone it does (the end of the settle wait, the end of the
    /// deceleration, the stop after the pinch, the selection cleared, the sheet closed). Taking one condition out of
    /// `isAtRest` shifts the window in that state.
    func testNoShiftWhileDrawingSettlingFlingingPinchingSelectingOrSheet() async throws {
        let session = try await open(stored: [page(w1116, ["a"]), page(w1123, ["b"]), page(w1130, ["c"])])
        let rig = await attach(session)
        var shifts = 0
        func held(_ what: String, line: UInt = #line) {
            XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .busy, what, line: line)
            XCTAssertEqual(rig.coordinator.spanShiftCount, shifts, what, line: line)
            XCTAssertFalse(rig.coordinator.isAtRest, what, line: line)
        }
        func shifted(_ what: String, line: UInt = #line) {
            shifts += 1
            XCTAssertEqual(rig.coordinator.spanShiftCount, shifts, what, line: line)
            XCTAssertFalse(session.needsShift, what, line: line)
        }

        // Each hold is in place before the paper moves: a shift check left over from the phase before (the window
        // read after its shift) may run during the scroll's turns, and must find the canvas held.

        // The pen, then the settle wait after it.
        touch(rig)
        await scroll(rig, pages: 1)
        held("the pen on the paper")
        lift(rig)
        held("the settle wait")
        rig.coordinator.endSettleWaitForTesting()
        await settle()
        shifted("after the settle wait")

        // A fling (UIKit decelerating), then its end.
        rig.coordinator.spanMotionOverride = true
        await scroll(rig, pages: 1)
        held("a fling")
        rig.coordinator.spanMotionOverride = nil
        rig.coordinator.scrollViewDidEndDecelerating(rig.canvas)
        await settle()
        shifted("after the deceleration")

        // A pinch (or its bounce), then the stop after it.
        rig.coordinator.liveOverride = true
        await scroll(rig, pages: 1)
        held("a pinch")
        rig.coordinator.liveOverride = nil
        XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .done)
        shifted("after the pinch")

        // A lasso selection, then the selection cleared.
        await settle()
        let focus = session.focusPageId
        let grid = cell(.grid, of: focus, session)
        draw(shortStroke(at: grid.minX + 500, grid.minY + 700), on: rig)
        update(rig, tool: .lasso)
        let box = CGRect(x: grid.minX + 440, y: grid.minY + 650, width: 120, height: 100)
        rig.coordinator.overlay(rig.container.overlayView, didFinishLasso: [
            CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY),
            CGPoint(x: box.maxX, y: box.maxY), CGPoint(x: box.minX, y: box.maxY),
        ])
        await scroll(rig, pages: 1)
        held("a lasso selection")
        rig.coordinator.overlayDidTouchOutsideSelection(rig.container.overlayView)
        XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .done)
        shifted("after the selection was cleared")

        // A sheet, then the sheet closed.
        update(rig, tool: pen)
        update(rig, isSheetOpen: true)
        await scroll(rig, pages: 1)
        held("a sheet")
        update(rig, isSheetOpen: false)
        await settle()
        shifted("after the sheet closed")
    }

    /// §3.6, `InkCanvasViewTests.swift:2570`'s idea for the window: at every step of a shift — the history pruned, the
    /// ledger reloaded, the window's drawing made while the canvas still shows the old one ("built"), the drawing on
    /// the canvas, x moved — PencilKit reports a change (as it may, late). Nothing is compared: the ledger holds exactly
    /// the new window's strokes, nothing is tombstoned, no delta goes out. With `isApplyingDrawing` held only around the
    /// assignment (1.2.3's `setDrawing`), the "built" step takes the leaving week's strokes in as new strokes of the week
    /// now at its place, under new ids.
    func testShiftNeverComparesTheOldDrawingWithTheNewLedger() async throws {
        let session = try await open(stored: [page(w1102, ["a", "b"]), page(w1109, ["c"]), page(w1116, ["d"]), page(w1123, ["e"])])
        let rig = await attach(session, tool: .eraser)
        await settle()
        await scroll(rig, pages: 1)
        var steps: [String] = []
        rig.coordinator.spanShiftProbe = { step in
            steps.append(step)
            rig.coordinator.canvasViewDrawingDidChange(rig.canvas)
        }
        XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .done)
        rig.coordinator.spanShiftProbe = nil
        XCTAssertEqual(steps, ["pruned", "reloaded", "built", "drawn", "moved"])

        func check(_ what: String, line: UInt = #line) {
            let ledgerPage = rig.ledger.page
            let window = session.window.ledgerPage
            XCTAssertEqual(Set(ledgerPage.liveStrokeIds), Set(window.liveStrokeIds), "the window's strokes only (\(what))", line: line)
            XCTAssertEqual(Set(ledgerPage.deleted.keys), Set(window.deleted.keys), "nothing tombstoned (\(what))", line: line)
            XCTAssertEqual(ledgerPage.liveStrokeCount, 3, what, line: line)
            XCTAssertTrue(rig.ledger.journal.isEmpty, what, line: line)
            XCTAssertTrue(session.inbox.deltas.isEmpty, "no delta (\(what))", line: line)
            XCTAssertTrue(session.inbox.unrouted.isEmpty, what, line: line)
            XCTAssertEqual(rig.canvas.drawing.strokes.count, 3, what, line: line)
            XCTAssertFalse(rig.ledger.canUndo, "nothing was done (\(what))", line: line)
        }
        check("after the shift")
        rig.coordinator.canvasViewDrawingDidChange(rig.canvas)
        check("a late report on the new drawing")
        await settle()
        XCTAssertEqual(Set(bed.store.load(w1109).liveStrokeIds), ["c"], "nothing was written into 11/09")
    }

    /// §3.6 はじき (P-B5 ア): at the overview a fast release (1.0 pt/ms) turns exactly one week, the next week in the middle
    /// (both ways); a slow stop within 6 % of the screen's width (50 pt) of a week's edge lines the two up, one beyond
    /// it stays where UIKit stops it; a drag the directional lock kept vertical is left alone; the one page's canvas
    /// never touches the target. The numbers are `SpanPlan.flingTarget`'s (KitChecks); without the delegate UIKit's
    /// proposal stands.
    func testFlingStopsAtTheNextPage() async throws {
        let session = try await open()
        let rig = await attach(session)
        let page = rig.page
        let x0 = rig.canvas.contentOffset.x
        XCTAssertEqual(x0, 2.5 * page - 417, accuracy: 0.5)

        func release(from start: CGFloat, to x: CGFloat, velocity: CGFloat, proposed: CGFloat) -> CGPoint {
            rig.canvas.contentOffset.x = start
            rig.coordinator.scrollViewWillBeginDragging(rig.canvas)
            rig.canvas.contentOffset.x = x
            var target = CGPoint(x: proposed, y: 12)
            rig.coordinator.scrollViewWillEndDragging(rig.canvas, withVelocity: CGPoint(x: velocity, y: 0), targetContentOffset: &target)
            return target
        }
        let right = release(from: x0, to: x0 + 40, velocity: 1.0, proposed: x0 + 900)
        XCTAssertEqual(right.x, 3.5 * page - 417, accuracy: 0.01, "the next week in the middle")
        XCTAssertEqual(right.y, 12, "y is UIKit's")
        let left = release(from: x0, to: x0 - 40, velocity: -1.0, proposed: x0 - 900)
        XCTAssertEqual(left.x, 1.5 * page - 417, accuracy: 0.01, "the week before in the middle")
        XCTAssertEqual(left.x, session.plan.flingTarget(offsetX: x0 - 40, velocity: -1.0, zoom: rig.zoom, viewportWidth: 834, proposedX: x0 - 900),
                       accuracy: 0.001)
        let near = release(from: x0, to: 2 * page + 20, velocity: 0.1, proposed: 2 * page + 30)
        XCTAssertEqual(near.x, 2 * page, accuracy: 0.01, "30 pt from a week's edge: lined up with the screen's edge")
        let far = release(from: x0, to: 2 * page + 110, velocity: 0.1, proposed: 2 * page + 120)
        XCTAssertEqual(far.x, 2 * page + 120, accuracy: 0.01, "120 pt from the edge: where UIKit stops")
        let vertical = release(from: x0, to: x0, velocity: 0, proposed: x0 + 0.2)
        XCTAssertEqual(vertical.x, x0 + 0.2, accuracy: 0.001, "a vertical drag: x untouched")

        // The one page.
        let week = try XCTUnwrap(session.layout.pages[2] as? WeekPageLayout)
        let one = InkCanvasView(layout: week, paper: .week(WeekPaperContent(layout: week)), tool: pen, allowFinger: false,
                                page: .constant(InkPage(pageId: week.pageId)), initialScrollY: 0, onTap: { _, _ in },
                                onInkBoundsChanged: {}, undoTrigger: 0, redoTrigger: 0)
        let coordinator = InkCanvasView.Coordinator(parent: one)
        let container = InkCanvasContainerView(paperView: PaperView(content: one.paper))
        coordinator.attach(container)
        container.frame = CGRect(x: 0, y: 0, width: 834, height: 955)
        container.layoutSubviews()
        coordinator.scrollViewWillBeginDragging(container.canvasView)
        container.canvasView.contentOffset.x = 30
        var target = CGPoint(x: 77, y: 5)
        coordinator.scrollViewWillEndDragging(container.canvasView, withVelocity: CGPoint(x: 1.0, y: 0), targetContentOffset: &target)
        XCTAssertEqual(target, CGPoint(x: 77, y: 5), "the one page's fling is UIKit's")
        coordinator.detach()
    }

    /// D15, §3.3 1: a stroke across the boundary of 11/16 and 11/23 belongs to the page its bounds' centre is on (the
    /// half-open rule: the boundary itself is the right page's), with the owner page in front of its id; its delta
    /// reaches that page with the real id and the page's own cell, its points left of the cell kept (negative x, not
    /// cut); no name reaches no page. Without `ownerId` the ids are bare UUIDs: no delta, an unrouted name.
    func testNewStrokeOwnerIsTheCenterPage() async throws {
        let session = try await open()
        let rig = await attach(session)
        let boundary = origin(w1123, session)
        let y = cell(.grid, of: w1123, session).minY + 900

        func ownerOfNewStroke(_ stroke: PKStroke, line: UInt = #line) -> (page: String, delta: PageDelta)? {
            let before = session.inbox.deltas.count
            draw(stroke, on: rig)
            let deltas = Array(session.inbox.deltas.dropFirst(before))
            XCTAssertEqual(deltas.count, 1, line: line)
            XCTAssertTrue(session.inbox.unrouted.isEmpty, "every name reaches its page", line: line)
            guard let delta = deltas.first else { return nil }
            return (delta.pageId, delta)
        }

        // The centre 20 lu right of the boundary.
        let across = makeStroke(through: [CGPoint(x: boundary - 60, y: y), CGPoint(x: boundary + 20, y: y + 4), CGPoint(x: boundary + 100, y: y)])
        XCTAssertGreaterThan(StrokeGeometry.paperBounds(of: across).midX, boundary)
        let right = try XCTUnwrap(ownerOfNewStroke(across))
        XCTAssertEqual(right.page, w1123)
        let stroke = try XCTUnwrap(right.delta.added.first)
        XCTAssertFalse(stroke.id.contains("|"), "the real id")
        XCTAssertEqual(stroke.cell, .grid, "the page's own cell")
        XCTAssertTrue(stroke.points.contains { $0.x < 0 }, "the points left of the cell stay (§4.1)")
        XCTAssertTrue(rig.ledger.page.isLive(SpanName.prefixed(id: stroke.id, page: w1123)), "the window name: the owner in front")

        // The centre 20 lu left of it.
        let leftStroke = makeStroke(through: [CGPoint(x: boundary - 100, y: y + 50), CGPoint(x: boundary - 20, y: y + 54), CGPoint(x: boundary + 60, y: y + 50)])
        XCTAssertLessThan(StrokeGeometry.paperBounds(of: leftStroke).midX, boundary)
        XCTAssertEqual(ownerOfNewStroke(leftStroke)?.page, w1116)

        // On the boundary (as PencilKit's bounds put it): the right page when the centre is not left of it.
        let onIt = makeStroke(through: [CGPoint(x: boundary - 40, y: y + 100), CGPoint(x: boundary + 40, y: y + 100)])
        let midX = StrokeGeometry.paperBounds(of: onIt).midX
        XCTAssertEqual(midX, boundary, accuracy: 1)
        XCTAssertEqual(ownerOfNewStroke(onIt)?.page, midX >= boundary ? w1123 : w1116)
        XCTAssertEqual(session.layout.drop(center: CGPoint(x: boundary, y: y)), .keep(page: w1123, cell: .grid), "exactly on it: the right page")

        await settle()
        XCTAssertEqual(session.page(w1123)?.liveStrokeCount, midX >= boundary ? 2 : 1)
    }

    /// K-9, D21: the budget is the owner page's. 11/16 holds 19,000 strokes and 11/23 14,999 (in a cell no layout has, so
    /// none is drawn): a new stroke on 11/16 is taken off the canvas and `.full(19000)` names 11/16; one on 11/23 is
    /// taken in and `.many(15000)` names 11/23, once. The one page's notices are never called. Counting the window
    /// (34,000) refuses 11/23's stroke too.
    func testBudgetCountsTheOwnerPage() async throws {
        let session = try await open(stored: [budgetPage(w1116, count: 19_000), budgetPage(w1123, count: 14_999)])
        let rig = await attach(session)
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 0, "a cell no layout has is not drawn")
        XCTAssertEqual(InkCanvasView.budgetCount(ofPage: w1116, in: rig.ledger.page), 19_000)
        XCTAssertEqual(InkCanvasView.budgetCount(ofPage: w1123, in: rig.ledger.page), 14_999)

        let g16 = cell(.grid, of: w1116, session)
        draw(shortStroke(at: g16.minX + 300, g16.minY + 600), on: rig)
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 0, "taken off the canvas")
        XCTAssertEqual(InkCanvasView.budgetCount(ofPage: w1116, in: rig.ledger.page), 19_000)
        XCTAssertFalse(rig.ledger.canUndo)
        XCTAssertEqual(rig.probe.pageBudget.map { $0.pageId }, [w1116])
        XCTAssertEqual(rig.probe.pageBudget.map { $0.event }, [.full(19_000)])

        let g23 = cell(.grid, of: w1123, session)
        draw(shortStroke(at: g23.minX + 300, g23.minY + 600), on: rig)
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 1, "11/23 takes it")
        XCTAssertEqual(InkCanvasView.budgetCount(ofPage: w1123, in: rig.ledger.page), 15_000)
        XCTAssertEqual(rig.probe.pageBudget.map { $0.pageId }, [w1116, w1123])
        XCTAssertEqual(rig.probe.pageBudget.last?.event, .many(15_000))
        draw(shortStroke(at: g23.minX + 600, g23.minY + 600), on: rig)
        XCTAssertEqual(rig.probe.pageBudget.count, 2, "the notice once")
        await settle()
        XCTAssertEqual(rig.probe.oldBudget, 0, "the one page's notice is not the window's")
    }

    /// D15, M4C-25, K-9: a new stroke centred left of the band or right of it is taken off the canvas without a notice
    /// and never reaches the ledger or the inbox; one near a boundary inside the band stays. On a window of three days,
    /// one centred more than 6,000 lu below the top of the focus day's free memo is taken off with one notice naming
    /// that day; one above it stays. With `PaperGrowth.drop` on the band (whose prefixed cells it cannot read) the
    /// stroke below the cap is dropped as off the paper, without the notice.
    func testStrokeOutsideTheBandIsDropped() async throws {
        let session = try await open()
        let rig = await attach(session)
        let width = session.layout.size.width
        let y = cell(.grid, of: w1116, session).minY + 600
        draw(shortStroke(at: -30, y), on: rig)
        draw(shortStroke(at: width + 30, y), on: rig)
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 0, "both taken off the canvas")
        XCTAssertEqual(rig.ledger.page.liveStrokeCount, 0)
        XCTAssertTrue(session.inbox.deltas.isEmpty)
        let near = origin(w1123, session) - 30
        draw(shortStroke(at: near, y), on: rig)
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 1, "inside the band: kept")
        await settle()
        XCTAssertTrue(rig.probe.pageCaps.isEmpty)

        let days = try await open(.day, radius: 1, number: 2)
        XCTAssertEqual(days.pageIds, [d1115, d1116, d1117])
        let dayRig = await attach(days, width: 834, height: 951)
        let extra = cell(.extra, of: d1116, days)
        draw(shortStroke(at: extra.minX + 300, extra.minY + 6_050), on: dayRig)
        XCTAssertEqual(dayRig.canvas.drawing.strokes.count, 0, "below the cap: taken off")
        XCTAssertEqual(dayRig.ledger.page.liveStrokeCount, 0)
        await settle()
        XCTAssertEqual(dayRig.probe.pageCaps, [d1116], "one notice, the owner day's")
        draw(shortStroke(at: extra.minX + 300, extra.minY + 3_000), on: dayRig)
        XCTAssertEqual(dayRig.canvas.drawing.strokes.count, 1, "above it: kept")
        await settle()
        XCTAssertEqual(dayRig.probe.pageCaps, [d1116])
        XCTAssertEqual(dayRig.probe.oldCaps, 0)
    }

    /// §3.4 (a), (b): ↶ twice in one turn (two `update(from:)` before any yield) puts two deltas into the inbox in that
    /// turn, one stroke each; the session applies both (tombstones), saves them, and the safety net has nothing to
    /// recover. 1.2.3's `publishPage` (a next-turn delivery that the newer one supersedes) puts none.
    func testInboxTakesTwoUndosInOneTurn() async throws {
        let session = try await open()
        let rig = await attach(session)
        let g = cell(.grid, of: w1116, session)
        draw(shortStroke(at: g.minX + 200, g.minY + 500), on: rig)
        draw(shortStroke(at: g.minX + 400, g.minY + 500), on: rig)
        await settle()
        XCTAssertTrue(session.inbox.deltas.isEmpty, "the session took both strokes")
        XCTAssertEqual(session.page(w1116)?.liveStrokeCount, 2)
        let names = rig.ledger.page.liveStrokeIds

        update(rig, undoTrigger: 1)
        update(rig, undoTrigger: 2)
        let deltas = session.inbox.deltas
        XCTAssertEqual(deltas.count, 2, "two deltas in the same turn")
        XCTAssertEqual(deltas.map(\.pageId), [w1116, w1116])
        XCTAssertEqual(deltas.map(\.removed.count), [1, 1])
        XCTAssertTrue(rig.ledger.page.liveStrokeIds.isEmpty)

        session.drainInbox()
        XCTAssertEqual(session.page(w1116)?.liveStrokeCount, 0)
        XCTAssertEqual(Set(session.page(w1116)?.deleted.keys.map { $0 } ?? []), Set(names.map { SpanName.split($0)?.local ?? $0 }))
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertEqual(bed.store.load(w1116).liveStrokeCount, 0)
        XCTAssertEqual(bed.store.load(w1116).deleted.count, 2)
    }

    /// §3.4 (a): `detach()` puts what the ledger did last into the inbox before the delegate goes. (a) A stroke PencilKit
    /// finished but never told of reaches the ledger, the inbox and, after `saveAll`, the store (without `detachSpan` it
    /// is lost without a trace: in neither the ledger nor the window). (b) A stroke told of in the same turn as the
    /// detach is in the inbox before its arrival and saved.
    func testInboxTakesTheLastStrokeBeforeDetach() async throws {
        // (a)
        let session = try await open()
        let rig = await attach(session)
        let g = cell(.grid, of: w1123, session)
        rig.canvas.delegate = nil
        rig.canvas.drawing = PKDrawing(strokes: [shortStroke(at: g.minX + 300, g.minY + 300)])
        rig.canvas.delegate = rig.coordinator
        XCTAssertEqual(rig.ledger.page.liveStrokeCount, 0, "PencilKit has not told")
        rig.coordinator.detach()
        XCTAssertEqual(session.inbox.deltas.map(\.pageId), [w1123], "into the inbox at the detach")
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertEqual(bed.store.load(w1123).liveStrokeCount, 1, "saved")

        // (b)
        let second = bed.session(.week, focus: nov16, number: 2)
        await second.prefetch()
        let rig2 = await attach(second)
        let g2 = cell(.grid, of: w1109, second)
        draw(shortStroke(at: g2.minX + 300, g2.minY + 300), on: rig2)
        rig2.coordinator.detach()
        XCTAssertEqual(second.inbox.deltas.map(\.pageId), [w1109], "still in the inbox")
        XCTAssertEqual(second.saveAll(), [])
        XCTAssertEqual(bed.store.load(w1109).liveStrokeCount, 1)
    }

    /// §2.1, §3.6 the palm: `horizontalPanMayBegin` is false while a Pencil touches and for 0.5 s after it lifted (0.49
    /// false, 0.5 true), true with no Pencil, and true when the clock went back; `panMayBegin` asks it for a sideways
    /// start only (up and down as today). The window's canvas is an `InkBandCanvasView` whose pan asks, with the
    /// Pencil's lift timed by the touch observer; the one page's canvas stays a plain `PKCanvasView`.
    func testHorizontalPanMayBeginRules() async throws {
        let t0 = Date(timeIntervalSince1970: 1_790_000_000)
        XCTAssertEqual(InkCanvasView.palmHold, 0.5)
        XCTAssertFalse(InkCanvasView.horizontalPanMayBegin(pencilsDown: 1, lastPencilUp: nil, now: t0))
        XCTAssertFalse(InkCanvasView.horizontalPanMayBegin(pencilsDown: 2, lastPencilUp: t0.addingTimeInterval(-60), now: t0))
        XCTAssertTrue(InkCanvasView.horizontalPanMayBegin(pencilsDown: 0, lastPencilUp: nil, now: t0))
        XCTAssertFalse(InkCanvasView.horizontalPanMayBegin(pencilsDown: 0, lastPencilUp: t0, now: t0))
        XCTAssertFalse(InkCanvasView.horizontalPanMayBegin(pencilsDown: 0, lastPencilUp: t0, now: t0.addingTimeInterval(0.49)))
        XCTAssertTrue(InkCanvasView.horizontalPanMayBegin(pencilsDown: 0, lastPencilUp: t0, now: t0.addingTimeInterval(0.5)))
        XCTAssertTrue(InkCanvasView.horizontalPanMayBegin(pencilsDown: 0, lastPencilUp: t0.addingTimeInterval(10), now: t0), "the clock went back")

        let soon = t0.addingTimeInterval(0.2)
        XCTAssertFalse(InkCanvasView.panMayBegin(translation: CGPoint(x: 30, y: 5), velocity: .zero, pencilsDown: 0, lastPencilUp: t0, now: soon))
        XCTAssertTrue(InkCanvasView.panMayBegin(translation: CGPoint(x: 2, y: 30), velocity: .zero, pencilsDown: 1, lastPencilUp: nil, now: soon),
                      "up and down as today")
        XCTAssertFalse(InkCanvasView.panMayBegin(translation: .zero, velocity: CGPoint(x: -400, y: 10), pencilsDown: 1, lastPencilUp: nil, now: soon))
        XCTAssertTrue(InkCanvasView.panMayBegin(translation: .zero, velocity: CGPoint(x: 10, y: 400), pencilsDown: 1, lastPencilUp: nil, now: soon))
        XCTAssertFalse(InkCanvasView.panMayBegin(translation: .zero, velocity: .zero, pencilsDown: 1, lastPencilUp: nil, now: soon),
                       "no direction to tell: the rule")
        XCTAssertTrue(InkCanvasView.panMayBegin(translation: CGPoint(x: 30, y: 5), velocity: .zero, pencilsDown: 0, lastPencilUp: t0,
                                                now: t0.addingTimeInterval(0.6)))

        // The wiring.
        let session = try await open()
        let rig = await attach(session)
        let bandCanvas = try XCTUnwrap(rig.canvas as? InkBandCanvasView)
        let ask = try XCTUnwrap(bandCanvas.panMayBegin)
        let pan = UIPanGestureRecognizer(target: nil, action: nil)
        XCTAssertTrue(ask(pan), "no Pencil yet")
        rig.coordinator.touchObserved(.down(.pencil))
        XCTAssertFalse(ask(pan), "a Pencil on the paper")
        rig.coordinator.touchObserved(.up(.pencil))
        XCTAssertEqual(rig.coordinator.spanLastPencilUp, bed.now)
        XCTAssertFalse(ask(pan), "just lifted")
        bed.now = bed.now.addingTimeInterval(0.5)
        XCTAssertTrue(ask(pan), "0.5 s after the lift")
        XCTAssertEqual(rig.coordinator.spanRefusedPans, 2)

        let week = try XCTUnwrap(session.layout.pages[2] as? WeekPageLayout)
        let one = InkCanvasView(layout: week, paper: .week(WeekPaperContent(layout: week)), tool: pen, allowFinger: false,
                                page: .constant(InkPage(pageId: week.pageId)), initialScrollY: 0, onTap: { _, _ in },
                                onInkBoundsChanged: {}, undoTrigger: 0, redoTrigger: 0)
        let container = InkCanvasContainerView(paperView: PaperView(content: one.paper))
        XCTAssertTrue(type(of: container.canvasView) == PKCanvasView.self, "the one page keeps a plain PKCanvasView")
        let coordinator = InkCanvasView.Coordinator(parent: one)
        coordinator.attach(container)
        XCTAssertFalse(container.gestureRecognizers?.contains { $0 is InkBandPanGate } ?? false, "and no gate")
        XCTAssertTrue(rig.container.gestureRecognizers?.contains { $0 === rig.coordinator.spanPanGate } ?? false, "the band has the gate")
        coordinator.detach()
    }

    /// §3.6, §3.16: a stop no scroll-view call tells of (the paper moved a week, then nothing) is taken by the watch: it
    /// waits 0.5 s on the injected sleep, finds the paper moved 0.4 s before by the injected clock and waits again,
    /// and 0.5 s after the motion shifts the window. Without the watch the window stays until a stop is told; with a
    /// real sleep `TestSleeper` records nothing.
    func testWatchTimerFiresAfterHalfASecond() async throws {
        let session = try await open(stored: [page(w1123, ["a"])])
        let rig = await attach(session)
        XCTAssertEqual(InkCanvasView.shiftWatchDelay, 0.5)
        await scroll(rig, pages: 1)
        XCTAssertTrue(session.needsShift)
        XCTAssertEqual(canvasSleeper.recorded, [0.5], "one watch, waiting 0.5 s")
        XCTAssertEqual(canvasSleeper.waiting, 1)
        XCTAssertTrue(rig.coordinator.spanWatchRunning)

        bed.now = bed.now.addingTimeInterval(0.4)
        await canvasSleeper.advance()
        XCTAssertEqual(rig.coordinator.spanShiftCount, 0, "0.4 s after the motion: not yet")
        XCTAssertEqual(canvasSleeper.recorded, [0.5, 0.5], "it waits again")

        bed.now = bed.now.addingTimeInterval(0.1)
        await canvasSleeper.advance()
        XCTAssertEqual(rig.coordinator.spanShiftCount, 1, "0.5 s after the motion: shifted")
        XCTAssertEqual(session.pageIds.first, w1109)
        XCTAssertFalse(session.needsShift)
        XCTAssertFalse(rig.coordinator.spanWatchRunning, "the watch ended")
    }

    /// §3.6, D16, and the inputs of `PaperGrowthTests` / `InkCanvasViewTests.testDayExtraGrowthUsesTheTailPath` (:1168),
    /// `testCapNoticeWhenTheTailReachesItsLastStep` (:1386) and `testNewStrokesBeyondTheCapAreDropped` (:1348) on the one
    /// page (`span` nil: 1.2.3's path, where a window of one page is) and on a window of three days: a line at 5,984 lu
    /// of the free memo makes it 6,040 on the one page and on every day of the window alike (D16), by the light path
    /// (no new drawing); 5,600 asks nothing and 5,601 tells the owner day once; 6,098 is dropped with the notice; erasing
    /// the low line brings the memo back to 6,000 on every day (「消して縮むときは下げる」). Without the canvas's
    /// `relayoutPages` the memo does not grow; without the removal's request it does not shrink.
    func testGrowthTestsThroughOneAndThreePageSessions() async throws {
        // The one page (1.2.3's path).
        let now = bed.now
        func dayLayout(_ bottoms: [CellKey: CGFloat] = [:]) -> DayPageLayout {
            DayLayoutEngine.layout(DayLayoutInput(day: nov16, events: [], inkBottoms: bottoms, now: now, calendar: SessionTestBed.tokyo))
        }
        let plain = dayLayout()
        XCTAssertEqual(plain.extra.height, PaperSpec.growMax, accuracy: 0.01)
        var oneInkBounds = 0
        var oneCaps = 0
        let oneView = { (layout: DayPageLayout, page: InkPage) in
            InkCanvasView(layout: layout, paper: .day(DayPaperContent(layout: layout)), tool: self.pen, allowFinger: false,
                          page: .constant(page), initialScrollY: 0, onTap: { _, _ in }, onInkBoundsChanged: { oneInkBounds += 1 },
                          undoTrigger: 0, redoTrigger: 0, onGrowthCapReached: { oneCaps += 1 })
        }
        let one = InkCanvasView.Coordinator(parent: oneView(plain, InkPage.empty(pageId: plain.pageId)))
        let oneContainer = InkCanvasContainerView(paperView: PaperView(content: .day(DayPaperContent(layout: plain))))
        one.attach(oneContainer)
        oneContainer.frame = CGRect(x: 0, y: 0, width: 834, height: 951)
        oneContainer.layoutSubviews()
        await settle()
        oneContainer.canvasView.drawing = PKDrawing(strokes: [makeStroke(through: (0..<5).map {
            CGPoint(x: 300 + CGFloat($0) * 3, y: plain.extra.minY + 5_984 + CGFloat($0))
        })])
        one.canvasViewDrawingDidChange(oneContainer.canvasView)
        XCTAssertEqual(oneInkBounds, 1)
        XCTAssertEqual(oneCaps, 1, "5,990 leaves less than 400 lu below it: once")
        let grown = dayLayout(one.ledger.page.inkBottoms())
        XCTAssertEqual(grown.extra.height, 6_040, accuracy: 0.5)
        let oneBuilds = one.setDrawingCount
        one.update(from: oneView(grown, one.ledger.page))
        XCTAssertEqual(one.setDrawingCount, oneBuilds, "the one page's light path")
        XCTAssertEqual(oneContainer.canvasView.contentSize.height, grown.size.height * oneContainer.canvasView.zoomScale, accuracy: 0.5)
        one.detach()

        // The window of three days.
        let session = try await open(.day, radius: 1)
        XCTAssertEqual(session.pageIds, [d1115, d1116, d1117])
        let rig = await attach(session, width: 834, height: 951)
        let extra = cell(.extra, of: d1116, session)
        XCTAssertEqual(extra.height, PaperSpec.growMax, accuracy: 0.01)
        let builds = rig.coordinator.setDrawingCount
        let low = makeStroke(through: (0..<5).map { CGPoint(x: extra.minX + 300 + CGFloat($0) * 3, y: extra.minY + 5_984 + CGFloat($0)) })
        draw(low, on: rig)
        let lowName = try XCTUnwrap(rig.ledger.id(of: try XCTUnwrap(rig.canvas.drawing.strokes.first)))
        XCTAssertEqual(rig.probe.inkBounds, 1, "the owner hears of it as on the one page")
        XCTAssertEqual(rig.probe.pageCaps, [d1116], "as on the one page: once, naming the owner day")
        await settle()
        for id in session.pageIds {
            XCTAssertEqual(cell(.extra, of: id, session).height, grown.extra.height, accuracy: 0.5, "\(id): the window's floor (D16)")
        }
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion, "the canvas took the new layout")
        XCTAssertEqual(rig.coordinator.setDrawingCount, builds, "the light path")
        XCTAssertEqual(rig.canvas.contentSize.height, session.layout.size.height * rig.zoom, accuracy: 0.5)
        XCTAssertEqual(session.layout.size.height, grown.size.height, accuracy: 0.5)

        // ⑦: 5,600 asks nothing, 5,601 tells the owner day once (nib 4: the line's bottom is y + 2).
        let flat = { (x: CGFloat, y: CGFloat) in
            self.makeStroke(through: (0..<5).map { CGPoint(x: x + CGFloat($0) * 10, y: y) }, nib: 4)
        }
        draw(flat(extra.minX + 100, extra.minY + 5_598), on: rig)
        await settle()
        XCTAssertEqual(rig.probe.pageCaps, [d1116], "5,600: 400 lu left, nothing more")
        draw(flat(extra.minX + 500, extra.minY + 5_599), on: rig)
        await settle()
        XCTAssertEqual(rig.probe.pageCaps, [d1116, d1116], "5,601: once, the owner day")
        draw(flat(extra.minX + 500, extra.minY + 6_098), on: rig)
        await settle()
        XCTAssertEqual(rig.probe.pageCaps, [d1116, d1116, d1116], "6,098: dropped, with the notice")
        XCTAssertEqual(rig.ledger.page.liveStrokeCount, 3)
        XCTAssertEqual(rig.probe.oldCaps, 0)

        // Erasing the low line: the memo of every day comes back to 6,000.
        update(rig, tool: .eraser)
        let kept = rig.canvas.drawing.strokes.filter { rig.ledger.id(of: $0) != lowName }
        rig.canvas.drawing = PKDrawing(strokes: kept)
        rig.coordinator.canvasViewDrawingDidChange(rig.canvas)
        XCTAssertFalse(rig.ledger.page.isLive(lowName))
        await settle()
        for id in session.pageIds {
            XCTAssertEqual(cell(.extra, of: id, session).height, PaperSpec.growMax, accuracy: 0.5, "\(id): shrunk back")
        }
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion)
        XCTAssertEqual(rig.canvas.contentSize.height, session.layout.size.height * rig.zoom, accuracy: 0.5)
        XCTAssertEqual(oneCaps, 1)
    }

    // MARK: More of §3.6, §3.4

    /// §3.4 (a): while the pen is on the paper, an update from iCloud makes the session compose a window; the stroke the pen
    /// then finishes goes into the inbox after that window was composed. When the pen is up, the canvas does not take
    /// that window as it is (it lacks the stroke: the stroke would vanish from the screen and from ↶): the session
    /// composes again first. The stroke stays shown, undoable, and the update's stroke is there too.
    func testAWindowComposedDuringAStrokeIsRecomposedBeforeAdoption() async throws {
        let session = try await open()
        let rig = await attach(session)
        touch(rig)
        var remote = InkPage.empty(pageId: w1109)
        remote.add(bed.stroke("from-icloud", x: 200, y: 200))
        session.remoteUpdated(remote)
        await settle()
        let composed = session.windowVersion
        XCTAssertNotEqual(rig.coordinator.spanAppliedWindowVersion, composed, "not taken under the pen")

        let g = cell(.grid, of: w1116, session)
        let stroke = shortStroke(at: g.minX + 300, g.minY + 300)
        draw(stroke, on: rig)
        let name = try XCTUnwrap(rig.ledger.id(of: try XCTUnwrap(rig.canvas.drawing.strokes.last)))
        await settle()
        XCTAssertEqual(session.page(w1116)?.liveStrokeCount, 1, "the session has it")
        XCTAssertFalse(session.window.ledgerPage.isLive(name), "the window composed under the pen lacks it")
        lift(rig)
        rig.coordinator.endSettleWaitForTesting()
        XCTAssertGreaterThan(session.windowVersion, composed, "composed again before it was taken")
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion)
        XCTAssertTrue(rig.ledger.page.isLive(name), "the stroke stays in the ledger")
        XCTAssertNotNil(shown(name, on: rig), "and on the screen")
        XCTAssertTrue(rig.ledger.page.isLive(SpanName.prefixed(id: "from-icloud", page: w1109)), "the update's stroke too")
        XCTAssertTrue(rig.ledger.canUndo)
        update(rig, undoTrigger: 1)
        XCTAssertFalse(rig.ledger.page.isLive(name), "↶ takes it away")
    }

    /// §3.16 (約 24 pt): at the overview one finger moves 24 pt sideways (or 10 pt more up or down than sideways) before
    /// the band moves; a translation that is not finite never starts it. The gate holds only at the overview.
    func testOverviewPanStartNeeds24Points() async throws {
        XCTAssertEqual(InkCanvasView.overviewPanStart, 24)
        XCTAssertFalse(InkCanvasView.overviewPanMayStart(translation: CGSize(width: 23.9, height: 0)))
        XCTAssertTrue(InkCanvasView.overviewPanMayStart(translation: CGSize(width: -24, height: 3)))
        XCTAssertFalse(InkCanvasView.overviewPanMayStart(translation: CGSize(width: 0, height: 9.9)))
        XCTAssertTrue(InkCanvasView.overviewPanMayStart(translation: CGSize(width: 2, height: 10)))
        XCTAssertFalse(InkCanvasView.overviewPanMayStart(translation: CGSize(width: 12, height: 11)), "neither yet")
        XCTAssertFalse(InkCanvasView.overviewPanMayStart(translation: CGSize(width: CGFloat.nan, height: 0)))
        XCTAssertFalse(InkCanvasView.overviewPanMayStart(translation: CGSize(width: CGFloat.infinity, height: 0)))

        let session = try await open()
        let rig = await attach(session)
        let gate = try XCTUnwrap(rig.coordinator.spanPanGate)
        XCTAssertTrue(gate.holds(), "the overview")
        rig.canvas.zoomScale = rig.canvas.zoomScale * 2
        XCTAssertFalse(gate.holds(), "zoomed in: the pan begins as it does today")
    }

    /// §3.6 回転・Split View: the paper area turns landscape (1,210 × 615); once still, the window is decided anew (seven
    /// weeks, R = 3) around the focus week, which stays where it was on the screen; the session, the virtual page and ↶
    /// stay.
    func testRotationDecidesTheWindowAnewWhenStill() async throws {
        let session = try await open(stored: [page(w1116, ["a"])])
        let rig = await attach(session)
        let g = cell(.grid, of: w1116, session)
        draw(shortStroke(at: g.minX + 300, g.minY + 900), on: rig)
        XCTAssertTrue(rig.ledger.canUndo)
        let virtual = session.layout.pageId

        rig.container.frame = CGRect(x: 0, y: 0, width: 1_210, height: 615)
        rig.container.layoutSubviews()
        let focusX = origin(w1116, session) * rig.zoom - rig.canvas.contentOffset.x
        XCTAssertEqual(session.pageIds.count, 5, "not under the layout pass")
        await settle()
        XCTAssertEqual(session.pageIds, [w1026, w1102, w1109, w1116, w1123, w1130, w1207])
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion)
        XCTAssertEqual(origin(w1116, session) * rig.zoom - rig.canvas.contentOffset.x, focusX, accuracy: 0.5, "the focus week stays put")
        XCTAssertEqual(session.layout.pageId, virtual)
        XCTAssertTrue(rig.ledger.canUndo, "↶ stays")
        XCTAssertEqual(pageIds(of: rig.container.paperView.span), session.pageIds)
    }

    /// §3.6: when a page that leaves cannot be saved, the window does not shift and the canvas is as it was: the pages,
    /// the drawing, x and the paper; the watch ends (the next motion tries again).
    func testRefusedShiftLeavesTheCanvasAsItIs() async throws {
        let session = try await open()
        let rig = await attach(session)
        let g = cell(.grid, of: w1102, session)
        draw(shortStroke(at: g.minX + 300, g.minY + 300), on: rig)
        await settle()
        XCTAssertEqual(session.page(w1102)?.liveStrokeCount, 1)
        try bed.failSaves(of: w1102)
        await scroll(rig, pages: 1)
        let x = rig.canvas.contentOffset.x
        let builds = rig.coordinator.setDrawingCount
        let paper = rig.container.paperView.span
        XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .refused)
        XCTAssertEqual(rig.coordinator.spanRefusedShiftCount, 1)
        XCTAssertEqual(session.pageIds.first, w1102, "the window stays")
        XCTAssertEqual(rig.canvas.contentOffset.x, x, accuracy: 0.001)
        XCTAssertEqual(rig.coordinator.setDrawingCount, builds)
        XCTAssertEqual(rig.container.paperView.span, paper)
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 1)
        bed.allowSaves(of: w1102)
    }

    /// §3.6 ◀ ▶: each slide is exactly one week (696.35 pt at the overview) and the window shifts when it ends, nothing
    /// moving on the screen. A second press while the first one slides waits for it and its shift (from where the first
    /// was going, the band of five weeks has no room to bring the week after next to the middle), then slides one more
    /// week. `slideTrigger` slides once per change, on the next turn. UIKit's animation is stood in for
    /// (`spanSlideAnimation`): the test moves the band and tells the end, as UIKit would.
    func testArrowsSlideExactlyOnePage() async throws {
        let session = try await open()
        let rig = await attach(session)
        let x0 = rig.canvas.contentOffset.x
        rig.coordinator.spanSlideAnimation = { _, _ in }
        // Two presses in one turn.
        rig.coordinator.slide(byPages: 1)
        XCTAssertEqual(rig.coordinator.spanSlideTargetX ?? .nan, x0 + rig.page, accuracy: 0.01, "exactly one week")
        rig.coordinator.slide(byPages: 1)
        XCTAssertEqual(rig.coordinator.spanSlideTargetX ?? .nan, x0 + rig.page, accuracy: 0.01, "the second press waits")
        XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .busy, "no shift while it slides")
        // The slide ends where it was going; the window shifts; the second press slides.
        func endTheSlide(line: UInt = #line) async {
            guard let target = rig.coordinator.spanSlideTargetX else {
                XCTFail("no slide runs", line: line)
                return
            }
            rig.canvas.contentOffset = CGPoint(x: target, y: rig.canvas.contentOffset.y)
            rig.coordinator.scrollViewDidScroll(rig.canvas)
            rig.coordinator.scrollViewDidEndScrollingAnimation(rig.canvas)
            await settle()
        }
        await endTheSlide()
        XCTAssertEqual(session.pageIds.first, w1109, "the window shifted after the first slide")
        XCTAssertEqual(rig.coordinator.spanSlideTargetX ?? .nan, x0 + rig.page, accuracy: 0.01, "the second: one more week from the middle")
        await endTheSlide()
        XCTAssertNil(rig.coordinator.spanSlideTargetX)
        XCTAssertEqual(session.pageIds, [w1116, w1123, w1130, w1207, "w-2026-12-14"], "two weeks on")
        XCTAssertEqual(rig.canvas.contentOffset.x, x0, accuracy: 0.5, "the focus week back in the middle of the band")
        XCTAssertEqual(rig.coordinator.spanShiftCount, 2)

        // The owner's trigger, once per change, on the next turn (an animation that ends at once).
        rig.coordinator.spanSlideAnimation = { [weak coordinator = rig.coordinator] canvas, target in
            canvas.contentOffset = target
            coordinator?.scrollViewDidScroll(canvas)
            coordinator?.scrollViewDidEndScrollingAnimation(canvas)
        }
        update(rig, slidePages: -1, slideTrigger: 1)
        XCTAssertEqual(rig.canvas.contentOffset.x, x0, accuracy: 0.01, "not inside the update")
        await settle()
        XCTAssertEqual(session.pageIds, [w1109, w1116, w1123, w1130, w1207], "one week back")
        XCTAssertEqual(rig.canvas.contentOffset.x, x0, accuracy: 0.5)
        update(rig, slidePages: -1, slideTrigger: 1)
        await settle()
        XCTAssertEqual(session.pageIds.first, w1109, "the same trigger: nothing")
        XCTAssertEqual(rig.coordinator.spanShiftCount, 3)
    }

    /// §3.3 5, §3.4 削除の守り (b): the canvas loses a stroke while the tool is not the eraser: nothing is tombstoned and no
    /// delta goes out; once the pen is up the drawing is rebuilt from the ledger and the stroke is back.
    func testNonEraserRemovalRebuildsTheDrawing() async throws {
        let session = try await open(stored: [page(w1116, ["a", "b"])])
        let rig = await attach(session)
        let lost = SpanName.prefixed(id: "a", page: w1116)
        XCTAssertNotNil(shown(lost, on: rig))
        touch(rig)
        rig.canvas.drawing = PKDrawing(strokes: rig.canvas.drawing.strokes.filter { rig.ledger.id(of: $0) != lost })
        rig.coordinator.canvasViewDrawingDidChange(rig.canvas)
        XCTAssertTrue(rig.ledger.page.isLive(lost), "the ledger keeps it")
        XCTAssertTrue(session.inbox.deltas.isEmpty, "no removal goes out")
        XCTAssertNil(shown(lost, on: rig), "not rebuilt under the pen")
        lift(rig)
        rig.coordinator.endSettleWaitForTesting()
        XCTAssertNotNil(shown(lost, on: rig), "back once the pen is up")
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 2)
        await settle()
        XCTAssertEqual(session.page(w1116)?.liveStrokeCount, 2)
    }

    /// §3.5: an update from iCloud of a window page reaches the canvas (the sink, on the next turn): the ledger reloads the
    /// window keeping its history, the stroke from iCloud is drawn, and ↶ still takes the person's own stroke away.
    func testRemoteUpdateIsAdoptedKeepingHistory() async throws {
        let session = try await open()
        let rig = await attach(session)
        let g = cell(.grid, of: w1116, session)
        draw(shortStroke(at: g.minX + 300, g.minY + 300), on: rig)
        let own = try XCTUnwrap(rig.ledger.page.liveStrokeIds.first)
        await settle()
        var remote = InkPage.empty(pageId: w1123)
        remote.add(bed.stroke("from-icloud", x: 200, y: 200))
        session.remoteUpdated(remote)
        await settle()
        let fromICloud = SpanName.prefixed(id: "from-icloud", page: w1123)
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion)
        XCTAssertTrue(rig.ledger.page.isLive(fromICloud))
        XCTAssertNotNil(shown(fromICloud, on: rig))
        XCTAssertTrue(rig.ledger.canUndo, "the history is kept")
        update(rig, undoTrigger: 1)
        XCTAssertFalse(rig.ledger.page.isLive(own))
        XCTAssertTrue(rig.ledger.page.isLive(fromICloud))
        XCTAssertEqual(session.inbox.deltas.last?.removed.count, 1)
    }

    /// §3.6 (the critic's L-C8): a stroke PencilKit finished and has not told of when the window shifts is taken into the
    /// ledger first, so the shift's new drawing keeps it (and its delta reaches its page).
    func testAStrokeNotYetToldOfSurvivesTheShift() async throws {
        let session = try await open()
        let rig = await attach(session)
        await scroll(rig, pages: 1)
        let g = cell(.grid, of: w1123, session)
        rig.canvas.delegate = nil
        rig.canvas.drawing = PKDrawing(strokes: rig.canvas.drawing.strokes + [shortStroke(at: g.minX + 300, g.minY + 300)])
        rig.canvas.delegate = rig.coordinator
        XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .done)
        XCTAssertEqual(rig.ledger.page.liveStrokeCount, 1, "in the ledger")
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 1, "on the new drawing")
        XCTAssertEqual(session.page(w1123)?.liveStrokeCount, 1, "in its page")
    }

    /// §3.8, P-3 (the critic's L-C9): the joined path's paper is the window's alone; the `paper` the owner passes (the
    /// focus page's) is neither drawn nor swapped in, so a new focus never redraws the band.
    func testThePaperIsTheWindowsNotTheOwners() async throws {
        let session = try await open()
        let rig = await attach(session)
        let content = rig.container.paperView.content
        let span = rig.container.paperView.span
        let other = Self.paper(of: session.layout.pages[0])
        XCTAssertNotEqual(other, content)
        let builds = rig.coordinator.setDrawingCount
        update(rig, paper: other)
        await settle()
        XCTAssertEqual(rig.container.paperView.content, content)
        XCTAssertEqual(rig.container.paperView.span, span)
        XCTAssertEqual(rig.coordinator.setDrawingCount, builds)
        XCTAssertTrue(rig.coordinator.isAtRest, "nothing queued")
    }
}
