# M3b 実装契約（予定の作成・編集・削除、予定ツール、投げなわ、設定画面、iPhone の見た目）

この文書は M3b の各担当が同時に作業するための **約束事**（公開 API・データ形状・UserDefaults の鍵・日本語の文言・ファイル所有）です。[M3A_CONTRACT.md](M3A_CONTRACT.md) の続きで、M2・M3a で決めたことはそのまま生きています（ここに書いていない API は変えません）。
設計の根拠は [DESIGN.md](DESIGN.md)（§2.7 ヘッダーとツールバー、§2.8 設定画面、§2.11 iPhone、§3.6 道具（投げなわ・予定）、§3.7 マスをまたぐ場合、§3.13 元に戻す、§4.3 カレンダーの選択、§4.5 予定の作成、§4.6 編集・削除）。ここに無いことは DESIGN.md に従い、DESIGN.md にも無ければ Web 版（`../tegaki-calendar/docs/SPEC.md` §3 `rectToEventRange` / `snapEventRect`、`js/views/page-geometry.js`、`js/ink/geometry.js`、`js/ink/surface.js` の投げなわと予定ツール、`js/ui/event-dialog.js`、`js/ui/settings.js`、`js/ui/selection-menu.js`、`js/main.js` の convert-to-event）の流儀に合わせます。本人が毎日使っている Web 版の **動き方が正** です。

本人の決定（この契約で既定にしてあるもの）:
- **B-4**: 閲覧専用モード（未購読時の制限）は M5。M3b では誰でも作成・編集できる。
- **「予定にした手書きを消す」の既定はオン**（UserDefaults `eraseInkAfterConvert`、§4.1）。
- 月ページの時間指定チップは **1 日 3 件まで**（2 件＋「+n件」、M2 のまま。変更なし）。
- 15 分丸めは **両端とも最寄りの 15 分**（Web 版 SPEC §3 の最新版。floor/ceil ではない）。30 分未満は 1 時間に。高さ 12 lu 未満はタップ扱い。

**M3b の範囲**: (1) 予定の作成（予定ツール・＋予定）、(2) 投げなわ（選択・移動・削除・「予定にする」）、(3) 編集・削除（繰り返しの「この回だけ／以降すべて」）、(4) 設定画面（同期・購入は「準備中」）、(5) iPhone の見た目（ヘッダー 2 段・ツールバーの横スクロール・指で書くの既定オン）、(6) スクリーンショットモードのシート 4 枚。
**範囲外**（触らない）: CloudKit 同期、StoreKit・ペイウォール・閲覧専用、手書きの書き出し／取り込み、初回案内の 4 枚目（iCloud の説明は M4）、キャンバスの使い回し（DESIGN §3.10）、iPhone の月ページの初期倍率（要確認 B-2）。

## 0. 構成とファイル所有

```
TegakiKit/                                   担当 K（TegakiKit だけを触る）
  Sources/Layout/EventRange.swift            新規: EventRange, EventGeometry（丸めの規則）、PageLayout の eventRange / snapRect の要件（§1.1〜1.3）
  Sources/Layout/MonthPageLayout.swift       変更: eventRange / snapRect の実装（§1.4）
  Sources/Layout/WeekLayoutEngine.swift      変更: 同上（§1.5）＋ nearestColumn(atX:)
  Sources/Layout/DayLayoutEngine.swift       変更: 同上（§1.6）
  Sources/Layout/YearLayoutEngine.swift      変更: 同上（§1.7）
  Sources/InkModel/LassoGeometry.swift       新規: 多角形の内外判定・投げなわの判定・外接矩形・移動の制限・スナップショットの寸法（§2.1）
  Sources/InkModel/InkStroke.swift           変更: 紙座標の点列・外接矩形・平行移動した複製（§2.2）
  Sources/KitChecks/main.swift               変更: §6.1 の検査を追加
  Tests/LayoutTests/EventRangeTests.swift    新規（§6.1）
  Tests/InkModelTests/LassoGeometryTests.swift   新規（§6.1）
  Package.swift                              変更なし
Sources/TegakiCalendar/
  Ink/InkTools.swift                         担当 I   変更: CanvasTool に .lasso / .eventRect（§3.1）
  Ink/InkLedger.swift                        担当 I   変更: removeStrokes(ids:) / moveStrokes(ids:by:) / strokes(ids:)（§3.2）
  Ink/InkCanvasView.swift                    担当 I   変更: 選択の状態と callback、命令の受け口、overlay の取り付け（§3.3）
  Ink/InkOverlayView.swift                   担当 I   新規: 投げなわ・予定ツールの入力ビュー（UIKit。破線の枠・プレビュー・移動の絵）（§3.4）
  Ink/InkSnapshot.swift                      担当 I   新規: 選んだ線の PNG（UIImage）（§3.5）
  Ink/PencilInteraction.swift                担当 I   変更なし
  Paper/*                                    担当 U   変更なし
  Views/CalendarRootScreen.swift             担当 U   変更: 予定の作成・編集・削除の流れ、投げなわのメニュー、設定、＋予定、トースト、iPhone 判定（§4.5）
  Views/PageHeaderView.swift                 担当 U   変更: ＋予定・⚙、幅 600 pt 未満で 2 段（§4.6）
  Views/ToolbarView.swift                    担当 U   変更: 投げなわ・予定のボタン（§4.7）
  Views/EventEditorSheet.swift               担当 U   新規: 作成・編集・閲覧のシート（§4.3）。Views/EventDetailSheet.swift は **削除**（閲覧は同じシートの readOnly）
  Views/EventEditorForm.swift                担当 U   新規: シートの純粋な状態（Web 版 event-dialog.js の form と同じ規則。テスト対象）（§4.3）
  Views/EventDateText.swift                  担当 U   EventDetailSheet.swift から `EventDateText` を移す（内容は変更なし）
  Views/RecurrenceScopeDialog.swift          担当 U   新規: 「この回だけ」「以降すべて」（§4.4）
  Views/SelectionMenuView.swift              担当 U   新規: 「予定にする」「削除」「選択解除」の浮いたメニュー（§4.2）
  Views/SettingsScreen.swift                 担当 U   新規: 設定画面（§4.8）
  Views/ToastView.swift                      担当 U   新規: 画面下のトースト（§4.9）
  Views/OnboardingView.swift                 担当 U   変更なし
  Calendar/EventKitService.swift             担当 U   変更: 書き込み可能なカレンダー・登録先・作成・更新・削除・エラー（§4.1）
  Calendar/EventStoreModel.swift             担当 U   変更: カレンダーの選択肢、登録先、作成・更新・削除の呼び出し、書き込み後の再取得（§4.1）
  Calendar/EventDraft.swift                  担当 U   新規: EventDraft / EventSpan / EventWriteError / CalendarOption（§4.1）
  Persistence/AppSettings.swift              担当 U   新規: UserDefaults の鍵と既定値（§4.0）
  Persistence/InkPageStore.swift             担当 U   変更: removeAll()（§4.8）
  Support/ScreenshotMode.swift               担当 U   変更: --screenshot-sheet（§5）
Tests/TegakiCalendarTests/InkLedgerTests.swift       担当 I   変更: §6.2
Tests/TegakiCalendarTests/InkSnapshotTests.swift     担当 I   新規: §6.2
Tests/TegakiCalendarTests/EventEditorFormTests.swift 担当 U   新規: §6.3
Tests/TegakiCalendarTests/EventKitServiceTests.swift 担当 U   変更: §6.3
Tests/TegakiCalendarTests/ScreenshotModeTests.swift  担当 U   変更: §6.3
project.yml / .github/workflows/build.yml / README.md / docs/M3B.md   担当 C（統合・CI）（§7）
```

依存の向き（M2 と同じ）: `TegakiCalendar` → `TegakiKit`（Layout, Holidays, InkModel）。
**担当 U は `Ink/*` を触らない。担当 I は `Views/*`・`Paper/*`・`Calendar/*` を触らない。担当 K は `TegakiKit/` だけ。** 担当 I と U の接点は次の 4 つだけで、いずれもこの契約の形に固定します。

1. `InkCanvasView` の引数（§3.3）: 選択の通知 `onSelectionChange`、予定ツールの `onEventRect` / `onEventPreview`、命令 `command` / `commandTrigger`、`initialSelectionIds`。
2. `CanvasTool.lasso` / `.eventRect`（§3.1）: U はツールバーで選ぶだけ。
3. `InkSelection`（§3.3）: U は `ids` と `viewRect` を読むだけ。
4. `InkSnapshot.render(strokes:cells:maxSize:scale:)`（§3.5）: U が `page.strokes` と `layout.cells` を渡して呼ぶ静的関数。

Web 版の「ページの幾何（矩形→日時）」は K、「投げなわの数学」は K、「入力と選択の見た目」は I、「シート・設定・EventKit」は U、という分担です。

## 1. Layout（担当 K）: 矩形 → 予定の範囲、予定の範囲 → 矩形

### 1.1 EventRange と丸めの規則（`EventRange.swift`）

