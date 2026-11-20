@_spi(SpanLedger) import InkModel
import Layout
import PencilKit
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

// 1.4 (docs/M7D_CONTRACT.md §4.9, §6; §1.5's width reading, C3, 0d-44): the iPhone Duo folding and unfolding is the
// window's width changing — the inner screen's paper 669 pt wide (CODE_SURVEY §3.2's estimate: CI could not open the inner
// screen, path 3 of §4.2) and the outer one's 382 pt (measured: duo-shots run 44696154794, the outer window 466 pt less its
// 84 pt side strip; the heights per kind are the measured ones too, see `outerPortrait`). Tests only: the frozen
// canvas (`InkCanvasView`, built as `makeUIView` builds it) and the session are called as they are, over a live
// `SyncEngine` (SessionTestBed: a temporary store, the fake database, `TestSleeper`s for every wait, a fixed clock; the
// canvas's watch on its own sleeper, never advanced with the session's; 1.2.3's settle wait ended, not waited for).
//
// The joined path (a week or a day of an iPhone's plan, the cap asked as the screen asks it): (a) while the pen is on the
// paper the window is not decided anew, (b) once it lifted and the paper is still it is, once (and after a scroll, once it
// stopped), (c) the focus page and the kind stay, (d) the pages' JSON stays byte for byte, (e) no page is marked dirty,
// (f) the stored zoom ratio of the kind (`zoomRatio.<kind>`) stays, (g) with the window of now (`overviewCapNow`) the outer
// screen's landscape (measured: the week's paper 594 × 141, the day's 594 × 190) caps the overview and the inner one's
// (951 × 446, estimated) does not, from the window decided anew.
// The one-page path (the month and the year, and the week and the day with 「前後のページを横につなげる」 off): (c)–(f) only —
// neither the middle's x (§1.5: the width read with the old offset, kept as 1.3's) nor "not while writing" (not that path's
// promise) is compared. A mutation that takes the frozen canvas's `pendingRedecide` path away fails the first two
// (`r14-q-m1`, not merged).

@MainActor
final class DuoFoldTests: XCTestCase {
    private var bed: SessionTestBed!
    private var faults: [String] = []
    private var savedOnFault: ((String) -> Void)!
    private var savedDefaults: UserDefaults!
    private var scratch: UserDefaults!
    private var suiteName = ""
    private var canvasSleeper: TestSleeper!
    private var rigs: [JoinedRig] = []
    private var strokeClock: TimeInterval = 0
    /// The window of now for `overviewCapNow` (true: the outer screen, false: the inner one).
    private var capNow = true

    private let nov16 = DayKey(year: 2026, month: 11, day: 16)
    private let nov18 = DayKey(year: 2026, month: 11, day: 18)
    private let w1109 = "w-2026-11-09"
    private let w1116 = "w-2026-11-16"
    private let w1123 = "w-2026-11-23"
    private let d1117 = "d-2026-11-17"
    private let d1118 = "d-2026-11-18"
    private let d1119 = "d-2026-11-19"
    private let pen = CanvasTool.ink(InkPresets.defaultPen)

    /// The paper areas (pt) of the Duo's inner screen in portrait and in landscape: estimates (CODE_SURVEY §3.2; path 3, the
    /// inner screen was not opened on CI).
    private let innerPortrait = CGSize(width: 669, height: 780)
    private let innerLandscape = CGSize(width: 951, height: 446)

    /// The paper area (pt) of the Duo's outer screen in portrait, measured (1.4 D1d; duo-shots run 44696154794, the `paper=`
    /// of the last `duo measure:` line of each photo): the window 466 × 678 less the 84 pt side strip, the two header rows,
    /// the toolbar and the photo's all-day band. The one-page week and day take the joined path's (measured there only).
    private func outerPortrait(_ kind: PageKind) -> CGSize {
        switch kind {
        case .month: return CGSize(width: 382, height: 456.67)
        case .week: return CGSize(width: 382, height: 343)
        case .day: return CGSize(width: 382, height: 402)
        case .year: return CGSize(width: 382, height: 435)
        }
    }

