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
// measurements of §4.6 stand in a corner of the band (`SpanPrototypeMeter`, `SpanPrototypeHUD`).

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
/// pick the window, §3.6) and composed again when they change. `close()` saves, closes and removes the
/// prototype's folder.
@MainActor
final class SpanPrototypeModel: ObservableObject {
    let environment: SpanPrototypeEnvironment
    let weekStart: WeekStart
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
    private(set) var isClosed = false
    /// The last size `screenChanged` was told of (a size that came while 「線の数」 wrote is taken after it).
    private var lastScreen: (size: CGSize, isPad: Bool)?

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

    /// The first size makes the session around this week; a size of another device class or orientation
    /// composes its window again (`rebuildWindow`, which saves the pages that leave first).
    func screenChanged(_ size: CGSize, isPad: Bool) {
        guard !isClosed, size.width > 0, size.height > 0 else { return }
        lastScreen = (size, isPad)
        let device = Self.device(for: size, isPad: isPad)
        guard let session else {
            session = SpanPrototypeSession(sync: environment.sync, weekStart: weekStart, focus: DayKey(now),
                                           deviceClass: device.deviceClass, orientation: device.orientation,
                                           now: now, holidays: holidays, events: events, meter: meter)
            return
        }
        guard !session.isFilling else { return }
        guard session.plan.deviceClass != device.deviceClass || session.plan.orientation != device.orientation else { return }
        session.rebuildWindow(plan: SpanPlan(kind: .week, weekStart: weekStart, deviceClass: device.deviceClass,
                                             orientation: device.orientation))
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
        meter.reset()
        fillProgress = SpanPrototypeSession.FillProgress(done: 0, total: 0)
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
                }
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

    /// ◀ ▶: one week back or on (§3.6).
    private func step(_ pages: Int) {
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

    /// The prototype's settings.
    private var optionsMenu: some View {
        Menu {
            Toggle(L.text("prototype.span.hud.show"), isOn: $model.showsMeasurements)
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
            undoTrigger: undoTrigger,
            redoTrigger: redoTrigger,
            onHistoryChanged: onHistoryChanged,
            initialCenterX: centerX,
            pageStep: pageStep,
            pageStepTrigger: pageStepTrigger,
            onFocusChange: { [weak model] index in model?.focusChanged(index) },
            onShift: { [weak model] index in model?.shift(toFocusIndex: index) },
            meter: model.meter
        )
        .id(session.layout.pageId)
    }
}
#endif
