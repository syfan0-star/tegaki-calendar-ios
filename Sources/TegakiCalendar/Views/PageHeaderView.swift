import Access
import Layout
import SwiftUI
import UIKit

/// The header above the paper (M3b contract §4.6, M4 contract §6.1, M4B contract §5, DESIGN §2.7). Since 1.4.1
/// (docs/R1_4_1_CONTRACT.md §3, §16.2, 0e-2 … 0e-5), the right hand's rows (the left hand's are the same rows reversed):
///
/// ```
/// width ≥ 600 pt:  題名           [日 | 週 | 月 | 年]  🔒閲覧専用  ＋予定   ☁ 保存済み   ⚙ (1🔍) (‹ 今日 ›)
/// width < 600 pt:  10/5〜10/11            ＋ ☁ ⚙ (‹ 今日 ›)
///                  [      日      |      週      |      月      |      年      ] [1🔍]
/// ```
///
/// 1.4.1 (the owner's request of 2026-11-21 and correction of 2026-11-22, docs/R1_4_1_CONTRACT.md §1.2, §16.1, §16.2):
/// 「‹ 今日 ›」 — ◀, 今日 and ▶, three buttons in one capsule (`todayCapsule`, §3.1) — sits at the writing hand's end of the
/// row (the right end for the right hand: 「＜今日＞と等倍は右端が右利き」), and right inside it the 等倍 button
/// (`zoomResetButton`: the magnifying glass with a 1, §16.3), which on the compact rows ends the second row instead, under
/// ▶ (the first has no room for it). The title (the date) starts the row at the other end (「年月日は一番左側でいいです」),
/// and ⚙ sits next to 等倍 (on the compact first row next to ◀). 1.1.1 had put 「今日」 on the right, left of 「＋予定」
/// (docs/R1_1_1.md); 1.4.1 keeps it on the right, at the end, in one capsule with ◀ and ▶. The order of every row is one
/// pure table, `HeaderOrder.pieces(arm:hand:readOnly:)`, drawn with a `ForEach` and a `switch`: the left hand (`hand`,
/// 設定 › 入力 「利き手」) is the right hand's order reversed, never a right-to-left `layoutDirection` (◀ stays left of ▶,
/// the switch keeps 日週月年, §4.2). The rows keep 1.4's heights (§3.3): the wide row and the first row 44 pt, and the
/// second row's 等倍 grows to the switch's height without deciding it (`fixedSize(horizontal: false, vertical: true)`), so
/// the paper area, the opening zooms and the photos below the header stay 1.4's.
///
/// M5 (M5_CONTRACT §3.2): while the app is read only (`readOnly`) an orange 「閲覧専用」 badge sits on the wide row (the
/// symbol alone below `readOnlyTextWidth`); a tap opens the paywall (`onReadOnlyTap`). Since 1.4.1 (§3.4, 0e-5) it sits
/// between the switch and 「＋予定」, M5's 「＋予定 の左」 (mirrored for the left hand). The compact rows have no room for it
/// (M4B-15), so there the owner shows a notice row under the header instead (M5-13). 「‹ 今日 ›」 and 等倍 work while read
/// only too (`GatedAction.navigate`, `.zoom`).
///
/// The title comes from `PageNavigation.title` (`compactTitle` on the compact rows, M4b, and on an iPhone's wide row, 1.4.1:
/// the owner passes the short form, `CalendarRootScreen.usesShortTitle`);
/// the owner measures the width and passes `compact`. Every button keeps its size (`fixedSize`, `layoutPriority(1)`; 96dafab)
/// and only the title gives way: its frame takes the room the buttons leave (`maxWidth: .infinity`, leading for the right
/// hand, trailing for the left, so what the text leaves lies between the title and the switch, or 「＋」 on the compact
/// first row), its text shrinks to `minimumScaleFactor(0.6)` and is then cut with 「…」. On the compact first row the fixed
/// parts take about 297.4 pt in ja (the 12 pt side paddings, the capsule's 44 + 47.4 + 44, ＋ 52, ☁ 26,
/// ⚙ 44 and four gaps of 4; 1.4's row took 324), so the title has about `width − 297.4`: 77.6 pt at 375, 84.6 on the iPhone
/// Duo's outer screen (382), 104.6 on the 402 pt iPhone 17 — the longest Japanese short title (「10/24〜10/30」) needs 70 at
/// the minimum scale. 1.4 D1d's tight row for the Duo's outer screen (`usesTightRow`, `sideInsets`) is retired (§3.2): the
/// new first row leaves the outer screen more room than the tight row did (80 pt).
///
/// The ☁ shows the sync state (`SyncStatus.header`): the text and the symbol at 600 pt and wider, the
/// symbol alone below (iPhone, M4 contract §6.8); a tap opens the settings screen. It is redrawn only
/// when `sync` changes (the engine publishes a new snapshot only when the status changed). (M3a's
/// calendar menu moved to the settings screen.)
struct PageHeaderView: View {
    var kind: PageKind
    var title: String
    /// Width < 600 pt (iPhone, narrow split view): the switch goes to a second row.
    var compact: Bool
    var onPrevious: () -> Void
    var onToday: () -> Void
    var onNext: () -> Void
    var onKindChange: (PageKind) -> Void
    /// 「＋予定」 (DESIGN §4.5: today 9:00〜10:00, or today all-day on the month / year page).
    var onAddEvent: () -> Void
    /// ⚙
    var onSettings: () -> Void
    /// The sync state for the ☁ (`SyncStatus.header`); nil shows no ☁. Below `syncTextWidth` only the symbol.
    var sync: HeaderSync? = nil
    /// ☁: opens the settings screen (`showSettings = true`).
    var onSyncTap: () -> Void = {}
    /// The available width in points (the owner measures it). Decides which labels keep their text:
    /// below `syncTextWidth` the ☁ is the symbol alone, below `addEventTextWidth` 「＋予定」 is the
    /// 「＋」 alone. Without it (`.infinity`) everything shows its text. The day page has the longest
    /// title (「2026年10月15日(木)」), and on an 11-inch iPad in portrait (834 pt) the single row did
    /// not fit, so SwiftUI squeezed the 「今日」 label to nothing; the buttons now keep their size
    /// (`fixedSize` / `layoutPriority`) and only the title shrinks or is cut.
    var width: CGFloat = .infinity
    /// M5 (M5_CONTRACT §3.2): the app is read only (unsubscribed, expired, …): the badge is shown on the
    /// wide row. Never shown while in the billing grace period (`canEdit` stays true then, M5-16).
    var readOnly: Bool = false
    /// バッジのタップ: ペイウォール（reason .badge）
    var onReadOnlyTap: () -> Void = {}
    /// 1.2 (F-11): the holiday name `title` ends with, on the day page's wide row. The languages other
    /// than ja draw it as its own text that gives way first, so the date keeps its size. nil: one text.
    var titleHoliday: String? = nil
    /// 1.4.1 (docs/R1_4_1_CONTRACT.md §2.1, §4.1, §4.2, 0e-12, 0e-13): 設定 › 入力 「利き手」 (the owner reads
    /// `AppSettings.handKey`, or screenshot mode's `--screenshot-hand`). `.left` reverses every row (`HeaderOrder`).
    var hand: Hand = .right
    /// 1.4.1 (§2.1, §16.3): 等倍: the owner asks both canvases to reset the zoom (`resetZoom`): on the day and week pages
    /// one page as wide as the paper's column, on the month and year pages the opening zoom. Nothing by default, so a header
    /// without it behaves as 1.4's.
    var onZoomReset: () -> Void = {}