    /// The paper area (pt) of the Duo's outer screen in landscape for the week or the day, measured the same way: the window
    /// 678 × 466 less the 84 pt side strip and two header rows (594 is under the header's one-row width of 600).
    private func outerLandscape(_ kind: PageKind) -> CGSize {
        kind == .day ? CGSize(width: 594, height: 190) : CGSize(width: 594, height: 141)
    }

    override func setUp() async throws {
        bed = try SessionTestBed("DuoFoldTests")
        faults = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
        suiteName = "DuoFoldTests-\(UUID().uuidString)"
        scratch = UserDefaults(suiteName: suiteName)
        savedDefaults = AppSettings.defaults
        AppSettings.defaults = scratch
        canvasSleeper = TestSleeper()
        rigs = []
        strokeClock = 0
        capNow = true
    }

    override func tearDown() async throws {
        for rig in rigs {
            rig.coordinator.detach()
        }
        await canvasSleeper?.advance()
        rigs = []
        XCTAssertEqual(faults, [], "no fault of the window's bookkeeping")
        SpanSession.onFault = savedOnFault
        AppSettings.defaults = savedDefaults
        scratch?.removePersistentDomain(forName: suiteName)
        bed?.tearDown()
        bed = nil
    }

    // MARK: The joined path's rig (the shape of InkCanvasSpanTests')

    /// What the canvas told its owner.
    private final class Probe {
        var ratios: [CGFloat] = []
        var stops: [SpanSession.Stop] = []
        var persisted: [String] = []
    }

    @MainActor
    private struct JoinedRig {
        let coordinator: InkCanvasView.Coordinator
        let container: InkCanvasContainerView
        let probe: Probe
        let session: SpanSession
        var canvas: PKCanvasView { container.canvasView }
    }

    private static func paper(of layout: any PageLayout) -> PaperContent {
        if let week = layout as? WeekPageLayout { return .week(WeekPaperContent(layout: week)) }
        if let day = layout as? DayPageLayout { return .day(DayPaperContent(layout: day)) }
        fatalError("only weeks and days are joined")
    }

