// The public documents (M5_CONTRACT §1.5, D5): the Web repository's Pages under app/, Apple's standard
// EULA (M5-8), and the support address (M5-1). 設定 › 情報 and the paywall open these.
import Foundation
import DayKit

public enum LegalLinks {
    /// Whether the English pages (app/en/…) are on the web and answer 200 (D11, 0-38). They went up on
    /// 2026-11-06, the day 1.2 was released; 1.2, reviewed before that day, opened the Japanese pages in
    /// every language. From 1.2.1 a screen outside ja opens the English pages (0-38, docs/R1_2_1.md §3).
    public static let englishPagesPublished = true

    public static let base = URL(string: "https://syfan0-star.github.io/tegaki-calendar/app/")!
    public static let terms = base.appending(path: "terms.html")
    public static let privacy = base.appending(path: "privacy.html")
    public static let support = base.appending(path: "support.html")
    /// Apple 標準の使用許諾契約（M5-8。審査 3.1.2(a) が説明欄とアプリ内に求める）
    public static let appleEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    public static let appleEULATitle = "使用許諾契約（Apple 標準 EULA）"
    /// M5-1
    public static let supportEmail = "syfan0@gmail.com"

    /// The terms for a screen in `language`: the Japanese page for ja and while `published` is false,
    /// app/en/terms.html otherwise (a language without its own page is `.en` by then, O-1).
    public static func terms(for language: UILanguage, published: Bool = englishPagesPublished) -> URL {
        page("terms.html", language, published)
    }

    /// The privacy policy for a screen in `language`, as `terms(for:published:)`.
    public static func privacy(for language: UILanguage, published: Bool = englishPagesPublished) -> URL {
        page("privacy.html", language, published)
    }

    /// The support page for a screen in `language`, as `terms(for:published:)`.
    public static func support(for language: UILanguage, published: Bool = englishPagesPublished) -> URL {
        page("support.html", language, published)
    }

    /// `appleEULATitle` in `language`.
    public static func appleEULATitle(_ language: UILanguage) -> String {
        KitStrings.text("kit.legal.appleEULATitle", language)
    }

    private static func page(_ name: String, _ language: UILanguage, _ published: Bool) -> URL {
        published && language != .ja ? base.appending(path: "en/" + name) : base.appending(path: name)
    }
}
