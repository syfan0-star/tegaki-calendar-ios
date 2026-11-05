import Holidays
import Layout
import SwiftUI

/// 設定 ›「祝日」 (1.2, docs/M7B_CONTRACT.md §5.7, O-3): the row 「表示する祝日」 with the current choice as
/// its value (`HolidayChoice.summary`), which opens `HolidayPickerScreen`, and the footer saying where
/// the holidays come from. Per device (0-21). Screenshot mode stores nothing: `Config.holidays` is the
/// setting (§5.6).
struct HolidaySettingsSection: View {
    @AppStorage(AppSettings.holidaySettingKey) private var raw = ""

    private var setting: HolidaySetting {
        ScreenshotMode.current?.holidays ?? HolidaySetting(storageValue: raw)
    }

    /// The year of the row's note (the fixed 「今日」 in screenshot mode).
    private var thisYear: Int {
        DayKey(ScreenshotMode.current?.today ?? Date()).year
    }

    var body: some View {
        Section {
            NavigationLink {
                HolidayPickerScreen()
            } label: {
                HStack {
                    Text(L.text("settings.holidays.row"))
                    Spacer()
                    Text(HolidayChoice.summary(setting: setting, deviceRegion: Locale.current.region?.identifier,
                                               language: L.language, store: HolidayChoice.store, year: thisYear))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        } header: {
            Text(L.text("settings.holidays.header"))
        } footer: {
            Text(L.text("settings.holidays.footer"))
        }
    }
}
