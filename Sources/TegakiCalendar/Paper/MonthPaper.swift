import Layout
import UIKit

/// The month page's paper (M2's `PaperView.draw`, moved here unchanged in appearance): grid lines,
/// date numbers (today / Saturday / Sunday-holiday / outside the month), holiday names, all-day bars,
/// timed chips and the memo area below the grid.
enum MonthPaper: PaperRenderer {
    private static let ruleStep: CGFloat = 50
    private static let ruleInset: CGFloat = 20

    static func draw(_ content: MonthPaperContent, in ctx: CGContext, dirty: CGRect, zoom: CGFloat, view: PaperView) {
        let scale = view.contentScaleFactor
        drawTints(ctx, content: content, dirty: dirty)
        drawGridLines(ctx, layout: content.layout, zoom: zoom, scale: scale)
        drawMemoArea(ctx, layout: content.layout, dirty: dirty, zoom: zoom, scale: scale)
        drawDateLabels(ctx, content: content, dirty: dirty, zoom: zoom)
        drawAllDayBars(ctx, content: content, dirty: dirty, zoom: zoom)
        drawTimedChips(ctx, content: content, dirty: dirty, zoom: zoom)
    }

    private static func drawTints(_ ctx: CGContext, content: MonthPaperContent, dirty: CGRect) {
        let layout = content.layout
        for label in content.labels {
            guard let cell = layout.cells[CellKey.day(label.day)], cell.intersects(dirty) else { continue }
            let tint: UIColor?
            if label.isToday {
                tint = PaperPalette.todayTint
            } else if !label.inMonth {
                tint = PaperPalette.outTint
            } else if label.tone != .normal {
                tint = PaperPalette.weekendTint
            } else {
                tint = nil
            }
            if let tint = tint {
                ctx.setFillColor(tint.cgColor)
                ctx.fill(cell)
            }
        }
    }

    private static func drawGridLines(_ ctx: CGContext, layout: MonthPageLayout, zoom: CGFloat, scale: CGFloat) {
        let width = PaperSpec.monthWidth
        let gridBottom = layout.memo.minY
        ctx.setLineWidth(PaperText.hairline(zoom))
        ctx.setStrokeColor(PaperPalette.line.cgColor)
        ctx.beginPath()
        for column in 1..<PaperSpec.monthColumns {
            PaperText.addVertical(ctx, x: CGFloat(column) * PaperSpec.monthColumnWidth, from: 0, to: gridBottom, zoom: zoom, scale: scale)
        }
        for row in layout.rows where row.index > 0 {
            PaperText.addHorizontal(ctx, y: row.frame.minY, from: 0, to: width, zoom: zoom, scale: scale)
        }
        ctx.strokePath()
    }

    private static func drawMemoArea(_ ctx: CGContext, layout: MonthPageLayout, dirty: CGRect, zoom: CGFloat, scale: CGFloat) {
        let memo = layout.memo
        guard memo.height > 0 else { return }
        let width = PaperSpec.monthWidth

        // Separator between the grid and the memo area (a little stronger than the grid lines).
        ctx.setLineWidth(PaperText.hairline(zoom))
        ctx.setStrokeColor(PaperPalette.lineStrong.cgColor)
        ctx.beginPath()
        PaperText.addHorizontal(ctx, y: memo.minY, from: 0, to: width, zoom: zoom, scale: scale)
        ctx.strokePath()

        // Faint ruled lines every 50 lu, inset 20 lu on both sides.
        ctx.setStrokeColor(PaperPalette.rule.cgColor)
        ctx.beginPath()
        var y = memo.minY + ruleStep
        while y < memo.maxY {
            if y >= dirty.minY - 1, y <= dirty.maxY + 1 {
                PaperText.addHorizontal(ctx, y: y, from: ruleInset, to: width - ruleInset, zoom: zoom, scale: scale)
            }
            y += ruleStep
        }
        ctx.strokePath()

        // Small 「メモ」 label at the top-left, as on the web version.
        let labelSize = PaperText.fontSize(PaperText.memoLabel, zoom: zoom)
        let labelFont = UIFont.systemFont(ofSize: labelSize, weight: .semibold)
        let labelRect = CGRect(x: ruleInset, y: memo.minY + 6, width: 200, height: labelFont.lineHeight + 2)
        if labelRect.intersects(dirty) {
            PaperText.drawLine("メモ", in: labelRect, font: labelFont, color: PaperPalette.memoLabel, kern: labelSize * 0.15)
        }
    }

    private static func drawDateLabels(_ ctx: CGContext, content: MonthPaperContent, dirty: CGRect, zoom: CGFloat) {
        let dateSize = PaperText.fontSize(PaperText.monthDate, zoom: zoom)
        let dateFont = UIFont.monospacedDigitSystemFont(ofSize: dateSize, weight: .semibold)
        let holidaySize = PaperText.fontSize(PaperText.monthHoliday, zoom: zoom)
        let holidayFont = UIFont.systemFont(ofSize: holidaySize, weight: .regular)

        for label in content.labels {
            let frame = label.frame
            guard frame.intersects(dirty) else { continue }
            let alpha: CGFloat = label.inMonth ? 1 : 0.4
            let number = "\(label.day.day)"
            let numberWidth = PaperText.width(of: number, font: dateFont)

            // The number sits in a circle-sized box at the left of the header; today fills the circle.
            let box = frame.height
            let boxWidth = max(box, numberWidth + box * 0.4)
            let numberBox = CGRect(x: frame.minX, y: frame.minY, width: boxWidth, height: box)

            let numberColor: UIColor
            if label.isToday {
                ctx.setFillColor(PaperPalette.accent.withAlphaComponent(alpha).cgColor)
                ctx.addPath(UIBezierPath(roundedRect: numberBox, cornerRadius: box / 2).cgPath)
                ctx.fillPath()
                numberColor = .white
            } else {
                numberColor = PaperPalette.toneColor(label.tone)
            }
            PaperText.drawLine(number, in: numberBox, font: dateFont, color: numberColor.withAlphaComponent(alpha),
                               alignment: .center)

            // Holiday name next to the number, truncated to the rest of the header.
            let holidayName = label.holidayName ?? content.holidayNames[label.day]
            if let name = holidayName, !name.isEmpty {
                let gap: CGFloat = 4
                let nameRect = CGRect(x: numberBox.maxX + gap, y: frame.minY,
                                      width: max(0, frame.maxX - numberBox.maxX - gap - 2), height: frame.height)
                if nameRect.width > holidaySize {
                    PaperText.drawLine(name, in: nameRect, font: holidayFont, color: PaperPalette.red.withAlphaComponent(alpha))
                }
            }
        }
    }

