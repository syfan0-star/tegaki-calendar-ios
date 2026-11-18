import Layout
import UIKit

/// The free memo area below 24:00, one function for the day page (since 1.1, M7A_CONTRACT §3.3, M7A-10) and,
/// since 1.3, the week page's memo (docs/M7C_CONTRACT.md §5.2: "the same function as the day's free memo";
/// docs/PLAN_MEMO_PAPER.md §5.1–§5.2, the shared part): a `lineStrong` line at its top across the whole area
/// (like the month's line above its memo area), ruled lines every `dayRuleStep` lu over x `dayRuleInset`…width
/// − `dayRuleInset` down to its bottom, and the label 「自由メモ」 at (`dayRuleInset`, top + 6) in the look of the
/// day's right column 「メモ」. Only what meets `dirty`. The body is 1.2.3's `DayPaper.drawExtra`, moved here
/// with the same calls in the same order, so the day's pixels are 1.2.3's (WeekMemoPaperSpanTests holds them
/// against a copy of 43fe366's `DayPaper`). On joined pages each page draws its own area: the strong line
/// meets its neighbour's, the ruled lines leave 2 × `dayRuleInset` at a boundary and each page has its label
/// (the lead's decision 5 of wave 1, decision 21 of the week memo's plan, docs/M7C.md).
enum FreeMemoPaper {
    /// The heading of the free memo area (M7A_CONTRACT §6.2).
    static let label = L.text("paper.freeMemo")

    /// The free memo area `area` (paper units of the page; the whole width of the page, from 24:00 down) at
    /// `zoom`, the hairlines snapped for `scale`, the label sized for the page's readable zoom `readable`.
    /// Nothing for an empty area.
    static func draw(_ ctx: CGContext, area: CGRect, dirty: CGRect, zoom: CGFloat, scale: CGFloat, readable: CGFloat) {
        guard area.height > 0, area.width > 0 else { return }

        ctx.setLineWidth(PaperText.hairline(zoom))
        if area.minY >= dirty.minY - 1, area.minY <= dirty.maxY + 1 {
            ctx.setStrokeColor(PaperPalette.lineStrong.cgColor)
            ctx.beginPath()
            PaperText.addHorizontal(ctx, y: area.minY, from: area.minX, to: area.maxX, zoom: zoom, scale: scale)
            ctx.strokePath()
        }

        ruledLines(ctx, area: area, dirty: dirty, zoom: zoom, scale: scale)

        let labelSize = PaperText.fontSize(PaperText.memoLabel, zoom: zoom, readable: readable)
        let labelFont = UIFont.systemFont(ofSize: labelSize, weight: .semibold)
        let labelRect = CGRect(x: area.minX + PaperSpec.dayRuleInset, y: area.minY + 6, width: 200, height: labelFont.lineHeight + 2)
        if labelRect.intersects(dirty) {
            PaperText.drawLine(label, in: labelRect, font: labelFont, color: PaperPalette.memoLabel, kern: labelSize * 0.15)
        }
    }

    /// The ruling of the area (1.3: lines every `dayRuleStep` lu, inset `dayRuleInset` on both sides, in the
    /// line width `draw` set): the one place a later paper of the memo area changes its pattern
    /// (docs/PLAN_MEMO_PAPER.md §5.2).
    private static func ruledLines(_ ctx: CGContext, area: CGRect, dirty: CGRect, zoom: CGFloat, scale: CGFloat) {
        ctx.setStrokeColor(PaperPalette.rule.cgColor)
        ctx.beginPath()
        var y = area.minY + PaperSpec.dayRuleStep
        while y < area.maxY {
            if y >= dirty.minY - 1, y <= dirty.maxY + 1 {
                PaperText.addHorizontal(ctx, y: y, from: area.minX + PaperSpec.dayRuleInset, to: area.maxX - PaperSpec.dayRuleInset,
                                        zoom: zoom, scale: scale)
            }
            y += PaperSpec.dayRuleStep
        }
        ctx.strokePath()
    }
}
