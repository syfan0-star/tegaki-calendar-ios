# M7c（1.3「横につなげる B-1」）の実装結果

契約は [M7C_CONTRACT.md](M7C_CONTRACT.md)。ここはリードの記録で、段ごとに節を足す。**今の状態は最初の「今の状態」の節を読む。** 各節は書いた時点の記録で、書き直さない（後で変わった物は「今の状態」で読み替える）。

## 今の状態（リード、2026-11-12 01:50）

- 枝 `r13`（origin も同じ）。S1 の Kit の部品が入った。凍結の表の 18 ファイル・アプリ（`Sources/`）・既存のテスト（`Tests/`、`TESTS_1_2_3.sha256` の 8 ファイル）・InkModel の既存の 7 ファイル・compat11・Compat10・CompatFixtures・Compat10Tests・`tools/compat10` は 43fe366 から 1 バイトも変わっていない（`git diff --stat 43fe366..r13` で、Sources と Tests と凍結の範囲は InkModel の新しい 2 ファイルだけ）。
- この Mac の関門: `swift run --package-path TegakiKit KitChecks` が **36,968 件・失敗 0**（約 81 秒）。§12.2 の S1 の関門（この Mac の KitChecks が緑）は満たした。
- CI: a463a69（直しの前）は全部のジョブが緑。55f11a6・4daf2cc は次の push で止まった（`cancel-in-progress`）。4daf2cc は止まる前に build-and-test の KitChecks・Test TegakiKit・凍結の段・lint・TESTS_1_2_3 と compat-v1.0 が緑だった。f982126 の全部の実行の結果は次の節で書く。
- S1 のうち、まだのもの: C の `CompatSpanTests`（§10.2）と §10.4 の compat-v1.0 への追加（`tools/span-compat` の v10・v11・v123 の Probe、`tools/compat-span/EXPECTED_MIN`、43fe366 の台帳のテスト、上限 65 分）、T の試作の写し（§4.6）と `PrototypeIsolationTests`、`span-shots` の最初の形（§10.5 の (1)）、testflight.yml の入力 `span_prototype`、`SPAN_PROTOTYPE` が `project.yml` に無いことの検査。次のワークフローで入れる。

### 段の実績（§12.2 の目安との比べ）

| 段 | 目安 | 実績 |
| --- | --- | --- |
| S0 | 11/11 | 11/11 13:10 に契約を push（c33dd73） |
| S1 の Kit の部品 | 11/12〜11/19 | 本人の「進められるところは、どんどん進めて」（11/11）で前倒し。11/11 21:00 に始め、11/12 01:30 に終わった（12 commit、a29291d〜f982126） |
| S1 の残り（C・T） | 〜11/19 | 11/12 から |

## 本人の操作

- 2026-11-11: iPad Pro 13 と iPad mini で、TestFlight のてがきカレンダーの「自動アップデート」をオフにした（§4.6 の手順 0、§0.5）。この 2 台には試作を入れない。

## S1（TegakiKit の部品。2026-11-11 21:00〜11-12 01:30）

作り方: 3 つの役（Layout の部品 → InkModel の部品と compat-span → CI）を順に、それぞれ commit ごとに `git archive` で取り出した木で KitChecks を通してから push。その後、5 つの観点（契約との一致・データの安全・レイアウト・確かめの強さ（変異の試し）・凍結）で別々の写しから見直し、指摘ごとに別の確かめ役が再現を試し、直し役が直し、最後に仕上げの見直し役が全体を読み直した。

### commit

