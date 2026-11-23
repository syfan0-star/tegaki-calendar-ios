@_spi(SpanLedger) import InkModel
import Layout
import PencilKit
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

// 1.4.1 (docs/R1_4_1_CONTRACT.md §6.1, §3.6–§3.8, §16.3, §16.6, 0e-7–0e-9): 等倍 on the joined path. The canvas with a window
// of joined pages is built as the frozen `InkCanvasSpanTests` builds it (TESTS_1_3: that file is not touched, so the parts of
// its rig these tests need are copied here): `InkCanvasContainerView` with an `InkBandCanvasView`, `Coordinator.attach`, a
// `SpanSession` of the live `SyncEngine` of `SessionTestBed`, the canvas's 0.5 s watch on its own `TestSleeper` (never
// advanced before `tearDown`, so a shift here is the one the press asked for), the bed's fixed clock. A pinch and a slide are
// the calls UIKit would make (`spanSlideAnimation` stands in for the slide's animation; XCTest cannot fling, so the fling's
// stop is left to the check table's row 6, §3.8).
//
// 等倍 on the joined week and day is fit (§16.3, the owner's words of 11/22): the page under the middle of the screen
// exactly as wide as the screen, its edges on the screen's (x = origin × fit), reported as the ratio fit / open and the fit
// state (`onZoomFitChange`); in that state a change of width goes to the new fit with the page's edges on the screen's, a
// band that stopped short is lined up again by a press, and `initialFit` opens the focus page edge to edge.
//
// The pages: iPad 11 portrait, five Monday weeks around 11/16 (R = 2): 11/02 … 11/30; the paper area 834 × 955 pt, the
// overview's zoom 0.4974, one week 696.35 pt; fit 834 / 1,400 = 0.5957, one week 834 pt (the middle of a week at 417); the
// iPhone in landscape at the cap (874 × 205: 3 weeks / 5 days across), where 等倍 is one week / one day across.

@MainActor
final class InkCanvasSpanZoomResetTests: XCTestCase {
    private var bed: SessionTestBed!
    private var faults: [String] = []
    private var savedOnFault: ((String) -> Void)!
    private var canvasSleeper: TestSleeper!
    private var rigs: [SpanRig] = []

    private let w1109 = "w-2026-11-09"
    private let w1116 = "w-2026-11-16"
    private let w1123 = "w-2026-11-23"
    private let nov16 = DayKey(year: 2026, month: 11, day: 16)
    private let pen = CanvasTool.ink(InkPresets.defaultPen)

