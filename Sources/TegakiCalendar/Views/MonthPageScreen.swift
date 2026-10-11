import Holidays
import InkModel
import Layout
import SwiftUI
import UIKit

/// The month page (contract §6): header (◀ 今日 ▶ and 「2026年10月」), the fixed weekday row, the
/// paper with the PencilKit canvas (`InkCanvasView`, 担当 I), the floating toolbar, and the sheets.
///
/// Flow: pick a month → `InkPageStore.load("m1-YYYY-MM")` → `EventStoreModel.load(month:)` →
/// `MonthLayoutEngine.layout(...)` → `InkCanvasView`. Ink changes are saved 1.5 s after the last one,
/// before leaving the month, and when the app goes to the background. Events changing or the ink
/// growing past a row's bottom re-run the layout with fresh `inkBottoms`.
struct MonthPageScreen: View {
    @StateObject private var model = EventStoreModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var month: YearMonth
    @State private var page: InkPage
    @State private var layout: MonthPageLayout
    @State private var holidayNames: [DayKey: String] = [:]
    @State private var tool: CanvasTool = .ink(ToolbarPalette.defaultPen)
    /// The last pen / marker, so the Pencil's double tap can go back to it from the eraser.
    @State private var lastInkTool: CanvasTool = .ink(ToolbarPalette.defaultPen)
    @State private var undoTrigger = 0
    @State private var redoTrigger = 0
    @State private var canUndo = false
    @State private var canRedo = false

    @AppStorage("allowFingerDrawing") private var allowFinger = false
    @AppStorage("allowFingerDrawingChosen") private var allowFingerChosen = false
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var showOnboarding = false

    @State private var detail: EventDetail?
    @State private var pendingDetail: EventDetail?
    @State private var dayList: DayListTarget?

    @State private var saveTask: Task<Void, Never>?
    @State private var pageDirty = false
    @State private var saveError: String?
    @State private var appeared = false

    private let store = InkPageStore()

    private static let weekdayLabels = ["月", "火", "水", "木", "金", "土", "日"]

