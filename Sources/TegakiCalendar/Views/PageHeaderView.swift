import Layout
import SwiftUI

/// The header above the paper (M3b contract §4.6, DESIGN §2.7):
///
/// ```
/// width ≥ 600 pt:  ◀  今日  ▶   題名                 [日 | 週 | 月 | 年]   ＋予定   ⚙
/// width < 600 pt:  ◀  今日  ▶   題名                                       ＋予定   ⚙
///                  [      日      |      週      |      月      |      年      ]
/// ```
///
/// The title comes from `PageNavigation.title`; the owner measures the width and passes `compact`.
/// (M3a's calendar menu moved to the settings screen.)
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

    var body: some View {
        if compact {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    navigationButtons
                    Spacer(minLength: 4)
                    titleText(.title3)
                    Spacer(minLength: 4)
                    addEventButton
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
                addEventButton
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

            Button("今日", action: onToday)
                .buttonStyle(.bordered)

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(Self.nextLabel(kind))
        }
    }

    private func titleText(_ font: Font) -> some View {
        Text(title)
            .font(font.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityAddTraits(.isHeader)
    }

    private var addEventButton: some View {
        Button(action: onAddEvent) {
            Label("予定", systemImage: "plus")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("予定を追加")
    }

    private var settingsButton: some View {
        Button(action: onSettings) {
            Image(systemName: "gearshape")
                .frame(minWidth: 44, minHeight: 44)
        }
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
}
