import Holidays
import Layout
import XCTest
@testable import TegakiCalendar

/// The holiday setting (docs/M7B_CONTRACT.md §1.4, §5.6, §5.7, D10, J-7): who keeps Japan, who gets
/// automatic, and what the row says. The data is the repository's, read from `#filePath`, the way the
/// other tests of the data do; the words are ja (the unit tests run with `-testLanguage ja`).
@MainActor
final class HolidayChoiceTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() async throws {
        suiteName = "test-\(UUID())"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private var dataDirectory: URL {
        URL(fileURLWithPath: "\(#filePath)").deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("TegakiKit/HolidayData", isDirectory: true)
    }

    private lazy var store = HolidayStore(directory: dataDirectory)

    private func region(_ code: String) throws -> HolidaySetting {
        .region(try XCTUnwrap(HolidayRegion(code: code)))
    }

    private func summary(_ setting: HolidaySetting, device: String? = "JP", year: Int = 2026, store: HolidayStore? = nil) -> String {
        HolidayChoice.summary(setting: setting, deviceRegion: device, language: .ja, store: store ?? self.store, year: year)
    }

    // MARK: The migration (§1.4)

    /// Any one of the three keys is someone who used 1.0, 1.1 or 1.1.1.
    func testExistingUserKeepsJapan() {
        for key in [AppSettings.onboardingDoneKey, AppSettings.lastKindKey, AppSettings.allowFingerChosenKey] {
            let name = "test-\(UUID())"
            let store = UserDefaults(suiteName: name)!
            defer { store.removePersistentDomain(forName: name) }
            store.set(true, forKey: key)
            HolidayChoice.migrateIfNeeded(store)
            XCTAssertEqual(store.string(forKey: AppSettings.holidaySettingKey), "JP", key)
            XCTAssertEqual(HolidayChoice.setting(store).storageValue, "JP", key)
        }
    }

    func testNewUserIsAutomatic() {
        HolidayChoice.migrateIfNeeded(defaults)
        XCTAssertEqual(defaults.string(forKey: AppSettings.holidaySettingKey), "auto", "written, not left missing")
        XCTAssertEqual(HolidayChoice.setting(defaults), .automatic)
    }

    /// The first version's mistake: the onboarding writes `onboardingDone`, so at the second launch a new
    /// person looked like an old one and got Japan's holidays, everywhere in the world.
    func testNewUserStaysAutomaticOnSecondLaunch() {
        HolidayChoice.migrateIfNeeded(defaults)
        defaults.set(true, forKey: AppSettings.onboardingDoneKey)
        defaults.set("month", forKey: AppSettings.lastKindKey)
        HolidayChoice.migrateIfNeeded(defaults)
        XCTAssertEqual(defaults.string(forKey: AppSettings.holidaySettingKey), "auto")
    }

    func testMigrationRunsOnce() {
        defaults.set(true, forKey: AppSettings.onboardingDoneKey)
        defaults.set(true, forKey: AppSettings.allowFingerChosenKey)
        for value in ["none", "US", "US-CA", "auto"] {
            defaults.set(value, forKey: AppSettings.holidaySettingKey)
            HolidayChoice.migrateIfNeeded(defaults)
            XCTAssertEqual(defaults.string(forKey: AppSettings.holidaySettingKey), value)
        }
    }

    // MARK: The row (§5.7, 0-20, 0-29, 0-30, 0-31). The years of the notes are python-holidays 0.107's.

