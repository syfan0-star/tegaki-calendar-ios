import Foundation

/// The ten languages the app shows (1.2, docs/M7B_CONTRACT.md O-1, §0, §2.1). A device in any other
/// language gets English. The raw values are the names of the app's `.lproj` folders.
///
/// TegakiKit never looks the language up by itself (D4): every function that returns words takes
/// `language: UILanguage` (default `.ja`, the text of 1.1) and reads `KitStrings`; the app passes
/// `L.language`, which is `UILanguage.current` read once at launch.
public enum UILanguage: String, CaseIterable, Sendable, Codable {
    case ja, en, zhHans = "zh-Hans", zhHant = "zh-Hant", ko, fr, de, es, it, ptBR = "pt-BR"

    /// The language of a bundle localization name (0-1, 0-2): "ja" → ja; "en", "en-GB" → en;
    /// "zh-Hans", "zh-CN", "zh-SG" → zhHans; "zh-Hant", "zh-TW", "zh-HK", "zh-MO", "yue-Hant" →
    /// zhHant; "ko" → ko; "fr", "fr-CA" → fr; "de", "de-CH" → de; "es", "es-419", "es-MX" → es;
    /// "it" → it; "pt", "pt-BR", "pt-PT" → ptBR. Case and "_" against "-" do not matter ("pt_PT",
    /// "ZH-hant-hk"). Chinese goes by its script when the name has one ("Hans" / "Hant"), otherwise
    /// by its region (TW, HK, MO → zhHant, any other or none → zhHans); Cantonese ("yue") is zhHant
    /// unless it says "Hans". Subtags after an extension ("-u-…", "-x-…") are not read. Anything
    /// else, nil and "" → en (O-1: the languages of the other devices get English).
    public static func resolve(_ localization: String?) -> UILanguage {
        guard let localization else { return .en }
        let subtags = localization.lowercased()
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .map(String.init)
        guard let language = subtags.first else { return .en }
        var script: String?
        var region: String?
        for subtag in subtags.dropFirst() {
            if subtag.count == 1 { break }  // "u", "x", …: an extension or private use follows
            if subtag.count == 4, script == nil, region == nil {
                script = subtag
            } else if region == nil, subtag.count == 2 || (subtag.count == 3 && subtag.allSatisfy(\.isNumber)) {
                region = subtag
            }
        }
        switch language {
        case "ja": return .ja
        case "en": return .en
        case "ko": return .ko
        case "fr": return .fr
        case "de": return .de
        case "es": return .es
        case "it": return .it
        case "pt": return .ptBR
        case "zh":
            if script == "hant" { return .zhHant }
            if script == "hans" { return .zhHans }
            return ["tw", "hk", "mo"].contains(region ?? "") ? .zhHant : .zhHans
        case "yue":
            return script == "hans" ? .zhHans : .zhHant
        default:
            return .en
        }
    }

    /// The language of the screen: `resolve(Bundle.main.preferredLocalizations.first)`, the `.lproj`
    /// iOS chose for the app (§2.1). iOS ends the app when the language changes, so it does not change
    /// while the app runs; the app reads it once (`L.language`).
    public static var current: UILanguage {
        resolve(Bundle.main.preferredLocalizations.first)
    }

    /// The locale for formatting in this language with the device's region (D6): "<rawValue>_<region>"
    /// (.en, "JP" → en_JP; .zhHant, "HK" → zh-Hant_HK), only the language when `region` is nil or
    /// empty (.ja → ja). `ptBR` names a region already ("pt-BR" would read "pt-BR_US" as the region BR
    /// with a variant US), so it is "pt_<region>" (pt_BR, pt_PT, pt_US) and "pt-BR" without a region.
    public func locale(region: String? = Locale.current.region?.identifier) -> Locale {
        guard let region, !region.isEmpty else { return Locale(identifier: rawValue) }
        switch self {
        case .ptBR: return Locale(identifier: "pt_" + region)
        default: return Locale(identifier: rawValue + "_" + region)
        }
    }

    /// The plural form of `n` (0-8, D5): ja, ko, zh-Hans and zh-Hant are always `.other` (their `.one`
    /// text is the same as `.other`); en, de, es and it are `.one` for 1 only; fr and pt-BR for 0 and 1.
    /// Like CLDR, the sign does not count (-1 is `.one` in en).
    public func pluralCategory(_ n: Int) -> PluralCategory {
        switch self {
        case .ja, .ko, .zhHans, .zhHant:
            return .other
        case .en, .de, .es, .it:
            return n.magnitude == 1 ? .one : .other
        case .fr, .ptBR:
            return n.magnitude <= 1 ? .one : .other
        }
    }

    /// ja, zh-Hans, zh-Hant and ko: the languages written with the CJK weekday signs (§3.3, F-8).
    public var isCJK: Bool {
        switch self {
        case .ja, .zhHans, .zhHant, .ko: return true
        case .en, .fr, .de, .es, .it, .ptBR: return false
        }
    }
}

/// The two plural forms the app's texts have (D5): a key "<k>.one" and "<k>.other" each.
public enum PluralCategory: String, Sendable {
    case one, other
}