    init() {
        // CI screenshot mode (`ScreenshotMode`) opens the month it was asked for.
        let current = ScreenshotMode.current?.month ?? YearMonth.current()
        _month = State(initialValue: current)
        _page = State(initialValue: InkPage.empty(pageId: current.inkPageId))
        _layout = State(initialValue: Self.makeLayout(month: current, events: [], inkBottoms: [:]))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            accessNotice
            weekdayRow
            InkCanvasView(
                layout: layout,
                paper: paperContent,
                tool: tool,
                allowFinger: allowFinger,
                page: pageBinding,
                onTap: handleTap,
                onInkBoundsChanged: inkBoundsChanged,
                undoTrigger: undoTrigger,
                redoTrigger: redoTrigger,
                onPencilToggle: togglePencilTool,
                onHistoryChanged: historyChanged
            )
            .id(month)
        }
        .background(Color(uiColor: .systemBackground))
        .safeAreaInset(edge: .bottom) {
            ToolbarView(
                tool: $tool,
                allowFinger: $allowFinger,
                canUndo: canUndo,
                canRedo: canRedo,
                onUndo: { undoTrigger += 1 },
                onRedo: { redoTrigger += 1 }
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .onAppear(perform: appear)
        .onChange(of: model.events) { relayout() }
        .onChange(of: scenePhase) { scenePhaseChanged() }
        .onChange(of: tool) {
            if case .ink = tool { lastInkTool = tool }
        }
        .sheet(item: $detail) { item in
            EventDetailSheet(detail: item) { detail = nil }
        }
        .sheet(item: $dayList, onDismiss: showPendingDetail) { target in
            DayEventsSheet(day: target.day, events: model.events(on: target.day), onSelect: { event in
                pendingDetail = model.detail(forEventId: event.id)
                dayList = nil
            }, onClose: { dayList = nil })
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                await model.requestAccess()
                onboardingDone = true
                showOnboarding = false
            }
            .interactiveDismissDisabled()
        }
        .alert("手書きを保存できませんでした", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 6) {
            Button {
                show(month.previous)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("前の月")

            Button("今日") {
                show(YearMonth.current())
            }
            .buttonStyle(.bordered)

            Button {
                show(month.next)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("次の月")

            Spacer(minLength: 0)

            if model.status.canRead, !model.calendars.isEmpty {
                calendarsMenu
            }
        }
        .overlay {
            Text(month.title)
                .font(.title2.weight(.semibold))
                .allowsHitTesting(false)
        }
    }

    private var calendarsMenu: some View {
        Menu {
            Section("表示するカレンダー") {
                ForEach(model.calendars, id: \.calendarIdentifier) { calendar in
                    Button {
                        model.setHidden(!model.isHidden(calendar), calendar: calendar)
                    } label: {
                        Label(calendar.title, systemImage: model.isHidden(calendar) ? "circle" : "checkmark.circle.fill")
                    }
                }
            }
        } label: {
            Image(systemName: "calendar")
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("表示するカレンダー")
    }

    /// A one-line notice while the calendar cannot be read (DESIGN §4.1).
    @ViewBuilder
    private var accessNotice: some View {
        switch model.status {
        case .fullAccess:
            EmptyView()
        case .notDetermined:
            noticeRow("予定を表示するにはカレンダーの読み取りを許可してください。", buttonTitle: "許可する") {
                showOnboarding = true
            }
        case .denied, .writeOnly:
            noticeRow("予定を表示するには設定でカレンダーを「フルアクセス」にしてください。", buttonTitle: "設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        case .restricted:
            noticeRow("この iPad ではカレンダーへのアクセスが制限されています。手書きだけ使えます。", buttonTitle: nil, action: {})
        }
    }

    private func noticeRow(_ text: String, buttonTitle: String?, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            if let buttonTitle = buttonTitle {
                Button(buttonTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    /// The fixed weekday row (DESIGN §2.1). Its columns match the paper at the fit-to-width zoom.
    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { column in
                Text(Self.weekdayLabels[column])
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Self.weekdayColor(column: column))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(uiColor: .separator))
                .frame(height: 0.5)
        }
    }

    private static func weekdayColor(column: Int) -> Color {
        switch column {
        case 5: return Color(uiColor: PaperPalette.blue)
        case 6: return Color(uiColor: PaperPalette.red)
        default: return .primary
        }
    }

    private var paperContent: PaperContent {
        PaperContent(
            layout: layout,
            labels: layout.dateLabels,
            bars: layout.allDayBars,
            chips: layout.timedChips,
            holidayNames: holidayNames
        )
    }

    /// The canvas writes every ink change here; writes for another month (a canvas being torn
    /// down) are ignored so they can never land in the wrong page.
    private var pageBinding: Binding<InkPage> {
        Binding(
            get: { page },
            set: { newValue in
                guard newValue.pageId == month.inkPageId else { return }
                page = newValue
                pageDirty = true
                scheduleSave()
            }
        )
    }

    // MARK: - Lifecycle

    private func appear() {
        guard !appeared else { return }
        appeared = true
        if !allowFingerChosen {
            // Pencil only on iPad by default; iPhones and Macs have no Pencil (DESIGN §2.1).
            allowFingerChosen = true
            allowFinger = UIDevice.current.userInterfaceIdiom != .pad
        }
        // CI screenshot mode never shows the onboarding (and so never asks for calendar access).
        if !onboardingDone, !ScreenshotMode.isActive {
            if model.status == .notDetermined {
                showOnboarding = true
            } else {
                onboardingDone = true
            }
        }
        show(month)
    }

    private func scenePhaseChanged() {
        switch scenePhase {
        case .background, .inactive:
            saveNow()
        case .active:
            model.refreshStatus()
            if appeared { model.reload() }
        @unknown default:
            break
        }
    }

    /// Saves the current page, then switches to `newMonth` (its ink, its events, its layout).
    private func show(_ newMonth: YearMonth) {
        saveNow()
        month = newMonth
        holidayNames = JapaneseHolidays.names(for: MonthLayout.grid(for: newMonth).days)
        // Screenshot mode injects its demo strokes in memory; the store is not read or written.
        page = ScreenshotMode.isActive ? ScreenshotMode.demoPage(for: newMonth) : store.load(newMonth.inkPageId)
        pageDirty = false
        model.load(month: newMonth)
        relayout()
    }

    // MARK: - Layout

    private static func makeLayout(month: YearMonth, events: [LayoutEvent], inkBottoms: [CellKey: CGFloat]) -> MonthPageLayout {
        MonthLayoutEngine.layout(MonthLayoutInput(month: month, events: events, inkBottoms: inkBottoms, now: ScreenshotMode.current?.today ?? Date()))
    }

    private func relayout() {
        layout = Self.makeLayout(month: month, events: model.events, inkBottoms: page.inkBottoms())
    }

    /// The canvas reports that ink may have grown past a row's bottom. The relayout is deferred one
    /// turn so the page binding (written just before or after this call) is already up to date.
    private func inkBoundsChanged() {
        Task { @MainActor in
            relayout()
        }
    }

    // MARK: - Taps

    private func handleTap(at point: CGPoint) {
        guard let hit = layout.hit(at: point) else { return }
        switch hit {
        case .allDayBar(let id), .timedChip(let id):
            if let found = model.detail(forEventId: id) {
                detail = found
            }
        case .moreChips(let day):
            dayList = DayListTarget(day: day)
        case .date:
            // M3: the day page.
            break
        }
    }

    private func showPendingDetail() {
        guard let pending = pendingDetail else { return }
        pendingDetail = nil
        detail = pending
    }

    // MARK: - Canvas callbacks

    /// Apple Pencil double tap / squeeze (DESIGN §3.11): pen or marker ⇄ eraser.
    private func togglePencilTool() {
        if case .eraser = tool {
            tool = lastInkTool
        } else {
            lastInkTool = tool
            tool = .eraser
        }
    }

    /// Undo / redo availability from the canvas's ledger. Applied one turn later: the canvas may
    /// report it while SwiftUI is updating views, when state must not change.
    private func historyChanged(canUndo newCanUndo: Bool, canRedo newCanRedo: Bool) {
        guard newCanUndo != canUndo || newCanRedo != canRedo else { return }
        Task { @MainActor in
            canUndo = newCanUndo
            canRedo = newCanRedo
        }
    }

    // MARK: - Saving

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if Task.isCancelled { return }
            saveNow()
        }
    }

    /// Writes the page now if it changed since the last save.
    private func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        guard pageDirty, !ScreenshotMode.isActive else { return }
        do {
            try store.save(page)
            pageDirty = false
        } catch {
            saveError = error.localizedDescription
        }
    }
}

/// `sheet(item:)` needs an `Identifiable` value; a day's string is its id.
struct DayListTarget: Identifiable, Hashable {
    var day: DayKey
    var id: String { day.description }
}

/// The three first-run cards (contract §6, DESIGN §2.10): the calendar account, the full-access
/// permission, and pen vs. finger. The last card's button asks the OS for access.
struct OnboardingView: View {
    /// Called by the last card's button; it should request access and then dismiss this view.
    var onFinish: () async -> Void