    func testSummaryTexts() throws {
        // The names are the system's (China is 「中国本土」 on Apple's systems), so they are asked for;
        // this test is about the sentences around them.
        func name(_ code: String) -> String { HolidayChoice.countryName(code, language: .ja) }
        XCTAssertEqual(name("JP"), "日本")
        XCTAssertEqual(summary(.automatic), "自動（日本）")
        XCTAssertEqual(summary(try region("JP")), "日本")
        XCTAssertEqual(summary(try region("US-CA")), "\(name("US"))・California")
        XCTAssertEqual(summary(HolidaySetting.none), "なし")
        // The automatic of a region without data (Kosovo has data in this version, Ascension does not).
        XCTAssertEqual(summary(.automatic, device: "AC"), "自動（\(name("AC"))・祝日のデータがありません）")
        // A device whose region is no country.
        XCTAssertEqual(summary(.automatic, device: nil), "自動（祝日のデータがありません）")
        XCTAssertEqual(summary(.automatic, device: "001"), "自動（祝日のデータがありません）")
        // National holidays only, in the country that differs by subdivision (0-31).
        XCTAssertEqual(summary(.automatic, device: "CA"), "自動（\(name("CA"))・全国共通の祝日のみ）")
        XCTAssertEqual(summary(try region("CA")), "\(name("CA"))（全国共通のみ）")
        XCTAssertEqual(summary(try region("CA-NS")), "\(name("CA"))・Nova Scotia")
        // Outside the data's years: the first year without data (0-30).
        XCTAssertEqual(summary(try region("LK"), year: 2027), "\(name("LK"))（2027 年以降のデータがありません）")
        XCTAssertEqual(summary(try region("LK"), year: 2026), name("LK"))
        XCTAssertEqual(summary(try region("UA"), year: 2026), "\(name("UA"))（2022 年以降のデータがありません）")
        // Before the government's notice (0-29).
        XCTAssertEqual(summary(try region("CN"), year: 2027), "\(name("CN"))（2027 年は発表前の推定）")
        XCTAssertEqual(summary(try region("KZ"), year: 2027), "\(name("KZ"))（2027 年は発表前の推定）")
        XCTAssertEqual(summary(try region("TW"), year: 2028), "\(name("TW"))（2028 年は発表前の推定）")
        XCTAssertEqual(summary(.automatic, device: "TW", year: 2028), "自動（\(name("TW"))・2028 年は発表前の推定）")
        // The years compared with the published calendar say nothing (gen.py's PUBLISHED_AND_COMPARED).
        XCTAssertEqual(summary(try region("KZ"), year: 2026), name("KZ"))
        XCTAssertEqual(summary(try region("TW"), year: 2026), name("TW"))
        XCTAssertEqual(summary(try region("TW"), year: 2027), name("TW"))
        XCTAssertEqual(summary(.automatic, device: "TW", year: 2026), "自動（\(name("TW"))）")
        // A chosen country whose file cannot be read (0-20).
        XCTAssertEqual(summary(try region("US"), store: HolidayStore(directory: nil)), "\(name("US"))（祝日のデータがありません）")
        XCTAssertEqual(summary(.automatic, device: "US", store: HolidayStore(directory: nil)), "自動（\(name("US"))・祝日のデータがありません）")
        // Japan needs no file.
        XCTAssertEqual(summary(try region("JP"), store: HolidayStore(directory: nil)), "日本")
        XCTAssertEqual(summary(.automatic, store: HolidayStore(directory: nil)), "自動（日本）")
    }

    func testCalendarFollowsTheSetting() throws {
        func calendar(_ setting: HolidaySetting, device: String?, language: UILanguage = .ja) -> HolidayCalendar {
            HolidayChoice.calendar(setting: setting, deviceRegion: device, language: language, store: store)
        }
        XCTAssertEqual(calendar(.automatic, device: "JP"), .japan)
        XCTAssertEqual(calendar(.automatic, device: "US", language: .en).id, "US|en")
        XCTAssertEqual(calendar(.automatic, device: "AC").id, "none", "no file")
        XCTAssertEqual(calendar(.automatic, device: nil).id, "none")
        XCTAssertEqual(calendar(.automatic, device: "001").id, "none", "not a country")
        XCTAssertEqual(calendar(HolidaySetting.none, device: "JP").id, "none")
        XCTAssertEqual(calendar(try region("JP"), device: "US"), .japan, "someone from 1.1 abroad keeps Japan")
        XCTAssertEqual(calendar(try region("US-CA"), device: "JP", language: .en).id, "US-CA|en")
        XCTAssertEqual(calendar(try region("US-ca"), device: "JP", language: .en).id, "US-CA|en", "the data's spelling")
        XCTAssertEqual(calendar(try region("US-ZZ"), device: "JP", language: .en).id, "US|en", "an unknown subdivision is the whole country")
        XCTAssertEqual(calendar(try region("ZZ"), device: "JP").id, "none")
    }

