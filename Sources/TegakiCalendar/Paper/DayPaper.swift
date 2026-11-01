import Layout
import UIKit

/// The day page's paper (contract §3.4, M4B_CONTRACT §2.5): the timeline column (tinted on today /
/// weekends), the hour grid, the memo area on the right with its ruled lines, the timed event boxes
/// and the now line. The date header and, since M4b, the all-day band are the fixed views above
/// the paper (`StickyHeaderView`, `AllDayBandView`): the paper starts at 0:00. Since 1.1
/// (M7A_CONTRACT §3.3) the paper goes on below 24:00 with the free memo area 「自由メモ」 (`extra`, the
/// whole width): the timeline's tint and its vertical lines stop at 24:00, a strong line marks
/// 24:00, ruled lines every 50 lu run to the bottom of the paper, as in the month's memo area.
enum DayPaper: PaperRenderer {
    static func draw(_ content: DayPaperContent, in ctx: CGContext, dirty: CGRect, zoom: CGFloat, view: PaperView) {
        let layout = content.layout
        let scale = view.contentScaleFactor
        let gutter = PaperSpec.dayGutter
        let timelineRight = PaperSpec.dayTimelineRight
        // 1.1: the 24 hours (0:00–24:00), not the whole paper.
        let height = layout.grid.maxY

        // 1. Timeline column tint (today over weekend / holiday), 0:00–24:00.
        let tint: UIColor?
        if layout.isToday {
            tint = PaperPalette.todayTintSoft
        } else if layout.dateLabels.first?.tone != .normal {
            tint = PaperPalette.weekendTintSoft
        } else {
            tint = nil
        }
        if let tint = tint {
            let rect = CGRect(x: gutter, y: 0, width: timelineRight - gutter, height: height)
            if rect.intersects(dirty) {
                ctx.setFillColor(tint.cgColor)
                ctx.fill(rect)
            }
        }

        // 2. The gutter's and the timeline's right lines run 0:00–24:00.
        ctx.setLineWidth(PaperText.hairline(zoom))
        ctx.setStrokeColor(PaperPalette.lineStrong.cgColor)
        ctx.beginPath()
        PaperText.addVertical(ctx, x: gutter, from: 0, to: height, zoom: zoom, scale: scale)
        PaperText.addVertical(ctx, x: timelineRight, from: 0, to: height, zoom: zoom, scale: scale)
        ctx.strokePath()

        // 3. Hour grid in the timeline column, labels right-aligned at x = 64.
        let grid = layout.grid
        let readable = ZoomPolicy.readableZoom(.day)
        TimeGridPaper.drawHourGrid(ctx, gridTop: grid.minY, hourHeight: PaperSpec.dayHourHeight, x0: gutter, x1: timelineRight,
                                   labelX: gutter - 8, labelSize: PaperText.dayTimeLabel, dirty: dirty, zoom: zoom, scale: scale,
                                   readable: readable)

        // 4. Memo area: ruled lines every 50 lu and the 「メモ」 label (same look as the month's memo area).
        let memo = layout.memo
        ctx.setLineWidth(PaperText.hairline(zoom))
        ctx.setStrokeColor(PaperPalette.rule.cgColor)
        ctx.beginPath()
        var y = grid.minY + PaperSpec.dayRuleStep
        while y < grid.maxY {
            if y >= dirty.minY - 1, y <= dirty.maxY + 1 {
                PaperText.addHorizontal(ctx, y: y, from: memo.minX + PaperSpec.dayRuleInset, to: memo.maxX - PaperSpec.dayRuleInset,
                                        zoom: zoom, scale: scale)
            }
            y += PaperSpec.dayRuleStep
        }
        ctx.strokePath()
        let labelSize = PaperText.fontSize(PaperText.memoLabel, zoom: zoom, readable: readable)
        let labelFont = UIFont.systemFont(ofSize: labelSize, weight: .semibold)
        let labelRect = CGRect(x: memo.minX + PaperSpec.dayRuleInset, y: grid.minY + 6, width: 200, height: labelFont.lineHeight + 2)
        if labelRect.intersects(dirty) {
            PaperText.drawLine("メモ", in: labelRect, font: labelFont, color: PaperPalette.memoLabel, kern: labelSize * 0.15)
        }

        // 5. 1.1: the free memo area below 24:00 (`extra`).
        drawExtra(ctx, layout: layout, dirty: dirty, zoom: zoom, scale: scale, readable: readable)

        // 6. Timed boxes, then the now line across the timeline column.
        TimeGridPaper.drawBoxes(ctx, boxes: layout.timedBoxes, textSize: PaperText.dayEvent, dirty: dirty, zoom: zoom, readable: readable)
        if let line = layout.nowLine, line.y >= dirty.minY - 8, line.y <= dirty.maxY + 8 {
            TimeGridPaper.drawNowLine(ctx, line: line, dotRadius: max(6, 4 / zoom), zoom: zoom)
        }
    }

    /// 1.1 (M7A_CONTRACT §3.3, M7A-10): the free memo area below 24:00 — a `lineStrong` line at its
    /// top (0…1000, like the month's line above its memo area), ruled lines every `dayRuleStep` lu
    /// over x `dayRuleInset`…1000 − `dayRuleInset` down to its bottom, and the label 「自由メモ」 at
    /// (`dayRuleInset`, top + 6) in the look of the right column's 「メモ」 (a different name, so the
    /// page does not show two 「メモ」). Only what meets `dirty`; nothing for a layout without it.
    private static func drawExtra(_ ctx: CGContext, layout: DayPageLayout, dirty: CGRect, zoom: CGFloat, scale: CGFloat, readable: CGFloat) {
        let extra = layout.extra
        guard layout.cells[.extra] != nil, extra.height > 0, extra.width > 0 else { return }

        ctx.setLineWidth(PaperText.hairline(zoom))
        if extra.minY >= dirty.minY - 1, extra.minY <= dirty.maxY + 1 {
            ctx.setStrokeColor(PaperPalette.lineStrong.cgColor)
            ctx.beginPath()
            PaperText.addHorizontal(ctx, y: extra.minY, from: extra.minX, to: extra.maxX, zoom: zoom, scale: scale)
            ctx.strokePath()
        }

        ctx.setStrokeColor(PaperPalette.rule.cgColor)
        ctx.beginPath()
        var y = extra.minY + PaperSpec.dayRuleStep
        while y < extra.maxY {
            if y >= dirty.minY - 1, y <= dirty.maxY + 1 {
                PaperText.addHorizontal(ctx, y: y, from: extra.minX + PaperSpec.dayRuleInset, to: extra.maxX - PaperSpec.dayRuleInset,
                                        zoom: zoom, scale: scale)
            }
            y += PaperSpec.dayRuleStep
        }
        ctx.strokePath()

        let labelSize = PaperText.fontSize(PaperText.memoLabel, zoom: zoom, readable: readable)
        let labelFont = UIFont.systemFont(ofSize: labelSize, weight: .semibold)
        let labelRect = CGRect(x: extra.minX + PaperSpec.dayRuleInset, y: extra.minY + 6, width: 200, height: labelFont.lineHeight + 2)
        if labelRect.intersects(dirty) {
            PaperText.drawLine(freeMemoLabel, in: labelRect, font: labelFont, color: PaperPalette.memoLabel, kern: labelSize * 0.15)
        }
    }

    /// The heading of the free memo area below 24:00 (M7A_CONTRACT §6.2).
    static let freeMemoLabel = "自由メモ"
}
