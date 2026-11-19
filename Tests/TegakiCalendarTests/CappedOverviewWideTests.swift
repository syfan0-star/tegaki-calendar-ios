import InkModel
import Layout
import XCTest
@testable import TegakiCalendar

// 1.4 (docs/M7D_CONTRACT.md §4.7, §6; 0d-8, C1, C12): the overview cap of P-B6 イ (3 weeks / 5 days across on an iPhone's
// landscape paper) is not put on a wide window's plan — the iPhone Duo's inner screen (a 951 × 446 paper in landscape by
// the estimate of CODE_SURVEY §3.2) — and `ScreenPaths.atCappedOverview` and `shotPaperOffset`, unchanged, follow the plan:
// such a window is never at the capped overview, and today's page opens at 0:00 as every page did before P-B6 イ. The
// iPhone's landscape (874 × 205) keeps 1.3's opening an hour before now (`cappedOpeningY`). A fold or an unfold switches the
// cap at the window decided anew (`overviewCapNow`, read by `SpanSession.redecide`): 678 × 256 (the outer screen's
// landscape) capped ↔ 951 × 446 (the inner one's) not. Over a live `SyncEngine` (SessionTestBed); no real sleep. Mutation
// (`r14-q-m1`): `makeSession` passing the cap whatever the window fails the first test's day row at 951 × 446 (today
// would open an hour before now, C1).

@MainActor
final class CappedOverviewWideTests: XCTestCase {
    private var bed: SessionTestBed!
    private var faults: [String] = []
    private var savedOnFault: ((String) -> Void)!
    private var savedDefaults: UserDefaults!
    private var scratch: UserDefaults!
    private var suiteName = ""
    private var paths: ScreenPaths!

    private let nov16 = DayKey(year: 2026, month: 11, day: 16)
    private let nov18 = DayKey(year: 2026, month: 11, day: 18)

