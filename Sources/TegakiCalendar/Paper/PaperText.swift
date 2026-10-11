import UIKit

/// Text and line helpers shared by the paper renderers (contract §3.1, §3.2). Everything is in paper
/// units (lu); `zoom` is the current scale so lines stay one device pixel wide and text never gets
/// smaller than its on-screen minimum.
enum PaperText {
    /// A text size of the web version's `TYPE` table: lu on the paper, minimum points on screen.
    struct Size {
        var lu: CGFloat
        var minPoints: CGFloat
    }

    // Web version js/views/view-common.js TYPE (contract §3.2).
    static let weekEvent = Size(lu: 13, minPoints: 10)
    static let dayEvent = Size(lu: 14, minPoints: 11)
    static let weekTimeLabel = Size(lu: 12, minPoints: 10)
    static let dayTimeLabel = Size(lu: 13, minPoints: 10.5)
    static let memoLabel = Size(lu: 14, minPoints: 10.5)
    static let monthDate = Size(lu: 17, minPoints: 12)
    static let monthChip = Size(lu: 12.5, minPoints: 10)
    static let monthHoliday = Size(lu: 11, minPoints: 9)
    static let yearDayNum = Size(lu: 22, minPoints: 11)
    static let yearWeekday = Size(lu: 15, minPoints: 9)
    static let yearChip = Size(lu: 13, minPoints: 8)
    static let yearHoliday = Size(lu: 11, minPoints: 7.5)

    /// Event box line height relative to the font size (web version `EVENT_LINE_HEIGHT`).
    static let eventLineHeight: CGFloat = 1.25

    /// Font size in paper units: proportional to the zoom, at least `minPoints` on screen.
    static func fontSize(_ size: Size, zoom: CGFloat) -> CGFloat {
        max(size.lu, size.minPoints / max(zoom, 0.0001))
    }

    /// A one-point line on screen, in paper units.
    static func hairline(_ zoom: CGFloat) -> CGFloat {
        1 / max(zoom, 0.0001)
    }

    /// Snaps a paper coordinate so a one-point line lands on whole device pixels.
    static func snap(_ value: CGFloat, zoom: CGFloat, scale: CGFloat) -> CGFloat {
        let z = max(zoom, 0.0001)
        let s = max(scale, 1)
        let pixels = floor(value * z * s) + 0.5
        return pixels / s / z
    }

    /// Width of `string` in `font`, rounded up.
    static func width(of string: String, font: UIFont) -> CGFloat {
        guard !string.isEmpty else { return 0 }
        return ceil((string as NSString).size(withAttributes: [.font: font]).width)
    }

    /// Draws one line of text vertically centred in `rect`, truncated with an ellipsis.
    static func drawLine(_ string: String, in rect: CGRect, font: UIFont, color: UIColor,
                         alignment: NSTextAlignment = .left, kern: CGFloat = 0) {
        guard !string.isEmpty, rect.width > 0 else { return }
        let attributed = attributedString(string, font: font, color: color, alignment: alignment, kern: kern)
        let lineHeight = font.lineHeight
        let lineRect = CGRect(x: rect.minX, y: rect.midY - lineHeight / 2, width: rect.width, height: lineHeight)
        attributed.draw(with: lineRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
    }

    /// Draws up to `maxLines` wrapped lines from the top of `rect`, the last visible one truncated.
    static func drawLines(_ string: String, in rect: CGRect, font: UIFont, color: UIColor, maxLines: Int,
                          lineHeight: CGFloat? = nil) {
        guard !string.isEmpty, rect.width > 0, maxLines > 0 else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.lineBreakStrategy = []
        if let lineHeight = lineHeight {
            paragraph.minimumLineHeight = lineHeight
            paragraph.maximumLineHeight = lineHeight
        }
        let attributed = NSAttributedString(string: string, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])
        let height = min(rect.height, CGFloat(maxLines) * (lineHeight ?? font.lineHeight))
        let box = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: height)
        attributed.draw(with: box, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
    }

    private static func attributedString(_ string: String, font: UIFont, color: UIColor,
                                         alignment: NSTextAlignment, kern: CGFloat) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = alignment
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        if kern != 0 { attributes[.kern] = kern }
        return NSAttributedString(string: string, attributes: attributes)
    }

    /// Strokes a horizontal line from `x0` to `x1` at the snapped `y` (adds to the current path).
    static func addHorizontal(_ ctx: CGContext, y: CGFloat, from x0: CGFloat, to x1: CGFloat, zoom: CGFloat, scale: CGFloat) {
        let sy = snap(y, zoom: zoom, scale: scale)
        ctx.move(to: CGPoint(x: x0, y: sy))
        ctx.addLine(to: CGPoint(x: x1, y: sy))
    }

    /// Strokes a vertical line from `y0` to `y1` at the snapped `x` (adds to the current path).
    static func addVertical(_ ctx: CGContext, x: CGFloat, from y0: CGFloat, to y1: CGFloat, zoom: CGFloat, scale: CGFloat) {
        let sx = snap(x, zoom: zoom, scale: scale)
        ctx.move(to: CGPoint(x: sx, y: y0))
        ctx.addLine(to: CGPoint(x: sx, y: y1))
    }

    /// A rounded rectangle whose corners on a continuing side are square (bars and chips).
    static func roundedPath(_ rect: CGRect, radius: CGFloat, squareLeft: Bool = false, squareRight: Bool = false,
                            squareTop: Bool = false, squareBottom: Bool = false) -> CGPath {
        var corners: UIRectCorner = .allCorners
        if squareLeft { corners.subtract([.topLeft, .bottomLeft]) }
        if squareRight { corners.subtract([.topRight, .bottomRight]) }
        if squareTop { corners.subtract([.topLeft, .topRight]) }
        if squareBottom { corners.subtract([.bottomLeft, .bottomRight]) }
        let r = max(0, min(radius, rect.width / 2, rect.height / 2))
        return UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: r, height: r)).cgPath
    }
}
