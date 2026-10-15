import Layout
import SwiftUI
import UIKit

/// The fixed all-day band of the week / day page (M4B_CONTRACT §2.2, DESIGN §2.4 / §2.5): under the
/// sticky header, above the canvas, outside the paper, like the web version's .sh-allday and the
/// iOS Calendar app. It cannot be written on (a SwiftUI view: neither the Pencil nor a finger
/// reaches the paper through it, M4B-16).
///
/// Every number and colour class comes from `AllDayBandLayout` (担当 K) and `AllDayBandMetrics`:
/// the x positions follow the paper's horizontal offset and zoom through `viewport` (D2: the
/// 「終日」 gutter flows left with the paper), the lanes have point minimums (M4B-1), the height is
/// capped at 35 % of the page's visible height and the band scrolls inside past that. A bar opens
/// the editor (`onBarTap`), the empty part of a column creates an all-day event on that day
/// (`onColumnTap`, M4B-14); a tap on the gutter does nothing. Without all-day events the band is
/// an `EmptyView` (height 0, no line; M4B-2). The view never judges weekdays or holidays itself:
/// `band.tones` and `band.todayColumn` decide the column tints.
struct AllDayBandView: View {
    var band: AllDayBandLayout
    /// The paper's horizontal offset, zoom and container width (§1.1).
    var viewport: PaperViewport
    /// Height (pt) of the area holding the band and the canvas: the base of the 35 % cap.
    var pageHeight: CGFloat
    /// eventId → the edit sheet.
    var onBarTap: (String) -> Void
    /// A column's empty part → the create sheet for that day's all-day event.
    var onColumnTap: (DayKey) -> Void

    /// Corner radius of a bar (0 on a side that continues past the band's range).
    static let barCorner: CGFloat = 4
    /// Horizontal padding of a bar's text, and the right padding of 「終日」.
    static let textPad: CGFloat = 6

    private var metrics: AllDayBandMetrics.Metrics {
        AllDayBandMetrics.metrics(kind: band.kind, laneCount: band.laneCount, zoom: viewport.zoom, pageHeight: pageHeight)
    }

    /// The container width; never negative or non-finite (a `frame` must not get those).
    private var width: CGFloat {
        viewport.width.isFinite ? max(0, viewport.width) : 0
    }

    var body: some View {
        if band.laneCount > 0 {
            let metrics = self.metrics
            ScrollView(.vertical, showsIndicators: true) {
                content(metrics)
                    .frame(width: width, height: metrics.contentHeight, alignment: .topLeading)
            }
            .scrollDisabled(!metrics.scrollsInside)
            .frame(width: width, height: metrics.visibleHeight)
            .background(paperColor)
            .overlay(alignment: .bottom) {
                Rectangle().fill(lineStrongColor).frame(height: 1)
            }
            .clipped()
        }
    }

    // MARK: - Content

