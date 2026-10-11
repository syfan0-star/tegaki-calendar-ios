# M3a 実装契約（週・日・年ページ＋表示の切替＋ページごとの手書き）

この文書は M3a の各担当が同時に作業するための **約束事**（公開 API・データ形状・ファイル所有）です。[M2_CONTRACT.md](M2_CONTRACT.md) の続きで、M2 で決めたことはそのまま生きています（ここに書いていない M2 の API は変えません）。
設計の根拠は [DESIGN.md](DESIGN.md)（§2.2 行が伸びるレイアウトの定数、§2.4〜2.7 各ページとヘッダー、§3.4 マスの鍵）。ここに無いことは DESIGN.md に従い、DESIGN.md にも無ければ Web 版（`../tegaki-calendar/js/views/page-geometry.js`・`event-layout.js`・`week-view.js`・`day-view.js`・`year-view.js`・`styles/views.css`・`docs/SPEC.md`）の流儀に合わせます。本人が毎日使っている Web 版の **見え方・動き方が正** です。

**M3a の範囲**: 週・日・年ページの紙と手書き、予定の **表示**（終日帯・時間軸の箱・年のチップ）、ヘッダーの 日/週/月/年 切替と ◀ 今日 ▶、タップでのページ移動、初期スクロール、現在時刻の赤線、ページごとの保存、スクリーンショットモードの拡張。
**M3b に残すもの**（この契約では作らない）: 予定の作成・編集・削除、予定ツール、投げなわ、設定画面、初回案内の 4 枚化、iPhone 向けの見た目の調整。

## 0. 構成とファイル所有

```
TegakiKit/                                   担当 K（TegakiKit だけを触る）
  Sources/Layout/PaperSpec.swift             変更: 週・日・年の定数、CellKey の追加（§1.1, §1.2）
  Sources/Layout/PageLayout.swift            新規: PageKind, PageBand, PageLayout プロトコル, PageScroll, NowLine, HitTarget の拡張（§1.3, §1.4）
  Sources/Layout/TimedEventEngine.swift      新規: 時間指定の重なり処理（Web 版 layoutTimedEvents の移植）と箱の矩形（§1.4）
  Sources/Layout/LanePacking.swift           新規: レーンの間引き（Web 版 allDayLaneMetrics の移植）（§1.4）
  Sources/Layout/MonthPageLayout.swift       変更: PageLayout に適合（公開 API は維持）（§1.5）
  Sources/Layout/MonthLayoutEngine.swift     変更: scrollDelta を PageScroll に委譲（公開 API は維持）（§1.5）
  Sources/Layout/WeekLayoutEngine.swift      新規: WeekLayoutInput / WeekPageLayout / WeekLayoutEngine（§1.6）
  Sources/Layout/DayLayoutEngine.swift       新規: DayLayoutInput / DayPageLayout / DayLayoutEngine（§1.7）
  Sources/Layout/YearLayoutEngine.swift      新規: YearLayoutInput / YearPageLayout / YearChip / YearRow / YearLayoutEngine（§1.8）
  Sources/Layout/PageNavigation.swift        新規: pageId・表示範囲・前後移動・題名・初期スクロール（§1.9）
  Sources/KitChecks/main.swift               変更: §8.1 の検査を追加
  Tests/LayoutTests/TimedEventEngineTests.swift, WeekLayoutEngineTests.swift, DayLayoutEngineTests.swift,
        YearLayoutEngineTests.swift, PageNavigationTests.swift, PageLayoutTests.swift   新規（§8.1）
  Package.swift                              変更なし（DayKit / Holidays / Layout / InkModel の構成のまま）
Sources/TegakiCalendar/
  Ink/InkLedger.swift                        担当 I   変更: `any PageLayout` に一般化（§2）
  Ink/InkCanvasView.swift                    担当 I   変更: `any PageLayout`、初期スクロール、紙幅からの倍率（§2）
  Ink/InkTools.swift, Ink/PencilInteraction.swift   担当 I   変更なし
  Paper/PaperView.swift                      担当 U   Ink/PaperView.swift を **移動**して一般化（PaperView 本体・PaperContent・PaperPalette）（§3）
  Paper/MonthPaper.swift                     担当 U   新規: M2 の月ページ描画をそのまま移す
  Paper/WeekPaper.swift, DayPaper.swift, YearPaper.swift   担当 U   新規（§3）
  Views/CalendarRootScreen.swift             担当 U   新規: Views/MonthPageScreen.swift を一般化したもの（MonthPageScreen.swift は削除）（§4）
  Views/PageHeaderView.swift                 担当 U   新規: ◀ 今日 ▶・題名・日/週/月/年・カレンダーのメニュー（§4）
  Views/StickyHeaderView.swift               担当 U   新規: ページごとの固定見出し（曜日行・週の日付見出し・日の日付・年の月名）（§4）
  Views/OnboardingView.swift                 担当 U   MonthPageScreen.swift から移す（内容は変更なし）
  Views/ToolbarView.swift, Views/EventDetailSheet.swift   担当 U   EventDetailSheet から DayEventsSheet を削除（§4.4）
  Calendar/EventKitService.swift, Calendar/EventStoreModel.swift   担当 U   変更: 任意の日付範囲の取得（§5）
  Persistence/InkPageStore.swift             担当 U   変更なし（pageId ごとのファイル）
  Support/ScreenshotMode.swift               担当 U   変更: --screenshot-page、ページごとの見本の線（§7）
Tests/TegakiCalendarTests/InkLedgerTests.swift   担当 I   変更: 週・日・年のマス割り当て（§8.2）
Tests/TegakiCalendarTests/ScreenshotModeTests.swift   担当 U   新規（§8.3）
project.yml / .github/workflows/build.yml / README.md / docs/M3A.md   担当 C（統合・CI）（§9）
```

依存の向き（M2 と同じ）: `TegakiCalendar` → `TegakiKit`（Layout, Holidays, InkModel）。
**担当 U は `Ink/*` を触らない。担当 I は `Views/*`・`Paper/*` を触らない。担当 K は `TegakiKit/` だけ。** 担当 I と U の接点は次の 3 つだけで、いずれもこの契約に書いてある形に固定します。

1. `InkCanvasView` の引数（§2.2）: U が作って渡す。
2. `PaperView` の `init(content:)`・`content`・`zoomScale`（§3.1）: I が M2 と同じ呼び方で使う（`PaperView(content: paper)` の 1 行だけが U の型を前提にする）。
3. `PaperContent: Equatable`（§3.1）: I は `==` でしか使わない。

ファイルの移動（`Ink/PaperView.swift` → `Paper/PaperView.swift`、`MonthPageScreen.swift` → `CalendarRootScreen.swift` ほか）は担当 U が行います。`project.yml` は `Sources/TegakiCalendar` を丸ごと拾うので変更不要です。

## 1. Layout（担当 K）

### 1.1 PaperSpec の追加定数（DESIGN §2.2 と同じ数字、lu）

```swift
public enum PaperSpec {
  // --- 月（M2 のまま。変更しない） ---
  // monthWidth 1400, monthColumnWidth 200, monthRowBase 175, monthRowMax 1200, monthDateHeader 28,
  // allDayLane 22, allDayGap 3, allDayLaneStep 25, timedChip 20, timedChipCap 3, monthInkMargin 40,
  // inkPad 12, memoMin 700, memoInkPad 50, cellInset 4

  // --- 週 ---
  public static let weekWidth: CGFloat = 1400
  public static let weekGutter: CGFloat = 64                       // 左の時刻帯
  public static let weekColumns = 7
  public static var weekColumnWidth: CGFloat { (weekWidth - weekGutter) / 7 }   // 190.857142…（丸めない）
  public static let weekHourHeight: CGFloat = 80
  public static var weekGridHeight: CGFloat { weekHourHeight * 24 }           // 1920（伸びない）
  public static let weekBandBase: CGFloat = 60                     // 終日帯の基本高さ
  public static let weekBandMax: CGFloat = 800                     // 終日帯の上限
  public static let weekBandTopPad: CGFloat = 3                    // 帯の上端から最初のレーンまで
  public static let weekBandInkMargin: CGFloat = 30                // 最後のレーンの下に残す手書きの余白
  public static let weekBarInset: CGFloat = 3                      // 帯の左右の内側余白（続く側は 0）
  public static let weekBoxPadLeft: CGFloat = 2, weekBoxPadRight: CGFloat = 6, weekBoxGap: CGFloat = 2   // 時間指定の箱
  //   レーン高は月と同じ allDayLane 22 ＋ allDayGap 3 = allDayLaneStep 25

  // --- 日 ---
  public static let dayWidth: CGFloat = 1000
  public static let dayGutter: CGFloat = 72
  public static let dayTimelineRight: CGFloat = 660                // 時間軸は x 72〜660、メモ欄は 660〜1000
  public static let dayHourHeight: CGFloat = 100
  public static var dayGridHeight: CGFloat { dayHourHeight * 24 }  // 2400（伸びない）
  public static let dayBandBase: CGFloat = 60, dayBandMax: CGFloat = 800
  public static let dayBandTopPad: CGFloat = 2
  public static let dayBandInkMargin: CGFloat = 30
  public static let dayLaneGap: CGFloat = 2                        // レーン高 22 ＋ 2 = 24（DESIGN §2.2 の「24」）
  public static var dayLaneStep: CGFloat { allDayLane + dayLaneGap }
  public static let dayChipPadLeft: CGFloat = 4, dayChipPadRight: CGFloat = 12   // 終日チップは時間軸の列の中（Web 版 .sh-allday-items）
  public static let dayBoxPadLeft: CGFloat = 4, dayBoxPadRight: CGFloat = 14, dayBoxGap: CGFloat = 3
  public static let dayRuleStep: CGFloat = 50, dayRuleInset: CGFloat = 20       // メモ欄の罫線（月のメモ欄と同じ）

  // --- 年 ---
  public static let yearWidth: CGFloat = 1400
  public static let yearGutter: CGFloat = 56                       // 左の日付（1〜31）の帯
  public static let yearColumns = 12, yearRows = 31
  public static let yearColumnWidth: CGFloat = 112
  public static let yearRowBase: CGFloat = 60, yearRowMax: CGFloat = 400
  public static let yearHeader: CGFloat = 16                       // 曜日の字の行
  public static let yearLane: CGFloat = 16, yearLaneGap: CGFloat = 2            // 18 = DESIGN §2.2 の「レーン高＋隙間」
  public static var yearLaneStep: CGFloat { yearLane + yearLaneGap }
  public static let yearInkMargin: CGFloat = 8
  public static let yearChipLeft: CGFloat = 0.45                   // チップはマスの右 55%（左 45% は手書き用）
  public static let yearPad: CGFloat = 3                           // 曜日の字・チップのマス端からの余白
  public static let yearHolidayLine: CGFloat = 12                  // 祝日名の行の高さ
  public static let yearThinLane: CGFloat = 12                     // これより薄いレーンのチップは「薄い」（タップで日ページ）

  // --- 時間軸の箱（週・日共通） ---
  public static let boxVerticalGap: CGFloat = 1                    // 続けて並ぶ箱の間
  public static let boxMinHeight: CGFloat = 4
  public static let timedMinVisualMinutes = 15                     // 箱の見た目の最小の長さ（分）
  public static let nowLineWidthPoints: CGFloat = 2                // 画面上の太さ（pt。倍率に関係なく一定）
}
```

