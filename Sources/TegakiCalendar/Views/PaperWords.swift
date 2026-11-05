import Layout
import UIKit

/// The words of the paper and of the headings above it, and how they are fitted into their boxes
/// (1.2, docs/M7B_CONTRACT.md §4.1 F-0–F-11, §10.5). Everything takes the language, so the tests can
/// measure all ten (`PaperFitTests`); the renderers and views pass `L.language`.
///
/// **ja takes 1.1's path** (the heading of §4.1): the boxes, `PaperText.drawLine` and the modifiers
/// of 1.1, so the Japanese pictures stay the same pixel for pixel (J-4), including the texts 1.1 cut
/// with 「…」. The new ways of drawing (`drawFittedLine`, the wider boxes, the separate `Text`s, the
/// added modifiers) are for the other languages only.
enum PaperWords {
    /// Below this column width (pt) a week column shows the weekday's sign instead of its short name
    /// (F-9), and the first of a month drops its weekday (M4C-28). 「10/1」 with its weekday is about 75 pt.
    static let narrowWeekColumnPoints: CGFloat = 75

    // MARK: - Weekdays

    /// F-1: the weekday's sign in a year cell (§3.3). `weekday` is `DayKey.weekday` (0 = Sunday).
    static func yearWeekday(_ weekday: Int, _ language: UILanguage) -> String {
        DateText.weekdays(.letter, language)[clamped(weekday)]
    }

    /// F-1: the one scale of the seven signs of a year cell: the scale at which the widest sign fits in
    /// the font of today's heavy weight, not below `yearWeekdayMinScale`. nil for ja (1.1's `drawLine`).
    static func yearWeekdayScale(boxWidth: CGFloat, fontSize: CGFloat, _ language: UILanguage) -> CGFloat? {
        guard language != .ja else { return nil }
        let signs = (0..<7).map { yearWeekday($0, language) }
        return PaperText.fittedScale(of: signs, width: boxWidth, font: UIFont.systemFont(ofSize: fontSize, weight: .heavy), minScale: yearWeekdayMinScale)
    }

    /// F-1's floor. The contract's 0.7 cut pt-BR's 「dom」 to 「d…」: with the font's tracking at that
    /// size it is 24.9 lu in the 23.4 lu box (docs/M7B.md, P).
    static let yearWeekdayMinScale: CGFloat = 0.65

    /// F-8, §10.5: the 7 names of the month page's weekday row, in the order of `weekStart`: the signs
    /// in Chinese, Japanese and Korean (ja 「月火水木金土日」, Sunday first 「日月火水木金土」), the short
    /// names in the other languages (at most 26.5 pt, an iPhone's column is 57.4 pt).
    static func monthHeaderWeekdays(_ language: UILanguage, weekStart: WeekStart) -> [String] {
        let names = DateText.weekdays(language.isCJK ? .letter : .short, language)
        return weekStart.order.map { names[$0] }
    }

    /// One column of the month page's weekday row. `weekday` is `DayKey.weekday`.
    struct MonthHeaderColumn: Equatable {
        var weekday: Int
        var name: String
        /// Spoken instead of `name` (§4.2).
        var fullName: String
        /// The colour goes with the weekday, not with the column (§10.5): Saturday blue, Sunday red.
        var tone: DayTone
    }

    /// The month page's weekday row of `layout`, for the sticky header and the PDF (§10.5): the order
    /// is read from the layout's first row, the layouts have no `weekStart` of their own (§10.1).
    static func monthHeaderColumns(_ layout: MonthPageLayout, _ language: UILanguage) -> [MonthHeaderColumn] {
        let first = layout.rows.first?.days.first
        let weekStart = first.flatMap { WeekStart(weekPageDate: $0) } ?? .monday
        let names = monthHeaderWeekdays(language, weekStart: weekStart)
        let fullNames = DateText.weekdays(.full, language)
        return weekStart.order.enumerated().map { column, weekday in
            MonthHeaderColumn(weekday: weekday, name: names[column], fullName: fullNames[weekday], tone: weekdayTone(weekday))
        }
    }

