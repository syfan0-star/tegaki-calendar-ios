import Foundation
import Layout

/// A validation failure of the event sheet (M3b contract §4.3). `errorDescription` is the Japanese
/// text shown under the field.
enum EventFormError: Equatable, LocalizedError {
    case emptyTitle
    case endBeforeStart
    case endDayBeforeStart

    var errorDescription: String? {
        switch self {
        case .emptyTitle: return "タイトルを入力してください"
        case .endBeforeStart: return "終了は開始より後にしてください"
        case .endDayBeforeStart: return "終了日は開始日以降にしてください"
        }
    }
}

/// The pure state of the event sheet (M3b contract §4.3): the same rules as the web version's
/// event-dialog.js (`formFromInput` / `inputFromForm` / `toggleAllDay` / `moveStart` / `moveEnd`).
///
/// - All-day: `startDay`…`endDay`, the end day **inclusive** (what the pickers show); the draft's end
///   is the exclusive next midnight.
/// - Timed: `startDay` + `startMinute` … `endDay` + `endMinute` (wall-clock minutes 0…1439). The
///   minutes are kept while the form is all-day, so switching back restores them.
/// - A start change keeps the duration (minutes, or whole days); an end not after the start is
///   corrected (timed: start + 1 h; all-day: the start day).
struct EventEditorForm: Equatable {
    var title: String
    var location: String
    var notes: String
    var allDay: Bool
    var startDay: DayKey
    var endDay: DayKey
    var startMinute: Int
    var endMinute: Int
    /// The calendar that turns days + minutes into instants (the device calendar in the app).
    var calendar: Calendar

    static let defaultStartMinute = 9 * 60
    static let defaultEndMinute = 10 * 60
    static let hourSeconds: TimeInterval = 3600

    /// All-day: `endDay` = the day before the exclusive end (an end that is not a midnight still
    /// covers its own day; an end not after the start → the start day). Timed: `end ≤ start` → start + 1 h.
    init(draft: EventDraft, calendar: Calendar = DayKey.deviceCalendar) {
        self.calendar = calendar
        title = draft.title
        location = draft.location
        notes = draft.notes
        allDay = draft.allDay
        if draft.allDay {
            let first = DayKey(draft.start, calendar: calendar)
            var last = DayKey(draft.end.addingTimeInterval(-1), calendar: calendar)
            if last < first { last = first }
            startDay = first
            endDay = last
            startMinute = Self.defaultStartMinute
            endMinute = Self.defaultEndMinute
        } else {
            let start = draft.start
            var end = draft.end
            if end <= start { end = start.addingTimeInterval(Self.hourSeconds) }
            startDay = DayKey(start, calendar: calendar)
            startMinute = Self.minutes(of: start, calendar: calendar)
            endDay = DayKey(end, calendar: calendar)
            endMinute = Self.minutes(of: end, calendar: calendar)
        }
    }

    // MARK: Instants

    /// Timed: the start instant. All-day: the start day's 0:00.
    var start: Date {
        allDay ? startDay.startOfDay(in: calendar) : Self.date(startDay, minute: startMinute, calendar: calendar)
    }

    /// Timed: the end instant. All-day: the exclusive next midnight after `endDay`.
    var end: Date {
        allDay ? endDay.adding(days: 1).startOfDay(in: calendar) : Self.date(endDay, minute: endMinute, calendar: calendar)
    }

    /// What the 終了日 / 終了 picker shows: the inclusive last day at 0:00 (all-day) or `end`.
    var endPickerDate: Date {
        allDay ? endDay.startOfDay(in: calendar) : end
    }

    // MARK: Draft

    /// Form → draft with validation (web `inputFromForm`). The title and location are trimmed, the
    /// notes lose their trailing whitespace. The all-day end is the exclusive next midnight.
    func draft(calendarId: String, calendar override: Calendar? = nil) -> Result<EventDraft, EventFormError> {
        let calendar = override ?? self.calendar
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty { return .failure(.emptyTitle) }
        let start: Date
        let end: Date
        if allDay {
            if endDay < startDay { return .failure(.endDayBeforeStart) }
            start = startDay.startOfDay(in: calendar)
            end = endDay.adding(days: 1).startOfDay(in: calendar)
        } else {
            start = Self.date(startDay, minute: startMinute, calendar: calendar)
            end = Self.date(endDay, minute: endMinute, calendar: calendar)
            if end <= start { return .failure(.endBeforeStart) }
        }
        return .success(EventDraft(
            title: trimmedTitle,
            allDay: allDay,
            start: start,
            end: end,
            calendarId: calendarId,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: Self.trimmingTrailingWhitespace(notes)
        ))
    }

