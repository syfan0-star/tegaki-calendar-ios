import Foundation
import CoreGraphics
import Holidays

/// Pure layout of the month page (DESIGN §2.2, M2_CONTRACT §1). No UI, no global state.
public enum MonthLayoutEngine {
    // MARK: - Row height

    /// Height of a week row (DESIGN §2.2):
    /// `min(1200, max(175, 28 + lanes×25 + maxChips×20 + 40, inkBottom + 12))`.
    public static func rowHeight(laneCount: Int, maxChips: Int, inkBottom: CGFloat) -> CGFloat {
        let lanes = CGFloat(max(0, laneCount))
        let chips = CGFloat(max(0, maxChips))
        let content = PaperSpec.monthDateHeader
            + lanes * PaperSpec.allDayLaneStep
            + chips * PaperSpec.timedChip
            + PaperSpec.monthInkMargin
        let ink = sanitized(inkBottom) + PaperSpec.inkPad
        let height = max(PaperSpec.monthRowBase, max(content, ink))
        return min(PaperSpec.monthRowMax, height)
    }

    /// Height of the memo area: `max(700, inkBottom + 50)`.
    public static func memoHeight(inkBottom: CGFloat) -> CGFloat {
        max(PaperSpec.memoMin, sanitized(inkBottom) + PaperSpec.memoInkPad)
    }

    /// Number of chips shown for `count` timed events on one day: all of them up to the cap,
    /// otherwise `cap − 1` events plus the 「+n件」 chip.
    public static func shownChipCount(for count: Int) -> (shown: Int, more: Int) {
        let n = max(0, count)
        let cap = PaperSpec.timedChipCap
        if n <= cap { return (n, 0) }
        let shown = cap - 1
        return (shown, n - shown)
    }

    private static func sanitized(_ v: CGFloat) -> CGFloat {
        v.isFinite ? max(0, v) : 0
    }

    // MARK: - Layout

