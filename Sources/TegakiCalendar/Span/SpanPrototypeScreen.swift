#if SPAN_PROTOTYPE
import Combine
import Holidays
import InkModel
import Layout
import SwiftUI
import UIKit

// The prototype's screen (1.3, docs/M7C_CONTRACT.md §4.6, D12, D13): the last row 「横につなげる試作」
// of 設定 › 情報 (`SpanPrototypeEntryRow`, only in the prototype build) opens a sample band of weeks
// (Monday first by default) around this week, the window `SpanPlan` gives the device class and the
// orientation of the screen, on the prototype's copies of the canvas and the ledger. What is written
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
/// whole screen (it is a canvas, not a form).
struct SpanPrototypeEntryRow: View {
    @State private var isOpen = false

    var body: some View {
        Button(L.text("prototype.span.entry")) { isOpen = true }
            .fullScreenCover(isPresented: $isOpen) {
                SpanPrototypeScreen(onClose: { isOpen = false })
            }
    }
}

// MARK: - Model

/// The prototype while its screen is open: its isolated environment (made by the screen, never the
/// app's), and the session, made once the screen knows its size (the device class and the orientation
/// pick the window, §3.6) and composed again when they change. The toggles of §4.6 and §4.5 live here:
/// 「線の数」, iPhone landscape's 「今のまま」 / 「上限あり」, 「1 ページずつ」 and the week start (a new session,
/// K-11). `close()` saves, closes and removes the prototype's folder.
@MainActor
final class SpanPrototypeModel: ObservableObject {
    /// 「上限あり」 (P-B6 イ, B_DESIGN.md §3.1, §6.2): at most this many weeks across on an iPhone in landscape.
    static let cappedVisiblePages: CGFloat = 3

    let environment: SpanPrototypeEnvironment
    @Published private(set) var weekStart: WeekStart
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

