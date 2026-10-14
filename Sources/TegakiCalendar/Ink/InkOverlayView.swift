import InkModel
import Layout
import UIKit

/// What the overlay asks of its owner (`InkCanvasView.Coordinator`): everything that touches the
/// ledger or the canvas. Geometry and drawing stay in the overlay; strokes stay in the coordinator.
@MainActor
protocol InkOverlayViewDelegate: AnyObject {
    /// The pen touched the overlay outside the selection (a lasso starts): the selection is cleared.
    func overlayDidTouchOutsideSelection(_ overlay: InkOverlayView)
    /// A lasso closed into `polygon` (paper lu; closed and simplified): select the strokes inside it.
    func overlay(_ overlay: InkOverlayView, didFinishLasso polygon: [CGPoint])
    /// The selection starts moving: take the selected strokes off the canvas and return their picture
    /// (`InkSnapshot.image` of the selection's bbox at the canvas zoom). nil when there is nothing to move.
    func overlayWillBeginMove(_ overlay: InkOverlayView) -> UIImage?
    /// The move ended with `delta` (paper lu, rounded to 0.1; may be zero): commit it, or put the
    /// strokes back where they were.
    func overlay(_ overlay: InkOverlayView, didEndMoveBy delta: CGVector)
    /// The move was cancelled: put the strokes back where they were.
    func overlayDidCancelMove(_ overlay: InkOverlayView)
    /// The 予定 tool's drag rect (paper, normalized) → the snapped rect to draw; nil draws the raw rect.
    func overlay(_ overlay: InkOverlayView, previewFor rect: CGRect) -> CGRect?
    /// The 予定 tool's drag ended (`rect` paper, normalized; `isTap` when the pen hardly moved).
    func overlay(_ overlay: InkOverlayView, didEndEvent rect: CGRect, isTap: Bool)
    /// The pen (or finger) is on the overlay / has left it. The coordinator treats it like the pen
    /// on the paper: layout changes wait until 300 ms after it lifts.
    func overlay(_ overlay: InkOverlayView, isTracking: Bool)
}

/// The input view of the lasso and the 予定 tool (M3B_CONTRACT.md §3.4; the look of the web version's
/// `js/ink/surface.js`). It lies over the `PKCanvasView`, fills the container, and is enabled only
/// while `tool.isOverlayTool`. Its `hitTest` takes the Pencil (and the finger when `allowFinger`) and
/// lets everything else fall through to the canvas (finger scroll, pinch, finger taps).
///
/// Input is tracked with `touchesBegan/Moved/Ended/Cancelled`: one contact at a time (a second one is
/// ignored; the Pencil takes over from a finger). Positions are turned into paper coordinates with
/// the canvas's `contentOffset` and `zoomScale`; what is drawn is sized in screen points, whatever
/// the zoom.
///
/// | tool | gesture |
/// | --- | --- |
/// | lasso, touch inside the selection box (+12 pt) | **move**: after 6 pt the selected strokes leave the canvas and their picture follows the pen (`LassoGeometry.clampedMoveDelta` keeps the box on the paper, 0.1 lu steps); lift → `didEndMoveBy` |
/// | lasso, elsewhere | the selection is cleared, a **lasso** is drawn (a vertex every 2 lu); lift → `LassoGeometry.lassoPolygon` → `didFinishLasso` (a tap: nothing more) |
/// | eventRect | a **rect** from the first point; every move asks `previewFor` and draws the answer; lift → `didEndEvent(rect, isTap: maxDistance < 8 lu)` |
@MainActor
final class InkOverlayView: UIView {
    weak var delegate: InkOverlayViewDelegate?
    /// The scroll view (the canvas) whose `contentOffset` / `zoomScale` map this view onto the paper.
    weak var scrollView: UIScrollView?
    /// The canvas tool. Only `.lasso` and `.eventRect` take input; any change cancels the gesture.
    var tool: CanvasTool = .ink(InkPresets.defaultPen) {
        didSet {
            guard tool != oldValue else { return }
            cancelGesture()
            isUserInteractionEnabled = tool.isOverlayTool
            setNeedsDisplay()
        }
    }
    /// Whether a finger is also accepted (otherwise only the Pencil; fingers scroll the canvas).
    var allowFinger = false
    /// The paper size (lu): a move never takes the selection box off the paper.
    var pageSize: CGSize = .zero
    /// The bounds of the selected strokes (paper lu); nil = no selection. Set by the coordinator.
    /// A move in progress is cancelled when it changes under it (the selection was reconciled).
    var selectionBBox: CGRect? {
        didSet {
            guard selectionBBox != oldValue else { return }
            if case .move = gesture { cancelGesture() }
            setNeedsDisplay()
        }
    }