```swift
/// 矩形（投げなわの外接矩形、予定ツールのドラッグ矩形）から決めた予定の範囲（Web 版 rectToEventRange の結果）。
/// 終日の end は翌日 0 時（排他）。時間指定は同じ日の中（end は最大でその日の 24:00 = 翌 0 時）。
public struct EventRange: Equatable, Sendable {
  public var start: Date
  public var end: Date
  public var allDay: Bool
  public init(start: Date, end: Date, allDay: Bool)
  /// end > start
  public var isValid: Bool
  /// 終日 1 日（start = day の 0 時、end = 翌 0 時）
  public static func allDay(_ day: DayKey, calendar: Calendar = DayKey.deviceCalendar) -> EventRange
  /// 時間指定（day の startMinute 分 〜 endMinute 分。endMinute 1440 は翌 0 時）
  public static func timed(_ day: DayKey, startMinute: Int, endMinute: Int, calendar: Calendar = DayKey.deviceCalendar) -> EventRange
}

/// Web 版 page-geometry.js の規則（数字は SPEC §3 のとおり）。純粋関数。
public enum EventGeometry {
  /// これより低い矩形はタップ扱い（lu）
  public static let tapMaxHeight: CGFloat = 12
  /// ドラッグがこれより短ければ 1 時間にする（分）
  public static let minDragMinutes = 30
  /// タップ・短いドラッグの長さ（分）
  public static let defaultDurationMinutes = 60
  public static let dayMinutes = 1440

  public enum Rounding { case nearest, floor, ceil }
  /// Web 版 roundMinutes: q = m/step。|q − round(q)| < 1e-9 なら round(q)×step（浮動小数の誤差で 1 段ずれない）。
  /// それ以外は mode どおり。nearest は 0.5 を切り上げ（JS の Math.round と同じ。m ≥ 0 だけを扱う）。
  public static func roundMinutes(_ minutes: Double, step: Int, _ mode: Rounding = .nearest) -> Int
  /// y（時間軸の 0:00 を 0 とした lu）→ 分。[0, 1440] に clamp（Web 版 yToMinutes）
  public static func minutes(forY y: CGFloat, hourHeight: CGFloat) -> Double
  /// 時間軸上の矩形（minY/maxY は 0:00 を 0 とした lu）→ [start, end] 分（Web 版 timelineSlotForRect の分の部分）:
  ///   height = maxY − minY < 12 → start = floor30(minutes(centerY)), end = start + 60
  ///   それ以外 → start = round15(minutes(minY)), end = round15(minutes(maxY))、end − start < 30 なら end = start + 60
  ///   end = min(end, 1440)、end ≤ start なら start = max(0, end − 60)
  public static func timelineSlot(minY: CGFloat, maxY: CGFloat, hourHeight: CGFloat) -> (startMinute: Int, endMinute: Int)
  /// 矩形の正規化（min ≤ max）。どれかが有限でなければ nil
  public static func normalized(_ rect: CGRect) -> CGRect?
}
```

`CGRect` は `origin`/`size` で持ちますが、幅や高さが負の矩形（ドラッグの向きが逆）も `normalized` で `standardized` に直してから使います。

### 1.2 PageLayout の要件の追加（`PageLayout.swift` に要件を足し、各 Layout の swift で実装）

```swift
public protocol PageLayout: Sendable {
  // 既存の要件はそのまま
  /// 紙座標の矩形 → 予定の範囲（Web 版 rectToEventRange）。`now` は月のメモ欄の日を決めるときだけ使う。
  /// 矩形が有限でないときだけ nil（紙の外の矩形は一番近いマス・列に寄せる）。
  func eventRange(for rect: CGRect, now: Date, calendar: Calendar) -> EventRange?
  /// 予定の範囲が占める紙座標の矩形（Web 版 snapEventRect。予定ツールのプレビュー）。
  /// その範囲がこのページに無ければ nil（別の週の日、別の年など）。
  func snapRect(for range: EventRange, calendar: Calendar) -> CGRect?
}
extension PageLayout {
  public func eventRange(for rect: CGRect, now: Date) -> EventRange?          // calendar = DayKey.deviceCalendar
  public func snapRect(for range: EventRange) -> CGRect?                      // 同上
  /// eventRange → snapRect の合成（担当 I の onEventPreview がそのまま使う）
  public func previewRect(for rect: CGRect, now: Date, calendar: Calendar = DayKey.deviceCalendar) -> CGRect?
}
```

不変条件（§6.1 で乱数検査する）: `eventRange(for: snapRect(for: eventRange(for: r)))` は `eventRange(for: r)` と同じ（プレビューの矩形を入れ直しても同じ予定になる。Web 版の「idempotent」検査）。

### 1.3 共通の規則

- 中心: `cx = rect.midX`、`cy = rect.midY`（正規化後）。
- 時間軸（週・日）の y は紙座標なので `grid.minY` を引いてから `EventGeometry.timelineSlot` に渡す（帯の中で始めたドラッグは minY − grid.minY が負 → 0:00 に clamp）。
- `snapRect` が返す矩形は `(x: 列の x, y: minutesToY(start), width: 列幅, height: minutesToY(end) − minutesToY(start))`（週・日の時間指定）、マスの矩形そのもの（月・年・終日）。

### 1.4 月（`MonthPageLayout`）

- `cx = clamp(midX, 0, 1400)`、`cy = clamp(midY, 0, size.height)`。
- `cy ≥ memo.minY`（メモ欄、紙の下の外も含む）→ **メモ欄の日**: `today = DayKey(now)` が `month` の中なら today、違えば `month.firstDay`。
- それ以外 → `cell(at: (cx, cy))!.day`（`cell(at:)` は x == 1400 を最後の列にし、行は半開区間。`cy < memo.minY` なので必ず日のマス）。
- 返す範囲は `EventRange.allDay(day)`。
- `snapRect(for:)`: `day = DayKey(range.start, calendar)`、`cells[.day(day)]`（42 日の中に無ければ nil）。時間指定の範囲でも同じ（その日のマス）。

### 1.5 週（`WeekPageLayout`）

```swift
extension WeekPageLayout {
  /// 時刻帯（x < 64）と紙の外も一番近い列に寄せる: clamp(floor((x − 64)/colW + 1e-9), 0, 6)（Web 版 nearestWeekColumn）
  public func nearestColumn(atX x: CGFloat) -> Int
}
```

- 列 = `column(atX: cx) ?? nearestColumn(atX: cx)`。
- 分 = `EventGeometry.timelineSlot(minY: rect.minY − grid.minY, maxY: rect.maxY − grid.minY, hourHeight: 80)`。
- 返す範囲は `EventRange.timed(days[col], startMinute:, endMinute:)`。
- `snapRect(for:)`: `day = DayKey(range.start)`、`col = days.firstIndex(of: day)` が無ければ nil。`range.allDay` なら `cells[.allDay(day)]`。時間指定なら `startMinute = range.start < 当日 0 時 ? 0 : minutesOfDay(start)`、`endMinute = range.end ≥ 翌 0 時 ? 1440 : minutesOfDay(end)`、`endMinute ≤ startMinute` なら nil。矩形は `(columnFrame(col).minX, minutesToY(startMinute), colW, minutesToY(endMinute) − minutesToY(startMinute))`。

### 1.6 日（`DayPageLayout`）

- 列は常に時間軸（メモ欄・時刻帯で始めたドラッグも時間軸の予定になる。Web 版「column outside the timeline still uses the day」）。
- 分は週と同じ（`hourHeight: 100`）。返す範囲は `EventRange.timed(day, …)`。
- `snapRect(for:)`: `DayKey(range.start) == day` でなければ nil。終日なら `cells[.allDayDay]`。時間指定なら `(timeline.minX = 72, minutesToY(start), 588, …)`。

### 1.7 年（`YearPageLayout`）

- `cx = clamp(midX, 56, 1400)`、`cy = clamp(midY, 0, size.height)`。
- 月 = `min(11, floor((cx − 56)/112 + 1e-9)) + 1`、日 = `row(atY: min(cy, size.height − 0.001)) ?? 31`（上の外は 1、下の外は 31）。
- 存在しない日（2/30、4/31、平年の 2/29）は **その月の最終日** にする（Web 版）。
- 返す範囲は `EventRange.allDay(DayKey(year, month, day))`。
- `snapRect(for:)`: `day = DayKey(range.start)`、`day.year == year` でなければ nil、`cellFrame(month: day.month, day: day.day)`。

### 1.8 数値の例（§6.1 の期待値。Web 版 tests/page-geometry.test.mjs から移したもの）

