import Layout

/// 1.4.3 (docs/R1_4_3_CONTRACT.md §2.1, §3.1, 0g-8): the kinds of page that join sideways while 設定 › ページ's switch is on,
/// in one place. The path (`ScreenPaths.joins`), 等倍 (`ZoomReset.followsFit`), the window's paper and heading
/// (`PaperSpan.window`) read it, so the fallback of 0g-3 (a version with the month alone) is one change here. The CI's
/// shell `case`s cannot read it; each says "the same as SpanKinds.joined".
///
/// D1b-0 (§14.1: the least of the month for the sample photos, on a work branch) had the week, the day and the month; D1y
/// (§14.1) added the year here, so all four kinds join (§2.1).
enum SpanKinds {
    /// The kinds a window joins with the setting on. The fallback (0g-3) takes `.year` out here and nowhere else.
    static let joined: Set<PageKind> = [.week, .day, .month, .year]

    /// `joined` in its order (the guide's kinds, the photos' order): the week, the day, the month, the year, each only
    /// when it is in `joined`.
    static var ordered: [PageKind] {
        [PageKind.week, .day, .month, .year].filter { joined.contains($0) }
    }
}