    /// The columns (tint + tap target), the 「終日」 gutter and the bars, all placed by paper x
    /// through `viewport` and by lane through `metrics`.
    private func content(_ metrics: AllDayBandMetrics.Metrics) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(band.days.indices, id: \.self) { index in
                column(index, metrics)
            }
            gutterLabel(metrics)
            ForEach(band.bars) { bar in
                barView(bar, metrics)
            }
        }
        .frame(width: width, height: metrics.contentHeight, alignment: .topLeading)
    }

    /// One day column: the today / weekend tint over the whole content height, tappable for 「その日の
    /// 終日予定を追加」.
    private func column(_ index: Int, _ metrics: AllDayBandMetrics.Metrics) -> some View {
        let day = band.days[index]
        let x = index < band.columnMinX.count ? viewport.x(ofPaper: band.columnMinX[index]) : 0
        let columnWidth = max(0, viewport.width(ofPaper: band.columnWidth))
        return Rectangle()
            .fill(columnTint(index) ?? Color.clear)
            .frame(width: columnWidth, height: metrics.contentHeight)
            .contentShape(Rectangle())
            .onTapGesture { onColumnTap(day) }
            .accessibilityLabel(Self.columnLabel(day))
            .accessibilityAddTraits(.isButton)
            .offset(x: x)
    }

    /// 「終日」 in the gutter `[paper 0, paper gutter]`, right-aligned, on the first lane. It moves
    /// with the paper (D2), so it leaves the screen when the paper is scrolled to the right.
    private func gutterLabel(_ metrics: AllDayBandMetrics.Metrics) -> some View {
        Text("終日")
            .font(.system(size: AllDayBandMetrics.labelPoints))
            .foregroundStyle(ink3)
            .lineLimit(1)
            .padding(.trailing, Self.textPad)
            .frame(width: max(0, viewport.width(ofPaper: band.gutter)), height: metrics.lane, alignment: .trailing)
            .clipped()
            .accessibilityHidden(true)
            .offset(x: viewport.x(ofPaper: 0), y: metrics.laneTop(0))
    }

    /// One bar: the event's colour, its title cut at the bar's edge (D4), round corners except on a
    /// side that continues past the band. A button: a Pencil tap works like a finger tap.
    private func barView(_ bar: AllDayBandBar, _ metrics: AllDayBandMetrics.Metrics) -> some View {
        let x = viewport.x(ofPaper: bar.minX)
        let barWidth = max(0, viewport.width(ofPaper: bar.maxX - bar.minX))
        let shape = Self.barShape(bar)
        let fill = Color(uiColor: PaperPalette.color(hex: bar.colorHex))
        let text = Color(uiColor: PaperPalette.readableText(on: bar.colorHex))
        return Button {
            onBarTap(bar.eventId)
        } label: {
            Text(bar.title)
                .font(.system(size: metrics.text, weight: .semibold))
                .foregroundStyle(text)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, Self.textPad)
                .frame(width: barWidth, height: metrics.lane, alignment: .leading)
                .background(shape.fill(fill))
                .clipShape(shape)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.barLabel(bar))
        .offset(x: x, y: metrics.laneTop(bar.lane))
    }

    // MARK: - Helpers

    /// The tint of column `index`: today wins (`todayTint` on the week page, `todayTintSoft` on the
    /// day page), then Saturday / Sunday / holiday (`weekendTint` / `weekendTintSoft`, the same as
    /// the paper's columns); nil for a plain weekday.
    private func columnTint(_ index: Int) -> Color? {
        let soft = band.kind == .day
        if band.todayColumn == index {
            return Color(uiColor: soft ? PaperPalette.todayTintSoft : PaperPalette.todayTint)
        }
        guard index < band.tones.count, band.tones[index] != .normal else { return nil }
        return Color(uiColor: soft ? PaperPalette.weekendTintSoft : PaperPalette.weekendTint)
    }

    /// Round corners of `barCorner`, squared off on the side the event continues past.
    static func barShape(_ bar: AllDayBandBar) -> UnevenRoundedRectangle {
        let left: CGFloat = bar.continuesLeft ? 0 : barCorner
        let right: CGFloat = bar.continuesRight ? 0 : barCorner
        return UnevenRoundedRectangle(
            topLeadingRadius: left,
            bottomLeadingRadius: left,
            bottomTrailingRadius: right,
            topTrailingRadius: right
        )
    }

    /// 「題名（予定を編集）」
    static func barLabel(_ bar: AllDayBandBar) -> String {
        bar.title + "（予定を編集）"
    }

    /// 「2026年10月7日(水) の終日予定を追加」
    static func columnLabel(_ day: DayKey) -> String {
        EventDateText.dayTitle(day) + " の終日予定を追加"
    }

    private var paperColor: Color { Color(uiColor: PaperPalette.paper) }
    private var ink3: Color { Color(uiColor: PaperPalette.ink3) }
    private var lineStrongColor: Color { Color(uiColor: PaperPalette.lineStrong) }
}