### 1.2 CellKey の追加（生の文字列は DESIGN §3.4 のとおり）

```swift
extension CellKey {
  public static func allDay(_ d: DayKey) -> CellKey           // 週の終日帯のマス: "allday:2026-10-04"
  public static let allDayDay = CellKey(raw: "allday")       // 日の終日帯（1 マス）
  public static let grid = CellKey(raw: "grid")              // 週・日の時間軸（左の時刻帯と日のメモ欄も含む 1 マス）
  public static func yearDay(month: Int, day: Int) -> CellKey   // 年のマス: "MM-DD"（0 詰め。"02-30" のような存在しない日も可）
  public var allDayDate: DayKey?            // "allday:YYYY-MM-DD" のときだけ非 nil
  public var yearMonthDay: (month: Int, day: Int)?   // "MM-DD" のときだけ非 nil（month 1…12, day 1…31）
  public var isGrid: Bool
  public var isAllDayDay: Bool
  // 既存: day(_:) "YYYY-MM-DD", memo "memo", var day: DayKey?, isMemo
}
```

`yearDay(month:day:)` は `month` 1…12・`day` 1…31 だけを受け付けます（範囲外は `precondition`）。`day` 計算プロパティは "MM-DD" や "allday:…" に対して nil のまま（`DayKey(ymd:)` が 3 要素しか受けないため）。JSON の書式は M2 と同じ（生の文字列）で、**保存形式は変えません**。

### 1.3 ページの共通プロトコル

```swift
public enum PageKind: String, CaseIterable, Codable, Sendable { case day, week, month, year }

/// スクロール補正の基準になる縦の帯。月: "row:0"…"row:5", "memo"／週・日: "allday", "grid"／年: "row:1"…"row:31"
public struct PageBand: Hashable, Sendable { public let raw: String; public init(raw: String) }

/// 1 ページの幾何（紙座標 lu）。担当 I は `any PageLayout` としてだけ使う。
public protocol PageLayout: Sendable {
  var kind: PageKind { get }
  var pageId: String { get }                       // "d-2026-10-04" / "w-2026-09-28" / "m1-2026-10" / "y-2026"
  var size: CGSize { get }
  var cells: [CellKey: CGRect] { get }             // 手書きを紐付けるマスの矩形（全て）
  var dateLabels: [DateLabel] { get }
  var allDayBars: [AllDayBar] { get }              // 年は空（年は YearPageLayout.chips）
  var timedBoxes: [TimedEventBox] { get }          // 週・日だけ。他は空
  var nowLine: NowLine? { get }                    // 週・日で今日が見えているときだけ。他は nil
  func cell(at point: CGPoint) -> CellKey?         // 点が入っているマス。どのマスにも入らなければ nil（ページ外も nil）
  func inkCell(forCenter point: CGPoint) -> CellKey   // 線の外接矩形の中心 → 所属マス。必ず返す（§1.10 の後始末）
  func growsWithInk(_ cell: CellKey) -> Bool       // 手書きで伸びるマスか（§1.10）
  func hit(at point: CGPoint) -> HitTarget?        // 指タップの当たり判定
  func band(atY y: CGFloat) -> PageBand?           // y が入っている帯（ページ外は nil）
  func bandTop(_ band: PageBand) -> CGFloat?       // 帯の上端 y（無い帯は nil）
}

extension PageLayout {
  /// kind・pageId・size・cells が同じなら true（担当 I が「合成し直しが要るか」の判定に使う）
  public func sameGeometry(as other: any PageLayout) -> Bool
}

public enum PageScroll {
  /// DESIGN §3.5 の補正を全ページに一般化: old で topVisibleY を含む帯が new で動いた量。
  /// `old.band(atY:)` が nil（紙の外）なら 0。帯が new に無ければ 0。
  public static func scrollDelta(old: any PageLayout, new: any PageLayout, topVisibleY: CGFloat) -> CGFloat
}
```

- プロトコルは **`Equatable` を継承しません**（`any PageLayout` のまま比較できないため）。具体型（`MonthPageLayout` など 4 つ）は `Equatable` です。担当 U の `PaperContent` は具体型を持つので `==` できます。
- `cell(at:)` の境界: 半開区間、紙の右端 `x == 幅` は最後の列、下端 `y == 高さ` は外（M2 の月と同じ）。
- 当たり判定の優先順位はページごとに §1.5〜1.8 に書きます。

### 1.4 共通部品

```swift
public enum HitTarget: Equatable, Sendable {
  case allDayBar(String)      // 月の帯・週/日の帯・年のチップ（eventId）
  case timedChip(String)      // 月のチップ
  case timedBox(String)       // 週・日の時間軸の箱（新規）
  case moreChips(DayKey)      // 月の「+n件」
  case date(DayKey)           // 月の日付の数字、年の曜日の字と薄いチップ → 日ページへ
}

/// 現在時刻の赤線（週・日）。y は紙座標（終日帯の高さを足してある）。x0〜x1 は今日の列（週）／時間軸の列（日）。
public struct NowLine: Equatable, Sendable { public var y: CGFloat; public var x0: CGFloat; public var x1: CGFloat; public var minute: Int }

/// 時間軸に置く時間指定の箱（Web 版 createEventBox ＋ timedBoxRect）。
public struct TimedEventBox: Equatable, Sendable {
  public var eventId: String
  public var frame: CGRect          // 紙座標（grid の上端を足してある）
  public var day: DayKey            // どの列（日）か
  public var startMinute: Int       // 見た目の分（0…1440、その日に切り詰め、最短 15 分）
  public var endMinute: Int
  public var column: Int            // 重なりの列（0 始まり）
  public var columns: Int           // その塊が使う列数
  public var title: String
  public var timeText: String       // "9:00〜10:30"（予定の本当の開始〜終了。Web 版 formatTimeRangeJa）
  public var startText: String      // "9:00"（1 行表示用。Web 版 formatTimeJa）
  public var colorHex: String
  public var isPast: Bool           // event.end <= now（薄く描く）
}

/// Web 版 layoutTimedEvents の 1 行分。
public struct TimedSlot: Equatable, Sendable { public var event: LayoutEvent; public var startMinute: Int; public var endMinute: Int; public var column: Int; public var columns: Int }

public enum TimedEventEngine {
  /// `day` に重なる時間指定（allDay でない）予定を、見た目の分に直し、重なりごとに列へ詰める（Web 版 layoutTimedEvents と同じ規則、§1.4 細則）。
  public static func layout(events: [LayoutEvent], day: DayKey, calendar: Calendar = DayKey.deviceCalendar) -> [TimedSlot]
  /// 壁時計の分（時×60＋分。DST の日もグリッドと一致）
  public static func minutesOfDay(_ date: Date, calendar: Calendar = DayKey.deviceCalendar) -> Int
  /// その日の見た目の [start, end]（Web 版 visualMinutes）
  public static func visualMinutes(of event: LayoutEvent, day: DayKey, calendar: Calendar = DayKey.deviceCalendar) -> (start: Int, end: Int)
  /// 箱の矩形（Web 版 timedBoxRect）。y は 0:00 を 0 とした列内の座標（呼び手が grid の上端を足す）。
  public static func boxFrame(columnX: CGFloat, columnWidth: CGFloat, startMinute: Int, endMinute: Int, column: Int, columns: Int,
                              hourHeight: CGFloat, padLeft: CGFloat, padRight: CGFloat, gap: CGFloat, verticalGap: CGFloat = PaperSpec.boxVerticalGap) -> CGRect
  public static func timeText(_ date: Date, calendar: Calendar = DayKey.deviceCalendar) -> String          // "9:00"（= MonthLayoutEngine.formatTime）
  public static func timeRangeText(start: Date, end: Date, calendar: Calendar = DayKey.deviceCalendar) -> String   // "9:00〜10:30"
}

/// レーンの間引き（Web 版 month-view.js allDayLaneMetrics）。上限に達したときだけ使う。
public struct LaneMetrics: Equatable, Sendable { public var lane: CGFloat; public var step: CGFloat; public var gap: CGFloat; public var fontScale: CGFloat }
public enum LanePacking {
  /// laneCount 本のレーン（高さ lane、隙間 gap）が available に収まらないときは step = (available + gap) / laneCount に縮め、
  /// step < 3×gap なら gap = step/3 として step = available / (laneCount − 1/3)。収まるときはそのまま。fontScale = min(1, lane/元の lane)。
  public static func metrics(laneCount: Int, lane: CGFloat, gap: CGFloat, available: CGFloat) -> LaneMetrics
}
```

