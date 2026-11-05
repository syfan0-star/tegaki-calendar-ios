import Foundation
import Holidays

/// The stroke budget of one page (1.1, K-9, M7A_CONTRACT D5 / §5): the numbers, how strokes are
/// counted, and the words of 設定 › 情報. Pure functions; the canvas (担当 P) decides with them, the
/// screen (担当 U) shows the notices, nothing here is stored or sent.
///
/// Strokes are counted as a 1.0 device counts them when it reads a page (`InkPage.init(json:)` of
/// 1.0 keeps at most 20,000 of strokes + unknown-tool strokes): `InkPage.budgetCount`.
public enum StrokeBudget {
    /// The device shows a notice once per page when a page first reaches this many strokes.
    public static let noticeAt = 15_000
    /// New strokes drawn on this device are refused from here on (erasing, moving and undo still work;
    /// iCloud, imports and undo are never stopped).
    public static let refuseAt = 19_000
    /// What a 1.0 device keeps of a page every time it reads it (F8; unchanged on 1.0 devices).
    public static let legacyReadCap = 20_000
    /// What 1.1 reads of a page (`InkPage.maxStrokes`, 60,000): a guard against broken or huge files.
    public static var readCap: Int { InkPage.maxStrokes }

    /// What the canvas reports: `.many(n)` the page has just reached `noticeAt` (n strokes now),
    /// `.full(n)` new strokes were refused (n strokes before them).
    public enum Event: Equatable, Sendable {
        case many(Int)
        case full(Int)
    }

    /// How many of `incoming` new strokes a page of `count` strokes takes:
    /// `min(incoming, max(0, refuseAt − count))` (a negative `incoming` counts as 0).
    public static func accepted(incoming: Int, count: Int) -> Int {
        Swift.min(Swift.max(0, incoming), Swift.max(0, refuseAt - count))
    }

    /// The count went from below `noticeAt` to `noticeAt` or more: `old < noticeAt ≤ new`.
    public static func crossesNotice(from old: Int, to new: Int) -> Bool {
        old < noticeAt && noticeAt <= new
    }

    /// The import check (§5.2): the number of strokes the page would have after importing `incoming`
    /// into a device page whose stroke ids are `localIds` — |localIds ∪ ids of incoming's strokes and
    /// unknown-tool strokes| minus the ids of that union tombstoned by `incoming` — when it exceeds
    /// `legacyReadCap` (a 1.0 device would show only part of it); nil when it does not.
    public static func importExceedsLegacyCap(localIds: Set<String>, incoming: InkPage) -> Int? {
        var union = localIds
        union.formUnion(incoming.strokes.keys)
        union.formUnion(incoming.unknownStrokes.keys)
        var count = union.count
        for id in incoming.deleted.keys where union.contains(id) {
            count -= 1
        }
        return count > legacyReadCap ? count : nil
    }

    /// One page of the count of 設定 › 情報 (`StrokeCensus`, 担当 U): live strokes as stored (before the
    /// read cap) and tombstones.
    public struct Entry: Equatable, Sendable {
        public var pageId: String
        public var strokes: Int
        public var tombstones: Int

        public init(pageId: String, strokes: Int, tombstones: Int) {
            self.pageId = pageId
            self.strokes = strokes
            self.tombstones = tombstones
        }
    }

    /// The page with the most strokes (on a tie the smaller pageId); nil when there is none or every
    /// page has 0 strokes.
    public static func largest(_ entries: [Entry]) -> Entry? {
        var best: Entry?
        for entry in entries where entry.strokes > 0 {
            guard let current = best else {
                best = entry
                continue
            }
            if entry.strokes > current.strokes || (entry.strokes == current.strokes && entry.pageId < current.pageId) {
                best = entry
            }
        }
        return best
    }

    /// `pageLabel(_:language:)` in Japanese. Two functions rather than a default argument, so that
    /// `.map(StrokeBudget.pageLabel)` still compiles (§0).
    public static func pageLabel(_ pageId: String) -> String {
        pageLabel(pageId, language: .ja)
    }

    /// 「年のページ（2026年）」「月のページ（2026年10月）」「週のページ（2026年10月5日〜10月11日）」
    /// (the header's week title; the week's form is read from the page's date, a Sunday id runs from
    /// that Sunday, K-11 rule 1) 「日のページ（2026年10月7日）」 (no weekday, no holiday name). A page
    /// id `PageNavigation.parse` cannot read is returned as it is.
    public static func pageLabel(_ pageId: String, language: UILanguage) -> String {
        guard let page = PageNavigation.parse(pageId: pageId) else { return pageId }
        let d = page.focus
        switch page.kind {
        case .year:
            return KitStrings.format("kit.budget.page.year", language, [PageNavigation.title(.year, focus: d, holidays: .none, language: language)])
        case .month:
            return KitStrings.format("kit.budget.page.month", language, [PageNavigation.title(.month, focus: d, holidays: .none, language: language)])
        case .week:
            let title = PageNavigation.title(.week, focus: d, holidays: .none, language: language, weekStart: WeekStart(weekPageDate: d) ?? .monday)
            return KitStrings.format("kit.budget.page.week", language, [title])
        case .day:
            return KitStrings.format("kit.budget.page.day", language, [DateText.plainDay(d, language)])
        }
    }

    /// 「12,345 本」: ja the number grouped by three digits with a half-width comma (whatever the
    /// locale), a space, 本; the other languages `DateText.number` and their word, one or other
    /// (en "1 stroke", "12,345 strokes"; de "12.345 Striche").
    public static func countText(_ n: Int, language: UILanguage = .ja) -> String {
        KitStrings.plural("kit.budget.count", language, count: n, [DateText.number(n, language)])
    }
}

extension InkPage {
    /// The strokes the budget counts (K-9, 0-16): live strokes plus strokes of a tool this version
    /// does not know (`liveStrokeCount + unknownStrokes.count`, as a 1.0 device counts toward its
    /// read cap).
    public var budgetCount: Int {
        liveStrokeCount + unknownStrokes.count
    }
}
