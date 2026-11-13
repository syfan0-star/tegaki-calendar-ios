import Access
import InkModel
import Layout
import StoreKit
import SwiftUI
import UIKit

/// The settings sheet (M3b contract §4.8, M4 contract §6.2, M5 contract §4.3, M6 contract §3.1,
/// DESIGN §2.8): calendars (shown, default, access, Google how-to), input (finger, Pencil,
/// erase-after-convert), sync (the iCloud state, the last sync, 「今すぐ同期」, the account question),
/// data (import from the web version or the app's own data file, 「手書きを書き出す」 (M6, usable while
/// read only too), erase everything confirmed twice), purchase (the plan and its date from
/// `store.snapshot`, 「購読する」 while read only, 「サブスクリプションを管理」, 「購入を復元」 with the
/// result under the footer), and the info links (`LegalLinks`). 1.1 (M7A_CONTRACT §2.6 / §5.3 / §6.1):
/// 入力 has 「消しゴムで消したらペンに戻る」 (`AppSettings.eraserAutoReturn`), 情報 has the two stroke
/// counts of this device (`StrokeCensus`, counted in the background while the sheet is open) and a
/// footer, and the device is 「この端末」 everywhere (an iPhone too). 1.2 (docs/M7B_CONTRACT.md §5.7, §10.4): the
/// sections of the week start and the holidays after 「カレンダー」, the licences' row in 情報, and on
/// every screen but a Japanese one the note about the translations under its footer. 1.3 (docs/M7C_CONTRACT.md §3.14,
/// D3 (3)): the section 「ページ」 between 入力 and 同期, with the one row 「前後のページを横につなげる」
/// (`AppSettings.pageSpan`).
struct SettingsScreen: View {
    @ObservedObject var model: EventStoreModel
    @ObservedObject var sync: SyncEngine
    @Binding var allowFinger: Bool
    /// 「許可する」 while the permission is undecided.
    var onRequestAccess: () async -> Void
    /// 「今すぐ同期」 (`Task { await sync.syncNow() }`).
    var onSyncNow: () -> Void
    /// 「Web 版の手書きを取り込む」: the owner closes this sheet and shows the file picker (§6.3).
    var onImportWeb: () -> Void
    /// Called after the second confirmation; the owner empties the page and asks the engine (§6.2).
    var onEraseAllInk: () -> Void
    /// 「新しいアカウントで使い始める…」: the owner shows the account question (§6.4).
    var onResolveAccountChange: () -> Void
    var onDone: () -> Void
    /// Screenshot mode's `sync` sheet (M4 contract §6.6): scroll to the 「同期」 section once the form
    /// is on screen, because the section sits below the fold on an iPad (DESIGN §2.8 order).
    var scrollToSyncOnAppear: Bool = false
    /// M5 (M5_CONTRACT §4.3): the store behind 「購入」 (the plan, its date, 「購入を復元」, the result line).
    @ObservedObject var store: StoreModel
    /// 「購読する」/「14 日間無料で試す」: the owner closes this sheet and shows the paywall (reason .settings).
    var onShowPaywall: () -> Void = {}
    /// Reserved for a screenshot of the 「購入」 section (M5 does not use it): scroll there on appear.
    var scrollToPurchaseOnAppear: Bool = false
    /// 「手書きを書き出す」 (M6 contract §3.1): the owner closes this sheet and shows `ExportSheet`.
    /// Allowed while read only (`GatedAction.export`), so the row is never greyed.
    var onExport: () -> Void = {}
    /// Screenshot mode's `info` sheet (1.1, M7A_CONTRACT §7.3): scroll to the 「情報」 section once the
    /// form is on screen (the same way as `scrollToSyncOnAppear`).
    var scrollToInfoOnAppear: Bool = false
    /// 1.2 (§10.7): screenshot mode's way to switch the week start: nothing is stored there, so the
    /// owner's `.onChange` never fires and the question's answer calls this instead.
    var onScreenshotWeekStart: (WeekStart) -> Void = { _ in }
    /// 1.3 (§3.1, §3.14): 「前後のページを横につなげる」 was switched (the new value), after it was stored (outside
    /// screenshot mode, where nothing is stored). The owner saves the open pages and reopens them on the other path
    /// (S5's screen wave); by default nothing more happens.
    var onPageSpanChange: (Bool) -> Void = { _ in }

