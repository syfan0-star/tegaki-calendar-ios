import Layout
import UIKit

/// Everything the paper draws for one month page (contract §4). Built by `MonthPageScreen` from the
/// current `MonthPageLayout` and handed to `InkCanvasView`, which keeps a `PaperView` under the canvas.
///
/// `Equatable` is implemented by hand (field by field) so it does not depend on the Layout types
/// conforming to `Equatable` themselves.
struct PaperContent: Equatable {
    var layout: MonthPageLayout
    var labels: [DateLabel]
    var bars: [AllDayBar]
    var chips: [TimedChip]
    var holidayNames: [DayKey: String]

    static func == (lhs: PaperContent, rhs: PaperContent) -> Bool {
        guard lhs.layout.size == rhs.layout.size,
              lhs.layout.memo == rhs.layout.memo,
              lhs.layout.cells == rhs.layout.cells,
              lhs.holidayNames == rhs.holidayNames,
              lhs.layout.rows.count == rhs.layout.rows.count,
              lhs.labels.count == rhs.labels.count,
              lhs.bars.count == rhs.bars.count,
              lhs.chips.count == rhs.chips.count else { return false }
        for (a, b) in zip(lhs.layout.rows, rhs.layout.rows) {
            if a.index != b.index || a.frame != b.frame || a.days != b.days
                || a.laneCount != b.laneCount || a.maxChips != b.maxChips { return false }
        }
        for (a, b) in zip(lhs.labels, rhs.labels) {
            if a.day != b.day || a.frame != b.frame || a.isToday != b.isToday || a.inMonth != b.inMonth
                || a.tone != b.tone || a.holidayName != b.holidayName { return false }
        }
        for (a, b) in zip(lhs.bars, rhs.bars) {
            if a.eventId != b.eventId || a.frame != b.frame || a.row != b.row || a.lane != b.lane
                || a.continuesLeft != b.continuesLeft || a.continuesRight != b.continuesRight
                || a.colorHex != b.colorHex || a.title != b.title { return false }
        }
        for (a, b) in zip(lhs.chips, rhs.chips) {
            if a.eventId != b.eventId || a.frame != b.frame || a.day != b.day || a.timeText != b.timeText
                || a.title != b.title || a.colorHex != b.colorHex || a.moreCount != b.moreCount { return false }
        }
        return true
    }
}

/// The paper colours of the web version (styles/views.css). The paper is always light, also in dark mode.
enum PaperPalette {
    static let paper = color(hex: "#fffdf8")
    static let line = color(hex: "#e5e7eb")
    static let lineStrong = color(hex: "#d7dade")
    static let rule = color(hex: "#ebe7de")
    static let ink1 = color(hex: "#1f2937")
    static let ink2 = color(hex: "#4b5563")
    static let red = color(hex: "#dc2626")
    static let blue = color(hex: "#2563eb")
    static let accent = color(hex: "#2563eb")
    static let memoLabel = color(hex: "#a8a29e")
    static let fallbackEvent = color(hex: "#039be5")
    static let todayTint = UIColor(red: 37 / 255, green: 99 / 255, blue: 235 / 255, alpha: 0.06)
    static let weekendTint = UIColor(red: 146 / 255, green: 118 / 255, blue: 64 / 255, alpha: 0.045)
    static let outTint = UIColor(red: 107 / 255, green: 114 / 255, blue: 128 / 255, alpha: 0.055)

    /// "#rrggbb" (or "#rgb", "#rrggbbaa") → colour; the fallback event colour for anything else.
    static func color(hex: String) -> UIColor {
        guard let rgba = rgba(hex: hex) else { return fallbackEvent }
        return UIColor(red: rgba.r, green: rgba.g, blue: rgba.b, alpha: rgba.a)
    }

    /// Parsed channels (0...1) of a hex colour string; nil when it is not a hex colour.
    static func rgba(hex: String) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        if text.count == 3 {
            text = text.map { "\($0)\($0)" }.joined()
        }
        guard text.count == 6 || text.count == 8, let value = UInt64(text, radix: 16) else { return nil }
        if text.count == 6 {
            return (CGFloat((value >> 16) & 0xff) / 255, CGFloat((value >> 8) & 0xff) / 255,
                    CGFloat(value & 0xff) / 255, 1)
        }
        return (CGFloat((value >> 24) & 0xff) / 255, CGFloat((value >> 16) & 0xff) / 255,
                CGFloat((value >> 8) & 0xff) / 255, CGFloat(value & 0xff) / 255)
    }

    /// White or dark text on a coloured background, by the WCAG contrast ratio against both
    /// (same rule as the web version's `readableTextColor`).
    static func readableText(on hex: String) -> UIColor {
        guard let c = rgba(hex: hex) else { return .white }
        func channel(_ v: CGFloat) -> CGFloat {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
        let darkTextLuminance: CGFloat = 0.0237 // #1f2937
        let contrastWhite = 1.05 / (luminance + 0.05)
        let contrastDark = (luminance + 0.05) / (darkTextLuminance + 0.05)
        return contrastWhite > contrastDark ? .white : ink1
    }
}

