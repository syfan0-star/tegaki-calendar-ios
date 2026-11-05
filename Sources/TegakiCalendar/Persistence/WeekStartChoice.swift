import Foundation
import InkModel
import Layout

/// Whether this device's weeks start on Monday or Sunday (1.2, O-2, K-11, docs/M7B_CONTRACT.md §10.3,
/// §10.4): the setting `weekStart.setting` (per device, D16, 0-45), what "auto" gives, and the one
/// comparison with the pages iCloud brought. **The only app file that reads a region's first day of the
/// week** (lint L-14). The layouts take the result as an input (D15).
///
/// Everything that decides here is a pure function or works on a `UserDefaults` it is given, so the
/// tests can call it without the screen. What must keep its order lives in
/// `CalendarRootScreen.weekStartSwitch` (§10.5).
enum WeekStartChoice {
    enum Setting: String, CaseIterable { case auto, monday, sunday }

    /// The week start in force, for what runs away from the view's body: the export and the PDF read it
    /// (`ExportBuilder`, `PDFPageRenderer`). `prepareAtLaunch` sets it, and every switch. A view's body
    /// reads `CalendarRootScreen`'s `@State weekStart` (§10.5).
    @MainActor static var current: WeekStart = .monday

    /// The setting on this device. Missing or broken is Monday: strokes stay where they are (§10.3).
    static func setting(_ defaults: UserDefaults = AppSettings.defaults) -> Setting {
        defaults.string(forKey: AppSettings.weekStartKey).flatMap(Setting.init(rawValue:)) ?? .monday
    }

    /// §10.3, steps 1 to 3: decided once, on the first launch that has no record. Someone who used an
    /// earlier version (any of the three keys) stays on Monday, wherever they live; someone new gets
    /// "auto". **Both are written**, as in `HolidayChoice.migrateIfNeeded`. Not called in screenshot mode.
    static func migrateIfNeeded(_ defaults: UserDefaults = AppSettings.defaults) {
        guard defaults.object(forKey: AppSettings.weekStartKey) == nil else { return }
        let value: Setting = AppSettings.isExistingUser(defaults) ? .monday : .auto
        defaults.set(value.rawValue, forKey: AppSettings.weekStartKey)
    }

    /// What "auto" gives on this launch: read once, like `L.language`, so it does not change while the
    /// app runs (0-44). `Locale.current.firstDayOfWeek` follows the device's own override too.
    static let launchAutomatic: WeekStart = WeekStart.automatic(
        region: Locale.current.region?.identifier,
        firstDayOfWeek: Locale.current.firstDayOfWeek
    )

    /// The week start of `setting`. The app always calls this one.
    static func resolve(_ setting: Setting) -> WeekStart {
        switch setting {
        case .auto: return launchAutomatic
        case .monday: return .monday
        case .sunday: return .sunday
        }
    }

    /// The same with the region given (the tests).
    static func resolve(setting: Setting, region: String?, firstDayOfWeek: Locale.Weekday) -> WeekStart {
        switch setting {
        case .auto: return WeekStart.automatic(region: region, firstDayOfWeek: firstDayOfWeek)
        case .monday: return .monday
        case .sunday: return .sunday
        }
    }

    /// `CalendarRootScreen.init`, once: the migration, the value, and `current` set to it (§5.6, §10.5: a
    /// Sunday person who exports a PDF right after launch would otherwise get the drawing of 11/1 under
    /// the title 10/26–11/1). Screenshot mode does not migrate and reads no memory: `Config.weekStart`.
    @MainActor static func prepareAtLaunch(shot: ScreenshotMode.Config?, _ defaults: UserDefaults = AppSettings.defaults) -> WeekStart {
        let value: WeekStart
        if let shot {
            value = shot.weekStart
        } else {
            migrateIfNeeded(defaults)
            value = resolve(setting(defaults))
        }
        current = value
        return value
    }

    /// §10.3: remembers what "auto" gives on this launch and returns it when it differs from the last
    /// launch's while the setting is "auto" (the region changed: never silently, a toast says so). The
    /// first time, and with a chosen week start, it only remembers, so going back to "auto" later says
    /// nothing about a change the person saw in the row.
    static func regionChange(automatic: WeekStart, _ defaults: UserDefaults = AppSettings.defaults) -> WeekStart? {
        let last = defaults.string(forKey: AppSettings.weekStartLastAutoKey).flatMap(WeekStart.init(rawValue:))
        defaults.set(automatic.rawValue, forKey: AppSettings.weekStartLastAutoKey)
        guard setting(defaults) == .auto, let last, last != automatic else { return nil }
        return automatic
    }

