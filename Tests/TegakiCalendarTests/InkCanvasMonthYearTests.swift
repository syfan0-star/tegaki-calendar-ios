@_spi(SpanLedger) import InkModel
import Layout
import PencilKit
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

// 1.4.3 (docs/R1_4_3_CONTRACT.md §11.2 row Z, §3.4, §3.5, §4.6, §6.1, §6.2, §8.4 R3, 0g-16, 0g-17, 0g-26, 0g-27): the frozen
// canvas with a window of joined months. Since R3 (DATA_1_1's row 1) the canvas's paper of a window is
// `PaperSpan.window(for:focus:)`'s whatever the kind (`InkCanvasView.paperSpan`, called by `updatePaperSpan` alone), so a
// window of months has its paper — each month 1,400 lu wide beside the next — where 1.4.2 drew the focus page alone at x 0.
// The canvas is built as the frozen `InkCanvasSpanTests` builds it (TESTS_1_3: that file is not touched, so the parts of
// its rig and of `InkCanvasSpanZoomResetTests`' (TESTS_1_4_1) these tests need are copied here): `InkCanvasContainerView`
// with an `InkBandCanvasView`, `Coordinator.attach`, a `SpanSession` of the live `SyncEngine` of `SessionTestBed`, the
// canvas's 0.5 s watch on its own `TestSleeper` (never advanced before `tearDown`, so every shift here is one a test asks
// for with `shiftIfAtRest()`), the bed's fixed clock. 等倍 on the one page is built as the frozen `InkCanvasZoomResetTests`
// builds it.
//
// The year joins with D1y (§14.1): every expectation of the year is read from `SpanKinds.joined.contains(.year)`, so the
// fallback of 0g-3 (the month alone) needs no change here (§11.2).
//
// The months: Monday weeks, five months around 11/16/2026 (R = 2 on the 11-inch iPad in both orientations): 2026-09 …
// 2027-01. An empty month is 1,400 × 7,050 lu (six rows of 175 and the memo of 6,000). The form is `SpanSession.monthForm`
// (ア unless the owner picks イ or ウ, 0g-10); what holds only when the window lines its separator line up (ア, イ) or only
// when the months keep their own rows (ア, ウ) says so. The paper area: portrait 834 × 1,005 pt (the month's
// `SpanPlan.referenceViewport`, rounded down): open = fit = 834 / 1,400; landscape 1,210 × 640: open 640 / 1,050, fit
// 1,210 / 1,400.

@MainActor
final class InkCanvasMonthYearTests: XCTestCase {
    private var bed: SessionTestBed!
    private var faults: [String] = []
    private var savedOnFault: ((String) -> Void)!
    private var canvasSleeper: TestSleeper!
    private var rigs: [SpanRig] = []
    private var strokeClock: TimeInterval = 0

    private let sep = "m1-2026-09"
    private let oct = "m1-2026-10"
    private let nov = "m1-2026-11"
    private let dec = "m1-2026-12"
    private let jan = "m1-2027-01"
    private let feb = "m1-2027-02"
    private let y2023 = "y-2023"
    private let y2024 = "y-2024"
    private let y2025 = "y-2025"
    private let y2026 = "y-2026"
    private let y2027 = "y-2027"
    private let y2028 = "y-2028"
    private let y2029 = "y-2029"
    private let y2030 = "y-2030"
    private let nov16 = DayKey(year: 2026, month: 11, day: 16)
    private let pen = CanvasTool.ink(InkPresets.defaultPen)
    private let portrait = CGSize(width: 834, height: 1_005)
    private let landscape = CGSize(width: 1_210, height: 640)

    override func setUp() async throws {
        bed = try SessionTestBed("InkCanvasMonthYearTests")
        faults = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
        canvasSleeper = TestSleeper()
        rigs = []
        strokeClock = 0
    }