細則（`TimedEventEngine.layout`、Web 版 `event-layout.js` と同じ）
- 対象: `!allDay` で `[dayStart, dayEnd)` に重なるもの（`LayoutEvent.overlaps`）。終日の予定は時間軸に出しません（長い時間指定は出します。24 時間を超える時間指定は各日の時間軸に切って出す）。
- 見た目の分: start ≤ dayStart なら 0、それ以外は `minutesOfDay(start)`。end ≥ dayEnd なら 1440、end ≤ start なら start と同じ、それ以外は `minutesOfDay(end)`。`end = max(end, start)`。15 分未満なら `end = min(1440, start + 15)`、`start = min(start, end − 15)`。
- 並び: startMinute 昇順 → endMinute 降順（長いもの先）→ 本当の start 昇順 → 題名（Unicode の `<`、M2 と同じ）→ id。
- 列詰め: 並び順に見て、`startMinute >= 塊の最大 endMinute` なら新しい塊。各項目は `endMinute <= startMinute` の最初の列（無ければ新しい列）。塊が閉じたら `columns = 列数` を塊の全項目に書く。
- 結果は並び順のまま返す。
- `boxFrame`: `inner = max(1, columnWidth − padLeft − padRight)`、`g = inner / columns ≥ gap×4 ? gap : 0`、`w = max(1, (inner − g×(columns−1)) / columns)`、`x = columnX + padLeft + column×(w + g)`、`y = startMinute×hourHeight/60 + verticalGap`、`h = max(boxMinHeight, (endMinute − startMinute)×hourHeight/60 − verticalGap×2)`。

### 1.5 月（既存の `MonthPageLayout` を適合させる。公開 API は維持）

```swift
extension MonthPageLayout: PageLayout {
  public var kind: PageKind { .month }
  public var month: YearMonth              // rows[0].days[6]（グリッド 7 日目は必ずその月）から計算（init は変えない）
  public var pageId: String                // month.inkPageId = "m1-2026-10"
  public var timedBoxes: [TimedEventBox]   // []
  public var nowLine: NowLine?             // nil
  public func inkCell(forCenter point: CGPoint) -> CellKey   // M2 の InkLedger.cellFor と同じ: cell(at:) → 紙の中に clamp して cell(at:) → .memo
  public func growsWithInk(_ cell: CellKey) -> Bool          // 42 日と memo は true（それ以外は false）
  public func band(atY y: CGFloat) -> PageBand?              // "row:r" / "memo" / nil
  public func bandTop(_ band: PageBand) -> CGFloat?
}
extension MonthLayoutEngine {
  // 既存の scrollDelta(old:new:topVisibleY:) は残し、中身は PageScroll.scrollDelta に委譲（結果は M2 と同じ）
}
```

`MonthLayoutInput`・`MonthLayoutEngine.layout`・`RowLayout`・`AllDayBar`・`TimedChip`・`DateLabel`・`DayTone` は **変更しません**。`HitTarget` に `.timedBox` が増えるので、月の `hit(at:)` は変わらないが、呼び手（担当 U）の `switch` は網羅し直す。

### 1.6 週

```swift
public struct WeekLayoutInput: Sendable {
  public var monday: DayKey                 // 週の月曜（init が focus から正規化する）
  public var events: [LayoutEvent]
  public var inkBottoms: [CellKey: CGFloat]
  public var now: Date
  public var calendar: Calendar
  public init(focus: DayKey, events: [LayoutEvent], inkBottoms: [CellKey: CGFloat], now: Date, calendar: Calendar = DayKey.deviceCalendar)
}

public struct WeekPageLayout: PageLayout, Equatable, Sendable {
  public var pageId: String                 // "w-2026-09-28"（月曜）
  public var days: [DayKey]                 // 7 日、月曜始まり
  public var size: CGSize                   // 1400 × (band.height + 1920)
  public var band: CGRect                   // 終日帯 (0, 0, 1400, bandH)
  public var grid: CGRect                   // 時間軸 (0, bandH, 1400, 1920)
  public var laneCount: Int
  public var laneMetrics: LaneMetrics       // 上限に達していなければ lane 22, step 25, gap 3, fontScale 1
  public var cells: [CellKey: CGRect]       // 7 つの .allDay(day) ＋ .grid（計 8）
  public var allDayBars: [AllDayBar]        // row は常に 0
  public var timedBoxes: [TimedEventBox]
  public var dateLabels: [DateLabel]        // 7 つ。frame は (列の x, 0, 列幅, 0) の高さ 0（紙の上ではタップ不可。固定見出しが担当 U）
  public var nowLine: NowLine?
  public var todayColumn: Int?
  public func columnFrame(_ col: Int) -> CGRect          // (64 + col×190.857…, grid.minY, 190.857…, 1920)
  public func column(atX x: CGFloat) -> Int?             // x < 64 または x > 1400 は nil。x == 1400 は 6（Web 版 xToColumn）
  public func minutesToY(_ minutes: Int) -> CGFloat      // grid.minY + minutes × 80 / 60
  // PageLayout: kind .week, cell(at:), inkCell(forCenter:), growsWithInk, hit(at:), band(atY:), bandTop
}

public enum WeekLayoutEngine {
  public static func layout(_ input: WeekLayoutInput) -> WeekPageLayout
  /// 終日帯の高さ: min(800, max(60, lanes×25 + 30, inkBottom + 12))（DESIGN §2.2 の週の列）
  public static func bandHeight(laneCount: Int, inkBottom: CGFloat) -> CGFloat
}
```

細則
- 終日レーン: `MonthLayoutEngine.packAllDayLanes(events:days:calendar:)` をそのまま使う（7 日）。帯の `frame`: `x = 64 + startCol×colW + 3`（`continuesLeft` なら +0）、`幅 = (endCol−startCol+1)×colW − 左右の inset`（続く側は 0）、`y = 3 + lane×step`、`高さ = laneMetrics.lane`。`continuesLeft/Right` は M2 と同じ規則（月曜 0 時より前に始まる／日曜の翌 0 時より後に終わる）。
- `inkBottom` は 7 つの `.allDay(day)` の最大。`.grid` の inkBottoms は **無視**（時間軸は伸びない）。
- 上限（lanes×25 + 30 > 800）に達したときだけ `LanePacking.metrics(laneCount:, lane: 22, gap: 3, available: 800 − 3 − 30)` で間引く。
- 時間指定: 列 i（0…6）ごとに `TimedEventEngine.layout(events, days[i])` → `boxFrame(columnX: 64 + i×colW, columnWidth: colW, …, hourHeight: 80, padLeft: 2, padRight: 6, gap: 2)` の y に `grid.minY` を足す。`isPast = event.end <= now`。
- `nowLine`: `days` に `DayKey(now)` があるときだけ。`y = grid.minY + minutesOfDay(now)×80/60`、`x0…x1` = 今日の列。
- `dateLabels`: `isToday`・`tone`（日曜・祝日は red、土曜は blue）・`holidayName`、`inMonth` は true。
- `cells`: `.allDay(days[i])` = `(64 + i×colW, 0, colW, bandH)`、`.grid` = `(0, bandH, 1400, 1920)`。帯の左 64 lu（時刻帯の上）はどのマスにも入らない。
- `cell(at:)`: 帯の中で x ≥ 64 → その列の `.allDay`、grid の中（x 0…1400、y bandH ≤ y < 高さ）→ `.grid`、それ以外 nil。
- `inkCell(forCenter:)`: `y < bandH`（y < 0 も含む）→ 列 = `clamp(floor((x−64)/colW), 0, 6)` の `.allDay`（帯の左の時刻帯や紙の外は月曜の帯に属し、x が負になる。DESIGN §3.4 の年の規則と同じ）；それ以外 → `.grid`。
- `growsWithInk`: 7 つの `.allDay` だけ true。
- `hit(at:)`: 箱（`.timedBox(id)`）→ 帯（`.allDayBar(id)`）→ nil。`dateLabels` は高さ 0 なので当たらない。
- `band(atY:)`: `y < bandH` → "allday"、`bandH ≤ y < 高さ` → "grid"、外は nil。

