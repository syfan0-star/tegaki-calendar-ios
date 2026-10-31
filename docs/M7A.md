# M7a（1.1）の実装結果

## K

担当 K の前半（K1: TegakiKit のソース・その XCTest・KitChecks の互換以外の節）の記録です。互換テスト（`Compat10`・`CompatFixtures`・`Compat10Tests`・fixture・KitChecks の互換の節と `--write-compat-fixtures`・`Package.swift`・`tools/compat10`・`tools/typecheck/typecheck.sh` の手順 6）は K2 が続けて行います。

### 入れたもの（契約 §0 の形のまま。新しい引数はすべて既定値つき、既存の名前は変えていない）

| ファイル | 中身 |
| --- | --- |
| `Layout/PaperSpec.swift` | `growStep` 400・`growMax` 6,000・`dayExtraMin` 700、`CellKey.extra`（`"extra"`。K-1: `allday` で始まらない）・`isExtra` |
| `Layout/PageLayout.swift` | `PageBand.extra` |
| `Layout/PaperGrowth.swift`（新規） | `isTail`・`tailHeight`（`700 + 400k`、上限 6,000、常に `b + 50` 以上）・`needsMoreRoom`・`reachesCap`・`Drop`・`drop(center:in:)`・`tail(of:)`・`onlyTailHeightChanged` |
| `Layout/MonthLayoutEngine.swift` | `memoHeight(inkBottom:)` の中身を `PaperGrowth.tailHeight` に（名前は残す） |
| `Layout/DayLayoutEngine.swift` | `DayPageLayout.extra`（(0, 2400, 1000, h)、最小 700）、紙 1000 × (2400 + h)、`cells` に `.extra`、`cell(at:)`・`inkCell(forCenter:)`・`growsWithInk`・`band(atY:)`・`bandTop` を §3.3 の表のとおり、`startsBelowDay(_:)`。`eventRange(for:)`・`snapRect`・`hit`・`dayAt`・`nowLine`・開く位置は変えていない（0-4）。`DayLayoutInput.inkBottoms` の説明を直した |
| `Layout/ZoomPolicy.swift` | `overviewSize` の日を 1000 × `grid.height`（2400）に（K-6） |
| `Layout/MonthPageLayout.swift` | `hit(at:minTarget:)`（§4.2） |
| `Layout/YearLayoutEngine.swift` | `gutterDay(at:numberOnly:)`・`gutterHit(at:numberOnly:month:)`（P-13、無い日は nil = M7A-3） |
| `Layout/DateTap.swift`（新規） | `minPoints` 44・`minTarget`・`target`（§4.1。M7A-1・M7A-2 は既定のとおり） |
| `Layout/PageNavigation.swift` | `parse(pageId:)` |
| `InkModel/InkPage.swift` | `maxStrokes` 20,000 → **60,000**（この 1 行だけ） |
| `InkModel/WebImport.swift` | `maxStrokesPerPage = 20_000` を足し、:187（今は :190）がそれを使う（Web 版の取り込みは今のまま 20,000 本） |
| `InkModel/StrokeBudget.swift`（新規） | `StrokeBudget`（15,000 / 19,000 / 20,000 / `readCap`、`accepted`・`crossesNotice`・`importExceedsLegacyCap`・`Entry`・`largest`・`pageLabel`・`countText`）と `InkPage.budgetCount`（生きている線 ＋ 知らない tool の線） |

### 着手直後の KitChecks の赤い行（この Mac）

`PaperSpec`・`PaperGrowth`・月の `memoHeight`・日の `extra` と `startsBelowDay`・`ZoomPolicy`・`InkPage.maxStrokes`（60,000）・`WebImport.maxStrokesPerPage` を入れた直後、既存の確認を直す前に `swift run --package-path TegakiKit KitChecks` を走らせた結果: **23,446 件のうち 11 件が赤**（行番号は m7a の HEAD b4f7271 = cb2343a の `TegakiKit/Sources/KitChecks/main.swift`）。

| 行 | 確認の文 | 得た値 → 1.0.1 の期待 | 契約 §7.1 の一覧 |
| --- | --- | --- | --- |
| :104 | memo ink bottom + 50 | 1,500 → 950 | ある（:104） |
| :336 | memo grows with its ink | 1,500 → 950 | ある（契約は :335-336。実際は :336-337） |
| :337 | paper height | 2,687 → 2,137（1050 + 137 + 950） | ある（同上） |
| :1074 | 1000 × 2400 (M4b: no band on the paper) | 1000 × 3,100 → 1000 × 2400 | ある（:1074-1080） |
| :1075 | one cell: the grid | 2 → 1 | ある（:1074-1080） |
| :1140 | below the paper（`cell(at: (100, 2400))`） | `.extra` → nil | ある（:1140） |
| :1147 | ink below the paper → grid（`inkCell(forCenter: (2000, 9000))`） | `.extra` → `.grid` | ある（:1147） |
| :1154 | band below（`band(atY: 2400)`） | `.extra` → nil | ある（:1154） |
| :1168 | the paper does not grow with the band（`busy.size.height`） | 3,100 → 2,400 | ある（:1168） |
| :1177 | ink does not grow the paper（`inked.size.height`） | 3,100 → 2,400 | ある（:1177） |
| :1188 | the 8th's paper（`tomorrow.size.height`） | 3,100 → 2,400 | **無い** |

