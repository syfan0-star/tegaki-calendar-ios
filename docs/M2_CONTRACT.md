# M2 実装契約（月ページ＋手書き＋予定の読み取り）

この文書は M2 の各担当が同時に作業するための **約束事**（公開 API・データ形状・ファイル所有）です。
設計の根拠は [DESIGN.md](DESIGN.md)（§2.2 行が伸びるレイアウト、§3 手書き、§4 予定、§8.2 モジュール分割）。
ここに無いことは DESIGN.md に従い、DESIGN.md にも無ければ Web 版（`../tegaki-calendar/docs/SPEC.md`）の流儀に合わせます。
付録 B は本人が決定済み（2026-10-11）: **B-1: 月ページで全件並べるのは終日予定だけ。時間指定の予定は Web 版と同じく、1 日 3 件まではチップ、4 件以上は 2 件＋「+n件」チップ**／B-4: 閲覧専用は作成・編集も停止／B-5: `com.syfan0.tegakicalendar`／B-7: 月 300 円・年 2,400 円・14 日無料（仮）。

## 0. 構成とファイル所有

```
TegakiKit/                         ローカル Swift パッケージ（Foundation のみの純粋モジュール）
  Package.swift                    担当 K
  Sources/Layout/                  担当 K   ページ幾何・行の高さ・マス矩形・予定の配置・当たり判定
  Sources/Holidays/                担当 K   祝日（M1 の JapaneseHolidays / DayKey を移動）
  Sources/InkModel/                担当 K   InkPage・InkStroke・merge・JSON・圧縮・マス割り当て
  Sources/KitChecks/main.swift     担当 K   Xcode 無しの Mac で走る確認用の実行ファイル（XCTest は CLT に無い）
  Tests/LayoutTests, HolidaysTests, InkModelTests   担当 K（XCTest。CI で実行）
Sources/TegakiCalendar/
  App.swift, ContentView.swift     担当 U
  Ink/InkCanvasView.swift          担当 I   PKCanvasView ＋ 紙ビューの重ね合わせ（UIViewRepresentable）
  Ink/InkLedger.swift              担当 I   台帳 ⇄ PKDrawing の変換、指紋、合成し直し、履歴
  Ink/InkTools.swift               担当 I   道具（ペン・マーカー・消しゴム）の定義と PKTool への変換
  Ink/PencilInteraction.swift      担当 I（M1 のものを流用・調整）
  Ink/PaperView.swift              担当 U   紙（罫線・日付・祝日・予定の帯とチップ・メモ欄）を描く UIView
  Calendar/EventKitService.swift   担当 U   許可・取得・正規化・変更の購読・表示カレンダーの選択
  Calendar/EventStoreModel.swift   担当 U   画面用の ObservableObject（月の予定、権限状態、再取得）
  Views/MonthPageScreen.swift      担当 U   月ページの画面（ヘッダー・ツールバー・キャンバス・予定の詳細シート）
  Views/ToolbarView.swift          担当 U
  Views/EventDetailSheet.swift     担当 U   予定の内容を表示（M2 は閲覧のみ）
  Persistence/InkPageStore.swift   担当 U   InkPage の端末内保存（Application Support/ink/<pageId>.json.lzfse）
project.yml / .github/workflows/*  担当 C（統合・CI）
docs/M2.md                         担当 C（この契約の実装結果を要約）
```

依存の向き: `TegakiCalendar` → `TegakiKit`（Layout, Holidays, InkModel）。担当 I と U は TegakiKit の API だけを通じて協調し、互いのファイルは触らない。

## 1. Layout（担当 K）