    init(environment: SpanPrototypeEnvironment, weekStart: WeekStart, now: Date, holidays: HolidayCalendar, events: [LayoutEvent]) {
        self.environment = environment
        self.weekStart = weekStart
        self.now = now
        self.holidays = holidays
        self.events = events
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

    /// A new session around `focus` for the device of the last size, with the model's week start.
    private func makeSession(focus: DayKey, device: (deviceClass: SpanDeviceClass, orientation: SpanOrientation)) -> SpanPrototypeSession {
        let plan = SpanPlan(kind: .week, weekStart: weekStart, deviceClass: device.deviceClass, orientation: device.orientation)
        let number = nextNumber
        nextNumber += 1
        return SpanPrototypeSession(sync: environment.sync, weekStart: weekStart, focus: focus,
                                    deviceClass: device.deviceClass, orientation: device.orientation,
                                    now: now, holidays: holidays, events: events, number: number,
                                    radius: radiusOverride(for: plan), meter: meter)
    }

    /// The first size makes the session around this week; a size of another device class or orientation
    /// composes its window again (`rebuildWindow`, which saves the pages that leave first), with the radius
    /// of 「上限あり」 when it is in force.
    func screenChanged(_ size: CGSize, isPad: Bool) {
        guard !isClosed, size.width > 0, size.height > 0 else { return }
        lastScreen = (size, isPad)
        let device = Self.device(for: size, isPad: isPad)
        guard let session else {
            session = makeSession(focus: DayKey(now), device: device)
            return
        }
        guard !session.isFilling else { return }
        let plan = SpanPlan(kind: .week, weekStart: weekStart, deviceClass: device.deviceClass, orientation: device.orientation)
        let radius = radiusOverride(for: plan)
        guard plan != session.plan || radius != session.radiusOverride else { return }
        session.rebuildWindow(focusIndex: nil, plan: plan, radius: .some(radius))
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
    /// it (nil when it could not: a page that leaves was not saved).
    func shift(toFocusIndex index: Int) -> SpanPrototypeWindowState? {
        guard !isClosed else { return nil }
        return session?.shift(toFocusIndex: index)
    }

    /// 「線の数」 (§4.6 ④): the band is taken away (its last deltas reach the session), then the session fills
    /// the pages with `total` synthetic strokes over the window (0: takes them out) and reads the window again;
    /// the measurements start afresh. Nothing while it is filling.
    func setStrokeTotal(_ total: Int) {
        guard !isClosed, let session, fillProgress == nil, !session.isFilling, total != strokeTotal else { return }
        strokeTotal = total
        startFill()
    }

    /// Writes `strokeTotal` over the window's pages of the session (`setStrokeTotal`, a new week start).
    private func startFill() {
        meter.reset()
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
        session.rebuildWindow(focusIndex: focusPageIndex, plan: nil, radius: .some(radiusOverride(for: session.plan)))
        focusIndex = nil
    }

    /// 「1 ページずつ」 on or off. On, the window is composed around the focus week (the page shown); off, the
    /// band is made anew with that week in the middle.
    func setSinglePage(_ on: Bool) {
        guard !isClosed, on != singlePage else { return }
        if on, let session, !session.isFilling, let focus = focusPageIndex {
            session.rebuildWindow(focusIndex: focus)
            focusIndex = focus
        }
        singlePage = on
    }

    /// ◀ ▶ while 「1 ページずつ」 is on: the week before or after, the window composed around it.
    func stepSinglePage(_ pages: Int) {
        guard !isClosed, let session, !session.isFilling, let focus = focusPageIndex else { return }
        let next = focus + pages
        guard session.rebuildWindow(focusIndex: next) else { return }
        focusIndex = next
    }

    /// The week start (K-11: a window never mixes the two shapes): the session is saved and closed, a new one
    /// opens around the same day with the other shape (the prototype's pages of that shape; what was written
    /// in the other one stays in its pages), and 「線の数」 fills its pages again.
    func setWeekStart(_ start: WeekStart) {
        guard !isClosed, start != weekStart, fillProgress == nil, let old = session, !old.isFilling,
              let screen = lastScreen else { return }
        let day = old.plan.firstDay(at: focusPageIndex ?? old.focusIndex)
        old.close()
        weekStart = start
        focusIndex = nil
        meter.reset()
        session = makeSession(focus: day, device: Self.device(for: screen.size, isPad: screen.isPad))
        if strokeTotal > 0 {
            startFill()
        }
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
    @State private var guideShown: Int? = 1

    /// `environment` nil is the prototype's own (`SpanPrototypeEnvironment.makeIsolated()`, made once, when
    /// the screen first appears); the events are the screenshot mode's sample events of this month
    /// (EventKit is never read).
    @MainActor
    init(onClose: @escaping () -> Void, weekStart: WeekStart = .monday, now: Date = Date(),
         environment: SpanPrototypeEnvironment? = nil) {
        self.onClose = onClose
        let today = DayKey(now)
        _model = StateObject(wrappedValue: SpanPrototypeModel(
            environment: environment ?? SpanPrototypeEnvironment.makeIsolated(),
            weekStart: weekStart,
            now: now,
            holidays: HolidayChoice.current,
            events: ScreenshotMode.demoEvents(for: YearMonth(year: today.year, month: today.month), empty: false,
                                              language: L.language, storeInk: false)
        ))
    }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                bar
                Text(L.text("prototype.span.note"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                Divider()
                ZStack(alignment: .bottomLeading) {
                    content
                    if model.showsMeasurements {
                        SpanPrototypeHUD(meter: model.meter)
                    }
                }
                .overlay(alignment: .top) {
                    if let shown = guideShown, !model.singlePage, model.fillProgress == nil {
                        SpanPrototypeGuideCard(text: allowFinger ? L.text("prototype.span.guide.week.finger") : L.text("prototype.span.guide.week.pencil"),
                                               onDismiss: hideGuide)
                            .task(id: shown) {
                                try? await Task.sleep(for: .seconds(SpanPrototypeGuideCard.duration))
                                if guideShown == shown { guideShown = nil }
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
            SpanPrototypeSinglePageView(session: session, index: focus, allowFinger: allowFinger)
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
                onTouch: hideGuide
            )
        } else {
            Color(uiColor: InkCanvasContainerView.deskColor)
        }
    }

    private var title: String {
        guard let session = model.session, let focus = model.focusPageIndex else { return L.text("prototype.span.entry") }
        return PageNavigation.title(.week, focus: session.plan.firstDay(at: focus), holidays: model.holidays, language: L.language,
                                    weekStart: session.weekStart)
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
                .accessibilityLabel(L.text("header.previous.week"))
                Button {
                    step(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel(L.text("header.next.week"))
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

    /// The prototype's settings: the week start (§4.5's Sunday sample), iPhone landscape's 「今のまま」 /
    /// 「上限あり」 (§4.6 ⑤), the week memo's form (§4.5), 「1 ページずつ」 (§4.5's old versions' view), the
    /// measurements.
    private var optionsMenu: some View {
        Menu {
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
    /// The pen touched the paper or a finger began to drag the band (the guide card goes).
    var onTouch: () -> Void = {}

    /// The band x of the middle of the focus week (the model's focus when the canvas is made again).
    private var centerX: CGFloat {
        let layout = session.layout
        let focus = model.focusPageIndex ?? session.focusIndex
        let slot = min(max(0, focus - layout.firstIndex), max(0, layout.pages.count - 1))
        return layout.origin(ofSlot: slot) + layout.plan.pageWidth / 2
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
            onInkBoundsChanged: { [weak session] in session?.relayoutPages() },
            undoTrigger: undoTrigger,
            redoTrigger: redoTrigger,
            onHistoryChanged: onHistoryChanged,
            onPenDown: onTouch,
            initialCenterX: centerX,
            pageStep: pageStep,
            pageStepTrigger: pageStepTrigger,
            onFocusChange: { [weak model] index in model?.focusChanged(index) },
            onShift: { [weak model] index in model?.shift(toFocusIndex: index) },
            onDragBegin: onTouch,
            meter: model.meter,
            maxVisiblePages: model.maxVisiblePages,
            memoStyle: model.memoStyle
        )
        .id(session.layout.pageId)
    }
}

// MARK: - One page at a time

/// 「1 ページずつ」 (§4.5: how a version up to 1.2.3 shows the same pages): the focus week alone on the app's own
/// canvas of 1.2.3 (`InkCanvasView`, unchanged), with the week as 1.2.3 lays it out (no memo below 24:00), read
/// only — a stroke written across a boundary shows on the page that holds it, its part beyond the paper as
/// 1.2.3 draws it, and the week memo's strokes not at all (the old layout has no such cell, F1). Nothing is
/// written back (the binding is a constant).
struct SpanPrototypeSinglePageView: View {
    @ObservedObject var session: SpanPrototypeSession
    let index: Int
    var allowFinger: Bool

    var body: some View {
        let pageId = session.plan.pageId(at: index)
        if let layout = session.plainLayouts[pageId] {
            InkCanvasView(
                layout: layout,
                paper: .week(WeekPaperContent(layout: layout)),
                tool: .ink(InkPresets.defaultPen),
                allowFinger: allowFinger,
                page: .constant(session.slots[pageId]?.page ?? InkPage.empty(pageId: pageId)),
                initialScrollY: 0,
                onTap: { _, _ in },
                onInkBoundsChanged: {},
                undoTrigger: 0,
                redoTrigger: 0,
                readOnly: true
            )
            .id(pageId)
        } else {
            Color(uiColor: InkCanvasContainerView.deskColor)
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