/// Draws the paper of the month page: grid lines, date numbers (today / Saturday / Sunday-holiday /
/// outside the month), holiday names, all-day bars, timed chips and the memo area below the grid.
///
/// Everything is drawn in paper units (lu) through a CoreGraphics transform scaled by `zoomScale`,
/// so the owner (`InkCanvasView`) just keeps `frame = layout.size × zoomScale` and `zoomScale` in sync
/// with the PencilKit scroll view (DESIGN §3.2). Fonts are proportional to the zoom with a floor of
/// about 10 pt on screen (contract §4).
@MainActor
final class PaperView: UIView {
    var content: PaperContent {
        didSet { setNeedsDisplay() }
    }

    var zoomScale: CGFloat {
        didSet {
            if zoomScale != oldValue { setNeedsDisplay() }
        }
    }

    /// - Parameter zoomScale: the initial zoom (the owner sets it again whenever the scroll view zooms).
    init(content: PaperContent, zoomScale: CGFloat = 1) {
        self.content = content
        self.zoomScale = zoomScale
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: content.layout.size.width * zoomScale,
                                                              height: content.layout.size.height * zoomScale)))
        isOpaque = true
        backgroundColor = PaperPalette.paper
        contentMode = .redraw
        isUserInteractionEnabled = false
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let scale = window?.screen.scale, scale > 0, scale != contentScaleFactor {
            contentScaleFactor = scale
            layer.contentsScale = scale
            setNeedsDisplay()
        }
    }

    // MARK: - Drawing

    /// Font sizes in lu (web version `TYPE` in js/views/view-common.js) and the on-screen minimum.
    private enum FontLu {
        static let date: CGFloat = 17
        static let chip: CGFloat = 12.5
        static let holiday: CGFloat = 11
        static let memoLabel: CGFloat = 14
        static let minimumPoints: CGFloat = 10
    }

    private static let ruleStep: CGFloat = 50
    private static let ruleInset: CGFloat = 20

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let zoom = max(zoomScale, 0.01)
        let layout = content.layout

        ctx.saveGState()
        ctx.scaleBy(x: zoom, y: zoom)
        // The dirty area in paper units; elements outside it are skipped.
        let dirty = CGRect(x: rect.minX / zoom, y: rect.minY / zoom, width: rect.width / zoom, height: rect.height / zoom)

        ctx.setFillColor(PaperPalette.paper.cgColor)
        ctx.fill(dirty)

        drawTints(ctx, layout: layout, dirty: dirty)
        drawGridLines(ctx, layout: layout, dirty: dirty, zoom: zoom)
        drawMemoArea(ctx, layout: layout, dirty: dirty, zoom: zoom)
        drawDateLabels(ctx, dirty: dirty, zoom: zoom)
        drawAllDayBars(ctx, layout: layout, dirty: dirty, zoom: zoom)
        drawTimedChips(ctx, dirty: dirty, zoom: zoom)

        ctx.restoreGState()
    }

    private func drawTints(_ ctx: CGContext, layout: MonthPageLayout, dirty: CGRect) {
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

    private func drawGridLines(_ ctx: CGContext, layout: MonthPageLayout, dirty: CGRect, zoom: CGFloat) {
        let width = PaperSpec.monthWidth
        let gridBottom = layout.memo.minY
        let lineWidth = hairline(zoom)
        ctx.setLineWidth(lineWidth)
        ctx.setStrokeColor(PaperPalette.line.cgColor)
        ctx.beginPath()
        for column in 1..<PaperSpec.monthColumns {
            let x = snap(CGFloat(column) * PaperSpec.monthColumnWidth, zoom: zoom)
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: gridBottom))
        }
        for row in layout.rows where row.index > 0 {
            let y = snap(row.frame.minY, zoom: zoom)
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: width, y: y))
        }
        ctx.strokePath()
    }

    private func drawMemoArea(_ ctx: CGContext, layout: MonthPageLayout, dirty: CGRect, zoom: CGFloat) {
        let memo = layout.memo
        guard memo.height > 0 else { return }
        let width = PaperSpec.monthWidth
        let lineWidth = hairline(zoom)

        // Separator between the grid and the memo area (a little stronger than the grid lines).
        ctx.setLineWidth(lineWidth)
        ctx.setStrokeColor(PaperPalette.lineStrong.cgColor)
        let separatorY = snap(memo.minY, zoom: zoom)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 0, y: separatorY))
        ctx.addLine(to: CGPoint(x: width, y: separatorY))
        ctx.strokePath()

        // Faint ruled lines every 50 lu, inset 20 lu on both sides.
        ctx.setStrokeColor(PaperPalette.rule.cgColor)
        ctx.beginPath()
        var y = memo.minY + Self.ruleStep
        while y < memo.maxY {
            if y >= dirty.minY - 1, y <= dirty.maxY + 1 {
                let sy = snap(y, zoom: zoom)
                ctx.move(to: CGPoint(x: Self.ruleInset, y: sy))
                ctx.addLine(to: CGPoint(x: width - Self.ruleInset, y: sy))
            }
            y += Self.ruleStep
        }
        ctx.strokePath()

        // Small 「メモ」 label at the top-left, as on the web version.
        let labelSize = fontSize(FontLu.memoLabel, zoom: zoom)
        let labelFont = UIFont.systemFont(ofSize: labelSize, weight: .semibold)
        let labelRect = CGRect(x: Self.ruleInset, y: memo.minY + 6, width: 200, height: labelFont.lineHeight + 2)
        if labelRect.intersects(dirty) {
            drawText("メモ", in: labelRect, font: labelFont, color: PaperPalette.memoLabel, kern: labelSize * 0.15)
        }
    }

    private func drawDateLabels(_ ctx: CGContext, dirty: CGRect, zoom: CGFloat) {
        let dateSize = fontSize(FontLu.date, zoom: zoom)
        let dateFont = UIFont.monospacedDigitSystemFont(ofSize: dateSize, weight: .semibold)
        let holidaySize = fontSize(FontLu.holiday, zoom: zoom)
        let holidayFont = UIFont.systemFont(ofSize: holidaySize, weight: .regular)

        for label in content.labels {
            let frame = label.frame
            guard frame.intersects(dirty) else { continue }
            let alpha: CGFloat = label.inMonth ? 1 : 0.4
            let number = "\(label.day.day)"
            let numberWidth = ceil((number as NSString).size(withAttributes: [.font: dateFont]).width)

            // The number sits in a circle-sized box at the left of the header; today fills the circle.
            let box = frame.height
            let boxWidth = max(box, numberWidth + box * 0.4)
            let numberBox = CGRect(x: frame.minX, y: frame.minY, width: boxWidth, height: box)

            let numberColor: UIColor
            if label.isToday {
                ctx.setFillColor(PaperPalette.accent.withAlphaComponent(alpha).cgColor)
                let path = UIBezierPath(roundedRect: numberBox, cornerRadius: box / 2)
                ctx.addPath(path.cgPath)
                ctx.fillPath()
                numberColor = .white
            } else {
                switch label.tone {
                case .saturday: numberColor = PaperPalette.blue
                case .sundayOrHoliday: numberColor = PaperPalette.red
                case .normal: numberColor = PaperPalette.ink1
                }
            }
            drawText(number, in: numberBox, font: dateFont, color: numberColor.withAlphaComponent(alpha),
                     alignment: .center)

            // Holiday name next to the number, truncated to the rest of the header.
            let holidayName = label.holidayName ?? content.holidayNames[label.day]
            if let name = holidayName, !name.isEmpty {
                let gap: CGFloat = 4
                let nameRect = CGRect(x: numberBox.maxX + gap, y: frame.minY,
                                      width: max(0, frame.maxX - numberBox.maxX - gap - 2), height: frame.height)
                if nameRect.width > holidaySize {
                    drawText(name, in: nameRect, font: holidayFont, color: PaperPalette.red.withAlphaComponent(alpha))
                }
            }
        }
    }

    private func drawAllDayBars(_ ctx: CGContext, layout: MonthPageLayout, dirty: CGRect, zoom: CGFloat) {
        let size = fontSize(FontLu.chip, zoom: zoom)
        let font = UIFont.systemFont(ofSize: size, weight: .semibold)
        let radius: CGFloat = 4

        for bar in content.bars {
            let frame = bar.frame
            guard frame.intersects(dirty), frame.width > 0, frame.height > 0 else { continue }
            let alpha: CGFloat = barIsOutsideMonth(bar, layout: layout) ? 0.55 : 1
            let fill = PaperPalette.color(hex: bar.colorHex)

            var corners: UIRectCorner = .allCorners
            if bar.continuesLeft { corners.subtract([.topLeft, .bottomLeft]) }
            if bar.continuesRight { corners.subtract([.topRight, .bottomRight]) }
            let path = UIBezierPath(roundedRect: frame, byRoundingCorners: corners,
                                    cornerRadii: CGSize(width: radius, height: radius))
            ctx.setFillColor(fill.withAlphaComponent(alpha).cgColor)
            ctx.addPath(path.cgPath)
            ctx.fillPath()

            let pad = size * 0.4
            let textRect = frame.insetBy(dx: pad, dy: 0)
            if textRect.width > size {
                let text = PaperPalette.readableText(on: bar.colorHex).withAlphaComponent(alpha)
                drawText(bar.title, in: textRect, font: font, color: text)
            }
        }
    }

    private func drawTimedChips(_ ctx: CGContext, dirty: CGRect, zoom: CGFloat) {
        let size = fontSize(FontLu.chip, zoom: zoom)
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
                drawText(text, in: rect, font: moreFont, color: PaperPalette.ink2.withAlphaComponent(alpha))
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
                let timeWidth = ceil((chip.timeText as NSString).size(withAttributes: [.font: timeFont]).width)
                let timeRect = CGRect(x: x, y: frame.minY, width: min(timeWidth, max(0, frame.maxX - pad - x)),
                                      height: frame.height)
                drawText(chip.timeText, in: timeRect, font: timeFont, color: PaperPalette.ink2.withAlphaComponent(alpha))
                x = timeRect.maxX + size * 0.3
            }

            // Title, truncated with an ellipsis.
            let titleRect = CGRect(x: x, y: frame.minY, width: max(0, frame.maxX - pad - x), height: frame.height)
            if titleRect.width > size {
                drawText(chip.title, in: titleRect, font: titleFont, color: PaperPalette.ink1.withAlphaComponent(alpha))
            }
        }
    }

    // MARK: - Helpers

    /// True when every day the bar covers lies outside the month (the bar is then faded like its cells).
    private func barIsOutsideMonth(_ bar: AllDayBar, layout: MonthPageLayout) -> Bool {
        guard bar.row >= 0, bar.row < layout.rows.count else { return false }
        let days = layout.rows[bar.row].days
        let columnWidth = PaperSpec.monthColumnWidth
        let first = max(0, min(days.count - 1, Int(floor(bar.frame.minX / columnWidth))))
        let last = max(0, min(days.count - 1, Int(floor((bar.frame.maxX - 1) / columnWidth))))
        guard first <= last else { return false }
        let inMonth = Set(content.labels.filter { $0.inMonth }.map { $0.day })
        for column in first...last where inMonth.contains(days[column]) {
            return false
        }
        return true
    }

    /// A one-point line on screen, in paper units.
    private func hairline(_ zoom: CGFloat) -> CGFloat {
        1 / zoom
    }

    /// Snaps a paper coordinate so a one-point line lands on whole device pixels.
    private func snap(_ value: CGFloat, zoom: CGFloat) -> CGFloat {
        let scale = max(contentScaleFactor, 1)
        let pixels = floor(value * zoom * scale) + 0.5
        return pixels / scale / zoom
    }

    /// Font size in paper units: proportional to the zoom, at least `minimumPoints` on screen.
    private func fontSize(_ lu: CGFloat, zoom: CGFloat) -> CGFloat {
        max(lu, FontLu.minimumPoints / zoom)
    }

    /// Draws one line of text vertically centred in `rect`, truncated with an ellipsis.
    private func drawText(_ string: String, in rect: CGRect, font: UIFont, color: UIColor,
                          alignment: NSTextAlignment = .left, kern: CGFloat = 0) {
        guard !string.isEmpty, rect.width > 0 else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = alignment
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        if kern != 0 { attributes[.kern] = kern }
        let attributed = NSAttributedString(string: string, attributes: attributes)
        let lineHeight = font.lineHeight
        let lineRect = CGRect(x: rect.minX, y: rect.midY - lineHeight / 2, width: rect.width, height: lineHeight)
        attributed.draw(with: lineRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
    }
}