| commit | 中身 |
| --- | --- |
| a29291d | `SpanName`・`SpanPlan` とその確かめ |
| d92d70b | `SpanAlign`、日・週のエンジンの下限の入力（`extraFloor`、既定 0）、終日帯の日の並びの口（`AllDayBandEngine.pages`） |
| 4ef4fc2 | `SpanLayout` とその確かめ |
| 68edeaa | lint L-13 に `SpanPlan(` を足し、`pageId(at:` を外す |
| 37167ef | 確かめの共用の部品の説明 1 行 |
| 8119f47 | `SpanGuard` とその確かめ |
| dc85b73 | `SpanComposer`・`PageDelta` とその確かめ |
| 9ce206d | compat-span の fixture（§4.2）を Kit の道で作り、1.0 の写しで読む確かめ |
| a463a69 | `tools/span/TESTS_1_2_3.sha256` と CI の段、KitChecks の下限 |
| 55f11a6 | 見直しの直し（下の「見直しで直したもの」）と確かめの強化 |
| 4daf2cc | KitChecks の出力を 1 行ずつ出す・Package.swift の注記の順・下限を 36918 に |
| f982126 | 契約の文を 55f11a6 のコードに合わせる（§18 の 2026-11-12 の行） |

### KitChecks の数と内訳（§10.1。build.yml の注記が指す内訳）

| 節 | 数 |
| --- | --- |
| 1.2.3 までの 46 の節（1.2.2 の 29,982。1.2.3 は変えていない） | 29,982 |
| `span (1.3)`（SpanName・SpanPlan・K-10、SpanAlign・下限・終日帯の並び、SpanLayout） | 819 |
| `span ink (1.3)`（SpanGuard、SpanComposer・PageDelta、compat-span） | 6,167 |
| 合計 | **36,968** |

- CI の下限は N − 50 = **36,918**（`build.yml` の KitChecks の段。前は 29,932）。
- 1.3 より前の節は、節ごとの数が S1 の前と 1 件も変わらない（`section()` に一時的に数を出させて、変える前後で比べた。commit していない）。
- 数は走らせ直しても同じ（辞書の並びに頼る所を直し、3 回確かめた）。
- `compat10: 361 checks`、`compat10 with compat-span: 582 checks`（1 ファイル 17 件）、どちらも失敗 0。

### 窓の表（§3.6）を Kit で計算し直した値

1.1.1 の倍率（`ZoomPolicy.bounds(…).min`）で計算した。週と日では一覧の矩形 = baseSize（1400×1920、1000×2400）なので、1.1.1 で V は変わらない（契約の【推論】を確かめた）。帯 1 レーン分を引いた紙の領域。

| 機種・向き（紙の領域 pt） | 週 倍率・V → 窓 | 日 倍率・V → 窓 |
| --- | --- | --- |
| iPad 11 縦（834×955/951） | 0.4974・1.198 → 5 | 0.3962・2.105 → 7 |
| iPad 11 横（1210×615） | 0.3203・2.698 → 7 | 0.2562・4.722 → 9 |
| iPad 13 縦（1032×1121/1117） | 0.5839・1.263 → 5 | 0.4654・2.217 → 7 |
| iPad 13 横（1366×805） | 0.4193・2.327 → 7 | 0.3354・4.073 → 9 |
| mini 縦（744×878/874） | 0.4573・1.162 → 5 | 0.3642・2.043 → 5 |
| mini 横（1133×525） | 0.2734・2.960 → 7 | 0.2188・5.179 → 9 |
| iPhone 縦（402×540/536） | 0.2812・1.021 → 5 | 0.2233・1.800 → 5 |
| iPhone 横（874×205） | 0.1068・5.847 → 9 | 0.0854・10.232 → 15 |

- B_DESIGN §6.2 の月・年の列も同じ紙の領域で一致した（例: iPad 11 横 月 1.418 → 5・年 2.512 → 7、iPhone 横 月 2.850 → 7・年 5.049 → 9）。
- 別の値（Air 11 縦・横、Pro Max 縦の実測・横の見積もり、iPhone 17 横の実測）でも、必要な窓が表の窓を超えない。
- iPad の横はこの KitChecks だけが自動の確かめ（§4.5）。Duo の内側は R の式だけ（1.37 → 5、2.40 → 7）。`SpanDeviceClass` に Duo は無い（1.4）。
- 機種の分け目: iPad は短い辺で、780 pt 以下が mini、900 以下が 11 インチ、それより上が 13 インチ。
- ずらし量（11 インチ縦の一覧）: 週 696.35 pt → 696、日 396.25 pt → 396。