    private static func drawAllDayBars(_ ctx: CGContext, content: MonthPaperContent, dirty: CGRect, zoom: CGFloat) {
        let size = PaperText.fontSize(PaperText.monthChip, zoom: zoom)
        let font = UIFont.systemFont(ofSize: size, weight: .semibold)
        let radius: CGFloat = 4
        let inMonth = Set(content.labels.filter { $0.inMonth }.map { $0.day })

        for bar in content.bars {
            let frame = bar.frame
            guard frame.intersects(dirty), frame.width > 0, frame.height > 0 else { continue }
            let alpha: CGFloat = barIsOutsideMonth(bar, layout: content.layout, inMonth: inMonth) ? 0.55 : 1
            let fill = PaperPalette.color(hex: bar.colorHex)

            ctx.setFillColor(fill.withAlphaComponent(alpha).cgColor)
            ctx.addPath(PaperText.roundedPath(frame, radius: radius, squareLeft: bar.continuesLeft, squareRight: bar.continuesRight))
            ctx.fillPath()

            let pad = size * 0.4
            let textRect = frame.insetBy(dx: pad, dy: 0)
            if textRect.width > size {
                let text = PaperPalette.readableText(on: bar.colorHex).withAlphaComponent(alpha)
                PaperText.drawLine(bar.title, in: textRect, font: font, color: text)
            }
        }
    }

    private static func drawTimedChips(_ ctx: CGContext, content: MonthPaperContent, dirty: CGRect, zoom: CGFloat) {
        let size = PaperText.fontSize(PaperText.monthChip, zoom: zoom)
        let titleFont = UIFont.systemFont(ofSize: size, weight: .medium)
        let timeFont = UIFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
        let moreFont = UIFont.systemFont(ofSize: size, weight: .semibold)
        let inMonth = Set(content.labels.filter { $0.inMonth }.map { $0.day })

        for chip in content.chips {
            let frame = chip.frame
            guard frame.intersects(dirty), frame.width > 0, frame.height > 0 else { continue }
            let alpha: CGFloat = inMonth.contains(chip.day) ? 1 : 0.55
            let pad = size * 0.35
            var x = frame.minX + pad

            if chip.moreCount > 0 {
                let text = chip.title.isEmpty ? "+\(chip.moreCount)件" : chip.title
                let rect = CGRect(x: x, y: frame.minY, width: max(0, frame.maxX - pad - x), height: frame.height)
                PaperText.drawLine(text, in: rect, font: moreFont, color: PaperPalette.ink2.withAlphaComponent(alpha))
                continue
            }

            // Colour dot
            let dot = size * 0.55
            let dotRect = CGRect(x: x, y: frame.midY - dot / 2, width: dot, height: dot)
            ctx.setFillColor(PaperPalette.color(hex: chip.colorHex).withAlphaComponent(alpha).cgColor)
            ctx.fillEllipse(in: dotRect)
            x = dotRect.maxX + size * 0.3

            // "9:00"
            if !chip.timeText.isEmpty {
                let timeWidth = PaperText.width(of: chip.timeText, font: timeFont)
                let timeRect = CGRect(x: x, y: frame.minY, width: min(timeWidth, max(0, frame.maxX - pad - x)),
                                      height: frame.height)
                PaperText.drawLine(chip.timeText, in: timeRect, font: timeFont, color: PaperPalette.ink2.withAlphaComponent(alpha))
                x = timeRect.maxX + size * 0.3
            }

            // Title, truncated with an ellipsis.
            let titleRect = CGRect(x: x, y: frame.minY, width: max(0, frame.maxX - pad - x), height: frame.height)
            if titleRect.width > size {
                PaperText.drawLine(chip.title, in: titleRect, font: titleFont, color: PaperPalette.ink1.withAlphaComponent(alpha))
            }
        }
    }

    /// True when every day the bar covers lies outside the month (the bar is then faded like its cells).
    private static func barIsOutsideMonth(_ bar: AllDayBar, layout: MonthPageLayout, inMonth: Set<DayKey>) -> Bool {
        guard bar.row >= 0, bar.row < layout.rows.count else { return false }
        let days = layout.rows[bar.row].days
        let columnWidth = PaperSpec.monthColumnWidth
        let first = max(0, min(days.count - 1, Int(floor(bar.frame.minX / columnWidth))))
        let last = max(0, min(days.count - 1, Int(floor((bar.frame.maxX - 1) / columnWidth))))
        guard first <= last else { return false }
        for column in first...last where inMonth.contains(days[column]) {
            return false
        }
        return true
    }
}
