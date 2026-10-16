import Foundation
import CoreGraphics
import Holidays

/// One bar of the week / day page's fixed all-day band (M4B_CONTRACT §2.1). The band lives outside
/// the paper (a view under the sticky header, like the web version's .sh-allday and the iOS
/// Calendar app): `minX` / `maxX` are paper x (lu; the view applies the zoom and the horizontal
/// offset through `PaperViewport`), the vertical position is the lane and `AllDayBandMetrics` turns
/// it into points.
public struct AllDayBandBar: Equatable, Sendable, Identifiable {
    /// One bar per event in the band.
    public var id: String { eventId }
    public var eventId: String
    public var title: String
    public var colorHex: String
    /// 0-based.
    public var lane: Int
    /// Week 0…6, day 0.
    public var startCol: Int
    public var endCol: Int
    /// The event started before the band's range (square off the left end).
    public var continuesLeft: Bool
    /// The event continues after the band's range (square off the right end).
    public var continuesRight: Bool
    /// Paper x range (lu). Week: 64 + startCol × colW + 3 (0 when continuesLeft) …
    /// 64 + (endCol + 1) × colW − 3 (0 when continuesRight). Day: 72 + 4 … 660 − 12
    /// (`PaperSpec.dayChipPadLeft` / `dayChipPadRight`).
    public var minX: CGFloat
    public var maxX: CGFloat

    public init(eventId: String, title: String, colorHex: String, lane: Int, startCol: Int, endCol: Int, continuesLeft: Bool, continuesRight: Bool, minX: CGFloat, maxX: CGFloat) {
        self.eventId = eventId
        self.title = title
        self.colorHex = colorHex
        self.lane = lane
        self.startCol = startCol
        self.endCol = endCol
        self.continuesLeft = continuesLeft
        self.continuesRight = continuesRight
        self.minX = minX
        self.maxX = maxX
    }
}

/// The fixed all-day band of a week / day page: every number and colour class the band view needs
/// (M4B_CONTRACT §2.1). The view never judges weekdays or holidays itself: `tones` carries them.
public struct AllDayBandLayout: Equatable, Sendable {
    /// `.week` / `.day` only.
    public var kind: PageKind
    /// 7 days (Monday first) / 1 day.
    public var days: [DayKey]
    /// Colour class of each column (`LayoutMath.tone(of:holiday:)`, the same value as the paper's
    /// `DateLabel.tone`). 7 / 1 entries.
    public var tones: [DayTone]
    /// 1400 / 1000.
    public var paperWidth: CGFloat
    /// 64 / 72 (the width of the 「終日」 label).
    public var gutter: CGFloat
    /// Week: 64 + i × colW (7 entries). Day: [72].
    public var columnMinX: [CGFloat]
    /// 190.857… / 588.
    public var columnWidth: CGFloat
    public var laneCount: Int
    /// Ordered by lane, then start column.
    public var bars: [AllDayBandBar]
    /// Today's column (for the column tint).
    public var todayColumn: Int?

    public init(kind: PageKind, days: [DayKey], tones: [DayTone], paperWidth: CGFloat, gutter: CGFloat, columnMinX: [CGFloat], columnWidth: CGFloat, laneCount: Int, bars: [AllDayBandBar], todayColumn: Int?) {
        self.kind = kind
        self.days = days
        self.tones = tones
        self.paperWidth = paperWidth
        self.gutter = gutter
        self.columnMinX = columnMinX
        self.columnWidth = columnWidth
        self.laneCount = laneCount
        self.bars = bars
        self.todayColumn = todayColumn
    }

    /// A band without bars (and without a today column); `tones` are computed from `days`. The
    /// geometry is the day page's for `.day`, the week page's for every other kind.
    public static func empty(kind: PageKind, days: [DayKey]) -> AllDayBandLayout {
        let holidays = JapaneseHolidays.names(for: days)
        let tones = days.map { LayoutMath.tone(of: $0, holiday: holidays[$0]) }
        if kind == .day {
            return AllDayBandLayout(
                kind: .day,
                days: days,
                tones: tones,
                paperWidth: PaperSpec.dayWidth,
                gutter: PaperSpec.dayGutter,
                columnMinX: days.map { _ in PaperSpec.dayGutter },
                columnWidth: PaperSpec.dayTimelineRight - PaperSpec.dayGutter,
                laneCount: 0,
                bars: [],
                todayColumn: nil
            )
        }
        return AllDayBandLayout(
            kind: kind,
            days: days,
            tones: tones,
            paperWidth: PaperSpec.weekWidth,
            gutter: PaperSpec.weekGutter,
            columnMinX: days.indices.map { PaperSpec.weekGutter + CGFloat($0) * PaperSpec.weekColumnWidth },
            columnWidth: PaperSpec.weekColumnWidth,
            laneCount: 0,
            bars: [],
            todayColumn: nil
        )
    }

