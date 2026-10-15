import Layout
import SwiftUI
import UIKit

/// The fixed heading above the paper (contract §4.3). It never scrolls vertically, cannot be
/// written on, and its columns match the paper's: since M4b every row is a `PaperRow` placed with
/// the canvas's horizontal offset and zoom (`viewport`, M4B_CONTRACT §1.4), so on an iPhone — and
/// on every device on the year page — the heading follows the paper sideways and what lies outside
/// the viewport is clipped. The gutter columns (the time labels, the year's day numbers) are part of
/// the paper and move with it (D2).
///
/// | page  | content                                                       | tap                  |
/// | ----- | ------------------------------------------------------------- | -------------------- |
/// | month | the weekday row 月…日 (M2)                                      | —                    |
/// | week  | 7 day headers: weekday + date number (+ holiday)               | column → day page    |
/// | day   | the date, "10月", "日曜日", the holiday badge; the memo column | —                    |
/// | year  | "1月"…"12月" over the 12 columns                               | month → month page   |
struct StickyHeaderView: View {
    var paper: PaperContent
    /// The current time (decides the current month of the year header).
    var now: Date
    /// The paper's horizontal offset and zoom (M4B_CONTRACT §1.1). `.zero` (width 0) means the
    /// canvas has not reported one yet: the rows then use `PaperViewport.initial` for the proposed
    /// width, the same value the screen starts from. Defaulted so the screen builds before and
    /// after it passes one.
    var viewport: PaperViewport = .zero
    var onDayTap: (DayKey) -> Void
    var onMonthTap: (YearMonth) -> Void

    private static let weekdayNames = ["日", "月", "火", "水", "木", "金", "土"]
    private static let monthWeekdayLabels = ["月", "火", "水", "木", "金", "土", "日"]

    var body: some View {
        switch paper {
        case .month:
            monthRow
        case .week(let content):
            weekRow(content.layout)
        case .day(let content):
            dayRow(content.layout)
        case .year(let content):
            yearRow(content)
        }
    }

    // MARK: - Month (M2's weekday row)

