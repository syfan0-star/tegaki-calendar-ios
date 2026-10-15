import Layout
import UIKit

/// The year page's paper (contract §3.5): the 12 × 31 cells with their tints (Saturday, Sunday /
/// holiday, today), hatching on dates that do not exist, the day numbers 1…31 down the gutter, the
/// day number and weekday letter and the holiday name of every day, and the all-day chips in the
/// right part of each cell. The month names are the sticky header's. Since M4b the page scrolls
/// horizontally on every device and starts at this month's column, so the gutter's 1…31 is often
/// off screen: every cell's heading carries its day number before the weekday letter (「7 水」,
/// M4B_CONTRACT §4.2, D2), and the text of a chip is clipped to its shape (D4).
enum YearPaper: PaperRenderer {
    private static let weekdayNames = ["日", "月", "火", "水", "木", "金", "土"]

    static func draw(_ content: YearPaperContent, in ctx: CGContext, dirty: CGRect, zoom: CGFloat, view: PaperView) {
        let layout = content.layout
        let scale = view.contentScaleFactor
        let gutter = PaperSpec.yearGutter
        let width = PaperSpec.yearWidth
        let height = layout.size.height
        let pad = PaperSpec.yearPad

        // 1. Cell tints and the hatched cells.
        var todayFrame: CGRect?
        for label in layout.dateLabels {
            guard let cell = layout.cells[.yearDay(month: label.day.month, day: label.day.day)], cell.intersects(dirty) else { continue }
            let tint: UIColor?
            if label.isToday {
                tint = PaperPalette.todayTintStrong
                todayFrame = cell
            } else if label.tone == .sundayOrHoliday {
                tint = PaperPalette.sunTint
            } else if label.tone == .saturday {
                tint = PaperPalette.satTint
            } else {
                tint = nil
            }
            if let tint = tint {
                ctx.setFillColor(tint.cgColor)
                ctx.fill(cell)
            }
        }
        for key in layout.invalidCells {
            guard let cell = layout.cells[key], cell.intersects(dirty) else { continue }
            drawHatch(ctx, in: cell)
        }

        // 2. Lines: between the days (line), between the months and right of the gutter (lineStrong).
        ctx.setLineWidth(PaperText.hairline(zoom))
        ctx.setStrokeColor(PaperPalette.line.cgColor)
        ctx.beginPath()
        for row in layout.rows where row.dayNumber > 1 {
            let y = row.frame.minY
            guard y >= dirty.minY - 1, y <= dirty.maxY + 1 else { continue }
            PaperText.addHorizontal(ctx, y: y, from: 0, to: width, zoom: zoom, scale: scale)
        }
        ctx.strokePath()
        ctx.setStrokeColor(PaperPalette.lineStrong.cgColor)
        ctx.beginPath()
        for month in 1..<PaperSpec.yearColumns {
            PaperText.addVertical(ctx, x: gutter + CGFloat(month) * PaperSpec.yearColumnWidth, from: 0, to: height, zoom: zoom, scale: scale)
        }
        PaperText.addVertical(ctx, x: gutter, from: 0, to: height, zoom: zoom, scale: scale)
        ctx.strokePath()

        // Today's ring: accent, 1.5 pt, 1 lu inside the cell.
        if let frame = todayFrame {
            ctx.setStrokeColor(PaperPalette.accent.cgColor)
            ctx.setLineWidth(1.5 / zoom)
            ctx.stroke(frame.insetBy(dx: 1, dy: 1))
        }

        // 3. Day numbers 1…31 down the gutter (today's in the accent colour).
        let numberSize = PaperText.fontSize(PaperText.yearDayNum, zoom: zoom)
        let numberFont = UIFont.monospacedDigitSystemFont(ofSize: numberSize, weight: .semibold)
        let todayNumberFont = UIFont.monospacedDigitSystemFont(ofSize: numberSize, weight: .bold)
        let todayDay = layout.todayCell?.yearMonthDay?.day
        for row in layout.rows {
            let rect = CGRect(x: 0, y: row.frame.minY, width: gutter, height: row.frame.height)
            guard rect.intersects(dirty) else { continue }
            let isToday = row.dayNumber == todayDay
            PaperText.drawLine("\(row.dayNumber)", in: rect, font: isToday ? todayNumberFont : numberFont,
                               color: isToday ? PaperPalette.accent : PaperPalette.ink2, alignment: .center)
        }

        // 4. Day number + weekday letter (「7 水」) and holiday names. The number takes 1.3 em
        // right-aligned, the letter starts 0.3 em after it (1.3 + 0.3 + 1.4 = 3 em = 45 lu, inside
        // the cell's left 45 % = 50.4 lu).
        let weekdaySize = PaperText.fontSize(PaperText.yearWeekday, zoom: zoom)
        let weekdayFont = UIFont.systemFont(ofSize: weekdaySize, weight: .semibold)
        let todayWeekdayFont = UIFont.systemFont(ofSize: weekdaySize, weight: .heavy)
        let dayNumberFont = UIFont.monospacedDigitSystemFont(ofSize: weekdaySize, weight: .semibold)
        let todayDayNumberFont = UIFont.monospacedDigitSystemFont(ofSize: weekdaySize, weight: .heavy)
        let holidaySize = PaperText.fontSize(PaperText.yearHoliday, zoom: zoom)
        let holidayFont = UIFont.systemFont(ofSize: holidaySize, weight: .regular)
        let leftWidth = PaperSpec.yearColumnWidth * PaperSpec.yearChipLeft
        for label in layout.dateLabels {
            let frame = label.frame
            guard frame.intersects(dirty) else { continue }
            let letter = weekdayNames[max(0, min(6, label.day.weekday))]
            let color: UIColor
            if label.isToday {
                color = PaperPalette.accent
            } else {
                color = PaperPalette.toneColor(label.tone, normal: PaperPalette.ink2)
            }
            let numberRect = CGRect(x: frame.minX + pad, y: frame.minY + pad, width: weekdaySize * 1.3, height: weekdayFont.lineHeight)
            PaperText.drawLine("\(label.day.day)", in: numberRect, font: label.isToday ? todayDayNumberFont : dayNumberFont,
                               color: color, alignment: .right)
            let letterRect = CGRect(x: frame.minX + pad + weekdaySize * 1.6, y: frame.minY + pad, width: weekdaySize * 1.4, height: weekdayFont.lineHeight)
            PaperText.drawLine(letter, in: letterRect, font: label.isToday ? todayWeekdayFont : weekdayFont, color: color)
            if let name = label.holidayName, !name.isEmpty {
                let nameRect = CGRect(x: frame.minX + pad, y: frame.minY + PaperSpec.yearHeader + 1,
                                      width: max(0, leftWidth - 2 * pad), height: holidayFont.lineHeight)
                if nameRect.width > holidaySize {
                    PaperText.drawLine(name, in: nameRect, font: holidayFont, color: PaperPalette.red)
                }
            }
        }

        // 5. Chips: colour, square corners on a continuing side, a link band down to the next day's chip.
        let chipSize = PaperText.fontSize(PaperText.yearChip, zoom: zoom)
        let linkWidth = max(2 / zoom, 4)
        for chip in layout.chips {
            let frame = chip.frame
            let reach = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: max(frame.height, (chip.linkToY ?? frame.maxY) - frame.minY))
            guard reach.intersects(dirty), frame.width > 0, frame.height > 0 else { continue }
            let color = PaperPalette.color(hex: chip.colorHex)
            let path = PaperText.roundedPath(frame, radius: chip.isThin ? 1 : 3, squareTop: chip.continuesUp, squareBottom: chip.continuesDown)
            ctx.setFillColor(color.cgColor)
            ctx.addPath(path)
            ctx.fillPath()
            if let linkToY = chip.linkToY, linkToY > frame.maxY {
                ctx.fill(CGRect(x: frame.minX, y: frame.maxY, width: linkWidth, height: linkToY - frame.maxY))
            }
            let size = chipSize * max(0.1, min(1, chip.fontScale))
            guard frame.height >= size * 0.8 else { continue }
            let font = UIFont.systemFont(ofSize: size, weight: .semibold)
            let textPad = size * (chip.isThin ? 0.2 : 0.3)
            let textRect = frame.insetBy(dx: textPad, dy: 0)
            if textRect.width > size * 0.6 {
                // The title, clipped to the chip's shape.
                ctx.saveGState()
                ctx.addPath(path)
                ctx.clip()
                PaperText.drawLine(chip.title, in: textRect, font: font, color: PaperPalette.readableText(on: chip.colorHex))
                ctx.restoreGState()
            }
        }
    }

    /// A 45° hatch (period 10 lu, line width 2.5 lu) over `rect` on the hatch background.
    private static func drawHatch(_ ctx: CGContext, in rect: CGRect) {
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.setFillColor(PaperPalette.hatchBg.cgColor)
        ctx.fill(rect)
        ctx.setStrokeColor(PaperPalette.hatchLine.cgColor)
        ctx.setLineWidth(2.5)
        ctx.beginPath()
        let period: CGFloat = 10
        let span = rect.width + rect.height
        var offset: CGFloat = -rect.height
        while offset < span {
            // Lines going down-left: from (minX + offset, minY) to (minX + offset − height, maxY).
            ctx.move(to: CGPoint(x: rect.minX + offset + rect.height, y: rect.minY))
            ctx.addLine(to: CGPoint(x: rect.minX + offset, y: rect.maxY))
            offset += period * sqrt(2)
        }
        ctx.strokePath()
        ctx.restoreGState()
    }
}
