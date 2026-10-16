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
///   InkCanvasContainerView (clips; the desk colour)
///     ├─ PaperView (担当 P)   below: a window of at most 2 × 2 screens around the visible part of the
///     │                        paper (`show(visible:zoom:contentSize:live:)`, M4B_CONTRACT §1.6), redrawn from `paper`
///     ├─ PKCanvasView         middle: transparent, fills the container, and *is* the scroll view
///     └─ InkOverlayView       above: the lasso / 予定 tool drawing; the Pencil's input for those tools
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
/// - The zoom limits come from `ZoomPolicy` (M4C_CONTRACT §1.1, D1): the minimum is the overview
///   (`fitAll`: the page's overview rectangle fits the paper area both ways), the maximum
///   `max(4 × fit-to-width, 2 × readable)`. Every page opens at its stored ratio of the overview
///   (`initialZoomRatio`, 1 = the overview, top-left); at a ratio above 1 `initialScrollX` /
///   `initialScrollY` (paper lu) are applied once, when the first zoom is known. A paper smaller than
///   the viewport is centred with `contentInset` (the margins are the desk colour, M4C-25).
/// - A pinch keeps its absolute zoom across rotations and height changes (D4 / M4C-24: the overview
///   follows the new overview, a zoomed-in paper is only clamped, and `targetZoom` remembers what the
///   clamp cut off); the ratio is reported (`onZoomRatioChange`) only at the end of a pinch.
/// - While the canvas is zooming or bouncing (`isLive`) the paper window is stretched, not redrawn
///   (F3); the end of the pinch (`scrollViewDidEndZooming`) centres, clamps, redraws once and reports.
/// - Whenever `contentOffset.x`, the zoom or the container's width changes, the owner gets a
///   `PaperViewport` (`onViewportChange`) so the sticky header and the all-day band follow the paper
///   (M4B_CONTRACT §1.3). Finger-driven changes are delivered at once; changes made inside a layout
///   pass or a SwiftUI update are delivered on the next main-actor turn (a `@State` must not change
///   during a view update).
/// - Finger taps (direct touches only) are reported in paper coordinates through `onTap`; a finger's
///   double tap through `onDoubleTap` (week / month / year, D5), the single tap waiting for it.
/// - The finger input of the lasso / 予定 tool goes through the container's own recogniser
///   (`InkFingerGestureRecognizer`, F2), so two fingers always reach the scroll view's pan and pinch.
/// - Strokes whose centre lies outside the paper (in the centring margin) are dropped (M4C-25).
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
    /// Paper y (lu) to show at the top when this canvas first appears at a ratio above 1 (× zoom,
    /// clamped to the paper). At the overview (ratio 1) the paper starts at the top-left.
    var initialScrollY: CGFloat
    /// Paper x (lu) to show at the left when this canvas first appears at a ratio above 1
    /// (`PageNavigation.initialScrollX`; × the first zoom, clamped to the paper). M4B_CONTRACT §1.3.
    var initialScrollX: CGFloat = 0
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
    /// `contentOffset.x`, `zoomScale` or the container's width changed (never for a change of y
    /// alone). The owner hands the value to `StickyHeaderView` and `AllDayBandView` (M4B_CONTRACT §1.3).
    var onViewportChange: (PaperViewport) -> Void = { _ in }
    /// The zoom to open with, as a ratio of the overview (`fitAll`; M4C_CONTRACT §1.3, D4). Applied
    /// once, at the first layout (a later value is not applied again). The stored ratio of the page
    /// kind, or `--screenshot-zoom`.
    var initialZoomRatio: CGFloat = 1
    /// The paper point (lu) to put at the top-left at the first layout. nil: the rule of §1.3 — the
    /// overview (ratio 1) starts at the top-left, a zoomed-in page at `initialScrollX` / `initialScrollY`.
    /// The way in for `--screenshot-offset`.
    var initialPaperOffset: CGPoint? = nil
    /// true on the week / month / year pages. false leaves `doubleTapRecognizer` disabled, so the
    /// single tap is not delayed (the day page).
    var doubleTapEnabled: Bool = false
    /// A finger's double tap, in paper coordinates (lu). The owner turns it into a day with
    /// `layout.dayAt(point:)` (D5).
    var onDoubleTap: (CGPoint) -> Void = { _ in }
    /// Once at the end of a pinch (after the bounce): the new ratio (zoom / fitAll). Never for a
    /// rotation or a change of the overview's height (D4). Always delivered on the next main-actor
    /// turn; the receiver only writes it to `AppSettings`.
    var onZoomRatioChange: (CGFloat) -> Void = { _ in }
    /// true when a pinch begins (`scrollViewWillBeginZooming`), false when it is over (together with
    /// the redraw after the bounce). The owner freezes the all-day band's lane height in between
    /// (M4C_CONTRACT §1.6, M4C-27). Delivered on the next main-actor turn.
    var onZoomingChange: (Bool) -> Void = { _ in }
    /// M5 (M5_CONTRACT §3.1): the app is read only. PencilKit's drawing recogniser, the overlay's
    /// input and the finger recogniser are off (`drawingPolicy` and `isUserInteractionEnabled` of
    /// the canvas are not touched: scrolling, pinching and taps keep working); a Pencil touch is
    /// reported through `onBlockedInput`.
    var readOnly: Bool = false
    /// The Pencil touched the read-only paper (`.began` of `blockedInputRecognizer`; a finger never
    /// reports, so an iPhone's finger scroll stays quiet). The owner shows the paywall or a toast
    /// and throttles it (2 s).
    var onBlockedInput: () -> Void = {}

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
        // Everything the canvas, the overlay and the recognisers need is wired in `attach` (the
        // tests build the same container without a `Context`).
        coordinator.attach(container)
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
/// size changes (rotation, split view, the all-day band growing) so the zoom limits can be recomputed.
@MainActor
final class InkCanvasContainerView: UIView {
    let paperView: PaperView
    let canvasView = PKCanvasView()
    let overlayView = InkOverlayView()
    var onLayout: (() -> Void)?