- **一覧に無い赤は :1188 の 1 件だけ**。理由: 日の紙が 2,400 + `extra` の最小 700 = 3,100 になったため（:1168・:1177 と同じ原因）。翌日（10/8）のページの紙の高さを確かめる行で、`extra` に手書きは無い。§7.2 の XCTest の一覧には同じ確かめ（`DayLayoutEngineTests` :193 の `tomorrow` 3,100）が載っているので、§7.1 の一覧から漏れただけと判断し、期待を 3,100 に直した（意味は「翌日のページの紙」のまま）。
- 契約が「直さない」とした行（:1180 の `inked == page`、:1557-1561 と :1776-1849 の `eventRange`、:2845 の日の一覧、:3055-3145 の日の `centeringInsets` と `PaperViewport.initial`）は赤にならなかった。:2845 は説明の文だけ "overview: day = the 24-hour grid (K-6)" に直した。

### 着手直後の `swift test` の赤い行（この Mac の代わりの走らせ方）

この Mac には XCTest が無いので、作業用のフォルダ（リポジトリの外）に **走る XCTest の代わり**（`XCTAssert…` が失敗を数えるだけの小さな module と、テストのメソッドを全部呼ぶ main を生成する台）を作り、**HEAD の `TegakiKit/Tests`（直す前のテスト）を新しい `TegakiKit/Sources` で** 走らせた。台そのものの確かめとして、HEAD のテストを HEAD のソースで走らせると LayoutTests 119 本・InkModelTests 83 本とも失敗 0。

結果: **LayoutTests 119 本のうち 12 か所が赤、InkModelTests 83 本は赤なし**（行番号は HEAD のテストのファイル）。

| ファイル:行 | テスト | 得た値 → 1.0.1 の期待 | 契約 §7.2 の一覧 |
| --- | --- | --- | --- |
| `DayLayoutEngineTests` :20 | testGeometry | 1000 × 3,100 → 1000 × 2400 | ある |
| `DayLayoutEngineTests` :24 | testGeometry | `cells.count` 2 → 1 | ある |
| `DayLayoutEngineTests` :71 | testAllDayBand | `busy` 3,100 → 2,400 | ある |
| `DayLayoutEngineTests` :142 | testCellsAndInkCells | `cell(at: (100, 2400))` `.extra` → nil | ある |
| `DayLayoutEngineTests` :149 | testCellsAndInkCells | `inkCell(2000, 9000)` `.extra` → `.grid` | ある |
| `DayLayoutEngineTests` :162 | testBandsAndGeometry | `band(atY: 2400)` `.extra` → nil | ある |
| `DayLayoutEngineTests` :175 | testBandsAndGeometry | 3,100 → 2,400 | ある |
| `DayLayoutEngineTests` :193 | testOtherDays | `tomorrow` 3,100 → 2,400 | ある |
| `MonthLayoutEngineTests` :74 | testRowHeightFormula | `memoHeight(900)` 1,500 → 950 | ある |
| `MonthLayoutEngineTests` :396 | testInkBottomsGrowRowsAndMemo | 1,500 → 950 | ある |
| `MonthLayoutEngineTests` :397 | testInkBottomsGrowRowsAndMemo | 2,687 → 2,137 | ある |
| `AllDayBandTests` :180 | testDayBand | 日の紙 3,100 → 2,400（"the paper does not grow with the band"） | **無い** |

- **一覧に無い赤は `AllDayBandTests` :180 の 1 件だけ**。理由は KitChecks の :1168 と同じ（日の紙が 3,100 になった。帯では紙が伸びない、という意味はそのまま）。`LayoutTests` は K の持ち物なので期待を 3,100 に直した。
- `EventRangeTests`（:178-182・:435- の乱数の不変条件）と `ZoomPolicyTests` :59 は赤にならなかった（契約どおり。:59 は説明の文だけ "day: the 24-hour grid (K-6)" に直した）。
- 本物の XCTest（CI の macOS の `swift test`）での結果は C が最初の CI で確かめる。この台は失敗の数え方が本物と同じではない（`continueAfterFailure` などは真似ていない）ので、本物で違いが出たら CI の結果を正とする。

### 直したあとの結果

- `swift build --package-path TegakiKit`: 成功。警告は KitChecks の 3 件（`main.swift` の `try` が要らない、の警告。HEAD の :2219・:2240・:2271 と同じ行で、K1 の前からある）だけ。新しいソースの警告は 0。
- `swift run --package-path TegakiKit KitChecks`: **「KitChecks: all 24024 checks passed」**（1.0.1 の 23,446 ＋ 578。新しい節は「growing paper (1.1)」「date taps (1.1)」「stroke budget (1.1)」の 3 つで、「app export (M6)」の後・Summary の前）。**この N = 24,024 は K1 の時点の数**。K2 が「compat with 1.0 (K-7)」の節（「stroke budget (1.1)」の後・Summary の前）を足すと増えるので、C が build.yml に入れる閾値（N − 50）は K2 の最後の実数から計算する。
- 上の代わりの台で、直したテストと新しいテストを新しいソースで走らせた結果: **LayoutTests 140 本・InkModelTests 89 本とも失敗 0**（新しいテストは LayoutTests 21 本・InkModelTests 6 本）。
- 型の確かめ（スナップショット: 作業ツリーの TegakiKit ＋ HEAD の `Sources`・`Tests` のアプリ、`tools/typecheck/typecheck.sh`）: **エラー 0・警告 0**（アプリ、TegakiCalendarTests 24 ファイル、TegakiCalendarUITests、TegakiKit の 4 つの XCTest ターゲット）。今のアプリは変えずに新しい TegakiKit で通る。

### XCTest（§7.2 の K の分。Compat10Tests は K2）