    public static func layout(_ input: MonthLayoutInput) -> MonthPageLayout {
        let calendar = input.calendar
        let grid = MonthLayout.grid(for: input.month)
        let today = DayKey(input.now, calendar: calendar)
        let holidayNames = JapaneseHolidays.names(for: grid.days)
        let allDayEvents = input.events.filter { $0.allDay }
        let timedEvents = input.events.filter { !$0.allDay }

        var rows: [RowLayout] = []
        var cells: [CellKey: CGRect] = [:]
        var bars: [AllDayBar] = []
        var chips: [TimedChip] = []
        var labels: [DateLabel] = []
        var y: CGFloat = 0

        for (rowIndex, days) in grid.allRows.enumerated() {
            let spans = packAllDayLanes(events: allDayEvents, days: days, calendar: calendar)
            let laneCount = spans.reduce(0) { max($0, $1.lane + 1) }

            // Timed events per day, in display order.
            var perDay: [[LayoutEvent]] = []
            var maxChips = 0
            for day in days {
                let dayStart = day.startOfDay(in: calendar)
                let dayEnd = day.adding(days: 1).startOfDay(in: calendar)
                let onDay = timedEvents
                    .filter { $0.overlaps(dayStart, dayEnd) }
                    .sorted { compareEvents($0, $1) < 0 }
                perDay.append(onDay)
                let (shown, more) = shownChipCount(for: onDay.count)
                maxChips = max(maxChips, shown + (more > 0 ? 1 : 0))
            }

            var inkBottom: CGFloat = 0
            for day in days {
                inkBottom = max(inkBottom, sanitized(input.inkBottoms[.day(day)] ?? 0))
            }

            let height = rowHeight(laneCount: laneCount, maxChips: maxChips, inkBottom: inkBottom)
            let frame = CGRect(x: 0, y: y, width: PaperSpec.monthWidth, height: height)
            rows.append(RowLayout(index: rowIndex, frame: frame, days: days, laneCount: laneCount, maxChips: maxChips))

            let rowFirstDay = days[0]
            let rowLastDay = days[days.count - 1]
            let rowStart = rowFirstDay.startOfDay(in: calendar)
            let rowEnd = rowLastDay.adding(days: 1).startOfDay(in: calendar)

            for (col, day) in days.enumerated() {
                let x = CGFloat(col) * PaperSpec.monthColumnWidth
                cells[.day(day)] = CGRect(x: x, y: y, width: PaperSpec.monthColumnWidth, height: height)

                let holiday = holidayNames[day]
                let tone: DayTone
                if holiday != nil || day.weekday == 0 {
                    tone = .sundayOrHoliday
                } else if day.weekday == 6 {
                    tone = .saturday
                } else {
                    tone = .normal
                }
                labels.append(DateLabel(
                    day: day,
                    frame: CGRect(x: x + PaperSpec.cellInset, y: y + 4, width: PaperSpec.monthColumnWidth - 2 * PaperSpec.cellInset, height: 24),
                    isToday: day == today,
                    inMonth: input.month.contains(day),
                    tone: tone,
                    holidayName: holiday
                ))

                let onDay = perDay[col]
                let (shown, more) = shownChipCount(for: onDay.count)
                let chipTop = y + PaperSpec.monthDateHeader + CGFloat(laneCount) * PaperSpec.allDayLaneStep
                let dayStart = day.startOfDay(in: calendar)
                let dayEnd = day.adding(days: 1).startOfDay(in: calendar)
                for i in 0..<shown {
                    let event = onDay[i]
                    chips.append(TimedChip(
                        eventId: event.id,
                        frame: chipFrame(x: x, top: chipTop, index: i),
                        day: day,
                        timeText: timeText(for: event, dayStart: dayStart, dayEnd: dayEnd, calendar: calendar),
                        title: event.title,
                        colorHex: event.colorHex,
                        moreCount: 0
                    ))
                }
                if more > 0 {
                    chips.append(TimedChip(
                        eventId: nil,
                        frame: chipFrame(x: x, top: chipTop, index: shown),
                        day: day,
                        timeText: "",
                        title: "+\(more)件",
                        colorHex: "",
                        moreCount: more
                    ))
                }
            }

            for span in spans {
                let x = CGFloat(span.startCol) * PaperSpec.monthColumnWidth + PaperSpec.cellInset
                let width = CGFloat(span.endCol - span.startCol + 1) * PaperSpec.monthColumnWidth - 2 * PaperSpec.cellInset
                let barY = y + PaperSpec.monthDateHeader + CGFloat(span.lane) * PaperSpec.allDayLaneStep
                bars.append(AllDayBar(
                    eventId: span.event.id,
                    frame: CGRect(x: x, y: barY, width: width, height: PaperSpec.allDayLane),
                    row: rowIndex,
                    lane: span.lane,
                    continuesLeft: span.event.start < rowStart,
                    continuesRight: span.event.end > rowEnd,
                    colorHex: span.event.colorHex,
                    title: span.event.title
                ))
            }

            y += height
        }

        let memoHeight = memoHeight(inkBottom: input.inkBottoms[.memo] ?? 0)
        let memo = CGRect(x: 0, y: y, width: PaperSpec.monthWidth, height: memoHeight)
        cells[.memo] = memo

        return MonthPageLayout(
            size: CGSize(width: PaperSpec.monthWidth, height: y + memoHeight),
            rows: rows,
            memo: memo,
            cells: cells,
            allDayBars: bars,
            timedChips: chips,
            dateLabels: labels
        )
    }

    private static func chipFrame(x: CGFloat, top: CGFloat, index: Int) -> CGRect {
        CGRect(
            x: x + PaperSpec.cellInset,
            y: top + CGFloat(index) * PaperSpec.timedChip,
            width: PaperSpec.monthColumnWidth - 2 * PaperSpec.cellInset,
            height: PaperSpec.timedChip
        )
    }

    /// "9:00" for an event starting on the day; "〜11:00" for the tail of an overnight event ending on
    /// the day; "" when the event covers the whole day (same as the web version's chipTime).
    public static func timeText(for event: LayoutEvent, dayStart: Date, dayEnd: Date, calendar: Calendar) -> String {
        if event.start >= dayStart { return formatTime(event.start, calendar: calendar) }
        if event.end < dayEnd { return "〜" + formatTime(event.end, calendar: calendar) }
        return ""
    }

    /// "9:00", "13:05" (hour without a leading zero, as the web version's formatTimeJa).
    public static func formatTime(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let hour = c.hour ?? 0
        let minute = c.minute ?? 0
        return "\(hour):" + (minute < 10 ? "0\(minute)" : "\(minute)")
    }

    // MARK: - Ordering (web version event-layout.js)

    /// allDay first, then start, then longer first, then title, then id. Negative when a < b.
    public static func compareEvents(_ a: LayoutEvent, _ b: LayoutEvent) -> Int {
        if a.allDay != b.allDay { return a.allDay ? -1 : 1 }
        if a.start != b.start { return a.start < b.start ? -1 : 1 }
        if a.duration != b.duration { return a.duration > b.duration ? -1 : 1 }
        if a.title != b.title { return a.title < b.title ? -1 : 1 }
        if a.id != b.id { return a.id < b.id ? -1 : 1 }
        return 0
    }

