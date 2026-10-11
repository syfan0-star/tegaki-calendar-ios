import Layout
import SwiftUI

/// The header above the paper (contract §4.2, DESIGN §2.7):
///
/// ```
/// ◀  今日  ▶   題名                          [日 | 週 | 月 | 年]   📅
/// ```
///
/// `trailing` is the owner's extra control (the calendar menu); the title comes from
/// `PageNavigation.title`.
struct PageHeaderView<Trailing: View>: View {
    var kind: PageKind
    var title: String
    var onPrevious: () -> Void
    var onToday: () -> Void
    var onNext: () -> Void
    var onKindChange: (PageKind) -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
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

            Spacer(minLength: 8)

            Text(title)
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            kindPicker

            trailing()
        }
    }

    /// The 日/週/月/年 switch. Switching keeps the focus day (contract §4.2).
    private var kindPicker: some View {
        Picker("表示の切替", selection: Binding(get: { kind }, set: { onKindChange($0) })) {
            ForEach(Self.pickerOrder, id: \.self) { item in
                Text(Self.shortLabel(item))
                    .accessibilityLabel(Self.pickerItemLabel(item))
                    .tag(item)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 220)
        .accessibilityLabel("表示の切替")
    }

    /// The order of the segments (a computed property: a generic type cannot hold a stored static).
    static var pickerOrder: [PageKind] { [.day, .week, .month, .year] }

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