| ファイル | 中身 |
| --- | --- |
| `LayoutTests/PaperGrowthTests.swift`（新規） | `testTailHeightSteps`・`testTailHeightKeepsTheOneZeroRule`・`testNeedsMoreRoom`・`testReachesCap`・`testDropReasons`・`testOnlyTailHeightChanged` |
| `LayoutTests/DayLayoutEngineTests.swift` | :20・:24・:71・:142・:149・:162・:175・:193 を直し、`testExtraCellAndBands`・`testExtraGrowsWithInk`・`testStartsBelowDay`・`testInkCellBelow24IsExtra`・`testOldCellsKeepTheirRects` |
| `LayoutTests/MonthLayoutEngineTests.swift` | :74・:396・:397 を直し、`testMemoGrowsInSteps`・`testHitWithMinTarget` |
| `LayoutTests/YearLayoutEngineTests.swift` | `testGutterDay`・`testGutterHitUsesTheGivenMonth`（1.0.1 の `testDateTargetIsAtLeast44PointsOnScreen` は不変） |
| `LayoutTests/ZoomPolicyTests.swift` | :59 の説明の文だけ |
| `LayoutTests/DateTapTests.swift`（新規） | `testMinTargetRule`・`testTargetOrderOnTheYearPage`・`testMonthTargetOnlyWhenFingerDrawingIsOff`・`testGutterIsTheWholeRowOnASmallScreen`・`testWeekAndDayAreUnchanged` |
| `LayoutTests/PageNavigationTests.swift` | `testParsePageId` |
| `LayoutTests/AllDayBandTests.swift` | :180 を 3,100 に（一覧に無い赤。上の表） |
| `InkModelTests/StrokeBudgetTests.swift`（新規） | `testBudgetCountIncludesUnknownTools`・`testAcceptedAndNotice`・`testLargestAndLabels`・`testNewReaderKeepsMoreThan20000`・`testImportExceedsLegacyCap` |
| `InkModelTests/BandMigrationTests.swift` | `testExtraIsNotABandCell`（K-1 を XCTest でも固定。§1.2 の求め。§7.2 の名前の一覧には無い追加） |
| `EventRangeTests.swift` | 直さない（契約どおり） |

### 契約からのずれ・契約が黙っている所の決め方

1. **§3.1 の表と 0-1 の「5,600 → 5,900」は式の計算違い**。式 `700 + 400 × max(0, ceil((b − 300) / 400))` では b = 5,500 が 5,900（最後の満額の段）、b = 5,600 は 6,300 を上限で切って **6,000**。同じ契約の「b ≤ 5,600 で白紙 ≥ 400」（§3.1、`testTailHeightKeepsTheOneZeroRule`）も 6,000 でなければ成り立たない（5,900 なら白紙 300）。**式（§0 の説明と D3 の文）に従い、表の 5,600 の列は 6,000 で確かめ、5,500 → 5,900 の点を足した**（KitChecks・XCTest とも 12 点）。ほかの 10 点は表のとおり。
2. **`reachesCap` は `b > 5,600`（= `growMax − growStep`、「b の下に残る白紙が 400 未満」と同じ）**。§0 の説明の式どおり「stepped(b) ≥ growMax」を文字どおりに計算すると b > 5,500 になるが、括弧の「= b > 5,600」、0-5、§7.1、§7.2 の K と P のテスト（`testReachesCap` 5,600 false・5,601 true、P の `testCapNoticeWhenTheTailReachesItsLastStep` 5,601 で来る・5,600 では来ない）がすべて 5,600 で書かれているので、そちらに合わせた（上の 1 の計算違いから来たずれ）。意味は「この下端の線を書くと、その下に 400 lu の白紙をもう残せない」で、`reachesCap(b) ⇔ tailHeight(b) − b < 400` を KitChecks と XCTest で 0〜7,000 にわたって確かめている。**リードへ**: 契約の §3.1 の表・0-1 の「5,600 で 5,900」と §0・§3.1 の `reachesCap` の式は、この 2 点に合わせて直すのがよい（P・U の実装には影響しない）。
3. `DayPageLayout.init` の最後の引数は **`extra: CGRect = .zero`**（任務の「新しい引数は既定値つき」に従った。呼ぶのはエンジンだけ）。`extra` を持たないレイアウト（`cells` に `.extra` が無い）では `cell(at:)`・`inkCell`・`growsWithInk`・`band`・`bandTop`・`PaperGrowth.tail` が 1.0 と同じに振る舞うよう、`cells[.extra]` があるかを見ている。
4. `inkCell(forCenter:)` の y が有限でない（NaN・±∞）ときは `.grid`（契約は「y ≥ 2400 → extra、それ以外 → grid」。+∞ は字面では ≥ 2400 だが、1.0 と NaN の扱いにそろえて grid にした）。x は見ない（紙の横の外でも y ≥ 2400 なら extra。§7.1 の (2000, 9000) → extra のとおり）。
5. `PageNavigation.parse(pageId:)` は `pageId(_:focus:)` が書く形だけを読む（年 4 桁・月日 2 桁・半角数字、実在する日。"d-2026-1-7"・全角の数字・前後の空白は nil）。`w-` は月曜でなくても実在する日なら (.week, その日) を返す（契約「(.week, その日)」のまま。ラベルは `title(.week, focus:)` が月曜に寄せる）。
6. `StrokeBudget.accepted` は負の `incoming` を 0 とみなす（`min(max(0, incoming), max(0, refuseAt − count))`）。`countText` は負の数に「-」を付ける（使う所は無いが、落ちないように）。
7. `YearPageLayout.gutterDay` の「数字の上だけ」は行の真ん中 ± 14 の **両端を含む**（`|y − midY| ≤ 14`）。月の `hit(at:minTarget:)` の高さの下限 28 は `PaperSpec.monthDateHeader`。
8. `PaperGrowth.tail(of:)` は `layout.kind`（月 → `.memo`、日 → `.extra`）と `layout.cells[key]` で決める（型を問わず、そのマスが無ければ nil）。
9. KitChecks の新しい 3 節は 578 件（契約の見込み「+380〜480 件」は互換の節を含めた数。件数の差は確かめの点を多めに取ったため）。
10. 本物の XCTest の赤い行は CI でしか取れないが、CI を動かすのは C だけで、最初の CI では既にテストを直してあるので「直す前の赤」は CI からは取れない。そこで上のとおり、この Mac で走る代わりの台で HEAD のテストを新しいソースに当てて取った（台はリポジトリに入れていない）。