### この段で決めた数（試作で測り直す）

- 焦点の切り替え 6%（週 84 lu・日 60 lu）。吸い付く近さは画面の幅の 6%。
- はじきとみなす速さ **0.3 pt/ms**（契約に無い数。試作で測る）。
- 「そろった位置」の読み方（55f11a6 の後）: 速くはじいたら隣のページを真ん中に置く。ゆっくり止めたら、どの倍率でも、ページの端と画面の端が画面の幅の 6% 以内ならそろえる（§3.6 の字面どおり）。拡大中に速く払ったときは UIKit の提案の位置まで流れる。
- 線の見積もりは 1 本 250 バイト（切り上げ）。窓の線の上限は iPad 20,000 本・iPhone 12,000 本。

### compat-span（§4.2）

- `TegakiKit/Tests/Fixtures/compat-span/` に MANIFEST と 13 の JSON。作るのは新しいターゲット `CompatSpanFixtures`（`TegakiKit/Tests/CompatSpanFixtures`。台帳と PageSlot の動きを値だけでまねる `SpanLedgerSim`・`SpanSlotsSim` も同じ所）。既存の CompatFixtures のソースを変えないため、別のターゲットにした。
- 作り直し: `swift run --package-path TegakiKit KitChecks --write-compat-span-fixtures [--out <フォルダ>]`。KitChecks は作った中身と commit 済みのファイルをバイトで比べる。CI では、KitChecks が `FAIL: compat-span` で落ちたときだけ、Kit が作る中身を `shots/fixtures/compat-span` に書いて成果物に上げる（`if: failure()`・`continue-on-error`）。
- MANIFEST の形: `#` のコメント 2 行、その後は 1 ファイル 1 行で「<ファイル> <fixture の番号> <monday|sunday>」。週でないページは monday。ファイルの数は fixture 1 が 4、2・3・6・7 が 2 ずつ、5（日曜の週）が 1。**fixture 4（週のメモ）はまだ入れていない**（週のメモの段で足す）。
- 中身（マスからの相対の x）: w-2026-11-02 grid −300…500。d-2026-11-03 grid と extra 690…1300。m1-2026-11 の 2026-11-08 −60…450・memo 1140…1650。y-2026 の 12-20 −188…400・01-20 −156…204。w-2026-11-16 移動の元（墓標 1）→ w-2026-11-23 行き先 300…500（新しい id）。d-2026-11-09 extra 600…1300・d-2026-11-10 extra −300…600。w-2026-11-08（日曜）grid −300…500 と 900…1700。m1-2026-11 と m1-2026-12 は、2026-11-30 と 2026-12-01 のマスに 1 本ずつ。w-2026-11-30 は photo・text（rect は右の端を越える）とセッションの線、w-2026-12-07 は photo（rect の x は −80）とセッションの線。時刻は 1,791,000,000,000 ＋ n、dev は fixture-1.3。
- 作るのに使った差分は 22 個。安全網が拾ったものは 0。fixture 7 の隣のページの保存だけが `.repaired`（stripped 2・dropped 2。窓の名前がもれた形をわざと入れ、見張りが直してもれる前のバイトに戻ることを確かめた）。
- 凍結した 1.0 の写しで読むと、ファイルごとに線・マス・点・墓標・知らない項目が同じで、1.0 が書き戻すバイトも同じ。1.0 が描く線の数: w 左 1、d 右 1（grid だけ。extra は 1.0 では描かない）、m1 右 2、y 2、移動の元 1・行き先 1、extra をまたぐ 2 ファイルは 0、日曜 1 ページに 2、月の重なりは各 2、7 は各 1。
- §4.2 の「S5 でアプリの保存の道で作り直して 1 バイトずつ比べる」は S5。新しい線の `t`（ここでは時計の値、台帳では PencilKit の creationDate）と中心の取り方（ここでは点の外接矩形、台帳では描画の矩形）は作り方で変わりうるので、違ったときはそのときにリードが確かめる。

### CI（build.yml の build-and-test だけ）

