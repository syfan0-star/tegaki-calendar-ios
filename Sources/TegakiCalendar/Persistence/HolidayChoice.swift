import Foundation
import Holidays
import Layout

/// Which country's holidays this device shows (1.2, docs/M7B_CONTRACT.md §5.6, O-3): the setting
/// `holidays.setting` in UserDefaults (per device, 0-21), the calendar it gives, the sentence of its row.
///
/// The data lives in the app's bundle (`store`, the folder "HolidayData"); choosing the calendar at
/// launch reads one country's file at most and never the index (§5.3). Screenshot mode does not come
/// here for the setting: `ScreenshotMode.Config.holidays` is its setting (0-26), and nothing is read
/// or written.
enum HolidayChoice {
    /// The calendar in force, for what runs away from the view's body: `relayout`, the export and the
    /// PDF. `CalendarRootScreen` sets it at `init` and when the setting changes. A view's body does not
    /// read it (SwiftUI does not see it change, §5.6: the title would stay on the old calendar until
    /// the next draw), it reads `CalendarRootScreen.holidays`. Default `.japan`, as in 1.1.
    @MainActor static var current: HolidayCalendar = .japan

    /// The one store of the app (§5.3), over the bundle's "HolidayData" folder.
    static let store = HolidayStore(directory: Bundle.main.url(forResource: "HolidayData", withExtension: nil))

    /// The setting on this device. Missing or broken is automatic (§5.6); `migrateIfNeeded` has written
    /// a value before anything reads it.
    static func setting(_ defaults: UserDefaults = AppSettings.defaults) -> HolidaySetting {
        HolidaySetting(storageValue: defaults.string(forKey: AppSettings.holidaySettingKey))
    }

    /// §1.4, D10: decided once, on the first launch that has no record. Someone who used 1.0 or 1.1
    /// (any of the three keys) stays on Japan's holidays, wherever they live; someone new gets
    /// automatic. **Both are written**: a new person has `onboardingDone` at the second launch and would
    /// otherwise count as an old one. Not called in screenshot mode.
    static func migrateIfNeeded(_ defaults: UserDefaults = AppSettings.defaults) {
        guard defaults.object(forKey: AppSettings.holidaySettingKey) == nil else { return }
        let existing = AppSettings.isExistingUser(defaults)
        defaults.set(existing ? "JP" : HolidaySetting.automatic.storageValue, forKey: AppSettings.holidaySettingKey)
    }

    /// The calendar of `setting` (§5.6). Automatic is the country of the device's region, without a
    /// subdivision, Japan through the bridge; a country without a file is none (0-20). Automatic does not
    /// read the index (`hasCountry`, §5.3). A chosen subdivision is matched by the store, against the
    /// country's file first; one it does not know is the whole country. A file that cannot be read is
    /// none: nothing here traps.
    static func calendar(setting: HolidaySetting, deviceRegion: String?, language: UILanguage, store: HolidayStore) -> HolidayCalendar {
        switch setting {
        case .none:
            return HolidayCalendar.none
        case .automatic:
            guard let region = deviceCountry(deviceRegion), store.hasCountry(region.country) else { return HolidayCalendar.none }
            return store.calendar(for: region, language: language)
        case .region(let region):
            return store.calendar(for: region, language: language)
        }
    }

