// KitChecks: the holiday checks of 1.2 (docs/M7B_CONTRACT.md §7.1, "holidays (1.2)", H's).
// main.swift calls `runHolidayChecks()` after "date text (1.2)" and before "holiday geometry (1.2)";
// it uses main.swift's `section`, `check`, `checkEqual` and `day`. The data is the repository's
// TegakiKit/HolidayData (`holidayDataDirectory()`), made by tools/holidays/gen.py from
// python-holidays 0.107: the answers marked "0.107" below move with the library's version (0-14).
import CryptoKit
import Foundation
import Holidays

/// TegakiKit/HolidayData, found from this file's own place (Sources/KitChecks/../../HolidayData; D8:
/// no `Bundle.module`, and the app's code has no such function).
func holidayDataDirectory() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // Sources/KitChecks
        .deletingLastPathComponent()   // Sources
        .deletingLastPathComponent()   // TegakiKit
        .appendingPathComponent("HolidayData", isDirectory: true)
}

/// The 27 countries of the EU, where the app is sold from 1.2 on (O-4, §11).
let holidayCheckEURegions = "AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE"
    .split(separator: " ").map(String.init)

/// The 175 regions of the App Store where the app is sold in 1.2, as ISO codes: the 148 of App Store
/// Connect (2026-10-31; Kosovo, the App Store's XKS, is XK) and the 27 of the EU (O-4). python-holidays
/// 0.107 has every one of them (Kosovo is new in it). Their notes are listed for docs/M7B.md (§5.10).
let holidayCheckSoldRegions = """
    AE AF AG AI AL AM AO AR AU AZ BA BB BF BH BJ BM BN BO BR BS BT BW BY BZ CA CD CG CH CI CL CM CN CO CR CV DM DO \
    DZ EC EG FJ FM GA GB GD GE GH GM GT GW GY HK HN ID IL IN IQ IS JM JO JP KE KG KH KN KR KW KY KZ LA LB LC LK LR \
    LY MA MD ME MG MK ML MM MN MO MR MS MU MV MW MX MY MZ NA NE NG NI NO NP NR NZ OM PA PE PG PH PK PW PY QA RS RU \
    RW SA SB SC SG SL SN SR ST SV SZ TC TD TH TJ TM TN TO TR TT TW TZ UA UG US UY UZ VC VE VG VN VU XK YE ZA ZM ZW
    """.split(separator: " ").map(String.init) + holidayCheckEURegions

