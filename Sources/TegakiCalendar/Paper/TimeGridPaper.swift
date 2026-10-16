import Layout
import UIKit

/// Pieces shared by the week and day papers (contract §3.2–3.4): the hour grid and its labels, the
/// timed event boxes (web version `createEventBox`) and the now line. The all-day band left the
/// paper in M4b (`AllDayBandView`), so there is nothing here for it any more.
enum TimeGridPaper {
    // MARK: - Hour grid

    /// Hour lines (solid), half-hour lines (dashed) over x0…x1 and the "0:00"…"23:00" labels right-aligned
    /// at `labelX` just below each hour line (web version `appendTimeAxis`).
    static func drawHourGrid(_ ctx: CGContext, gridTop: CGFloat, hourHeight: CGFloat, x0: CGFloat, x1: CGFloat,
                             labelX: CGFloat, labelSize: PaperText.Size, dirty: CGRect, zoom: CGFloat, scale: CGFloat,
                             readable: CGFloat) {
        let hairline = PaperText.hairline(zoom)
        ctx.setLineWidth(hairline)

        // Half-hour lines, dashed 3 / 4 (screen points).
        ctx.saveGState()
        ctx.setStrokeColor(PaperPalette.lineSoft.cgColor)
        ctx.setLineDash(phase: 0, lengths: [3 / zoom, 4 / zoom])
        ctx.beginPath()
        for hour in 0..<24 {
            let y = gridTop + (CGFloat(hour) + 0.5) * hourHeight
            guard y >= dirty.minY - 1, y <= dirty.maxY + 1 else { continue }
            PaperText.addHorizontal(ctx, y: y, from: x0, to: x1, zoom: zoom, scale: scale)
        }
        ctx.strokePath()
        ctx.restoreGState()

        // Hour lines.
        ctx.setStrokeColor(PaperPalette.line.cgColor)
        ctx.beginPath()
        for hour in 1..<24 {
            let y = gridTop + CGFloat(hour) * hourHeight
            guard y >= dirty.minY - 1, y <= dirty.maxY + 1 else { continue }
            PaperText.addHorizontal(ctx, y: y, from: x0, to: x1, zoom: zoom, scale: scale)
        }
        ctx.strokePath()

        // Labels "0:00"…"23:00", right-aligned, 3 lu below each hour line. The size is capped so
        // "23:00" fits the gutter (`labelX` = gutter − 8; M4B_CONTRACT §4.1); below the readable zoom
        // it is frozen and shrinks with the paper (M4C_CONTRACT §3.1).
        let size = PaperText.gutterLabelSize(labelSize, zoom: zoom, gutter: labelX + 8, readable: readable)
        let font = UIFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)
        let labelWidth = labelX
        for hour in 0..<24 {
            let top = gridTop + CGFloat(hour) * hourHeight + 3
            let rect = CGRect(x: 0, y: top, width: labelWidth, height: font.lineHeight)
            guard rect.intersects(dirty) else { continue }
            PaperText.drawLine("\(hour):00", in: rect, font: font, color: PaperPalette.ink3, alignment: .right)
        }
    }

    // MARK: - Timed boxes

    /// Timed event boxes (web version `createEventBox` + `.event` in views.css): background = event
    /// colour at α .85, a 3 lu solid left edge, 6 lu corners, a 1 pt paper-coloured ring, text in
    /// three modes by height (contract §3.3 item 4); the whole box at α .75 when the event is past.
    /// `readable` is the page's `ZoomPolicy.readableZoom`: below it the text keeps its readable size
    /// (lu) and shrinks with the box (M4C_CONTRACT §3.1); the paddings, the edge, the ring and the
    /// compact threshold stay in screen points as before.
    static func drawBoxes(_ ctx: CGContext, boxes: [TimedEventBox], textSize: PaperText.Size, dirty: CGRect, zoom: CGFloat,
                          readable: CGFloat) {
        let fontLu = PaperText.fontSize(textSize, zoom: zoom, readable: readable)
        let lineHeight = fontLu * PaperText.eventLineHeight
        let titleFont = UIFont.systemFont(ofSize: fontLu, weight: .semibold)
        let timeFont = UIFont.monospacedDigitSystemFont(ofSize: fontLu * 0.85, weight: .regular)
        let padY = max(3, 1 / zoom)
        let padX = max(6, 3 / zoom)
        let edge: CGFloat = 3
        let radius: CGFloat = 6
        let ring = PaperText.hairline(zoom)

        for box in boxes {
            let frame = box.frame
            guard frame.intersects(dirty), frame.width > 0, frame.height > 0 else { continue }
            let color = PaperPalette.color(hex: box.colorHex)
            let path = UIBezierPath(roundedRect: frame, cornerRadius: min(radius, frame.height / 2)).cgPath

            ctx.saveGState()
            ctx.setAlpha(box.isPast ? 0.75 : 1)

            // Ring, fill, left edge.
            ctx.setStrokeColor(PaperPalette.boxRing.cgColor)
            ctx.setLineWidth(ring)
            ctx.addPath(path)
            ctx.strokePath()
            ctx.setFillColor(color.withAlphaComponent(0.85).cgColor)
            ctx.addPath(path)
            ctx.fillPath()
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            ctx.setFillColor(color.cgColor)
            ctx.fill(CGRect(x: frame.minX, y: frame.minY, width: edge, height: frame.height))

            // Text, clipped to the box.
            let text = PaperPalette.readableText(on: box.colorHex)
            let inner = CGRect(x: frame.minX + edge + padX, y: frame.minY + padY,
                               width: frame.width - edge - 2 * padX, height: frame.height - 2 * padY)
            if inner.width > fontLu * 0.5 {
                let duration = box.endMinute - box.startMinute
                if duration < 30 {
                    // 'short': the title only, one line, vertically centred.
                    let rect = CGRect(x: inner.minX, y: frame.minY, width: inner.width, height: frame.height)
                    PaperText.drawLine(box.title, in: rect, font: titleFont, color: text)
                } else if frame.height < lineHeight * 2 + 4 / zoom {
                    // 'compact': "9:00 title" on one line.
                    let rect = CGRect(x: inner.minX, y: frame.minY, width: inner.width, height: frame.height)
                    var x = rect.minX
                    if !box.startText.isEmpty {
                        let timeWidth = min(PaperText.width(of: box.startText, font: timeFont), rect.width)
                        PaperText.drawLine(box.startText, in: CGRect(x: x, y: rect.minY, width: timeWidth, height: rect.height),
                                           font: timeFont, color: text.withAlphaComponent(0.92))
                        x += timeWidth + fontLu * 0.35
                    }
                    let titleRect = CGRect(x: x, y: rect.minY, width: max(0, rect.maxX - x), height: rect.height)
                    PaperText.drawLine(box.title, in: titleRect, font: titleFont, color: text)
                } else {
                    // 'normal': the time range on the first line, the title on up to two more.
                    let timeLine = lineHeight * 0.85
                    PaperText.drawLine(box.timeText, in: CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: timeLine),
                                       font: timeFont, color: text.withAlphaComponent(0.92))
                    let titleRect = CGRect(x: inner.minX, y: inner.minY + timeLine, width: inner.width,
                                           height: max(0, inner.maxY - inner.minY - timeLine))
                    PaperText.drawLines(box.title, in: titleRect, font: titleFont, color: text, maxLines: 2, lineHeight: lineHeight)
                }
            }
            ctx.restoreGState()
            ctx.restoreGState()
        }
    }

    // MARK: - Now line

    /// The current-time line: red, 2 pt on screen whatever the zoom, a dot at its left end.
    static func drawNowLine(_ ctx: CGContext, line: NowLine, dotRadius: CGFloat, zoom: CGFloat) {
        let width = PaperSpec.nowLineWidthPoints / max(zoom, 0.0001)
        ctx.setStrokeColor(PaperPalette.red.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.butt)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: line.x0, y: line.y))
        ctx.addLine(to: CGPoint(x: line.x1, y: line.y))
        ctx.strokePath()
        ctx.setFillColor(PaperPalette.red.cgColor)
        ctx.fillEllipse(in: CGRect(x: line.x0 - dotRadius, y: line.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
    }
}