- 段「The tests of 1.2.3 unchanged (1.3)」（`shasum -a 256 -c tools/span/TESTS_1_2_3.sha256`。8 行、`git show 43fe366:<path> | shasum -a 256` で作った）を「Data code frozen since 1.1.1」の直後に足した。段の名前の変更（§6.4 の手順 5）は S6。
- KitChecks の下限 36,918 と注記。KitChecks の段の grep を `compat10( with compat-span)?:` に広げた（表示だけ。判定には使わない）。
- KitChecks の `main.swift` の頭で stdout を行ごとに出すようにした（落ちる前の FAIL 行が `tee` のログから消えないように。下の TS-6）。
- r13-quick・span-shots・`SPAN_PROTOTYPE` の検査・testflight の入力・compat-v1.0 への追加は、まだ入れていない（S1 の残り）。
- （リード、11/12）作業用の枝 `r13-w-*` では、写真のジョブ l10n-shots と blank-paper を走らせない（`if: !startsWith(github.ref_name, 'r13-w-')`）。S1 の残りを 2 本の枝で並べて進めるので、macOS の実行機を要るジョブ（build-and-test・compat-v1.0・span-shots）に空けるため。§10.6 の r13-quick とは別の物で、`r13` と main は今までどおり全部走る。

### 契約からのずれ（契約の文は f982126 で直したものを含む）