    override func setUp() async throws {
        bed = try SessionTestBed("CappedOverviewWideTests")
        faults = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
        suiteName = "CappedOverviewWideTests-\(UUID().uuidString)"
        scratch = UserDefaults(suiteName: suiteName)
        savedDefaults = AppSettings.defaults
        AppSettings.defaults = scratch
        let sleeper = bed.sessionSleeper
        paths = ScreenPaths(sync: bed.engine,
                            onePage: OnePageSession(sync: bed.engine, sleep: { await sleeper.sleep($0) },
                                                    clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) }),
                            screenshot: false, shot: nil, settingOn: { true }, defaults: scratch,
                            sleep: { await sleeper.sleep($0) },
                            clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) })
    }

    override func tearDown() async throws {
        XCTAssertEqual(faults, [], "no fault of the window's bookkeeping")
        AppSettings.defaults = savedDefaults
        scratch?.removePersistentDomain(forName: suiteName)
        SpanSession.onFault = savedOnFault
        paths = nil
        bed?.tearDown()
        bed = nil
    }

    private func at(_ month: Int, _ day: Int, _ hour: Int) throws -> Date {
        try XCTUnwrap(SessionTestBed.tokyo.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)))
    }

    /// The window of `kind` at `focus` opened through `ScreenPaths` for a full-screen window of `window` (its device:
    /// `ScreenPaths.device`) and the paper area `area` (the radius the band's lanes need), read.
    private func openWindow(_ kind: PageKind, focus: DayKey, window: CGSize, area: CGSize, now: Date,
                            file: StaticString = #filePath, line: UInt = #line) async throws -> SpanSession {
        let device = try XCTUnwrap(ScreenPaths.device(isPad: false, windowSize: window, screen: window), file: file, line: line)
        let opening = ScreenPaths.Opening(kind: kind, focus: focus, weekStart: .monday, device: device, paperArea: area,
                                          context: SpanSession.PaperContext(now: now, calendar: SessionTestBed.tokyo))
        XCTAssertEqual(paths.open(opening), .joined, file: file, line: line)
        let session = try XCTUnwrap(paths.span, file: file, line: line)
        await session.prefetch()
        return session
    }

    /// C1: a wide window's plan (the Duo's inner landscape, 951 × 669, its paper 951 × 446) has no cap, so at its lowest zoom
    /// and at its opening zoom it is not at the capped overview, and today's page opens at 0:00 (`shotPaperOffset` gives no
    /// offset: its today's y is nil). The iPhone's landscape (874 × 402, its paper 874 × 205) keeps 1.3's: at the capped
    /// overview, today's page opens an hour before now (`cappedOpeningY`, 14:00 at 15:00).
    func testWideWindowIsNotCappedThroughShotPaperOffset() async throws {
        let now = try at(11, 18, 15)
        let innerArea = CGSize(width: 951, height: 446)
        for (kind, focus, across) in [(PageKind.week, nov16, CGFloat(3)), (.day, nov18, 5)] {
            let session = try await openWindow(kind, focus: focus, window: CGSize(width: 951, height: 669), area: innerArea, now: now)
            XCTAssertFalse(session.plan.overviewCap, "\(kind): a wide window's plan has no cap")
            XCTAssertNotNil(ScreenPaths.cappedOpeningY(layout: session.layout, pageId: session.focusPageId), "\(kind): today is on the page")
            let overview = InkCanvasView.bandOverview(session.layout)
            let bounds = session.plan.zoomBounds(overview: overview, viewport: innerArea)
            XCTAssertEqual(bounds.min, ZoomPolicy.bounds(kind, overview: overview, viewport: innerArea).min, accuracy: 1e-12,
                           "\(kind): P-B6 ア's lowest zoom")
            if kind == .day {
                XCTAssertGreaterThan(951 / (across * ZoomPolicy.paperWidth(kind)), bounds.min,
                                     "the day at 446 pt: a cap would bite here (§4.7), so this row sees it")
            }
            for zoom in [bounds.min, ScreenPaths.bandZoom(layout: session.layout, area: innerArea, ratio: 1)] {
                XCTAssertFalse(ScreenPaths.atCappedOverview(layout: session.layout, width: 951, zoom: zoom), "\(kind) at \(zoom)")
                XCTAssertNil(ScreenPaths.shotPaperOffset(layout: session.layout, focusPageId: session.focusPageId, pages: nil, offset: nil,
                                                         viewportWidth: 951, zoom: zoom),
                             "\(kind) at \(zoom): today's page opens at 0:00")
            }
        }

        let phoneArea = CGSize(width: 874, height: 205)
        for (kind, focus, hour) in [(PageKind.week, nov16, CGFloat(80)), (.day, nov18, 100)] {
            let session = try await openWindow(kind, focus: focus, window: CGSize(width: 874, height: 402), area: phoneArea, now: now)
            XCTAssertTrue(session.plan.overviewCap, "\(kind): an iPhone's landscape window, capped (1.3)")
            let zoom = ScreenPaths.bandZoom(layout: session.layout, area: phoneArea, ratio: 1)
            XCTAssertTrue(ScreenPaths.atCappedOverview(layout: session.layout, width: 874, zoom: zoom), "\(kind)")
            let opened = try XCTUnwrap(ScreenPaths.shotPaperOffset(layout: session.layout, focusPageId: session.focusPageId, pages: nil,
                                                                   offset: nil, viewportWidth: 874, zoom: zoom), "\(kind)")
            let capped = try XCTUnwrap(ScreenPaths.cappedOpeningY(layout: session.layout, pageId: session.focusPageId))
            XCTAssertEqual(opened.y, capped, accuracy: 1e-9, "\(kind): 1.3's cappedOpeningY")
            XCTAssertEqual(opened.y, 14 * hour, accuracy: 1e-9, "\(kind): 14:00, an hour before now")
        }
    }

    /// §4.7 (C12): a fold and an unfold switch the cap where the window is decided anew — the window of now from the screen's
    /// `overviewCapNow`: the outer screen's landscape paper (678 × 256) at the cap's lowest zoom (3 weeks / 5 days across),
    /// the inner one's (951 × 446) at P-B6 ア's, and the outer one's again. The window's short side does not move with the
    /// all-day band's lanes, so the answer never sways with them.
    func testFoldSwitchesTheCapAtTheRedecide() async throws {
        var capNow = true
        paths.overviewCapNow = { capNow }
        let outer = CGSize(width: 678, height: 256)
        let inner = CGSize(width: 951, height: 446)
        for (kind, focus, across) in [(PageKind.week, nov16, CGFloat(3)), (.day, nov18, 5)] {
            capNow = true
            let session = try await openWindow(kind, focus: focus, window: CGSize(width: 678, height: 466), area: outer, now: bed.now)
            let overview = InkCanvasView.bandOverview(session.layout)
            func lowest(_ area: CGSize) -> CGFloat { session.plan.zoomBounds(overview: overview, viewport: area).min }
            func uncapped(_ area: CGSize) -> CGFloat { ZoomPolicy.bounds(kind, overview: overview, viewport: area).min }
            let outerCap = outer.width / (across * ZoomPolicy.paperWidth(kind))
            XCTAssertGreaterThan(outerCap, uncapped(outer), "\(kind): the cap bites on the outer screen's landscape")
            XCTAssertTrue(session.plan.overviewCap, "\(kind): the outer screen, capped")
            XCTAssertEqual(lowest(outer), outerCap, accuracy: 1e-9, "\(kind): 3 weeks / 5 days across")

            capNow = false
            XCTAssertTrue(session.redecide(orientation: .landscape, paperArea: inner), "\(kind): unfolded")
            XCTAssertFalse(session.plan.overviewCap, "\(kind): the inner screen, no cap")
            XCTAssertEqual(lowest(inner), uncapped(inner), accuracy: 1e-12, "\(kind): P-B6 ア's lowest zoom")

            capNow = true
            XCTAssertTrue(session.redecide(orientation: .landscape, paperArea: outer), "\(kind): folded")
            XCTAssertTrue(session.plan.overviewCap, "\(kind): capped again")
            XCTAssertEqual(lowest(outer), outerCap, accuracy: 1e-9, "\(kind): 3 weeks / 5 days across again")
        }
    }
}
