#if SPAN_PROTOTYPE
import Darwin
import Foundation
import InkModel
import Layout
import QuartzCore
import SwiftUI
import UIKit

// What the prototype measures and shows in a corner of its screen (1.3, docs/M7C_CONTRACT.md §4.6 測ること,
// D6, D18, §3.15, §3.16; B_DESIGN.md §6.1, §8.2): every number is read on the device while the prototype
// runs — a clock around the work, the kernel's count of the process's memory, the display's frames — never
// an estimate. And the synthetic strokes of 「線の数」 that fill the prototype's pages for it. Compiled only
// into the prototype build (`SPAN_PROTOTYPE`); it goes away with the prototype (S6).

// MARK: - Memory

/// The process's memory as the system counts it.
enum SpanPrototypeMemory {
    /// The physical footprint (bytes): `task_vm_info.phys_footprint`, what Xcode's memory gauge shows and the
    /// system's memory limit for an app counts. nil when the kernel does not answer.
    static func footprint() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { raw in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), raw, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return info.phys_footprint
    }
}

// MARK: - Meter

/// The measurements of one opening of the prototype (§4.6 測ること). The canvas and the session report what
/// they timed or counted; the meter keeps the last value and the largest since the last `reset()` (a new
/// 「線の数」 or week start), samples the memory every `refresh` seconds and right after a swap, and watches
/// the display's frames for `frameWindow` seconds after each swap. The HUD reads `snapshot`, published at most
/// every `refresh` seconds and never from inside the canvas's work (a SwiftUI update may be running then).
@MainActor
final class SpanPrototypeMeter: ObservableObject {
    /// What the HUD shows. Times in ms, memory in MB (10⁶ bytes), lengths in pt; nil: nothing measured yet.
    struct Snapshot: Equatable {
        /// The last window swap (a shift, or the first drawing of a window): all of it, the largest, and the
        /// session's part of the last (the pages that leave saved, those that come in read, the window composed).
        var swapMs: Double?
        var swapMaxMs: Double?
        var swapSessionMs: Double?
        /// How far the focus page moved on screen in the last shift (§3.6: 0, at most 0.5).
        var driftPt: Double?
        /// The longest interval between two frames of the display in the second after the last swap (the
        /// hitch one sees; 16.7 at 60 Hz, 8.3 at 120 Hz when nothing is held up).
        var frameGapMs: Double?
        /// The physical footprint now, and the largest sample since the last reset.
        var memoryMB: Double?
        var memoryPeakMB: Double?
        /// The main thread's work when the pen lifts (PencilKit's change handed to the canvas: the new strokes
        /// screened, `drawing.strokes` read, the ledger's diff, the deltas), last and largest.
        var liftMs: Double?
        var liftMaxMs: Double?
        /// The strokes one change of the eraser removed (§3.16's 50), last and largest.
        var erased: Int?
        var erasedMax: Int?
        /// One page read from its file (`sync.load` and `BandMigration`, D6's 16 ms), last, largest and the
        /// strokes of that largest page.
        var loadMs: Double?
        var loadMaxMs: Double?
        var loadMaxStrokes: Int?
        /// Pans the palm's rule held (§3.6), and the size of the last finger touch (`UITouch.majorRadius`, pt)
        /// and the largest (the 【推論】 of §3.6 on large contacts).
        var palmRefused = 0
        var touchRadius: Double?
        var touchRadiusMax: Double?
        /// The horizontal speed of the last release (pt per ms; `SpanPlan.flingVelocity` is the border).
        var releaseVelocity: Double?
        /// The live strokes of the window's pages.
        var windowStrokes: Int?
    }

    static let refresh: TimeInterval = 0.5
    static let frameWindow: CFTimeInterval = 1

    @Published private(set) var snapshot = Snapshot()
    private var live = Snapshot()
    private var running = false
    private var generation = 0
    private var displayLink: CADisplayLink?
    private var lastFrame: CFTimeInterval?
    /// When the last swap began (the frames after it are watched for `frameWindow`).
    private var swapStartedAt: CFTimeInterval?

    /// Starts the memory samples, the publishing and the frame watch (the screen appears).
    func start() {
        guard !running else { return }
        running = true
        generation += 1
        let current = generation
        let target = SpanPrototypeFrameTarget(meter: self)
        let link = CADisplayLink(target: target, selector: #selector(SpanPrototypeFrameTarget.tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        sampleMemory()
        Task { @MainActor [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(Self.refresh))
                guard let self, self.running, self.generation == current else { return }
                self.sampleMemory()
                self.publish()
            }
        }
    }

    /// Stops everything `start` began (the screen closes).
    func stop() {
        running = false
        generation += 1
        displayLink?.invalidate()
        displayLink = nil
        lastFrame = nil
    }

    /// Forgets every measurement (a new 「線の数」 or week start measures afresh); the memory is sampled again.
    func reset() {
        live = Snapshot()
        swapStartedAt = nil
        sampleMemory()
        publish()
    }

