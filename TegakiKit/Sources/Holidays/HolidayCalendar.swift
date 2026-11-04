import Foundation

/// What a holiday name carries besides its words (docs/M7B_CONTRACT.md §5.2): the date is an
/// estimate (lunar and Islamic calendars, and the years before a government's notice, 0-29), the
/// day is an observed day (振替), or it is a day off swapped with a weekend (振替休日, substituted).
public struct HolidayFlags: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let estimated = HolidayFlags(rawValue: 1)
    public static let observed = HolidayFlags(rawValue: 2)
    public static let substituted = HolidayFlags(rawValue: 4)
}

/// One holiday of one day, ready to show: `full` for the day, week and month headers, titles, the
/// spoken text and PDF (with the estimate mark of the screen's language, 0-17), `short` for the
/// narrow year cells (no observed suffix, no mark).
public struct HolidayEntry: Hashable, Sendable {
    public var full: String
    public var short: String
    public var flags: HolidayFlags
    /// A holiday of the chosen subdivision only (it comes after the country's holidays of its day).
    public var isSubdivision: Bool

    public init(full: String, short: String, flags: HolidayFlags = [], isSubdivision: Bool = false) {
        self.full = full
        self.short = short
        self.flags = flags
        self.isSubdivision = isSubdivision
    }
}

/// Where a `HolidayCalendar` gets its days. Implementations must be cheap to ask again (the
/// calendar does not cache) and safe from any thread.
public protocol HolidaySource: Sendable {
    /// The holidays of `year` by day: the country's holidays first (less the ones the subdivision
    /// removes), then the subdivision's, both in the order of the data (never re-sorted, §5.3).
    /// Empty for a year outside the data (before 2000, from 2100).
    func entries(forYear year: Int) -> [DayKey: [HolidayEntry]]
    /// The weekend days of `year` that are working days (China's 调休 and the like); usually empty.
    func workdays(forYear year: Int) -> Set<DayKey>
    /// A note about the data of `year` (0-29, 0-30); nil for Japan and for "none".
    func note(forYear year: Int) -> HolidayYearNote?
}

/// Why the holidays of a year may be incomplete (shown next to the setting, never on the paper, D9).
public enum HolidayYearNote: Sendable, Equatable {
    /// A country whose days off are set by a yearly government notice, in a year after the last
    /// one the data has (0-29): the holidays are the rules' estimate.
    case beforeNotice
    /// A year outside the years whose data looks complete (0-30); `until` is the last of them.
    case incomplete(until: Int)
}

/// The holidays the paper shows (D8): Japan by default (the 1.1 rules), a country (and
/// subdivision) of the bundled data, or none. Passed into the layouts, which use it for the colour
/// of a day and its name only, never for the shape of the paper (D9).
///
/// Two calendars are equal when their `id`s are: "<region code>|<UILanguage.rawValue>" ("JP|ja",
/// "US-CA|en") or "none".
public struct HolidayCalendar: Sendable, Equatable {
    public enum NameStyle: Sendable {
        case full, short
    }

    /// Japan with the Japanese names: `JapaneseHolidays`, the same as 1.1 (J-5). Reads no file.
    public static let japan = HolidayCalendar(
        id: "JP|ja", region: HolidayRegion(country: "JP", subdivision: nil), source: JapanHolidayBridge(language: .ja))

    /// No holidays at all.
    public static let none = HolidayCalendar(id: "none", region: nil, source: NoHolidays())

    public let id: String
    public let region: HolidayRegion?
    private let source: any HolidaySource

    public init(id: String, region: HolidayRegion?, source: any HolidaySource) {
        self.id = id
        self.region = region
        self.source = source
    }

    /// The names of the holidays among `days` (days without one are not in the result). Two
    /// holidays of one day are joined with " · " (0-16), the country's first.
    public func names(for days: [DayKey], style: NameStyle = .full) -> [DayKey: String] {
        var tables: [Int: [DayKey: [HolidayEntry]]] = [:]
        var result: [DayKey: String] = [:]
        for day in days {
            let table: [DayKey: [HolidayEntry]]
            if let cached = tables[day.year] {
                table = cached
            } else {
                table = source.entries(forYear: day.year)
                tables[day.year] = table
            }
            if let entries = table[day], !entries.isEmpty {
                result[day] = Self.joined(entries, style: style)
            }
        }
        return result
    }

    /// The name of the holiday of `day`, or nil.
    public func name(of day: DayKey, style: NameStyle = .full) -> String? {
        guard let entries = source.entries(forYear: day.year)[day], !entries.isEmpty else { return nil }
        return Self.joined(entries, style: style)
    }

    /// The holidays of `year` as the source gives them (for the checks and the settings).
    public func entries(forYear year: Int) -> [DayKey: [HolidayEntry]] {
        source.entries(forYear: year)
    }

    /// True when `day` is a weekend day that is a working day (its colour is then the normal one,
    /// §5.4). Always false for Japan and for none.
    public func isWorkday(_ day: DayKey) -> Bool {
        source.workdays(forYear: day.year).contains(day)
    }

    public func note(forYear year: Int) -> HolidayYearNote? {
        source.note(forYear: year)
    }

    public static func == (lhs: HolidayCalendar, rhs: HolidayCalendar) -> Bool {
        lhs.id == rhs.id
    }

    /// The separator of two holidays on one day (0-16).
    public static let separator = " · "

    private static func joined(_ entries: [HolidayEntry], style: NameStyle) -> String {
        entries.map { style == .full ? $0.full : $0.short }.joined(separator: separator)
    }
}

/// The source of `HolidayCalendar.none`.
struct NoHolidays: HolidaySource {
    func entries(forYear year: Int) -> [DayKey: [HolidayEntry]] { [:] }
    func workdays(forYear year: Int) -> Set<DayKey> { [] }
    func note(forYear year: Int) -> HolidayYearNote? { nil }
}
