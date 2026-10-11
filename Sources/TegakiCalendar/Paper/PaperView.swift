import Layout
import UIKit

// MARK: - Content

/// Everything the paper draws for one month page (M2's `PaperContent`, renamed). Built by
/// `CalendarRootScreen` from the current `MonthPageLayout`.
struct MonthPaperContent: Equatable {
    var layout: MonthPageLayout
    var labels: [DateLabel]
    var bars: [AllDayBar]
    var chips: [TimedChip]
    var holidayNames: [DayKey: String]
}

/// The week page: the layout carries the bands, boxes, labels and the now line (contract §1.6).
struct WeekPaperContent: Equatable {
    var layout: WeekPageLayout
}

/// The day page (contract §1.7).
struct DayPaperContent: Equatable {
    var layout: DayPageLayout
}

/// The year page (contract §1.8). `monthNames` ("1月"…"12月") are used by the sticky header only;
/// the paper does not draw them.
struct YearPaperContent: Equatable {
    var layout: YearPageLayout
    var monthNames: [String]
}

/// What the paper under the ink canvas shows (contract §3.1). 担当 I only compares it with `==` and
/// hands it to `PaperView(content:)`.
enum PaperContent: Equatable {
    case month(MonthPaperContent)
    case week(WeekPaperContent)
    case day(DayPaperContent)
    case year(YearPaperContent)

    var size: CGSize { layout.size }

    var kind: PageKind { layout.kind }

    /// The page geometry behind the content, as the common protocol.
    var layout: any PageLayout {
        switch self {
        case .month(let content): return content.layout
        case .week(let content): return content.layout
        case .day(let content): return content.layout
        case .year(let content): return content.layout
        }
    }
}

// MARK: - Palette

/// The paper colours of the web version (styles/views.css). The paper is always light, also in dark mode.
enum PaperPalette {
    static let paper = color(hex: "#fffdf8")
    static let line = color(hex: "#e5e7eb")
    static let lineSoft = color(hex: "#eceef1")
    static let lineStrong = color(hex: "#d7dade")
    static let rule = color(hex: "#ebe7de")
    static let ink1 = color(hex: "#1f2937")
    static let ink2 = color(hex: "#4b5563")
    static let ink3 = color(hex: "#9ca3af")
    static let red = color(hex: "#dc2626")
    static let blue = color(hex: "#2563eb")
    static let accent = color(hex: "#2563eb")
    static let memoLabel = color(hex: "#a8a29e")
    static let fallbackEvent = color(hex: "#039be5")
    static let todayTint = UIColor(red: 37 / 255, green: 99 / 255, blue: 235 / 255, alpha: 0.06)
    static let todayTintSoft = UIColor(red: 37 / 255, green: 99 / 255, blue: 235 / 255, alpha: 0.03)
    static let weekendTint = UIColor(red: 146 / 255, green: 118 / 255, blue: 64 / 255, alpha: 0.045)
    static let weekendTintSoft = UIColor(red: 146 / 255, green: 118 / 255, blue: 64 / 255, alpha: 0.03)
    static let outTint = UIColor(red: 107 / 255, green: 114 / 255, blue: 128 / 255, alpha: 0.055)
    // Year page cells.
    static let satTint = UIColor(red: 37 / 255, green: 99 / 255, blue: 235 / 255, alpha: 0.055)
    static let sunTint = UIColor(red: 220 / 255, green: 38 / 255, blue: 38 / 255, alpha: 0.06)
    static let todayTintStrong = UIColor(red: 37 / 255, green: 99 / 255, blue: 235 / 255, alpha: 0.15)
    static let hatchBg = color(hex: "#f3f2ee")
    static let hatchLine = color(hex: "#dcd9d2")
    /// The faint paper-coloured ring around a timed event box.
    static let boxRing = UIColor(red: 255 / 255, green: 253 / 255, blue: 248 / 255, alpha: 0.9)

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

    /// Colour of a date label's text: Sunday / holiday red, Saturday blue, otherwise `normal`.
    static func toneColor(_ tone: DayTone, normal: UIColor = ink1) -> UIColor {
        switch tone {
        case .saturday: return blue
        case .sundayOrHoliday: return red
        case .normal: return normal
        }
    }
}

// MARK: - Renderers

/// One page kind's drawing (contract §3.1): `MonthPaper`, `WeekPaper`, `DayPaper`, `YearPaper`.
@MainActor
protocol PaperRenderer {
    associatedtype Content
    /// Draws `content` into `ctx`, which is already scaled by `zoom` (paper units). `dirty` is the
    /// area to redraw in paper units; `view` gives the device scale for pixel snapping.
    static func draw(_ content: Content, in ctx: CGContext, dirty: CGRect, zoom: CGFloat, view: PaperView)
}

// MARK: - View

/// Draws the paper of the current page under the PencilKit canvas: grid lines, date numbers, event
/// bars / chips / boxes, the now line … everything that is not ink.
///
/// Everything is drawn in paper units (lu) through a CoreGraphics transform scaled by `zoomScale`,
/// so the owner (`InkCanvasView`, 担当 I) just keeps `frame = content.size × zoomScale` and
/// `zoomScale` in sync with the PencilKit scroll view (DESIGN §3.2).
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
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: content.size.width * zoomScale,
                                                              height: content.size.height * zoomScale)))
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

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let zoom = max(zoomScale, 0.01)

        ctx.saveGState()
        ctx.scaleBy(x: zoom, y: zoom)
        // The dirty area in paper units; elements outside it are skipped.
        let dirty = CGRect(x: rect.minX / zoom, y: rect.minY / zoom, width: rect.width / zoom, height: rect.height / zoom)

        ctx.setFillColor(PaperPalette.paper.cgColor)
        ctx.fill(dirty)

        switch content {
        case .month(let month):
            MonthPaper.draw(month, in: ctx, dirty: dirty, zoom: zoom, view: self)
        case .week(let week):
            WeekPaper.draw(week, in: ctx, dirty: dirty, zoom: zoom, view: self)
        case .day(let day):
            DayPaper.draw(day, in: ctx, dirty: dirty, zoom: zoom, view: self)
        case .year(let year):
            YearPaper.draw(year, in: ctx, dirty: dirty, zoom: zoom, view: self)
        }

        ctx.restoreGState()
    }
}