    /// §10.3, step 4: only an automatic week start that was not compared yet is compared at all. A chosen
    /// one never changes by itself, so someone who used an earlier version ("monday") never adopts (J-9).
    static func needsDataCheck(setting: Setting, dataChecked: Bool) -> Bool {
        setting == .auto && !dataChecked
    }

    /// What the person chose on the settings screen (§10.4). The comparison ends here, whatever the choice:
    /// someone from an earlier version is on "monday" with `dataChecked` still false, so choosing 自動 and
    /// answering the question would otherwise be taken back by the next sync (`.adopt` to the form of the
    /// pages they already have). The mark goes first: the record's `.onChange` must find it set.
    static func choose(_ setting: Setting, _ defaults: UserDefaults = AppSettings.defaults) {
        defaults.set(true, forKey: AppSettings.weekStartDataCheckedKey)
        defaults.set(setting.rawValue, forKey: AppSettings.weekStartKey)
    }

    /// §10.3, step 4 (1): one pull has finished. `.synced` alone is not enough: `.pushOnly` never pulls, so
    /// after a failed pull a stroke's push can reach `.synced` with the other device's pages still
    /// unseen. `lastSyncAt` is no mark either (a push writes it too); `zoneToken` is written only by the
    /// pull and the erase (`testPushOnlyLeavesNoZoneToken`).
    static func readyToCheck(status: SyncStatus, zoneToken: Data?) -> Bool {
        status == .synced && zoneToken != nil
    }

    /// §10.3, 4 (1), §10.5: an import of the app's own file is when someone without iCloud is compared,
    /// since no pull ever comes for them. Someone with iCloud is compared after the first pull, not
    /// before: an import while offline must not use up the one comparison before the other device's
    /// pages arrived. `.unknown` and `.notAuthenticated` are passing states of someone with iCloud, like
    /// offline, so they wait too. A web import is not asked: it always lands on Monday pages (§10.2).
    static func checksAfterImport(status: SyncStatus, zoneToken: Data?, isAppExport: Bool) -> Bool {
        guard isAppExport else { return false }
        switch status {
        case .localOnly(.noAccount), .localOnly(.restricted): return true
        case .localOnly: return false
        default: return readyToCheck(status: status, zoneToken: zoneToken)
        }
    }

    /// What the comparison says (§10.3, step 4).
    enum DataCheck: Equatable {
        /// It should adopt, but the person is writing: nothing is written; asked again at the next `show`
        /// or `.active` (`atBoundary`).
        case wait
        /// No week page, or only the current form: nothing to tell.
        case finish
        /// Take this form. `otherPages` > 0: that many pages of the form looked at until now.
        case adopt(WeekStart, otherPages: Int)
        /// Stay. `otherPages` pages of the other form exist; say so.
        case stay(otherPages: Int)
    }

    /// §10.3, step 4 (2) and (3), for a setting of "auto" that was not compared yet. `pageIds` are the
    /// ids on this device (`sync.allLocalPageIds()`; no file is read), `dirtyPageId` the shown page while
    /// it is not saved (a new page is not in `pageIds` yet, and it is of the current form), `penTouched`
    /// that the pen touched the paper since launch. Switching changes the canvas's id, which loses a
    /// stroke in progress, and the last 1.5 s of ink would be saved to the other form's page, so `.adopt`
    /// waits while the person is writing, until `atBoundary` (just saved, the page is about to change).
    /// `.finish` and `.stay` switch nothing, so they never wait.
    static func dataCheck(current: WeekStart, pageIds: [String], dirtyPageId: String?, penTouched: Bool, atBoundary: Bool) -> DataCheck {
        var ids = pageIds
        if let dirtyPageId, !ids.contains(dirtyPageId) { ids.append(dirtyPageId) }
        let pages = WeekStartImpact.weekPages(ids)
        let here = current == .monday ? pages.monday : pages.sunday
        let there = current == .monday ? pages.sunday : pages.monday
        if there == 0 { return .finish }
        guard there > here else { return .stay(otherPages: there) }
        if !atBoundary, dirtyPageId != nil || penTouched { return .wait }
        return .adopt(current == .monday ? .sunday : .monday, otherPages: here)
    }

