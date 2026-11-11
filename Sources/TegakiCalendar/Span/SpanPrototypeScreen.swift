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
// Not here yet: the shift of the window, the fling, the palm's rule, the measurements and their toggles,
// the week memo and the guide card (§4.6).

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
    private(set) var isClosed = false

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
        let device = Self.device(for: size, isPad: isPad)
        guard let session else {
            session = SpanPrototypeSession(sync: environment.sync, weekStart: weekStart, focus: DayKey(now),
                                           deviceClass: device.deviceClass, orientation: device.orientation,
                                           now: now, holidays: holidays, events: events)
            return
        }
        guard session.plan.deviceClass != device.deviceClass || session.plan.orientation != device.orientation else { return }
        session.rebuildWindow(plan: SpanPlan(kind: .week, weekStart: weekStart, deviceClass: device.deviceClass,
                                             orientation: device.orientation))
    }

    /// Saves what is waiting (the app went to the background, the pen rests).
    func saveNow() {
        session?.saveAll()
    }

    /// Saves, closes the session and removes the prototype's folder. Once.
    func close() {
        guard !isClosed else { return }
        isClosed = true
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
                if let session = model.session {
                    SpanPrototypeWindowView(
                        session: session,
                        tool: tool,
                        allowFinger: allowFinger,
                        undoTrigger: undoTrigger,
                        redoTrigger: redoTrigger,
                        onHistoryChanged: { undo, redo in
                            canUndo = undo
                            canRedo = redo
                        }
                    )
                } else {
                    Color(uiColor: InkCanvasContainerView.deskColor)
                }
            }
            .onAppear { model.screenChanged(proxy.size, isPad: isPad) }
            .onChange(of: proxy.size) { model.screenChanged(proxy.size, isPad: isPad) }
        }
        .background(Color(uiColor: .systemBackground))
        .onChange(of: scenePhase) {
            if scenePhase != .active { model.saveNow() }
        }
        .onDisappear { model.close() }
    }

    private var title: String {
        guard let session = model.session else { return L.text("prototype.span.entry") }
        return PageNavigation.title(.week, focus: session.focusDay, holidays: model.holidays, language: L.language,
                                    weekStart: model.weekStart)
    }

    private var bar: some View {
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
        }
        .font(.title3)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - The band

/// The canvas of the session's window, opened at the focus week's left edge (the band holds the window's
/// weeks side by side; a finger, or two on an iPhone that writes with a finger, scrolls along it).
struct SpanPrototypeWindowView: View {
    @ObservedObject var session: SpanPrototypeSession
    var tool: CanvasTool
    var allowFinger: Bool
    var undoTrigger: Int
    var redoTrigger: Int
    var onHistoryChanged: (Bool, Bool) -> Void

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
            initialPaperOffset: CGPoint(x: session.layout.origin(ofSlot: session.focusSlot), y: 0)
        )
        .id(session.layout.pageId)
    }
}
#endif