    private var monthRow: some View {
        PaperRow(kind: .month, viewport: viewport, columns: Array(repeating: PaperSpec.monthColumnWidth, count: PaperSpec.monthColumns)) {
            ForEach(0..<7, id: \.self) { column in
                Text(Self.monthWeekdayLabels[column])
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Self.monthWeekdayColor(column: column))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
        }
        .clipped()
        .background(Color(uiColor: .secondarySystemBackground))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(uiColor: .separator))
                .frame(height: 0.5)
        }
    }

    private static func monthWeekdayColor(column: Int) -> Color {
        switch column {
        case 5: return Color(uiColor: PaperPalette.blue)
        case 6: return Color(uiColor: PaperPalette.red)
        default: return .primary
        }
    }

    // MARK: - Week

    private func weekRow(_ layout: WeekPageLayout) -> some View {
        let columns = [PaperSpec.weekGutter] + Array(repeating: PaperSpec.weekColumnWidth, count: PaperSpec.weekColumns)
        return PaperRow(kind: .week, viewport: viewport, columns: columns) {
            Color.clear
            ForEach(layout.dateLabels, id: \.day) { label in
                weekDayCell(label)
            }
        }
        .clipped()
        .background(paperColor)
        .overlay(alignment: .bottom) { bottomLine }
    }

    private func weekDayCell(_ label: DateLabel) -> some View {
        let number = label.day.day == 1 ? "\(label.day.month)/1" : "\(label.day.day)"
        let tone = Self.toneColor(label.tone)
        return Button {
            onDayTap(label.day)
        } label: {
            VStack(spacing: 1) {
                HStack(spacing: 4) {
                    Text(Self.weekdayNames[label.day.weekday])
                        .font(.system(size: 12, weight: label.isToday ? .bold : .medium))
                        .foregroundStyle(label.isToday ? accentColor : (tone ?? ink2))
                    Text(number)
                        .font(.system(size: 18, weight: .semibold).monospacedDigit())
                        .foregroundStyle(label.isToday ? Color.white : (tone ?? ink1))
                        .padding(.horizontal, 6)
                        .frame(minWidth: 30, minHeight: 30)
                        .background(label.isToday ? Capsule().fill(accentColor) : nil)
                }
                if let holiday = label.holidayName, !holiday.isEmpty {
                    Text(holiday)
                        .font(.system(size: 10))
                        .foregroundStyle(redColor)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(label.isToday ? todayTint : (label.tone != .normal ? weekendTint : Color.clear))
            .overlay(alignment: .leading) { columnLine }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.dayLabel(label) + "（日表示へ）")
    }

    // MARK: - Day

    private func dayRow(_ layout: DayPageLayout) -> some View {
        let timeline = PaperSpec.dayTimelineRight - PaperSpec.dayGutter
        let memo = PaperSpec.dayWidth - PaperSpec.dayTimelineRight
        let label = layout.dateLabels.first
        return PaperRow(kind: .day, viewport: viewport, columns: [PaperSpec.dayGutter, timeline, memo]) {
            Color.clear
            if let label = label {
                dayDateBlock(label)
            } else {
                Color.clear
            }
            Color.clear
                .overlay(alignment: .leading) { Rectangle().fill(lineStrongColor).frame(width: 1) }
        }
        .clipped()
        .background(paperColor)
        .overlay(alignment: .bottom) { bottomLine }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label.map(Self.dayLabel) ?? "")
    }

    private func dayDateBlock(_ label: DateLabel) -> some View {
        let tone = Self.toneColor(label.tone)
        return HStack(spacing: 10) {
            Text("\(label.day.day)")
                .font(.system(size: 21, weight: .semibold).monospacedDigit())
                .foregroundStyle(label.isToday ? Color.white : (tone ?? ink1))
                .padding(.horizontal, 6)
                .frame(minWidth: 36, minHeight: 36)
                .background(label.isToday ? Capsule().fill(accentColor) : nil)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(label.day.month)月")
                    .font(.system(size: 11))
                    .foregroundStyle(ink3)
                Text(Self.weekdayNames[label.day.weekday] + "曜日")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(label.isToday ? accentColor : (tone ?? ink1))
            }
            if let holiday = label.holidayName, !holiday.isEmpty {
                Text(holiday)
                    .font(.system(size: 12))
                    .foregroundStyle(redColor)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(redColor.opacity(0.08)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(label.isToday ? todayTintSoft : (label.tone != .normal ? weekendTintSoft : Color.clear))
        .overlay(alignment: .leading) { columnLine }
    }

    // MARK: - Year

    private func yearRow(_ content: YearPaperContent) -> some View {
        let columns = [PaperSpec.yearGutter] + Array(repeating: PaperSpec.yearColumnWidth, count: PaperSpec.yearColumns)
        let year = content.layout.year
        let current = YearMonth.current(calendar: DayKey.deviceCalendar, now: now)
        return PaperRow(kind: .year, viewport: viewport, columns: columns) {
            Color.clear
            ForEach(1...PaperSpec.yearColumns, id: \.self) { month in
                let yearMonth = YearMonth(year: year, month: month)
                let name = month - 1 < content.monthNames.count ? content.monthNames[month - 1] : "\(month)月"
                Button {
                    onMonthTap(yearMonth)
                } label: {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(yearMonth == current ? accentColor : ink1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(alignment: .leading) { Rectangle().fill(lineStrongColor).frame(width: 1) }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(yearMonth.title + "（月表示へ）")
            }
        }
        .clipped()
        .background(paperColor)
        .overlay(alignment: .bottom) { bottomLine }
    }

    // MARK: - Helpers

    /// "2026年10月4日(日) 体育の日" (the holiday name only when there is one).
    static func dayLabel(_ label: DateLabel) -> String {
        var text = EventDateText.dayTitle(label.day)
        if let holiday = label.holidayName, !holiday.isEmpty {
            text += " " + holiday
        }
        return text
    }

    private static func toneColor(_ tone: DayTone) -> Color? {
        switch tone {
        case .saturday: return Color(uiColor: PaperPalette.blue)
        case .sundayOrHoliday: return Color(uiColor: PaperPalette.red)
        case .normal: return nil
        }
    }

    private var paperColor: Color { Color(uiColor: PaperPalette.paper) }
    private var ink1: Color { Color(uiColor: PaperPalette.ink1) }
    private var ink2: Color { Color(uiColor: PaperPalette.ink2) }
    private var ink3: Color { Color(uiColor: PaperPalette.ink3) }
    private var accentColor: Color { Color(uiColor: PaperPalette.accent) }
    private var redColor: Color { Color(uiColor: PaperPalette.red) }
    private var lineColor: Color { Color(uiColor: PaperPalette.line) }
    private var lineStrongColor: Color { Color(uiColor: PaperPalette.lineStrong) }
    private var todayTint: Color { Color(uiColor: PaperPalette.todayTint) }
    private var todayTintSoft: Color { Color(uiColor: PaperPalette.todayTintSoft) }
    private var weekendTint: Color { Color(uiColor: PaperPalette.weekendTint) }
    private var weekendTintSoft: Color { Color(uiColor: PaperPalette.weekendTintSoft) }

    private var columnLine: some View {
        Rectangle().fill(lineColor).frame(width: 1)
    }

    private var bottomLine: some View {
        Rectangle().fill(lineColor).frame(height: 1)
    }
}

extension YearMonth {
    /// The month containing `now` in `calendar`.
    static func current(calendar: Calendar, now: Date) -> YearMonth {
        let day = DayKey(now, calendar: calendar)
        return YearMonth(year: day.year, month: day.month)
    }
}

/// A row whose children sit on the paper's columns (M4B_CONTRACT §1.4; it replaces M3a's
/// `FractionRow`): child i is placed at x = (Σ_{j<i} columns[j]) × zoom − offsetX with the width
/// columns[i] × zoom (pt), so the heading follows the paper's horizontal scroll and zoom exactly.
/// `columns` are the paper's column widths in lu: month [200] × 7, week [64] + [190.857…] × 7, day
/// [72, 588, 340], year [56] + [112] × 12. The row is as wide as proposed (the viewport) and as tall
/// as its tallest child; what lies outside is clipped by the caller. At the fit-to-width zoom this is
/// the same geometry as before (every column a fixed fraction of the width).
///
/// A viewport of width 0 (the first frame, before the canvas has reported one) is replaced by
/// `PaperViewport.initial(kind, viewportWidth:)` for the proposed width — the value the screen
/// starts from too, so the canvas's first report changes nothing visible.
struct PaperRow: Layout {
    var kind: PageKind
    var viewport: PaperViewport
    var columns: [CGFloat]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let v = resolved(width: proposal.width)
        let width = proposal.width ?? v.width
        var height: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let w = v.width(ofPaper: column(at: index))
            let size = subview.sizeThatFits(ProposedViewSize(width: w, height: nil))
            height = max(height, size.height)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let v = resolved(width: bounds.width)
        var x: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let lu = column(at: index)
            subview.place(
                at: CGPoint(x: bounds.minX + v.x(ofPaper: x), y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: v.width(ofPaper: lu), height: bounds.height)
            )
            x += lu
        }
    }

    /// The viewport to lay out with: the canvas's, or the first-frame one for `width`.
    private func resolved(width: CGFloat?) -> PaperViewport {
        if viewport.width > 0 { return viewport }
        return PaperViewport.initial(kind, viewportWidth: width ?? 0)
    }

    private func column(at index: Int) -> CGFloat {
        guard index < columns.count else { return 0 }
        return max(0, columns[index])
    }
}