日ページ（2026-10-04、y = 分 × 100/60）: `(100, 900)-(300, 1050)` → 9:00〜10:30／`(100, 910)-(300, 1060)` → 9:00〜10:30（最寄りで下へ）／`(100, 915)-(300, 1065)` → 9:15〜10:45／`(100, 900)-(300, 950)` → 9:00〜9:30（ちょうど 30 分はそのまま）／`(100, 905)-(300, 925)` → 9:00〜10:00（30 分未満 → 1 時間）／逆向き `(300, 1050)-(100, 900)` → 9:00〜10:30／`(100, 1398)-(300, 1504)` → 14:00〜15:00（行き過ぎは線に戻る）／`(100, 1403)-(300, 1495)` → 14:00〜15:00／`(100, 1400)-(300, 1513)` → 14:00〜15:15（7.5 分を超えたら次の線）／メモ欄 `(700, 900)-(950, 1050)` と時刻帯 `(0, 900)-(40, 1050)` も 9:00〜10:30／タップ `(200, 1275)` → 12:30〜13:30／高さ 11.9 `(200, 1270)-(205, 1281.9)` → 12:30〜13:30／高さ 12 `(200, 1270)-(205, 1282)` → 12:45〜13:45／`(200, 2300)-(300, 2500)` → 23:00〜翌 0:00／タップ `(200, 2390)` → 23:30〜翌 0:00／`(200, 2380)-(300, 2400)` → 23:45〜翌 0:00／タップ `(200, 2400)` → 23:00〜翌 0:00／`(200, 2500)-(300, 2600)` → 23:00〜翌 0:00／`(200, −100)-(300, −50)` → 0:00〜1:00。
週ページ（2026-10-05 の週、y = 分 × 80/60。`weekColCenter(i) = 64 + (i + 0.5) × colW`）: `(700, 720)-(760, 840)` → 10/08 9:00〜10:30（x 700 は列 3 = 木曜）／`(weekColCenter(3), 1117)-(同, 1206)` → 10/08 14:00〜15:00、`snapRect` は `(columnFrame(3).minX, 1120, colW, 80)`／タップ `(weekColCenter(2), 1000)` → 10/07 12:30〜13:30／`(0, 720)-(60, 840)` → 月曜（列 0）／`(1450, 720)-(1500, 840)` → 日曜（列 6）／`(1300, 720)-(1390, 840)` → 10/11（列 6）／`(700, 1800)-(760, 2000)` → 22:30〜翌 0:00。帯の高さ（`grid.minY`）を足してから渡すこと（上の数値は帯 0 のときの y。検査では `grid.minY` を足す）。
月ページ（2026-10、月曜始まり、グリッドは 9/28〜11/8）: `(850, 20)-(950, 140)` → 10/02 終日（行 0 列 4）／`(410, 360)-(490, 380)` → 行 2 列 2 = 10/14／中心 (200, 175) は次のマス（行 1 列 1 = 10/06）／`(−100, −100)-(−50, −50)` → 9/28／`(1450, 1000)-(1500, 1040)` → 行 5 列 6 = 11/08（予定なし・手書きなしの行高 175）／メモ欄（`y ≥ memo.minY`）: now が 10/14 なら 10/14、now が 11/3・9/29・2025-10-14 なら 10/01／`snapRect` はそのマス（10/14 = (400, 350, 200, 175)）。
年ページ（2026）: 各マスの中心のタップと小さな矩形 → その日の終日／2/29・2/30・2/31 → 2/28（2028 年は 2/29）／4/31 → 4/30、6/31 → 6/30、9/31 → 9/30、11/31 → 11/30／日付帯 `(0, 130)-(40, 150)` → 1/03、右の外 `(1450, 130)-(1500, 150)` → 12/03、上の外 → 1 日、下の外 → 31 日／`snapRect(2/31 → 2/28)` は 2/28 のマス（`cellFrame(2, 28)`）。

## 2. InkModel（担当 K）: 投げなわの数学

### 2.1 LassoGeometry（`LassoGeometry.swift`。Web 版 js/ink/geometry.js と surface.js の純粋関数の移植）

```swift
public enum LassoGeometry {
  /// 投げなわの頂点はこれ以上離れたときだけ足す（lu）
  public static let minStep: CGFloat = 2
  /// 縦横ともこれより小さい投げなわはタップ（lu）
  public static let minExtent: CGFloat = 4
  public static let simplifyEpsilon: CGFloat = 1
  public static let maxVertices = 512
  /// スナップショットの余白（lu）と拡大の上限
  public static let snapshotPadding: CGFloat = 12
  public static let snapshotMaxZoom: CGFloat = 4

  /// 偶奇規則の内外判定。頂点が 3 未満なら false
  public static func pointInPolygon(_ p: CGPoint, _ polygon: [CGPoint]) -> Bool
  /// 線の点の 50% 以上（`inside × 2 ≥ 有効な点の数`）が多角形の中なら true。有限でない点は数えない。点が無ければ false。
  /// `bounds`（多角形の外接矩形）を渡せば外接矩形の外の点は内外判定を省く。頂点 3 未満なら false。
  public static func strokeInLasso(points: [CGPoint], polygon: [CGPoint], bounds: CGRect? = nil) -> Bool
  /// 有限でない点を捨て、頂点 3 未満か縦横とも minExtent 未満なら nil、最後に最初の頂点を繰り返して閉じる
  public static func closedPolygon(_ points: [CGPoint], minExtent: CGFloat = minExtent) -> [CGPoint]?
  /// Ramer–Douglas–Peucker。最初と最後は残す。結果が 4 頂点（3 + 閉じ）未満なら入力のコピー。n ≤ 4 はそのまま
  public static func simplified(_ polygon: [CGPoint], epsilon: CGFloat = simplifyEpsilon) -> [CGPoint]
  /// closedPolygon → simplified(ε=1) → 頂点が maxVertices を超えるあいだ ε を 2, 4, 8 と倍にする（Web 版 _endLasso）
  public static func lassoPolygon(_ points: [CGPoint]) -> [CGPoint]?
  public static func bounds(of polygon: [CGPoint]) -> CGRect?
  /// 矩形の和（空なら nil。有限でない矩形は無視）
  public static func union(_ rects: [CGRect]) -> CGRect?
  /// 選択の枠が紙 [0, W]×[0, H] から出ないように移動量を制限。はみ出している枠は戻る向きには動けるが、さらに出る向きには動けない。
  /// 枠を押し戻すことはしない（Web 版 clampMoveDelta）。
  public static func clampedMoveDelta(bbox: CGRect, dx: CGFloat, dy: CGFloat, pageSize: CGSize) -> CGVector
  /// スナップショットの寸法: bbox を pad だけ広げ、maxSize に収まる倍率（ただし maxZoom 以下）。
  /// size = clamp(round(w×zoom), 1, maxW) × clamp(round(h×zoom), 1, maxH)
  public static func snapshotLayout(bbox: CGRect, pad: CGFloat = snapshotPadding, maxSize: CGSize = CGSize(width: 480, height: 240), maxZoom: CGFloat = snapshotMaxZoom) -> (rect: CGRect, zoom: CGFloat, size: CGSize)?
}
```

### 2.2 InkStroke の追加（`InkStroke.swift`）

```swift
extension InkStroke {
  /// 点列を紙座標に（cellOrigin を足す）
  public func paperPoints(cellOrigin: CGPoint) -> [CGPoint]
  /// 紙座標の外接矩形: 点の min/max を、最大の太さの半分だけ広げる（Web 版 strokeBBox）。点が無ければ nil
  public func paperBounds(cellOrigin: CGPoint) -> CGRect?
  /// 平行移動した複製（**新しい id**、t は `at`、dev は引き継ぐ）。点は紙座標で delta 動かし、新しいマス newCell の左上 newCellOrigin からの相対に直す。
  /// 0.1 丸めはそのまま InkPoint の init が行う
  public func translated(by delta: CGVector, from cellOrigin: CGPoint, to newCell: CellKey, newCellOrigin: CGPoint, id: String = InkStroke.newId(), at ms: Int) -> InkStroke
}
```

投げなわの判定に使う点は **台帳に保存している制御点（`InkStroke.points`）を紙座標にしたもの** です（Web 版も保存した点で判定する）。DESIGN §3.6 の `interpolatedPoints(by: .distance(4))` は使いません（PencilKit の制御点は十分に密で、純粋関数で検査できるため。意図したずれ）。

## 3. Ink（担当 I）: 道具、選択、移動、予定ツールの入力、スナップショット

### 3.1 CanvasTool（`InkTools.swift`）

```swift
enum CanvasTool: Equatable {
  case ink(InkStyle)
  case eraser
  case lasso        // 投げなわ（DESIGN §3.6）
  case eventRect    // 予定ツール（矩形のドラッグ／タップ）
  var isEraser: Bool; var style: InkStyle?
  /// 線を描かない道具（lasso / eventRect）。このあいだ PKCanvasView の drawingGestureRecognizer は無効
  var isOverlayTool: Bool
  /// PKCanvasView.tool。lasso / eventRect のときは直前のインクの道具のまま（描画は無効なので何でもよい。`PKInkingTool(.pen, …)` の既定でよい）
  var pkTool: PKTool
}
```

### 3.2 InkLedger の追加（`InkLedger.swift`。UIKit を import しないまま）