    /// Below this width the ☁ shows only its symbol (13-inch portrait is 1024 pt, 11-inch is 834 pt).
    static let syncTextWidth: CGFloat = 980
    /// Below this width 「＋予定」 shows only the 「＋」 (a 2/3 split view on a 13-inch iPad is 678 pt).
    static let addEventTextWidth: CGFloat = 760
    /// この幅未満ではバッジは記号（lock.fill）だけ（☁ が記号だけになる幅と同じ。11 インチ縦 834 と mini 744 は
    /// 記号だけ、13 インチ縦 1024 と 11 インチ横 1194 は文字つき。M5-32: 760 にすると 11 インチ縦の日ページの
    /// 題名（上の `width` の注記）がさらに縮む）
    static let readOnlyTextWidth: CGFloat = syncTextWidth
    /// The badge's accessibility label.
    static let readOnlyLabel = L.text("header.readOnly.spoken")

    /// 1.4.1 (§3.1, 0e-2): the 等倍 button's symbol, the magnifying glass with a 1 (no word to translate; `HeaderGlyphTests`
    /// checks the system has it).
    static let zoomResetSymbol = "1.magnifyingglass"
    /// 1.4.1 (§2.1, §3.1): the 等倍 button's identifier, for the UI tests.
    static let zoomResetIdentifier = "header.zoomReset"
    /// 1.4.1 (§3.1, §8.1): the 等倍 button's accessibility label (「等倍に戻す」).
    static var zoomResetLabel: String { L.text("header.zoomReset.spoken") }
    /// 1.4.1 (§3.1): the height of the capsule 「‹ 今日 ›」 and the diameter of the wide row's 等倍 circle; their tap targets
    /// stay 44 pt.
    static let capsuleHeight: CGFloat = 36

