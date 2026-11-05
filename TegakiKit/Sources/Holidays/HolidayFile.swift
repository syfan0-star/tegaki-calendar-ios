import Foundation

// The bundled holiday data, "tegaki-holidays/1" (docs/M7B_CONTRACT.md §5.2): one file per country
// written by tools/holidays/gen.py, and index.json. A file that does not pass every check of §5.3
// is unreadable, never half read; nothing here traps on bad data.

/// One country file: its names in every column, the national days, the working weekends and the
/// subdivisions that differ from the country.
public final class CountryHolidays: Sendable {
    public struct Subdivision: Sendable {
        public let code: String
        let add: [Int32]           // [day offset, name number, …]
        let addFrom: [Int32: Int32]
        let remove: [Int32]

        /// True when the subdivision adds or removes a holiday (gen.py writes no other, §5.1).
        public var hasDifference: Bool { !add.isEmpty || !remove.isEmpty }
    }

    /// The two capitals of the file.
    public let country: String
    /// The library's language of each name column; langs[0] is the country's own.
    public let langs: [String]
    /// The app language (`UILanguage.rawValue`) -> the column that has its names.
    public let ui: [String: Int]
    public let years: ClosedRange<Int>
    public let subdivisions: [Subdivision]

    let names: [[String]]
    let shorts: [Int: [String]]
    let flags: [HolidayFlags]
    let substFormat: [String]
    let days: [Int32]              // [day offset, name number, …] in day order
    let substFrom: [Int32: Int32]  // substituted day -> the weekend day it was swapped with
    let workdays: Set<Int>         // day numbers (DayKey.dayNumber)
    let epoch: Int                 // DayKey.dayNumber of the file's epoch

    /// Parses and checks a country file; nil for anything that is not a complete, consistent
    /// "tegaki-holidays/1" file of `expectedCountry` (when given).
    public static func parse(_ data: Data, expectedCountry: String? = nil) -> CountryHolidays? {
        guard let raw = try? JSONDecoder().decode(RawCountry.self, from: data) else { return nil }
        return CountryHolidays(raw, expectedCountry: expectedCountry)
    }

    private init?(_ raw: RawCountry, expectedCountry: String?) {
        guard raw.format == "tegaki-holidays/1",
              Self.isCountryCode(raw.country),
              expectedCountry.map({ $0 == raw.country }) ?? true,
              raw.years.count == 2, raw.years[0] <= raw.years[1],
              Self.fileYears.contains(raw.years[0]), Self.fileYears.contains(raw.years[1]),
              let epoch = DayKey(ymd: raw.epoch), Self.fileYears.contains(epoch.year) else { return nil }
        let columns = raw.langs.count
        guard columns >= 1,
              raw.flags.count == raw.names.count,
              raw.substFmt.count == columns,
              raw.names.allSatisfy({ $0.count == columns }),
              raw.ui.values.allSatisfy({ (0..<columns).contains($0) }) else { return nil }
        var shorts: [Int: [String]] = [:]
        for (key, value) in raw.short {
            guard let n = Int(key), (0..<raw.names.count).contains(n), value.count == columns else { return nil }
            shorts[n] = value
        }
        let nameCount = raw.names.count
        let substituted = Set(raw.flags.indices.filter { HolidayFlags(rawValue: raw.flags[$0]).contains(.substituted) })
        guard Self.isDayList(raw.days, names: nameCount),
              Self.isPairList(raw.substFrom),
              raw.workdays.allSatisfy(Self.isDayOffset),
              Self.fromDays(raw.days, substituted: substituted, are: raw.substFrom) else { return nil }
        var subdivisions: [Subdivision] = []
        var seen = Set<String>()
        for sub in raw.subdivisions {
            let add = sub.add ?? [], addFrom = sub.addFrom ?? [], remove = sub.remove ?? []
            guard HolidayRegion.isSubdivisionCode(sub.code), seen.insert(sub.code.lowercased()).inserted,
                  Self.isDayList(add, names: nameCount), Self.isDayList(remove, names: nameCount),
                  Self.isPairList(addFrom),
                  Self.fromDays(add, substituted: substituted, are: addFrom) else { return nil }
            subdivisions.append(Subdivision(code: sub.code, add: add.map(Int32.init), addFrom: Self.pairs(addFrom),
                                            remove: remove.map(Int32.init)))
        }
        country = raw.country
        langs = raw.langs
        ui = raw.ui
        years = raw.years[0]...raw.years[1]
        self.subdivisions = subdivisions
        names = raw.names
        self.shorts = shorts
        flags = raw.flags.map { HolidayFlags(rawValue: $0) }
        substFormat = raw.substFmt
        days = raw.days.map(Int32.init)
        substFrom = Self.pairs(raw.substFrom)
        self.epoch = epoch.dayNumber
        workdays = Set(raw.workdays.map { epoch.dayNumber + $0 })
    }

