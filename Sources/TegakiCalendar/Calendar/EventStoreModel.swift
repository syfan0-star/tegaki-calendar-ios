import Combine
import EventKit
import Foundation
import Layout

/// A read-only snapshot of one event for the detail sheet (contract §5, M2 is view only).
struct EventDetail: Identifiable, Equatable {
    var id: String
    var title: String
    var allDay: Bool
    var start: Date
    /// All-day: exclusive next midnight (same as `LayoutEvent`).
    var end: Date
    var calendarTitle: String
    var colorHex: String
    var location: String?
    var notes: String?
    var url: URL?
}

/// The screen's view of the calendar (contract §5): permission status, the events of the shown
/// page (normalised), the calendars and which of them the person hid.
///
/// Reloads when EventKit reports a change (`.EKEventStoreChanged`, debounced 1 s — DESIGN §4.2).
@MainActor
final class EventStoreModel: ObservableObject {
    typealias AccessStatus = EventKitService.AccessState

    @Published private(set) var status: AccessStatus
    @Published private(set) var events: [LayoutEvent] = []
    @Published private(set) var calendars: [EKCalendar] = []
    /// Calendars the person turned off (persisted in UserDefaults). Changing it reloads the page.
    @Published var hiddenCalendarIds: Set<String> {
        didSet {
            guard hiddenCalendarIds != oldValue else { return }
            defaults.set(Array(hiddenCalendarIds).sorted(), forKey: Self.hiddenKey)
            reload()
        }
    }
    /// The page whose events are loaded (`PageNavigation.dayRange(kind, focus:)`).
    private(set) var kind: PageKind?
    private(set) var focus: DayKey?

    let service: EventKitService
    private let defaults: UserDefaults
    private var cancellables: Set<AnyCancellable> = []
    /// CI screenshot mode (`ScreenshotMode`): demo events instead of EventKit, no permission request.
    private let screenshot: Bool

    static let hiddenKey = "hiddenCalendarIds"

    /// - Parameter service: the EventKit wrapper; nil = a fresh one (made here, on the main actor,
    ///   because a default argument expression is not actor-isolated).
    init(service: EventKitService? = nil, defaults: UserDefaults = .standard) {
        let service = service ?? EventKitService()
        self.service = service
        self.defaults = defaults
        screenshot = ScreenshotMode.isActive
        status = screenshot ? .fullAccess : service.accessState
        if let stored = defaults.array(forKey: Self.hiddenKey) as? [String] {
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
    /// 7 days, the month grid's 42 days, or the year's 365 / 366 days (all-day events only).
    func load(kind: PageKind, focus: DayKey) {
        self.kind = kind
        self.focus = focus
        reload()
    }

    /// Re-fetches the current page (after a change notification, a permission change, or a
    /// calendar being hidden/shown).
    func reload() {
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
        let range = PageNavigation.dayRange(kind, focus: focus)
        events = service.events(from: range.start, to: range.end, calendars: visible, allDayOnly: kind == .year)
    }

    // MARK: - Details

    func isHidden(_ calendar: EKCalendar) -> Bool {
        hiddenCalendarIds.contains(calendar.calendarIdentifier)
    }

    func setHidden(_ hidden: Bool, calendar: EKCalendar) {
        if hidden {
            hiddenCalendarIds.insert(calendar.calendarIdentifier)
        } else {
            hiddenCalendarIds.remove(calendar.calendarIdentifier)
        }
    }

    /// The loaded event with this id (an all-day bar's or a timed chip's `eventId`).
    func layoutEvent(id: String) -> LayoutEvent? {
        events.first { $0.id == id }
    }

    /// Loaded events that touch `day` (all-day events spanning it included), in layout order.
    func events(on day: DayKey) -> [LayoutEvent] {
        let dayStart = day.startOfDay()
        let dayEnd = day.adding(days: 1).startOfDay()
        return events.filter { $0.start < dayEnd && $0.end > dayStart }
    }

    /// A snapshot of the event for the detail sheet; nil when it is no longer loaded.
    func detail(forEventId id: String) -> EventDetail? {
        guard let layoutEvent = layoutEvent(id: id) else { return nil }
        let ekEvent = service.event(withLayoutId: id)
        let location = ekEvent?.location?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = ekEvent?.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        return EventDetail(
            id: id,
            title: layoutEvent.title,
            allDay: layoutEvent.allDay,
            start: layoutEvent.start,
            end: layoutEvent.end,
            calendarTitle: ekEvent?.calendar?.title ?? (screenshot ? ScreenshotMode.calendarTitle(forCalendarId: layoutEvent.calendarId) : ""),
            colorHex: layoutEvent.colorHex,
            location: (location ?? "").isEmpty ? nil : location,
            notes: (notes ?? "").isEmpty ? nil : notes,
            url: ekEvent?.url
        )
    }
}
