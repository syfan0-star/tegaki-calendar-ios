import InkModel
import Layout
import PencilKit
import SwiftUI
import UIKit

/// The paper + ink surface for SwiftUI (contract §3, DESIGN.md §3.2).
///
/// ```
///   InkCanvasContainerView (clips)
///     ├─ PaperView (担当 U)   below: frame = (−contentOffset, layout.size × zoom), redrawn from `paper`
///     └─ PKCanvasView         above: transparent, fills the container, and *is* the scroll view
/// ```
/// `PKCanvasView` owns scrolling and pinch zoom; the paper view is a sibling that is moved under it
/// on every `scrollViewDidScroll` / `scrollViewDidZoom` (public API only, no subview tricks).
///
/// Rules implemented here:
/// - The drawing is never replaced while the Pencil is on the paper. Layout changes, page reloads
///   and undo / redo wait until 300 ms after the pen lifts, then land together with a scroll
///   compensation from `MonthLayoutEngine.scrollDelta` so the first visible row stays put.
/// - `page` is written back after every change the ledger records; a `page` that arrives from
///   outside (new month, merge) replaces the ledger's page.
/// - Finger taps (direct touches only) are reported in paper coordinates through `onTap`.
/// - PencilKit's own undo manager is emptied after every change; history is the ledger's.
struct InkCanvasView: UIViewRepresentable {
    var layout: MonthPageLayout
    var paper: PaperContent
    var tool: CanvasTool
    var allowFinger: Bool
    @Binding var page: InkPage
    /// A finger tap, in paper coordinates (lu). The owner resolves it with `layout.hit(at:)`.
    var onTap: (CGPoint) -> Void
    /// Handwriting may have crossed the bottom of its row (or an erased stroke may have been holding
    /// a row open). The owner re-runs the layout with fresh `page.inkBottoms()`.
    var onInkBoundsChanged: () -> Void
    /// Bump to undo / redo (the values themselves do not matter).
    var undoTrigger: Int
    var redoTrigger: Int
    /// Apple Pencil double tap / squeeze asked for pen ⇄ eraser. The owner flips `tool`.
    var onPencilToggle: () -> Void = {}
    /// Whether undo / redo currently have anything to do (for the toolbar buttons).
    var onHistoryChanged: (_ canUndo: Bool, _ canRedo: Bool) -> Void = { _, _ in }

    /// How long after the pen lifts a pending relayout is applied (contract §3).
    static let settleDelay: TimeInterval = 0.3

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> InkCanvasContainerView {
        let coordinator = context.coordinator
        // Integration point: PaperView belongs to 担当 U. Only this line assumes its initializer.
        let paperView = PaperView(content: paper)
        paperView.zoomScale = 1
        paperView.isUserInteractionEnabled = false

        let container = InkCanvasContainerView(paperView: paperView)
        let canvas = container.canvasView
        canvas.delegate = coordinator
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        // The paper is always light; never let PencilKit invert ink colours (DESIGN.md §3.2).
        canvas.overrideUserInterfaceStyle = .light
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.alwaysBounceVertical = true
        canvas.alwaysBounceHorizontal = false
        canvas.showsHorizontalScrollIndicator = false
        canvas.maximumSupportedContentVersion = .version1
        canvas.drawingPolicy = allowFinger ? .anyInput : .pencilOnly
        canvas.tool = tool.pkTool
        canvas.addInteraction(coordinator.pencilInteraction)
        canvas.addGestureRecognizer(coordinator.tapRecognizer)

        coordinator.attach(container)
        container.onLayout = { [weak coordinator] in coordinator?.containerDidLayout() }
        return container
    }

    func updateUIView(_ view: InkCanvasContainerView, context: Context) {
        context.coordinator.update(from: self)
    }

    static func dismantleUIView(_ view: InkCanvasContainerView, coordinator: Coordinator) {
        coordinator.detach()
    }
}

// MARK: - Container

/// Holds the paper view under the transparent canvas and reports its own size changes
/// (rotation, split view) so the fit-to-width zoom can be recomputed.
@MainActor
final class InkCanvasContainerView: UIView {
    let paperView: PaperView
    let canvasView = PKCanvasView()
    var onLayout: (() -> Void)?

