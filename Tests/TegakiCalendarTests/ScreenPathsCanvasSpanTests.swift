@_spi(SpanLedger) import InkModel
import Layout
import PencilKit
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

// 1.3 (docs/M7C_CONTRACT.md §3.4 (d), B_DESIGN.md:208; wave C's plan §3.4 and the lead's decision C3-m9): the screen's
// reopening with the real canvas of the window (`InkCanvasView.Coordinator` attached to its container as `makeUIView` does,
// over a `SpanSession` that `ScreenPaths` opened on the live engine of SessionTestBed). A class of its own so the repeated
// run takes only the pure ScreenPathsSpanTests (C3-m2). No real sleep: the canvas's watch waits on its own `TestSleeper`,
// the session's timers on the bed's, and 1.2.3's 0.3 s settle wait is never started (PencilKit is not told, L5).

@MainActor
final class ScreenPathsCanvasSpanTests: XCTestCase {
    private var bed: SessionTestBed!
    private var faults: [String] = []
    private var savedOnFault: ((String) -> Void)!
    private var canvasSleeper: TestSleeper!
    private var coordinators: [InkCanvasView.Coordinator] = []
    private var paths: ScreenPaths!
    private var strokeClock: TimeInterval = 0

    private let w1123 = "w-2026-11-23"
    private let nov16 = DayKey(year: 2026, month: 11, day: 16)

    override func setUp() async throws {
        bed = try SessionTestBed("ScreenPathsCanvasSpanTests")
        faults = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
        canvasSleeper = TestSleeper()
        coordinators = []
        strokeClock = 0
        let sleeper = bed.sessionSleeper
        let made = ScreenPaths(sync: bed.engine, onePage: OnePageSession(sync: bed.engine, sleep: { await sleeper.sleep($0) }),
                               screenshot: false, settingOn: { true },
                               defaults: UserDefaults(suiteName: "ScreenPathsCanvasSpanTests-\(UUID().uuidString)") ?? .standard,
                               sleep: { await sleeper.sleep($0) },
                               clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) })
        bed.engine.onRemoteUpdate = { [weak made] in _ = made?.remoteUpdated($0, shownPageId: "") }
        bed.engine.onRemoteDelete = { [weak made] in _ = made?.remoteDeleted($0, shownPageId: "") }
        paths = made
    }

    override func tearDown() async throws {
        for coordinator in coordinators {
            coordinator.detach()
        }
        await canvasSleeper?.advance()
        coordinators = []
        paths = nil
        SpanSession.onFault = savedOnFault
        bed?.tearDown()
        bed = nil
    }

    private func opening() -> ScreenPaths.Opening {
        ScreenPaths.Opening(kind: .week, focus: nov16, weekStart: .monday,
                            device: ScreenPaths.Device(deviceClass: .iPad11, orientation: .portrait), paperArea: nil,
                            context: SpanSession.PaperContext(now: bed.now, calendar: SessionTestBed.tokyo))
    }

    /// The window's canvas as the screen builds it (`CalendarRootScreen.joinedCanvas`, the inputs the test reads).
    private func canvasView(_ session: SpanSession) -> InkCanvasView {
        let focus = session.layout.pages[min(max(0, session.focusSlot), session.layout.pages.count - 1)]
        let sleeper = canvasSleeper!
        let bed = bed!
        return InkCanvasView(
            layout: session.layout,
            paper: ScreenPaths.paper(of: focus) ?? .week(WeekPaperContent(layout: focus as! WeekPageLayout)),
            tool: .ink(InkPresets.defaultPen),
            allowFinger: false,
            page: .constant(InkPage(pageId: session.layout.pageId)),
            initialScrollY: 0,
            onTap: { _, _ in },
            onInkBoundsChanged: {},
            undoTrigger: 0,
            redoTrigger: 0,
            onViewportChange: { [weak paths] in paths?.viewportArrived($0) },
            span: session,
            sleep: { await sleeper.sleep($0) },
            clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) }
        )
    }

    /// The canvas attached to its container (834 × 955) as `makeUIView` does and settled.
    private func attach(_ session: SpanSession) async -> (InkCanvasView.Coordinator, InkCanvasContainerView) {
        let view = canvasView(session)
        let coordinator = InkCanvasView.Coordinator(parent: view)
        let container = InkCanvasContainerView(paperView: PaperView(content: view.paper), canvasView: InkBandCanvasView())
        coordinator.attach(container)
        container.frame = CGRect(x: 0, y: 0, width: 834, height: 955)
        container.layoutSubviews()
        await settle()
        coordinators.append(coordinator)
        return (coordinator, container)
    }

    private func settle(_ turns: Int = 24) async {
        for _ in 0..<turns {
            await Task.yield()
        }
    }

    /// A short pen stroke centred near (x, y) of the band.
    private func shortStroke(at x: CGFloat, _ y: CGFloat) -> PKStroke {
        strokeClock += 1
        var points: [PKStrokePoint] = []
        for i in 0..<5 {
            let step = CGFloat(i)
            let px: CGFloat = x - 20 + step * 10
            let py: CGFloat = y + CGFloat(i % 2)
            let offset: TimeInterval = TimeInterval(i) * 0.01
            let altitude: CGFloat = CGFloat.pi / 2
            points.append(PKStrokePoint(location: CGPoint(x: px, y: py), timeOffset: offset, size: CGSize(width: 3.5, height: 3.5),
                                        opacity: 1, force: 0.5, azimuth: 0, altitude: altitude))
        }
        let created = Date(timeIntervalSince1970: 1_790_000_000 + strokeClock)
        let path = PKStrokePath(controlPoints: points, creationDate: created)
        return PKStroke(ink: PKInk(.pen, color: .black), path: path, transform: .identity, mask: nil)
    }

    /// §3.4 (d), B_DESIGN.md:208, C3-m9: the screen opens anew (a date tap) while the old canvas holds a stroke PencilKit has
    /// not told of; SwiftUI takes the old canvas away after the new window is up (`dismantleUIView` → `detach`), and its hand-over
    /// reaches the closing window, which saves it, hands the page to the new window and is let go. Without the closing window
    /// the old session would only have its own 1.5 s timer, gone with the canvas, and the stroke would be lost.
    func testReopenKeepsTheOldCanvasLastStroke() async throws {
        XCTAssertEqual(paths.open(opening()), .joined)
        let old = try XCTUnwrap(paths.span)
        await old.prefetch()
        let (coordinator, container) = await attach(old)
        let cell = try XCTUnwrap(old.layout.cells[SpanName.prefixed(.grid, page: w1123)])
        let canvas = container.canvasView
        canvas.delegate = nil
        canvas.drawing = PKDrawing(strokes: [shortStroke(at: cell.minX + 300, cell.minY + 300)])
        canvas.delegate = coordinator
        XCTAssertEqual(coordinator.ledger.page.liveStrokeCount, 0, "PencilKit has not told")

        XCTAssertEqual(paths.open(opening()), .joined)
        let fresh = try XCTUnwrap(paths.span)
        XCTAssertNotEqual(fresh.id, old.id)
        XCTAssertEqual(paths.closing.map(\.session.id), [old.id])
        XCTAssertFalse(bed.store.exists(w1123))

        coordinator.detach() // SwiftUI takes the old canvas away
        await settle()
        XCTAssertEqual(bed.store.load(w1123).liveStrokeCount, 1, "saved from the closing window")
        XCTAssertEqual(fresh.page(w1123)?.liveStrokeCount, 1, "and handed to the new window")
        XCTAssertTrue(paths.closing.isEmpty, "let go after the hand-over")
        XCTAssertEqual(faults, [])
    }
}