    @Environment(\.openURL) private var openURL
    @State private var eraseInkAfterConvert: Bool = ScreenshotMode.isActive ? true : AppSettings.eraseInkAfterConvert
    /// 1.1 (§2.6): 「消しゴムで消したらペンに戻る」, on in screenshot mode (nothing is stored there).
    @State private var eraserAutoReturn: Bool = ScreenshotMode.isActive ? true : AppSettings.eraserAutoReturn
    /// 1.3 (§3.14): 「前後のページを横につなげる」 (`initialPageSpan`).
    @State private var pageSpan: Bool = Self.initialPageSpan(screenshot: ScreenshotMode.isActive)
    /// 1.1 (§5.3): the stroke counts of 情報; nil until `StrokeCensus` has counted (「数えています…」).
    @State private var census: StrokeCensus.Result?
    @State private var confirmEraseStep1 = false
    @State private var confirmEraseStep2 = false
    @State private var requestingAccess = false
    /// 「今すぐ同期」 shows a spinner for one second after the tap.
    @State private var syncingNow = false
    /// 「サブスクリプションを管理」 → `.manageSubscriptionsSheet` (M5-21).
    @State private var showManage = false
    /// 1.1 fix (TestFlight only, docs/M7A.md ずれ 46): the 「記録」 sheet (`InkTrace`).
    @State private var showTrace = false
    /// 1.2 (§10.4): the setting the question of switching the week start is about; nil = no question.
    @State private var pendingWeekStart: WeekStartChoice.Setting?
    /// 1.2 (§10.7): the week start of screenshot mode while the sheet is open (nothing is stored there).
    @State private var screenshotWeekStart: WeekStart = ScreenshotMode.current?.weekStart ?? .monday
    /// 1.2 (§7.4): `--screenshot-sheet holidays` opens the picker over this screen.
    @State private var showHolidayPicker = false

    /// The id of the first row of the 「同期」 section (the scroll target of `scrollToSyncOnAppear`).
    private static let syncRowId = "sync-section"
    /// The id of the first row of the 「購入」 section (`scrollToPurchaseOnAppear`).
    private static let purchaseRowId = "purchase-section"
    /// The id of the 「バージョン」 row of the 「情報」 section (`scrollToInfoOnAppear`). Not the first row:
    /// in the 13-inch form sheet the scroll leaves its target about half way down (CI run 41191448391:
    /// 「利用規約」 landed there and 「今年の年のページ」 and the footer stayed below the sheet), so the
    /// row above the two stroke-count rows is the target and the whole section with its footer shows.
    private static let infoRowId = "info-section"

    /// The same steps as the first onboarding card (OnboardingView, DESIGN §2.10). 1.1 (§6.1): the
    /// 「設定」 app of whichever device, and the OS name of both.
    static let googleHowTo = L.text("settings.calendar.google.howTo")

    // MARK: 1.1 texts (M7A_CONTRACT §2.6 / §5.3 / §6.2)

    /// 設定 › 入力: the row of the eraser's return to the pen.
    static let eraserAutoReturnTitle = L.text("settings.input.eraserAutoReturn.title")

    /// The footer of that row: the Apple Pencil sentences only on an iPad (an iPhone's settings never
    /// speak of the Pencil, like the 「Apple Pencil」 row, which only an iPad has).
    static func eraserAutoReturnFooter(isPad: Bool) -> String {
        isPad
            ? L.text("settings.input.eraserAutoReturn.footer.pad")
            : L.text("settings.input.eraserAutoReturn.footer.phone")
    }

