import Foundation
@_exported import DayKit

/// Japanese national holidays (国民の祝日・休日), rule-based, valid for 2000–2099.
///
/// Ported one-to-one from the web version (js/util/holidays-jp.js), which was verified against the
/// 内閣府 syukujitsu.csv for 2000–2027 (0 mismatches) and the NAOJ equinox prediction table for
/// 2020–2050. Years outside 2000–2099 return no holidays rather than guesses.
///
/// Labels: 第3条第2項 days are named 「振替休日」 and 第3条第3項 days 「国民の休日」 (the CSV says just 「休日」).
/// Future special laws (like the 2019–2021 moves) belong in `specialDays(_:)` so the 第3条 rules see them.
public enum JapaneseHolidays {
    public static let minYear = 2000
    public static let maxYear = 2099

    public struct Holiday: Hashable, Sendable {
        public let day: DayKey
        public let name: String

        public init(day: DayKey, name: String) {
            self.day = day
            self.name = name
        }
    }

    // MARK: - Public API

    /// All 祝日・休日 of year `y`, sorted by date. Empty for years outside 2000–2099.
    public static func holidays(ofYear y: Int) -> [Holiday] {
        let table = table(forYear: y)
        return table.keys.sorted().map { Holiday(day: $0, name: table[$0] ?? "") }
    }

    /// All 祝日・休日 of year `y` as a dictionary. Empty for years outside 2000–2099.
    public static func table(forYear y: Int) -> [DayKey: String] {
        guard y >= minYear, y <= maxYear else { return [:] }
        let base = shukujitsu(y)
        var out = base
        addSubstituteHolidays(y, base: base, into: &out)
        addCitizensHolidays(y, base: base, into: &out)
        return out
    }

    /// Holiday name of a day, e.g. '元日', '振替休日', '国民の休日'; nil if it is not a holiday
    /// (or the year is outside 2000–2099).
    public static func name(of day: DayKey) -> String? {
        table(forYear: day.year)[day]
    }

    /// Holiday name of the local calendar day containing `date`.
    public static func name(of date: Date, calendar: Calendar = DayKey.deviceCalendar) -> String? {
        name(of: DayKey(date, calendar: calendar))
    }

    /// Holidays between `start` and `end`, both inclusive, sorted by date.
    public static func holidays(from start: DayKey, through end: DayKey) -> [Holiday] {
        guard start <= end else { return [] }
        let y0 = max(minYear, start.year)
        let y1 = min(maxYear, end.year)
        guard y0 <= y1 else { return [] }
        var result: [Holiday] = []
        for y in y0...y1 {
            for holiday in holidays(ofYear: y) where holiday.day >= start && holiday.day <= end {
                result.append(holiday)
            }
        }
        return result
    }

    /// Holiday names for an arbitrary set of days (one table lookup per distinct year).
    public static func names(for days: [DayKey]) -> [DayKey: String] {
        var tables: [Int: [DayKey: String]] = [:]
        var result: [DayKey: String] = [:]
        for day in days {
            if tables[day.year] == nil { tables[day.year] = table(forYear: day.year) }
            if let name = tables[day.year]?[day] { result[day] = name }
        }
        return result
    }

    // MARK: - Rules

    /// Day-of-month of the n-th Monday of month m.
    private static func nthMonday(_ y: Int, _ m: Int, _ n: Int) -> Int {
        1 + ((8 - DayKey(year: y, month: m, day: 1).weekday) % 7) + (n - 1) * 7
    }

    // Equinox days (traditional formula, valid 1980–2099). Official dates are fixed each February by
    // the NAOJ 暦要項 for the following year; the formula matches every published/predicted date 2000–2050.
    private static func vernalEquinoxDay(_ y: Int) -> Int {
        Int(floor(20.8431 + 0.242194 * Double(y - 1980) - Double((y - 1980) / 4)))
    }

    private static func autumnalEquinoxDay(_ y: Int) -> Int {
        Int(floor(23.2488 + 0.242194 * Double(y - 1980) - Double((y - 1980) / 4)))
    }

