import Combine
@_spi(SpanLedger) import InkModel
import Layout
import PencilKit
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

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
///     └─ InkOverlayView       above: the lasso / 予定 tool drawing (its input comes through the
///                              container's recognisers: the Pencil's, a writing finger's)
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
///   ignored until both agree; the ledger never mixes pages. 1.1 fix (the lead's review): when another
///   page id arrives while the pen is down or settling, the canvas keeps the old page's drawing until
///   the rebuild, and nothing compares that drawing with the new ledger meanwhile.
/// - The zoom limits come from `ZoomPolicy` (M4C_CONTRACT §1.1, D1; 1.1.1, docs/R1_1_1.md): the minimum
///   is the overview (`fitAll`: the page's overview rectangle fits the paper area both ways), the
///   maximum `max(4 × fit-to-width, 2 × readable)`. Every page opens at its stored ratio of the opening
///   zoom (`Bounds.open`: the `fitAll` of the kind's `baseSize`, so what a page holds does not change
///   it; `initialZoomRatio`, 1 = the opening zoom, top-left); at a ratio above 1 `initialScrollX` /
///   `initialScrollY` (paper lu) are applied once, when the first zoom is known. A paper narrower than
///   the viewport is centred across with `contentInset` (the margins are the desk colour, M4C-25); it
///   always starts at the top of the viewport (1.1.1).
/// - A pinch keeps its absolute zoom across rotations and height changes (D4 / M4C-24: the opening zoom
///   follows the new opening zoom, a paper pinched to the minimum follows the new minimum across a
///   rotation only, a zoomed-in paper is only clamped, and `targetZoom` remembers what the clamp cut
///   off); the ratio is reported (`onZoomRatioChange`) only at the end of a pinch. 1.1.1: at the opening
///   zoom or the minimum the top of the view stays on the same paper y.
/// - 1.1.1: 「今日」 brings today's cell on screen (`revealRect`, `revealTrigger`): at the first layout of
///   the page it opened, and once per trigger on the page already shown. A page opened any other way
///   starts at the top (M4C-18).
/// - While the canvas is zooming or bouncing (`isLive`) the paper window is stretched, not redrawn
///   (F3); the end of the pinch (`scrollViewDidEndZooming`) centres, clamps, redraws once and reports.
/// - Whenever `contentOffset.x`, the zoom or the container's width changes, the owner gets a
///   `PaperViewport` (`onViewportChange`) so the sticky header and the all-day band follow the paper
///   (M4B_CONTRACT §1.3). Finger-driven changes are delivered at once; changes made inside a layout
///   pass or a SwiftUI update are delivered on the next main-actor turn (a `@State` must not change
///   during a view update).
/// - Finger taps (direct touches only) are reported in paper coordinates, with the canvas's zoom at
///   that moment, through `onTap` (1.0.1: the zoom too); a finger's double tap through `onDoubleTap`
///   (week / month / year, D5), the single tap waiting for it.
/// - The finger input of the lasso / 予定 tool goes through the container's own recogniser
///   (`InkFingerGestureRecognizer`, F2), so two fingers always reach the scroll view's pan and pinch.
///   1.1 fix (docs/M7A.md ずれ 47): so does the Pencil's (`InkPencilGestureRecognizer`); the overlay
///   takes no touch itself.
/// - Strokes whose centre lies outside the paper (in a margin) are dropped (M4C-25).
/// - 1.1 (M7A_CONTRACT §3.4, §5.2, K-9): of the strokes *drawn on this canvas* (never one that came
///   from iCloud, an import or undo), one centred more than 6,000 lu below the top of the page's last
///   cell is dropped too (`PaperGrowth.drop`, `onGrowthCapReached`), and so are the newest ones that
///   would take the page past 19,000 strokes (`StrokeBudget.accepted`, `onStrokeBudget(.full)`).
///   Reaching 15,000 (`.many`) and a stroke whose bottom leaves less than 400 lu of the last cell below
///   it (`PaperGrowth.reachesCap`, `onGrowthCapReached`) are reported.
/// - 1.1 (§3.6): when only the height of the page's last cell changed, the drawing is not rebuilt:
///   the ledger adopts the layout and the content size follows (`PaperGrowth.onlyTailHeightChanged`;
///   since 1.1.1 the cell is open to its full length, so only a line below 5,950 lu comes this way).
///   The margins are recomputed on both paths (0-6), the bottom one is `bottomClearance` (the collapsed
///   toolbar's round button, §2.2).
/// - 1.1 (§2.5): an erasure with the eraser (1 stroke or more) is reported once (`onEraseEnded`); a
///   touch of the pen or a writing finger is reported at once (`onPenDown`). A finger tap that leaves
///   the page with the eraser first undoes what that very touch erased (0-22). The dots a leaving tap
///   removes are only strokes this canvas added in the last second, timed by the device's monotonic
///   clock (0-21). 1.1 fix (TestFlight build 12; docs/M7A.md ずれ 46): what the eraser erased is
///   counted whenever PencilKit tells of it while the tool is the eraser, and reported once nothing
///   touches the paper — by the touches the container's `InkTouchObserver` saw (PencilKit's
///   Begin / End only until it has seen one): at once after the Pencil, after `fingerEraseReportDelay`
///   after a finger; an erasure PencilKit never told of is found when the settle wait ends.
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
    /// clamped to the paper). At the opening zoom (ratio 1) the paper starts at the top-left.
    var initialScrollY: CGFloat
    /// Paper x (lu) to show at the left when this canvas first appears at a ratio above 1
    /// (`PageNavigation.initialScrollX`; × the first zoom, clamped to the paper). M4B_CONTRACT §1.3.
    var initialScrollX: CGFloat = 0
    /// A finger tap, in paper coordinates (lu), and the canvas's zoom when it was recognised (1.0.1:
    /// the owner resolves it with that zoom, the same one `tapLeavesPage` was asked with).
    var onTap: (CGPoint, CGFloat) -> Void
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
    /// The zoom to open with, as a ratio of the opening zoom (`Bounds.open`; M4C_CONTRACT §1.3, D4,
    /// 1.1.1). Applied once, at the first layout (a later value is not applied again). The stored ratio
    /// of the page kind, or `--screenshot-zoom`.
    var initialZoomRatio: CGFloat = 1
    /// The paper point (lu) to put at the top-left at the first layout. nil: the rule of §1.3 — the
    /// opening zoom (ratio 1) starts at the top-left, a zoomed-in page at `initialScrollX` / `initialScrollY`.
    /// The way in for `--screenshot-offset`.
    var initialPaperOffset: CGPoint? = nil
    /// 1.1.1: what 「今日」 asks to bring on screen (paper lu): at the first layout of the page it opened,
    /// and once per `revealTrigger` on the page already shown. nil otherwise.
    var revealRect: CGRect? = nil
    var revealTrigger: Int = 0
    /// true on the week / month / year pages. false leaves `doubleTapRecognizer` disabled, so the
    /// single tap is not delayed (the day page).
    var doubleTapEnabled: Bool = false
    /// A finger's double tap, in paper coordinates (lu). The owner turns it into a day with
    /// `layout.dayAt(point:)` (D5).
    var onDoubleTap: (CGPoint) -> Void = { _ in }
    /// Once at the end of a pinch (after the bounce): the new ratio (zoom / the opening zoom; below the
    /// opening zoom it is 1, so nothing is stored, 1.1.1). Never for a rotation or a change of the
    /// overview's height (D4). Always delivered on the next main-actor turn; the receiver only writes
    /// it to `AppSettings`.
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
    /// 1.0.1: whether a finger tap at this paper point (lu) and zoom takes the screen to another page
    /// (the owner's hit test: a date or 「+n件」 → the day page). With 「指でも書く」 the canvas then
    /// removes the dot PencilKit drew for the tap before `onTap`, as the double tap does (M4C-22). A
    /// tap that opens the edit sheet keeps its dot (the page stays). Default: never.
    var tapLeavesPage: (CGPoint, CGFloat) -> Bool = { _, _ in false }
    /// 1.1 (M7A_CONTRACT §2.1): the pen or a writing finger touched the paper — PencilKit began using
    /// its tool (`canvasViewDidBeginUsingTool`), or the lasso / 予定 overlay began tracking. Never for
    /// a finger that only scrolls or taps without 「指でも書く」, never while read only. The owner
    /// folds a toolbar it unfolded from the round button.
    var onPenDown: () -> Void = {}
    /// 1.1 (§2.5): the eraser erased `erased` strokes (1 or more, the touches before the report added
    /// up), reported once when nothing touches the paper any more (1.1 fix, docs/M7A.md ずれ 46: right
    /// after the Pencil lifts, `fingerEraseReportDelay` after a finger; never while something touches).
    /// Undo / redo, iCloud, a reload, the dots a finger tap removes, a lasso move and the strokes a
    /// leaving eraser tap put back are not counted; nothing is reported while read only.
    var onEraseEnded: (_ erased: Int) -> Void = { _ in }
    /// 1.1 (§5.2, K-9): `.many(n)` this canvas's stroke took the page to `StrokeBudget.noticeAt`
    /// (n strokes now); `.full(n)` new strokes were refused (the page had n strokes).
    var onStrokeBudget: (StrokeBudget.Event) -> Void = { _ in }
    /// 1.1 (§3.4): a new stroke was dropped beyond the last cell's limit, or a new stroke in the last
    /// cell went so low that less than 400 lu is left below it (`PaperGrowth.reachesCap`). At most
    /// once per canvas change; the owner shows 「メモ欄はここまでです」 once per page.
    var onGrowthCapReached: () -> Void = {}
    /// 1.1 (§2.2): the bottom margin of the paper (pt) — the collapsed toolbar's round button (60), so
    /// the bottom of the paper can be scrolled above it. 0 = none. (1.1.1: the paper starts at the top,
    /// so there is no centring margin below it to compare with.)
    var bottomClearance: CGFloat = 0
    /// 1.3 (docs/M7C_CONTRACT.md §2.1, §3.1, §3.6): the window of joined week or day pages this canvas shows,
    /// or nil for 1.2.3's one page (the month, the year, the setting off; every input below then does
    /// nothing). With a session the canvas's ledger edits `span.window` laid out as `span.layout` (the
    /// owner passes `layout: span.layout`, a `page` of its virtual id and `.id(span.id)`), its deltas go to the
    /// inbox, it shifts the window when the paper stops, and it never reads `page` or `paper` again: the paper
    /// is the window's (`PaperView.span`, made from `span.layout`). `initialScrollX` / `initialScrollY` /
    /// `initialPaperOffset` / `revealRect` are in the band's lu (the focus page's origin added); at the
    /// opening zoom the focus page opens in the middle of the screen.
    var span: SpanSession? = nil
    /// 1.3 (§3.4 (a)): where the deltas go. nil is the session's own (`span.inbox`); any other box is a
    /// mistake of the owner (Debug stops) and the session's is used, so no delta goes where no one drains it.
    var inbox: SpanInbox? = nil
    /// 1.3 (§3.6, §3.16): the wait of the 0.5 s watch that shifts the window after a stop no scroll-view
    /// call told of (`SyncEngine.init`'s shape; the tests pass `TestSleeper`). The 1.2.3 waits stay real.
    var sleep: @MainActor (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }
    /// 1.3 (§3.6, §3.16): "now" for the watch and the palm (the last Pencil lift).
    var clock: () -> Date = Date.init
    /// 1.3 (D21, K-9): `onStrokeBudget` of the joined path, with the page that owns the strokes.
    var onPageStrokeBudget: (_ pageId: String, _ event: StrokeBudget.Event) -> Void = { _, _ in }
    /// 1.3 (D21): `onGrowthCapReached` of the joined path, with the page that owns the stroke.
    var onPageGrowthCapReached: (_ pageId: String) -> Void = { _ in }
    /// 1.3 (§3.6): a sheet covers the paper; the window does not shift until it is gone.
    var isSheetOpen: Bool = false
    /// 1.3 (§3.6 ◀ ▶, a near 「今日」): each change of `slideTrigger` slides the band exactly `slidePages`
    /// pages (the window shifts when it stops). A 「今日」 on the page already shown is `revealTrigger`'s.
    var slidePages: Int = 0
    var slideTrigger: Int = 0
    /// 1.3 (§3.7, D20): the paper stopped on a focus page (its first day, the visit that ended), on the
    /// next main-actor turn, when the focus day changed or a visit ended.
    var onSpanStop: (SpanSession.Stop) -> Void = { _ in }

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

        // 1.3 (§3.6 the palm): the band's canvas asks before its pan begins; the one page keeps a plain PKCanvasView.
        let container = span == nil
            ? InkCanvasContainerView(paperView: paperView)
            : InkCanvasContainerView(paperView: paperView, canvasView: InkBandCanvasView())
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
    /// A plain `PKCanvasView` (the one page); 1.3: `InkBandCanvasView` for the window of joined pages.
    let canvasView: PKCanvasView
    let overlayView = InkOverlayView()
    var onLayout: (() -> Void)?
    /// The UI tests only (`--screenshot-probe`): the coordinator's `probeValue()`, read out as this
    /// view's accessibility value at the moment it is asked (never stale). nil otherwise.
    var probe: (() -> String)?

    override var accessibilityValue: String? {
        get { probe?() ?? super.accessibilityValue }
        set { super.accessibilityValue = newValue }
    }

    /// The desk behind the paper (M4C-25): #ecebe6, the same in dark mode (the paper is always light,
    /// DESIGN §3.2). The paper view paints its own window in the paper colour, so only the paper is
    /// paper-coloured; the centring margins, overscroll and the outside of the window during a pinch
    /// (M4C-20) show the desk.
    static let deskColor = UIColor(red: 0xec / 255.0, green: 0xeb / 255.0, blue: 0xe6 / 255.0, alpha: 1)

    init(paperView: PaperView, canvasView given: PKCanvasView? = nil) {
        self.paperView = paperView
        canvasView = given ?? PKCanvasView()
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
        /// 1.1 fix (TestFlight build 12; docs/M7A.md ずれ 47): the Pencil's input of the lasso / 予定 tool,
        /// on the container (the overlay takes no touch: a touch's type cannot be told while UIKit
        /// hit-tests it). Enabled while an overlay tool is up and the app is not read only, whatever
        /// `allowFinger` says (`syncRecognizers`). It never recognises, so nothing waits for it, and the
        /// pan needs no `require(toFail:)`: the pan takes no Pencil while it is on (PencilKit's takes
        /// only fingers on a Mac; `syncRecognizers` leaves the Pencil out should an iOS's take it).
        private(set) lazy var pencilOverlayRecognizer: InkPencilGestureRecognizer = {
            let r = InkPencilGestureRecognizer(target: nil, action: nil)
            r.delegate = self
            return r
        }()
        /// 1.1 fix (TestFlight build 12; docs/M7A.md ずれ 46): the touches on the paper as they come down
        /// and lift (`touchObserved`), on the container. Always on; it never recognises, never delays
        /// or cancels a touch and runs alongside every recogniser (`InkTouchObserver`).
        private(set) lazy var touchObserver: InkTouchObserver = {
            let r = InkTouchObserver(target: nil, action: nil)
            r.delegate = self
            r.onChange = { [weak self] change in self?.touchObserved(change) }
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
        private var lastRevealTrigger: Int

        private enum HistoryAction { case undo, redo }
        /// PencilKit's tool is in use (Begin → End) or the overlay is tracking. Readable for the tests.
        private(set) var isUsingTool = false
        private var isSettling = false
        private var settleGeneration = 0
        /// The drawing must be rebuilt (page reload, undo / redo, a new page).
        private var pendingDrawing = false
        /// 1.1 (M7A_CONTRACT §3.6): the layout's geometry changed. `applyPending` decides: only the
        /// last cell's height → the light path (no new drawing), anything else → rebuilt like
        /// `pendingDrawing`.
        private var pendingGeometry = false
        /// The paper content changed (now line, chips, lanes …); rebuilt together with the drawing.
        private var pendingPaper = false
        private var pendingHistory: [HistoryAction] = []
        /// Commands from the owner, performed with the next apply (after the pen lifts).
        private var pendingCommands: [CanvasCommand] = []
        /// A different page id arrived: fit the zoom again and scroll to `initialScrollY` instead
        /// of compensating. 1.1 fix (the lead's review, docs/M7A.md ずれ 46): until `applyPending`
        /// rebuilds the drawing, the canvas still shows the old page, which the new ledger's
        /// fingerprints do not describe, so nothing compares the two meanwhile (`applyCanvasDrawing`).
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

        // 1.1 (M7A_CONTRACT §2.4, §2.5, §3.6, §4.1)
        /// How many times `setDrawing` put a drawing on the canvas (tests: the light path of §3.6
        /// must not rebuild it).
        private(set) var setDrawingCount = 0
        /// Strokes the eraser erased since the last report (§2.5): added up until the report goes out
        /// (`scheduleEraseReport`), carried over when a new touch cuts the wait for it short.
        private var erasedSinceReport = 0
        /// The ids the eraser erased during the current (or last) touch (§2.4), emptied when a touch
        /// begins.
        private var removedSinceTouch: [String] = []
        /// `uptime()` when the current (or last) touch began (`penDidTouch`).
        private var touchBeganAt: TimeInterval = -.infinity
        /// `UITouch.timestamp` of the finger the single-tap recogniser last received (the same clock
        /// as `systemUptime`). Internal so the tests can stand in for a real touch.
        var tapTouchBeganAt: TimeInterval = .infinity
        /// The strokes this canvas added itself (`applyCanvasChange`'s `added`, §4.1, 0-21), with the
        /// device's monotonic time they were added: the only candidates for a finger tap's dots.
        /// At most 2 s old and 64 entries; emptied by `detach()` and when the page changes.
        private var recentAdds: [(at: TimeInterval, id: String)] = []
        /// The device's monotonic clock (s; `systemUptime`, the clock of `UITouch.timestamp`). Replaces
        /// 1.0.1's `clock`; the tests pin it.
        var uptime: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }

        // 1.1 fix (TestFlight build 12, 確認 4・5・6b; docs/M7A.md ずれ 46). On a device the eraser did
        // not go back to the pen: the report hung on PencilKit's Begin / change / End coming in the
        // order and within the times the tests assumed. Now what the eraser erased is counted whenever
        // the change comes while the tool is the eraser (⑥), and the report goes out when nothing
        // touches the paper any more (`touchingPaper`, `scheduleEraseReport`) — by the touches
        // `touchObserver` saw; PencilKit's `isUsingTool` only until it has seen one.
        /// The Pencil touches, the finger touches and the pointer's presses (a mouse, a trackpad) that are
        /// on the paper (`touchObserved`; never < 0). The lead's review: a pointer is counted on its own
        /// and always writes. On a Mac PencilKit draws with any touch whatever 「指でも書く」 says (its
        /// drawing recogniser takes `[0, 2, 3]` in both drawing policies and a finger drew under
        /// `.pencilOnly` too); an iOS is not known yet (A17's `repro:` line prints its types), so a pointer
        /// is taken as writing — the safe side: at worst a report waits until it lifts.
        private var pencilsDown = 0
        private var fingersDown = 0
        private var pointersDown = 0
        /// `touchObserver` has seen a touch: from then on it alone tells whether the paper is touched.
        private var observerReady = false
        /// The writing touch that lifted last was a finger or a pointer (`fingerEraseReportDelay`, not
        /// the Pencil's).
        private var lastLiftWasFinger = false
        /// The report scheduled last (`scheduleEraseReport`): a newer schedule, a new writing touch and
        /// `detach` move it on, so the older one does nothing.
        private var eraseReportGeneration = 0
        /// A report is scheduled and has not run: it also carries what is counted in the meantime.
        private var eraseReportPending = false
        /// The watch for an End that never comes (`startLiftWatch`).
        private var liftWatchGeneration = 0
        /// The lead's review (案 a): the lift watch took the pen as lifted (`W`) and PencilKit has said
        /// nothing since (no Begin, no End). For PencilKit its tool may still be in use, and it may write
        /// the next touch without a Begin: the next writing touch that comes down with PencilKit's tool
        /// (not read only) is taken as the tool in use (`touchObserved`), so nothing queued lands under it.
        private var liftTakenByWatch = false
        /// The current (or last) touch began with the eraser: the end of its settle wait takes in an
        /// erasure PencilKit never told of, even when the report has already put the pen back.
        private var touchBeganWithEraser = false
        /// The review (ずれ 47): PencilKit's pan took the Pencil, and `syncRecognizers` left it out for an
        /// overlay tool; it is given back when the overlay no longer takes the Pencil.
        private var panPencilLeftOut = false

        /// The eraser's report after the Pencil lifts: at once (the next turn), so the stroke a quick
        /// hand writes next is ink (確認 6b; of §2.4's two answers, "go back at the lift").
        static let pencilEraseReportDelay: TimeInterval = 0
        /// After a writing finger lifts on the week, month and year pages: a single tap on a date waits
        /// about 0.35 s for the double tap to fail (M4C-6), and it must put back what its own touch
        /// erased (0-22) before the report (docs/M7A.md ずれ 38). The day page has no double tap.
        static let fingerEraseReportDelayWithDoubleTap: TimeInterval = 0.5
        /// Nothing has touched the paper for this long while PencilKit still says its tool is in use
        /// (its End never came, or it began for the Pencil's hover): the pen is taken as lifted
        /// (`penDidLift`), so undo / redo and a growing memo area are not held up.
        static let liftWithoutEndGrace: TimeInterval = 0.5

        /// `settleDelay` on the day page (no double tap to wait for).
        private var fingerEraseReportDelay: TimeInterval {
            parent.doubleTapEnabled ? Self.fingerEraseReportDelayWithDoubleTap : InkCanvasView.settleDelay
        }

        /// Something that writes (or erases) touches the paper: the Pencil, a pointer's press, or a finger
        /// with 「指でも書く」 (`writes`). Decides the eraser's report and the lift watch only.
        private var touchingPaper: Bool {
            guard observerReady else { return isUsingTool }
            return pencilsDown > 0 || pointersDown > 0 || (parent.allowFinger && fingersDown > 0)
        }

        // The UI tests only (`--screenshot-probe`, `EraserAndBelowDayUITests`): the last canvas events
        // as short tokens with their time (ms since `attach`), read out with the counts and the
        // geometry through the container's accessibility value (`probeValue()`). Off and empty otherwise.
        /// The accessibility identifier of the probed container.
        static let probeIdentifier = "ink-canvas"
        private var probeOn = false
        private var probeStart: TimeInterval = 0
        private var probeTrace: [String] = []

        /// 1.3 (docs/M7C_CONTRACT.md §3.6): the window of joined pages (`parent.span` when this canvas was made);
        /// nil on the one-page path, where none of the joined path's code runs. Its code is the extension at
        /// the end of this file.
        private var spanState: InkSpanState?

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
            lastRevealTrigger = parent.revealTrigger
            lastInitialSelectionIds = parent.initialSelectionIds
            initialSelectionPending = !parent.initialSelectionIds.isEmpty
            // A local so nothing on `self` is read before super.init (two-phase initialisation).
            let handler = PencilInteractionHandler()
            pencilHandler = handler
            pencilInteraction = handler.makeInteraction()
            super.init()
            handler.onToggle = { [weak self] in self?.parent.onPencilToggle() }
            if parent.span != nil { beginSpan() }
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
            // bounce means "never smaller than the overview" (M4C-13). 1.1.1: a page that holds no more
            // than its `baseSize` opens at that limit, so a pinch inward only bounces there.
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
            // 1.1 fix (ずれ 47): the Pencil of the lasso / 予定 tool reaches the overlay through this one
            // (nothing waits for it). 1.1 fix (ずれ 46): the touches on the paper, for the eraser's report.
            pencilOverlayRecognizer.overlay = container.overlayView
            container.addGestureRecognizer(pencilOverlayRecognizer)
            container.addGestureRecognizer(touchObserver)
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
            if spanState != nil { attachSpan(container) }
            syncPaperFrame()
            InkTrace.note("A:\(appliedLayout.kind.rawValue)")

            // The UI tests' probe (never in the photos or in normal use).
            if ScreenshotMode.current?.probe == true {
                startProbe()
                container.isAccessibilityElement = true
                container.accessibilityIdentifier = Self.probeIdentifier
                container.accessibilityLabel = "手書きの紙"
                container.probe = { [weak self] in self?.probeValue() ?? "detached" }
            }
        }

        /// Starts the trace of `probeNote` (times from now). `attach` calls it for `--screenshot-probe`;
        /// the unit tests that send real touches through UIKit call it to print what the canvas saw.
        func startProbe() {
            guard !probeOn else { return }
            probeOn = true
            probeStart = uptime()
        }

        /// Notes one canvas event for the UI tests (`probeOn` only): `B` / `E` PencilKit began / ended
        /// using its tool, `C+a-r` a drawing change the ledger applied (a added, r removed; then `u`
        /// while the tool is in use, `s` while settling, `e` when the tool is the eraser — ⑥ counts
        /// r − a of a change with `e` when it is positive), `C0` a change that changed nothing, `c` one
        /// the guard skipped (our own drawing, a lasso move, the old page's drawing before the rebuild
        /// after a page change), `r` a settle wait a new touch cut short, `O` / `o` the overlay began /
        /// stopped tracking, `L<n>` a lasso selected n strokes, `T` a finger tap. 1.1 fix (ずれ 46): `Dp` /
        /// `Df` / `Di` a Pencil / finger / pointer (a mouse, a trackpad) came down and `Up` / `Uf` / `Ui`
        /// lifted (`touchObserver`), `S<s>` the eraser's report scheduled in s seconds, `R<n>` the report
        /// of n erased strokes, `W` the lift watch took the pen as lifted (no End came), `Bw` a writing
        /// touch came down after it with no `B` and is taken as the tool in use (PencilKit may write it
        /// without a Begin; the lead's review, 案 a), `K` the end of the settle wait found an erasure
        /// PencilKit never told of. Each token ends in `@<ms since attach>`; the last 48 are kept.
        /// 1.1 fix (ずれ 46): every token also goes to `InkTrace` (always; TestFlight's 「記録」).
        private func probeNote(_ token: @autoclosure () -> String) {
            let text = token()
            InkTrace.note(text)
            guard probeOn else { return }
            let ms = Int(((uptime() - probeStart) * 1000).rounded())
            probeTrace.append("\(text)@\(ms)")
            if probeTrace.count > 48 {
                probeTrace.removeFirst(probeTrace.count - 48)
            }
        }

        /// What the probed container reads out (`key=value` pairs joined by `;`): the page, the zoom and
        /// the content offset (pt) that map paper lu to the container (screen = frame origin + lu ×
        /// zoom − offset), the paper size (lu), the strokes PencilKit holds (`pk`) and the ledger's live
        /// strokes (`ink`), the tool, the erasures not yet reported (`pending`), the touches on the
        /// paper (`down`) and the event trace.
        func probeValue() -> String {
            guard let canvas else { return "detached" }
            func number(_ value: CGFloat) -> String { String(format: "%.3f", Double(value)) }
            let size = appliedLayout.size
            return [
                "page=\(appliedLayout.pageId)",
                "zoom=\(String(format: "%.5f", Double(canvas.zoomScale)))",
                "ox=\(number(canvas.contentOffset.x))",
                "oy=\(number(canvas.contentOffset.y))",
                "pw=\(number(size.width))",
                "ph=\(number(size.height))",
                "pk=\(canvas.drawing.strokes.count)",
                "ink=\(ledger.page.liveStrokeCount)",
                "tool=\(Self.probeName(parent.tool))",
                "pending=\(erasedSinceReport)",
                // 1.1 fix: the touches `touchObserver` counts (`-` until it has seen one): Pencils,
                // fingers and (the lead's review) the pointer's presses.
                "down=\(observerReady ? "\(pencilsDown)p\(fingersDown)f\(pointersDown)i" : "-")",
                "trace=\(probeTrace.joined(separator: " "))",
            ].joined(separator: ";")
        }

        /// `pen:#dc2626:6`, `marker:#fde047:18`, `eraser`, `lasso`, `event`.
        static func probeName(_ tool: CanvasTool) -> String {
            switch tool {
            case .ink(let style):
                return "\(style.tool.rawValue):\(style.colorHex):\(String(format: "%g", Double(style.width)))"
            case .eraser:
                return "eraser"
            case .lasso:
                return "lasso"
            case .eventRect:
                return "event"
            }
        }

        func detach() {
            if spanState != nil { detachSpan() }
            settleGeneration += 1
            isSettling = false
            erasedSinceReport = 0
            removedSinceTouch = []
            recentAdds.removeAll()
            // 1.1 fix (ずれ 46): no report and no lift watch after this.
            eraseReportGeneration += 1
            eraseReportPending = false
            liftWatchGeneration += 1
            liftTakenByWatch = false
            pencilsDown = 0
            fingersDown = 0
            pointersDown = 0
            overlay?.delegate = nil
            canvas?.delegate = nil
            container = nil
        }

        /// `doubleTapRecognizer` is on while the owner asks for it and no overlay tool is up;
        /// `fingerRecognizer` while an overlay tool is up, the finger may write and the app is not
        /// read only; 1.1 fix: `pencilOverlayRecognizer` while an overlay tool is up and the app is not
        /// read only. A disabled recogniser fails at once, so the recognisers waiting for it are not
        /// delayed. M5 (M5_CONTRACT §3.1): the read-only rule is applied here too (`readOnly` alone
        /// may change under the same tool): `blockedInputRecognizer` on, PencilKit's drawing
        /// recogniser and the overlay's input off. `touchObserver` is always on. The review (ずれ 47): the
        /// canvas's pan takes no Pencil while `pencilOverlayRecognizer` is on (below).
        private func syncRecognizers() {
            let doubleTap = parent.doubleTapEnabled && !parent.tool.isOverlayTool
            if doubleTapRecognizer.isEnabled != doubleTap {
                doubleTapRecognizer.isEnabled = doubleTap
            }
            let finger = parent.tool.isOverlayTool && parent.allowFinger && !parent.readOnly
            if fingerRecognizer.isEnabled != finger {
                fingerRecognizer.isEnabled = finger
            }
            let pencil = parent.tool.isOverlayTool && !parent.readOnly
            if pencilOverlayRecognizer.isEnabled != pencil {
                pencilOverlayRecognizer.isEnabled = pencil
            }
            if blockedInputRecognizer.isEnabled != parent.readOnly {
                blockedInputRecognizer.isEnabled = parent.readOnly
            }
            if let canvas {
                let drawing = !parent.tool.isOverlayTool && !parent.readOnly
                if canvas.drawingGestureRecognizer.isEnabled != drawing {
                    canvas.drawingGestureRecognizer.isEnabled = drawing
                }
                // The review (ずれ 47): the Pencil's loop or rect must not scroll the paper under it.
                // PencilKit's pan takes fingers only on a Mac (`[direct]` in every drawing policy,
                // measured); should an iOS's take the Pencil, it is left out while the overlay takes
                // the Pencil and given back after. This runs after every `drawingPolicy` change.
                let pan = canvas.panGestureRecognizer
                let pencilType = NSNumber(value: UITouch.TouchType.pencil.rawValue)
                if pencil, pan.allowedTouchTypes.contains(pencilType) {
                    pan.allowedTouchTypes = pan.allowedTouchTypes.filter { $0 != pencilType }
                    panPencilLeftOut = true
                } else if !pencil, panPencilLeftOut {
                    panPencilLeftOut = false
                    if !pan.allowedTouchTypes.contains(pencilType) {
                        pan.allowedTouchTypes.append(pencilType)
                    }
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
            let oldClearance = parent.bottomClearance
            parent = newParent
            guard let canvas else { return }
            isUpdating = true
            defer { isUpdating = false }

            // 1. The page: another page id (new ledger), or the same page from outside (merge, import).
            let signature = PageSignature(newParent.page)
            if spanState != nil {
                // 1.3 (§3.4): the joined path never reads `page` (no page is written back whole); a window the
                // session composed again is taken once the pen is up (`applyPendingSpan`).
                noteSessionWindow()
            } else if signature.pageId != ledger.page.pageId {
                overlay?.cancelGesture()
                clearSelection()
                ledger = InkLedger(page: newParent.page, layout: newParent.layout, deviceId: deviceId)
                publishedSignature = signature
                pendingDrawing = true
                resetScroll = true
                pendingHistory.removeAll()
                // 1.1 (§4.1): the dot candidates and the eraser's touch belong to the old page.
                recentAdds.removeAll()
                removedSinceTouch = []
                notifyHistory()
            } else if signature != publishedSignature {
                ledger.reload(page: newParent.page, keepHistory: true)
                publishedSignature = signature
                pendingDrawing = true
                notifyHistory()
            }

            // 2. Layout geometry (kind / page / size / cells) and paper content. 1.1 (§3.6): a change of
            // geometry alone is `pendingGeometry`; `applyPending` takes the light path when only the
            // last cell's height changed.
            if !appliedLayout.sameGeometry(as: newParent.layout) {
                pendingGeometry = true
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
                probeNote("T:\(Self.probeName(newParent.tool))")
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
            // 1.1 (§2.2): the round button's clearance applies at once (it moves no stroke).
            if newParent.bottomClearance != oldClearance {
                applyInsets()
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

            if spanState != nil { noteSpanTriggers(newParent) }
            if pendingDrawing || pendingPaper || pendingGeometry || !pendingCommands.isEmpty {
                requestApply()
            }

            // 7. 1.1.1: 「今日」 on the page already shown (once per trigger; never under the pen or a pinch).
            if newParent.revealTrigger != lastRevealTrigger {
                lastRevealTrigger = newParent.revealTrigger
                if hasInitialZoom, !isLive, !isUsingTool, let rect = newParent.revealRect {
                    reveal(rect)
                }
            }
        }

        // MARK: Applying queued work (pen up only)

        private func requestApply() {
            guard !isUsingTool, !isSettling else { return }
            applyPending()
        }

        private func applyPending() {
            if spanState != nil { applyPendingSpan(); return }
            let wasApplyingGeometry = isApplyingGeometry
            isApplyingGeometry = true
            defer { isApplyingGeometry = wasApplyingGeometry }
            guard let canvas, let container else { return }
            let commands = pendingCommands
            pendingCommands.removeAll()
            var drawingWork = pendingDrawing
            let paperWork = pendingPaper
            let geometryWork = pendingGeometry
            pendingDrawing = false
            pendingPaper = false
            pendingGeometry = false

            var historyChanged = false
            var inkBoundsChanged = false
            for command in commands where perform(command) {
                drawingWork = true
                historyChanged = true
                inkBoundsChanged = true
            }
            guard drawingWork || paperWork || geometryWork else { return }

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
            // 1.1 (M7A_CONTRACT §3.6): only the height of the last cell changed (the month's memo area,
            // the day's free memo area grew or shrank with its handwriting) and nothing else needs a
            // new drawing — every cell keeps its origin, so the strokes stay where they are.
            let tailOnly = !drawingWork && geometryWork && !resetScroll
                && PaperGrowth.onlyTailHeightChanged(old: oldLayout, new: newLayout)
            if !tailOnly {
                drawingWork = drawingWork || geometryWork
            }

            if tailOnly {
                // The light path: no `setDrawing`, no `applyBounds` (the overview rectangle is the fixed
                // part of the page, K-6), no scroll compensation (no band's top moved). 1.1.1: only a line
                // past 5,950 lu comes this way (the cell is open to 6,000 from the start): a 1.0 device's, or
                // this device's written near the end of the cell or moved there with the lasso.
                ledger.adopt(newLayout)
                appliedLayout = newLayout
                canvas.contentSize = Self.scaled(newLayout.size, by: zoom)
                overlay?.pageSize = newLayout.size
                applyInsets()
                if !isLive {
                    // A shorter paper must not leave the viewport below its end.
                    canvas.contentOffset = clampedOffset(canvas.contentOffset)
                }
                #if DEBUG
                let oldTail = PaperGrowth.tail(of: oldLayout)?.rect.height ?? 0
                let newTail = PaperGrowth.tail(of: newLayout)?.rect.height ?? 0
                NSLog("canvas: tail-only %@ %.0f→%.0f", newLayout.pageId as NSString, oldTail, newTail)
                #endif
            } else if drawingWork {
                setDrawing(ledger.relayout(newLayout), on: canvas)
                appliedLayout = newLayout
                canvas.contentSize = Self.scaled(newLayout.size, by: zoom)
                overlay?.pageSize = newLayout.size
                // 1.1 (0-6): a paper that only got taller or shorter at the same zoom gets its margins
                // again (1.0 kept the old ones until the next layout pass).
                applyInsets()
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
                // (The opening zoom does not depend on the page, `revealRect` is read again.)
                hasInitialZoom = false
                containerDidLayout()
            } else if drawingWork, geometryChanged {
                // The overview rectangle grew or shrank with handwriting / events (a month row, a
                // year row): only the lower limit changes (1.1.1). The opening zoom comes from the
                // kind's `baseSize`, so a page at that zoom keeps it and the paper being written on
                // does not shrink (a zoom below a raised limit is clamped).
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
            setDrawingCount += 1
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
        /// 2. Same limits as last time: only the margins and the paper window are refreshed.
        /// 3. The first time: the limits, the zoom for `initialZoomRatio` (assigned through
        ///    `zoomScale`, so UIKit's `scrollViewDidZoom` does the same synchronisation as a pinch),
        ///    the margins, the content size, the first offset (`initialPaperOffset`; the top-left at
        ///    the opening zoom; `initialScrollX` / `Y` above it; then `revealRect`, 1.1.1), then the
        ///    end-of-pinch path once (`scrollViewDidEndZooming`: margins, clamp, the ratio report) and
        ///    the DEBUG log.
        /// 4. The width changed (rotation, Split View): the opening zoom stays the opening zoom and the
        ///    minimum the minimum, with the top of the view on the same paper y (1.1.1); a zoomed-in
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
            // 1.3 (§3.6): the window's limits come from one page's overview (the middle one), never the band's.
            let overview = spanState == nil ? ZoomPolicy.overviewSize(appliedLayout) : bandZoomOverview()
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
                    // The opening zoom: the top-left (M4C-18), inside the left margin.
                    canvas.contentOffset = CGPoint(x: -inset.left, y: -inset.top)
                } else {
                    // Zoomed in: paper lu × the zoom, clamped to the paper (M3A §2.2 for y,
                    // M4B_CONTRACT §1.3 for x). Not finite → 0, negative → 0.
                    let x = parent.initialScrollX.isFinite ? max(0, parent.initialScrollX) : 0
                    let y = parent.initialScrollY.isFinite ? max(0, parent.initialScrollY) : 0
                    canvas.contentOffset = clampedOffset(CGPoint(x: x * zoom, y: y * zoom))
                }
                if spanState != nil { applyBandOpening(zoom: zoom, bounds: bounds) }
                // 1.1.1: the page 「今日」 opened goes on to today's cell (any other opening stays at the top).
                if parent.initialPaperOffset == nil, let rect = parent.revealRect {
                    reveal(rect)
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
                let base = ZoomPolicy.baseSize(appliedLayout.kind)
                NSLog("zoom: kind=%@ pinch=%d enabled=%d min=%.4f max=%.4f zoom=%.4f fitAll=%.4f open=%.4f ratio=%.3f view=%.0fx%.0f overview=%.0fx%.0f base=%.0fx%.0f",
                      appliedLayout.kind.rawValue as NSString, Int32(pinch == nil ? 0 : 1), Int32((pinch?.isEnabled ?? false) ? 1 : 0),
                      bounds.min, bounds.max, canvas.zoomScale, bounds.min, bounds.open,
                      ZoomPolicy.ratio(forZoom: canvas.zoomScale, bounds: bounds),
                      viewport.width, viewport.height, overview.width, overview.height, base.width, base.height)
                #endif
                return
            }

            let live = isLive
            if viewport.width != lastLayoutSize.width {
                // 4. The width changed.
                let oldMin = canvas.minimumZoomScale
                let oldZoom = max(canvas.zoomScale, 0.0001)
                let oldOpen = lastBounds?.open ?? oldMin
                let atOpen = abs(oldZoom - oldOpen) < 0.0005
                let atMin = abs(oldZoom - oldMin) < 0.0005
                // Read before the limits change: UIKit may move the zoom and the offset with them.
                let oldOffset = canvas.contentOffset
                canvas.minimumZoomScale = bounds.min
                canvas.maximumZoomScale = bounds.max
                if !live {
                    let centerPaper = CGPoint(
                        x: (oldOffset.x + viewport.width / 2) / oldZoom,
                        y: (oldOffset.y + viewport.height / 2) / oldZoom
                    )
                    let topY = oldOffset.y / oldZoom
                    let newZoom = atOpen ? bounds.open : (atMin ? bounds.min : bounds.clamped(targetZoom ?? oldZoom))
                    canvas.zoomScale = newZoom
                    canvas.contentSize = Self.scaled(appliedLayout.size, by: newZoom)
                    applyInsets()
                    canvas.contentOffset = clampedOffset(CGPoint(
                        x: centerPaper.x * newZoom - viewport.width / 2,
                        // 1.1.1: at the opening zoom or the minimum the top of the view stays on the same
                        // paper y: the paper is longer than the viewport now, so the clamp no longer
                        // brings it back to the top.
                        y: (atOpen || atMin) ? topY * newZoom : centerPaper.y * newZoom - viewport.height / 2
                    ))
                }
                if spanState != nil { bandWidthChanged() }
            } else {
                // 5. Only the height changed.
                if spanState != nil { bandHeightWillChange() }
                applyBounds(bounds)
                if spanState != nil { bandHeightChanged() }
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

        /// True when fit, open, min and max all differ by less than 0.0005.
        private static func sameBounds(_ a: ZoomPolicy.Bounds, _ b: ZoomPolicy.Bounds) -> Bool {
            abs(a.fit - b.fit) < 0.0005 && abs(a.open - b.open) < 0.0005 && abs(a.min - b.min) < 0.0005 && abs(a.max - b.max) < 0.0005
        }

        /// New limits without a change of width (the band grew, a month / year row grew with ink or
        /// events; M4C_CONTRACT §1.3). The limits are always updated; the zoom only when no pinch is
        /// live: a paper at the opening zoom follows the new opening zoom with the top of the view on
        /// the same paper y (1.1.1; `targetZoom` with it), any other paper — a paper pinched to the
        /// minimum too, so the paper being written on does not move — is clamped only when it fell
        /// outside the new range, and then keeps the top of the view on the same paper y too. The ratio
        /// is not reported.
        private func applyBounds(_ bounds: ZoomPolicy.Bounds) {
            guard let canvas else { return }
            let oldZoom = max(canvas.zoomScale, 0.0001)
            let atOpen = abs(oldZoom - (lastBounds?.open ?? canvas.minimumZoomScale)) < 0.0005
            // Read before the limits change: UIKit may move the zoom and the offset with them.
            let topY = canvas.contentOffset.y / oldZoom
            canvas.minimumZoomScale = bounds.min
            canvas.maximumZoomScale = bounds.max
            lastBounds = bounds
            guard !isLive else { return }
            if atOpen {
                if abs(oldZoom - bounds.open) >= 0.0005 {
                    canvas.zoomScale = bounds.open
                    canvas.contentOffset = clampedOffset(CGPoint(x: canvas.contentOffset.x, y: topY * bounds.open))
                }
                targetZoom = bounds.open
            } else {
                if canvas.zoomScale < bounds.min || canvas.zoomScale > bounds.max {
                    canvas.zoomScale = bounds.clamped(canvas.zoomScale)
                }
                // By the zoom it ended on, not by the test above: UIKit may have clamped it with the limits.
                if abs(canvas.zoomScale - oldZoom) >= 0.0005 {
                    canvas.contentOffset = clampedOffset(CGPoint(x: canvas.contentOffset.x, y: topY * canvas.zoomScale))
                }
            }
        }

        /// The margins of the whole paper (`layout.size`, never the overview rectangle) at the current
        /// zoom (M4C_CONTRACT §1.3). `contentInsetAdjustmentBehavior` is `.never`, so the inset is ours to
        /// set. Margins under 1 µpt are 0 (fit-to-width leaves floating-point dust). 1.1.1
        /// (docs/R1_1_1.md): centred across only. The top is 0 and the bottom `bottomClearance` (1.1,
        /// M7A_CONTRACT §2.2: the bottom of the paper can be scrolled above the collapsed toolbar's
        /// round button), so a short paper starts under the heading and what is left stays below it.
        private func applyInsets() {
            guard let container, let canvas else { return }
            let inset = ZoomPolicy.centeringInsets(paper: appliedLayout.size, zoom: canvas.zoomScale, viewport: container.bounds.size)
            let horizontal = inset.width < 1e-6 ? 0 : inset.width
            let clearance = parent.bottomClearance.isFinite ? max(0, parent.bottomClearance) : 0
            let edges = UIEdgeInsets(top: 0, left: horizontal, bottom: clearance, right: horizontal)
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
        /// max(−inset.left, contentSize.width + inset.right − width)], y likewise. A paper centred across
        /// therefore rests at a negative x. Not finite → the top-left.
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

        /// 1.1.1: brings `rect` (paper lu) on screen with the least movement, above the round button's
        /// clearance (`ZoomPolicy.revealOffset`, then the clamp to the paper). `setContentOffset` rather
        /// than the property: it also stops a scroll still decelerating or bouncing, which would carry
        /// the row away again (「今日」 right after a flick).
        private func reveal(_ rect: CGRect) {
            guard let container, let canvas else { return }
            var viewport = container.bounds.size
            viewport.height -= canvas.contentInset.bottom
            canvas.setContentOffset(clampedOffset(ZoomPolicy.revealOffset(rect: rect, zoom: canvas.zoomScale, viewport: viewport, current: canvas.contentOffset)), animated: false)
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
            if spanState != nil { putJournalIntoInbox(); return }
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
            fingerTapped(atPaper: CGPoint(x: location.x / zoom, y: location.y / zoom), zoom: zoom)
        }

        /// How far back a single tap's dot may have been drawn (s; 1.0.1). The single tap waits about
        /// 0.3 s for the double tap to fail (M4C-6) before it is recognised, so the double tap's 0.5 s
        /// would be too tight.
        static let singleTapDotWindow: TimeInterval = 1.0

        /// 1.0.1: a tap that takes the screen to another page (`tapLeavesPage`) first removes the dot
        /// 「指でも書く」 drew for it (M4C-22, one undoable op; not while read only), then reports with the
        /// same zoom — before the owner saves and leaves the page (the same order as the double tap).
        /// 1.1 (M7A_CONTRACT §2.4, 0-22): with the eraser, what that very touch erased is undone first
        /// (`undoEraserTap`): the person would otherwise leave the page without seeing it go.
        /// `tapLeavesPage` is still asked once at most.
        func fingerTapped(atPaper point: CGPoint, zoom: CGFloat) {
            probeNote("T")
            if parent.allowFinger, !parent.readOnly, parent.tapLeavesPage(point, zoom) {
                undoEraserTap()
                removeDots(near: point, zoom: zoom, within: Self.singleTapDotWindow)
            }
            parent.onTap(point, zoom)
        }

        /// How the eraser's last touch is matched to the tap's finger (§2.4): it began no more than
        /// `eraserTapLead` before the finger touched down (`tapTouchBeganAt` is the touch's own time,
        /// `touchBeganAt` the moment PencilKit told of it) and less than `eraserTapLag` after it
        /// (PencilKit may tell of a finger's tool only once the finger moves or lifts, more than
        /// 0.1 s into an ordinary tap). An earlier touch began before the finger and is never matched.
        static let eraserTapLead: TimeInterval = 0.05
        static let eraserTapLag: TimeInterval = 0.5

        /// The eraser's half of a leaving tap (§2.4): when the last touch erased something with the
        /// eraser (`removedSinceTouch`, filled only while the tool was the eraser) and that touch is
        /// the tap's own finger (it began from `eraserTapLead` before to `eraserTapLag` after
        /// `tapTouchBeganAt`; what an earlier touch erased stays erased, and a touch that begins after
        /// the erasing one empties `removedSinceTouch`), the ledger undoes exactly that
        /// (`undoIfTopRestores`: the strokes come back as clones with new ids). The strokes put back are
        /// taken off `erasedSinceReport`, so the tool does not return to the pen for them. Nothing when
        /// the top of the history is any other op.
        ///
        /// The tool is deliberately not asked again here (docs/M7A.md ずれ 33). The tap normally comes
        /// before the eraser's report and takes its strokes off the count, so nothing is reported and
        /// the tool stays the eraser: on the day page it does not wait (no double tap) and the report
        /// after a finger waits 0.3 s; on the week, month and year pages it waits about 0.35 s for the
        /// double tap to fail (M4C-6) and the report waits 0.5 s (`fingerEraseReportDelay`; 1.1 fix,
        /// ずれ 46). Should the tap come later (a busy device), the report has gone out and the
        /// toolbar's eraser may already be back on the pen; the strokes that touch erased still come back.
        private func undoEraserTap() {
            guard !removedSinceTouch.isEmpty,
                  touchBeganAt >= tapTouchBeganAt - Self.eraserTapLead,
                  touchBeganAt - tapTouchBeganAt < Self.eraserTapLag, let canvas else { return }
            let ids = Set(removedSinceTouch)
            guard let drawing = ledger.undoIfTopRestores(ids: ids) else { return }
            setDrawing(drawing, on: canvas)
            refreshSelection()
            publishPage()
            notifyHistory()
            erasedSinceReport = max(0, erasedSinceReport - ids.count)
            removedSinceTouch = []
            deliver { [weak self] in self?.parent.onInkBoundsChanged() }
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

        /// How long a stroke this canvas added stays a dot candidate (s) and how many are kept (§4.1).
        static let recentAddWindow: TimeInterval = 2
        static let recentAddLimit = 64

        /// 1.1 (M7A_CONTRACT §4.1, 0-21): records a stroke this canvas added itself (from
        /// `applyCanvasChange`'s `added`; the tests call it too) at the device's monotonic `time`.
        /// Entries more than 2 s older than `time` and all but the newest 64 are dropped.
        func noteRecentAdd(_ id: String, at time: TimeInterval) {
            recentAdds.append((at: time, id: id))
            let cutoff = time - Self.recentAddWindow
            recentAdds.removeAll { $0.at < cutoff }
            if recentAdds.count > Self.recentAddLimit {
                recentAdds.removeFirst(recentAdds.count - Self.recentAddLimit)
            }
        }

        /// The ids of the live strokes this canvas added in the last `within` seconds (`recentAdds`,
        /// by `uptime()`; 1.1: never a stroke from iCloud, an import or undo, and the strokes' own `t`
        /// — another device's clock — is not read) whose paper bounds fit in 16 pt on screen
        /// (16 / zoom lu) and whose centre is within 24 pt (24 / zoom lu) of `near`: the dots a
        /// finger's taps drew.
        func dotStrokeIds(near: CGPoint, zoom: CGFloat, within: TimeInterval = 0.5) -> [String] {
            let z = max(zoom, 0.0001)
            let maxSide = 16 / z
            let maxDistance = 24 / z
            let cutoff = uptime() - within
            var seen = Set<String>()
            var ids: [String] = []
            for entry in recentAdds where entry.at >= cutoff && seen.insert(entry.id).inserted {
                guard ledger.page.isLive(entry.id), let box = ledger.paperBounds(of: entry.id),
                      box.width <= maxSide, box.height <= maxSide else { continue }
                let dx = box.midX - near.x
                let dy = box.midY - near.y
                guard (dx * dx + dy * dy).squareRoot() <= maxDistance else { continue }
                ids.append(entry.id)
            }
            return ids
        }

        /// Removes `dotStrokeIds` as one `.removeStrokes` op (undoable). Nothing when there are none.
        private func removeDots(near: CGPoint, zoom: CGFloat, within: TimeInterval = 0.5) {
            guard let canvas else { return }
            let ids = dotStrokeIds(near: near, zoom: zoom, within: within)
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
        /// `blockedInputRecognizer` (Pencil only): both take the default true here. 1.1 (§2.4): the
        /// single tap's finger is timed (`tapTouchBeganAt`) to tell whether the eraser's last touch
        /// was this tap.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard gestureRecognizer === tapRecognizer || gestureRecognizer === doubleTapRecognizer else { return true }
            let direct = touch.type == .direct
            if direct, gestureRecognizer === tapRecognizer {
                tapTouchBeganAt = touch.timestamp
            }
            return direct
        }

        /// With 「指でも書く」 on, PencilKit's `drawingGestureRecognizer` begins on the finger's
        /// touch-down; the taps are recognised alongside it (M4C_CONTRACT §4.1) or they would never
        /// fire. Nothing else runs simultaneously (the finger recogniser of F2 in particular) —
        /// except M5's `blockedInputRecognizer`, which only reports and runs alongside everything
        /// (drawing, pan, pinch, taps; M5_CONTRACT §3.1), and 1.1 fix's `touchObserver` and
        /// `pencilOverlayRecognizer`, which never recognise and run alongside everything too.
        /// (Unchanged in 1.0.1: PencilKit's second drawing recogniser allows the taps itself,
        /// docs/R1_0_1.md §5.2, and the iPhone UI test taps through all of them.)
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === touchObserver || otherGestureRecognizer === touchObserver
                || gestureRecognizer === pencilOverlayRecognizer || otherGestureRecognizer === pencilOverlayRecognizer {
                return true
            }
            if gestureRecognizer === blockedInputRecognizer || otherGestureRecognizer === blockedInputRecognizer { return true }
            guard let canvas else { return false }
            let isTap = gestureRecognizer === tapRecognizer || gestureRecognizer === doubleTapRecognizer
            return isTap && otherGestureRecognizer === canvas.drawingGestureRecognizer
        }

        // MARK: The pen on the paper (canvas or overlay)

        /// A touch begins (PencilKit's tool or the overlay's tracking). 1.1: the eraser's touch starts
        /// empty and is timed (§2.4), the owner hears of it (`onPenDown`, §2.1). 1.1 fix (ずれ 46):
        /// until `touchObserver` has seen a touch, a new touch cuts a waiting report short (the count
        /// is carried over), as before; after that the touches decide, and a Begin with nothing on the
        /// paper (the Pencil's hover, or a Begin ahead of its touch) is watched (`startLiftWatch`).
        private func penDidTouch() {
            isUsingTool = true
            isSettling = false
            settleGeneration += 1
            removedSinceTouch = []
            touchBeganAt = uptime()
            touchBeganWithEraser = parent.tool.isEraser
            if !observerReady {
                eraseReportGeneration += 1
                eraseReportPending = false
            } else if !touchingPaper {
                startLiftWatch()
            }
            deliver { [weak self] in self?.parent.onPenDown() }
        }

        /// The touch ended: the queued work waits `settleDelay`. 1.1 (§2.5) and its fix (ずれ 46): the
        /// eraser's report is scheduled at once (`scheduleEraseReport`; nothing is scheduled while
        /// something still touches the paper). When the wait is over, an erasure PencilKit never told
        /// of is taken into the ledger first (`canvasViewDrawingDidChange`'s work once more, with the
        /// eraser or after a touch that began with it — the report may have put the pen back by then:
        /// a rebuilt drawing must not bring the stroke back), then the queued work runs, then the
        /// report is scheduled again for whatever came in during the wait. The lead's review: never
        /// while the ledger is another page's (`resetScroll`: `update(from:)` replaced it during the
        /// touch or the wait, and the queued work rebuilds the drawing) — the canvas still shows the old
        /// page, and comparing the two would copy its strokes into the new page.
        private func penDidLift() {
            isUsingTool = false
            isSettling = true
            settleGeneration += 1
            let generation = settleGeneration
            scheduleEraseReport(.lift)
            let delay = InkCanvasView.settleDelay
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard let self else { return }
                guard self.settleGeneration == generation, !self.isUsingTool else {
                    self.probeNote("r")
                    return
                }
                if self.parent.tool.isEraser || self.touchBeganWithEraser, !self.parent.readOnly, !self.isMovingSelection,
                   !self.resetScroll, let canvas = self.canvas, self.applyCanvasDrawing(canvas) {
                    self.probeNote("K")
                }
                self.isSettling = false
                self.applyPending()
                self.scheduleEraseReport(.settleEnd)
            }
        }

        // MARK: The eraser's report (1.1 §2.5; the fix of TestFlight build 12, docs/M7A.md ずれ 46)

        /// What asks for the report: a count (⑥), a lift (the last writing touch, or PencilKit's End),
        /// the end of the settle wait.
        private enum EraseReportTrigger {
            case count, lift, settleEnd
        }

        /// Schedules `onEraseEnded` with what was counted, unless nothing was or something still
        /// touches the paper (D2: the tool never changes under the pen; the lift schedules it then).
        /// A report already waiting carries a new count, so only a lift schedules anew (and starts its
        /// wait again). The wait: with the observer, `pencilEraseReportDelay` (the next turn) after the
        /// Pencil and `fingerEraseReportDelay` after a finger; before it has seen a touch, `settleDelay`
        /// (none at the end of the settle wait: the pen lifted that long ago). The report itself goes
        /// out only when it is still the latest, the canvas is attached, nothing touches the paper and
        /// the app is not read only; otherwise the count waits for the next one. Times are never
        /// compared (the tests pin `uptime`): only `Task.sleep` and the generation decide.
        private func scheduleEraseReport(_ trigger: EraseReportTrigger) {
            guard erasedSinceReport > 0, !touchingPaper else { return }
            if trigger != .lift, eraseReportPending { return }
            let delay: TimeInterval
            if observerReady {
                delay = lastLiftWasFinger ? fingerEraseReportDelay : Self.pencilEraseReportDelay
            } else {
                delay = trigger == .settleEnd ? 0 : InkCanvasView.settleDelay
            }
            eraseReportGeneration += 1
            eraseReportPending = true
            let generation = eraseReportGeneration
            probeNote("S\(String(format: "%g", delay))")
            Task { @MainActor [weak self] in
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                guard let self, self.eraseReportGeneration == generation, self.container != nil else { return }
                self.eraseReportPending = false
                guard self.erasedSinceReport > 0, !self.touchingPaper, !self.parent.readOnly else { return }
                let erased = self.erasedSinceReport
                self.erasedSinceReport = 0
                self.probeNote("R\(erased)")
                self.deliver { [weak self] in self?.parent.onEraseEnded(erased) }
            }
        }

        /// `touchObserver` saw a touch of `type` come down or lift. Internal: the tests stand in for
        /// UIKit with it. A writing touch coming down (`writes`: the Pencil, a pointer, or a finger with
        /// 「指でも書く」) cuts a waiting report short (the count is carried over); the last one lifting
        /// schedules the report and watches for an End that does not come. A pointer (a mouse, a
        /// trackpad) is waited for like a finger after it lifts; the lead's review: it writes with
        /// 「指でも書く」 off too, so it always holds the report and the lift watch while it is pressed.
        func touchObserved(_ change: InkTouchObserver.Change) {
            if spanState != nil { bandTouchObserved(change) }
            switch change {
            case .down(let type):
                observerReady = true
                switch type {
                case .pencil: pencilsDown += 1
                case .direct: fingersDown += 1
                case .indirectPointer: pointersDown += 1
                default: return
                }
                probeNote("D\(Self.touchToken(type))")
                if writes(type) {
                    eraseReportGeneration += 1
                    eraseReportPending = false
                    // The lead's review (案 a): after `W` PencilKit may write this touch without a Begin.
                    // It is taken as the tool in use (the settle wait `W` started is cut short, like a
                    // Begin does), so a page from iCloud, ↶ ↷ and a rebuild wait until it lifts.
                    if liftTakenByWatch, !parent.tool.isOverlayTool, !parent.readOnly {
                        liftTakenByWatch = false
                        isUsingTool = true
                        isSettling = false
                        settleGeneration += 1
                        probeNote("Bw")
                    }
                }
            case .up(let type):
                switch type {
                case .pencil: pencilsDown = max(0, pencilsDown - 1)
                case .direct: fingersDown = max(0, fingersDown - 1)
                case .indirectPointer: pointersDown = max(0, pointersDown - 1)
                default: return
                }
                probeNote("U\(Self.touchToken(type))")
                guard writes(type), !touchingPaper else { return }
                lastLiftWasFinger = type != .pencil
                scheduleEraseReport(.lift)
                startLiftWatch()
            }
        }

        /// The trace's letter of a touch type: `p` the Pencil, `f` a finger, `i` a pointer.
        private static func touchToken(_ type: UITouch.TouchType) -> String {
            switch type {
            case .pencil: return "p"
            case .indirectPointer: return "i"
            default: return "f"
            }
        }

        /// A touch of this type writes or erases on the canvas: the Pencil, a pointer (the lead's review:
        /// whatever 「指でも書く」 says, as PencilKit's drawing recogniser takes it), or a finger with
        /// 「指でも書く」.
        private func writes(_ type: UITouch.TouchType) -> Bool {
            type == .pencil || type == .indirectPointer || (type == .direct && parent.allowFinger)
        }

        /// In `liftWithoutEndGrace`, if nothing touches the paper and PencilKit (or the overlay) still
        /// says the tool is in use, the pen is taken as lifted (`penDidLift`): an End that never came,
        /// or a Begin of the hover, must not hold up undo / redo and the growing memo area. A newer
        /// watch replaces this one. The lead's review (案 a): PencilKit, its tool still in use for it,
        /// may then write the next touch without a Begin; that touch is taken as the tool in use as it
        /// comes down (`liftTakenByWatch`, `touchObserved`), so nothing queued lands in its stroke.
        private func startLiftWatch() {
            liftWatchGeneration += 1
            let generation = liftWatchGeneration
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(Self.liftWithoutEndGrace))
                guard let self, self.liftWatchGeneration == generation, self.observerReady,
                      !self.touchingPaper, self.isUsingTool else { return }
                self.probeNote("W")
                self.penDidLift()
                self.liftTakenByWatch = true
            }
        }

        // MARK: PKCanvasViewDelegate

        /// What the canvas did, in the order of M7A_CONTRACT §5.2: ① the guard (our own drawing, a lasso
        /// move) and PencilKit's undo emptied → ② ③ the new strokes screened (`screenNewStrokes`: off
        /// the paper, beyond the last cell's limit, over the budget) → ④ the ledger's diff → ④' the
        /// strokes added remembered as dot candidates → ⑤ the 15,000 notice → ⑥ the eraser's count →
        /// ⑦ the relayout request and the cap notice.
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            applyCanvasDrawing(canvasView)
        }

        /// `canvasViewDrawingDidChange`'s work; true when the ledger changed (1.1 fix: the end of the
        /// settle wait calls it too, to take in an erasure PencilKit never told of). The lead's review:
        /// nothing is compared while the ledger is another page's than the canvas (`resetScroll`, until
        /// `applyPending` rebuilds the drawing): its fingerprints do not describe the strokes on the
        /// canvas, so every stroke of the old page would be taken in as a new stroke of the new page. A
        /// stroke PencilKit finishes on the old page then is dropped by the rebuild (the old page's
        /// ledger is gone; it never reaches either page).
        @discardableResult
        private func applyCanvasDrawing(_ canvasView: PKCanvasView) -> Bool {
            guard !isApplyingDrawing, !isMovingSelection, !resetScroll else {
                probeNote("c")
                return false
            }
            if spanState != nil { return applyBandDrawing(canvasView) }
            // History is the ledger's; never let the system (3-finger swipe) undo through PencilKit.
            canvasView.undoManager?.removeAllActions()
            let screening = screenNewStrokes(on: canvasView)
            if let before = screening.refusedAt {
                deliver { [weak self] in self?.parent.onStrokeBudget(.full(before)) }
            }
            var capReached = screening.beyondCap
            defer {
                if capReached {
                    deliver { [weak self] in self?.parent.onGrowthCapReached() }
                }
            }
            let change = ledger.applyCanvasChange(canvasView.drawing)
            guard !change.isEmpty else {
                probeNote("C0")
                return false
            }
            // The UI tests' probe: `e` = the tool is the eraser (⑥ counts r − a when it is positive).
            probeNote("C+\(change.added.count)-\(change.removedIds.count)\(isUsingTool ? "u" : "")\(isSettling ? "s" : "")\(parent.tool.isEraser ? "e" : "")")
            // ④' Only what this canvas added itself can be a finger tap's dot (§4.1, 0-21).
            let addedAt = uptime()
            for stroke in change.added {
                noteRecentAdd(stroke.id, at: addedAt)
            }
            publishPage()
            notifyHistory()
            if !change.removedIds.isEmpty {
                refreshSelection()
            }
            // ⑤ The page reached 15,000 strokes with this canvas's stroke (iCloud, imports and undo
            // never come here).
            if !change.added.isEmpty, let before = screening.countBefore {
                let after = ledger.page.budgetCount
                if StrokeBudget.crossesNotice(from: before, to: after) {
                    deliver { [weak self] in self?.parent.onStrokeBudget(.many(after)) }
                }
            }
            // ⑥ The eraser (§2.5), never read only; undo / redo, iCloud, a rebuilt drawing and the dots
            // of a finger tap come through `setDrawing` and a lasso move through `isMovingSelection`, so
            // the guard above already returned for them. 1.1 fix (ずれ 46): whenever the change comes
            // while the tool is the eraser — before PencilKit's Begin, after its End and the settle wait,
            // or with no Begin at all — and by what it removed beyond what it added (PencilKit may
            // hand back a stroke it touched as a new one). Only a pure erasure is the touch's own (0-22).
            let erasedNow = change.removedIds.count - change.added.count
            if parent.tool.isEraser, !parent.readOnly, erasedNow > 0 {
                erasedSinceReport += erasedNow
                if change.added.isEmpty {
                    removedSinceTouch.append(contentsOf: change.removedIds)
                }
                scheduleEraseReport(.count)
            }
            // ⑦ Only cells that grow with ink ask for a relayout (`needsMoreRoom` is false on the time
            // grid); an erased stroke may have been holding any growing cell open.
            let needsRoom = change.added.contains { ledger.needsMoreRoom($0) }
            if needsRoom || !change.removedIds.isEmpty {
                deliver { [weak self] in self?.parent.onInkBoundsChanged() }
            }
            // Less than 400 lu of the last cell is left below this stroke (§3.4).
            if change.added.contains(where: { PaperGrowth.isTail($0.cell) && PaperGrowth.reachesCap(inkBottom: $0.bottom) }) {
                capReached = true
            }
            return true
        }

        /// What `screenNewStrokes` did: a stroke went beyond the last cell's limit; the budget count
        /// before the new strokes (nil when there was no new stroke left to count); the count when
        /// new strokes were refused (nil = none was).
        private struct Screening {
            var beyondCap = false
            var countBefore: Int?
            var refusedAt: Int?
        }

        /// Screens the strokes the canvas holds that the ledger did not build (`id(of:) == nil`: drawn
        /// on this canvas just now — never one that came from iCloud, an import or undo, which the
        /// ledger built). Such a stroke never reaches the ledger and leaves the canvas at once, with
        /// no undo, when:
        /// - its paper bounds are centred outside the paper (x < 0, x > width, y < 0, y > height: a
        ///   margin; M4C-25): `inkCell(forCenter:)` would file it on an edge cell with
        ///   negative cell coordinates, and at another zoom or in the web version it would stick out
        ///   of the paper;
        /// - 1.1 (§3.4, 0-5): it is centred more than `growMax` below the top of the page's last cell,
        ///   even when the paper is longer (a line past 5,950 lu) — `.beyondCap`;
        /// - 1.1 (§5.2, K-9): it is one of the newest strokes that would take the page past
        ///   `StrokeBudget.refuseAt` (`accepted(incoming:count:)`; the last ones go).
        private func screenNewStrokes(on canvasView: PKCanvasView) -> Screening {
            var result = Screening()
            let strokes = canvasView.drawing.strokes
            var keep = [Bool](repeating: true, count: strokes.count)
            var newIndices: [Int] = []
            for (index, pk) in strokes.enumerated() where ledger.id(of: pk) == nil {
                let box = StrokeGeometry.paperBounds(of: pk)
                if let reason = PaperGrowth.drop(center: CGPoint(x: box.midX, y: box.midY), in: appliedLayout) {
                    keep[index] = false
                    if reason == .beyondCap { result.beyondCap = true }
                } else {
                    newIndices.append(index)
                }
            }
            if !newIndices.isEmpty {
                let before = ledger.page.budgetCount
                result.countBefore = before
                let accepted = StrokeBudget.accepted(incoming: newIndices.count, count: before)
                if accepted < newIndices.count {
                    for index in newIndices.suffix(newIndices.count - accepted) {
                        keep[index] = false
                    }
                    result.refusedAt = before
                }
            }
            guard keep.contains(false) else { return result }
            var kept: [PKStroke] = []
            kept.reserveCapacity(strokes.count)
            for (index, pk) in strokes.enumerated() where keep[index] {
                kept.append(pk)
            }
            isApplyingDrawing = true
            canvasView.drawing = PKDrawing(strokes: kept)
            isApplyingDrawing = false
            canvasView.undoManager?.removeAllActions()
            return result
        }

        /// PencilKit's Begin and End (the lead's review: after either, PencilKit and the canvas agree
        /// again on whether its tool is in use; `liftTakenByWatch` is over).
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            probeNote("B")
            liftTakenByWatch = false
            penDidTouch()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            probeNote("E")
            liftTakenByWatch = false
            penDidLift()
        }

        // MARK: UIScrollViewDelegate (inherited by PKCanvasViewDelegate)

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            syncPaperFrame()
            if spanState != nil { bandDidScroll() }
        }

        /// Every frame of a pinch, and synchronously after every `zoomScale` assignment: the content
        /// size, the margins and the paper window. The first frame after a bounce redraws.
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

        // 1.3 (docs/M7C_CONTRACT.md §3.6): the ends of a movement, for the shift of the window and the fling. The
        // one-page path has none of them (each returns at its first line, `targetContentOffset` untouched).

        /// Where a drag began (the fling's start); a finger stops an arrow's slide.
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            guard let state = spanState else { return }
            state.dragStartX = scrollView.contentOffset.x
            state.slideTargetX = nil
            state.queuedSlidePages = 0
            noteMotion()
        }

        /// はじき (P-B5 ア, §3.6): where a release comes to rest, `SpanPlan.flingTarget` with the speed UIKit measured
        /// (pt per ms), the screen's width and the stop UIKit proposes: at a zoom that shows a page whole a fling turns
        /// to the next page (centred), a slow stop near a page edge (6 % of the screen's width) lines the edge up with
        /// the screen's, zoomed in a fling flows. A drag the directional lock kept vertical leaves x alone. Kept on
        /// the band.
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            guard let state = spanState else { return }
            guard let canvas, let container, let band = appliedLayout as? SpanLayout else { return }
            let startX = state.dragStartX ?? canvas.contentOffset.x
            state.dragStartX = nil
            guard velocity.x != 0 || abs(canvas.contentOffset.x - startX) >= 0.5 else { return }
            let zoom = max(canvas.zoomScale, 0.0001)
            let proposed = targetContentOffset.pointee
            let x = band.plan.flingTarget(offsetX: canvas.contentOffset.x, velocity: velocity.x, zoom: zoom,
                                          viewportWidth: container.bounds.width, proposedX: proposed.x)
            targetContentOffset.pointee = CGPoint(x: clampedOffset(CGPoint(x: x, y: proposed.y)).x, y: proposed.y)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            guard spanState != nil else { return }
            noteMotion()
            if !decelerate { requestShiftCheck() }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            guard spanState != nil else { return }
            noteMotion()
            requestShiftCheck()
        }

        /// The end of an arrow's slide (`setContentOffset(_:animated: true)`). An end with the band away from where the
        /// slide is going (an animation the canvas aimed again, or one a touch stopped) leaves the slide running: the
        /// animation aimed again tells its own end, and the watch ends a slide nothing moves any more.
        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            guard let state = spanState else { return }
            noteMotion()
            if let target = state.slideTargetX, abs(scrollView.contentOffset.x - target) >= 0.5 { return }
            state.slideTargetX = nil
            requestShiftCheck()
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
            probeNote("L\(ids.count)")
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
            probeNote(isTracking ? "O" : "o")
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