    /// A window of an iPhone's plan around `focus` (the Duo's plan, inner and outer, §4.6), the cap asked as the screen asks
    /// it and the window of now read from `capNow` (`ScreenPaths.makeSession`'s inputs), `stored` written first, its pages read.
    private func open(_ kind: PageKind, focus: DayKey, orientation: SpanOrientation, paperArea: CGSize, stored: [InkPage] = [],
                      number: Int = 1) async throws -> SpanSession {
        for page in stored {
            try bed.store.save(page)
        }
        let sleeper = bed.sessionSleeper
        let session = SpanSession(kind: kind, weekStart: .monday, focus: focus, sync: bed.engine, deviceClass: .iPhone,
                                  orientation: orientation, number: number,
                                  context: SpanSession.PaperContext(now: bed.now, calendar: SessionTestBed.tokyo), paperArea: paperArea,
                                  overviewCap: true, overviewCapNow: { [weak self] in self?.capNow ?? true },
                                  sleep: { await sleeper.sleep($0) },
                                  clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 1_790_000_000) })
        bed.engine.onRemoteUpdate = { [weak session] in session?.remoteUpdated($0) }
        bed.engine.onRemoteDelete = { [weak session] in session?.remoteDeleted($0) }
        await session.prefetch()
        return session
    }

    /// The canvas as the screen builds it for a session: it opens at the kind's stored ratio and the end of a pinch's ratio goes
    /// where the screen puts it (`currentRatio`, `AppSettings.setZoomRatio`; here the scratch suite).
    private func makeView(_ session: SpanSession, probe: Probe) -> InkCanvasView {
        let focus = session.layout.pages[min(max(0, session.focusSlot), session.layout.pages.count - 1)]
        let sleeper = canvasSleeper!
        let bed = bed!
        let kind = session.kind
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
            onViewportChange: { _ in },
            initialZoomRatio: AppSettings.zoomRatio(for: kind),
            onZoomRatioChange: { ratio in
                probe.ratios.append(ratio)
                AppSettings.setZoomRatio(ratio, for: kind)
            },
            span: session,
            sleep: { await sleeper.sleep($0) },
            clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) },
            onSpanStop: { probe.stops.append($0) }
        )
    }

    /// The canvas attached to its container as `makeUIView` does, laid out once in `area` and settled; the first layout's
    /// own ratio report (its end-of-pinch call) is dropped, so a test sees only what it causes.
    private func attach(_ session: SpanSession, area: CGSize) async -> JoinedRig {
        let probe = Probe()
        let view = makeView(session, probe: probe)
        let coordinator = InkCanvasView.Coordinator(parent: view)
        let container = InkCanvasContainerView(paperView: PaperView(content: view.paper), canvasView: InkBandCanvasView())
        coordinator.attach(container)
        container.frame = CGRect(origin: .zero, size: area)
        container.layoutSubviews()
        await settle()
        probe.ratios.removeAll()
        session.willPersist = { probe.persisted.append($0) }
        let rig = JoinedRig(coordinator: coordinator, container: container, probe: probe, session: session)
        rigs.append(rig)
        return rig
    }

    /// A fold or an unfold as UIKit lays it out: the paper area takes `area`, then the queued work.
    private func fold(_ container: InkCanvasContainerView, to area: CGSize) async {
        container.frame = CGRect(origin: .zero, size: area)
        container.layoutSubviews()
        await settle()
    }

    private func settle(_ turns: Int = 24) async {
        for _ in 0..<turns {
            await Task.yield()
        }
    }

    /// A page with a short grid stroke for each id (cell-relative points).
    private func gridPage(_ pageId: String, _ ids: [String]) -> InkPage {
        var page = InkPage.empty(pageId: pageId)
        for (i, id) in ids.enumerated() {
            page.add(bed.stroke(id, cell: .grid, x: 300, y: 400 + CGFloat(i) * 60, t: 1_790_000_001_000 + i))
        }
        return page
    }

    /// The stored files of `pageIds`, byte for byte.
    private func files(_ pageIds: [String]) -> [String: Data] {
        var out: [String: Data] = [:]
        for id in pageIds {
            out[id] = FileManager.default.contents(atPath: bed.store.url(for: id).path)
        }
        return out
    }

    /// The session's pages as JSON (`InkPageCodec`), byte for byte.
    private func json(_ session: SpanSession, _ pageIds: [String]) throws -> [String: Data] {
        var out: [String: Data] = [:]
        for id in pageIds {
            out[id] = try InkPageCodec.encode(try XCTUnwrap(session.page(id), "\(id) is in the window"))
        }
        return out
    }

    /// A pen stroke through `points` (band lu), each with its own creation date.
    private func shortStroke(at x: CGFloat, _ y: CGFloat) -> PKStroke {
        strokeClock += 1
        // Built step by step: Xcode 27.2's compiler gave up type-checking the one-expression form for x86_64 on CI
        // (duo.yml run 44690590720, "unable to type-check this expression in reasonable time").
        var points: [PKStrokePoint] = []
        for i in 0..<5 {
            let step = CGFloat(i)
            let location = CGPoint(x: x - 20 + step * 10, y: y + CGFloat(i % 2))
            let timeOffset: TimeInterval = TimeInterval(i) * 0.01
            let altitude: CGFloat = .pi / 2
            points.append(PKStrokePoint(location: location, timeOffset: timeOffset, size: CGSize(width: 3.5, height: 3.5),
                                        opacity: 1, force: 0.5, azimuth: 0, altitude: altitude))
        }
        return PKStroke(ink: PKInk(.pen, color: .black),
                        path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 1_790_000_000 + strokeClock)),
                        transform: .identity, mask: nil)
    }

    // MARK: The joined path

    /// (a) While the Pencil writes on the paper the fold changes the zoom and the place in its own layout pass, but the window
    /// is not decided anew (the frozen canvas's `isAtRest` sees `touchingPaper`); (b) once the pen lifted and the settle wait
    /// ended, it is — once — around the same focus page.
    func testWidthChangeWhileDrawingWaitsForPenUp() async throws {
        for (kind, focus, focusId) in [(PageKind.week, nov16, w1116), (.day, nov18, d1118)] {
            let session = try await open(kind, focus: focus, orientation: .portrait, paperArea: innerPortrait,
                                         stored: [kind == .week ? gridPage(w1116, ["a"]) : gridPage(d1118, ["a"])],
                                         number: kind == .week ? 1 : 2)
            let rig = await attach(session, area: innerPortrait)
            let shifts = rig.coordinator.spanShiftCount
            let version = session.windowVersion
            XCTAssertEqual(session.focusPageId, focusId)

            // The Pencil comes down and writes; the Duo folds under it.
            rig.coordinator.touchObserved(.down(.pencil))
            rig.coordinator.canvasViewDidBeginUsingTool(rig.canvas)
            let grid = try XCTUnwrap(session.layout.cells[SpanName.prefixed(.grid, page: focusId)], "the focus page's grid")
            rig.canvas.drawing = PKDrawing(strokes: rig.canvas.drawing.strokes + [shortStroke(at: grid.minX + 300, grid.minY + 300)])
            rig.coordinator.canvasViewDrawingDidChange(rig.canvas)
            await fold(rig.container, to: outerPortrait(kind))
            XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .busy, "\(kind): (a) the pen is on the paper")
            await settle()
            XCTAssertEqual(rig.coordinator.spanShiftCount, shifts, "\(kind): (a) not decided anew under the pen")
            XCTAssertEqual(session.windowVersion, version, "\(kind): (a) the window stays")

            // The pen lifts; once still, the window is decided anew once.
            rig.coordinator.touchObserved(.up(.pencil))
            rig.coordinator.canvasViewDidEndUsingTool(rig.canvas)
            rig.coordinator.endSettleWaitForTesting()
            await settle()
            let outcome = rig.coordinator.shiftIfAtRest()
            XCTAssertTrue(outcome == .done || (outcome == .nothing && rig.coordinator.spanShiftCount == shifts + 1),
                          "\(kind): (b) decided anew at rest (\(outcome))")
            await settle()
            XCTAssertEqual(rig.coordinator.spanShiftCount, shifts + 1, "\(kind): (b) once")
            XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .nothing, "\(kind): (b) not twice")
            XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion, "\(kind): the canvas took it")
            XCTAssertEqual(session.focusPageId, focusId, "\(kind): (c) the focus page")
            XCTAssertEqual(session.kind, kind, "\(kind): (c) the kind")
            XCTAssertEqual(session.page(focusId)?.liveStrokeCount, 2, "\(kind): the stroke written during the fold is kept")
        }
    }

    /// (b) A still paper is decided anew once after each fold and unfold (669 → 382 → 669), and a fold during a scroll waits
    /// for the scroll to stop, then once.
    func testFoldRedecidesTheWindowOnceAfterSettling() async throws {
        let session = try await open(.week, focus: nov16, orientation: .portrait, paperArea: innerPortrait, stored: [gridPage(w1116, ["a"])])
        let rig = await attach(session, area: innerPortrait)
        let shifts = rig.coordinator.spanShiftCount
        await fold(rig.container, to: outerPortrait(.week))
        _ = rig.coordinator.shiftIfAtRest()
        await settle()
        XCTAssertEqual(rig.coordinator.spanShiftCount, shifts + 1, "folded: decided anew once")
        XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .nothing)
        await fold(rig.container, to: innerPortrait)
        _ = rig.coordinator.shiftIfAtRest()
        await settle()
        XCTAssertEqual(rig.coordinator.spanShiftCount, shifts + 2, "unfolded: once more")
        XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .nothing)

        // During a scroll: the band moves (a finger drags it), so it waits; once it stopped, once.
        rig.coordinator.spanMotionOverride = true
        await fold(rig.container, to: outerPortrait(.week))
        XCTAssertEqual(rig.coordinator.shiftIfAtRest(), .busy, "the band moves")
        await settle()
        XCTAssertEqual(rig.coordinator.spanShiftCount, shifts + 2, "not during the scroll")
        rig.coordinator.spanMotionOverride = false
        let outcome = rig.coordinator.shiftIfAtRest()
        XCTAssertTrue(outcome == .done || (outcome == .nothing && rig.coordinator.spanShiftCount == shifts + 3), "\(outcome)")
        await settle()
        XCTAssertEqual(rig.coordinator.spanShiftCount, shifts + 3, "once it stopped")
        XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion)
        XCTAssertEqual(session.focusPageId, w1116)
    }

    /// (c) (d) on both paths. Joined: the focus page, the kind, the stored files and the pages' JSON are the same after a fold
    /// and an unfold, for the week and the day, with handwriting on the pages and without. One page (the four kinds, with
    /// handwriting and without): the page (its id: its kind and focus) and its JSON.
    func testFoldKeepsKindFocusAndBytes() async throws {
        let cases: [(PageKind, DayKey, String, [InkPage])] = [
            (.week, nov16, w1116, [gridPage(w1109, ["p"]), gridPage(w1116, ["a", "b"]), gridPage(w1123, ["n"])]),
            (.day, nov18, d1118, [gridPage(d1117, ["p"]), gridPage(d1118, ["a", "b"]), gridPage(d1119, ["n"])]),
            (.week, DayKey(year: 2026, month: 12, day: 7), "w-2026-12-07", []),
        ]
        for (number, (kind, focus, focusId, stored)) in cases.enumerated() {
            let session = try await open(kind, focus: focus, orientation: .portrait, paperArea: innerPortrait, stored: stored,
                                         number: number + 1)
            let rig = await attach(session, area: innerPortrait)
            let ids = stored.map(\.pageId)
            let filesBefore = files(ids)
            let jsonBefore = try json(session, ids + [focusId])
            for area in [outerPortrait(kind), innerPortrait] {
                await fold(rig.container, to: area)
                _ = rig.coordinator.shiftIfAtRest()
                await settle()
                XCTAssertEqual(session.focusPageId, focusId, "\(kind) \(area): (c) the focus page")
                XCTAssertEqual(session.kind, kind, "\(kind) \(area): (c) the kind")
            }
            await bed.flushSessionTimers()
            XCTAssertEqual(files(ids), filesBefore, "\(kind): (d) the stored files byte for byte")
            XCTAssertEqual(try json(session, ids + [focusId]), jsonBefore, "\(kind): (d) the pages' JSON byte for byte")
        }

        for kind in PageKind.allCases {
            for strokes in [3, 0] {
                let folded = try await foldOnePage(kind, strokes: strokes)
                XCTAssertEqual(folded.liveBefore, strokes, "\(kind) \(strokes): the page's strokes")
                XCTAssertEqual(folded.pageIds, [folded.pageIds[0], folded.pageIds[0], folded.pageIds[0]], "\(kind) \(strokes): (c) the same page")
                XCTAssertEqual(folded.pageIds[0], folded.expectedPageId, "\(kind) \(strokes): (c) its kind and focus")
                XCTAssertEqual(folded.jsonAfter, folded.jsonBefore, "\(kind) \(strokes): (d) the page's JSON byte for byte")
            }
        }
    }

    /// (e) on both paths. Joined: no page of the window is dirty after a fold and an unfold, and nothing is written. One page
    /// (the four kinds): the canvas writes nothing back to its page (the screen's dirty mark comes from those writes).
    func testFoldMarksNoPageDirty() async throws {
        for (kind, focus, stored) in [(PageKind.week, nov16, [gridPage(w1116, ["a"]), gridPage(w1123, ["b"])]),
                                      (.day, nov18, [gridPage(d1118, ["a"]), gridPage(d1119, ["b"])])] {
            let session = try await open(kind, focus: focus, orientation: .portrait, paperArea: innerPortrait, stored: stored,
                                         number: kind == .week ? 1 : 2)
            let rig = await attach(session, area: innerPortrait)
            for area in [outerPortrait(kind), innerPortrait, outerPortrait(kind)] {
                await fold(rig.container, to: area)
                _ = rig.coordinator.shiftIfAtRest()
                await settle()
                XCTAssertFalse(session.slots.values.contains { $0.dirty }, "\(kind) \(area): (e) no page dirty")
            }
            await bed.flushSessionTimers()
            XCTAssertEqual(rig.probe.persisted, [], "\(kind): (e) nothing written")
        }

        for kind in PageKind.allCases {
            let folded = try await foldOnePage(kind, strokes: 3)
            XCTAssertEqual(folded.writes, 0, "\(kind): (e) nothing written back (no dirty mark)")
        }
    }

    /// (f) on both paths: the stored ratio of the kind (`zoomRatio.<kind>`) is not written by a fold or an unfold (the ratio
    /// is reported only at the end of a pinch), whether the paper was at the opening zoom or zoomed in; the one page of the
    /// four kinds alike.
    func testFoldKeepsTheZoomRatioKey() async throws {
        for (kind, focus, ratio) in [(PageKind.week, nov16, CGFloat(1.6)), (.day, nov18, 2.5)] {
            AppSettings.setZoomRatio(ratio, for: kind)
            let key = AppSettings.zoomRatioKey(kind)
            let session = try await open(kind, focus: focus, orientation: .portrait, paperArea: innerPortrait, number: kind == .week ? 1 : 2)
            let rig = await attach(session, area: innerPortrait)
            // The first layout's report went where the screen puts it; what is stored now is the key under test.
            let stored = scratch.object(forKey: key) as? Double
            for area in [outerPortrait(kind), innerPortrait] {
                await fold(rig.container, to: area)
                _ = rig.coordinator.shiftIfAtRest()
                await settle()
            }
            XCTAssertEqual(rig.probe.ratios, [], "\(kind): (f) no ratio reported by a fold")
            XCTAssertEqual(scratch.object(forKey: key) as? Double, stored, "\(kind): (f) the key stays")
        }

        for kind in PageKind.allCases {
            for ratio in [CGFloat(1), 1.5] {
                AppSettings.setZoomRatio(ratio, for: kind)
                let folded = try await foldOnePage(kind, strokes: 3)
                XCTAssertEqual(folded.ratios, [], "\(kind) at \(ratio): (f) no ratio reported")
                XCTAssertEqual(folded.keyAfter, folded.keyBefore, "\(kind) at \(ratio): (f) the key stays")
            }
        }
    }

    /// (g) (§4.7, 0d-8): with the window of now, the outer screen's landscape (measured: the week's paper 594 × 141, the
    /// day's 594 × 190) caps the overview — 3 weeks / 5 days across, the lowest zoom of the window plan (594 ÷ 4200 and
    /// 594 ÷ 5000, above the plain 141 ÷ 1920 and 190 ÷ 2400) — and once the window is decided anew after the unfold to the
    /// inner one's (951 × 446, estimated; `overviewCapNow` false) it does not (P-B6 ア's lowest zoom); folded again, capped
    /// again. On the day at 446 pt the cap would bite, so the lowest zoom differs (§4.7); on the week it is below the lowest
    /// zoom there.
    func testFoldSwitchesTheCap() async throws {
        for (kind, focus, across) in [(PageKind.week, nov16, CGFloat(3)), (.day, nov18, 5)] {
            capNow = true
            let outer = outerLandscape(kind)
            let session = try await open(kind, focus: focus, orientation: .landscape, paperArea: outer,
                                         number: kind == .week ? 1 : 2)
            let rig = await attach(session, area: outer)
            let overview = InkCanvasView.bandOverview(session.layout)
            func lowest(_ area: CGSize) -> CGFloat { session.plan.zoomBounds(overview: overview, viewport: area).min }
            func uncapped(_ area: CGSize) -> CGFloat { ZoomPolicy.bounds(kind, overview: overview, viewport: area).min }
            let outerCap = outer.width / (across * ZoomPolicy.paperWidth(kind))
            XCTAssertGreaterThan(outerCap, uncapped(outer), "\(kind): the cap bites on the outer screen's landscape")
            XCTAssertTrue(session.plan.overviewCap, "\(kind): folded, capped")
            XCTAssertEqual(lowest(outer), outerCap, accuracy: 1e-9, "\(kind): the cap's lowest zoom")
            XCTAssertEqual(rig.canvas.minimumZoomScale, outerCap, accuracy: 1e-4, "\(kind): the canvas's lowest zoom")

            // Unfold: the window of now has no cap; from the window decided anew, P-B6 ア's lowest zoom.
            capNow = false
            let shifts = rig.coordinator.spanShiftCount
            await fold(rig.container, to: innerLandscape)
            _ = rig.coordinator.shiftIfAtRest()
            await settle()
            XCTAssertEqual(rig.coordinator.spanShiftCount, shifts + 1, "\(kind): decided anew once")
            XCTAssertFalse(session.plan.overviewCap, "\(kind): unfolded, no cap")
            XCTAssertEqual(lowest(innerLandscape), uncapped(innerLandscape), accuracy: 1e-12, "\(kind): P-B6 ア's lowest zoom")
            if kind == .day {
                XCTAssertGreaterThan(innerLandscape.width / (across * ZoomPolicy.paperWidth(kind)), uncapped(innerLandscape),
                                     "the day at 446 pt: a cap would bite, so its coming off shows in the lowest zoom")
            }

            // Fold again: capped again.
            capNow = true
            await fold(rig.container, to: outer)
            _ = rig.coordinator.shiftIfAtRest()
            await settle()
            XCTAssertEqual(rig.coordinator.spanShiftCount, shifts + 2, "\(kind): decided anew once more")
            XCTAssertTrue(session.plan.overviewCap, "\(kind): folded, capped again")
            XCTAssertEqual(lowest(outer), outerCap, accuracy: 1e-9, "\(kind): the cap's lowest zoom again")
            XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion)
        }
    }

    // MARK: The one-page path

    /// What the one-page canvas wrote back to its page (the screen's dirty mark comes from these writes).
    private final class PageWrites {
        var count = 0
        var page: InkPage
        init(_ page: InkPage) { self.page = page }
    }

    /// 2026-11-18 10:00 in the device's time zone.
    private var onePageNow: Date { DayKey(year: 2026, month: 11, day: 18).startOfDay().addingTimeInterval(10 * 3600) }

    /// The one page of `kind` around 11/18 with `strokes` strokes in its cells, and its paper.
    private func onePage(_ kind: PageKind, strokes: Int) -> (layout: any PageLayout, paper: PaperContent, page: InkPage) {
        let now = onePageNow
        let day = DayKey(year: 2026, month: 11, day: 18)
        let layout: any PageLayout
        let paper: PaperContent
        let cell: CellKey
        switch kind {
        case .month:
            let month = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 11), events: [], inkBottoms: [:], now: now))
            layout = month
            paper = .month(MonthPaperContent(layout: month, labels: month.dateLabels, bars: month.allDayBars, chips: month.timedChips, holidayNames: [:]))
            cell = .day(day)
        case .year:
            let year = YearLayoutEngine.layout(YearLayoutInput(year: 2026, events: [], inkBottoms: [:], now: now))
            layout = year
            paper = .year(YearPaperContent(layout: year, monthNames: (1...12).map { "\($0)" }))
            cell = .yearDay(month: 11, day: 18)
        case .week:
            let week = WeekLayoutEngine.layout(WeekLayoutInput(focus: day, events: [], inkBottoms: [:], now: now))
            layout = week
            paper = .week(WeekPaperContent(layout: week))
            cell = .grid
        case .day:
            let page = DayLayoutEngine.layout(DayLayoutInput(day: day, events: [], inkBottoms: [:], now: now))
            layout = page
            paper = .day(DayPaperContent(layout: page))
            cell = .grid
        }
        var page = InkPage.empty(pageId: layout.pageId)
        for i in 0..<strokes {
            page.add(bed.stroke("s\(i)", cell: cell, x: 10 + CGFloat(i) * 5, y: 10 + CGFloat(i) * 4, t: 1_790_000_001_000 + i))
        }
        return (layout, paper, page)
    }

    /// The one-page canvas as the screen builds it (no window), its page binding counting the writes, the ratio going where
    /// the screen puts it; attached, laid out once in `area` and settled, the first layout's report and writes dropped.
    private func attachOnePage(_ kind: PageKind, strokes: Int, area: CGSize) async -> (InkCanvasView.Coordinator, InkCanvasContainerView, Probe, PageWrites) {
        let (layout, paper, page) = onePage(kind, strokes: strokes)
        let probe = Probe()
        let writes = PageWrites(page)
        let sleeper = canvasSleeper!
        let bed = bed!
        let binding = Binding<InkPage>(get: { writes.page }, set: { writes.page = $0; writes.count += 1 })
        let view = InkCanvasView(
            layout: layout,
            paper: paper,
            tool: pen,
            allowFinger: false,
            page: binding,
            initialScrollY: PageNavigation.initialScrollY(layout, now: onePageNow),
            onTap: { _, _ in },
            onInkBoundsChanged: {},
            undoTrigger: 0,
            redoTrigger: 0,
            onViewportChange: { _ in },
            initialZoomRatio: AppSettings.zoomRatio(for: kind),
            onZoomRatioChange: { ratio in
                probe.ratios.append(ratio)
                AppSettings.setZoomRatio(ratio, for: kind)
            },
            sleep: { await sleeper.sleep($0) },
            clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) }
        )
        let coordinator = InkCanvasView.Coordinator(parent: view)
        let container = InkCanvasContainerView(paperView: PaperView(content: paper))
        coordinator.attach(container)
        container.frame = CGRect(origin: .zero, size: area)
        container.layoutSubviews()
        await settle()
        probe.ratios.removeAll()
        writes.count = 0
        return (coordinator, container, probe, writes)
    }

    /// What a fold and an unfold (669 → 382 → 669) did on the one-page path (the month, the year, and the week and the day
    /// with the setting off): the canvas's page id after the opening and each step, its JSON before and after, the writes back
    /// to the page, the ratios reported and the stored key before and after. The middle's x is not looked at (§1.5).
    private struct OnePageFold {
        var expectedPageId: String
        var liveBefore: Int
        var pageIds: [String]
        var jsonBefore: Data
        var jsonAfter: Data
        var writes: Int
        var ratios: [CGFloat]
        var keyBefore: Double?
        var keyAfter: Double?
    }

    private func foldOnePage(_ kind: PageKind, strokes: Int) async throws -> OnePageFold {
        let key = AppSettings.zoomRatioKey(kind)
        let (coordinator, container, probe, writes) = await attachOnePage(kind, strokes: strokes, area: innerPortrait)
        defer { coordinator.detach() }
        let keyBefore = scratch.object(forKey: key) as? Double
        var pageIds = [coordinator.ledger.page.pageId]
        let jsonBefore = try InkPageCodec.encode(coordinator.ledger.page)
        let liveBefore = coordinator.ledger.page.liveStrokeCount
        for area in [outerPortrait(kind), innerPortrait] {
            await fold(container, to: area)
            pageIds.append(coordinator.ledger.page.pageId)
        }
        return OnePageFold(expectedPageId: onePage(kind, strokes: 0).layout.pageId, liveBefore: liveBefore, pageIds: pageIds,
                           jsonBefore: jsonBefore, jsonAfter: try InkPageCodec.encode(coordinator.ledger.page), writes: writes.count,
                           ratios: probe.ratios, keyBefore: keyBefore, keyAfter: scratch.object(forKey: key) as? Double)
    }
}