    /// 設定 › 情報: the two rows of the stroke counts (values: `StrokeCensus.rowText` / `yearRowText`).
    static let largestPageTitle = L.text("settings.info.largestPage")
    static let yearPageTitle = L.text("settings.info.yearPage")
    /// The footer of 情報.
    static let infoFooter = L.format("settings.info.footer", DateText.number(StrokeBudget.refuseAt, L.language))

    /// 1.2 (M7B-13, §5.7): under the footer of 情報 on every screen but a Japanese one: how the
    /// translations were made, and where to report a mistake.
    static func translationNote(language: UILanguage = L.language) -> String? {
        language == .ja ? nil : L.text("info.translationNote", in: language)
    }

    // MARK: 1.3 texts (docs/M7C_CONTRACT.md §8.1 N-1 … N-3)

    /// 設定 › ページ: the section's title (N-1).
    static let pageSectionTitle = L.text("settings.page.header")
    /// Its one row (N-2).
    static let pageSpanTitle = L.text("settings.page.span")
    /// The row's footnote (N-3).
    static let pageSpanFooter = L.text("settings.page.span.footer")
    /// The row's switch, for the UI tests (§10.3).
    static let pageSpanIdentifier = "settings.pageSpan"

    /// The switch as the sheet opens: this device's `AppSettings.pageSpan` (on until the person turns it off);
    /// in screenshot mode off, the one-page path, without reading the store (§3.12: nothing is stored there).
    static func initialPageSpan(screenshot: Bool) -> Bool {
        screenshot ? false : AppSettings.pageSpan
    }

    /// The switch was turned to `value`: outside screenshot mode it is stored for this device first, then the owner
    /// is told (`onPageSpanChange`), so the owner that saves and reopens the pages on the other path (S5's screen
    /// wave) already reads the new value. Screenshot mode stores nothing and still tells the owner.
    static func pageSpanChanged(to value: Bool, screenshot: Bool, notify: (Bool) -> Void) {
        if !screenshot {
            AppSettings.pageSpan = value
        }
        notify(value)
    }

    /// The data section's footer (M4 contract §6.2).
    static let importFooter = L.text("settings.data.importFooter")

    /// The data section's second paragraph (M6 contract §3.1 / §3.6): what 「手書きを書き出す」 makes,
    /// and that the data file goes back in through the import row (while subscribed).
    static let exportFooter = L.text("settings.data.exportFooter")

