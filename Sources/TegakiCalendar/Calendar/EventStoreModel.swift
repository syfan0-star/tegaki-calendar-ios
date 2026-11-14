import Combine
import EventKit
import Foundation
import Layout

/// A snapshot of one loaded event for the sheets (contract §5, M3b §4.1).
struct EventDetail: Identifiable, Equatable {
    var id: String
    /// The event's own title (may be empty; the layout shows 「（無題）」 for it).
    var title: String
    var allDay: Bool
    var start: Date
    /// All-day: exclusive next midnight (same as `LayoutEvent`).
    var end: Date
    var calendarId: String
    var calendarTitle: String
    var colorHex: String
    var location: String?
    var notes: String?
    var url: URL?
    /// `hasRecurrenceRules || isDetached` (DESIGN §4.6).
    var isRecurring: Bool
    /// `calendar.allowsContentModifications`.
    var isEditable: Bool
}

/// The screen's view of the calendar (contract §5): permission status, the events of the shown
/// page (normalised), the calendars and which of them the person hid; since M3b also the calendar
/// options for the sheets and the settings, the default calendar, and the writes.
///
/// Reloads when EventKit reports a change (`.EKEventStoreChanged`, debounced 1 s — DESIGN §4.2).
@MainActor
final class EventStoreModel: ObservableObject {
    typealias AccessStatus = EventKitService.AccessState

    @Published private(set) var status: AccessStatus
    @Published private(set) var events: [LayoutEvent] = []
    @Published private(set) var calendars: [EKCalendar] = []
    /// 1.3 (wave C, the lead's decision C3-m8): moves on at the end of every `reload()` (whatever way it ends), so the
    /// screen's joined path reads the events of its window again (`SpanSession.reloadEvents`) after a change of the
    /// calendar, a calendar shown or hidden, a permission change or a write; the screen remembers the value after
    /// opening a window, so the `load` of the opening does not read them twice.
    @Published private(set) var revision = 0
    /// Calendars the person turned off (persisted in UserDefaults). Changing it reloads the page.
    @Published var hiddenCalendarIds: Set<String> {
        didSet {
            guard hiddenCalendarIds != oldValue else { return }
            defaults.set(Array(hiddenCalendarIds).sorted(), forKey: Self.hiddenKey)
            reload()
        }
    }
    /// The page whose events are loaded (`PageNavigation.dayRange(kind, focus:, weekStart:)`).
    private(set) var kind: PageKind?
    private(set) var focus: DayKey?
    /// 1.2 (§10.5): the week start of the page: the days of a week page and of a month grid follow it.
    private(set) var weekStart: WeekStart = .monday

    let service: EventKitService
    private let defaults: UserDefaults
    private var cancellables: Set<AnyCancellable> = []
    /// CI screenshot mode (`ScreenshotMode`): demo events instead of EventKit, no permission request.
    private let screenshot: Bool

    static let hiddenKey = AppSettings.hiddenCalendarIdsKey
    /// The demo calendar new events go to in screenshot mode (a plain constant: tests read it too).
    nonisolated static let demoDefaultCalendarId = "demo-personal"

