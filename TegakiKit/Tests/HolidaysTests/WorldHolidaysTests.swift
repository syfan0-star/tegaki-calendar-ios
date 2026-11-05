import CryptoKit
import Foundation
import Holidays
import XCTest

/// The holidays of the world (docs/M7B_CONTRACT.md §5, §7.2): the bundled data of python-holidays
/// 0.107 (TegakiKit/HolidayData, read through `holidayDataDirectory()`), Japan through
/// `JapaneseHolidays`, the setting and the store. The answers that move with the library's version
/// (0-14) are those of 0.107; docs/M7B.md (H) lists what changed from 0.83.
final class WorldHolidaysTests: XCTestCase {
    private let store = HolidayStore(directory: holidayDataDirectory())

    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey {
        DayKey(year: y, month: m, day: d)
    }

    private func region(_ code: String, file: StaticString = #filePath, line: UInt = #line) -> HolidayRegion? {
        let r = HolidayRegion(code: code)
        XCTAssertNotNil(r, "\(code) is a region code", file: file, line: line)
        return r
    }

    private func calendar(_ code: String, _ language: UILanguage) -> HolidayCalendar {
        store.calendar(for: HolidayRegion(code: code), language: language)
    }

    private func days(of year: Int) -> [DayKey] {
        (day(year, 1, 1).dayNumber...day(year, 12, 31).dayNumber).map { DayKey(dayNumber: $0) }
    }

    private func data(_ name: String) -> Data? {
        try? Data(contentsOf: holidayDataDirectory().appendingPathComponent(name))
    }

    // MARK: - Japan

    func testJapanIsJapaneseHolidaysFrom2000To2099() {
        let fromStore = calendar("JP", .ja)
        XCTAssertEqual(fromStore, HolidayCalendar.japan)
        XCTAssertEqual(HolidayCalendar.japan.id, "JP|ja")
        for year in 2000...2099 {
            let all = days(of: year)
            let expected = JapaneseHolidays.names(for: all)
            XCTAssertEqual(HolidayCalendar.japan.names(for: all), expected, "\(year)")
            XCTAssertEqual(fromStore.names(for: all), expected, "\(year)")
            XCTAssertEqual(HolidayCalendar.japan.names(for: all, style: .short), expected, "\(year) short")
        }
        XCTAssertEqual(JapaneseHolidays.names(for: (2000...2099).flatMap(days(of:))).count, 1773)
        XCTAssertTrue(HolidayCalendar.japan.names(for: [day(1999, 12, 31), day(2100, 1, 1)]).isEmpty)
        XCTAssertNil(HolidayCalendar.japan.note(forYear: 2026))
        XCTAssertFalse(HolidayCalendar.japan.isWorkday(day(2026, 10, 10)))
    }

    func testJapanDataMatchesJapaneseHolidaysDates() throws {
        let jp = try XCTUnwrap(data("JP.json").flatMap { CountryHolidays.parse($0, expectedCountry: "JP") })
        let ja = try XCTUnwrap(jp.ui["ja"])
        var differ: [String] = []
        var count = 0
        for year in 2000...2099 {
            let table = JapaneseHolidays.table(forYear: year)
            let entries = jp.entries(forYear: year, column: ja, subdivision: nil, language: .ja)
            XCTAssertEqual(Set(entries.keys), Set(table.keys), "\(year)")
            count += entries.count
            for (d, list) in entries where list.map(\.full) != [table[d] ?? ""] {
                differ.append("\(d) \(table[d] ?? "-") / \(list.map(\.full).joined(separator: ";"))")
            }
        }
        XCTAssertEqual(count, 1773)
        XCTAssertEqual(differ.sorted(), ["2019-05-01 即位の日 / 天皇の即位の日", "2019-10-22 即位礼正殿の儀 / 即位礼正殿の儀が行われる日"])
    }