    /// "0.5.0 (1)" from the bundle.
    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = (info?["CFBundleShortVersionString"] as? String) ?? "—"
        let build = (info?["CFBundleVersion"] as? String) ?? "—"
        return "\(short) (\(build))"
    }

    /// 「2026/10/7 9:57」 on a Japanese iPad, "10/7/2026, 9:57 AM" in English: the date and the time, in
    /// the Gregorian calendar whatever the device's (0-11, 0-33).
    static func timeText(_ date: Date) -> String {
        DateText.numericDateTime(date, L.language)
    }

    /// The 「最後に同期」 value: the time, or 「まだありません」.
    static func lastSyncText(_ date: Date?) -> String {
        date.map(timeText) ?? L.text("settings.sync.lastSync.none")
    }

    /// 「前回の取り込み: 2026/10/14 9:41」 under the data footer; nil when nothing was imported yet.
    static func webImportedText(_ date: Date?) -> String? {
        date.map { L.format("settings.data.lastImport", timeText($0)) }
    }

    /// 「今すぐ同期」 is inert while there is no account to sync with or a round is running.
    static func canSyncNow(_ status: SyncStatus) -> Bool {
        switch status {
        case .localOnly, .accountMismatch, .syncing: return false
        case .synced, .pending, .offline, .error: return true
        }
    }

    /// Whether erasing also reaches iCloud (the engine deletes the records in these states; M4
    /// contract §4.5 の 10). The two confirmations say so.
    static func erasesCloud(_ status: SyncStatus) -> Bool {
        switch status {
        case .synced, .pending, .syncing, .offline, .error: return true
        case .localOnly, .accountMismatch: return false
        }
    }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private var status: SyncStatus { sync.snapshot.status }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    calendarSection
                    // 1.2 (§5.7, §10.4): right after 「カレンダー」; the day's holidays and the week's first
                    // day belong with the calendar, and the rows above do not move.
                    WeekStartSettingsSection(
                        pending: $pendingWeekStart,
                        screenshotWeekStart: screenshotWeekStart,
                        pageIds: { sync.allLocalPageIds() }
                    )
                    HolidaySettingsSection()
                    inputSections
                    // 1.3 (§3.14): between 入力 and 同期; the rows above and below do not move.
                    pageSection
                    syncSection
                    dataSection
                    purchaseSection
                    infoSection
                }
                .navigationTitle(L.text("settings.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L.text("settings.done"), action: onDone)
                            .fontWeight(.semibold)
                    }
                }
                .confirmationDialog(eraseQuestion, isPresented: $confirmEraseStep1, titleVisibility: .visible) {
                    Button(L.text("settings.data.erase.confirm"), role: .destructive) {
                        // The second question is an alert; it can only appear once the dialog is gone.
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(0.35))
                            confirmEraseStep2 = true
                        }
                    }
                    Button(L.text("settings.data.erase.cancel"), role: .cancel) {}
                }
                .alert(L.text("settings.data.erase.title"), isPresented: $confirmEraseStep2) {
                    Button(L.text("settings.data.erase.all"), role: .destructive, action: onEraseAllInk)
                    Button(L.text("settings.data.erase.cancel"), role: .cancel) {}
                } message: {
                    Text(eraseWarning)
                }
                // 1.2 (§10.4): the question of switching the week start (here, not on the row: a form
                // keeps no off-screen row alive, and the row's picker is on its way back).
                .weekStartQuestion(pending: $pendingWeekStart, current: screenshotWeekStart, onScreenshotAnswer: { new in
                    screenshotWeekStart = new
                    onScreenshotWeekStart(new)
                })
                // 1.2 (§7.4): `--screenshot-sheet holidays`.
                .navigationDestination(isPresented: $showHolidayPicker) { HolidayPickerScreen() }
                .onChange(of: eraseInkAfterConvert) {
                    guard !ScreenshotMode.isActive else { return }
                    AppSettings.eraseInkAfterConvert = eraseInkAfterConvert
                }
                .onChange(of: eraserAutoReturn) {
                    guard !ScreenshotMode.isActive else { return }
                    AppSettings.eraserAutoReturn = eraserAutoReturn
                }
                .onChange(of: pageSpan) {
                    Self.pageSpanChanged(to: pageSpan, screenshot: ScreenshotMode.isActive, notify: onPageSpanChange)
                }
                .task { await openScreenshotPieces() }
                .onAppear {
                    guard scrollToSyncOnAppear || scrollToPurchaseOnAppear || scrollToInfoOnAppear else { return }
                    // The list needs a layout pass before it can scroll; the row lands a little below
                    // the top so the section header stays in view.
                    let target = scrollToSyncOnAppear ? Self.syncRowId : scrollToInfoOnAppear ? Self.infoRowId : Self.purchaseRowId
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.4))
                        proxy.scrollTo(target, anchor: UnitPoint(x: 0.5, y: 0.08))
                    }
                }
                // 1.1 (§5.3): count the pages while the sheet is open; closing it cancels the count.
                .task { await countStrokes() }
                .manageSubscriptionsSheet(isPresented: $showManage)
                .sheet(isPresented: $showTrace) {
                    InkTraceSheet(text: InkTrace.text, onDone: { showTrace = false })
                }
            }
        }
        // A restore's result line is for this visit only (the paywall does the same).
        .onDisappear { store.clearMessage() }
    }

    // MARK: - カレンダー

    private struct SourceGroup: Identifiable {
        var id: String { source }
        var source: String
        var calendars: [CalendarOption]
    }

    /// The calendars grouped by account (`sourceTitle`), sources and titles sorted.
    private var sourceGroups: [SourceGroup] {
        let options = model.calendarOptions
        let sources = Array(Set(options.map { $0.sourceTitle })).sorted()
        return sources.map { source in
            SourceGroup(source: source, calendars: options.filter { $0.sourceTitle == source }.sorted { $0.title < $1.title })
        }
    }

    private var calendarSection: some View {
        Section(L.text("settings.calendar.header")) {
            Text(L.text("settings.calendar.shown"))
                .font(.subheadline.weight(.semibold))
            if sourceGroups.isEmpty {
                Text(model.status.canRead ? L.text("settings.calendar.empty") : L.text("settings.calendar.noAccess"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sourceGroups) { group in
                    Text(group.source.isEmpty ? L.text("settings.calendar.otherSource") : group.source)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ForEach(group.calendars) { option in
                        calendarRow(option)
                    }
                }
            }
            let writable = model.writableCalendarOptions
            if !writable.isEmpty {
                Picker(L.text("settings.calendar.default"), selection: defaultCalendarBinding(writable)) {
                    ForEach(writable) { option in
                        HStack(spacing: 8) {
                            colorDot(option.colorHex)
                            Text(option.title)
                        }
                        .tag(option.id)
                    }
                }
                .pickerStyle(.navigationLink)
            }
            HStack {
                Text(L.text("settings.calendar.access.title"))
                Spacer()
                Text(accessText)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            accessButton
            DisclosureGroup(L.text("settings.calendar.google.title")) {
                Text(Self.googleHowTo)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(L.text("settings.openSettingsApp"), action: openSettingsApp)
            }
        }
    }

    private func calendarRow(_ option: CalendarOption) -> some View {
        let hidden = model.isHidden(calendarId: option.id)
        return Button {
            model.setHidden(!hidden, calendarId: option.id)
        } label: {
            HStack(spacing: 10) {
                colorDot(option.colorHex)
                Text(option.title)
                    .foregroundStyle(.primary)
                Spacer()
                if !hidden {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityValue(hidden ? L.text("settings.calendar.a11y.hidden") : L.text("settings.calendar.a11y.shown"))
        .accessibilityAddTraits(hidden ? [] : .isSelected)
    }

    private func colorDot(_ hex: String) -> some View {
        Circle()
            .fill(Color(uiColor: PaperPalette.color(hex: hex)))
            .frame(width: 10, height: 10)
    }

    private func defaultCalendarBinding(_ writable: [CalendarOption]) -> Binding<String> {
        Binding(
            get: {
                if let id = model.defaultCalendarId, writable.contains(where: { $0.id == id }) { return id }
                return writable.first?.id ?? ""
            },
            set: { model.setDefaultCalendarId($0) }
        )
    }

    private var accessText: String {
        switch model.status {
        case .fullAccess: return L.text("settings.calendar.access.full")
        case .notDetermined: return L.text("settings.calendar.access.notDetermined")
        case .denied: return L.text("settings.calendar.access.denied")
        case .writeOnly: return L.text("settings.calendar.access.writeOnly")
        case .restricted: return L.text("settings.calendar.access.restricted")
        }
    }

    @ViewBuilder
    private var accessButton: some View {
        switch model.status {
        case .notDetermined:
            Button {
                guard !requestingAccess else { return }
                requestingAccess = true
                Task { @MainActor in
                    await onRequestAccess()
                    requestingAccess = false
                }
            } label: {
                if requestingAccess {
                    ProgressView()
                } else {
                    Text(L.text("settings.calendar.access.allow"))
                }
            }
            .disabled(requestingAccess)
        case .denied, .writeOnly:
            Button(L.text("settings.openSettingsApp"), action: openSettingsApp)
        case .fullAccess, .restricted:
            EmptyView()
        }
    }

    // MARK: - 入力

    @ViewBuilder
    private var inputSections: some View {
        Section {
            Toggle(L.text("settings.input.allowFinger"), isOn: $allowFinger)
        } header: {
            Text(L.text("settings.input.header"))
        } footer: {
            Text(L.text("settings.input.allowFinger.footer"))
        }
        // 1.1 (§2.6): on the iPad and the iPhone; the footer speaks of the Pencil only on an iPad.
        Section {
            Toggle(Self.eraserAutoReturnTitle, isOn: $eraserAutoReturn)
        } footer: {
            Text(Self.eraserAutoReturnFooter(isPad: isPad))
        }
        if isPad {
            Section {
                HStack {
                    Text(L.text("settings.input.pencil"))
                    Spacer()
                    Button(L.text("settings.openSettingsApp"), action: openSettingsApp)
                }
            } footer: {
                Text(L.text("settings.input.pencil.footer"))
            }
        }
        Section {
            Toggle(L.text("settings.input.eraseAfterConvert"), isOn: $eraseInkAfterConvert)
        } footer: {
            Text(L.text("settings.input.eraseAfterConvert.footer"))
        }
    }

    // MARK: - ページ (1.3, docs/M7C_CONTRACT.md §3.14)

    /// One row, 「前後のページを横につなげる」 (on by default, per device), and its footnote (§8.1 N-1 … N-3).
    private var pageSection: some View {
        Section {
            Toggle(Self.pageSpanTitle, isOn: $pageSpan)
                .accessibilityIdentifier(Self.pageSpanIdentifier)
        } header: {
            Text(Self.pageSectionTitle)
        } footer: {
            Text(Self.pageSpanFooter)
        }
    }

    // MARK: - 同期 (M4 contract §6.2)

    private var syncSection: some View {
        Section {
            HStack {
                Text(L.text("settings.sync.icloud"))
                Spacer()
                Text(status.settingsText)
                    .foregroundStyle(status.isError ? Color.red : Color.secondary)
                    .multilineTextAlignment(.trailing)
            }
            .id(Self.syncRowId)
            HStack {
                Text(L.text("settings.sync.lastSync"))
                Spacer()
                Text(Self.lastSyncText(sync.snapshot.lastSyncAt))
                    .foregroundStyle(.secondary)
            }
            Button(action: syncNow) {
                if syncingNow {
                    ProgressView()
                } else {
                    Text(L.text("settings.sync.now"))
                }
            }
            .disabled(!Self.canSyncNow(status) || syncingNow)
            if status == .accountMismatch {
                Button(L.text("settings.sync.newAccount"), action: onResolveAccountChange)
            }
        } header: {
            Text(L.text("settings.sync.header"))
        } footer: {
            Text(status.settingsFooter)
        }
    }

    /// 「今すぐ同期」: one round now, and a spinner for a second so the tap is seen.
    private func syncNow() {
        guard !syncingNow else { return }
        syncingNow = true
        onSyncNow()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            syncingNow = false
        }
    }

    // MARK: - データ

    private var dataSection: some View {
        Section {
            // M5 (M5_CONTRACT §3.1): greyed while read only, but still tappable (the owner then shows
            // the paywall or a toast).
            Button(action: onImportWeb) {
                Text(L.text("settings.data.import"))
                    .foregroundStyle(store.isReadOnly ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
            }
            // M6 (M6_CONTRACT §3.1, D1): the export is allowed while read only (`GatedAction.export`),
            // so the row keeps its tint in every access state.
            Button(action: onExport) {
                Text(L.text("settings.data.export"))
                    .foregroundStyle(.tint)
            }
            Button(L.text("settings.data.eraseAll"), role: .destructive) {
                confirmEraseStep1 = true
            }
        } header: {
            Text(L.text("settings.data.header"))
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.importFooter)
                Text(Self.exportFooter)
                if let imported = Self.webImportedText(sync.snapshot.webImportedAt) {
                    Text(imported)
                }
            }
        }
    }

    /// The first confirmation: whether iCloud's copy goes too.
    private var eraseQuestion: String {
        Self.erasesCloud(status)
            ? L.text("settings.data.erase.question.cloud")
            : L.text("settings.data.erase.question.local")
    }

    /// The second confirmation's message.
    private var eraseWarning: String {
        Self.erasesCloud(status)
            ? L.text("settings.data.erase.warning.cloud")
            : L.text("settings.data.erase.warning.local")
    }

    // MARK: - 購入 (M5 contract §4.3)

    private var access: AccessState { store.snapshot.access }

    /// 現在のプラン / the date row / 「購読する」 (read only) / サブスクリプションを管理 / 購入を復元, the
    /// footer (`purchaseFooter`) and the last result (`store.snapshot.message`, red when it failed).
    private var purchaseSection: some View {
        let eligible = store.snapshot.offers.first?.isEligibleForIntroOffer ?? false
        let restoring = store.snapshot.phase == .restoring
        let busy = store.snapshot.phase != .idle && store.snapshot.phase != .loadingProducts
        return Section {
            HStack {
                Text(L.text("settings.purchase.plan"))
                Spacer()
                Text(Self.planText(access))
                    .foregroundStyle(Self.planIsProblem(access) ? Color.red : Color.secondary)
                    .multilineTextAlignment(.trailing)
            }
            .id(Self.purchaseRowId)
            if let label = Self.dateLabel(access), let until = access.until {
                HStack {
                    Text(label)
                    Spacer()
                    Text(Self.dateText(until))
                        .foregroundStyle(.secondary)
                }
            }
            if let title = Self.purchaseButtonTitle(access, eligible: eligible) {
                Button(title, action: onShowPaywall)
            }
            // Also while read only: the place to check a cancelled subscription (M5-21).
            Button(L.text("settings.purchase.manage")) {
                guard !ScreenshotMode.isActive else { return }
                showManage = true
            }
            Button(action: restore) {
                if restoring {
                    ProgressView()
                } else {
                    Text(L.text("settings.purchase.restore"))
                }
            }
            .disabled(busy)
        } header: {
            Text(L.text("settings.purchase.header"))
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.purchaseFooter(access))
                if let message = store.snapshot.message {
                    Text(StoreStrings.text(for: message, access: access))
                        .foregroundStyle(Self.isFailure(message) ? Color.red : Color.secondary)
                }
            }
        }
    }

    private func restore() {
        Task { await store.restore() }
    }

    // MARK: - 情報

    private var infoSection: some View {
        Section {
            Link(L.text("settings.info.terms"), destination: LegalLinks.terms(for: L.language))
            Link(L.text("settings.info.privacy"), destination: LegalLinks.privacy(for: L.language))
            Link(LegalLinks.appleEULATitle(L.language), destination: LegalLinks.appleEULA)
            Link(L.text("settings.info.support"), destination: LegalLinks.support(for: L.language))
            // 1.2 (§5.7, §5.9): above 「バージョン」, which stays the scroll target of the `info` photo.
            NavigationLink(L.text("settings.info.licenses")) { LicenseScreen() }
            versionRow
                .id(Self.infoRowId)
            // 1.1 (§5.3): counted on this device, before the read cap; 「数えています…」 until done.
            countRow(Self.largestPageTitle, StrokeCensus.rowText(census?.largest, counting: census == nil))
            countRow(Self.yearPageTitle, StrokeCensus.yearRowText(census?.year, year: currentYear, counting: census == nil))
            #if SPAN_PROTOTYPE
            // 1.3 (docs/M7C_CONTRACT.md §4.6, D12): 「横につなげる試作」, the prototype build's last row only.
            SpanPrototypeEntryRow()
            #endif
        } header: {
            Text(L.text("settings.info.header"))
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.infoFooter)
                if let note = Self.translationNote() {
                    Text(note)
                }
            }
        }
    }

    /// 「バージョン」. 1.1 fix (docs/M7A.md ずれ 46): where `InkTrace.isAvailable` (the sandbox receipt: a
    /// TestFlight build, and also Xcode's, the simulator's and App Review's), holding it opens 「記録」
    /// (`InkTrace`); in an App Store build and in screenshot mode it is the plain row it always was.
    @ViewBuilder
    private var versionRow: some View {
        let row = HStack {
            Text(L.text("settings.info.version"))
            Spacer()
            Text(Self.versionText)
                .foregroundStyle(.secondary)
        }
        if InkTrace.isAvailable {
            row
                .contentShape(Rectangle())
                .onLongPressGesture { showTrace = true }
        } else {
            row
        }
    }

    /// A two-line row: the title, and the value under it (footnote, secondary).
    private func countRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(value)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// The year of 「今年の年のページ」 (the fixed 「今日」 in screenshot mode).
    private var currentYear: Int {
        DayKey(ScreenshotMode.current?.today ?? Date()).year
    }

    /// Counts the pages of this device (`StrokeCensus.run`, in the background; nil when the sheet
    /// closed first, then nothing changes). Screenshot mode shows the demo pages' counts.
    private func countStrokes() async {
        if ScreenshotMode.isActive {
            census = StrokeCensus.demo(year: currentYear)
            return
        }
        guard let result = await StrokeCensus.run(store: sync.store, year: currentYear) else { return }
        census = result
    }

    /// 1.2 (§7.4, §10.7): what `--screenshot-sheet holidays` and `week-start` show over this screen, once
    /// the form is on screen. Nothing is stored; the week start's answer goes through `onScreenshotWeekStart`.
    private func openScreenshotPieces() async {
        guard let sheet = ScreenshotMode.current?.sheet, sheet == .holidays || sheet == .weekStart else { return }
        try? await Task.sleep(for: .seconds(0.4))
        switch sheet {
        case .holidays:
            showHolidayPicker = true
        case .weekStart:
            pendingWeekStart = screenshotWeekStart == .monday ? .sunday : .monday
        default:
            break
        }
    }

    private func openSettingsApp() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