### K2 への引き継ぎ

- KitChecks の互換の節は「stroke budget (1.1)」の節の後、`// MARK: - Summary` の前に足す。`--write-compat-fixtures` の引数の処理も K2。
- `CompatFixtures` が fixture のマスを決めるときは 1.1 の `DayLayoutEngine`・`MonthLayoutEngine` の `inkCell(forCenter:)` を使う（日の中心 y ≥ 2400 → `extra`）。`d-2026-11-02.json` の「1.1 の extra の高さ 6,005（= 5,955 + 50）」は `PaperGrowth.tailHeight(5955) = 6005` で合う。`m1-2026-11.json` のメモ 6,040（b 5,990）、`m1-2026-12.from10.json` の 6,470（b 6,420）と「相対 6,100 の新しい線 → `beyondCap`」も `PaperGrowth` で確かめ済みの数（KitChecks と `PaperGrowthTests`）。
- 1.1 の読む上限は `InkPage.maxStrokes` = 60,000（`StrokeBudget.readCap`）。`Compat10` の写しは 1.0 の 20,000 のまま写す。

### K2: 互換テスト K-7（§1.4・§7.1 の互換の節・§7.2 の Compat10Tests）

担当 K の後半（K2）の記録です。1.0 の端末と 1.1 の端末が同じ iCloud を使っても、どちらも相手の手書きを消したり動かしたりしないことを、**1.0 のコードそのもの** で確かめる仕組みです。

#### 入れたもの

| 場所 | 中身 |
| --- | --- |
| `TegakiKit/Tests/Compat10/`（ターゲット `Compat10`） | 1.0（a21e469）の InkModel の凍結した写し 9 ファイル（`JSONValueV10`・`InkStrokeV10`・`InkPageV10`・`InkPageCodecV10`・`BandMigrationV10` は丸ごと、`CellKeyV10`（`PaperSpecV10` の週の 4 定数を含む）・`DayKeyV10`・`WebImportV10`（`ParseError`・`versionNumber`・`supportedVersion` だけ）・`AppExportV10`（:1-132）は一部）、手で写した `LedgerV10.swift`（1.0 のアプリの台帳・画面・同期の規則 7 つ）と `LayoutFactsV10.swift`（`cellsV10(pageId:)`・`memoHeightV10(_:)`）、`Checks/Compat10Checks.swift`、`FROZEN.sha256`（写し 11 ファイルだけ。`Checks/` は含めない）、`ORIGIN.sha256`（元にした 1.0 のファイル 18 個）、`ORIGIN.ranges`（一部だけ写した範囲と手で写した関数の元の範囲 28 行）。Foundation・CoreGraphics・Compression だけに依存（TegakiKit のどのモジュールにも依存しない） |
| `TegakiKit/Tests/CompatFixtures/`（ターゲット `CompatFixtures`） | 新しいコードで K の fixture を作る（`make()`・`makeLarge()`・`digestsData()`・`write(to:)`・`prepare(from:into:skippingLarge:)`）。マスは 1.1 のレイアウトの `inkCell(forCenter:)` で決め、点はそのマスからの相対。id は種から作る小文字の UUID、t = 1,790,000,000,000 + n |
| `TegakiKit/Tests/Fixtures/compat11/` | K の fixture 7 つ ＋ `digests.json` ＋ `.gitignore`（大きい 3 つを git に入れない）。`ledger-*.json`（P）・`screenshot-*.json`（U）は K が書かない・消さない・比べない（0-23） |
| `TegakiKit/Tests/Compat10Tests/` | §7.2 の名前どおりの 23 本（9 クラス）＋ 共通の `Compat10TestSupport.swift` |
| `TegakiKit/Package.swift` | `Compat10`（`exclude: ["FROZEN.sha256", "ORIGIN.sha256", "ORIGIN.ranges"]`）・`CompatFixtures`・`Compat10Tests`、KitChecks の依存に `Compat10`・`CompatFixtures`。どれも product にしない（アプリには入らない） |
| `TegakiKit/Sources/KitChecks/main.swift` | 先頭に `--write-compat-fixtures [--out <フォルダ>]`（書いて終わる。チェックは走らせない）、「stroke budget (1.1)」の後・Summary の前に `section("compat with 1.0 (K-7)")` |
| `tools/compat10/` | 本物の 1.0 で同じ確かめを走らせる package（`RunReal`：`Aliases.swift` の別名 13 個と本物の 1.0 の Layout から作る `cellsV10`・`memoHeightV10`／`RunFrozen`）、`run.sh`（写しのコピーと両方の実行と比較）、`check-origin.sh`（ORIGIN.sha256・ORIGIN.ranges・FROZEN.sha256 の照合）、`freeze.py`（凍結した写しを a21e469 から機械的に作り直して 1 バイトずつ比べる）、`AppTests/Real10LedgerTests.swift`（1.0 のアプリの台帳と同期をシミュレータで）、`EXPECTED_MIN`、`.gitignore` |
| `tools/typecheck/typecheck.sh` 手順 6 | `Compat10`（`Checks/` も含めて `find`）と `CompatFixtures` を module として出し、テストのフォルダのループは `Compat10`・`CompatFixtures`・`Fixtures` を飛ばし、各フォルダのファイルを `find` で集める。この手順の XCTest の代わりに `measure` を足した（下のずれ 6） |

