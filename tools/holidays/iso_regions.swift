// The two-letter regions of Foundation (`Locale.Region.isoRegions`), one per line as
// "<code>\t<the region's name in Japanese>", sorted by code (docs/M7B_CONTRACT.md §5.1).
//
//     swift tools/holidays/iso_regions.swift > tools/holidays/iso-regions.txt
//
// Run once and commit the output; run it again only on purpose (a newer macOS may know a new
// region or name one differently). gen.py writes a country only when its code is in the first
// column (so "UK", python-holidays' alias of GB, never becomes a file); summarize.py shows the
// second column next to the code. The numeric regions (001, 419, …) are left out.
import Foundation

let japanese = Locale(identifier: "ja")
let codes = Locale.Region.isoRegions
    .map(\.identifier)
    .filter { $0.count == 2 && $0.unicodeScalars.allSatisfy { $0.value >= 65 && $0.value <= 90 } }
    .sorted()
for code in codes {
    print("\(code)\t\(japanese.localizedString(forRegionCode: code) ?? code)")
}
