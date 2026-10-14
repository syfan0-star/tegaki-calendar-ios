import InkModel
import Layout
import PencilKit
import UIKit

/// Pictures of ledger strokes (M3B_CONTRACT.md §3.5): the 「書いた内容」 image of the create sheet
/// (担当 U calls `render` with `page.strokes` and `layout.cells`) and the transparent picture that
/// follows the pen while a selection is moved (`image`, used by `InkOverlayView`).
///
/// The strokes are drawn by PencilKit itself (`PKDrawing.image(from:scale:)`), rebuilt exactly as the
/// canvas rebuilds them (`StrokeGeometry.makePKStroke`), so the picture matches what is on the paper;
/// the marker keeps PencilKit's own translucency.
enum InkSnapshot {
    /// The create sheet's picture is at most this big (pt).
    static let defaultMaxSize = CGSize(width: 480, height: 240)
    /// The move picture never asks the GPU for more pixels than this (a page-wide selection at 4×
    /// zoom on a Retina screen would otherwise need hundreds of MB); above it the picture is rendered
    /// at a lower scale and stretched by its layer.
    static let maxImagePixels: CGFloat = 12_000_000

    /// The strokes on white (`#ffffff`), cropped to their bounds + 12 lu and fitted into `maxSize`
    /// (pt) without enlarging more than 4× (`LassoGeometry.snapshotLayout`). nil when nothing can be
    /// drawn: no stroke, or only strokes whose cell `cells` does not have (or without points).
    static func render(strokes: [InkStroke], cells: [CellKey: CGRect], maxSize: CGSize = defaultMaxSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        let drawable = strokes.filter { cells[$0.cell] != nil && !$0.points.isEmpty }
        let boxes = drawable.compactMap { s in cells[s.cell].flatMap { s.paperBounds(cellOrigin: $0.origin) } }
        guard let bbox = LassoGeometry.union(boxes),
              let layout = LassoGeometry.snapshotLayout(bbox: bbox, maxSize: maxSize) else { return nil }
        let pk = pkStrokes(drawable, cells: cells)
        guard !pk.isEmpty else { return nil }
        let pixelScale = scale.isFinite && scale > 0 ? scale : 1
        let ink = drawingImage(PKDrawing(strokes: pk), from: layout.rect, scale: layout.zoom * pixelScale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = pixelScale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: layout.size, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: layout.size))
            ink.draw(in: CGRect(x: 0, y: 0, width: layout.rect.width * layout.zoom, height: layout.rect.height * layout.zoom))
        }
    }

    /// The strokes on a transparent ground: the paper rect `bounds` (lu) drawn at `zoom` pt per lu
    /// and `scale` px per pt (the picture that follows the pen during a selection move; its `size`
    /// is `bounds.size` in points). nil when nothing can be drawn or the arguments are unusable.
    static func image(strokes: [InkStroke], cells: [CellKey: CGRect], bounds: CGRect, zoom: CGFloat, scale: CGFloat) -> UIImage? {
        guard bounds.origin.x.isFinite, bounds.origin.y.isFinite, bounds.width.isFinite, bounds.height.isFinite,
              bounds.width > 0, bounds.height > 0, zoom.isFinite, zoom > 0 else { return nil }
        let pk = pkStrokes(strokes, cells: cells)
        guard !pk.isEmpty else { return nil }
        let pixelScale = scale.isFinite && scale > 0 ? scale : 1
        let pixels = bounds.width * zoom * bounds.height * zoom * pixelScale * pixelScale
        let effectiveScale = pixels > maxImagePixels ? pixelScale * (maxImagePixels / pixels).squareRoot() : pixelScale
        return drawingImage(PKDrawing(strokes: pk), from: bounds, scale: max(zoom * effectiveScale, 0.01))
    }

    /// Ledger strokes → `PKStroke`s placed at their cells: the same conversion as the canvas
    /// (`StrokeGeometry.makePKStroke`; `transform` is the translation to the cell's top-left corner).
    /// Strokes whose cell `cells` does not have, or without points, are skipped.
    static func pkStrokes(_ strokes: [InkStroke], cells: [CellKey: CGRect]) -> [PKStroke] {
        var map: [StrokeFingerprint: String] = [:]
        var out: [PKStroke] = []
        out.reserveCapacity(strokes.count)
        for s in strokes {
            guard !s.points.isEmpty, let cell = cells[s.cell] else { continue }
            let pk = StrokeGeometry.makePKStroke(s, cellOrigin: cell.origin, avoiding: map)
            map[StrokeGeometry.fingerprint(of: pk)] = s.id
            out.append(pk)
        }
        return out
    }

    /// `PKDrawing.image(from:scale:)` under the light appearance: PencilKit adapts ink colours to the
    /// current appearance, and the paper is always light (DESIGN.md §3.2).
    private static func drawingImage(_ drawing: PKDrawing, from rect: CGRect, scale: CGFloat) -> UIImage {
        var image = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: rect, scale: scale)
        }
        return image
    }
}