    /// Publishes what changed since the last time (the HUD's text).
    func publish() {
        if snapshot != live { snapshot = live }
    }

    // MARK: Reports

    /// A window swap that began at `startedAt` (`CACurrentMediaTime`) and took `seconds` (`sessionSeconds` of
    /// them the session's), the focus page `drift` pt from where it was (nil for a first drawing).
    func recordSwap(seconds: TimeInterval, sessionSeconds: TimeInterval?, drift: CGFloat?, startedAt: CFTimeInterval) {
        let ms = seconds * 1000
        live.swapMs = ms
        live.swapMaxMs = max(live.swapMaxMs ?? 0, ms)
        live.swapSessionMs = sessionSeconds.map { $0 * 1000 }
        if let drift { live.driftPt = Double(drift) }
        live.frameGapMs = nil
        swapStartedAt = startedAt
        sampleMemory()
    }

    /// The main thread's work for one change PencilKit handed over when the pen lifted.
    func recordPenLift(seconds: TimeInterval) {
        let ms = seconds * 1000
        live.liftMs = ms
        live.liftMaxMs = max(live.liftMaxMs ?? 0, ms)
    }

    /// One change of the eraser removed `removed` strokes.
    func recordEraserChange(removed: Int) {
        live.erased = removed
        live.erasedMax = max(live.erasedMax ?? 0, removed)
    }

    /// One page read in `seconds`, holding `strokes` live strokes.
    func recordLoad(seconds: TimeInterval, strokes: Int) {
        let ms = seconds * 1000
        live.loadMs = ms
        if ms >= (live.loadMaxMs ?? -1) {
            live.loadMaxMs = ms
            live.loadMaxStrokes = strokes
        }
    }

    /// The palm's rule held a pan.
    func recordPalmRefused() {
        live.palmRefused += 1
    }

    /// A finger touched the paper with this `majorRadius` (pt).
    func recordTouch(radius: CGFloat) {
        guard radius.isFinite, radius >= 0 else { return }
        live.touchRadius = Double(radius)
        live.touchRadiusMax = max(live.touchRadiusMax ?? 0, Double(radius))
    }

    /// A drag was released at this horizontal speed (pt per ms).
    func recordRelease(velocity: CGFloat) {
        guard velocity.isFinite else { return }
        live.releaseVelocity = Double(velocity)
    }

    /// The window's pages hold `count` live strokes.
    func recordWindowStrokes(_ count: Int) {
        live.windowStrokes = count
    }

    /// A frame of the display at `timestamp` (`CADisplayLink.timestamp`, the clock of `CACurrentMediaTime`).
    func frame(at timestamp: CFTimeInterval) {
        defer { lastFrame = timestamp }
        guard let last = lastFrame, let started = swapStartedAt, timestamp > started,
              timestamp - started <= Self.frameWindow else { return }
        let gap = (timestamp - last) * 1000
        live.frameGapMs = max(live.frameGapMs ?? 0, gap)
    }

    private func sampleMemory() {
        guard let bytes = SpanPrototypeMemory.footprint() else { return }
        let mb = Double(bytes) / 1_000_000
        live.memoryMB = mb
        live.memoryPeakMB = max(live.memoryPeakMB ?? 0, mb)
    }

    // MARK: The HUD's lines

    /// The lines of the HUD for `snapshot` (ja-only keys of the prototype; "-" where nothing was measured).
    static func lines(_ s: Snapshot) -> [String] {
        [
            L.format("prototype.span.hud.swap", ms(s.swapMs), ms(s.swapMaxMs), ms(s.swapSessionMs)),
            L.format("prototype.span.hud.drift", decimal(s.driftPt, digits: 2)),
            L.format("prototype.span.hud.frame", ms(s.frameGapMs)),
            L.format("prototype.span.hud.memory", decimal(s.memoryMB, digits: 0), decimal(s.memoryPeakMB, digits: 0)),
            L.format("prototype.span.hud.lift", ms(s.liftMs), ms(s.liftMaxMs)),
            L.format("prototype.span.hud.erase", count(s.erased), count(s.erasedMax)),
            L.format("prototype.span.hud.load", ms(s.loadMs), ms(s.loadMaxMs), count(s.loadMaxStrokes)),
            L.format("prototype.span.hud.palm", L.count(s.palmRefused), decimal(s.touchRadius, digits: 1), decimal(s.touchRadiusMax, digits: 1)),
            L.format("prototype.span.hud.fling", decimal(s.releaseVelocity, digits: 2), decimal(Double(SpanPlan.flingVelocity), digits: 2)),
            L.format("prototype.span.hud.strokes", count(s.windowStrokes)),
        ]
    }

    private static func ms(_ value: Double?) -> String {
        decimal(value, digits: 1)
    }

    private static func decimal(_ value: Double?, digits: Int) -> String {
        guard let value, value.isFinite else { return "-" }
        return String(format: "%.\(digits)f", value)
    }

    private static func count(_ value: Int?) -> String {
        guard let value else { return "-" }
        return L.count(value)
    }
}

