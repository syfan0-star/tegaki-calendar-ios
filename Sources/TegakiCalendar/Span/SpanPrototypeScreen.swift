#if SPAN_PROTOTYPE
import Combine
import Holidays
import InkModel
import Layout
import SwiftUI
import UIKit

// The prototype's screen (1.3, docs/M7C_CONTRACT.md §4.6, D12, D13): the last row 「横につなげる試作」
// of 設定 › 情報 (`SpanPrototypeEntryRow`, only in the prototype build) opens a sample band of weeks
// (Monday first by default) around this week — or of days (試作の設定 › 表示の切替: §4.5's photos of the day band and
// §4.6's widest window, iPhone landscape's 15 days) — the window `SpanPlan` gives the device class and the
// orientation of the screen, on the prototype's copies of the canvas and the ledger, with the day headings and the
// all-day band of each page over it (§3.8: the lanes packed over the window's days). What is written
// there goes to "proto-<id>" pages in a folder of the prototype's own (`SpanPrototypeEnvironment`),
// through an engine that is never started, and the folder is removed when the screen closes. Compiled
// only into the prototype build (`SPAN_PROTOTYPE`); it goes away with the prototype (S6).
// The band moves as §3.6 says (the canvas shifts the window at rest, flings to the next week, ◀ ▶ slide one
// week, the palm's rule holds the pan), and the title follows the focus week (the page under the middle of
// the screen, with the 6 % hysteresis). 「線の数」 fills the prototype's pages with synthetic strokes, and the
// measurements of §4.6 stand in a corner of the band (`SpanPrototypeMeter`, `SpanPrototypeHUD`). Every week
// has its memo below 24:00 (`SpanPrototypeWeekMemoLayout`, §5.2), in one of the two forms of §4.5. The first-time
// guide card is shown as the real one will be (§3.14, §8.1 N-4 / N-5): at the top of the paper, 8 seconds, gone
// at a touch (`SpanPrototypeGuideCard`).

// MARK: - The row in 設定 › 情報

/// 「横につなげる試作」: the last row of 設定 › 情報 in the prototype build. Opens the prototype over the
/// whole screen (it is a canvas, not a form). With `--screenshot-prototype <scene>` (the CI's sample images,
/// `SpanPrototypeShot`) it opens it by itself, once, a moment after the row is on screen, in that scene.
struct SpanPrototypeEntryRow: View {
    @State private var isOpen = false

    var body: some View {
        Button(L.text("prototype.span.entry")) { isOpen = true }
            .fullScreenCover(isPresented: $isOpen) {
                if let scene = SpanPrototypeShot.current {
                    SpanPrototypeScreen(onClose: { isOpen = false }, weekStart: scene.weekStart, now: SpanPrototypeShot.now,
                                        scene: scene)
                } else {
                    SpanPrototypeScreen(onClose: { isOpen = false })
                }
            }
            .task {
                guard SpanPrototypeShot.current != nil, !SpanPrototypeShot.opened else { return }
                await SpanPrototypeShot.waitForOrientation()
                // The settings sheet has just scrolled to 情報 (`--screenshot-sheet info`): let it come to rest.
                try? await Task.sleep(for: .seconds(0.6))
                guard !Task.isCancelled, !SpanPrototypeShot.opened else { return }
                SpanPrototypeShot.opened = true
                isOpen = true
            }
    }
}

// MARK: - Model

/// The prototype while its screen is open: its isolated environment (made by the screen, never the
/// app's), and the session, made once the screen knows its size (the device class and the orientation
/// pick the window, §3.6) and composed again when they change — at once when no canvas holds a stroke back,
/// else once the canvas is free (`rebuild`, review ISO-3). The toggles of §4.6 and §4.5 live here:
/// 「線の数」 (filled again when the window's page count changes or it moves past the pages filled, reviews B1,
/// B1-R), iPhone landscape's 「今のまま」 /
/// 「上限あり」, 「1 ページずつ」, the week start and the kind (week or day; each a new session, K-11).
/// `close()` saves, closes and removes the prototype's folder.
@MainActor
final class SpanPrototypeModel: ObservableObject {
    /// 「上限あり」 (P-B6 イ, B_DESIGN.md §3.1, §6.2): at most this many weeks across on an iPhone in landscape.
    static let cappedVisiblePages: CGFloat = 3

