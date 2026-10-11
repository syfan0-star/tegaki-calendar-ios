import Layout
import UIKit

/// The day page's paper (contract §3.4): the timeline column (tinted on today / weekends), the
/// all-day band with its chips, the hour grid, the memo area on the right with its ruled lines, the
/// timed event boxes and the now line. The date header is the sticky header's.
enum DayPaper: PaperRenderer {
    static func draw(_ content: DayPaperContent, in ctx: CGContext, dirty: CGRect, zoom: CGFloat, view: PaperView) {
        let layout = content.layout
        let scale = view.contentScaleFactor
        let gutter = PaperSpec.dayGutter
        let timelineRight = PaperSpec.dayTimelineRight
        let width = PaperSpec.dayWidth
        let height = layout.size.height

        // 1. Timeline column tint (today over weekend / holiday), the whole height.
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

        // 2. All-day band: bottom line, 「終日」, chips (in the timeline column only).
        let band = layout.band
        ctx.setLineWidth(PaperText.hairline(zoom))
        ctx.setStrokeColor(PaperPalette.lineStrong.cgColor)
        ctx.beginPath()
        PaperText.addHorizontal(ctx, y: band.maxY, from: 0, to: width, zoom: zoom, scale: scale)
        PaperText.addVertical(ctx, x: gutter, from: 0, to: height, zoom: zoom, scale: scale)
        PaperText.addVertical(ctx, x: timelineRight, from: 0, to: height, zoom: zoom, scale: scale)
        ctx.strokePath()
        TimeGridPaper.drawBandLabel(ctx, rightX: gutter - 6, top: band.minY, dirty: dirty, zoom: zoom)
        TimeGridPaper.drawAllDayBars(ctx, bars: layout.allDayBars, textSize: PaperText.dayEvent,
                                     fontScale: layout.laneMetrics.fontScale, dirty: dirty, zoom: zoom)

        // 3. Hour grid in the timeline column, labels right-aligned at x = 64.
        let grid = layout.grid
        TimeGridPaper.drawHourGrid(ctx, gridTop: grid.minY, hourHeight: PaperSpec.dayHourHeight, x0: gutter, x1: timelineRight,
                                   labelX: gutter - 8, labelSize: PaperText.dayTimeLabel, dirty: dirty, zoom: zoom, scale: scale)

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
        let labelSize = PaperText.fontSize(PaperText.memoLabel, zoom: zoom)
        let labelFont = UIFont.systemFont(ofSize: labelSize, weight: .semibold)
        let labelRect = CGRect(x: memo.minX + PaperSpec.dayRuleInset, y: grid.minY + 6, width: 200, height: labelFont.lineHeight + 2)
        if labelRect.intersects(dirty) {
            PaperText.drawLine("メモ", in: labelRect, font: labelFont, color: PaperPalette.memoLabel, kern: labelSize * 0.15)
        }

        // 5. Timed boxes, then the now line across the timeline column.
        TimeGridPaper.drawBoxes(ctx, boxes: layout.timedBoxes, textSize: PaperText.dayEvent, dirty: dirty, zoom: zoom)
        if let line = layout.nowLine, line.y >= dirty.minY - 8, line.y <= dirty.maxY + 8 {
            TimeGridPaper.drawNowLine(ctx, line: line, dotRadius: max(6, 4 / zoom), zoom: zoom)
        }
    }
}