    /// The subdivision whose code is `code`, ignoring case (0-28).
    public func subdivision(matching code: String) -> Subdivision? {
        let wanted = code.lowercased()
        return subdivisions.first { $0.code.lowercased() == wanted }
    }

    /// The column whose names an app in `language` shows (§5.5): the language's own column; else
    /// the country's own language when it is one of the ten and written in the same script as the
    /// screen (Latin, Han or Hangul); else English; else the country's own language.
    public func column(for language: UILanguage) -> Int {
        if let own = ui[language.rawValue] { return own }
        if let standard = Self.appLanguage(ofLibraryLanguage: langs[0]), standard.holidayNameScript == language.holidayNameScript { return 0 }
        if let english = ui[UILanguage.en.rawValue] { return english }
        return 0
    }

    /// The app language of a python-holidays language code ("en_US" -> en, "zh_TW" -> zhHant,
    /// "pt_AO" -> ptBR), or nil when it is none of the ten.
    static func appLanguage(ofLibraryLanguage code: String) -> UILanguage? {
        let base = code.split(separator: "_").first.map(String.init) ?? code
        switch base {
        case "ja": return .ja
        case "en": return .en
        case "ko": return .ko
        case "fr": return .fr
        case "de": return .de
        case "es": return .es
        case "it": return .it
        case "pt": return .ptBR
        case "zh":
            switch code {
            case "zh_TW", "zh_HK", "zh_MO": return .zhHant
            default: return .zhHans
            }
        default:
            return nil
        }
    }

    /// The number of name rows (for the checks).
    public var nameCount: Int { names.count }

    /// The flags of name row `n` (for the checks).
    public func flags(ofName n: Int) -> HolidayFlags { flags[n] }

    /// The text of name row `n` in `column` as the file has it (a substituted day's template keeps
    /// its "%s"; for the checks).
    public func text(ofName n: Int, column: Int) -> String { names[n][column] }

    /// The entries of one year for one column (and one subdivision): the country's first (less the
    /// subdivision's removals), then the subdivision's additions, each in the order of the file.
    /// `language` is the screen's, for the estimate mark and the short name of a day off.
    public func entries(forYear year: Int, column: Int, subdivision: Subdivision?, language: UILanguage) -> [DayKey: [HolidayEntry]] {
        guard years.contains(year) else { return [:] }
        let first = Int32(DayKey(year: year, month: 1, day: 1).dayNumber - epoch)
        let last = Int32(DayKey(year: year, month: 12, day: 31).dayNumber - epoch)
        var out: [DayKey: [(name: Int32, entry: HolidayEntry)]] = [:]
        Self.forEachPair(days, from: first, through: last) { offset, nid in
            out[day(offset), default: []].append((nid, entry(nid, offset: offset, from: substFrom[offset], column: column,
                                                              language: language, isSubdivision: false)))
        }
        if let subdivision {
            Self.forEachPair(subdivision.remove, from: first, through: last) { offset, nid in
                let key = day(offset)
                if var list = out[key], let i = list.firstIndex(where: { $0.name == nid }) {
                    list.remove(at: i)
                    out[key] = list.isEmpty ? nil : list
                }
            }
            Self.forEachPair(subdivision.add, from: first, through: last) { offset, nid in
                out[day(offset), default: []].append((nid, entry(nid, offset: offset, from: subdivision.addFrom[offset],
                                                                  column: column, language: language, isSubdivision: true)))
            }
        }
        return out.mapValues { $0.map(\.entry) }
    }