### 1.7 日

```swift
public struct DayLayoutInput: Sendable {
  public var day: DayKey; public var events: [LayoutEvent]; public var inkBottoms: [CellKey: CGFloat]; public var now: Date; public var calendar: Calendar
  public init(day: DayKey, events: [LayoutEvent], inkBottoms: [CellKey: CGFloat], now: Date, calendar: Calendar = DayKey.deviceCalendar)
}

public struct DayPageLayout: PageLayout, Equatable, Sendable {
  public var pageId: String                 // "d-2026-10-04"
  public var day: DayKey
  public var size: CGSize                   // 1000 × (band.height + 2400)
  public var band: CGRect                   // (0, 0, 1000, bandH)
  public var grid: CGRect                   // (0, bandH, 1000, 2400)
  public var timeline: CGRect               // (72, bandH, 588, 2400)
  public var memo: CGRect                   // (660, bandH, 340, 2400)
  public var laneCount: Int
  public var laneMetrics: LaneMetrics       // 通常 lane 22, step 24, gap 2
  public var cells: [CellKey: CGRect]       // .allDayDay ＋ .grid（計 2）
  public var allDayBars: [AllDayBar]        // row 0、lane = 並び順
  public var timedBoxes: [TimedEventBox]
  public var dateLabels: [DateLabel]        // 1 つ、frame は (72, 0, 588, 0)
  public var nowLine: NowLine?
  public var isToday: Bool
  public func minutesToY(_ minutes: Int) -> CGFloat      // grid.minY + minutes × 100 / 60
}

public enum DayLayoutEngine {
  public static func layout(_ input: DayLayoutInput) -> DayPageLayout
  /// min(800, max(60, lanes×24 + 30, inkBottom + 12))
  public static func bandHeight(laneCount: Int, inkBottom: CGFloat) -> CGFloat
}
```

細則
- 終日: `packAllDayLanes(events, [day])`（1 日なので lane = 並び順。Web 版 `eventsOnDay` と同じ順）。チップの `frame` = `(72 + 4, 2 + lane×24, 588 − 4 − 12, laneMetrics.lane)`。`continuesLeft` = その日の 0 時より前に始まる、`continuesRight` = 翌 0 時より後に終わる。
- 帯は幅いっぱい 1 マス（`.allDayDay` = `(0, 0, 1000, bandH)`）。チップは時間軸の列の中にだけ置き、右のメモ欄の幅（660〜1000）は帯の中でも手書き用に空ける。左の時刻帯（0〜72）には担当 U が「終日」のラベルを描く。
- `inkBottom` は `.allDayDay` のもの。`.grid` は無視。
- 時間指定: `TimedEventEngine.layout(events, day)` → `boxFrame(columnX: 72, columnWidth: 588, …, hourHeight: 100, padLeft: 4, padRight: 14, gap: 3)` ＋ `grid.minY`。
- `nowLine`: `day == DayKey(now)` のとき。`x0 = 72, x1 = 660`。
- `cell(at:)`: 帯 → `.allDayDay`、grid → `.grid`、外は nil。`inkCell(forCenter:)`: `y < bandH` → `.allDayDay`、それ以外 → `.grid`。`growsWithInk`: `.allDayDay` だけ。
- `hit(at:)`: 箱 → 帯（チップ）→ nil。`band(atY:)`: "allday" / "grid"。

### 1.8 年

```swift
public struct YearLayoutInput: Sendable {
  public var year: Int; public var events: [LayoutEvent]; public var inkBottoms: [CellKey: CGFloat]; public var now: Date; public var calendar: Calendar
  public init(year: Int, events: [LayoutEvent], inkBottoms: [CellKey: CGFloat], now: Date, calendar: Calendar = DayKey.deviceCalendar)
}

/// 年ページの 1 行（日付 d の行。12 か月の中で一番多いマスに合わせて伸びる）
public struct YearRow: Equatable, Sendable { public var dayNumber: Int /* 1…31 */; public var frame: CGRect /* (0, y, 1400, h) */; public var laneCount: Int /* 12 か月の max */ }

/// 年ページのチップ（複数日の予定は、またがる各日に 1 つずつ。同じ月の列の中では同じレーン）
public struct YearChip: Equatable, Sendable {
  public var eventId: String
  public var frame: CGRect
  public var day: DayKey
  public var lane: Int
  public var continuesUp: Bool              // その日の 0 時より前に始まる（上の角を角張らせる）
  public var continuesDown: Bool            // 翌 0 時より後に終わる（下の角を角張らせる）
  public var linkToY: CGFloat?              // 同じ月の翌日にも続くとき: 翌日のチップの上端 y（色の帯でつなぐ。月末なら nil）
  public var title: String
  public var colorHex: String
  public var isThin: Bool                   // laneMetrics.lane < yearThinLane（12）。薄いチップはタップで日ページ
  public var fontScale: CGFloat
}

public struct YearPageLayout: PageLayout, Equatable, Sendable {
  public var pageId: String                 // "y-2026"
  public var year: Int
  public var size: CGSize                   // 1400 × Σ rows[i].frame.height
  public var rows: [YearRow]                // 31
  public var cells: [CellKey: CGRect]       // 12×31 = 372（存在しない日も含む）
  public var invalidCells: [CellKey]        // 2/30, 4/31 … と平年の 2/29（斜線で描く）
  public var chips: [YearChip]
  public var dateLabels: [DateLabel]        // 存在する日だけ（365/366）。frame はタップ用 (cellX, cellY, 40, 28)（曜日の字はその左上 (x+3, y+3) に描く）
  public var allDayBars: [AllDayBar]        // []
  public var timedBoxes: [TimedEventBox]    // []
  public var nowLine: NowLine?              // nil
  public var todayCell: CellKey?
  public func columnFrame(month: Int) -> CGRect           // month 1…12: (56 + (month−1)×112, 0, 112, 高さ)
  public func cellFrame(month: Int, day: Int) -> CGRect?  // 1…12 × 1…31
  public func row(atY y: CGFloat) -> Int?                 // 日付 1…31、外は nil
}

public enum YearLayoutEngine {
  public static func layout(_ input: YearLayoutInput) -> YearPageLayout
  /// min(400, max(60, 16 + lanes×18 + 8, inkBottom + 12))
  public static func rowHeight(laneCount: Int, inkBottom: CGFloat) -> CGFloat
  /// 月 m（1…12）の列のレーン詰め: packAllDayLanes(events, その月の全日)。テスト用に公開。
  public static func monthSpans(events: [LayoutEvent], year: Int, month: Int, calendar: Calendar) -> [(event: LayoutEvent, startCol: Int, endCol: Int, lane: Int)]
}
```

細則
- 列: 月 m の列は `x = 56 + (m−1)×112`、幅 112。行: 日付 d の行の `frame.y` は前の行までの合計、高さは `rowHeight(laneCount: 12 か月のうち最大の needed(m, d), inkBottom: 12 マスの inkBottoms の最大)`。
- `needed(m, d)` = その月のレーン詰め（`monthSpans`）で日付 d を含む span の `lane + 1` の最大（無ければ 0）。同じ予定は同じ月の中では同じレーン（複数日の予定が日をまたいでも横にずれない）。
- チップの `frame`: `x = cellX + 112×0.45`（= cellX + 50.4）、`幅 = 112×0.55 − 3`（= 58.6）、`y = cellY + 16 + lane×laneMetrics.step`、`高さ = laneMetrics.lane`。`laneMetrics` は行が上限 400 に達した（16 + lanes×18 + 8 > 400）ときだけ `LanePacking.metrics(laneCount: needed(m, d), lane: 16, gap: 2, available: 400 − 16 − 8)`、それ以外は lane 16 / step 18 / gap 2 / fontScale 1。間引きはマスごと（同じ行の他の月は影響を受けない）。
- `continuesUp` = `event.start < その日の 0 時`、`continuesDown` = `event.end > 翌 0 時`。`linkToY` は `continuesDown` かつ `d < その月の日数` のとき翌日のチップの `frame.minY`。
- 時間指定の予定は年ページに出しません（DESIGN §2.6）。
- `dateLabels`: `isToday`、`tone`（日曜・祝日 red、土曜 blue）、`holidayName`、`inMonth` true。曜日の字は担当 U が `day.weekday` から描く（`["日","月","火","水","木","金","土"]`）。
- `cells`: `.yearDay(month: m, day: d)` = `(56 + (m−1)×112, rows[d−1].frame.minY, 112, rows[d−1].frame.height)`。存在しない日も `cells` に入れる（DESIGN §3.4「存在しない 2/30 にも書ける」）。
- `cell(at:)`: `56 ≤ x ≤ 1400`、`0 ≤ y < 高さ` のとき `(min(11, floor((x−56)/112)) + 1, row(atY:))`。左の日付帯（x < 56）と紙の外は nil。
- `inkCell(forCenter:)`: 月 = `clamp(floor((x−56)/112), 0, 11) + 1`（日付帯と左の外は 1 月、右の外は 12 月）、日 = `row(atY: clamp(y, 0, 高さ − 0.001))`（上の外は 1、下の外は 31）。DESIGN §3.4「左の日付帯は 1 月の列に属する（x が負になる）」。
- `growsWithInk`: 372 マス全て true。
- `hit(at:)`: チップ（`isThin` なら `.date(day)`、それ以外 `.allDayBar(eventId)`）→ 曜日の字の `dateLabels.frame`（`.date(day)`）→ nil。
- `band(atY:)`: "row:d"。