```swift
@MainActor final class InkLedger {
  // 既存の API はそのまま
  /// 生きている線（墓標の無い）だけを ids の順に返す（無い id は飛ばす）
  func strokes(ids: [String]) -> [InkStroke]
  /// 紙座標の外接矩形（stroke.paperBounds(cellOrigin: cells[cell].origin)）。マスが layout に無い線は nil
  func paperBounds(of id: String) -> CGRect?
  /// 複数の線の外接矩形の和（LassoGeometry.union）。無ければ nil
  func paperBounds(ids: [String]) -> CGRect?
  /// 線を消す 1 操作（履歴は `.remove(strokes)`、元に戻すと新しい id の複製で戻る）。生きていない id は無視。何も消さなければ空の InkChange
  func removeStrokes(ids: [String]) -> InkChange
  /// 選択の移動: 元の線を墓標にし、delta だけ動かした複製（新しい id）を足す **1 つの batch 操作**。
  /// 複製の所属マスは動かした後の外接矩形の中心で `layout.inkCell(forCenter:)` から決め直す（DESIGN §3.7）。
  /// 返り値の `newIds` は ids と同じ順（元の線が生きていなかったものは落ちる）。delta が (0, 0) なら何もしない
  func moveStrokes(ids: [String], by delta: CGVector) -> (change: InkChange, newIds: [String])
}
```

- `removeStrokes` / `moveStrokes` のあとは `drawing()` を作り直して canvas に入れる（担当 I の Coordinator がやる）。`applyCanvasChange` の指紋の対応表は `drawing()` が作り直す。
- `needsMoreRoom` は移動した複製にも使う（動かした先のマスが伸びる）。

### 3.3 InkCanvasView の引数（`InkCanvasView.swift`）

```swift
/// 投げなわで選んだ線。bbox は紙座標（lu）、viewRect は InkCanvasView 自身の座標（pt。スクロール・ズームのたびに更新して通知する）
struct InkSelection: Equatable {
  var ids: [String]
  var bbox: CGRect
  var viewRect: CGRect
}

/// 担当 U からキャンバスへの命令（undoTrigger と同じ「値が変わったら 1 回」方式）
enum CanvasCommand: Equatable {
  case clearSelection
  case deleteSelection                 // 選択中の線を removeStrokes（1 操作）→ 選択解除
  case removeStrokes([String])         // 「予定にする」の後始末（1 操作）。選択中なら選択解除
}

struct InkCanvasView: UIViewRepresentable {
  // M3a の引数はそのまま（layout, paper, tool, allowFinger, page, initialScrollY, onTap, onInkBoundsChanged,
  //   undoTrigger, redoTrigger, onPencilToggle, onHistoryChanged）
  var onSelectionChange: (InkSelection?) -> Void = { _ in }
  /// 予定ツール: ドラッグが終わった（矩形は紙座標、正規化済み）。isTap はドラッグ距離 < 8 lu
  var onEventRect: (_ rect: CGRect, _ isTap: Bool) -> Void = { _, _ in }
  /// 予定ツール: ドラッグ中の矩形（紙座標）→ 吸着した矩形（担当 U は layout.previewRect(for:now:) を返す）。nil なら生の矩形を描く
  var onEventPreview: (CGRect) -> CGRect? = { _ in nil }
  var command: CanvasCommand? = nil
  var commandTrigger: Int = 0
  /// スクリーンショットモード用: 最初の倍率が決まった直後に 1 回だけこの id を選択状態にする（無い id は無視）
  var initialSelectionIds: [String] = []
}
```

細則
- **overlay**: `InkCanvasContainerView` に `InkOverlayView`（§3.4）を PKCanvasView の **上** に重ねる（`frame = bounds`）。`tool.isOverlayTool` のときだけ `isUserInteractionEnabled = true`。`hitTest` は Pencil（`touch.type == .pencil`）と、`allowFinger` のときの指（`.direct`）だけを取り、それ以外は nil を返して下の PKCanvasView（スクロール・ピンチ・指タップ）に通す。
- `tool` が lasso / eventRect のあいだ `canvasView.drawingGestureRecognizer.isEnabled = false`。それ以外は true に戻す。
- **選択の解除**: `tool` が `.lasso` 以外に変わったとき、ページが変わったとき（`resetScroll` の経路）、`command == .clearSelection`。消しゴムやペンで線が消えたとき・undo/redo・外からの `page` の reload のあとは、選択から生きていない id を落とし（`ledger.page.isLive`）、残りが無ければ解除（Web 版 `_reconcileSelection`）。
- **通知**: 選択が変わったとき、スクロール・ズームで `viewRect` が動いたとき（`scrollViewDidScroll` / `scrollViewDidZoom` のたび。同じ値なら送らない）、`onSelectionChange` を `deliver` 経由で呼ぶ。`viewRect = (bbox × zoom − contentOffset)` を container の座標で。
- **命令**: `commandTrigger` が変わったら `command` を 1 回だけ実行（`lastCommandTrigger` を持つ）。ペンが触れているあいだは `pendingDrawing` と同じ待ち行列に乗せ、離れて 300 ms 後に実行。
- **initialSelectionIds**: `containerDidLayout` の最初の 1 回（`hasInitialZoom` が立つとき）に `ledger.strokes(ids:)` が空でなければ選択にする。
- `onInkBoundsChanged` は移動・削除のあとも呼ぶ（伸びたマスが縮む・伸びる）。`publishPage()` と `notifyHistory()` も同じ。

### 3.4 InkOverlayView（`InkOverlayView.swift`。UIKit、担当 I の私物。見た目は Web 版 surface.js と同じ）

入力は `UIGestureRecognizer` ではなく `touchesBegan/Moved/Ended/Cancelled` で 1 本の接触だけを追う（2 本目は無視。Pencil 優先: 指の接触中に Pencil が来たら指の gesture を取り消す）。座標は `canvas.contentOffset` と `zoomScale` で紙座標に直す。

| 道具 | 動き |
| --- | --- |
| 投げなわ（新規） | 触れた点が **選択の枠の中**（`bbox` を画面上 12 pt 広げた矩形）なら「移動」、それ以外は選択を解除して「投げなわ」。投げなわ: 前の頂点から 2 lu 以上離れたら頂点を足す。離したら `LassoGeometry.lassoPolygon(points)`。nil（タップ）なら何もしない（解除は触れた時点で済んでいる）。多角形があれば、外接矩形が重なる線だけ `strokeInLasso(points: stroke.paperPoints(cellOrigin:), polygon:, bounds:)` で選び、1 本以上なら選択にする |
| 移動 | 画面上 6 pt 動くまでは始めない（Pencil のタップの揺れ）。始めたら、選んだ線を **キャンバスの drawing から除いた drawing** を 1 回だけ入れ（`isApplyingDrawing` で差分を取らせない）、選んだ線の絵（`InkSnapshot.image(strokes:cells:zoom:)`、§3.5。マーカーは multiply）を overlay の layer に載せて指に追従させる。移動量は `LassoGeometry.clampedMoveDelta(bbox:dx:dy:pageSize: layout.size)` で制限し、0.1 lu に丸める。離したら `ledger.moveStrokes(ids:by:)` → `setDrawing(ledger.drawing())` → **選択は複製に移る**（`newIds`）。移動が 0 なら元の drawing に戻すだけ。取り消し（`touchesCancelled`、ページ変更、道具の変更）は元の drawing に戻す |
| 予定ツール | 触れた点から矩形をドラッグ。`maxDistance`（始点からの最大距離、lu）を追う。動くたびに `onEventPreview(正規化した矩形)`、返った矩形（nil なら生の矩形。幅か高さが 0 なら描かない）を描く。離したら `onEventRect(正規化した矩形, isTap: maxDistance < 8)`。取り消しは何も呼ばない |

描くもの（すべて画面上の pt で太さを決める。倍率に依らない）:
- 投げなわの線: polyline、accent `#2563eb`、1.5 pt、破線 `[6, 4]` pt。
- 選択の枠: bbox を画面上 6 pt 広げた角丸 4 pt の矩形、accent 1.5 pt、破線 `[6, 4]` pt。移動中は移動量だけずらす。
- 予定のプレビュー: 塗り `rgba(37, 99, 235, 0.18)`、枠 `rgba(37, 99, 235, 0.85)` 1.5 pt、角丸 6 pt。
- overlay は `backgroundColor = .clear`、`isOpaque = false`。描画は `draw(_:)`（CoreGraphics）。スクロール・ズームのたびに `setNeedsDisplay()`（Coordinator の `syncPaperFrame` から呼ぶ）。

### 3.5 InkSnapshot（`InkSnapshot.swift`。UIKit + PencilKit。担当 U も呼ぶ）

```swift
enum InkSnapshot {
  /// 選んだ線を白地に描いた画像（作成シートの「書いた内容」）。
  /// 外接矩形（LassoGeometry.union(各 stroke.paperBounds)）を 12 lu 広げ、maxSize（pt）に収まる倍率（4 倍まで）で
  /// `PKDrawing(strokes:).image(from: rect, scale: zoom × scale)`。線が無い・マスが cells に無い線だけなら nil
  static func render(strokes: [InkStroke], cells: [CellKey: CGRect], maxSize: CGSize = CGSize(width: 480, height: 240), scale: CGFloat = UIScreen.main.scale) -> UIImage?
  /// 移動中の絵（透明地、紙座標 bounds をそのまま zoom 倍で）。担当 I の私物
  static func image(strokes: [InkStroke], cells: [CellKey: CGRect], bounds: CGRect, zoom: CGFloat, scale: CGFloat) -> UIImage?
  /// 台帳の線 → PKStroke（InkLedger.makePKStroke と同じ変換。`transform` はマス左上への平行移動）
  static func pkStrokes(_ strokes: [InkStroke], cells: [CellKey: CGRect]) -> [PKStroke]
}
```

