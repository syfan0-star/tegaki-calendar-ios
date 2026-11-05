import Holidays
import SwiftUI

/// 設定 › 情報 ›「オープンソースのライセンス」 (1.2, docs/M7B_CONTRACT.md §5.7, §5.9): the licence and the
/// contributors of the holiday data (python-holidays), in full and in English as they are. The first line
/// of the licence says "see CONTRIBUTORS file", so both belong here. CI checks that both files are in the
/// bundle; should one still not be read, the screen is never empty: the licence's copy in TegakiKit and
/// the address of the contributors stand in.
struct LicenseScreen: View {
    private static let licenseFile = "LICENSE-python-holidays.txt"
    private static let contributorsFile = "CONTRIBUTORS-python-holidays.txt"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(L.text("license.holidayData"))
                    .font(.headline)
                Text(Self.bodyText(directory: HolidayChoice.store.directory))
                    .font(.footnote)
                    .textSelection(.enabled)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(L.text("settings.info.licenses"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The text from the data folder `directory`, with the stand-ins for what cannot be read.
    static func bodyText(directory: URL?) -> String {
        func read(_ name: String) -> String? {
            directory.flatMap { try? String(contentsOf: $0.appendingPathComponent(name), encoding: .utf8) }
        }
        let license = read(licenseFile) ?? HolidayDataLicense.mitText
        let contributors = read(contributorsFile) ?? L.format("license.contributors", HolidayDataLicense.contributorsURL.absoluteString)
        return license + "\n\n" + contributors
    }
}
