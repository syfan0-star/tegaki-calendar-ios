import Foundation

/// Japan (docs/M7B_CONTRACT.md §5.3): the days of `JapaneseHolidays` (1.1's rules, checked against
/// the Cabinet Office's list), with their Japanese names whenever the screen's language takes the
/// Japanese column (ja; zh-Hans and zh-Hant by the script rule of §5.5), so that every Japanese
/// name comes from one place. The other languages take the name of the same day from JP.json (its
/// days agree with `JapaneseHolidays` on all 1,773 days); a day JP.json does not have, or a missing
/// JP.json, gives the Japanese name. No working weekends, no notes.
public struct JapanHolidayBridge: HolidaySource {
    public let language: UILanguage
    private let data: (@Sendable () -> CountryHolidays?)?

    /// The bridge without the data file: Japanese names in every language. `HolidayCalendar.japan`
    /// is `JapanHolidayBridge(language: .ja)`, which reads no file (J-5).
    public init(language: UILanguage) {
        self.init(language: language, data: nil)
    }

    /// `data` gives JP.json when a language other than ja needs it (HolidayStore passes its cache).
    init(language: UILanguage, data: (@Sendable () -> CountryHolidays?)?) {
        self.language = language
        self.data = data
    }

    public func entries(forYear year: Int) -> [DayKey: [HolidayEntry]] {
        let table = JapaneseHolidays.table(forYear: year)
        guard !table.isEmpty else { return [:] }
        var file: CountryHolidays?
        var column = 0
        if language != .ja, let loaded = data?() {
            let c = loaded.column(for: language)
            if loaded.langs[c] != "ja" {
                file = loaded
                column = c
            }
        }
        var out: [DayKey: [HolidayEntry]] = [:]
        out.reserveCapacity(table.count)
        for (day, japanese) in table {
            let name = file?.nationalName(onDay: day, column: column) ?? japanese
            out[day] = [HolidayEntry(full: name, short: name)]
        }
        return out
    }

    public func workdays(forYear year: Int) -> Set<DayKey> { [] }

    public func note(forYear year: Int) -> HolidayYearNote? { nil }
}