- `render` は `UIGraphicsImageRenderer` で白（`#ffffff`）を敷き、その上に PencilKit の画像（`PKDrawing.image(from:scale:)`、`traitCollection` は light）を描く。マーカーは PencilKit 自身の半透明のまま。
- `InkLedger.makePKStroke` の中身（点列 → `PKStrokePoint`、`PKStrokePath(controlPoints:creationDate:)`、指紋の衝突回避）は `StrokeGeometry.makePKStroke(_:cellOrigin:avoiding:)` に出して `InkSnapshot` と共用する（InkLedger.swift は UIKit を import しないまま。InkSnapshot.swift だけが UIKit を import する）。

## 4. 画面と予定の書き込み（担当 U）

### 4.0 UserDefaults の鍵（`Persistence/AppSettings.swift`）

```swift
enum AppSettings {
  static let defaultCalendarIdKey = "defaultCalendarId"          // String?。予定の登録先（calendarIdentifier）。無ければ EKEventStore.defaultCalendarForNewEvents
  static let eraseInkAfterConvertKey = "eraseInkAfterConvert"    // Bool。既定 true（本人の決定）
  static let allowFingerKey = "allowFingerDrawing"               // Bool。既存。既定: iPad false、iPhone・Mac true（`allowFingerDrawingChosen` で初回に決める。M2 のまま）
  static let lastKindKey = "lastPageKind"                        // 既存。無ければ iPad .month、iPhone .week（DESIGN §2.11）
  static let lastFocusKey = "lastFocusDate"                      // 既存
  static let hiddenCalendarIdsKey = "hiddenCalendarIds"          // 既存（EventStoreModel.hiddenKey）
  static let onboardingDoneKey = "onboardingDone"                // 既存
  // "toolbar.penColor" / "toolbar.penWidth" / "toolbar.markerColor" は ToolbarView のまま
  static var defaultCalendarId: String? { get set }
  static var eraseInkAfterConvert: Bool { get set }              // object(forKey:) == nil なら true
}
```

`CalendarRootScreen` の `static let lastKindKey / lastFocusKey` は `AppSettings` に移す（値は同じ）。スクリーンショットモードでは読まない・書かない（M2）。

### 4.1 EventKit の書き込み（`Calendar/EventDraft.swift`、`EventKitService.swift`、`EventStoreModel.swift`）

```swift
/// シートが扱う予定の内容（Web 版 EventInput）。終日の end は **翌日 0 時（排他）**（LayoutEvent と同じ）
struct EventDraft: Equatable {
  var title: String
  var allDay: Bool
  var start: Date
  var end: Date
  var calendarId: String            // 登録先（作成）／予定のカレンダー（編集。変更不可）
  var location: String
  var notes: String
  init(range: EventRange, calendarId: String)     // title "" / location "" / notes ""
  init(detail: EventDetail)                        // 編集の初期値
}

/// 繰り返しの予定の保存・削除の範囲（DESIGN §4.6）
enum EventSpan: Equatable { case thisEvent, futureEvents }   // → EKSpan.thisEvent / .futureEvents

/// 書き込みの失敗。`errorDescription` は日本語（トーストとシートにそのまま出す）
enum EventWriteError: LocalizedError, Equatable {
  case noAccess                 // 「カレンダーへのアクセスが許可されていません」
  case noWritableCalendar       // 「予定を登録できるカレンダーがありません」
  case calendarNotFound         // 「登録先のカレンダーが見つかりません」
  case readOnlyCalendar         // 「このカレンダーは変更できません」
  case eventNotFound            // 「予定が見つかりません（別の端末で削除されたかもしれません）」
  case invalidRange             // 「終了は開始より後にしてください」
  case failed(String)           // EventKit のエラー文をそのまま（「保存できませんでした: …」）
}

/// 設定画面・シートに出すカレンダー（EKCalendar の薄い写し。スクリーンショットモードでは見本）
struct CalendarOption: Identifiable, Equatable {
  var id: String                // calendarIdentifier
  var title: String
  var colorHex: String
  var sourceTitle: String       // EKSource.title（「iCloud」「Gmail」…）。見本は「見本」
  var isWritable: Bool          // allowsContentModifications
  var isSubscribed: Bool        // type == .subscription
  var isBirthday: Bool          // type == .birthday
}
```

```swift
@MainActor final class EventKitService {
  // 既存はそのまま
  /// 書き込みできるカレンダー: allowsContentModifications、誕生日（.birthday）と購読（.subscription）を除く。並びは calendars と同じ
  func writableCalendars() -> [EKCalendar]
  /// 登録先: preferredId が書き込み可能ならそれ、違えば store.defaultCalendarForNewEvents（書き込み可能なら）、違えば writableCalendars().first
  func calendarForNewEvents(preferredId: String?) -> EKCalendar?
  func calendar(withId id: String) -> EKCalendar?
  /// EKEvent(eventStore:) を作って apply(draft) → save(span: .thisEvent, commit: true)。返り値は LayoutEvent の id（layoutId(for:)）
  @discardableResult func create(_ draft: EventDraft) throws -> String
  /// 直近の取得（fetched）にある予定を draft で書き換えて save(span:commit: true)。カレンダーは変えない
  func update(eventId: String, with draft: EventDraft, span: EventSpan) throws
  func delete(eventId: String, span: EventSpan) throws
  /// hasRecurrenceRules || isDetached（直近の取得に無ければ false）
  func isRecurring(eventId: String) -> Bool
  /// calendar.allowsContentModifications（直近の取得に無ければ false）
  func isEditable(eventId: String) -> Bool
  /// draft → EKEvent の項目（テスト用に公開。保存はしない）:
  ///   title（trim。空なら「（無題）」にはせず空のまま保存する: EventKit は空題名を許す）、location（trim。空なら nil）、notes（末尾の空白を落とす。空なら nil）、
  ///   isAllDay、startDate / endDate: 時間指定はそのまま。終日は startDate = 初日 0:00、endDate = **最終日 23:59:59**（= draft.end − 1 秒。EventKit が返す形と同じ。読み戻しは exclusiveAllDayEnd が翌 0 時に直す）、
  ///   calendar: 作成は draft.calendarId のカレンダー（無ければ throw .calendarNotFound）、更新は変えない
  static func apply(_ draft: EventDraft, to event: EKEvent, calendar: EKCalendar?) throws
}
```

細則
- `create` の前提: `accessState.canRead`（.fullAccess）でなければ `.noAccess`。書き込み可能なカレンダーが無ければ `.noWritableCalendar`。`draft.end <= draft.start` なら `.invalidRange`。
- `update` / `delete` の対象は `event(withLayoutId:)`（`calendarItemIdentifier@occurrence`。DESIGN §4.6）。無ければ `.eventNotFound`。`calendar.allowsContentModifications == false` なら `.readOnlyCalendar`。
- `save` / `remove` が投げたエラーは `.failed(error.localizedDescription)`。
- 書き込みのあと `EKEventStoreChanged` が来る（1 秒デバウンス）が、待たずに `EventStoreModel.reload()` を呼ぶ（下記）。

```swift
@MainActor final class EventStoreModel: ObservableObject {
  // 既存はそのまま
  /// 設定・シート用（EKSource ごとにまとめるのは画面側）。スクリーンショットモードでは ScreenshotMode.calendars の 4 つ（全部 isWritable、sourceTitle「見本」）
  var calendarOptions: [CalendarOption]
  var writableCalendarOptions: [CalendarOption]                   // isWritable のもの
  /// 登録先の id: AppSettings.defaultCalendarId が writable にあればそれ、無ければ service.calendarForNewEvents(preferredId: nil)?.calendarIdentifier（見本は "demo-personal"）
  var defaultCalendarId: String?
  func setDefaultCalendarId(_ id: String?)                        // AppSettings に書く
  func create(_ draft: EventDraft) throws                         // service.create → reload()
  func update(eventId: String, with draft: EventDraft, span: EventSpan) throws   // → reload()
  func delete(eventId: String, span: EventSpan) throws            // → reload()
  func isRecurring(eventId: String) -> Bool
  func isEditable(eventId: String) -> Bool                        // スクリーンショットモードは true
  /// 既存 detail(forEventId:) はそのまま（EventDetail に `calendarId: String` と `isRecurring: Bool`、`isEditable: Bool` を足す）
}
```

スクリーンショットモードの `create/update/delete` は何もしないで成功する（シートが閉じてトーストが出る）。

### 4.2 投げなわのメニュー（`Views/SelectionMenuView.swift`）

```swift
struct SelectionMenuView: View {
  var onConvert: () -> Void      // 「予定にする」（primary）
  var onDelete: () -> Void       // 「削除」
  var onDeselect: () -> Void     // 「選択解除」
}
```