### 1.9 ページの id・範囲・移動・題名・初期スクロール

```swift
public enum PageNavigation {
  /// "d-2026-10-04" / "w-2026-09-28"（focus を含む週の月曜）/ "m1-2026-10" / "y-2026"（Web 版 pageIdFor と同じ文字列）
  public static func pageId(_ kind: PageKind, focus: DayKey) -> String
  /// focus を含む週の月曜（= MonthLayout.mondayOnOrBefore）
  public static func mondayOnOrBefore(_ day: DayKey) -> DayKey
  /// ページに出る日の範囲（end は排他）: 日 1 日／週 月曜から 7 日／月 グリッドの 42 日／年 1/1 から翌年 1/1
  public static func dayRange(_ kind: PageKind, focus: DayKey) -> (start: DayKey, end: DayKey)
  /// ◀ ▶ の移動（Web 版 navigate）: 日 ±1 日／週 ±7 日（同じ曜日）／月 ±1 か月（その月の 1 日）／年 ±1 年（1 月 1 日）。delta 0 は月なら 1 日、年なら 1/1 に正規化
  public static func move(_ kind: PageKind, focus: DayKey, by delta: Int) -> DayKey
  /// ヘッダーの題名（DESIGN §2.7）: 日「2026年10月4日(日) 体育の日」（祝日名は半角空白で続ける。無ければ付けない）／
  /// 週「2026年9月28日〜10月4日」（年をまたぐ週は「2026年12月28日〜2027年1月3日」。同じ月でも月は両側に書く: 「2026年10月5日〜10月11日」）／
  /// 月「2026年10月」／年「2026年」
  public static func title(_ kind: PageKind, focus: DayKey) -> String
  /// 初めて表示するときのスクロール位置（紙座標 y。倍率は呼び手が掛け、はみ出しは呼び手が clamp する）:
  /// 週・日: grid.minY + minutes×hourH/60、minutes = 今日が見えていれば clamp(now の分 − 60, 0, 1440)、それ以外 7×60／
  /// 年: 今日がその年なら rows[max(0, today.day − 3)].frame.minY（今日の行の 2 行上）、それ以外 0／月: 0
  public static func initialScrollY(_ layout: any PageLayout, now: Date, calendar: Calendar = DayKey.deviceCalendar) -> CGFloat
}
```

### 1.10 inkBottoms の意味（マスの種類ごと）

| ページ | 伸びるマス（`growsWithInk` true。engine が inkBottoms を読む） | 伸びないマス（inkBottoms は読まれない） |
| --- | --- | --- |
| 月 | 42 日のマス（行の高さ）、`memo`（メモ欄の高さ） | — |
| 週 | `allday:YYYY-MM-DD` × 7（帯の高さ。7 つの最大） | `grid`（1920 固定） |
| 日 | `allday`（帯の高さ） | `grid`（2400 固定） |
| 年 | `MM-DD` × 372（行の高さ。同じ日付の 12 マスの最大） | — |

伸びる量は M2 と同じ `inkBottom + inkPad(12)`（月のメモ欄だけ +50）。上限（月 1200、週・日の帯 800、年 400）を超えた手書きは、はみ出して隣に重なる（紙だから。DESIGN §2.2）。`InkPage.inkBottoms()` は変えない（全マスを返す）。

## 2. Ink（担当 I）

### 2.1 InkLedger

```swift
@MainActor final class InkLedger {
  init(page: InkPage, layout: any PageLayout, deviceId: String? = nil)
  private(set) var page: InkPage
  private(set) var layout: any PageLayout
  func drawing() -> PKDrawing                                // 変更なし（cells[stroke.cell] が無い線は描かない・消したとも見なさない）
  func bind(to canvasDrawing: PKDrawing)                     // 変更なし
  func relayout(_ layout: any PageLayout) -> PKDrawing       // 一般化
  func applyCanvasChange(_ drawing: PKDrawing) -> InkChange  // 新しい線の所属マスは layout.inkCell(forCenter: 外接矩形の中心)
  func needsMoreRoom(_ stroke: InkStroke) -> Bool            // layout.growsWithInk(cell) が false なら常に false
  func reload(page: InkPage, keepHistory: Bool)              // 変更なし
  func undo() -> PKDrawing?; func redo() -> PKDrawing?; var canUndo: Bool; var canRedo: Bool
}
```

- `cellFor(bounds:)`（M2 の私的関数）は `layout.inkCell(forCenter:)` に置き換える。後始末（紙の外・時刻帯・年の日付帯）の規則は §1.6〜1.8 のとおり Layout が持つ。
- `needsMoreRoom`: `pad = cell.isMemo ? memoInkPad : inkPad`、`growsWithInk(cell)` が false なら false（`grid` に書いても再レイアウトしない）。
- **台帳はページを混ぜない**: `reload(page:keepHistory:)` に `page.pageId != layout.pageId` の組が来たら `assertionFailure` し、何もしない（Release では無視）。`relayout(_:)` に `layout.pageId != page.pageId` の layout が来たときも同じ。

### 2.2 InkCanvasView

```swift
struct InkCanvasView: UIViewRepresentable {
  var layout: any PageLayout
  var paper: PaperContent                       // 担当 U（§3.1）。I は == と PaperView(content:) にしか使わない
  var tool: CanvasTool
  var allowFinger: Bool
  @Binding var page: InkPage
  var initialScrollY: CGFloat                   // 紙座標。最初の倍率が決まった直後に 1 回だけ適用（× zoom、clamp）
  var onTap: (CGPoint) -> Void
  var onInkBoundsChanged: () -> Void
  var undoTrigger: Int; var redoTrigger: Int
  var onPencilToggle: () -> Void = {}
  var onHistoryChanged: (_ canUndo: Bool, _ canRedo: Bool) -> Void = { _, _ in }
}
```

細則
- **ページが変わるときはキャンバスを作り直す**: 担当 U が `InkCanvasView(...).id(layout.pageId)` を付ける（M2 の `.id(month)` の一般化）。Coordinator・台帳・PKCanvasView はページごとに新しくなり、台帳がページを混ぜる余地を無くす。DESIGN §3.10「1 枚を使い回す」は M3b 以降の最適化。
- それでも同じキャンバスに別の pageId の `page` や `layout` が来たら（SwiftUI の更新順の都合で一瞬ありうる）: `update(from:)` は `newParent.page.pageId == newParent.layout.pageId` でないあいだは **何もしない**（drawing を触らない・書き戻さない）。両方が揃った更新で `reload(page:keepHistory: false)` → `pendingDrawing` → `resetScroll`（この場合は `initialScrollY` へ）。
- 倍率: `minimumZoomScale = 画面幅 / layout.size.width`（**`PaperSpec.monthWidth` 固定をやめる**。日ページは幅 1000）、最大はその 4 倍。向きが変わったときの再計算は M2 と同じ。
- 初期スクロール: `containerDidLayout` の最初の 1 回で `contentOffset = clamp((0, initialScrollY × fit))`（M2 は `.zero`）。
- スクロール補正: `PageScroll.scrollDelta(old:new:topVisibleY:)`。幾何の変化判定は `oldLayout.sameGeometry(as: newLayout)`。紙の内容（`paper`）だけの変化（現在時刻の線が動いた、`isPast` が変わった）は drawing を触らず `paperView.content` だけ差し替える（M2 の `pendingPaper` の経路）。
- 指タップ・ペンの状態・300 ms 待ち・undo/redo・`onHistoryChanged`・`onInkBoundsChanged` は M2 のまま。
- `Ink/InkLedger.swift` は引き続き UIKit を import しない（この Mac で `swiftc -parse` できるように）。

## 3. 紙（担当 U, `Paper/*`）

### 3.1 PaperContent と PaperView

```swift
enum PaperContent: Equatable {
  case month(MonthPaperContent)      // = M2 の PaperContent（layout, labels, bars, chips, holidayNames）を改名したもの
  case week(WeekPaperContent)        // struct WeekPaperContent: Equatable { var layout: WeekPageLayout }
  case day(DayPaperContent)          // struct DayPaperContent: Equatable { var layout: DayPageLayout }
  case year(YearPaperContent)        // struct YearPaperContent: Equatable { var layout: YearPageLayout; var monthNames: [String] /* "1月"… */ }
  var size: CGSize                   // layout.size
  var kind: PageKind
}

@MainActor final class PaperView: UIView {
  init(content: PaperContent, zoomScale: CGFloat = 1)      // M2 と同じ呼び方（担当 I はこの 1 行だけを前提にする）
  var content: PaperContent { didSet { setNeedsDisplay() } }
  var zoomScale: CGFloat
}
```

`PaperView.draw(_:)` は `content` の種類で `MonthPaper` / `WeekPaper` / `DayPaper` / `YearPaper`（それぞれ `enum ...: PaperRenderer`、`static func draw(_ content, in ctx: CGContext, dirty: CGRect, zoom: CGFloat, view: PaperView)`）に振り分ける。M2 の描画は `MonthPaper` にそのまま移す（見た目を変えない）。文字の描画・ヘアライン・snap・`fontSize(lu, zoom)` は M2 の `PaperView` の私的関数を `Paper/PaperText.swift`（`enum PaperText`）に出して共用。

