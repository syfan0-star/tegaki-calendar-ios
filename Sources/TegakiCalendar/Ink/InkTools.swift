import CoreGraphics
import Foundation
import InkModel
import Layout
import PencilKit
#if canImport(UIKit)
import UIKit
/// The colour class PencilKit takes on this platform. UIColor on iOS; NSColor only exists so that
/// the pure logic in this folder can be type-checked on a Mac without Xcode (see docs/M2_CONTRACT.md §8).
typealias InkPlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias InkPlatformColor = NSColor
#endif

// MARK: - Tool definitions (contract §3)

/// One pen or marker setting as the toolbar chooses it: which ink, which colour, how wide (lu).
///
/// `InkModel.InkTool` is written out in full because the M1 file `Ink/CanvasView.swift` still
/// declares an app-local `InkTool` (pen / highlighter / eraser) that would shadow the package type
/// until it is removed at integration time.
struct InkStyle: Equatable {
    var tool: InkModel.InkTool
    var colorHex: String
    var width: CGFloat

    init(tool: InkModel.InkTool, colorHex: String, width: CGFloat) {
        self.tool = tool
        self.colorHex = InkColors.normalized(colorHex) ?? colorHex
        self.width = width
    }
}

/// What the canvas is currently doing with the Pencil: drawing with a style, erasing whole strokes,
/// selecting with the lasso, or dragging the rect of a new event (M3B_CONTRACT.md §3.1).
enum CanvasTool: Equatable {
    case ink(InkStyle)
    case eraser
    /// 投げなわ (DESIGN.md §3.6): circle strokes to select them, drag inside the box to move them.
    case lasso
    /// 予定ツール: drag a rect (or tap) on the paper to create an event.
    case eventRect
}

/// The palette and widths of the web version (`js/ink/render.js` PEN_COLORS / HIGHLIGHTER_COLORS,
/// DESIGN.md §3.6: pen 細 2 / 中 3.5 / 太 6, marker 18, eraser radius 10 lu → width 20).
enum InkPresets {
    static let penColors: [String] = ["#1f2937", "#2563eb", "#dc2626", "#16a34a", "#ea580c", "#7c3aed"]
    static let markerColors: [String] = ["#fde047", "#f9a8d4", "#86efac", "#93c5fd"]
    /// 細 / 中 / 太
    static let penWidths: [CGFloat] = [2, 3.5, 6]
    static let markerWidth: CGFloat = 18
    /// Vector eraser width in paper units (the web version erases within a 10 lu radius).
    static let eraserWidth: CGFloat = 20

    static let defaultPen = InkStyle(tool: .pen, colorHex: penColors[0], width: penWidths[1])
    static let defaultMarker = InkStyle(tool: .marker, colorHex: markerColors[0], width: markerWidth)

    /// The colour used when a stored hex string cannot be parsed (web DEFAULT_COLORS).
    static func fallbackColorHex(for tool: InkModel.InkTool) -> String {
        tool == .marker ? markerColors[0] : penColors[0]
    }
}

extension InkStyle {
    static func pen(_ colorHex: String, width: CGFloat = InkPresets.penWidths[1]) -> InkStyle {
        InkStyle(tool: .pen, colorHex: colorHex, width: width)
    }

    static func marker(_ colorHex: String) -> InkStyle {
        InkStyle(tool: .marker, colorHex: colorHex, width: InkPresets.markerWidth)
    }

    /// PencilKit ink type for this style. Only `.pen` and `.marker` are used (DESIGN.md §3.9), so
    /// `maximumSupportedContentVersion = .version1` never has to reject our own strokes.
    var pkInkType: PKInkingTool.InkType {
        tool == .marker ? .marker : .pen
    }

    var platformColor: InkPlatformColor {
        InkColors.color(hex: colorHex)
            ?? InkColors.color(hex: InkPresets.fallbackColorHex(for: tool))
            ?? InkPlatformColor.black
    }

    /// The ink a stored stroke of this style is rebuilt with (width lives in the stroke points).
    var pkInk: PKInk {
        PKInk(pkInkType, color: platformColor)
    }

    /// The tool the canvas draws new strokes with.
    var pkInkingTool: PKInkingTool {
        PKInkingTool(pkInkType, color: platformColor, width: width)
    }
}

extension CanvasTool {
    var isEraser: Bool {
        if case .eraser = self { return true }
        return false
    }

    var style: InkStyle? {
        if case .ink(let style) = self { return style }
        return nil
    }

