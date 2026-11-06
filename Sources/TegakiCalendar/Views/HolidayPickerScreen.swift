import Holidays
import Layout
import SwiftUI

/// 「表示する祝日」 (1.2, docs/M7B_CONTRACT.md §5.7): automatic and none first, the shortcuts (this device's
/// region, Japan: in a Japanese list the kanji names are not in reading order), then the search field and
/// every country and region of the data. A country that differs by subdivision opens its own list. A
/// choice is stored at once and the screen goes back; screenshot mode stores nothing (§5.6).
struct HolidayPickerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.holidaySettingKey) private var raw = ""
    @State private var query = ""
    /// The list, named and sorted once (250 countries).
    @State private var rows: [HolidayCountryRow] = []

    private let deviceRegion = Locale.current.region?.identifier
    private let store = HolidayChoice.store
    private let thisYear = DayKey(ScreenshotMode.current?.today ?? Date()).year

    private var setting: HolidaySetting {
        ScreenshotMode.current?.holidays ?? HolidaySetting(storageValue: raw)
    }

    private var deviceCountry: HolidayRegion? {
        HolidayChoice.deviceCountry(deviceRegion)
    }

    private var japan: HolidayRegion? {
        HolidayRegion(code: "JP")
    }

    var body: some View {
        List {
            Section {
                choiceRow(Self.automaticTitle(deviceCountry: deviceCountry?.country, language: L.language),
                          selected: setting == .automatic) {
                    choose(.automatic)
                }
                choiceRow(L.text("holidayPicker.none"), selected: setting == HolidaySetting.none) {
                    choose(HolidaySetting.none)
                }
            }
            Section {
                ForEach(shortcuts, id: \.code) { region in
                    choiceRow(shortcutTitle(region), selected: setting == .region(region)) {
                        choose(.region(region))
                    }
                }
            }
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(L.text("holidayPicker.search"), text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            Section(L.text("holidayPicker.countries")) {
                ForEach(Self.filtered(rows, query: query)) { row in
                    countryRow(row)
                }
            }
        }
        .navigationTitle(L.text("holidayPicker.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if rows.isEmpty {
                rows = Self.rows(index: store.index, language: L.language)
            }
        }
        // A choice here or on a country's own list goes back to the settings.
        .onChange(of: raw) { dismiss() }
    }

    // MARK: - Rows

    /// 「この端末の地域：<国>」 and 「日本」 (one row when the device is in Japan). The name in the row of the
    /// device's country is a choice of the whole country, like the list's.
    private var shortcuts: [HolidayRegion] {
        var regions: [HolidayRegion] = []
        if let deviceCountry, store.hasCountry(deviceCountry.country) { regions.append(deviceCountry) }
        if let japan, deviceCountry != japan { regions.append(japan) }
        return regions
    }

    private func shortcutTitle(_ region: HolidayRegion) -> String {
        let name = HolidayChoice.countryName(region.country, language: L.language)
        return region == deviceCountry ? L.format("holidayPicker.deviceRegion", name) : name
    }

    @ViewBuilder
    private func countryRow(_ row: HolidayCountryRow) -> some View {
        let selected: Bool = {
            if case .region(let region) = setting { return region.country == row.country.code }
            return false
        }()
        let notes = Self.rowNotes(row.country, year: thisYear, language: L.language)
        if row.country.subdivisions.isEmpty {
            choiceRow(row.name, notes: notes, selected: selected) {
                if let region = HolidayRegion(code: row.country.code) { choose(.region(region)) }
            }
        } else {
            NavigationLink {
                HolidaySubdivisionScreen(country: row.country, title: row.name, raw: raw, choose: { choose(.region($0)) })
            } label: {
                HolidayChoiceLabel(title: row.name, notes: notes, selected: selected)
            }
        }
    }

    private func choiceRow(_ title: String, notes: [String] = [], selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HolidayChoiceLabel(title: title, notes: notes, selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func choose(_ choice: HolidaySetting) {
        guard !ScreenshotMode.isActive else { return }
        if raw == choice.storageValue {
            dismiss()
        } else {
            raw = choice.storageValue
        }
    }

    // MARK: - The list (tests call these)

    /// 「自動（この端末の地域：日本）」; "—" for a device whose region is no country.
    static func automaticTitle(deviceCountry: String?, language: UILanguage) -> String {
        KitStrings.fill(L.text("holidayPicker.auto", in: language),
                        [deviceCountry.map { HolidayChoice.countryName($0, language: language) } ?? "—"])
    }

    /// Every country of the index with its name in `language` and in English, in the screen's order.
    static func rows(index: HolidayIndex?, language: UILanguage) -> [HolidayCountryRow] {
        let english = Locale(identifier: "en")
        let rows = (index?.countries ?? []).map { country in
            HolidayCountryRow(country: country,
                              name: HolidayChoice.countryName(country.code, language: language),
                              englishName: english.localizedString(forRegionCode: country.code) ?? country.code)
        }
        return rows.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// The rows `query` finds: the screen's name, the code ("KR") or the English name holds it.
    /// 「かんこく」 finds nothing, "korea" and "KR" do (§5.7).
    static func filtered(_ rows: [HolidayCountryRow], query: String) -> [HolidayCountryRow] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return rows }
        return rows.filter { row in
            [row.name, row.country.code, row.englishName].contains { holds($0, query) }
        }
    }

    /// The lines under a country's row: that subdivisions add holidays, and the year's note (0-29, 0-30).
    static func rowNotes(_ country: HolidayIndex.Country, year: Int, language: UILanguage) -> [String] {
        var notes: [String] = []
        if !country.subdivisions.isEmpty {
            notes.append(L.text("holidayPicker.subdivisionHint", in: language))
        }
        if let note = HolidayChoice.yearNote(of: country, year: year) {
            notes.append(HolidayChoice.noteText(note, year: year, language: language))
        }
        return notes
    }

    /// Ignoring case and accents.
    static func holds(_ text: String, _ query: String) -> Bool {
        text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

/// A country in the list of `HolidayPickerScreen`.
struct HolidayCountryRow: Identifiable {
    var id: String { country.code }
    var country: HolidayIndex.Country
    var name: String
    var englishName: String
}

/// A country's own list (§5.7), titled with its name: the sentence on subdivisions, the whole country, the
/// states and regions (their names as the data writes them), and under another heading the places that
/// are not ISO subdivisions (cities). The search reads every name of the data and the code.
struct HolidaySubdivisionScreen: View {
    var country: HolidayIndex.Country
    var title: String
    var raw: String
    /// `HolidayPickerScreen.choose`: the one place that stores and goes back, also for the row already chosen.
    var choose: (HolidayRegion) -> Void
    @State private var query = ""

    private var setting: HolidaySetting {
        ScreenshotMode.current?.holidays ?? HolidaySetting(storageValue: raw)
    }

    /// The chosen subdivision of this country; nil for its whole country or another choice.
    private var chosenSubdivision: String? {
        if case .region(let region) = setting, region.country == country.code { return region.subdivision }
        return nil
    }

    private var wholeCountryChosen: Bool {
        if case .region(let region) = setting { return region.country == country.code && region.subdivision == nil }
        return false
    }

    var body: some View {
        let lists = Self.lists(country, query: query)
        List {
            Section {
                row(L.text("holidayPicker.wholeCountry"), selected: wholeCountryChosen, code: country.code)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(L.text("holidayPicker.search"), text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            } header: {
                Text(L.text("holidayPicker.subdivisionHint"))
                    .textCase(nil)
            }
            if !lists.regions.isEmpty {
                Section {
                    subdivisionRows(lists.regions)
                } header: {
                    Text(L.text("holidayPicker.subdivisions"))
                } footer: {
                    if lists.local.isEmpty {
                        Text(L.text("holidayPicker.subdivisions.footer"))
                    }
                }
            }
            if !lists.local.isEmpty {
                Section {
                    subdivisionRows(lists.local)
                } header: {
                    Text(L.text("holidayPicker.localAreas"))
                } footer: {
                    Text(L.text("holidayPicker.subdivisions.footer"))
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func subdivisionRows(_ subdivisions: [HolidayIndex.Subdivision]) -> some View {
        ForEach(subdivisions, id: \.code) { subdivision in
            row(subdivision.display, selected: chosenSubdivision == subdivision.code, code: "\(country.code)-\(subdivision.code)")
        }
    }

    private func row(_ title: String, selected: Bool, code: String) -> some View {
        Button {
            guard let region = HolidayRegion(code: code) else { return }
            choose(region)
        } label: {
            HolidayChoiceLabel(title: title, notes: [], selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// The states and regions, and the other places, sorted by their shown name and narrowed by `query`
    /// (any of the data's names or the code).
    static func lists(_ country: HolidayIndex.Country, query: String) -> (regions: [HolidayIndex.Subdivision], local: [HolidayIndex.Subdivision]) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let found = country.subdivisions.filter { subdivision in
            query.isEmpty || ([subdivision.display, subdivision.code] + subdivision.names).contains { HolidayPickerScreen.holds($0, query) }
        }
        let sorted = found.sorted { $0.display.localizedStandardCompare($1.display) == .orderedAscending }
        return (sorted.filter { !$0.local }, sorted.filter(\.local))
    }
}

/// The inside of a choice's row: the name, the small lines under it, a check mark when it is chosen.
private struct HolidayChoiceLabel: View {
    var title: String
    var notes: [String]
    var selected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                ForEach(notes, id: \.self) { note in
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}
