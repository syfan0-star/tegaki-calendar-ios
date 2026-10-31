import Foundation
import CoreGraphics
import DayKit
import Layout
import InkModel

// The names of the frozen copy, pointed at the real 1.0 types (M7A_CONTRACT §1.4). The copied
// Compat10Checks.swift and LedgerV10.swift compile against these exactly as they compile against the
// copy, because the copy keeps the real names, nesting and access levels (only the suffix V10).
public typealias JSONValueV10 = InkModel.JSONValue
public typealias InkPointV10 = InkModel.InkPoint
public typealias InkToolV10 = InkModel.InkTool
public typealias InkStrokeV10 = InkModel.InkStroke
public typealias StrokeFingerprintV10 = InkModel.StrokeFingerprint
public typealias InkPageV10 = InkModel.InkPage
public typealias InkPageCodecV10 = InkModel.InkPageCodec
public typealias BandMigrationV10 = InkModel.BandMigration
public typealias CellKeyV10 = Layout.CellKey
public typealias PaperSpecV10 = Layout.PaperSpec
public typealias DayKeyV10 = DayKit.DayKey
public typealias AppExportV10 = InkModel.AppExport
public typealias WebImportV10 = InkModel.WebImport

// The facts of TegakiKit/Tests/Compat10/LayoutFactsV10.swift, here made by the real 1.0 Layout (that
// file is not copied into RunReal): when the hand-written facts are wrong, RunReal and RunFrozen
// disagree.

private let layoutNow = Date(timeIntervalSince1970: 1_790_000_000)

/// `layout.cells.keys` of the 1.0 layout of the page (no event, no handwriting); no cell for an id
/// 1.0 never opens.
public func cellsV10(pageId: String) -> Set<CellKeyV10> {
    if pageId.hasPrefix("d-") {
        guard let day = DayKey(ymd: String(pageId.dropFirst(2))) else { return [] }
        return Set(DayLayoutEngine.layout(DayLayoutInput(day: day, events: [], inkBottoms: [:], now: layoutNow)).cells.keys)
    }
    if pageId.hasPrefix("w-") {
        guard let day = DayKey(ymd: String(pageId.dropFirst(2))) else { return [] }
        return Set(WeekLayoutEngine.layout(WeekLayoutInput(focus: day, events: [], inkBottoms: [:], now: layoutNow)).cells.keys)
    }
    if pageId.hasPrefix("m1-") {
        let parts = pageId.dropFirst(3).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]), (1...12).contains(month) else { return [] }
        let input = MonthLayoutInput(month: YearMonth(year: year, month: month), events: [], inkBottoms: [:], now: layoutNow)
        return Set(MonthLayoutEngine.layout(input).cells.keys)
    }
    if pageId.hasPrefix("y-") {
        guard let year = Int(pageId.dropFirst(2)) else { return [] }
        return Set(YearLayoutEngine.layout(YearLayoutInput(year: year, events: [], inkBottoms: [:], now: layoutNow)).cells.keys)
    }
    return []
}

/// The real 1.0 memo area of the month page.
public func memoHeightV10(_ b: CGFloat) -> CGFloat {
    MonthLayoutEngine.memoHeight(inkBottom: b)
}