    func testJapanUsesJapaneseHolidaysNamesForTheJaColumn() {
        XCTAssertEqual(calendar("JP", .zhHans).name(of: day(2019, 5, 1)), "即位の日")
        XCTAssertEqual(calendar("JP", .zhHant).name(of: day(2019, 10, 22)), "即位礼正殿の儀")
        for year in [2019, 2026, 2099] {
            XCTAssertEqual(calendar("JP", .zhHans).names(for: days(of: year)), JapaneseHolidays.names(for: days(of: year)), "\(year)")
        }
        // English (and every Latin screen, and Korean: Hangul is not Han, §5.5) takes JP.json's English.
        XCTAssertEqual(calendar("JP", .en).name(of: day(2026, 10, 12)), "Sports Day")
        XCTAssertEqual(calendar("JP", .de).name(of: day(2026, 5, 6)), "Substitute Holiday")
        XCTAssertEqual(calendar("JP", .ko).name(of: day(2026, 1, 1)), "New Year's Day")
        XCTAssertEqual(calendar("JP", .en).name(of: day(2019, 5, 1)), "Emperor's Enthronement Day")
    }

    // MARK: - Known days

    func testKnownDates() {
        let estimated = KitStrings.text("kit.holiday.estimatedSuffix", .en)
        let cases: [(String, UILanguage, DayKey, String?)] = [
            ("US", .en, day(2026, 7, 3), "Independence Day (observed)"),
            ("US", .en, day(2026, 11, 26), "Thanksgiving Day"),
            ("US", .en, day(2026, 10, 12), "Columbus Day"),
            ("DE-BY", .de, day(2026, 1, 6), "Heilige Drei Könige"),
            ("DE", .de, day(2026, 1, 6), nil),
            ("GB-SCT", .en, day(2026, 1, 2), "New Year Holiday"),
            ("GB-SCT", .en, day(2026, 8, 3), "Summer Bank Holiday"),
            ("GB-ENG", .en, day(2026, 8, 31), "Late Summer Bank Holiday"),
            ("KR", .ko, day(2026, 2, 17), "설날"),
            ("KR", .ko, day(2026, 9, 25), "추석"),
            ("KR", .en, day(2026, 9, 25), "Chuseok"),
            ("TW", .zhHant, day(2026, 10, 9), "國慶日（補假）"),
            ("TW", .zhHant, day(2026, 10, 10), "國慶日"),
            ("BR", .ptBR, day(2026, 4, 21), "Tiradentes"),
            ("BR", .ptBR, day(2026, 11, 20), "Dia Nacional de Zumbi e da Consciência Negra"),
            ("BR-SP", .ptBR, day(2026, 7, 9), "Revolução Constitucionalista"),
            ("CH-ZH", .de, day(2026, 4, 6), "Ostermontag"),
            ("CH-ZH", .fr, day(2026, 4, 6), "Lundi de Pâques"),
            // 0.107's template (0.83 had "休息日（2025-01-26日起取代）").
            ("CN", .zhHans, day(2025, 2, 3), "休息日（由 2025-01-26 调休）"),
            ("CN", .en, day(2025, 2, 3), "Day off (substituted from 01/26/2025)"),
            // Still an estimate in 0.107.
            ("AE", .en, day(2026, 3, 20), "Eid al-Fitr" + estimated),
            ("US-CA", .en, day(2026, 10, 12), nil),
            ("US-CA", .en, day(2026, 11, 27), "Day After Thanksgiving"),
        ]
        for (code, language, d, expected) in cases {
            XCTAssertEqual(calendar(code, language).name(of: d), expected, "\(code) \(language.rawValue) \(d)")
        }
        XCTAssertEqual(calendar("CN", .zhHans).name(of: day(2025, 2, 3), style: .short), "休息日")
        XCTAssertEqual(calendar("CN", .en).name(of: day(2025, 2, 3), style: .short), "Day off")
        XCTAssertEqual(calendar("AE", .en).name(of: day(2026, 3, 20), style: .short), "Eid al-Fitr")
        // Canada as a whole (0-31): five holidays in 2026; Thanksgiving and Victoria Day are the provinces'.
        XCTAssertEqual(calendar("CA", .en).names(for: days(of: 2026)).values.sorted(),
                       ["Canada Day", "Christmas Day", "Good Friday", "Labour Day", "New Year's Day"])
    }

