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
    /// canvas has not reported one yet: the rows then use `PaperViewport.initial(_:viewportWidth:)`
    /// (fit-to-width since M4c) for the proposed width, the value the screen starts from too (it
    /// passes a width > 0 viewport from its first frame, so this only covers the moment right after
    /// `attach`). Since M4c `offsetX` is negative when the paper is narrower than the viewport and
    /// centred (M4C_CONTRACT §1.4): `x(ofPaper:)` then shifts the columns right by the margin, so the
    /// heading lines up with the paper on its own. Defaulted so the screen builds before and after
    /// it passes one.
    var viewport: PaperViewport = .zero
    /// 1.3 (docs/M7C_CONTRACT.md §3.8, §3.13; the lead's decision 4 of docs/M7C.md, S1 の残り): the window of
    /// joined weeks or days whose columns the row lays out side by side, each page from its slot's x, with
    /// `viewport` the canvas's offset and zoom over the whole window (`spanWeekRow`, `spanDayRow`). Only there
    /// the heading thins out when its columns get too narrow (`weekCellForm`, `dayBlockForm`) and the week's
    /// time column carries the month of the week's first day (`weekGutterTitle`). nil, or a window of one
    /// page (`PaperSpan.isJoined` false): the heading of `paper` alone, 1.2.3's. The title above it, and the
    /// narrow screen's two-row title, stay the focus page's (the screen's `PageHeaderView`, §3.13).
    var span: PaperSpan? = nil
    /// The language of the day page's heading (F-10). Always `L.language` in the app; the tests, which run
    /// in Japanese (0-25), pass the others to measure them.
    var language: UILanguage = L.language
    var onDayTap: (DayKey) -> Void
    var onMonthTap: (YearMonth) -> Void

    var body: some View {
        if let span = span, span.isJoined {
            switch span.kind {
            case .day:
                spanDayRow(span)
            default:
                spanWeekRow(span)
            }
        } else {
            switch paper {
            case .month(let content):
                monthRow(content.layout)
            case .week(let content):
                weekRow(content.layout)
            case .day(let content):
                dayRow(content.layout)
            case .year(let content):
                yearRow(content)
            }
        }
    }

    // MARK: - Month (M2's weekday row)

    /// 1.2 (§10.5): the order is the layout's first row and the colour goes with the weekday, so a
    /// Sunday-first page has its red Sunday in the first column and its blue Saturday in the last.
    private func monthRow(_ layout: MonthPageLayout) -> some View {
        PaperRow(kind: .month, viewport: viewport, columns: Array(repeating: PaperSpec.monthColumnWidth, count: PaperSpec.monthColumns)) {
            ForEach(PaperWords.monthHeaderColumns(layout, L.language), id: \.weekday) { column in
                Text(column.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Self.toneColor(column.tone) ?? .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .accessibilityLabel(column.fullName)
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

    /// Below this column width (pt) the first of a month (「10/1」, about 75 pt with its weekday) does
    /// not fit: its weekday letter is dropped and the row may scale its text down to 60 % (M4C-28,
    /// M4C_CONTRACT §1.4). An iPhone's overview has 54.8 pt columns; 「水 7」 (about 50 pt) still fits.
    static let narrowWeekColumnPoints: CGFloat = PaperWords.narrowWeekColumnPoints

    private func weekDayCell(_ label: DateLabel) -> some View {
        let firstOfMonth = label.day.day == 1
        let number = firstOfMonth ? "\(label.day.month)/1" : "\(label.day.day)"
        // F-9: over the number there is room for the weekday of the first of a month too.
        let stacked = PaperWords.weekColumnStacksWeekday(L.language)
        let showsWeekday = stacked || !(firstOfMonth && viewport.width(ofPaper: PaperSpec.weekColumnWidth) < Self.narrowWeekColumnPoints)
        let tone = Self.toneColor(label.tone)
        return Button {
            onDayTap(label.day)
        } label: {
            VStack(spacing: 1) {
                Group {
                    if stacked {
                        VStack(spacing: 0) {
                            weekDayWeekday(label, tone: tone)
                            weekDayNumber(number, label, tone: tone)
                        }
                    } else {
                        HStack(spacing: 4) {
                            if showsWeekday {
                                weekDayWeekday(label, tone: tone)
                            }
                            weekDayNumber(number, label, tone: tone)
                        }
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                if let holiday = label.holidayName, !holiday.isEmpty {
                    if let short = PaperWords.weekColumnShortHoliday(label, L.language) {
                        // F-9: outside ja the short name when the full one does not fit, not an open bracket.
                        ViewThatFits(in: .horizontal) {
                            weekDayHoliday(holiday)
                            weekDayHoliday(short)
                        }
                    } else {
                        weekDayHoliday(holiday)
                    }
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
        .accessibilityLabel(L.format("header.day.spoken", Self.dayLabel(label)))
    }

    private func weekDayWeekday(_ label: DateLabel, tone: Color?) -> some View {
        Text(PaperWords.weekColumnWeekday(label.day.weekday, columnWidth: viewport.width(ofPaper: PaperSpec.weekColumnWidth), L.language))
            .font(.system(size: 12, weight: label.isToday ? .bold : .medium))
            .foregroundStyle(label.isToday ? accentColor : (tone ?? ink2))
    }

    private func weekDayNumber(_ number: String, _ label: DateLabel, tone: Color?) -> some View {
        Text(number)
            .font(.system(size: 18, weight: .semibold).monospacedDigit())
            .foregroundStyle(label.isToday ? Color.white : (tone ?? ink1))
            .padding(.horizontal, 6)
            .frame(minWidth: 30, minHeight: 30)
            .background(label.isToday ? Capsule().fill(accentColor) : nil)
    }

    private func weekDayHoliday(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 10))
            .foregroundStyle(redColor)
            .lineLimit(1)
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
        .accessibilityLabel(label.map { Self.dayLabel($0) } ?? "")
    }

    private func dayDateBlock(_ label: DateLabel) -> some View {
        dayDateContent(label)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(label.isToday ? todayTintSoft : (label.tone != .normal ? weekendTintSoft : Color.clear))
            .overlay(alignment: .leading) { columnLine }
    }

    /// F-10 (docs/M7B.md, FIX4): outside ja, with a holiday, the capsule when the whole row fits the column,
    /// else the name in the line of the month's name (the month is in the page's title), and a name too long
    /// for that line in two lines of 9 pt (`PaperWords.dayHeadingLongHolidayPoints`), the size the 11 pt line
    /// could shrink to anyway. All three are as high as a day with no holiday: the number's 36 pt decides, the
    /// lines stay within 40 pt (the last form by its frame), so a pinch that switches between them does not
    /// move the paper area (K-6, F-10). The column follows the zoom, so a pinch can bring the capsule back.
    /// ja and a day with no holiday have the one row.
    @ViewBuilder
    private func dayDateContent(_ label: DateLabel) -> some View {
        if let line = PaperWords.dayHeadingHolidayLine(label, language) {
            ViewThatFits(in: .horizontal) {
                dayDateRow(label)
                dayDateRow(label, holidayLine: line)
                dayDateRow(label, holidayLine: line, wraps: true)
                    .frame(maxHeight: PaperWords.dayHeadingLinesMaxHeight)
            }
        } else {
            dayDateRow(label)
        }
    }

    /// The number, the two lines and, unless the name is in the first line (`holidayLine`), the capsule.
    /// With the name on top the gap to the number is 4 pt less, for the sake of the name.
    private func dayDateRow(_ label: DateLabel, holidayLine: String? = nil, wraps: Bool = false) -> some View {
        let tone = Self.toneColor(label.tone)
        let fit = PaperWords.dayHeadingFit(language) // F-10
        return HStack(spacing: holidayLine == nil ? 10 : 6) {
            Text("\(label.day.day)")
                .font(.system(size: 21, weight: .semibold).monospacedDigit())
                .foregroundStyle(label.isToday ? Color.white : (tone ?? ink1))
                .padding(.horizontal, 6)
                .frame(minWidth: 36, minHeight: 36)
                .background(label.isToday ? Capsule().fill(accentColor) : nil)
            VStack(alignment: .leading, spacing: 0) {
                Text(holidayLine ?? DateText.monthName(label.day.month, .full, language))
                    .font(.system(size: wraps ? PaperWords.dayHeadingLongHolidayPoints : 11))
                    .foregroundStyle(holidayLine == nil ? ink3 : redColor)
                    .lineLimit(wraps ? 2 : fit.lineLimit)
                    .minimumScaleFactor(wraps ? 1 : fit.minScale)
                Text(DateText.weekdays(.full, language)[label.day.weekday])
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(label.isToday ? accentColor : (tone ?? ink1))
                    .lineLimit(fit.lineLimit)
                    .minimumScaleFactor(fit.minScale)
            }
            if holidayLine == nil, let holiday = label.holidayName, !holiday.isEmpty {
                Text(holiday)
                    .font(.system(size: 12))
                    .foregroundStyle(redColor)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(redColor.opacity(0.08)))
                    .layoutPriority(fit.holidayPriority)
            }
        }
    }

    // MARK: - Year

    private func yearRow(_ content: YearPaperContent) -> some View {
        let columns = [PaperSpec.yearGutter] + Array(repeating: PaperSpec.yearColumnWidth, count: PaperSpec.yearColumns)
        let year = content.layout.year
        let current = YearMonth.current(calendar: DayKey.deviceCalendar, now: now)
        // F-8: ja is 1.1's (the content's names, each down to 0.7); the others fit this zoom's column
        // at one scale for the twelve, or show numbers. The first frame has no viewport yet: the paper's width.
        let columnWidth = viewport.width > 0 ? viewport.width(ofPaper: PaperSpec.yearColumnWidth) : PaperSpec.yearColumnWidth
        let fitted = PaperWords.yearColumnTitles(columnWidth: columnWidth, fontSize: Self.yearMonthFontSize, L.language)
        return PaperRow(kind: .year, viewport: viewport, columns: columns) {
            Color.clear
            ForEach(1...PaperSpec.yearColumns, id: \.self) { month in
                let yearMonth = YearMonth(year: year, month: month)
                let name = fitted.scale == nil && month - 1 < content.monthNames.count ? content.monthNames[month - 1] : fitted.titles[month - 1]
                Button {
                    onMonthTap(yearMonth)
                } label: {
                    Text(name)
                        .font(.system(size: Self.yearMonthFontSize * (fitted.scale ?? 1), weight: .semibold))
                        .foregroundStyle(yearMonth == current ? accentColor : ink1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(alignment: .leading) { Rectangle().fill(lineStrongColor).frame(width: 1) }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.format("header.month.spoken", yearMonth.title(language: L.language)))
            }
        }
        .clipped()
        .background(paperColor)
        .overlay(alignment: .bottom) { bottomLine }
    }

    // MARK: - 1.3: the joined window (§3.8, §3.13; the lead's decision 4)

    /// How a day column of the joined weeks' heading is shown (decision 4: on an iPhone in landscape at the
    /// overview, 20 pt columns, 1.2.3's cells run into each other).
    enum WeekCellForm: Equatable {
        /// 1.2.3's cell (`weekDayCell`): the weekday, the number, the holiday name.
        case full
        /// The number alone, on every day. The holiday name gives way (its line stays, empty, so the row is
        /// as tall as 1.2.3's and the paper area does not change during a pinch, K-6); the number keeps the
        /// holiday's red.
        case number
        /// The number on every `every`-th day only, counted from today (`sparseShows`), so the labelled days
        /// keep their places across the weeks' boundaries and while the window shifts; the other columns keep
        /// their tint and line. No holiday names.
        case sparse(every: Int)
    }

    /// At and above this column width (pt) the joined weeks keep 1.2.3's day cell: its weekday sign, 4 pt and
    /// the number's 30 pt box fit with the cell's 2 pt on each side (an iPad mini in landscape at the overview
    /// has 52 pt, an iPhone in portrait 54 pt).
    static let joinedWeekFullPoints: CGFloat = 50
    /// At and above this column width (pt) every day keeps its number (the 30 pt box and 2 pt on each side).
    static let joinedWeekNumberPoints: CGFloat = 34

    /// The form of the week's day columns at `columnPoints` (190.857 lu × zoom). Only the joined path thins
    /// (`joined`); the heading of one page is always 1.2.3's (`.full`), as is a column width that is not
    /// usable (the first frame). Below `joinedWeekNumberPoints` one day in ⌈34 ÷ width⌉ (at least 2) keeps its
    /// number: every other day at the iPhone's 20 pt.
    static func weekCellForm(joined: Bool, columnPoints: CGFloat) -> WeekCellForm {
        guard joined, columnPoints.isFinite, columnPoints > 0 else { return .full }
        if columnPoints >= joinedWeekFullPoints { return .full }
        if columnPoints >= joinedWeekNumberPoints { return .number }
        return .sparse(every: max(2, Int((joinedWeekNumberPoints / columnPoints).rounded(.up))))
    }

    /// Does `day` keep its number in `.sparse(every:)`: (its day number − `anchor`) is a multiple of `every`.
    /// The screen's anchor is today's day number, so today is always one of them.
    static func sparseShows(_ day: DayKey, every: Int, anchor: Int) -> Bool {
        guard every > 1 else { return true }
        return (day.dayNumber - anchor) % every == 0
    }

    /// How the date of a joined day page is shown over its time line column.
    enum DayBlockForm: Equatable {
        /// 1.2.3's date block (`dayDateBlock`): the number, the month's name, the weekday, the holiday.
        case full
        /// The number and the weekday's short name.
        case numberAndWeekday
        /// The number alone.
        case number
    }

    /// At and above this width of the time line column (pt) the joined days keep 1.2.3's date block (an
    /// iPhone in portrait at the overview has 131 pt, an iPad mini in landscape 128 pt).
    static let joinedDayFullPoints: CGFloat = 100
    /// At and above it the weekday stays beside the number (an iPhone in landscape has 50 pt: the number alone).
    static let joinedDayWeekdayPoints: CGFloat = 64

    /// The form of a joined day's date at `columnPoints` (588 lu × zoom). The day page alone is always
    /// 1.2.3's (`joined` false), as is a width that is not usable.
    static func dayBlockForm(joined: Bool, columnPoints: CGFloat) -> DayBlockForm {
        guard joined, columnPoints.isFinite, columnPoints > 0 else { return .full }
        if columnPoints >= joinedDayFullPoints { return .full }
        return columnPoints >= joinedDayWeekdayPoints ? .numberAndWeekday : .number
    }

    /// The size (pt, semibold) of the month over a joined week's time column.
    static let joinedGutterFontSize: CGFloat = 11

    /// The heading of a joined week's time column (§3.8, §3.9 3, B_DESIGN.md §3.2): the month of the week's
    /// first day (`days.first`, a Monday or a Sunday by the week start) — its name, `.full` then `.short` — or,
    /// for the week that holds January 1, that year (`DateText.yearTitle`, then the plain number). The first
    /// that fits `gutterPoints` (64 lu × zoom) with 2 pt on each side at 11 pt semibold; nil when none fits
    /// (an iPhone in landscape) or there is no day.
    static func weekGutterTitle(days: [DayKey], gutterPoints: CGFloat, language: UILanguage) -> String? {
        guard let first = days.first, gutterPoints.isFinite else { return nil }
        let candidates: [String]
        if let newYear = days.first(where: { $0.month == 1 && $0.day == 1 }) {
            candidates = [DateText.yearTitle(newYear.year, language), String(newYear.year)]
        } else {
            candidates = [DateText.monthName(first.month, .full, language), DateText.monthName(first.month, .short, language)]
        }
        let font = UIFont.systemFont(ofSize: joinedGutterFontSize, weight: .semibold)
        let room = gutterPoints - 4
        return candidates.first { !$0.isEmpty && PaperText.naturalWidth(of: $0, font: font) <= room }
    }

    /// The columns of the joined pages side by side: per page the week's [64] + [190.857…] × 7 or the day's
    /// [72, 588, 340] (the columns of `weekRow` / `dayRow`), so page k's first column starts at k × the page
    /// width, `PaperSpan.origin(ofSlot:)`.
    static func spanColumns(_ span: PaperSpan) -> [CGFloat] {
        let page: [CGFloat] = span.kind == .day
            ? [PaperSpec.dayGutter, PaperSpec.dayTimelineRight - PaperSpec.dayGutter, PaperSpec.dayWidth - PaperSpec.dayTimelineRight]
            : [PaperSpec.weekGutter] + Array(repeating: PaperSpec.weekColumnWidth, count: PaperSpec.weekColumns)
        return Array(Array(repeating: page, count: span.pages.count).joined())
    }

    /// The joined weeks: per page the month over its time column and its 7 day columns, in the form the
    /// column width allows.
    private func spanWeekRow(_ span: PaperSpan) -> some View {
        let columnPoints = viewport.width(ofPaper: PaperSpec.weekColumnWidth)
        let gutterPoints = viewport.width(ofPaper: PaperSpec.weekGutter)
        let form = Self.weekCellForm(joined: true, columnPoints: columnPoints)
        let anchor = DayKey(now, calendar: DayKey.deviceCalendar).dayNumber
        return PaperRow(kind: .week, viewport: viewport, columns: Self.spanColumns(span)) {
            ForEach(span.pages.indices, id: \.self) { slot in
                weekGutterCell(span.dateLabels(ofSlot: slot).map(\.day), gutterPoints: gutterPoints)
                ForEach(span.dateLabels(ofSlot: slot), id: \.day) { label in
                    spanWeekDayCell(label, form: form, anchor: anchor, columnPoints: columnPoints)
                }
            }
        }
        .clipped()
        .background(paperColor)
        .overlay(alignment: .bottom) { bottomLine }
    }

    /// The month (or the year) over a joined week's time column; empty when it does not fit. The day columns
    /// say the whole date to VoiceOver, so this one is not read.
    private func weekGutterCell(_ days: [DayKey], gutterPoints: CGFloat) -> some View {
        Text(Self.weekGutterTitle(days: days, gutterPoints: gutterPoints, language: L.language) ?? "")
            .font(.system(size: Self.joinedGutterFontSize, weight: .semibold))
            .foregroundStyle(ink2)
            .lineLimit(1)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 48)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func spanWeekDayCell(_ label: DateLabel, form: WeekCellForm, anchor: Int, columnPoints: CGFloat) -> some View {
        switch form {
        case .full:
            weekDayCell(label)
        case .number:
            thinWeekDayCell(label, shows: true, labelWidth: nil)
        case .sparse(let every):
            thinWeekDayCell(label, shows: Self.sparseShows(label.day, every: every, anchor: anchor),
                            labelWidth: max(30, CGFloat(every) * columnPoints - 4))
        }
    }

    /// A day column of the thinned joined weeks: the number alone (1.2.3's number, today's capsule, the tone's
    /// colour) centred over the column, the holiday line kept empty; `shows` false leaves the column's tint
    /// and line only. `labelWidth` is the room a sparse number gets over its empty neighbours. The column is
    /// exactly as wide as proposed, so what reaches past it is shared evenly on both sides.
    private func thinWeekDayCell(_ label: DateLabel, shows: Bool, labelWidth: CGFloat?) -> some View {
        let number = label.day.day == 1 ? "\(label.day.month)/1" : "\(label.day.day)"
        let tone = Self.toneColor(label.tone)
        return Button {
            onDayTap(label.day)
        } label: {
            VStack(spacing: 1) {
                weekDayNumber(number, label, tone: tone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: labelWidth)
                    .opacity(shows ? 1 : 0)
                if let holiday = label.holidayName, !holiday.isEmpty {
                    weekDayHoliday(holiday)
                        .hidden()
                }
            }
            .padding(.vertical, 4)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 48)
            .background(label.isToday ? todayTint : (label.tone != .normal ? weekendTint : Color.clear))
            .overlay(alignment: .leading) { columnLine }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.format("header.day.spoken", Self.dayLabel(label)))
    }

    /// The joined days: per page 1.2.3's three columns, the date over the time line column in the form its
    /// width allows.
    private func spanDayRow(_ span: PaperSpan) -> some View {
        let timeline = PaperSpec.dayTimelineRight - PaperSpec.dayGutter
        let form = Self.dayBlockForm(joined: true, columnPoints: viewport.width(ofPaper: timeline))
        return PaperRow(kind: .day, viewport: viewport, columns: Self.spanColumns(span)) {
            ForEach(span.pages.indices, id: \.self) { slot in
                Color.clear
                if let label = span.dateLabels(ofSlot: slot).first {
                    spanDayBlock(label, form: form)
                } else {
                    Color.clear
                }
                Color.clear
                    .overlay(alignment: .leading) { Rectangle().fill(lineStrongColor).frame(width: 1) }
            }
        }
        .clipped()
        .background(paperColor)
        .overlay(alignment: .bottom) { bottomLine }
    }

    @ViewBuilder
    private func spanDayBlock(_ label: DateLabel, form: DayBlockForm) -> some View {
        switch form {
        case .full:
            dayDateBlock(label)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Self.dayLabel(label, language: language))
        case .numberAndWeekday, .number:
            thinDayDateBlock(label, showsWeekday: form == .numberAndWeekday)
        }
    }

    /// A joined day's date in a narrow column: 1.2.3's number (today's capsule, the tone's colour) and, when
    /// there is room, the weekday's short name; as tall as 1.2.3's block (52 pt).
    private func thinDayDateBlock(_ label: DateLabel, showsWeekday: Bool) -> some View {
        let tone = Self.toneColor(label.tone)
        return HStack(spacing: 4) {
            Text("\(label.day.day)")
                .font(.system(size: 21, weight: .semibold).monospacedDigit())
                .foregroundStyle(label.isToday ? Color.white : (tone ?? ink1))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 6)
                .frame(minWidth: 36, minHeight: 36)
                .background(label.isToday ? Capsule().fill(accentColor) : nil)
            if showsWeekday {
                Text(DateText.weekdays(.short, language)[label.day.weekday])
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(label.isToday ? accentColor : (tone ?? ink1))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(label.isToday ? todayTintSoft : (label.tone != .normal ? weekendTintSoft : Color.clear))
        .overlay(alignment: .leading) { columnLine }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.dayLabel(label, language: language))
    }

    // MARK: - Helpers

    /// The year page's month row (pt).
    static let yearMonthFontSize: CGFloat = 13

    /// The spoken day (§4.2): "2026年10月4日(日) 体育の日", the holiday name only when there is one. The
    /// other languages: "Sunday, October 4, 2026, Thanksgiving Day".
    static func dayLabel(_ label: DateLabel, language: UILanguage = L.language) -> String {
        var text = DateText.spokenDay(label.day, language)
        if let holiday = label.holidayName, !holiday.isEmpty {
            text += (language == .ja ? " " : ", ") + holiday
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
/// `PaperViewport.initial(kind, viewportWidth:)` (fit-to-width since M4c) for the proposed width —
/// the value the screen starts from too, so the canvas's first report changes nothing visible. A
/// negative `offsetX` (the paper centred in a wider viewport, M4c D1) moves every column right.
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
