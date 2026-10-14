import EventKit
import Foundation
import Layout

/// What the event sheet edits (M3b contract §4.1; the web version's EventInput). An all-day
/// draft's `end` is the **exclusive next midnight**, like `LayoutEvent`; `EventKitService.apply`
/// turns it into EventKit's "end of the last day" when saving.
struct EventDraft: Equatable {
    var title: String
    var allDay: Bool
    var start: Date
    var end: Date
    /// The calendar to create the event in (create), or the event's calendar (edit; never changed).
    var calendarId: String
    var location: String
    var notes: String

    init(title: String = "", allDay: Bool, start: Date, end: Date, calendarId: String, location: String = "", notes: String = "") {
        self.title = title
        self.allDay = allDay
        self.start = start
        self.end = end
        self.calendarId = calendarId
        self.location = location
        self.notes = notes
    }

    /// An empty draft for the range the page geometry produced (予定 tool, 投げなわ, ＋予定).
    init(range: EventRange, calendarId: String) {
        self.init(allDay: range.allDay, start: range.start, end: range.end, calendarId: calendarId)
    }

    /// The initial values of the edit sheet.
    init(detail: EventDetail) {
        self.init(
            title: detail.title,
            allDay: detail.allDay,
            start: detail.start,
            end: detail.end,
            calendarId: detail.calendarId,
            location: detail.location ?? "",
            notes: detail.notes ?? ""
        )
    }
}

/// How far a change to a recurring event reaches (DESIGN §4.6).
enum EventSpan: Equatable {
    case thisEvent
    case futureEvents

    var ekSpan: EKSpan {
        switch self {
        case .thisEvent: return .thisEvent
        case .futureEvents: return .futureEvents
        }
    }
}

/// A failed write. `errorDescription` is Japanese and is shown as it is (toast, sheet footer).
enum EventWriteError: LocalizedError, Equatable {
    case noAccess
    case noWritableCalendar
    case calendarNotFound
    case readOnlyCalendar
    case eventNotFound
    case invalidRange
    /// EventKit's own message.
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .noAccess: return "カレンダーへのアクセスが許可されていません"
        case .noWritableCalendar: return "予定を登録できるカレンダーがありません"
        case .calendarNotFound: return "登録先のカレンダーが見つかりません"
        case .readOnlyCalendar: return "このカレンダーは変更できません"
        case .eventNotFound: return "予定が見つかりません（別の端末で削除されたかもしれません）"
        case .invalidRange: return "終了は開始より後にしてください"
        case .failed(let message): return "保存できませんでした: \(message)"
        }
    }
}

/// A calendar as the settings screen and the sheets show it: a thin copy of `EKCalendar`
/// (demo values in screenshot mode).
struct CalendarOption: Identifiable, Equatable {
    /// `calendarIdentifier`
    var id: String
    var title: String
    /// "#rrggbb"
    var colorHex: String
    /// `EKSource.title` (「iCloud」「Gmail」…); 「見本」 for the demo calendars.
    var sourceTitle: String
    /// `allowsContentModifications`
    var isWritable: Bool
    /// `type == .subscription`
    var isSubscribed: Bool
    /// `type == .birthday`
    var isBirthday: Bool

    init(id: String, title: String, colorHex: String, sourceTitle: String, isWritable: Bool, isSubscribed: Bool, isBirthday: Bool) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
        self.sourceTitle = sourceTitle
        self.isWritable = isWritable
        self.isSubscribed = isSubscribed
        self.isBirthday = isBirthday
    }

    init(calendar: EKCalendar) {
        self.init(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            colorHex: EventKitService.hexString(from: calendar.cgColor),
            sourceTitle: calendar.source?.title ?? "",
            isWritable: calendar.allowsContentModifications,
            isSubscribed: calendar.type == .subscription,
            isBirthday: calendar.type == .birthday
        )
    }

    /// Writable and able to receive new events (no birthday or subscribed calendar).
    var acceptsNewEvents: Bool {
        isWritable && !isSubscribed && !isBirthday
    }
}