    let environment: SpanPrototypeEnvironment
    @Published private(set) var weekStart: WeekStart
    /// The band's pages: weeks (the default, §4.6) or days.
    @Published private(set) var kind: PageKind
    let now: Date
    let holidays: HolidayCalendar
    let events: [LayoutEvent]
    @Published private(set) var session: SpanPrototypeSession?
    /// The page number under the middle of the screen as the canvas last reported it (§3.6; the title). nil:
    /// the session's focus (the window's middle page).
    @Published private(set) var focusIndex: Int?
    /// The measurements of this opening (§4.6), started and stopped by the screen.
    let meter = SpanPrototypeMeter()
    /// 「線の数」: the synthetic strokes of the window (0: only what was written in the prototype).
    @Published private(set) var strokeTotal = 0
    /// While 「線の数」 writes the pages: how far it got (the band is taken away meanwhile).
    @Published private(set) var fillProgress: SpanPrototypeSession.FillProgress?
    /// The measurements stand in a corner of the band.
    @Published var showsMeasurements = true
    /// iPhone in landscape: false 「今のまま」 (P-B6 ア, the default: the lowest zoom shows the 24 hours), true
    /// 「上限あり」 (P-B6 イ: at most `cappedVisiblePages` weeks across, a smaller window).
    @Published private(set) var landscapeCap = false
    /// 「1 ページずつ」: the focus week alone on the 1.2.3 canvas, as an old version shows the same page (§4.5).
    @Published private(set) var singlePage = false
    /// The week memo's form (§4.5: 罫線だけ, the default, or 方眼).
    @Published var memoStyle: SpanPrototypeMemoStyle = .ruled
    private(set) var isClosed = false
    /// The last size `screenChanged` was told of (a size that came while 「線の数」 wrote is taken after it).
    private var lastScreen: (size: CGSize, isPad: Bool)?
    /// The number of the next session's virtual id (a new week start is a new session, K-11).
    private var nextNumber = 1
    /// The sample image this screen was opened for (`--screenshot-prototype`); nil in use.
    let scene: SpanPrototypeShot.Scene?
    /// Where the band's canvas reports its offset and zoom, for the day headings (`SpanPrototypeHeader`). Not
    /// published here: only the headings follow the scroll.
    let viewport = SpanPrototypeViewport()

    /// A window to compose again outside a shift, waiting for the canvas (`rebuild`): the focus (nil: the
    /// canvas's), the plan (nil: the same) and the radius override (nil: the same; `.some(nil)`: the plan's).
    private struct Rebuild {
        var focusIndex: Int?
        var plan: SpanPlan?
        var radius: Int??
    }

    private var waitingRebuild: Rebuild?

    /// `scene` (the sample images, `SpanPrototypeShot`): the scene's sample strokes are written into the
    /// environment's folder before the first session reads it, the measurements are hidden, and the toggles start
    /// as the scene says (「上限あり」, 「1 ページずつ」 on this week or the next, the memo's form).
    init(environment: SpanPrototypeEnvironment, weekStart: WeekStart, now: Date, holidays: HolidayCalendar, events: [LayoutEvent],
         scene: SpanPrototypeShot.Scene? = nil, kind: PageKind = .week) {
        self.environment = environment
        self.weekStart = weekStart
        self.kind = (scene?.kind ?? kind) == .day ? .day : .week
        self.now = now
        self.holidays = holidays
        self.events = events
        self.scene = scene
        if let scene {
            SpanPrototypeShot.seed(environment, kind: self.kind, weekStart: weekStart, today: DayKey(now))
            showsMeasurements = false
            landscapeCap = scene.landscapeCap
            memoStyle = scene.memoStyle
            if scene.singlePage {
                let plan = SpanPlan(kind: self.kind, weekStart: weekStart, deviceClass: .iPad11, orientation: .portrait)
                focusIndex = plan.index(containing: DayKey(now)) + scene.pageOffset
                singlePage = true
            }
        }
    }

    /// The device class and the orientation of a screen of `size` (pt).
    static func device(for size: CGSize, isPad: Bool) -> (deviceClass: SpanDeviceClass, orientation: SpanOrientation) {
        (SpanDeviceClass(screen: size, isPad: isPad), SpanOrientation(screen: size))
    }

    /// 「上限あり」 is in force: on, on an iPhone in landscape.
    func capsLandscape(_ plan: SpanPlan) -> Bool {
        landscapeCap && plan.deviceClass == .iPhone && plan.orientation == .landscape
    }

    /// The window's radius for `plan`: 「上限あり」's (`SpanPlan.radius` of `cappedVisiblePages`), else the plan's (nil).
    func radiusOverride(for plan: SpanPlan) -> Int? {
        capsLandscape(plan) ? SpanPlan.radius(forVisiblePages: Self.cappedVisiblePages) : nil
    }

    /// The most pages across the lowest zoom may show (`SpanPrototypeCanvas.maxVisiblePages`): 「上限あり」's, else nil.
    var maxVisiblePages: CGFloat? {
        guard let session, capsLandscape(session.plan) else { return nil }
        return Self.cappedVisiblePages
    }

    /// A new session around `focus` for the device of the last size, with the model's week start and kind. A
    /// rebuild that waited for the old session's canvas is dropped (the new one is made for the screen as it is).
    private func makeSession(focus: DayKey, device: (deviceClass: SpanDeviceClass, orientation: SpanOrientation)) -> SpanPrototypeSession {
        let plan = SpanPlan(kind: kind, weekStart: weekStart, deviceClass: device.deviceClass, orientation: device.orientation)
        let number = nextNumber
        nextNumber += 1
        waitingRebuild = nil
        let made = SpanPrototypeSession(sync: environment.sync, weekStart: weekStart, focus: focus,
                                        deviceClass: device.deviceClass, orientation: device.orientation,
                                        now: now, holidays: holidays, events: events, number: number,
                                        radius: radiusOverride(for: plan), kind: kind, meter: meter, filled: environment.filled)
        made.inbox.onCanvasLeft = { [weak self, weak made] in
            guard let self, let made, self.session === made else { return }
            self.runWaitingRebuild(focusIndex: nil)
        }
        return made
    }

    /// The plan and the radius override the window has once a waiting rebuild is done (the session's when none
    /// waits).
    private func target(_ session: SpanPrototypeSession) -> (plan: SpanPlan, radius: Int?) {
        var radius = session.radiusOverride
        if let waiting = waitingRebuild, let next = waiting.radius {
            radius = next
        }
        return (waitingRebuild?.plan ?? session.plan, radius)
    }