// MARK: - 購入 の純関数 (M5 contract §4.3, §7.6)

extension SettingsScreen {
    /// 「現在のプラン」の値（`PlanText.statusTitle`）
    static func planText(_ access: AccessState) -> String {
        PlanText.statusTitle(access, language: L.language)
    }

    /// 日付行のラベル（readOnly は nil。`PlanText.dateLabel`）
    static func dateLabel(_ access: AccessState) -> String? {
        PlanText.dateLabel(access, language: L.language)
    }

    /// 「2026/10/25」 in ja_JP (numeric date, no time, the Gregorian calendar whatever the device's: 0-11,
    /// 0-33). `locale` is an argument so the CI's English locale can be overridden in the tests.
    static func dateText(_ date: Date, locale: Locale = L.locale) -> String {
        DateText.numericDate(date, UILanguage.resolve(locale.identifier), region: locale.region?.identifier)
    }

    /// The value of 「現在のプラン」 is red while the payment is the problem: `.billingRetry` and `inGrace`.
    static func planIsProblem(_ access: AccessState) -> Bool {
        switch access {
        case .subscribed(let subscription): return subscription.inGrace
        case .trial: return false
        case .readOnly(let reason): return reason == .billingRetry
        }
    }

    /// The footer of 「購入」: how to cancel (plus the trial's reassurance), the payment problem
    /// while in grace, or the read-only reason and what read only still allows.
    static func purchaseFooter(_ access: AccessState) -> String {
        switch access {
        case .subscribed(let subscription):
            if subscription.inGrace {
                return L.format("settings.purchase.footer.grace", PlanText.paymentPath(language: L.language))
            }
            return L.format("settings.purchase.footer.cancel", PlanText.cancelPath(language: L.language))
        case .trial:
            return L.format("settings.purchase.footer.trial", PlanText.cancelPath(language: L.language))
        case .readOnly(let reason):
            return L.format("settings.purchase.footer.readOnly", PlanText.readOnlyNote(reason, language: L.language))
        }
    }

    /// 「購読する」 / 「14 日間無料で試す」 while read only; nil otherwise (no row).
    static func purchaseButtonTitle(_ access: AccessState, eligible: Bool) -> String? {
        guard !access.canEdit else { return nil }
        return eligible
            ? L.plural("settings.purchase.trial", count: ProductIDs.trialDays, DateText.number(ProductIDs.trialDays, L.language))
            : L.text("settings.purchase.subscribe")
    }

    /// Red under the footer.
    static func isFailure(_ message: StoreMessage) -> Bool {
        if case .failed = message { return true }
        return false
    }
}
