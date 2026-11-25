import Layout
import UIKit

/// The week page's paper (contract §3.3, M4B_CONTRACT §2.5): column tints, the hour grid with the
/// gutter labels, the timed event boxes and the now line. The weekday / date headers and, since
/// M4b, the all-day band live in the fixed views above the paper (`StickyHeaderView`,
/// `AllDayBandView`), not on the paper: the paper starts at 0:00. 1.3 (docs/M7C_CONTRACT.md §5.2): a week laid
/// out with its memo (`WeekLayoutInput.freeMemo`) goes on below 24:00 with the free memo 「自由メモ」 (`extra`,
/// the whole width), drawn by the day's function (`FreeMemoPaper`): the column tints and the time column's
/// line stop at 24:00, a strong line marks 24:00, ruled lines every 50 lu run to the bottom of the paper. A week without the
/// memo is 1.2.3's paper, pixel for pixel. 1.3 drew only ruled lines (the owner's choice Q2 A); since 1.4.2
/// (docs/R1_4_2_CONTRACT.md §4.4) the memo follows 設定 › 「メモ欄の紙」 (`view.memoPaper`; ruled lines by default), as every
/// memo area does.
enum WeekPaper: PaperRenderer {
    static func draw(_ content: WeekPaperContent, in ctx: CGContext, dirty: CGRect, zoom: CGFloat, view: PaperView) {
        let layout = content.layout
        let scale = view.contentScaleFactor
        // 1.4.2 (docs/R1_4_2_CONTRACT.md §4.3): the memo paper's pattern, read once here and passed to the memo.
        let style = view.memoPaper
        let gutter = PaperSpec.weekGutter
        let width = PaperSpec.weekWidth
        // 1.3: the 24 hours (0:00–24:00), not the whole paper (the same for a week without the memo).
        let height = layout.grid.maxY

        // 1. Column tints (today over weekend / holiday), 0:00–24:00.
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

        // 2. The gutter's right line runs 0:00–24:00.
        ctx.setLineWidth(PaperText.hairline(zoom))
        ctx.setStrokeColor(PaperPalette.lineStrong.cgColor)
        ctx.beginPath()
        PaperText.addVertical(ctx, x: gutter, from: 0, to: height, zoom: zoom, scale: scale)
        ctx.strokePath()

        // 3. Hour grid, column lines and time labels.
        let grid = layout.grid
        let readable = ZoomPolicy.readableZoom(.week)
        TimeGridPaper.drawHourGrid(ctx, gridTop: grid.minY, hourHeight: PaperSpec.weekHourHeight, x0: gutter, x1: width,
                                   labelX: gutter - 8, labelSize: PaperText.weekTimeLabel, dirty: dirty, zoom: zoom, scale: scale,
                                   readable: readable)
        ctx.setLineWidth(PaperText.hairline(zoom))
        ctx.setStrokeColor(PaperPalette.line.cgColor)
        ctx.beginPath()
        for column in 1..<PaperSpec.weekColumns {
            let x = gutter + CGFloat(column) * PaperSpec.weekColumnWidth
            PaperText.addVertical(ctx, x: x, from: grid.minY, to: grid.maxY, zoom: zoom, scale: scale)
        }
        ctx.strokePath()

        // 1.3: the week memo below 24:00 (`extra`), the day's free memo.
        if layout.cells[.extra] != nil {
            // MUTATION MM5: the week's memo is always ruled (r142-q-m1 only, never merged).
            FreeMemoPaper.draw(ctx, area: layout.extra, dirty: dirty, zoom: zoom, scale: scale, readable: readable, style: .ruled)
        }

        // 4. Timed boxes.
        TimeGridPaper.drawBoxes(ctx, boxes: layout.timedBoxes, textSize: PaperText.weekEvent, dirty: dirty, zoom: zoom, readable: readable)

        // 5. The now line, above the boxes.
        if let line = layout.nowLine, line.y >= dirty.minY - 8, line.y <= dirty.maxY + 8 {
            TimeGridPaper.drawNowLine(ctx, line: line, dotRadius: max(5, 4 / zoom), zoom: zoom)
        }
    }
}