    /// The window composed again outside a shift (§3.6: a rotation, 「上限あり」, 「1 ページずつ」). While the canvas may
    /// hold a stroke the inbox has not got (`SpanPrototypeInbox.canvasBusy`) it waits — merged with any rebuild
    /// already waiting — and the canvas takes it when it is free (`runWaitingRebuild`), or the next turn after the
    /// canvas goes; otherwise it is done now. Review ISO-3: composed under the pen, the window lacked the stroke
    /// being written, which the canvas then stopped drawing (its ↶ step did nothing) or lost with its page.
    private func rebuild(focusIndex: Int?, plan: SpanPlan?, radius: Int??) {
        guard let session else { return }
        var request = waitingRebuild ?? Rebuild(focusIndex: nil, plan: nil, radius: nil)
        if let focusIndex { request.focusIndex = focusIndex }
        if let plan { request.plan = plan }
        if let radius { request.radius = .some(radius) }
        waitingRebuild = request
        if session.inbox.canvasBusy?() == true {
            session.inbox.rebuildWaiting = true
            session.inbox.onRebuildWaiting?()
            return
        }
        runWaitingRebuild(focusIndex: nil)
    }

    /// Composes the waiting rebuild now around its focus, else `focusIndex` (the canvas's), else the session's; nil
    /// when none waits or a page that leaves could not be saved. Then 「線の数」 fills the pages of a window of another
    /// page count again, measuring afresh (`fillIfNeeded`).
    @discardableResult
    func runWaitingRebuild(focusIndex: Int?) -> SpanPrototypeWindowState? {
        guard let request = waitingRebuild, let session, !isClosed else { return nil }
        waitingRebuild = nil
        session.inbox.rebuildWaiting = false
        guard !session.isFilling else { return nil }
        guard session.rebuildWindow(focusIndex: request.focusIndex ?? focusIndex, plan: request.plan, radius: request.radius) else { return nil }
        fillIfNeeded(resetsMeter: true)
        return session.windowState
    }

    /// Reviews B1, B1-R: 「線の数」 wrote `strokeTotal` ÷ the window's pages on each page of the window and of one radius
    /// beyond each side (`SpanPrototypeFilledPages`). A window with a page that lacks that set holds another total:
    /// another page count (a rotation, 「上限あり」: iPhone portrait's 25,000 turned into 45,000 in landscape), a page
    /// more than one radius past where the fill was (moving sideways, ◀ ▶ of 「1 ページずつ」: on an 11-inch iPad in
    /// portrait 25,000 turned into 20,000 three weeks on, and into 0 seven weeks on), or a session of another week
    /// start or kind (a page that still holds an earlier choice, 0 included). The pages that lack it are written,
    /// the band taken away meanwhile, so the window holds the chosen number. `resetsMeter`: a window of another page
    /// count measures afresh; one that only moved keeps what was measured with the same choice.
    private func fillIfNeeded(resetsMeter: Bool) {
        guard fillProgress == nil, let session, !session.isFilling, session.windowNeedsFill(total: strokeTotal) else { return }
        startFill(resetsMeter: resetsMeter)
    }

    /// The first size makes the session around this week; a size of another device class or orientation
    /// composes its window again (`rebuildWindow`, which saves the pages that leave first), with the radius
    /// of 「上限あり」 when it is in force.
    func screenChanged(_ size: CGSize, isPad: Bool) {
        guard !isClosed, size.width > 0, size.height > 0 else { return }
        lastScreen = (size, isPad)
        let device = Self.device(for: size, isPad: isPad)
        guard let session else {
            let made = makeSession(focus: DayKey(now), device: device)
            session = made
            if let scene {
                SpanPrototypeShot.log("scene=\(scene.rawValue) device=\(device.deviceClass.rawValue) orientation=\(device.orientation.rawValue) "
                                      + "size=\(Int(size.width))x\(Int(size.height)) window=\(made.pageIds.first ?? "")…\(made.pageIds.last ?? "") "
                                      + "focus=\(made.plan.pageId(at: focusPageIndex ?? made.focusIndex)) strokes=\(made.windowStrokeCount)")
            }
            return
        }
        guard !session.isFilling else { return }
        let plan = SpanPlan(kind: kind, weekStart: weekStart, deviceClass: device.deviceClass, orientation: device.orientation)
        let radius = radiusOverride(for: plan)
        let target = target(session)
        guard plan != target.plan || radius != target.radius else { return }
        rebuild(focusIndex: nil, plan: plan, radius: .some(radius))
    }

    /// The focus week the title shows: the canvas's, else the session's.
    var focusPageIndex: Int? {
        guard let session else { return nil }
        return focusIndex ?? session.focusIndex
    }

    /// The canvas found another page under the middle of the screen (§3.6).
    func focusChanged(_ index: Int) {
        guard !isClosed else { return }
        focusIndex = index
    }

    /// §3.6: the canvas is at rest away from the window's middle page — the session composes the window around
    /// it (nil when it could not: a page that leaves was not saved). A window that came to a page 「線の数」 has not
    /// reached is filled after the canvas took it (`fillIfNeeded`, review B1-R; the measurements stay).
    func shift(toFocusIndex index: Int) -> SpanPrototypeWindowState? {
        guard !isClosed, let state = session?.shift(toFocusIndex: index) else { return nil }
        fillIfNeeded(resetsMeter: false)
        return state
    }