    init(paperView: PaperView) {
        self.paperView = paperView
        super.init(frame: .zero)
        // Paper colour (web views.css) behind everything, so overscroll looks like more paper.
        backgroundColor = UIColor(red: 0xff / 255.0, green: 0xfd / 255.0, blue: 0xf8 / 255.0, alpha: 1)
        clipsToBounds = true
        addSubview(paperView)
        addSubview(canvasView)
        // The canvas is a separate layer above the paper, so PencilKit's translucent marker would
        // otherwise paint over the date numbers and event chips. Multiply-blending the whole canvas
        // layer with what is below makes the marker behave like a real highlighter (text stays
        // readable through it) while the dark pen colours look the same on the cream paper.
        canvasView.layer.compositingFilter = "multiplyBlendMode"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if canvasView.frame != bounds {
            canvasView.frame = bounds
        }
        onLayout?()
    }
}

// MARK: - Coordinator

extension InkCanvasView {
    /// Cheap identity of an `InkPage` value, to tell an echo of our own write-back from a page that
    /// really came from outside.
    struct PageSignature: Equatable, Sendable {
        let pageId: String
        let updatedAt: Int
        let strokeCount: Int
        let deletedCount: Int

        init(_ page: InkPage) {
            pageId = page.pageId
            updatedAt = page.updatedAt
            strokeCount = page.strokes.count
            deletedCount = page.deleted.count
        }
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
        var parent: InkCanvasView
        let ledger: InkLedger

        private weak var container: InkCanvasContainerView?
        private var canvas: PKCanvasView? { container?.canvasView }

        private let pencilHandler: PencilInteractionHandler
        /// Receives Apple Pencil double taps / squeezes. Added to the canvas in `makeUIView`.
        let pencilInteraction: UIPencilInteraction
        /// Finger taps on the paper (direct touches only). Added to the canvas in `makeUIView`.
        private(set) lazy var tapRecognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            recognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
            recognizer.delegate = self
            return recognizer
        }()

        /// The layout the canvas currently shows (strokes placed, contentSize set, paper drawn).
        private var appliedLayout: MonthPageLayout
        private var appliedTool: CanvasTool?
        private var publishedSignature: PageSignature
        private var lastUndoTrigger: Int
        private var lastRedoTrigger: Int

        private enum HistoryAction { case undo, redo }
        private var isUsingTool = false
        private var isSettling = false
        private var settleGeneration = 0
        /// The drawing must be rebuilt (layout geometry, page reload, undo / redo).
        private var pendingDrawing = false
        /// The paper content changed (titles, chips, lanes …); rebuilt together with the drawing.
        private var pendingPaper = false
        private var pendingHistory: [HistoryAction] = []
        /// A different page id arrived: scroll to the top instead of compensating.
        private var resetScroll = false
        private var isApplyingDrawing = false
        private var isUpdating = false
        private var hasInitialZoom = false

        init(parent: InkCanvasView) {
            self.parent = parent
            ledger = InkLedger(
                page: parent.page,
                layout: parent.layout,
                deviceId: UIDevice.current.identifierForVendor?.uuidString
            )
            appliedLayout = parent.layout
            publishedSignature = PageSignature(parent.page)
            lastUndoTrigger = parent.undoTrigger
            lastRedoTrigger = parent.redoTrigger
            // A local so nothing on `self` is read before super.init (two-phase initialisation).
            let handler = PencilInteractionHandler()
            pencilHandler = handler
            pencilInteraction = handler.makeInteraction()
            super.init()
            handler.onToggle = { [weak self] in self?.parent.onPencilToggle() }
        }

        // MARK: Lifecycle

        func attach(_ container: InkCanvasContainerView) {
            self.container = container
            let canvas = container.canvasView
            setDrawing(ledger.drawing(), on: canvas)
            canvas.contentSize = appliedLayout.size // zoom 1 until the first layout pass
            syncPaperFrame()
        }

        func detach() {
            settleGeneration += 1
            isSettling = false
            canvas?.delegate = nil
            container = nil
        }