- 丸いカプセル（`.regularMaterial`、角丸 14、影）に 3 つのボタンを横並び（高さ 44 pt）。accessibilityLabel はそのままの文言。
- 置き場所: `CalendarRootScreen` がキャンバスの上に `overlay(alignment: .topLeading)` で置き、`selection.viewRect` の **上 10 pt**（上に入らなければ下 10 pt、どちらも入らなければ枠の上端 + 10 pt）に、横は枠の中央に揃えて画面の内側（8 pt の余白）へ clamp（Web 版 placeMenu）。シートが出ているあいだは隠す。
- 「削除」→ `CanvasCommand.deleteSelection`。「選択解除」→ `.clearSelection`。「予定にする」→ §4.5 の流れ。

### 4.3 作成・編集・閲覧のシート（`Views/EventEditorSheet.swift`、`Views/EventEditorForm.swift`）

```swift
enum EventEditorMode: Equatable {
  case create
  case edit(eventId: String, recurring: Bool)
  case readOnly(eventId: String)          // calendar.allowsContentModifications == false
}

enum EventEditorResult {
  case save(EventDraft, span: EventSpan?, eraseInk: Bool)    // span は繰り返しの編集のときだけ非 nil
  case delete(span: EventSpan?)
  case cancel
}

struct EventEditorSheet: View {
  var mode: EventEditorMode
  var draft: EventDraft                     // 初期値
  var calendars: [CalendarOption]           // 作成: writable だけ／編集・閲覧: その予定のカレンダー 1 つ
  var snapshot: UIImage?                    // 投げなわ →「予定にする」のときだけ
  var showEraseOption: Bool                 // 同上
  var eraseDefault: Bool                    // AppSettings.eraseInkAfterConvert
  /// 保存・削除を実行する。throw したらシートは閉じずに footer に赤字で errorDescription を出す（Web 版 onSubmit）
  var onSubmit: (EventEditorResult) async throws -> Void
  var onCancel: () -> Void
}

/// 純粋な状態（Web 版 formFromInput / inputFromForm / toggleAllDay / moveStart / moveEnd）
struct EventEditorForm: Equatable {
  var title: String; var location: String; var notes: String
  var allDay: Bool
  var startDay: DayKey; var endDay: DayKey          // 終日: 開始日・終了日（**終了日は含む**）／時間指定: 開始・終了の日
  var startMinute: Int; var endMinute: Int         // 時間指定の分（0…1439）。終日のあいだも保持（戻したとき復元）
  init(draft: EventDraft, calendar: Calendar = DayKey.deviceCalendar)      // 終日: endDay = DayKey(end − 1 秒)。時間指定で end ≤ start なら end = start + 1 h
  func draft(calendarId: String, calendar: Calendar = DayKey.deviceCalendar) -> Result<EventDraft, EventFormError>
  mutating func setAllDay(_ on: Bool)              // 時間指定→終日: endDay = DayKey(end)（end がちょうど 0 時で start より後なら前日）。終日→時間指定: 同じ日に startMinute/endMinute（既定 9:00/10:00）、end ≤ start なら +1 h
  mutating func setStart(_ date: Date)             // **長さを保つ**（時間指定は分、終日は日数）
  mutating func setEnd(_ date: Date)               // 時間指定: end ≤ start なら start + 1 h／終日: endDay < startDay なら startDay
  var start: Date; var end: Date                   // 時間指定の瞬間
}
enum EventFormError: Equatable, LocalizedError {
  case emptyTitle          // 「タイトルを入力してください」
  case endBeforeStart      // 「終了は開始より後にしてください」
  case endDayBeforeStart   // 「終了日は開始日以降にしてください」
}
```

見た目（`NavigationStack` + `Form`。iPad は標準の form sheet、iPhone は `.presentationDetents([.large])`）:
1. 題名: 「予定を追加」「予定を編集」「予定の詳細」（readOnly）。左に「キャンセル」（readOnly は「閉じる」）、右に「保存」（readOnly は無し）。
2. `snapshot` があれば先頭に画像（幅いっぱい、最大高さ 160 pt、白地、角丸 8、下に「書いた内容」のキャプション）。
3. 「タイトル」`TextField`（placeholder 「ここにペンで書くと文字になります」、`.font(.title3)`、`submitLabel(.done)`）。**自動フォーカスしない**。iPad では下に注記「Apple Pencil で欄の上に書くと、文字に変換されます（スクリブル）」（`.footnote` `.secondary`）。空のまま保存 → 欄の下に赤字「タイトルを入力してください」＋フォーカス。
4. 「終日」`Toggle`。
5. 時間指定: 「開始」`DatePicker(displayedComponents: [.date, .hourAndMinute])`、「終了」同じ。終日: 「開始日」「終了日」（`.date`、終了日は含む）。変更は `EventEditorForm.setStart/setEnd` を通す。
6. 「カレンダー」: 作成は `Picker`（色の丸＋題名。`calendars` が 1 つなら固定表示）。編集・閲覧は固定の行（色の丸＋題名）。
7. 「場所」`TextField`、「メモ」`TextEditor`（最小高さ 80 pt）。
8. `showEraseOption` なら「この手書きを消す」`Toggle`（初期値 `eraseDefault`）。
9. 編集（recurring）: 注記「繰り返しの予定です。保存・削除のときに「この回だけ」か「以降すべて」を選びます」。
10. 編集: 最後に赤い「削除」ボタン → `confirmationDialog`「この予定を削除しますか？」（「削除」destructive／「キャンセル」）→ recurring なら続けて §4.4 → `onSubmit(.delete(span:))`。
11. readOnly: 全項目 `disabled`、footer に「このカレンダーは変更できません（読み取り専用）」。
12. 保存: `form.draft(calendarId:)` → エラーなら赤字（3・5 の下）。OK なら recurring なら §4.4 → `onSubmit(.save(draft, span:, eraseInk:))`。実行中は「保存中…」で全ボタン無効。throw なら footer に赤字（`errorDescription`、無ければ「保存できませんでした」）。
13. `interactiveDismissDisabled` はしない（下にスワイプで閉じる＝キャンセル）。

`DatePicker` は分の刻みを指定できないので、任意の分を受け付けます（Web 版の 5 分刻みとは違う。意図したずれ）。

### 4.4 繰り返しの範囲（`Views/RecurrenceScopeDialog.swift`）

```swift
/// confirmationDialog の中身。`kind` で文言を変える
enum RecurrenceScopeKind { case save, delete }
extension View {
  func recurrenceScopeDialog(isPresented: Binding<Bool>, kind: RecurrenceScopeKind, onChoose: @escaping (EventSpan) -> Void) -> some View
}
```

- 題: 「繰り返しの予定です」。message: save「この回だけ変更しますか？ 以降すべてに適用しますか？」／delete「この回だけ削除しますか？ 以降すべて削除しますか？」。
- ボタン: 「この回だけ」→ `.thisEvent`、「以降すべて」→ `.futureEvents`（delete では `.destructive`）、「キャンセル」。

### 4.5 CalendarRootScreen の流れ

状態の追加: `selection: InkSelection?`、`editor: EventEditorRequest?`（`Identifiable`: `mode`, `draft`, `calendars`, `snapshot`, `inkIds: [String]`）、`command: CanvasCommand?`、`commandTrigger`、`showSettings`、`toast: ToastMessage?`、`isCompact: Bool`（§4.6）。

| 入口 | 動き |
| --- | --- |
| 予定ツールのドラッグ `onEventRect(rect, isTap: false)` | `range = layout.eventRange(for: rect, now:)` → `openCreate(range:, snapshot: nil, inkIds: [])` |
| 予定ツールのタップ `onEventRect(rect, isTap: true)` | `layout.hit(at: rect の中心)` が `.allDayBar/.timedChip/.timedBox` なら `openEdit(eventId:)`。それ以外は `openCreate(range: layout.eventRange(for: rect, now:))`（月・年ではタップでその日の終日。週・日ではその半時間から 1 時間） |
| 予定ツールのプレビュー `onEventPreview(rect)` | `layout.previewRect(for: rect, now:)` を返す |
| 「＋予定」 | `today = DayKey(now)`。週・日: `EventRange.timed(today, 540, 600)`（9:00〜10:00）／月・年: `EventRange.allDay(today)`（DESIGN §4.5） |
| 投げなわ →「予定にする」 | `range = layout.eventRange(for: selection.bbox, now:)`、`snapshot = InkSnapshot.render(strokes: selection.ids.compactMap { page.strokes[$0] }, cells: layout.cells)`、`openCreate(range:, snapshot:, inkIds: selection.ids)`（showEraseOption = true） |
| 指タップ `.allDayBar/.timedChip/.timedBox` | `openEdit(eventId:)`（M3a の詳細シートの代わり） |
| `.moreChips/.date` | 日ページへ（M3a のまま） |