1. `WeekLayoutInput.extraFloor`（既定 0）を足した。S1 の週には extra が無いので何もしない（どの値でも今と == を KitChecks で確かめた）。週のメモ（§5）で効かせ、そのとき確かめを書き換える。
2. `SpanLayout.init` に `session: Int = 0`（仮想 id `span~<kind>~<n>` の番号）と `viewOnly: Set<String> = []`（1.3 では空。段 1 は 1.8）を足した。
3. `SpanPlan.flingTarget` に `viewportWidth: CGFloat? = nil`（画面の幅の 6% を計る。nil なら機種の基準の幅）と `proposedX: CGFloat? = nil`（UIKit が提案する止まる位置）を足した。
4. `owner(ofCenterX:)`・`focus(midX:previous:)`・`SpanLayout.page(containing:)` の答えは「窓の何枚目か」（0 = 窓の最初）。`origin(of:around:)` は通し番号を受ける。中心の x が NaN・無限のときの owner は 0。focus は [X − 6%W, X + W + 6%W) の間は前の焦点のまま。
5. 機種ごとの基準の紙の領域（`SpanPlan.referenceViewport`）は、縦が CI の実測、横が M4C_CONTRACT §1.2 の見積もり（B_DESIGN §6.2 が使った値）。
6. `SpanName` が前置名と見なすのは、ASCII の数字のページ id の形に `|` が続く名前だけ。ほかの場所に `|` を含む名前はそのまま残す。
7. lint L-13: `SpanPlan(` を足し、`pageId(` の規則から `pageId(at:` を外した（`PageNavigation.pageId` には `at:` のラベルが無いので、外しても見張りは弱くならない。仕上げの見直しで確かめた）。L-13 は 18 件の呼び出し・58 ファイルのまま。
8. 終日帯の日の並びの口は `AllDayBandEngine.pages(_:days:events:now:calendar:holidays:minimumLaneCount:)`。どのページもレーン数は窓全体の数。セッション中に減らさないため `minimumLaneCount` を足した。
9. `SpanComposer.compose(_:plan:session:aliases:)`。`aliases`（`SpanAliases`。D4 の対応表を型にした。番号は 1 から）は、窓をずらしても別名を変えないため。
10. **`deltas(from:epoch:aliases:)` の `aliases` は既定値なし**（C6）。表を渡し忘れると別名の削除が差分から黙って抜けるため。§2.1 の見出しの「新しい引数には既定値」の例外として、契約に理由を書いた。
11. **`unroutedNames(in:aliases:)` を足した**（C1・DS-1）。窓の名前でない素の id（前置なし）の線は、足すときも消すときも、差分でも安全網でもどのページにも届かない（前は足すときだけ cell のページへ送り、消すときは捨てていたので、消した線が生き返った）。その代わり、新しい道では台帳が id を作る 3 か所（`InkLedger.swift` の :422 ↶ の写し、:511 投げなわの写し、:550 新しい線）の全部が `ownerId` を使う（§3.3 の 1）。S は配るたびに `unroutedNames` を見て、空でなければ記録し、Debug では止める（`SpanSession.deliver(_:unrouted:)`、§3.4 (d)）。L のテスト `testEveryIdOfTheJoinedPathIsAnOwnerId` を §10.2 に足した。
12. **`SpanVirtualPage.ledgerPage` は `@_spi(SpanLedger) public`**（C5・DS-4）。§2.1 の「型で漏れを防ぐ」はやめ、「ledgerPage は SPI を import するファイル（台帳・キャンバスと試作の写し）だけに見せ、漏れは実行時に `SpanGuard`（`span~` のページ id はページごと断る）が止める」にした。SPI を import しないファイルから使うとコンパイルで落ちることを確かめた。
13. `SpanGuard` に `isWriteForm`・`savesPageId(_:mode:)`・`isWindowName`・`prototypePrefix` を足した。`SpanComposer.neighborInk(for:from:layout:)`（D17 の `SpanPDFInk` を作る。持ち主のページ id も持つ）、`SpanVirtualPage.owner(ofStroke:)`・`migratedPageIds`・`skippedPageIds`・`with(ledgerPage:)`。`SpanVirtualPage` には JSON も Codable も無い。
14. §10.1 の「added の id の `|` だけが断られる」は、ページは断らず、その項目だけを落とす（dropped）と読んだ（§6.1 の「ページごと断るのはページ id が書く形でないときだけ」に合わせた）。線・墓標・知らない道具の項目のどれにもかける。
15. 書く形は契約の正規表現どおり（数字は ASCII だけ、`\z`）。`d-`・`m1-` は形だけを見るので無い日付も通る。`w-` は日付が実在して月曜か日曜のときだけ通す。
16. **試作（§4.6 (a)）は案 (b)**（C4）: 窓は本物の id で組み、試作の PageSlot が `proto-<id>` として保存する。`.prototype` は `proto-<id>` のページでは `<id>|` を自分の前置として外し（`proto-<id>|` も外す）、ほかのページの前置は落とす。案 (a)（idPrefix）を採らなかった理由: `SpanName` の前置名の形は `proto-` を知らないので、(a) にすると Release の §6.1 の形まで変わる。
17. `extract` は、窓に無いページ id には id が "" の空のページを返す（`InkPage.merge` では "" が中立）。`compose` は `plan.index(of:)` が読めないページ（別の種類、別の週の始まり（K-11）、仮想 id）を `skippedPageIds` に入れる。同じページが 2 回来たら最初の位置に merge する。保存されていた `span~…` の名前は窓に入れない（DS-2。PageSlot には残り、保存の見張りが dropped として落とす）。
18. KitChecks が落ちたときだけ compat-span の中身を書き出す CI の段（§10.6 の表に無い段）。

### 見直しで見つけ、直したもの

指摘 15 件（major 2・minor 13）は、全部確かめ役が再現し、55f11a6・4daf2cc で直した。直しごとに確かめを足し、捨てる写しで古いコードに戻して新しい確かめが落ちることを見た（変異 15 個、全部落ちた）。