        /// Called from `updateUIView`. Never touches the drawing directly: everything that would
        /// move the paper is queued and applied through `requestApply()`.
        func update(from newParent: InkCanvasView) {
            parent = newParent
            guard let canvas else { return }
            isUpdating = true
            defer { isUpdating = false }

            // 1. A page from outside (new month, merge, import)?
            let signature = PageSignature(newParent.page)
            if signature != publishedSignature {
                let samePage = signature.pageId == publishedSignature.pageId
                ledger.reload(page: newParent.page, keepHistory: samePage)
                publishedSignature = signature
                pendingDrawing = true
                if !samePage {
                    resetScroll = true
                    pendingHistory.removeAll()
                }
                notifyHistory()
            }

            // 2. Layout geometry (cells / size) and paper content.
            if !Self.sameGeometry(appliedLayout, newParent.layout) {
                pendingDrawing = true
            }
            if let paperView = container?.paperView, paperView.content != newParent.paper {
                pendingPaper = true
            }

            // 3. Tool and input policy apply at once (they affect the next stroke only).
            let policy: PKCanvasViewDrawingPolicy = newParent.allowFinger ? .anyInput : .pencilOnly
            if canvas.drawingPolicy != policy {
                canvas.drawingPolicy = policy
            }
            if appliedTool != newParent.tool {
                appliedTool = newParent.tool
                canvas.tool = newParent.tool.pkTool
            }

            // 4. Undo / redo requests.
            if newParent.undoTrigger != lastUndoTrigger {
                lastUndoTrigger = newParent.undoTrigger
                pendingHistory.append(.undo)
                pendingDrawing = true
            }
            if newParent.redoTrigger != lastRedoTrigger {
                lastRedoTrigger = newParent.redoTrigger
                pendingHistory.append(.redo)
                pendingDrawing = true
            }

            if pendingDrawing || pendingPaper {
                requestApply()
            }
        }

        // MARK: Applying queued work (pen up only)

        private func requestApply() {
            guard !isUsingTool, !isSettling else { return }
            applyPending()
        }

        private func applyPending() {
            guard let canvas, let container else { return }
            let drawingWork = pendingDrawing
            let paperWork = pendingPaper
            pendingDrawing = false
            pendingPaper = false
            guard drawingWork || paperWork else { return }

            var historyChanged = false
            for action in pendingHistory {
                switch action {
                case .undo: if ledger.undo() != nil { historyChanged = true }
                case .redo: if ledger.redo() != nil { historyChanged = true }
                }
            }
            pendingHistory.removeAll()

            let oldLayout = appliedLayout
            let newLayout = parent.layout
            let zoom = max(canvas.zoomScale, 0.0001)
            let topVisibleY = canvas.contentOffset.y / zoom
            let geometryChanged = !Self.sameGeometry(oldLayout, newLayout)

            if drawingWork {
                setDrawing(ledger.relayout(newLayout), on: canvas)
                appliedLayout = newLayout
                canvas.contentSize = Self.scaled(newLayout.size, by: zoom)
            }
            if container.paperView.content != parent.paper {
                container.paperView.content = parent.paper
            }
            syncPaperFrame()

            if resetScroll {
                resetScroll = false
                canvas.contentOffset = .zero
            } else if drawingWork, geometryChanged {
                let delta = MonthLayoutEngine.scrollDelta(old: oldLayout, new: newLayout, topVisibleY: topVisibleY)
                let target = CGPoint(x: canvas.contentOffset.x, y: (topVisibleY + delta) * zoom)
                canvas.contentOffset = clampedOffset(target)
            }
            syncPaperFrame()

            if historyChanged {
                publishPage()
            }
            notifyHistory()
        }

        private func setDrawing(_ drawing: PKDrawing, on canvas: PKCanvasView) {
            isApplyingDrawing = true
            canvas.drawing = drawing
            isApplyingDrawing = false
            ledger.bind(to: canvas.drawing)
            canvas.undoManager?.removeAllActions()
        }

        // MARK: Geometry

        /// Recomputes the fit-to-width zoom when the container's size changes (first layout,
        /// rotation, split view). A paper at fit width stays at fit width; a zoomed-in paper keeps
        /// the point at the centre of the viewport in the centre.
        func containerDidLayout() {
            guard let container, let canvas else { return }
            let viewport = container.bounds.size
            guard viewport.width > 0, viewport.height > 0 else { return }
            let fit = viewport.width / PaperSpec.monthWidth
            let oldMin = canvas.minimumZoomScale
            let oldZoom = max(canvas.zoomScale, 0.0001)
            if hasInitialZoom, abs(fit - oldMin) < 0.0005 {
                syncPaperFrame()
                return
            }
            let wasAtFit = !hasInitialZoom || abs(oldZoom - oldMin) < 0.0005
            let centerPaper = CGPoint(
                x: (canvas.contentOffset.x + viewport.width / 2) / oldZoom,
                y: (canvas.contentOffset.y + viewport.height / 2) / oldZoom
            )
            canvas.minimumZoomScale = fit
            canvas.maximumZoomScale = fit * 4
            let newZoom = wasAtFit ? fit : min(max(oldZoom, fit), fit * 4)
            canvas.zoomScale = newZoom
            canvas.contentSize = Self.scaled(appliedLayout.size, by: newZoom)
            if hasInitialZoom {
                canvas.contentOffset = clampedOffset(CGPoint(
                    x: centerPaper.x * newZoom - viewport.width / 2,
                    y: centerPaper.y * newZoom - viewport.height / 2
                ))
            } else {
                canvas.contentOffset = .zero
            }
            hasInitialZoom = true
            syncPaperFrame()
        }