    /// The working weekends of `year`.
    public func workdays(forYear year: Int) -> Set<DayKey> {
        guard years.contains(year) else { return [] }
        let first = DayKey(year: year, month: 1, day: 1).dayNumber
        let last = DayKey(year: year, month: 12, day: 31).dayNumber
        return Set(workdays.lazy.filter { (first...last).contains($0) }.map { DayKey(dayNumber: $0) })
    }

    /// The column texts of the national day `offset` (the first name of that day), for the
    /// Japanese bridge.
    func nationalName(onDay day: DayKey, column: Int) -> String? {
        let offset = Int32(day.dayNumber - epoch)
        var lo = 0, hi = days.count / 2
        while lo < hi {
            let mid = (lo + hi) / 2
            if days[2 * mid] < offset { lo = mid + 1 } else { hi = mid }
        }
        guard lo < days.count / 2, days[2 * lo] == offset else { return nil }
        return names[Int(days[2 * lo + 1])][column]
    }

    private func day(_ offset: Int32) -> DayKey {
        DayKey(dayNumber: epoch + Int(offset))
    }

    private func entry(_ nid: Int32, offset: Int32, from: Int32?, column: Int, language: UILanguage, isSubdivision: Bool) -> HolidayEntry {
        let n = Int(nid)
        let flags = self.flags[n]
        var full = names[n][column]
        var short = shorts[n]?[column] ?? full
        if flags.contains(.substituted) {
            if let from {
                full = Self.filled(full, with: day(from), format: substFormat[column])
            }
            if short.isEmpty || short.contains("%s") {
                short = KitStrings.text("kit.holiday.dayOff", language)
            }
        }
        if flags.contains(.estimated) {
            full += KitStrings.text("kit.holiday.estimatedSuffix", language)
        }
        return HolidayEntry(full: full, short: short, flags: flags, isSubdivision: isSubdivision)
    }

    /// `template` with its "%s" replaced by `day` written in `format` (%Y, %m and %d, zero-padded).
    static func filled(_ template: String, with day: DayKey, format: String) -> String {
        guard let range = template.range(of: "%s") else { return template }
        var date = ""
        var chars = format.makeIterator()
        while let c = chars.next() {
            guard c == "%" else { date.append(c); continue }
            switch chars.next() {
            case "Y": date += String(format: "%04d", day.year)
            case "m": date += String(format: "%02d", day.month)
            case "d": date += String(format: "%02d", day.day)
            case let other?: date += "%" + String(other)
            case nil: date += "%"
            }
        }
        return template.replacingCharacters(in: range, with: date)
    }

    // MARK: - Checks of §5.3

    /// The years a file may name. The arithmetic on years and days cannot overflow inside it.
    private static let fileYears = 1...9999

    /// A day offset from the epoch. Not `abs(x)`, which traps on `Int.min`.
    private static func isDayOffset(_ x: Int) -> Bool {
        (-1_000_000..<1_000_000).contains(x)
    }

    /// Every substituted day of `list` ([day, name, …]) has its other day in `from` ([day, other day, …]):
    /// without it the screen would show the template's "%s".
    private static func fromDays(_ list: [Int], substituted: Set<Int>, are from: [Int]) -> Bool {
        let days = Set(stride(from: 0, to: from.count, by: 2).map { from[$0] })
        return stride(from: 0, to: list.count, by: 2).allSatisfy { !substituted.contains(list[$0 + 1]) || days.contains(list[$0]) }
    }