    /// A tool that draws no ink (lasso / eventRect). While one is selected the overlay view takes
    /// the pen and `PKCanvasView.drawingGestureRecognizer` is disabled (DESIGN.md §3.6).
    var isOverlayTool: Bool {
        switch self {
        case .lasso, .eventRect:
            return true
        case .ink, .eraser:
            return false
        }
    }

    /// The PencilKit tool for `PKCanvasView.tool`. The eraser is the *vector* eraser: it removes a
    /// whole stroke on touch, exactly like the web version (no partial erasing, DESIGN.md §3.6).
    /// For the lasso and the 予定 tool drawing is disabled, so the canvas tool does not matter: the
    /// canvas keeps whatever ink tool it had (the coordinator does not set it); this is the default pen.
    var pkTool: PKTool {
        switch self {
        case .ink(let style):
            return style.pkInkingTool
        case .eraser:
            return PKEraserTool(.vector, width: InkPresets.eraserWidth)
        case .lasso, .eventRect:
            return InkPresets.defaultPen.pkInkingTool
        }
    }
}

// MARK: - Ink type ⇄ model tool

extension InkModel.InkTool {
    /// The model tool for a PencilKit ink. Anything that is not a marker is stored as a pen; with
    /// `maximumSupportedContentVersion = .version1` and our own tools this only ever sees pen / marker.
    init(inkType: PKInkingTool.InkType) {
        self = inkType == .marker ? .marker : .pen
    }
}

// MARK: - Colours

/// "#rrggbb" ⇄ platform colour, lower-case, alpha ignored (the marker's translucency is PencilKit's).
enum InkColors {
    /// Lower-case "#rrggbb" for "#rgb" / "#rrggbb" input (either case); nil for anything else.
    static func normalized(_ hex: String) -> String? {
        guard let (r, g, b) = components(hex: hex) else { return nil }
        return string(r: r, g: g, b: b)
    }

    /// RGB components 0...1 parsed from "#rgb" or "#rrggbb".
    static func components(hex: String) -> (r: CGFloat, g: CGFloat, b: CGFloat)? {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("#") else { return nil }
        text.removeFirst()
        let scalars = Array(text.unicodeScalars)
        let digits: [Int]
        switch scalars.count {
        case 3:
            let nibbles = scalars.map(hexValue)
            guard !nibbles.contains(nil) else { return nil }
            digits = nibbles.map { $0! * 17 }
        case 6:
            var out: [Int] = []
            for i in stride(from: 0, to: 6, by: 2) {
                guard let hi = hexValue(scalars[i]), let lo = hexValue(scalars[i + 1]) else { return nil }
                out.append(hi * 16 + lo)
            }
            digits = out
        default:
            return nil
        }
        return (CGFloat(digits[0]) / 255, CGFloat(digits[1]) / 255, CGFloat(digits[2]) / 255)
    }

    /// "#rrggbb" (lower-case) from components 0...1 (clamped).
    static func string(r: CGFloat, g: CGFloat, b: CGFloat) -> String {
        func byte(_ v: CGFloat) -> Int {
            let clamped = min(max(v, 0), 1)
            return Int((clamped * 255).rounded())
        }
        return String(format: "#%02x%02x%02x", byte(r), byte(g), byte(b))
    }

    static func color(hex: String) -> InkPlatformColor? {
        guard let (r, g, b) = components(hex: hex) else { return nil }
        #if canImport(UIKit)
        return UIColor(red: r, green: g, blue: b, alpha: 1)
        #else
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
        #endif
    }

    /// Lower-case "#rrggbb" of a colour as PencilKit reports it on a stroke; nil if it has no RGB form.
    /// On iOS the colour is resolved for the light appearance first: PencilKit may hand back a
    /// dynamic colour, and the paper is always light (DESIGN.md §3.2 switches ink inversion off).
    static func hex(of color: InkPlatformColor) -> String? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        guard resolved.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            var white: CGFloat = 0
            guard resolved.getWhite(&white, alpha: &a) else { return nil }
            return string(r: white, g: white, b: white)
        }
        return string(r: r, g: g, b: b)
        #else
        guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
        rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        return string(r: r, g: g, b: b)
        #endif
    }

    private static func hexValue(_ scalar: Unicode.Scalar) -> Int? {
        switch scalar {
        case "0"..."9": return Int(scalar.value - 48)
        case "a"..."f": return Int(scalar.value - 97 + 10)
        case "A"..."F": return Int(scalar.value - 65 + 10)
        default: return nil
        }
    }
}
