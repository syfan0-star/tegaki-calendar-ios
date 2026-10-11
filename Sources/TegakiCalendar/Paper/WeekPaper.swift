import Layout
import UIKit

/// The week page's paper (contract §3.3): column tints, the all-day band with its bars, the hour
/// grid with the gutter labels, the timed event boxes and the now line. The weekday / date headers
/// live in the sticky header (`StickyHeaderView`), not on the paper.
enum WeekPaper: PaperRenderer {
    static func draw(_ content: WeekPaperContent, in ctx: CGContext, dirty: CGRect, zoom: CGFloat, view: PaperView) {
        let layout = content.layout
        let scale = view.contentScaleFactor
        let gutter = PaperSpec.weekGutter
        let width = PaperSpec.weekWidth
        let height = layout.size.height

        // 1. Column tints (today over weekend / holiday), band and grid alike.
        for (column, label) in layout.dateLabels.enumerated() {
            let tint: UIColor?
            if layout.todayColumn == column {
                tint = PaperPalette.todayTint
            } else if label.tone != .normal {
                tint = PaperPalette.weekendTint
            } else {
                tint = nil
            }
            guard let tint = tint else { continue }
            let frame = layout.columnFrame(column)
            let rect = CGRect(x: frame.minX, y: 0, width: frame.width, height: height)
            guard rect.intersects(dirty) else { continue }
            ctx.setFillColor(tint.cgColor)
            ctx.fill(rect)
        }

        // 2. All-day band: the bottom line, the 「終日」 label, the bars.
        let band = layout.band
        ctx.setLineWidth(PaperText.hairline(zoom))
        ctx.setStrokeColor(PaperPalette.lineStrong.cgColor)
        ctx.beginPath()
        PaperText.addHorizontal(ctx, y: band.maxY, from: 0, to: width, zoom: zoom, scale: scale)
        // The gutter's right line runs the whole height (band included).
        PaperText.addVertical(ctx, x: gutter, from: 0, to: height, zoom: zoom, scale: scale)
        ctx.strokePath()
        TimeGridPaper.drawBandLabel(ctx, rightX: gutter - 8, top: band.minY, dirty: dirty, zoom: zoom)
        TimeGridPaper.drawAllDayBars(ctx, bars: layout.allDayBars, textSize: PaperText.weekEvent,
                                     fontScale: layout.laneMetrics.fontScale, dirty: dirty, zoom: zoom)

        // 3. Hour grid, column lines and time labels.
        let grid = layout.grid
        TimeGridPaper.drawHourGrid(ctx, gridTop: grid.minY, hourHeight: PaperSpec.weekHourHeight, x0: gutter, x1: width,
                                   labelX: gutter - 8, labelSize: PaperText.weekTimeLabel, dirty: dirty, zoom: zoom, scale: scale)
        ctx.setLineWidth(PaperText.hairline(zoom))
        ctx.setStrokeColor(PaperPalette.line.cgColor)
        ctx.beginPath()
        for column in 1..<PaperSpec.weekColumns {
            let x = gutter + CGFloat(column) * PaperSpec.weekColumnWidth
            PaperText.addVertical(ctx, x: x, from: grid.minY, to: grid.maxY, zoom: zoom, scale: scale)
        }
        ctx.strokePath()

        // 4. Timed boxes.
        TimeGridPaper.drawBoxes(ctx, boxes: layout.timedBoxes, textSize: PaperText.weekEvent, dirty: dirty, zoom: zoom)

        // 5. The now line, above the boxes.
        if let line = layout.nowLine, line.y >= dirty.minY - 8, line.y <= dirty.maxY + 8 {
            TimeGridPaper.drawNowLine(ctx, line: line, dotRadius: max(5, 4 / zoom), zoom: zoom)
        }
    }
}