    private static func isCountryCode(_ s: String) -> Bool {
        s.unicodeScalars.count == 2 && s.unicodeScalars.allSatisfy { ("A"..."Z").contains($0) }
    }

    /// [day, name, …]: even, days in order (equal days may follow each other), names in range.
    private static func isDayList(_ list: [Int], names: Int) -> Bool {
        guard list.count % 2 == 0 else { return false }
        var previous = Int.min
        var i = 0
        while i < list.count {
            guard list[i] >= previous, (0..<names).contains(list[i + 1]), isDayOffset(list[i]) else { return false }
            previous = list[i]
            i += 2
        }
        return true
    }

    /// [day, other day, …]: even, first days in order.
    private static func isPairList(_ list: [Int]) -> Bool {
        guard list.count % 2 == 0 else { return false }
        var previous = Int.min
        var i = 0
        while i < list.count {
            guard list[i] >= previous, isDayOffset(list[i]), isDayOffset(list[i + 1]) else { return false }
            previous = list[i]
            i += 2
        }
        return true
    }

    private static func pairs(_ list: [Int]) -> [Int32: Int32] {
        var out: [Int32: Int32] = [:]
        var i = 0
        while i + 1 < list.count {
            out[Int32(list[i])] = Int32(list[i + 1])
            i += 2
        }
        return out
    }

    /// Calls `body(day, name)` for the pairs of `list` whose day is in `first...last` (the days
    /// are in order, so the start is found by halving).
    private static func forEachPair(_ list: [Int32], from first: Int32, through last: Int32, _ body: (Int32, Int32) -> Void) {
        var lo = 0, hi = list.count / 2
        while lo < hi {
            let mid = (lo + hi) / 2
            if list[2 * mid] < first { lo = mid + 1 } else { hi = mid }
        }
        var i = 2 * lo
        while i + 1 < list.count, list[i] <= last {
            body(list[i], list[i + 1])
            i += 2
        }
    }

    private struct RawCountry: Decodable {
        let format: String
        let country: String
        let years: [Int]
        let epoch: String
        let langs: [String]
        let ui: [String: Int]
        let names: [[String]]
        let substFmt: [String]
        let short: [String: [String]]
        let flags: [Int]
        let days: [Int]
        let substFrom: [Int]
        let workdays: [Int]
        let subdivisions: [RawSubdivision]
    }

    private struct RawSubdivision: Decodable {
        let code: String
        let add: [Int]?
        let addFrom: [Int]?
        let remove: [Int]?
    }
}

/// index.json: what the settings show about each country (§5.1).
public struct HolidayIndex: Sendable {
    public struct Country: Sendable {
        public let code: String
        /// Only the subdivisions that differ from the country (§5.1); empty means no subdivision screen.
        public let subdivisions: [Subdivision]
        /// Old code -> today's code (a subdivision renamed by a newer library, §5.11).
        public let renamed: [String: String]
        /// The last year of the library's special tables, or of a published calendar compared with the data (0-29, §5.1).
        public let lastOfficialYear: Int?
        /// The country's days off are set by a yearly government notice (0-29).
        public let notice: Bool
        /// The years whose data looks complete (0-30).
        public let coverage: ClosedRange<Int>

        public init(code: String, subdivisions: [Subdivision], renamed: [String: String] = [:],
                    lastOfficialYear: Int? = nil, notice: Bool = false, coverage: ClosedRange<Int> = 2000...2099) {
            self.code = code
            self.subdivisions = subdivisions
            self.renamed = renamed
            self.lastOfficialYear = lastOfficialYear
            self.notice = notice
            self.coverage = coverage
        }
    }

    public struct Subdivision: Sendable {
        /// The data's spelling ("CA", "971", "South Canterbury").
        public let code: String
        /// The name to show ("Auckland", "Nova Scotia", "Guadeloupe"; §5.2).
        public let display: String
        /// Every other name of the library, for the search.
        public let names: [String]
        /// Not an ISO-like code (a city: "Augsburg", "Andria", "South Canterbury").
        public let local: Bool