```swift
public enum PaperSpec {                      // Web 版 SPEC §3 と同じ数字（lu）
  public static let monthWidth: CGFloat = 1400
  public static let monthColumns = 7, monthRows = 6
  public static let monthColumnWidth: CGFloat = 200
  public static let monthRowBase: CGFloat = 175, monthRowMax: CGFloat = 1200
  public static let monthDateHeader: CGFloat = 28
  public static let allDayLane: CGFloat = 22, allDayGap: CGFloat = 3
  public static let timedChip: CGFloat = 20
  public static let timedChipCap = 3                 // 1 日に出す時間指定チップの上限（超えたら 2 件＋「+n件」）
  public static let monthInkMargin: CGFloat = 40, inkPad: CGFloat = 12
  public static let memoMin: CGFloat = 700, memoInkPad: CGFloat = 50
}

/// マスの鍵。月: "2026-10-04"、メモ欄: "memo"。（週・日・年の鍵は M3）
public struct CellKey: Hashable, Codable, Sendable { public let raw: String }
extension CellKey { public static func day(_ d: DayKey) -> CellKey; public static let memo: CellKey; public var day: DayKey? }

/// 予定の正規化形（Web 版 CalEvent 相当）。終日の end は **翌日 0 時（排他）** に正規化する。
public struct LayoutEvent: Hashable, Sendable {
  public var id: String; public var title: String; public var allDay: Bool
  public var start: Date; public var end: Date          // ローカル時刻
  public var colorHex: String; public var calendarId: String
}

/// 月ページの入力
public struct MonthLayoutInput: Sendable {
  public var month: YearMonth                 // 表示する月
  public var events: [LayoutEvent]            // 表示するカレンダーの予定（終日・時間指定とも）
  public var inkBottoms: [CellKey: CGFloat]   // マスごとの手書きの下端（マス相対 lu）。無ければ 0
  public var now: Date
}

/// 月ページの出力（全て紙座標 lu）
public struct MonthPageLayout: Sendable {
  public var size: CGSize                     // 紙の大きさ（幅 1400、高さ = 行の合計 + メモ欄）
  public var rows: [RowLayout]                // 6 行
  public var memo: CGRect                     // メモ欄
  public var cells: [CellKey: CGRect]         // 42 日 + memo
  public var allDayBars: [AllDayBar]          // 週ごとのレーンに並べた終日の帯（複数日は 1 本、週をまたぐと分割）
  public var timedChips: [TimedChip]          // 日ごとの時間指定チップ（全件）
  public var dateLabels: [DateLabel]          // 日付見出しの位置と種別（今日・土・日祝・月外）
  public func cell(at point: CGPoint) -> CellKey?          // 紙座標 → マス（メモ欄含む）。外なら nil
  public func hit(at point: CGPoint) -> HitTarget?         // .allDayBar(eventId) / .timedChip(eventId) / .date(DayKey)
}
public struct RowLayout: Sendable { public var index: Int; public var frame: CGRect; public var days: [DayKey]; public var laneCount: Int; public var maxChips: Int }  // maxChips は表示するチップ数の最大（上限 timedChipCap）
public struct AllDayBar: Sendable { public var eventId: String; public var frame: CGRect; public var row: Int; public var lane: Int; public var continuesLeft: Bool; public var continuesRight: Bool; public var colorHex: String; public var title: String }
public struct TimedChip: Sendable { public var eventId: String?; public var frame: CGRect; public var day: DayKey; public var timeText: String; public var title: String; public var colorHex: String; public var moreCount: Int }  // moreCount > 0 なら「+n件」チップ（eventId は nil、title は "+n件"）
public struct DateLabel: Sendable { public var day: DayKey; public var frame: CGRect; public var isToday: Bool; public var inMonth: Bool; public var tone: DayTone; public var holidayName: String? }
public enum DayTone: Sendable { case normal, saturday, sundayOrHoliday }
public enum HitTarget: Sendable { case allDayBar(String), timedChip(String), moreChips(DayKey), date(DayKey) }

public enum MonthLayoutEngine {
  public static func layout(_ input: MonthLayoutInput) -> MonthPageLayout
  /// 行の高さの式（DESIGN §2.2）。テスト用に公開。
  public static func rowHeight(laneCount: Int, maxChips: Int, inkBottom: CGFloat) -> CGFloat
  /// 終日の帯をレーンに詰める（Web 版 allDayRowsForRange と同じ規則：開始列昇順→長いもの優先→題名）。
  public static func packAllDayLanes(events: [LayoutEvent], days: [DayKey]) -> [(event: LayoutEvent, startCol: Int, endCol: Int, lane: Int)]
  /// スクロール補正（DESIGN §3.5）: 先頭の見えている行 r が動かないよう、新旧レイアウトから contentOffset.y の差分を返す
  public static func scrollDelta(old: MonthPageLayout, new: MonthPageLayout, topVisibleY: CGFloat) -> CGFloat
}
```