    /// §5.3: the automatic calendar of a launch reads one country's file and never the index: it works
    /// from a folder with that file alone.
    func testAutomaticDoesNotReadTheIndex() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("HolidayChoiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.copyItem(at: dataDirectory.appendingPathComponent("US.json"), to: folder.appendingPathComponent("US.json"))
        let lone = HolidayStore(directory: folder)
        let calendar = HolidayChoice.calendar(setting: .automatic, deviceRegion: "US", language: .en, store: lone)
        XCTAssertEqual(calendar.id, "US|en")
        XCTAssertEqual(calendar.name(of: DayKey(year: 2026, month: 11, day: 26)), "Thanksgiving Day")
        XCTAssertFalse(lone.hasCountry("CA"))
    }

    // MARK: The picker (§5.7)

    func testPickerList() throws {
        let rows = HolidayPickerScreen.rows(index: store.index, language: .ja)
        XCTAssertEqual(rows.count, 250)
        XCTAssertTrue(HolidayPickerScreen.filtered(rows, query: "").count == 250)
        // The screen's name, the code and the English name; a reading finds nothing (§5.7).
        for query in ["韓国", "KR", "kr", "korea", "South Korea"] {
            XCTAssertTrue(HolidayPickerScreen.filtered(rows, query: query).contains { $0.country.code == "KR" }, query)
        }
        XCTAssertTrue(HolidayPickerScreen.filtered(rows, query: "かんこく").isEmpty)
        XCTAssertEqual(HolidayPickerScreen.automaticTitle(deviceCountry: "JP", language: .ja), "自動（この端末の地域：日本）")

        let index = try XCTUnwrap(store.index)
        let us = try XCTUnwrap(index.country("US"))
        XCTAssertEqual(HolidayPickerScreen.rowNotes(us, year: 2026, language: .ja), ["州・地域を選ぶと、その地域の祝日が加わります"])
        XCTAssertEqual(HolidayPickerScreen.rowNotes(try XCTUnwrap(index.country("JP")), year: 2026, language: .ja), [])
        XCTAssertEqual(HolidayPickerScreen.rowNotes(try XCTUnwrap(index.country("TW")), year: 2026, language: .ja), [])
        XCTAssertEqual(HolidayPickerScreen.rowNotes(try XCTUnwrap(index.country("TW")), year: 2027, language: .ja), [])
        XCTAssertEqual(HolidayPickerScreen.rowNotes(try XCTUnwrap(index.country("TW")), year: 2028, language: .ja), ["2028 年は発表前の推定"])
        XCTAssertEqual(HolidayPickerScreen.rowNotes(try XCTUnwrap(index.country("KZ")), year: 2026, language: .ja), [])
        XCTAssertEqual(HolidayPickerScreen.rowNotes(try XCTUnwrap(index.country("KZ")), year: 2027, language: .ja), ["2027 年は発表前の推定"])
        XCTAssertEqual(HolidayPickerScreen.rowNotes(try XCTUnwrap(index.country("LK")), year: 2027, language: .ja), ["2027 年以降のデータがありません"])

        // The index alone says what a calendar's note says (the list does not read 250 files).
        for code in ["TW", "KZ", "CN", "LK", "UA", "US", "SK"] {
            let country = try XCTUnwrap(index.country(code))
            let calendar = store.calendar(for: try XCTUnwrap(HolidayRegion(code: code)), language: .en)
            for year in [2021, 2026, 2027, 2028, 2036, 2080] {
                XCTAssertEqual(HolidayChoice.yearNote(of: country, year: year), calendar.note(forYear: year), "\(code) \(year)")
            }
        }

        // A country's own list: every name of the data and the code find a subdivision.
        let found = HolidaySubdivisionScreen.lists(us, query: "california").regions
        XCTAssertTrue(found.contains { $0.code == "CA" })
        XCTAssertTrue(HolidaySubdivisionScreen.lists(us, query: "CA").regions.contains { $0.code == "CA" })
        XCTAssertEqual(HolidaySubdivisionScreen.lists(us, query: "").regions.count + HolidaySubdivisionScreen.lists(us, query: "").local.count, us.subdivisions.count)
    }

    /// The licence is never empty (§5.7): the files, or the copy in TegakiKit and the address.
    func testLicenseText() {
        let read = LicenseScreen.bodyText(directory: dataDirectory)
        XCTAssertTrue(read.contains("Permission is hereby granted"), read)
        let standIn = LicenseScreen.bodyText(directory: nil)
        XCTAssertTrue(standIn.hasPrefix(HolidayDataLicense.mitText))
        XCTAssertTrue(standIn.contains(HolidayDataLicense.contributorsURL.absoluteString))
    }
}