#### 凍結した写しの作り方と見張り

- 写しは `python3 -I tools/compat10/freeze.py --write` で a21e469 から機械的に作った: 1.0 の本文の、写すファイルの型名 14 個（`JSONValue`・`InkPoint`・`InkTool`・`InkStroke`・`StrokeFingerprint`・`InkPage`・`InkPageCodec`・`InkCodecError`・`BandMigration`・`CellKey`・`PaperSpec`・`DayKey`・`AppExport`・`WebImport`）に単語単位で `V10` を付け（コメントも同じ置き換え）、TegakiKit のモジュールの `import`（InkStroke の `@_exported import Layout`）を消しただけ。一部だけ写したファイルは、範囲ごとに `// a21e469 <パス>:<始め>-<終わり>  <名前>` の 1 行を前に置き、外側の数行（`public enum PaperSpecV10 {` など）で包んだ。名前の付け方・入れ物・public かどうかは本物のまま（RunReal で別名を向けると同じ呼び方で通ることを確かめた）。
- 見張りは 3 重: ①`FROZEN.sha256`（写しが凍結の後に変わっていない。KitChecks・`Compat10FrozenSourceTests`・CI の「Frozen 1.0 copy」）、②`ORIGIN.sha256` と `ORIGIN.ranges`（写した元が本当に a21e469 のその行。`check-origin.sh`）、③`freeze.py --check`（写しが a21e469 から機械的に作れるものと 1 バイトも違わない）。この Mac で 3 つとも通した。`InkPage.swift` の sha256 は契約の `32f29ca4…6675` と一致。

#### fixture（K の分）

| ファイル | 大きさ | 中身（契約の表との対応） |
| --- | --- | --- |
| `d-2026-11-02.json` | 5,953 B | `grid` 6 本（y 700〜2,350）、`extra` 8 本（相対 y 30〜5,950、一番深い線は太さ 10 で下端 5,955 → 1.1 の extra 6,005）、`extra` の知らない tool `"tape"` 1 本（線の中に知らない項目 `width` も持つ）、墓標 3 件 |
| `d-2026-11-02.from10.json` | 6,402 B | 上を読み、1.0 の日のマス（`grid` だけ）に 2 本足し、1.1 の `grid` の 1 本に墓標。`grid` 7・`extra` 8・知らない線 1・墓標 4 |
| `d-2026-11-04.moved.json` | 1,293 B | `grid` 3 本のうち 22 時の 1 本を投げなわで 600 下へ（`InkLedger.moveStrokes` と同じ手順: 動かした中心の `inkCell` → `extra`、`InkStroke.translated`、元の id に墓標）。`grid` 2・`extra` 1・墓標 1 |
| `m1-2026-11.json` | 3,275 B | メモの下端 380 / 790 / 3,190 / 5,590 / 5,990、日のマス 4 本（10/26・11/3・11/18・12/6。月の外の日を含む）。1.0 も 1.1 もメモ 6,040 |
| `m1-2026-12.from10.json` | 1,086 B | Web 版の取り込み（`WebImport.convert`）の形: 蛍光ペンでメモの下端 6,420、メモの浅い線 1 本、12/8 の 1 本（dev `web`、点ごとに 8 ms）。1.0 も 1.1 もメモ 6,470。相対 6,100 に中心がある新しい線は `beyondCap`、5,900 は残す |
| `w-2026-11-02.legacy.json` | 434 B | `allday:2026-11-04` の線 1 本（x0 = 10）。1.0 も新しいコードも `grid` へ移し x0 = 455.7（10 + 64 + 2 × 190.857 = 455.714 を 0.1 に丸めた値）、id はそのまま |
| `export-1.1.json` | 13,847 B | `tegaki-app-export` v1、`app` = `"ios/1.1 (1)"`、ページは d-2026-11-02・m1-2026-11・w-2026-11-02（書き出す側の決まりどおり移行済み） |
| `y-2026.n15000.json`（作り直し） | 3,434,956 B | 2 点の線 15,000 本を 372 マスに |
| `y-2026.n20500.json`（作り直し） | 4,694,404 B | 線 20,300 本 ＋ 知らない tool 200 本（103 本おき） |
| `y-2026.tomb200500.json`（作り直し） | 10,626,576 B | 墓標 200,500 件 |
| `digests.json` | 283 B | 大きい 3 つの sha256 だけ |

- 大きい 3 つは commit しない（`.gitignore`）。KitChecks・Compat10Tests・CI は毎回作り直して一時フォルダに置き、`digests.json` と照合する（見つからない・違う → 失敗として数える。`testMissingLargeFixtureCountsAsAFailure` で確かめた）。
- `swift run --package-path TegakiKit KitChecks --write-compat-fixtures --out <空のフォルダ>` の結果が、commit する 7 つと `digests.json` と 1 バイトも違わないことを、この Mac で 2 回（別のフォルダ・別のプロセス）確かめた。

#### 結果（この Mac）

