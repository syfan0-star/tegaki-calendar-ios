import Layout
import SwiftUI

/// The header above the paper (M3b contract §4.6, M4 contract §6.1, M4B contract §5, DESIGN §2.7):
///
/// ```
/// width ≥ 600 pt:  ◀  今日  ▶   題名              [日 | 週 | 月 | 年]   ＋予定   ☁ 保存済み   ⚙
/// width < 600 pt:  ◀ 今日 ▶  10/5〜10/11  ＋ ☁ ⚙
///                  [      日      |      週      |      月      |      年      ]
/// ```
///
/// The title comes from `PageNavigation.title` (`compactTitle` on the compact rows, M4b: the owner
/// passes the short form); the owner measures the width and passes `compact`. On the compact first
/// row the fixed parts (◀ 今日 ▶ ＋ ☁ ⚙ with their 44 pt tap targets and `.bordered` padding) take
/// about 299 pt, so the spacing is 4, the spacers have no minimum and the title is `.headline`
/// (17 pt): about 79 pt remain for it on a 402 pt iPhone, 67 pt on a 390 pt one, enough for every
/// short title at `minimumScaleFactor(0.6)` (M4B-15). The ☁ shows the sync state
/// (`SyncStatus.header`): the text and the symbol at 600 pt and wider, the symbol alone below
/// (iPhone, M4 contract §6.8); a tap opens the settings screen. It is redrawn only when `sync`
/// changes (the engine publishes a new snapshot only when the status changed). (M3a's calendar menu
/// moved to the settings screen.)
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

    /// Below this width the ☁ shows only its symbol (13-inch portrait is 1024 pt, 11-inch is 834 pt).
    static let syncTextWidth: CGFloat = 980
    /// Below this width 「＋予定」 shows only the 「＋」 (a 2/3 split view on a 13-inch iPad is 678 pt).
    static let addEventTextWidth: CGFloat = 760

    private var showsSyncText: Bool { !compact && width >= Self.syncTextWidth }
    private var showsAddEventText: Bool { width >= Self.addEventTextWidth }

    var body: some View {
        if compact {
            VStack(spacing: 4) {
                // M4B contract §5: spacing 4, no spacer minimum, a 17 pt title (the buttons keep
                // their 44 pt targets, `.bordered` and `fixedSize`).
                HStack(spacing: 4) {
                    navigationButtons
                    Spacer(minLength: 0)
                    titleText(.headline)
                    Spacer(minLength: 0)
                    addEventButton
                    syncButton
                    settingsButton
                }
                kindPicker
                    .frame(maxWidth: .infinity)
            }
        } else {
            HStack(spacing: 6) {
                navigationButtons
                Spacer(minLength: 8)
                titleText(.title2)
                Spacer(minLength: 8)
                kindPicker
                    .frame(width: 220)
                    .layoutPriority(1)
                addEventButton
                syncButton
                settingsButton
            }
        }
    }

    // MARK: - Pieces

    private var navigationButtons: some View {
        HStack(spacing: 6) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(Self.previousLabel(kind))

            // `fixedSize`: the label must never be squeezed away when the row is too narrow
            // (the day page on an 11-inch iPad in portrait); the title gives way instead.
            Button("今日", action: onToday)
                .buttonStyle(.bordered)
                .fixedSize()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(Self.nextLabel(kind))
        }
        .layoutPriority(1)
    }

    private func titleText(_ font: Font) -> some View {
        Text(title)
            .font(font.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityAddTraits(.isHeader)
    }

    /// 「＋予定」, or the 「＋」 alone below `addEventTextWidth`.
    private var addEventButton: some View {
        Button(action: onAddEvent) {
            if showsAddEventText {
                Label("予定", systemImage: "plus")
                    .labelStyle(.titleAndIcon)
            } else {
                Image(systemName: "plus")
                    .frame(minWidth: 28, minHeight: 28)
            }
        }
        .buttonStyle(.bordered)
        .fixedSize()
        .layoutPriority(1)
        .accessibilityLabel("予定を追加")
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
        .accessibilityLabel("設定")
    }

    /// The 日/週/月/年 switch. Switching keeps the focus day (M3a contract §4.2).
    private var kindPicker: some View {
        Picker("表示の切替", selection: Binding(get: { kind }, set: { onKindChange($0) })) {
            ForEach(Self.pickerOrder, id: \.self) { item in
                Text(Self.shortLabel(item))
                    .accessibilityLabel(Self.pickerItemLabel(item))
                    .tag(item)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("表示の切替")
    }

    /// The order of the segments.
    static let pickerOrder: [PageKind] = [.day, .week, .month, .year]

    static func shortLabel(_ kind: PageKind) -> String {
        switch kind {
        case .day: return "日"
        case .week: return "週"
        case .month: return "月"
        case .year: return "年"
        }
    }

    static func pickerItemLabel(_ kind: PageKind) -> String {
        shortLabel(kind) + "表示"
    }

    static func previousLabel(_ kind: PageKind) -> String {
        "前の" + shortLabel(kind)
    }

    static func nextLabel(_ kind: PageKind) -> String {
        "次の" + shortLabel(kind)
    }

    /// The ☁'s accessibility label: 「同期: 保存済み」.
    static func syncLabel(_ sync: HeaderSync) -> String {
        "同期: " + sync.text
    }
}