    /// 「線の数」 (§4.6 ④): the band is taken away (its last deltas reach the session), then the session fills
    /// the pages with `total` synthetic strokes over the window (0: takes them out) and reads the window again;
    /// the measurements start afresh. Nothing while it is filling.
    func setStrokeTotal(_ total: Int) {
        guard !isClosed, let session, fillProgress == nil, !session.isFilling, total != strokeTotal else { return }
        strokeTotal = total
        startFill(resetsMeter: true)
    }

    /// Writes `strokeTotal` over the window's pages of the session (`setStrokeTotal`, and `fillIfNeeded`: a new week
    /// start or kind, a window of another page count, a window that moved past the pages filled). `resetsMeter`:
    /// the measurements start afresh.
    private func startFill(resetsMeter: Bool) {
        if resetsMeter {
            meter.reset()
        }
        fillProgress = SpanPrototypeSession.FillProgress(done: 0, total: 0)
        let total = strokeTotal
        Task { @MainActor [weak self] in
            // A moment for SwiftUI to take the band away (its canvas hands its last deltas to the inbox).
            try? await Task.sleep(for: .milliseconds(100))
            guard let self, !self.isClosed, let session = self.session else { return }
            await session.fill(windowTotal: total) { [weak self] progress in
                self?.fillProgress = progress
            }
            self.focusIndex = nil
            self.fillProgress = nil
            if let screen = self.lastScreen {
                self.screenChanged(screen.size, isPad: screen.isPad)
            }
        }
    }

    /// iPhone in landscape: 「今のまま」 (false) or 「上限あり」 (true). The window is composed again with its
    /// radius; the canvas takes the new lowest zoom (`maxVisiblePages`).
    func setLandscapeCap(_ on: Bool) {
        guard !isClosed, on != landscapeCap else { return }
        landscapeCap = on
        guard let session, !session.isFilling else { return }
        rebuild(focusIndex: focusPageIndex, plan: nil, radius: .some(radiusOverride(for: target(session).plan)))
    }

    /// 「1 ページずつ」 on or off. On, the window is composed around the focus week (the page shown); off, the
    /// band is made anew with that week in the middle.
    func setSinglePage(_ on: Bool) {
        guard !isClosed, on != singlePage else { return }
        if on, let session, !session.isFilling, let focus = focusPageIndex {
            rebuild(focusIndex: focus, plan: nil, radius: nil)
            focusIndex = focus
        }
        singlePage = on
    }

    /// ◀ ▶ while 「1 ページずつ」 is on: the week before or after, the window composed around it (and filled when it
    /// came to a page 「線の数」 has not reached, review B1-R).
    func stepSinglePage(_ pages: Int) {
        guard !isClosed, let session, !session.isFilling, let focus = focusPageIndex else { return }
        let next = focus + pages
        guard session.rebuildWindow(focusIndex: next) else { return }
        focusIndex = next
        fillIfNeeded(resetsMeter: false)
    }

    /// The week start (K-11: a window never mixes the two shapes): the session is saved and closed, a new one
    /// opens around the same day with the other shape (the prototype's pages of that shape; what was written
    /// in the other one stays in its pages), and 「線の数」 fills its pages that lack the chosen set (`fillIfNeeded`:
    /// with 0, those that still hold an earlier choice).
    func setWeekStart(_ start: WeekStart) {
        guard !isClosed, start != weekStart, fillProgress == nil, let old = session, !old.isFilling,
              let screen = lastScreen else { return }
        let day = old.plan.firstDay(at: focusPageIndex ?? old.focusIndex)
        old.close()
        weekStart = start
        focusIndex = nil
        meter.reset()
        session = makeSession(focus: day, device: Self.device(for: screen.size, isPad: screen.isPad))
        fillIfNeeded(resetsMeter: true)
    }

    /// Weeks or days (K-11: a window never mixes kinds): the session is saved and closed, a new one opens with the
    /// other kind — on the focus day, or on today when the focus week holds it, or on the focus week's first day —
    /// and 「線の数」 fills its pages that lack the chosen set (`fillIfNeeded`). 「1 ページずつ」 goes off.
    func setKind(_ newKind: PageKind) {
        let next: PageKind = newKind == .day ? .day : .week
        guard !isClosed, next != kind, fillProgress == nil, let old = session, !old.isFilling,
              let screen = lastScreen else { return }
        let focus = focusPageIndex ?? old.focusIndex
        var day = old.plan.firstDay(at: focus)
        let today = DayKey(now)
        if old.plan.kind == .week, old.plan.index(containing: today) == focus {
            day = today
        }
        old.close()
        kind = next
        singlePage = false
        focusIndex = nil
        meter.reset()
        session = makeSession(focus: day, device: Self.device(for: screen.size, isPad: screen.isPad))
        fillIfNeeded(resetsMeter: true)
    }

    /// Saves what is waiting (the app went to the background, the pen rests).
    func saveNow() {
        session?.saveAll()
    }

    /// Saves, closes the session and removes the prototype's folder. Once.
    func close() {
        guard !isClosed else { return }
        isClosed = true
        meter.stop()
        session?.close()
        environment.discard()
    }
}

// MARK: - Screen

/// The prototype's screen: a bar (close, the focus week's title, pen and eraser, ↶ ↷, 「指でも書く」) and
/// the band of weeks.
struct SpanPrototypeScreen: View {
    var onClose: () -> Void

