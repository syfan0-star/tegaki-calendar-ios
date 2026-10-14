import InkModel
import Layout
import PencilKit
import SwiftUI
import UIKit

/// The strokes the lasso selected (M3B_CONTRACT.md §3.3). `bbox` is in paper coordinates (lu);
/// `viewRect` is the same box in the `InkCanvasView`'s own coordinates (pt), updated on every scroll
/// and zoom (the owner places the selection menu above it).
struct InkSelection: Equatable {
    var ids: [String]
    var bbox: CGRect
    var viewRect: CGRect
}

/// An order from the owner to the canvas (M3B_CONTRACT.md §3.3). Like `undoTrigger`: it is performed
/// once each time `commandTrigger` changes.
enum CanvasCommand: Equatable {
    case clearSelection
    /// Removes the selected strokes (one undoable op), then clears the selection.
    case deleteSelection
    /// Removes these strokes (one undoable op), e.g. after 「予定にする」; a selection is cleared.
    case removeStrokes([String])
}

/// The paper + ink surface for SwiftUI (M3A_CONTRACT.md §2.2, M3B_CONTRACT.md §3.3, DESIGN.md §3.2).
/// One instance shows one page of any kind (month / week / day / year); the owner re-creates it per
/// page with `.id(layout.pageId)`.
///
/// ```
///   InkCanvasContainerView (clips)
///     ├─ PaperView (担当 U)   below: frame = (−contentOffset, layout.size × zoom), redrawn from `paper`
///     ├─ PKCanvasView         middle: transparent, fills the container, and *is* the scroll view
///     └─ InkOverlayView       above: the lasso / 予定 tool input and drawing (enabled for those tools only)
/// ```
/// `PKCanvasView` owns scrolling and pinch zoom; the paper view is a sibling that is moved under it
/// on every `scrollViewDidScroll` / `scrollViewDidZoom` (public API only, no subview tricks).
///
/// Rules implemented here:
/// - The drawing is never replaced while the Pencil is on the paper (on the canvas or on the
///   overlay). Layout changes, page reloads, undo / redo and commands wait until 300 ms after the
///   pen lifts, then land together with a scroll compensation from `PageScroll.scrollDelta` so the
///   band under the top of the viewport stays put.
/// - `page` is written back after every change the ledger records; a `page` that arrives from
///   outside (merge, import) replaces the ledger's page.
/// - A `page` and a `layout` of different page ids (a transient of SwiftUI's update order) are
///   ignored until both agree; the ledger never mixes pages.
/// - The fit-to-width zoom comes from `layout.size.width` (the day page is 1000 lu wide, the others
///   1400). `initialScrollY` (paper lu) is applied once, when the first zoom is known.
/// - Finger taps (direct touches only) are reported in paper coordinates through `onTap`.
/// - PencilKit's own undo manager is emptied after every change; history is the ledger's.
/// - The selection follows the ledger: ids that stop being live (eraser, undo / redo, a reload)
///   are dropped, its box is recomputed after every relayout, and it is cleared when the tool
///   leaves the lasso, when the page changes, and on `.clearSelection`.
struct InkCanvasView: UIViewRepresentable {
    var layout: any PageLayout
    /// What the paper draws (担当 U). Used here only for `==` and `PaperView(content:)`.
    var paper: PaperContent
    var tool: CanvasTool
    var allowFinger: Bool
    @Binding var page: InkPage
    /// Paper y (lu) to show at the top when this canvas first appears (× zoom, clamped to the paper).
    var initialScrollY: CGFloat
    /// A finger tap, in paper coordinates (lu). The owner resolves it with `layout.hit(at:)`.
    var onTap: (CGPoint) -> Void
    /// Handwriting may have crossed the bottom of its cell (or an erased stroke may have been holding
    /// a cell open). The owner re-runs the layout with fresh `page.inkBottoms()`.
    var onInkBoundsChanged: () -> Void
    /// Bump to undo / redo (the values themselves do not matter).
    var undoTrigger: Int
    var redoTrigger: Int
    /// Apple Pencil double tap / squeeze asked for pen ⇄ eraser. The owner flips `tool`.
    var onPencilToggle: () -> Void = {}
    /// Whether undo / redo currently have anything to do (for the toolbar buttons).
    var onHistoryChanged: (_ canUndo: Bool, _ canRedo: Bool) -> Void = { _, _ in }
    /// The lasso selection changed, or its `viewRect` moved with a scroll / zoom; nil = no selection.
    var onSelectionChange: (InkSelection?) -> Void = { _ in }
    /// 予定 tool: the drag ended (`rect` paper coordinates, normalized). `isTap` when the pen moved
    /// less than 8 lu from where it touched.
    var onEventRect: (_ rect: CGRect, _ isTap: Bool) -> Void = { _, _ in }
    /// 予定 tool: the rect being dragged (paper) → the snapped rect to show (the owner returns
    /// `layout.previewRect(for:now:)`); nil shows the raw rect.
    var onEventPreview: (CGRect) -> CGRect? = { _ in nil }
    /// Performed once each time `commandTrigger` changes (after the pen lifts).
    var command: CanvasCommand? = nil
    var commandTrigger: Int = 0
    /// Screenshot mode: once the first zoom is known, these strokes are selected (unknown ids are ignored).
    var initialSelectionIds: [String] = []