    /// The desk behind the paper (M4C-25): #ecebe6, the same in dark mode (the paper is always light,
    /// DESIGN §3.2). The paper view paints its own window in the paper colour, so only the paper is
    /// paper-coloured; the centring margins, overscroll and the outside of the window during a pinch
    /// (M4C-20) show the desk.
    static let deskColor = UIColor(red: 0xec / 255.0, green: 0xeb / 255.0, blue: 0xe6 / 255.0, alpha: 1)

    init(paperView: PaperView) {
        self.paperView = paperView
        super.init(frame: .zero)
        backgroundColor = Self.deskColor
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
        /// Receives Apple Pencil double taps / squeezes. Added to the canvas in `attach`.
        let pencilInteraction: UIPencilInteraction
        /// Finger taps on the paper (direct touches only). Added to the canvas in `attach`; it waits
        /// for `doubleTapRecognizer` and `fingerRecognizer` to fail.
        private(set) lazy var tapRecognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            recognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
            recognizer.delegate = self
            return recognizer
        }()
        /// A finger's double tap on the paper (M4C_CONTRACT §4.1, D5): the week / month / year pages
        /// jump to the day under it. Direct touches only, so the Pencil never triggers it. Enabled
        /// while `doubleTapEnabled` and no overlay tool is up (`syncRecognizers`).
        private(set) lazy var doubleTapRecognizer: UITapGestureRecognizer = {
            let r = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            r.numberOfTapsRequired = 2
            r.numberOfTouchesRequired = 1
            r.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
            r.delegate = self
            return r
        }()
        /// The one-finger input of the lasso / 予定 tool (M4C_CONTRACT §2.2 F2), on the container. Enabled
        /// while an overlay tool is up and `allowFinger`; the canvas's pan and `tapRecognizer` wait for
        /// it to fail, which it does as soon as a second finger touches (a scroll or a pinch).
        private(set) lazy var fingerRecognizer: InkFingerGestureRecognizer = {
            let r = InkFingerGestureRecognizer()
            r.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
            r.delegate = self
            r.cancelsTouchesInView = false
            return r
        }()
        /// M5 (M5_CONTRACT §3.1): a Pencil touch on the read-only paper, on the canvas. Recognised at
        /// touch-down (`minimumPressDuration` 0), never fails on movement, Pencil only (a finger
        /// scroll must not report), lets the touches through, and runs alongside every other
        /// recogniser (see the delegate). Enabled while `readOnly` (`syncRecognizers`).
        private(set) lazy var blockedInputRecognizer: UILongPressGestureRecognizer = {
            let r = UILongPressGestureRecognizer(target: self, action: #selector(handleBlockedInput(_:)))
            r.minimumPressDuration = 0
            r.allowableMovement = .greatestFiniteMagnitude
            r.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
            r.cancelsTouchesInView = false
            r.delegate = self
            return r
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
        /// The first zoom (and with it `initialZoomRatio` / `initialPaperOffset` / `initialScrollX` /
        /// `initialScrollY`) has been applied once.
        private var hasInitialZoom = false
        /// `containerDidLayout()` / `applyPending()` are running: they may be inside a UIKit layout
        /// pass or a SwiftUI update, and the `zoomScale` / `contentOffset` they assign make UIKit
        /// call `scrollViewDidScroll` / `scrollViewDidZoom` synchronously. A viewport born there is
        /// delivered on the next turn (M4B_CONTRACT §1.3).
        private var isApplyingGeometry = false
        /// What `onViewportChange` last received or is about to receive (the same value is not sent twice).
        private var lastViewport: PaperViewport?
        /// A next-turn delivery of `lastViewport` is scheduled.
        private var viewportDeliveryPending = false
        /// `initialSelectionIds` have not been applied yet (they are, once, at the first zoom; a new
        /// value arriving later is applied the same way, once).
        private var initialSelectionPending: Bool
        private var lastInitialSelectionIds: [String]

        // Zoom (M4C_CONTRACT §1.3)
        /// The container size the limits were last computed for (a change of width is a rotation or
        /// Split View; a change of height alone is the all-day band growing or shrinking).
        private var lastLayoutSize: CGSize = .zero
        /// The limits last applied (`containerDidLayout` returns early when they did not change).
        private var lastBounds: ZoomPolicy.Bounds?
        /// The absolute zoom the user last chose (the end of a pinch, or the first layout). A
        /// rotation may clamp the canvas below it; it is kept, and restored when the range allows
        /// again (D4 / M4C-24).
        private var targetZoom: CGFloat?
        /// The pinch ended in a bounce: the first `scrollViewDidZoom` after it redraws the paper once.
        private var needsFinalRedraw = false
        /// Tests only: nil reads the canvas's `isZooming` / `isZoomBouncing` (XCTest cannot pinch).
        var liveOverride: Bool? = nil
        /// The canvas is pinching or bouncing: the paper window is stretched, not redrawn (F3), the
        /// zoom and the offset are not touched by layout passes (UIKit is driving them).
        private var isLive: Bool {
            if let liveOverride { return liveOverride }
            guard let canvas else { return false }
            return canvas.isZooming || canvas.isZoomBouncing
        }
        /// F4 (M4C_CONTRACT §2.5): the view the scroll view zooms, chosen once from the canvas's
        /// subviews (see `viewForZooming(in:)`).
        private var zoomingView: UIView?
        private var loggedMissingZoomingView = false
        /// The canvas's `contentSize` as `scrollViewDidZoom` last found it: the value UIScrollView
        /// itself derived from the zooming view's frame, before this coordinator sets paper × zoom
        /// (F4, §2.5). The regression test compares the two; should they disagree on a device, the
        /// assignment in `scrollViewDidZoom` is the one to drop.
        private(set) var contentSizeFromUIKit: CGSize?

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

        /// Wires the container: the canvas's settings, delegate, interactions and recognisers, the
        /// overlay, the first drawing. Called from `makeUIView` (and directly by the tests).
        func attach(_ container: InkCanvasContainerView) {
            self.container = container
            container.onLayout = { [weak self] in self?.containerDidLayout() }

            let canvas = container.canvasView
            canvas.delegate = self
            canvas.backgroundColor = .clear
            canvas.isOpaque = false
            // The paper is always light; never let PencilKit invert ink colours (DESIGN.md §3.2).
            canvas.overrideUserInterfaceStyle = .light
            // The centring margins are set by hand (`applyInsets`), never by the safe area.
            canvas.contentInsetAdjustmentBehavior = .never
            canvas.alwaysBounceVertical = true
            canvas.alwaysBounceHorizontal = false
            // Shown only while the content is wider than the view (an iPhone, the year page; M4B-5).
            canvas.showsHorizontalScrollIndicator = true
            // A vertical flick does not drift sideways (M4B-6).
            canvas.isDirectionalLockEnabled = true
            // `bouncesZoom` stays at its default (true): with the overview as the lower limit the
            // bounce means "never smaller than the overview" (M4C-13).
            canvas.maximumSupportedContentVersion = .version1
            canvas.drawingPolicy = parent.allowFinger ? .anyInput : .pencilOnly
            canvas.tool = parent.tool.pkTool
            // M5 (M5_CONTRACT §3.1): no new ink while read only.
            canvas.drawingGestureRecognizer.isEnabled = !parent.tool.isOverlayTool && !parent.readOnly
            canvas.addInteraction(pencilInteraction)
            canvas.addGestureRecognizer(tapRecognizer)
            canvas.addGestureRecognizer(doubleTapRecognizer)
            canvas.addGestureRecognizer(blockedInputRecognizer)
            // The single tap waits about 0.3 s for the double tap to fail (M4C-6); on the day page and
            // with an overlay tool the double tap is disabled and fails at once, so nothing waits.
            tapRecognizer.require(toFail: doubleTapRecognizer)
            // F2: one finger of the lasso / 予定 tool goes to the overlay through this recogniser; the
            // pan (and so the pinch) and the single tap wait for it. It must stay `.possible` while
            // the finger is down (a `.began` would make the pan fail for the whole touch sequence).
            fingerRecognizer.overlay = container.overlayView
            container.addGestureRecognizer(fingerRecognizer)
            canvas.panGestureRecognizer.require(toFail: fingerRecognizer)
            tapRecognizer.require(toFail: fingerRecognizer)
            syncRecognizers()

            let overlay = container.overlayView
            overlay.delegate = self
            overlay.scrollView = canvas
            overlay.allowFinger = parent.allowFinger
            overlay.pageSize = parent.layout.size
            overlay.tool = parent.tool
            // M5 (M5_CONTRACT §3.1): after `tool` (its didSet sets this from the tool alone).
            overlay.isUserInteractionEnabled = parent.tool.isOverlayTool && !parent.readOnly

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

        /// `doubleTapRecognizer` is on while the owner asks for it and no overlay tool is up;
        /// `fingerRecognizer` while an overlay tool is up, the finger may write and the app is not
        /// read only. A disabled recogniser fails at once, so the recognisers waiting for it are not
        /// delayed. M5 (M5_CONTRACT §3.1): the read-only rule is applied here too (`readOnly` alone
        /// may change under the same tool): `blockedInputRecognizer` on, PencilKit's drawing
        /// recogniser and the overlay's input off.
        private func syncRecognizers() {
            let doubleTap = parent.doubleTapEnabled && !parent.tool.isOverlayTool
            if doubleTapRecognizer.isEnabled != doubleTap {
                doubleTapRecognizer.isEnabled = doubleTap
            }
            let finger = parent.tool.isOverlayTool && parent.allowFinger && !parent.readOnly
            if fingerRecognizer.isEnabled != finger {
                fingerRecognizer.isEnabled = finger
            }
            if blockedInputRecognizer.isEnabled != parent.readOnly {
                blockedInputRecognizer.isEnabled = parent.readOnly
            }
            if let canvas {
                let drawing = !parent.tool.isOverlayTool && !parent.readOnly
                if canvas.drawingGestureRecognizer.isEnabled != drawing {
                    canvas.drawingGestureRecognizer.isEnabled = drawing
                }
            }
            if let overlay {
                let interactive = parent.tool.isOverlayTool && !parent.readOnly
                if overlay.isUserInteractionEnabled != interactive {
                    overlay.isUserInteractionEnabled = interactive
                }
            }
        }

        /// Called from `updateUIView`. Never touches the drawing directly: everything that would
        /// move the paper is queued and applied through `requestApply()`. `initialZoomRatio` and
        /// `initialPaperOffset` are read by the first layout only (and again after `resetScroll`).
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
                // M5 (M5_CONTRACT §3.1): right after `tool` (its didSet sets this from the tool alone).
                overlay?.isUserInteractionEnabled = newParent.tool.isOverlayTool && !newParent.readOnly
                canvas.drawingGestureRecognizer.isEnabled = !newParent.tool.isOverlayTool && !newParent.readOnly
                // The lasso / 予定 tool leaves the canvas tool as it was (drawing is disabled anyway).
                if !newParent.tool.isOverlayTool {
                    canvas.tool = newParent.tool.pkTool
                }
                if newParent.tool != .lasso {
                    clearSelection()
                }
            }
            // The double tap (off with an overlay tool) and the finger input of the overlay tools.
            syncRecognizers()

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
            let wasApplyingGeometry = isApplyingGeometry
            isApplyingGeometry = true
            defer { isApplyingGeometry = wasApplyingGeometry }
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
                // A new page in this canvas: compute the limits for its overview again, open it at
                // its `initialZoomRatio` and `initialScrollX` / `Y`, exactly like a freshly created canvas.
                hasInitialZoom = false
                containerDidLayout()
            } else if drawingWork, geometryChanged {
                // The overview rectangle grew or shrank with handwriting / events (a month row, a
                // year row): new limits, and the overview follows the new overview (M4C_CONTRACT §1.3).
                let viewport = container.bounds.size
                if hasInitialZoom, viewport.width > 0, viewport.height > 0 {
                    applyBounds(ZoomPolicy.bounds(newLayout.kind, overview: ZoomPolicy.overviewSize(newLayout), viewport: viewport))
                }
                let zoomNow = max(canvas.zoomScale, 0.0001)
                let delta = PageScroll.scrollDelta(old: oldLayout, new: newLayout, topVisibleY: topVisibleY)
                let target = CGPoint(x: canvas.contentOffset.x, y: (topVisibleY + delta) * zoomNow)
                if !isLive {
                    canvas.contentOffset = clampedOffset(target)
                }
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

        /// Recomputes the zoom limits (`ZoomPolicy.bounds`, M4C_CONTRACT §1.3) when the container's
        /// size changes (first layout, rotation, split view, the all-day band growing) or a page of
        /// another kind replaced the layout.
        ///
        /// 1. The overview and the limits for the container's size.
        /// 2. Same limits as last time: only the centring margins and the paper window are refreshed.
        /// 3. The first time: the limits, the zoom for `initialZoomRatio` (assigned through
        ///    `zoomScale`, so UIKit's `scrollViewDidZoom` does the same synchronisation as a pinch),
        ///    the margins, the content size, the first offset (`initialPaperOffset`; the top-left at
        ///    the overview; `initialScrollX` / `Y` above it), then the end-of-pinch path once
        ///    (`scrollViewDidEndZooming`: margins, clamp, the ratio report) and the DEBUG log.
        /// 4. The width changed (rotation, Split View): the overview stays the overview, a zoomed-in
        ///    paper keeps its absolute zoom (`targetZoom`, which a clamp does not change) with the
        ///    point at the centre of the viewport in the centre (D4 / M4C-24). Nothing of the zoom
        ///    while a pinch is live (the limits only). No ratio report.
        /// 5. Only the height changed (the band grew or shrank): `applyBounds`.
        /// 6. Margins, the offset clamped (not while live: UIKit holds it at the pinch's anchor), the
        ///    paper window.
        func containerDidLayout() {
            let wasApplyingGeometry = isApplyingGeometry
            isApplyingGeometry = true
            defer { isApplyingGeometry = wasApplyingGeometry }
            guard let container, let canvas else { return }
            let viewport = container.bounds.size
            guard viewport.width > 0, viewport.height > 0 else { return }
            let overview = ZoomPolicy.overviewSize(appliedLayout)
            let bounds = ZoomPolicy.bounds(appliedLayout.kind, overview: overview, viewport: viewport)

            // 2. Same limits (a layout pass during a pinch, a height change the width-bound month
            // ignores): the margins may still differ (the height changed), the window follows.
            if hasInitialZoom, let last = lastBounds, Self.sameBounds(last, bounds) {
                lastLayoutSize = viewport
                applyInsets()
                syncPaperFrame()
                return
            }

            if !hasInitialZoom {
                // 3. The first zoom.
                canvas.minimumZoomScale = bounds.min
                canvas.maximumZoomScale = bounds.max
                let zoom = ZoomPolicy.zoom(forRatio: parent.initialZoomRatio, bounds: bounds)
                canvas.zoomScale = zoom // → scrollViewDidZoom: contentSize, margins, window, heading
                targetZoom = zoom
                applyInsets()
                canvas.contentSize = Self.scaled(appliedLayout.size, by: zoom)
                let inset = canvas.contentInset
                if let offset = parent.initialPaperOffset {
                    let x = offset.x.isFinite ? offset.x : 0
                    let y = offset.y.isFinite ? offset.y : 0
                    canvas.contentOffset = clampedOffset(CGPoint(x: x * zoom, y: y * zoom))
                } else if ZoomPolicy.ratio(forZoom: zoom, bounds: bounds) <= 1.0005 {
                    // The overview: the top-left (M4C-18), inside the centring margins.
                    canvas.contentOffset = CGPoint(x: -inset.left, y: -inset.top)
                } else {
                    // Zoomed in: paper lu × the zoom, clamped to the paper (M3A §2.2 for y,
                    // M4B_CONTRACT §1.3 for x). Not finite → 0, negative → 0.
                    let x = parent.initialScrollX.isFinite ? max(0, parent.initialScrollX) : 0
                    let y = parent.initialScrollY.isFinite ? max(0, parent.initialScrollY) : 0
                    canvas.contentOffset = clampedOffset(CGPoint(x: x * zoom, y: y * zoom))
                }
                hasInitialZoom = true
                lastLayoutSize = viewport
                lastBounds = bounds
                syncPaperFrame()
                // The screenshot and the first layout share the end-of-pinch path (M4C_CONTRACT §2.4).
                scrollViewDidEndZooming(canvas, with: nil, atScale: zoom)
                // Screenshot mode (contract §3.3): the selection to show, once the zoom is known.
                applyInitialSelectionIfPending()
                #if DEBUG
                let pinch = canvas.pinchGestureRecognizer
                NSLog("zoom: kind=%@ pinch=%d enabled=%d min=%.4f max=%.4f zoom=%.4f fitAll=%.4f ratio=%.3f view=%.0fx%.0f overview=%.0fx%.0f",
                      appliedLayout.kind.rawValue as NSString, Int32(pinch == nil ? 0 : 1), Int32((pinch?.isEnabled ?? false) ? 1 : 0),
                      bounds.min, bounds.max, canvas.zoomScale, bounds.min,
                      ZoomPolicy.ratio(forZoom: canvas.zoomScale, bounds: bounds),
                      viewport.width, viewport.height, overview.width, overview.height)
                #endif
                return
            }

            let live = isLive
            if viewport.width != lastLayoutSize.width {
                // 4. The width changed.
                let oldMin = canvas.minimumZoomScale
                let oldZoom = max(canvas.zoomScale, 0.0001)
                let atOverview = abs(oldZoom - oldMin) < 0.0005
                canvas.minimumZoomScale = bounds.min
                canvas.maximumZoomScale = bounds.max
                if !live {
                    let centerPaper = CGPoint(
                        x: (canvas.contentOffset.x + viewport.width / 2) / oldZoom,
                        y: (canvas.contentOffset.y + viewport.height / 2) / oldZoom
                    )
                    let newZoom = atOverview ? bounds.min : bounds.clamped(targetZoom ?? oldZoom)
                    canvas.zoomScale = newZoom
                    canvas.contentSize = Self.scaled(appliedLayout.size, by: newZoom)
                    applyInsets()
                    canvas.contentOffset = clampedOffset(CGPoint(
                        x: centerPaper.x * newZoom - viewport.width / 2,
                        y: centerPaper.y * newZoom - viewport.height / 2
                    ))
                }
            } else {
                // 5. Only the height changed.
                applyBounds(bounds)
            }

            // 6. The common tail.
            lastLayoutSize = viewport
            lastBounds = bounds
            applyInsets()
            if !live {
                canvas.contentOffset = clampedOffset(canvas.contentOffset)
            }
            syncPaperFrame()
        }

        /// True when fit, min and max all differ by less than 0.0005.
        private static func sameBounds(_ a: ZoomPolicy.Bounds, _ b: ZoomPolicy.Bounds) -> Bool {
            abs(a.fit - b.fit) < 0.0005 && abs(a.min - b.min) < 0.0005 && abs(a.max - b.max) < 0.0005
        }

        /// New limits without a change of width (the band grew, a month / year row grew with ink or
        /// events; M4C_CONTRACT §1.3). The limits are always updated; the zoom only when no pinch is
        /// live: a paper at the overview follows the new overview (D1; `targetZoom` with it), a
        /// zoomed-in paper is clamped only when it fell outside the new range (a paper that was at
        /// the old minimum by chance is *not* re-applied). The ratio is not reported.
        private func applyBounds(_ bounds: ZoomPolicy.Bounds) {
            guard let canvas else { return }
            let atOverview = abs(canvas.zoomScale - canvas.minimumZoomScale) < 0.0005
            canvas.minimumZoomScale = bounds.min
            canvas.maximumZoomScale = bounds.max
            lastBounds = bounds
            guard !isLive else { return }
            if atOverview {
                if abs(canvas.zoomScale - bounds.min) >= 0.0005 {
                    canvas.zoomScale = bounds.min
                }
                targetZoom = bounds.min
            } else if canvas.zoomScale < bounds.min || canvas.zoomScale > bounds.max {
                canvas.zoomScale = bounds.clamped(canvas.zoomScale)
            }
        }

        /// The centring margins of the whole paper (`layout.size`, never the overview rectangle) at
        /// the current zoom (M4C_CONTRACT §1.3). `contentInsetAdjustmentBehavior` is `.never`, so the
        /// inset is ours to set. Margins under 1 µpt are 0 (fit-to-width leaves floating-point dust).
        private func applyInsets() {
            guard let container, let canvas else { return }
            let inset = ZoomPolicy.centeringInsets(paper: appliedLayout.size, zoom: canvas.zoomScale, viewport: container.bounds.size)
            let horizontal = inset.width < 1e-6 ? 0 : inset.width
            let vertical = inset.height < 1e-6 ? 0 : inset.height
            let edges = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
            if canvas.contentInset != edges {
                canvas.contentInset = edges
            }
        }

        /// Keeps the paper view's window under the visible part of the canvas content (M4B_CONTRACT
        /// §1.6), the overlay in step with it, the selection's `viewRect` current, and reports the
        /// viewport. Every scroll, zoom, layout pass and `applyPending` comes through here. While a
        /// pinch is live the window is stretched (`show(live: true)`) and the paper's `zoomScale` is
        /// left alone (F3: its `didSet` would redraw the window every frame and the transform would
        /// scale it twice); the end of the pinch comes back here with `live` false.
        private func syncPaperFrame() {
            guard let container, let canvas else { return }
            let zoom = canvas.zoomScale
            container.paperView.show(
                visible: CGRect(origin: canvas.contentOffset, size: container.bounds.size),
                zoom: zoom,
                contentSize: canvas.contentSize,
                live: isLive
            )
            container.overlayView.viewportChanged()
            notifySelection()
            notifyViewport()
        }

        /// Sends the viewport (offset x, zoom, container width) when it changed since the last time
        /// (M4B_CONTRACT §1.3). A change made by the finger (tracking, dragging, decelerating,
        /// zooming) outside a layout pass or a SwiftUI update is delivered at once, so the heading
        /// never lags a frame; anything else (layout, a page change, an assignment from code) is
        /// delivered on the next main-actor turn, once, with the latest value. While a next-turn
        /// delivery is pending nothing is sent synchronously (an older value must never land after
        /// a newer one).
        private func notifyViewport() {
            guard let canvas, let container else { return }
            let v = PaperViewport(offsetX: canvas.contentOffset.x, zoom: canvas.zoomScale, width: container.bounds.width)
            guard v != lastViewport else { return } // a change of y alone stops here
            lastViewport = v
            let byFinger = canvas.isTracking || canvas.isDragging || canvas.isDecelerating || canvas.isZooming
            if byFinger, !isApplyingGeometry, !isUpdating, !viewportDeliveryPending {
                parent.onViewportChange(v)
            } else if !viewportDeliveryPending {
                viewportDeliveryPending = true
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.viewportDeliveryPending = false
                    if let latest = self.lastViewport { self.parent.onViewportChange(latest) }
                }
            }
        }

        /// `point` kept inside the scrollable range, margins included: x in [−inset.left,
        /// max(−inset.left, contentSize.width + inset.right − width)], y likewise. A centred paper
        /// therefore rests at a negative offset. Not finite → the top-left.
        private func clampedOffset(_ point: CGPoint) -> CGPoint {
            guard let container, let canvas else { return point }
            let inset = canvas.contentInset
            let minX = -inset.left
            let minY = -inset.top
            let maxX = max(minX, canvas.contentSize.width + inset.right - container.bounds.width)
            let maxY = max(minY, canvas.contentSize.height + inset.bottom - container.bounds.height)
            let x = point.x.isFinite ? point.x : minX
            let y = point.y.isFinite ? point.y : minY
            return CGPoint(x: min(max(x, minX), maxX), y: min(max(y, minY), maxY))
        }

        private static func scaled(_ size: CGSize, by zoom: CGFloat) -> CGSize {
            CGSize(width: size.width * zoom, height: size.height * zoom)
        }

        // MARK: The end of a pinch (M4C_CONTRACT §1.3)

        /// The limits now in force (`lastBounds`, or computed afresh).
        private func currentBounds() -> ZoomPolicy.Bounds? {
            if let lastBounds { return lastBounds }
            guard let container else { return nil }
            return ZoomPolicy.bounds(appliedLayout.kind, overview: ZoomPolicy.overviewSize(appliedLayout), viewport: container.bounds.size)
        }

        /// The pinch (or the bounce after it) is over: the offset clamped, the paper redrawn once at
        /// the final zoom, the ratio and the end of zooming reported on the next turn.
        private func finishZoom() {
            guard let canvas else { return }
            canvas.contentOffset = clampedOffset(canvas.contentOffset)
            syncPaperFrame()
            let bounds = currentBounds()
            let ratio = bounds.map { ZoomPolicy.ratio(forZoom: canvas.zoomScale, bounds: $0) } ?? 1
            deliverNextTurn { [weak self] in
                guard let self else { return }
                self.parent.onZoomRatioChange(ratio)
                self.parent.onZoomingChange(false)
            }
        }

        /// Always the next main-actor turn (unlike `deliver`): the ratio and the zooming flag come
        /// synchronously out of UIKit's scroll-view delegate, and the receiver touches SwiftUI state.
        private func deliverNextTurn(_ block: @escaping @MainActor () -> Void) {
            Task { @MainActor in
                block()
            }
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

        /// A finger's double tap (M4C_CONTRACT §4.1): the point in paper coordinates goes to the
        /// owner. With 「指でも書く」 on, PencilKit drew a dot for each tap (the drawing recogniser
        /// runs alongside): the dots of the last half second around the point are removed first, as
        /// one undoable op (M4C-22).
        @objc private func handleDoubleTap(_ r: UITapGestureRecognizer) {
            guard r.state == .ended, let canvas else { return }
            let p = r.location(in: canvas)
            let z = max(canvas.zoomScale, 0.0001)
            let paperPoint = CGPoint(x: p.x / z, y: p.y / z)
            if parent.allowFinger {
                removeDots(near: paperPoint, zoom: z)
            }
            parent.onDoubleTap(paperPoint)
        }

        /// The ids of the strokes that entered the ledger in the last `within` seconds whose paper
        /// bounds fit in 16 pt on screen (16 / zoom lu) and whose centre is within 24 pt (24 / zoom
        /// lu) of `near`: the dots a finger's taps drew.
        func dotStrokeIds(near: CGPoint, zoom: CGFloat, within: TimeInterval = 0.5) -> [String] {
            let z = max(zoom, 0.0001)
            let maxSide = 16 / z
            let maxDistance = 24 / z
            let cutoff = Int(((Date().timeIntervalSince1970 - within) * 1000).rounded())
            var ids: [String] = []
            for stroke in ledger.page.liveStrokes where stroke.t >= cutoff {
                guard let box = ledger.paperBounds(of: stroke.id),
                      box.width <= maxSide, box.height <= maxSide else { continue }
                let dx = box.midX - near.x
                let dy = box.midY - near.y
                guard (dx * dx + dy * dy).squareRoot() <= maxDistance else { continue }
                ids.append(stroke.id)
            }
            return ids
        }

        /// Removes `dotStrokeIds` as one `.removeStrokes` op (undoable). Nothing when there are none.
        private func removeDots(near: CGPoint, zoom: CGFloat) {
            guard let canvas else { return }
            let ids = dotStrokeIds(near: near, zoom: zoom)
            guard !ids.isEmpty else { return }
            let change = ledger.removeStrokes(ids: ids)
            guard !change.isEmpty else { return }
            setDrawing(ledger.drawing(), on: canvas)
            refreshSelection()
            publishPage()
            notifyHistory()
            deliver { [weak self] in self?.parent.onInkBoundsChanged() }
        }

        // MARK: Read only (M5_CONTRACT §3.1)

        /// `blockedInputRecognizer` began: the Pencil touched the read-only paper.
        @objc private func handleBlockedInput(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began else { return }
            parent.onBlockedInput()
        }

        // MARK: UIGestureRecognizerDelegate

        /// The tap recognisers take direct touches only (the Pencil never taps or double-taps the
        /// paper); the finger recogniser is already limited by `allowedTouchTypes`, and so is
        /// `blockedInputRecognizer` (Pencil only): both take the default true here.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard gestureRecognizer === tapRecognizer || gestureRecognizer === doubleTapRecognizer else { return true }
            return touch.type == .direct
        }

        /// With 「指でも書く」 on, PencilKit's `drawingGestureRecognizer` begins on the finger's
        /// touch-down; the taps are recognised alongside it (M4C_CONTRACT §4.1) or they would never
        /// fire. Nothing else runs simultaneously (the finger recogniser of F2 in particular) —
        /// except M5's `blockedInputRecognizer`, which only reports and runs alongside everything
        /// (drawing, pan, pinch, taps; M5_CONTRACT §3.1).
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === blockedInputRecognizer || otherGestureRecognizer === blockedInputRecognizer { return true }
            guard let canvas else { return false }
            let isTap = gestureRecognizer === tapRecognizer || gestureRecognizer === doubleTapRecognizer
            return isTap && otherGestureRecognizer === canvas.drawingGestureRecognizer
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
            dropStrokesOutsideThePaper(on: canvasView)
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

        /// A new stroke whose paper bounds are centred outside the paper (x < 0, x > width, y < 0,
        /// y > height: the centring margin) never reaches the ledger and leaves the canvas at once,
        /// with no undo (M4C-25): `inkCell(forCenter:)` would file it on an edge cell with negative
        /// cell coordinates, and at another zoom or in the web version it would stick out of the paper.
        private func dropStrokesOutsideThePaper(on canvasView: PKCanvasView) {
            let size = appliedLayout.size
            let strokes = canvasView.drawing.strokes
            let kept = strokes.filter { pk in
                if ledger.id(of: pk) != nil { return true }
                let box = StrokeGeometry.paperBounds(of: pk)
                let cx = box.midX
                let cy = box.midY
                return cx >= 0 && cx <= size.width && cy >= 0 && cy <= size.height
            }
            guard kept.count != strokes.count else { return }
            isApplyingDrawing = true
            canvasView.drawing = PKDrawing(strokes: kept)
            isApplyingDrawing = false
            canvasView.undoManager?.removeAllActions()
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

        /// Every frame of a pinch, and synchronously after every `zoomScale` assignment: the content
        /// size, the centring margins and the paper window. The first frame after a bounce redraws.
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let canvas else { return }
            contentSizeFromUIKit = canvas.contentSize
            let size = Self.scaled(appliedLayout.size, by: canvas.zoomScale)
            if canvas.contentSize != size {
                canvas.contentSize = size
            }
            applyInsets()
            syncPaperFrame()
            if needsFinalRedraw, !isLive {
                needsFinalRedraw = false
                finishZoom()
            }
        }

        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
            deliverNextTurn { [weak self] in self?.parent.onZoomingChange(true) }
            #if DEBUG
            NSLog("zoom: begin")
            #endif
        }