    /// §10.5: the form an import's sentence names: the other form when any of the imported pages is of
    /// it (`import.otherWeekStart.*`), else nil. Called with the week start after the comparison, so the
    /// sentence and the setting agree.
    static func otherForm(amongPageIds pageIds: [String], current: WeekStart) -> WeekStart? {
        let pages = WeekStartImpact.weekPages(pageIds)
        switch current {
        case .monday: return pages.sunday > 0 ? .sunday : nil
        case .sunday: return pages.monday > 0 ? .monday : nil
        }
    }

    /// The name of `weekStart` as the setting's rows and the sentences say it.
    static func name(_ weekStart: WeekStart) -> String {
        switch weekStart {
        case .monday: return L.text("settings.weekStart.monday")
        case .sunday: return L.text("settings.weekStart.sunday")
        }
    }
}

/// A toast about the week start waiting to be shown (§10.4).
enum WeekStartNotice: Equatable {
    /// The month page `pageId` has `strokes` strokes on days the current week start does not show (D17).
    case hiddenInk(pageId: String, strokes: Int)
    /// The week start was set to match the iCloud handwriting.
    case adopted(WeekStart)
    /// The week start was set to match the device's new region.
    case regionChanged(WeekStart)
    /// `pages` week pages of this other form exist.
    case otherForm(WeekStart, pages: Int)

    /// The toast's sentence. Numbers are written first (D5). `testWeekStartToastsFitThreeLines` measures
    /// the ten languages through the keys.
    var text: String {
        switch self {
        case .hiddenInk(_, let strokes):
            return L.plural("toast.weekStart.hiddenInk", count: strokes, DateText.number(strokes, L.language))
        case .adopted(.monday):
            return L.text("toast.weekStart.adopted.monday")
        case .adopted(.sunday):
            return L.text("toast.weekStart.adopted.sunday")
        case .regionChanged(.monday):
            return L.text("toast.weekStart.regionChanged.monday")
        case .regionChanged(.sunday):
            return L.text("toast.weekStart.regionChanged.sunday")
        case .otherForm(let form, let pages):
            return L.plural("toast.weekStart.otherForm", count: pages, WeekStartChoice.name(form), DateText.number(pages, L.language))
        }
    }
}

/// The toasts waiting (§10.4). A switch happens under the settings sheet, and the first launch's under the
/// onboarding and the paywall; a toast shown there is lost behind the sheet, and a page's hidden
/// strokes would count as told about. So nothing is shown directly: the screen adds here and takes one
/// whenever it could be seen. A plain value, so the tests can call it.
struct WeekStartNotices {
    private var waiting: [WeekStartNotice] = []

    /// Adds one, unless the same one is waiting; the same page's hidden strokes keep the newer count.
    mutating func add(_ notice: WeekStartNotice) {
        if case .hiddenInk(let id, _) = notice {
            waiting.removeAll {
                if case .hiddenInk(let other, _) = $0 { return other == id }
                return false
            }
        }
        guard !waiting.contains(notice) else { return }
        waiting.append(notice)
    }

    /// Forgets the hidden strokes waiting to be told: `show` judges the shown page again. A month page
    /// keeps its id in both forms, so a count made under the other week start would otherwise survive a
    /// switch and be told, wrongly, under this one.
    mutating func dropHiddenInk() {
        waiting.removeAll {
            if case .hiddenInk = $0 { return true }
            return false
        }
    }

    /// One notice, the oldest, when it could be seen now: no sheet is up and no toast is showing. A
    /// page's hidden strokes for another page than the one shown are dropped (it is judged again when
    /// that page is opened).
    mutating func next(sheetIsUp: Bool, toastShowing: Bool, currentPageId: String) -> WeekStartNotice? {
        guard !sheetIsUp, !toastShowing else { return nil }
        while !waiting.isEmpty {
            let notice = waiting.removeFirst()
            if case .hiddenInk(let id, _) = notice, id != currentPageId { continue }
            return notice
        }
        return nil
    }
}