    func testSubdivisionAddsAndRemoves() throws {
        // BA-SRP 2061-05-01: the country's holiday, then the subdivision's (§5.3, never re-sorted).
        let srp = try XCTUnwrap(calendar("BA-SRP", .en).entries(forYear: 2061)[day(2061, 5, 1)])
        XCTAssertEqual(srp.map(\.isSubdivision), [false, true])
        XCTAssertEqual(srp.first?.full, "International Labor Day")
        XCTAssertEqual(calendar("BA", .en).entries(forYear: 2061)[day(2061, 5, 1)]?.count, 1)
        // US-CA removes Columbus Day and adds the Day After Thanksgiving.
        let california = calendar("US-CA", .en)
        XCTAssertNil(california.name(of: day(2026, 10, 12)))
        XCTAssertEqual(california.entries(forYear: 2026)[day(2026, 11, 27)]?.map(\.isSubdivision), [true])
        XCTAssertEqual(california.entries(forYear: 2026)[day(2026, 11, 26)]?.map(\.isSubdivision), [false])
        XCTAssertEqual(california.region?.code, "US-CA")
        XCTAssertEqual(california.id, "US-CA|en")
    }

    func testTwoHolidaysOnOneDayAreJoined() {
        XCTAssertEqual(calendar("KR", .ko).name(of: day(2025, 5, 5)), "부처님오신날 · 어린이날")
        XCTAssertEqual(calendar("KR", .ko).names(for: [day(2025, 5, 5)])[day(2025, 5, 5)], "부처님오신날 · 어린이날")
        XCTAssertEqual(HolidayCalendar.separator, " · ")
    }

    func testWorkdays() {
        let china = calendar("CN", .zhHans)
        XCTAssertTrue(china.isWorkday(day(2024, 2, 4)))   // a working Sunday
        XCTAssertTrue(china.isWorkday(day(2024, 5, 11)))  // a working Saturday
        XCTAssertFalse(china.isWorkday(day(2024, 2, 3)))
        XCTAssertNil(china.name(of: day(2024, 2, 4)))
        XCTAssertFalse(calendar("US", .en).isWorkday(day(2024, 2, 4)))
        XCTAssertFalse(HolidayCalendar.japan.isWorkday(day(2024, 2, 4)))
    }

    func testNoneIsEmpty() {
        let none = HolidayCalendar.none
        XCTAssertEqual(none.id, "none")
        XCTAssertNil(none.region)
        XCTAssertTrue(none.names(for: days(of: 2026)).isEmpty)
        XCTAssertNil(none.name(of: day(2026, 1, 1)))
        XCTAssertFalse(none.isWorkday(day(2024, 2, 4)))
        XCTAssertNil(none.note(forYear: 2026))
        XCTAssertEqual(store.calendar(for: nil, language: .en), HolidayCalendar.none)
    }

    // MARK: - Bad input