細則
- 行の高さ: `max(175, 28 + lanes×25 + maxChips×20 + 40, inkBottom + 12)`、上限 1200。`maxChips` はその行の 7 日のうち最大の **表示** チップ数（時間指定が 3 件以下ならその数、4 件以上なら 3 = 2 件＋「+n件」）。メモ欄: `max(700, memoInkBottom + 50)`。
- 月のグリッドは常に 6 行（42 日、月曜始まり、`MonthLayout`（M1）を流用）。行 r の frame.y は前の行の合計。
- 終日の帯の frame: 行の `y + 28 + lane×25`、x は `startCol×200 + 4`、幅 `(endCol−startCol+1)×200 − 8`、高さ 22。
- 時間指定チップ: 行の `y + 28 + laneCount×25 + i×20`、x は `col×200 + 4`、幅 192、高さ 20。`timeText` は "9:00"（終了は出さない）、開始時刻順。1 日 3 件まではすべて出し、4 件以上は先頭 2 件＋「+n件」（n = 件数 − 2）の `moreCount` 付きチップを 3 つ目に置く（Web 版と同じ）。
- 日付見出し frame: `(col×200+4, y+4, 192, 24)`。
- `cell(at:)`: 行の frame 内で列 = `floor(x/200)` を 0..6 に clamp。メモ欄の中なら `.memo`。紙の外は nil。
- 当たり判定の優先順位: チップ（「+n件」は `.moreChips(day)`）→ 帯 → 日付見出し。

## 2. InkModel（担当 K）

```swift
public struct InkPoint: Hashable, Codable, Sendable {   // PKStrokePoint の全属性（DESIGN §3.9）
  public var x: CGFloat, y: CGFloat          // マス相対 lu（0.1 丸め）
  public var dtMs: Int                       // 線の開始からの ms
  public var sizeW: CGFloat, sizeH: CGFloat, opacity: CGFloat, force: CGFloat   // 0.01 丸め
  public var azimuth: CGFloat, altitude: CGFloat                                 // rad、0.001 丸め
}
public enum InkTool: String, Codable, Sendable { case pen, marker }   // 未知の値は decode で保持（下記）
public struct InkStroke: Hashable, Codable, Sendable, Identifiable {
  public var id: String                      // UUID 文字列（Web 取り込み時は Web の id をそのまま）
  public var cell: CellKey
  public var tool: InkTool
  public var color: String                   // "#rrggbb"
  public var t: Int                          // 書いた時刻（ms epoch）
  public var dev: String?                    // 端末 id
  public var points: [InkPoint]
  public var inkStart: Date                  // creationDate の復元用（t から導出可）
}
public struct InkPage: Codable, Sendable {
  public var v: Int = 1
  public var pageId: String                  // "m1-2026-10" など Web 版と同じ
  public var strokes: [String: InkStroke]
  public var deleted: [String: Int]          // id → 削除時刻 ms（墓標）
  public var updatedAt: Int
  public var unknown: [String: JSONValue]    // 知らないトップレベル項目は保持して書き戻す
  public static func empty(pageId: String) -> InkPage
  public var liveStrokes: [InkStroke]        // 墓標の無いもの。marker を先に、次に pen、各 t 昇順
  public mutating func add(_ s: InkStroke)   // 墓標があれば無視
  public mutating func remove(ids: [String], at ms: Int)
  public static func merge(_ a: InkPage, _ b: InkPage) -> InkPage   // 和集合＋墓標（Web 版 mergePages と同じ法則。可換・結合・冪等）
  public func inkBottoms() -> [CellKey: CGFloat]                   // マスごとの手書きの下端（点の y の最大 + 太さ/2）
}
public enum InkPageCodec {
  public static func encode(_ page: InkPage) throws -> Data              // JSON（キーは DESIGN §3.9 と同じ名前）
  public static func decode(_ data: Data) throws -> InkPage              // 寛容: 壊れた線は捨てる、未知項目は保持
  public static func compress(_ data: Data) throws -> Data               // LZFSE（import Compression）
  public static func decompress(_ data: Data) throws -> Data
}
/// 線の所属マスの決め方: 紙座標での外接矩形の中心が入るマス（担当 I が Layout.cell(at:) と組み合わせて使う）
public struct StrokeFingerprint: Hashable, Sendable {               // PKStroke の id 代わり（transform に依存しない）
  public var creationDate: Date; public var pointCount: Int; public var inkType: String; public var firstX: CGFloat; public var firstY: CGFloat
}
```