| 印 | 重さ | 中身 |
| --- | --- | --- |
| TS-1 | major | 二重に前置した名前を落とす規則を、どの確かめも試していなかった（消しても緑）。確かめを足した |
| TS-2 | major | 「差分を 1 つ落としても安全網で戻る」を無作為の 40 個でしか見ておらず、別名の削除に当たっていなかった。全部の差分で確かめるようにした（約 6 秒増える） |
| C1・DS-1 | minor | 素の id の線の、足すときと消すときの扱いの食い違い（消した線が生き返る）。上のずれ 11 |
| C4 | minor | 試作の決まりと Kit の部品が合っていなかった。上のずれ 16 |
| C5・DS-4 | minor | `ledgerPage` が型で閉じていなかった。上のずれ 12 |
| C6 | minor | `aliases` の既定値。上のずれ 10 |
| DS-2 | minor | 保存済みの `span~a~<n>` と別名の番号が重なると本物の線が墓標で消えうる。保存済みの `span~` の名前を窓に入れないようにした |
| L1 | minor | ゆっくり止めたときの 6% の吸い付きを、一覧の倍率ではページの真ん中から測っていた。§3.6 の字面（端と端）に直した |
| TS-3〜TS-5 | minor | 生き残った変異（`span~` の錨、extract の知らない項目と長い鍵、帯の答え・窓の高さ・墓標の時刻など 5 つ）。確かめを足した |
| TS-6 | minor | Kit の退行で fixture を作る部品のトラップが起きると、`tee` のログから FAIL 行が全部消えていた。stdout を行ごとに出すようにした（トラップの後もログに 104 行の FAIL と理由が残る） |
| F2 | minor | Package.swift の注記の順 |

仕上げの見直しの指摘 1 件（R1。直したコードに契約の文が追いついていない）は、f982126 で契約の §2.1・§3.3 の 1・§3.4 (d)・§4.6 (a)・§10.2・§13 を直した。

### リードの決定（作業者からの問い）

1. **iPhone の横で終日予定のレーンが多いとき**: 表の窓（週 9・日 15）は帯 1 レーンで計算している。帯が上限（紙の高さの 35%、80 pt）まで伸びると V は週で最大 7.99、日で最大 13.98 になり、週はレーン 3 本以上・日は 4 本以上のとき、焦点から 1 ページはじくと窓をずらす前に窓の外の机の色が最大で約 0.5 ページ見えうる。**既定: S の `SpanSession` は、今の紙の領域から `SpanPlan.visiblePages` で V を計算し、`max(表の R, radius(forVisiblePages:))` を使う。ただし窓の線の上限（iPad 20,000・iPhone 12,000 本）は今のまま守り、超えるときは表の R に戻す。** iPad と iPhone の縦では、ふつうのレーン数なら起きない。試作で見え方を見る。
2. lint L-13 で `pageId(at:` を外したこと: よい（上のずれ 7）。
3. はじきの速さ 0.3 pt/ms と「そろった位置」の読み方: 試作の感想で見直す（0c-17）。
4. `WeekLayoutInput.extraFloor`: 週のメモの段で効かせる。
5. Duo の機種の分類と窓の行: 1.4。
6. MANIFEST の形: このまま。C の CI の写しの確かめと `CompatSpanTests` はこの形を読む。
7. `SaveCheck.repaired` を返したときの「直したことを記録し、Debug では止める」は画面の側（`PageSlot.persist`、S5）。Kit は stripped と dropped の一覧を返すだけ。
8. `CompatSpanTests`（§10.2 の C）と §10.4 の compat-v1.0 への追加: S1 の残りとして次のワークフローで入れる。`tools/compat-span/EXPECTED_MIN` は CI の `real N=` の実測から決めて、ここに書く。
9. `lint-skip.txt` への分け（§6.4 の手順 1）: S4 の始め（契約どおり）。

### 確かめの記録（この Mac）

- `swift build` 緑。KitChecks 36,968 件・失敗 0。
- `shasum -a 256 -c`: `tools/compat10/DATA_1_1.sha256` 18 行、`tools/span/TESTS_1_2_3.sha256` 8 行、Compat10 の `FROZEN.sha256` 11 行、全部 OK。
- `tools/l10n/lint.py` exit 0（L-12 は今までどおり警告だけ）。`tools/typecheck/typecheck.sh` all OK（`CompatSpanFixtures` と SPI の import を含む）。
- Layout のファイルは InkModel を import していない。
- 差分と 12 の commit の文に、ローカルの絶対パスや個人の情報は無い。12 とも Co-Authored-By の行がある。
- 見直しの写し（`rev-*`）は全部 `git worktree remove` で外した。
- 節ごとの数・変異ごとのログはスクラッチパッドの s1-logs・s1-fix-logs にある（commit していない。毎日 0:00 の掃除で消えうる）。
