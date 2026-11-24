import Foundation
import UIKit

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §4.1, 0f-19): the pattern of the memo areas — the month's memo area, the day's right
/// column 「メモ」 and the free memo below 24:00 of the day and the week — chosen in 設定 › 「メモ欄の紙」: ruled lines (1.4.1's
/// paper, the default), a dot grid on the rows of the ruled lines, or blank paper. One setting for every memo area, per device
/// (`AppSettings.memoPaperKey`, UserDefaults, never sent to iCloud, never in an export or a PDF's data). Only the drawing of the
/// paper changes: no handwriting moves, and the layouts, the content and the joined window (`PaperSpan`) do not know it.
///
/// The paper reads it as a property of `PaperView` (`PaperView.memoPaper`, §4.3, 0f-21): every `PaperView` starts with
/// `current` and follows `didChange`, so the one page, the joined window and the PDF all draw the device's choice.
enum MemoPaperStyle: String, CaseIterable, Sendable {
    case ruled, dots, plain

    /// The stored value: nil, an unknown text or anything that is not text (UserDefaults' `string(forKey:)` gives nil or the
    /// number's text) is the ruled paper, 1.4.1's.
    init(stored raw: String?) {
        self = raw.flatMap(MemoPaperStyle.init(rawValue:)) ?? .ruled
    }

    /// The pattern in force, for every `PaperView` made from now on (`WeekStartChoice.current`'s and
    /// `HolidayChoice.current`'s shape). `prepareAtLaunch` sets it once; `set` after a choice in the settings.
    @MainActor static var current: MemoPaperStyle = .ruled

    /// Posted by `set` when `current` changed; every `PaperView` reads `current` again and redraws once.
    static let didChange = Notification.Name("MemoPaperStyle.didChange")

    /// `CalendarRootScreen.init`, once, beside `WeekStartChoice.prepareAtLaunch` (§4.1):
    /// - screenshot mode: `--screenshot-memo-paper` (`Config.memoPaper`), the ruled paper without it; the stored value is
    ///   not read (`--screenshot-hand`'s shape), so the photos of J-4 stay ruled whatever a simulator kept;
    /// - a test host (`testHost`, by default `SyncEngine.isTestHost`): the ruled paper, the stored value not read, so a
    ///   simulator that kept 「ドット方眼」 cannot change the frozen pixel tests of the paper;
    /// - otherwise the value stored on this device.
    /// Inside the unit tests `SyncEngine.isTestHost` is always true, so the stored value's branch is reached only with
    /// `testHost: false` (MemoPaperStyleTests, mutation MM4): 1.4.1's lesson of a stored value no check ever read.
    @MainActor static func prepareAtLaunch(shot: ScreenshotMode.Config?, _ defaults: UserDefaults = AppSettings.defaults,
                                           testHost: Bool = SyncEngine.isTestHost) {
        let value: MemoPaperStyle
        if let shot {
            value = shot.memoPaper ?? .ruled
        } else if testHost {
            value = .ruled
        } else {
            value = MemoPaperStyle(stored: defaults.string(forKey: AppSettings.memoPaperKey))
        }
        set(value)
    }