    // Look (screen points, like the web version's overlay metrics)
    static let accent = UIColor(red: 37 / 255.0, green: 99 / 255.0, blue: 235 / 255.0, alpha: 1)
    static let lineWidth: CGFloat = 1.5
    static let dash: [CGFloat] = [6, 4]
    /// The dashed box is drawn this much outside the selection's bbox.
    static let selectionPad: CGFloat = 6
    /// A touch this far outside the bbox still grabs the selection (a move).
    static let selectionHitPad: CGFloat = 12
    static let selectionCornerRadius: CGFloat = 4
    static let previewCornerRadius: CGFloat = 6
    static let previewFill = UIColor(red: 37 / 255.0, green: 99 / 255.0, blue: 235 / 255.0, alpha: 0.18)
    static let previewStroke = UIColor(red: 37 / 255.0, green: 99 / 255.0, blue: 235 / 255.0, alpha: 0.85)
    /// A drag inside the selection shorter than this (screen pt) is the wobble of a Pencil tap.
    static let moveStartDistance: CGFloat = 6
    /// A 予定 drag whose farthest point is closer than this (lu) is a tap (web EVENT_TAP_DISTANCE).
    static let eventTapDistance: CGFloat = 8

    private enum Gesture {
        case lasso(points: [CGPoint])
        case move(start: CGPoint, delta: CGVector, active: Bool)
        case event(start: CGPoint, current: CGPoint, maxDistance: CGFloat, preview: CGRect?)
    }

    private var gesture: Gesture?
    private var activeTouch: UITouch?
    /// The picture of the strokes being moved (transparent, multiplied like the canvas layer so the
    /// marker stays a highlighter over the paper's text).
    private let moveLayer = CALayer()
    /// Whether the last `draw(_:)` painted anything (so a scroll with nothing to show costs nothing).
    private var drewSomething = false

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = false
        moveLayer.isHidden = true
        moveLayer.contentsGravity = .resize
        moveLayer.compositingFilter = "multiplyBlendMode"
        layer.addSublayer(moveLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Coordinates

    private var zoom: CGFloat {
        let z = scrollView?.zoomScale ?? 1
        return z.isFinite && z > 0 ? z : 1
    }

    private var contentOffset: CGPoint {
        scrollView?.contentOffset ?? .zero
    }

    /// Overlay (= container) point → paper lu.
    func paperPoint(fromView p: CGPoint) -> CGPoint {
        let z = zoom
        let o = contentOffset
        return CGPoint(x: (p.x + o.x) / z, y: (p.y + o.y) / z)
    }

    /// Paper rect (lu) → overlay rect (pt).
    func viewRect(fromPaper r: CGRect) -> CGRect {
        let z = zoom
        let o = contentOffset
        return CGRect(x: r.minX * z - o.x, y: r.minY * z - o.y, width: r.width * z, height: r.height * z)
    }

    private func viewPoint(fromPaper p: CGPoint) -> CGPoint {
        let z = zoom
        let o = contentOffset
        return CGPoint(x: p.x * z - o.x, y: p.y * z - o.y)
    }

    /// The canvas scrolled or zoomed: the picture and the drawing follow (called by the coordinator).
    func viewportChanged() {
        layoutMoveLayer()
        if drewSomething || gesture != nil || selectionBBox != nil {
            setNeedsDisplay()
        }
    }

    // MARK: - Hit testing

    /// Takes the touch only for the Pencil, or for a finger when `allowFinger`; anything else (and a
    /// touch whose type cannot be told) goes to the canvas below, which scrolls and pinches with it.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01, tool.isOverlayTool, bounds.contains(point) else { return nil }
        guard let touches = event?.allTouches, !touches.isEmpty else { return nil }
        let fresh = touches.filter { $0.phase == .began }
        let candidates = fresh.isEmpty ? Array(touches) : Array(fresh)
        if candidates.contains(where: { $0.type == .pencil }) { return self }
        if allowFinger, candidates.contains(where: { $0.type == .direct }) { return self }
        return nil
    }