    // MARK: - All-day lanes

    /// Packs the all-day events overlapping the consecutive `days` into lanes, like the web version's
    /// `allDayRowsForRange`: spans are clipped to the range (endCol inclusive), ordered by start column,
    /// then longer first, then `compareEvents`; each takes the lowest lane free over its whole span.
    /// The result is sorted by lane, then start column. Timed events are ignored.
    public static func packAllDayLanes(
        events: [LayoutEvent],
        days: [DayKey],
        calendar: Calendar = DayKey.deviceCalendar
    ) -> [(event: LayoutEvent, startCol: Int, endCol: Int, lane: Int)] {
        guard let first = days.first else { return [] }
        let lastCol = days.count - 1
        let rangeStart = first.startOfDay(in: calendar)
        let rangeEnd = first.adding(days: days.count).startOfDay(in: calendar)

        struct Span {
            var event: LayoutEvent
            var startCol: Int
            var endCol: Int
            var lane: Int
        }

        var spans: [Span] = []
        for event in events where event.allDay {
            guard event.overlaps(rangeStart, rangeEnd) else { continue }
            let startCol = max(0, DayKey(event.start, calendar: calendar).dayNumber - first.dayNumber)
            var endCol: Int
            if event.end <= event.start {
                endCol = startCol
            } else {
                // The last day is the one containing the instant just before the exclusive end.
                let lastInstant = event.end.addingTimeInterval(-0.001)
                endCol = min(lastCol, DayKey(lastInstant, calendar: calendar).dayNumber - first.dayNumber)
            }
            endCol = max(startCol, endCol)
            spans.append(Span(event: event, startCol: startCol, endCol: endCol, lane: 0))
        }

        spans.sort { p, q in
            if p.startCol != q.startCol { return p.startCol < q.startCol }
            let pl = p.endCol - p.startCol
            let ql = q.endCol - q.startCol
            if pl != ql { return pl > ql }
            return compareEvents(p.event, q.event) < 0
        }

        var laneEnds: [Int] = [] // per lane: endCol of the last span placed in it
        for i in spans.indices {
            if let lane = laneEnds.firstIndex(where: { $0 < spans[i].startCol }) {
                laneEnds[lane] = spans[i].endCol
                spans[i].lane = lane
            } else {
                spans[i].lane = laneEnds.count
                laneEnds.append(spans[i].endCol)
            }
        }

        spans.sort { p, q in
            if p.lane != q.lane { return p.lane < q.lane }
            return p.startCol < q.startCol
        }
        return spans.map { ($0.event, $0.startCol, $0.endCol, $0.lane) }
    }

    // MARK: - Scroll correction (DESIGN §3.5)

    /// How far (paper lu) the content under `topVisibleY` moved between two layouts: the row (or the
    /// memo area) containing that y in `old` keeps its on-screen position when the caller adds the
    /// result to `contentOffset.y` (× zoomScale). 0 when nothing moved or the point is above the paper.
    public static func scrollDelta(old: MonthPageLayout, new: MonthPageLayout, topVisibleY: CGFloat) -> CGFloat {
        guard topVisibleY.isFinite, topVisibleY >= 0 else { return 0 }
        // Since M3a the rule is the general one (PageScroll, M3A_CONTRACT §1.3); the M2 result is
        // kept for a point below the paper, which follows the memo area.
        if old.band(atY: topVisibleY) != nil {
            return PageScroll.scrollDelta(old: old, new: new, topVisibleY: topVisibleY)
        }
        return new.memo.minY - old.memo.minY
    }

    // MARK: - Cell coordinates (used by 担当 I to place strokes)

    /// Paper point of a cell's top-left corner; (0, 0) for an unknown cell.
    public static func paperPoint(of cell: CellKey, in layout: MonthPageLayout) -> CGPoint {
        layout.cells[cell]?.origin ?? .zero
    }

    /// Converts a paper point into coordinates relative to the cell's top-left corner.
    public static func cellRelative(_ p: CGPoint, cell: CellKey, in layout: MonthPageLayout) -> CGPoint {
        let origin = paperPoint(of: cell, in: layout)
        return CGPoint(x: p.x - origin.x, y: p.y - origin.y)
    }
}