### 3.2 色と文字の大きさ（Web 版 views.css / view-common.js TYPE と同じ）

| 名前 | 値 | 使う所 |
| --- | --- | --- |
| paper | #fffdf8 | 紙 |
| line | #e5e7eb | 時間の線（毎時）、週の列の線、年の日の線 |
| lineSoft | #eceef1 | 30 分の線（破線 3 4） |
| lineStrong | #d7dade | 時刻帯の右の線、日のメモ欄の左の線、年の月の線と日付帯の線 |
| rule | #ebe7de | メモ欄の罫線 |
| ink1 / ink2 / ink3 | #1f2937 / #4b5563 / #9ca3af | 本文 / 補助（年の日付・曜日の字）/ 時刻ラベル |
| red / blue / accent | #dc2626 / #2563eb / #2563eb | 日祝 / 土 / 今日 |
| todayTint / todayTintSoft | rgba(37,99,235,.06) / .03 | 週の今日の列 / 日ページの今日の列 |
| weekendTint / weekendTintSoft | rgba(146,118,64,.045) / .03 | 週の土日祝の列 / 日ページ |
| satTint / sunTint / todayTintStrong | rgba(37,99,235,.055) / rgba(220,38,38,.06) / rgba(37,99,235,.15) | 年のマス |
| hatchBg / hatchLine | #f3f2ee / #dcd9d2（幅 2.5、周期 10 lu、45°） | 年の存在しない日 |
| todayRing | accent、1.5 pt、マスの内側 1 lu | 年の今日 |
| nowLine | red、2 pt（倍率に依らない）、左端に丸（半径 max(5 lu, 4 pt)。日は max(6 lu, 4 pt)） | 週・日 |
| 箱（時間指定） | 背景 = 予定色 α .85、左の縁 3 lu 実線 予定色、角丸 6 lu、文字 = `readableText(on:)`（M2）、外枠 1 pt rgba(255,253,248,.9)、`isPast` なら全体 α .75 | 週・日 |
| 帯・チップ（終日） | 背景 = 予定色、文字 = readableText、角丸 4 lu（続く側は角張る）、年は角丸 3 lu（薄いときは 1 lu） | 週・日・年 |
| memoLabel | #a8a29e、semibold、字間 .15em | 「メモ」「終日」 |

| TYPE | lu | 画面上の最小 pt | 使う所 |
| --- | --- | --- | --- |
| weekEvent / dayEvent | 13 / 14 | 10 / 11 | 箱の文字 |
| weekTimeLabel / dayTimeLabel | 12 / 13 | 10 / 10.5 | 時刻帯の "0:00"〜"23:00"（右寄せ、x = gutter − 8、各時の線の 3 lu 下） |
| memoLabel | 14 | 10.5 | 「メモ」「終日」 |
| monthDate / monthChip / monthHoliday | 17 / 12.5 / 11 | 12 / 10 / 9 | 月（M2 のまま） |
| yearDayNum / yearWeekday / yearChip / yearHoliday | 22 / 15 / 13 / 11 | 11 / 9 / 8 / 7.5 | 年 |

`fontSize(lu, zoom) = max(lu, minPt / zoom)`（M2 の式を TYPE ごとの最小値にする）。帯の文字は `laneMetrics.fontScale`（年は `chip.fontScale`）を掛ける。

### 3.3 週ページに描くもの（`WeekPaper`）

1. 紙色で塗る。列の色: 今日の列（`todayColumn`）は todayTint、土日祝の列（`dateLabels[i].tone != .normal`）は weekendTint。帯の中（y < bandH）も時間軸も同じ列の色で塗る（x は列の範囲、y は 0〜高さ）。
2. 終日帯: 帯の下端に lineStrong の横線。左の時刻帯（x < 64）に「終日」を右寄せ（memoLabel の色、帯の上端 +3）。帯（`allDayBars`）を §3.2 の「帯・チップ」で描き、題名を 1 行（省略記号）。
3. 時間軸: 毎時の線（line、h = 1…23、`y = grid.minY + h×80`、x 64〜1400）、30 分の線（lineSoft、破線）、時刻帯の右の線（lineStrong、x = 64、帯を含む全高）、列の線（line、x = 64 + i×colW、i = 1…6、grid の中）。時刻ラベル "0:00"…"23:00"（ink3、weight 500、等幅数字、右寄せ x = 56、各時の線の下）。
4. 箱（`timedBoxes`）: 高さに応じて Web 版 `eventBoxMode` の 3 段階: 30 分未満（`endMinute − startMinute < 30`）は題名だけ 1 行（縦中央）／ 2 行分（行高 1.25 × 字 + 4 lu）に満たなければ「`startText` 題名」の 1 行／それ以外は 1 行目に `timeText`（0.85 倍、α .92）、2 行目から題名（最大 2 行、省略）。内側の余白は 3 lu 上下・6 lu 左右。
5. 現在時刻の線（`nowLine`）: 箱の **上** に描く（最後）。

固定見出し（SwiftUI、§4.3）が曜日・日付・祝日名を持つので、紙には日付を描かない。

### 3.4 日ページに描くもの（`DayPaper`）

1. 紙色。今日なら時間軸の列（x 72〜660、全高）を todayTintSoft、土日祝なら weekendTintSoft。
2. 終日帯: 下端に lineStrong、左に「終日」（右寄せ、x = 66）。チップ（`allDayBars`）は時間軸の列の中（§1.7）。
3. 時間軸: 毎時の線・30 分の線は x 72〜660 だけ。時刻帯の右の線（x = 72、全高）、メモ欄の左の線（lineStrong、x = 660、全高）。時刻ラベルは右寄せ x = 64。
4. メモ欄（x 660〜1000、grid の中）: 罫線（rule）を `grid.minY + 50k`（k = 1, 2, …、y < grid.maxY）に x 680〜980、左上に「メモ」（x = 680、`grid.minY + 6`、月のメモ欄と同じ見た目）。
5. 箱（padLeft 4 / padRight 14 / gap 3 は Layout が済ませてある）と現在時刻の線（x 72〜660）。

### 3.5 年ページに描くもの（`YearPaper`）

1. 紙色。マスの色: 土曜 satTint、日曜・祝日 sunTint、今日 todayTintStrong（＋ todayRing）。存在しない日（`invalidCells`）は hatchBg の上に 45° の斜線（hatchLine）。
2. 線: 日の間の横線（line、各行の上端、d = 2…31、x 0〜1400）、月の間の縦線（lineStrong、x = 56 + m×112、m = 1…11）、日付帯の右の線（lineStrong、x = 56）。
3. 日付帯: 1〜31 を各行の縦中央・x = 28 に中央寄せ（yearDayNum、ink2 semibold 等幅数字。今日の日付は accent bold。今日がその年のときだけ）。
4. 各マス: 曜日の字（yearWeekday、`["日","月","火","水","木","金","土"][day.weekday]`、`dateLabels[i].frame` の左上 +3, +3 に。日祝 red、土 blue、今日 accent 800）。祝日名（yearHoliday、red）は曜日の字の **下**（x = cellX + 3、y = cellY + 17、幅 112×0.45 − 6、省略記号）。チップ（`chips`）は §3.2 の年の見た目、題名 1 行（`fontScale` を掛ける）。`continuesUp/Down` で上下の角を角張らせ、`linkToY` があれば `frame.minX` から幅 max(2 pt, 4 lu) の帯を `frame.maxY` から `linkToY` まで予定色で描く。
5. 月名は紙に描かない（固定見出し、§4.3）。

### 3.6 月ページ

M2 の `PaperView` の描画をそのまま `MonthPaper` に移す。見た目の変更はしない。

## 4. 画面とナビゲーション（担当 U）

### 4.1 CalendarRootScreen（`Views/CalendarRootScreen.swift`。M2 の `MonthPageScreen` を置き換える）

```swift
struct CalendarRootScreen: View {
  @State private var kind: PageKind          // 最後に見ていた表示（UserDefaults "lastPageKind"、無ければ .month）
  @State private var focus: DayKey           // 最後に見ていた日（UserDefaults "lastFocusDate" = "YYYY-MM-DD"、無ければ今日）
  @State private var page: InkPage
  @State private var layout: any PageLayout
  // tool / lastInkTool / undoTrigger / redoTrigger / canUndo / canRedo / allowFinger / onboarding / detail / saveTask / pageDirty / saveError / appeared は M2 のまま
}
```