    private var showsSyncText: Bool { !compact && width >= Self.syncTextWidth }
    private var showsAddEventText: Bool { width >= Self.addEventTextWidth }
    private var showsReadOnlyText: Bool { width >= Self.readOnlyTextWidth }
    /// 1.4.1 (§16.2; 0e-5 as §16.12 reads it): the title starts the row at the end away from the writing hand: leading for
    /// the right hand (the date at the left end), trailing for the left (at the right end).
    private var titleAlignment: Alignment { hand == .left ? .trailing : .leading }

    var body: some View {
        if compact {
            // M4B contract §5: spacing 4 and a 17 pt title on the first row (the buttons keep their 44 pt targets and
            // `fixedSize`). 1.4.1 (§3.3, §16.2): the second row is the switch and 等倍, as tall as the switch.
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(HeaderOrder.pieces(arm: .compactFirst, hand: hand, readOnly: readOnly), id: \.self) { piece in
                        view(for: piece, in: .compactFirst)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(HeaderOrder.pieces(arm: .compactSecond, hand: hand, readOnly: readOnly), id: \.self) { piece in
                        view(for: piece, in: .compactSecond)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            HStack(spacing: 6) {
                ForEach(HeaderOrder.pieces(arm: .wide, hand: hand, readOnly: readOnly), id: \.self) { piece in
                    view(for: piece, in: .wide)
                }
            }
        }
    }

    // MARK: - Pieces

    /// 1.4.1 (§3.1–§3.4): one piece of `arm`. The title takes the room the others leave; the switch is 220 pt on the wide
    /// row and takes the second row's room beside 等倍.
    @ViewBuilder
    private func view(for piece: HeaderPiece, in arm: HeaderOrder.Arm) -> some View {
        switch piece {
        case .today:
            todayCapsule
        case .zoomReset:
            zoomResetButton(fillsRow: arm == .compactSecond)
        case .title:
            titleText(arm == .wide ? .title2 : .headline)
                .frame(maxWidth: .infinity, alignment: titleAlignment)
        case .picker:
            if arm == .wide {
                kindPicker
                    .frame(width: 220)
                    .layoutPriority(1)
            } else {
                kindPicker
                    .frame(maxWidth: .infinity)
            }
        case .badge:
            readOnlyBadge
        case .add:
            addEventButton
        case .sync:
            syncButton
        case .settings:
            settingsButton
        }
    }

    /// M5 (M5_CONTRACT §3.2): the orange 「閲覧専用」 badge (the lock alone below `readOnlyTextWidth`),
    /// on the wide row only. Not an error colour: read only is a state, not a fault.
    @ViewBuilder
    private var readOnlyBadge: some View {
        if readOnly {
            Button(action: onReadOnlyTap) {
                if showsReadOnlyText {
                    Label(PlanText.readOnlyBadgeText(language: L.language), systemImage: "lock.fill")
                        .font(.footnote)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.footnote)
                }
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .controlSize(.small)
            .fixedSize()
            .layoutPriority(1)
            .accessibilityLabel(Self.readOnlyLabel)
        }
    }

    /// 1.4.1 (§3.1, 0e-2): 「‹ 今日 ›」, three buttons side by side in one 36 pt capsule (`tertiarySystemFill`) with two thin
    /// lines between them that take no width: ◀ (44 × 44, 「前の日／週／月／年」), 今日 (`header.today` at 17 pt, the
    /// `.body` of 1.4's `.bordered` 「今日」, 8 pt on each side, at least 44 × 44, 「今日」) and ▶ (44 × 44, 「次の…」). The
    /// spoken names and the words are 1.4's, so the UI tests find them as before; the ‹ › are the chevrons, never part of
    /// `header.today` (de 「Heute」 is at its width limit, PaperFitTests). ◀ is always left of ▶. About 135.4 pt in ja and
    /// 151.4 in en and de (§3.5 measures it); `fixedSize`, so the title gives way, never the capsule.
    private var todayCapsule: some View {
        HStack(spacing: 0) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Self.previousLabel(kind))

            Button(action: onToday) {
                Text(L.text("header.today"))
                    .font(.body)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 8)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .overlay(alignment: .leading) { Self.capsuleDivider }
            .overlay(alignment: .trailing) { Self.capsuleDivider }

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Self.nextLabel(kind))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .background {
            Capsule()
                .fill(Color(uiColor: .tertiarySystemFill))
                .frame(height: Self.capsuleHeight)
        }
        .fixedSize()
        .layoutPriority(1)
    }

