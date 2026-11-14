@_spi(SpanLedger) import InkModel
import Layout
import XCTest
@testable import TegakiCalendar

// 1.3 (docs/M7C_CONTRACT.md §3.1, §3.5, §3.7, §3.8, §3.11, §3.15, §6.6, D2, D7, D20, D21; wave C's plan §3.1, §3.2, §3.4
// and the lead's decisions C3-M1 … C3-m11): the screen's calls of both paths through `ScreenPaths`, over a live
// `SyncEngine` (SessionTestBed: a temporary `InkPageStore`, `InMemoryCloudDatabase`, `TestSleeper` for every wait, a fixed
// clock; no real sleep, §3.16). The engine's two hooks are routed through `ScreenPaths` as the screen routes them. The
// canvas of a window is `JoinedLedgerStandIn` (its journal into the session's inbox, as the canvas puts it); the canvas of
// the one page is the binding `ScreenPaths.pageBinding` gives it. The tests with the real canvas are in
// ScreenPathsCanvasSpanTests (not in the repeated run, C3-m2).
//
// The pages: iPad 11 portrait (R = 2), five Monday weeks around 11/16: 11/02 … 11/30.

@MainActor
final class ScreenPathsSpanTests: XCTestCase {
    private var bed: SessionTestBed!
    private var faults: [String] = []
    private var savedOnFault: ((String) -> Void)!
    private var savedDefaults: UserDefaults!
    private var scratch: UserDefaults!
    private var suiteName = ""
    private var setting = true
    private var one: OnePageSession!
    private var paths: ScreenPaths!
    private var stageTwo: [PageKind] = []

    private let w1102 = "w-2026-11-02"
    private let w1109 = "w-2026-11-09"
    private let w1116 = "w-2026-11-16"
    private let w1123 = "w-2026-11-23"
    private let w1130 = "w-2026-11-30"
    private let nov16 = DayKey(year: 2026, month: 11, day: 16)
    private let nov18 = DayKey(year: 2026, month: 11, day: 18)
    private let ipad = ScreenPaths.Device(deviceClass: .iPad11, orientation: .portrait)

    override func setUp() async throws {
        bed = try SessionTestBed("ScreenPathsSpanTests")
        faults = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
        suiteName = "ScreenPathsSpanTests-\(UUID().uuidString)"
        scratch = UserDefaults(suiteName: suiteName)
        savedDefaults = AppSettings.defaults
        AppSettings.defaults = scratch
        setting = true
        stageTwo = []
        paths = makePaths()
        one = paths.onePage
    }

    override func tearDown() async throws {
        AppSettings.defaults = savedDefaults
        scratch?.removePersistentDomain(forName: suiteName)
        SpanSession.onFault = savedOnFault
        paths = nil
        one = nil
        bed?.tearDown()
        bed = nil
    }