        public init(code: String, display: String, names: [String] = [], local: Bool = false) {
            self.code = code
            self.display = display
            self.names = names
            self.local = local
        }
    }

    public let countries: [Country]
    private let byCode: [String: Int]

    public init(countries: [Country]) {
        self.countries = countries
        var byCode: [String: Int] = [:]
        for (i, c) in countries.enumerated() where byCode[c.code.uppercased()] == nil {
            byCode[c.code.uppercased()] = i
        }
        self.byCode = byCode
    }

    /// The country of `code`, ignoring case.
    public func country(_ code: String) -> Country? {
        byCode[code.uppercased()].map { countries[$0] }
    }

    /// `region` in the data's spelling: a subdivision matched ignoring case (or through `renamed`),
    /// an unknown subdivision as the whole country; nil for a country without data.
    public func canonical(_ region: HolidayRegion) -> HolidayRegion? {
        guard let country = country(region.country) else { return nil }
        let whole = HolidayRegion(country: country.code, subdivision: nil)
        guard let wanted = region.subdivision?.lowercased() else { return whole }
        if let sub = country.subdivisions.first(where: { $0.code.lowercased() == wanted }) {
            return HolidayRegion(country: country.code, subdivision: sub.code)
        }
        if let renamed = country.renamed.first(where: { $0.key.lowercased() == wanted })?.value.lowercased(),
           let sub = country.subdivisions.first(where: { $0.code.lowercased() == renamed }) {
            return HolidayRegion(country: country.code, subdivision: sub.code)
        }
        return whole
    }

    /// Parses and checks index.json (§5.3: coverage from ≤ until, codes of 0-28); nil when any
    /// part is wrong.
    public static func parse(_ data: Data) -> HolidayIndex? {
        guard let raw = try? JSONDecoder().decode(RawIndex.self, from: data),
              raw.format == "tegaki-holidays-index/1" else { return nil }
        var countries: [Country] = []
        var seen = Set<String>()
        for c in raw.countries {
            guard c.code.unicodeScalars.count == 2, c.code.unicodeScalars.allSatisfy({ ("A"..."Z").contains($0) }),
                  seen.insert(c.code).inserted,
                  c.coverage.from <= c.coverage.until,
                  c.subdivisions.allSatisfy({ HolidayRegion.isSubdivisionCode($0.code) }),
                  c.renamed.allSatisfy({ HolidayRegion.isSubdivisionCode($0.key) && HolidayRegion.isSubdivisionCode($0.value) })
            else { return nil }
            countries.append(Country(
                code: c.code,
                subdivisions: c.subdivisions.map { Subdivision(code: $0.code, display: $0.display, names: $0.names, local: $0.local) },
                renamed: c.renamed, lastOfficialYear: c.lastOfficialYear, notice: c.notice,
                coverage: c.coverage.from...c.coverage.until))
        }
        return HolidayIndex(countries: countries)
    }

    private struct RawIndex: Decodable {
        let format: String
        let countries: [RawCountry]
    }

    private struct RawCountry: Decodable {
        let code: String
        let subdivisions: [RawSubdivision]
        let renamed: [String: String]
        let lastOfficialYear: Int?
        let notice: Bool
        let coverage: RawCoverage
    }

    private struct RawSubdivision: Decodable {
        let code: String
        let display: String
        let names: [String]
        let local: Bool
    }

    private struct RawCoverage: Decodable {
        let from: Int
        let until: Int
    }
}

extension UILanguage {
    /// The script family of §5.5 rule 2: Latin (en fr de es it pt-BR), Han (ja zh-Hans zh-Hant),
    /// Hangul (ko).
    var holidayNameScript: Int {
        switch self {
        case .en, .fr, .de, .es, .it, .ptBR: return 0
        case .ja, .zhHans, .zhHant: return 1
        case .ko: return 2
        }
    }
}