細則
- `JSONValue` は InkModel 内の小さな列挙（null/bool/number/string/array/object）。
- 点の `x,y` はマス相対（紙座標 − マスの左上）。紙座標への変換は `cells[cell].origin` を足すだけ。
- 旧い `v` も未知の `v` も読んで保持。`tool` が未知の文字列なら `InkTool` にはならず、線は `InkPage.unknownStrokes`（raw JSON）に残して書き戻す（表示はしない）。

## 3. Ink（担当 I）

```swift
public struct InkStyle: Equatable { var tool: InkTool; var colorHex: String; var width: CGFloat }   // ペン幅 2/3.5/6、マーカー 18
enum CanvasTool: Equatable { case ink(InkStyle), eraser }

/// 1 ページ分の手書きの台帳と PKCanvasView の橋渡し
@MainActor final class InkLedger {
  init(page: InkPage, layout: MonthPageLayout)
  var page: InkPage { get }
  func drawing() -> PKDrawing                               // 台帳 → PKDrawing（各線に transform = マス左上への平行移動）
  func applyCanvasChange(_ drawing: PKDrawing) -> InkChange // canvasViewDrawingDidChange 時: 指紋で差分を取り、新規に id/cell を付け、消えた線に墓標
  func relayout(_ layout: MonthPageLayout) -> PKDrawing     // レイアウト変更時の合成し直し（ペンを離している時だけ呼ぶ）
  func undo() -> PKDrawing?; func redo() -> PKDrawing?; var canUndo: Bool; var canRedo: Bool   // 自前履歴（追加/削除の op、最大 200）
}
struct InkChange { var added: [InkStroke]; var removedIds: [String] }

/// SwiftUI から使うキャンバス。PKCanvasView を紙のスクロールビューとして使い、PaperView を下に敷いて scroll/zoom を同期（DESIGN §3.2）
struct InkCanvasView: UIViewRepresentable {
  var layout: MonthPageLayout
  var paper: PaperContent                      // 担当 U の PaperView が描くための内容（下記 4.）
  var tool: CanvasTool
  var allowFinger: Bool
  @Binding var page: InkPage                   // 台帳の内容（変更があれば書き戻す。担当 U が保存する）
  var onTap: (CGPoint) -> Void                 // 指タップ（紙座標）。担当 U が layout.hit(at:) で予定を開く
  var onInkBoundsChanged: () -> Void           // 手書きの下端が行をはみ出した可能性があるとき（担当 U が再レイアウト）
  var undoTrigger: Int; var redoTrigger: Int   // 値が変わったら undo/redo
}
```

細則
- `drawingPolicy`: `allowFinger ? .anyInput : .pencilOnly`。`maximumSupportedContentVersion = .version1`。`canvasView.isOpaque = false`、背景透明。
- 指タップ: `UITapGestureRecognizer` を `PKCanvasView` に付け、`gestureRecognizer(_:shouldReceive:)` で `touch.type == .direct` のときだけ受ける。位置 ÷ `zoomScale` で紙座標に。
- `contentSize = layout.size × zoomScale`、`minimumZoomScale = 画面幅 / 1400`、`maximumZoomScale = min×4`。向きが変わったら min を取り直す。
- ペン使用中（`canvasViewDidBeginUsingTool` 〜 `DidEndUsingTool`）は `drawing` を差し替えない。保留した relayout はペンを離して 300 ms 後に反映し、`MonthLayoutEngine.scrollDelta` で `contentOffset.y` を補正。
- PencilInteraction（M1）を取り付け、ダブルタップ/スクイーズで `tool` をペン⇄消しゴム（`preferredTapAction` を尊重）。切替は `onToolChange` 的なコールバックで担当 U に通知（`InkCanvasView` に `var onPencilToggle: () -> Void` を足してよい）。
- 消しゴムは `PKEraserTool(.vector)`。履歴は台帳側（キャンバスの undoManager は使わない。`canvasView.undoManager?.removeAllActions()` 等で無効化）。

## 4. 紙（担当 U, `PaperView`）

