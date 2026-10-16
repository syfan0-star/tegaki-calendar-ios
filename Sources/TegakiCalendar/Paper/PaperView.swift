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

/// The week page: the layout carries the boxes, labels and the now line (contract §1.6). Since M4b
/// the all-day band is not on the paper (`PaperContent.allDayBand`).
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

    /// The fixed all-day band above the paper (M4B_CONTRACT §2.5): the week / day layout's band,
    /// nil on the month and year pages. The screen hands it to `AllDayBandView`.
    var allDayBand: AllDayBandLayout? {
        switch self {
        case .week(let content): return content.layout.allDayBand
        case .day(let content): return content.layout.allDayBand
        case .month, .year: return nil
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
/// Everything is drawn in paper units (lu) through a CoreGraphics transform scaled by `zoomScale`.
/// Since M4b the view does not cover the whole paper (at the year page's minimum zoom that would be
/// a 1875 × 2491 pt backing store, M4B_CONTRACT §1.6 / M4B-25): it holds a **window** of at most
/// 2 × 2 screens around the visible part, in content coordinates (paper × zoom, pt). The owner
/// (`InkCanvasView`) calls `show(visible:zoom:contentSize:live:)` on every scroll, zoom and layout
/// pass; while the visible rect stays inside the window at the same zoom only the frame moves (no
/// redraw), otherwise a new window is made around it and drawn once. While the canvas is pinching
/// or bouncing (`live`) the window is only stretched with a transform and redrawn once at the end
/// (M4C_CONTRACT §2.2 F3: no 2 × 2-screen backing store per frame).
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

    /// The range this view holds, in content coordinates (paper × zoom, pt);
    /// `frame.size == contentWindow.size`. (Named `window` in M4B_CONTRACT §1.6; `UIView.window`
    /// is taken.)
    private(set) var contentWindow: CGRect = .zero
    /// The zoom the window was made for (a different zoom makes a new window).
    private var windowZoom: CGFloat = 0
    /// How many times a redraw was requested (`setNeedsDisplay()`); the tests watch it.
    private(set) var displayRequestCount = 0

    /// - Parameter zoomScale: the initial zoom (the owner sets it again whenever the scroll view zooms).
    /// The frame starts at `.zero`: the first `show` decides it.
    init(content: PaperContent, zoomScale: CGFloat = 1) {
        self.content = content
        self.zoomScale = zoomScale
        super.init(frame: .zero)
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

    override func setNeedsDisplay() {
        displayRequestCount += 1
        super.setNeedsDisplay()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let scale = window?.screen.scale, scale > 0, scale != contentScaleFactor {
            contentScaleFactor = scale
            layer.contentsScale = scale
            setNeedsDisplay()
        }
    }

    /// Tells the view what is visible (content coordinates). When the window already holds
    /// `visible` at the same zoom, only `frame.origin` moves (nothing is redrawn). Otherwise the
    /// window becomes `window(for:content:)`, the frame is `(window.origin − visible.origin,
    /// window.size)` and the view is redrawn — once: a zoom change requests the redraw through
    /// `zoomScale`'s `didSet`, and the new window then asks for no second one.
    ///
    /// `live` (M4C_CONTRACT §2.2 F3): the canvas is pinching or bouncing (`Coordinator.isLive`). The
    /// window is neither remade nor redrawn and `zoomScale` is left alone; the window drawn at
    /// `windowZoom` is stretched by s = zoom / windowZoom instead: `bounds.size` stays
    /// `contentWindow.size`, `transform` = scale(s), `center` = (contentWindow.midX × s − visible.minX,
    /// contentWindow.midY × s − visible.minY). Only when `windowZoom > 0 && !contentWindow.isEmpty`
    /// (right after `attach` the window is empty and s would not be finite); otherwise it falls
    /// through to the `live: false` path. `live: false` first puts `transform` back to `.identity`,
    /// then updates `zoomScale` and does the usual work (a zoom that differs from `windowZoom` makes
    /// and draws a new window once).
    func show(visible: CGRect, zoom: CGFloat, contentSize: CGSize, live: Bool = false) {
        if live, windowZoom > 0, !contentWindow.isEmpty {
            let s = zoom / windowZoom
            if s.isFinite, s > 0 {
                let stretched = CGAffineTransform(scaleX: s, y: s)
                if transform != stretched {
                    transform = stretched
                }
                let c = CGPoint(x: contentWindow.midX * s - visible.minX, y: contentWindow.midY * s - visible.minY)
                if center != c {
                    center = c
                }
                return
            }
        }
        if transform != .identity {
            transform = .identity
        }
        var redrawRequested = false
        if zoomScale != zoom {
            zoomScale = zoom // didSet → setNeedsDisplay()
            redrawRequested = true
        }
        let content = CGRect(origin: .zero, size: contentSize)
        let needed = visible.intersection(content)
        if windowZoom == zoom, !contentWindow.isEmpty, !needed.isNull, contentWindow.contains(needed) {
            let origin = CGPoint(x: contentWindow.minX - visible.minX, y: contentWindow.minY - visible.minY)
            if frame.origin != origin {
                frame.origin = origin
            }
            return
        }
        contentWindow = Self.window(for: visible, content: contentSize)
        windowZoom = zoom
        frame = CGRect(x: contentWindow.minX - visible.minX, y: contentWindow.minY - visible.minY,
                       width: contentWindow.width, height: contentWindow.height)
        if !redrawRequested {
            setNeedsDisplay()
        }
    }

    /// `visible` grown by half its width to the left and right and half its height above and below
    /// (at most 2 × 2 screens), intersected with `(0, 0, content)`. `.zero` when `visible` is not
    /// finite or empty.
    static func window(for visible: CGRect, content: CGSize) -> CGRect {
        guard visible.minX.isFinite, visible.minY.isFinite, visible.width.isFinite, visible.height.isFinite,
              visible.width > 0, visible.height > 0,
              content.width.isFinite, content.height.isFinite else { return .zero }
        let grown = visible.insetBy(dx: -visible.width / 2, dy: -visible.height / 2)
        let clipped = grown.intersection(CGRect(origin: .zero, size: content))
        guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else { return .zero }
        return clipped
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let zoom = max(zoomScale, 0.01)

        ctx.saveGState()
        // View coordinates → content coordinates (the window's origin) → paper units.
        ctx.translateBy(x: -contentWindow.minX, y: -contentWindow.minY)
        ctx.scaleBy(x: zoom, y: zoom)
        // The dirty area in paper units; elements outside it are skipped.
        let dirty = CGRect(x: (rect.minX + contentWindow.minX) / zoom, y: (rect.minY + contentWindow.minY) / zoom,
                           width: rect.width / zoom, height: rect.height / zoom)

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
