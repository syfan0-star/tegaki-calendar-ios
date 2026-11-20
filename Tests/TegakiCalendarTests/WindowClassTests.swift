import InkModel
import Layout
import XCTest
@testable import TegakiCalendar

// 1.4 (docs/M7D_CONTRACT.md §2.1, §4.3, §4.7, §6; 0d-8, 0d-9): the app's glue of `WindowClass` — the pure table is
// KitChecks' section "window & finger (1.4)". The wide window's short side is the header's one-row width; the screen's
// window of a wide window has no overview cap (`ScreenPaths.device`'s `wide`, `makeSession`) while every iPhone's window keeps
// 1.3's cap; a window decided anew reads the window of now (`SpanSession`'s `overviewCapNow`), and without it keeps 1.3's.
// Over a live `SyncEngine` (SessionTestBed: a temporary store, the fake database, `TestSleeper`, a fixed clock); no real
// sleep. Mutations (§6, `r14-q-m1`): `makeSession` passing the cap whatever the window fails the second test; `redecide`
// not reading `overviewCapNow` fails the third.

@MainActor
final class WindowClassTests: XCTestCase {
    private var bed: SessionTestBed!
    private var faults: [String] = []
    private var savedOnFault: ((String) -> Void)!
    private var savedDefaults: UserDefaults!
    private var scratch: UserDefaults!
    private var suiteName = ""
    private var paths: ScreenPaths!

    private let nov16 = DayKey(year: 2026, month: 11, day: 16)

    override func setUp() async throws {
        bed = try SessionTestBed("WindowClassTests")
        faults = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
        suiteName = "WindowClassTests-\(UUID().uuidString)"
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

    private func size(_ width: CGFloat, _ height: CGFloat) -> CGSize {
        CGSize(width: width, height: height)
    }

    /// A week at 11/16 opened through `ScreenPaths` with the device of a full-screen window of `window` (`ScreenPaths.device`).
    private func openWindow(_ window: CGSize, isPad: Bool = false, paperArea: CGSize? = nil, file: StaticString = #filePath,
                            line: UInt = #line) throws -> SpanSession {
        let device = try XCTUnwrap(ScreenPaths.device(isPad: isPad, windowSize: window, screen: window), file: file, line: line)
        let opening = ScreenPaths.Opening(kind: .week, focus: nov16, weekStart: .monday, device: device, paperArea: paperArea,
                                          context: SpanSession.PaperContext(now: bed.now, calendar: SessionTestBed.tokyo))
        XCTAssertEqual(paths.open(opening), .joined, file: file, line: line)
        return try XCTUnwrap(paths.span, file: file, line: line)
    }

    /// §2.1, §4.7: `WindowClass.wideShortSide` is the width from which the header is one row (`compactWidth`), so the Duo's
    /// inner screen is wide in the look and the header alike. Fails if either moves alone (§4.7: a measurement on the wrong
    /// side of 600 changes this test to "wideShortSide ≤ compactWidth").
    func testWideShortSideIsTheCompactWidth() {
        XCTAssertEqual(WindowClass.wideShortSide, CalendarRootScreen.compactWidth)
        XCTAssertEqual(WindowClass.wideShortSide, 600)
    }

    /// §4.7, 0d-8: the device of a wide window (the Duo's inner screen, 669 × 951 and 951 × 669 by the estimate; a widened
    /// iPhone Mirroring window) is `wide`, and the screen's window made for it has no overview cap. Every iPhone's window keeps
    /// 1.3's cap (402 × 874 and 874 × 402; the Duo's outer screen as duo-shots measured it, 466 × 678 and 678 × 466), and an
    /// iPad's device stays 1.3's (not `wide`, the cap asked as before; its plan has none either way). Fails with `makeSession`
    /// passing the cap whatever the window (the inner rows).
    func testWideWindowSessionHasNoCap() throws {
        let rows: [(String, CGSize, Bool, SpanOrientation)] = [
            ("Duo inner portrait (estimate)", size(669, 951), true, .portrait),
            ("Duo inner landscape (estimate)", size(951, 669), true, .landscape),
            ("iPhone 17 portrait", size(402, 874), false, .portrait),
            ("iPhone 17 landscape", size(874, 402), false, .landscape),
            ("Duo outer portrait (measured)", size(466, 678), false, .portrait),
            ("Duo outer landscape (measured)", size(678, 466), false, .landscape),
        ]
        for (name, window, wide, orientation) in rows {
            let device = try XCTUnwrap(ScreenPaths.device(isPad: false, windowSize: window, screen: window), name)
            XCTAssertEqual(device.wide, wide, "\(name): wide")
            XCTAssertEqual(device.deviceClass, .iPhone, "\(name): the Duo is an iPhone's plan, inner and outer (§4.6)")
            XCTAssertEqual(device.orientation, orientation, name)
            let session = try openWindow(window)
            XCTAssertEqual(session.plan.overviewCap, !wide, "\(name): the window plan's cap")
            XCTAssertEqual(session.overviewCap, !wide, "\(name): the session's cap")
        }
        // An iPad: 1.3's device, so 1.3's equality (ScreenPathsSpanTests.testDeviceFromTheWindowSize) and 1.3's request.
        let pad = try XCTUnwrap(ScreenPaths.device(isPad: true, windowSize: size(1032, 1376), screen: size(1032, 1376)))
        XCTAssertEqual(pad, ScreenPaths.Device(deviceClass: .iPad13, orientation: .portrait))
        XCTAssertFalse(pad.wide)
        XCTAssertTrue(try openWindow(size(1032, 1376), isPad: true).plan.overviewCap, "an iPad's window asks as in 1.3")
        // Not measured yet: no device (the page waits, 1.3's C3-m11), so no window of a guessed width.
        XCTAssertNil(ScreenPaths.device(isPad: false, windowSize: .zero, screen: size(669, 951)))
    }

    /// §2.1, §4.7: a window decided anew (`redecide`: a fold, an unfold, a turn) takes the cap of the window of now from
    /// `overviewCapNow` — the screen's, through `ScreenPaths.overviewCapNow` and `makeSession` — and keeps the opening's cap
    /// without it (1.3's), also after a refusal. Fails with `redecide` not reading `overviewCapNow`.
    func testRedecideReadsTheWindowNow() async throws {
        let sleeper = bed.sessionSleeper
        var capNow = true
        // The session alone: the hook true → false → true.
        let session = SpanSession(kind: .week, weekStart: .monday, focus: nov16, sync: bed.engine, deviceClass: .iPhone,
                                  orientation: .landscape, number: 1,
                                  context: SpanSession.PaperContext(now: bed.now, calendar: SessionTestBed.tokyo),
                                  overviewCap: true, overviewCapNow: { capNow },
                                  sleep: { await sleeper.sleep($0) }, clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) })
        await session.prefetch()
        XCTAssertTrue(session.plan.overviewCap, "opened capped")
        capNow = false
        XCTAssertTrue(session.redecide(orientation: .landscape, paperArea: size(951, 446)))
        XCTAssertFalse(session.plan.overviewCap, "unfolded: the window of now has no cap")
        XCTAssertFalse(session.overviewCap)
        capNow = true
        XCTAssertTrue(session.redecide(orientation: .landscape, paperArea: size(594, 141)))
        XCTAssertTrue(session.plan.overviewCap, "folded: the cap again")
        XCTAssertTrue(session.overviewCap)

