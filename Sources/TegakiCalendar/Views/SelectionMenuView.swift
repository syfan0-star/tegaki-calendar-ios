import SwiftUI

/// The floating menu of a lasso selection (M3b contract §4.2, the web version's selection-menu.js):
/// 「予定にする」 (primary), 「削除」, 「選択解除」 side by side in a 44 pt capsule. `CalendarRootScreen`
/// places it over the canvas with `placement(anchor:size:bounds:)`.
struct SelectionMenuView: View {
    var onConvert: () -> Void
    var onDelete: () -> Void
    var onDeselect: () -> Void

    /// Space between the selection frame and the menu (pt).
    static let gap: CGFloat = 10
    /// Space kept free at the edges of the canvas (pt).
    static let margin: CGFloat = 8

    var body: some View {
        HStack(spacing: 0) {
            item("予定にする", symbol: "calendar.badge.plus", primary: true, action: onConvert)
            divider
            item("削除", symbol: "trash", primary: false, action: onDelete)
            divider
            item("選択解除", symbol: "xmark", primary: false, action: onDeselect)
        }
        .frame(height: 44)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("選択した手書き")
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 24)
    }

    private func item(_ label: String, symbol: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                Text(label)
                    .font(.system(size: 14, weight: primary ? .semibold : .regular))
            }
            .foregroundStyle(primary ? Color.accentColor : Color.primary)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Where a menu of `size` goes next to `anchor` inside `bounds` (all in the canvas's points; the
    /// web version's placeMenu): `gap` above the anchor when that fits, else `gap` below it, else just
    /// under the anchor's top edge; horizontally centred on the anchor and clamped into `bounds`.
    /// Returns the menu's top-left corner.
    static func placement(anchor: CGRect, size: CGSize, bounds: CGRect, gap: CGFloat = gap) -> CGPoint {
        let a = anchor.standardized
        let b = bounds.standardized
        let w = max(0, size.width)
        let h = max(0, size.height)
        func clampX(_ x: CGFloat) -> CGFloat { min(max(x, b.minX), max(b.minX, b.maxX - w)) }
        func clampY(_ y: CGFloat) -> CGFloat { min(max(y, b.minY), max(b.minY, b.maxY - h)) }
        let x = clampX(a.midX - w / 2)
        let aboveTop = a.minY - gap - h
        if aboveTop >= b.minY, a.minY <= b.maxY {
            return CGPoint(x: x, y: aboveTop)
        }
        let belowTop = a.maxY + gap
        if belowTop + h <= b.maxY, a.maxY >= b.minY {
            return CGPoint(x: x, y: belowTop)
        }
        return CGPoint(x: x, y: clampY(max(a.minY, b.minY) + gap))
    }
}