- **KitChecks: 「KitChecks: all 24302 checks passed」**（K1 時点の 24,024 ＋ 互換の節 278）。**C が build.yml :67-74 に入れる閾値は 24,252（= 24,302 − 50）**。互換の節の中の `Compat10Checks` は 225 件（P・U の fixture が commit されると、その分だけ増える）。KitChecks の時間はこの Mac の debug で約 28 秒（互換の節が約 24 秒。大きい fixture の作り直しと読み込み）。
- `swift build --package-path TegakiKit`: 成功。警告は前からある KitChecks の「try が要らない」3 件だけ（先頭に 33 行足したので今は :2256・:2277・:2308）。新しいコードの警告 0。SwiftPM の「unhandled file」の警告 0。
- **tools/compat10（本物の 1.0）**: CI と同じ形（リポジトリの写しの根に `git archive a21e4692109e504701b507ad9c695181fdecddfd TegakiKit | tar -x -C v10`、fixture は commit した `*.json` をコピーしてから `--write-compat-fixtures --out`）で `tools/compat10/run.sh` を走らせ、**RunReal「compat10: 225 checks, 0 failed」・RunFrozen「compat10: 225 checks, 0 failed」・RunReal の InkImport 2 件 0 失敗、`EXPECTED_MIN` = 225**。写しを壊して（`LayoutFactsV10` の月を 41 日に、`InkPageV10.maxStrokes` を 20,001 に）走らせると RunFrozen だけが 5 件赤になり、run.sh が失敗することも確かめた（元に戻した）。
- **`EXPECTED_MIN` = 225**（K の fixture だけで数えた N。P・U の fixture が入ると N は増えるだけ）。
- Compat10Tests: XCTest が無いので、作業用の代わりの台（K1 の台を広げたもの、リポジトリの外）で 23 本・4,681 アサーションとも失敗 0（debug で約 65 秒）。本物の `swift test` は C の CI で確かめる。
- `Real10LedgerTests.swift`: a21e469 のアプリと 1.0 のテストのフォルダにこのファイルを入れた木で `tools/typecheck/typecheck.sh` を走らせ、型の確かめ OK・警告 0（25 ファイル）。シミュレータでは走らせていない（最初の compat-v1.0 で赤なら K が直す。1.0 のコードは直さない）。
- 型の確かめ（スナップショット: 作業ツリーの TegakiKit・tools ＋ HEAD の `Sources`・`Tests`）: **エラー 0・警告 0**（TegakiKit の Compat10Tests 10 ファイルを含む）。

#### 契約からのずれ・契約が黙っている所の決め方

1. `d-2026-11-02.from10.json` は「1.0 の写しで」作ると契約にあるが、`CompatFixtures` の依存は契約どおり `InkModel`・`Layout` だけなので、新しい `InkPage`（1.0 との違いは読む上限の数字だけ）で作った。そのかわり `Compat10SessionTests.testEditingGridOn10KeepsExtra` で、同じ編集（`CompatFixtures.dayFrom10Edit()` の値）を **凍結した 1.0 の写しで** やり直し、fixture と 1 バイトも違わないことを確かめている。`m1-2026-12.from10.json` も同じ理由で新しい `WebImport.convert`（1.0 と同じ挙動。20,000 本以下）で作った（写しの `WebImportV10` は契約どおり `ParseError` などだけ）。
2. `w-2026-11-02.legacy.json` の x0 は契約の「455.714」ではなく **455.7** で確かめる（`InkPoint` が 0.1 に丸める。1.0 も新しいコードも同じ）。
3. `export-1.1.json` の `app` の N は 1（`"ios/1.1 (1)"`。`CURRENT_PROJECT_VERSION` と同じ）。
4. `LedgerV10` の関数の引数の形は契約が決めていないので、`drawnIds(page:cells:)`・`lassoCandidates(page:cells:)`・`dotCandidates(page:cells:)` の `cells` は `Set<CellKeyV10>`（レイアウトの `cells.keys`）、`needsMoreRoom(_:cellHeight:growsWithInk:)`、`applyRemoteWouldSave(page:updated:) -> (page:, saves:)?`（nil = 画面が無視する）、`mergeRemoteOutcome(local:remote:) -> (merged:, writesFile:, marksDirty:)` にした。1.0 の `PaperSpec.inkPad`・`memoInkPad` は写しの `PaperSpecV10` に無い（契約どおり週の定数だけ）ので、`LedgerV10.inkPad` 12・`memoInkPad` 50 として元の行（PaperSpec.swift:23-25）を `ORIGIN.ranges` に入れた。`ORIGIN.ranges` には `LayoutFactsV10` の元の範囲（6 行）も入れた。
5. 時間を抑えるため（最初の形では KitChecks の互換の節だけで debug 約 90 秒かかった）、大きい 3 つのページでは、ページ全体をもう一度写す確かめ（全部消す・同じページの取り寄せ・1.0 での書き足し・ファイルの読み直し）を省き、それらは小さいページで確かめる（大きいページには `largeChecks` の専用の確かめがある）。省くかどうかはファイル名で決まるので、確かめの数は実行ごとに変わらない。墓標が 200,000 件を超えるページは、読むたびに残る組が辞書の順で変わりうる（F8）ので、そのページでは「`InkPageCodec.decode` と `init(json:)` が同じ」を比べない。大きい fixture の sha256 は写しの中で Foundation だけで計算する（Compat10 の依存を増やさないため。`digests.json` は CryptoKit で作るので、2 つの実装が互いに確かめ合う）。
6. `Compat10BudgetTests.testDecodeTimeOf15000Strokes` は契約どおり `measure` を使う。型の確かめの XCTest の代わり（`tools/typecheck/XCTestStandIn.swift`。K の持ち物ではない）に `measure` が無いので、**手順 6 の中で** 小さな拡張（`extension XCTestCase { public func measure(_ block: () -> Void) {} }`）を作業フォルダに書いて一緒に module にした。`XCTestStandIn.swift` に `measure` が足されたら、手順 6 のこの 5 行は消す。
7. `--write-compat-fixtures` は書いて終わる（24,000 件のチェックは走らせない）。ファイルごとに new / unchanged / changed を出すが、終了コードは書けたら 0。CI で「作り直した `digests.json` が commit したものと同じ」を確かめるのは、書いた後の `cmp`（下の CI の ③）。
8. KitChecks と Compat10Tests の新しいコードの側の確かめ（1.1 の高さ 6,005・6,040・6,470、`beyondCap`、1.0 と 1.1 の merge・移行・書き出しが同じバイト、20,500 本の復元、`InkImport` の流し読み）は `Compat10Checks` の外に置いた（RunReal・RunFrozen の N に入らない）。P・U の fixture も、`Compat10Checks` と同じ互換の確かめ（1.0 で読んで書き戻す・1.1 が読む）だけに使い、作り直して比べることはしない（0-23）。
9. `Real10LedgerTests` は fixture のうち線が 5,000 本以下で、墓標が 200,000 件（`InkPage.maxTombstones`）以下のページで 1〜3 を、`y-2026.n20500.json` で 4 を走らせる（1.0 の台帳は線ごとに PKStroke を作るため。墓標が 200,000 件を超える `y-2026.tomb200500.json` は、1.0 が残す墓標の組が辞書の順で決まり（F8）、3 の「端末のファイルが fixture と 1 バイトも違わない」が成り立たないので外す。このページは `Compat10Checks` が本物の 1.0 の InkModel（RunReal）で確かめる）。1〜3 の「描く本数」は K の fixture では契約の数（6・7・2・9・3・1）でも確かめる。

