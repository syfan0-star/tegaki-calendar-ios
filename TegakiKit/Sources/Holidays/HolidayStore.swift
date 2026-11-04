import Foundation

/// Reads the bundled holiday data (docs/M7B_CONTRACT.md §5.3) from a folder it is given: the app
/// passes the bundle's "HolidayData" folder, KitChecks and the tests the repository's
/// TegakiKit/HolidayData (from their own #filePath). Nothing here knows where the data lives.
///
/// The country files are read when a calendar first needs them and kept (each country once); a
/// calendar keeps up to 8 years of entries. index.json is read only when `index` is first asked
/// for (the settings screen) or a calendar's note needs it; choosing the automatic calendar at
/// launch reads neither it nor any file but the one country's. A missing folder or a file that
/// fails the checks never traps: Japan still has its holidays (`JapaneseHolidays`), anything else
/// is "none".
///
/// One store in the app (`HolidayChoice.store`); safe from any thread (an NSLock guards the caches).
public final class HolidayStore: @unchecked Sendable {
    public let directory: URL?

    private let lock = NSLock()
    private var countryCache: [String: CountryHolidays?] = [:]
    private var indexCache: HolidayIndex??
    private var calendarCache: [String: HolidayCalendar] = [:]

    public init(directory: URL?) {
        self.directory = directory
    }

    /// index.json, or nil when it cannot be read or fails the checks (read once).
    public var index: HolidayIndex? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = indexCache { return cached }
        let parsed = read("index.json").flatMap(HolidayIndex.parse)
        indexCache = .some(parsed)
        return parsed
    }

    /// True when the data has a file for the country `code` (two letters, either case), without
    /// reading it or the index; always true for Japan, whose holidays need no file.
    public func hasCountry(_ code: String) -> Bool {
        guard let country = Self.countryCode(code) else { return false }
        if country == "JP" { return true }
        guard let url = directory?.appendingPathComponent("\(country).json") else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// True when the country of `region` has a file that reads and passes the checks (the note of
    /// 0-20); always true for Japan.
    public func isReadable(_ region: HolidayRegion) -> Bool {
        region.country == "JP" || countryData(region.country) != nil
    }

    /// The calendar of `region` with names for a screen in `language` (§5.5): none for nil, Japan
    /// through `JapanHolidayBridge`, any other country from its file (none when the file cannot be
    /// read). A subdivision is matched against the file ignoring case, then through the index
    /// (`HolidayIndex.canonical`, renamed codes); one that still matches nothing is the whole
    /// country. The id is "<the data's code>|<language>".
    public func calendar(for region: HolidayRegion?, language: UILanguage) -> HolidayCalendar {
        guard let region, let country = Self.countryCode(region.country) else { return .none }
        if country == "JP" {
            if language == .ja { return .japan }
            return cachedCalendar("JP|\(language.rawValue)") {
                HolidayCalendar(id: "JP|\(language.rawValue)", region: HolidayRegion(country: "JP", subdivision: nil),
                                source: JapanHolidayBridge(language: language, data: { [weak self] in self?.countryData("JP") }))
            }
        }
        guard let data = countryData(country) else { return .none }
        var subdivision: CountryHolidays.Subdivision?
        if let wanted = region.subdivision {
            if let match = data.subdivision(matching: wanted) {
                subdivision = match
            } else if let canonical = index?.canonical(HolidayRegion(country: country, subdivision: wanted)),
                      let code = canonical.subdivision, let match = data.subdivision(matching: code) {
                subdivision = match
            }
        }
        let resolved = HolidayRegion(country: country, subdivision: subdivision?.code)
        let id = "\(resolved.code)|\(language.rawValue)"
        return cachedCalendar(id) {
            let source = CountryHolidaySource(data: data, subdivision: subdivision, column: data.column(for: language),
                                              language: language,
                                              indexEntry: { [weak self] in self?.index?.country(country) })
            return HolidayCalendar(id: id, region: resolved, source: source)
        }
    }

    // MARK: - Caches

    private func cachedCalendar(_ id: String, _ make: () -> HolidayCalendar) -> HolidayCalendar {
        lock.lock()
        defer { lock.unlock() }
        if let cached = calendarCache[id] { return cached }
        let made = make()
        calendarCache[id] = made
        return made
    }

    /// The parsed file of `country` (capitals), or nil when there is none or it fails the checks.
    func countryData(_ country: String) -> CountryHolidays? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = countryCache[country] { return cached }
        let parsed = read("\(country).json").flatMap { CountryHolidays.parse($0, expectedCountry: country) }
        countryCache[country] = .some(parsed)
        return parsed
    }

    private func read(_ name: String) -> Data? {
        guard let url = directory?.appendingPathComponent(name) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// "us" -> "US"; nil for anything but two ASCII letters.
    private static func countryCode(_ code: String) -> String? {
        let scalars = code.unicodeScalars
        guard scalars.count == 2, scalars.allSatisfy({ ("A"..."Z").contains($0) || ("a"..."z").contains($0) }) else { return nil }
        return code.uppercased()
    }
}

/// One country (and subdivision) in one screen language: the entries of a year, built from the
/// file once and kept for the last 8 years asked.
final class CountryHolidaySource: HolidaySource, @unchecked Sendable {
    static let cachedYears = 8

    private let data: CountryHolidays
    private let subdivision: CountryHolidays.Subdivision?
    private let column: Int
    private let language: UILanguage
    private let indexEntry: @Sendable () -> HolidayIndex.Country?
    private let lock = NSLock()
    private var years: [Int: (entries: [DayKey: [HolidayEntry]], workdays: Set<DayKey>)] = [:]
    private var recent: [Int] = []

    init(data: CountryHolidays, subdivision: CountryHolidays.Subdivision?, column: Int, language: UILanguage,
         indexEntry: @escaping @Sendable () -> HolidayIndex.Country?) {
        self.data = data
        self.subdivision = subdivision
        self.column = column
        self.language = language
        self.indexEntry = indexEntry
    }

    func entries(forYear year: Int) -> [DayKey: [HolidayEntry]] {
        table(year).entries
    }

    func workdays(forYear year: Int) -> Set<DayKey> {
        table(year).workdays
    }

    /// 0-29 and 0-30 from the index: outside `coverage` -> incomplete (also when it is after the
    /// notice), a notice country after its last official year -> before the notice.
    func note(forYear year: Int) -> HolidayYearNote? {
        guard let country = indexEntry() else { return nil }
        if !country.coverage.contains(year) { return .incomplete(until: country.coverage.upperBound) }
        if country.notice, let last = country.lastOfficialYear, year > last { return .beforeNotice }
        return nil
    }

    private func table(_ year: Int) -> (entries: [DayKey: [HolidayEntry]], workdays: Set<DayKey>) {
        lock.lock()
        defer { lock.unlock() }
        if let cached = years[year] {
            if recent.last != year {
                recent.removeAll { $0 == year }
                recent.append(year)
            }
            return cached
        }
        let made = (data.entries(forYear: year, column: column, subdivision: subdivision, language: language),
                    data.workdays(forYear: year))
        years[year] = made
        recent.append(year)
        if recent.count > Self.cachedYears {
            years[recent.removeFirst()] = nil
        }
        return made
    }
}
