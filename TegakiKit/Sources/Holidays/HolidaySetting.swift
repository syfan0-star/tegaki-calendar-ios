import Foundation

/// A country and maybe one of its subdivisions, as the holiday setting and the data name them
/// (docs/M7B_CONTRACT.md 0-28): "US", "US-CA", "GB-SCT", "NZ-South Canterbury", "AR-C", "AT-9",
/// "FR-971".
public struct HolidayRegion: Hashable, Sendable {
    /// Two ASCII capitals ("US").
    public let country: String
    /// The subdivision as it was written (the data's spelling once `HolidayIndex.canonical` or the
    /// store has matched it), or nil for the whole country.
    public let subdivision: String?

    /// Parses a region code: two ASCII letters (either case; kept as capitals), then optionally "-"
    /// and a subdivision of 1 to 40 characters of [A-Za-z0-9 ], kept as written. Anything else is
    /// nil: "", "-", "US-", "-CA", "US--CA", "J", "JPN", "1A", "US-C@".
    public init?(code: String) {
        let scalars = Array(code.unicodeScalars)
        guard scalars.count >= 2, Self.isLetter(scalars[0]), Self.isLetter(scalars[1]) else { return nil }
        let country = String(String.UnicodeScalarView(scalars[0..<2])).uppercased()
        if scalars.count == 2 {
            self.init(country: country, subdivision: nil)
            return
        }
        guard scalars[2] == "-" else { return nil }
        let rest = scalars[3...]
        guard (1...40).contains(rest.count), rest.allSatisfy(Self.isSubdivisionScalar) else { return nil }
        self.init(country: country, subdivision: String(String.UnicodeScalarView(rest)))
    }

    init(country: String, subdivision: String?) {
        self.country = country
        self.subdivision = subdivision
    }

    /// "US" or "US-CA".
    public var code: String {
        subdivision.map { "\(country)-\($0)" } ?? country
    }

    /// The region without its subdivision.
    public var wholeCountry: HolidayRegion {
        HolidayRegion(country: country, subdivision: nil)
    }

    /// True when `text` is a subdivision code of 0-28 ([A-Za-z0-9 ], 1 to 40 characters).
    static func isSubdivisionCode(_ text: String) -> Bool {
        let scalars = text.unicodeScalars
        return (1...40).contains(scalars.count) && scalars.allSatisfy(isSubdivisionScalar)
    }

    private static func isLetter(_ s: Unicode.Scalar) -> Bool {
        ("A"..."Z").contains(s) || ("a"..."z").contains(s)
    }

    private static func isSubdivisionScalar(_ s: Unicode.Scalar) -> Bool {
        isLetter(s) || ("0"..."9").contains(s) || s == " "
    }
}

/// The holiday setting of this device (§5.6; UserDefaults "holidays.setting", never sent to
/// iCloud): automatic (the device's region), none, or one region.
public enum HolidaySetting: Hashable, Sendable {
    case automatic, none, region(HolidayRegion)

    /// "auto", nil, "" and anything that is not a region code are automatic; "none" is none; a
    /// region code is that region (0-28).
    public init(storageValue: String?) {
        switch storageValue {
        case nil, "", "auto":
            self = .automatic
        case "none":
            self = .none
        case let value?:
            if let region = HolidayRegion(code: value) {
                self = .region(region)
            } else {
                self = .automatic
            }
        }
    }

    /// "auto", "none", or the region code ("US-CA", "NZ-South Canterbury").
    public var storageValue: String {
        switch self {
        case .automatic: return "auto"
        case .none: return "none"
        case .region(let region): return region.code
        }
    }

    /// The region whose holidays the setting shows, or nil for none (0-20).
    ///
    /// Automatic is the country of `deviceRegion` (never a subdivision). A region is matched against
    /// the data with `index.canonical` (the data's spelling of a subdivision, a renamed code, an
    /// unknown subdivision as the whole country, an unknown country as nil). Without an index (it
    /// could not be read) only Japan resolves: its holidays need no data (§5.3).
    public func resolved(deviceRegion: String?, index: HolidayIndex?) -> HolidayRegion? {
        let wanted: HolidayRegion
        switch self {
        case .none:
            return nil
        case .automatic:
            guard let device = deviceRegion, device.unicodeScalars.count == 2,
                  let region = HolidayRegion(code: device) else { return nil }
            wanted = region
        case .region(let region):
            wanted = region
        }
        guard let index else {
            return wanted.country == "JP" ? wanted.wholeCountry : nil
        }
        return index.canonical(wanted)
    }
}