        /// The end of a pinch (also called once by the first layout): margins; a clamp only when
        /// `bouncesZoom` is not going to do it (the minimum rose during the pinch, §1.6); the chosen
        /// zoom remembered; then `finishZoom` — at once, or after the bounce (the first
        /// `scrollViewDidZoom` that is not live, with a 0.4 s safety net in case none comes).
        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            guard let canvas else { return }
            applyInsets()
            let zoom = canvas.zoomScale
            if !canvas.isZoomBouncing,
               zoom < canvas.minimumZoomScale - 0.0005 || zoom > canvas.maximumZoomScale + 0.0005 {
                canvas.zoomScale = min(max(zoom, canvas.minimumZoomScale), canvas.maximumZoomScale)
            }
            targetZoom = canvas.zoomScale
            if isLive {
                needsFinalRedraw = true
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(0.4))
                    guard let self, self.needsFinalRedraw, !self.isLive else { return }
                    self.needsFinalRedraw = false
                    self.finishZoom()
                }
            } else {
                finishZoom()
            }
            #if DEBUG
            NSLog("zoom: end scale=%.4f min=%.4f max=%.4f", canvas.zoomScale, canvas.minimumZoomScale, canvas.maximumZoomScale)
            #endif
        }

        // MARK: F4 — the view the scroll view zooms (M4C_CONTRACT §2.5)

        /// `PKCanvasView` is a `UIScrollView`, and a scroll view asks its delegate for the view to
        /// zoom. The person's 0.5.1 could not pinch at all, so the canvas's own drawing subview is
        /// handed back here: the first subview whose class name starts with "PK", else the first
        /// that is not a scroll indicator. Chosen once and kept; nil (logged once) when the canvas
        /// has no such subview yet. Everything else (`paperView`, the overlay, the heading) keeps
        /// reading `zoomScale` / `contentOffset`, and the drawing's coordinates stay paper coordinates.
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            if let zoomingView { return zoomingView }
            let subviews = scrollView.subviews
            let chosen = subviews.first { NSStringFromClass(type(of: $0)).hasPrefix("PK") }
                ?? subviews.first { !($0 is UIImageView) && !NSStringFromClass(type(of: $0)).contains("Indicator") }
            if let chosen {
                zoomingView = chosen
                #if DEBUG
                // Which subview UIScrollView zooms (the CI log shows it next to `zoom: kind=… pinch=%d`).
                NSLog("zoom: zoomingView=%@ subviews=%@", NSStringFromClass(type(of: chosen)) as NSString,
                      subviews.map { NSStringFromClass(type(of: $0)) }.joined(separator: ",") as NSString)
                #endif
                return chosen
            }
            #if DEBUG
            if !loggedMissingZoomingView {
                loggedMissingZoomingView = true
                NSLog("zoom: no subview to zoom (subviews=%@)", subviews.map { NSStringFromClass(type(of: $0)) }.joined(separator: ",") as NSString)
            }
            #endif
            return nil
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
