// The public documents (M5_CONTRACT §1.5, D5): the Web repository's Pages under app/, Apple's standard
// EULA (M5-8), and the support address (M5-1). 設定 › 情報 and the paywall open these.
import Foundation

public enum LegalLinks {
    public static let base = URL(string: "https://syfan0-star.github.io/tegaki-calendar/app/")!
    public static let terms = base.appending(path: "terms.html")
    public static let privacy = base.appending(path: "privacy.html")
    public static let support = base.appending(path: "support.html")
    /// Apple 標準の使用許諾契約（M5-8。審査 3.1.2(a) が説明欄とアプリ内に求める）
    public static let appleEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    public static let appleEULATitle = "使用許諾契約（Apple 標準 EULA）"
    /// M5-1
    public static let supportEmail = "syfan0@gmail.com"
}