    /// The 1 × 18 pt line between two buttons of the capsule (drawn over the 今日 button's edges: no width, no tap).
    private static var capsuleDivider: some View {
        Rectangle()
            .fill(Color(uiColor: .separator))
            .frame(width: 1, height: 18)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// 1.4.1 (§3.1, §3.3, §16.3, 0e-2, 0e-4): 等倍 (`zoomResetSymbol`, 「等倍に戻す」, `zoomResetIdentifier`). Always
    /// shown and always enabled, read only too. On the day and week pages a tap makes one page exactly as wide as the paper's
    /// column (from the opening zoom too, which is narrower on most screens; once there, another tap changes nothing); on the
    /// month and year pages it goes back to the opening zoom (there, a tap changes nothing). On the wide row a 44 × 44
    /// target on a 36 pt circle; on the compact second row (`fillsRow`) a rounded rectangle at least 44 wide that grows to
    /// the switch's height (`maxHeight: .infinity` in a row of `fixedSize(horizontal: false, vertical: true)`) and never
    /// sets it.
    private func zoomResetButton(fillsRow: Bool) -> some View {
        Button(action: onZoomReset) {
            if fillsRow {
                Image(systemName: Self.zoomResetSymbol)
                    .font(.body)
                    .frame(minWidth: 44, maxHeight: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(uiColor: .tertiarySystemFill))
                    }
                    .contentShape(Rectangle())
            } else {
                Image(systemName: Self.zoomResetSymbol)
                    .font(.body)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(Color(uiColor: .tertiarySystemFill))
                            .frame(width: Self.capsuleHeight, height: Self.capsuleHeight)
                    }
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
        .accessibilityLabel(Self.zoomResetLabel)
        .accessibilityIdentifier(Self.zoomResetIdentifier)
    }

    /// F-11: one text in ja (1.1), and whenever there is no holiday; otherwise the date and the
    /// holiday are two texts and the holiday is cut first.
    @ViewBuilder
    private func titleText(_ font: Font) -> some View {
        if let parts = Self.titleParts(title, holiday: titleHoliday, language: L.language) {
            HStack(spacing: 6) {
                Text(parts.date)
                    .font(font.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .layoutPriority(1)
                Text(parts.holiday)
                    .font(font.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(Self.titleIdentifier)
        } else {
            Text(title)
                .font(font.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(Self.titleIdentifier)
        }
    }

    /// The title's identifier for the language UI tests (§7.3).
    static let titleIdentifier = "page.title"

    /// F-11: `title` split into the date and the holiday name it ends with; nil for ja, and when there
    /// is nothing to split (no holiday, or a title without it, as the compact rows have).
    static func titleParts(_ title: String, holiday: String?, language: UILanguage) -> (date: String, holiday: String)? {
        guard language != .ja, let holiday = holiday, !holiday.isEmpty, title.hasSuffix(" " + holiday) else { return nil }
        return (String(title.dropLast(holiday.count + 1)), holiday)
    }

    /// 「＋予定」, or the 「＋」 alone below `addEventTextWidth` (at least 28 × 28).
    private var addEventButton: some View {
        Button(action: onAddEvent) {
            if showsAddEventText {
                Label(L.text("header.addEvent"), systemImage: "plus")
                    .labelStyle(.titleAndIcon)
            } else {
                Image(systemName: "plus")
                    .frame(minWidth: 28, minHeight: 28)
            }
        }
        .buttonStyle(.bordered)
        .fixedSize()
        .layoutPriority(1)
        .accessibilityLabel(L.text("header.addEvent.spoken"))
    }

    /// ☁ + the state (the symbol alone when compact or narrower than `syncTextWidth`). Red when
    /// the state is an error.
    @ViewBuilder
    private var syncButton: some View {
        if let sync = sync {
            Button(action: onSyncTap) {
                HStack(spacing: 4) {
                    Image(systemName: sync.symbol)
                    if showsSyncText {
                        Text(sync.text)
                            .lineLimit(1)
                    }
                }
                .font(.footnote)
                .foregroundStyle(sync.isError ? Color.red : Color.secondary)
                .padding(.horizontal, 4)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .layoutPriority(1)
            .accessibilityLabel(Self.syncLabel(sync))
        }
    }

    private var settingsButton: some View {
        Button(action: onSettings) {
            Image(systemName: "gearshape")
                .frame(minWidth: 44, minHeight: 44)
        }
        .layoutPriority(1)
        .accessibilityLabel(L.text("header.settings.spoken"))
    }

    /// The 日/週/月/年 switch. Switching keeps the focus day (M3a contract §4.2).
    private var kindPicker: some View {
        Picker(L.text("header.picker.spoken"), selection: Binding(get: { kind }, set: { onKindChange($0) })) {
            ForEach(Self.pickerOrder, id: \.self) { item in
                Text(Self.shortLabel(item))
                    .accessibilityLabel(Self.pickerItemLabel(item))
                    .tag(item)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(L.text("header.picker.spoken"))
    }

    /// The order of the segments.
    static let pickerOrder: [PageKind] = [.day, .week, .month, .year]

    static func shortLabel(_ kind: PageKind) -> String {
        switch kind {
        case .day: return L.text("header.picker.day")
        case .week: return L.text("header.picker.week")
        case .month: return L.text("header.picker.month")
        case .year: return L.text("header.picker.year")
        }
    }

    static func pickerItemLabel(_ kind: PageKind) -> String {
        switch kind {
        case .day: return L.text("header.pickerItem.day")
        case .week: return L.text("header.pickerItem.week")
        case .month: return L.text("header.pickerItem.month")
        case .year: return L.text("header.pickerItem.year")
        }
    }

    /// 「前の日」: one sentence per kind (§4.2), never 「前の」 + a word.
    static func previousLabel(_ kind: PageKind) -> String {
        switch kind {
        case .day: return L.text("header.previous.day")
        case .week: return L.text("header.previous.week")
        case .month: return L.text("header.previous.month")
        case .year: return L.text("header.previous.year")
        }
    }

    static func nextLabel(_ kind: PageKind) -> String {
        switch kind {
        case .day: return L.text("header.next.day")
        case .week: return L.text("header.next.week")
        case .month: return L.text("header.next.month")
        case .year: return L.text("header.next.year")
        }
    }

    /// The ☁'s accessibility label: 「同期: 保存済み」.
    static func syncLabel(_ sync: HeaderSync) -> String {
        L.format("header.sync.spoken", sync.text)
    }
}