    @StateObject private var model: SpanPrototypeModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var tool: CanvasTool = .ink(InkPresets.defaultPen)
    /// iPhone writes with a finger by default, an iPad with the Pencil (as the app's first launch).
    @State private var allowFinger = UIDevice.current.userInterfaceIdiom != .pad
    @State private var undoTrigger = 0
    @State private var redoTrigger = 0
    @State private var canUndo = false
    @State private var canRedo = false
    /// ◀ ▶ (§3.6): the direction of the last press and a counter the canvas reacts to.
    @State private var pageStep = 0
    @State private var pageStepTrigger = 0
    /// The guide card is up (a new value each time it is shown; its 8 s count from then).
    @State private var guideShown: Int?
    /// The all-day band's lane height is computed at this zoom while a pinch runs (M4C-27, as the calendar screen
    /// does); nil: the canvas's zoom.
    @State private var frozenLaneZoom: CGFloat?

    /// `environment` nil is the prototype's own (`SpanPrototypeEnvironment.makeIsolated()`, made once, when
    /// the screen first appears); the events are the screenshot mode's sample events of this month
    /// (EventKit is never read). `scene`: the sample image to open as (`SpanPrototypeShot`; the guide card then
    /// shows only in its own scene, and stays there).
    @MainActor
    init(onClose: @escaping () -> Void, weekStart: WeekStart = .monday, now: Date = Date(),
         environment: SpanPrototypeEnvironment? = nil, scene: SpanPrototypeShot.Scene? = nil) {
        self.onClose = onClose
        let today = DayKey(now)
        _model = StateObject(wrappedValue: SpanPrototypeModel(
            environment: environment ?? SpanPrototypeEnvironment.makeIsolated(),
            weekStart: weekStart,
            now: now,
            holidays: HolidayChoice.current,
            events: ScreenshotMode.demoEvents(for: YearMonth(year: today.year, month: today.month), empty: false,
                                              language: L.language, storeInk: false),
            scene: scene
        ))
        _guideShown = State(initialValue: scene == nil || scene?.showsGuide == true ? 1 : nil)
    }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                bar
                Text(model.kind == .day ? L.text("prototype.span.note.day") : L.text("prototype.span.note"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                Divider()
                if model.fillProgress == nil, let session = model.session {
                    SpanPrototypeHeader(session: session, singlePageIndex: model.singlePage ? model.focusPageIndex : nil,
                                        viewport: model.viewport)
                }
                GeometryReader { area in
                    VStack(spacing: 0) {
                        // §3.8: the all-day band of each page under the headings (review B2: the photos showed no
                        // all-day event, the family trip across the boundary of 10/11 | 10/12 included).
                        if model.fillProgress == nil, let session = model.session {
                            SpanPrototypeAllDayBand(session: session, singlePageIndex: model.singlePage ? model.focusPageIndex : nil,
                                                    viewport: model.viewport, pageHeight: area.size.height, laneZoom: frozenLaneZoom)
                        }
                        ZStack(alignment: .bottomLeading) {
                            content
                            if model.showsMeasurements {
                                SpanPrototypeHUD(meter: model.meter)
                            }
                        }
                        .overlay(alignment: .top) {
                            if let shown = guideShown, !model.singlePage, model.fillProgress == nil {
                                SpanPrototypeGuideCard(text: guideText, onDismiss: hideGuide)
                                    .task(id: shown) {
                                        // The guide's sample image keeps it (`SpanPrototypeShot.Scene.guide`).
                                        guard model.scene == nil else { return }
                                        try? await Task.sleep(for: .seconds(SpanPrototypeGuideCard.duration))
                                        if guideShown == shown { guideShown = nil }
                                    }
                            }
                        }
                    }
                }
            }
            .onAppear { model.screenChanged(proxy.size, isPad: isPad) }
            .onChange(of: proxy.size) { model.screenChanged(proxy.size, isPad: isPad) }
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear { model.meter.start() }
        .onChange(of: scenePhase) {
            if scenePhase != .active { model.saveNow() }
        }
        .onDisappear { model.close() }
    }