#### C への引き渡し（CI）

build ジョブ:

- KitChecks の閾値: `test "${N:-0}" -ge 24252`（コメントの数字は「1.1 counts 24302 … minus 50」）。
- `swift test` の後に「Frozen 1.0 copy」: `cd TegakiKit/Tests/Compat10 && shasum -a 256 -c FROZEN.sha256`（11 行とも OK）。

compat-v1.0 ジョブ（macos-26、`timeout-minutes: 45`、build と並行。build の「Select Xcode」と同じ手順を最初に）:

```bash
# ① actions/checkout@v4（この commit）と actions/checkout@v4（ref: a21e4692109e504701b507ad9c695181fdecddfd、path: v10）
# ② 元の照合（ORIGIN.sha256 の 18 行、ORIGIN.ranges の 28 行、FROZEN.sha256 の 11 行）と、写しが a21e469 から機械的に作れること
(cd v10 && shasum -a 256 -c ../TegakiKit/Tests/Compat10/ORIGIN.sha256)
tools/compat10/check-origin.sh v10                 # 最後の行「check-origin: OK (28 ranges)」
python3 -I tools/compat10/freeze.py --check --from-dir v10   # 最後の行「freeze: the frozen copy is what a21e469 gives」
# ③ 大きい fixture を作る（K の分を書き、commit したものと照らし合わせる）
mkdir -p "$RUNNER_TEMP/compat11"
cp TegakiKit/Tests/Fixtures/compat11/*.json "$RUNNER_TEMP/compat11/"
swift run --package-path TegakiKit KitChecks --write-compat-fixtures --out "$RUNNER_TEMP/compat11"
for f in TegakiKit/Tests/Fixtures/compat11/*.json; do cmp "$f" "$RUNNER_TEMP/compat11/$(basename "$f")"; done
# ④⑤ 写しのコピー、本物の 1.0（RunReal）と凍結した写し（RunFrozen）、N の比較と EXPECTED_MIN
tools/compat10/run.sh "$RUNNER_TEMP/compat11"      # 最後の行「compat-v1.0: OK (225 checks on the real 1.0 and on the frozen copy, 0 failed)」（P・U の fixture が入ると 225 より多い）
# ⑥ 1.0 のアプリの台帳と同期（brew install xcodegen の後）
cp tools/compat10/AppTests/Real10LedgerTests.swift v10/Tests/TegakiCalendarTests/
(cd v10 && xcodegen generate)
# SIM = build の「Pick a simulator」と同じ選び方の 13 インチの iPad
TEST_RUNNER_TEGAKI_COMPAT_FIXTURES="$RUNNER_TEMP/compat11" xcodebuild test \
  -project v10/TegakiCalendar.xcodeproj -scheme TegakiCalendar -destination "id=$SIM" \
  -only-testing:TegakiCalendarTests/Real10LedgerTests CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
# 期待: Real10LedgerTests の 4 本（testThe10LedgerDrawsOnlyItsOwnCells・testErasingEverythingOn10KeepsTheOtherStrokesByteForByte・
#       testSyncOn10KeepsExtraAndDoesNotSendAPageBack・testThe10EngineTruncatesTo20000WithoutTombstones）が合格
```

- run.sh は `swift build`・`swift run --skip-build` を `tools/compat10` に対して行い、`tools/compat10/Sources/*/Copied-*.swift`（git に入らない）を作る。v10 は `tools/compat10/Package.swift` の `.package(path: "../../v10/TegakiKit")` で使うので、2 回目の checkout は必ずリポジトリの根の `v10`。
- この Mac の python3（/Library/Frameworks の x86_64 版）からは `git` が呼べないので、手元では `/usr/bin/python3 -I tools/compat10/freeze.py …` を使った（CI の python3 では問題ない。`--from-dir v10` なら git を呼ばない）。

### K の検証（検証役 vK）

契約（第 2 版）と K1・K2 の結果を突き合わせ、この Mac で次をやり直した。数字はどれも変わらない（**KitChecks の N = 24,302、C の閾値 24,252、`EXPECTED_MIN` = 225**）。