- `openCreate`: `model.status.canRead` でなければトースト「予定を登録するには、設定でカレンダーへのアクセスを許可してください」。`writableCalendarOptions` が空ならトースト「予定を登録できるカレンダーがありません」。`range` が nil なら何もしない。`draft = EventDraft(range:, calendarId: model.defaultCalendarId!)`、`editor = (.create, draft, writableCalendarOptions, snapshot, inkIds)`。
- `openEdit(eventId:)`: `detail = model.detail(forEventId:)` が無ければ何もしない。`mode = model.isEditable(eventId) ? .edit(eventId:, recurring: model.isRecurring(eventId)) : .readOnly(eventId:)`。`draft = EventDraft(detail:)`、`calendars = [その予定の CalendarOption]`。
- `onSubmit`:
  - `.save(draft, span, eraseInk)` の create: `try model.create(draft)` → 成功で `editor = nil`、`AppSettings.defaultCalendarId = draft.calendarId`（最後に使った登録先を覚える）、`inkIds` が空でなく `eraseInk` かつ `page.pageId` が同じなら `command = .removeStrokes(inkIds); commandTrigger += 1`、それ以外で選択中なら `.clearSelection`、トースト「予定を登録しました」。
  - edit: `try model.update(eventId:, with: draft, span: span ?? .thisEvent)` → トースト「予定を更新しました」。
  - `.delete(span)`: `try model.delete(eventId:, span: span ?? .thisEvent)` → トースト「予定を削除しました」。
  - throw はシートが受けて赤字に出す（§4.3 の 12）。
- シートが開いているあいだ選択のメニューは隠す。シートを閉じても選択は残る（キャンセル時に続きができる）。
- `relayout()` は `model.events` の変化で走る（M3a のまま）。

### 4.6 ヘッダー（`Views/PageHeaderView.swift`）

```
幅 ≥ 600 pt:  ◀  今日  ▶   題名                 [日 | 週 | 月 | 年]   ＋予定   ⚙
幅 < 600 pt:  ◀  今日  ▶   題名                                       ＋予定   ⚙
              [      日      |      週      |      月      |      年      ]
```

```swift
struct PageHeaderView: View {
  var kind: PageKind; var title: String
  var compact: Bool                       // 幅 < 600 pt（CalendarRootScreen が GeometryReader で測る）
  var onPrevious, onToday, onNext: () -> Void
  var onKindChange: (PageKind) -> Void
  var onAddEvent: () -> Void              // 「＋予定」。accessibilityLabel「予定を追加」。Label("予定", systemImage: "plus")
  var onSettings: () -> Void              // ⚙（"gearshape"）。accessibilityLabel「設定」
}
```

- M3a の `trailing`（📅 のメニュー）は **削除**（表示するカレンダーは設定画面へ。DESIGN §2.7 のヘッダーに 📅 は無い）。
- `compact` のときセグメントは 2 段目に幅いっぱい（`frame(maxWidth: .infinity)`）、1 段目の題名は `.title3`。
- 許可の案内行（`accessNotice`）は M3a のまま。
- 同期の状態は M4（出さない）。

### 4.7 ツールバー（`Views/ToolbarView.swift`）

- ボタンの並び（Web 版と同じ）: ペン／マーカー／消しゴム／**投げなわ**（"lasso"、「投げなわ」）／**予定**（"calendar.badge.plus"、「予定」）｜ 文脈の領域 ｜ ↶ ↷ ｜ 指でも書く。
- 文脈の領域: ペン → 色と太さ、マーカー → 色、消しゴム → 「触れた線をまるごと消します」（M2）、投げなわ → 「囲んで選びます。枠の中をドラッグで動かせます」、予定 → 「なぞって予定を作ります。予定をタップすると編集します」（`.caption` `.secondary`）。
- 横スクロール（`ScrollView(.horizontal)`）は M2 のまま。iPhone ではそのまま横にスクロールする。
- `lastInkTool` は `.ink` のときだけ更新（M3a のまま）。Pencil のダブルタップは lasso / eventRect からでも消しゴムへ、戻りは `lastInkTool`。

### 4.8 設定画面（`Views/SettingsScreen.swift`。`.sheet`、`NavigationStack` + `Form`、題「設定」、右上「完了」）

```swift
struct SettingsScreen: View {
  @ObservedObject var model: EventStoreModel
  @Binding var allowFinger: Bool
  var onRequestAccess: () async -> Void
  var onEraseAllInk: () -> Void          // 2 回目の確認のあとに呼ぶ（CalendarRootScreen が store.removeAll() と現在ページの空化をする）
  var onDone: () -> Void
}
```

| Section | 行 | 動き・文言 |
| --- | --- | --- |
| 「カレンダー」 | 「表示するカレンダー」: `calendarOptions` を `sourceTitle` ごとに小見出し（並びは sourceTitle、中は title）。各行 = 色の丸（10 pt）＋ title ＋ 右にチェック（表示中は `checkmark`） | タップで `model.setHidden(…)`。`calendarOptions` が空: `canRead` なら「カレンダーがありません」、違えば「カレンダーへのアクセスを許可すると、ここに一覧が出ます」 |
| | 「予定の登録先」`Picker`（writable、色の丸＋title。`navigationLink` スタイル） | `model.setDefaultCalendarId`。writable が無ければ行を出さない |
| | 「カレンダーへのアクセス」: 状態の文（fullAccess「許可されています（フルアクセス）」／notDetermined「まだ許可していません」／denied「許可されていません」／writeOnly「追加のみ（予定を表示できません）」／restricted「この iPad では制限されています」） | notDetermined → ボタン「許可する」（`onRequestAccess`）。denied・writeOnly → 「設定アプリを開く」（`UIApplication.openSettingsURLString`）。restricted → ボタン無し |
| | 「Google カレンダーを使うには」`DisclosureGroup` | 本文は `OnboardingView` の 1 枚目と同じ文（①〜③）＋「設定アプリを開く」 |
| 「入力」 | 「指でも書く」`Toggle(allowFinger)` | footer「オンにすると指でも線が引けます。オフのときは指でスクロールとタップをします。手書きは iPad と Apple Pencil で書くのに向いています」 |
| | 「Apple Pencil」（iPad だけ） | 文「ダブルタップ／スクイーズは、iPad の「設定 › Apple Pencil」で選んだ動作に従います」＋ボタン「設定アプリを開く」 |
| | 「予定にした手書きを消す」`Toggle` | `AppSettings.eraseInkAfterConvert`。footer「投げなわで囲んだ手書きを予定にしたあと、その手書きを消すかどうかの初期値です」 |
| 「同期」 | 「iCloud 同期」 | 行の右に「準備中」（`.secondary`）、無効。footer「iCloud での同期は次の段階で対応します。いまは手書きをこの iPad の中だけに保存しています。」 |
| 「データ」 | 「Web 版の手書きを取り込む」「手書きを書き出す」 | 「準備中」、無効 |
| | 「この iPad の手書きを全て消す」（`.destructive`） | 1 回目 `confirmationDialog`「この iPad に保存した手書きを全て消しますか？」（「消す」destructive）→ 2 回目 `alert`「本当に消しますか？ この操作は元に戻せません。」（「全て消す」destructive／「キャンセル」）→ `onEraseAllInk` → トースト「手書きを全て消しました」 |
| 「購入」 | 「現在のプラン」「購入を復元」「サブスクリプションの管理」 | すべて「準備中」、無効。footer「購入は次の段階で対応します。」 |
| 「情報」 | 「利用規約」「プライバシーポリシー」「サポート」`Link` | `https://syfan0-star.github.io/tegaki-calendar/ios/terms.html` ／ `…/ios/privacy.html` ／ `…/ios/support.html`（仮の URL。M5 で確定） |
| | 「バージョン」 | 右に `CFBundleShortVersionString (CFBundleVersion)`（例 「0.4.0 (1)」） |

`InkPageStore` に `func removeAll() throws`（`directory` の中の `*.json.lzfse` と `*.bak` を全部消す）を足す。`onEraseAllInk` は `saveTask` を止め、`store.removeAll()`、`page = InkPage.empty(pageId:)`（キャンバスは外からの `page` として `reload(keepHistory: false)` に乗る）、`pageDirty = false`。

### 4.9 トースト（`Views/ToastView.swift`）

```swift
struct ToastMessage: Equatable, Identifiable { var id: UUID; var text: String; var isError: Bool }
struct ToastView: View { var message: ToastMessage }    // 画面下（ツールバーの上 8 pt）、カプセル、3 秒で消える（エラーは 6 秒）
```

`CalendarRootScreen.showToast(_ text: String, isError: Bool = false)`。文言の一覧: 「予定を登録しました」「予定を更新しました」「予定を削除しました」「手書きを全て消しました」、エラーは `EventWriteError.errorDescription` と上記の 2 つ（アクセス・登録先なし）。

## 5. スクリーンショットモード（担当 U、`Support/ScreenshotMode.swift`）

```swift
enum ScreenshotMode {
  enum Sheet: String, CaseIterable, Sendable { case create, edit, lasso, settings }
  struct Config: Equatable, Sendable { var page: PageKind; var month: YearMonth; var today: Date; var focus: DayKey; var sheet: Sheet? }
  // parse: --screenshot-sheet create|edit|lasso|settings（無ければ nil。不正な値は nil）。他は M3a のまま
  /// 見本のカレンダー（CalendarOption）: calendars の 4 つ、全部 isWritable、sourceTitle「見本」
  static var calendarOptions: [CalendarOption]
  /// 「予定にする」の見本の矩形と id: demoPage(for: month) の "demo-stroke-wave"（14 日のマスの波線）
  static let lassoDemoStrokeId = "demo-stroke-wave"
  /// 編集の見本: 家族旅行（"demo-3"、9〜13 日の終日、家族）
  static let editDemoEventId = "demo-3"
}
```