    /// The day of the band column under paper x (lu; M4C_CONTRACT §4.3, the double tap on the fixed
    /// band): nil left of the first column (the 「終日」 gutter, x < columnMinX[0]), right of the paper
    /// (x > paperWidth) or for a non-finite x; else `days[min(days.count − 1, floor((x −
    /// columnMinX[0]) / columnWidth))]`, so x == paperWidth is the last column (the day page's one
    /// column is [72]). The floor allows 1e-9 of noise like `WeekPageLayout.column(atX:)`, so a
    /// column boundary maps to its own column.
    public func day(atPaperX x: CGFloat) -> DayKey? {
        guard x.isFinite, let first = columnMinX.first, !days.isEmpty, columnWidth > 0 else { return nil }
        guard x >= first, x <= paperWidth else { return nil }
        let index = Int(floor((x - first) / columnWidth + 1e-9))
        return days[min(days.count - 1, max(0, index))]
    }
}

/// Pure layout of the fixed all-day band (M4B_CONTRACT §2.1).
public enum AllDayBandEngine {
    /// The week's band: `MonthLayoutEngine.packAllDayLanes` over the 7 days (the web version's
    /// allDayRowsForRange), one bar per span. No thinning: the lane count is unbounded and the view
    /// scrolls inside the band past 35 % of the page. `monday` is normalized like `WeekLayoutInput`.
    public static func week(monday: DayKey, events: [LayoutEvent], now: Date, calendar: Calendar = DayKey.deviceCalendar) -> AllDayBandLayout {
        let first = MonthLayout.mondayOnOrBefore(monday)
        let days = (0..<PaperSpec.weekColumns).map { first.adding(days: $0) }
        var band = AllDayBandLayout.empty(kind: .week, days: days)
        let colW = PaperSpec.weekColumnWidth
        let gutter = PaperSpec.weekGutter
        let weekStart = first.startOfDay(in: calendar)
        let weekEnd = first.adding(days: PaperSpec.weekColumns).startOfDay(in: calendar)
        let spans = MonthLayoutEngine.packAllDayLanes(events: events, days: days, calendar: calendar)
        var bars: [AllDayBandBar] = []
        for span in spans {
            let left = span.event.start < weekStart
            let right = span.event.end > weekEnd
            bars.append(AllDayBandBar(
                eventId: span.event.id,
                title: span.event.title,
                colorHex: span.event.colorHex,
                lane: span.lane,
                startCol: span.startCol,
                endCol: span.endCol,
                continuesLeft: left,
                continuesRight: right,
                minX: gutter + CGFloat(span.startCol) * colW + (left ? 0 : PaperSpec.weekBarInset),
                maxX: gutter + CGFloat(span.endCol + 1) * colW - (right ? 0 : PaperSpec.weekBarInset)
            ))
        }
        band.bars = bars
        band.laneCount = spans.reduce(0) { max($0, $1.lane + 1) }
        band.todayColumn = days.firstIndex(of: DayKey(now, calendar: calendar))
        return band
    }

    /// One day's band: every all-day event gets its own lane, in `eventsOnDay` order (earlier start
    /// first, then longer, then title, then id: the order of the former `DayLayoutEngine` chips).
    public static func day(_ day: DayKey, events: [LayoutEvent], now: Date, calendar: Calendar = DayKey.deviceCalendar) -> AllDayBandLayout {
        var band = AllDayBandLayout.empty(kind: .day, days: [day])
        let dayStart = day.startOfDay(in: calendar)
        let dayEnd = day.adding(days: 1).startOfDay(in: calendar)
        let spans = MonthLayoutEngine.packAllDayLanes(events: events, days: [day], calendar: calendar)
        var bars: [AllDayBandBar] = []
        for span in spans {
            bars.append(AllDayBandBar(
                eventId: span.event.id,
                title: span.event.title,
                colorHex: span.event.colorHex,
                lane: span.lane,
                startCol: 0,
                endCol: 0,
                continuesLeft: span.event.start < dayStart,
                continuesRight: span.event.end > dayEnd,
                minX: PaperSpec.dayGutter + PaperSpec.dayChipPadLeft,
                maxX: PaperSpec.dayTimelineRight - PaperSpec.dayChipPadRight
            ))
        }
        band.bars = bars
        band.laneCount = spans.reduce(0) { max($0, $1.lane + 1) }
        band.todayColumn = day == DayKey(now, calendar: calendar) ? 0 : nil
        return band
    }
}

