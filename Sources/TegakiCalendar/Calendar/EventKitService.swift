import CoreGraphics
import EventKit
import Foundation
import Layout

/// Reads events from the iOS calendar database (every account the person added in
/// Settings > Calendar, Google included) through EventKit and normalises them into the
/// `LayoutEvent` shape the Layout module expects (contract §5). No Google API is involved.
///
/// Normalisation (DESIGN §4.4): an all-day event's `end` becomes the *exclusive* midnight after its
/// last day (EventKit stores the end of the last day), colours are the calendar's colour as "#rrggbb",
/// and invitations the person declined are dropped.
@MainActor
final class EventKitService {
    enum AccessState: Equatable {
        case notDetermined
        case fullAccess
        /// iOS 17 "add only" permission: the app may create events but cannot read any.
        case writeOnly
        case denied
        /// Parental controls / device management forbid calendar access.
        case restricted

        var canRead: Bool { self == .fullAccess }
    }

    private(set) var accessState: AccessState
    private(set) var lastError: String?

    let store = EKEventStore()

    /// The EKEvent behind each `LayoutEvent.id` of the last fetch (for the detail sheet).
    private var fetched: [String: EKEvent] = [:]

    init() {
        accessState = Self.accessState(from: EKEventStore.authorizationStatus(for: .event))
    }

    /// Re-reads the authorisation status (e.g. after returning from the Settings app).
    func refreshAccessState() {
        accessState = Self.accessState(from: EKEventStore.authorizationStatus(for: .event))
    }

    /// Shows the system permission dialog (iOS 17 full-access API). Safe to call repeatedly:
    /// once the person has decided, iOS answers immediately without a dialog.
    func requestAccess() async {
        do {
            _ = try await store.requestFullAccessToEvents()
        } catch {
            lastError = error.localizedDescription
        }
        refreshAccessState()
    }

    // MARK: - Calendars

    /// Every event calendar, subscribed ones included, sorted by account then title.
    var calendars: [EKCalendar] {
        guard accessState.canRead else { return [] }
        return store.calendars(for: .event).sorted { a, b in
            let sa = a.source?.title ?? ""
            let sb = b.source?.title ?? ""
            if sa != sb { return sa < sb }
            return a.title < b.title
        }
    }

    /// Calendars hidden until the person turns them on (DESIGN §4.3): birthdays, and subscribed
    /// holiday calendars (the app draws Japanese holidays itself, so they would show twice).
    static func isHiddenByDefault(_ calendar: EKCalendar) -> Bool {
        if calendar.type == .birthday { return true }
        if calendar.type == .subscription {
            let title = calendar.title
            if title.contains("祝日") || title.lowercased().contains("holiday") { return true }
        }
        return false
    }

    /// The ids of the calendars hidden by default among the current ones.
    func defaultHiddenCalendarIds() -> Set<String> {
        Set(calendars.filter(Self.isHiddenByDefault).map { $0.calendarIdentifier })
    }

    // MARK: - Events

    /// Events of the 42 days of the month page (Monday-start grid), normalised for the Layout module
    /// and sorted all-day first, then by start, then by title. Empty without read access.
    ///
    /// - Parameter calendars: the calendars to read; nil = every calendar.
    func events(in month: YearMonth, calendars: [EKCalendar]?) -> [LayoutEvent] {
        guard accessState.canRead else {
            fetched = [:]
            return []
        }
        if let calendars = calendars, calendars.isEmpty {
            fetched = [:]
            return []
        }
        let grid = MonthLayout.grid(for: month)
        let start = grid.firstDay.startOfDay()
        let end = grid.firstDay.adding(days: MonthLayout.gridDayCount).startOfDay()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let found = store.events(matching: predicate)

        var map: [String: EKEvent] = [:]
        var result: [LayoutEvent] = []
        result.reserveCapacity(found.count)
        for event in found {
            guard let layoutEvent = Self.makeLayoutEvent(event) else { continue }
            if map[layoutEvent.id] != nil { continue } // the same occurrence twice (defensive)
            map[layoutEvent.id] = event
            result.append(layoutEvent)
        }
        fetched = map
        return result.sorted { a, b in
            if a.allDay != b.allDay { return a.allDay }
            if a.start != b.start { return a.start < b.start }
            return a.title < b.title
        }
    }