- `var pageId: String { PageNavigation.pageId(kind, focus: focus) }`。
- 流れ（M2 §6 の一般化）: `(kind, focus)` が決まる → `saveNow()` → `page = store.load(pageId)`（スクリーンショットモードは `ScreenshotMode.demoPage(kind:focus:)`）→ `model.load(kind: kind, focus: focus)` → `layout = makeLayout()` → `InkCanvasView(...).id(pageId)`。
- `makeLayout()`: `kind` で `MonthLayoutEngine` / `WeekLayoutEngine` / `DayLayoutEngine` / `YearLayoutEngine` を呼ぶ。`now = ScreenshotMode.current?.today ?? Date()`、`inkBottoms = page.inkBottoms()`、`events = model.events`。
- `paperContent`: `kind` に応じた `PaperContent` の case。年は `monthNames = ["1月", …, "12月"]`。
- `initialScrollY`: `PageNavigation.initialScrollY(layout, now:)` をキャンバス生成時に渡す（`.id(pageId)` で作り直されるたびに効く）。
- 保存: `page` が変わったら 1.5 秒デバウンスで `InkPageStore.save`（M2）。**ページを変える前**（◀ 今日 ▶・切替・タップ移動のすべて）と、バックグラウンドへ行くときに `saveNow()`。`pageBinding` の setter は `newValue.pageId == pageId` でないものを捨てる（M2）。
- `kind`・`focus` が変わるたびに UserDefaults に書く。
- 現在時刻の線: `kind` が週または日で、今日がそのページにあるあいだ、30 秒ごとに `relayout()`（`now` だけが変わる。幾何は変わらないので担当 I の紙だけの更新経路に乗る）。日付が変わったら（`DayKey(now)` が前回と違う）どのページでも `relayout()`（今日の印が移る）。前面復帰（`.active`）でも `relayout()`。
- ページごとの倍率・スクロール位置の記憶は **任意**（やるならメモリ内 `[pageId: (zoom, offset)]`、保存しない。M3a では「初期スクロール＋幅ぴったり」で可）。

### 4.2 ヘッダー（`Views/PageHeaderView.swift`）

```
◀  今日  ▶   題名                          [日 | 週 | 月 | 年]   📅
```

- ◀ ▶: `focus = PageNavigation.move(kind, focus: focus, by: ∓1)`。accessibilityLabel は kind ごとに「前の日／前の週／前の月／前の年」「次の日／次の週／次の月／次の年」。
- 今日: `focus = DayKey(now)`（kind は変えない）。
- 題名: `PageNavigation.title(kind, focus:)`。
- 切替: `Picker` の `.segmented`、表示は「日」「週」「月」「年」、各項目の accessibilityLabel は「日表示」「週表示」「月表示」「年表示」、Picker 全体は「表示の切替」。切替で `focus` は変えない（週→日なら focus の日、年→月なら focus の月）。
- 📅（表示するカレンダーのメニュー）と許可の案内行（`accessNotice`）は M2 のまま。

### 4.3 固定見出し（`Views/StickyHeaderView.swift`。紙の上に重ならず、キャンバスの上に置く。手書き不可。列は幅ぴったりの倍率で紙と一致）

| kind | 内容 | タップ |
| --- | --- | --- |
| 月 | 月〜日の 7 列（M2 の `weekdayRow` そのまま） | なし |
| 週 | 左に 64/1400 の空き、7 列: 曜日（12 pt、ink2）＋日付の数字（18 pt semibold、月の 1 日は "10/1"、今日は accent の丸 30 pt に白字）、下に祝日名（10 pt、red、省略）。土日祝の列は weekendTint、今日は todayTint。列の高さ最小 48 pt | 列 → `kind = .day, focus = その日`。accessibilityLabel「2026年10月4日(日) 体育の日（日表示へ）」 |
| 日 | 左 72/1000 の空き、時間軸の列（588/1000）に: 日付の数字（21 pt、今日は丸 36 pt）、「10月」（11 pt ink3）と「日曜日」（14 pt semibold）、祝日名の丸いバッジ（12 pt red、背景 rgba(220,38,38,.08)）。右のメモ欄の列は左に lineStrong の線 | なし |
| 年 | 左 56/1400 の空き、12 列「1月」〜「12月」（13 pt semibold、高さ最小 44 pt、今の月は accent） | 月名 → `kind = .month, focus = その月の 1 日`。accessibilityLabel「2026年10月（月表示へ）」 |

列の幅は `GeometryReader` で画面幅 × (64/1400 など) から出す。倍率を上げたときに紙とずれるのは M2 §4.3 と同じ既知の制限。

### 4.4 タップの行き先（`handleTap`、`layout.hit(at:)` の結果で分岐。`switch` は網羅）

| HitTarget | 動き |
| --- | --- |
| `.allDayBar(id)`, `.timedChip(id)`, `.timedBox(id)` | 予定の詳細シート（M2 の `EventDetailSheet`。閲覧のみ） |
| `.moreChips(day)` | **日ページへ**（`kind = .day, focus = day`）。M2 の `DayEventsSheet` は役目を終えるので削除（DESIGN §2.3・§4.5 の予定どおり） |
| `.date(day)` | 日ページへ（月の日付の数字、年の曜日の字、年の薄いチップ） |

### 4.5 初回案内・ツールバー

M2 のまま（`OnboardingView` はファイルを分けるだけ）。ツールバーはどのページでも同じ。

## 5. 予定の取得（担当 U）

```swift
extension EventKitService {
  /// [start, end) の日の予定（終日の end を翌 0 時に正規化、色、辞退の除外は M2 と同じ）。4 年までなので年ページも 1 回で済む
  func events(from start: DayKey, to end: DayKey, calendars: [EKCalendar]?) -> [LayoutEvent]
  // 既存 events(in month:calendars:) は上を呼ぶ薄い包み（残す）
}
@MainActor final class EventStoreModel: ObservableObject {
  func load(kind: PageKind, focus: DayKey)     // dayRange(kind, focus:) の範囲を読む。reload() も同じ範囲
  // status / events / calendars / hiddenCalendarIds / requestAccess / refreshStatus / events(on:) / detail(forEventId:) は M2 のまま
}
```

スクリーンショットモードは `ScreenshotMode.demoEvents(for: month)` を範囲に関係なく返す（engine が重なるものだけ使う）。

## 6. 保存（担当 U）

`InkPageStore` は変更なし。pageId がそのままファイル名（`w-2026-09-28.json.lzfse`、`d-2026-10-04.json.lzfse`、`y-2026.json.lzfse`。すべて安全な文字）。最後に見ていた表示と日付は UserDefaults（§4.1）。

## 7. スクリーンショットモード（担当 U）

```swift
enum ScreenshotMode {
  struct Config: Equatable, Sendable { var page: PageKind; var month: YearMonth; var today: Date; var focus: DayKey }
  static func parse(_ arguments: [String]) -> Config?
  //   --screenshot-mode が無ければ nil。--screenshot-month YYYY-MM（既定: 今月）。--screenshot-page day|week|month|year（既定: month。不正な値は month）
  //   today = その月の 7 日 10:00（M2 と同じ）、focus = その月の 7 日
  static func demoEvents(for month: YearMonth) -> [LayoutEvent]   // M2 の見本に 7 日の予定を足す（下記）
  static func demoPage(kind: PageKind, focus: DayKey) -> InkPage   // pageId = PageNavigation.pageId(kind, focus:)。月は M2 の demoPage(for:) と同じ 3 本
}
```

- 7 日（今日）に足す見本: 終日「締切」（個人）、時間指定「打合せ」10:00〜11:30（仕事）、「電話」10:30〜11:00（個人）→ 週・日ページで重なりの 2 列が見える、「歯科」14:00〜15:00（個人）。月ページでは 7 日のチップが 3 件になるだけ（行の高さは変わらない: 28 + 25 + 60 + 40 = 153 < 175）。id は "demo-…" の連番を続ける。
- ページごとの見本の線（マス相対 lu、M2 と同じ作り）: 週 = `allday:<水曜>` にペンの波線、`grid` に「打合せ」の箱の上を横切るマーカー／日 = `allday` にペンの丸、`grid` のメモ欄（x ≥ 660）にペンの波線 2 本／年 = "10-07" の左 45% に赤ペンの丸、"02-30"（存在しない日）にペンの短い線（書けることを示す）。
- 画面は `CalendarRootScreen` が `ScreenshotMode.current` の `page`・`focus` で始まり、UserDefaults の記憶は読まない・書かない。`InkPageStore` も読み書きしない（M2）。

## 8. テスト

### 8.1 TegakiKit（担当 K）: `KitChecks` に節を足し、同じ内容を XCTest にも置く