/// Point sizes of the fixed band (M4B_CONTRACT §2.2). The lanes are lu × zoom like the paper's, but
/// the band is not paper, so they have a floor (the web version's 22 px, the iOS Calendar's ≈ 20 pt):
/// at the iPhone's minimum zoom a 10.4 pt lane would be too cramped for its text (M4B-1).
public enum AllDayBandMetrics {
    public static let minLanePoints: CGFloat = 18
    public static let minGapPoints: CGFloat = 2
    public static let minTextPoints: CGFloat = 11
    /// Web .sh-allday padding 3px 0 4px.
    public static let topPadPoints: CGFloat = 3
    public static let bottomPadPoints: CGFloat = 4
    /// The 「終日」 label (web .sh-allday-label 10px).
    public static let labelPoints: CGFloat = 10
    /// Upper limit of the band's height as a fraction of the page's visible height (web 34vh).
    public static let heightCap: CGFloat = 0.35

    public struct Metrics: Equatable, Sendable {
        /// max(22 × zoom, 18).
        public var lane: CGFloat
        /// max(gapLu × zoom, 2); gapLu is 3 for the week (`allDayGap`), 2 for the day (`dayLaneGap`).
        public var gap: CGFloat
        /// max(textLu × zoom, 11); textLu is 13 for the week (weekEvent), 14 for the day (dayEvent).
        public var text: CGFloat
        /// 0 without lanes, else 3 + n × lane + (n − 1) × gap + 4.
        public var contentHeight: CGFloat
        /// min(contentHeight, floor(0.35 × pageHeight)).
        public var visibleHeight: CGFloat
        /// contentHeight > visibleHeight.
        public var scrollsInside: Bool

        public init(lane: CGFloat, gap: CGFloat, text: CGFloat, contentHeight: CGFloat, visibleHeight: CGFloat, scrollsInside: Bool) {
            self.lane = lane
            self.gap = gap
            self.text = text
            self.contentHeight = contentHeight
            self.visibleHeight = visibleHeight
            self.scrollsInside = scrollsInside
        }

        /// topPadPoints + index × (lane + gap).
        public func laneTop(_ index: Int) -> CGFloat {
            AllDayBandMetrics.topPadPoints + CGFloat(index) * (lane + gap)
        }
    }

    /// The gap between lanes (lu): week 3, day 2.
    public static func gapLu(_ kind: PageKind) -> CGFloat {
        kind == .day ? PaperSpec.dayLaneGap : PaperSpec.allDayGap
    }

    /// The bar text (lu): week 13 (PaperText.Size.weekEvent), day 14 (dayEvent).
    public static func textLu(_ kind: PageKind) -> CGFloat {
        kind == .day ? 14 : 13
    }

    /// `pageHeight` = the height (pt) of the area holding the band and the canvas. A zoom that is
    /// not finite or not positive counts as 1, such a pageHeight as 0; a negative lane count as 0.
    public static func metrics(kind: PageKind, laneCount: Int, zoom: CGFloat, pageHeight: CGFloat) -> Metrics {
        let z = zoom.isFinite && zoom > 0 ? zoom : 1
        let h = pageHeight.isFinite && pageHeight > 0 ? pageHeight : 0
        let n = CGFloat(max(0, laneCount))
        let lane = max(PaperSpec.allDayLane * z, minLanePoints)
        let gap = max(gapLu(kind) * z, minGapPoints)
        let text = max(textLu(kind) * z, minTextPoints)
        let content = n > 0 ? topPadPoints + n * lane + (n - 1) * gap + bottomPadPoints : 0
        let visible = min(content, floor(heightCap * h))
        return Metrics(lane: lane, gap: gap, text: text, contentHeight: content, visibleHeight: visible, scrollsInside: content > visible)
    }
}