    @Environment(\.openURL) private var openURL
    @State private var index = 0
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $index) {
                card(
                    symbol: "person.crop.circle.badge.plus",
                    title: "カレンダーのアカウント",
                    text: "このアプリは iPad の「カレンダー」に入っている予定を表示します。\n\nGoogle カレンダーの予定を出すには、iPad の設定で Google アカウントを追加します。\n①「設定」→「アプリ」→「カレンダー」→「カレンダーアカウント」→「アカウントを追加」→「Google」（iPadOS 17 では「設定」→「カレンダー」→「アカウント」）\n②「カレンダー」のスイッチをオン\n③同じ画面の「データの取得方法」で「15 分ごと」を選ぶと、予定の反映が早くなります。\n\niCloud カレンダーだけの人は、このままで大丈夫です。",
                    extra: AnyView(
                        Button("設定アプリを開く") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .buttonStyle(.bordered)
                    )
                )
                .tag(0)

                card(
                    symbol: "lock.open",
                    title: "カレンダーへのアクセス",
                    text: "次の画面で、カレンダーへの「フルアクセス」を求めます。予定を手帳のページに表示し、手書きから予定を作るためです。\n\niPadOS には読み取りだけの許可が無いため、フルアクセスになります。予定は iPad の中だけで扱い、開発者やほかの誰にも送りません。",
                    extra: nil
                )
                .tag(1)

                card(
                    symbol: "pencil.and.scribble",
                    title: "ペンで書き、指で動かす",
                    text: "Apple Pencil で紙に書きます。指はスクロール・ピンチ拡大・予定のタップに使います。手のひらが触れても線は引かれません。\n\n指でも書きたいときは、ツールバーの「指でも書く」をオンにしてください。Apple Pencil のダブルタップ／スクイーズは、iPad の「設定 › Apple Pencil」で選んだ動作どおりにペンと消しゴムを切り替えます。",
                    extra: nil
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            HStack {
                Spacer()
                if index < 2 {
                    Button("次へ") {
                        withAnimation { index += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        guard !requesting else { return }
                        requesting = true
                        Task { @MainActor in
                            await onFinish()
                            requesting = false
                        }
                    } label: {
                        if requesting {
                            ProgressView()
                        } else {
                            Text("許可の画面を出す")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(requesting)
                }
                Spacer()
            }
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func card(symbol: String, title: String, text: String, extra: AnyView?) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: symbol)
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 48)
                Text(title)
                    .font(.title.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: 520, alignment: .leading)
                if let extra = extra {
                    extra
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
    }
}
