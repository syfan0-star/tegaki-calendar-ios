import Foundation

/// What the week start does to the pages this device has (1.2, K-11, docs/M7B_CONTRACT.md §10.1,
/// §10.2). Pure functions over the stored form: nothing here moves or changes a stroke (K-2, D17).
/// Not one of the frozen data files.
public enum WeekStartImpact {
    /// The live strokes of a month page ("m1-…") whose day cell is not among the 42 days of the month's
    /// grid under `weekStart`, sorted: they are not drawn and not erased, and come back when the week
    /// start is switched back (D17, F1). Empty for any other page; a stroke on the memo is never hidden.
    public static func hiddenStrokeIds(in page: InkPage, weekStart: WeekStart) -> [String] {
        guard let parsed = PageNavigation.parse(pageId: page.pageId), parsed.kind == .month else { return [] }
        let grid = Set(MonthLayout.grid(year: parsed.focus.year, month: parsed.focus.month, weekStart: weekStart).days)
        return page.liveStrokes.compactMap { stroke in
            guard let day = stroke.cell.day, !grid.contains(day) else { return nil }
            return stroke.id
        }.sorted()
    }

    /// The week pages among `ids` by the weekday of their date. Reads the ids only, never a file, so a
    /// page whose strokes were all erased counts too (the sentences say 「週のページが」, §10.4). An id
    /// that is not a week page, or whose date is neither a Monday nor a Sunday, is not counted.
    public static func weekPages(_ ids: [String]) -> (monday: Int, sunday: Int) {
        var monday = 0, sunday = 0
        for id in ids {
            guard let parsed = PageNavigation.parse(pageId: id), parsed.kind == .week else { continue }
            switch WeekStart(weekPageDate: parsed.focus) {
            case .monday: monday += 1
            case .sunday: sunday += 1
            case nil: break
            }
        }
        return (monday, sunday)
    }
}