        // Without the hook: 1.3's (the opening's cap at every redecide), capped or not.
        let still = SpanSession(kind: .week, weekStart: .monday, focus: nov16, sync: bed.engine, deviceClass: .iPhone,
                                orientation: .landscape, number: 2,
                                context: SpanSession.PaperContext(now: bed.now, calendar: SessionTestBed.tokyo),
                                overviewCap: true, sleep: { await sleeper.sleep($0) }, clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) })
        XCTAssertTrue(still.redecide(orientation: .portrait, paperArea: size(402, 540)))
        XCTAssertTrue(still.redecide(orientation: .landscape, paperArea: size(874, 205)))
        XCTAssertTrue(still.plan.overviewCap, "no hook: the cap stays")
        let wide = SpanSession(kind: .day, weekStart: .monday, focus: nov16, sync: bed.engine, deviceClass: .iPhone,
                               orientation: .landscape, number: 3,
                               context: SpanSession.PaperContext(now: bed.now, calendar: SessionTestBed.tokyo),
                               overviewCap: true, wideWindow: true, sleep: { await sleeper.sleep($0) },
                               clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) })
        XCTAssertFalse(wide.plan.overviewCap, "a wide window opens without the cap")
        XCTAssertTrue(wide.redecide(orientation: .landscape, paperArea: size(951, 446)))
        XCTAssertFalse(wide.plan.overviewCap, "no hook: no cap stays")
        // A session of P-B6 ア's numbers (not asked for the cap) never takes it from the window.
        let notAsked = SpanSession(kind: .week, weekStart: .monday, focus: nov16, sync: bed.engine, deviceClass: .iPhone,
                            orientation: .landscape, number: 4,
                            context: SpanSession.PaperContext(now: bed.now, calendar: SessionTestBed.tokyo),
                            overviewCapNow: { true }, sleep: { await sleeper.sleep($0) }, clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) })
        XCTAssertTrue(notAsked.redecide(orientation: .landscape, paperArea: size(874, 205)))
        XCTAssertFalse(notAsked.plan.overviewCap)

        // Through the screen's paths: the hook reaches every window opened after it is set.
        capNow = true
        paths.overviewCapNow = { capNow }
        let screen = try openWindow(size(874, 402))
        XCTAssertTrue(screen.plan.overviewCap, "an iPhone's landscape window, capped")
        capNow = false
        XCTAssertTrue(screen.redecide(orientation: .landscape, paperArea: size(874, 205)))
        XCTAssertFalse(screen.plan.overviewCap, "the window of now, read through ScreenPaths")
    }
}