    override func tearDown() async throws {
        // As `InkCanvasSpanTests`: the watches first lose their canvas, then wake and end.
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

    // MARK: The rig (the joined path)

    /// What the canvas told its owner.
    private final class SpanProbe {
        var viewports: [PaperViewport] = []
        var stops: [SpanSession.Stop] = []
        var inkBounds = 0
        var ratios: [CGFloat] = []
        /// `onZoomFitChange` (1.4.1, §16.3.3): one with each ratio.
        var fits: [Bool] = []
        var zooming: [Bool] = []
        /// The screen's own wire of each report (`CalendarRootScreen`'s `onViewportChange: { paths.viewportArrived($0) }`).
        var onViewport: ((PaperViewport) -> Void)?
        /// The screen's own take of each stop in the turn the canvas tells of it (`CalendarRootScreen`'s `onSpanStop:
        /// spanStopped`; review F2: after every viewport the canvas reported before it).
        var onStop: ((SpanSession.Stop) -> Void)?
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
        /// The paper's window (`PaperView.span`, set by the canvas's `updatePaperSpan`).
        var paper: PaperSpan? { container.paperView.span }
    }

    /// The paper of one page, as the screen makes it (the month's and the year's words do not matter to the canvas).
    private static func paper(of layout: any PageLayout) -> PaperContent {
        if let month = layout as? MonthPageLayout {
            return .month(MonthPaperContent(layout: month, labels: month.dateLabels, bars: month.allDayBars, chips: month.timedChips,
                                            holidayNames: [:]))
        }
        if let year = layout as? YearPageLayout {
            return .year(YearPaperContent(layout: year, monthNames: (1...12).map { "\($0)" }))
        }
        if let week = layout as? WeekPageLayout { return .week(WeekPaperContent(layout: week)) }
        if let day = layout as? DayPageLayout { return .day(DayPaperContent(layout: day)) }
        fatalError("a page of the four kinds")
    }

    /// The canvas as the screen builds it for a session, with the press count `zoomResetTrigger` (the screen's `@State`),
    /// `initialFit` (the kind's stored fit) and `initialScrollX` (band lu; the screen's `bandStart`: the focus page's left
    /// edge at fit); `tool` and the ↶ ↷ counts `undoTrigger` / `redoTrigger` (the screen's `@State`, review TEST-1);
    /// `initialPaperOffset` (band lu; the screen's `ScreenPaths.shotPaperOffset`, D1y: the capped year's opening); 「今日」's
    /// `revealRect` and its count `revealTrigger` (the screen's `@State`; the lead's decision of 11/28: the landing's request).
    private func makeView(_ session: SpanSession, probe: SpanProbe, zoomResetTrigger: Int = 0, initialFit: Bool = false,
                          initialScrollX: CGFloat = 0, tool: CanvasTool? = nil, undoTrigger: Int = 0,
                          redoTrigger: Int = 0, initialPaperOffset: CGPoint? = nil, revealRect: CGRect? = nil,
                          revealTrigger: Int = 0) -> InkCanvasView {
        let focus = session.layout.pages[min(max(0, session.focusSlot), session.layout.pages.count - 1)]
        let sleeper = canvasSleeper!
        let bed = bed!
        return InkCanvasView(
            layout: session.layout,
            paper: Self.paper(of: focus),
            tool: tool ?? pen,
            allowFinger: false,
            page: .constant(InkPage(pageId: session.layout.pageId)),
            initialScrollY: 0,
            initialScrollX: initialScrollX,
            onTap: { _, _ in },
            onInkBoundsChanged: { probe.inkBounds += 1 },
            undoTrigger: undoTrigger,
            redoTrigger: redoTrigger,
            onViewportChange: {
                probe.viewports.append($0)
                probe.onViewport?($0)
            },
            initialPaperOffset: initialPaperOffset,
            revealRect: revealRect,
            revealTrigger: revealTrigger,
            onZoomRatioChange: { probe.ratios.append($0) },
            onZoomingChange: { probe.zooming.append($0) },
            span: session,
            sleep: { await sleeper.sleep($0) },
            clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) },
            onSpanStop: {
                probe.stops.append($0)
                probe.onStop?($0)
            },
            zoomResetTrigger: zoomResetTrigger,
            initialFit: initialFit,
            onZoomFitChange: { probe.fits.append($0) }
        )
    }

    /// The canvas attached to its container as `makeUIView` does, laid out once in the paper area and settled (the first
    /// layout's report stays in the probe; `onViewport` takes every report from the first, as the screen's wire does).
    private func attach(_ session: SpanSession, size: CGSize, initialFit: Bool = false, initialScrollX: CGFloat = 0,
                        initialPaperOffset: CGPoint? = nil, onViewport: ((PaperViewport) -> Void)? = nil) async -> SpanRig {
        let probe = SpanProbe()
        probe.onViewport = onViewport
        let view = makeView(session, probe: probe, initialFit: initialFit, initialScrollX: initialScrollX,
                            initialPaperOffset: initialPaperOffset)
        let coordinator = InkCanvasView.Coordinator(parent: view)
        let container = InkCanvasContainerView(paperView: PaperView(content: view.paper), canvasView: InkBandCanvasView())
        coordinator.attach(container)
        container.frame = CGRect(origin: .zero, size: size)
        container.layoutSubviews()
        await settle()
        let rig = SpanRig(coordinator: coordinator, container: container, probe: probe, session: session)
        rigs.append(rig)
        return rig
    }

    /// 等倍 pressed `trigger` times so far (the screen's SwiftUI update with that count), then the press's turn.
    private func press(_ rig: SpanRig, _ trigger: Int) async {
        rig.coordinator.update(from: makeView(rig.session, probe: rig.probe, zoomResetTrigger: trigger))
        await settle()
    }

    /// The queued main-actor work (the press's turn, the next-turn deliveries, the relayout, the prefetch's turns).
    private func settle(_ turns: Int = 24) async {
        for _ in 0..<turns {
            await Task.yield()
        }
    }

    /// A month session around 11/16 on the 11-inch iPad (or a session of `kind`) whose pages are read, `stored` written to
    /// the store first.
    private func open(_ kind: PageKind = .month, number: Int = 1, stored: [InkPage] = [],
                      orientation: SpanOrientation = .portrait) async throws -> SpanSession {
        for page in stored {
            try bed.store.save(page)
        }
        let session = bed.session(kind, focus: nov16, number: number, deviceClass: .iPad11, orientation: orientation)
        await session.prefetch()
        return session
    }

    /// A month page with a three-point stroke for each (id, cell, y): at x 50 of a day's cell or x 300 of the memo
    /// (cell-relative). `SessionTestBed.stroke` makes points y, y + 1, y + 2 with a 3.5 lu nib and `InkPoint` rounds x and y
    /// to 0.1 lu as it is made (1.0's data rule), so the stroke's bottom (`InkStroke.bottom`) is y + 2 rounded to 0.1, + 1.75:
    /// y + 3.75 for a y on the 0.1 grid, 388.05 for y 384.25 (its points 384.3, 385.3, 386.3). A day's row is
    /// max(175, that bottom + 12) lu tall (`MonthLayoutEngine.rowHeight`): 400.05 for y 384.25.
    private func page(_ pageId: String, _ strokes: [(id: String, cell: CellKey, y: CGFloat)]) -> InkPage {
        var page = InkPage.empty(pageId: pageId)
        for (i, s) in strokes.enumerated() {
            page.add(bed.stroke(s.id, cell: s.cell, x: s.cell == .memo ? 300 : 50, y: s.y, t: 1_790_000_001_000 + i))
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

    /// A new stroke on the canvas, reported as PencilKit reports it.
    private func draw(_ stroke: PKStroke, on rig: SpanRig) {
        rig.canvas.drawing = PKDrawing(strokes: rig.canvas.drawing.strokes + [stroke])
        rig.coordinator.canvasViewDrawingDidChange(rig.canvas)
    }

    /// A short stroke whose bounds are centred near (x, y) of the band (InkCanvasSpanTests' own).
    private func shortStroke(at x: CGFloat, _ y: CGFloat) -> PKStroke {
        makeStroke(through: (0..<5).map { CGPoint(x: x - 20 + CGFloat($0) * 10, y: y + CGFloat($0 % 2)) })
    }

    /// The window name of the stroke `draw` put last on the canvas (InkCanvasSpanTests' own).
    private func lastDrawn(on rig: SpanRig, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let stroke = try XCTUnwrap(rig.canvas.drawing.strokes.last, file: file, line: line)
        return try XCTUnwrap(rig.ledger.id(of: stroke), file: file, line: line)
    }

    /// The canvas's stroke of window name `name`, if it shows it (InkCanvasSpanTests' own).
    private func shown(_ name: String, on rig: SpanRig) -> PKStroke? {
        rig.canvas.drawing.strokes.first { rig.ledger.id(of: $0) == name }
    }

    /// `update(from:)` with the rig's session, `tool`, the ↶ ↷ counts and 「今日」's rect and count so far (the screen's SwiftUI
    /// update).
    private func update(_ rig: SpanRig, tool: CanvasTool? = nil, undoTrigger: Int = 0, redoTrigger: Int = 0,
                        revealRect: CGRect? = nil, revealTrigger: Int = 0) {
        rig.coordinator.update(from: makeView(rig.session, probe: rig.probe, tool: tool ?? rig.coordinator.parent.tool,
                                              undoTrigger: undoTrigger, redoTrigger: redoTrigger, revealRect: revealRect,
                                              revealTrigger: revealTrigger))
    }

    /// The eraser takes the canvas's stroke of window name `name` away, as PencilKit reports it (InkCanvasSpanTests' own;
    /// before any ↶, whose count it passes as 0).
    private func erase(_ name: String, on rig: SpanRig) {
        update(rig, tool: .eraser)
        rig.canvas.drawing = PKDrawing(strokes: rig.canvas.drawing.strokes.filter { rig.ledger.id(of: $0) != name })
        rig.coordinator.canvasViewDrawingDidChange(rig.canvas)
        update(rig, tool: pen)
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

    /// The window's month pages, left to right.
    private func months(_ layout: SpanLayout) -> [MonthPageLayout] {
        layout.pages.compactMap { $0 as? MonthPageLayout }
    }

    /// The window's month page `pageId`.
    private func month(_ pageId: String, _ session: SpanSession) -> MonthPageLayout? {
        months(session.layout).first { $0.pageId == pageId }
    }

    private func pageIds(of span: PaperSpan?) -> [String] {
        span?.pages.map { $0.layout.pageId } ?? []
    }

    /// A year page with a three-point stroke for each (id, month, day, y) at x 20 of the cell (cell-relative). As
    /// `page(_:_:)`: the stroke's bottom is y + 2 rounded to 0.1, + 1.75 (y + 3.75 for a y on the 0.1 grid; 88.05 for y
    /// 84.25, its points 84.3, 85.3, 86.3), and a row is min(400, max(60, 24, that bottom + 12)) lu
    /// (`YearLayoutEngine.rowHeight` with no lane): 100.05 for y 84.25, 60 for y 10 (bottom 13.75).
    private func yearPage(_ pageId: String, _ strokes: [(id: String, month: Int, day: Int, y: CGFloat)]) -> InkPage {
        var page = InkPage.empty(pageId: pageId)
        for (i, s) in strokes.enumerated() {
            page.add(bed.stroke(s.id, cell: .yearDay(month: s.month, day: s.day), x: 20, y: s.y, t: 1_790_000_002_000 + i))
        }
        return page
    }

    /// The window's year pages, left to right.
    private func years(_ layout: SpanLayout) -> [YearPageLayout] {
        layout.pages.compactMap { $0 as? YearPageLayout }
    }

    /// The 31 row heights a window of years has on every page (`SpanAlign.yearFloors`, §5.1): each page's row frames are
    /// asserted to be the first page's (the same tops and heights, so the same day runs on in one straight line), then the
    /// heights are returned.
    private func linedUpRows(_ session: SpanSession, _ step: String, file: StaticString = #filePath, line: UInt = #line) -> [CGFloat] {
        let pages = years(session.layout)
        guard let first = pages.first else {
            XCTFail("\(step): no year in the window", file: file, line: line)
            return []
        }
        XCTAssertEqual(first.rows.count, 31, "\(step): 31 rows", file: file, line: line)
        for page in pages.dropFirst() {
            XCTAssertEqual(page.rows.map(\.frame), first.rows.map(\.frame), "\(step): \(page.pageId)'s rows are \(first.pageId)'s",
                           file: file, line: line)
        }
        return first.rows.map(\.frame.height)
    }

    /// The top (lu) of row `day` (1…31) of a year whose 31 rows are `heights` tall.
    private func rowTop(_ day: Int, of heights: [CGFloat]) -> CGFloat {
        heights.prefix(day - 1).reduce(0, +)
    }

    /// Where the middle of `pageId` is on the screen (pt from the canvas's left edge).
    private func middle(of pageId: String, _ rig: SpanRig, file: StaticString = #filePath, line: UInt = #line) -> CGFloat {
        (origin(pageId, rig.session, file: file, line: line) + rig.session.plan.pageWidth / 2) * rig.zoom - rig.canvas.contentOffset.x
    }

    /// The paper moved by `pages` page widths as a finger leaves it (no end of the movement told), the focus following on
    /// the next turn.
    private func scroll(_ rig: SpanRig, pages: CGFloat) async {
        rig.canvas.contentOffset.x += pages * rig.page
        rig.coordinator.scrollViewDidScroll(rig.canvas)
        await settle()
    }

    /// The band x `mid` (lu) put in the middle of the screen with the paper's `y` (pt) at the top, as a finger leaves it,
    /// the focus following on the next turn.
    private func put(_ rig: SpanRig, mid: CGFloat, y: CGFloat = 0) async {
        rig.canvas.contentOffset = CGPoint(x: mid * rig.zoom - rig.container.bounds.width / 2, y: y)
        rig.coordinator.scrollViewDidScroll(rig.canvas)
        await settle()
    }

    /// The end-of-pinch path as UIKit drives it, without a pinch; its reports delivered and dropped.
    private func pinch(_ rig: SpanRig, to zoom: CGFloat) async {
        rig.coordinator.scrollViewWillBeginZooming(rig.canvas, with: nil)
        rig.canvas.setZoomScale(zoom, animated: false)
        rig.coordinator.scrollViewDidEndZooming(rig.canvas, with: nil, atScale: zoom)
        await settle()
        drop(rig)
    }

    /// The reports so far dropped, so a test collects only what it causes.
    private func drop(_ rig: SpanRig) {
        rig.probe.ratios.removeAll()
        rig.probe.fits.removeAll()
        rig.probe.zooming.removeAll()
    }

    /// A rotation as UIKit lays it out: the paper area takes `size`, then the queued work (the window decided anew at the
    /// stop the canvas asks for).
    private func turn(_ rig: SpanRig, to size: CGSize) async {
        rig.container.frame = CGRect(origin: .zero, size: size)
        rig.container.layoutSubviews()
        await settle()
    }

    // MARK: The rig (the one page)

    /// What a one-page canvas told its owner; `opening` keeps the first layout's own report.
    private final class PageProbe {
        var ratios: [CGFloat] = []
        var fits: [Bool] = []
        var opening: (ratios: [CGFloat], fits: [Bool]) = ([], [])
    }

    @MainActor
    private struct PageRig {
        let coordinator: InkCanvasView.Coordinator
        let container: InkCanvasContainerView
        let probe: PageProbe
        let view: (Int) -> InkCanvasView
        var canvas: PKCanvasView { container.canvasView }
    }

    /// A one-page canvas (`span` nil) of `layout`, as the frozen `InkCanvasZoomResetTests` builds it, laid out once at `size`
    /// and settled; the first layout's report is kept in `probe.opening` and dropped from the rest.
    private func onePage(_ layout: any PageLayout, size: CGSize, initialFit: Bool = false) async -> PageRig {
        let probe = PageProbe()
        let paper = Self.paper(of: layout)
        let make: (Int) -> InkCanvasView = { trigger in
            InkCanvasView(
                layout: layout,
                paper: paper,
                tool: .eraser,
                allowFinger: false,
                page: .constant(InkPage.empty(pageId: layout.pageId)),
                initialScrollY: 0,
                initialScrollX: 0,
                onTap: { _, _ in },
                onInkBoundsChanged: {},
                undoTrigger: 0,
                redoTrigger: 0,
                onZoomRatioChange: { probe.ratios.append($0) },
                zoomResetTrigger: trigger,
                initialFit: initialFit,
                onZoomFitChange: { probe.fits.append($0) }
            )
        }
        let coordinator = InkCanvasView.Coordinator(parent: make(0))
        let container = InkCanvasContainerView(paperView: PaperView(content: paper))
        coordinator.attach(container)
        container.frame = CGRect(origin: .zero, size: size)
        container.layoutSubviews()
        await settle()
        probe.opening = (probe.ratios, probe.fits)
        probe.ratios.removeAll()
        probe.fits.removeAll()
        return PageRig(coordinator: coordinator, container: container, probe: probe, view: make)
    }

    /// 等倍 pressed `trigger` times so far on a one-page canvas, then the press's turn.
    private func press(_ rig: PageRig, _ trigger: Int) async {
        rig.coordinator.update(from: rig.view(trigger))
        await settle()
    }

    /// The one page is at fit for the paper column it has now: the zoom vw / W, no margin at the sides, the paper's left edge
    /// on the screen's (UIKit puts offsets on the pixel grid, ± 0.5 pt) and the content exactly as wide as the screen.
    private func assertFit(_ rig: PageRig, _ kind: PageKind, _ step: String, line: UInt = #line) {
        let width = rig.container.bounds.width
        XCTAssertEqual(rig.canvas.zoomScale, width / ZoomPolicy.paperWidth(kind), accuracy: 1e-6, "\(step): fit", line: line)
        XCTAssertEqual(rig.canvas.contentInset.left, 0, accuracy: 1e-9, "\(step): no margin at the left", line: line)
        XCTAssertEqual(rig.canvas.contentInset.right, 0, accuracy: 1e-9, "\(step): no margin at the right", line: line)
        XCTAssertEqual(rig.canvas.contentOffset.x, 0, accuracy: 0.5, "\(step): the paper's left edge on the screen's", line: line)
        XCTAssertEqual(rig.canvas.contentSize.width, width, accuracy: 0.5, "\(step): one page as wide as the screen", line: line)
    }

    // MARK: Tests

    /// §3.4, §8.4 R3 (MZ1, MP1): a window of five months has the canvas's paper of the window — not nil, of the month, its
    /// months slot by slot with no all-day band, the focus month's slot, five pages of 1,400 lu — and it is
    /// `PaperSpan.window(for:focus:)`'s as the canvas takes it (`updatePaperSpan`'s focus is the session's slot). 1.4.2's
    /// body (weeks and days only) gave nil, and the paper drew the focus month alone at x 0. A window of years has its paper
    /// exactly when the year joins (`SpanKinds.joined`, D1y); until then nil, as `PaperSpan.window` says.
    func testTheCanvasPaperOfAWindowOfMonthsIsTheWindow() async throws {
        let session = try await open()
        let rig = await attach(session, size: portrait)
        XCTAssertEqual(session.pageIds, [sep, oct, nov, dec, jan])
        XCTAssertEqual(rig.zoom, 834.0 / 1400, accuracy: 1e-4, "open = fit on the portrait iPad")
        let paper = try XCTUnwrap(rig.paper, "R3: the canvas's paper of a window of months is the window")
        XCTAssertEqual(paper.kind, .month)
        XCTAssertEqual(pageIds(of: paper), session.pageIds, "every month of the window, slot by slot")
        XCTAssertEqual(paper.focus, session.focusSlot, "the focus month's slot")
        XCTAssertEqual(paper.focus, 2)
        XCTAssertTrue(paper.bands.isEmpty, "a month has no all-day band")
        XCTAssertEqual(paper.size.width, 5 * 1400, accuracy: 0.01, "five months side by side")
        XCTAssertEqual(paper, PaperSpan.window(for: session.layout, focus: session.focusSlot), "PaperSpan.window's, as the canvas takes it")

        let years = try await open(.year, number: 2)
        let yearRig = await attach(years, size: CGSize(width: 834, height: 984))
        let joinsYear = SpanKinds.joined.contains(.year)
        XCTAssertEqual(yearRig.paper != nil, joinsYear, "a window of years has its paper exactly when the year joins (SpanKinds.joined)")
        if joinsYear {
            XCTAssertEqual(yearRig.paper?.kind, .year)
            XCTAssertEqual(pageIds(of: yearRig.paper), years.pageIds)
            XCTAssertEqual(yearRig.paper?.bands.isEmpty, true, "a year has no all-day band")
            XCTAssertEqual(yearRig.paper, PaperSpan.window(for: years.layout, focus: years.focusSlot))
        } else {
            XCTAssertNil(PaperSpan.window(for: years.layout, focus: years.focusSlot), "the year does not join yet: one page's answer")
        }
    }

    /// §3.5 (0g-17; K's month branch of `PageScroll.scrollDelta`): November's 11/11 row is 400.05 lu (its stroke at y 384.25
    /// ends at 388.05, `page(_:_:)`), so its rows below differ from December's (its row 3 at 750.05 lu, December's at 525 with
    /// ア). With the top of the screen in November's row 3 (800 lu) and the middle of the screen moved to December, the window
    /// shifts (2026-10 … 2027-02): every stroke the canvas showed — in the grids and the memos — is where it was on the screen
    /// (0.5 pt), y stays, x went back by one month, and the paper is the new window's in the same turn; still so once February
    /// is read. The middle pages' answer (1.4.2's `scrollDelta`: December's row 3 against November's) would have moved them all
    /// by 225.05 lu.
    func testAShiftKeepsTheLinesOnScreenAcrossMonthsOfOtherRows() async throws {
        let session = try await open(stored: [
            page(oct, [("o-grid", .day(DayKey(year: 2026, month: 10, day: 14)), 60), ("o-memo", .memo, 200)]),
            page(nov, [("n-tall", .day(DayKey(year: 2026, month: 11, day: 11)), 384.25),
                       ("n-grid", .day(DayKey(year: 2026, month: 11, day: 18)), 60), ("n-memo", .memo, 200)]),
            page(dec, [("d-grid", .day(DayKey(year: 2026, month: 12, day: 16)), 60), ("d-memo", .memo, 200)]),
            page(jan, [("j-grid", .day(DayKey(year: 2027, month: 1, day: 13)), 60), ("j-memo", .memo, 200)]),
        ])
        let rig = await attach(session, size: portrait)
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 9)
        let november = try XCTUnwrap(month(nov, session))
        // y 384.25 is kept as 384.3 (`InkPoint`'s 0.1 lu): the bottom 386.3 + 1.75 = 388.05, the row 388.05 + 12.
        XCTAssertEqual(try XCTUnwrap(session.page(nov)?.inkBottoms()[.day(DayKey(year: 2026, month: 11, day: 11))]), 388.05,
                       accuracy: 0.001, "11/11's ink bottom")
        XCTAssertEqual(november.rows[2].frame.height, 400.05, accuracy: 0.01, "11/11's row: 400.05 lu")
        XCTAssertEqual(november.rows[3].frame.minY, 750.05, accuracy: 0.01)
        XCTAssertNotNil(rig.paper)

        rig.canvas.contentOffset.y = 800 * rig.zoom
        rig.coordinator.scrollViewDidScroll(rig.canvas)
        await settle()
        await scroll(rig, pages: 1)
        XCTAssertEqual(session.focusPageId, dec, "the focus followed the middle of the screen")
        let oldLayout = session.layout
        let x = rig.canvas.contentOffset.x
        let y = rig.canvas.contentOffset.y
        let topY = y / rig.zoom
        let before = screenRects(rig)
        XCTAssertEqual(before.count, 9)

        XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .done)
        // The same turn: nothing awaited since the shift.
        XCTAssertEqual(session.pageIds, [oct, nov, dec, jan, feb])
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion, "the canvas took the window")
        XCTAssertEqual(PageScroll.scrollDelta(old: oldLayout, new: session.layout, topVisibleY: topY), 0, accuracy: 0.001,
                       "November against itself")
        if SpanSession.monthForm != SpanAlign.MonthForm.rows {
            let band = try XCTUnwrap(oldLayout.band(atY: topY))
            let middles = try XCTUnwrap(session.layout.bandTop(band)) - XCTUnwrap(oldLayout.bandTop(band))
            XCTAssertEqual(middles, 525 - 750.05, accuracy: 0.01,
                           "the middle pages' rows differ (December's row 3 at 525, November's at 750.05): their answer would move y by 225.05 lu")
        }
        XCTAssertEqual(rig.canvas.contentOffset.x, x - rig.page, accuracy: 0.5, "x went back by one month")
        XCTAssertEqual(rig.canvas.contentOffset.y, y, accuracy: 0.5, "y stays")
        XCTAssertEqual(pageIds(of: rig.paper), session.pageIds, "the paper is the new window's, in the same turn")
        let after = screenRects(rig)
        for (name, rect) in before {
            guard let moved = after[name] else {
                XCTFail("\(name) is no longer shown")
                continue
            }
            XCTAssertEqual(moved.minX, rect.minX, accuracy: 0.5, name)
            XCTAssertEqual(moved.minY, rect.minY, accuracy: 0.5, name)
            XCTAssertEqual(moved.width, rect.width, accuracy: 0.5, name)
        }

        await settle()
        XCTAssertFalse(session.pageIds.contains { session.slots[$0]?.unread == true }, "February was read")
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion)
        let settled = screenRects(rig)
        for (name, rect) in before {
            XCTAssertEqual(settled[name]?.minY ?? .nan, rect.minY, accuracy: 0.5, "\(name), once February is read")
            XCTAssertEqual(settled[name]?.minX ?? .nan, rect.minX, accuracy: 0.5, "\(name), once February is read")
        }
        XCTAssertEqual(pageIds(of: rig.paper), session.pageIds)
    }

    /// §4.6, §3.3 (0g-16; MS8): on the landscape iPad September's 9/16 row is 400.05 lu and December's 12/16 row 250.05 (their
    /// strokes at y 384.25 and 234.25 end at 388.05 and 238.05, `page(_:_:)`), so the window's separator line is at 1,275.05 lu
    /// on every month (ア: September's grid; イ: the rows lined up) and the lowest zoom is 640 / 1,275.05, under the opening
    /// zoom 640 / 1,050. Pinched to it with November in the middle, the middle of the
    /// screen moved to December (a month of another grid) and the window shifts (2026-10 … 2027-02): September, the tallest
    /// grid, left. Right after the shift and again once the prefetch read February and composed the window anew
    /// (`.redecide`, read as `.shift` for a month), the separator line, the lowest zoom and the zoom are where they were.
    /// Lowering the floors at that `.redecide` (MS8) brings the line up to December's 1,125.05 and the zoom with it (the
    /// canvas's `applyBounds` raises a zoom under the new lowest). ウ lines nothing up, so its lowest zoom is the middle
    /// month's own and a shift may change it (§4.6): this test is ア's and イ's.
    func testTheLowestZoomStaysThroughAShiftAndThePrefetchAfterIt() async throws {
        try XCTSkipIf(SpanSession.monthForm == SpanAlign.MonthForm.none, "ウ: the lowest zoom follows the middle month (§4.6)")
        let session = try await open(stored: [
            page(sep, [("s-tall", .day(DayKey(year: 2026, month: 9, day: 16)), 384.25)]),
            page(dec, [("d-taller", .day(DayKey(year: 2026, month: 12, day: 16)), 234.25)]),
        ], orientation: .landscape)
        let rig = await attach(session, size: landscape)
        XCTAssertEqual(session.pageIds, [sep, oct, nov, dec, jan])
        let opening = 640.0 / 1050
        XCTAssertEqual(rig.zoom, opening, accuracy: 1e-4, "opens at the opening zoom")
        let separator = try XCTUnwrap(month(nov, session)).memo.minY
        XCTAssertEqual(separator, 1_275.05, accuracy: 0.01, "September's 400.05 lu row (5 × 175 + 388.05 + 12): the window's separator line")
        for page in months(session.layout) {
            XCTAssertEqual(page.memo.minY, separator, accuracy: 0.01, "\(page.pageId): the separator line lines up")
        }
        let lowest = rig.canvas.minimumZoomScale
        XCTAssertEqual(lowest, 640 / separator, accuracy: 1e-4, "the lowest zoom: the window's grid (§4.6)")
        XCTAssertLessThan(lowest, opening - 0.05)
        await pinch(rig, to: lowest)
        await put(rig, mid: origin(nov, session) + session.plan.pageWidth / 2)
        XCTAssertEqual(rig.zoom, lowest, accuracy: 1e-6, "at the lowest zoom")
        XCTAssertEqual(session.focusPageId, nov)

        await scroll(rig, pages: 1)
        XCTAssertEqual(session.focusPageId, dec, "the middle of the screen in December")
        XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .done)
        XCTAssertEqual(session.pageIds, [oct, nov, dec, jan, feb], "September, the tallest grid, left the window")
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion, "the canvas took the window")
        for page in months(session.layout) {
            XCTAssertEqual(page.memo.minY, separator, accuracy: 0.01, "\(page.pageId), right after the shift: the line stays")
        }
        XCTAssertEqual(rig.canvas.minimumZoomScale, lowest, accuracy: 1e-6, "right after the shift: the lowest zoom stays")
        XCTAssertEqual(rig.zoom, lowest, accuracy: 1e-6, "right after the shift: the zoom stays")
        XCTAssertTrue(session.pageIds.contains { session.slots[$0]?.unread == true }, "February waits for the prefetch")
        let shifted = session.windowVersion

        await settle(48)
        XCTAssertFalse(session.pageIds.contains { session.slots[$0]?.unread == true }, "the prefetch read February")
        XCTAssertGreaterThan(session.windowVersion, shifted, "and composed the window anew")
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion, "the canvas took it")
        for page in months(session.layout) {
            XCTAssertEqual(page.memo.minY, separator, accuracy: 0.01, "\(page.pageId), after the prefetch: the floors did not come down")
        }
        XCTAssertEqual(rig.canvas.minimumZoomScale, lowest, accuracy: 1e-6, "after the prefetch: the lowest zoom stays")
        XCTAssertEqual(rig.zoom, lowest, accuracy: 1e-6, "after the prefetch: the zoom stays (§4.6)")
    }

    /// §3.3, §3.4 (MZ1, MP1): a line written down November's 6th row (11/30; its centre in the cell, its bottom about 290 lu
    /// down) makes that row taller. The canvas asks the session to lay the window out again (`relayoutPages`), and in the
    /// new window only the 6th rows grew — November's, and with ア or イ every month's to the same line — and the separator
    /// line moved; rows 1–5 did not move. The canvas takes the window by its heavy path (the separator line moved) and
    /// `updatePaperSpan` puts the new window's paper in: not equal to the one before, equal to `PaperSpan.window`'s.
    func testALongerSixthRowMovesTheSeparatorAndRedrawsThePaper() async throws {
        let session = try await open()
        let rig = await attach(session, size: portrait)
        let before = session.layout
        let paperBefore = try XCTUnwrap(rig.paper)
        for page in months(before) {
            XCTAssertEqual(page.memo.minY, 1050, accuracy: 0.01, "\(page.pageId): empty, six rows of 175")
        }
        let builds = rig.coordinator.setDrawingCount
        let version = session.windowVersion
        let nov30 = DayKey(year: 2026, month: 11, day: 30)
        let target = cell(.day(nov30), of: nov, session)
        XCTAssertEqual(target.minY, 875, accuracy: 0.01, "11/30 is on November's 6th row (Monday weeks)")
        XCTAssertEqual(target.height, 175, accuracy: 0.01)
        draw(makeStroke(through: (0..<6).map { CGPoint(x: target.minX + 60 + CGFloat($0 % 2) * 4, y: target.minY + 20 + CGFloat($0) * 54) }),
             on: rig)
        await settle()

        XCTAssertGreaterThan(session.windowVersion, version, "the session laid the window out again")
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion, "the canvas took it")
        XCTAssertEqual(session.page(nov)?.liveStrokeCount, 1, "November has the line")
        let bottom = try XCTUnwrap(session.page(nov)?.inkBottoms()[.day(nov30)], "the line is 11/30's")
        let row = MonthLayoutEngine.rowHeight(laneCount: 0, maxChips: 0, inkBottom: bottom)
        XCTAssertGreaterThan(row, 250, "the 6th row grew")
        let aligns = SpanSession.monthForm != SpanAlign.MonthForm.none
        let after = months(session.layout)
        XCTAssertEqual(after.map(\.pageId), months(before).map(\.pageId))
        for (old, new) in zip(months(before), after) {
            for r in 0..<5 {
                XCTAssertEqual(new.rows[r].frame, old.rows[r].frame, "\(new.pageId): row \(r + 1) did not move")
            }
            if new.pageId == nov || aligns {
                XCTAssertEqual(new.rows[5].frame.height, row, accuracy: 0.01, "\(new.pageId): the 6th row grew")
                XCTAssertEqual(new.memo.minY, 875 + row, accuracy: 0.01, "\(new.pageId): the separator line moved")
            } else {
                XCTAssertEqual(new.memo.minY, old.memo.minY, accuracy: 0.01, "\(new.pageId): ウ, nothing lines up")
            }
        }
        XCTAssertGreaterThan(rig.coordinator.setDrawingCount, builds, "the separator line moved: the heavy path (§3.3)")
        let paperAfter = try XCTUnwrap(rig.paper)
        XCTAssertNotEqual(paperAfter, paperBefore, "the paper is drawn again (updatePaperSpan)")
        XCTAssertEqual(paperAfter, PaperSpan.window(for: session.layout, focus: session.focusSlot), "the new window's")
        if aligns {
            XCTAssertNotEqual(paperAfter.pages[3], paperBefore.pages[3], "December too, whose 6th row and separator line alone moved")
        }
    }

    /// §6.1, §6.2, §6.4 (0g-26; MS4): the month's 等倍 is fit on both paths. The joined month on the landscape iPad opens at
    /// 640 / 1,050; a press goes to fit (1,210 / 1,400, one month across) with the month under the middle of the screen edge
    /// to edge, the paper y in the middle of the screen kept, and reports the ratio fit / open and the fit state; the window
    /// does not shift. Opened with `initialFit` (the kind's stored fit) and the focus month's left edge, the joined month
    /// opens at fit, edge to edge, at its top (§6.4), the first layout reporting fit / open and the fit state; a press then
    /// does nothing. The one page (`span` nil) the same: a press goes to fit and `initialFit` opens at fit. The year on the
    /// one page follows fit exactly when it joins (`SpanKinds.joined`); until then 1.4.2's opening zoom (a press there does
    /// nothing, `initialFit` is not read).
    func testTheMonthsOneTimesIsFitOnBothPathsAndOpensAtFit() async throws {
        let opening = 640.0 / 1050
        let fit = 1210.0 / 1400

        let session = try await open(orientation: .landscape)
        let rig = await attach(session, size: landscape)
        XCTAssertEqual(rig.zoom, opening, accuracy: 1e-4, "the joined month opens at its opening zoom")
        XCTAssertEqual(middle(of: nov, rig), 605, accuracy: 1, "the focus month in the middle")
        drop(rig)
        let midY = (rig.canvas.contentOffset.y + 640.0 / 2) / rig.zoom
        await press(rig, 1)
        XCTAssertEqual(rig.zoom, fit, accuracy: 1e-6, "等倍: fit, one month across")
        XCTAssertEqual(rig.page, 1210, accuracy: 0.5)
        XCTAssertEqual(middle(of: nov, rig), 605, accuracy: 1, "the month under the middle of the screen, edge to edge")
        let maxY = max(0, rig.canvas.contentSize.height + rig.canvas.contentInset.bottom - 640)
        XCTAssertEqual(rig.canvas.contentOffset.y, min(max(0, midY * fit - 640.0 / 2), maxY), accuracy: 1,
                       "the paper y in the middle of the screen kept")
        XCTAssertEqual(rig.probe.ratios.count, 1, "reported once")
        XCTAssertEqual(rig.probe.ratios.first ?? 0, fit / opening, accuracy: 1e-3, "the ratio fit / open")
        XCTAssertEqual(rig.probe.fits, [true], "the fit state")
        XCTAssertEqual(rig.probe.zooming, [false])
        XCTAssertEqual(session.focusPageId, nov)
        XCTAssertEqual(rig.coordinator.spanShiftCount, 0, "the focus month is the window's middle: no shift")
        XCTAssertEqual(rig.probe.viewports.last?.zoom ?? 0, fit, accuracy: 1e-6, "the heading follows")

        let second = try await open(number: 2, orientation: .landscape)
        let opened = await attach(second, size: landscape, initialFit: true, initialScrollX: origin(nov, second))
        XCTAssertEqual(opened.zoom, fit, accuracy: 1e-6, "initialFit: opens at fit")
        XCTAssertEqual(middle(of: nov, opened), 605, accuracy: 1, "the focus month edge to edge")
        XCTAssertEqual(opened.canvas.contentOffset.y, 0, accuracy: 0.5, "at the top of the month (§6.4)")
        XCTAssertEqual(opened.probe.ratios.count, 1, "the first layout's report")
        XCTAssertEqual(opened.probe.ratios.first ?? 0, fit / opening, accuracy: 1e-3, "the ratio fit / open")
        XCTAssertEqual(opened.probe.fits, [true], "the fit state")
        await press(opened, 1)
        XCTAssertEqual(opened.probe.ratios.count, 1, "at fit, edge to edge: a press does nothing")
        XCTAssertEqual(middle(of: nov, opened), 605, accuracy: 1)

        let november = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 11), events: [], inkBottoms: [:],
                                                                 now: bed.now, calendar: SessionTestBed.tokyo))
        let one = await onePage(november, size: landscape)
        XCTAssertEqual(one.canvas.zoomScale, opening, accuracy: 1e-4, "the one page opens at its opening zoom")
        XCTAssertEqual(one.probe.opening.fits, [false])
        await press(one, 1)
        assertFit(one, .month, "the one page, pressed")
        XCTAssertEqual(one.probe.ratios.count, 1)
        XCTAssertEqual(one.probe.ratios.first ?? 0, fit / opening, accuracy: 1e-3, "the one page: the ratio fit / open")
        XCTAssertEqual(one.probe.fits, [true], "the one page: the fit state")
        let oneOpened = await onePage(november, size: landscape, initialFit: true)
        assertFit(oneOpened, .month, "the one page, opened with initialFit")
        XCTAssertEqual(oneOpened.probe.opening.ratios.first ?? 0, fit / opening, accuracy: 1e-3)
        XCTAssertEqual(oneOpened.probe.opening.fits, [true])

        let joinsYear = SpanKinds.joined.contains(.year)
        let year = YearLayoutEngine.layout(YearLayoutInput(year: 2026, events: [], inkBottoms: [:], now: bed.now, calendar: SessionTestBed.tokyo))
        let yearArea = CGSize(width: 834, height: 984)
        let yearOpen = 984.0 / 1860
        let yearFit = 834.0 / 1400
        let yearPage = await onePage(year, size: yearArea)
        XCTAssertEqual(yearPage.canvas.zoomScale, yearOpen, accuracy: 1e-4, "the year opens at its opening zoom")
        await press(yearPage, 1)
        if joinsYear {
            assertFit(yearPage, .year, "the joined year's one page, pressed")
            XCTAssertEqual(yearPage.probe.ratios.first ?? 0, yearFit / yearOpen, accuracy: 1e-3)
            XCTAssertEqual(yearPage.probe.fits, [true])
        } else {
            XCTAssertEqual(yearPage.canvas.zoomScale, yearOpen, accuracy: 1e-9, "the year not joined: its opening zoom, as 1.4.2")
            XCTAssertEqual(yearPage.probe.ratios, [], "at its opening zoom nothing is reported")
            XCTAssertEqual(yearPage.probe.fits, [])
        }
        let yearOpened = await onePage(year, size: yearArea, initialFit: true)
        XCTAssertEqual(yearOpened.canvas.zoomScale, joinsYear ? yearFit : yearOpen, accuracy: 1e-4, "the year reads initialFit when it joins")
        XCTAssertEqual(yearOpened.probe.opening.fits, [joinsYear])
    }

    /// §6.4's first row, §16.3.3 of 1.4.1 (MS4): on the portrait iPad the month opens at fit already (open = fit = 834 /
    /// 1,400). A press moves nothing and takes the fit state only (one report, ratio 1). The state shows when the iPad turns:
    /// landscape goes to fit (1,210 / 1,400, one month across, the focus month edge to edge; without the state 1.4's rule keeps
    /// the opening zoom 640 / 1,050), portrait again to 834 / 1,400; the focus stays and a turn reports nothing.
    func testAtFitTheMonthFollowsAChangeOfWidth() async throws {
        let session = try await open()
        let rig = await attach(session, size: portrait)
        let portraitFit = 834.0 / 1400
        XCTAssertEqual(rig.zoom, portraitFit, accuracy: 1e-6, "portrait: open = fit")
        XCTAssertEqual(middle(of: nov, rig), 417, accuracy: 1)
        drop(rig)
        let before = rig.canvas.contentOffset
        await press(rig, 1)
        XCTAssertEqual(rig.zoom, portraitFit, accuracy: 1e-9, "nothing moves")
        XCTAssertEqual(rig.canvas.contentOffset.x, before.x, accuracy: 0.001)
        XCTAssertEqual(rig.canvas.contentOffset.y, before.y, accuracy: 0.001)
        XCTAssertEqual(rig.probe.ratios.count, 1, "the fit state taken: reported once")
        XCTAssertEqual(rig.probe.ratios.first ?? 0, 1, accuracy: 1e-6, "ratio 1")
        XCTAssertEqual(rig.probe.fits, [true])
        XCTAssertEqual(rig.probe.zooming, [false])

        await turn(rig, to: landscape)
        XCTAssertEqual(rig.zoom, 1210.0 / 1400, accuracy: 1e-6, "landscape: the new fit, not the opening zoom 640 / 1,050")
        XCTAssertEqual(rig.page, 1210, accuracy: 0.5, "landscape: one month across")
        XCTAssertEqual(middle(of: nov, rig), 605, accuracy: 1, "landscape: the month edge to edge")
        XCTAssertEqual(session.focusPageId, nov, "landscape: the focus stays")
        await turn(rig, to: portrait)
        XCTAssertEqual(rig.zoom, portraitFit, accuracy: 1e-6, "portrait again: fit")
        XCTAssertEqual(middle(of: nov, rig), 417, accuracy: 1, "portrait again: the month edge to edge")
        XCTAssertEqual(session.focusPageId, nov)
        XCTAssertEqual(rig.probe.ratios.count, 1, "the press's report only: a turn reports nothing")
        XCTAssertEqual(rig.probe.fits, [true])
    }

    /// §6.1 (MS4): a pinch ends the month's fit state. The landscape month pressed to fit, then pinched to 0.75: the pinch's
    /// own report is its ratio (0.75 / open) and the fit state off, with the zooming flag on and off. Turned to portrait and
    /// back, the month keeps 1.4's absolute zoom (the handwriting keeps its size), not fit; a turn reports nothing.
    func testAPinchEndsTheMonthsFitState() async throws {
        let session = try await open(orientation: .landscape)
        let rig = await attach(session, size: landscape)
        let opening = rig.zoom
        XCTAssertEqual(opening, 640.0 / 1050, accuracy: 1e-4)
        drop(rig)
        await press(rig, 1)
        XCTAssertEqual(rig.zoom, 1210.0 / 1400, accuracy: 1e-6, "pressed: fit")
        XCTAssertEqual(rig.probe.fits, [true])
        drop(rig)

        rig.coordinator.scrollViewWillBeginZooming(rig.canvas, with: nil)
        rig.canvas.setZoomScale(0.75, animated: false)
        rig.coordinator.scrollViewDidEndZooming(rig.canvas, with: nil, atScale: 0.75)
        await settle()
        XCTAssertEqual(rig.zoom, 0.75, accuracy: 1e-6)
        XCTAssertEqual(rig.probe.ratios.count, 1, "the pinch's report")
        XCTAssertEqual(rig.probe.ratios.first ?? 0, 0.75 / opening, accuracy: 1e-3, "the pinch's ratio")
        XCTAssertEqual(rig.probe.fits, [false], "the fit state is over")
        XCTAssertEqual(rig.probe.zooming, [true, false])
        await put(rig, mid: origin(nov, session) + session.plan.pageWidth / 2)

        await turn(rig, to: portrait)
        XCTAssertEqual(rig.zoom, 0.75, accuracy: 1e-6, "portrait: the absolute zoom stays, not fit 834 / 1,400")
        await turn(rig, to: landscape)
        XCTAssertEqual(rig.zoom, 0.75, accuracy: 1e-6, "landscape again: the absolute zoom stays, not fit 1,210 / 1,400")
        XCTAssertEqual(rig.probe.ratios.count, 1, "a turn reports nothing")
        XCTAssertEqual(rig.probe.fits, [false])
    }

    // MARK: ↶ ↷ and iCloud across months (§9.1, §9.5; review TEST-1)

    /// §9.1 (review TEST-1): one history for the window, whatever the kind. A line written in December's memo while November
    /// is the focus (the neighbour month of the window, its cell December's own) is saved to December; ↶ takes it away — its
    /// delta December's, the file without it, November untouched — and ↷ puts it back, saved again. A tombstoned id never
    /// comes back (1.0's rule, `InkLedger.perform`; the frozen `InkLedgerTests.testEraseMakesTombstoneAndUndoRestoresClone`),
    /// so ↷ re-adds the line as a copy under a fresh name, its cell's owner's (`SpanSession.ownerId(for:)`, 1.3's §3.3 1):
    /// December's again, in December's memo, with the same points.
    func testUndoAndRedoOfALineInTheNeighbouringMonthsMemo() async throws {
        let session = try await open()
        let rig = await attach(session, size: portrait)
        XCTAssertEqual(session.focusPageId, nov)
        let memo = cell(.memo, of: dec, session)
        draw(shortStroke(at: memo.minX + 300, memo.minY + 200), on: rig)
        let written = try lastDrawn(on: rig)
        XCTAssertTrue(written.hasPrefix(dec), "December's line")
        XCTAssertEqual(rig.ledger.page.strokes[written]?.cell, SpanName.prefixed(.memo, page: dec), "in December's memo")
        let writtenPoints = try XCTUnwrap(rig.ledger.page.strokes[written]).points
        XCTAssertTrue(rig.ledger.canUndo)
        await settle()
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertEqual(bed.live(dec).count, 1)
        XCTAssertEqual(bed.live(nov).count, 0)

        update(rig, undoTrigger: 1)
        XCTAssertFalse(rig.ledger.page.isLive(written), "↶ takes the line away")
        XCTAssertNil(shown(written, on: rig))
        XCTAssertEqual(session.inbox.deltas.map(\.pageId), [dec], "December's delta")
        XCTAssertTrue(session.inbox.unrouted.isEmpty)
        XCTAssertTrue(rig.ledger.canRedo)
        await settle()
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertEqual(bed.live(dec).count, 0, "December's file without it")

        update(rig, undoTrigger: 1, redoTrigger: 1)
        XCTAssertFalse(rig.ledger.page.isLive(written), "the name ↶ tombstoned stays tombstoned")
        let back = rig.ledger.page.liveStrokes
        XCTAssertEqual(back.count, 1, "↷ puts the line back")
        let redone = try XCTUnwrap(back.first)
        XCTAssertNotEqual(redone.id, written, "as a copy under a fresh name")
        XCTAssertEqual(SpanName.split(redone.id)?.page, dec, "December's name")
        XCTAssertEqual(redone.cell, SpanName.prefixed(.memo, page: dec), "in December's memo")
        XCTAssertEqual(redone.points, writtenPoints, "the same line")
        XCTAssertNotNil(shown(redone.id, on: rig))
        XCTAssertEqual(session.inbox.deltas.map(\.pageId), [dec], "↷'s delta December's")
        XCTAssertTrue(session.inbox.unrouted.isEmpty)
        XCTAssertFalse(rig.ledger.canRedo)
        await settle()
        XCTAssertEqual(session.saveAll(), [])
        let local = try XCTUnwrap(SpanName.split(redone.id)?.local)
        XCTAssertEqual(bed.live(dec), [local], "December's file with it again, under its new name")
        XCTAssertNotNil(bed.store.load(dec).deleted[try XCTUnwrap(SpanName.split(written)?.local)], "its first name tombstoned in the file")
        XCTAssertEqual(bed.live(nov).count, 0, "November untouched")
    }

    /// §9.1 (review TEST-1; `pruneHistory`, InkCanvasSpanTests' week rows): a line written on 10/14 and erased, then a line on
    /// 12/16. The window shifts twice to the right: after the first (2026-10 … 2027-02) October is still in and its steps
    /// stay; after the second (2026-11 … 2027-03) October left, saved as it went, and its steps went with it. ↶ takes
    /// December's line away (its delta December's) and there is nothing more to undo; a second ↶ puts nothing into the
    /// inbox and writes nothing into October, whose file stays as it was saved (its line erased, not made again).
    func testUndoAfterTwoShiftsWritesNoMonthOutsideTheWindow() async throws {
        let session = try await open()
        let rig = await attach(session, size: portrait)
        let mar = "m1-2027-03"
        let october = cell(.day(DayKey(year: 2026, month: 10, day: 14)), of: oct, session)
        draw(shortStroke(at: october.minX + 100, october.minY + 80), on: rig)
        let erased = try lastDrawn(on: rig)
        XCTAssertTrue(erased.hasPrefix(oct))
        erase(erased, on: rig)
        XCTAssertFalse(rig.ledger.page.isLive(erased), "erased")
        let december = cell(.day(DayKey(year: 2026, month: 12, day: 16)), of: dec, session)
        draw(shortStroke(at: december.minX + 100, december.minY + 80), on: rig)
        let later = try lastDrawn(on: rig)
        XCTAssertTrue(later.hasPrefix(dec))
        await settle()
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertEqual(bed.store.load(oct).liveStrokeCount, 0)
        XCTAssertEqual(bed.store.load(oct).deleted.count, 1)
        XCTAssertEqual(bed.live(dec).count, 1)

        await scroll(rig, pages: 1)
        XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .done)
        XCTAssertEqual(session.pageIds, [oct, nov, dec, jan, feb], "the first shift: October still in")
        XCTAssertTrue(rig.ledger.canUndo)
        await settle(48)
        await scroll(rig, pages: 1)
        XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .done)
        XCTAssertEqual(session.pageIds, [nov, dec, jan, feb, mar], "the second shift: October left")
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion, "the canvas took the window")
        XCTAssertTrue(rig.ledger.canUndo, "December's step stays")

        update(rig, undoTrigger: 1)
        XCTAssertFalse(rig.ledger.page.isLive(later), "↶ takes December's line away")
        XCTAssertEqual(session.inbox.deltas.map(\.pageId), [dec])
        XCTAssertFalse(rig.ledger.canUndo, "October's steps left with it")
        update(rig, undoTrigger: 2)
        XCTAssertEqual(session.inbox.deltas.map(\.pageId), [dec], "a second ↶ puts no delta of October")
        XCTAssertTrue(session.inbox.unrouted.isEmpty)
        XCTAssertFalse(rig.ledger.page.strokes.keys.contains { $0.hasPrefix(oct) }, "nothing of October in the ledger")
        await settle()
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertEqual(bed.store.load(oct).liveStrokeCount, 0, "October as it was saved when it left: its line erased")
        XCTAssertEqual(bed.store.load(oct).deleted.count, 1)
        XCTAssertEqual(bed.live(dec).count, 0, "December's ↶ is saved")
    }

    /// §9.5 (review TEST-1; InkCanvasSpanTests.testRemoteUpdateIsAdoptedKeepingHistory's month): an update from iCloud of
    /// December, the neighbour month of the window, reaches the canvas (the sink, on the next turn): the canvas takes the
    /// window, the line from iCloud is live and drawn in December's 12/16 cell of the band, and ↶ still takes the person's
    /// own line on November away, the line from iCloud left alone.
    func testARemoteUpdateOfTheNeighbouringMonthReachesTheCanvas() async throws {
        let session = try await open()
        let rig = await attach(session, size: portrait)
        let november = cell(.day(DayKey(year: 2026, month: 11, day: 18)), of: nov, session)
        draw(shortStroke(at: november.minX + 100, november.minY + 80), on: rig)
        let own = try lastDrawn(on: rig)
        XCTAssertTrue(own.hasPrefix(nov))
        await settle()

        let dec16 = DayKey(year: 2026, month: 12, day: 16)
        var remote = InkPage.empty(pageId: dec)
        remote.add(bed.stroke("from-icloud", cell: .day(dec16), x: 50, y: 60))
        session.remoteUpdated(remote)
        await settle()
        let fromICloud = SpanName.prefixed(id: "from-icloud", page: dec)
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion, "the canvas took the window")
        XCTAssertTrue(rig.ledger.page.isLive(fromICloud))
        let drawn = try XCTUnwrap(shown(fromICloud, on: rig), "drawn on the canvas")
        let bounds = drawn.renderBounds
        XCTAssertTrue(cell(.day(dec16), of: dec, session).contains(CGPoint(x: bounds.midX, y: bounds.midY)),
                      "in December's 12/16 cell of the band")
        XCTAssertTrue(rig.ledger.page.isLive(own))
        XCTAssertTrue(rig.ledger.canUndo, "the history is kept")
        update(rig, undoTrigger: 1)
        XCTAssertFalse(rig.ledger.page.isLive(own))
        XCTAssertTrue(rig.ledger.page.isLive(fromICloud))
        XCTAssertEqual(session.inbox.deltas.last?.pageId, nov)
        XCTAssertEqual(session.inbox.deltas.last?.removed.count, 1)
    }

    // MARK: The joined years (D1y; §3.3, §3.5, §4.6, §5.1, §5.4, §6.1, 0g-16, 0g-21, 0g-23, 0g-26)
    //
    // Five years around 11/16/2026 on the portrait 11-inch iPad (2024 … 2028; the year's paper area 834 × 984, the year's
    // `SpanPlan.referenceViewport`: open 984 / 1,860, fit 834 / 1,400), seven on the landscape one (2023 … 2029; 1,210 × 640:
    // open 640 / 1,860, fit 1,210 / 1,400). An empty year is 1,400 × 1,860 lu (31 rows of 60). Each test is the year's when
    // the year joins (`SpanKinds.joined`); in the fallback of 0g-3 it checks the one page's answer and ends (§11.2).

    /// §3.5, §5.1 (0g-17, 0g-21): a window of years shares its rows (`SpanAlign.yearFloors`), so a shift between years of
    /// other natural rows moves nothing on the screen (`PageScroll.scrollDelta` keeps the middle page's answer for the year:
    /// the rows are the window's, so it is 0). 2024's 6/20 row is 200.05 lu, 2026's 11/11 row 100.05 and 2027's 3/5 row
    /// 150.05 (strokes at y 184.25, 84.25 and 134.25 end at 188.05, 88.05 and 138.05, `yearPage(_:_:)`): all five years have
    /// those three rows. Zoomed in to 1 with the top of the screen at 900 lu (row 13; the middle pages' own rows put row 13
    /// at 760.05 on 2026 and 810.05 on 2027) and the middle of the screen moved from 2026 to 2027, the window shifts (2025 …
    /// 2029): 2024, the year of the tallest row, left with its two lines; the rows stay (`.shift` never lowers); every other
    /// line is where it was on the screen (0.5 pt), y stays, x went back by one year, and the paper is the new window's in
    /// the same turn; still so once 2029 is read (the prefetch's `.redecide`, read as `.shift`).
    func testAShiftKeepsTheLinesOnScreenAcrossYearsOfOtherRows() async throws {
        let session = try await open(.year, stored: [
            yearPage(y2024, [("a-tall", 6, 20, 184.25), ("a-low", 9, 3, 10)]),
            yearPage(y2025, [("b-low", 2, 3, 10)]),
            yearPage(y2026, [("c-tall", 11, 11, 84.25), ("c-low", 11, 16, 10)]),
            yearPage(y2027, [("d-tall", 3, 5, 134.25), ("d-low", 1, 25, 10)]),
            yearPage(y2028, [("e-low", 7, 28, 10)]),
        ])
        guard SpanKinds.joined.contains(.year) else {
            XCTAssertNil(PaperSpan.window(for: session.layout, focus: session.focusSlot), "the year does not join: one page at a time")
            return
        }
        let rig = await attach(session, size: CGSize(width: 834, height: 984))
        XCTAssertEqual(session.pageIds, [y2024, y2025, y2026, y2027, y2028])
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 8)
        // y 184.25 is kept as 184.3 (`InkPoint`'s 0.1 lu): the bottom 186.3 + 1.75 = 188.05, the row 188.05 + 12.
        let tall = try XCTUnwrap(session.page(y2024)?.inkBottoms()[.yearDay(month: 6, day: 20)])
        XCTAssertEqual(tall, 188.05, accuracy: 0.001, "6/20's ink bottom")
        let rows = linedUpRows(session, "opened")
        XCTAssertEqual(rows[19], YearLayoutEngine.rowHeight(laneCount: 0, inkBottom: tall), accuracy: 0.001)
        XCTAssertEqual(rows[19], 200.05, accuracy: 0.01, "row 20: 2024's 6/20 on every year")
        XCTAssertEqual(rows[10], 100.05, accuracy: 0.01, "row 11: 2026's 11/11 on every year")
        XCTAssertEqual(rows[4], 150.05, accuracy: 0.01, "row 5: 2027's 3/5 on every year")
        for (r, height) in rows.enumerated() where ![4, 10, 19].contains(r) {
            XCTAssertEqual(height, 60, accuracy: 0.001, "row \(r + 1)")
        }
        let own2026 = try XCTUnwrap(session.yearNaturals[y2026], "2026's own rows")
        let own2027 = try XCTUnwrap(session.yearNaturals[y2027], "2027's own rows")
        XCTAssertEqual(rowTop(13, of: own2026), 760.05, accuracy: 0.01, "2026's own row 13 (its 11/11 above)")
        XCTAssertEqual(rowTop(13, of: own2027), 810.05, accuracy: 0.01, "2027's own row 13 (its 3/5 above)")
        XCTAssertNotNil(rig.paper)

        await pinch(rig, to: 1)
        await put(rig, mid: origin(y2026, session) + session.plan.pageWidth / 2, y: 900)
        XCTAssertEqual(rig.zoom, 1, accuracy: 1e-6)
        XCTAssertEqual(session.focusPageId, y2026)
        let y = rig.canvas.contentOffset.y
        let topY = y / rig.zoom
        XCTAssertEqual(topY, 900, accuracy: 0.5)
        XCTAssertEqual(years(session.layout).first?.row(atY: topY), 13, "the top of the screen in row 13")
        await scroll(rig, pages: 1)
        XCTAssertEqual(session.focusPageId, y2027, "the focus followed the middle of the screen")
        let oldLayout = session.layout
        let x = rig.canvas.contentOffset.x
        let before = screenRects(rig)
        XCTAssertEqual(before.count, 8)

        XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .done)
        // The same turn: nothing awaited since the shift.
        XCTAssertEqual(session.pageIds, [y2025, y2026, y2027, y2028, y2029], "2024, the year of the tallest row, left")
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion, "the canvas took the window")
        XCTAssertEqual(PageScroll.scrollDelta(old: oldLayout, new: session.layout, topVisibleY: topY), 0, accuracy: 0.001,
                       "2027's row 13 against 2026's: the window's rows")
        XCTAssertEqual(linedUpRows(session, "right after the shift"), rows, "the rows stay: 2024's row 20 too (`.shift` never lowers)")
        XCTAssertEqual(rig.canvas.contentOffset.x, x - rig.page, accuracy: 0.5, "x went back by one year")
        XCTAssertEqual(rig.canvas.contentOffset.y, y, accuracy: 0.5, "y stays")
        XCTAssertEqual(pageIds(of: rig.paper), session.pageIds, "the paper is the new window's, in the same turn")
        let after = screenRects(rig)
        XCTAssertEqual(after.count, 6, "2024's two lines left with it")
        for (name, rect) in before where !name.hasPrefix(y2024) {
            guard let moved = after[name] else {
                XCTFail("\(name) is no longer shown")
                continue
            }
            XCTAssertEqual(moved.minX, rect.minX, accuracy: 0.5, name)
            XCTAssertEqual(moved.minY, rect.minY, accuracy: 0.5, name)
            XCTAssertEqual(moved.width, rect.width, accuracy: 0.5, name)
        }

        await settle(48)
        XCTAssertFalse(session.hasUnreadPages, "2029 was read")
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion)
        XCTAssertEqual(linedUpRows(session, "once 2029 is read"), rows, "the prefetch's `.redecide` is read as `.shift`")
        let settled = screenRects(rig)
        for (name, rect) in before where !name.hasPrefix(y2024) {
            XCTAssertEqual(settled[name]?.minY ?? .nan, rect.minY, accuracy: 0.5, "\(name), once 2029 is read")
            XCTAssertEqual(settled[name]?.minX ?? .nan, rect.minX, accuracy: 0.5, "\(name), once 2029 is read")
        }
        XCTAssertEqual(rig.canvas.contentOffset.y, y, accuracy: 0.5)
        XCTAssertEqual(pageIds(of: rig.paper), session.pageIds)
    }

    /// §4.6's year, §5.4, §3.3 (0g-16; MS8): on the landscape iPad 2023's 4/10 and 8/22 rows are 300.05 lu (strokes at y
    /// 284.25 end at 288.05), so every year of the window (2023 … 2029) is 1,860 + 2 × 240.05 = 2,340.1 lu tall and the
    /// lowest zoom is 640 / 2,340.1, under the opening zoom 640 / 1,860. Pinched to it with 2026 in the middle, the middle
    /// of the screen moved to 2027 (a year of 60 lu rows) and the window shifts (2024 … 2030): 2023, the tall rows' year,
    /// left. Right after the shift and again once the prefetch read 2030 and composed the window anew (`.redecide`, read as
    /// `.shift` for a year), the rows, the lowest zoom and the zoom are where they were. Lowering the floors at that
    /// `.redecide` (MS8) brings every year back to 1,860 lu and the zoom up to 640 / 1,860 with it (the canvas's
    /// `applyBounds` raises a zoom under the new lowest).
    func testTheLowestZoomStaysThroughAShiftToYearsOfLowerRows() async throws {
        let session = try await open(.year, stored: [
            yearPage(y2023, [("a-tall", 4, 10, 284.25), ("a-taller", 8, 22, 284.25)]),
            yearPage(y2027, [("d-low", 2, 2, 10)]),
        ], orientation: .landscape)
        guard SpanKinds.joined.contains(.year) else {
            XCTAssertNil(PaperSpan.window(for: session.layout, focus: session.focusSlot), "the year does not join: one page at a time")
            return
        }
        let rig = await attach(session, size: landscape)
        XCTAssertEqual(session.pageIds, [y2023, y2024, y2025, y2026, y2027, y2028, y2029], "seven years on the landscape iPad")
        let opening = 640.0 / 1860
        XCTAssertEqual(rig.zoom, opening, accuracy: 1e-4, "opens at the opening zoom")
        let rows = linedUpRows(session, "opened")
        XCTAssertEqual(rows[9], 300.05, accuracy: 0.01, "row 10: 2023's 4/10 on every year")
        XCTAssertEqual(rows[21], 300.05, accuracy: 0.01, "row 22: 2023's 8/22 on every year")
        let height = try XCTUnwrap(years(session.layout).first).size.height
        XCTAssertEqual(height, 1_860 + 2 * 240.05, accuracy: 0.01, "the window's paper: 2,340.1 lu")
        for page in years(session.layout) {
            XCTAssertEqual(page.size.height, height, accuracy: 0.001, "\(page.pageId): as tall as the window's")
        }
        let lowest = rig.canvas.minimumZoomScale
        XCTAssertEqual(lowest, 640 / height, accuracy: 1e-4, "the lowest zoom: the window's paper (§5.4)")
        XCTAssertLessThan(lowest, opening - 0.05)
        await pinch(rig, to: lowest)
        await put(rig, mid: origin(y2026, session) + session.plan.pageWidth / 2)
        XCTAssertEqual(rig.zoom, lowest, accuracy: 1e-6, "at the lowest zoom")
        XCTAssertEqual(session.focusPageId, y2026)

        await scroll(rig, pages: 1)
        XCTAssertEqual(session.focusPageId, y2027, "the middle of the screen in 2027")
        XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .done)
        XCTAssertEqual(session.pageIds, [y2024, y2025, y2026, y2027, y2028, y2029, y2030], "2023, the tall rows' year, left the window")
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion, "the canvas took the window")
        XCTAssertEqual(linedUpRows(session, "right after the shift"), rows, "right after the shift: the rows stay")
        XCTAssertEqual(rig.canvas.minimumZoomScale, lowest, accuracy: 1e-6, "right after the shift: the lowest zoom stays")
        XCTAssertEqual(rig.zoom, lowest, accuracy: 1e-6, "right after the shift: the zoom stays")
        XCTAssertTrue(session.hasUnreadPages, "2030 waits for the prefetch")
        let shifted = session.windowVersion

        await settle(48)
        XCTAssertFalse(session.hasUnreadPages, "the prefetch read 2030")
        XCTAssertGreaterThan(session.windowVersion, shifted, "and composed the window anew")
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion, "the canvas took it")
        XCTAssertEqual(linedUpRows(session, "after the prefetch"), rows, "after the prefetch: the floors did not come down")
        XCTAssertEqual(rig.canvas.minimumZoomScale, lowest, accuracy: 1e-6, "after the prefetch: the lowest zoom stays")
        XCTAssertEqual(rig.zoom, lowest, accuracy: 1e-6, "after the prefetch: the zoom stays (§4.6)")
    }

    /// §3.3, §5.1 (MZ1, MP1): a line written down 2026's 3/16 cell (row 16; its points from 2 lu under the cell's top to 102
    /// lu, its centre about 52 lu down, in the cell) makes that row taller. The canvas asks the session to lay the window out
    /// again (`relayoutPages`, `.inkGrew`), and in the new window row 16 grew on every year — the empty ones too — to the
    /// line's row (`YearLayoutEngine.rowHeight` of its bottom), rows 1–15 did not move and rows 17–31 went down by as much on
    /// every year. The canvas takes the window by its heavy path (a year has no tail of its own) and `updatePaperSpan` puts
    /// the new window's paper in: not equal to the one before (2024's page too), equal to `PaperSpan.window`'s.
    func testALongerYearRowMovesTheRowsBelowOnEveryYearAndRedrawsThePaper() async throws {
        let session = try await open(.year)
        guard SpanKinds.joined.contains(.year) else {
            XCTAssertNil(PaperSpan.window(for: session.layout, focus: session.focusSlot), "the year does not join: one page at a time")
            return
        }
        let rig = await attach(session, size: CGSize(width: 834, height: 984))
        let before = session.layout
        let paperBefore = try XCTUnwrap(rig.paper)
        XCTAssertEqual(linedUpRows(session, "empty"), Array(repeating: CGFloat(60), count: 31), "empty: 31 rows of 60")
        let builds = rig.coordinator.setDrawingCount
        let version = session.windowVersion
        let target = cell(.yearDay(month: 3, day: 16), of: y2026, session)
        XCTAssertEqual(target.minY, 900, accuracy: 0.01, "3/16 is row 16 (15 rows of 60 above)")
        XCTAssertEqual(target.height, 60, accuracy: 0.01)
        draw(makeStroke(through: (0..<6).map { CGPoint(x: target.minX + 40 + CGFloat($0 % 2) * 4, y: target.minY + 2 + CGFloat($0) * 20) }),
             on: rig)
        await settle()

        XCTAssertGreaterThan(session.windowVersion, version, "the session laid the window out again")
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion, "the canvas took it")
        XCTAssertEqual(session.page(y2026)?.liveStrokeCount, 1, "2026 has the line")
        let bottom = try XCTUnwrap(session.page(y2026)?.inkBottoms()[.yearDay(month: 3, day: 16)], "the line is 3/16's")
        let row = YearLayoutEngine.rowHeight(laneCount: 0, inkBottom: bottom)
        XCTAssertGreaterThan(row, 100, "row 16 grew")
        let rows = linedUpRows(session, "after the line")
        for (r, height) in rows.enumerated() {
            XCTAssertEqual(height, r == 15 ? row : 60, accuracy: 0.001, "row \(r + 1)")
        }
        let after = years(session.layout)
        XCTAssertEqual(after.map(\.pageId), years(before).map(\.pageId))
        for (old, new) in zip(years(before), after) {
            for r in 0..<15 {
                XCTAssertEqual(new.rows[r].frame, old.rows[r].frame, "\(new.pageId): row \(r + 1) did not move")
            }
            for r in 16..<31 {
                XCTAssertEqual(new.rows[r].frame.minY, old.rows[r].frame.minY + row - 60, accuracy: 0.001, "\(new.pageId): row \(r + 1) went down")
            }
            XCTAssertEqual(new.size.height, 1_860 + row - 60, accuracy: 0.001, "\(new.pageId): its paper")
        }
        XCTAssertGreaterThan(rig.coordinator.setDrawingCount, builds, "the rows moved: the heavy path (§3.3)")
        let paperAfter = try XCTUnwrap(rig.paper)
        XCTAssertNotEqual(paperAfter, paperBefore, "the paper is drawn again (updatePaperSpan)")
        XCTAssertEqual(paperAfter, PaperSpan.window(for: session.layout, focus: session.focusSlot), "the new window's")
        XCTAssertNotEqual(paperAfter.pages[0], paperBefore.pages[0], "2024 too, which has no ink")
    }

    /// §6.1, §6.2, §6.4 (0g-26; MS4): the year's 等倍 on the joined path. The window of years on the landscape iPad opens at
    /// 640 / 1,860; a press goes to fit (the column ÷ 1,400: 1,210 / 1,400, one year across) with the year under the middle of
    /// the screen edge to edge, the paper y in the middle of the screen kept, and reports the ratio fit / open and the fit
    /// state; the window does not shift. The state shows when the iPad turns: portrait goes to its fit (834 / 1,400, not its
    /// opening zoom 984 / 1,860) with the window decided anew around the focus year (five years) and the year edge to edge,
    /// landscape again to 1,210 / 1,400 (seven years); a turn reports nothing. A pinch to 0.7 then reports its ratio and the
    /// fit state off, and a turn keeps 1.4's absolute zoom (the handwriting keeps its size), not fit.
    func testTheYearWindowsOneTimesIsFitAndFollowsTheWidthUntilAPinch() async throws {
        let session = try await open(.year, orientation: .landscape)
        guard SpanKinds.joined.contains(.year) else {
            XCTAssertFalse(ZoomReset.followsFit(.year), "the year does not join: 1.4.2's opening zoom")
            return
        }
        let rig = await attach(session, size: landscape)
        let opening = 640.0 / 1860
        let fit = 1210.0 / 1400
        let portraitFit = 834.0 / 1400
        let yearPortrait = CGSize(width: 834, height: 984)
        XCTAssertEqual(session.pageIds.count, 7)
        XCTAssertEqual(rig.zoom, opening, accuracy: 1e-4, "the joined year opens at its opening zoom")
        XCTAssertEqual(middle(of: y2026, rig), 605, accuracy: 1, "the focus year in the middle")
        drop(rig)
        let midY = (rig.canvas.contentOffset.y + 640.0 / 2) / rig.zoom
        await press(rig, 1)
        XCTAssertEqual(rig.zoom, fit, accuracy: 1e-6, "等倍: fit, one year across")
        XCTAssertEqual(rig.page, 1210, accuracy: 0.5)
        XCTAssertEqual(middle(of: y2026, rig), 605, accuracy: 1, "the year under the middle of the screen, edge to edge")
        let maxY = max(0, rig.canvas.contentSize.height + rig.canvas.contentInset.bottom - 640)
        XCTAssertEqual(rig.canvas.contentOffset.y, min(max(0, midY * fit - 640.0 / 2), maxY), accuracy: 1,
                       "the paper y in the middle of the screen kept")
        XCTAssertEqual(rig.probe.ratios.count, 1, "reported once")
        XCTAssertEqual(rig.probe.ratios.first ?? 0, fit / opening, accuracy: 1e-3, "the ratio fit / open")
        XCTAssertEqual(rig.probe.fits, [true], "the fit state")
        XCTAssertEqual(rig.probe.zooming, [false])
        XCTAssertEqual(session.focusPageId, y2026)
        XCTAssertEqual(rig.coordinator.spanShiftCount, 0, "the focus year is the window's middle: no shift")
        XCTAssertEqual(rig.probe.viewports.last?.zoom ?? 0, fit, accuracy: 1e-6, "the heading follows")

        await turn(rig, to: yearPortrait)
        XCTAssertEqual(rig.zoom, portraitFit, accuracy: 1e-6, "portrait: its fit, not the opening zoom 984 / 1,860")
        XCTAssertEqual(rig.page, 834, accuracy: 0.5, "portrait: one year across")
        XCTAssertEqual(session.pageIds, [y2024, y2025, y2026, y2027, y2028], "portrait: the window decided anew (five years)")
        XCTAssertEqual(middle(of: y2026, rig), 417, accuracy: 1, "portrait: the year edge to edge")
        XCTAssertEqual(session.focusPageId, y2026, "portrait: the focus stays")
        await turn(rig, to: landscape)
        XCTAssertEqual(rig.zoom, fit, accuracy: 1e-6, "landscape again: fit")
        XCTAssertEqual(session.pageIds.count, 7, "landscape again: seven years")
        XCTAssertEqual(middle(of: y2026, rig), 605, accuracy: 1, "landscape again: the year edge to edge")
        XCTAssertEqual(session.focusPageId, y2026)
        XCTAssertEqual(rig.probe.ratios.count, 1, "the press's report only: a turn reports nothing")
        XCTAssertEqual(rig.probe.fits, [true])
        drop(rig)

        rig.coordinator.scrollViewWillBeginZooming(rig.canvas, with: nil)
        rig.canvas.setZoomScale(0.7, animated: false)
        rig.coordinator.scrollViewDidEndZooming(rig.canvas, with: nil, atScale: 0.7)
        await settle()
        XCTAssertEqual(rig.zoom, 0.7, accuracy: 1e-6)
        XCTAssertEqual(rig.probe.ratios.count, 1, "the pinch's report")
        XCTAssertEqual(rig.probe.ratios.first ?? 0, 0.7 / opening, accuracy: 1e-3, "the pinch's ratio")
        XCTAssertEqual(rig.probe.fits, [false], "the fit state is over")
        XCTAssertEqual(rig.probe.zooming, [true, false])
        await put(rig, mid: origin(y2026, session) + session.plan.pageWidth / 2)
        await turn(rig, to: yearPortrait)
        XCTAssertEqual(rig.zoom, 0.7, accuracy: 1e-6, "portrait: the absolute zoom stays, not fit 834 / 1,400")
        await turn(rig, to: landscape)
        XCTAssertEqual(rig.zoom, 0.7, accuracy: 1e-6, "landscape again: the absolute zoom stays, not fit 1,210 / 1,400")
        XCTAssertEqual(rig.probe.ratios.count, 1, "a turn reports nothing")
        XCTAssertEqual(rig.probe.fits, [false])
    }

    /// §3.7, §5.4 (0g-19, 0g-23; P-B6 イ's cap of three years works from 1.4.3): the window of years on an iPhone in landscape
    /// (the paper area 750 × 208 of iPhone 17) opens at the cap, three years across (750 / 4,200), and the screen hands the
    /// canvas `ScreenPaths.shotPaperOffset`: on today's year (11/7/2026 10:00, the focus 11/16) it opens two rows above today's
    /// row — day 5's top, 4 × 60 lu (`cappedOpeningY`, `PageNavigation.initialScrollY`'s rule of the year) — with the focus year
    /// in the middle and today's cell on screen. A window whose focus year does not hold today (2028) has no offset and opens
    /// at its top.
    func testTheCappedYearOpensTwoRowsAboveTodaysRow() async throws {
        bed.now = try XCTUnwrap(SessionTestBed.tokyo.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 10)))
        let area = CGSize(width: 750, height: 208)
        let session = bed.session(.year, focus: nov16, deviceClass: .iPhone, orientation: .landscape, overviewCap: true)
        await session.prefetch()
        guard SpanKinds.joined.contains(.year) else {
            XCTAssertNil(PaperSpan.window(for: session.layout, focus: session.focusSlot), "the year does not join: one page at a time")
            return
        }
        let cap = area.width / (3 * ZoomPolicy.paperWidth(.year))
        let zoom = ScreenPaths.bandZoom(layout: session.layout, area: area, ratio: 1)
        XCTAssertEqual(zoom, cap, accuracy: 1e-6, "the screen's zoom: the cap, three years across")
        let today = try XCTUnwrap(years(session.layout).first { $0.pageId == y2026 })
        XCTAssertEqual(today.todayCell, .yearDay(month: 11, day: 7))
        let top = today.rows[4].frame.minY
        XCTAssertEqual(top, 240, accuracy: 0.001, "two rows above 11/7's row: day 5's top")
        let offset = try XCTUnwrap(ScreenPaths.shotPaperOffset(layout: session.layout, focusPageId: session.focusPageId, pages: nil,
                                                               offset: nil, viewportWidth: area.width, zoom: zoom), "today's year")
        let focus = origin(y2026, session)
        XCTAssertEqual(offset.y, top, accuracy: 0.001, "the opening's y: `cappedOpeningY`")
        XCTAssertEqual(offset.x, focus + session.plan.pageWidth / 2 - area.width / 2 / zoom, accuracy: 0.001, "the focus year in the middle")

        let rig = await attach(session, size: area, initialPaperOffset: offset)
        XCTAssertEqual(rig.zoom, cap, accuracy: 1e-4, "the cap")
        XCTAssertEqual(middle(of: y2026, rig), area.width / 2, accuracy: 0.5, "the focus year in the middle")
        XCTAssertLessThanOrEqual(top * cap, rig.canvas.contentSize.height - area.height, "inside the paper: nothing clamps it")
        XCTAssertEqual(rig.canvas.contentOffset.y, top * cap, accuracy: 0.5, "opened with day 5's row at the top")
        let todayCell = cell(.yearDay(month: 11, day: 7), of: y2026, session)
        XCTAssertGreaterThanOrEqual(todayCell.minY * cap, rig.canvas.contentOffset.y, "today's cell on screen")
        XCTAssertLessThanOrEqual(todayCell.maxY * cap, rig.canvas.contentOffset.y + area.height, "today's cell on screen")

        let other = bed.session(.year, focus: DayKey(year: 2028, month: 3, day: 1), number: 2, deviceClass: .iPhone,
                                orientation: .landscape, overviewCap: true)
        await other.prefetch()
        let otherZoom = ScreenPaths.bandZoom(layout: other.layout, area: area, ratio: 1)
        XCTAssertNil(ScreenPaths.shotPaperOffset(layout: other.layout, focusPageId: other.focusPageId, pages: nil, offset: nil,
                                                 viewportWidth: area.width, zoom: otherZoom), "2028 does not hold today")
        let otherRig = await attach(other, size: area)
        XCTAssertEqual(otherRig.zoom, cap, accuracy: 1e-4)
        XCTAssertEqual(otherRig.canvas.contentOffset.y, 0, accuracy: 0.5, "another year opens at its top")
        XCTAssertEqual(middle(of: "y-2028", otherRig), area.width / 2, accuracy: 0.5, "the focus year in the middle")
    }

    // MARK: ↶ ↷, the eraser and iCloud across years (§9.1, §9.3, §9.5; D1y review S4, the month's TEST-1)

    /// §9.1, §9.3, §5.2 (D1y review S4): one history for the window of years. A line on the 20th's row (all rows 60 lu: its
    /// top 1,140) from 2025's December into 2026's January — nine points from 60 lu left of 2026's left edge to 160 lu right
    /// of it, its centre 50 lu right of the edge, in 2026's day-number column, whose cell is January's (§5.2) — belongs to
    /// 2026's 1/20 with its points left of the page kept (x < −56 of the cell, which starts at 56). The eraser takes it away
    /// (2026's delta, its name tombstoned in the file); ↶ brings it back as a copy under a fresh name (a tombstoned id never
    /// comes back, 1.0's rule: the frozen `InkLedgerTests.testEraseMakesTombstoneAndUndoRestoresClone`), its cell's owner's
    /// (`SpanSession.ownerId(for:)`): 2026's again, in 1/20, with the same points, saved; ↷ erases the copy again. 2025
    /// never gets a file.
    func testALineFromDecemberIntoJanuaryErasedComesBackWithUndo() async throws {
        let session = try await open(.year)
        guard SpanKinds.joined.contains(.year) else {
            XCTAssertNil(PaperSpan.window(for: session.layout, focus: session.focusSlot), "the year does not join: one page at a time")
            return
        }
        let rig = await attach(session, size: CGSize(width: 834, height: 984))
        XCTAssertEqual(session.pageIds, [y2024, y2025, y2026, y2027, y2028])
        let edge = origin(y2026, session)
        let january20 = CellKey.yearDay(month: 1, day: 20)
        let target = cell(january20, of: y2026, session)
        XCTAssertEqual(target.minX, edge + 56, accuracy: 0.001, "January's cell starts after the day-number column")
        XCTAssertEqual(target.minY, 1_140, accuracy: 0.001, "row 20 (19 rows of 60 above)")
        XCTAssertEqual(cell(.yearDay(month: 12, day: 20), of: y2025, session).maxX, edge, accuracy: 0.001,
                       "2025's December ends at 2026's left edge")
        let y = target.minY + 30
        draw(makeStroke(through: (0...8).map { CGPoint(x: edge - 60 + CGFloat($0) * 27.5, y: y + CGFloat($0 % 2)) }), on: rig)
        let written = try lastDrawn(on: rig)
        XCTAssertTrue(written.hasPrefix(y2026), "its centre right of the edge: 2026's line")
        let stroke = try XCTUnwrap(rig.ledger.page.strokes[written])
        XCTAssertEqual(stroke.cell, SpanName.prefixed(january20, page: y2026), "in 2026's 1/20")
        let xs = stroke.points.map(\.x)
        XCTAssertLessThan(xs.min() ?? 0, -56, "the points left of 2026's page kept (\(xs.min() ?? 0))")
        XCTAssertGreaterThan(xs.max() ?? 0, 0, "and the points in January (\(xs.max() ?? 0))")
        let writtenPoints = stroke.points
        await settle()
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertEqual(bed.live(y2026).count, 1)
        XCTAssertFalse(bed.store.exists(y2025), "2025 holds none of it")

        erase(written, on: rig)
        XCTAssertFalse(rig.ledger.page.isLive(written), "erased")
        XCTAssertNil(shown(written, on: rig))
        XCTAssertEqual(session.inbox.deltas.map(\.pageId), [y2026], "2026's delta")
        XCTAssertTrue(session.inbox.unrouted.isEmpty)
        XCTAssertTrue(rig.ledger.canUndo)
        await settle()
        XCTAssertEqual(session.saveAll(), [])
        let writtenLocal = try XCTUnwrap(SpanName.split(written)?.local)
        XCTAssertEqual(bed.live(y2026).count, 0, "2026's file without it")
        XCTAssertNotNil(bed.store.load(y2026).deleted[writtenLocal], "its name tombstoned in the file")

        update(rig, undoTrigger: 1)
        XCTAssertFalse(rig.ledger.page.isLive(written), "the name the eraser tombstoned stays tombstoned")
        let back = rig.ledger.page.liveStrokes
        XCTAssertEqual(back.count, 1, "↶ brings the line back")
        let copy = try XCTUnwrap(back.first)
        XCTAssertNotEqual(copy.id, written, "as a copy under a fresh name")
        XCTAssertEqual(SpanName.split(copy.id)?.page, y2026, "2026's name")
        XCTAssertEqual(copy.cell, SpanName.prefixed(january20, page: y2026), "in 2026's 1/20")
        XCTAssertEqual(copy.points, writtenPoints, "the same line")
        XCTAssertNotNil(shown(copy.id, on: rig))
        XCTAssertEqual(session.inbox.deltas.map(\.pageId), [y2026], "↶'s delta 2026's")
        XCTAssertTrue(session.inbox.unrouted.isEmpty)
        XCTAssertTrue(rig.ledger.canRedo)
        await settle()
        XCTAssertEqual(session.saveAll(), [])
        let copyLocal = try XCTUnwrap(SpanName.split(copy.id)?.local)
        XCTAssertEqual(bed.live(y2026), [copyLocal], "2026's file with it again, under its new name")
        XCTAssertNotNil(bed.store.load(y2026).deleted[writtenLocal], "its first name still tombstoned")
        XCTAssertFalse(bed.store.exists(y2025), "2025 untouched")

        update(rig, undoTrigger: 1, redoTrigger: 1)
        XCTAssertFalse(rig.ledger.page.isLive(copy.id), "↷ erases the copy again")
        XCTAssertNil(shown(copy.id, on: rig))
        XCTAssertEqual(rig.ledger.page.liveStrokes.count, 0)
        XCTAssertEqual(session.inbox.deltas.map(\.pageId), [y2026], "↷'s delta 2026's")
        XCTAssertFalse(rig.ledger.canRedo)
        await settle()
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertEqual(bed.live(y2026).count, 0, "2026's file without it again")
        XCTAssertNotNil(bed.store.load(y2026).deleted[copyLocal], "the copy's name tombstoned too")
        XCTAssertFalse(bed.store.exists(y2025))
    }

    /// §9.5 (D1y review S4; InkCanvasSpanTests.testARemoteDeletionDropsThatPagesUndoSteps' year): 2025 holds a stored line
    /// (2/3); a line written on 2025's 3/10 and erased, then a line on 2027's 5/10, saved. Another device's 「全て消す」
    /// deletes 2025 (its file goes, then the session hears of it): the canvas takes the window, 2025 is empty on it (its
    /// stored line gone too), 2027's line stays and so does its step. ↶ takes 2027's line away and there is nothing more to
    /// undo: 2025's steps went with the window taken after the deletion; a second ↶ puts no delta of 2025 and its erased
    /// line does not come back. Saved, 2025's file is not made again.
    func testAYearDeletedOutsideIsEmptiedAndLeavesTheUndo() async throws {
        let session = try await open(.year, stored: [yearPage(y2025, [("old", 2, 3, 10)])])
        guard SpanKinds.joined.contains(.year) else {
            XCTAssertNil(PaperSpan.window(for: session.layout, focus: session.focusSlot), "the year does not join: one page at a time")
            return
        }
        let rig = await attach(session, size: CGSize(width: 834, height: 984))
        let old = SpanName.prefixed(id: "old", page: y2025)
        XCTAssertNotNil(shown(old, on: rig), "2025's stored line is drawn")
        let march10 = cell(.yearDay(month: 3, day: 10), of: y2025, session)
        draw(shortStroke(at: march10.minX + 56, march10.minY + 30), on: rig)
        let written = try lastDrawn(on: rig)
        XCTAssertTrue(written.hasPrefix(y2025))
        erase(written, on: rig)
        XCTAssertFalse(rig.ledger.page.isLive(written), "erased")
        let may10 = cell(.yearDay(month: 5, day: 10), of: y2027, session)
        draw(shortStroke(at: may10.minX + 56, may10.minY + 30), on: rig)
        let later = try lastDrawn(on: rig)
        XCTAssertTrue(later.hasPrefix(y2027))
        await settle()
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertEqual(bed.store.load(y2025).liveStrokeCount, 1, "2025: its stored line")
        XCTAssertEqual(bed.store.load(y2025).deleted.count, 1, "and the erased one's tombstone")
        XCTAssertEqual(bed.live(y2027).count, 1)

        // As `SyncEngine` applies a deleted record: the file goes, then the session hears of it.
        try bed.store.remove(y2025)
        session.remoteDeleted(y2025)
        await settle()
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion, "the canvas took the window")
        XCTAssertEqual(session.page(y2025)?.liveStrokeCount, 0, "2025 is empty")
        XCTAssertFalse(rig.ledger.page.isLive(old), "its stored line is gone")
        XCTAssertNil(shown(old, on: rig))
        XCTAssertFalse(rig.canvas.drawing.strokes.contains { rig.ledger.id(of: $0)?.hasPrefix(y2025) == true }, "nothing of 2025 drawn")
        XCTAssertFalse(rig.ledger.page.isLive(written))
        XCTAssertTrue(rig.ledger.page.isLive(later))
        XCTAssertTrue(rig.ledger.canUndo, "2027's later step stays")

        update(rig, undoTrigger: 1)
        XCTAssertFalse(rig.ledger.page.isLive(later), "↶ takes 2027's line away")
        XCTAssertEqual(session.inbox.deltas.map(\.pageId), [y2027])
        XCTAssertFalse(rig.ledger.canUndo, "2025's steps went with the window taken after the deletion")
        XCTAssertTrue(rig.ledger.canRedo, "the ↶ just made can be redone")
        update(rig, undoTrigger: 2)
        XCTAssertEqual(session.inbox.deltas.map(\.pageId), [y2027], "a second ↶ puts no delta of 2025")
        XCTAssertTrue(session.inbox.unrouted.isEmpty)
        XCTAssertFalse(rig.ledger.page.isLive(written), "the erased line does not come back")
        XCTAssertNil(shown(written, on: rig))
        XCTAssertFalse(rig.ledger.page.liveStrokes.contains { $0.id.hasPrefix(y2025) }, "nothing of 2025 is live")
        await settle()
        XCTAssertEqual(session.page(y2025)?.liveStrokeCount, 0)
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertFalse(bed.store.exists(y2025), "its file is not made again")
        XCTAssertEqual(bed.live(y2027).count, 0, "2027's ↶ is saved")
    }

    // MARK: 「今日」's slide lands (§3.7; the lead's decision of 11/28, in place of review UX-2 (b))

    /// The screen's `ScreenPaths` over the bed's engine (ScreenPathsMonthYearTests' `makePaths`, the parts used here: the
    /// setting on, not in screenshot mode), `lastPageKind` / `lastFocusDate` written to `defaults`.
    private func makePaths(defaults: UserDefaults) -> ScreenPaths {
        let sleeper = bed.sessionSleeper
        return ScreenPaths(sync: bed.engine,
                           onePage: OnePageSession(sync: bed.engine, sleep: { await sleeper.sleep($0) },
                                                   clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) }),
                           screenshot: false, shot: nil, settingOn: { true }, defaults: defaults,
                           sleep: { await sleeper.sleep($0) },
                           clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) })
    }

    /// The screen's window of `kind` at 11/16/2026 opened through `paths` on `device` (the screen's `show`), its pages read
    /// (the canvas starts `prefetch` as it attaches).
    private func openThrough(_ paths: ScreenPaths, _ kind: PageKind, device: ScreenPaths.Device, file: StaticString = #filePath,
                             line: UInt = #line) async throws -> SpanSession {
        let o = ScreenPaths.Opening(kind: kind, focus: nov16, weekStart: .monday, device: device, paperArea: nil,
                                    context: SpanSession.PaperContext(now: bed.now, calendar: SessionTestBed.tokyo))
        XCTAssertEqual(paths.open(o), .joined, file: file, line: line)
        let session = try XCTUnwrap(paths.span, file: file, line: line)
        await session.prefetch()
        return session
    }

    /// 10:00 in Tokyo on that day.
    private func at(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try XCTUnwrap(SessionTestBed.tokyo.date(from: DateComponents(year: year, month: month, day: day, hour: 10)))
    }

    /// What one 「今日」 did on the canvas: the pages slid, the offset (pt) as the slide landed (its window shifted at the
    /// stop) and after the stop's request, and the request.
    private struct Landing {
        var pages: Int
        var landed: CGPoint
        var after: CGPoint
        var request: CGRect?
    }

    /// 「今日」 on `day` at `now` as the screen presses it (`CalendarRootScreen.goToday`): `paths.today` with the screen's last
    /// viewport (`heading`), its `.slide` run by the canvas (`slide(byPages:)`, UIKit's animation stood in for: it ends where
    /// it was going, so the window shifts at the stop), the one stop the canvas tells (`onSpanStop`) taken as `spanStopped`
    /// takes it (`ScreenPaths.stopped` with the screen's focus, in the turn the canvas tells of it: review F2 reads the
    /// screen's last viewport there) and its `reveal` handed to the canvas once (through `paths.revealRect(_:for:)`, a new
    /// `revealTrigger`), then the canvas's turns.
    private func pressToday(_ day: DayKey, at now: Date, paths: ScreenPaths, rig: SpanRig, area: CGSize, fit: Bool,
                            focus: inout DayKey, trigger: inout Int, file: StaticString = #filePath,
                            line: UInt = #line) async throws -> Landing {
        let action = paths.today(day, now: now, viewport: paths.heading?.viewport, area: area, ratio: 1, fit: fit)
        guard case .slide(let pages)? = action else {
            XCTFail("「今日」 on \(day): a slide, not \(String(describing: action))", file: file, line: line)
            return Landing(pages: 0, landed: rig.canvas.contentOffset, after: rig.canvas.contentOffset, request: nil)
        }
        rig.coordinator.spanSlideAnimation = { [weak coordinator = rig.coordinator] canvas, target in
            canvas.contentOffset = target
            coordinator?.scrollViewDidScroll(canvas)
            coordinator?.scrollViewDidEndScrollingAnimation(canvas)
        }
        let stops = rig.probe.stops.count
        let shown = focus
        var taken: ScreenPaths.Stopped?
        rig.probe.onStop = { stop in
            taken = paths.stopped(stop, focus: shown, kind: rig.session.kind, weekStart: .monday, boundary: {})
        }
        defer { rig.probe.onStop = nil }
        rig.coordinator.slide(byPages: pages)
        await settle()
        XCTAssertNil(rig.coordinator.spanSlideTargetX, "\(day): the slide ended", file: file, line: line)
        XCTAssertEqual(rig.probe.stops.count, stops + 1, "\(day): one stop", file: file, line: line)
        let landed = rig.canvas.contentOffset
        let result = try XCTUnwrap(taken, "\(day): the stop taken in its turn", file: file, line: line)
        focus = result.focus
        if let rect = result.reveal {
            trigger += 1
            update(rig, revealRect: paths.revealRect(rect, for: rig.session), revealTrigger: trigger)
            await settle()
        }
        return Landing(pages: pages, landed: landed, after: rig.canvas.contentOffset, request: result.reveal)
    }

    /// `rect` (band lu) is on screen from top to bottom, the paper area `height` pt high.
    private func assertOnScreen(_ rect: CGRect, _ rig: SpanRig, height: CGFloat, _ step: String, file: StaticString = #filePath,
                                line: UInt = #line) {
        let top = rig.canvas.contentOffset.y
        XCTAssertGreaterThanOrEqual(rect.minY * rig.zoom, top - 0.5, "\(step): today's cell on screen", file: file, line: line)
        XCTAssertLessThanOrEqual(rect.maxY * rig.zoom, top + height + 0.5, "\(step): today's cell on screen", file: file, line: line)
    }

    /// §3.7 (「今日のページが窓の中なら滑って行き、今日のマスが画面に入るように縦も合わせる（今日のマスがもう見えていれば縦は動かさない）」;
    /// the lead's decision of 11/28, in place of review UX-2 (b)) on the frozen canvas, through the screen's `ScreenPaths`: a
    /// window of months on the landscape iPad at 等倍 (fit 1,210 / 1,400; 740 lu of the paper on screen, the rows 175 lu).
    /// 「今日」 slides by pages keeping y; at its stop on today's month the request (`Stopped.reveal`) moves y alone, x staying:
    /// 12/31 (December's fifth row, 700–875 lu), below the screen at the paper's top → to the cell's top less 1.1.1's margin
    /// (690.7 lu); 1/27/2027 (January's fifth row), on screen from there → nothing moves; 12/3 (December's first row), above
    /// the screen with the paper down in January's memo → up to the paper's top. Today's cell ends on screen each time, and
    /// a later stop there brings nothing. Before the decision the paper stayed where the slide left it.
    func testTodaysSlideOfMonthsBringsTodaysCellOnScreen() async throws {
        let suite = "InkCanvasMonthYearTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let paths = makePaths(defaults: defaults)
        let session = try await openThrough(paths, .month, device: ScreenPaths.Device(deviceClass: .iPad11, orientation: .landscape))
        XCTAssertEqual(session.pageIds, [sep, oct, nov, dec, jan])
        let fit = 1210.0 / 1400
        let rig = await attach(session, size: landscape, initialFit: true, initialScrollX: origin(nov, session),
                               onViewport: { paths.viewportArrived($0) })
        XCTAssertEqual(rig.zoom, fit, accuracy: 1e-6, "等倍")
        XCTAssertEqual(rig.canvas.contentOffset.y, 0, accuracy: 0.5, "at the paper's top")
        XCTAssertEqual(paths.heading?.viewport?.zoom ?? 0, fit, accuracy: 1e-6, "the screen's last viewport")
        var focus = nov16
        var trigger = 0

        let dec31 = DayKey(year: 2026, month: 12, day: 31)
        let below = try await pressToday(dec31, at: try at(2026, 12, 31), paths: paths, rig: rig, area: landscape, fit: true,
                                         focus: &focus, trigger: &trigger)
        XCTAssertEqual(below.pages, 1)
        XCTAssertEqual(session.focusPageId, dec)
        XCTAssertEqual(focus, dec31, "today the focus (review UX-3)")
        XCTAssertEqual(middle(of: dec, rig), 605, accuracy: 1, "December edge to edge")
        XCTAssertEqual(below.landed.y, 0, accuracy: 0.5, "the slide kept y")
        let dec31Cell = cell(.day(dec31), of: dec, session)
        XCTAssertEqual(dec31Cell.minY, 700, accuracy: 0.001, "December's fifth row")
        XCTAssertGreaterThan(dec31Cell.maxY * fit, landscape.height, "below the screen as the slide landed")
        let lines = try XCTUnwrap(below.request.flatMap { InkCanvasView.nowLineRevealLines($0) }, "the landing's request")
        XCTAssertEqual(lines.top, 700 - ZoomPolicy.revealMargin / fit, accuracy: 1e-6, "the cell's top less the margin")
        XCTAssertEqual(lines.nowLine, 875, accuracy: 1e-6, "the cell's bottom")
        XCTAssertEqual(below.after.y, lines.top * fit, accuracy: 0.5, "y alone, to the cell's top less the margin")
        XCTAssertEqual(below.after.x, below.landed.x, accuracy: 0.01, "x never moves")
        assertOnScreen(dec31Cell, rig, height: landscape.height, "below")

        let jan27 = DayKey(year: 2027, month: 1, day: 27)
        let shown = try await pressToday(jan27, at: try at(2027, 1, 27), paths: paths, rig: rig, area: landscape, fit: true,
                                         focus: &focus, trigger: &trigger)
        XCTAssertEqual(shown.pages, 1)
        XCTAssertEqual(session.focusPageId, jan)
        XCTAssertEqual(focus, jan27)
        XCTAssertEqual(shown.landed.y, below.after.y, accuracy: 0.5, "the slide kept y")
        XCTAssertNotNil(shown.request, "the request goes: the screen does not know the paper's y")
        XCTAssertEqual(shown.after.y, shown.landed.y, accuracy: 0.01, "today's cell already on screen: y stays")
        XCTAssertEqual(shown.after.x, shown.landed.x, accuracy: 0.01)
        assertOnScreen(cell(.day(jan27), of: jan, session), rig, height: landscape.height, "on screen")

        await put(rig, mid: origin(jan, session) + 700, y: 3_000 * fit)
        let dec3 = DayKey(year: 2026, month: 12, day: 3)
        let above = try await pressToday(dec3, at: try at(2026, 12, 3), paths: paths, rig: rig, area: landscape, fit: true,
                                         focus: &focus, trigger: &trigger)
        XCTAssertEqual(above.pages, -1)
        XCTAssertEqual(session.focusPageId, dec)
        XCTAssertEqual(above.landed.y, 3_000 * fit, accuracy: 0.5, "the slide kept y (down in the memo)")
        XCTAssertEqual(above.after.y, 0, accuracy: 0.5, "up to the cell's top less the margin, the paper's top")
        XCTAssertEqual(above.after.x, above.landed.x, accuracy: 0.01, "x never moves")
        assertOnScreen(cell(.day(dec3), of: dec, session), rig, height: landscape.height, "above")

        // Once: a later check tells no stop, and the stop again brings no request.
        let stops = rig.probe.stops.count
        rig.coordinator.shiftIfAtRest()
        await settle()
        XCTAssertEqual(rig.probe.stops.count, stops, "the same focus page: no stop")
        let again = paths.stopped(try XCTUnwrap(rig.probe.stops.last), focus: focus, kind: .month, weekStart: .monday, boundary: {})
        XCTAssertNil(again.reveal, "once")
        XCTAssertEqual(rig.canvas.contentOffset.y, above.after.y, accuracy: 0.01)
    }

    /// The same on a window of years (§3.7, the month's rule; D1y), the landscape iPad at 等倍 (fit 1,210 / 1,400; 740 lu on
    /// screen, the paper 1,860 lu high so y ends at 967.6 pt), 2023 … 2029 around 2026: 2027-12-28 (the 28th's row, 1,620–1,680
    /// lu) below the screen at the paper's top → y to the cell's top less the margin, which the paper's end clamps; 2028-12-30
    /// (1,740–1,800 lu) on screen from there → nothing moves; 2027-01-05 (240–300 lu) above → y to its top less the margin.
    func testTodaysSlideOfYearsBringsTodaysCellOnScreen() async throws {
        let suite = "InkCanvasMonthYearTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let paths = makePaths(defaults: defaults)
        guard SpanKinds.joined.contains(.year) else {
            XCTAssertEqual(paths.open(ScreenPaths.Opening(kind: .year, focus: nov16, weekStart: .monday,
                                                          device: ScreenPaths.Device(deviceClass: .iPad11, orientation: .landscape),
                                                          paperArea: nil,
                                                          context: SpanSession.PaperContext(now: bed.now, calendar: SessionTestBed.tokyo))),
                           .onePage, "the year does not join: one page")
            return
        }
        let session = try await openThrough(paths, .year, device: ScreenPaths.Device(deviceClass: .iPad11, orientation: .landscape))
        XCTAssertEqual(session.pageIds, [y2023, y2024, y2025, y2026, y2027, y2028, y2029])
        let fit = 1210.0 / 1400
        let rig = await attach(session, size: landscape, initialFit: true, initialScrollX: origin(y2026, session),
                               onViewport: { paths.viewportArrived($0) })
        XCTAssertEqual(rig.zoom, fit, accuracy: 1e-6, "等倍")
        XCTAssertEqual(rig.canvas.contentOffset.y, 0, accuracy: 0.5, "at the paper's top")
        let maxY = rig.canvas.contentSize.height + rig.canvas.contentInset.bottom - landscape.height
        XCTAssertEqual(maxY, 1_860 * fit - 640, accuracy: 0.5, "the paper's end")
        var focus = nov16
        var trigger = 0

        let dec28 = DayKey(year: 2027, month: 12, day: 28)
        let below = try await pressToday(dec28, at: try at(2027, 12, 28), paths: paths, rig: rig, area: landscape, fit: true,
                                         focus: &focus, trigger: &trigger)
        XCTAssertEqual(below.pages, 1)
        XCTAssertEqual(session.focusPageId, y2027)
        XCTAssertEqual(focus, dec28, "today the focus (review UX-3)")
        XCTAssertEqual(below.landed.y, 0, accuracy: 0.5, "the slide kept y")
        let dec28Cell = cell(.yearDay(month: 12, day: 28), of: y2027, session)
        XCTAssertEqual(dec28Cell.minY, 1_620, accuracy: 0.001, "the 28th's row")
        XCTAssertGreaterThan(dec28Cell.maxY * fit, landscape.height, "below the screen as the slide landed")
        let lines = try XCTUnwrap(below.request.flatMap { InkCanvasView.nowLineRevealLines($0) }, "the landing's request")
        XCTAssertEqual(lines.top, 1_620 - ZoomPolicy.revealMargin / fit, accuracy: 1e-6, "the cell's top less the margin")
        XCTAssertEqual(lines.nowLine, 1_680, accuracy: 1e-6, "the cell's bottom")
        XCTAssertGreaterThan(lines.top * fit, maxY, "past the paper's end")
        XCTAssertEqual(below.after.y, maxY, accuracy: 0.5, "y alone, clamped at the paper's end")
        XCTAssertEqual(below.after.x, below.landed.x, accuracy: 0.01, "x never moves")
        assertOnScreen(dec28Cell, rig, height: landscape.height, "below")

        let dec30 = DayKey(year: 2028, month: 12, day: 30)
        let shown = try await pressToday(dec30, at: try at(2028, 12, 30), paths: paths, rig: rig, area: landscape, fit: true,
                                         focus: &focus, trigger: &trigger)
        XCTAssertEqual(shown.pages, 1)
        XCTAssertEqual(session.focusPageId, y2028)
        XCTAssertEqual(shown.landed.y, below.after.y, accuracy: 0.5, "the slide kept y")
        XCTAssertNotNil(shown.request, "the request goes: the screen does not know the paper's y")
        XCTAssertEqual(shown.after.y, shown.landed.y, accuracy: 0.01, "today's cell already on screen: y stays")
        assertOnScreen(cell(.yearDay(month: 12, day: 30), of: y2028, session), rig, height: landscape.height, "on screen")

        let jan5 = DayKey(year: 2027, month: 1, day: 5)
        let above = try await pressToday(jan5, at: try at(2027, 1, 5), paths: paths, rig: rig, area: landscape, fit: true,
                                         focus: &focus, trigger: &trigger)
        XCTAssertEqual(above.pages, -1)
        XCTAssertEqual(session.focusPageId, y2027)
        XCTAssertEqual(above.landed.y, below.after.y, accuracy: 0.5, "the slide kept y")
        XCTAssertEqual(above.after.y, (240 - ZoomPolicy.revealMargin / fit) * fit, accuracy: 0.5, "y alone, to the cell's top less the margin")
        XCTAssertEqual(above.after.x, above.landed.x, accuracy: 0.01, "x never moves")
        assertOnScreen(cell(.yearDay(month: 1, day: 5), of: y2027, session), rig, height: landscape.height, "above")
    }

    /// §3.7, §5.4 (0g-23: 「「今日」で今日の年が焦点なら、今日の行が見えていなければ縦だけ動く」; the lead's decision of 11/28): the
    /// capped year of an iPhone in landscape (750 × 208 of iPhone 17, three years across: 750 / 4,200, about 1,165 lu on screen,
    /// the paper's end at 124.1 pt), 2023 … 2029 around 2026. 「今日」's slide and its stop bring `cappedTodayRect`'s request:
    /// 2027-12-28 (its bottom 1,680 lu) below the screen at the paper's top → y to two rows above today's row (1,500 lu),
    /// which the paper's end clamps; 2028-11-18 (its bottom 1,080 lu) on screen from there → nothing moves; 2027-01-05 (its
    /// bottom 300 lu) above → y to two rows above its row (the 3rd's, 120 lu).
    func testTodaysSlideOfTheCappedYearsBringsTodaysRowOnScreen() async throws {
        let suite = "InkCanvasMonthYearTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let paths = makePaths(defaults: defaults)
        let phone = ScreenPaths.Device(deviceClass: .iPhone, orientation: .landscape)
        let area = CGSize(width: 750, height: 208)
        guard SpanKinds.joined.contains(.year) else {
            XCTAssertEqual(paths.open(ScreenPaths.Opening(kind: .year, focus: nov16, weekStart: .monday, device: phone, paperArea: nil,
                                                          context: SpanSession.PaperContext(now: bed.now, calendar: SessionTestBed.tokyo))),
                           .onePage, "the year does not join: one page")
            return
        }
        let session = try await openThrough(paths, .year, device: phone)
        XCTAssertEqual(session.pageIds, [y2023, y2024, y2025, y2026, y2027, y2028, y2029])
        let cap = area.width / (3 * ZoomPolicy.paperWidth(.year))
        let rig = await attach(session, size: area, onViewport: { paths.viewportArrived($0) })
        XCTAssertEqual(rig.zoom, cap, accuracy: 1e-4, "the cap")
        await put(rig, mid: origin(y2026, session) + 700, y: 0)
        let shownViewport = try XCTUnwrap(paths.heading?.viewport, "the screen's last viewport")
        XCTAssertTrue(ScreenPaths.atCappedOverview(layout: session.layout, width: shownViewport.width, zoom: shownViewport.zoom))
        let maxY = rig.canvas.contentSize.height + rig.canvas.contentInset.bottom - area.height
        XCTAssertEqual(maxY, 1_860 * cap - 208, accuracy: 0.5, "the paper's end")
        var focus = nov16
        var trigger = 0

        let dec28 = DayKey(year: 2027, month: 12, day: 28)
        let below = try await pressToday(dec28, at: try at(2027, 12, 28), paths: paths, rig: rig, area: area, fit: false,
                                         focus: &focus, trigger: &trigger)
        XCTAssertEqual(below.pages, 1)
        XCTAssertEqual(session.focusPageId, y2027)
        XCTAssertEqual(below.landed.y, 0, accuracy: 0.5, "the slide kept y")
        let lines = try XCTUnwrap(below.request.flatMap { InkCanvasView.nowLineRevealLines($0) }, "the landing's request")
        XCTAssertEqual(lines.top, 25 * 60, accuracy: 1e-6, "two rows above the 28th's: the 26th's top")
        XCTAssertEqual(lines.nowLine, 28 * 60, accuracy: 1e-6, "the bottom of today's cell")
        XCTAssertGreaterThan(lines.nowLine * cap, area.height, "below the screen as the slide landed")
        XCTAssertEqual(below.after.y, min(lines.top * cap, maxY), accuracy: 0.5, "y alone, clamped at the paper's end")
        XCTAssertEqual(below.after.x, below.landed.x, accuracy: 0.01, "x never moves")
        assertOnScreen(cell(.yearDay(month: 12, day: 28), of: y2027, session), rig, height: area.height, "below")

        let nov18 = DayKey(year: 2028, month: 11, day: 18)
        let shown = try await pressToday(nov18, at: try at(2028, 11, 18), paths: paths, rig: rig, area: area, fit: false,
                                         focus: &focus, trigger: &trigger)
        XCTAssertEqual(shown.pages, 1)
        XCTAssertEqual(session.focusPageId, y2028)
        XCTAssertNotNil(shown.request)
        XCTAssertEqual(shown.after.y, shown.landed.y, accuracy: 0.01, "today's row on screen: y stays")
        assertOnScreen(cell(.yearDay(month: 11, day: 18), of: y2028, session), rig, height: area.height, "on screen")

        let jan5 = DayKey(year: 2027, month: 1, day: 5)
        let above = try await pressToday(jan5, at: try at(2027, 1, 5), paths: paths, rig: rig, area: area, fit: false,
                                         focus: &focus, trigger: &trigger)
        XCTAssertEqual(above.pages, -1)
        XCTAssertEqual(session.focusPageId, y2027)
        let aboveLines = try XCTUnwrap(above.request.flatMap { InkCanvasView.nowLineRevealLines($0) })
        XCTAssertEqual(aboveLines.top, 2 * 60, accuracy: 1e-6, "two rows above the 5th's: the 3rd's top")
        XCTAssertEqual(above.after.y, 2 * 60 * cap, accuracy: 0.5, "y alone")
        XCTAssertEqual(above.after.x, above.landed.x, accuracy: 0.01, "x never moves")
        assertOnScreen(cell(.yearDay(month: 1, day: 5), of: y2027, session), rig, height: area.height, "above")
    }

    /// Review F2 of the lead's decision of 11/28 (§3.7) on the frozen canvas, through the screen's `ScreenPaths`: a finger
    /// that takes 「今日」's slide on the way ends it (`scrollViewWillBeginDragging`) and tells the screen nothing; a drag the
    /// directional lock kept vertical leaves x where the finger took it, here the middle of the screen 200 lu into December
    /// (past the 6 %), so the stop at the drag's end is on today's month — within the grace, so today is the focus (review
    /// UX-3's known edge). The screen's last viewport at that stop (the canvas reports the move before it tells of the stop)
    /// has the middle of the screen 500 lu short of where the slide was taking it, so the stop brings no request and the y the
    /// finger chose stays; before review F2 the request took y back to 12/31's cell (690.7 lu). The landscape iPad at 等倍, as
    /// `testTodaysSlideOfMonthsBringsTodaysCellOnScreen`, whose slides that go their whole way still bring the request.
    func testAFingerThatTakesTodaysSlideKeepsItsY() async throws {
        let suite = "InkCanvasMonthYearTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let paths = makePaths(defaults: defaults)
        let session = try await openThrough(paths, .month, device: ScreenPaths.Device(deviceClass: .iPad11, orientation: .landscape))
        XCTAssertEqual(session.pageIds, [sep, oct, nov, dec, jan])
        let fit = 1210.0 / 1400
        let rig = await attach(session, size: landscape, initialFit: true, initialScrollX: origin(nov, session),
                               onViewport: { paths.viewportArrived($0) })
        XCTAssertEqual(rig.zoom, fit, accuracy: 1e-6, "等倍")
        var taken: [ScreenPaths.Stopped] = []
        let shown = nov16
        rig.probe.onStop = { taken.append(paths.stopped($0, focus: shown, kind: .month, weekStart: .monday, boundary: {})) }
        defer { rig.probe.onStop = nil }

        let dec31 = DayKey(year: 2026, month: 12, day: 31)
        XCTAssertEqual(paths.today(dec31, now: try at(2026, 12, 31), viewport: paths.heading?.viewport, area: landscape, ratio: 1,
                                   fit: true), .slide(1))
        let caught = (origin(dec, session) + 200) * fit - landscape.width / 2
        rig.coordinator.spanSlideAnimation = { [weak coordinator = rig.coordinator] canvas, _ in
            // UIKit's animation, as far as the finger lets it go.
            canvas.contentOffset.x = caught
            coordinator?.scrollViewDidScroll(canvas)
        }
        rig.coordinator.slide(byPages: 1)
        await settle()
        XCTAssertNotNil(rig.coordinator.spanSlideTargetX, "the slide runs")
        XCTAssertEqual(session.focusPageId, dec, "past the 6 %: December is the focus page")
        XCTAssertEqual(taken.count, 0, "no stop while it runs")

        rig.coordinator.scrollViewWillBeginDragging(rig.canvas)
        XCTAssertNil(rig.coordinator.spanSlideTargetX, "the finger ended the slide")
        rig.canvas.contentOffset.y = 300 * fit
        rig.coordinator.scrollViewDidScroll(rig.canvas)
        rig.coordinator.scrollViewDidEndDragging(rig.canvas, willDecelerate: false)
        await settle()
        XCTAssertEqual(taken.count, 1, "the drag's end: one stop")
        let stopped = try XCTUnwrap(taken.first)
        XCTAssertEqual(stopped.focus, dec31, "today's month within the grace: today the focus (review UX-3's known edge)")
        XCTAssertNil(stopped.reveal, "a finger took the slide: no request")
        // The scroll view keeps its offset on the screen's pixels (half a point here).
        let middle = (rig.canvas.contentOffset.x + landscape.width / 2) / fit
        XCTAssertEqual((middle - origin(dec, session)) * fit, 200 * fit, accuracy: 0.5, "x stays where the finger took it")
        XCTAssertEqual(rig.canvas.contentOffset.y, 300 * fit, accuracy: 0.5, "the y the finger chose stays")
    }
}