        /// Keeps the paper view exactly under the canvas content.
        private func syncPaperFrame() {
            guard let container, let canvas else { return }
            let zoom = canvas.zoomScale
            let size = appliedLayout.size
            let offset = canvas.contentOffset
            let frame = CGRect(x: -offset.x, y: -offset.y, width: size.width * zoom, height: size.height * zoom)
            if container.paperView.zoomScale != zoom {
                container.paperView.zoomScale = zoom
            }
            if container.paperView.frame != frame {
                container.paperView.frame = frame
            }
        }

        private func clampedOffset(_ point: CGPoint) -> CGPoint {
            guard let container, let canvas else { return point }
            let maxX = max(0, canvas.contentSize.width - container.bounds.width)
            let maxY = max(0, canvas.contentSize.height - container.bounds.height)
            return CGPoint(x: min(max(point.x, 0), maxX), y: min(max(point.y, 0), maxY))
        }

        private static func sameGeometry(_ a: MonthPageLayout, _ b: MonthPageLayout) -> Bool {
            a.size == b.size && a.cells == b.cells
        }

        private static func scaled(_ size: CGSize, by zoom: CGFloat) -> CGSize {
            CGSize(width: size.width * zoom, height: size.height * zoom)
        }

        // MARK: Writing back

        private func publishPage() {
            let page = ledger.page
            let signature = PageSignature(page)
            publishedSignature = signature
            deliver { [weak self] in
                guard let self, self.publishedSignature == signature else { return } // superseded
                self.parent.page = page
            }
        }

        private func notifyHistory() {
            let canUndo = ledger.canUndo
            let canRedo = ledger.canRedo
            deliver { [weak self] in self?.parent.onHistoryChanged(canUndo, canRedo) }
        }

        /// Runs `block` now, or on the next main-actor turn when we are inside `updateUIView`
        /// (SwiftUI state must not change during a view update). A main-actor `Task` rather than
        /// `DispatchQueue.main.async`, so the closure's isolation is explicit (no Sendable-closure
        /// diagnostics whatever the concurrency checking level).
        private func deliver(_ block: @escaping () -> Void) {
            if isUpdating {
                Task { @MainActor in
                    block()
                }
            } else {
                block()
            }
        }

        // MARK: Finger taps

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let canvas else { return }
            // location(in:) of a scroll view is already in content coordinates (bounds.origin = contentOffset).
            let location = recognizer.location(in: canvas)
            let zoom = max(canvas.zoomScale, 0.0001)
            parent.onTap(CGPoint(x: location.x / zoom, y: location.y / zoom))
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard gestureRecognizer === tapRecognizer else { return true }
            return touch.type == .direct
        }

        // MARK: PKCanvasViewDelegate

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingDrawing else { return }
            // History is the ledger's; never let the system (3-finger swipe) undo through PencilKit.
            canvasView.undoManager?.removeAllActions()
            let change = ledger.applyCanvasChange(canvasView.drawing)
            guard !change.isEmpty else { return }
            publishPage()
            notifyHistory()
            let needsRoom = change.added.contains { ledger.needsMoreRoom($0) }
            if needsRoom || !change.removedIds.isEmpty {
                deliver { [weak self] in self?.parent.onInkBoundsChanged() }
            }
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            isUsingTool = true
            isSettling = false
            settleGeneration += 1
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            isUsingTool = false
            isSettling = true
            settleGeneration += 1
            let generation = settleGeneration
            let delay = InkCanvasView.settleDelay
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard let self, self.settleGeneration == generation, !self.isUsingTool else { return }
                self.isSettling = false
                self.applyPending()
            }
        }

        // MARK: UIScrollViewDelegate (inherited by PKCanvasViewDelegate)

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            syncPaperFrame()
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let canvas else { return }
            let size = Self.scaled(appliedLayout.size, by: canvas.zoomScale)
            if canvas.contentSize != size {
                canvas.contentSize = size
            }
            syncPaperFrame()
        }
    }
}
