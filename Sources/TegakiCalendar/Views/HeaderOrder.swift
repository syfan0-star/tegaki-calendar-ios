import Foundation

// 1.4.1 (docs/R1_4_1_CONTRACT.md §2.1, §4.2, §16.2; 0e-3 and 0e-13 as §16.12 reads them): the order of the header's
// pieces, one pure table that `PageHeaderView` draws with a `ForEach` and a `switch`. Nothing here reads SwiftUI or UIKit, so
// `HeaderOrderTests` checks every row, hand and read-only state.

/// One piece of the header (`PageHeaderView`). `today` is the capsule 「‹ 今日 ›」: its three buttons ◀, 今日 and ▶ keep
/// their order inside it in both hands (the past on the left, as on the paper).
enum HeaderPiece: Hashable, CaseIterable, Sendable {
    /// 「‹ 今日 ›」 (◀ · 今日 · ▶, three buttons in one capsule, §3.1).
    case today
    /// 等倍 (the magnifying glass with a 1, §3.1, §16.3): on the day and week pages one page (a day, a week) as wide as the
    /// paper's column, exactly; on the month and year pages back to the page's opening zoom.
    case zoomReset
    /// The page's title (the date); the only piece that gives way.
    case title
    /// The 日/週/月/年 switch.
    case picker
    /// The orange 「閲覧専用」 badge (the wide row only, while read only; M5_CONTRACT §3.2, §3.4 here).
    case badge
    /// 「＋予定」 (「＋」 alone below `PageHeaderView.addEventTextWidth`).
    case add
    /// ☁ the sync state.
    case sync
    /// ⚙
    case settings
}

enum HeaderOrder {
    /// The header's rows: the wide row (the column ≥ `CalendarRootScreen.compactWidth`), and the compact first and second
    /// rows below it.
    enum Arm: Equatable, CaseIterable, Sendable {
        case wide, compactFirst, compactSecond
    }

    /// The pieces of `arm` from left to right. The right hand's (§16.2, plan B):
    ///
    /// ```
    /// wide           [title][picker][badge?][add][sync][settings][zoomReset][today]
    /// compactFirst   [title][add][sync][settings][today]
    /// compactSecond  [picker][zoomReset]
    /// ```
    ///
    /// The date at the left end (the owner, 2026-11-21: 「年月日は一番左側でいいです」), 「‹ 今日 ›」 at the right end and
    /// 等倍 right inside it (the owner, 2026-11-22: 「＜今日＞と等倍は右端が右利き」): the buttons the writing hand presses
    /// most sit at that hand's end, ⚙ next to 等倍 (on the compact first row next to ◀), and on the compact rows 等倍 ends the
    /// second row, under ▶. The left hand's is the right hand's reversed (the writing hand's end is then the left one),
    /// never a right-to-left `layoutDirection`, which would also turn the chevrons and the 日週月年 switch around. The badge
    /// only on the wide row and only while read only (the compact rows show the notice row instead, M5-13); it sits between
    /// the switch and 「＋予定」 (M5_CONTRACT §3.2's 「＋予定 の左」, §3.4 here).
    static func pieces(arm: Arm, hand: Hand, readOnly: Bool) -> [HeaderPiece] {
        let right: [HeaderPiece]
        switch arm {
        case .wide:
            var row: [HeaderPiece] = [.title, .picker]
            if readOnly { row.append(.badge) }
            row += [.add, .sync, .settings, .zoomReset, .today]
            right = row
        case .compactFirst:
            right = [.title, .add, .sync, .settings, .today]
        case .compactSecond:
            right = [.picker, .zoomReset]
        }
        switch hand {
        case .right: return right
        // MUTATION MH1 (r141-q-m2 only, never merged; docs/R1_4_1_CONTRACT.md §16.7, HeaderOrderTests): the left hand's
        // rows are the right hand's as they are (was: the right hand's reversed).
        case .left: return right
        }
    }
}
