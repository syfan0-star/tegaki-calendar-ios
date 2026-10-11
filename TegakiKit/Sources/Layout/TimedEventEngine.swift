import Foundation
import CoreGraphics

/// One line of the web version's layoutTimedEvents: an event on one day with its visual minutes and
/// its overlap column.
public struct TimedSlot: Equatable, Sendable {
    public var event: LayoutEvent
    /// Visual minutes on the day (0…1440, at least 15 apart).
    public var startMinute: Int
    public var endMinute: Int
    /// Column (0-based) inside the cluster and the cluster's column count.
    public var column: Int
    public var columns: Int

    public init(event: LayoutEvent, startMinute: Int, endMinute: Int, column: Int, columns: Int) {
        self.event = event
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.column = column
        self.columns = columns
    }
}

/// Overlap layout of the timed events of one day (a port of the web version's event-layout.js
/// layoutTimedEvents) and the box geometry (view-common.js timedBoxRect). Pure.
public enum TimedEventEngine {
    public static let dayMinutes = 1440

    /// Wall-clock minutes of the day (hour × 60 + minute). They match the hour grid also on DST days.
    public static func minutesOfDay(_ date: Date, calendar: Calendar = DayKey.deviceCalendar) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// The visual [start, end] minutes of a timed event on `day` (web visualMinutes): clipped to the
    /// day, inverted / zero-length events occupy their start instant, and a box is at least 15
    /// minutes tall (near midnight the start moves up instead of overflowing 24:00).
    public static func visualMinutes(of event: LayoutEvent, day: DayKey, calendar: Calendar = DayKey.deviceCalendar) -> (start: Int, end: Int) {
        let dayStart = day.startOfDay(in: calendar)
        let dayEnd = day.adding(days: 1).startOfDay(in: calendar)
        return visualMinutes(of: event, dayStart: dayStart, dayEnd: dayEnd, calendar: calendar)
    }

    private static func visualMinutes(of event: LayoutEvent, dayStart: Date, dayEnd: Date, calendar: Calendar) -> (start: Int, end: Int) {
        var start = event.start <= dayStart ? 0 : minutesOfDay(event.start, calendar: calendar)
        var end: Int
        if event.end >= dayEnd {
            end = dayMinutes
        } else if event.end <= event.start {
            end = start
        } else {
            end = minutesOfDay(event.end, calendar: calendar)
        }
        start = min(max(start, 0), dayMinutes)
        end = max(end, start)
        let minimum = PaperSpec.timedMinVisualMinutes
        if end - start < minimum {
            end = min(dayMinutes, start + minimum)
            start = min(start, end - minimum)
        }
        return (start, end)
    }

    /// The timed (non-all-day) events overlapping `day`, in display order, packed into columns:
    /// sorted by start, then longer first, then real start, then title, then id; transitively
    /// overlapping events form a cluster that is packed greedily (each takes the first column that
    /// is free at its start); `columns` is the cluster's column count. Overlap is judged on the
    /// visual minutes, so boxes never collide on screen.
    public static func layout(events: [LayoutEvent], day: DayKey, calendar: Calendar = DayKey.deviceCalendar) -> [TimedSlot] {
        let dayStart = day.startOfDay(in: calendar)
        let dayEnd = day.adding(days: 1).startOfDay(in: calendar)
        guard dayEnd > dayStart else { return [] }

        var items: [TimedSlot] = []
        for event in events where !event.allDay && event.overlaps(dayStart, dayEnd) {
            let v = visualMinutes(of: event, dayStart: dayStart, dayEnd: dayEnd, calendar: calendar)
            items.append(TimedSlot(event: event, startMinute: v.start, endMinute: v.end, column: 0, columns: 1))
        }

        items.sort { p, q in
            if p.startMinute != q.startMinute { return p.startMinute < q.startMinute }
            if p.endMinute != q.endMinute { return p.endMinute > q.endMinute }
            if p.event.start != q.event.start { return p.event.start < q.event.start }
            if p.event.title != q.event.title { return p.event.title < q.event.title }
            return p.event.id < q.event.id
        }

        var cluster: [Int] = []          // indices of the open cluster
        var columnEnds: [Int] = []       // per column: endMinute of the last item placed in it
        var clusterEnd = Int.min         // max endMinute within the open cluster

        func closeCluster() {
            for i in cluster { items[i].columns = columnEnds.count }
            cluster = []
            columnEnds = []
            clusterEnd = Int.min
        }

        for i in items.indices {
            // Items are sorted by start, so one starting after everything so far ends the cluster.
            if !cluster.isEmpty && items[i].startMinute >= clusterEnd { closeCluster() }
            if let col = columnEnds.firstIndex(where: { $0 <= items[i].startMinute }) {
                columnEnds[col] = items[i].endMinute
                items[i].column = col
            } else {
                items[i].column = columnEnds.count
                columnEnds.append(items[i].endMinute)
            }
            cluster.append(i)
            clusterEnd = max(clusterEnd, items[i].endMinute)
        }
        if !cluster.isEmpty { closeCluster() }
        return items
    }

    /// Rect of a box inside a day column (web timedBoxRect). `y` counts from 0:00 of the column
    /// (the caller adds the grid's top). Overlapping events share the column width equally; the gap
    /// between them is dropped when the columns get very narrow; a vertical gap separates
    /// back-to-back boxes.
    public static func boxFrame(
        columnX: CGFloat,
        columnWidth: CGFloat,
        startMinute: Int,
        endMinute: Int,
        column: Int,
        columns: Int,
        hourHeight: CGFloat,
        padLeft: CGFloat,
        padRight: CGFloat,
        gap: CGFloat,
        verticalGap: CGFloat = PaperSpec.boxVerticalGap
    ) -> CGRect {
        let n = max(1, columns)
        let i = min(n - 1, max(0, column))
        let inner = max(1, columnWidth - padLeft - padRight)
        let g = inner / CGFloat(n) >= gap * 4 ? gap : 0
        let w = max(1, (inner - g * CGFloat(n - 1)) / CGFloat(n))
        let x = columnX + padLeft + CGFloat(i) * (w + g)
        let y0 = CGFloat(startMinute) * hourHeight / 60
        let y1 = CGFloat(endMinute) * hourHeight / 60
        let h = max(PaperSpec.boxMinHeight, y1 - y0 - verticalGap * 2)
        return CGRect(x: x, y: y0 + verticalGap, width: w, height: h)
    }

    /// "9:00" (= `MonthLayoutEngine.formatTime`, web formatTimeJa).
    public static func timeText(_ date: Date, calendar: Calendar = DayKey.deviceCalendar) -> String {
        MonthLayoutEngine.formatTime(date, calendar: calendar)
    }

    /// "9:00〜10:30" (web formatTimeRangeJa).
    public static func timeRangeText(start: Date, end: Date, calendar: Calendar = DayKey.deviceCalendar) -> String {
        timeText(start, calendar: calendar) + "〜" + timeText(end, calendar: calendar)
    }
}