    /// The value of the row 「表示する祝日」 (§5.7, §6.3): 「自動（日本）」「日本」「アメリカ合衆国・California」
    /// 「なし」「自動（カナダ・全国共通の祝日のみ）」「カナダ（全国共通のみ）」「スリランカ（2027 年以降のデータがありません）」
    /// 「中国（2027 年は発表前の推定）」「アメリカ合衆国（祝日のデータがありません）」. Notes go in the brackets in the
    /// order no data → outside the data's years → before the notice → national holidays only, joined by
    /// 「・」. `year` is this year. Reads the index, so it is for the settings screen.
    static func summary(setting: HolidaySetting, deviceRegion: String?, language: UILanguage, store: HolidayStore, year: Int) -> String {
        switch setting {
        case .none:
            return L.text("settings.holidays.value.none", in: language)
        case .automatic:
            guard let region = deviceCountry(deviceRegion) else {
                return KitStrings.fill(L.text("settings.holidays.value.auto", in: language), [L.text("settings.holidays.note.noData", in: language)])
            }
            let name = countryName(region.country, language: language)
            let notes = yearAndDataNotes(of: region, language: language, store: store, year: year)
                + (store.hasCountry(region.country) && hasSubdivisions(region.country, store: store)
                    ? [L.text("settings.holidays.note.nationalOnlyAuto", in: language)] : [])
            guard let note = joined(notes, language: language) else {
                return KitStrings.fill(L.text("settings.holidays.value.auto", in: language), [name])
            }
            return KitStrings.fill(L.text("settings.holidays.value.autoNote", in: language), [name, note])
        case .region(let region):
            let wanted = store.index?.canonical(region) ?? region
            var name = countryName(wanted.country, language: language)
            if let subdivision = wanted.subdivision {
                let display = store.index?.country(wanted.country)?.subdivisions.first { $0.code == subdivision }?.display ?? subdivision
                name = KitStrings.fill(L.text("settings.holidays.value.subdivision", in: language), [name, display])
            }
            let notes = yearAndDataNotes(of: wanted, language: language, store: store, year: year)
                + (wanted.subdivision == nil && store.isReadable(wanted) && hasSubdivisions(wanted.country, store: store)
                    ? [L.text("settings.holidays.note.nationalOnly", in: language)] : [])
            guard let note = joined(notes, language: language) else { return name }
            return KitStrings.fill(L.text("settings.holidays.value.regionNote", in: language), [name, note])
        }
    }

    /// The note the country's row shows in the picker (0-29, 0-30), from the index alone: the list has
    /// 250 countries and must not read 250 files. The same rule as a calendar's `note(forYear:)`.
    static func yearNote(of country: HolidayIndex.Country, year: Int) -> HolidayYearNote? {
        if !country.coverage.contains(year) { return .incomplete(until: country.coverage.upperBound) }
        if country.notice, let last = country.lastOfficialYear, year > last { return .beforeNotice }
        return nil
    }

    /// The words of a year's note: `.incomplete(until:)` names the first year without data (until + 1).
    static func noteText(_ note: HolidayYearNote, year: Int, language: UILanguage) -> String {
        switch note {
        case .beforeNotice:
            return KitStrings.fill(L.text("settings.holidays.note.beforeNotice", in: language), [String(year)])
        case .incomplete(let until):
            return KitStrings.fill(L.text("settings.holidays.note.noDataFrom", in: language), [String(until + 1)])
        }
    }

    /// The country's name in `language`, or its code when the system has none (§5.7).
    static func countryName(_ code: String, language: UILanguage) -> String {
        Locale(identifier: language.rawValue).localizedString(forRegionCode: code) ?? code
    }

    /// The device's region as a country: two letters only ("001", a world region, is no country).
    static func deviceCountry(_ deviceRegion: String?) -> HolidayRegion? {
        guard let deviceRegion, deviceRegion.unicodeScalars.count == 2 else { return nil }
        return HolidayRegion(code: deviceRegion)
    }

    /// No file or an unreadable one, else the note of this year's data.
    private static func yearAndDataNotes(of region: HolidayRegion, language: UILanguage, store: HolidayStore, year: Int) -> [String] {
        guard store.hasCountry(region.country), store.isReadable(region) else {
            return [L.text("settings.holidays.note.noData", in: language)]
        }
        guard let note = store.calendar(for: region, language: language).note(forYear: year) else { return [] }
        return [noteText(note, year: year, language: language)]
    }

    /// The country differs by subdivision (0-31).
    private static func hasSubdivisions(_ country: String, store: HolidayStore) -> Bool {
        !(store.index?.country(country)?.subdivisions.isEmpty ?? true)
    }

    private static func joined(_ notes: [String], language: UILanguage) -> String? {
        guard var text = notes.first else { return nil }
        for next in notes.dropFirst() {
            text = KitStrings.fill(L.text("settings.holidays.note.join", in: language), [text, next])
        }
        return text
    }
}
