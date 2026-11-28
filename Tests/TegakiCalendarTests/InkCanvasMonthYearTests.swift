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
    /// edge at fit); `tool` and the ↶ ↷ counts `undoTrigger` / `redoTrigger` (the screen's `@State`, review TEST-1).
    private func makeView(_ session: SpanSession, probe: SpanProbe, zoomResetTrigger: Int = 0, initialFit: Bool = false,
                          initialScrollX: CGFloat = 0, tool: CanvasTool? = nil, undoTrigger: Int = 0,
                          redoTrigger: Int = 0) -> InkCanvasView {
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
            onViewportChange: { probe.viewports.append($0) },
            onZoomRatioChange: { probe.ratios.append($0) },
            onZoomingChange: { probe.zooming.append($0) },
            span: session,
            sleep: { await sleeper.sleep($0) },
            clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) },
            onSpanStop: { probe.stops.append($0) },
            zoomResetTrigger: zoomResetTrigger,
            initialFit: initialFit,
            onZoomFitChange: { probe.fits.append($0) }
        )
    }

    /// The canvas attached to its container as `makeUIView` does, laid out once in the paper area and settled (the first
    /// layout's report stays in the probe).
    private func attach(_ session: SpanSession, size: CGSize, initialFit: Bool = false, initialScrollX: CGFloat = 0) async -> SpanRig {
        let probe = SpanProbe()
        let view = makeView(session, probe: probe, initialFit: initialFit, initialScrollX: initialScrollX)
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

    /// `update(from:)` with the rig's session, `tool` and the ↶ ↷ counts so far (the screen's SwiftUI update).
    private func update(_ rig: SpanRig, tool: CanvasTool? = nil, undoTrigger: Int = 0, redoTrigger: Int = 0) {
        rig.coordinator.update(from: makeView(rig.session, probe: rig.probe, tool: tool ?? rig.coordinator.parent.tool,
                                              undoTrigger: undoTrigger, redoTrigger: redoTrigger))
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
}