- PaperSpec: `weekColumnWidth == 1336/7`、`weekGridHeight 1920`、`dayGridHeight 2400`、`dayLaneStep 24`、`yearLaneStep 18`。
- CellKey: `.allDay(2026-10-04).raw == "allday:2026-10-04"`、`.allDayDay.raw == "allday"`、`.grid.raw == "grid"`、`.yearDay(month: 2, day: 30).raw == "02-30"`、`yearDay(12, 31) == "12-31"`、`allDayDate`・`yearMonthDay` の往復、`CellKey(raw: "02-30").day == nil`、`CellKey(raw: "allday:2026-10-04").day == nil`。
- PageNavigation: `pageId` 4 種（Web 版 page-geometry.test.mjs の pageIdFor の期待値: 2026-10-04（日）の週は "w-2026-09-28"、2026-10-05 は "w-2026-10-05"、2027-01-01 の年は "y-2027"）、`dayRange`（週は 7 日、月は 42 日で 9/28〜11/9 排他、年は 365/366 日）、`move`（日 ±1、週 ±7 で同じ曜日、月 +1 は翌月 1 日、3/31 の −1 は 2/1、12 月 +1 は翌年 1/1、年 ±1 は 1/1、2028-02-29 の年 −1 は 2027-01-01）、`title` 4 種（祝日つきの日、年をまたぐ週、同じ月の週）。
- TimedEventEngine（Web 版 event-layout.test.mjs の layoutTimedEvents の節を **全て** 移す。期待値は `[startMin, endMin, col, cols]`）: 1 件と終日の除外、連続する予定は重ならない、同じ開始は長いもの先→題名、入れ子、列の再利用と推移的な塊、深夜をまたぐ予定の日ごとの切り詰め（22:00〜翌 2:00、12:00〜翌々日 12:00、23:00〜翌 0:00 は翌日に出ない）、15 分の最小（9:00〜9:05、長さ 0、逆転、23:55 の長さ 0 は [1425, 1440]、9:00〜9:05 と 9:10 は衝突・9:15 は衝突しない）、並び順、300 回の乱数（衝突なし・同じ塊なら同じ cols）。`boxFrame` の数値例（週 colW で 2 列: inner = 182.857…、g = 2、w = 90.428…）。
- LanePacking: 収まるときはそのまま（`metrics(laneCount: 30, lane: 22, gap: 3, available: 767)` は 747 ≤ 767 なので lane 22 / step 25）、`metrics(laneCount: 40, lane: 22, gap: 3, available: 767)` は step = 770/40 = 19.25、gap 3、lane 16.25、fontScale 16.25/22、`step < 3×gap` の分岐（`metrics(laneCount: 100, lane: 22, gap: 3, available: 767)`）。
- 週（2026-10-05 の週、`tokyo`。予定は §7 の見本と同じものを KitChecks 側にも定義する）: `size`（予定なし = 1400 × 1980）、`cells.count == 8`、`cells[.allDay(10/5)] == (64, 0, 190.857…, 60)`、`cells[.grid] == (0, 60, 1400, 1920)`、`columnFrame(6).maxX ≈ 1400`、帯 1 レーン（キャンプ 4〜5 は月曜の列に `continuesLeft`、締切 7 は水曜、家族旅行 9〜13 は金〜日で `continuesRight`。3 本とも lane 0）の frame、`bandHeight(1, 0) == 60`、`bandHeight(2, 0) == 80`、`bandHeight(0, 100) == 112`、`bandHeight(40, 0) == 800`、箱の frame（10/7 の 10:00〜11:30 と 10:30〜11:00 が 2 列、14:00〜15:00 は 1 列）、`isPast`（今日 10:00 では 10/6 の週次定例だけ過去）、`nowLine`（今日 10:00 → y = bandH + 800、列 2）、`cell(at:)`（帯の時刻帯 (10, 10) は nil、(1400, 100) は `.grid`、(100, 1980) は nil）、`inkCell(forCenter:)`（(10, 10) → 月曜の帯、(-5, -5) → 月曜の帯、(1500, 30) → 日曜の帯、(10, 500) → grid、(700, 5000) → grid）、`growsWithInk`、`hit`（箱 → 帯 → nil、帯と箱が重なる点は箱）、`band`/`bandTop`、`PageScroll.scrollDelta`（帯が 60 → 80 に伸びたとき grid 内の点は +20、帯内の点は 0）、`initialScrollY`（今日あり 10:00 → 60 + 720、今日なし → 60 + 560）。
- 日（2026-10-07、同じ見本）: `size`（1000 × 2460）、`cells.count == 2`、チップ frame `(76, 2 + lane×24, 572, 22)`、`bandHeight(3, 0) == 102`、箱（`columnX 72, columnWidth 588, padLeft 4, padRight 14, gap 3`。打合せと電話が 2 列）、`nowLine x0 72 x1 660`、`inkCell`（(900, 30) → allday、(900, 1000) → grid、(30, 1000) → grid）、`growsWithInk(.grid) == false`、`initialScrollY`。
- 年（2026、同じ見本）: `rows.count == 31`、`cells.count == 372`、`invalidCells`（2/29, 2/30, 2/31, 4/31, 6/31, 9/31, 11/31 の 7 つ。2028 年は 2/29 を含まず 6 つ）、`dateLabels.count == 365`、予定なしの `size == 1400 × 1860`、`cellFrame(10, 7) == (56 + 9×112, 6×60, 112, 60)`（7 日の行は 1 レーンなので 60 のまま）、行の伸び（10/16 に終日 4 件 → `rows[15].frame.height == 16 + 4×18 + 8 = 96`、`rows[16].frame.minY` が予定なしより +36、2 月の列の 16 日のマスも高さ 96）、複数日の予定が同じレーン（家族旅行 9〜13: 5 つのチップ、`lane` 同じ、9 日は `continuesDown` だけ、13 日は `continuesUp` だけ、`linkToY == 翌日のチップの minY`、13 日は `linkToY == nil`）、チップ frame `(cellX + 50.4, cellY + 16 + lane×18, 58.6, 16)`、上限での間引き（1 日に終日 40 件 → 行 400、`step == 378/40`、`lane < 12` で `isThin`、同じ行の他の月のチップは 16 のまま）、予定なしのレイアウトで `cell(at:)`（(30, 100) は nil、(56, 100) は 01-02、(1400, 100) は 12-02、(100, 1860) は nil）と `inkCell`（(30, 100) → 01-02、(-10, -10) → 01-01、(1500, 100) → 12-02、(100, 5000) → 01-31）、`hit`（曜日の字 → `.date`、チップ → `.allDayBar`、薄いチップ → `.date`、存在しない日の左上 → nil）、`band`、`scrollDelta`（16 日の行が伸びたとき 17 日以降の点は +36、16 日の行の点は 0）、`initialScrollY`（今日 10/7 → `rows[4].frame.minY`、今日 1/1 → 0、他の年 → 0）。
- 月: 既存の検査はそのまま通ること（`MonthLayoutEngine.scrollDelta` の期待値を変えない）。`MonthPageLayout.pageId == "m1-2026-10"`、`inkCell`（M2 の cellFor と同じ: 紙の外 → 近いマス、下の外 → memo）、`growsWithInk(.memo) == true`、`band(atY: 1100) == "memo"`。
- `sameGeometry`: 同じ入力なら true、inkBottoms を変えると false、`now` だけ変えると true。

### 8.2 アプリ（担当 I, `InkLedgerTests`）

M2 の検査に加えて: 週の帯の中に書いた線が `allday:YYYY-MM-DD` に付く、時間軸に書いた線が `grid` に付く（`needsMoreRoom` は false）、年の日付帯に書いた線が 1 月の列に付いて x が負、帯が伸びた relayout で grid の線が平行移動して差分が出ない、`reload` に別 pageId を渡しても台帳が変わらない（Debug では assertion なので Release 相当の経路を直接は検査せず、`page.pageId` が変わらないことを確かめる）。

### 8.3 アプリ（担当 U, `ScreenshotModeTests`）

`parse` の 4 ページと既定値、不正な値は month、`focus` が 7 日、`demoPage(kind:focus:)` の pageId が各ページの pageId。

## 9. CI・統合（担当 C）

- `project.yml`: `MARKETING_VERSION` を 0.3.0 に。他は変更なし（`Paper/` は `Sources/TegakiCalendar` の下なので自動で入る）。
- `build.yml` のスクリーンショット: 1 回の launch を 4 回に。

```yaml
      - name: Screenshots (portrait, 4 pages)
        if: ${{ !cancelled() && steps.simudid.outcome == 'success' }}
        continue-on-error: true
        run: |
          set -euo pipefail
          UDID="${{ steps.simudid.outputs.udid }}"
          mkdir -p shots
          for PAGE in month week day year; do
            xcrun simctl terminate "$UDID" com.syfan0.tegakicalendar 2>/dev/null || true
            xcrun simctl launch "$UDID" com.syfan0.tegakicalendar --screenshot-mode --screenshot-month 2026-10 --screenshot-page "$PAGE"
            sleep 8
            pgrep -fl "TegakiCalendar.app/TegakiCalendar" || echo "::warning::The app is not running after 8 s ($PAGE)"
            xcrun simctl io "$UDID" screenshot "shots/ipad-portrait-$PAGE.png"
          done
          ls -la shots
```

  成果物 `screenshots` に `ipad-portrait-month.png`・`-week.png`・`-day.png`・`-year.png` と `app-log.txt`。
- ローカル確認（この Mac）: `cd TegakiKit && swift build && swift run KitChecks`、`for f in $(find Sources Tests -name '*.swift'); do swiftc -parse -swift-version 5 "$f"; done`。
- 統合の順番: K → I と U（並行。U は K の API ができるまで `MonthPaper` の移動と固定見出しを先に進める）→ C。コンパイルの本番は CI。
- `README.md` の「いま出来ていること」と `docs/M3A.md`（実装結果の要約。M2.md と同じ構成）は C が書く。

## 10. M3b に残すもの（この契約で触らない）

予定の作成・編集・削除（`EventKitService` の書き込み、作成・編集シート、繰り返しの扱い）、予定ツール（`rectToEventRange` / `snapEventRect` / `pointToSlot` の移植と矩形ドラッグ）、投げなわ（選択・移動・「予定にする」）、設定画面（カレンダー・入力・データ・情報）、初回案内の 4 枚化（iCloud の説明）、iPhone の見た目（ヘッダー 2 段、月の初期倍率）、キャンバスの使い回し（DESIGN §3.10）、上限を超えた月の行のレーン間引き。