```swift
struct PaperContent: Equatable { var layout: MonthPageLayout; var labels: [DateLabel]; var bars: [AllDayBar]; var chips: [TimedChip]; var holidayNames: [DayKey: String] }
final class PaperView: UIView {  // frame = 紙の大きさ × zoomScale。draw(_:) で描く（CoreGraphics）。contentScaleFactor は画面に合わせる
  var content: PaperContent { didSet { setNeedsDisplay() } }
  var zoomScale: CGFloat
}
```
見た目は Web 版 views.css と同じ色（紙 #fffdf8、罫線 #e5e7eb、日曜・祝日 #dc2626、土曜 #2563eb、今日の丸 #2563eb、帯は予定色、チップは色の丸＋時刻＋題名）。文字は `UIFont.systemFont` で lu×zoom に比例、最小 10pt 相当。

## 5. 予定（担当 U）

- `EventKitService`（M1）を拡張: `func events(in month: YearMonth, calendars: [EKCalendar]?) -> [LayoutEvent]`（終日 end を翌日 0 時に正規化、`isAllDay`、`calendar.cgColor` → hex）、`var calendars: [EKCalendar]`（購読カレンダー含む。祝日・誕生日カレンダーは既定で非表示）、`NotificationCenter` の `.EKEventStoreChanged` を購読して再取得。
- `EventStoreModel: ObservableObject`: `@Published var status: AccessStatus`、`@Published var events: [LayoutEvent]`、`@Published var hiddenCalendarIds: Set<String>`（UserDefaults に保存）、`func load(month:)`、`func requestAccess()`。
- 予定の詳細シート（M2 は閲覧のみ）: 題名、日時、カレンダー名、場所、メモ。「+n件」のタップ（`.moreChips(day)`）はその日の予定一覧シート（M3 で日ページへ）。

## 6. 画面（担当 U, `MonthPageScreen`）

- ヘッダー: ◀ 今日 ▶、タイトル「2026年10月」。ツールバー: ペン（6 色・3 太さ）、マーカー（4 色）、消しゴム、元に戻す／やり直す、指で書くトグル。
- 流れ: 月を決める → `InkPageStore.load("m1-YYYY-MM")` → `EventStoreModel.load` → `MonthLayoutEngine.layout(MonthLayoutInput(month, events, page.inkBottoms(), now))` → `InkCanvasView` に渡す。
- `page` が変わったら 1.5 秒デバウンスで `InkPageStore.save`。`onInkBoundsChanged` と予定の変化で再レイアウト（`inkBottoms` を入れ直す）。
- 前後の月へ移る前に保存。アプリがバックグラウンドへ行くときも保存。
- 初回案内（3 枚）: 「iPad の設定でカレンダーのアカウントを追加」「予定の読み取りに許可が必要（フルアクセス）」「ペン・指の使い分け」。3 枚目のボタンで `requestAccess()`。

## 7. 保存（担当 U, `InkPageStore`）

- 場所: `Application Support/TegakiCalendar/ink/<pageId>.json.lzfse`（`InkPageCodec.encode` → `compress`）。
- 読み込みは `decompress` → `decode`。壊れていたら `.bak` に退避して空ページ（手書きを消さない）。
- 書き込みはアトミック（一時ファイル → rename）。

## 8. CI（担当 C）

- `project.yml`: アプリターゲットがローカルパッケージ `TegakiKit`（path: `TegakiKit`）の `Layout`・`Holidays`・`InkModel` に依存。M1 の `Calendar/DayKey.swift`・`MonthLayout.swift`・`Holidays/JapaneseHolidays.swift` とそのテストはパッケージへ移動（アプリ側から削除）。
- `build.yml`: 既存の手順の前に `swift build --package-path TegakiKit` と `swift run --package-path TegakiKit KitChecks`、`swift test --package-path TegakiKit` を追加（macOS 上で動く）。その後、既存どおりシミュレータ向けビルドとテスト。
- `testflight.yml`: 手動実行（workflow_dispatch）。Secrets（`BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `BUILD_PROVISION_PROFILE_BASE64`, `KEYCHAIN_PASSWORD`, `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_BASE64`）が未設定なら最初のステップで分かりやすく失敗する。署名付きアーカイブ → `xcrun altool --upload-app` か `xcodebuild -exportArchive` + API キーで TestFlight へ。Developer Program 承認後に有効化。
- ローカル確認（この Mac、Xcode 無し）: `cd TegakiKit && swift build && swift run KitChecks` が通ること（XCTest は使えないので `KitChecks` に主要な検査を重複させる）。