    /// 国民の祝日 (祝日法 第2条, plus days a special law treats as 祝日) of year y.
    private static func shukujitsu(_ y: Int) -> [DayKey: String] {
        var h: [DayKey: String] = [:]
        func add(_ m: Int, _ d: Int, _ name: String) {
            h[DayKey(year: y, month: m, day: d)] = name
        }

        add(1, 1, "元日")
        add(1, nthMonday(y, 1, 2), "成人の日")
        add(2, 11, "建国記念の日")
        if y >= 2020 { add(2, 23, "天皇誕生日") }
        add(3, vernalEquinoxDay(y), "春分の日")
        if y >= 2007 {
            add(4, 29, "昭和の日")
            add(5, 4, "みどりの日")
        } else {
            add(4, 29, "みどりの日")
        }
        add(5, 3, "憲法記念日")
        add(5, 5, "こどもの日")
        if y >= 2003 { add(7, nthMonday(y, 7, 3), "海の日") } else { add(7, 20, "海の日") }
        if y >= 2016 { add(8, 11, "山の日") }
        if y >= 2003 { add(9, nthMonday(y, 9, 3), "敬老の日") } else { add(9, 15, "敬老の日") }
        add(9, autumnalEquinoxDay(y), "秋分の日")
        add(10, nthMonday(y, 10, 2), y >= 2020 ? "スポーツの日" : "体育の日")
        add(11, 3, "文化の日")
        add(11, 23, "勤労感謝の日")
        if y <= 2018 { add(12, 23, "天皇誕生日") }

        applySpecialDays(y, &h)
        return h
    }

    private struct SpecialDays {
        /// Relocates a regular holiday (by name) within the year: (name, month, day).
        var moves: [(String, Int, Int)] = []
        /// Inserts a day that counts as a 祝日 for 第3条 (振替休日 / 国民の休日): (month, day, name).
        var adds: [(Int, Int, String)] = []
    }

    /// One-off changes made by special laws.
    private static func specialDays(_ y: Int) -> SpecialDays? {
        switch y {
        case 2019: // 天皇の即位の日及び即位礼正殿の儀の行われる日を休日とする法律
            return SpecialDays(adds: [(5, 1, "即位の日"), (10, 22, "即位礼正殿の儀")])
        case 2020: // 東京オリンピック・パラリンピック特措法（平成30年法律第55号）
            return SpecialDays(moves: [("海の日", 7, 23), ("スポーツの日", 7, 24), ("山の日", 8, 10)])
        case 2021: // 同改正（令和2年法律第68号）
            return SpecialDays(moves: [("海の日", 7, 22), ("スポーツの日", 7, 23), ("山の日", 8, 8)])
        default:
            return nil
        }
    }

    private static func applySpecialDays(_ y: Int, _ h: inout [DayKey: String]) {
        guard let special = specialDays(y) else { return }
        for (name, m, d) in special.moves {
            for (key, n) in h where n == name { h[key] = nil }
            h[DayKey(year: y, month: m, day: d)] = name
        }
        for (m, d, name) in special.adds {
            h[DayKey(year: y, month: m, day: d)] = name
        }
    }

    /// 第3条第2項 振替休日: a 祝日 on Sunday makes the nearest following non-祝日 day a holiday.
    private static func addSubstituteHolidays(_ y: Int, base: [DayKey: String], into out: inout [DayKey: String]) {
        for d in base.keys where d.weekday == 0 {
            if y >= 2007 {
                var n = d.adding(days: 1)
                while base[n] != nil { n = n.adding(days: 1) }
                out[n] = "振替休日"
            } else {
                // Before 2007 only the next day (Monday) qualified, and only if it was not itself a 祝日.
                let n = d.adding(days: 1)
                if base[n] == nil { out[n] = "振替休日" }
            }
        }
    }

    /// 第3条第3項 国民の休日: a non-祝日 day sandwiched between two 祝日.
    private static func addCitizensHolidays(_ y: Int, base: [DayKey: String], into out: inout [DayKey: String]) {
        for d in base.keys {
            let mid = d.adding(days: 1)
            let next = d.adding(days: 2)
            if base[mid] != nil || base[next] == nil || out[mid] != nil { continue }
            if y < 2007 && mid.weekday == 0 { continue } // the pre-2007 wording excluded Sundays
            out[mid] = "国民の休日"
        }
    }
}