| `--screenshot-sheet` | ページ | 出すもの |
| --- | --- | --- |
| `create` | month | `EventEditorSheet(mode: .create, draft: EventDraft(range: .allDay(14 日), calendarId: "demo-personal"), calendars: 見本の 4 つ, snapshot: nil, showEraseOption: false)`。タイトルは空（placeholder が見える） |
| `edit` | month | `openEdit(eventId: "demo-3")`（家族旅行。`.edit(recurring: false)`、カレンダーは「家族」固定） |
| `lasso` | month | `tool = .lasso`、`initialSelectionIds: ["demo-stroke-wave"]` → 枠とメニュー「予定にする／削除／選択解除」が見える |
| `settings` | month | `SettingsScreen`（見本のカレンダー 4 つが「見本」の下に並ぶ。アクセスは「許可されています」） |

- `CalendarRootScreen.appear()` の最後で `ScreenshotMode.current?.sheet` があれば、キャンバスが出た後（`Task` で 0.5 秒待つ）にその状態にする。`page` の引数は無視して month にする（`--screenshot-page` と同時に来たら sheet が優先）。
- 保存・削除・全消去は何もしない（§4.1）。

## 6. テスト

### 6.1 TegakiKit（担当 K）: `KitChecks` に節を足し、同じ内容を XCTest にも置く

- `EventGeometry.roundMinutes`: `(547.5, 15, .nearest) == 555`（0.5 は上へ）、`(552.49, 15) == 555`（552.49/15 = 36.83 → 37）、`(547.49, 15) == 540`（36.499 → 36）、`(540.0000001, 15) == 540`（1e-9 の救済）、`(547, 30, .floor) == 540`、`(541, 30, .ceil) == 570`。
- `EventGeometry.timelineSlot`（hourHeight 100）: 上の §1.8 の日ページの分の部分を全部（`(900, 1050) → (540, 630)`、`(905, 925) → (540, 600)`、`(1270, 1281.9) → (750, 810)`、`(1270, 1282) → (765, 825)`、`(2300, 2500) → (1380, 1440)`、`(2390, 2390) → (1410, 1440)`、`(2380, 2400) → (1425, 1440)`、`(2400, 2400) → (1380, 1440)`、`(−100, −50) → (0, 60)`）。
- `eventRange` / `snapRect`: §1.8 の例を **全部**（日・週・月・年）。月のメモ欄は `now` 3 通り。年は 2026 と 2028 の全日（365 + 366）でマスの中心のタップと小さな矩形 → その日の終日、`snapRect` がそのマス。
- 不変条件: 乱数 300 回 × (日・週・月(10 月, 2 月)・年(2026, 2028)): 紙の外 100 lu までの矩形（30% はタップ大）で `eventRange` が非 nil・`isValid`・終日なら 1 日・年ページなら同じ年、`snapRect(for: range)` が非 nil、`eventRange(for: snapRect)` が同じ範囲。
- `LassoGeometry`: `pointInPolygon`（正方形 (5,5) 内・(15,5) 外・(−1,−1) 外、凹 `[0,0 10,0 10,10 5,3 0,10]` は (5,8) 外・(5,1) 内、五芒星の中心は外・(0,−8) は内、頂点 2 は false、空は false）／`strokeInLasso`（`[0,0 100,0 100,100 0,100]` に対して 4 点中 2 点で true、3 点中 1 点で false、1 点 (50,50) true、(150,50) false、点なし false、頂点 2 の多角形は false、NaN の点は数えない）、乱数 200 回で `bounds` あり・なしが同じ答え／`closedPolygon`（`[0,0 10,0 10,10]` → 4 頂点で閉じる、閉じているものはそのまま、2 頂点は nil、`[0,0 1,1 2,0]` は 4 lu 未満で nil）／`simplified`（半径 500 の円を 2 lu 刻み → ε 1 で 120 頂点未満かつ 8 以上、最初と最後が保たれる、落とした頂点は結果から 1 lu 以内）／`union`／`clampedMoveDelta`（`(100,100,100×50)` に `(50, −20)` → そのまま、`(−500, 5000)` → `(−100, 1770)`（W 1400, H 1920）、左にはみ出た `(−3, 10, 53×10)` は `(0,0)` → `(0,0)`、`(−10, 0)` → `(0,0)`、`(10,0)` → `(10,0)`）／`snapshotLayout`（`(100,100)-(476,136)` → rect `(88,88)-(488,148)`、zoom 1.2、size 480×72、`(0,0)-(2,2)` は zoom 4、高さ 2000 は height ≤ 240）。
- `InkStroke.paperBounds`（点 + 太さの半分）、`translated`（新しい id、点が delta だけ動いて新しいマスの相対になる、t が `at`）。

### 6.2 アプリ（担当 I）

`InkLedgerTests` に追加: `removeStrokes` が墓標を残して 1 操作で undo（複製の id）・redo できる／`moveStrokes` が元を墓標に、複製を新しい id で、`change.added.count == ids.count`、`newIds` の順、`batch` 1 つで undo すると元の id は戻らず複製（新しい id）で戻る／月ページで行をまたいで動かすと複製の `cell` が移動先の日になる／`delta == 0` は何もしない／生きていない id は無視。
`InkSnapshotTests`（新規、シミュレータ）: 1 本の線で `render` が非 nil、`size.width ≤ 480`・`≤ 240`、小さな線は 4 倍まで、マスが無い線だけなら nil、`pkStrokes` の `transform` がマス左上。

### 6.3 アプリ（担当 U）

- `EventEditorFormTests`（新規）: 終日の初期値（end 翌 0 時 → endDay は同じ日、3 日の予定は endDay = 3 日目）／時間指定で end ≤ start なら +1 h／`setAllDay(true)`（10:00〜11:00 → 同じ日、23:00〜翌 0:00 は 1 日）／`setAllDay(false)`（9:00〜10:00 に戻る）／`setStart` が長さを保つ（時間指定 90 分、終日 3 日）／`setEnd` の補正／`draft()` のエラー 3 種と、終日の end が翌 0 時（排他）になること。
- `EventKitServiceTests` に追加: `apply(_:to:)` の項目（終日の endDate が最終日 23:59:59、時間指定はそのまま、空の場所・メモは nil、題名の trim）。`EKEvent(eventStore:)` はアクセス無しでも作れる（保存しない）。
- `ScreenshotModeTests` に追加: `--screenshot-sheet` の 4 つと不正値 nil、`calendarOptions` が 4 つで全部 writable、`defaultCalendarId` の見本が "demo-personal"。

## 7. CI・統合（担当 C）

- `project.yml`: `MARKETING_VERSION` を **0.4.0** に。他は変更なし。
- `build.yml` のスクリーンショット: 4 ページのループのあとに 4 シートのループを足す。

```yaml
      - name: Screenshots (portrait, 4 sheets on the month page)
        if: ${{ !cancelled() && steps.simudid.outcome == 'success' }}
        continue-on-error: true
        run: |
          set -euo pipefail
          UDID="${{ steps.simudid.outputs.udid }}"
          BUNDLE="com.syfan0.tegakicalendar"
          mkdir -p shots
          for SHEET in create edit lasso settings; do
            xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
            sleep 1
            xcrun simctl launch "$UDID" "$BUNDLE" --screenshot-mode --screenshot-month 2026-10 --screenshot-page month --screenshot-sheet "$SHEET"
            sleep 9
            pgrep -fl "TegakiCalendar.app/TegakiCalendar" || echo "::warning::The app is not running after 9 s (sheet $SHEET; crashed?)"
            xcrun simctl io "$UDID" screenshot "shots/ipad-portrait-sheet-$SHEET.png"
          done
          ls -la shots
```

  成果物 `screenshots` に M3a の 4 枚に加えて `ipad-portrait-sheet-create.png`・`-sheet-edit.png`・`-sheet-lasso.png`・`-sheet-settings.png`。
- ローカル確認（この Mac）: `cd TegakiKit && swift build && swift run KitChecks`、`for f in $(find Sources Tests -name '*.swift'); do swiftc -parse -swift-version 5 "$f"; done`。
- 統合の順番: K → I と U（並行。U は K の `eventRange` ができるまでシート・設定・EventKit の書き込みを先に進める。I は K の `LassoGeometry` ができるまで overlay の入力と `InkLedger` の操作を先に進める）→ C。コンパイルの本番は CI。
- `README.md` の「いま出来ていること」と `docs/M3B.md`（実装結果の要約。M3A.md と同じ構成）は C が書く。

## 8. M4 以降に残すもの（この契約で触らない）

CloudKit 同期（ヘッダーの同期の状態、設定の「同期」）、Web 版の取り込み・書き出し、課金・ペイウォール・閲覧専用モード（B-4）、初回案内の 4 枚目、iPhone の月ページの初期倍率（B-2）、キャンバスの使い回し（DESIGN §3.10）、編集シートでのカレンダーの変更（Web 版も不可）、設定画面からの予定の色の変更。