- §0 の K の接点（名前・引数・戻り値・`public`）、§3.1・§3.3・§3.4・§4.1〜§4.3・§5.1 の数字と規則、`eventRange`・`snapRect`・`BandMigration`・`InkPage` の形式が変わっていないこと（`git diff HEAD -- TegakiKit`）。既存の確認を直したのは §7.1・§7.2 の一覧の行と、上に理由を書いた KitChecks :1188・`AllDayBandTests` :180 だけで、ほかに弱めた確かめは無い。
- 凍結した写し: 丸ごとの 5 つは `V10` を外すと a21e469 と 1 行（InkStroke の `@_exported import Layout`）しか違わない。一部の 4 つは `ORIGIN.ranges` の各範囲が a21e469 の行と 1 行ずつ同じで、範囲の外は包みの数行だけ。`ORIGIN.sha256` 18 行・`ORIGIN.ranges` 28 行・`FROZEN.sha256` 11 行を、`check-origin.sh` を使わず自分で計算して一致。`Compat10` の import は Foundation・CoreGraphics・Compression だけ。`swift package describe` と `swift build` に「unhandled file」の警告は無い。
- `--write-compat-fixtures` を空のフォルダに 2 回書き、K の 7 つと `digests.json` が commit するものと 1 バイトも違わない（大きい 3 つの sha256 も `digests.json` と同じ）。`git archive a21e4692109e504701b507ad9c695181fdecddfd TegakiKit` に対して `tools/compat10/run.sh` → RunReal・RunFrozen とも 225 件・失敗 0。
- 走る XCTest の代わり（作業用・リポジトリの外）で LayoutTests 140 本・InkModelTests 89 本・Compat10Tests 23 本とも失敗 0。`tools/typecheck/typecheck.sh` はエラー 0・警告 0。
- **直した 1 か所**: `Real10LedgerTests` の 1〜3 が `y-2026.tomb200500.json`（線 0 本・墓標 200,500 件）も対象にしていた。1.0 はそのうち 200,000 件しか残さないので、3 の「端末のファイルが fixture と 1 バイトも違わない」が CI の compat-v1.0 で必ず赤になる。墓標が `InkPage.maxTombstones` を超えるページを 1〜3 から外した（上のずれ 9）。直した後、a21e469 のアプリとテストにこのファイルを入れた木で型の確かめ OK・警告 0。

## 見直しの後の直し（役割 FIX）

データの守りの見直し（blocker・major は 0 件、minor 2 件）と文言の確かめ（直すもの 1 件）を受けて直したもの。見直しが始まった後に検証役 vA が直した 2 点（`undoEraserTap` の `parent.tool.isEraser` を外したこと、`confirmLargeImport` が Task の前に `.importing` にすること）は、そのまま残している。

- **消しゴムのタップの取り消し（0-22）の時刻の比べ方**（`Ink/InkCanvasView.swift` の `undoEraserTap`。契約 §2.4 からのずれ）: 契約の `abs(touchBeganAt − tapTouchBeganAt) < 0.1` を、「消した触れ方が、タップの指が触れた時の 0.05 秒前から 0.5 秒後までに始まった」（`touchBeganAt >= tapTouchBeganAt − eraserTapLead`（0.05）かつ `touchBeganAt − tapTouchBeganAt < eraserTapLag`（0.5））に変えた。`tapTouchBeganAt` は指が触れた時刻（`UITouch.timestamp`）、`touchBeganAt` は PencilKit が道具の始まりを知らせた時刻（`uptime()`）で、指の道具の始まりは動きの判定や指を離した時まで遅れうる。0.1 秒を超えると取り消しが走らず、消えた線が墓標付きのまま日のページへ移っていた（1.0.1 と同じ消え方）。前の触れ方は指より前に始まるので戻さない（契約の「前の触れ方で消した分は戻さない」はそのまま）。後から始まった触れ方は `penDidTouch` が `removedSinceTouch` を空にする。0.5 秒の上限は、タップの待ちの間に始まった別の触れ方（Pencil など）を戻さないため。テスト: 新規 `InkCanvasViewTests.testEraserTapRestoresWhenPencilKitBeginsLate`（指が触れてから 0.15 秒・0.49 秒後の Begin → 戻る。0.5 秒・1 秒後、0.06 秒・1 秒前 → 戻さない）。前の比べ方ではこのテストが赤（9 件）、今の比べ方で緑（Mac Catalyst の代わりの台、`InkCanvasViewTests` 37 本・失敗 0）。
- **リードが決めること（直していない）**: 週・月・年のページの 1 回タップはダブルタップの失敗を約 0.3 秒待つので、落ち着く待ち（0.3 秒）の方が先に終わることが多い。そのときは `onEraseEnded` が先に届き、ツールバーの消しゴムはペンに戻ってから線が戻り、日のページはペンで開く。契約 §2.4 の表の「消しゴムのまま日付を指でタップ」の行は「道具は消しゴムのまま」と言っている。データには関係しない（線は戻る）。(1) 今の動き（線を戻してからペン）を既定として契約の表の行を読み替えるか、(2) 指の消しゴムの触れ方では報告をダブルタップの失敗を待つ分（約 0.35 秒）遅らせるかを決める。(2) は指で消した後の自動復帰がすべて 0.35 秒遅れ、その間に書き始めた指の 1 筆が消しゴムのままになる（確認 6b と同じ心配）ので、本人の確認 21 の結果を見てから決めるのがよい。
- **許可の文**（契約 §6.1 の表の最後の行）: `project.yml:64` の `NSCalendarsFullAccessUsageDescription` と DESIGN §4.1 を「カレンダーの予定を手帳のページに表示し、手書きから予定を作るために使います。iOS と iPadOS には読み取りだけの許可が無いため、フルアクセスをお願いしています。予定はこの端末の中だけで扱い、外部には送りません。」に（`docs/PRIVACY.md:108` はもうこの文）。`MARKETING_VERSION` は 1.0.1 のまま（1.1 にするのは C）。