    /// Makes `style` the pattern in force: when it differs from `current`, `current` changes and `didChange` is posted (the
    /// paper views redraw); the same value does nothing.
    @MainActor static func set(_ style: MemoPaperStyle) {
        guard style != current else { return }
        current = style
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §4.4, §4.5, 0f-22, 0f-23): the dots of 「ドット方眼」. The rows are the ruled lines' (the
/// area's top + `step` × k, k ≥ 1, above its bottom), so handwriting written on the lines sits on the rows of dots; the columns
/// are one grid for every page, x = `columnOrigin` + `step` × k in the page's own coordinates, between the area's left + `inset`
/// and its right − `inset`: the month 30…1,380 (28 dots), the day's right column 680…980 (7), the day's free memo 30…980 (20),
/// the week's 30…1,380 (28). On the day page the right column's dots stand above the free memo's, and on joined pages (each drawn
/// in its own coordinates, `PaperView.drawSpan`) the columns go on 50 lu apart across a boundary (the day 980 → 1,030, the week
/// 1,380 → 1,430: 1,000 and 1,400 are multiples of 50), where the ruled lines leave 40 lu.
///
/// A dot is `diameter` points wide on the screen at every zoom (`PaperText.hairline`'s idea: d / zoom lu; on a PDF, 1 lu = 1 pt),
/// its centre on the device pixels (`PaperText.snapDot`). Every dot that meets `dirty` goes into one path, filled once.
enum MemoDots {
    /// The first column of the grid (lu from the page's left: the month's and the free memo's inset 20, rounded up to the grid).
    static let columnOrigin: CGFloat = 30
    /// The distance between two columns (lu), the ruled lines' 50.
    static let step: CGFloat = 50
    /// The dot's diameter on the screen (pt): the owner's choice (a) by default (§4.5; (b) 1.5, (c) 2.5). The colour is
    /// `PaperPalette.memoDot`.
    static let diameter: CGFloat = 2

    /// The x of every column between `left` + `inset` and `right` − `inset` (page coordinates, lu), all of them.
    static func columns(left: CGFloat, right: CGFloat, inset: CGFloat) -> [CGFloat] {
        columns(from: left + inset, to: right - inset)
    }

    /// The columns of the grid in `minX`…`maxX` (both included).
    private static func columns(from minX: CGFloat, to maxX: CGFloat) -> [CGFloat] {
        guard minX.isFinite, maxX.isFinite, maxX >= minX else { return [] }
        let first = Int(((minX - columnOrigin) / step - 1e-6).rounded(.up))
        let last = Int(((maxX - columnOrigin) / step + 1e-6).rounded(.down))
        guard last >= first else { return [] }
        return (first...last).map { columnOrigin + CGFloat($0) * step }
    }

    /// The dots of one memo area: rows at `top` + `rowStep` × k (k ≥ 1) while below `bottom`, columns of the grid between
    /// `left` + `inset` and `right` − `inset`; only what meets `dirty` (both x and y), in `PaperPalette.memoDot`. Returns how
    /// many dots were drawn (the tests and the timing log read it).
    @discardableResult
    static func draw(_ ctx: CGContext, top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat, inset: CGFloat,
                     rowStep: CGFloat, dirty: CGRect, zoom: CGFloat, scale: CGFloat) -> Int {
        let z = max(zoom, 0.0001)
        let size = diameter / z
        let reach = size / 2 + 1
        guard rowStep > 0, bottom > top, !dirty.isNull, !dirty.isEmpty else { return 0 }
        let xs = columns(from: max(left + inset, dirty.minX - reach), to: min(right - inset, dirty.maxX + reach))
        guard !xs.isEmpty else { return 0 }
        let snappedXs = xs.map { PaperText.snapDot($0, diameter: diameter, zoom: z, scale: scale) }
        let firstRow = max(1, Int(((dirty.minY - reach - top) / rowStep - 1e-6).rounded(.up)))
        var count = 0
        ctx.saveGState()
        ctx.setFillColor(PaperPalette.memoDot.cgColor)
        ctx.beginPath()
        var k = firstRow
        while true {
            let y = top + CGFloat(k) * rowStep
            guard y < bottom, y <= dirty.maxY + reach else { break }
            let sy = PaperText.snapDot(y, diameter: diameter, zoom: z, scale: scale)
            for sx in snappedXs {
                ctx.addEllipse(in: CGRect(x: sx - size / 2, y: sy - size / 2, width: size, height: size))
            }
            count += snappedXs.count
            k += 1
        }
        if count > 0 {
            ctx.fillPath()
        }
        ctx.restoreGState()
        return count
    }
}