    /// The band, or the progress of 「線の数」 while it writes the pages.
    @ViewBuilder
    private var content: some View {
        if let progress = model.fillProgress {
            VStack(spacing: 12) {
                ProgressView(value: Double(progress.done), total: Double(max(1, progress.total)))
                    .frame(maxWidth: 320)
                Text(L.format("prototype.span.preparing", L.count(progress.done), L.count(progress.total)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: InkCanvasContainerView.deskColor))
        } else if model.singlePage, let session = model.session, let focus = model.focusPageIndex {
            SpanPrototypeSinglePageView(session: session, index: focus, allowFinger: allowFinger, viewport: model.viewport)
        } else if let session = model.session {
            SpanPrototypeWindowView(
                session: session,
                model: model,
                tool: tool,
                allowFinger: allowFinger,
                undoTrigger: undoTrigger,
                redoTrigger: redoTrigger,
                pageStep: pageStep,
                pageStepTrigger: pageStepTrigger,
                onHistoryChanged: { undo, redo in
                    canUndo = undo
                    canRedo = redo
                },
                onTouch: hideGuide,
                onZoomingChange: { zooming in
                    frozenLaneZoom = zooming ? model.viewport.value.zoom : nil
                }
            )
        } else {
            Color(uiColor: InkCanvasContainerView.deskColor)
        }
    }

    private var title: String {
        guard let session = model.session, let focus = model.focusPageIndex else { return L.text("prototype.span.entry") }
        return PageNavigation.title(session.plan.kind, focus: session.plan.firstDay(at: focus), holidays: model.holidays, language: L.language,
                                    weekStart: session.weekStart)
    }

    /// The guide's fixed text (§8.1 N-4 / N-5 for the week, N-6 / N-7 for the day).
    private var guideText: String {
        switch (model.kind == .day, allowFinger) {
        case (true, true): return L.text("prototype.span.guide.day.finger")
        case (true, false): return L.text("prototype.span.guide.day.pencil")
        case (false, true): return L.text("prototype.span.guide.week.finger")
        case (false, false): return L.text("prototype.span.guide.week.pencil")
        }
    }

    /// The guide card goes (a touch on it or on the paper, a drag of the band). Nothing when it is not up (every
    /// pen down comes here).
    private func hideGuide() {
        if guideShown != nil {
            guideShown = nil
        }
    }

    /// ◀ ▶: one week back or on (§3.6); with 「1 ページずつ」 the week shown.
    private func step(_ pages: Int) {
        if model.singlePage {
            model.stepSinglePage(pages)
            return
        }
        pageStep = pages
        pageStepTrigger += 1
    }

    private var bar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                Button(L.text("prototype.span.close")) {
                    model.close()
                    onClose()
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(L.text("prototype.span.entry"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 8)
                Button {
                    step(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel(model.kind == .day ? L.text("header.previous.day") : L.text("header.previous.week"))
                Button {
                    step(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel(model.kind == .day ? L.text("header.next.day") : L.text("header.next.week"))
            }
            tools
        }
        .font(.title3)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// Pen, eraser, ↶ ↷ and 「指でも書く」.
    private var tools: some View {
        HStack(spacing: 16) {
            Button {
                tool = .ink(InkPresets.defaultPen)
            } label: {
                Image(systemName: tool.isEraser ? "pencil" : "pencil.circle.fill")
            }
            .accessibilityLabel(L.text("toolbar.tool.pen"))
            Button {
                tool = .eraser
            } label: {
                Image(systemName: tool.isEraser ? "eraser.fill" : "eraser")
            }
            .accessibilityLabel(L.text("toolbar.tool.eraser"))
            Button {
                undoTrigger += 1
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!canUndo)
            .accessibilityLabel(L.text("toolbar.undo"))
            Button {
                redoTrigger += 1
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!canRedo)
            .accessibilityLabel(L.text("toolbar.redo"))
            Toggle(isOn: $allowFinger) {
                Image(systemName: "hand.draw")
            }
            .toggleStyle(.button)
            .accessibilityLabel(L.text("toolbar.fingerToggle"))
            Spacer(minLength: 8)
            countMenu
            optionsMenu
        }
    }

    /// 「線の数」 (§4.6 ④): only what was written in the prototype, or a window of 2,500, 10,000 or 25,000.
    private var countMenu: some View {
        Menu {
            Picker(L.text("prototype.span.count"), selection: Binding(get: { model.strokeTotal }, set: { model.setStrokeTotal($0) })) {
                Text(L.text("prototype.span.count.none")).tag(0)
                ForEach(SpanPrototypeSynthetic.counts, id: \.self) { total in
                    Text(L.format("prototype.span.count.value", L.count(total))).tag(total)
                }
            }
        } label: {
            Text(L.text("prototype.span.count"))
                .font(.body)
        }
        .disabled(model.fillProgress != nil)
    }

    /// The prototype's settings: weeks or days (§4.5's day band, §4.6's widest window), the week start (§4.5's
    /// Sunday sample), iPhone landscape's 「今のまま」 / 「上限あり」 (§4.6 ⑤), the week memo's form (§4.5;
    /// PLAN_WEEK_MEMO.md Q2), 「1 ページずつ」 (§4.5's old versions' view), the measurements.
    private var optionsMenu: some View {
        Menu {
            Picker(L.text("header.picker.spoken"), selection: Binding(get: { model.kind }, set: { model.setKind($0) })) {
                Text(L.text("header.picker.week")).tag(PageKind.week)
                Text(L.text("header.picker.day")).tag(PageKind.day)
            }
            .pickerStyle(.menu)
            Picker(L.text("settings.weekStart.title"), selection: Binding(get: { model.weekStart }, set: { model.setWeekStart($0) })) {
                Text(L.text("settings.weekStart.monday")).tag(WeekStart.monday)
                Text(L.text("settings.weekStart.sunday")).tag(WeekStart.sunday)
            }
            .pickerStyle(.menu)
            Picker(L.text("prototype.span.landscape.title"), selection: Binding(get: { model.landscapeCap }, set: { model.setLandscapeCap($0) })) {
                Text(L.text("prototype.span.landscape.now")).tag(false)
                Text(L.text("prototype.span.landscape.cap")).tag(true)
            }
            .pickerStyle(.menu)
            Picker(L.text("prototype.span.memo.title"), selection: $model.memoStyle) {
                Text(L.text("prototype.span.memo.ruled")).tag(SpanPrototypeMemoStyle.ruled)
                Text(L.text("prototype.span.memo.grid")).tag(SpanPrototypeMemoStyle.grid)
                Text(L.text("prototype.span.memo.weekdays")).tag(SpanPrototypeMemoStyle.weekdays)
            }
            .pickerStyle(.menu)
            Toggle(L.text("prototype.span.singlePage"), isOn: Binding(get: { model.singlePage }, set: { model.setSinglePage($0) }))
            Toggle(L.text("prototype.span.hud.show"), isOn: $model.showsMeasurements)
            Button(L.text("prototype.span.guide.show")) {
                guideShown = (guideShown ?? 0) + 1
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
        .accessibilityLabel(L.text("prototype.span.options"))
    }
}

// MARK: - The band

/// The canvas of the session's window, opened with the focus week in the middle of the screen (the band holds
/// the window's weeks side by side; a finger, or two on an iPhone that writes with a finger, scrolls along it).
/// The canvas reports the focus and asks the model to shift the window when it rests elsewhere (§3.6).
struct SpanPrototypeWindowView: View {
    @ObservedObject var session: SpanPrototypeSession
    let model: SpanPrototypeModel
    var tool: CanvasTool
    var allowFinger: Bool
    var undoTrigger: Int
    var redoTrigger: Int
    var pageStep: Int
    var pageStepTrigger: Int
    var onHistoryChanged: (Bool, Bool) -> Void
    /// The pen touched the paper, a finger tapped it, began to drag the band or to pinch (the guide card goes:
    /// §3.14 触れても消える; review B7).
    var onTouch: () -> Void = {}
    /// A pinch began (true) or ended (false): the all-day band's lane height is frozen in between (M4C-27).
    var onZoomingChange: (Bool) -> Void = { _ in }

    /// The band x of the middle of the focus week (the model's focus when the canvas is made again); in a sample
    /// image whose scene says so (`SpanPrototypeShot.Scene.centersBoundary`), its right edge: the boundary with
    /// the next week.
    private var centerX: CGFloat {
        let layout = session.layout
        let focus = model.focusPageIndex ?? session.focusIndex
        let slot = min(max(0, focus - layout.firstIndex), max(0, layout.pages.count - 1))
        if model.scene?.centersBoundary == true {
            return layout.origin(ofSlot: slot) + layout.plan.pageWidth
        }
        return layout.origin(ofSlot: slot) + layout.plan.pageWidth / 2
    }

    /// The sample image's first zoom and top (`SpanPrototypeShot.Scene.opening`); in use the opening zoom at the top.
    private var opening: (zoomRatio: CGFloat, topY: CGFloat?) {
        model.scene?.opening(for: session.plan) ?? (1, nil)
    }

    var body: some View {
        SpanPrototypeCanvas(
            layout: session.layout,
            papers: session.papers,
            tool: tool,
            allowFinger: allowFinger,
            window: session.window,
            windowVersion: session.windowVersion,
            inbox: session.inbox,
            epoch: session.epoch,
            onTap: { _, _ in onTouch() },
            onInkBoundsChanged: { [weak session] in session?.relayoutPages() },
            undoTrigger: undoTrigger,
            redoTrigger: redoTrigger,
            onHistoryChanged: onHistoryChanged,
            onViewportChange: { [weak model] viewport in model?.viewport.value = viewport },
            initialZoomRatio: opening.zoomRatio,
            initialPaperOffset: opening.topY.map { CGPoint(x: 0, y: $0) },
            onZoomingChange: { zooming in
                if zooming { onTouch() }
                onZoomingChange(zooming)
            },
            onPenDown: onTouch,
            initialCenterX: centerX,
            pageStep: pageStep,
            pageStepTrigger: pageStepTrigger,
            onFocusChange: { [weak model] index in model?.focusChanged(index) },
            onShift: { [weak model] index in model?.shift(toFocusIndex: index) },
            onDragBegin: onTouch,
            onRebuild: { [weak model] index in model?.runWaitingRebuild(focusIndex: index) },
            meter: model.meter,
            maxVisiblePages: model.maxVisiblePages,
            memoStyle: model.memoStyle
        )
        .id(session.layout.pageId)
    }
}

// MARK: - One page at a time

/// 「1 ページずつ」 (§4.5: how a version up to 1.2.3 shows the same pages): the focus page alone on the app's own
/// canvas of 1.2.3 (`InkCanvasView`, unchanged), with the page as 1.2.3 lays it out (a week without its memo below
/// 24:00, a day with its free memo by its own handwriting), read only — a stroke written across a boundary shows on
/// the page that holds it, its part beyond the paper as 1.2.3 draws it, and the week memo's strokes not at all (the
/// old layout has no such cell, F1). Nothing is written back (the binding is a constant).
struct SpanPrototypeSinglePageView: View {
    @ObservedObject var session: SpanPrototypeSession
    let index: Int
    var allowFinger: Bool
    /// Where the canvas reports its offset and zoom (the page's day headings, `SpanPrototypeHeader`).
    var viewport: SpanPrototypeViewport? = nil

    var body: some View {
        let pageId = session.plan.pageId(at: index)
        if let paper = session.plainPapers[pageId] {
            InkCanvasView(
                layout: paper.layout,
                paper: paper,
                tool: .ink(InkPresets.defaultPen),
                allowFinger: allowFinger,
                page: .constant(session.slots[pageId]?.page ?? InkPage.empty(pageId: pageId)),
                initialScrollY: 0,
                onTap: { _, _ in },
                onInkBoundsChanged: {},
                undoTrigger: 0,
                redoTrigger: 0,
                onViewportChange: { [weak viewport] value in viewport?.value = value },
                readOnly: true
            )
            .id(pageId)
        } else {
            Color(uiColor: InkCanvasContainerView.deskColor)
        }
    }
}
// MARK: - The day headings

/// The canvas's offset and zoom (`PaperViewport`) for the day headings alone: an object of its own, so a scroll
/// redraws the headings and nothing else of the screen.
@MainActor
final class SpanPrototypeViewport: ObservableObject {
    @Published var value: PaperViewport = .zero
}

/// The day headings over the band (a simple form of §3.8's fixed heading, so the weekday and the date stand over
/// each column; the sample images of §4.5 show which days a stroke crosses): 1.2.3's week heading
/// (`StickyHeaderView`, unchanged) of each window page on screen, placed at that page's x in the band and cut to
/// its width. With 「1 ページずつ」 the shown page's heading alone. Nothing until the canvas has said where it is.
struct SpanPrototypeHeader: View {
    @ObservedObject var session: SpanPrototypeSession
    /// 「1 ページずつ」: the page number shown; nil: the band.
    let singlePageIndex: Int?
    @ObservedObject var viewport: SpanPrototypeViewport

    var body: some View {
        let v = viewport.value
        if v.width > 0 {
            if let index = singlePageIndex {
                if let paper = session.plainPapers[session.plan.pageId(at: index)] {
                    StickyHeaderView(paper: paper, now: session.now, viewport: v,
                                     onDayTap: { _ in }, onMonthTap: { _ in })
                }
            } else {
                ZStack(alignment: .topLeading) {
                    ForEach(Array(session.papers.enumerated()), id: \.offset) { slot, paper in
                        let origin = session.layout.origin(ofSlot: slot)
                        let left = v.x(ofPaper: origin)
                        let width = v.width(ofPaper: session.layout.plan.pageWidth)
                        if left + width > 0, left < v.width {
                            StickyHeaderView(paper: paper, now: session.now,
                                             viewport: PaperViewport(offsetX: v.offsetX - origin * v.zoom, zoom: v.zoom, width: v.width),
                                             onDayTap: { _ in }, onMonthTap: { _ in })
                                .mask(alignment: .topLeading) {
                                    Rectangle()
                                        .frame(width: max(0, width))
                                        .offset(x: left)
                                }
                        }
                    }
                }
                .clipped()
            }
        }
    }
}

// MARK: - The all-day band

/// The all-day band under the day headings (§3.8; review B2), as the calendar screen shows it (`AllDayBandView`,
/// unchanged): each window page's band (`SpanPrototypeSession.bands`: the lanes packed over the window's days, so an
/// event across a boundary keeps its lane and continues square into the next page) placed at that page's x and cut
/// to its width, like the headings. With 「1 ページずつ」 the shown page's band as 1.2.3 lays it out alone. Taps do
/// nothing (the prototype makes no events). Nothing until the canvas has said where it is.
struct SpanPrototypeAllDayBand: View {
    @ObservedObject var session: SpanPrototypeSession
    /// 「1 ページずつ」: the page number shown; nil: the band.
    let singlePageIndex: Int?
    @ObservedObject var viewport: SpanPrototypeViewport
    /// The height of the area holding the band and the canvas (the base of the band's 35 % cap).
    let pageHeight: CGFloat
    /// The zoom the lanes are computed at during a pinch (nil: the canvas's).
    let laneZoom: CGFloat?

    var body: some View {
        let v = viewport.value
        if v.width > 0 {
            if let index = singlePageIndex {
                if let band = session.plainPapers[session.plan.pageId(at: index)]?.allDayBand {
                    AllDayBandView(band: band, viewport: v, pageHeight: pageHeight, laneZoom: laneZoom,
                                   onBarTap: { _ in }, onColumnTap: { _ in })
                }
            } else if session.bands.count == session.papers.count {
                ZStack(alignment: .topLeading) {
                    ForEach(Array(session.bands.enumerated()), id: \.offset) { slot, band in
                        let origin = session.layout.origin(ofSlot: slot)
                        let left = v.x(ofPaper: origin)
                        let width = v.width(ofPaper: session.layout.plan.pageWidth)
                        // Every page's band has the window's lane count, so the same height: the ones off screen are
                        // laid out too (invisible) and keep the row's height while the band slides.
                        AllDayBandView(band: band,
                                       viewport: PaperViewport(offsetX: v.offsetX - origin * v.zoom, zoom: v.zoom, width: v.width),
                                       pageHeight: pageHeight, laneZoom: laneZoom, onBarTap: { _ in }, onColumnTap: { _ in })
                            .mask(alignment: .topLeading) {
                                Rectangle()
                                    .frame(width: max(0, width))
                                    .offset(x: left)
                            }
                            .opacity(left + width > 0 && left < v.width ? 1 : 0)
                            .allowsHitTesting(false)
                    }
                }
                .clipped()
            }
        }
    }
}

// MARK: - The guide card

/// The first-time guide's card as the real one will be (§3.14, B_DESIGN.md §3.1, §8.1): a small dark card at
/// the top of the paper with the fixed text of N-4 (「指でも書く」 off: a finger slides the band) or N-5 (on:
/// two fingers), gone after `duration` or at a touch. In the prototype it comes each time the screen opens and
/// from the settings menu (the real one comes once per device and kind, after the update; none in screenshot
/// mode or with the setting off).
struct SpanPrototypeGuideCard: View {
    /// §3.16: 8 seconds.
    static let duration: TimeInterval = 8

    var text: String
    var onDismiss: () -> Void

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: 520)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .transition(.opacity)
    }
}
#endif
