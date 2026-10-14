import Foundation
import CoreGraphics

/// The event a rect (a lasso's bounding box, the 予定 tool's drag rect) stands for: the result of the
/// web version's rectToEventRange (M3B_CONTRACT §1.1). An all-day range ends at the next day's 0:00
/// (exclusive, as `LayoutEvent`). A timed range lies within one day (`end` is at most that day's
/// 24:00 = the next day's 0:00).
public struct EventRange: Equatable, Sendable {
    public var start: Date
    public var end: Date
    public var allDay: Bool

    public init(start: Date, end: Date, allDay: Bool) {
        self.start = start
        self.end = end
        self.allDay = allDay
    }

    /// `end > start`.
    public var isValid: Bool {
        end > start
    }

    /// One all-day day: `start` = the day's 0:00, `end` = the next day's 0:00.
    public static func allDay(_ day: DayKey, calendar: Calendar = DayKey.deviceCalendar) -> EventRange {
        EventRange(start: day.startOfDay(in: calendar), end: day.adding(days: 1).startOfDay(in: calendar), allDay: true)
    }

    /// Minutes `startMinute`…`endMinute` of `day` (wall-clock; 1440 is the next day's 0:00).
    public static func timed(_ day: DayKey, startMinute: Int, endMinute: Int, calendar: Calendar = DayKey.deviceCalendar) -> EventRange {
        EventRange(
            start: date(day, minute: startMinute, calendar: calendar),
            end: date(day, minute: endMinute, calendar: calendar),
            allDay: false
        )
    }

    /// Local wall-clock time `minute` minutes into `day` (clamped to 0…1440; 1440 = the next day's
    /// 0:00), like the web version's atMinutes. Wall-clock, not elapsed time, so the hour grid stays
    /// right on a DST day.
    static func date(_ day: DayKey, minute: Int, calendar: Calendar) -> Date {
        let m = min(max(minute, 0), EventGeometry.dayMinutes)
        if m >= EventGeometry.dayMinutes { return day.adding(days: 1).startOfDay(in: calendar) }
        var c = DateComponents()
        c.year = day.year
        c.month = day.month
        c.day = day.day
        c.hour = m / 60
        c.minute = m % 60
        return calendar.date(from: c) ?? day.startOfDay(in: calendar).addingTimeInterval(TimeInterval(m * 60))
    }
}

/// The rounding rules of the web version's page-geometry.js (SPEC §3), as pure functions.
public enum EventGeometry {
    /// A rect shorter than this is a tap (lu).
    public static let tapMaxHeight: CGFloat = 12
    /// A drag shorter than this becomes one hour (minutes).
    public static let minDragMinutes = 30
    /// Length of a tap or a short drag (minutes).
    public static let defaultDurationMinutes = 60
    public static let dayMinutes = 1440

    public enum Rounding: Sendable {
        case nearest, floor, ceil
    }

    /// The web version's roundMinutes: `q = minutes / step`; when `|q − round(q)| < 1e-9` the result is
    /// `round(q) × step` whatever the mode (floating-point noise never moves a line); otherwise the mode
    /// decides. `.nearest` rounds 0.5 up (JS Math.round; only `minutes ≥ 0` is used).
    public static func roundMinutes(_ minutes: Double, step: Int, _ mode: Rounding = .nearest) -> Int {
        guard minutes.isFinite else { return 0 }
        guard step > 0 else { return Int(minutes.rounded()) }
        let s = Double(step)
        let q = minutes / s
        let nearest = (q + 0.5).rounded(.down)
        if abs(q - nearest) < 1e-9 { return Int(nearest) * step }
        switch mode {
        case .nearest: return Int(nearest) * step
        case .floor: return Int(q.rounded(.down)) * step
        case .ceil: return Int(q.rounded(.up)) * step
        }
    }

    /// `y` (lu, 0 = the time axis's 0:00) → minutes, clamped to [0, 1440]; NaN → 0 (web yToMinutes).
    public static func minutes(forY y: CGFloat, hourHeight: CGFloat) -> Double {
        let raw = Double(y) * 60 / Double(hourHeight)
        return Double(LayoutMath.clamp(CGFloat(raw), 0, CGFloat(dayMinutes)))
    }

    /// The minutes a rect on the time axis means (the minute part of the web version's
    /// timelineSlotForRect; `minY` / `maxY` are lu with the axis's 0:00 at 0):
    /// - height < 12 → a tap: `start = floor30(minutes(centerY))`, `end = start + 60`;
    /// - else `start = round15(minutes(minY))`, `end = round15(minutes(maxY))`, and `end = start + 60`
    ///   when `end − start < 30`;
    /// - then `end = min(end, 1440)`, and `start = max(0, end − 60)` when `end ≤ start`.
    public static func timelineSlot(minY: CGFloat, maxY: CGFloat, hourHeight: CGFloat) -> (startMinute: Int, endMinute: Int) {
        let lo = min(minY, maxY)
        let hi = max(minY, maxY)
        var start: Int
        var end: Int
        if hi - lo < tapMaxHeight {
            start = roundMinutes(minutes(forY: (lo + hi) / 2, hourHeight: hourHeight), step: 30, .floor)
            end = start + defaultDurationMinutes
        } else {
            start = roundMinutes(minutes(forY: lo, hourHeight: hourHeight), step: 15)
            end = roundMinutes(minutes(forY: hi, hourHeight: hourHeight), step: 15)
            if end - start < minDragMinutes { end = start + defaultDurationMinutes }
        }
        end = min(end, dayMinutes)
        if end <= start { start = max(0, end - defaultDurationMinutes) }
        return (start, end)
    }

    /// The rect with `min ≤ max` on both axes (a drag in the reverse direction has a negative size);
    /// nil when any coordinate is not finite.
    public static func normalized(_ rect: CGRect) -> CGRect? {
        guard rect.origin.x.isFinite, rect.origin.y.isFinite, rect.size.width.isFinite, rect.size.height.isFinite else { return nil }
        return rect.standardized
    }
}

// MARK: - PageLayout: rect → event, event → rect (M3B_CONTRACT §1.2)

extension PageLayout {
    /// `eventRange(for:now:calendar:)` in the device calendar.
    public func eventRange(for rect: CGRect, now: Date) -> EventRange? {
        eventRange(for: rect, now: now, calendar: DayKey.deviceCalendar)
    }

    /// `snapRect(for:calendar:)` in the device calendar.
    public func snapRect(for range: EventRange) -> CGRect? {
        snapRect(for: range, calendar: DayKey.deviceCalendar)
    }

    /// The paper rect the event made from `rect` would occupy (the 予定 tool's live preview):
    /// `snapRect(for: eventRange(for: rect))`.
    public func previewRect(for rect: CGRect, now: Date, calendar: Calendar = DayKey.deviceCalendar) -> CGRect? {
        guard let range = eventRange(for: rect, now: now, calendar: calendar) else { return nil }
        return snapRect(for: range, calendar: calendar)
    }
}