    /// How long after the pen lifts a pending relayout is applied (M2 contract §3).
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
        canvas.drawingGestureRecognizer.isEnabled = !tool.isOverlayTool
        canvas.addInteraction(coordinator.pencilInteraction)
        canvas.addGestureRecognizer(coordinator.tapRecognizer)

        let overlay = container.overlayView
        overlay.delegate = coordinator
        overlay.scrollView = canvas
        overlay.allowFinger = allowFinger
        overlay.pageSize = layout.size
        overlay.tool = tool

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

/// Holds the paper view under the transparent canvas, the overlay above it, and reports its own
/// size changes (rotation, split view) so the fit-to-width zoom can be recomputed.
@MainActor
final class InkCanvasContainerView: UIView {
    let paperView: PaperView
    let canvasView = PKCanvasView()
    let overlayView = InkOverlayView()
    var onLayout: (() -> Void)?

    init(paperView: PaperView) {
        self.paperView = paperView
        super.init(frame: .zero)
        // Paper colour (web views.css) behind everything, so overscroll looks like more paper.
        backgroundColor = UIColor(red: 0xff / 255.0, green: 0xfd / 255.0, blue: 0xf8 / 255.0, alpha: 1)
        clipsToBounds = true
        addSubview(paperView)
        addSubview(canvasView)
        addSubview(overlayView)
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
        if overlayView.frame != bounds {
            overlayView.frame = bounds
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
    final class Coordinator: NSObject, PKCanvasViewDelegate, UIGestureRecognizerDelegate, InkOverlayViewDelegate {
        var parent: InkCanvasView
        /// The ledger of the page shown. Replaced (never reloaded across pages) if a different page
        /// id ever arrives in this canvas; normally the owner's `.id(pageId)` makes that impossible.
        private(set) var ledger: InkLedger
        private let deviceId: String?

        private weak var container: InkCanvasContainerView?
        private var canvas: PKCanvasView? { container?.canvasView }
        private var overlay: InkOverlayView? { container?.overlayView }

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
        private var appliedLayout: any PageLayout
        private var appliedTool: CanvasTool?
        private var publishedSignature: PageSignature
        private var lastUndoTrigger: Int
        private var lastRedoTrigger: Int
        private var lastCommandTrigger: Int

        private enum HistoryAction { case undo, redo }
        private var isUsingTool = false
        private var isSettling = false
        private var settleGeneration = 0
        /// The drawing must be rebuilt (layout geometry, page reload, undo / redo).
        private var pendingDrawing = false
        /// The paper content changed (now line, chips, lanes …); rebuilt together with the drawing.
        private var pendingPaper = false
        private var pendingHistory: [HistoryAction] = []
        /// Commands from the owner, performed with the next apply (after the pen lifts).
        private var pendingCommands: [CanvasCommand] = []
        /// A different page id arrived: fit the zoom again and scroll to `initialScrollY` instead
        /// of compensating.
        private var resetScroll = false
        private var isApplyingDrawing = false
        private var isUpdating = false
        /// The fit-to-width zoom (and with it `initialScrollY`) has been applied once.
        private var hasInitialZoom = false
        /// `initialSelectionIds` have not been applied yet (they are, once, at the first zoom; a new
        /// value arriving later is applied the same way, once).
        private var initialSelectionPending: Bool
        private var lastInitialSelectionIds: [String]

        /// The lasso selection: live stroke ids (in selection order) and their paper bounds.
        private var selectedIds: [String] = []
        private var selectionBBox: CGRect?
        /// What `onSelectionChange` last received (the same value is not sent twice).
        private var lastNotifiedSelection: InkSelection?
        /// The selected strokes are off the canvas while their picture follows the pen: a canvas
        /// change in that window is not a diff.
        private var isMovingSelection = false

        init(parent: InkCanvasView) {
            self.parent = parent
            let deviceId = UIDevice.current.identifierForVendor?.uuidString
            self.deviceId = deviceId
            // The ledger never mixes pages: when the first `page` does not belong to `layout` yet
            // (SwiftUI update order), start empty for the layout's page and wait for the real page
            // (it arrives through `update(from:)` once both agree).
            let page = parent.page.pageId == parent.layout.pageId
                ? parent.page
                : InkPage.empty(pageId: parent.layout.pageId)
            let ledger = InkLedger(page: page, layout: parent.layout, deviceId: deviceId)
            self.ledger = ledger
            appliedLayout = parent.layout
            publishedSignature = PageSignature(ledger.page)
            lastUndoTrigger = parent.undoTrigger
            lastRedoTrigger = parent.redoTrigger
            lastCommandTrigger = parent.commandTrigger
            lastInitialSelectionIds = parent.initialSelectionIds
            initialSelectionPending = !parent.initialSelectionIds.isEmpty
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
            overlay?.delegate = nil
            canvas?.delegate = nil
            container = nil
        }

        /// Called from `updateUIView`. Never touches the drawing directly: everything that would
        /// move the paper is queued and applied through `requestApply()`.
        func update(from newParent: InkCanvasView) {
            // Contract §2.2: while `page` and `layout` disagree about the page, do nothing at all
            // (not even keep the new values, so a pending apply cannot see a mixed pair).
            guard newParent.page.pageId == newParent.layout.pageId else { return }
            parent = newParent
            guard let canvas else { return }
            isUpdating = true
            defer { isUpdating = false }

            // 1. The page: another page id (new ledger), or the same page from outside (merge, import).
            let signature = PageSignature(newParent.page)
            if signature.pageId != ledger.page.pageId {
                overlay?.cancelGesture()
                clearSelection()
                ledger = InkLedger(page: newParent.page, layout: newParent.layout, deviceId: deviceId)
                publishedSignature = signature
                pendingDrawing = true
                resetScroll = true
                pendingHistory.removeAll()
                notifyHistory()
            } else if signature != publishedSignature {
                ledger.reload(page: newParent.page, keepHistory: true)
                publishedSignature = signature
                pendingDrawing = true
                notifyHistory()
            }

            // 2. Layout geometry (kind / page / size / cells) and paper content.
            if !appliedLayout.sameGeometry(as: newParent.layout) {
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
            if let overlay, overlay.allowFinger != newParent.allowFinger {
                overlay.allowFinger = newParent.allowFinger
            }
            if appliedTool != newParent.tool {
                appliedTool = newParent.tool
                // The overlay cancels its gesture (a move puts the strokes back) before anything else.
                overlay?.tool = newParent.tool
                canvas.drawingGestureRecognizer.isEnabled = !newParent.tool.isOverlayTool
                // The lasso / 予定 tool leaves the canvas tool as it was (drawing is disabled anyway).
                if !newParent.tool.isOverlayTool {
                    canvas.tool = newParent.tool.pkTool
                }
                if newParent.tool != .lasso {
                    clearSelection()
                }
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

            // 5. Commands (once per trigger change; performed after the pen lifts, like the rest).
            if newParent.commandTrigger != lastCommandTrigger {
                lastCommandTrigger = newParent.commandTrigger
                if let command = newParent.command {
                    pendingCommands.append(command)
                }
            }

            // 6. Screenshot mode: a selection to show. Usually set before the first zoom (applied in
            // `containerDidLayout`); a value that arrives later is applied here, once.
            if newParent.initialSelectionIds != lastInitialSelectionIds {
                lastInitialSelectionIds = newParent.initialSelectionIds
                initialSelectionPending = !newParent.initialSelectionIds.isEmpty
                applyInitialSelectionIfPending()
            }

            if pendingDrawing || pendingPaper || !pendingCommands.isEmpty {
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
            let commands = pendingCommands
            pendingCommands.removeAll()
            var drawingWork = pendingDrawing
            let paperWork = pendingPaper
            pendingDrawing = false
            pendingPaper = false

            var historyChanged = false
            var inkBoundsChanged = false
            for command in commands where perform(command) {
                drawingWork = true
                historyChanged = true
                inkBoundsChanged = true
            }
            guard drawingWork || paperWork else { return }

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
            let geometryChanged = !oldLayout.sameGeometry(as: newLayout)

            if drawingWork {
                setDrawing(ledger.relayout(newLayout), on: canvas)
                appliedLayout = newLayout
                canvas.contentSize = Self.scaled(newLayout.size, by: zoom)
                overlay?.pageSize = newLayout.size
            }
            // Paper-only changes (the now line moved, `isPast` flipped) land here without touching
            // the drawing.
            if container.paperView.content != parent.paper {
                container.paperView.content = parent.paper
            }
            syncPaperFrame()

            if resetScroll {
                resetScroll = false
                // A new page in this canvas: fit the zoom to its width (1000 or 1400) again and
                // start at its `initialScrollY`, exactly like a freshly created canvas.
                hasInitialZoom = false
                containerDidLayout()
            } else if drawingWork, geometryChanged {
                let delta = PageScroll.scrollDelta(old: oldLayout, new: newLayout, topVisibleY: topVisibleY)
                let target = CGPoint(x: canvas.contentOffset.x, y: (topVisibleY + delta) * zoom)
                canvas.contentOffset = clampedOffset(target)
            }
            syncPaperFrame()

            if drawingWork {
                // The selection follows the ledger (ids that died, cells that moved).
                refreshSelection()
                applyInitialSelectionIfPending()
            }
            if historyChanged {
                publishPage()
            }
            notifyHistory()
            if inkBoundsChanged {
                deliver { [weak self] in self?.parent.onInkBoundsChanged() }
            }
        }

        /// Performs one owner command. Returns true when the ledger changed (the drawing must be
        /// rebuilt and the page written back).
        private func perform(_ command: CanvasCommand) -> Bool {
            switch command {
            case .clearSelection:
                clearSelection()
                return false
            case .deleteSelection:
                let ids = selectedIds
                guard !ids.isEmpty else { return false }
                let change = ledger.removeStrokes(ids: ids)
                clearSelection()
                return !change.isEmpty
            case .removeStrokes(let ids):
                let change = ledger.removeStrokes(ids: ids)
                clearSelection()
                return !change.isEmpty
            }
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
        /// rotation, split view) or a page of another width replaced the layout. A paper at fit
        /// width stays at fit width; a zoomed-in paper keeps the point at the centre of the viewport
        /// in the centre. The very first time, the paper is scrolled to `initialScrollY`.
        func containerDidLayout() {
            guard let container, let canvas else { return }
            let viewport = container.bounds.size
            guard viewport.width > 0, viewport.height > 0 else { return }
            let fit = viewport.width / max(appliedLayout.size.width, 1)
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
                // Contract §2.2: the initial scroll is paper lu × the fit zoom, clamped to the paper.
                let y = parent.initialScrollY.isFinite ? max(0, parent.initialScrollY) : 0
                canvas.contentOffset = clampedOffset(CGPoint(x: 0, y: y * newZoom))
            }
            let firstZoom = !hasInitialZoom
            hasInitialZoom = true
            syncPaperFrame()
            if firstZoom {
                // Screenshot mode (contract §3.3): the selection to show, once the zoom is known.
                applyInitialSelectionIfPending()
            }
        }

        /// Keeps the paper view exactly under the canvas content, the overlay in step with it, and
        /// the selection's `viewRect` current.
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
            container.overlayView.viewportChanged()
            notifySelection()
        }

        private func clampedOffset(_ point: CGPoint) -> CGPoint {
            guard let container, let canvas else { return point }
            let maxX = max(0, canvas.contentSize.width - container.bounds.width)
            let maxY = max(0, canvas.contentSize.height - container.bounds.height)
            return CGPoint(x: min(max(point.x, 0), maxX), y: min(max(point.y, 0), maxY))
        }

        private static func scaled(_ size: CGSize, by zoom: CGFloat) -> CGSize {
            CGSize(width: size.width * zoom, height: size.height * zoom)
        }

        // MARK: Selection

        /// Selects the live strokes among `ids` (in that order); nothing live clears the selection.
        private func setSelection(ids: [String]) {
            let live = ledger.strokes(ids: ids).map { $0.id }
            guard !live.isEmpty, let bbox = ledger.paperBounds(ids: live) else {
                clearSelection()
                return
            }
            selectedIds = live
            selectionBBox = bbox
            overlay?.selectionBBox = bbox
            notifySelection()
        }

        private func clearSelection() {
            guard !selectedIds.isEmpty else { return }
            selectedIds = []
            selectionBBox = nil
            overlay?.selectionBBox = nil // cancels a move in progress
            notifySelection()
        }

        /// Drops ids that are no longer live (eraser, undo / redo, a reload: the web version's
        /// `_reconcileSelection`) and recomputes the box after a relayout (cells may have moved).
        private func refreshSelection() {
            guard !selectedIds.isEmpty else { return }
            let live = ledger.strokes(ids: selectedIds).map { $0.id }
            if live.count != selectedIds.count {
                setSelection(ids: live)
                return
            }
            if let bbox = ledger.paperBounds(ids: live), bbox != selectionBBox {
                selectionBBox = bbox
                overlay?.selectionBBox = bbox
            }
            notifySelection()
        }

        private func applyInitialSelectionIfPending() {
            guard initialSelectionPending, hasInitialZoom else { return }
            let ids = parent.initialSelectionIds
            if ids.isEmpty {
                initialSelectionPending = false
                return
            }
            // The page may still be on its way (a reload lands later): keep trying until it is there.
            guard !ledger.strokes(ids: ids).isEmpty else { return }
            initialSelectionPending = false
            setSelection(ids: ids)
        }

        /// The selection as the owner sees it: ids, paper box and the box in container coordinates.
        private func currentSelection() -> InkSelection? {
            guard !selectedIds.isEmpty, let bbox = selectionBBox, let canvas else { return nil }
            let zoom = canvas.zoomScale
            let offset = canvas.contentOffset
            let viewRect = CGRect(
                x: bbox.minX * zoom - offset.x,
                y: bbox.minY * zoom - offset.y,
                width: bbox.width * zoom,
                height: bbox.height * zoom
            )
            return InkSelection(ids: selectedIds, bbox: bbox, viewRect: viewRect)
        }

        /// Sends the selection when it (or its `viewRect`) changed since the last time. Always on
        /// the next main-actor turn: a scroll or a layout pass may be running inside a UIKit layout
        /// or a SwiftUI update, where the owner must not change its state. Order is kept.
        private func notifySelection() {
            let current = currentSelection()
            guard current != lastNotifiedSelection else { return }
            lastNotifiedSelection = current
            Task { @MainActor [weak self] in
                self?.parent.onSelectionChange(current)
            }
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

        // MARK: The pen on the paper (canvas or overlay)

        private func penDidTouch() {
            isUsingTool = true
            isSettling = false
            settleGeneration += 1
        }

        private func penDidLift() {
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

        // MARK: PKCanvasViewDelegate

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingDrawing, !isMovingSelection else { return }
            // History is the ledger's; never let the system (3-finger swipe) undo through PencilKit.
            canvasView.undoManager?.removeAllActions()
            let change = ledger.applyCanvasChange(canvasView.drawing)
            guard !change.isEmpty else { return }
            publishPage()
            notifyHistory()
            if !change.removedIds.isEmpty {
                refreshSelection()
            }
            // Only cells that grow with ink ask for a relayout (`needsMoreRoom` is false on the time
            // grid); an erased stroke may have been holding any growing cell open.
            let needsRoom = change.added.contains { ledger.needsMoreRoom($0) }
            if needsRoom || !change.removedIds.isEmpty {
                deliver { [weak self] in self?.parent.onInkBoundsChanged() }
            }
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            penDidTouch()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            penDidLift()
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

        // MARK: InkOverlayViewDelegate (the lasso and the 予定 tool)

        func overlayDidTouchOutsideSelection(_ overlay: InkOverlayView) {
            clearSelection()
        }

        /// Selects the live strokes at least half of whose stored points lie inside the lasso
        /// (DESIGN §3.6, web `_endLasso`); only strokes whose bounds overlap the lasso's are tested.
        func overlay(_ overlay: InkOverlayView, didFinishLasso polygon: [CGPoint]) {
            guard let bounds = LassoGeometry.bounds(of: polygon) else { return }
            let cells = ledger.layout.cells
            var ids: [String] = []
            for stroke in ledger.page.liveStrokes {
                guard let cell = cells[stroke.cell],
                      let box = stroke.paperBounds(cellOrigin: cell.origin),
                      Self.overlaps(box, bounds) else { continue }
                if LassoGeometry.strokeInLasso(points: stroke.paperPoints(cellOrigin: cell.origin), polygon: polygon, bounds: bounds) {
                    ids.append(stroke.id)
                }
            }
            if !ids.isEmpty {
                setSelection(ids: ids)
            }
        }

        /// Takes the selected strokes off the canvas without a diff (the ledger keeps them) and
        /// returns their picture for the overlay to drag around.
        func overlayWillBeginMove(_ overlay: InkOverlayView) -> UIImage? {
            guard let canvas, let bbox = selectionBBox, !selectedIds.isEmpty else { return nil }
            let strokes = ledger.strokes(ids: selectedIds)
            guard !strokes.isEmpty else { return nil }
            let scale = container?.traitCollection.displayScale ?? 2
            guard let image = InkSnapshot.image(strokes: strokes, cells: ledger.layout.cells, bounds: bbox, zoom: canvas.zoomScale, scale: scale > 0 ? scale : 2) else { return nil }
            let hidden = Set(selectedIds)
            let kept = canvas.drawing.strokes.filter { pk in
                ledger.id(of: pk).map { !hidden.contains($0) } ?? true
            }
            isMovingSelection = true
            isApplyingDrawing = true
            canvas.drawing = PKDrawing(strokes: kept)
            isApplyingDrawing = false
            canvas.undoManager?.removeAllActions()
            return image
        }

        /// Commits the move as one batch op; the selection moves on to the clones. A zero move (or
        /// nothing live any more) only puts the original drawing back.
        func overlay(_ overlay: InkOverlayView, didEndMoveBy delta: CGVector) {
            guard let canvas else { return }
            isMovingSelection = false
            let result = ledger.moveStrokes(ids: selectedIds, by: delta)
            setDrawing(ledger.drawing(), on: canvas)
            guard !result.change.isEmpty else {
                refreshSelection()
                return
            }
            setSelection(ids: result.newIds)
            publishPage()
            notifyHistory()
            // The cells the strokes left and the cells they landed in may shrink / grow.
            deliver { [weak self] in self?.parent.onInkBoundsChanged() }
        }

        func overlayDidCancelMove(_ overlay: InkOverlayView) {
            guard let canvas else { return }
            isMovingSelection = false
            setDrawing(ledger.drawing(), on: canvas)
        }

        func overlay(_ overlay: InkOverlayView, previewFor rect: CGRect) -> CGRect? {
            parent.onEventPreview(rect)
        }

        func overlay(_ overlay: InkOverlayView, didEndEvent rect: CGRect, isTap: Bool) {
            deliver { [weak self] in self?.parent.onEventRect(rect, isTap) }
        }

        func overlay(_ overlay: InkOverlayView, isTracking: Bool) {
            if isTracking {
                penDidTouch()
            } else {
                penDidLift()
            }
        }

        /// Rects touch or overlap (edges count, like the web version's rectsOverlap).
        private static func overlaps(_ a: CGRect, _ b: CGRect) -> Bool {
            !(a.maxX < b.minX || a.minX > b.maxX || a.maxY < b.minY || a.minY > b.maxY)
        }
    }
}