func runHolidayChecks() {
    section("holidays (1.2)")
    let directory = holidayDataDirectory()
    let store = HolidayStore(directory: directory)

    func region(_ code: String) -> HolidayRegion {
        guard let r = HolidayRegion(code: code) else { fatalError("bad region in a check: \(code)") }
        return r
    }
    func calendar(_ code: String, _ language: UILanguage) -> HolidayCalendar {
        store.calendar(for: region(code), language: language)
    }
    func allDays(_ year: Int) -> [DayKey] {
        let first = day(year, 1, 1).dayNumber, last = day(year, 12, 31).dayNumber
        return (first...last).map { DayKey(dayNumber: $0) }
    }
    func fileData(_ name: String) -> Data? {
        try? Data(contentsOf: directory.appendingPathComponent(name))
    }
    func file(_ code: String) -> CountryHolidays? {
        fileData("\(code).json").flatMap { CountryHolidays.parse($0, expectedCountry: code) }
    }
    func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    let estimatedEn = KitStrings.text("kit.holiday.estimatedSuffix", .en)

    // J-5: Japan is JapaneseHolidays, 2000–2099 (one check per year), both as .japan and from the store.
    let storeJapan = calendar("JP", .ja)
    checkEqual(storeJapan, HolidayCalendar.japan, "holidays: the store's Japan in ja is .japan (id JP|ja)")
    for year in 2000...2099 {
        let days = allDays(year)
        let expected = JapaneseHolidays.names(for: days)
        let a = HolidayCalendar.japan.names(for: days), b = storeJapan.names(for: days)
        let shortA = HolidayCalendar.japan.names(for: days, style: .short)
        check(a == expected && b == expected && shortA == expected && days.allSatisfy { !HolidayCalendar.japan.isWorkday($0) },
              "holidays: J-5 \(year) .japan and the store's Japan name the days of JapaneseHolidays and no other")
    }
    check(HolidayCalendar.japan.names(for: [day(1999, 12, 31), day(2100, 1, 1)]).isEmpty, "holidays: J-5 no Japanese holiday outside 2000–2099")
    check(HolidayCalendar.japan.note(forYear: 2026) == nil && HolidayCalendar.none.note(forYear: 2026) == nil, "holidays: Japan and none have no note")

    // JP.json against JapaneseHolidays: the same 1,773 days, two names different (2019).
    if let jp = file("JP"), let ja = jp.ui["ja"] {
        var dates = 0, missing: [DayKey] = [], extra: [DayKey] = [], differ: [String] = []
        for year in 2000...2099 {
            let table = JapaneseHolidays.table(forYear: year)
            let data = jp.entries(forYear: year, column: ja, subdivision: nil, language: .ja)
            dates += data.count
            missing += table.keys.filter { data[$0] == nil }
            extra += data.keys.filter { table[$0] == nil }
            for (d, entries) in data {
                if let name = table[d], entries.map(\.full) != [name] {
                    differ.append("\(d) \(name)/\(entries.map(\.full).joined(separator: ";"))")
                }
            }
        }
        checkEqual(dates, 1773, "holidays: JP.json has 1,773 days 2000–2099")
        check(missing.isEmpty && extra.isEmpty, "holidays: JP.json's days are JapaneseHolidays' days (missing \(missing), extra \(extra))")
        checkEqual(differ.sorted(), ["2019-05-01 即位の日/天皇の即位の日", "2019-10-22 即位礼正殿の儀/即位礼正殿の儀が行われる日"],
                   "holidays: JP.json's Japanese names differ from JapaneseHolidays only on 2019-05-01 and 2019-10-22")
        let observed = (0..<jp.nameCount).filter { jp.flags(ofName: $0).contains(.observed) }.map { jp.text(ofName: $0, column: ja) }
        check(observed.allSatisfy { $0 == "振替休日" }, "holidays: JP.json marks no name observed but 振替休日 (\(observed))")
    } else {
        check(false, "holidays: JP.json reads and has a ja column")
    }

    // The bridge: a screen whose column is ja (ja, and zh-Hans / zh-Hant by the script rule of §5.5)
    // shows JapaneseHolidays' names; ko (Hangul) and the Latin languages take English.
    for language in [UILanguage.zhHans, .zhHant] {
        let c = calendar("JP", language)
        let same = (2000...2099).allSatisfy { c.names(for: allDays($0)) == JapaneseHolidays.names(for: allDays($0)) }
        check(same, "holidays: Japan in \(language.rawValue) has JapaneseHolidays' names 2000–2099")
    }
    checkEqual(calendar("JP", .zhHans).name(of: day(2019, 5, 1)), "即位の日", "holidays: Japan in zh-Hans 2019-05-01 即位の日 (JapaneseHolidays, not JP.json)")
    checkEqual(calendar("JP", .en).name(of: day(2026, 10, 12)), "Sports Day", "holidays: Japan in en 2026-10-12 Sports Day")
    checkEqual(calendar("JP", .ko).name(of: day(2026, 10, 12)), "Sports Day", "holidays: Japan in ko 2026-10-12 Sports Day (Hangul is not Han, §5.5)")
    checkEqual(calendar("JP", .fr).name(of: day(2026, 5, 6)), "Substitute Holiday", "holidays: Japan in fr 2026-05-06 Substitute Holiday (English, §5.5)")
    check(Set(calendar("JP", .en).names(for: allDays(2026)).keys) == Set(JapaneseHolidays.names(for: allDays(2026)).keys),
          "holidays: Japan in en has JapaneseHolidays' days")

    // Known days (§7.2; "0.107" = the value of python-holidays 0.107).
    let known: [(String, UILanguage, DayKey, String?, String)] = [
        ("US", .en, day(2026, 7, 3), "Independence Day (observed)", "US 2026-07-03"),
        ("US", .en, day(2026, 10, 12), "Columbus Day", "US 2026-10-12"),
        ("US", .en, day(2026, 11, 26), "Thanksgiving Day", "US 2026-11-26"),
        ("US-CA", .en, day(2026, 10, 12), nil, "US-CA 2026-10-12 (California does not keep Columbus Day)"),
        ("US-CA", .en, day(2026, 11, 27), "Day After Thanksgiving", "US-CA 2026-11-27"),
        ("DE-BY", .de, day(2026, 1, 6), "Heilige Drei Könige", "DE-BY 2026-01-06"),
        ("DE", .de, day(2026, 1, 6), nil, "DE 2026-01-06 (not national)"),
        ("GB-SCT", .en, day(2026, 1, 2), "New Year Holiday", "GB-SCT 2026-01-02"),
        ("GB-SCT", .en, day(2026, 8, 3), "Summer Bank Holiday", "GB-SCT 2026-08-03"),
        ("GB-ENG", .en, day(2026, 8, 31), "Late Summer Bank Holiday", "GB-ENG 2026-08-31"),
        ("KR", .ko, day(2026, 2, 17), "설날", "KR 2026-02-17"),
        ("KR", .ko, day(2026, 9, 25), "추석", "KR 2026-09-25"),
        ("KR", .en, day(2026, 9, 25), "Chuseok", "KR en 2026-09-25"),
        ("TW", .zhHant, day(2026, 10, 9), "國慶日（補假）", "TW 2026-10-09"),
        ("TW", .zhHant, day(2026, 10, 10), "國慶日", "TW 2026-10-10"),
        ("TW", .ja, day(2026, 10, 10), "國慶日", "TW in ja 2026-10-10 (§5.5 rule 2)"),
        ("BR", .ptBR, day(2026, 4, 21), "Tiradentes", "BR 2026-04-21"),
        ("BR", .ptBR, day(2026, 11, 20), "Dia Nacional de Zumbi e da Consciência Negra", "BR 2026-11-20"),
        ("BR-SP", .ptBR, day(2026, 7, 9), "Revolução Constitucionalista", "BR-SP 2026-07-09"),
        ("CH-ZH", .de, day(2026, 4, 6), "Ostermontag", "CH-ZH 2026-04-06"),
        ("CH-ZH", .fr, day(2026, 4, 6), "Lundi de Pâques", "CH-ZH fr 2026-04-06"),
        // A day off swapped with a weekend is its short name everywhere (0-17, docs/M7B.md FIX3).
        ("CN", .zhHans, day(2025, 2, 3), "休息日", "CN 2025-02-03 (the template's date is not shown)"),
        ("CN", .en, day(2025, 2, 3), "Day off", "CN en 2025-02-03"),
        ("CN", .zhHans, day(2026, 10, 7), "休息日", "CN 2026-10-07 (the day of the photos, §7.4)"),
        ("CN", .zhHant, day(2026, 10, 7), "放假日", "CN zh-Hant 2026-10-07"),
        ("AE", .en, day(2026, 3, 20), "Eid al-Fitr" + estimatedEn, "AE en 2026-03-20 (0.107: still an estimate)"),
        ("CA", .en, day(2026, 10, 12), nil, "CA 2026-10-12 (Thanksgiving is the provinces')"),
        ("CA", .en, day(2026, 7, 1), "Canada Day", "CA 2026-07-01"),
    ]
    for (code, language, d, expected, what) in known {
        checkEqual(calendar(code, language).name(of: d), expected, "holidays: \(what)")
    }
    checkEqual(calendar("US", .en).name(of: day(2026, 7, 3), style: .short), "Independence Day", "holidays: US 2026-07-03 short has no (observed)")
    checkEqual(calendar("CN", .zhHans).name(of: day(2025, 2, 3), style: .short), "休息日", "holidays: CN 2025-02-03 short 休息日")
    checkEqual(calendar("CN", .en).name(of: day(2025, 2, 3), style: .short), "Day off", "holidays: CN en 2025-02-03 short Day off")
    checkEqual(calendar("AE", .en).name(of: day(2026, 3, 20), style: .short), "Eid al-Fitr", "holidays: AE 2026-03-20 short has no estimate mark")
    check(calendar("AE", .en).entries(forYear: 2026)[day(2026, 3, 20)]?.first?.flags.contains(.estimated) == true,
          "holidays: AE 2026-03-20 is flagged estimated")
    checkEqual(calendar("CA", .en).names(for: allDays(2026)).count, 5, "holidays: Canada as a whole has 5 holidays in 2026 (0.107)")

    // Two holidays on one day, and a subdivision's after the country's.
    checkEqual(calendar("KR", .ko).name(of: day(2025, 5, 5)), "부처님오신날 · 어린이날", "holidays: KR 2025-05-05 two holidays joined with ·")
    if let srp = calendar("BA-SRP", .en).entries(forYear: 2061)[day(2061, 5, 1)] {
        check(srp.count == 2 && !srp[0].isSubdivision && srp[1].isSubdivision && srp[0].full == "International Labor Day",
              "holidays: BA-SRP 2061-05-01 the country's holiday first, then the subdivision's (\(srp.map(\.full)))")
    } else {
        check(false, "holidays: BA-SRP 2061-05-01 has holidays")
    }

    // Working weekends.
    let china = calendar("CN", .zhHans)
    check(china.isWorkday(day(2024, 2, 4)) && china.isWorkday(day(2024, 2, 18)) && !china.isWorkday(day(2024, 2, 3)),
          "holidays: CN 2024-02-04 and 2024-02-18 are working Sundays, 2024-02-03 not")
    check(!calendar("US", .en).isWorkday(day(2024, 2, 4)) && !HolidayCalendar.none.isWorkday(day(2024, 2, 4)), "holidays: no working weekends in the US or none")

    // Before the notice (0-29) and the coverage (0-30); both move with the library's version.
    let index = store.index
    check(index != nil, "holidays: index.json reads and passes the checks")
    if let index, let cn = index.country("CN"), let cnLast = cn.lastOfficialYear, let tw = index.country("TW"), let twLast = tw.lastOfficialYear {
        let after = cnLast + 1
        checkEqual(china.note(forYear: after), .beforeNotice, "holidays: CN \(after) (after the last official year \(cnLast)) is before the notice")
        checkEqual(china.note(forYear: cnLast), nil, "holidays: CN \(cnLast) has no note")
        let rule = after == 2027 ? [day(2027, 2, 9), day(2027, 2, 10), day(2027, 5, 3), day(2027, 5, 4), day(2027, 10, 4), day(2027, 10, 5)] : []
        check(after == 2027 && rule.allSatisfy { china.name(of: $0) == nil },
              "holidays: CN 2027 (0.107) has none of the rule's observed days (2/9 2/10 5/3 5/4 10/4 10/5)")
        check(china.entries(forYear: after)[day(after, 10, 1)]?.first?.flags.contains(.estimated) == true,
              "holidays: CN \(after)-10-01 is flagged estimated")
        check(china.entries(forYear: cnLast)[day(cnLast, 10, 1)]?.first?.flags.contains(.estimated) == false,
              "holidays: CN \(cnLast)-10-01 is not flagged estimated")
        let taiwan = calendar("TW", .zhHant)
        checkEqual(taiwan.note(forYear: twLast + 1), .beforeNotice, "holidays: TW \(twLast + 1) is before the notice")
        check(taiwan.entries(forYear: twLast + 1)[day(twLast + 1, 10, 10)]?.first?.flags == [],
              "holidays: TW \(twLast + 1)-10-10 keeps its flags")
        check(cnLast == 2026 && twLast == 2027, "holidays: the last official years are CN 2026 (0.107) and TW 2027 (compared) (\(cnLast), \(twLast))")
    } else {
        check(false, "holidays: the index has CN and TW with their last official years")
    }
    // The years compared with the government's published calendar (gen.py's PUBLISHED_AND_COMPARED; the
    // sources are in docs/M7B.md, section "TW") have no note, the next year has, and the data has exactly
    // the published days off: a new library version that changes one of them stops here.
    let publishedAndCompared: [(code: String, language: UILanguage, year: Int, days: [(Int, Int)])] = [
        ("TW", .zhHant, 2026, [(1, 1), (2, 15), (2, 16), (2, 17), (2, 18), (2, 19), (2, 20), (2, 27), (2, 28),
                               (4, 3), (4, 4), (4, 5), (4, 6), (5, 1), (6, 19), (9, 25), (9, 28),
                               (10, 9), (10, 10), (10, 25), (10, 26), (12, 25)]),
        ("TW", .zhHant, 2027, [(1, 1), (2, 4), (2, 5), (2, 6), (2, 7), (2, 8), (2, 9), (2, 10), (2, 28), (3, 1),
                               (4, 4), (4, 5), (4, 6), (4, 30), (5, 1), (6, 9), (9, 15), (9, 28),
                               (10, 10), (10, 11), (10, 25), (12, 24), (12, 25), (12, 31)]),
        ("KZ", .en, 2026, [(1, 1), (1, 2), (1, 7), (3, 8), (3, 9), (3, 21), (3, 22), (3, 23), (3, 24), (3, 25),
                           (5, 1), (5, 7), (5, 9), (5, 11), (5, 27), (7, 6), (10, 25), (10, 26), (12, 16)]),
    ]
    for item in publishedAndCompared {
        let compared = calendar(item.code, item.language)
        checkEqual(compared.note(forYear: item.year), nil, "holidays: \(item.code) \(item.year) is published: no note")
        check(Set(compared.entries(forYear: item.year).keys) == Set(item.days.map { day(item.year, $0.0, $0.1) }),
              "holidays: \(item.code) \(item.year) has exactly the \(item.days.count) published days off")
        check(allDays(item.year).allSatisfy { !compared.isWorkday($0) }, "holidays: \(item.code) \(item.year) has no working weekend")
    }
    checkEqual(calendar("TW", .zhHant).note(forYear: 2028), .beforeNotice, "holidays: TW 2028 is before the notice")
    checkEqual(calendar("KZ", .en).note(forYear: 2027), .beforeNotice, "holidays: KZ 2027 is before the notice")
    if let index, let lk = index.country("LK"), let ua = index.country("UA") {
        // Where the data really stops, the coverage stops (0-30): Sri Lanka has no holidays after 2026,
        // Ukraine three in 2022 and then none (one low year is bridged only with full years on both sides).
        check(lk.coverage == 2003...2026 && ua.coverage == 2000...2021,
              "holidays: the coverage of 0.107 stops at LK 2003–2026 and UA 2000–2021 (\(lk.coverage), \(ua.coverage))")
        checkEqual(calendar("LK", .en).note(forYear: 2026), nil, "holidays: LK 2026 is in the coverage")
        checkEqual(calendar("LK", .en).note(forYear: 2027), .incomplete(until: 2026), "holidays: LK 2027 is incomplete")
        checkEqual(calendar("UA", .en).note(forYear: 2021), nil, "holidays: UA 2021 is in the coverage")
        checkEqual(calendar("UA", .en).note(forYear: 2022), .incomplete(until: 2021), "holidays: UA 2022 (3 holidays) is incomplete")
        checkEqual(calendar("UA", .en).note(forYear: 2026), .incomplete(until: 2021), "holidays: UA 2026 is incomplete")
    } else {
        check(false, "holidays: the index has LK and UA")
    }
    if let index {
        // One low year between full ones does not end the coverage (0-30, §5.10): Slovakia's 2026 has
        // 11 holidays against a line of 12 and 13 a year follow; the setting must not say the data stops.
        checkEqual(index.country("SK")?.coverage, 2000...2099, "holidays: SK's coverage goes on past its low 2026")
        checkEqual(calendar("SK", .en).note(forYear: 2026), nil, "holidays: SK 2026 has no note")
        checkEqual(calendar("SK", .en).names(for: allDays(2026)).count, 11, "holidays: SK 2026 has 11 holidays (0.107)")
        let widened: [(String, ClosedRange<Int>)] = [("AM", 2001...2099), ("CD", 2000...2099), ("KE", 2000...2099), ("PH", 2010...2099)]
        for (code, range) in widened {
            checkEqual(index.country(code)?.coverage, range, "holidays: \(code)'s coverage bridges its one low year (§5.10)")
        }
        // The EU: every country has data through 2099, and no note in 2026 (O-4).
        let euProblems = holidayCheckEURegions.filter { code in
            index.country(code)?.coverage.upperBound != 2099 || !store.hasCountry(code) || calendar(code, .en).note(forYear: 2026) != nil
        }
        checkEqual(holidayCheckEURegions.count, 27, "holidays: the EU has 27 countries")
        check(euProblems.isEmpty, "holidays: every EU country has data through 2099 and no note in 2026 (\(euProblems))")
        // Where the app is sold.
        checkEqual(Set(holidayCheckSoldRegions).count, 175, "holidays: the app is sold in 175 regions")
        let soldWithoutData = holidayCheckSoldRegions.filter { index.country($0) == nil || !store.hasCountry($0) }
        checkEqual(soldWithoutData, [], "holidays: every sold region has data in 0.107 (Kosovo too)")
    }
    checkEqual(calendar("US", .en).note(forYear: 2026), nil, "holidays: US 2026 has no note")
    checkEqual(calendar("JP", .en).note(forYear: 2026), nil, "holidays: JP 2026 has no note")

    // Every file reads and passes §5.3's checks; SOURCE.json's digests; no UK.json.
    let names = ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).sorted()
    let countryFiles = names.filter { $0.count == 7 && $0.hasSuffix(".json") }
    let codes = countryFiles.map { String($0.prefix(2)) }
    let unreadable = codes.filter { file($0) == nil }
    checkEqual(codes.count, 250, "holidays: 250 country files (0.107; 249 in 0.83, Kosovo is new)")
    check(!codes.isEmpty && unreadable.isEmpty, "holidays: all \(codes.count) country files read and pass the checks (unreadable \(unreadable))")
    check(Set(codes) == Set(index?.countries.map(\.code) ?? []), "holidays: index.json lists exactly the country files")
    check(!names.contains("UK.json"), "holidays: no UK.json (UK is GB's alias, not a region)")
    if let sourceData = fileData("SOURCE.json"),
       let source = try? JSONSerialization.jsonObject(with: sourceData) as? [String: Any],
       let files = source["files"] as? [String: String], let licenses = source["licenses"] as? [String: String] {
        let wrong = files.keys.sorted().filter { name in fileData(name).map(digest) != files[name] }
        let notListed = names.filter { $0 != "SOURCE.json" && files[$0] == nil && !$0.hasPrefix(".") }
        check(wrong.isEmpty && notListed.isEmpty && files.count == countryFiles.count + 3,
              "holidays: SOURCE.json has the sha256 of every file (wrong \(wrong), not listed \(notListed))")
        let licenseNames = ["LICENSE-python-holidays.txt", "CONTRIBUTORS-python-holidays.txt"]
        check(licenseNames.allSatisfy { fileData($0).map(digest) == licenses[$0] }, "holidays: SOURCE.json's licence digests")
        checkEqual(source["version"] as? String, "0.107", "holidays: the data is python-holidays 0.107")
    } else {
        check(false, "holidays: SOURCE.json reads")
    }
    checkEqual(fileData("LICENSE-python-holidays.txt").map { String(decoding: $0, as: UTF8.self) }, HolidayDataLicense.mitText,
               "holidays: HolidayDataLicense.mitText is LICENSE-python-holidays.txt byte for byte")
    checkEqual(HolidayDataLicense.contributorsURL.absoluteString, "https://github.com/vacanza/holidays/blob/v0.107/CONTRIBUTORS",
               "holidays: the contributors URL is of v0.107")

    // Bad input never traps (16): codes that are no region, or a region the data does not have.
    let notRegions = ["", "-", "US-", "-CA", "US--CA", "J", "JPN", "1A", "US-C@", "日本", "U S"]
    for code in notRegions {
        check(HolidayRegion(code: code) == nil && HolidaySetting(storageValue: code) == .automatic,
              "holidays: \"\(code)\" is no region (the setting reads as automatic)")
    }
    checkEqual(calendar("US-ZZ", .en).id, "US|en", "holidays: an unknown subdivision US-ZZ is the whole country")
    checkEqual(calendar("ZZ", .en), HolidayCalendar.none, "holidays: ZZ (no such country) is none")
    checkEqual(calendar("AC", .en), HolidayCalendar.none, "holidays: AC (a region without data) is none")
    check(!store.hasCountry("AC") && store.hasCountry("US") && store.hasCountry("us") && store.hasCountry("JP") && !store.hasCountry("../US"),
          "holidays: hasCountry looks for <CC>.json (and always has Japan)")
    let empty = HolidayStore(directory: nil)
    check(empty.calendar(for: region("JP"), language: .ja) == .japan && empty.calendar(for: region("US"), language: .en) == .none
          && empty.index == nil && !empty.hasCountry("US") && empty.hasCountry("JP")
          && empty.calendar(for: region("JP"), language: .en).name(of: day(2026, 10, 12)) == "スポーツの日",
          "holidays: a store without a folder has Japan (Japanese names) and nothing else")

    // The setting (12 round trips, and the data's spelling).
    let stored: [(String?, String)] = [
        (nil, "auto"), ("", "auto"), ("auto", "auto"), ("none", "none"), ("JP", "JP"), ("US-CA", "US-CA"),
        ("GB-SCT", "GB-SCT"), ("NZ-South Canterbury", "NZ-South Canterbury"), ("AR-C", "AR-C"), ("AT-9", "AT-9"),
        ("FR-971", "FR-971"), ("us", "US"),
    ]
    for (value, back) in stored {
        checkEqual(HolidaySetting(storageValue: value).storageValue, back, "holidays: the setting \(value ?? "nil") is stored as \(back)")
    }
    if let index {
        let nz = HolidaySetting(storageValue: "nz-south canterbury").resolved(deviceRegion: nil, index: index)
        checkEqual(nz?.code, "NZ-South Canterbury", "holidays: nz-south canterbury is matched to the data's NZ-South Canterbury")
        checkEqual(HolidaySetting.automatic.resolved(deviceRegion: "US", index: index)?.code, "US", "holidays: automatic in the US is US")
        checkEqual(HolidaySetting.automatic.resolved(deviceRegion: "AC", index: index), nil, "holidays: automatic where there is no data is none (0-20)")
        checkEqual(HolidaySetting.automatic.resolved(deviceRegion: "419", index: index), nil, "holidays: automatic in region 419 is none")
        checkEqual(HolidaySetting(storageValue: "US-ca").resolved(deviceRegion: "JP", index: index)?.code, "US-CA", "holidays: US-ca is US-CA")
        checkEqual(HolidaySetting(storageValue: "NO-03").resolved(deviceRegion: nil, index: index)?.code, "NO", "holidays: NO-03 (no difference) is Norway")
        checkEqual(HolidaySetting.none.resolved(deviceRegion: "US", index: index), nil, "holidays: none is none")
    }
    checkEqual(HolidaySetting.automatic.resolved(deviceRegion: "JP", index: nil)?.code, "JP", "holidays: without an index Japan still resolves")
    checkEqual(HolidaySetting.automatic.resolved(deviceRegion: "US", index: nil), nil, "holidays: without an index other countries do not")
    checkEqual(calendar("nz-south canterbury", .en).id, "NZ-South Canterbury|en", "holidays: the store matches a subdivision ignoring case")

    // The language of the names (§5.5): six examples.
    checkEqual(calendar("TW", .ja).name(of: day(2026, 10, 10)), "國慶日", "holidays: ja screen, Taiwan -> Chinese (Han)")
    checkEqual(calendar("DE", .ja).name(of: day(2026, 1, 1)), "New Year's Day", "holidays: ja screen, Germany -> English")
    checkEqual(calendar("DE", .fr).name(of: day(2026, 1, 1)), "Neujahr", "holidays: fr screen, Germany -> German (Latin)")
    checkEqual(calendar("SA", .ja).name(of: day(2026, 9, 23)), "National Day Holiday", "holidays: ja screen, Saudi Arabia -> English")
    checkEqual(calendar("JP", .fr).name(of: day(2026, 1, 1)), "New Year's Day", "holidays: fr screen, Japan -> English")
    checkEqual(calendar("JP", .zhHant).name(of: day(2026, 1, 1)), "元日", "holidays: zh-Hant screen, Japan -> Japanese (JapaneseHolidays)")

    // Observed flags (no label "%s" took every name) and the subdivisions (§5.1, §5.2).
    var observedHeavy: [String] = []
    var subdivisionProblems: [String] = []
    for code in codes {
        guard let data = file(code) else { continue }
        let observed = (0..<data.nameCount).filter { data.flags(ofName: $0).contains(.observed) }.count
        if data.nameCount > 0, 2 * observed > data.nameCount { observedHeavy.append("\(code) \(observed)/\(data.nameCount)") }
        let listed = index?.country(code)?.subdivisions.map(\.code) ?? []
        if listed != data.subdivisions.map(\.code) || !data.subdivisions.allSatisfy(\.hasDifference) {
            subdivisionProblems.append(code)
        }
    }
    check(observedHeavy.isEmpty, "holidays: no country has more than half of its names observed (\(observedHeavy))")
    check(subdivisionProblems.isEmpty, "holidays: the index lists exactly the subdivisions that differ (\(subdivisionProblems))")

    // A day off swapped with a weekend (0-17, docs/M7B.md FIX3): in every country, language and year its name
    // is the file's short name, no date and no template left. Japan has none (J-4 does not move), and this
    // is the only kind of name it touches (TW's 「國慶日（補假）」 and US's "(observed)" above keep theirs).
    var swappedCountries: [String] = []
    for code in codes {
        guard let data = file(code), (0..<data.nameCount).contains(where: { data.flags(ofName: $0).contains(.substituted) }) else { continue }
        swappedCountries.append(code)
        var days = 0
        var wrong: [String] = []
        for language in UILanguage.allCases {
            let column = data.column(for: language)
            for year in data.years {
                for (key, entries) in data.entries(forYear: year, column: column, subdivision: nil, language: language) {
                    for entry in entries where entry.flags.contains(.substituted) {
                        days += 1
                        let mark = entry.flags.contains(.estimated) ? KitStrings.text("kit.holiday.estimatedSuffix", language) : ""
                        if entry.full != entry.short + mark || entry.short.isEmpty || entry.full.contains("%") || entry.full.contains(where: \.isNumber) {
                            wrong.append("\(key) \(language.rawValue) \(entry.full)")
                        }
                    }
                }
            }
        }
        check(days > 0 && wrong.isEmpty, "holidays: \(code)'s \(days) days off of the ten languages are their short names (\(wrong.prefix(3)))")
    }
    checkEqual(swappedCountries, "AM AZ BG BY CN HU KG KZ LV MM RU TW UA UZ VN".split(separator: " ").map(String.init), "holidays: the 15 countries with days off swapped with a weekend (0.107)")
    if let index {
        func sub(_ c: String, _ s: String) -> HolidayIndex.Subdivision? {
            index.country(c)?.subdivisions.first { $0.code == s }
        }
        checkEqual(index.country("NO")?.subdivisions.count, 0, "holidays: Norway has no subdivision that differs")
        checkEqual(index.country("KR")?.subdivisions.count, 0, "holidays: Korea has no subdivision")
        checkEqual(sub("NZ", "AUK")?.display, "Auckland", "holidays: NZ-AUK is shown as Auckland")
        checkEqual(sub("CA", "NS")?.display, "Nova Scotia", "holidays: CA-NS is shown as Nova Scotia")
        checkEqual(sub("FR", "971")?.display, "Guadeloupe", "holidays: FR-971 is shown as Guadeloupe")
        checkEqual(sub("DE", "BY")?.display, "Bayern", "holidays: DE-BY is shown as Bayern")
        checkEqual(sub("US", "CA")?.display, "California", "holidays: US-CA is shown as California")
        check(sub("DE", "Augsburg")?.local == true && sub("DE", "BY")?.local == false && sub("NZ", "South Canterbury")?.local == true,
              "holidays: DE-Augsburg and NZ-South Canterbury are local, DE-BY is not")
        check(sub("BR", "Sao Paulo Capital")?.display == "São Paulo Capital", "holidays: BR's São Paulo Capital has the ASCII code Sao Paulo Capital (0-28)")
        check(index.countries.allSatisfy { $0.renamed.isEmpty }, "holidays: no renamed subdivision in the first data (1.2)")
    }

    // How long a country file takes to read (for docs/M7B.md; not counted).
    let started = Date()
    let timing = HolidayStore(directory: directory)
    let us = timing.calendar(for: region("US"), language: .en)
    let loaded = Date()
    _ = us.names(for: allDays(2026))
    let year = Date()
    print("   holidays: US.json read in \(Int(loaded.timeIntervalSince(started) * 1000)) ms, its 2026 in \(Int(year.timeIntervalSince(loaded) * 1000)) ms (debug build)")

    // The sold regions' notes (§5.10; for docs/M7B.md, not counted).
    if let index {
        print("   holidays: the \(holidayCheckSoldRegions.count) sold regions (lastOfficialYear / notice / coverage):")
        var line = "     "
        for code in holidayCheckSoldRegions {
            let text: String
            if let c = index.country(code) {
                text = "\(code) \(c.lastOfficialYear.map(String.init) ?? "-")/\(c.notice ? "notice" : "-")/\(c.coverage.lowerBound)-\(c.coverage.upperBound)"
            } else {
                text = "\(code) no data"
            }
            if line.count + text.count > 110 {
                print(line)
                line = "     "
            }
            line += text + "  "
        }
        print(line)
    }
}
