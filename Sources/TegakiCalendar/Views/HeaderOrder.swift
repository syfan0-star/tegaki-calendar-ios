import Foundation

// 1.4.1 (docs/R1_4_1_CONTRACT.md §2.1, §3.2, §4.2, 0e-3, 0e-13): the order of the header's pieces, one pure table that
// `PageHeaderView` draws with a `ForEach` and a `switch`. Nothing here reads SwiftUI or UIKit, so `HeaderOrderTests` checks
// every row, hand and read-only state.

/// One piece of the header (`PageHeaderView`). `today` is the capsule 「‹ 今日 ›」: its three buttons ◀, 今日 and ▶ keep
/// their order inside it in both hands (the past on the left, as on the paper).
enum HeaderPiece: Hashable, CaseIterable, Sendable {
    /// 「‹ 今日 ›」 (◀ · 今日 · ▶, three buttons in one capsule, §3.1).
    case today
    /// 等倍 (the magnifying glass with a 1, §3.1, §3.6): back to the page's opening zoom.
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

    /// The pieces of `arm` from left to right. The right hand's (§3.2, 0e-3):
    ///
    /// ```
    /// wide           [today][zoomReset][title][picker][badge?][add][sync][settings]
    /// compactFirst   [today][title][add][sync][settings]
    /// compactSecond  [zoomReset][picker]
    /// ```
    ///
    /// The left hand's is the right hand's reversed (0e-13: the buttons of the free hand on its side), never a
    /// right-to-left `layoutDirection`, which would also turn the chevrons and the 日週月年 switch around. The badge only on
    /// the wide row and only while read only (the compact rows show the notice row instead, M5-13); it sits between the
    /// switch and 「＋予定」 (M5_CONTRACT §3.2's 「＋予定 の左」, §3.4 here).
    static func pieces(arm: Arm, hand: Hand, readOnly: Bool) -> [HeaderPiece] {
        let right: [HeaderPiece]
        switch arm {
        case .wide:
            var row: [HeaderPiece] = [.today, .zoomReset, .title, .picker]
            if readOnly { row.append(.badge) }
            row += [.add, .sync, .settings]
            right = row
        case .compactFirst:
            right = [.today, .title, .add, .sync, .settings]
        case .compactSecond:
            right = [.zoomReset, .picker]
        }
        switch hand {
        case .right: return right
        case .left: return Array(right.reversed())
        }
    }
}

#if DEBUG
// r141-alt only (docs/R1_4_1_CONTRACT.md §3.2, §7.5; the throwaway branch of the owner's choice photos, never merged): the order
// (b), the date first, which screenshot mode's `--screenshot-header-order b` lays out (`ScreenshotMode.headerOrderB`). Debug
// builds only, so a Release build is r141's: `HeaderPiece`, `pieces(arm:hand:readOnly:)` and `HeaderOrderTests` stay as they
// are. If the owner picks (b), r141 makes it the table itself, with the new piece `gap` (§3.2), and redoes D1–D2's gates.

/// One place of a row of the order (b): a piece, or the gap (`Spacer(minLength: 0)`) right after 「‹ 今日 ›」 and 等倍 that
/// keeps them next to the title instead of pushed to the far end (§3.2).
enum HeaderSlot: Hashable, Sendable {
    case piece(HeaderPiece)
    case gap
}

extension HeaderOrder {
    /// The order (b) of §3.2 from left to right. The right hand's:
    ///
    /// ```
    /// wide           [title][today][zoomReset][gap][picker][badge?][add][sync][settings]
    /// compactFirst   [title][today][gap][add][sync][settings]
    /// compactSecond  [zoomReset][picker]                         (as the order (a))
    /// ```
    ///
    /// The left hand's is the right hand's reversed, as in the order (a) (0e-13); the badge as in (a), the wide row only and
    /// only while read only.
    static func slotsB(arm: Arm, hand: Hand, readOnly: Bool) -> [HeaderSlot] {
        let right: [HeaderSlot]
        switch arm {
        case .wide:
            var row: [HeaderSlot] = [.piece(.title), .piece(.today), .piece(.zoomReset), .gap, .piece(.picker)]
            if readOnly { row.append(.piece(.badge)) }
            row += [.piece(.add), .piece(.sync), .piece(.settings)]
            right = row
        case .compactFirst:
            right = [.piece(.title), .piece(.today), .gap, .piece(.add), .piece(.sync), .piece(.settings)]
        case .compactSecond:
            right = pieces(arm: .compactSecond, hand: .right, readOnly: readOnly).map(HeaderSlot.piece)
        }
        switch hand {
        case .right: return right
        case .left: return Array(right.reversed())
        }
    }
}
#endif
