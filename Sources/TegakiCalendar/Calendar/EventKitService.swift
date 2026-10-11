import Combine
import CoreGraphics
import EventKit
import Foundation

/// A calendar event in the shape the screens need (a thin, immutable copy of an EKEvent).
struct CalendarEvent: Identifiable {
    /// Unique per occurrence (EventKit reuses `eventIdentifier` for every occurrence of a recurring event).
    let id: String
    let title: String
    let start: Date
    /// EventKit convention: for all-day events `end` is the end of the last day (inclusive),
    /// unlike the web version where the all-day end is the exclusive next midnight.
    let end: Date
    let isAllDay: Bool
    let calendarTitle: String
    /// Calendar colour (EventKit has no per-event colour).
    let color: CGColor?
}

/// Reads events from the iOS calendar database (every account the person added in
/// Settings > Calendar, Google included) through EventKit. No Google API is involved.
@MainActor
final class EventKitService: ObservableObject {
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

    @Published private(set) var accessState: AccessState
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var lastError: String?

    private let store = EKEventStore()

    init() {
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
        accessState = Self.accessState(from: EKEventStore.authorizationStatus(for: .event))
    }

    /// Loads the events of every calendar that start before `end` and end after `start`
    /// (all-day events included), sorted all-day first, then by start time.
    func loadEvents(from start: Date, to end: Date) {
        guard accessState.canRead else {
            events = []
            return
        }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let found = store.events(matching: predicate)
        events = found.map(Self.makeEvent).sorted { a, b in
            if a.isAllDay != b.isAllDay { return a.isAllDay }
            if a.start != b.start { return a.start < b.start }
            return a.title < b.title
        }
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

    private static func makeEvent(_ event: EKEvent) -> CalendarEvent {
        let start = event.startDate ?? Date()
        let end = event.endDate ?? start
        let baseIdentifier = event.eventIdentifier ?? event.calendarItemIdentifier
        let title = (event.title ?? "").isEmpty ? "（無題）" : (event.title ?? "")
        return CalendarEvent(
            id: "\(baseIdentifier)@\(Int(start.timeIntervalSince1970))",
            title: title,
            start: start,
            end: end,
            isAllDay: event.isAllDay,
            calendarTitle: event.calendar?.title ?? "",
            color: event.calendar?.cgColor
        )
    }
}