    func testBadInputNeverCrashes() throws {
        for code in ["", "-", "US-", "-CA", "US--CA", "J", "JPN", "1A", "US-C@", "日本"] {
            XCTAssertNil(HolidayRegion(code: code), code)
            XCTAssertEqual(HolidaySetting(storageValue: code), .automatic, code)
        }
        XCTAssertEqual(calendar("US-ZZ", .en).id, "US|en")     // an unknown subdivision: the whole country
        XCTAssertEqual(calendar("ZZ", .en), HolidayCalendar.none)
        XCTAssertEqual(calendar("AC", .en), HolidayCalendar.none)  // a region without data (0-20)

        // Files that fail the checks of §5.3 are unreadable: no holidays, no trap.
        let good: [String: Any] = [
            "format": "tegaki-holidays/1", "country": "ZZ", "source": "test", "years": [2000, 2099], "epoch": "2000-01-01",
            "langs": ["en"], "ui": ["en": 0], "names": [["Day One"]], "substFmt": ["%Y-%m-%d"], "short": [String: Any](),
            "flags": [0], "days": [0, 0], "substFrom": [Int](), "workdays": [Int](), "subdivisions": [Any](),
        ]
        let broken: [(String, (inout [String: Any]) -> Void)] = [
            ("format", { $0["format"] = "tegaki-holidays/2" }),
            ("years", { $0["years"] = [2000, 2050, 2099] }),
            ("days odd", { $0["days"] = [0, 0, 1] }),
            ("days out of order", { $0["days"] = [5, 0, 1, 0] }),
            ("name number", { $0["days"] = [0, 1] }),
            ("flags", { $0["flags"] = [0, 0] }),
            ("columns", { $0["names"] = [["Day One", "Jour un"]] }),
            ("ui", { $0["ui"] = ["en": 1] }),
            // Numbers the arithmetic would trap on.
            ("day Int.min", { $0["days"] = [Int.min, 0] }),
            ("day Int.max", { $0["days"] = [Int.max, 0] }),
            ("substFrom Int.min", { $0["substFrom"] = [Int.min, 0] }),
            ("substFrom's other day Int.min", { $0["substFrom"] = [0, Int.min] }),
            ("workday Int.max", { $0["workdays"] = [Int.max] }),
            ("workday Int.min", { $0["workdays"] = [Int.min] }),
            ("epoch's year Int.max", { $0["epoch"] = "9223372036854775807-01-01" }),
            ("epoch's large year", { $0["epoch"] = "99999999999-01-01" }),
            ("years Int", { $0["years"] = [Int.min, Int.max] }),
            ("years large", { $0["years"] = [2000, 99999999999] }),
            ("a subdivision's add Int.min", { $0["subdivisions"] = [["code": "AA", "add": [Int.min, 0]]] }),
            ("a subdivision's addFrom Int.min", { $0["subdivisions"] = [["code": "AA", "addFrom": [Int.min, 0]]] }),
            ("a subdivision's remove Int.min", { $0["subdivisions"] = [["code": "AA", "remove": [Int.min, 0]]] }),
            // A substituted day without the day it was swapped with would show "%s".
            ("substituted without from", { $0["names"] = [["Off (%s)"]]; $0["flags"] = [HolidayFlags.substituted.rawValue] }),
            ("a subdivision's substituted without from", {
                $0["names"] = [["Day One"], ["Off (%s)"]]
                $0["flags"] = [0, HolidayFlags.substituted.rawValue]
                $0["subdivisions"] = [["code": "AA", "add": [1, 1]]]
            }),
        ]
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("WorldHolidaysTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let goodData = try JSONSerialization.data(withJSONObject: good)
        XCTAssertNotNil(CountryHolidays.parse(goodData), "the unbroken file reads")
        var swapped = good
        swapped["names"] = [["Off (%s)"]]
        swapped["flags"] = [HolidayFlags.substituted.rawValue]
        swapped["substFrom"] = [0, 3]
        XCTAssertNotNil(CountryHolidays.parse(try JSONSerialization.data(withJSONObject: swapped)), "a substituted day with its other day reads")
        for (what, breakIt) in broken {
            var json = good
            breakIt(&json)
            let bytes = try JSONSerialization.data(withJSONObject: json)
            XCTAssertNil(CountryHolidays.parse(bytes), what)
            try bytes.write(to: folder.appendingPathComponent("ZZ.json"))
            let fresh = HolidayStore(directory: folder)
            let zz = try XCTUnwrap(region("ZZ"))
            XCTAssertTrue(fresh.hasCountry("ZZ"), what)
            XCTAssertFalse(fresh.isReadable(zz), what)
            XCTAssertEqual(fresh.calendar(for: zz, language: .en), HolidayCalendar.none, what)
        }
        try goodData.write(to: folder.appendingPathComponent("ZZ.json"))
        let fresh = HolidayStore(directory: folder)
        let zz = try XCTUnwrap(region("ZZ"))
        XCTAssertTrue(fresh.isReadable(zz))
        XCTAssertEqual(fresh.calendar(for: zz, language: .en).name(of: day(2000, 1, 1)), "Day One")
        XCTAssertNil(fresh.index, "no index.json in the folder")
        XCTAssertNil(HolidayIndex.parse(Data("{}".utf8)))
        XCTAssertNil(CountryHolidays.parse(Data("not json".utf8)))
    }

    // MARK: - The setting

    func testSettingStorageRoundTrip() {
        let cases: [(String?, HolidaySetting, String)] = [
            (nil, .automatic, "auto"), ("", .automatic, "auto"), ("auto", .automatic, "auto"), ("none", .none, "none"),
            ("JP", .region(HolidayRegion(code: "JP")!), "JP"), ("US-CA", .region(HolidayRegion(code: "US-CA")!), "US-CA"),
            ("GB-SCT", .region(HolidayRegion(code: "GB-SCT")!), "GB-SCT"),
            ("NZ-South Canterbury", .region(HolidayRegion(code: "NZ-South Canterbury")!), "NZ-South Canterbury"),
            ("AR-C", .region(HolidayRegion(code: "AR-C")!), "AR-C"), ("AT-9", .region(HolidayRegion(code: "AT-9")!), "AT-9"),
            ("FR-971", .region(HolidayRegion(code: "FR-971")!), "FR-971"), ("broken!", .automatic, "auto"),
        ]
        for (stored, setting, back) in cases {
            XCTAssertEqual(HolidaySetting(storageValue: stored), setting, stored ?? "nil")
            XCTAssertEqual(setting.storageValue, back, stored ?? "nil")
            XCTAssertEqual(HolidaySetting(storageValue: setting.storageValue), setting, stored ?? "nil")
        }
        XCTAssertEqual(HolidayRegion(code: "us-ca")?.code, "US-ca")   // the country in capitals, the subdivision as written
        XCTAssertEqual(HolidayRegion(code: "NZ-South Canterbury")?.subdivision, "South Canterbury")
    }

    func testSubdivisionCodesAreMatchedIgnoringCase() throws {
        let index = try XCTUnwrap(store.index)
        XCTAssertEqual(index.canonical(try XCTUnwrap(region("nz-south canterbury")))?.code, "NZ-South Canterbury")
        XCTAssertEqual(index.canonical(try XCTUnwrap(region("us-ca")))?.code, "US-CA")
        XCTAssertEqual(index.canonical(try XCTUnwrap(region("US-ZZ")))?.code, "US")     // unknown: the whole country
        XCTAssertEqual(index.canonical(try XCTUnwrap(region("NO-03")))?.code, "NO")     // no difference: the whole country
        XCTAssertNil(index.canonical(try XCTUnwrap(region("AC"))))
        XCTAssertEqual(calendar("gb-sct", .en).id, "GB-SCT|en")
        XCTAssertEqual(calendar("fr-971", .fr).region?.code, "FR-971")
        XCTAssertEqual(index.country("us")?.code, "US")
    }

    func testAutomaticUsesTheDeviceRegion() throws {
        let index = try XCTUnwrap(store.index)
        XCTAssertEqual(HolidaySetting.automatic.resolved(deviceRegion: "US", index: index)?.code, "US")
        XCTAssertEqual(HolidaySetting.automatic.resolved(deviceRegion: "JP", index: index)?.code, "JP")
        XCTAssertEqual(HolidaySetting.automatic.resolved(deviceRegion: "JP", index: nil)?.code, "JP")
        XCTAssertEqual(HolidaySetting(storageValue: "DE-BY").resolved(deviceRegion: "US", index: index)?.code, "DE-BY")
        XCTAssertTrue(store.hasCountry("US"))
        XCTAssertTrue(store.hasCountry("JP"))
        XCTAssertFalse(store.hasCountry("AC"))
    }

    func testUnknownRegionMeansNone() throws {
        let index = try XCTUnwrap(store.index)
        XCTAssertNil(HolidaySetting.automatic.resolved(deviceRegion: "AC", index: index))   // no data (0-20)
        XCTAssertNil(HolidaySetting.automatic.resolved(deviceRegion: "419", index: index))  // not a country
        XCTAssertNil(HolidaySetting.automatic.resolved(deviceRegion: nil, index: index))
        XCTAssertNil(HolidaySetting.automatic.resolved(deviceRegion: "US", index: nil))
        XCTAssertNil(HolidaySetting.none.resolved(deviceRegion: "US", index: index))
        XCTAssertNil(HolidaySetting(storageValue: "ZZ").resolved(deviceRegion: "US", index: index))
        XCTAssertEqual(store.calendar(for: HolidaySetting.automatic.resolved(deviceRegion: "AC", index: index), language: .en), .none)
    }

    func testNameLanguageRule() {
        // §5.5: the screen's column, else the country's own language in the same script, else English.
        XCTAssertEqual(calendar("TW", .ja).name(of: day(2026, 10, 10)), "國慶日")
        XCTAssertEqual(calendar("DE", .ja).name(of: day(2026, 1, 1)), "New Year's Day")
        XCTAssertEqual(calendar("DE", .fr).name(of: day(2026, 1, 1)), "Neujahr")
        XCTAssertEqual(calendar("SA", .ja).name(of: day(2026, 9, 23)), "National Day Holiday")
        XCTAssertEqual(calendar("JP", .fr).name(of: day(2026, 1, 1)), "New Year's Day")
        XCTAssertEqual(calendar("JP", .zhHans).name(of: day(2026, 1, 1)), "元日")
        XCTAssertEqual(calendar("CH", .it).name(of: day(2026, 1, 1)), "Capodanno")
        XCTAssertEqual(calendar("US", .ja).name(of: day(2026, 1, 1)), "New Year's Day")
    }

    func testShortNamesDropTheObservedSuffix() {
        let us = calendar("US", .en)
        XCTAssertEqual(us.name(of: day(2026, 7, 3)), "Independence Day (observed)")
        XCTAssertEqual(us.name(of: day(2026, 7, 3), style: .short), "Independence Day")
        XCTAssertEqual(us.entries(forYear: 2026)[day(2026, 7, 3)]?.first?.flags, [.observed])
        XCTAssertEqual(calendar("TW", .zhHant).name(of: day(2026, 10, 9), style: .short), "國慶日")
        // Switzerland's observed label is only "%s": nothing there is marked observed (§5.2).
        XCTAssertEqual(calendar("CH", .de).entries(forYear: 2026)[day(2026, 1, 1)]?.first?.flags, [])
    }

    func testEstimatedSuffixOnlyInFull() throws {
        let mark = KitStrings.text("kit.holiday.estimatedSuffix", .en)
        let entry = try XCTUnwrap(calendar("AE", .en).entries(forYear: 2026)[day(2026, 3, 20)]?.first)
        XCTAssertTrue(entry.flags.contains(.estimated))
        XCTAssertEqual(entry.full, "Eid al-Fitr" + mark)
        XCTAssertEqual(entry.short, "Eid al-Fitr")
        XCTAssertEqual(calendar("AE", .ja).name(of: day(2026, 3, 20)), "Eid al-Fitr" + KitStrings.text("kit.holiday.estimatedSuffix", .ja))
        XCTAssertEqual(KitStrings.text("kit.holiday.estimatedSuffix", .ja), "（推定）")
        XCTAssertFalse(try XCTUnwrap(calendar("AE", .en).name(of: day(2026, 3, 20), style: .short)).contains(mark))
    }

    func testYearNotes() throws {
        let index = try XCTUnwrap(store.index)
        let cn = try XCTUnwrap(index.country("CN"))
        let last = try XCTUnwrap(cn.lastOfficialYear)
        XCTAssertEqual(last, 2026)                                             // 0.107 has China's 2026 notice
        XCTAssertTrue(cn.notice)
        XCTAssertEqual(calendar("CN", .zhHans).note(forYear: last + 1), .beforeNotice)
        XCTAssertNil(calendar("CN", .zhHans).note(forYear: last))
        // The rule's observed days of 2027 are not written; the year's holidays are estimates.
        XCTAssertNil(calendar("CN", .zhHans).name(of: day(2027, 10, 4)))
        XCTAssertEqual(calendar("CN", .zhHans).entries(forYear: 2027)[day(2027, 10, 1)]?.first?.flags, [.estimated])
        // TW's and KZ's tables end in 2025, but the years compared with the published calendar say nothing
        // (gen.py's PUBLISHED_AND_COMPARED: TW 2027, KZ 2026).
        XCTAssertNil(calendar("TW", .zhHant).note(forYear: 2026))
        XCTAssertNil(calendar("TW", .zhHant).note(forYear: 2027))
        XCTAssertEqual(calendar("TW", .zhHant).note(forYear: 2028), .beforeNotice)
        XCTAssertEqual(calendar("TW", .zhHant).entries(forYear: 2028)[day(2028, 10, 10)]?.first?.flags, [])
        XCTAssertNil(calendar("KZ", .en).note(forYear: 2026))
        XCTAssertEqual(calendar("KZ", .en).note(forYear: 2027), .beforeNotice)
        // Where the data really stops, the coverage stops (0-30).
        XCTAssertEqual(index.country("LK")?.coverage, 2003...2026)             // 0.107 (0.83: until 2025)
        XCTAssertEqual(index.country("UA")?.coverage, 2000...2021)
        XCTAssertNil(calendar("LK", .en).note(forYear: 2026))
        XCTAssertEqual(calendar("LK", .en).note(forYear: 2027), .incomplete(until: 2026))
        XCTAssertEqual(calendar("UA", .en).note(forYear: 2022), .incomplete(until: 2021))   // 3 holidays, then none
        XCTAssertEqual(calendar("UA", .en).note(forYear: 2026), .incomplete(until: 2021))
        XCTAssertNil(calendar("JP", .ja).note(forYear: 2026))
        XCTAssertNil(calendar("US", .en).note(forYear: 2026))
    }

    /// One low year between full ones does not end the coverage (0-30, §5.10). Slovakia's 2026 has 11
    /// holidays against a line of 12, and 13 a year follow to 2099: no "データがありません" there.
    func testOneLowYearDoesNotEndTheCoverage() throws {
        let index = try XCTUnwrap(store.index)
        XCTAssertEqual(index.country("SK")?.coverage, 2000...2099)
        XCTAssertNil(calendar("SK", .en).note(forYear: 2026))
        XCTAssertEqual(calendar("SK", .en).names(for: days(of: 2026)).count, 11)
        XCTAssertEqual(index.country("AM")?.coverage, 2001...2099)
        XCTAssertEqual(index.country("CD")?.coverage, 2000...2099)
        XCTAssertEqual(index.country("KE")?.coverage, 2000...2099)
        XCTAssertEqual(index.country("PH")?.coverage, 2010...2099)
    }

    /// The EU (O-4): every one of the 27 has data through 2099 and no note this year. Kosovo, sold
    /// since 1.0, has data from 0.107 on.
    func testEUCountriesHaveData() throws {
        let index = try XCTUnwrap(store.index)
        let eu = "AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE".split(separator: " ").map(String.init)
        XCTAssertEqual(Set(eu).count, 27)
        for code in eu {
            XCTAssertTrue(store.hasCountry(code), code)
            XCTAssertEqual(index.country(code)?.coverage.upperBound, 2099, code)
            XCTAssertNil(calendar(code, .en).note(forYear: 2026), code)
        }
        XCTAssertTrue(store.hasCountry("XK"))
    }

    func testSubdivisionDisplayNames() throws {
        let index = try XCTUnwrap(store.index)
        func sub(_ country: String, _ code: String) -> HolidayIndex.Subdivision? {
            index.country(country)?.subdivisions.first { $0.code == code }
        }
        XCTAssertEqual(sub("NZ", "AUK")?.display, "Auckland")
        XCTAssertEqual(sub("CA", "NS")?.display, "Nova Scotia")
        XCTAssertEqual(sub("FR", "971")?.display, "Guadeloupe")
        XCTAssertEqual(sub("DE", "BY")?.display, "Bayern")
        XCTAssertEqual(sub("US", "CA")?.display, "California")
        XCTAssertEqual(sub("DE", "Augsburg")?.local, true)
        XCTAssertEqual(sub("NZ", "South Canterbury")?.local, true)
        XCTAssertEqual(sub("DE", "BY")?.local, false)
        XCTAssertEqual(sub("BR", "Sao Paulo Capital")?.display, "São Paulo Capital")
        XCTAssertEqual(index.country("NO")?.subdivisions.count, 0)
        XCTAssertEqual(index.country("KR")?.subdivisions.count, 0)
        XCTAssertFalse(index.country("CA")?.subdivisions.isEmpty ?? true)
    }

    // MARK: - The files

    func testEveryCountryFileParses() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: holidayDataDirectory().path)
        let codes = names.filter { $0.count == 7 && $0.hasSuffix(".json") }.map { String($0.prefix(2)) }.sorted()
        XCTAssertEqual(codes.count, 250)                                       // 0.107 (0.83: 249; XK is new)
        XCTAssertFalse(names.contains("UK.json"))
        let index = try XCTUnwrap(store.index)
        XCTAssertEqual(index.countries.map(\.code).sorted(), codes)
        for code in codes {
            let file = try XCTUnwrap(data("\(code).json").flatMap { CountryHolidays.parse($0, expectedCountry: code) }, code)
            XCTAssertEqual(file.country, code)
            XCTAssertEqual(file.years, 2000...2099, code)
            XCTAssertEqual(index.country(code)?.subdivisions.map(\.code), file.subdivisions.map(\.code), code)
            XCTAssertTrue(file.subdivisions.allSatisfy(\.hasDifference), code)
            XCTAssertTrue(store.isReadable(HolidayRegion(code: code)!), code)
        }
    }

    func testSourceDigests() throws {
        let sourceData = try XCTUnwrap(data("SOURCE.json"))
        let source = try XCTUnwrap(try JSONSerialization.jsonObject(with: sourceData) as? [String: Any])
        let files = try XCTUnwrap(source["files"] as? [String: String])
        for (name, digest) in files {
            let bytes = try XCTUnwrap(data(name), name)
            XCTAssertEqual(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(), digest, name)
        }
        XCTAssertEqual(source["version"] as? String, "0.107")
        XCTAssertEqual(data("LICENSE-python-holidays.txt").map { String(decoding: $0, as: UTF8.self) }, HolidayDataLicense.mitText)
        XCTAssertNotNil(data("CONTRIBUTORS-python-holidays.txt"))
        XCTAssertEqual(HolidayDataLicense.contributorsURL.absoluteString, "https://github.com/vacanza/holidays/blob/v0.107/CONTRIBUTORS")
    }

    func testStoreWithoutADirectory() throws {
        let empty = HolidayStore(directory: nil)
        XCTAssertNil(empty.index)
        XCTAssertEqual(empty.calendar(for: try XCTUnwrap(region("JP")), language: .ja), HolidayCalendar.japan)
        XCTAssertEqual(empty.calendar(for: try XCTUnwrap(region("US")), language: .en), HolidayCalendar.none)
        XCTAssertFalse(empty.hasCountry("US"))
        XCTAssertTrue(empty.hasCountry("JP"))
        XCTAssertTrue(empty.isReadable(try XCTUnwrap(region("JP"))))
        XCTAssertFalse(empty.isReadable(try XCTUnwrap(region("US"))))
        // Japan without JP.json: the Japanese names in every language.
        XCTAssertEqual(empty.calendar(for: try XCTUnwrap(region("JP")), language: .en).name(of: day(2026, 10, 12)), "スポーツの日")
        let missing = HolidayStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("no-such-folder-\(UUID().uuidString)"))
        XCTAssertNil(missing.index)
        XCTAssertEqual(missing.calendar(for: try XCTUnwrap(region("US")), language: .en), HolidayCalendar.none)
    }
}