    /// Saturday and Sunday by the weekday alone (a holiday does not colour the weekday row).
    static func weekdayTone(_ weekday: Int) -> DayTone {
        switch weekday {
        case 6: return .saturday
        case 0: return .sundayOrHoliday
        default: return .normal
        }
    }

    /// F-9: the weekday over a week column: the sign below `narrowWeekColumnPoints`, else the short
    /// name (ja: the same one character).
    static func weekColumnWeekday(_ weekday: Int, columnWidth: CGFloat, _ language: UILanguage) -> String {
        DateText.weekdays(columnWidth < narrowWeekColumnPoints ? .letter : .short, language)[clamped(weekday)]
    }

    // MARK: - Months

    /// F-8: the 12 titles of the year page's month row and their common scale. ja: 「1月」…「12月」 and
    /// nil (1.1: each title shrinks on its own, to 0.7). The others: the short names at
    /// `min(1, (columnWidth − 4) ÷ the widest)`, and below 0.7 the numbers 「1」…「12」 at full size.
    static func yearColumnTitles(columnWidth: CGFloat, fontSize: CGFloat, _ language: UILanguage) -> (titles: [String], scale: CGFloat?) {
        let names = (1...12).map { DateText.monthName($0, .short, language) }
        guard language != .ja else { return (names, nil) }
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let widest = names.map { PaperText.naturalWidth(of: $0, font: font) }.max() ?? 0
        let scale = widest > 0 ? min(1, (columnWidth - 4) / widest) : 1
        if scale >= yearMonthMinScale {
            return (names, scale)
        }
        return ((1...12).map { String($0) }, 1)
    }

    /// F-8: below this the year's month row shows numbers.
    static let yearMonthMinScale: CGFloat = 0.7

    // MARK: - 「終日」

    /// F-7: the word in the gutter of the all-day band: the full form when it fits `widthPoints − 6`
    /// at `fontSize`, else the short form when that fits, else nil (nothing is shown; VoiceOver does
    /// not read it anyway). ja: always 「終日」, also where it is cut as in 1.1 (an iPhone at full width).
    static func allDayLabel(widthPoints: CGFloat, fontSize: CGFloat, _ language: UILanguage) -> String? {
        let full = language == L.language ? L.text("allday.label") : L.text("allday.label", in: language)
        guard language != .ja else { return full }
        let font = UIFont.systemFont(ofSize: fontSize)
        let room = widthPoints - allDayLabelPad
        if PaperText.naturalWidth(of: full, font: font) <= room {
            return full
        }
        let short = language == L.language ? L.text("allday.label.short") : L.text("allday.label.short", in: language)
        return PaperText.naturalWidth(of: short, font: font) <= room ? short : nil
    }

    /// `AllDayBandView.textPad` and `PDFPageRenderer.barTextPad`.
    static let allDayLabelPad: CGFloat = 6

    // MARK: - Which way a line is drawn

    /// F-2: a holiday name in a year cell: ja 1.1's `drawLine`, the others down to 0.8.
    static func yearHolidayFit(_ language: UILanguage) -> PaperText.LineFit {
        language == .ja ? .oneOne : .fitted(minScale: 0.8)
    }

    /// F-3: a holiday name in a month cell: ja 1.1's `drawLine`, the others down to 0.9.
    static func monthHolidayFit(_ language: UILanguage) -> PaperText.LineFit {
        language == .ja ? .oneOne : .fitted(minScale: 0.9)
    }

    /// F-10: the modifiers of the day heading's month and weekday, and the priority of the holiday's
    /// capsule. ja: the values SwiftUI has without them (1.1 has no modifier there).
    static func dayHeadingFit(_ language: UILanguage) -> (lineLimit: Int?, minScale: CGFloat, holidayPriority: Double) {
        language == .ja ? (nil, 1, 0) : (1, 0.8, -1)
    }

    private static func clamped(_ weekday: Int) -> Int {
        max(0, min(6, weekday))
    }
}