    /// The screen's `ScreenPaths` over the bed's engine: its timers on the bed's session sleeper, its clock the bed's,
    /// the setting `setting`, the records in the scratch defaults, the engine's hooks routed as the screen routes them.
    private func makePaths(screenshot: Bool = false, shot: ScreenshotMode.Config? = nil) -> ScreenPaths {
        let sleeper = bed.sessionSleeper
        let made = ScreenPaths(sync: bed.engine,
                               onePage: OnePageSession(sync: bed.engine, sleep: { await sleeper.sleep($0) },
                                                       clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) }),
                               screenshot: screenshot,
                               shot: shot,
                               settingOn: { [weak self] in self?.setting ?? true },
                               defaults: scratch,
                               sleep: { await sleeper.sleep($0) },
                               clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) })
        made.onStageTwo = { [weak self] in self?.stageTwo.append($0) }
        bed.engine.onRemoteUpdate = { [weak made] page in
            guard let made else { return }
            _ = made.remoteUpdated(page, shownPageId: made.onePage.page.pageId)
        }
        bed.engine.onRemoteDelete = { [weak made] id in
            guard let made else { return }
            _ = made.remoteDeleted(id, shownPageId: made.onePage.page.pageId)
        }
        return made
    }

    private func opening(_ kind: PageKind = .week, focus: DayKey? = nil, weekStart: WeekStart = .monday,
                         device: ScreenPaths.Device?? = .none, now: Date? = nil) -> ScreenPaths.Opening {
        ScreenPaths.Opening(kind: kind, focus: focus ?? nov16, weekStart: weekStart, device: device ?? ipad, paperArea: nil,
                            context: SpanSession.PaperContext(now: now ?? bed.now, calendar: SessionTestBed.tokyo))
    }

    /// The window at 11/16 opened through `ScreenPaths` and read (the canvas starts `prefetch` as it attaches).
    @discardableResult
    private func openWindow(_ o: ScreenPaths.Opening? = nil, file: StaticString = #filePath, line: UInt = #line) async throws -> SpanSession {
        XCTAssertEqual(paths.open(o ?? opening()), .joined, file: file, line: line)
        let session = try XCTUnwrap(paths.span, file: file, line: line)
        await session.prefetch()
        return session
    }

    /// The one page at 11/16 (the setting off), its file holding `ids` (in the fake cloud too when `synced`).
    private func showOnePage(_ ids: [String], synced: Bool = false, file: StaticString = #filePath, line: UInt = #line) async throws {
        if synced { await bed.startSynced() }
        try bed.engine.save(bed.page(w1116, ids))
        if synced { await bed.flushDebounce() }
        setting = false
        XCTAssertEqual(paths.open(opening()), .onePage, file: file, line: line)
        XCTAssertEqual(Set(one.page.liveStrokeIds), Set(ids), file: file, line: line)
        // The opening's single-page fetch (`pageOpened`, 1.2.3) runs now, before a test changes the account: a fetch still
        // queued when the fake deletes the zone and switches the account at once would meet the missing zone before the
        // engine heard of the switch and send the page again (the engine's zone recovery, a race of the engine alone).
        if synced { await bed.engine.waitUntilIdle() }
    }

    private var oneBase: String { "\(w1116)|monday" }

    /// The one page with `extra` written through the one-page canvas's binding.
    private func writeOnePage(_ extra: String, base: String? = nil, x: CGFloat = 600) {
        var page = one.page
        page.add(bed.stroke(extra, x: x))
        paths.pageBinding(base: base ?? oneBase) {}.set(page)
    }

    /// The engine waits for the account answer (another iCloud account signed in), its account check held.
    private func accountChangedAndHeld() async -> Int {
        bed.db.simulateZoneDeleted()
        bed.db.simulateAccountChange(status: .available, userName: "_user-b")
        await bed.engine.waitUntilIdle()
        XCTAssertEqual(bed.status, .accountMismatch)
        bed.db.pause(.accountStatus)
        return bed.db.calls.filter { $0 == .accountStatus }.count
    }

    private func at(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) throws -> Date {
        try XCTUnwrap(SessionTestBed.tokyo.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)))
    }

    /// The band x (lu) of the middle of the page `slots` pages from the focus page.
    private func middle(of session: SpanSession, slots offset: Int = 0) -> CGFloat {
        let w = session.plan.pageWidth
        let slot = CGFloat(session.focusSlot + offset)
        return slot * w + w / 2
    }

    private func settle(_ turns: Int = 24) async {
        for _ in 0..<turns {
            await Task.yield()
        }
    }

    /// Screenshot mode's arguments of the photos of 2026-10 (its day: Wednesday 10/7) and `extra`.
    private func shotConfig(_ extra: [String]) throws -> ScreenshotMode.Config {
        try XCTUnwrap(ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "week"] + extra))
    }

    /// The photos' day with `--screenshot-month 2026-10`.
    private let oct7 = DayKey(year: 2026, month: 10, day: 7)

    /// `ScreenshotMode.spanDemoPage` with the photos' defaults (no grown, empty, tall year or store ink).
    private func demo(_ pageId: String, _ kind: PageKind, crossing: Bool) -> InkPage {
        ScreenshotMode.spanDemoPage(pageId: pageId, kind: kind, focus: oct7, weekStart: .monday, crossing: crossing,
                                    grown: false, empty: false, tallYear: false, storeInk: false)
    }

    /// `span.state`'s value as its fields.
    private func fields(_ label: String) -> [String: String] {
        var out: [String: String] = [:]
        for part in label.split(separator: ";") {
            guard let eq = part.firstIndex(of: "=") else { continue }
            out[String(part[..<eq])] = String(part[part.index(after: eq)...])
        }
        return out
    }

    private static let repository = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    // MARK: §5.1 — the one place that decides the path

    /// §5.1, D2: month and year are one page always; a week or a day joins with the setting on, in screenshot mode only with its
    /// own memory-only setting (off by default: the photos stay 1.2.3's), and not after it fell back in this run (stage 2).
    /// `open` follows it.
    func testOnePagePathDecision() async throws {
        for kind in [PageKind.month, .year] {
            XCTAssertFalse(ScreenPaths.joins(kind: kind, setting: true, screenshot: false, screenshotSpan: true, fallenBack: []), "\(kind)")
            XCTAssertFalse(ScreenPaths.joins(kind: kind, setting: true, screenshot: true, screenshotSpan: true, fallenBack: []), "\(kind)")
        }
        for kind in [PageKind.week, .day] {
            XCTAssertTrue(ScreenPaths.joins(kind: kind, setting: true, screenshot: false, screenshotSpan: false, fallenBack: []), "\(kind)")
            XCTAssertFalse(ScreenPaths.joins(kind: kind, setting: false, screenshot: false, screenshotSpan: true, fallenBack: []), "\(kind) off")
            XCTAssertFalse(ScreenPaths.joins(kind: kind, setting: true, screenshot: true, screenshotSpan: false, fallenBack: []),
                           "\(kind): screenshot mode's default")
            XCTAssertTrue(ScreenPaths.joins(kind: kind, setting: false, screenshot: true, screenshotSpan: true, fallenBack: []),
                          "\(kind): screenshot mode's own setting")
            XCTAssertFalse(ScreenPaths.joins(kind: kind, setting: true, screenshot: false, screenshotSpan: false, fallenBack: [kind]),
                           "\(kind): stage 2")
            XCTAssertFalse(ScreenPaths.joins(kind: kind, setting: true, screenshot: true, screenshotSpan: true, singlePage: true, fallenBack: []),
                           "\(kind): --screenshot-single-page, the old versions' view")
            XCTAssertTrue(ScreenPaths.joins(kind: kind, setting: true, screenshot: false, screenshotSpan: false, singlePage: true, fallenBack: []),
                          "\(kind): no screenshot argument outside screenshot mode")
        }
        XCTAssertTrue(ScreenPaths.joins(kind: .day, setting: true, screenshot: false, screenshotSpan: false, fallenBack: [.week]))

        XCTAssertEqual(paths.open(opening(.month)), .onePage)
        XCTAssertEqual(paths.path, .onePage)
        XCTAssertNil(paths.span)
        XCTAssertEqual(one.page.pageId, PageNavigation.pageId(.month, focus: nov16, weekStart: .monday))
        XCTAssertEqual(paths.open(opening(.year)), .onePage)
        XCTAssertEqual(paths.open(opening()), .joined)
        XCTAssertEqual(paths.path, .joined)
        setting = false
        XCTAssertEqual(paths.open(opening(.day)), .onePage)
        XCTAssertEqual(one.page.pageId, "d-2026-11-16")

        // Screenshot mode: the one page (the demo page) unless its own setting is on.
        let shot = makePaths(screenshot: true)
        setting = true
        XCTAssertEqual(shot.open(opening()), .onePage)
        XCTAssertEqual(shot.onePage.page.pageId, w1116)
        shot.screenshotSpan = true
        XCTAssertEqual(shot.open(opening()), .joined)
        XCTAssertEqual(faults, [])
    }

    /// C3-m11: the device of a window comes from the idiom and the window's size; nothing before the window is laid out.
    func testDeviceFromTheWindowSize() {
        XCTAssertEqual(ScreenPaths.device(isPad: true, windowSize: CGSize(width: 820, height: 1180)),
                       ScreenPaths.Device(deviceClass: .iPad11, orientation: .portrait))
        XCTAssertEqual(ScreenPaths.device(isPad: true, windowSize: CGSize(width: 1180, height: 820)),
                       ScreenPaths.Device(deviceClass: .iPad11, orientation: .landscape))
        XCTAssertEqual(ScreenPaths.device(isPad: true, windowSize: CGSize(width: 744, height: 1133))?.deviceClass, .iPadMini)
        XCTAssertEqual(ScreenPaths.device(isPad: true, windowSize: CGSize(width: 1032, height: 1376))?.deviceClass, .iPad13)
        XCTAssertEqual(ScreenPaths.device(isPad: false, windowSize: CGSize(width: 874, height: 402)),
                       ScreenPaths.Device(deviceClass: .iPhone, orientation: .landscape))
        XCTAssertNil(ScreenPaths.device(isPad: true, windowSize: .zero))
        XCTAssertNil(ScreenPaths.device(isPad: false, windowSize: CGSize(width: CGFloat.nan, height: 800)))
    }

    /// C3-m11: a joined page without the window scene waits on the desk (no window of a guessed device); the next `open` with
    /// the device opens it. A month needs no device.
    func testAJoinedPageWaitsForTheWindowScene() async throws {
        XCTAssertEqual(paths.open(opening(device: .some(nil))), .waiting)
        XCTAssertEqual(paths.path, .erasing)
        XCTAssertTrue(paths.waitingForScene)
        XCTAssertNil(paths.span)
        XCTAssertEqual(paths.openings, 0, "no window was made")
        XCTAssertEqual(paths.open(opening()), .joined)
        XCTAssertFalse(paths.waitingForScene)
        XCTAssertEqual(paths.span?.deviceClass, .iPad11)
        XCTAssertEqual(paths.open(opening(.month, device: .some(nil))), .onePage)
    }

    // MARK: §3.1 — the ten S tests whose screen half is here (wave A's names)

    /// §3.1, K-3: switching the path saves the path on the screen first (`open`): what the window's inbox held is in the file
    /// and on the one page; what the one page wrote is in the next window; the old window is closing, never open as the
    /// same page on two paths.
    func testPathSwitchSavesThenReopens() async throws {
        let session = try await openWindow()
        let ledger = JoinedLedgerStandIn(session)
        let mine = try XCTUnwrap(ledger.draw(on: w1116))
        ledger.put() // still in the inbox
        let real = try XCTUnwrap(SpanName.split(mine.id)?.local)

        setting = false
        XCTAssertEqual(paths.open(opening()), .onePage)
        XCTAssertEqual(bed.live(w1116), [real], "saved before the switch")
        XCTAssertEqual(one.page.liveStrokeIds, [real])
        XCTAssertNil(paths.span)
        XCTAssertEqual(paths.closing.map(\.session.id), [session.id])

        writeOnePage("one-page")
        XCTAssertTrue(one.isDirty)
        setting = true
        paths.settingChanged(true)
        XCTAssertEqual(paths.open(opening()), .joined)
        let next = try XCTUnwrap(paths.span)
        XCTAssertFalse(one.isDirty, "the one page was saved before the window opened")
        XCTAssertEqual(next.page(w1116).map { Set($0.liveStrokeIds) }, [real, "one-page"])
        XCTAssertNotEqual(next.id, session.id)
        XCTAssertEqual(faults, [])
    }

    /// §3.9, K-11: `switchWeekStart` saves the window in its old form before the new form goes in, then a window of the new
    /// form opens: its pages are Sunday weeks only, and a delta of the old form never lands in it.
    func testWeekStartSwitchSavesThenReopensAndNeverMixes() async throws {
        let monday = try await openWindow()
        let ledger = JoinedLedgerStandIn(monday)
        ledger.draw(on: w1116)
        ledger.put()
        var steps: [String] = []
        monday.willPersist = { steps.append("persist \($0)") }
        paths.switchWeekStart(from: .monday, to: .sunday, apply: { steps.append("apply \($0.rawValue)") }, reopen: {
            steps.append("reopen")
            XCTAssertEqual(self.paths.open(self.opening(weekStart: .sunday)), .joined)
        })
        XCTAssertEqual(steps, ["persist \(w1116)", "apply sunday", "reopen"])
        XCTAssertEqual(bed.live(w1116).count, 1)
        let sunday = try XCTUnwrap(paths.span)
        await sunday.prefetch()
        XCTAssertEqual(sunday.weekStart, .sunday)
        XCTAssertEqual(sunday.pageIds, ["w-2026-11-01", "w-2026-11-08", "w-2026-11-15", "w-2026-11-22", "w-2026-11-29"])
        XCTAssertNotEqual(sunday.id, monday.id)
        // Nothing switches when the form is the same.
        steps = []
        paths.switchWeekStart(from: .sunday, to: .sunday, apply: { _ in steps.append("apply") }, reopen: { steps.append("reopen") })
        XCTAssertEqual(steps, [])
        XCTAssertEqual(faults, [])
    }

    /// §2 #1: going to the background saves every dirty page of the window, and only then tells the engine
    /// (`applicationDidEnterBackground`); going inactive saves without telling it.
    func testBackgroundSavesEveryDirtyPage() async throws {
        await bed.startSynced()
        let session = try await openWindow()
        let ledger = JoinedLedgerStandIn(session)
        ledger.draw(on: w1102)
        ledger.draw(on: w1116)
        ledger.draw(on: w1130)
        ledger.put() // still in the inbox
        var order: [String] = []
        session.willPersist = { order.append($0) }
        paths.engineWentToBackground = {
            order.append("engine")
            for id in [self.w1102, self.w1116, self.w1130] {
                XCTAssertEqual(self.bed.live(id).count, 1, "\(id) is on file before the engine hears of it")
            }
        }
        paths.enterBackground()
        XCTAssertEqual(order, [w1102, w1116, w1130, "engine"])
        for id in [w1102, w1116, w1130] {
            XCTAssertEqual(session.slots[id]?.dirty, false, id)
        }
        order = []
        ledger.draw(on: w1109)
        ledger.put()
        paths.sceneLeft(background: false)
        XCTAssertEqual(order, [w1109], "inactive: saved, the engine not told")
        XCTAssertEqual(faults, [])
    }

    /// §2 #8: the export saves every page first: the JSON the builder writes from the store holds the stroke that was only in
    /// the inbox and the neighbour's.
    func testExportSavesEveryPageFirst() async throws {
        try bed.engine.save(bed.page(w1109, ["old"]))
        let session = try await openWindow()
        let ledger = JoinedLedgerStandIn(session)
        let a = try XCTUnwrap(ledger.draw(on: w1109))
        let b = try XCTUnwrap(ledger.draw(on: w1123))
        ledger.put()
        paths.exportWillOpen()
        let directory = bed.directory.appendingPathComponent("export", isDirectory: true)
        let result = try await ExportBuilder(store: bed.store, directory: directory).exportJSON { _, _ in }
        let pages = InkImport.pages(try InkImport.parse(try Data(contentsOf: result.url))).pages
        let byId = Dictionary(uniqueKeysWithValues: pages.map { ($0.pageId, Set($0.liveStrokeIds)) })
        XCTAssertEqual(byId[w1109], ["old", try XCTUnwrap(SpanName.split(a.id)?.local)])
        XCTAssertEqual(byId[w1123], [try XCTUnwrap(SpanName.split(b.id)?.local)])
        XCTAssertEqual(faults, [])
    }

    /// D7, §2 #14: an import saves the window first and does not move its number: the stroke that was only in the inbox is in
    /// the file and in the window opened after it, with the import's.
    func testImportDoesNotAdvanceTheEpoch() async throws {
        await bed.startSynced()
        let session = try await openWindow()
        let ledger = JoinedLedgerStandIn(session)
        let mine = try XCTUnwrap(ledger.draw(on: w1116))
        ledger.put() // just handed over
        paths.importWillRun()
        XCTAssertEqual(session.epoch, 0)
        _ = try await bed.engine.importPages([bed.page(w1116, ["imported"])]) { _, _ in }
        paths.importDidFinish(opening())
        let real = try XCTUnwrap(SpanName.split(mine.id)?.local)
        let next = try XCTUnwrap(paths.span)
        XCTAssertNotEqual(next.id, session.id)
        XCTAssertEqual(next.epoch, 0)
        XCTAssertEqual(next.page(w1116).map { Set($0.liveStrokeIds) }, [real, "imported"])
        XCTAssertEqual(bed.live(w1116), [real, "imported"])
        // The one-page path does as 1.2.3: nothing before or after.
        setting = false
        paths.open(opening())
        writeOnePage("one")
        paths.importWillRun()
        XCTAssertTrue(one.isDirty)
        paths.importDidFinish(opening())
        XCTAssertNil(paths.span)
        XCTAssertEqual(faults, [])
    }

    /// D20: a stop on another page ends the visit (the rating prompt's): with ink when the person wrote while it was the focus,
    /// without when not; a stop on the same page ends nothing. The screen's focus keeps its weekday.
    func testReviewVisitFollowsTheFocus() async throws {
        let session = try await openWindow()
        let ledger = JoinedLedgerStandIn(session)
        var stopped = paths.stopped(session.stopped(midX: middle(of: session)), focus: nov18, kind: .week,
                                    weekStart: .monday, boundary: {})
        XCTAssertNil(stopped.visitEnded, "the same page")
        XCTAssertEqual(stopped.focus, nov18)
        bed.now = Date(timeIntervalSince1970: 1_790_000_500)
        ledger.draw(on: w1123)
        ledger.deliver()
        stopped = paths.stopped(session.stopped(midX: middle(of: session, slots: 1)), focus: stopped.focus, kind: .week,
                                weekStart: .monday, boundary: {})
        XCTAssertEqual(stopped.visitEnded, SpanSession.Visit(pageId: w1116, inkChanged: true, lastInkChangeAt: bed.now))
        XCTAssertEqual(stopped.focus, DayKey(year: 2026, month: 11, day: 25))
        stopped = paths.stopped(session.stopped(midX: middle(of: session, slots: -1)), focus: stopped.focus, kind: .week,
                                weekStart: .monday, boundary: {})
        XCTAssertEqual(stopped.visitEnded, SpanSession.Visit(pageId: w1123), "no ink there")
        XCTAssertEqual(stopped.focus, nov18)
        XCTAssertFalse(stopped.fallBack)
    }

    /// D17, §2 #9: the PDF of the focus page on the joined path is the real page (no window name, the transfer check holds) with
    /// the neighbour's stroke that reaches into it apart; the builder draws it. With TEGAKI_SPAN_SHOT_OUT the PDF is kept there
    /// (the span-shots job's photo).
    func testPDFDrawsNeighborInkWithoutPrefixedNamesInThePage() async throws {
        let session = try await openWindow()
        let ledger = JoinedLedgerStandIn(session)
        let origin = try XCTUnwrap(session.origin(ofPage: w1116))
        // Owned by 11/09 (its centre is left of the boundary), reaching 200 lu into 11/16.
        let a: CGFloat = origin - 300
        let b: CGFloat = origin - 50
        let c: CGFloat = origin + 200
        let crossing = try XCTUnwrap(ledger.draw([CGPoint(x: a, y: 900), CGPoint(x: b, y: 905), CGPoint(x: c, y: 900)]))
        XCTAssertTrue(crossing.id.hasPrefix(w1109 + "|"))
        let own = try XCTUnwrap(ledger.draw(on: w1116))
        ledger.put()
        let input = try XCTUnwrap(paths.pdfInput())
        XCTAssertEqual(input.page.pageId, w1116)
        XCTAssertTrue(SpanGuard.checkForTransfer(input.page))
        XCTAssertFalse(input.page.strokes.keys.contains { $0.contains("|") })
        XCTAssertEqual(input.page.liveStrokeIds, [try XCTUnwrap(SpanName.split(own.id)?.local)])
        XCTAssertEqual(input.neighborInk.map(\.pageId), [w1109])
        XCTAssertEqual(input.neighborInk.first?.stroke.id, SpanName.split(crossing.id)?.local)
        XCTAssertEqual(input.focus, nov16)
        XCTAssertEqual(input.paper.layout.pageId, w1116)
        let directory = bed.directory.appendingPathComponent("pdf", isDirectory: true)
        let result = try ExportBuilder(store: bed.store, directory: directory)
            .exportPDF(paper: input.paper, page: input.page, kind: .week, focus: input.focus, neighborInk: input.neighborInk)
        XCTAssertEqual(result.kind, .pdf)
        XCTAssertGreaterThan(result.byteCount, 0)
        if let out = ProcessInfo.processInfo.environment["TEGAKI_SPAN_SHOT_OUT"], !out.isEmpty {
            let folder = URL(fileURLWithPath: out, isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let target = folder.appendingPathComponent("span-pdf-neighbor-ink.pdf")
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.copyItem(at: result.url, to: target)
        }
        setting = false
        paths.open(opening())
        XCTAssertNil(paths.pdfInput(), "the one page's PDF is 1.2.3's")
        XCTAssertEqual(faults, [])
    }

    /// §3.15, D18, C3-m6: a window estimated over the device's cap as it opens falls back to one page for this kind (the page
    /// opens on one page); one that turns out too heavy once its pages are read falls back at the first stop after that, and one
    /// that is light again by then does not. Turning the setting on again decides anew.
    func testStageTwoFallsBackToOnePage() async throws {
        let iPhone = ScreenPaths.Device(deviceClass: .iPhone, orientation: .portrait)
        // iPhone portrait (R = 2): cap 12,000. Four neighbours of 800,000 bytes each are estimated 3,200 strokes each.
        for id in [w1102, w1109, w1123, w1130] {
            try Data(repeating: 0x41, count: 800_000).write(to: bed.store.url(for: id))
        }
        XCTAssertEqual(paths.open(opening(device: iPhone)), .fellBack)
        XCTAssertEqual(paths.path, .onePage)
        XCTAssertEqual(one.page.pageId, w1116)
        XCTAssertEqual(paths.fallenBack, [.week])
        XCTAssertEqual(paths.open(opening(device: iPhone)), .onePage, "the same run: one page")
        XCTAssertEqual(paths.open(opening(.day, device: iPhone)), .joined, "the day is its own kind")
        paths.settingChanged(true)
        XCTAssertEqual(paths.fallenBack, [])

        // Light as it opens, heavy once a page grows past the cap (an update from iCloud), light again before the stop: no fallback.
        for id in [w1102, w1109, w1123, w1130] {
            try? FileManager.default.removeItem(at: bed.store.url(for: id))
        }
        let session = try await openWindow(opening(device: iPhone))
        var heavy = InkPage.empty(pageId: w1123)
        for n in 0..<12_001 {
            let px = CGFloat(n % 1000)
            let py = CGFloat(n / 1000)
            let point = InkPoint(x: px, y: py, dtMs: 0, sizeW: 1, sizeH: 1, opacity: 1, force: 0, azimuth: 0, altitude: 0)
            heavy.add(InkStroke(id: "h\(n)", cell: .grid, tool: .pen, color: "#000000", t: 1, points: [point]))
        }
        session.remoteUpdated(heavy)
        XCTAssertTrue(session.fallsBackToOnePage)
        session.remoteDeleted(w1123)
        XCTAssertFalse(session.fallsBackToOnePage)
        var stopped = paths.stopped(session.stopped(midX: middle(of: session)), focus: nov16, kind: .week,
                                    weekStart: .monday, boundary: {})
        XCTAssertFalse(stopped.fallBack, "light again: no fallback")
        session.remoteUpdated(heavy)
        stopped = paths.stopped(session.stopped(midX: middle(of: session)), focus: nov16, kind: .week,
                                weekStart: .monday, boundary: {})
        XCTAssertTrue(stopped.fallBack)
        XCTAssertEqual(paths.fallenBack, [.week])
        XCTAssertEqual(paths.open(opening(device: iPhone)), .onePage)
    }

    /// §3.7, §3.16: the focus (the title) changes 6 % past a boundary; a stop remembers the kind and the focus day for the next
    /// launch (`lastPageKind`, `lastFocusDate`); screenshot mode remembers nothing.
    func testFocusHysteresisAndRemember() async throws {
        let session = try await openWindow()
        let w = session.plan.pageWidth
        let middleLeft = CGFloat(session.focusSlot) * w
        XCTAssertFalse(session.scrolled(midX: middleLeft + w + 0.05 * w), "5 % past the boundary: still 11/16")
        XCTAssertTrue(session.scrolled(midX: middleLeft + w + 0.07 * w))
        let stopped = paths.stopped(session.stopped(midX: middleLeft + 1.5 * w), focus: nov18, kind: .week, weekStart: .monday, boundary: {})
        XCTAssertEqual(stopped.focus, DayKey(year: 2026, month: 11, day: 25))
        XCTAssertEqual(scratch.string(forKey: AppSettings.lastKindKey), "week")
        XCTAssertEqual(scratch.string(forKey: AppSettings.lastFocusKey), "2026-11-25")

        let shot = makePaths(screenshot: true)
        shot.screenshotSpan = true
        XCTAssertEqual(shot.open(opening()), .joined)
        scratch.removeObject(forKey: AppSettings.lastFocusKey)
        let other = try XCTUnwrap(shot.span)
        _ = shot.stopped(other.stopped(midX: middle(of: other, slots: 1)), focus: nov18, kind: .week, weekStart: .monday, boundary: {})
        XCTAssertNil(scratch.string(forKey: AppSettings.lastFocusKey), "nothing remembered in screenshot mode")
    }

    /// §3.8, §2 #4: every window the screen opens (at a date, after a week start switch, after an import) reads its events page
    /// by page through `eventSource`, the focus first, each query under four years; the events are laid out on their page.
    func testEventsArePerPageUnderFourYears() async throws {
        var queries: [(DayKey, DayKey)] = []
        paths.eventSource = { start, end in
            queries.append((start, end))
            let day = start.adding(days: 1)
            return [LayoutEvent(id: "e-\(start)", title: "e", allDay: true, start: day.startOfDay(), end: day.adding(days: 1).startOfDay(),
                                colorHex: "#ff0000", calendarId: "c")]
        }
        let session = try await openWindow()
        XCTAssertEqual(queries.map(\.0), [DayKey(year: 2026, month: 11, day: 16), DayKey(year: 2026, month: 11, day: 9),
                                          DayKey(year: 2026, month: 11, day: 23), DayKey(year: 2026, month: 11, day: 2),
                                          DayKey(year: 2026, month: 11, day: 30)])
        for (start, end) in queries {
            XCTAssertEqual(end, start.adding(days: 7))
            XCTAssertLessThan(end.dayNumber - start.dayNumber, SpanSession.eventQueryMaxDays)
        }
        for (slot, page) in session.layout.pages.enumerated() {
            let week = try XCTUnwrap(page as? WeekPageLayout)
            XCTAssertEqual(week.allDayBand.bars.map(\.eventId), ["e-\(session.plan.firstDay(at: session.layout.pageIndex(ofSlot: slot)))"], page.pageId)
        }
        XCTAssertEqual(paths.windowEvents.count, 5)
        queries = []
        paths.switchWeekStart(from: .monday, to: .sunday, apply: { _ in }, reopen: { self.paths.open(self.opening(weekStart: .sunday)) })
        XCTAssertEqual(queries.first?.0, DayKey(year: 2026, month: 11, day: 15), "the new window's focus")
        queries = []
        paths.importDidFinish(opening(weekStart: .sunday))
        XCTAssertEqual(queries.count, 1, "the focus at once, the others as they are read")
        XCTAssertEqual(faults, [])
    }

    // MARK: §3.2 — S5A-C1: the screen's lines of H1–H3 (C3-M1)

    /// H1 (one page, §2 #18): another device's 「全て消す」 deleted the shown page's record: the page empties, its canvas is made
    /// anew (the identity moves), and the save the person's last stroke started writes nothing. Another page: nothing.
    func testScreenRemoteDeleteRebuildsTheShownOnePage() async throws {
        try await showOnePage(["a", "b"], synced: true)
        let identity = one.canvasIdentity(base: oneBase)
        writeOnePage("c")
        XCTAssertTrue(one.isDirty)
        bed.db.simulateRemoteDelete(w1116)
        await bed.engine.syncNow()
        XCTAssertEqual(one.page.liveStrokeCount, 0)
        XCTAssertFalse(one.isDirty)
        XCTAssertNotEqual(one.canvasIdentity(base: oneBase), identity, "the canvas is made anew")
        await bed.flushSessionTimers()
        await bed.flushDebounce()
        XCTAssertFalse(bed.store.exists(w1116), "the timer wrote nothing back")
        XCTAssertNil(bed.db.records[w1116])
        XCTAssertFalse(paths.remoteDeleted(w1123, shownPageId: w1116))
        XCTAssertEqual(one.canvasIdentity(base: oneBase), "\(oneBase)|1")
    }

    /// H1, H3 (one page, §2.1): the canvas made before 「全て消す」 or a record deletion hands its page on a turn late; the binding
    /// it was given keeps its identity, so the write is dropped; the new canvas's binding writes.
    func testScreenLatePublishOfTheOldCanvasIsDropped() async throws {
        try await showOnePage(["a"])
        let old = paths.pageBinding(base: oneBase) {}
        paths.eraseAll(reopen: opening())
        old.set(bed.page(w1116, ["a", "late"]))
        XCTAssertEqual(one.page.liveStrokeCount, 0, "the old canvas's late write is dropped")
        XCTAssertFalse(one.isDirty)
        var own = 0
        let fresh = paths.pageBinding(base: oneBase) { own += 1 }
        var page = one.page
        page.add(bed.stroke("new", x: 500))
        fresh.set(page)
        XCTAssertEqual(one.page.liveStrokeIds, ["new"])
        XCTAssertEqual(own, 1, "the person's own ink (1.2.1)")
        let before = paths.pageBinding(base: oneBase) {}
        XCTAssertTrue(paths.remoteDeleted(w1116, shownPageId: w1116))
        before.set(bed.page(w1116, ["new", "late2"]))
        XCTAssertEqual(one.page.liveStrokeCount, 0)
    }

    /// H3 (one page, §2 #12): 「全て消す」 makes the canvas anew, empties the page and stops its save.
    func testScreenEraseAllRebuildsAndEmpties() async throws {
        try await showOnePage(["a"])
        let identity = one.canvasIdentity(base: oneBase)
        writeOnePage("b")
        XCTAssertTrue(one.isDirty)
        paths.eraseAll(reopen: opening())
        XCTAssertEqual(one.page.liveStrokeCount, 0)
        XCTAssertFalse(one.isDirty)
        XCTAssertNotEqual(one.canvasIdentity(base: oneBase), identity)
        XCTAssertEqual(paths.path, .onePage)
        XCTAssertNil(paths.span)
        await bed.flushSessionTimers()
        XCTAssertEqual(bed.live(w1116), ["a"], "the stopped timer wrote nothing (the engine deletes the files itself)")
    }

    /// H2 (one page, §2 #11): 「消して始める」 closes the screen before the engine's `await`: while the engine waits, going to the
    /// background, the export, the old canvas's late write, a new stroke, the 1.5 s timer and another page write nothing into
    /// the new account's store; after the answer the page is read again and saving goes on.
    func testScreenEraseAndStartClosesBeforeTheAwait() async throws {
        try await showOnePage(["a", "b"], synced: true)
        let oldCanvas = paths.pageBinding(base: oneBase) {}
        writeOnePage("c")
        XCTAssertTrue(one.isDirty)
        let checks = await accountChangedAndHeld()
        var shown = nov16
        var closed = 0
        var answered = 0
        let answer = paths.chooseAccount(.eraseInk, resolve: { await self.bed.engine.resolveAccountChange($0) },
                                         closed: { closed += 1 }, answered: { answered += 1 },
                                         reload: { self.paths.reloadShown(self.opening(focus: shown)) })
        XCTAssertEqual(closed, 1)
        XCTAssertEqual(one.page.liveStrokeCount, 0, "closed before the await")
        XCTAssertFalse(one.isDirty)
        await bed.yieldUntil { bed.db.calls.filter { $0 == .accountStatus }.count > checks }
        XCTAssertEqual(bed.store.allPageIds(), [], "the engine emptied the store before its await")

        paths.enterBackground()                                   // (1) the background
        paths.exportWillOpen()                                    // (3) the export
        oldCanvas.set(bed.page(w1116, ["a", "b", "c", "late"]))   // the old canvas's late write
        writeOnePage("d")                                          // (4) a new stroke on the new canvas
        await bed.sessionSleeper.advance()                        // (5) the 1.5 s timer
        shown = DayKey(year: 2026, month: 11, day: 23)
        paths.open(opening(focus: shown))                         // (2) another page: saved first, then opened
        XCTAssertEqual(bed.store.allPageIds(), [], "nothing was written meanwhile")
        XCTAssertEqual(bed.engine.state.dirty, [])

        bed.db.resume()
        await answer.value
        XCTAssertEqual(answered, 1)
        XCTAssertEqual(bed.engine.state.account, "_user-b")
        XCTAssertEqual(one.page.pageId, w1123)
        writeOnePage("new-account", base: "\(w1123)|monday")
        await bed.flushSessionTimers()
        XCTAssertEqual(bed.live(w1123), ["new-account"], "saving goes on after the page was read again")
        for id in bed.store.allPageIds() where id != w1123 {
            XCTAssertEqual(bed.live(id), [], "nothing of the old account in \(id)")
        }
    }

    /// §2 #10 (both paths): 「残す」 saves before the engine's answer — the one page's last stroke, and the window's inbox.
    func testScreenKeepInkSavesBeforeTheAnswer() async throws {
        try await showOnePage(["a"])
        writeOnePage("b")
        var onFile: Set<String> = []
        await paths.chooseAccount(.keepInk, resolve: { _ in onFile = self.bed.live(self.w1116) }, reload: {}).value
        XCTAssertEqual(onFile, ["a", "b"])

        setting = true
        let session = try await openWindow()
        let ledger = JoinedLedgerStandIn(session)
        let mine = try XCTUnwrap(ledger.draw(on: w1123))
        ledger.put()
        var reloaded = 0
        await paths.chooseAccount(.keepInk, resolve: { _ in onFile = self.bed.live(self.w1123) }, reload: { reloaded += 1 }).value
        XCTAssertEqual(onFile, [try XCTUnwrap(SpanName.split(mine.id)?.local)])
        XCTAssertEqual(reloaded, 1)
        XCTAssertEqual(faults, [])
    }

    /// H1 (joined, §2 #18, §3.4 (d)): a record deletion reaches the window on the screen and the closing one: the stroke the
    /// closing window's canvas hands over after the reopening (made before the deletion) is dropped, and its last save writes
    /// nothing back.
    func testScreenRemoteDeleteReachesTheWindowAndTheClosingSession() async throws {
        await bed.startSynced()
        try bed.engine.save(bed.page(w1123, ["a", "b"]))
        await bed.flushDebounce()
        let old = try await openWindow()
        await bed.engine.waitUntilIdle()
        let ledger = JoinedLedgerStandIn(old)
        ledger.draw(on: w1123)
        ledger.put()
        ledger.draw(on: w1123, x: 500) // PencilKit has not told yet: it comes with the canvas's hand-over
        let current = try await openWindow()
        await bed.engine.waitUntilIdle()
        XCTAssertEqual(paths.closing.map(\.session.id), [old.id])
        XCTAssertEqual(bed.live(w1123).count, 3, "saved as the window closed")
        await bed.flushDebounce()

        bed.db.simulateRemoteDelete(w1123)
        await bed.engine.syncNow()
        XCTAssertEqual(current.page(w1123)?.liveStrokeCount, 0)
        XCTAssertEqual(old.page(w1123)?.liveStrokeCount, 0, "the closing window took the deletion too")

        ledger.put() // the old canvas's hand-over
        await settle()
        XCTAssertTrue(paths.closing.isEmpty, "saved and let go")
        await bed.flushSessionTimers()
        await bed.flushDebounce()
        XCTAssertFalse(bed.store.exists(w1123), "nothing written back")
        XCTAssertNil(bed.db.records[w1123])
        XCTAssertEqual(current.page(w1123)?.liveStrokeCount, 0)
        XCTAssertEqual(faults, [])
    }

    /// H3 (joined, §2 #12, §4.4): after 「全て消す」 the new window holds empty pages even before the engine deleted the files (a
    /// page read now would bring the erased strokes back); once the engine is done, a stroke written and saved is the only one.
    func testScreenEraseAllOnTheJoinedPathOpensAnEmptyWindow() async throws {
        try bed.engine.save(bed.page(w1116, ["a", "b"]))
        let old = try await openWindow()
        paths.eraseAll(reopen: opening())
        let fresh = try XCTUnwrap(paths.span)
        XCTAssertNotEqual(fresh.id, old.id, "a new canvas: no ↶")
        XCTAssertEqual(old.epoch, 1, "the old window was cancelled")
        XCTAssertTrue(bed.store.exists(w1116), "the engine has not erased yet")
        XCTAssertEqual(fresh.page(w1116)?.liveStrokeCount, 0, "empty before the engine erased")
        await fresh.prefetch()
        XCTAssertTrue(fresh.pageIds.allSatisfy { fresh.page($0)?.liveStrokeCount == 0 })
        try await bed.engine.eraseEverything()
        paths.eraseDidFinish()
        let ledger = JoinedLedgerStandIn(fresh)
        let mine = try XCTUnwrap(ledger.draw(on: w1116))
        ledger.put()
        XCTAssertEqual(paths.saveCurrent(), [])
        XCTAssertEqual(bed.live(w1116), [try XCTUnwrap(SpanName.split(mine.id)?.local)], "the erased strokes do not come back")
        XCTAssertEqual(faults, [])
    }

    /// H2 (joined, §2 #11): 「消して始める」 closes the window before the engine's `await` (the desk instead of the canvas); the
    /// background, the export, the canvas's late deltas and the timer write nothing meanwhile; a new window after the answer.
    func testScreenEraseAndStartOnTheJoinedPathClosesBeforeTheAwait() async throws {
        await bed.startSynced()
        try bed.engine.save(bed.page(w1116, ["a", "b"]))
        await bed.flushDebounce()
        let old = try await openWindow()
        await bed.engine.waitUntilIdle()
        let ledger = JoinedLedgerStandIn(old)
        ledger.draw(on: w1116)
        ledger.put()
        let checks = await accountChangedAndHeld()
        let answer = paths.chooseAccount(.eraseInk, resolve: { await self.bed.engine.resolveAccountChange($0) },
                                         reload: { self.paths.reloadShown(self.opening()) })
        XCTAssertTrue(old.isClosed, "closed before the await")
        XCTAssertEqual(paths.path, .erasing)
        XCTAssertNil(paths.span)
        await bed.yieldUntil { bed.db.calls.filter { $0 == .accountStatus }.count > checks }
        paths.enterBackground()
        paths.exportWillOpen()
        ledger.draw(on: w1116, x: 500)
        ledger.put()
        await settle()
        await bed.sessionSleeper.advance()
        XCTAssertEqual(bed.store.allPageIds(), [], "nothing of the old account reached the new store")
        bed.db.resume()
        await answer.value
        await bed.flushDebounce()
        XCTAssertEqual(paths.path, .joined)
        let fresh = try XCTUnwrap(paths.span)
        XCTAssertNotEqual(fresh.id, old.id)
        XCTAssertEqual(fresh.page(w1116)?.liveStrokeCount, 0)
        XCTAssertEqual(bed.store.allPageIds(), [])
        XCTAssertNil(bed.db.records[w1116])
        XCTAssertEqual(faults, [])
    }

    /// C3-M1, H2: a closing window (its canvas not yet handed over) is closed too before the `await`: its canvas's hand-over
    /// during the wait writes nothing into the new account's store.
    func testScreenEraseAndStartClosesTheClosingSessionsBeforeTheAwait() async throws {
        await bed.startSynced()
        try bed.engine.save(bed.page(w1116, ["a"]))
        await bed.flushDebounce()
        let old = try await openWindow()
        await bed.engine.waitUntilIdle()
        let ledger = JoinedLedgerStandIn(old)
        ledger.draw(on: w1116)
        ledger.put()
        ledger.draw(on: w1123) // not told yet: the canvas hands it over when it is taken away
        try await openWindow()
        await bed.engine.waitUntilIdle()
        XCTAssertEqual(paths.closing.count, 1)
        let checks = await accountChangedAndHeld()
        let answer = paths.chooseAccount(.eraseInk, resolve: { await self.bed.engine.resolveAccountChange($0) },
                                         reload: { self.paths.reloadShown(self.opening()) })
        XCTAssertTrue(old.isClosed, "the closing window is closed before the await")
        XCTAssertTrue(paths.closing.isEmpty)
        await bed.yieldUntil { bed.db.calls.filter { $0 == .accountStatus }.count > checks }
        ledger.put() // the old canvas's hand-over arrives during the wait
        await settle()
        paths.enterBackground()
        await bed.sessionSleeper.advance()
        XCTAssertEqual(bed.store.allPageIds(), [], "nothing of the old account reached the new store")
        bed.db.resume()
        await answer.value
        await bed.flushDebounce()
        XCTAssertEqual(bed.store.allPageIds(), [])
        XCTAssertEqual(faults, [])
    }

    /// C3-M1, H3: 「全て消す」 cancels the closing windows too: the stroke a closing window's canvas hands over afterwards (made
    /// before the erase) is dropped, never saved into the erased store.
    func testScreenEraseAllEmptiesTheClosingSessions() async throws {
        try bed.engine.save(bed.page(w1116, ["a"]))
        let old = try await openWindow()
        let ledger = JoinedLedgerStandIn(old)
        ledger.draw(on: w1123) // not told yet
        try await openWindow()
        XCTAssertEqual(paths.closing.count, 1)
        paths.eraseAll(reopen: opening())
        XCTAssertTrue(paths.closing.isEmpty)
        XCTAssertEqual(old.epoch, 1, "cancelled")
        try await bed.engine.eraseEverything()
        paths.eraseDidFinish()
        ledger.put() // the hand-over, made under the old number
        await settle()
        await bed.flushSessionTimers()
        XCTAssertEqual(bed.store.allPageIds(), [], "the erased store stays empty")
        XCTAssertTrue(old.records.contains { $0.hasPrefix("dropped a delta of number 0 for \(w1123)") })
        XCTAssertEqual(faults, [])
    }

    // MARK: §3.4 — the closing window (§3.4 (d), C3-m9)

    /// §3.4 (d): after a reopening the old window's canvas hands over a stroke (the detach): the closing window takes it on the
    /// turn it arrives, saves it, hands the page to the new window and is let go.
    func testReopenDrainsTheOldSessionAfterItsCanvasLeft() async throws {
        let old = try await openWindow()
        let ledger = JoinedLedgerStandIn(old)
        let late = try XCTUnwrap(ledger.draw(on: w1123)) // not told yet
        let fresh = try await openWindow()
        XCTAssertEqual(paths.closing.count, 1)
        XCTAssertEqual(bed.live(w1123), [], "not in the store yet")
        ledger.put() // the canvas's hand-over as SwiftUI takes it away
        await settle()
        let real = try XCTUnwrap(SpanName.split(late.id)?.local)
        XCTAssertEqual(bed.live(w1123), [real], "saved")
        XCTAssertEqual(fresh.page(w1123)?.liveStrokeIds, [real], "the new window has it too")
        XCTAssertTrue(paths.closing.isEmpty)
        XCTAssertEqual(faults, [])
    }

    /// C3-m9: a closing window is let go only after its canvas handed over (a put moved its inbox's basis off −1) — neither at
    /// the new canvas's first viewport nor at a save before that — or at once when it never had a canvas.
    func testAClosingSessionIsLetGoOnlyAfterItsCanvasHandedOver() async throws {
        let old = try await openWindow()
        let ledger = JoinedLedgerStandIn(old) // its canvas attached (the window put)
        try await openWindow()
        XCTAssertEqual(old.inbox.latestBasis, -1)
        XCTAssertFalse(try XCTUnwrap(paths.closing.first).handedOver)
        paths.viewportArrived(PaperViewport(offsetX: 0, zoom: 0.5, width: 834))
        await settle()
        XCTAssertEqual(paths.closing.count, 1, "kept at the first viewport: the canvas has not handed over")
        paths.saveCurrent()
        XCTAssertEqual(paths.closing.count, 1, "kept at a save")
        ledger.put() // nothing new, but the hand-over
        XCTAssertTrue(try XCTUnwrap(paths.closing.first).handedOver)
        paths.saveCurrent()
        XCTAssertTrue(paths.closing.isEmpty, "let go")

        // A window whose canvas was never made (opened anew in the same turn) has nothing to hand over.
        let unseen = try XCTUnwrap(paths.span)
        try await openWindow()
        XCTAssertEqual(paths.closing.map(\.session.id), [unseen.id])
        paths.saveCurrent()
        XCTAssertTrue(paths.closing.isEmpty)
    }

    // MARK: §3.4 — the band's points, coordinates, the heading, 「今日」

    /// HANDOFF 9: a tap, a double tap and the 予定 tool on the band go to the page under the point, with the point in its lu.
    func testTapsAndEventsGoToThePageUnderThePoint() async throws {
        let start = try at(11, 24, 11)
        paths.eventSource = { first, end in
            let day = DayKey(year: 2026, month: 11, day: 24)
            return first <= day && day < end
                ? [LayoutEvent(id: "e", title: "e", allDay: false, start: start, end: start.addingTimeInterval(3600), colorHex: "#ff0000", calendarId: "c")]
                : []
        }
        let session = try await openWindow()
        let box = try XCTUnwrap(session.layout.timedBoxes.first { $0.eventId == "e" })
        XCTAssertGreaterThan(box.frame.minX, try XCTUnwrap(session.origin(ofPage: w1123)), "on 11/23's page in the band")
        XCTAssertEqual(ScreenPaths.tapTarget(layout: session.layout, point: CGPoint(x: box.frame.midX, y: box.frame.midY), zoom: 0.5,
                                             smallScreen: false, allowFinger: false, currentMonth: 11), .timedBox("e"))
        let slot = try XCTUnwrap(session.layout.slot(ofPage: w1123))
        let week = try XCTUnwrap(session.layout.pages[slot] as? WeekPageLayout)
        let column = week.columnFrame(2).offsetBy(dx: session.layout.origin(ofSlot: slot), dy: 0)
        XCTAssertEqual(session.layout.dayAt(point: CGPoint(x: column.midX, y: 500)), DayKey(year: 2026, month: 11, day: 25))
        let left: CGFloat = column.midX - 20
        let rect = CGRect(x: left, y: week.minutesToY(600), width: 40, height: 100)
        let made = try XCTUnwrap(ScreenPaths.newEvent(layout: session.layout, rect: rect, now: bed.now))
        XCTAssertEqual(made.pageId, w1123)
        guard case .create(let range?) = made.plan else { return XCTFail("\(made.plan)") }
        XCTAssertFalse(range.allDay)
        XCTAssertEqual(DayKey(range.start), DayKey(year: 2026, month: 11, day: 25), "the day of the page under the rect")
        XCTAssertNil(ScreenPaths.newEvent(layout: session.layout, rect: CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1), now: bed.now))
    }

    /// 1.1's 0-4 on the joined path: a rect at or below 24:00 on a day page of the window is refused there (the plan of the page
    /// under it; the band itself is no day page).
    func testNewEventBelow24OnTheJoinedDayIsRefused() async throws {
        let session = try await openWindow(opening(.day))
        let d1117 = "d-2026-11-17"
        let origin = try XCTUnwrap(session.origin(ofPage: d1117))
        let left: CGFloat = origin + 300
        let below = CGRect(x: left, y: 2_500, width: 100, height: 100)
        let made = try XCTUnwrap(ScreenPaths.newEvent(layout: session.layout, rect: below, now: bed.now))
        XCTAssertEqual(made.pageId, d1117)
        XCTAssertEqual(made.plan, .refusedBelowDay)
        XCTAssertNotEqual(CalendarRootScreen.newEventPlan(layout: session.layout, rect: below, now: bed.now), .refusedBelowDay,
                          "the band alone does not know it is a day page")
        let above = try XCTUnwrap(ScreenPaths.newEvent(layout: session.layout, rect: below.offsetBy(dx: 0, dy: -1_500), now: bed.now))
        guard case .create(let range?) = above.plan else { return XCTFail("\(above.plan)") }
        XCTAssertEqual(DayKey(range.start), DayKey(year: 2026, month: 11, day: 17))
    }

    /// 「予定にする」 (HANDOFF 9): the picture is drawn from the real pages (no `@_spi`), a window name the page does not hold (a long
    /// id's alias) is left out; the event's page is the page under the selection; the strokes are erased only while the window
    /// that named them is the screen's (the one page: while its page is shown).
    func testConvertSelectionUsesTheOwnerPage() async throws {
        let session = try await openWindow()
        let ledger = JoinedLedgerStandIn(session)
        let stroke = try XCTUnwrap(ledger.draw(on: w1123))
        ledger.deliver()
        let picture = ScreenPaths.selectionPicture([stroke.id, SpanName.prefixed(id: "span~a~9", page: w1123)], in: session)
        XCTAssertEqual(picture.strokes.count, 1)
        let drawn = try XCTUnwrap(picture.strokes.first)
        XCTAssertEqual(drawn.id, SpanName.split(stroke.id)?.local)
        XCTAssertEqual(drawn.cell, SpanName.prefixed(.grid, page: w1123))
        XCTAssertNotNil(picture.cells[drawn.cell])
        XCTAssertEqual(session.page(w1123)?.strokes[drawn.id]?.cell, .grid, "the page itself is untouched")
        let bounds = try XCTUnwrap(stroke.paperBounds(cellOrigin: try XCTUnwrap(session.layout.cells[stroke.cell]).origin))
        XCTAssertEqual(ScreenPaths.newEvent(layout: session.layout, rect: bounds, now: bed.now)?.pageId, w1123)
        XCTAssertTrue(ScreenPaths.erasesConverted(requestPageId: w1123, requestSessionId: session.id, shownPageId: w1116, sessionId: session.id))
        XCTAssertFalse(ScreenPaths.erasesConverted(requestPageId: w1123, requestSessionId: session.id, shownPageId: w1123, sessionId: "other"))
        XCTAssertTrue(ScreenPaths.erasesConverted(requestPageId: w1116, requestSessionId: nil, shownPageId: w1116, sessionId: nil))
        XCTAssertFalse(ScreenPaths.erasesConverted(requestPageId: w1116, requestSessionId: nil, shownPageId: w1123, sessionId: session.id))
    }

    /// L9, HANDOFF 6: the opening's positions are in the band's lu — the focus page's `initialScrollX` / `Y` and
    /// `--screenshot-offset` with its origin added — and the first frame's viewport puts the focus page in the middle at the
    /// overview, the band's `initialScrollX` zoomed in.
    func testBandCoordinatesAddTheFocusOrigin() async throws {
        let now = try at(11, 18, 10)
        let session = try await openWindow(opening(now: now))
        let slot = try XCTUnwrap(session.layout.slot(ofPage: w1116))
        let origin = session.layout.origin(ofSlot: slot)
        XCTAssertEqual(origin, 2 * 1_400)
        let page = session.layout.pages[slot]
        let tokyo = SessionTestBed.tokyo
        let start = ScreenPaths.bandStart(layout: session.layout, focusPageId: w1116, now: now, calendar: tokyo, visibleWidth: 600)
        let pageX: CGFloat = PageNavigation.initialScrollX(page, now: now, calendar: tokyo, visibleWidth: 600)
        XCTAssertEqual(start.x, origin + pageX, accuracy: 1e-9)
        XCTAssertGreaterThan(start.x, origin, "today's column, right of the page's edge")
        XCTAssertEqual(start.y, PageNavigation.initialScrollY(page, now: now, calendar: tokyo), accuracy: 1e-9)
        XCTAssertEqual(ScreenPaths.bandPoint(CGPoint(x: 10, y: 20), layout: session.layout, focusPageId: w1116), CGPoint(x: origin + 10, y: 20))

        let area = CGSize(width: 834, height: 955)
        let overview = ScreenPaths.bandViewport(layout: session.layout, focusPageId: w1116, now: now, calendar: tokyo, area: area, ratio: 1)
        XCTAssertEqual(overview.zoom, 0.4974, accuracy: 0.0005)
        let middle: CGFloat = (origin + 700) * overview.zoom - 417
        XCTAssertEqual(overview.offsetX, middle, accuracy: 1e-6, "the focus page in the middle")
        XCTAssertEqual(overview.width, 834)
        let zoomed = ScreenPaths.bandViewport(layout: session.layout, focusPageId: w1116, now: now, calendar: tokyo, area: area, ratio: 2)
        let visible = ZoomPolicy.visibleWidth(.week, viewportWidth: 834, zoom: zoomed.zoom)
        let zoomedStart = ScreenPaths.bandStart(layout: session.layout, focusPageId: w1116, now: now, calendar: tokyo, visibleWidth: visible)
        XCTAssertEqual(zoomed.offsetX, zoomedStart.x * zoomed.zoom, accuracy: 1e-6)
        XCTAssertGreaterThan(zoomed.zoom, overview.zoom * 1.9)
    }

    /// L8: the heading shows a window with the viewport the canvas reported for it. A version whose first page did not move
    /// (events, the now line) is used at once with the last viewport; a shifted version waits for a viewport of its own (the
    /// canvas sends one in the same turn) — until then the heading keeps the window before.
    func testViewportIsPairedWithTheWindowVersion() async throws {
        let session = try await openWindow()
        XCTAssertEqual(paths.heading?.version, session.windowVersion)
        XCTAssertNil(paths.heading?.viewport, "no report yet: the screen uses the first frame's")
        let v1 = PaperViewport(offsetX: 1_000, zoom: 0.5, width: 834)
        paths.viewportArrived(v1)
        XCTAssertEqual(paths.heading?.viewport, v1)
        session.contextChanged()
        XCTAssertEqual(paths.heading?.version, session.windowVersion, "the first page did not move: at once")
        XCTAssertEqual(paths.heading?.viewport, v1)
        let shown = try XCTUnwrap(paths.heading)
        _ = session.stopped(midX: middle(of: session, slots: 1))
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex))
        XCTAssertEqual(paths.heading, shown, "the shifted window waits for its viewport")
        let v2 = PaperViewport(offsetX: 1_000 - 700, zoom: 0.5, width: 834)
        paths.viewportArrived(v2)
        let heading = try XCTUnwrap(paths.heading)
        XCTAssertEqual(heading.version, session.windowVersion)
        XCTAssertEqual(heading.firstIndex, session.layout.firstIndex)
        XCTAssertEqual(heading.viewport, v2)
        XCTAssertEqual(heading.span.pages.map(\.layout.pageId), session.pageIds)
        XCTAssertEqual(paths.headingSpan?.focus, session.focusSlot)
        XCTAssertEqual(paths.headingSpan?.bands.count, 5)
    }

    /// The plan §4.1 and the lead's decision: far → a new window; near at the overview → a slide; today's page already the focus
    /// → it comes to the middle; zoomed in → today's column from an hour before now (no slide).
    func testTodayOverviewSlidesAndZoomedReveals() async throws {
        let session = try await openWindow()
        let area = CGSize(width: 834, height: 955)
        let far = DayKey(year: 2026, month: 12, day: 10)
        XCTAssertEqual(paths.today(far, now: bed.now, viewport: nil, area: area, ratio: 1), .reopen(far))
        let dec3 = DayKey(year: 2026, month: 12, day: 3)
        XCTAssertEqual(paths.today(dec3, now: bed.now, viewport: nil, area: area, ratio: 1), .slide(2))

        let overview = PaperViewport(offsetX: 1_200, zoom: 0.4974, width: 834)
        guard case .reveal(let middle)? = paths.today(nov18, now: bed.now, viewport: overview, area: area, ratio: 1) else {
            return XCTFail("today's page is the focus: reveal")
        }
        let origin = try XCTUnwrap(session.origin(ofPage: w1116))
        let centred: CGFloat = (origin + 700) * overview.zoom - 417
        let start: CGFloat = middle.minX * overview.zoom - ZoomPolicy.revealMargin
        XCTAssertEqual(start, centred, accuracy: 1e-6)
        let offset = ZoomPolicy.revealOffset(rect: middle, zoom: overview.zoom, viewport: area, current: CGPoint(x: 0, y: 0))
        XCTAssertEqual(offset.x, centred, accuracy: 1e-6, "the canvas puts the page in the middle")

        let zoomed = PaperViewport(offsetX: 2_000, zoom: 1.2, width: 834)
        let now = try at(12, 3, 10)
        guard case .reveal(let column)? = paths.today(dec3, now: now, viewport: zoomed, area: area, ratio: 1) else {
            return XCTFail("zoomed in: reveal, not slide")
        }
        let slot = try XCTUnwrap(session.layout.slot(ofPage: w1130))
        let week = try XCTUnwrap(session.layout.pages[slot] as? WeekPageLayout)
        let today = week.columnFrame(3).offsetBy(dx: session.layout.origin(ofSlot: slot), dy: 0)
        XCTAssertEqual(column.minX, today.minX, accuracy: 1e-9)
        XCTAssertEqual(column.width, today.width, accuracy: 1e-9)
        let top: CGFloat = PageNavigation.initialScrollY(week, now: now, calendar: SessionTestBed.tokyo)
        let margin: CGFloat = ZoomPolicy.revealMargin / 1.2
        XCTAssertEqual(column.minY, top + margin, accuracy: 1e-9, "an hour before now at the top")
        XCTAssertTrue(ScreenPaths.zoomedIn(layout: session.layout, viewport: nil, area: area, ratio: 2))
        XCTAssertFalse(ScreenPaths.zoomedIn(layout: session.layout, viewport: overview, area: area, ratio: 2))
        setting = false
        paths.open(opening())
        XCTAssertNil(paths.today(nov18, now: bed.now, viewport: nil, area: area, ratio: 1), "the one page: 1.1.1's 「今日」")
    }

    /// §2 #5: ◀ ▶ slide one page of the window (the same canvas); on the one page nothing here (1.2.3's `show`).
    func testArrowsSlideOnePage() async throws {
        try await openWindow()
        XCTAssertEqual(paths.move(by: 1), .slide(pages: 1))
        XCTAssertEqual(paths.move(by: -1), .slide(pages: -1))
        setting = false
        paths.open(opening())
        XCTAssertNil(paths.move(by: 1))
    }

    // MARK: §3.4 — notices, stage 2, the sheet, the save failure

    /// D21: the stroke budget's 15,000 notice once per page on this device, the refusal at most every 2 s, 「メモ欄はここまでです」
    /// once per page of the window.
    func testPerPageNoticesOncePerPage() async throws {
        try await openWindow()
        let t0 = bed.now
        XCTAssertEqual(paths.pageStrokeBudget(w1116, .many(15_000), now: t0), .many)
        XCTAssertNil(paths.pageStrokeBudget(w1116, .many(15_001), now: t0))
        XCTAssertEqual(paths.pageStrokeBudget(w1123, .many(15_000), now: t0), .many)
        XCTAssertTrue(AppSettings.strokeBudgetNoticed(w1116))
        XCTAssertEqual(paths.pageStrokeBudget(w1116, .full(19_000), now: t0), .full)
        XCTAssertNil(paths.pageStrokeBudget(w1123, .full(19_000), now: t0.addingTimeInterval(1.9)))
        XCTAssertEqual(paths.pageStrokeBudget(w1123, .full(19_000), now: t0.addingTimeInterval(2)), .full)
        XCTAssertTrue(paths.pageGrowthCap(w1116))
        XCTAssertFalse(paths.pageGrowthCap(w1116))
        XCTAssertTrue(paths.pageGrowthCap(w1123))
        XCTAssertFalse(paths.pageGrowthCap("w-2027-01-04"), "not in the window")
    }

    /// N-8 (the lead's decision 9 of wave A): stage 2 is said once per device and kind — not again in this run, nor in the
    /// next one on this device; never in screenshot mode.
    func testStageTwoNoticeOncePerDeviceAndKind() async throws {
        let iPhone = ScreenPaths.Device(deviceClass: .iPhone, orientation: .portrait)
        for id in [w1102, w1109, w1123, w1130] {
            try Data(repeating: 0x41, count: 800_000).write(to: bed.store.url(for: id))
        }
        XCTAssertEqual(paths.open(opening(device: iPhone)), .fellBack)
        XCTAssertEqual(stageTwo, [.week])
        XCTAssertTrue(AppSettings.stageTwoNoticed(.week))
        XCTAssertFalse(AppSettings.stageTwoNoticed(.day))
        XCTAssertEqual(scratch.object(forKey: AppSettings.stageTwoNoticedKey(.week)) as? Bool, true)
        XCTAssertEqual(AppSettings.stageTwoNoticedKey(.day), "hint.spanStageTwo.day")
        paths.settingChanged(true)
        XCTAssertEqual(paths.open(opening(device: iPhone)), .fellBack)
        XCTAssertEqual(stageTwo, [.week], "not again in this run")
        let next = makePaths()
        XCTAssertEqual(next.open(opening(device: iPhone)), .fellBack)
        XCTAssertEqual(stageTwo, [.week], "nor in the next run on this device")
        scratch.removeObject(forKey: AppSettings.stageTwoNoticedKey(.week))
        let shot = makePaths(screenshot: true)
        shot.screenshotSpan = true
        XCTAssertEqual(shot.open(opening(device: iPhone)), .fellBack)
        XCTAssertEqual(stageTwo, [.week], "never in screenshot mode")
        XCTAssertFalse(AppSettings.stageTwoNoticed(.week))
    }

    /// §3.6: the window does not shift under a sheet, the account question, the save-failure alert or screenshot mode's hold.
    /// C3-M4: `--screenshot-span-shift` holds the first window's shift from its opening until the UI test taps `span.release`
    /// (`releaseShift()`) — a window opened again meanwhile keeps the one hold, and once released no window holds again — or
    /// until the 60 s ceiling passed (the injected sleep, `TestSleeper`: no real wait). Nothing without the argument, on the
    /// one-page path (`--screenshot-single-page`) or outside screenshot mode.
    func testSheetHoldsTheShift() async throws {
        XCTAssertFalse(ScreenPaths.canvasSheetOpen(sheetIsUp: false, accountQuestion: false, saveFailed: false, shiftHeld: false))
        XCTAssertTrue(ScreenPaths.canvasSheetOpen(sheetIsUp: true, accountQuestion: false, saveFailed: false, shiftHeld: false))
        XCTAssertTrue(ScreenPaths.canvasSheetOpen(sheetIsUp: false, accountQuestion: true, saveFailed: false, shiftHeld: false))
        XCTAssertTrue(ScreenPaths.canvasSheetOpen(sheetIsUp: false, accountQuestion: false, saveFailed: true, shiftHeld: false))
        XCTAssertTrue(ScreenPaths.canvasSheetOpen(sheetIsUp: false, accountQuestion: false, saveFailed: false, shiftHeld: true))

        let shift = try shotConfig(["--screenshot-span", "on", "--screenshot-span-shift"])
        let sleeper = bed.sessionSleeper
        let before = sleeper.recorded.count
        let held = makePaths(screenshot: true, shot: shift)
        XCTAssertFalse(held.shiftHeld, "no window yet")
        XCTAssertEqual(held.open(opening(focus: oct7)), .joined)
        XCTAssertTrue(held.shiftHeld, "held from the opening")
        XCTAssertTrue(ScreenPaths.canvasSheetOpen(sheetIsUp: false, accountQuestion: false, saveFailed: false, shiftHeld: held.shiftHeld))
        XCTAssertEqual(fields(held.stateLabel)["hold"], "on")
        await settle()
        XCTAssertEqual(ScreenPaths.shiftHoldCeiling, 60)
        XCTAssertEqual(Array(sleeper.recorded.dropFirst(before)), [60], "the ceiling's one wait")
        XCTAssertEqual(held.open(opening(focus: oct7)), .joined)
        XCTAssertTrue(held.shiftHeld, "a window opened again keeps the hold")
        await settle()
        XCTAssertEqual(Array(sleeper.recorded.dropFirst(before)), [60], "and its one timer")
        held.releaseShift()
        XCTAssertFalse(held.shiftHeld, "span.release")
        XCTAssertFalse(ScreenPaths.canvasSheetOpen(sheetIsUp: false, accountQuestion: false, saveFailed: false, shiftHeld: held.shiftHeld))
        XCTAssertEqual(fields(held.stateLabel)["hold"], "off")
        XCTAssertEqual(held.open(opening(focus: oct7)), .joined)
        XCTAssertFalse(held.shiftHeld, "released once: no window holds again")
        await sleeper.advance()
        await settle()
        XCTAssertFalse(held.shiftHeld, "the cancelled timer does nothing")

        let timed = makePaths(screenshot: true, shot: shift)
        XCTAssertEqual(timed.open(opening(focus: oct7)), .joined)
        XCTAssertTrue(timed.shiftHeld)
        await settle()
        XCTAssertEqual(sleeper.waiting, 1)
        await sleeper.advance()
        await settle()
        XCTAssertFalse(timed.shiftHeld, "the 60 s ceiling released it")
        XCTAssertEqual(timed.open(opening(focus: oct7)), .joined)
        XCTAssertFalse(timed.shiftHeld)

        let plain = makePaths(screenshot: true, shot: try shotConfig(["--screenshot-span", "on"]))
        XCTAssertEqual(plain.open(opening(focus: oct7)), .joined)
        XCTAssertFalse(plain.shiftHeld, "no --screenshot-span-shift")
        let single = makePaths(screenshot: true, shot: try shotConfig(["--screenshot-span", "on", "--screenshot-span-shift", "--screenshot-single-page"]))
        XCTAssertEqual(single.open(opening(focus: oct7)), .onePage)
        XCTAssertFalse(single.shiftHeld, "one page: nothing to shift")
        let normal = makePaths(screenshot: false, shot: shift)
        XCTAssertEqual(normal.open(opening(focus: oct7)), .joined)
        XCTAssertFalse(normal.shiftHeld, "outside screenshot mode the arguments are not read")
        XCTAssertEqual(sleeper.waiting, 0)
        XCTAssertEqual(faults, [])
    }

    // MARK: Screenshot mode's joined pages (§3.12; C3-B1, C3-M4; the plan §4.2–§4.4, §7.3)

    /// §3.12, B_DESIGN.md §5.6: with `--screenshot-span on` screenshot mode opens a week or a day joined (its switch starts on)
    /// and every page of the window is screenshot mode's demo of that page — never the engine's file — the focus page the
    /// one-page demo with its half of the crossing demo, its left neighbour the other half, every id once in the window.
    /// Without the argument (or with `--screenshot-span off`, or the switch turned off) the one page is 1.2.3's demo page;
    /// `--screenshot-single-page` is the one page with the halves the focus page owns (a month: 1.2.3's demo).
    func testScreenshotWindowReadsTheDemoPagesAndTheCrossingDemo() async throws {
        try bed.engine.save(bed.page("w-2026-10-05", ["stored"]))
        let on = try shotConfig(["--screenshot-span", "on"])
        let shot = makePaths(screenshot: true, shot: on)
        XCTAssertTrue(shot.screenshotSpan, "the switch starts with --screenshot-span on")
        XCTAssertEqual(shot.open(opening(focus: oct7)), .joined)
        let week = try XCTUnwrap(shot.span)
        await week.prefetch()
        XCTAssertEqual(week.focusPageId, "w-2026-10-05")
        XCTAssertEqual(week.pageIds, ["w-2026-09-21", "w-2026-09-28", "w-2026-10-05", "w-2026-10-12", "w-2026-10-19"])
        var seen: Set<String> = []
        for id in week.pageIds {
            let page = try XCTUnwrap(week.page(id))
            XCTAssertEqual(Set(page.liveStrokeIds), Set(demo(id, .week, crossing: true).liveStrokeIds), id)
            XCTAssertFalse(page.liveStrokeIds.isEmpty, id)
            XCTAssertTrue(seen.isDisjoint(with: page.liveStrokeIds), "\(id): an id of another page")
            seen.formUnion(page.liveStrokeIds)
        }
        let crossing = ScreenshotMode.crossingDemoStrokeIds(.week)
        let focusIds = Set(try XCTUnwrap(week.page("w-2026-10-05")).liveStrokeIds)
        let oneDemo = ScreenshotMode.demoPage(kind: .week, focus: oct7, grown: false, empty: false, tallYear: false, weekStart: .monday, storeInk: false)
        XCTAssertEqual(focusIds, Set(oneDemo.liveStrokeIds).union(crossing.focus), "the one-page demo and its half")
        XCTAssertFalse(focusIds.contains("stored"), "the engine's file is not read")
        XCTAssertTrue(Set(try XCTUnwrap(week.page("w-2026-09-28")).liveStrokeIds).isSuperset(of: crossing.left), "the left half")

        XCTAssertEqual(shot.open(opening(.day, focus: oct7)), .joined)
        let day = try XCTUnwrap(shot.span)
        await day.prefetch()
        let dayCrossing = ScreenshotMode.crossingDemoStrokeIds(.day)
        XCTAssertTrue(Set(try XCTUnwrap(day.page("d-2026-10-07")).liveStrokeIds).isSuperset(of: dayCrossing.focus))
        XCTAssertTrue(Set(try XCTUnwrap(day.page("d-2026-10-06")).liveStrokeIds).isSuperset(of: dayCrossing.left))
        XCTAssertTrue(Set(try XCTUnwrap(day.page("d-2026-10-08")).liveStrokeIds).isDisjoint(with: dayCrossing.focus + dayCrossing.left))

        // 設定 › ページ off (the screen copies `ScreenshotMode.pageSpan`): 1.2.3's one demo page, no crossing demo.
        shot.screenshotSpan = false
        XCTAssertEqual(shot.open(opening(focus: oct7)), .onePage)
        XCTAssertEqual(Set(shot.onePage.page.liveStrokeIds), Set(oneDemo.liveStrokeIds))
        shot.screenshotSpan = true
        XCTAssertEqual(shot.open(opening(focus: oct7)), .joined)

        for args in [[], ["--screenshot-span", "off"], ["--screenshot-span", "ON"]] {
            let plain = makePaths(screenshot: true, shot: try shotConfig(args))
            XCTAssertFalse(plain.screenshotSpan, "\(args)")
            XCTAssertEqual(plain.open(opening(focus: oct7)), .onePage, "\(args)")
            XCTAssertEqual(Set(plain.onePage.page.liveStrokeIds), Set(oneDemo.liveStrokeIds), "\(args): 1.2.3's demo page")
        }

        let single = makePaths(screenshot: true, shot: try shotConfig(["--screenshot-span", "on", "--screenshot-single-page"]))
        XCTAssertEqual(single.open(opening(focus: oct7)), .onePage)
        XCTAssertEqual(Set(single.onePage.page.liveStrokeIds), Set(demo("w-2026-10-05", .week, crossing: true).liveStrokeIds))
        XCTAssertTrue(Set(single.onePage.page.liveStrokeIds).isSuperset(of: crossing.focus), "its own half")
        XCTAssertTrue(Set(single.onePage.page.liveStrokeIds).isDisjoint(with: crossing.left), "never the left page's")
        XCTAssertEqual(single.open(opening(.day, focus: oct7)), .onePage)
        XCTAssertTrue(Set(single.onePage.page.liveStrokeIds).isSuperset(of: dayCrossing.focus))
        XCTAssertEqual(single.open(opening(.month, focus: oct7)), .onePage)
        let month = ScreenshotMode.demoPage(kind: .month, focus: oct7, grown: false, empty: false, tallYear: false, weekStart: .monday, storeInk: false)
        XCTAssertEqual(Set(single.onePage.page.liveStrokeIds), Set(month.liveStrokeIds), "a month: 1.2.3's demo")
        XCTAssertNil(ScreenPaths.singlePageDemo(on, opening(focus: oct7)), "no --screenshot-single-page")
        XCTAssertNil(ScreenPaths.singlePageDemo(nil, opening(focus: oct7)), "normal use")
        XCTAssertEqual(faults, [])
    }

    /// §3.12, the plan §7.3: `--screenshot-offset-x p` puts the band x `origin(focus) + W/2 + p·W` in the middle of the canvas
    /// (−0.5: the focus page's left boundary; +1, `--screenshot-span-shift`'s opening: the next page's middle), y from
    /// `--screenshot-offset` or 0; without it `--screenshot-offset` gets the focus page's origin; nil without either.
    func testScreenshotOffsetXPutsTheBoundaryInTheMiddle() async throws {
        let session = try await openWindow()
        let origin = try XCTUnwrap(session.origin(ofPage: w1116))
        XCTAssertEqual(origin, 2_800)
        let boundary = try XCTUnwrap(ScreenPaths.shotPaperOffset(layout: session.layout, focusPageId: w1116, pages: -0.5, offset: nil,
                                                                 viewportWidth: 834, zoom: 0.5))
        XCTAssertEqual(boundary.x + 834 / 2 / 0.5, origin, accuracy: 1e-9, "the left boundary in the middle")
        XCTAssertEqual(boundary.y, 0)
        let next = try XCTUnwrap(ScreenPaths.shotPaperOffset(layout: session.layout, focusPageId: w1116, pages: 1, offset: CGPoint(x: 5, y: 30),
                                                             viewportWidth: 834, zoom: 0.5))
        XCTAssertEqual(next.x + 834 / 2 / 0.5, origin + 1_400 + 700, accuracy: 1e-9, "the next page's middle")
        XCTAssertEqual(next.y, 30, "--screenshot-offset's y")
        XCTAssertEqual(ScreenPaths.shotPaperOffset(layout: session.layout, focusPageId: w1116, pages: nil, offset: CGPoint(x: 10, y: 20),
                                                   viewportWidth: 834, zoom: 0.5), CGPoint(x: origin + 10, y: 20))
        XCTAssertEqual(ScreenPaths.shotPaperOffset(layout: session.layout, focusPageId: w1116, pages: .infinity, offset: CGPoint(x: 10, y: 20),
                                                   viewportWidth: 834, zoom: 0.5), CGPoint(x: origin + 10, y: 20))
        XCTAssertNil(ScreenPaths.shotPaperOffset(layout: session.layout, focusPageId: w1116, pages: nil, offset: nil, viewportWidth: 834, zoom: 0.5))
        XCTAssertEqual(ScreenPaths.shotPaperOffset(layout: session.layout, focusPageId: w1116, pages: 0, offset: nil, viewportWidth: 0, zoom: 0)?.x,
                       origin + 700, "before the canvas has a size: the point itself")
        XCTAssertEqual(try shotConfig(["--screenshot-span-shift"]).spanOpeningOffsetX, 1)
        XCTAssertEqual(try shotConfig(["--screenshot-span-shift", "--screenshot-offset-x", "-0.5"]).spanOpeningOffsetX, -0.5)
        XCTAssertNil(try shotConfig(["--screenshot-span", "on"]).spanOpeningOffsetX)
    }

    /// The plan §4.3: `span.state` — shown with the joined pages' arguments only — reads out the path, the window (its id, kind,
    /// focus page, the focus page's origin in the band, its first page and pages, its version), the shifts and stops of
    /// the window, the hold and the newest stroke of the pages on the screen in its own cell (a line across the boundary
    /// keeps its points beyond its page: x < 0 on the page that owns it). The one-page path reads `path=one`.
    func testScreenshotStateReadsTheWindow() async throws {
        let on = try shotConfig(["--screenshot-span", "on"])
        for args in [["--screenshot-span", "on"], ["--screenshot-span", "off"], ["--screenshot-single-page"], ["--screenshot-span-shift"]] {
            XCTAssertTrue(ScreenPaths.reportsState(try shotConfig(args)), "\(args)")
        }
        XCTAssertFalse(ScreenPaths.reportsState(try shotConfig(["--screenshot-probe", "--screenshot-select", "a"])), "1.2.3's arguments")
        XCTAssertFalse(ScreenPaths.reportsState(nil))
        XCTAssertFalse(makePaths(screenshot: false, shot: on).reportsShotState, "outside screenshot mode")

        let shot = makePaths(screenshot: true, shot: on)
        XCTAssertTrue(shot.reportsShotState)
        XCTAssertEqual(shot.open(opening(focus: oct7)), .joined)
        let session = try XCTUnwrap(shot.span)
        await session.prefetch()
        var state = fields(shot.stateLabel)
        XCTAssertEqual(state["path"], "span")
        XCTAssertEqual(state["session"], session.id)
        XCTAssertEqual(state["kind"], "week")
        XCTAssertEqual(state["focus"], "w-2026-10-05")
        XCTAssertEqual(state["origin"], String(format: "%.1f", Double(try XCTUnwrap(session.origin(ofPage: "w-2026-10-05")))))
        XCTAssertEqual(state["origin"], "2800.0")
        XCTAssertEqual(state["first"], "w-2026-09-21")
        XCTAssertEqual(state["pages"], "5")
        XCTAssertEqual(state["version"], "\(session.windowVersion)")
        XCTAssertEqual(state["shifts"], "0")
        XCTAssertEqual(state["stops"], "0")
        XCTAssertEqual(state["hold"], "off")
        XCTAssertNotEqual(state["last"], "-", "the demo strokes")

        // A line from the focus week into the next one, its centre on the boundary: the next week owns it (D15).
        let ledger = JoinedLedgerStandIn(session)
        let boundary = try XCTUnwrap(session.origin(ofPage: "w-2026-10-12"))
        let line = try XCTUnwrap(ledger.draw([CGPoint(x: boundary - 120, y: 900), CGPoint(x: boundary, y: 920), CGPoint(x: boundary + 120, y: 940)]))
        ledger.put()
        session.drainInbox()
        let points = line.points.map(\.x)
        state = fields(shot.stateLabel)
        let last = try XCTUnwrap(state["last"])
        XCTAssertEqual(last, "w-2026-10-12:grid:minx=\(String(format: "%.1f", Double(points.min() ?? 0))):maxx=\(String(format: "%.1f", Double(points.max() ?? 0)))")
        XCTAssertLessThan(try XCTUnwrap(points.min()), 0, "kept beyond the page's left edge")

        _ = shot.stopped(session.stopped(midX: middle(of: session, slots: 1)), focus: oct7, kind: .week, weekStart: .monday, boundary: {})
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex))
        state = fields(shot.stateLabel)
        XCTAssertEqual(state["stops"], "1")
        XCTAssertEqual(state["shifts"], "1")
        XCTAssertEqual(state["focus"], "w-2026-10-12")
        XCTAssertEqual(state["first"], "w-2026-09-28")
        XCTAssertEqual(state["version"], "\(session.windowVersion)")
        XCTAssertEqual(state["session"], session.id, "the same window")

        shot.screenshotSpan = false
        XCTAssertEqual(shot.open(opening(focus: oct7)), .onePage)
        state = fields(shot.stateLabel)
        XCTAssertEqual(state["path"], "one")
        XCTAssertEqual(state["session"], "-")
        XCTAssertEqual(state["kind"], "week")
        XCTAssertEqual(state["focus"], "w-2026-10-05")
        XCTAssertEqual(state["origin"], "0.0")
        XCTAssertEqual(state["pages"], "1")
        XCTAssertEqual(state["shifts"], "0")
        XCTAssertEqual(state["stops"], "0")
        XCTAssertEqual(ScreenPaths.newestStroke(in: []), "-")
        XCTAssertEqual(ScreenPaths.newestStroke(in: [bed.page(w1116, ["a", "b"])]), "\(w1116):grid:minx=140.0:maxx=150.0", "the largest t")
        XCTAssertEqual(faults, [])
    }

    /// §3.12, §3.14, the plan §4.4: `--screenshot-span-guide one|two` is the guide's card of a week or a day with 「指でも書く」
    /// off / on (no value or an unknown one: as it is), `stage-two` stage 2's notice (N-8); nothing without the argument.
    func testScreenshotGuideArguments() throws {
        XCTAssertNil(ScreenPaths.photoGuide(try shotConfig([]), kind: .week, allowFinger: true))
        XCTAssertNil(ScreenPaths.photoGuide(nil, kind: .week, allowFinger: true))
        for kind in [PageKind.week, .day] {
            for finger in [false, true] {
                XCTAssertEqual(ScreenPaths.photoGuide(try shotConfig(["--screenshot-span-guide", "one"]), kind: kind, allowFinger: finger),
                               .card(allowFinger: false), "\(kind)")
                XCTAssertEqual(ScreenPaths.photoGuide(try shotConfig(["--screenshot-span-guide", "two"]), kind: kind, allowFinger: finger),
                               .card(allowFinger: true), "\(kind)")
                XCTAssertEqual(ScreenPaths.photoGuide(try shotConfig(["--screenshot-span-guide"]), kind: kind, allowFinger: finger),
                               .card(allowFinger: finger), "\(kind): no value")
                XCTAssertEqual(ScreenPaths.photoGuide(try shotConfig(["--screenshot-span-guide", "three"]), kind: kind, allowFinger: finger),
                               .card(allowFinger: finger), "\(kind): an unknown value")
            }
        }
        XCTAssertNil(ScreenPaths.photoGuide(try shotConfig(["--screenshot-span-guide", "one"]), kind: .month, allowFinger: false), "no card of a month")
        for kind in PageKind.allCases {
            XCTAssertEqual(ScreenPaths.photoGuide(try shotConfig(["--screenshot-span-guide", "stage-two"]), kind: kind, allowFinger: false),
                           .stageTwoNotice, "\(kind)")
        }
    }

    /// The View's lines of screenshot mode's joined pages that no screen-free test runs (C3-M3: not claimed as "fails when
    /// removed"; read here from the source so a lost wire shows): the settings at 「ページ」, the hold passed to the canvas,
    /// the band's opening offset, the two elements, the switch's memory, the guide's photo and N-8. The one page keeps
    /// 1.2.3's `initialPaperOffset`.
    func testScreenPassesTheScreenshotArguments() throws {
        let url = Self.repository.appendingPathComponent("Sources/TegakiCalendar/Views/CalendarRootScreen.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        for wire in [
            "scrollToPageOnAppear: ScreenshotMode.current?.settingsSection == .page",
            "saveFailed: saveError != nil, shiftHeld: paths.shiftHeld)",
            "pages: ScreenshotMode.current?.spanOpeningOffsetX,",
            "offset: ScreenshotMode.current?.offset, viewportWidth: viewportWidth, zoom: zoom),",
            ".overlay(alignment: .topLeading) { spanShotElements }",
            "if paths.reportsShotState {",
            ".accessibilityIdentifier(ScreenPaths.stateIdentifier)",
            ".accessibilityLabel(paths.stateLabel)",
            ".accessibilityIdentifier(ScreenPaths.releaseIdentifier)",
            ".onTapGesture { paths.releaseShift() }",
            "if ScreenshotMode.isActive { paths.screenshotSpan = ScreenshotMode.pageSpan }",
            "guide.showForPhoto(kind, allowFinger: finger)",
            "showToast(SpanGuide.stageTwoNotice, duration: Self.screenshotReadOnlyToastDuration)",
            "initialPaperOffset: ScreenshotMode.current?.offset,",
        ] {
            XCTAssertTrue(source.contains(wire), wire)
        }
        XCTAssertEqual(ScreenPaths.stateIdentifier, "span.state")
        XCTAssertEqual(ScreenPaths.releaseIdentifier, "span.release")
    }

    /// 1.2.3's 「手書きを保存できませんでした」 on the joined path: one notice while it is up, whichever windows failed (the one on
    /// the screen and a closing one); after it closed, the next failure tells again.
    func testSaveFailureShowsOneNotice() async throws {
        let session = try await openWindow()
        let ledger = JoinedLedgerStandIn(session)
        ledger.draw(on: w1102)
        ledger.draw(on: w1130)
        ledger.put()
        try bed.failSaves(of: w1102)
        try bed.failSaves(of: w1130)
        var notices = 0
        paths.onSaveFailed = { _ in notices += 1 }
        XCTAssertEqual(Set(paths.saveCurrent()), [w1102, w1130])
        XCTAssertEqual(notices, 1)
        try await openWindow() // the failing window closes (its save fails again)
        XCTAssertEqual(paths.closing.count, 1)
        paths.saveCurrent()
        XCTAssertEqual(notices, 1, "one notice while it is up")
        paths.saveFailureNoticeClosed()
        paths.saveCurrent()
        XCTAssertEqual(notices, 2)
        bed.allowSaves(of: w1102)
        bed.allowSaves(of: w1130)
    }

    /// `--screenshot-select` on the joined path selects the focus page's strokes by their window names.
    func testInitialSelectionIsInWindowNames() {
        XCTAssertEqual(ScreenPaths.windowSelection(["a", "b"], focusPageId: w1116), ["\(w1116)|a", "\(w1116)|b"])
        XCTAssertEqual(ScreenPaths.windowSelection([], focusPageId: w1116), [])
    }

    // MARK: The lead's decisions C3-m5, C3-m7, C3-m8

    /// C3-m5: the 30 s tick moves the now line when any page of the window has it (today on the page next to the focus), not
    /// only the focus page; a window without today composes nothing unless the day changed.
    func testNowLineGateLooksAtEveryPage() async throws {
        let session = try await openWindow(opening(now: try at(11, 25, 10)))
        let focusPage = session.layout.pages[session.focusSlot]
        XCTAssertNil(focusPage.nowLine, "today is on 11/23's page, not the focus")
        XCTAssertTrue(ScreenPaths.nowLineTickDue(dayChanged: false, window: session.layout))
        let version = session.windowVersion
        XCTAssertTrue(paths.nowTicked(try at(11, 25, 10, 30), dayChanged: false))
        XCTAssertGreaterThan(session.windowVersion, version)
        XCTAssertEqual(session.layout.pages.compactMap(\.nowLine).map(\.minute), [630])

        let far = try await openWindow(opening(focus: DayKey(year: 2027, month: 1, day: 11), now: try at(11, 25, 10)))
        let farVersion = far.windowVersion
        XCTAssertFalse(ScreenPaths.nowLineTickDue(dayChanged: false, window: far.layout))
        XCTAssertFalse(paths.nowTicked(try at(11, 25, 11), dayChanged: false))
        XCTAssertEqual(far.windowVersion, farVersion)
        XCTAssertTrue(paths.nowTicked(try at(11, 26, 0, 1), dayChanged: true))
        XCTAssertGreaterThan(far.windowVersion, farVersion)
    }

    /// C3-m8: the model's revision moves at the end of every `reload()` (also one that returns early); the window reads its
    /// events again only when the revision rose after its opening's read.
    func testEventsRevisionReadsTheWindowOnceAfterTheOpening() async throws {
        let model = EventStoreModel(defaults: scratch)
        let first = model.revision
        model.reload() // no page loaded: returns early
        XCTAssertEqual(model.revision, first + 1)

        var queries = 0
        paths.eventSource = { _, _ in
            queries += 1
            return []
        }
        try await openWindow()
        XCTAssertEqual(queries, 5)
        paths.eventsRead(revision: 7)
        queries = 0
        paths.eventsChanged(revision: 7)
        XCTAssertEqual(queries, 0, "the opening's own read")
        paths.eventsChanged(revision: 8)
        XCTAssertEqual(queries, 5, "the calendar changed: every page again")
        paths.eventsChanged(revision: 8)
        XCTAssertEqual(queries, 5)
    }

    /// C3-m7: a stop that ends a visit is a boundary as `show` is: the window is saved, then the week start's boundary runs; a
    /// stop on the same page is not.
    func testWeekStartBoundaryRunsWhenAVisitEnds() async throws {
        let session = try await openWindow()
        let ledger = JoinedLedgerStandIn(session)
        ledger.draw(on: w1123)
        ledger.put()
        var order: [String] = []
        session.willPersist = { order.append("persist \($0)") }
        _ = paths.stopped(session.stopped(midX: middle(of: session)), focus: nov18, kind: .week, weekStart: .monday,
                          focusMoved: { order.append("focus \($0)") }, boundary: { order.append("boundary") })
        XCTAssertEqual(order, ["focus 2026-11-18"])
        order = []
        _ = paths.stopped(session.stopped(midX: middle(of: session, slots: 1)), focus: nov18, kind: .week, weekStart: .monday,
                          focusMoved: { order.append("focus \($0)") }, boundary: { order.append("boundary") })
        XCTAssertEqual(order, ["focus 2026-11-25", "persist \(w1123)", "boundary"])
    }

    /// C3-m7: the screen's focus follows the window's focus page keeping its weekday (a week moves by whole weeks; a day is the
    /// day), whatever the week start.
    func testFocusFollowsTheWindowKeepingTheWeekday() {
        XCTAssertEqual(ScreenPaths.focus(nov18, kind: .week, weekStart: .monday, movedTo: DayKey(year: 2026, month: 11, day: 23)),
                       DayKey(year: 2026, month: 11, day: 25))
        XCTAssertEqual(ScreenPaths.focus(nov18, kind: .week, weekStart: .monday, movedTo: nov16), nov18, "the same page")
        XCTAssertEqual(ScreenPaths.focus(nov18, kind: .week, weekStart: .monday, movedTo: DayKey(year: 2026, month: 11, day: 2)),
                       DayKey(year: 2026, month: 11, day: 4))
        XCTAssertEqual(ScreenPaths.focus(nov18, kind: .week, weekStart: .sunday, movedTo: DayKey(year: 2026, month: 11, day: 22)),
                       DayKey(year: 2026, month: 11, day: 25))
        XCTAssertEqual(ScreenPaths.focus(nov16, kind: .day, weekStart: .monday, movedTo: nov18), nov18)
    }
}