/// The display link's target: the meter is held weakly (a display link holds its target), and the link is
/// invalidated by `SpanPrototypeMeter.stop()`.
@MainActor
final class SpanPrototypeFrameTarget: NSObject {
    private weak var meter: SpanPrototypeMeter?

    init(meter: SpanPrototypeMeter) {
        self.meter = meter
    }

    @objc func tick(_ link: CADisplayLink) {
        meter?.frame(at: link.timestamp)
    }
}

// MARK: - HUD

/// The measurements in a corner of the band (§4.6: 数を画面の隅に出す): small white text on a dark plate.
/// Touches go through it to the paper.
struct SpanPrototypeHUD: View {
    @ObservedObject var meter: SpanPrototypeMeter

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(SpanPrototypeMeter.lines(meter.snapshot).enumerated()), id: \.offset) { item in
                Text(item.element)
            }
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.white)
        .padding(6)
        .background(Color.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 6))
        .padding(8)
        .allowsHitTesting(false)
    }
}

// MARK: - Synthetic strokes

/// The strokes 「線の数」 fills the prototype's pages with (§4.6: windows of 2,500, 10,000 and 25,000 strokes):
/// short wavy pen strokes like handwriting, 24 control points each (B_DESIGN.md §6.1 measured with 40; a
/// written stroke has some tens), spread over each week's 24 hours. The same page id, count and tag always
/// give the same strokes (the pictures of CI are the same each run). Their ids start with "syn-", so a new
/// count takes the old ones out of the page (`replacing`) — only in the prototype's own folder, which is never
/// synced.
enum SpanPrototypeSynthetic {
    /// The window totals the menu offers (0 = only what was written in the prototype).
    static let counts = [2_500, 10_000, 25_000]
    static let idPrefix = "syn-"
    static let pointsPerStroke = 24
    /// The pen strokes' colours (the presets' ink colours of the toolbar look).
    static let colors = ["#1f2937", "#2563eb", "#dc2626", "#16a34a"]

    static func isSynthetic(_ id: String) -> Bool {
        id.hasPrefix(idPrefix)
    }

    /// `count` strokes for page `pageId` in its `grid` cell (cell-relative lu, the week's 1400 × 1920), ids
    /// "syn-<tag>-<n>", times one apart from a fixed date (each stroke's PencilKit fingerprint differs).
    static func strokes(pageId: String, count: Int, tag: Int) -> [InkStroke] {
        guard count > 0 else { return [] }
        var random = Random(seed: seed(of: pageId) ^ UInt64(truncatingIfNeeded: tag))
        let base = 1_790_000_000_000 + Int(seed(of: pageId) % 1_000_000) * 1_000
        var out: [InkStroke] = []
        out.reserveCapacity(count)
        for n in 0..<count {
            let x0 = 80 + random.unit() * 1_260
            let y0 = 20 + random.unit() * 1_860
            let width = 16 + random.unit() * 40
            let amplitude = 3 + random.unit() * 9
            let waves = 1 + Double(random.below(3))
            var points: [InkPoint] = []
            points.reserveCapacity(pointsPerStroke)
            for j in 0..<pointsPerStroke {
                let f = Double(j) / Double(pointsPerStroke - 1)
                let x = x0 + width * f
                let y = y0 + amplitude * sin(f * Double.pi * waves)
                points.append(InkPoint(x: CGFloat(x), y: CGFloat(y), dtMs: j * 8, sizeW: 3, sizeH: 3, opacity: 1, force: 0.5,
                                       azimuth: 0, altitude: 1.571))
            }
            let color = colors[n % colors.count]
            out.append(InkStroke(id: "\(idPrefix)\(tag)-\(n)", cell: .grid, tool: .pen, color: color, t: base + n, points: points))
        }
        return out
    }

    /// `page` without its synthetic strokes and their tombstones (taken out, not tombstoned: the prototype's
    /// folder is never synced), with `strokes` added.
    static func replacing(_ page: InkPage, with strokes: [InkStroke]) -> InkPage {
        var out = page
        out.strokes = out.strokes.filter { !isSynthetic($0.key) }
        out.deleted = out.deleted.filter { !isSynthetic($0.key) }
        out.unknownStrokes = out.unknownStrokes.filter { !isSynthetic($0.key) }
        for stroke in strokes {
            out.add(stroke)
        }
        return out
    }

    /// FNV-1a over the id's bytes.
    private static func seed(of text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }

    /// xorshift64*: the same seed gives the same numbers on every device.
    struct Random {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed == 0 ? 0x9e37_79b9_7f4a_7c15 : seed
        }

        mutating func next() -> UInt64 {
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27
            return state &* 0x2545_f491_4f6c_dd1d
        }

        /// In [0, 1).
        mutating func unit() -> Double {
            Double(next() >> 11) / Double(UInt64(1) << 53)
        }

        /// In 0..<n.
        mutating func below(_ n: Int) -> Int {
            Int(next() % UInt64(max(1, n)))
        }
    }
}
#endif