// MARK: - 1.3 The window of joined pages (docs/M7C_CONTRACT.md §3.6, §3.4, §3.3, D6, D15, D16, D20, D21; role L)
//
// Everything below runs only when the canvas was made with a `SpanSession` (`InkCanvasView.span`): the
// coordinator then has a `spanState`, and each 1.2.3 function it passes through has one line at its entry
// (`if spanState != nil { … }`) that sends the joined path here. With `span` nil (the month, the year, the
// setting off, the screenshot mode by default) none of it runs and the canvas is 43fe366's (D9).

/// 1.3 (§3.6 the palm, B_DESIGN.md:354-360): the band's `PKCanvasView`. Its scroll pan asks `panMayBegin`
/// before it begins (the scroll view stays the pan's delegate, so the question is the view's own
/// `gestureRecognizerShouldBegin`). Only the window of joined pages makes one; the one page keeps a plain
/// `PKCanvasView`.
@MainActor
final class InkBandCanvasView: PKCanvasView {
    /// nil, or true, lets the pan begin; false keeps the paper where it is for this touch.
    var panMayBegin: ((UIPanGestureRecognizer) -> Bool)?

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGestureRecognizer, let panMayBegin, !panMayBegin(panGestureRecognizer) {
            return false
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

/// 1.3 (§3.6, §3.16, B_DESIGN.md:356): in the overview one finger has to move about 24 pt sideways (or 10 pt
/// more up or down than sideways) before the band moves. A recogniser on the container that the canvas's pan
/// waits for (`require(toFail:)`); it never recognises: it fails at once unless `holds` (the overview, one
/// finger), and otherwise as soon as the finger moved far enough (`InkCanvasView.overviewPanMayStart`), or
/// lifts. Fingers only (the Pencil never pans the paper).
@MainActor
final class InkBandPanGate: UIGestureRecognizer {
    /// Asked when the first finger comes down: true holds the pan back (the band is at the overview's zoom).
    var holds: () -> Bool = { false }
    private var start: CGPoint?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard state == .possible else { return }
        guard start == nil, numberOfTouches == 1, holds(), let touch = touches.first else {
            state = .failed
            return
        }
        start = touch.location(in: view)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard state == .possible, let start, let point = touches.first?.location(in: view) else { return }
        if InkCanvasView.overviewPanMayStart(translation: CGSize(width: point.x - start.x, height: point.y - start.y)) {
            state = .failed
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        if state == .possible { state = .failed }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        if state == .possible { state = .failed }
    }

    override func reset() {
        super.reset()
        start = nil
    }
}

extension InkCanvasView {
    // MARK: The fixed numbers (§3.16) and the pure rules (§2.1; XCTest fixes them)

    /// The watch: this long after the last scroll, zoom or slide, a stop no scroll-view call told of shifts the
    /// window (§3.6).
    static let shiftWatchDelay: TimeInterval = 0.5
    /// The palm: a sideways pan does not begin while an Apple Pencil touches the paper, nor this long after the
    /// last one lifted (B_DESIGN.md:355).
    static let palmHold: TimeInterval = 0.5
    /// The overview: a finger moves this far sideways (pt) before the band moves (B_DESIGN.md:356).
    static let overviewPanStart: CGFloat = 24
    /// … or this far, more up or down than sideways, and the pan begins at once (up and down stay as they are).
    static let verticalPanStart: CGFloat = 10

    /// What a shift of the window came to (`Coordinator.shiftIfAtRest`).
    enum SpanShiftOutcome: Equatable {
        /// The window shifted (or was decided anew).
        case done
        /// Nothing to do: the focus is the window's middle page.
        case nothing
        /// A shift is due but something holds it back (the pen, a finger, a fling, a pinch, a selection, a sheet).
        case busy
        /// The session could not save a page that leaves (§3.6: then the window does not shift).
        case refused
    }

    /// §2.1, §3.6 the palm: false while `pencilsDown` > 0, or when the last Pencil lifted less than `palmHold`
    /// before `now`; true otherwise (no Pencil yet, or long enough ago). A `lastPencilUp` later than `now` (the
    /// clock was set back) does not hold the pan.
    static func horizontalPanMayBegin(pencilsDown: Int, lastPencilUp: Date?, now: Date) -> Bool {
        guard pencilsDown <= 0 else { return false }
        guard let up = lastPencilUp else { return true }
        let elapsed = now.timeIntervalSince(up)
        return !(elapsed >= 0 && elapsed < palmHold)
    }

    /// The band's pan, about to begin after moving `translation` (pt; `velocity` when it has not moved yet):
    /// one more up or down than sideways begins as it does today (§3.6: 縦は今どおり; S3's lead's decision 2);
    /// any other (sideways, or no direction to tell) asks `horizontalPanMayBegin`.
    static func panMayBegin(translation: CGPoint, velocity: CGPoint, pencilsDown: Int, lastPencilUp: Date?, now: Date) -> Bool {
        var dx = abs(translation.x)
        var dy = abs(translation.y)
        if !(dx > 0 || dy > 0) {
            dx = abs(velocity.x)
            dy = abs(velocity.y)
        }
        if dx.isFinite, dy.isFinite, dy > dx { return true }
        return horizontalPanMayBegin(pencilsDown: pencilsDown, lastPencilUp: lastPencilUp, now: now)
    }

    /// The overview's start (§3.16): may the band's pan begin after one finger moved `translation` (pt) from
    /// where it touched? true once it moved `overviewPanStart` sideways, or `verticalPanStart` more up or down
    /// than sideways; false before, and for a translation that is not finite.
    static func overviewPanMayStart(translation: CGSize) -> Bool {
        let dx = abs(translation.width)
        let dy = abs(translation.height)
        guard dx.isFinite, dy.isFinite else { return false }
        if dy >= verticalPanStart, dy > dx { return true }
        return dx >= overviewPanStart
    }

    /// K-9, D21: `InkPage.budgetCount` of one real page of the window (`page` is the window's ledger page): its
    /// live strokes and its strokes of an unknown tool, found by the page in front of their window names
    /// (aliases included).
    static func budgetCount(ofPage pageId: String, in page: InkPage) -> Int {
        var count = 0
        for (key, stroke) in page.strokes where page.deleted[stroke.id] == nil && SpanName.split(key)?.page == pageId {
            count += 1
        }
        for key in page.unknownStrokes.keys where SpanName.split(key)?.page == pageId {
            count += 1
        }
        return count
    }

    /// §3.6 ずらし: how far (pt) x moves when the same session's window is composed around other pages — the pages
    /// that came in (or went) on the left × the page width × zoom (`SpanPlan.shiftAmount`), so the pages on screen
    /// stay where they are. 0 for another session or the same first page.
    static func windowShift(old: SpanLayout, new: SpanLayout, zoom: CGFloat) -> CGFloat {
        guard old.pageId == new.pageId, old.firstIndex != new.firstIndex else { return 0 }
        return new.plan.shiftAmount(pages: old.firstIndex - new.firstIndex, zoom: zoom)
    }

    /// P-3, the canvas's side (§3.8): the paper of the window, made from the session's layout in the turn the
    /// canvas takes it (so the paper never lags the offset by a page). Each page's own all-day band stands in
    /// for the packed ones: the paper draws only the pages (`PaperView.drawSpan`); the heading and the band are
    /// the screen's. nil when a page is neither a week nor a day.
    static func paperSpan(for layout: SpanLayout, focus: Int) -> PaperSpan? {
        var bands: [AllDayBandLayout] = []
        for page in layout.pages {
            if let week = page as? WeekPageLayout {
                bands.append(week.allDayBand)
            } else if let day = page as? DayPageLayout {
                bands.append(day.allDayBand)
            } else {
                return nil
            }
        }
        return PaperSpan(layout: layout, bands: bands, focus: focus)
    }

    /// §3.6: the rectangle the window's zoom limits come from — the overview of its middle page (every joined
    /// week is 1,400 × 1,920, every day's 24 hours 1,000 × 2,400), never the band (whose width would make the
    /// lowest zoom show the whole window at once).
    static func bandOverview(_ layout: SpanLayout) -> CGSize {
        guard !layout.pages.isEmpty else { return ZoomPolicy.overviewSize(layout) }
        return ZoomPolicy.overviewSize(layout.pages[layout.pages.count / 2])
    }
}

/// 1.3 (§3.6): what the canvas keeps for the window of joined pages.
@MainActor
final class InkSpanState {
    let session: SpanSession
    /// The session's inbox (`InkCanvasView.inbox` may only name it).
    let inbox: SpanInbox
    /// The window the ledger was last loaded from, its `windowVersion` and the session's number then (D7).
    var appliedWindow: SpanVirtualPage
    var appliedWindowVersion: Int
    var appliedEpoch: Int
    /// The session composed a newer window: taken when the pen is up (`applyPendingSpan`).
    var pendingWindow = false
    /// `windowVersion` when the canvas last put deltas (§3.4 (a)): a window of that very version was composed
    /// before they reached the session and lacks them.
    var lastDeltaPutVersion: Int?
    /// A shift (or a decision anew) is under way: the scrolls it makes are not the person's.
    var isShiftingWindow = false
    /// The width changed (a rotation, Split View): the window is decided anew at the next stop.
    var pendingRedecide = false
    var shiftCheckScheduled = false
    var focusUpdateScheduled = false
    var relayoutScheduled = false
    /// Where an arrow's slide is going (nil when none runs), and where the last one went (the tests).
    var slideTargetX: CGFloat?
    var lastSlideTargetX: CGFloat?
    /// The band x (lu) the running slide brings to the middle of the screen (read only while `slideTargetX` is set):
    /// a slide aimed again after the canvas moved the band goes to the same middle at the zoom it has then.
    var slideTargetMid: CGFloat = 0
    var reaimScheduled = false
    /// The band x (lu) in the middle of the screen and the zoom, read just before 1.2.3's `applyBounds` when only the
    /// height of the paper area changed (`bandHeightWillChange`); nil otherwise.
    var heightChangeMid: (midX: CGFloat, zoom: CGFloat)?
    /// Pages still to slide: pressed while a slide ran or under the pen or a pinch, or the rest of a slide of more
    /// pages than the band holds beyond the screen. Slid once the paper is at rest (after the window shifted).
    var queuedSlidePages = 0
    /// The content offset x where the drag began (the fling's start).
    var dragStartX: CGFloat?
    var lastSlideTrigger: Int
    var lastSheetOpen: Bool
    /// `clock()` at the last scroll, zoom, slide or drag.
    var lastMotionAt = Date.distantPast
    var watchRunning = false
    var watchGeneration = 0
    /// `clock()` when an Apple Pencil last lifted (the palm).
    var lastPencilUp: Date?
    /// The focus day `onSpanStop` last told of.
    var lastStopFocusDay: DayKey?
    var windowSink: AnyCancellable?
    let panGate = InkBandPanGate(target: nil, action: nil)
    // The tests' handles and InkTrace's counts.
    var shiftCount = 0
    var refusedShiftCount = 0
    var refusedPans = 0
    /// Tests only: nil reads the canvas's `isTracking` / `isDragging` / `isDecelerating` (XCTest cannot fling).
    var motionOverride: Bool?
    /// Tests only: called at each step of taking a window ("pruned", "reloaded", "built" — the window's drawing
    /// made, the canvas still holding the old one —, "drawn", "moved").
    var shiftProbe: ((String) -> Void)?
    /// Tests only: stands in for UIKit's animated `setContentOffset` of a slide (XCTest cannot drive its frames).
    var slideAnimation: ((PKCanvasView, CGPoint) -> Void)?

    init(session: SpanSession, inbox: SpanInbox, slideTrigger: Int, sheetOpen: Bool) {
        self.session = session
        self.inbox = inbox
        appliedWindow = session.window
        appliedWindowVersion = session.windowVersion
        appliedEpoch = session.epoch
        lastSlideTrigger = slideTrigger
        lastSheetOpen = sheetOpen
    }
}

extension InkCanvasView.Coordinator {
    // MARK: The tests' handles (1.3)

    /// How many times the window shifted (or was decided anew), and was not (a page that leaves could not be saved).
    var spanShiftCount: Int { spanState?.shiftCount ?? 0 }
    var spanRefusedShiftCount: Int { spanState?.refusedShiftCount ?? 0 }
    /// Pans the palm's rule did not let begin.
    var spanRefusedPans: Int { spanState?.refusedPans ?? 0 }
    var spanMotionOverride: Bool? {
        get { spanState?.motionOverride }
        set { spanState?.motionOverride = newValue }
    }
    var spanShiftProbe: ((String) -> Void)? {
        get { spanState?.shiftProbe }
        set { spanState?.shiftProbe = newValue }
    }
    var spanSlideAnimation: ((PKCanvasView, CGPoint) -> Void)? {
        get { spanState?.slideAnimation }
        set { spanState?.slideAnimation = newValue }
    }
    var spanSlideTargetX: CGFloat? { spanState?.slideTargetX }
    var spanLastSlideTargetX: CGFloat? { spanState?.lastSlideTargetX }
    var spanLastPencilUp: Date? { spanState?.lastPencilUp }
    var spanWatchRunning: Bool { spanState?.watchRunning ?? false }
    var spanAppliedWindowVersion: Int? { spanState?.appliedWindowVersion }
    var spanPanGate: InkBandPanGate? { spanState?.panGate }

    /// Tests only: the end of 1.2.3's settle wait (`penDidLift`'s task after its 0.3 s), now, so a test of the
    /// joined path waits for no real time (§10.2). The task itself finds its generation moved on and does nothing.
    func endSettleWaitForTesting() {
        guard isSettling else { return }
        settleGeneration += 1
        if parent.tool.isEraser || touchBeganWithEraser, !parent.readOnly, !isMovingSelection, !resetScroll, let canvas,
           applyCanvasDrawing(canvas) {
            probeNote("K")
        }
        isSettling = false
        applyPending()
        scheduleEraseReport(.settleEnd)
    }

    // MARK: Lifecycle

    /// `init`'s entry (§3.3 1, D15): the ledger edits the session's window, and every id it makes carries the
    /// owner page of its cell (`SpanSession.ownerId(for:)`).
    fileprivate func beginSpan() {
        guard let session = parent.span else { return }
        #if DEBUG
        if let given = parent.inbox, given !== session.inbox {
            assertionFailure("InkCanvasView: inbox is not the session's own")
        }
        #endif
        let windowLedger = InkLedger(page: session.window.ledgerPage, layout: session.layout, deviceId: deviceId)
        windowLedger.ownerId = { [weak session] cell in session?.ownerId(for: cell) ?? InkStroke.newId() }
        ledger = windowLedger
        appliedLayout = session.layout
        publishedSignature = InkCanvasView.PageSignature(windowLedger.page)
        spanState = InkSpanState(session: session, inbox: session.inbox, slideTrigger: parent.slideTrigger, sheetOpen: parent.isSheetOpen)
    }

    /// `attach`'s entry (§3.6, P-3, §3.4 (c), D6): the band bounces sideways, its pan asks the palm and waits for
    /// the overview's gate, the paper is the window's, the lasso moves on the whole band; the window this canvas
    /// starts from is the safety net's source; the canvas follows `windowVersion` itself; the pages next to the
    /// focus are read.
    fileprivate func attachSpan(_ container: InkCanvasContainerView) {
        guard let state = spanState, let band = appliedLayout as? SpanLayout else { return }
        let canvas = container.canvasView
        canvas.alwaysBounceHorizontal = true
        (canvas as? InkBandCanvasView)?.panMayBegin = { [weak self] pan in self?.bandPanMayBegin(pan) ?? true }
        state.panGate.holds = { [weak self] in self?.isAtOverview ?? false }
        container.addGestureRecognizer(state.panGate)
        canvas.panGestureRecognizer.require(toFail: state.panGate)
        container.overlayView.pageSize = band.size
        updatePaperSpan(band)
        putWindowIntoInbox()
        // `@Published` tells before the value is set: the canvas reads it on the next turn.
        state.windowSink = state.session.$windowVersion.sink { [weak self] _ in
            guard self != nil else { return }
            Task { @MainActor [weak self] in self?.noteSessionWindow() }
        }
        startPrefetch()
    }

    /// `detach`'s entry (§3.4 (a)): what PencilKit finished and has not told of yet goes into the ledger, the
    /// journal into the inbox, before the delegate goes — quietly (no notice, no history, no write back: the
    /// canvas is being taken away inside SwiftUI's update). No watch, no slide and no window after this.
    fileprivate func detachSpan() {
        guard let state = spanState else { return }
        if let canvas, !isApplyingDrawing, !isMovingSelection, !resetScroll {
            _ = screenNewStrokesInBand(on: canvas)
            let change = ledger.applyCanvasChange(canvas.drawing, allowRemovals: parent.tool.isEraser || touchBeganWithEraser)
            if !change.isEmpty {
                probeNote("C+\(change.added.count)-\(change.removedIds.count)d")
            }
        }
        putJournalIntoInbox(relayout: false)
        state.watchGeneration += 1
        state.watchRunning = false
        state.windowSink = nil
        state.slideTargetX = nil
        state.panGate.holds = { false }
        (canvas as? InkBandCanvasView)?.panMayBegin = nil
    }

    /// The next turn: the session's `prefetch()` (the pages that came in, nearest first, one per turn; their
    /// events; `pagesOpened` once, D6), then the window it composed is taken (when the pen is up).
    fileprivate func startPrefetch() {
        guard let state = spanState else { return }
        let session = state.session
        Task { @MainActor [weak self] in
            await session.prefetch()
            self?.noteSessionWindow()
        }
    }

    // MARK: The session's window (§3.4, §3.5)

    /// `update(from:)`'s and the sink's: a newer `windowVersion` is taken once the pen is up.
    fileprivate func noteSessionWindow() {
        guard let state = spanState, container != nil, !state.session.isClosed,
              state.session.windowVersion != state.appliedWindowVersion else { return }
        state.pendingWindow = true
        if !isUpdating { requestApply() }
    }

    /// `update(from:)`'s entry before the queued work is asked for: the joined path takes its layout and its paper
    /// from the session (`pendingWindow`), never from `layout` / `paper` (whose `paper`, the focus page's, would
    /// redraw the band at every focus change, and whose layout may be a turn behind the session's); ◀ ▶ slide on
    /// the next turn (never an animated offset inside a SwiftUI update); a sheet that closed lets the window shift.
    fileprivate func noteSpanTriggers(_ newParent: InkCanvasView) {
        guard let state = spanState else { return }
        pendingPaper = false
        pendingGeometry = false
        #if DEBUG
        if newParent.span !== state.session {
            assertionFailure("InkCanvasView: another session reached the canvas (the owner gives it .id(span.id))")
        }
        if let given = newParent.inbox, given !== state.session.inbox {
            assertionFailure("InkCanvasView: inbox is not the session's own")
        }
        #endif
        if state.pendingWindow { requestApply() }
        if newParent.slideTrigger != state.lastSlideTrigger {
            state.lastSlideTrigger = newParent.slideTrigger
            let pages = newParent.slidePages
            Task { @MainActor [weak self] in self?.slide(byPages: pages) }
        }
        if newParent.isSheetOpen != state.lastSheetOpen {
            state.lastSheetOpen = newParent.isSheetOpen
            if !newParent.isSheetOpen { requestShiftCheck() }
        }
    }

    /// The window as the ledger holds it now, with the version it was loaded from, into the inbox: the safety
    /// net's source (§3.4 (c), H1: the session leaves a page another device emptied alone until this basis).
    fileprivate func putWindowIntoInbox() {
        guard let state = spanState else { return }
        state.inbox.put([], unrouted: [], window: state.appliedWindow.with(ledgerPage: ledger.page), basis: state.appliedWindowVersion)
    }

    /// `publishPage`'s entry (§3.4 (a), (b), (d)): the ledger's journal goes into the inbox in the turn it was
    /// written, every step of it (no `superseded`), as deltas of the real pages with the names that reach no page,
    /// under the session's number when this canvas took its window (D7). A step that may change the height of a
    /// growing cell (the day's free memo, D16) asks the session to lay the window out again on the next turn.
    fileprivate func putJournalIntoInbox(relayout: Bool = true) {
        guard let state = spanState else { return }
        let journal = ledger.journal
        ledger.journal.removeAll()
        state.inbox.put(journal: journal, window: state.appliedWindow.with(ledgerPage: ledger.page),
                        basis: state.appliedWindowVersion, epoch: state.appliedEpoch)
        guard !journal.isEmpty else { return }
        state.lastDeltaPutVersion = state.session.windowVersion
        if relayout, journal.contains(where: { needsRelayout($0) }) {
            scheduleRelayoutPages()
        }
    }

    /// A journal step that may change a growing cell's height (§3.3 4, D16): a stroke added past what its cell
    /// holds (`needsMoreRoom`, the prefix taken off), or a removal while a page's last cell is taller than its
    /// open length (it may shrink back: 「消して縮むときは下げる」). A removal names only ids (its stroke is gone from
    /// the page), so the window's tails are what tell; the week has no growing cell in 1.3.
    fileprivate func needsRelayout(_ entry: SpanJournalEntry) -> Bool {
        if entry.added.contains(where: { ledger.needsMoreRoom($0) }) { return true }
        guard !entry.removed.isEmpty, let band = appliedLayout as? SpanLayout else { return false }
        return band.pages.contains { (PaperGrowth.tail(of: $0)?.rect.height ?? 0) > PaperSpec.growMax + 0.001 }
    }

    /// Once, on the next turn: the session lays the window out again (`relayoutPages`: the inbox emptied first)
    /// and the canvas takes it (the light path when only the tails changed).
    fileprivate func scheduleRelayoutPages() {
        guard let state = spanState, !state.relayoutScheduled else { return }
        state.relayoutScheduled = true
        Task { @MainActor [weak self] in
            guard let self, let state = self.spanState else { return }
            state.relayoutScheduled = false
            guard self.container != nil, !state.session.isClosed else { return }
            state.session.relayoutPages()
            self.noteSessionWindow()
        }
    }

    /// Takes the session's window into the ledger (§3.6 ずらしの手順, the canvas's part; §3.5): the steps of pages
    /// that left or were emptied from outside are dropped from the history (`pruneHistory`), the ledger reloads the
    /// window keeping the rest of its history (its fingerprints still describe the canvas), and the window goes out
    /// as the safety net's source. A window composed before this canvas's newest deltas reached the session (one
    /// of the very `windowVersion` they were put at) lacks them: the session composes again first (inside a
    /// SwiftUI update, on the next turn). nil when nothing was taken; else whether the ledger's page changed.
    fileprivate func adoptSessionWindow() -> (changed: Bool, layout: SpanLayout)? {
        guard let state = spanState else { return nil }
        let session = state.session
        guard !session.isClosed else {
            state.pendingWindow = false
            return nil
        }
        if state.lastDeltaPutVersion == session.windowVersion {
            if isUpdating {
                scheduleRelayoutPages()
                return nil
            }
            session.relayoutPages()
        }
        let pruned = session.takeHistoryPrune()
        ledger.pruneHistory(touching: pruned)
        state.shiftProbe?("pruned")
        let window = session.window
        let changed = window.ledgerPage.contentDiffers(from: ledger.page)
        if changed {
            ledger.reload(page: window.ledgerPage, keepHistory: true)
        }
        state.shiftProbe?("reloaded")
        let pagesChanged = window.pageIds != state.appliedWindow.pageIds
        state.appliedWindow = window
        state.appliedWindowVersion = session.windowVersion
        state.appliedEpoch = session.epoch
        state.pendingWindow = false
        putWindowIntoInbox()
        if pagesChanged {
            // The dot candidates and the eraser's touch may name a stroke of a page that left.
            recentAdds.removeAll()
            removedSinceTouch = []
        }
        if changed || !pruned.isEmpty {
            notifyHistory()
        }
        return (changed, session.layout)
    }

    /// `applyPending`'s entry: 43fe366's `applyPending` for the window. The session's window first (the history
    /// steps and the commands then work on it); then ↶ ↷ and the commands; then the light path when only tails
    /// changed (`SpanLayout.onlyTailHeightChanged`), else the drawing rebuilt (`setWindowDrawing`); the paper of
    /// the window; when the window's pages moved, x moved back by the pages that came in on the left
    /// (`windowShift`), so nothing on screen moves. From taking a window until its drawing is on the canvas,
    /// nothing compares the canvas's drawing with the ledger (§3.6: the old drawing never meets the new window's
    /// fingerprints, `isApplyingDrawing`). Last, a shift may be due now that the queued work is done.
    fileprivate func applyPendingSpan() {
        guard let state = spanState else { return }
        let wasApplyingGeometry = isApplyingGeometry
        isApplyingGeometry = true
        defer { isApplyingGeometry = wasApplyingGeometry }
        guard let canvas, let container else { return }
        let wasApplyingDrawing = isApplyingDrawing
        if state.pendingWindow { isApplyingDrawing = true }
        defer { isApplyingDrawing = wasApplyingDrawing }

        var adoptedLayout: SpanLayout?
        var contentChanged = false
        if state.pendingWindow, let taken = adoptSessionWindow() {
            adoptedLayout = taken.layout
            contentChanged = taken.changed
        }
        let commands = pendingCommands
        pendingCommands.removeAll()
        var drawingWork = pendingDrawing || contentChanged
        pendingDrawing = false
        pendingPaper = false
        pendingGeometry = false
        var historyChanged = false
        var inkBoundsChanged = false
        for command in commands where perform(command) {
            drawingWork = true
            historyChanged = true
            inkBoundsChanged = true
        }
        for action in pendingHistory {
            switch action {
            case .undo: if ledger.undo() != nil { historyChanged = true }
            case .redo: if ledger.redo() != nil { historyChanged = true }
            }
        }
        pendingHistory.removeAll()

        guard let oldBand = appliedLayout as? SpanLayout else { return }
        let newBand = adoptedLayout ?? oldBand
        let zoom = max(canvas.zoomScale, 0.0001)
        let oldX = canvas.contentOffset.x
        let topVisibleY = canvas.contentOffset.y / zoom
        let geometryChanged = !oldBand.sameGeometry(as: newBand)
        let tailOnly = !drawingWork && geometryChanged && newBand.onlyTailHeightChanged(from: oldBand)
        if tailOnly {
            // The light path (§3.3's table): no new drawing, no new limits, no scroll compensation.
            ledger.adopt(newBand)
            appliedLayout = newBand
            canvas.contentSize = Self.scaled(newBand.size, by: zoom)
            container.overlayView.pageSize = newBand.size
            applyInsets()
            if !isLive {
                canvas.contentOffset = clampedOffset(canvas.contentOffset)
            }
        } else if drawingWork || geometryChanged {
            setWindowDrawing(ledger.relayout(newBand), on: canvas)
            appliedLayout = newBand
            canvas.contentSize = Self.scaled(newBand.size, by: zoom)
            container.overlayView.pageSize = newBand.size
            applyInsets()
        }
        if geometryChanged {
            updatePaperSpan(newBand)
        }
        if geometryChanged, !tailOnly {
            let viewport = container.bounds.size
            if hasInitialZoom, viewport.width > 0, viewport.height > 0 {
                applyBounds(ZoomPolicy.bounds(newBand.kind, overview: InkCanvasView.bandOverview(newBand), viewport: viewport))
            }
            let zoomNow = max(canvas.zoomScale, 0.0001)
            let delta = PageScroll.scrollDelta(old: oldBand, new: newBand, topVisibleY: topVisibleY)
            let x = oldX + InkCanvasView.windowShift(old: oldBand, new: newBand, zoom: zoomNow)
            if !isLive {
                canvas.contentOffset = clampedOffset(CGPoint(x: x, y: (topVisibleY + delta) * zoomNow))
            }
            state.shiftProbe?("moved")
        }
        if geometryChanged {
            // The offset was set under a running slide (a window taken while it slides: never a shift).
            reaimSlideNextTurn()
        }
        syncPaperFrame()

        if drawingWork {
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
        requestShiftCheck()
    }

    /// `setDrawing` for the window: the drawing on the canvas with nothing compared meanwhile, and
    /// `isApplyingDrawing` back to what it was (a window being taken keeps it until it is all done).
    fileprivate func setWindowDrawing(_ drawing: PKDrawing, on canvas: PKCanvasView) {
        setDrawingCount += 1
        spanState?.shiftProbe?("built")
        let was = isApplyingDrawing
        isApplyingDrawing = true
        canvas.drawing = drawing
        isApplyingDrawing = was
        ledger.bind(to: canvas.drawing)
        canvas.undoManager?.removeAllActions()
        spanState?.shiftProbe?("drawn")
    }

    /// The paper of the window (P-3), when its pages or their sizes changed, and at every window taken (wave C's F4:
    /// the events, the now line and the holidays change no geometry); a paper equal to the one shown is not set again.
    fileprivate func updatePaperSpan(_ band: SpanLayout) {
        guard let state = spanState, let container else { return }
        let focus = min(max(0, state.session.focusIndex - band.firstIndex), max(0, band.pages.count - 1))
        let span = InkCanvasView.paperSpan(for: band, focus: focus)
        if container.paperView.span != span {
            container.paperView.span = span
        }
    }

    // MARK: Geometry (§3.6)

    /// `containerDidLayout`'s overview on the joined path.
    fileprivate func bandZoomOverview() -> CGSize {
        guard let band = appliedLayout as? SpanLayout else { return ZoomPolicy.overviewSize(appliedLayout) }
        return InkCanvasView.bandOverview(band)
    }

    /// The first layout's entry: at the opening zoom (and without `initialPaperOffset`) the focus page opens in
    /// the middle of the screen, its neighbours showing at the sides. A zoomed-in opening keeps
    /// `initialScrollX` / `Y` (band lu).
    fileprivate func applyBandOpening(zoom: CGFloat, bounds: ZoomPolicy.Bounds) {
        guard let state = spanState, let canvas, let container, let band = appliedLayout as? SpanLayout, !band.pages.isEmpty,
              parent.initialPaperOffset == nil, ZoomPolicy.ratio(forZoom: zoom, bounds: bounds) <= 1.0005 else { return }
        let slot = min(max(0, state.session.focusIndex - band.firstIndex), band.pages.count - 1)
        let x = (band.origin(ofSlot: slot) + band.plan.pageWidth / 2) * zoom - container.bounds.width / 2
        canvas.contentOffset = clampedOffset(CGPoint(x: x, y: canvas.contentOffset.y))
    }

    /// `containerDidLayout`'s entry when the width changed (a rotation, Split View): the window is decided anew
    /// when the paper is still. A slide (and the pages waiting to slide) was aimed at the old width and zoom: it
    /// ends where the band is (its animation stopped, so it does not carry the band to the old place).
    fileprivate func bandWidthChanged() {
        guard let state = spanState else { return }
        if state.slideTargetX != nil || state.queuedSlidePages != 0 {
            state.slideTargetX = nil
            state.queuedSlidePages = 0
            if let canvas, !isLive {
                canvas.setContentOffset(canvas.contentOffset, animated: false)
            }
        }
        state.pendingRedecide = true
        requestShiftCheck()
    }

    /// `containerDidLayout`'s entry before 1.2.3's `applyBounds` when only the height changed: the band x (lu) in the
    /// middle of the screen and the zoom, for `bandHeightChanged`.
    fileprivate func bandHeightWillChange() {
        guard let state = spanState, let canvas else { return }
        state.heightChangeMid = (midX: currentMidX(), zoom: max(canvas.zoomScale, 0.0001))
    }

    /// `containerDidLayout`'s entry when only the height changed (the all-day lanes grew, a bar came or went). 1.2.3's
    /// `applyBounds` lets the zoom follow the height (at the overview, or clamped into the new limits) and leaves x in
    /// points, or where UIKit's zoom setter puts it; on the band that moves every page sideways (955 → 900 pt at the
    /// overview of an 11-inch portrait week: about 100 pt with x kept in points; in the simulator the focus week's middle
    /// went to 1,241.6 pt and the focus to the week before). So when the zoom changed, the band x that was in the middle
    /// of the screen goes back there, as a change of width keeps it (`centerPaper`, entry 4): the focus page stays where
    /// it was, in the middle at the overview as the opening put it (`applyBandOpening`). y stays 1.2.3's (the top of the
    /// view on the same paper y). Not under a pinch (the zoom did not change). A running slide is then aimed again
    /// (`reaimSlideNextTurn`).
    fileprivate func bandHeightChanged() {
        if let state = spanState, let kept = state.heightChangeMid {
            state.heightChangeMid = nil
            if let canvas, let container, !isLive, abs(canvas.zoomScale - kept.zoom) >= 0.0005 {
                let x = kept.midX * max(canvas.zoomScale, 0.0001) - container.bounds.width / 2
                canvas.contentOffset = clampedOffset(CGPoint(x: x, y: canvas.contentOffset.y))
            }
        }
        reaimSlideNextTurn()
    }

    /// The band x (lu) in the middle of the screen.
    fileprivate func currentMidX() -> CGFloat {
        guard let canvas, let container else { return 0 }
        return (canvas.contentOffset.x + container.bounds.width / 2) / max(canvas.zoomScale, 0.0001)
    }

    /// The band is at the overview's zoom (the lowest, or the opening zoom where the two differ): where the
    /// 24 pt start applies (§3.6).
    fileprivate var isAtOverview: Bool {
        guard let canvas, hasInitialZoom else { return false }
        let overview = max(canvas.minimumZoomScale, lastBounds?.open ?? canvas.minimumZoomScale)
        return canvas.zoomScale <= overview + 0.0005
    }

    // MARK: The band moves (§3.6)

    /// `scrollViewDidScroll`'s entry: the watch's clock, and the focus (the title) on the next turn — never a
    /// `@Published` change inside UIKit's call or a SwiftUI update, never from the scrolls a shift makes.
    fileprivate func bandDidScroll() {
        guard let state = spanState, !state.isShiftingWindow else { return }
        noteMotion()
        guard !state.focusUpdateScheduled else { return }
        state.focusUpdateScheduled = true
        Task { @MainActor [weak self] in
            guard let self, let state = self.spanState else { return }
            state.focusUpdateScheduled = false
            guard !state.isShiftingWindow, self.hasInitialZoom, self.container != nil, !state.session.isClosed else { return }
            state.session.scrolled(midX: self.currentMidX())
        }
    }

    /// Something moved the band: the watch waits `shiftWatchDelay` from now.
    fileprivate func noteMotion() {
        guard let state = spanState else { return }
        state.lastMotionAt = parent.clock()
        startWatch()
    }

    /// The watch (§3.6: 止まりの取りこぼしに備えて 0.5 秒の見張りのタイマー; §3.16): `shiftWatchDelay` (the injected
    /// `sleep`) after the last motion (the injected `clock`), a stop no scroll-view call told of is taken: the
    /// shift is tried. While a shift is due and held back (`.busy`) it looks again every `shiftWatchDelay`; it ends
    /// when nothing is due, the window shifted, or the session could not save (the next motion tries again). A
    /// clock that did not move during the wait (a test's fixed clock) or went back counts the wait as the delay.
    fileprivate func startWatch() {
        guard let state = spanState, !state.watchRunning, container != nil, !state.session.isClosed else { return }
        state.watchRunning = true
        state.watchGeneration += 1
        let generation = state.watchGeneration
        Task { @MainActor [weak self] in
            while true {
                guard let sleep = self?.parent.sleep, let before = self?.parent.clock() else { return }
                await sleep(InkCanvasView.shiftWatchDelay)
                guard let self, let state = self.spanState, state.watchGeneration == generation, self.container != nil else { return }
                let now = self.parent.clock()
                let elapsed = now.timeIntervalSince(state.lastMotionAt)
                if now > before, elapsed >= 0, elapsed < InkCanvasView.shiftWatchDelay - 0.001 { continue }
                // Every frame of a slide's animation scrolls: nothing scrolled for `shiftWatchDelay`, so no slide runs any
                // more, wherever the band stopped and whether or not UIKit told of the end (a touch or the canvas's own
                // offset may stop the animation without it). Kept, it would hold every shift and every press back.
                if state.slideTargetX != nil {
                    state.slideTargetX = nil
                    self.probeNote("Q")
                }
                let outcome = self.shiftIfAtRest()
                if outcome == .busy { continue }
                state.watchRunning = false
                self.continueQueuedSlide(after: outcome)
                return
            }
        }
    }

    /// The shift may be due: checked once, on the next turn (never inside a scroll-view call, a SwiftUI update or
    /// `applyPendingSpan`). Held back, the watch keeps looking.
    fileprivate func requestShiftCheck() {
        guard let state = spanState, !state.shiftCheckScheduled, container != nil else { return }
        state.shiftCheckScheduled = true
        Task { @MainActor [weak self] in
            guard let self, let state = self.spanState else { return }
            state.shiftCheckScheduled = false
            let outcome = self.shiftIfAtRest()
            if outcome == .busy {
                self.startWatch()
            } else {
                self.continueQueuedSlide(after: outcome)
            }
        }
    }

    /// A finger holds or drags the band, a fling or a pinch runs, or an arrow's slide.
    fileprivate func isBandMoving(_ canvas: PKCanvasView) -> Bool {
        let finger = spanState?.motionOverride ?? (canvas.isTracking || canvas.isDragging || canvas.isDecelerating)
        return finger || isLive || spanState?.slideTargetX != nil
    }

    /// §3.6 ずらす条件: the canvas is attached, has its zoom and its session is open; no pen or writing finger is on
    /// the paper and the settle wait is over; nothing is queued; no finger holds or drags the band, no fling, no
    /// pinch or bounce, no slide; nothing is selected or being moved; no sheet covers the band.
    var isAtRest: Bool {
        guard let state = spanState, let canvas, container != nil, hasInitialZoom, !state.session.isClosed else { return false }
        if isUsingTool || isSettling || touchingPaper || isMovingSelection || state.isShiftingWindow || resetScroll { return false }
        if pendingDrawing || pendingGeometry || pendingPaper || state.pendingWindow || !pendingHistory.isEmpty || !pendingCommands.isEmpty {
            return false
        }
        if isBandMoving(canvas) { return false }
        return selectedIds.isEmpty && !parent.isSheetOpen
    }

    /// The paper stopped (or may have): the focus and the visit go to the screen (`onSpanStop`, §3.7, D20); then,
    /// when the focus is off the window's middle page (or the width changed) and the canvas is at rest, the window
    /// shifts (or is decided anew). Internal for the tests (it is what the watch and `requestShiftCheck` run).
    @discardableResult
    func shiftIfAtRest() -> InkCanvasView.SpanShiftOutcome {
        guard let state = spanState, let canvas, container != nil, hasInitialZoom, !state.session.isClosed else { return .nothing }
        if isBandMoving(canvas) { return .busy }
        let stop = state.session.stopped(midX: currentMidX())
        if stop.focusDay != state.lastStopFocusDay || stop.ended != nil {
            state.lastStopFocusDay = stop.focusDay
            deliverNextTurn { [weak self] in self?.parent.onSpanStop(stop) }
        }
        guard state.session.needsShift || state.pendingRedecide else { return .nothing }
        guard isAtRest else { return .busy }
        if state.pendingRedecide { return redecideWindow() }
        return shiftWindow(to: state.session.focusIndex)
    }

    /// §3.6 ずらしの手順 (B_DESIGN.md:194-201): a stroke PencilKit holds and has not told of goes into the ledger and
    /// the journal into the inbox; the session shifts (the inbox emptied, the safety net, the pages that leave saved
    /// — a failure leaves everything as it is —, the history prune, the window composed, `pendingRemote` applied);
    /// the canvas takes the window in the same turn (`applyPendingSpan`: the history pruned, the ledger reloaded,
    /// the drawing rebuilt, x moved back by the pages that came in on the left, the paper of the window); the
    /// viewport goes to the owner in the same turn, after `windowVersion` moved (the heading pairs it with that
    /// version); the pages that came in are read.
    fileprivate func shiftWindow(to focus: Int) -> InkCanvasView.SpanShiftOutcome {
        guard let state = spanState, let canvas else { return .nothing }
        applyCanvasDrawing(canvas)
        putJournalIntoInbox(relayout: false)
        let oldFirst = (appliedLayout as? SpanLayout)?.firstIndex ?? 0
        #if DEBUG
        let started = CACurrentMediaTime()
        #endif
        state.isShiftingWindow = true
        defer { state.isShiftingWindow = false }
        guard state.session.shift(toFocusIndex: focus) else {
            state.refusedShiftCount += 1
            probeNote("Z!")
            return .refused
        }
        state.pendingWindow = true
        applyPendingSpan()
        deliverViewportNow()
        state.shiftCount += 1
        probeNote("Z\(((appliedLayout as? SpanLayout)?.firstIndex ?? oldFirst) - oldFirst)")
        #if DEBUG
        NSLog("span: shift %.1f ms", (CACurrentMediaTime() - started) * 1000)
        #endif
        startPrefetch()
        return .done
    }

    /// §3.6 回転・Split View: at a stop after the width changed, the session decides the window anew around the
    /// focus page (the plan of the screen's orientation, the radius the paper area needs) with the steps of a
    /// shift; the session, its virtual page and the history stay.
    fileprivate func redecideWindow() -> InkCanvasView.SpanShiftOutcome {
        guard let state = spanState, let canvas, let container else { return .nothing }
        applyCanvasDrawing(canvas)
        putJournalIntoInbox(relayout: false)
        state.isShiftingWindow = true
        defer { state.isShiftingWindow = false }
        let screen = container.window?.windowScene?.screen.bounds.size ?? container.bounds.size
        guard state.session.redecide(orientation: SpanOrientation(screen: screen), paperArea: container.bounds.size) else {
            state.refusedShiftCount += 1
            probeNote("Y!")
            return .refused
        }
        state.pendingRedecide = false
        state.pendingWindow = true
        applyPendingSpan()
        deliverViewportNow()
        state.shiftCount += 1
        probeNote("Y")
        startPrefetch()
        return .done
    }

    /// The viewport now (outside any SwiftUI update: a shift runs in a task), so the heading takes it with the new
    /// window's version in the same turn (§3.6 版つきの PaperViewport). A delivery `notifyViewport` put off to the
    /// next turn brings the same value again.
    fileprivate func deliverViewportNow() {
        guard let canvas, let container else { return }
        let viewport = PaperViewport(offsetX: canvas.contentOffset.x, zoom: canvas.zoomScale, width: container.bounds.width)
        lastViewport = viewport
        parent.onViewportChange(viewport)
    }

    /// ◀ ▶ and a near 「今日」 (§3.6, B_DESIGN.md:274-276): exactly `pages` pages (`SpanPlan.shiftAmount` at the zoom it has,
    /// so a boundary in the middle of the screen stays there), animated; kept on the band. The window shifts when the
    /// slide ends. The band holds R pages beyond the focus and has no side margin, so a page further on may lie past its
    /// end until the window has shifted (「今日」 two weeks away, a press while a slide runs): the slide goes the most pages
    /// that end inside the band (at least one), and the rest once the window shifted (`queuedSlidePages`, 「行き先が窓の外
    /// なら、窓をずらしてからすべる」). A press while a slide runs, under the pen or during a pinch waits for the paper to be
    /// at rest (B_DESIGN.md:274 ◀ ▶ はいつでも使える; never a slide under the pen). Internal for the tests (the owner's
    /// way is `slideTrigger`).
    func slide(byPages pages: Int) {
        guard let state = spanState, pages != 0, let canvas, let band = appliedLayout as? SpanLayout, hasInitialZoom else { return }
        if state.slideTargetX != nil || isLive || isUsingTool {
            state.queuedSlidePages += pages
            return
        }
        let total = pages + state.queuedSlidePages
        state.queuedSlidePages = 0
        guard total != 0 else { return }
        let zoom = max(canvas.zoomScale, 0.0001)
        let x = canvas.contentOffset.x
        let y = canvas.contentOffset.y
        let step = total > 0 ? 1 : -1
        var now = total
        while abs(now) > 1 {
            let aim = x + band.plan.shiftAmount(pages: now, zoom: zoom)
            if abs(clampedOffset(CGPoint(x: aim, y: y)).x - aim) < 0.5 { break }
            now -= step
        }
        let target = clampedOffset(CGPoint(x: x + band.plan.shiftAmount(pages: now, zoom: zoom), y: y))
        guard abs(target.x - x) >= 0.5 else { return }
        state.queuedSlidePages = total - now
        animateSlide(to: target)
    }

    /// Starts the animation of a slide to `target` (pt), or aims the running one again: UIKit's
    /// `setContentOffset(_:animated: true)` (the tests' stand-in when set), the middle of the screen it brings kept in
    /// band lu (`slideTargetMid`).
    fileprivate func animateSlide(to target: CGPoint) {
        guard let state = spanState, let canvas, let container else { return }
        state.lastSlideTargetX = target.x
        state.slideTargetX = target.x
        state.slideTargetMid = (target.x + container.bounds.width / 2) / max(canvas.zoomScale, 0.0001)
        noteMotion()
        if let animate = state.slideAnimation {
            animate(canvas, target)
        } else {
            canvas.setContentOffset(target, animated: true)
        }
    }

    /// The canvas moved the band itself while a slide runs (a window taken with new heights, a new height of the paper
    /// area and its zoom): UIKit's animation may have stopped there, or may go on to where it was aimed (y without the
    /// correction, x at the old zoom). On the next turn (never inside a SwiftUI update or a layout pass) the slide is
    /// aimed again from where the band is, to the same middle of the screen at the zoom it has now.
    fileprivate func reaimSlideNextTurn() {
        guard let state = spanState, state.slideTargetX != nil, !state.reaimScheduled else { return }
        state.reaimScheduled = true
        Task { @MainActor [weak self] in
            guard let self, let state = self.spanState else { return }
            state.reaimScheduled = false
            guard state.slideTargetX != nil, !self.isLive, let canvas = self.canvas, let container = self.container else { return }
            let zoom = max(canvas.zoomScale, 0.0001)
            let target = self.clampedOffset(CGPoint(x: state.slideTargetMid * zoom - container.bounds.width / 2, y: canvas.contentOffset.y))
            if abs(target.x - canvas.contentOffset.x) < 0.5 {
                state.slideTargetX = nil
                self.requestShiftCheck()
                return
            }
            self.animateSlide(to: target)
        }
    }

    /// The pages that waited (presses during a slide, under the pen or a pinch; the rest of a long slide), once the paper
    /// is still (the window shifted, or had nothing to shift); dropped when the session could not save a page that
    /// leaves.
    fileprivate func continueQueuedSlide(after outcome: InkCanvasView.SpanShiftOutcome) {
        guard let state = spanState, state.queuedSlidePages != 0, state.slideTargetX == nil else { return }
        let pages = state.queuedSlidePages
        state.queuedSlidePages = 0
        if outcome != .refused {
            slide(byPages: pages)
        }
    }

    // MARK: The palm (§3.6, B_DESIGN.md:354-360)

    /// `touchObserved`'s entry: when an Apple Pencil lifts (`clock()`).
    fileprivate func bandTouchObserved(_ change: InkTouchObserver.Change) {
        guard let state = spanState, case .up(let type) = change, type == .pencil else { return }
        state.lastPencilUp = parent.clock()
    }

    /// Asked by the band's pan before it begins (`InkBandCanvasView`).
    fileprivate func bandPanMayBegin(_ pan: UIPanGestureRecognizer) -> Bool {
        guard let state = spanState, let canvas else { return true }
        let may = InkCanvasView.panMayBegin(translation: pan.translation(in: canvas), velocity: pan.velocity(in: canvas),
                                            pencilsDown: pencilsDown, lastPencilUp: state.lastPencilUp, now: parent.clock())
        if !may {
            state.refusedPans += 1
            probeNote("P")
        }
        return may
    }

    // MARK: A change of the canvas (D15, D21, K-9, §3.3 5, §3.4 削除の守り)

    /// What `screenNewStrokesInBand` did, per owner page (K-9, D21).
    fileprivate struct BandScreening {
        /// Pages where a new stroke went more than 6,000 lu below the top of the last cell.
        var capPages: Set<String> = []
        /// The budget count of each page before its new strokes (no entry when none of them was left to count).
        var countsBefore: [String: Int] = [:]
        /// The count of each page whose new strokes were refused.
        var refused: [String: Int] = [:]
    }

    /// `applyCanvasDrawing`'s entry after its guard: 43fe366's ① – ⑦ for the window. The new strokes are screened by
    /// the band (`SpanLayout.drop`: outside the band, below a page's cap) and counted by the page that owns them;
    /// a removal that is not the eraser's (or too many at once) is not taken: the ledger keeps the strokes and the
    /// drawing is rebuilt from it once the pen is up (§3.3 5); an id that was already erased is recorded (a race
    /// that is allowed), one the page never had is a fault (Debug stops, S4's lead's decision 3). The notices name
    /// the owner page (D21).
    fileprivate func applyBandDrawing(_ canvasView: PKCanvasView) -> Bool {
        canvasView.undoManager?.removeAllActions()
        let screening = screenNewStrokesInBand(on: canvasView)
        for (pageId, before) in screening.refused.sorted(by: { $0.key < $1.key }) {
            deliver { [weak self] in self?.parent.onPageStrokeBudget(pageId, .full(before)) }
        }
        var capPages = screening.capPages
        defer {
            for pageId in capPages.sorted() {
                deliver { [weak self] in self?.parent.onPageGrowthCapReached(pageId) }
            }
        }
        let change = ledger.applyCanvasChange(canvasView.drawing, allowRemovals: parent.tool.isEraser || touchBeganWithEraser)
        noteRemovalGuards(change)
        guard !change.isEmpty else {
            probeNote("C0")
            return false
        }
        probeNote("C+\(change.added.count)-\(change.removedIds.count)\(isUsingTool ? "u" : "")\(isSettling ? "s" : "")\(parent.tool.isEraser ? "e" : "")")
        let addedAt = uptime()
        for stroke in change.added {
            noteRecentAdd(stroke.id, at: addedAt)
        }
        publishPage()
        notifyHistory()
        if !change.removedIds.isEmpty {
            refreshSelection()
        }
        // ⑤ A page reached 15,000 strokes with this canvas's stroke: each owner page on its own.
        if !change.added.isEmpty {
            for (pageId, before) in screening.countsBefore.sorted(by: { $0.key < $1.key }) {
                let after = InkCanvasView.budgetCount(ofPage: pageId, in: ledger.page)
                if StrokeBudget.crossesNotice(from: before, to: after) {
                    deliver { [weak self] in self?.parent.onPageStrokeBudget(pageId, .many(after)) }
                }
            }
        }
        // ⑥ The eraser (§2.5), as on the one page.
        let erasedNow = change.removedIds.count - change.added.count
        if parent.tool.isEraser, !parent.readOnly, erasedNow > 0 {
            erasedSinceReport += erasedNow
            if change.added.isEmpty {
                removedSinceTouch.append(contentsOf: change.removedIds)
            }
            scheduleEraseReport(.count)
        }
        // ⑦ The owner hears of it as on the one page (the window's relayout is asked by `putJournalIntoInbox`);
        // the cap notice reads the page's own name of the cell (§3.3's table) and names the owner page.
        let needsRoom = change.added.contains { ledger.needsMoreRoom($0) }
        if needsRoom || !change.removedIds.isEmpty {
            deliver { [weak self] in self?.parent.onInkBoundsChanged() }
        }
        for stroke in change.added where PaperGrowth.isTail(SpanName.strip(stroke.cell)) && PaperGrowth.reachesCap(inkBottom: stroke.bottom) {
            if let pageId = SpanName.split(stroke.cell.raw)?.page {
                capPages.insert(pageId)
            }
        }
        return true
    }

    /// §3.4 削除の守り, S4's lead's decisions 2 and 3, read before `isEmpty`: refused removals rebuild the drawing
    /// from the ledger (not under the pen); ids erased already are recorded; ids the page never had are a fault.
    fileprivate func noteRemovalGuards(_ change: InkChange) {
        if change.needsRebuild {
            probeNote("Rr\(change.refusedRemovals.count)")
            pendingDrawing = true
            requestApply()
        }
        if !change.alreadyErased.isEmpty {
            probeNote("Ra\(change.alreadyErased.count)")
        }
        if !change.unknownRemovals.isEmpty {
            probeNote("Ru\(change.unknownRemovals.count)")
            SpanSession.onFault("canvas: removals of ids the window never had: \(change.unknownRemovals.joined(separator: ","))")
        }
    }

    /// `screenNewStrokes` for the band (D15, M4C-25, K-9, D21): of the strokes the canvas holds that the ledger
    /// did not build, one centred outside the band or outside its page's paper (`.outsidePaper`, no notice) or
    /// more than 6,000 lu below the top of its page's last cell (`.belowCap`: that page's notice) is taken off
    /// the canvas, and so are the newest ones that would take their owner page past `StrokeBudget.refuseAt`.
    fileprivate func screenNewStrokesInBand(on canvasView: PKCanvasView) -> BandScreening {
        var result = BandScreening()
        guard let band = appliedLayout as? SpanLayout else { return result }
        let strokes = canvasView.drawing.strokes
        var keep = [Bool](repeating: true, count: strokes.count)
        var newIndices: [String: [Int]] = [:]
        for (index, pk) in strokes.enumerated() where ledger.id(of: pk) == nil {
            let box = StrokeGeometry.paperBounds(of: pk)
            let center = CGPoint(x: box.midX, y: box.midY)
            switch band.drop(center: center) {
            case .keep(let page, _):
                newIndices[page, default: []].append(index)
            case .belowCap:
                keep[index] = false
                if let target = band.eventTarget(at: center) {
                    result.capPages.insert(target.pageId)
                }
            case .outsidePaper, .viewOnly:
                keep[index] = false
            }
        }
        for (page, indices) in newIndices {
            let before = InkCanvasView.budgetCount(ofPage: page, in: ledger.page)
            result.countsBefore[page] = before
            let accepted = StrokeBudget.accepted(incoming: indices.count, count: before)
            if accepted < indices.count {
                for index in indices.suffix(indices.count - accepted) {
                    keep[index] = false
                }
                result.refused[page] = before
            }
        }
        guard keep.contains(false) else { return result }
        var kept: [PKStroke] = []
        kept.reserveCapacity(strokes.count)
        for (index, pk) in strokes.enumerated() where keep[index] {
            kept.append(pk)
        }
        let was = isApplyingDrawing
        isApplyingDrawing = true
        canvasView.drawing = PKDrawing(strokes: kept)
        isApplyingDrawing = was
        canvasView.undoManager?.removeAllActions()
        return result
    }
}
