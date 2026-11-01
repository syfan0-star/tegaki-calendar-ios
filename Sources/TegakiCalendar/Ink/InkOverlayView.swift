import InkModel
import Layout
import UIKit
import UIKit.UIGestureRecognizerSubclass

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
/// while `tool.isOverlayTool`. It takes no touch itself (`hitTest` is always nil): every touch goes
/// to the canvas below (finger scroll, pinch, finger taps), and the overlay's input arrives through
/// two recognisers on the container. Since M4c (M4C_CONTRACT §2.2 F2) a finger comes through
/// `InkFingerGestureRecognizer` (`beginFinger` / `moveFinger` / `endFinger` / `cancelFinger`), which
/// fails as soon as a second finger touches — a touch the overlay took could never reach the scroll
/// view again, so a second finger could not pinch. 1.1 fix (TestFlight build 12, 確認 12; docs/M7A.md
/// ずれ 47): the Pencil comes through `InkPencilGestureRecognizer` (`beginPencil` / `movePencil` /
/// `endPencil` / `cancelPencil`). Before, the overlay's own `hitTest` took the touch when the event
/// held a Pencil touch, but UIKit hit-tests a touch that begins before it adds it to the event, so
/// the Pencil never reached the lasso or the 予定 tool.
///
/// One contact at a time: a second one is ignored, and the Pencil takes over from a finger.
/// Positions are turned into paper coordinates with the canvas's `contentOffset` and `zoomScale`;
/// what is drawn is sized in screen points, whatever the zoom.
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
    /// Since M4c the finger comes through the container's recogniser (enabled by the coordinator
    /// under the same condition); `beginFinger` checks this as well.
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

    /// What is on the overlay: the Pencil or a finger (each through its recogniser on the container).
    private enum Contact {
        case pencil
        case finger
    }

    private var gesture: Gesture?
    private var contact: Contact?
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

    /// Never takes a touch (1.1 fix, docs/M7A.md ずれ 47). UIKit hit-tests a touch that begins before it
    /// adds the touch to the event, so `event.allTouches` cannot tell the Pencil from a finger here (in
    /// 1.1 build 12 this view took the Pencil only when the event already held one, which it never
    /// did on a device: the Pencil could not lasso or drag a 予定 rect). Every touch goes to the canvas
    /// below; the Pencil reaches this view through `InkPencilGestureRecognizer`, a writing finger
    /// through `InkFingerGestureRecognizer` (F2), both on the container.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }

    // MARK: - The Pencil (through InkPencilGestureRecognizer)

    /// The Pencil touched at `view` (overlay = container coordinates). Only with an overlay tool and
    /// while the overlay takes input (never read only). A second Pencil contact is ignored; the Pencil
    /// wins over a finger (a palm) that is already tracked.
    func beginPencil(at view: CGPoint) {
        guard tool.isOverlayTool, isUserInteractionEnabled else { return }
        switch contact {
        case .pencil?:
            return
        case .finger?:
            cancelGesture()
        case nil:
            break
        }
        begin(.pencil, at: paperPoint(fromView: view))
    }

    /// The Pencil moved to `view`; `coalesced` are the intermediate positions (the last is `view`).
    func movePencil(to view: CGPoint, coalesced: [CGPoint]) {
        guard case .pencil? = contact, gesture != nil else { return }
        let points = coalesced.isEmpty ? [view] : coalesced
        move(samples: points.map { paperPoint(fromView: $0) })
    }

    /// The Pencil lifted at `view`: the gesture ends normally (a lasso closes, a 予定 drag reports).
    func endPencil(at view: CGPoint) {
        guard case .pencil? = contact else { return }
        finishGesture(at: paperPoint(fromView: view))
    }

    /// The Pencil's touch was cancelled: the same as `cancelGesture`.
    func cancelPencil() {
        guard case .pencil? = contact else { return }
        cancelGesture()
    }

    // MARK: - The finger (through InkFingerGestureRecognizer, F2)

    /// A finger touched at `view` (overlay = container coordinates). Ignored while the Pencil is on
    /// the overlay, while another finger is tracked, when the finger may not write, or with a tool
    /// that is not an overlay tool.
    func beginFinger(at view: CGPoint) {
        guard tool.isOverlayTool, allowFinger, contact == nil else { return }
        begin(.finger, at: paperPoint(fromView: view))
    }

    /// The finger moved to `view`; `coalesced` are the intermediate positions (the last is `view`).
    func moveFinger(to view: CGPoint, coalesced: [CGPoint]) {
        guard case .finger? = contact, gesture != nil else { return }
        let points = coalesced.isEmpty ? [view] : coalesced
        move(samples: points.map { paperPoint(fromView: $0) })
    }

    /// The finger lifted at `view`: the gesture ends normally (a lasso closes, a 予定 drag reports).
    func endFinger(at view: CGPoint) {
        guard case .finger? = contact else { return }
        finishGesture(at: paperPoint(fromView: view))
    }

    /// The finger's touch was cancelled, or a second finger touched (a scroll or a pinch begins):
    /// the same as `cancelGesture`.
    func cancelFinger() {
        guard case .finger? = contact else { return }
        cancelGesture()
    }

    /// The contact moved through `samples` (paper lu, the last one current).
    private func move(samples: [CGPoint]) {
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

    /// `newContact` touched at `p` (paper): a move or a lasso, or a 予定 rect, by the tool.
    private func begin(_ newContact: Contact, at p: CGPoint) {
        switch tool {
        case .lasso:
            contact = newContact
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
            contact = newContact
            gesture = .event(start: p, current: p, maxDistance: 0, preview: nil)
            updateEventPreview()
        case .ink, .eraser:
            return
        }
        delegate?.overlay(self, isTracking: true)
        setNeedsDisplay()
    }

    /// The pen (or the finger) lifted at `p` (paper): the gesture ends normally.
    private func finishGesture(at p: CGPoint) {
        guard let g = gesture else {
            contact = nil
            return
        }
        gesture = nil
        contact = nil
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
        contact = nil
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
            contact = nil
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

// MARK: - The finger recogniser (F2)

/// Forwards one finger's (`.direct`) input to the overlay (M4C_CONTRACT §2.2 F2). It lives on the
/// `InkCanvasContainerView`, so it sees the touches that are hit-tested to the canvas, and the
/// canvas's pan and the coordinator's single tap `require(toFail:)` it. Its states follow
/// `UILongPressGestureRecognizer`'s: while one finger is down it stays `.possible` (a `.possible`
/// recogniser still receives `touchesMoved`) and forwards the touches; when the finger lifts it
/// becomes `.ended` (recognised: the pan and the tap waiting on it fail, whether or not the finger
/// moved — the 予定 tool's `isTap`); when a second finger touches it becomes `.failed` (the overlay
/// gets `cancelFinger`, and UIKit, which was holding the touches for the pan, lets the pan and the
/// pinch go on with the same touch sequence). It must never go `.began` on touch-down: a recognised
/// recogniser makes the pan fail for the whole sequence, and failing later would not revive it.
/// The Pencil's touches are not its business (`allowedTouchTypes` is `.direct`; the Pencil comes
/// through `InkPencilGestureRecognizer`).
@MainActor
final class InkFingerGestureRecognizer: UIGestureRecognizer {
    /// The overlay the finger is forwarded to (positions are `location(in: overlay)`).
    weak var overlay: InkOverlayView?
    private var tracked: UITouch?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard state == .possible else { return }
        for touch in touches where touch.type == .direct {
            if let tracked {
                guard touch !== tracked else { continue }
                // A second finger: a scroll or a pinch. Fail, so the pan / pinch go on with these touches.
                self.tracked = nil
                overlay?.cancelFinger()
                state = .failed
                return
            }
            guard let overlay else {
                state = .failed
                return
            }
            tracked = touch
            overlay.beginFinger(at: touch.location(in: overlay))
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard state == .possible, let tracked, touches.contains(tracked), let overlay else { return }
        let coalesced = (event.coalescedTouches(for: tracked) ?? [tracked]).map { $0.location(in: overlay) }
        overlay.moveFinger(to: tracked.location(in: overlay), coalesced: coalesced)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard state == .possible, let tracked, touches.contains(tracked) else { return }
        if let overlay {
            overlay.endFinger(at: tracked.location(in: overlay))
        }
        self.tracked = nil
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        guard let tracked, touches.contains(tracked) else { return }
        overlay?.cancelFinger()
        self.tracked = nil
        if state == .possible {
            state = .failed
        }
    }

    override func reset() {
        super.reset()
        tracked = nil
    }
}

// MARK: - The Pencil recogniser (1.1 fix)

/// 1.1 fix (TestFlight build 12, 確認 12; docs/M7A.md ずれ 47): forwards the Apple Pencil's input to the
/// overlay while the lasso / 予定 tool is up (the coordinator enables it then, never read only). It
/// lives on the `InkCanvasContainerView`, so it sees the Pencil's touches that were hit-tested to the
/// canvas (the overlay takes none: a touch's type cannot be told during hit-testing). It follows one
/// Pencil touch: `beginPencil` on touch-down, `movePencil` with the coalesced positions, `endPencil` on
/// the lift. It never recognises — it stays `.possible` while the Pencil is down and becomes `.failed`
/// when it lifts or is cancelled (never `.began` or `.ended`) — lets the touches through at once,
/// prevents nothing and is prevented by nothing, so the canvas's own recognisers (the finger's
/// scroll, pinch and taps) never wait for it. `allowedTouchTypes` is `.pencil`: fingers are not its
/// business.
@MainActor
final class InkPencilGestureRecognizer: UIGestureRecognizer {
    /// The overlay the Pencil is forwarded to (positions are `location(in: overlay)`).
    weak var overlay: InkOverlayView?
    private var tracked: UITouch?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard state == .possible, tracked == nil, let overlay,
              let touch = touches.first(where: { $0.type == .pencil }) else { return }
        tracked = touch
        overlay.beginPencil(at: touch.location(in: overlay))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard state == .possible, let tracked, touches.contains(tracked), let overlay else { return }
        let coalesced = (event.coalescedTouches(for: tracked) ?? [tracked]).map { $0.location(in: overlay) }
        overlay.movePencil(to: tracked.location(in: overlay), coalesced: coalesced)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard let tracked, touches.contains(tracked) else { return }
        self.tracked = nil
        if let overlay {
            overlay.endPencil(at: tracked.location(in: overlay))
        }
        if state == .possible {
            state = .failed
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        guard let tracked, touches.contains(tracked) else { return }
        self.tracked = nil
        overlay?.cancelPencil()
        if state == .possible {
            state = .failed
        }
    }

    /// A sequence UIKit ended some other way (the recogniser was turned off with the tool, the view
    /// left the window) leaves no gesture behind on the overlay.
    override func reset() {
        super.reset()
        if tracked != nil {
            overlay?.cancelPencil()
        }
        tracked = nil
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }
}