    /// The EKEvent of a `LayoutEvent.id` from the last `events(in:calendars:)` call.
    func event(withLayoutId id: String) -> EKEvent? {
        fetched[id]
    }

    // MARK: - Mapping

    private static func accessState(from status: EKAuthorizationStatus) -> AccessState {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .fullAccess: return .fullAccess
        case .writeOnly: return .writeOnly
        default: return .denied // `.authorized` (pre-iOS 17) and any future value
        }
    }

    /// Stable per-occurrence id: `calendarItemIdentifier` + the occurrence's start (DESIGN §4.6;
    /// `eventIdentifier` can change when the account syncs).
    static func layoutId(for event: EKEvent) -> String {
        let base = event.calendarItemIdentifier
        let occurrence = event.occurrenceDate ?? event.startDate ?? Date(timeIntervalSince1970: 0)
        return "\(base)@\(Int(occurrence.timeIntervalSince1970))"
    }

    /// nil for events that must not be shown (declined invitations, missing dates).
    static func makeLayoutEvent(_ event: EKEvent) -> LayoutEvent? {
        guard let startDate = event.startDate else { return nil }
        if isDeclined(event) { return nil }
        let endDate = event.endDate ?? startDate

        let start: Date
        let end: Date
        if event.isAllDay {
            start = DayKey(startDate).startOfDay()
            end = exclusiveAllDayEnd(start: start, eventEnd: endDate)
        } else {
            start = startDate
            end = max(endDate, startDate)
        }

        let rawTitle = (event.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return LayoutEvent(
            id: layoutId(for: event),
            title: rawTitle.isEmpty ? "（無題）" : rawTitle,
            allDay: event.isAllDay,
            start: start,
            end: end,
            colorHex: hexString(from: event.calendar?.cgColor),
            calendarId: event.calendar?.calendarIdentifier ?? ""
        )
    }

    /// EventKit's all-day end is the end of the last day (23:59:59); the layout wants the next
    /// midnight, exclusive. An end that already is a midnight after the start is kept as such.
    static func exclusiveAllDayEnd(start: Date, eventEnd: Date) -> Date {
        let endDay = DayKey(eventEnd)
        let endMidnight = endDay.startOfDay()
        let candidate: Date
        if eventEnd == endMidnight && eventEnd > start {
            candidate = eventEnd
        } else {
            candidate = endDay.adding(days: 1).startOfDay()
        }
        let minimum = DayKey(start).adding(days: 1).startOfDay()
        return max(candidate, minimum)
    }

    static func isDeclined(_ event: EKEvent) -> Bool {
        guard let attendees = event.attendees else { return false }
        for attendee in attendees where attendee.isCurrentUser {
            if attendee.participantStatus == .declined { return true }
        }
        return false
    }

    /// "#rrggbb" of a CGColor (converted to sRGB); the web version's fallback blue when unknown.
    static func hexString(from cgColor: CGColor?) -> String {
        let fallback = "#039be5"
        guard let cgColor = cgColor else { return fallback }
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)
        let converted: CGColor
        if let srgb = srgb, let c = cgColor.converted(to: srgb, intent: .defaultIntent, options: nil) {
            converted = c
        } else {
            converted = cgColor
        }
        guard let components = converted.components, !components.isEmpty else { return fallback }
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        if components.count >= 3 {
            r = components[0]; g = components[1]; b = components[2]
        } else {
            r = components[0]; g = components[0]; b = components[0]
        }
        func byte(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02x%02x%02x", byte(r), byte(g), byte(b))
    }
}