    // MARK: Edits

    /// 終日 on/off (web `toggleAllDay`). Timed → all-day: the last day is the day of the end instant,
    /// except that an end exactly at a midnight after the start does not touch that day (23:00〜翌 0:00
    /// is a one-day event). All-day → timed: the remembered minutes on the start day; end ≤ start → +1 h.
    mutating func setAllDay(_ on: Bool) {
        guard on != allDay else { return }
        if on {
            let s = start
            let e = end
            var last = DayKey(e, calendar: calendar)
            if e == last.startOfDay(in: calendar), e > s {
                last = last.adding(days: -1)
            }
            if last < startDay { last = startDay }
            allDay = true
            endDay = last
        } else {
            allDay = false
            let s = Self.date(startDay, minute: startMinute, calendar: calendar)
            var e = Self.date(startDay, minute: endMinute, calendar: calendar)
            if e <= s { e = s.addingTimeInterval(Self.hourSeconds) }
            endDay = DayKey(e, calendar: calendar)
            endMinute = Self.minutes(of: e, calendar: calendar)
        }
    }

    /// Moves the start and **keeps the duration** (timed: the minutes; all-day: the whole days).
    mutating func setStart(_ date: Date) {
        if allDay {
            let days = endDay >= startDay ? endDay.dayNumber - startDay.dayNumber : 0
            let first = DayKey(date, calendar: calendar)
            startDay = first
            endDay = first.adding(days: days)
        } else {
            let oldStart = start
            let oldEnd = end
            let duration = oldEnd > oldStart ? oldEnd.timeIntervalSince(oldStart) : Self.hourSeconds
            startDay = DayKey(date, calendar: calendar)
            startMinute = Self.minutes(of: date, calendar: calendar)
            // Re-derive the end from the minute-aligned start (a picker may hand over seconds).
            let newEnd = start.addingTimeInterval(duration)
            endDay = DayKey(newEnd, calendar: calendar)
            endMinute = Self.minutes(of: newEnd, calendar: calendar)
        }
    }

    /// Sets the end; an end not after the start is corrected (timed: start + 1 h; all-day: the
    /// inclusive end day becomes the start day).
    mutating func setEnd(_ date: Date) {
        if allDay {
            let last = DayKey(date, calendar: calendar)
            endDay = last < startDay ? startDay : last
        } else {
            endDay = DayKey(date, calendar: calendar)
            endMinute = Self.minutes(of: date, calendar: calendar)
            if end <= start {
                let corrected = start.addingTimeInterval(Self.hourSeconds)
                endDay = DayKey(corrected, calendar: calendar)
                endMinute = Self.minutes(of: corrected, calendar: calendar)
            }
        }
    }

    // MARK: Helpers

    /// Wall-clock minutes of the day (0…1439).
    static func minutes(of date: Date, calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Wall-clock `minute` minutes into `day` (1440 and beyond roll into the next day).
    static func date(_ day: DayKey, minute: Int, calendar: Calendar) -> Date {
        let m = max(0, minute)
        let d = day.adding(days: m / 1440)
        let rest = m % 1440
        var c = DateComponents()
        c.year = d.year
        c.month = d.month
        c.day = d.day
        c.hour = rest / 60
        c.minute = rest % 60
        return calendar.date(from: c) ?? d.startOfDay(in: calendar).addingTimeInterval(TimeInterval(rest * 60))
    }

    /// Drops whitespace and newlines at the end only (web `description.replace(/\s+$/, '')`).
    static func trimmingTrailingWhitespace(_ text: String) -> String {
        var scalars = Substring(text)
        while let last = scalars.last, last.isWhitespace || last.isNewline {
            scalars.removeLast()
        }
        return String(scalars)
    }
}