    override func setUp() async throws {
        bed = try SessionTestBed("InkCanvasSpanZoomResetTests")
        faults = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
        canvasSleeper = TestSleeper()
        rigs = []
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

    // MARK: The rig

    /// What the canvas told its owner.
    private final class SpanProbe {
        var viewports: [PaperViewport] = []
        var stops: [SpanSession.Stop] = []
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
        var zoom: CGFloat { container.canvasView.zoomScale }
        /// One page on screen (pt).
        var page: CGFloat { session.plan.pageWidth * container.canvasView.zoomScale }
    }

    private static func paper(of layout: any PageLayout) -> PaperContent {
        if let week = layout as? WeekPageLayout { return .week(WeekPaperContent(layout: week)) }
        if let day = layout as? DayPageLayout { return .day(DayPaperContent(layout: day)) }
        fatalError("only weeks and days are joined")
    }

    /// The canvas as the screen builds it for a session, with the press count `zoomResetTrigger` (the screen's `@State`),
    /// `initialFit` (the kind's stored fit, §16.3.4) and `initialScrollX` (band lu; the screen's `bandStart`: the focus page's
    /// left edge at fit).
    private func makeView(_ session: SpanSession, probe: SpanProbe, isSheetOpen: Bool = false, zoomResetTrigger: Int = 0,
                          initialFit: Bool = false, initialScrollX: CGFloat = 0) -> InkCanvasView {
        let focus = session.layout.pages[min(max(0, session.focusSlot), session.layout.pages.count - 1)]
        let sleeper = canvasSleeper!
        let bed = bed!
        return InkCanvasView(
            layout: session.layout,
            paper: Self.paper(of: focus),
            tool: pen,
            allowFinger: false,
            page: .constant(InkPage(pageId: session.layout.pageId)),
            initialScrollY: 0,
            initialScrollX: initialScrollX,
            onTap: { _, _ in },
            onInkBoundsChanged: {},
            undoTrigger: 0,
            redoTrigger: 0,
            onViewportChange: { probe.viewports.append($0) },
            onZoomRatioChange: { probe.ratios.append($0) },
            onZoomingChange: { probe.zooming.append($0) },
            span: session,
            sleep: { await sleeper.sleep($0) },
            clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) },
            isSheetOpen: isSheetOpen,
            onSpanStop: { probe.stops.append($0) },
            zoomResetTrigger: zoomResetTrigger,
            initialFit: initialFit,
            onZoomFitChange: { probe.fits.append($0) }
        )
    }

    /// The canvas attached to its container as `makeUIView` does, laid out once in the paper area and settled (the first
    /// layout's report stays in the probe).
    private func attach(_ session: SpanSession, width: CGFloat = 834, height: CGFloat = 955, initialFit: Bool = false,
                        initialScrollX: CGFloat = 0) async -> SpanRig {
        let probe = SpanProbe()
        let view = makeView(session, probe: probe, initialFit: initialFit, initialScrollX: initialScrollX)
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

    /// `update(from:)` with the rig's session, the sheet as asked and 等倍 pressed `zoomResetTrigger` times so far.
    private func update(_ rig: SpanRig, isSheetOpen: Bool = false, zoomResetTrigger: Int) {
        rig.coordinator.update(from: makeView(rig.session, probe: rig.probe, isSheetOpen: isSheetOpen, zoomResetTrigger: zoomResetTrigger))
    }

    /// The queued main-actor work (the press's turn, the shift check's, the next-turn deliveries, the prefetch's turns).
    private func settle(_ turns: Int = 24) async {
        for _ in 0..<turns {
            await Task.yield()
        }
    }

    /// A week session around 11/16 (or a day session) whose pages are read.
    private func open(_ kind: PageKind = .week, number: Int = 1, deviceClass: SpanDeviceClass = .iPad11,
                      orientation: SpanOrientation = .portrait, overviewCap: Bool = false) async throws -> SpanSession {
        let session = bed.session(kind, focus: nov16, number: number, deviceClass: deviceClass, orientation: orientation,
                                  overviewCap: overviewCap)
        await session.prefetch()
        return session
    }

    /// The band x (lu) of a window page's left edge.
    private func origin(_ pageId: String, _ session: SpanSession, file: StaticString = #filePath, line: UInt = #line) -> CGFloat {
        guard let x = session.origin(ofPage: pageId) else {
            XCTFail("\(pageId) is not in the window", file: file, line: line)
            return 0
        }
        return x
    }

    /// Where the middle of `pageId` is on the screen (pt from the canvas's left edge).
    private func middle(of pageId: String, _ rig: SpanRig, file: StaticString = #filePath, line: UInt = #line) -> CGFloat {
        (origin(pageId, rig.session, file: file, line: line) + rig.session.plan.pageWidth / 2) * rig.zoom - rig.canvas.contentOffset.x
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

    /// The band x `mid` (lu) put in the middle of the screen with the paper's `y` (pt; 0:00 by default) at the top, as a
    /// finger leaves it (no end of the movement told: the watch waits on the sleeper), the focus following on the next turn.
    private func put(_ rig: SpanRig, mid: CGFloat, y: CGFloat = 0) async {
        rig.canvas.contentOffset = CGPoint(x: mid * rig.zoom - rig.container.bounds.width / 2, y: y)
        rig.coordinator.scrollViewDidScroll(rig.canvas)
        await settle()
    }

    /// A rotation as UIKit lays it out: the paper area takes `size`, then the queued work.
    private func turn(_ rig: SpanRig, to size: CGSize) async {
        rig.container.frame = CGRect(origin: .zero, size: size)
        rig.container.layoutSubviews()
        await settle()
    }

    // MARK: Tests

    /// §3.8, §16.3.2: zoomed in (1.0) with the middle of the screen a quarter into the week after the focus (the focus followed
    /// it, no stop told yet) and 500 pt down: one press goes to fit on the next turn (834 / 1,400: one week across), that
    /// week edge to edge (`applyBandOpening`'s rule at fit: its middle in the middle of the screen), the paper y in the middle
    /// of the screen kept (the midY rule: the week is taller than the screen at fit), reports the ratio fit / open and the
    /// fit state, and asks for the shift check: the window shifts around that week at once (the watch is never woken here),
    /// and the week stays where it is.
    func testZoomedInThePageUnderTheMiddleComesToTheMiddleAndTheWindowShifts() async throws {
        let session = try await open()
        let rig = await attach(session)
        let open = rig.zoom
        XCTAssertEqual(open, 0.4974, accuracy: 1e-4)
        let fit = 834.0 / 1400
        await pinch(rig, to: 1.0)
        XCTAssertEqual(rig.zoom, 1.0, accuracy: 1e-6)
        await put(rig, mid: origin(w1123, session) + 0.25 * session.plan.pageWidth, y: 500)
        XCTAssertEqual(session.focusPageId, w1123, "the focus followed the middle of the screen")
        XCTAssertEqual(rig.coordinator.spanShiftCount, 0, "no stop was told of")
        let midY = (rig.canvas.contentOffset.y + 955.0 / 2) / rig.zoom

        update(rig, zoomResetTrigger: 1)
        XCTAssertEqual(rig.zoom, 1.0, accuracy: 1e-6, "never inside the SwiftUI update")
        await settle()
        XCTAssertEqual(rig.zoom, fit, accuracy: 1e-6, "等倍: fit, one week across")
        XCTAssertEqual(rig.page, 834, accuracy: 0.5, "one week as wide as the screen")
        XCTAssertEqual(rig.probe.ratios.count, 1, "reported once")
        XCTAssertEqual(rig.probe.ratios.first ?? 0, fit / open, accuracy: 1e-3, "the ratio fit / open")
        XCTAssertEqual(rig.probe.fits, [true], "the fit state")
        XCTAssertEqual(rig.probe.zooming, [false])
        XCTAssertEqual(rig.coordinator.spanShiftCount, 1, "the shift check the press asked for shifted the window")
        XCTAssertEqual(session.pageIds.first, w1109, "the window around 11/23")
        XCTAssertEqual(session.focusPageId, w1123)
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion, "the canvas took it")
        // UIKit puts each offset on the screen's pixels; the shift moves x once more: ± 1 pt.
        XCTAssertEqual(middle(of: w1123, rig), 417, accuracy: 1, "the week under the middle of the screen, edge to edge")
        let maxY = max(0, rig.canvas.contentSize.height + rig.canvas.contentInset.bottom - 955)
        XCTAssertEqual(rig.canvas.contentOffset.y, min(max(0, midY * fit - 955.0 / 2), maxY), accuracy: 1,
                       "the paper y in the middle of the screen kept (the midY rule)")
        XCTAssertGreaterThan(rig.canvas.contentOffset.y, 50, "not the top")
        XCTAssertEqual(rig.probe.viewports.last?.zoom ?? 0, fit, accuracy: 1e-6, "the heading follows")
    }

    /// §3.8 先に止める物: zoomed in, an arrow's slide runs (UIKit's animation stood in for: the band does not move) and a
    /// second press waits for it. 等倍 stops the slide and drops the waiting page, then goes to fit: the week under the
    /// middle (still the focus week) edge to edge, and no slide afterwards.
    func testAnArrowsSlideIsStoppedFirst() async throws {
        let session = try await open()
        let rig = await attach(session)
        await pinch(rig, to: 1.0)
        await put(rig, mid: origin(w1116, session) + session.plan.pageWidth / 2)
        rig.coordinator.spanSlideAnimation = { _, _ in }
        rig.coordinator.slide(byPages: 1)
        let aimed = rig.coordinator.spanLastSlideTargetX
        XCTAssertNotNil(rig.coordinator.spanSlideTargetX, "a slide runs")
        rig.coordinator.slide(byPages: 1)

        update(rig, zoomResetTrigger: 1)
        await settle()
        XCTAssertNil(rig.coordinator.spanSlideTargetX, "the slide was stopped")
        XCTAssertEqual(rig.zoom, 834.0 / 1400, accuracy: 1e-6, "then 等倍: fit")
        XCTAssertEqual(middle(of: w1116, rig), 417, accuracy: 1, "the week under the middle, edge to edge")
        XCTAssertEqual(rig.coordinator.spanLastSlideTargetX, aimed, "the waiting press was dropped: no slide after it")
        XCTAssertEqual(rig.probe.ratios.count, 1)
        XCTAssertEqual(rig.probe.fits, [true])
        XCTAssertEqual(session.focusPageId, w1116)
    }

    /// §3.8 (0e-9): while a finger holds or drags the band (`spanMotionOverride`, XCTest's stand-in for UIKit's tracking and
    /// dragging) a press is dropped, and not kept: when the finger is gone the zoom is still the pinch's. The next press works.
    func testAFingerOnTheBandDropsThePress() async throws {
        let session = try await open()
        let rig = await attach(session)
        await pinch(rig, to: 1.0)
        await put(rig, mid: origin(w1116, session) + session.plan.pageWidth / 2)
        rig.coordinator.spanMotionOverride = true
        update(rig, zoomResetTrigger: 1)
        await settle()
        XCTAssertEqual(rig.zoom, 1.0, accuracy: 1e-6, "a finger on the band: dropped")
        rig.coordinator.spanMotionOverride = nil
        await settle()
        XCTAssertEqual(rig.zoom, 1.0, accuracy: 1e-6, "not kept for later")
        XCTAssertEqual(rig.probe.ratios, [])
        XCTAssertEqual(rig.probe.fits, [])
        update(rig, zoomResetTrigger: 2)
        await settle()
        XCTAssertEqual(rig.zoom, 834.0 / 1400, accuracy: 1e-6, "the next press: fit")
        XCTAssertEqual(rig.probe.ratios.count, 1)
        XCTAssertEqual(rig.probe.fits, [true])
    }

    /// §16.3.5 (P-B6 イ; 1.4.1's first version went back to the cap): on an iPhone in landscape at the cap (874 × 205: it
    /// opens at 3 weeks / 5 days across) the joined week and day go to fit — one week / one day across (1,400 × z = 874,
    /// 1,000 × z = 874: 3 and 5 times the cap) — with the focus page edge to edge, its middle where it opened, and report the
    /// ratio fit / cap (3, 5) and the fit state. The focus page is the one the band opened on, read before the pinch: the
    /// pinch (`setZoomScale` keeps the offset at 0) leaves the band's first page under the middle and the stop makes that the
    /// focus (the probe branch r141-q-zr, run 44924491852: w-2026-10-26, d-2026-11-13), so a focus read after it is another page.
    func testTheCappedIPhoneLandscapeGoesToOneWeekAndOneDayAcross() async throws {
        var number = 0
        for (kind, across) in [(PageKind.week, CGFloat(3)), (.day, 5)] {
            number += 1
            let session = try await open(kind, number: number, deviceClass: .iPhone, orientation: .landscape, overviewCap: true)
            let rig = await attach(session, width: 874, height: 205)
            let cap = 874 / (across * ZoomPolicy.paperWidth(kind))
            XCTAssertEqual(rig.zoom, cap, accuracy: 0.0001, "\(kind): opens at the cap")
            let focus = session.focusPageId
            let opened = middle(of: focus, rig)
            XCTAssertEqual(opened, 437, accuracy: 1, "\(kind): opens with the focus page in the middle")
            await pinch(rig, to: 2 * cap)
            XCTAssertEqual(rig.zoom, 2 * cap, accuracy: 0.0001, "\(kind): zoomed in")
            await put(rig, mid: origin(focus, session) + session.plan.pageWidth / 2)
            update(rig, zoomResetTrigger: 1)
            await settle()
            XCTAssertEqual(rig.zoom, 874 / ZoomPolicy.paperWidth(kind), accuracy: 0.0001, "\(kind): fit")
            XCTAssertEqual(rig.page, 874, accuracy: 0.5, "\(kind): one page across")
            XCTAssertEqual(middle(of: focus, rig), opened, accuracy: 1, "\(kind): the focus page edge to edge, its middle where it opened")
            XCTAssertEqual(rig.probe.ratios.last ?? 0, across, accuracy: 0.001, "\(kind): fit is \(across) times the cap")
            XCTAssertEqual(rig.probe.fits.last, true, "\(kind): the fit state")
        }
    }

    /// §3.7 (0e-8): a turn keeps the focus page's place on it (`turnAnchor`, UI1-R2) until the window is decided anew; a sheet
    /// holds that here. Zoomed in, the band turned to landscape with the middle of the screen a quarter into the focus week
    /// (11/16), then the canvas moved it a week on (no finger: the anchor stays, the focus with it). 等倍 forgets the anchor:
    /// the week now under the middle (11/23) goes edge to edge at the landscape fit (1,210 / 1,400) and is the focus at once,
    /// and when the sheet closes the window is decided anew around it, the week staying where it is. Kept, the anchor would
    /// take the focus — and the band, when the window is decided anew — back to 11/16.
    func testTheTurnAnchorIsForgotten() async throws {
        let session = try await open()
        let rig = await attach(session)
        await pinch(rig, to: 1.0)
        await put(rig, mid: origin(w1116, session) + 0.25 * session.plan.pageWidth)
        XCTAssertEqual(session.focusPageId, w1116)
        update(rig, isSheetOpen: true, zoomResetTrigger: 0)
        await turn(rig, to: CGSize(width: 1_210, height: 615))
        XCTAssertEqual(rig.zoom, 1.0, accuracy: 1e-6, "zoomed in: the absolute zoom stays")
        XCTAssertEqual(session.focusPageId, w1116, "turned: the focus stays")
        XCTAssertEqual(session.pageIds.count, 5, "the sheet holds the window")

        rig.canvas.contentOffset.x += session.plan.pageWidth * rig.zoom
        rig.coordinator.scrollViewDidScroll(rig.canvas)
        await settle()
        XCTAssertEqual(session.focusPageId, w1116, "the anchor keeps the focus")

        update(rig, isSheetOpen: true, zoomResetTrigger: 1)
        await settle()
        XCTAssertEqual(rig.zoom, 1210.0 / 1400, accuracy: 1e-6, "等倍: the landscape fit, one week across")
        XCTAssertEqual(rig.page, 1210, accuracy: 0.5)
        XCTAssertEqual(middle(of: w1123, rig), 605, accuracy: 1, "the week under the middle, edge to edge")
        XCTAssertEqual(session.focusPageId, w1123, "the anchor is forgotten: the focus is the week in the middle")

        update(rig, isSheetOpen: false, zoomResetTrigger: 1)
        await settle()
        XCTAssertEqual(session.focusPageId, w1123, "decided anew around 11/23")
        XCTAssertEqual(session.pageIds.count, 7, "the landscape window")
        XCTAssertFalse(session.needsShift)
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion)
        XCTAssertEqual(middle(of: w1123, rig), 605, accuracy: 3, "the week stays in the middle")
        XCTAssertEqual(rig.probe.ratios.count, 1)
        XCTAssertEqual(rig.probe.fits, [true])
    }

    /// §16.3.2 (the edges lined up), §16.3.5 (a fling that stopped short): at fit with the band 250 pt (0.3 of a week) off
    /// the week edges — a slow fling's 6 % snap stopping short — a press lines the week under the middle (still 11/16) up
    /// with the screen's edges again, at the same zoom, and reports it like any reset (the ratio fit / open, the fit state).
    /// Lined up, the next press does nothing.
    func testAtFitABandThatStoppedShortLinesUpAgain() async throws {
        let session = try await open()
        let rig = await attach(session)
        let open = rig.zoom
        let fit = 834.0 / 1400
        update(rig, zoomResetTrigger: 1)
        await settle()
        XCTAssertEqual(rig.zoom, fit, accuracy: 1e-6, "等倍 from the opening zoom: fit")
        XCTAssertEqual(middle(of: w1116, rig), 417, accuracy: 1, "the focus week edge to edge")
        drop(rig)

        rig.canvas.contentOffset.x += 0.3 * 834
        rig.coordinator.scrollViewDidScroll(rig.canvas)
        await settle()
        XCTAssertEqual(middle(of: w1116, rig), 417 - 0.3 * 834, accuracy: 1, "stopped short: the week 250 pt off")
        XCTAssertEqual(session.focusPageId, w1116)
        update(rig, zoomResetTrigger: 2)
        await settle()
        XCTAssertEqual(rig.zoom, fit, accuracy: 1e-6, "still fit")
        XCTAssertEqual(middle(of: w1116, rig), 417, accuracy: 1, "lined up again: the week under the middle edge to edge")
        XCTAssertEqual(rig.probe.ratios.count, 1, "reported like any reset")
        XCTAssertEqual(rig.probe.ratios.first ?? 0, fit / open, accuracy: 1e-3)
        XCTAssertEqual(rig.probe.fits, [true])

        update(rig, zoomResetTrigger: 3)
        await settle()
        XCTAssertEqual(middle(of: w1116, rig), 417, accuracy: 1, "lined up: nothing moves")
        XCTAssertEqual(rig.probe.ratios.count, 1, "lined up: nothing is reported")
    }

    /// §16.3.3 (Z2-6; MZ5): in the fit state a change of width goes to the new fit with the page's edges on the screen's
    /// (`bandWidthChanged` puts the band x in the middle back at the new zoom: origin × fit). The 11-inch iPad's week at fit
    /// turned to landscape (1,210 × 615: one week 1,210 pt, its middle at 605) and back (834, 417); the focus stays; a turn
    /// reports nothing.
    func testAtFitTheBandFollowsAChangeOfWidth() async throws {
        let session = try await open()
        let rig = await attach(session)
        drop(rig)
        update(rig, zoomResetTrigger: 1)
        await settle()
        XCTAssertEqual(rig.page, 834, accuracy: 0.5, "portrait: one week across")
        XCTAssertEqual(middle(of: w1116, rig), 417, accuracy: 1)
        await turn(rig, to: CGSize(width: 1_210, height: 615))
        XCTAssertEqual(rig.zoom, 1210.0 / 1400, accuracy: 1e-6, "landscape: the new fit")
        XCTAssertEqual(rig.page, 1210, accuracy: 0.5, "landscape: one week across")
        XCTAssertEqual(middle(of: w1116, rig), 605, accuracy: 1, "landscape: the week edge to edge")
        XCTAssertEqual(session.focusPageId, w1116, "landscape: the focus stays")
        await turn(rig, to: CGSize(width: 834, height: 955))
        XCTAssertEqual(rig.zoom, 834.0 / 1400, accuracy: 1e-6, "portrait again: fit")
        XCTAssertEqual(rig.page, 834, accuracy: 0.5)
        XCTAssertEqual(middle(of: w1116, rig), 417, accuracy: 1, "portrait again: the week edge to edge")
        XCTAssertEqual(session.focusPageId, w1116)
        XCTAssertEqual(rig.probe.ratios.count, 1, "the press's report only: a turn reports nothing")
        XCTAssertEqual(rig.probe.fits, [true])
    }

    /// §16.3.4 (the joined path's `initialFit`; §16.10: both paths open at fit): the screen opens the band with the kind's
    /// stored fit and the focus page's left edge (`bandStart` at fit): the focus week edge to edge at fit, and the first layout
    /// reports the ratio fit / open and the fit state; a press then does nothing. On the 18 Pro Max's portrait week (440 ×
    /// 622, open = fit) the opening's own rule (ratio 1) puts the focus week in the middle: edge to edge too, at the top,
    /// ratio 1 and the fit state.
    func testInitialFitOpensTheFocusPageEdgeToEdge() async throws {
        let session = try await open()
        let rig = await attach(session, initialFit: true, initialScrollX: origin(w1116, session))
        XCTAssertEqual(rig.zoom, 834.0 / 1400, accuracy: 1e-6, "opens at fit")
        XCTAssertEqual(rig.page, 834, accuracy: 0.5)
        XCTAssertEqual(middle(of: w1116, rig), 417, accuracy: 1, "the focus week edge to edge")
        XCTAssertEqual(rig.probe.ratios.count, 1, "the first layout's report")
        XCTAssertEqual(rig.probe.ratios.first ?? 0, (834.0 / 1400) / (955.0 / 1920), accuracy: 1e-3, "the ratio fit / open")
        XCTAssertEqual(rig.probe.fits, [true], "the fit state")
        update(rig, zoomResetTrigger: 1)
        await settle()
        XCTAssertEqual(rig.probe.ratios.count, 1, "at fit, edge to edge: a press does nothing")
        XCTAssertEqual(middle(of: w1116, rig), 417, accuracy: 1)

        let phone = try await open(number: 2, deviceClass: .iPhone)
        let small = await attach(phone, width: 440, height: 622, initialFit: true, initialScrollX: origin(w1116, phone))
        XCTAssertEqual(small.zoom, 440.0 / 1400, accuracy: 1e-6, "the phone: fit (= open)")
        XCTAssertEqual(middle(of: w1116, small), 220, accuracy: 1, "the phone: the focus week edge to edge")
        XCTAssertEqual(small.canvas.contentOffset.y, 0, accuracy: 0.5, "the phone: at the top")
        XCTAssertEqual(small.probe.ratios.first ?? 0, 1, accuracy: 1e-6, "the phone: ratio 1")
        XCTAssertEqual(small.probe.fits, [true], "the phone: the fit state")
    }
}
