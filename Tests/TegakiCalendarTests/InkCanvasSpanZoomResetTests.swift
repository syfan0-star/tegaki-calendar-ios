@_spi(SpanLedger) import InkModel
import Layout
import PencilKit
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

// 1.4.1 (docs/R1_4_1_CONTRACT.md §6.1, §3.6–§3.8, 0e-7–0e-9): 等倍 on the joined path. The canvas with a window of joined
// pages is built as the frozen `InkCanvasSpanTests` builds it (TESTS_1_3: that file is not touched, so the parts of its rig
// these tests need are copied here): `InkCanvasContainerView` with an `InkBandCanvasView`, `Coordinator.attach`, a
// `SpanSession` of the live `SyncEngine` of `SessionTestBed`, the canvas's 0.5 s watch on its own `TestSleeper` (never
// advanced before `tearDown`, so a shift here is the one the press asked for), the bed's fixed clock. A pinch and a slide are
// the calls UIKit would make (`spanSlideAnimation` stands in for the slide's animation; XCTest cannot fling, so the fling's
// stop is left to the check table's row 6, §3.8).
//
// The pages: iPad 11 portrait, five Monday weeks around 11/16 (R = 2): 11/02 … 11/30; the paper area 834 × 955 pt, the
// overview's zoom 0.4974, one week 696.35 pt; the iPhone in landscape at the cap (874 × 205: 3 weeks / 5 days across).

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

    /// The canvas as the screen builds it for a session, with the press count `zoomResetTrigger` (the screen's `@State`).
    private func makeView(_ session: SpanSession, probe: SpanProbe, isSheetOpen: Bool = false, zoomResetTrigger: Int = 0) -> InkCanvasView {
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
            zoomResetTrigger: zoomResetTrigger
        )
    }

    /// The canvas attached to its container as `makeUIView` does, laid out once in the paper area and settled.
    private func attach(_ session: SpanSession, width: CGFloat = 834, height: CGFloat = 955) async -> SpanRig {
        let probe = SpanProbe()
        let view = makeView(session, probe: probe)
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
        rig.probe.ratios.removeAll()
        rig.probe.zooming.removeAll()
    }

    /// The band x `mid` (lu) put in the middle of the screen with 0:00 at the top, as a finger leaves it (no end of the
    /// movement told: the watch waits on the sleeper), the focus following on the next turn.
    private func put(_ rig: SpanRig, mid: CGFloat) async {
        rig.canvas.contentOffset = CGPoint(x: mid * rig.zoom - rig.container.bounds.width / 2, y: 0)
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

    /// §3.8: zoomed in (1.0) with the middle of the screen a quarter into the week after the focus (the focus followed it,
    /// no stop told yet): one press goes back to the band's opening zoom on the next turn, puts that week's middle in the
    /// middle of the screen (`applyBandOpening`'s rule) with 0:00 at the top, reports ratio 1, and asks for the shift check:
    /// the window shifts around that week at once (the watch is never woken here), and the week stays in the middle.
    func testZoomedInThePageUnderTheMiddleComesToTheMiddleAndTheWindowShifts() async throws {
        let session = try await open()
        let rig = await attach(session)
        let open = rig.zoom
        XCTAssertEqual(open, 0.4974, accuracy: 1e-4)
        await pinch(rig, to: 1.0)
        XCTAssertEqual(rig.zoom, 1.0, accuracy: 1e-6)
        await put(rig, mid: origin(w1123, session) + 0.25 * session.plan.pageWidth)
        XCTAssertEqual(session.focusPageId, w1123, "the focus followed the middle of the screen")
        XCTAssertEqual(rig.coordinator.spanShiftCount, 0, "no stop was told of")

        update(rig, zoomResetTrigger: 1)
        XCTAssertEqual(rig.zoom, 1.0, accuracy: 1e-6, "never inside the SwiftUI update")
        await settle()
        XCTAssertEqual(rig.zoom, open, accuracy: 1e-6, "等倍: the band's opening zoom")
        XCTAssertEqual(rig.probe.ratios.count, 1, "ratio 1 reported once")
        XCTAssertEqual(rig.probe.ratios.first ?? 0, 1, accuracy: 1e-6)
        XCTAssertEqual(rig.probe.zooming, [false])
        XCTAssertEqual(rig.coordinator.spanShiftCount, 1, "the shift check the press asked for shifted the window")
        XCTAssertEqual(session.pageIds.first, w1109, "the window around 11/23")
        XCTAssertEqual(session.focusPageId, w1123)
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion, "the canvas took it")
        // UIKit puts each offset on the screen's pixels; the shift moves x once more: ± 1 pt.
        XCTAssertEqual(middle(of: w1123, rig), 417, accuracy: 1, "the week under the middle of the screen, in the middle")
        XCTAssertEqual(rig.canvas.contentOffset.y, 0, accuracy: 0.5, "0:00 at the top (the week is no taller than the screen: its top, as it opens)")
        XCTAssertEqual(rig.probe.viewports.last?.zoom ?? 0, open, accuracy: 1e-6, "the heading follows")
    }

    /// §3.8 先に止める物: zoomed in, an arrow's slide runs (UIKit's animation stood in for: the band does not move) and a
    /// second press waits for it. 等倍 stops the slide and drops the waiting page, then goes back: the opening zoom, the week
    /// under the middle (still the focus week) in the middle, and no slide afterwards.
    func testAnArrowsSlideIsStoppedFirst() async throws {
        let session = try await open()
        let rig = await attach(session)
        let open = rig.zoom
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
        XCTAssertEqual(rig.zoom, open, accuracy: 1e-6, "then 等倍")
        XCTAssertEqual(middle(of: w1116, rig), 417, accuracy: 1, "the week under the middle, in the middle")
        XCTAssertEqual(rig.coordinator.spanLastSlideTargetX, aimed, "the waiting press was dropped: no slide after it")
        XCTAssertEqual(rig.probe.ratios.count, 1)
        XCTAssertEqual(session.focusPageId, w1116)
    }

    /// §3.8 (0e-9): while a finger holds or drags the band (`spanMotionOverride`, XCTest's stand-in for UIKit's tracking and
    /// dragging) a press is dropped, and not kept: when the finger is gone the zoom is still the pinch's. The next press works.
    func testAFingerOnTheBandDropsThePress() async throws {
        let session = try await open()
        let rig = await attach(session)
        let open = rig.zoom
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
        update(rig, zoomResetTrigger: 2)
        await settle()
        XCTAssertEqual(rig.zoom, open, accuracy: 1e-6, "the next press")
        XCTAssertEqual(rig.probe.ratios.count, 1)
    }

    /// §3.6: on an iPhone in landscape at the cap (874 × 205) the joined week and day go back to the cap — 3 weeks / 5 days
    /// across, the lowest and the opening zoom there — with the focus page in the middle, and report ratio 1.
    func testTheCappedIPhoneLandscapeGoesBackToThreeWeeksAndFiveDays() async throws {
        var number = 0
        for (kind, across) in [(PageKind.week, CGFloat(3)), (.day, 5)] {
            number += 1
            let session = try await open(kind, number: number, deviceClass: .iPhone, orientation: .landscape, overviewCap: true)
            let rig = await attach(session, width: 874, height: 205)
            let cap = 874 / (across * ZoomPolicy.paperWidth(kind))
            XCTAssertEqual(rig.zoom, cap, accuracy: 0.0001, "\(kind): opens at the cap")
            await pinch(rig, to: 2 * cap)
            XCTAssertEqual(rig.zoom, 2 * cap, accuracy: 0.0001, "\(kind): zoomed in")
            let focus = session.focusPageId
            await put(rig, mid: origin(focus, session) + session.plan.pageWidth / 2)
            update(rig, zoomResetTrigger: 1)
            await settle()
            XCTAssertEqual(rig.zoom, cap, accuracy: 0.0001, "\(kind): back to the cap")
            XCTAssertEqual(rig.page * across, 874, accuracy: 0.5, "\(kind): \(across) pages across")
            XCTAssertEqual(middle(of: focus, rig), 437, accuracy: 1, "\(kind): the focus page in the middle")
            XCTAssertEqual(rig.probe.ratios.last ?? 0, 1, accuracy: 0.001, "\(kind): the cap is ratio 1")
        }
    }

    /// §3.7 (0e-8): a turn keeps the focus page's place on it (`turnAnchor`, UI1-R2) until the window is decided anew; a sheet
    /// holds that here. Zoomed in, the band turned to landscape with the middle of the screen a quarter into the focus week
    /// (11/16), then the canvas moved it a week on (no finger: the anchor stays, the focus with it). 等倍 forgets the anchor:
    /// the week now under the middle (11/23) comes to the middle and is the focus at once, and when the sheet closes the
    /// window is decided anew around it, the week staying where it is. Kept, the anchor would take the focus — and the band,
    /// when the window is decided anew — back to 11/16.
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
        let open = rig.canvas.minimumZoomScale
        XCTAssertEqual(rig.zoom, open, accuracy: 1e-6, "等倍 (the week's lowest zoom is its opening zoom)")
        XCTAssertEqual(rig.zoom, 615.0 / 1920, accuracy: 1e-3)
        XCTAssertEqual(middle(of: w1123, rig), 605, accuracy: 1, "the week under the middle, in the middle")
        XCTAssertEqual(session.focusPageId, w1123, "the anchor is forgotten: the focus is the week in the middle")

        update(rig, isSheetOpen: false, zoomResetTrigger: 1)
        await settle()
        XCTAssertEqual(session.focusPageId, w1123, "decided anew around 11/23")
        XCTAssertEqual(session.pageIds.count, 7, "the landscape window")
        XCTAssertFalse(session.needsShift)
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion)
        XCTAssertEqual(middle(of: w1123, rig), 605, accuracy: 3, "the week stays in the middle")
        XCTAssertEqual(rig.probe.ratios.count, 1)
    }
}