    /// - Parameter service: the EventKit wrapper; nil = a fresh one (made here, on the main actor,
    ///   because a default argument expression is not actor-isolated).
    /// - Parameter screenshot: 1.3 (the lead's decision 8 of wave C1, docs/M7C.md): the process's screenshot mode by
    ///   default, as in 1.2.3; the unit tests pass true to read the demo month (`ScreenshotMode.current` is fixed by the
    ///   launch arguments) and false for the host's own calendar access.
    init(service: EventKitService? = nil, defaults: UserDefaults = .standard, screenshot: Bool = ScreenshotMode.isActive) {
        let service = service ?? EventKitService()
        self.service = service
        self.defaults = defaults
        self.screenshot = screenshot
        status = screenshot ? .fullAccess : service.accessState
        if !screenshot, let stored = defaults.array(forKey: Self.hiddenKey) as? [String] {
            hiddenCalendarIds = Set(stored)
        } else {
            hiddenCalendarIds = []
        }

        NotificationCenter.default.publisher(for: .EKEventStoreChanged, object: nil)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)
    }

    // MARK: - Permission

    /// Asks for full access (after the onboarding explanation, DESIGN §4.1), then loads.
    func requestAccess() async {
        guard !screenshot else { return }
        await service.requestAccess()
        status = service.accessState
        reload()
    }

    /// Re-reads the permission (e.g. after the Settings app) and reloads if it changed.
    func refreshStatus() {
        guard !screenshot else { return }
        service.refreshAccessState()
        if status != service.accessState {
            status = service.accessState
            reload()
        }
    }

    // MARK: - Loading

    /// Loads the events of the page `(kind, focus)` from the visible calendars: one day, the week's
    /// 7 days, the month grid's 42 days, or the year's 365 / 366 days (all-day events only). The days
    /// of the week and the month are those of `weekStart` (1.2, D15: the screen always passes it).
    func load(kind: PageKind, focus: DayKey, weekStart: WeekStart) {
        self.kind = kind
        self.focus = focus
        self.weekStart = weekStart
        reload()
    }

    /// Re-fetches the current page (after a change notification, a permission change, a calendar
    /// being hidden/shown, or one of the writes below).
    func reload() {
        defer { revision &+= 1 }
        guard status.canRead, let kind = kind, let focus = focus else {
            events = []
            calendars = []
            return
        }
        if screenshot {
            // The demo month whatever the range; the engines keep what overlaps the page.
            let month = ScreenshotMode.current?.month ?? YearMonth(year: focus.year, month: focus.month)
            events = ScreenshotMode.demoEvents(for: month)
            calendars = []
            return
        }
        let all = service.calendars
        calendars = all
        if defaults.object(forKey: Self.hiddenKey) == nil {
            // First time with access: hide holiday and birthday calendars (DESIGN §4.3). Setting the
            // property persists it and calls `reload()` again, so stop here.
            let initial = service.defaultHiddenCalendarIds()
            if !initial.isEmpty {
                hiddenCalendarIds = initial
                return
            }
            defaults.set([String](), forKey: Self.hiddenKey)
        }
        let visible = all.filter { !hiddenCalendarIds.contains($0.calendarIdentifier) }
        let range = PageNavigation.dayRange(kind, focus: focus, weekStart: weekStart)
        events = service.events(from: range.start, to: range.end, calendars: visible, allDayOnly: kind == .year)
    }

    /// 1.3 (docs/M7C_CONTRACT.md §3.8; wave C §7.4): the events of the days [start, end) of one page of a joined window
    /// (`SpanSession.eventSource`; the session cuts the queries under four years): from the visible calendars, nothing
    /// without read access, and in screenshot mode the demo month's events that touch the days. The EKEvents stay
    /// known next to the shown page's (`EventKitService.events(…, keepingEarlier: true)`), so the event of any page of
    /// the window opens in the sheet and can be edited. The shown page's own `events` and `load` are not touched.
    func events(from start: DayKey, to end: DayKey) -> [LayoutEvent] {
        guard status.canRead else { return [] }
        if screenshot {
            let month = ScreenshotMode.current?.month ?? YearMonth(year: start.year, month: start.month)
            let from = start.startOfDay()
            let until = end.startOfDay()
            _ = (from, until)
            return ScreenshotMode.demoEvents(for: month)
        }
        let visible = service.calendars.filter { !hiddenCalendarIds.contains($0.calendarIdentifier) }
        return service.events(from: start, to: end, calendars: visible, keepingEarlier: true)
    }

    // MARK: - Calendars (settings, sheets)

    func isHidden(_ calendar: EKCalendar) -> Bool {
        hiddenCalendarIds.contains(calendar.calendarIdentifier)
    }

    func isHidden(calendarId: String) -> Bool {
        hiddenCalendarIds.contains(calendarId)
    }

    func setHidden(_ hidden: Bool, calendar: EKCalendar) {
        setHidden(hidden, calendarId: calendar.calendarIdentifier)
    }

    func setHidden(_ hidden: Bool, calendarId: String) {
        if hidden {
            hiddenCalendarIds.insert(calendarId)
        } else {
            hiddenCalendarIds.remove(calendarId)
        }
    }

    /// Every calendar as the settings screen and the sheets show it (grouping by `sourceTitle` is the
    /// screen's job). Screenshot mode: the four demo calendars, all writable, source 「見本」.
    var calendarOptions: [CalendarOption] {
        if screenshot { return ScreenshotMode.calendarOptions }
        return calendars.map { CalendarOption(calendar: $0) }
    }

    /// The calendars new events can go to.
    var writableCalendarOptions: [CalendarOption] {
        calendarOptions.filter { $0.acceptsNewEvents }
    }

    /// Where a new event goes: `AppSettings.defaultCalendarId` when it is still writable, else the
    /// store's default for new events (`service.calendarForNewEvents(preferredId: nil)`); nil without
    /// any writable calendar. Screenshot mode: "demo-personal".
    var defaultCalendarId: String? {
        if screenshot { return Self.demoDefaultCalendarId }
        let writable = writableCalendarOptions
        if let stored = AppSettings.defaultCalendarId, writable.contains(where: { $0.id == stored }) {
            return stored
        }
        return service.calendarForNewEvents(preferredId: nil)?.calendarIdentifier
    }

    /// Remembers the calendar new events go to (UserDefaults; not in screenshot mode).
    func setDefaultCalendarId(_ id: String?) {
        guard !screenshot else { return }
        AppSettings.defaultCalendarId = id
        objectWillChange.send()
    }

    // MARK: - Writes (M3b contract §4.1)

    /// Creates the event, then reloads the page without waiting for `EKEventStoreChanged`.
    /// Screenshot mode: does nothing and succeeds.
    func create(_ draft: EventDraft) throws {
        guard !screenshot else { return }
        try service.create(draft)
        reload()
    }

    func update(eventId: String, with draft: EventDraft, span: EventSpan) throws {
        guard !screenshot else { return }
        try service.update(eventId: eventId, with: draft, span: span)
        reload()
    }

    func delete(eventId: String, span: EventSpan) throws {
        guard !screenshot else { return }
        try service.delete(eventId: eventId, span: span)
        reload()
    }

    func isRecurring(eventId: String) -> Bool {
        screenshot ? false : service.isRecurring(eventId: eventId)
    }

    /// Screenshot mode: every demo event is editable.
    func isEditable(eventId: String) -> Bool {
        screenshot ? true : service.isEditable(eventId: eventId)
    }

    // MARK: - Details

    /// The loaded event with this id (an all-day bar's or a timed chip's `eventId`).
    func layoutEvent(id: String) -> LayoutEvent? {
        events.first { $0.id == id }
    }

    /// 1.3: `layoutEvent(id:)`, else the event among `others` (the joined window's pages, wave C §7.4).
    func layoutEvent(id: String, among others: [LayoutEvent]) -> LayoutEvent? {
        layoutEvent(id: id)
    }

    /// Loaded events that touch `day` (all-day events spanning it included), in layout order.
    func events(on day: DayKey) -> [LayoutEvent] {
        let dayStart = day.startOfDay()
        let dayEnd = day.adding(days: 1).startOfDay()
        return events.filter { $0.start < dayEnd && $0.end > dayStart }
    }

    /// A snapshot of the event for the sheets; nil when it is no longer loaded. 1.3 (wave C §7.4): an event of
    /// another page of the joined window is found in `others` (the default, none, is 1.2.3's lookup).
    func detail(forEventId id: String, among others: [LayoutEvent] = []) -> EventDetail? {
        guard let layoutEvent = layoutEvent(id: id, among: others) else { return nil }
        let ekEvent = service.event(withLayoutId: id)
        let location = ekEvent?.location?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = ekEvent?.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        // The sheet edits the event's own title: an untitled event stays empty there, not 「（無題）」.
        let title = ekEvent.map { ($0.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines) } ?? layoutEvent.title
        let calendarTitle: String
        if let ekTitle = ekEvent?.calendar?.title {
            calendarTitle = ekTitle
        } else if screenshot {
            calendarTitle = ScreenshotMode.calendarTitle(forCalendarId: layoutEvent.calendarId)
        } else {
            calendarTitle = ""
        }
        return EventDetail(
            id: id,
            title: title,
            allDay: layoutEvent.allDay,
            start: layoutEvent.start,
            end: layoutEvent.end,
            calendarId: layoutEvent.calendarId,
            calendarTitle: calendarTitle,
            colorHex: layoutEvent.colorHex,
            location: (location ?? "").isEmpty ? nil : location,
            notes: (notes ?? "").isEmpty ? nil : notes,
            url: ekEvent?.url,
            isRecurring: isRecurring(eventId: id),
            isEditable: isEditable(eventId: id)
        )
    }
}