    private func accepts(_ touch: UITouch) -> Bool {
        switch touch.type {
        case .pencil: return true
        case .direct: return allowFinger
        default: return false
        }
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard accepts(touch), tool.isOverlayTool else { continue }
            if let active = activeTouch {
                // The Pencil wins over a finger (a palm) that is already tracked; a second contact
                // of the same kind is ignored.
                guard touch.type == .pencil, active.type != .pencil else { continue }
                cancelGesture()
            }
            begin(touch)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let active = activeTouch, touches.contains(active), gesture != nil else { return }
        let coalesced = event?.coalescedTouches(for: active) ?? [active]
        let samples = coalesced.map { paperPoint(fromView: $0.location(in: self)) }
        guard let last = samples.last else { return }
        switch gesture {
        case .lasso(var points):
            for s in samples where Self.shouldAppend(s, to: points) { points.append(s) }
            gesture = .lasso(points: points)
            setNeedsDisplay()
        case .move(let start, _, let wasActive):
            let rawDx = last.x - start.x
            let rawDy = last.y - start.y
            if !wasActive {
                // Screen distance: at month zoom (≈ 0.6) a few lu are only the drift of a Pencil tap.
                guard (rawDx * rawDx + rawDy * rawDy).squareRoot() * zoom >= Self.moveStartDistance else { return }
                guard beginMovePicture() else { return }
            }
            gesture = .move(start: start, delta: clampedDelta(dx: rawDx, dy: rawDy), active: true)
            layoutMoveLayer()
            setNeedsDisplay()
        case .event(let start, _, var maxDistance, _):
            for s in samples {
                maxDistance = max(maxDistance, ((s.x - start.x) * (s.x - start.x) + (s.y - start.y) * (s.y - start.y)).squareRoot())
            }
            gesture = .event(start: start, current: last, maxDistance: maxDistance, preview: nil)
            updateEventPreview()
        case nil:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let active = activeTouch, touches.contains(active) else { return }
        finishGesture(at: paperPoint(fromView: active.location(in: self)))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let active = activeTouch, touches.contains(active) else { return }
        cancelGesture()
    }

    private func begin(_ touch: UITouch) {
        let p = paperPoint(fromView: touch.location(in: self))
        switch tool {
        case .lasso:
            activeTouch = touch
            let pad = Self.selectionHitPad / zoom
            if let bbox = selectionBBox, bbox.insetBy(dx: -pad, dy: -pad).contains(p) {
                gesture = .move(start: p, delta: .zero, active: false)
            } else {
                // A tap or a new lasso outside the selection deselects (the lasso's own result, if
                // any, becomes the new selection when the pen lifts).
                delegate?.overlayDidTouchOutsideSelection(self)
                gesture = .lasso(points: [p])
            }
        case .eventRect:
            activeTouch = touch
            gesture = .event(start: p, current: p, maxDistance: 0, preview: nil)
            updateEventPreview()
        case .ink, .eraser:
            return
        }
        delegate?.overlay(self, isTracking: true)
        setNeedsDisplay()
    }

    /// The pen lifted at `p` (paper): the gesture ends normally.
    private func finishGesture(at p: CGPoint) {
        guard let g = gesture else {
            activeTouch = nil
            return
        }
        gesture = nil
        activeTouch = nil
        switch g {
        case .lasso(var points):
            if Self.shouldAppend(p, to: points) { points.append(p) }
            setNeedsDisplay()
            if let polygon = LassoGeometry.lassoPolygon(points) {
                delegate?.overlay(self, didFinishLasso: polygon)
            }
        case .move(let start, _, let active):
            hideMovePicture()
            setNeedsDisplay()
            if active {
                delegate?.overlay(self, didEndMoveBy: clampedDelta(dx: p.x - start.x, dy: p.y - start.y))
            }
        case .event(let start, _, var maxDistance, _):
            maxDistance = max(maxDistance, ((p.x - start.x) * (p.x - start.x) + (p.y - start.y) * (p.y - start.y)).squareRoot())
            setNeedsDisplay()
            delegate?.overlay(self, didEndEvent: Self.normalizedRect(start, p), isTap: maxDistance < Self.eventTapDistance)
        }
        delegate?.overlay(self, isTracking: false)
    }

    /// Drops the gesture in progress (the touch was cancelled, the tool or the page changed, the
    /// selection went away). A move puts the strokes back; a lasso or a 予定 drag reports nothing.
    func cancelGesture() {
        let g = gesture
        gesture = nil
        activeTouch = nil
        guard let g else { return }
        if case .move(_, _, let active) = g {
            hideMovePicture()
            if active { delegate?.overlayDidCancelMove(self) }
        }
        setNeedsDisplay()
        delegate?.overlay(self, isTracking: false)
    }

    // MARK: - Gesture helpers

    /// A lasso vertex is stored only 2 lu or more away from the previous one (web shouldAppendPoint).
    private static func shouldAppend(_ p: CGPoint, to points: [CGPoint]) -> Bool {
        guard p.x.isFinite, p.y.isFinite else { return false }
        guard let last = points.last else { return true }
        let dx = p.x - last.x
        let dy = p.y - last.y
        return dx * dx + dy * dy >= LassoGeometry.minStep * LassoGeometry.minStep
    }

    /// The move delta limited so the selection box stays on the paper, in 0.1 lu steps.
    private func clampedDelta(dx: CGFloat, dy: CGFloat) -> CGVector {
        let bbox = selectionBBox ?? .zero
        let d = LassoGeometry.clampedMoveDelta(bbox: bbox, dx: dx, dy: dy, pageSize: pageSize)
        return CGVector(dx: Self.round1(d.dx), dy: Self.round1(d.dy))
    }

    private static func round1(_ v: CGFloat) -> CGFloat {
        guard v.isFinite else { return 0 }
        let r = (v * 10).rounded() / 10
        return r == 0 ? 0 : r
    }

    private static func normalizedRect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    private func updateEventPreview() {
        guard case .event(let start, let current, let maxDistance, _) = gesture else { return }
        let raw = Self.normalizedRect(start, current)
        let snapped = delegate?.overlay(self, previewFor: raw)
        // The delegate may have ended the gesture (a tool change from the owner's side).
        guard case .event = gesture else { return }
        let preview = snapped ?? (raw.width > 0 && raw.height > 0 ? raw : nil)
        gesture = .event(start: start, current: current, maxDistance: maxDistance, preview: preview)
        setNeedsDisplay()
    }

    // MARK: - Move picture

    /// Asks the coordinator for the picture of the selection (which also takes the strokes off the
    /// canvas). false when there is nothing to move: the gesture is dropped.
    private func beginMovePicture() -> Bool {
        guard let image = delegate?.overlayWillBeginMove(self) else {
            gesture = nil
            activeTouch = nil
            delegate?.overlay(self, isTracking: false)
            return false
        }
        moveLayer.contents = image.cgImage
        moveLayer.isHidden = false
        layoutMoveLayer()
        return true
    }

    private func layoutMoveLayer() {
        guard !moveLayer.isHidden, let bbox = selectionBBox, case .move(_, let delta, true) = gesture else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        moveLayer.frame = viewRect(fromPaper: bbox.offsetBy(dx: delta.dx, dy: delta.dy))
        CATransaction.commit()
    }

    private func hideMovePicture() {
        moveLayer.isHidden = true
        moveLayer.contents = nil
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        drewSomething = false

        // The lasso in progress: a dashed polyline.
        if case .lasso(let points) = gesture, points.count >= 2 {
            let path = UIBezierPath()
            path.move(to: viewPoint(fromPaper: points[0]))
            for p in points.dropFirst() { path.addLine(to: viewPoint(fromPaper: p)) }
            path.lineWidth = Self.lineWidth
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            path.setLineDash(Self.dash, count: Self.dash.count, phase: 0)
            Self.accent.setStroke()
            path.stroke()
            drewSomething = true
        }

        // The selection box (shifted by the move in progress).
        if let bbox = selectionBBox {
            var r = bbox
            if case .move(_, let delta, true) = gesture { r = r.offsetBy(dx: delta.dx, dy: delta.dy) }
            let box = viewRect(fromPaper: r).insetBy(dx: -Self.selectionPad, dy: -Self.selectionPad)
            let path = UIBezierPath(roundedRect: box, cornerRadius: Self.selectionCornerRadius)
            path.lineWidth = Self.lineWidth
            path.setLineDash(Self.dash, count: Self.dash.count, phase: 0)
            Self.accent.setStroke()
            path.stroke()
            drewSomething = true
        }

        // The 予定 tool's preview.
        if case .event(_, _, _, let preview) = gesture, let p = preview, p.width > 0, p.height > 0 {
            let box = viewRect(fromPaper: p)
            let path = UIBezierPath(roundedRect: box, cornerRadius: Self.previewCornerRadius)
            Self.previewFill.setFill()
            path.fill()
            path.lineWidth = Self.lineWidth
            Self.previewStroke.setStroke()
            path.stroke()
            drewSomething = true
        }
    }
}
