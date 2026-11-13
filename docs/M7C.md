# M7c（1.3「横につなげる B-1」）の実装結果

契約は [M7C_CONTRACT.md](M7C_CONTRACT.md)。ここはリードの記録で、段ごとに節を足す。**今の状態は最初の「今の状態」の節を読む。** 各節は書いた時点の記録で、書き直さない（後で変わった物は「今の状態」で読み替える）。

## 今の状態（リード、2026-11-13 21:10）

- 枝 `r13`（origin も同じ）。S1〜S4 は済んだ。S2 の見本の画像と S3 の試作（版 1.3・ビルド 24）は 11/12 に本人へ届けた。S5（本体）は 11/13 06:30 に前倒しで始め、**第 1 陣（S・P・C・U の前半）を 11/13 21:10 に `r13` へ入れた**（7ec3c6c まで早送り。下の「S5」の節）。次は第 2 陣（L のキャンバス）。H4 の直し（枝 `h4-fix`）は f5ae07d で `r13` に入れた（1.3 で直す既定のとおり。1.2.4 で出すときも同じ commit を使う）。
- 画面はまだどの種類も 1 ページの道（D2）。横の道の部品（`SpanSession`・紙・見出し・終日帯・PDF の隣の線・設定「ページ」・案内の札）は入ったが、画面から呼ぶのは第 3 陣。
- ふつうのアプリと 43fe366 の違い: 凍結の表のうち `Ink/InkLedger.swift` と `Sync/SyncEngine.swift` の 2 つが S4 で変わり、`tools/compat10/DATA_1_1.sha256` はその 2 行だけを書き直した（§6.4 の手順 2。ほかの 16 行は 43fe366 のまま）。今の画面（1 ページの道）の振る舞いは変わらない（S4 の節の「1 ページの道の記録」）。既存のテスト（`TESTS_1_2_3.sha256` の 8 ファイル）・InkModel の既存の 7 ファイル・compat11・Compat10 は 43fe366 から 1 バイトも変わっていない。試作は `#if SPAN_PROTOTYPE` の中のまま。
- `tools/span/prototype_gate.py --base 43fe366` は `r13` の先頭では FAIL になる（S4 の 2 ファイル）。これは S3 の試作のビルドだけの関門で、CI では走らない（testflight.yml の `span_prototype=1` のときだけ）。試作を作り直すときはタグ `r13-proto-1` から作る。
- この Mac の関門（dcf32f0。リードが 11/12 23:55 に確かめた）: KitChecks **36,968 件・失敗 0**（Kit は S1 から変わらない）、typecheck は試作の印なし・ありの両方で all OK（アプリの警告 0、TegakiCalendarTests 39 ファイル・UITests 6 ファイル、警告 0）、lint OK（読むアプリのファイルは 65 → 69）、DATA_1_1 18/18・TESTS_1_2_3 8/8 OK、`prototype_gate_test.py` 14 件 OK。
- CI: `r13` の dcf32f0（80c900e ＋ 1.0 の試験の待ち方の直し）の run 43237335436 は 5 つのジョブが全部緑（11/13 00:44、build-and-test 77 分）。
- 読み替え: S1 の節の「CI」の項の「r13-quick … まだ入れていない」は、073e748 で入った（§10.6。`r13-quick` の枝はまだ作っていない。S5 で最初に push したときが最初の実行）。
- 文書の掃除: 647ea01 で、前の段の文書 7 つにあった手元の絶対パス（利用者名を含む）を `~/`・`<scratchpad>/`・`<Claude のセッションの記録>/` に置き換えた。main には 1.3 をまとめるときに入る。docs だけの commit は CI を走らせない（`[skip ci]`）。
- 1.2.3 の穴 **H4**（下の「H4」の節）: 「全て消す」の後に、今の 1.2.3 の `pageOpened`／`fetchPage` が消したページを端末に戻し、次の起動で iCloud に送り直すことがある。43fe366 の本物の同期のコードで再現した。直し（2 行）は枝 `h4-fix`（43fe366 から、2470c5d）で、`r13` には f5ae07d で取り込んだ（凍結の表の SyncEngine の行は取り込んだファイルから計算し直した、1b79f377…）。1.2.4 で出すかは、1.2.4 を作るかの判断（S1' の後）で決める（既定は 1.3）。

### 段の実績（§12.2 の目安との比べ）

| 段 | 目安 | 実績 |
| --- | --- | --- |
| S0 | 11/11 | 11/11 13:10 に契約を push（c33dd73） |
| S1 の Kit の部品 | 11/12〜11/19 | 本人の「進められるところは、どんどん進めて」（11/11）で前倒し。11/11 21:00 に始め、11/12 01:30 に終わった（12 commit、a29291d〜f982126） |
| S1 の残り（C・T） | 〜11/19 | 11/12 01:44〜12:55（33 commit、1ce392a〜073e748。下の節） |
| S2 見本の画像 | 〜11/20 | 11/12 14:30 ごろ確認ページを本人に送った（073e748 の画像 23 枚。iPad の横は無い） |
| S3 試作を TestFlight へ | 〜11/21 | 11/12（下の「S3」の節） |
| S4 台帳ほか | 11/21〜 | 11/12 14:05〜23:20（枝 r13-s4、11 commit）。試作が VALID になった（15:29）後の 23:30 に r13 へ早送りで入れ、1.0 の試験の直し dcf32f0 を足した（下の「S4」の節） |

### 予定の前倒し（2026-11-12、本人の「早く出来るのであれば、予定を前倒ししましょう」）

| 段 | 契約の目安（§0.4・§12.2） | 新しい目安 |
| --- | --- | --- |
| S2 見本の画像 | 11/20 ごろ | 11/12（済み） |
| S3 試作を TestFlight へ | 11/21 ごろ | 11/12〜11/13 |
| S4 台帳・組の印・lint の範囲 | 11/21〜 | 11/12〜。Y（SyncEngine の 2 つの口、§7）も画面に出ないので S5 から S4 へ移した |
| 試作の感想の期日 | 11/25（11/21 に届いた場合） | 11/18（水）。決まりは同じ「届いた後の最初の土日の、次の水曜まで」。期日の後の感想も本体に反映する（§0.6） |
| S5 本体（画面に出る部分） | 11/27〜 | 11/19〜（週の利用枠が 11/18 の昼に戻るのとも合う） |
| 1.2.4 を作るかの判断 | 11/27 | S1'（年齢区分の 2 問、11/16〜20）の結果が出たらすぐ |
| 早い道かふつうの道かの判断 | 12/9 | 本体が全部のジョブで緑になった時点（12/9 より前でも）。12/16 までの提出と 12/19〜1/4 に審査に出さない決まりは変えない |

- 1/15（週のメモの関門）と 2/15（Duo の決まり）は変えない。
- 週の利用枠: 11/12 13:00 に 34%（11/18 の昼に戻る）。本人は無料の枠の回復を 1 回持っている（11/12）。今は使わず、95% に近づいて作業が止まりそうなとき（特に S5 の 11/19〜12/9）に本人に知らせて押してもらう。
- 追記（11/12 23:50）: 週の利用枠は 48%。無料の枠の回復は週の枠を 0 に戻すフルリセットで、使える期限は 12/11（本人、11/12 18:00）。押すのは本人。12/9 までに使わなかったときは、12/10 に週の枠が半分を超えていれば押してもらう。

## 本人の操作

- 2026-11-11: iPad Pro 13 と iPad mini で、TestFlight のてがきカレンダーの「自動アップデート」をオフにした（§4.6 の手順 0、§0.5）。この 2 台には試作を入れない。
- 2026-11-12: 「早く出来るのであれば、予定を前倒ししましょう」（上の表）。
- 2026-11-12 18:00: 「今のままで良いです。進めて下さい。フルリセット、期限12/11です。」（無料の枠の回復の使い方はリードの案のまま。「今のまま」は iPhone 横の形の答えとしても、おすすめと同じなので、そのまま進む）。

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

## S1 の残り（C・T）と S2 の見本の画像（2026-11-12 01:44〜14:30）

作り方: 2 本の作業用の枝を並べて進めた。`r13-w-c`（C: 互換・CI・版の確かめ）と `r13-w-t`（T: 試作。核 → 動きと計測 → 見本の場面と span-shots の 3 つに分けて順に）。それぞれ CI を緑にしてから、`r13` に `git merge --no-ff` で取り込んだ（1ce392a・63731e1、衝突なし）。その後、5 つの観点（試作の切り離し・S3 の関門とふつうのビルド・互換・試作の動き・CI）で別々の写しから見直した。指摘 30 件のうち 23 件を確かめ役が再現し、直し役が 22 件を直した（dc39173〜80d7c54。B9 は文書だけの誤りでコードの直しは無い）。最後に仕上げの見直し役が全体を読み直し、2 件（B1-R・SCOPE-1）を直した（ab612d6・073e748）。

### commit（`r13` の first-parent。取り込んだ枝の中の commit は 33 個）

| commit | 中身 |
| --- | --- |
| 1ce392a | C の枝を取り込む（下の C の中身） |
| 63731e1 | T の枝を取り込む（下の T の中身） |
| dc39173 | S3 の関門 (2) の穴をふさぐ（43fe366 の行を `#if` で囲む塊・試作でないキー・InfoPlist の新しいキーを落とす） |
| 7687fa0 | 試作のビルドは版 1.3 でないと作らない・span-shots の上げ直しを上書きに・ja-baseline の上限 90 分 |
| 0621585 | CompatSpanTests で compat-span の 13 ファイルの SHA-256 を手で書いて固定 |
| cda71ab | 試作の見直しの直し（回転はペンが離れてから窓を決め直す・線の数・日の帯・終日帯・週のメモの 3 つ目の形・案内の札・小さな HUD ほか） |
| 80d7c54 | 試作の日の帯の注記を「見本の日です」に |
| ab612d6 | 「線の数」は窓が埋めた週の先へ動いたときも足りない週を入れ直す（B1-R） |
| 073e748 | CI に速い確かめの道 `r13-quick` を足す（§10.6、SCOPE-1） |

### C の中身

- `TegakiKit/Tests/CompatSpanTests`（新しいターゲット）: §10.2 の 4 本。CI の Test TegakiKit で「Executed 4 tests, with 0 failures」。期待する値は手で書いた（CompatSpanFixtures に頼らない）。13 ファイルの SHA-256 も手で固定（0621585）。
- compat-v1.0（§10.4）: 月曜の compat-span 12 ファイルを compat11 の一時フォルダに写して確かめる段、`tools/span-compat`（1.0・<1.1.1>・1.2.3 の本物の Kit の Probe）、43fe366 のアプリの台帳のテスト `Real123LedgerTests`、上限 65 分。
  - real N: 1.2.3 の見本だけで 361、月曜の compat-span を写した後 **565**（= 361 + 12 × 17。1 ファイル 17 件）。`tools/compat-span/EXPECTED_MIN` = 565。`tools/compat10/EXPECTED_MIN` は 225 のまま。
  - span-compat: 1.0（a21e469）225 件・失敗 0、<1.1.1>（9cbc3c9）225 件・失敗 0、1.2.3（43fe366）227 件・失敗 0。3 つの版とも fixture 7 の知らない道具の項目と墓標は 1 バイトも変わらない。
  - Real123LedgerTests 4 本・Real10LedgerTests 4 本とも合格。1.2.3 の台帳では、どのはみ出す線も needsMoreRoom が false。
  - 時間: 12.2〜13.8 分。
- build-and-test: `SPAN_PROTOTYPE` が `project.yml` に無いことの段（AGE_FORCE と同じ形）と、`prototype_gate_test.py` の段（14 件）。
- testflight.yml の入力 `span_prototype`（"1" のときだけ）: `marketing_version` が "1.3" でなければ止める・`age_force` と一緒なら止める・43fe366 の DATA_1_1 の `shasum -c`・TESTS_1_2_3・`tools/span/prototype_gate.py --base 43fe366`・アーカイブに `SpanPrototype` があり版が 1.3 であること・run の要約にビルドの番号。空なら今までどおり。
- J-4（§10.5）: `tools/l10n/ja-baseline-ref-1.3.txt`（43fe366）と、ja-baseline.yml の写真の段を 43fe366 の build.yml から写し直した（`ja-baseline-ref.txt` は 1 バイトも変えない）。上限 90 分（実測 61.6 分）。

### T の中身（全部 `#if SPAN_PROTOTYPE` の中。ふつうのビルドには入らない）

- `Span/SpanPrototypeLedger.swift`（台帳の写し。id を作る 3 か所が全部持ち主の前置つき・日誌から差分・生きている id だけを墓標に）、`SpanPrototypeCanvas.swift`（キャンバスの写し。窓の帯・線は中心の下のページ・帯の外は捨てる・差分を受け箱へ）、`SpanPrototypeSession.swift`（一時フォルダ `span-prototype-<uuid>` の `proto-` のページ・`InMemoryCloudDatabase`・始めない `SyncEngine`・差分と安全網）、`SpanPrototypeScreen.swift`（設定 › 情報 のいちばん下の「横につなげる試作」から開く）、`SpanPrototypeShots.swift`（`--screenshot-prototype <場面>`）ほか。
- 動き: 焦点・止まったら窓をずらす・はじき（0.3 pt/ms、6% の吸い付き）・◀ ▶・手のひら（Pencil が触れている間と離して 0.5 秒）・一覧の 24 pt の動き出し・回転や「上限あり」はペンが離れてから窓を決め直す。
- 計測（画面の隅の小さな HUD）: 窓の差し替えの時間・差し替え後 1 秒のコマの間の最大・メモリ（phys_footprint）・ペンを離したときの止まり・消しゴム 1 回で消える線の数・1 ページの読み込み・指の大きさ。「線の数」2,500・10,000・25,000（窓の中の合計。横に動いたときも足りないページを入れ直す）。
- 切り替え: iPhone 横の「今のまま／上限あり」・「1 ページずつ（古い版の見え方）」・週の始まり・週と日。週のメモの欄（罫線だけ／方眼／曜日の線つき）。初めての案内の札（§8.1 の N-4〜N-7 の文のまま、8 秒、触れても消える）。
- テスト: `PrototypeIsolationTests` 4 本（本物の ink フォルダの全ファイルの名前と SHA-256 が前後で同じ・shared の save と pageOpened が呼ばれない・shared.onRemoteUpdate が同じまま・`.prototype` が本物の id を断る）と `SpanPrototypeInteractionTests` 20 本。
- CI の span-shots（§10.5・§10.6）: 試作の印はコマンドの行だけ、別の DerivedData（build/ProtoData）。`PrototypeIsolationTests` 4 本以上・`SpanPrototypeInteractionTests` 19 本以上・失敗 0 でなければ落とす。見本の画像 23 枚。約 35 分。

### 契約からのずれ

1. 試作の文の ja だけのキー: 1.2 の仕組み（`tools/l10n/build.py`）はアプリのキーに ja だけを許さなかったので、名前が `prototype.` で始まるアプリのキーだけ許した（`APP_JA_ONLY_PREFIX`）。既存のテスト `LocalizationBundleTests.swift`（`TESTS_1_2_3.sha256` の 8 ファイルの外）の `testEveryLanguageBundleHasEveryKey` が ja だけのキーを飛ばすようにした（§10.2 の 1 文目「既存のテストのファイルは変えない」から外れる）。`testJapaneseMatchesTheOneOneBaseline` は今も ja を見る。
2. `--screenshot-prototype` は Support/ ではなく `Span/SpanPrototypeShots.swift` で読む（S3 の関門 (2) の範囲に収めるため。`ScreenshotMode.swift` は変えていない）。
3. 試作の手のひらの規則は縦の動きも止める（§3.6 と B_DESIGN は横の動き出しだけ）。`majorRadius` で大きな接触を外す規則（§3.6 の【推論】）は入れず、HUD に指の大きさを出して測る。
4. 試作は窓の線の上限（D18）を掛けない（25,000 本を測るため）。段 2 の切り替えも無い。
5. 帯の上に、1.2.3 の `StickyHeaderView` を窓のページごとに並べた日付の見出しを足した（頼まれていない。写真を読めるようにするため）。
6. 週のメモの形は 3 つ: 罫線だけ・方眼（罫線と 50 lu ごとの縦線。日の自由メモには方眼が無いので、契約の「日の自由メモと同じ方眼」のとおりには作れない）・曜日の線つき（PLAN_WEEK_MEMO の Q2 のもう一方）。線は週の境目で切れ（40 lu の余白）、「自由メモ」の見出しはページごと。
7. span-shots は契約の `PrototypeIsolationTests`（4 本以上）に加えて `SpanPrototypeInteractionTests`（19 本以上）も求める。
8. 試作の一時フォルダは、試作を閉じたときに消す。前の起動で残ったものは次に開いたときに消す。
9. `CompatSpanTests` の依存は Compat10・InkModel・Layout だけ（Compat12Tests の形）。`EXPECTED_MIN` は「1.2.3 の N ＋ 月曜の 12 ファイルが増やす確かめの数」と読んだ（ファイルの数 12 を足すだけでは 1 ファイル欠けても気づけない）。
10. 見本の画像の iPad 11 は iPad Air 11（M4）（本人の端末。最初のジョブの写真は iPad Pro 11）。
11. `r13-quick` は `swift test` と macOS の確かめ（lint・凍結の表・関門のテスト）も残した（§10.6 の字面は build・Span のテスト・KitChecks だけ。数分で、CompatSpanTests が swift test にあるため）。

### 見直しで見つけ、直したもの（確かめ役が再現した 23 件。重い順）

| 印 | 重さ | 中身 |
| --- | --- | --- |
| ISO-1・G1・CI-1 | major | S3 の関門 (2) が、43fe366 の既存の行を `#if SPAN_PROTOTYPE` で囲む変更を通していた（ふつうのビルドから行が消えても OK になる）。塊を取り除いたファイルが 43fe366 と 1 バイトも違わないことを求めるようにした |
| B1 | major | 「線の数」の合計が、回転・「上限あり」・横の移動で窓のページ数が変わると、選んだ数でなくなっていた（横の移動の分は仕上げの見直しの B1-R で直した） |
| B4 | major | 試作に日のページが無く、日の帯の見本の画像と「iPhone 横の日の一番広い窓」の計測が欠けていた。日の帯を足した |
| ISO-2・G2・CI-2 | minor | 文の表の新しいキーを名前で制限していなかった。`prototype.` で始まり ja だけのものに限った。InfoPlist の新しいキーは落とす |
| G3・CI-3 | minor | 試作のビルドの版 1.3 を強制していなかった |
| ISO-3 | minor | ずらし以外の組み直し（回転など）がペンを置いている途中に起きうる。ペンが離れるまで待つようにした |
| ISO-4 | minor | 試作を開いたままアプリが終わると一時フォルダが残る。次に開いたときに消す |
| C-R2-1 | minor | CompatSpanTests が線の y・色・時刻を固定していなかった。13 ファイルの SHA-256 を手で固定した |
| B2 | minor | 見本の画像に終日帯の行が無かった。足した |
| B3 | minor | 週のメモの 2 つ目の形が PLAN_WEEK_MEMO の Q2 のもう一方ではなかった。曜日の線つきを 3 つ目に足した |
| B5 | minor | 手のひらの手当てが §3.6 と違う（上のずれ 3）。一覧の 24 pt の動き出しは入れた |
| B6 | minor | メモリの山を取りこぼしうる。差し替え後 1 秒はコマごとに測る |
| B7 | minor | 案内の札が、タップとピンチで消えなかった |
| B8 | minor | HUD が大きく、iPhone の横で比べるのを邪魔した。小さくした |
| B9 | minor | T の写真の説明の誤り（iPhone 縦の boundary は約 1.05 週）。コードの直しは無い |
| CI-7・CI-8・CI-11 | minor | span-shots の上げ直しの上書き、ja-baseline の上限（90 分に）、日の帯の写真（B4 で解消） |

### リードの決定（作業者からの問い）

1. 上のずれ 1（`LocalizationBundleTests.swift` と build.py の例外）: 認める。S6 で試作の写しを消すときに ja だけのアプリのキーが無くなるので、そのとき 2 つとも 43fe366 のバイトに戻す。
2. 手のひらで縦も止めるか（ずれ 3）: 試作の感想を見て S5 の初めに決める。既定は §3.6 のまま（本物のキャンバスは横の動き出しだけを止める）。
3. 帯の上の日付の見出し（ずれ 5）: 試作に残す。
4. iPhone 横の一番縮めた形「今のまま」では、日付の数字と祝日の名前が重なって読みにくい（見本の 4-1）。S5 で、狭いときに見出しを間引く（P の仕事）。本人には確認ページで「決めていただく必要はありません」と知らせた。
5. 週のメモの線が境目で切れること・見出しがページごと（ずれ 6）: 週のメモの段（§5。1/15 の関門の後）で決める。
6. span-shots の `SpanPrototypeInteractionTests` 19 本以上（ずれ 7）: このまま。
7. compat-v1.0 の上限 65 分（実測 12.2〜13.8 分）: S4 を取り込んだ後に測り直してから戻すか決める。
8. build-and-test（:822 あたり）と l10n-shots（:1271 あたり）の「The app is not running」の誤った警告（`grep -q` と `pipefail`。警告だけでジョブは緑）: S5 の C の仕事で直す。
9. J-4 の読み方: M7B.md C1 と同じ（強い差 0・基準だけ 0 なら「違う写真 0 枚」）。
10. 試作のアーカイブの確かめ（署名したバイナリに `SpanPrototype` の文字があるか）は、最初の試作の TestFlight の run で初めて分かる（Release の最適化の後に型の名前が残るか）。

### S2 の見本の画像（§4.5）

- 073e748 の run 43149906124 の成果物 span-shots の 23 枚（iPad Air 11・iPad Pro 13・iPad mini・iPhone 17。iPad は縦だけ）。リードが 23 枚とも開いて、場面の名前どおりに写っていることを見た。
- 確認ページは 1 枚（題「見本の画像（1.3 の前）・commit 073e748」）。8 つの節: 週の帯・日の帯・日曜始まり・iPhone 横の一番縮めた形（今のまま／上限あり）・一覧・古い版での見え方（1 ページずつ）・初めての案内の札・週のメモの形。iPad の横が無いことと、その理由を書いた。答えは任意（§0.5）。11/12 に本人に送った（ページの HTML は手元だけで commit しない）。
- 成果物の期限は 2026-11-19。

## S3（試作を TestFlight へ。2026-11-12）

### 関門（§12.2 の S3。機械で確かめた）

| 関門 | 結果 |
| --- | --- |
| (1) 凍結の 18 ファイルが 43fe366 の表で `shasum -c` OK | 647ea01 で 18/18 OK（この Mac）。testflight.yml の段でも確かめる |
| (2) `git diff 43fe366 -- Sources/TegakiCalendar` の範囲 | `tools/span/prototype_gate.py --base 43fe366` が OK: `Span/SpanPrototype*.swift` 7 ファイル（全体が `#if SPAN_PROTOTYPE` の中）・`SettingsScreen.swift` の 4 行（`#if SPAN_PROTOTYPE` の中。塊を除くと 43fe366 と同じ）・`prototype.span.*` のキー 33 個（ja だけ） |
| (3) span-shots の `PrototypeIsolationTests` が 4 本以上・失敗 0 | 073e748 の run 43149906124: 4 本合格（試作のテスト全体で 24 本・失敗 0） |
| (4) J-4 の日本語の写真が 43fe366 と同じ | 合格（下） |

- そのほか: `TESTS_1_2_3.sha256` 8/8 OK、`project.yml` に `SPAN_PROTOTYPE` なし。

### J-4（§10.5。M7B.md C1 の読み方）

- 基準: ja-baseline.yml を `r13`（073e748）で走らせた run 43158921131（2026-11-12 05:04〜06:00 UTC、成果物 `ja-baseline-43fe366`）。env.txt（Xcode 26.6 17F113・機種と iOS）は下の 2 つの run と同じ。
- 073e748 の run 43149906124 の `screenshots` と比べると、77 枚のうち同じ 55・弱い差だけ 21・**強い差 1**（`ipad13-portrait-sheet-holidays.png`）・基準だけ 0（新だけは UI テストの 31 枚）。強い差の 1 枚は、祝日の画面に移る前の設定の画面が写っていた（写真の段は起動から決まった 9 秒で撮る。build.yml の 13 インチの 11 のシートの段）。撮る時刻の揺れで、コードの違いではない。
- 同じ UTC の日の 80d7c54 の run 43136565762 の `screenshots` と比べると、**77 枚のうち同じ 58・弱い差だけ 19（最大 9/255）・強い差 0・基準だけ 0**。80d7c54 と 073e748 のふつうのビルドのコードは同じ（`git diff 80d7c54 073e748 -- Sources project.yml TegakiKit/Sources` は `Span/SpanPrototypeScreen.swift`・`SpanPrototypeSession.swift` だけで、どちらも全体が `#if SPAN_PROTOTYPE` の中）。よって「違う写真 0 枚」と読む（リードの決定 9）。
- 次の 1 枚の揺れを減らすため、13 インチのシートの段の決まった 9 秒を「画面が出たのを待つ」形にするかは、S5 の C の仕事で見る（下の S5 への申し送り）。

### 試作のビルド

- 2026-11-12 15:15（JST）に testflight.yml を `r13`（647ea01。073e748 に docs だけを足した commit）で、`marketing_version=1.3`・`span_prototype=1` で走らせた（run 43166806113）。**ビルドの番号は 24**（run の番号）。タグ `r13-proto-1`（647ea01）を付けた。S4 で表のファイルが変わった後に試作を作り直すときは、このタグから作る。
- 後で本物の 1.3 を出すとき、提出のスクリプトは版に付けるビルドが 24 でないことを確かめる（§4.6）。ビルド 24 は、次のふつうのビルドが TestFlight で使えるようになって（VALID）から期限切れにする。
- ビルド 24 は 15:29 に VALID、内部のテスト（IN_BETA_TESTING）に入った。アーカイブの確かめ（testflight.yml）: 版 1.3・ビルド 24・SpanPrototype が入っている。VALID の後、§4.6 の手順 1〜6 を、期日 11/18（水）を添えてチャットで本人に送った（入るのは iPad Air 11 と iPhone だけ）。

### S5 への申し送り

- iPhone 横の一番縮めた形「今のまま」の日付の見出しが重なる（リードの決定 4。P）。
- 写真の段の「The app is not running」の誤った警告（決定 8。C）と、13 インチのシートの段の決まった 9 秒（上の J-4。C）。
- 手のひらで縦も止めるか（決定 2。L）。

## S4（台帳・同期の 2 つの口・lint の読む範囲。2026-11-12 14:05〜23:30）

予定の前倒しで、試作の後ではなく試作と並べて、作業用の枝で作った（Workflow wf_c205445e-6e8: 作る 3・まとめ 1・見直し 5・確かめ 5・直し 2・最後の点検 1 の 17 人）。D12 のとおり、`r13` には試作のビルド 24 が VALID になった後で入れた（23:30、ac3e896 → 80c900e の早送り。続けてリードの dcf32f0）。

### commit（`r13` に入った順）

| commit | 中身 |
| --- | --- |
| d330aa8 | lint が読まないファイルの一覧を `tools/l10n/lint-skip.txt`（14 行）に分け、1.3 で変える 4 つ（InkLedger・InkCanvasView・InkOverlayView・SyncEngine）を読ませる（§6.4 の手順 1）。4 つに lint の指摘は 0。一覧の行が古い・重なる・表に無いときは lint が落ちる |
| ba6a9d9 | 台帳（L）: §3.3 の 5 か所（id の持ち主・横の道の記録・`pruneHistory(touching:)`・`needsMoreRoom` の接頭辞・消しゴムでない削除を断る）と §4.4 の組の印。`InkLedgerSpanTests` 8 本。DATA_1_1 の InkLedger の行を同じ commit で書き直し |
| 4bec111 | 同期（Y）: `onRemoteDelete` と `pagesOpened(_:)`（§7）。`SyncEngineSpanTests` 6 本（M4_CONTRACT §8.2 の 54〜59）。DATA_1_1 の SyncEngine の行 |
| a95c860・e83fb10 | 20 回くり返しの段に `SyncEngineSpanTests` を足し、クラスごとの時間を出す（§10.6。上限は測った時間から 9 分のまま） |
| 4b5be49・7bbc5b5 | `r13-s4` への取り込み（ぶつかり無し） |
| 3554bf3 | 見直しの直し: `allowRemovals: false` で断るのは横の道だけ（§3.3 の 5。1 ページの道は 1.2.3 のまま常に受け取る）。墓標にしなかった id を `InkChange.alreadyErased`・`unknownRemovals` で返す（§3.4 (a)）。テストを強める |
| 1c8a356 | 見直しの直し: `pagesOpened` は「全て消す」の iCloud の分が残る間と、呼んだ後に epoch が動いたときは取りに行かない。テストを強める |
| 62939eb | くり返しの段のクラスごとの数を、期待する数（回数 × テストの数）と比べ、足りなければ警告 |
| 80c900e | 最後の点検の直し（テストだけ）: ゾーンが消えたときにアカウントを先に確かめること、混ざった変更が消えていた id の指紋も忘れること |
| dcf32f0 | リード: 1.0 の同期の試験の待ち方（下の「1.0 の試験の道具」） |

### 1 ページの道の記録（§6.4。凍結の表のファイルを変えた commit ごと）

| commit | ファイル | 1 ページの道が通る行 | 理由（§6.4 の表の行） | 通る既存のテスト |
| --- | --- | --- | --- | --- |
| ba6a9d9（4b5be49 で取り込み） | `Ink/InkLedger.swift` | 49 行（既存の 24 行を変え、25 行を足した）: id を作る 3 か所（`ownerId?(cell) ?? makeId()`）、履歴の歩の型（§4.4）、記録の呼び出し（`ownerId` が nil ならすぐ戻る）、`applyCanvasChange` の引数（既定 `true`）と戻り値、`needsMoreRoom` の接頭辞外し（1 ページでは何もしない）、新しい property の初期値。振る舞いの違いは 0（43fe366 の台帳と並べて同じ操作を与える手元の比べ 46,835 歩で違い 0） | InkLedger.swift の行（§3.3 の 5 か所と組の印） | InkLedgerTests 24（testLedgerWritesTheCompatShapes を含む）・WeekStartLedgerTests 2・InkCanvasViewTests のうち canvasViewDrawingDidChange を呼ぶ 6 本・EraserAndBelowDayUITests 8・InkSnapshotTests |
| 4bec111（7bbc5b5 で取り込み） | `Sync/SyncEngine.swift` | 1 行: `apply` の削除の輪の `onRemoteDelete?(name)`（S5 まで nil なので何もしない）。ほかは既存の関数の外（property 7 行と、1 ページの道が呼ばない新しい extension 81 行） | SyncEngine.swift の行（2 つの口だけ。今の関数の中は onRemoteDelete の 1 行だけ） | SyncEngineTests.test11DeletedNamesRemoveTheFile（単体と 20 回くり返し） |
| 3554bf3 | `Ink/InkLedger.swift` | 7 行: 断る条件に `ownerId != nil` を足した行、最後の return、InkChange の 2 つの property（既定は空）ほか。1 ページの道では新しい一覧は常に空。43fe366 の台帳と並べた比べ 77,764 歩（`allowRemovals` を true/false の乱数で渡す）で違い 0 | 同上（§3.3 の 5「1 ページの道は今どおり（常に許す）」） | 同上 |
| 1c8a356 | `Sync/SyncEngine.swift` | 0 行（1.3 の extension だけ） | 同上 | — |
| 80c900e | （テストだけ） | 0 行 | — | — |

- DATA_1_1.sha256 は InkLedger と SyncEngine の 2 行だけが 43fe366 と違う（`r13` で 18/18 OK）。TESTS_1_2_3 8/8 OK。

### 見直し（5 つの見方。14 件のうち確かめ役が再現したもの 10 件、どれも minor。全部直した）

| 見方 | 再現した指摘 | 直し |
| --- | --- | --- |
| 1 ページの道・台帳 | OP-1/L-1: 1 ページの道でも `allowRemovals: false` で削除を断っていた（§3.3 の 5 は「常に許す」）。L-2: ページごとの「半分以上」をテストが固定していない。L-3: 墓標にしなかった id を返さないので、S5 のキャンバスが記録できない。L-5: 生きていない id だけの変化・古い歩を通って届く組をテストが固定していない。OP-2: 1 ページの道の記録の文の誤り | 3554bf3（OP-2 は上の表で直した） |
| 同期 | Y-1: `pagesOpened` が「全て消す」の iCloud の分が残る間も取りに行く。Y-2: `onRemoteDelete` が記録の無いページや取り込みで呼ばれないことをテストしていない。Y-3: 状態の門・見た変更タグ・ゾーンの回復・通信なしの枝をテストしていない | 1c8a356 |
| CI | R4-CI-1: くり返しの段のクラスごとのまとめが、割れたログの行を数え落とす | 62939eb |
| 凍結 | 2 件とも再現せず | — |

- 最後の点検の 2 件（ゾーンが消えたときのアカウントの確かめ・混ざった変更の指紋）はテストを強めて直した（80c900e）。どの直しも、外すとそのテストが落ちることを手元の写しで確かめた（作業者の記録）。

### CI

- r13-s4 7bbc5b5（run 43176186917）: 1 回目に compat-v1.0 だけ落ちた（下の「1.0 の試験の道具」）。落ちたジョブだけ走らせ直して緑。
- 62939eb（run 43202786785）: 5 つのジョブが全部緑。単体テスト 482 本（skip 8・失敗 0）。くり返しの段 1,320 本・失敗 0（3.5 分）。
- 80c900e（run 43220903284）: 5 つのジョブが全部緑。くり返しの段は SyncEngineSpanTests 120/120（4.8 秒）・SyncEngineTests 1200/1200（24.8 秒）、警告なし。
- `r13` dcf32f0（run 43237335436）: 5 つのジョブが全部緑（compat-v1.0 12.5 分・build-and-test 77 分）。

### 1.0 の試験の道具（リードの直し、dcf32f0）

- compat-v1.0 の `Real10LedgerTests.testSyncOn10KeepsExtraAndDoesNotSendAPageBack` が `w-2026-12-07.photo-text-neighbor.json` で「送った線が 2 本（3 本のはず）」で落ちた。S4 はこの試験・1.0 の木・見本のどれにも触れていない。同じ試験は前にも 1 回揺れた（R1_2_2.md:965）。
- 原因: 1.0 のエンジンは `sleep` を main actor でない closure を通して呼ぶので、`waitUntilIdle` が返った時点で、デバウンスのタスクがまだ `TestSleeper.sleep` に届いていないことがある。そのとき `advance()` を 1 回呼んでも何も起きず、送る処理が来ない。
- 直し: `tools/compat10/AppTests/Real10LedgerTests.swift` の `flushDebounce` を、ページが dirty でなくなるまで「待つ → 起こす → 10 ms」をくり返す形にした（最長 5 秒）。後の確かめは同じ。1.0 の本体（a21e469）は変えない。この Mac で 1.0 の木に入れて typecheck OK（TegakiCalendarTests 25 ファイル・警告 0）。1.2.3 の写し（Real123LedgerTests）は `advance` が async で、この揺れは無い。

### リードの決定（作業者からの問い）

1. `makeGroup`（組の印の種。`makeId`・`nowMs` と同じ形）・`InkHistoryStep`・`removalLimit = 50`・`pageRemovalLimit = 20` を、§2.1 に無い名前として認める。結果の型は `InkChange` のまま（`needsRebuild` は計算で出す）。
2. `allowRemovals: false` は横の道だけで守る（3554bf3）。S5 のキャンバスは 1 ページの道でも引数をそのまま渡してよい。
3. 断った削除だけで新しい線が無い変化は `isEmpty` が true になる。S5 のキャンバスは `guard !change.isEmpty`（InkCanvasView.swift:1907）より先に `needsRebuild` を見る。`alreadyErased`・`unknownRemovals` の記録と Debug での停止は S5 のキャンバスの役。
4. lint-skip.txt に 4 つが戻らないように止める仕組みは入れない（§6.4 の手順 4 で表と一緒に直す）。README の lint の説明に lint-skip.txt を足すのは S6 の文書の仕事。
5. PrototypeIsolationTests の禁止の語に `onRemoteDelete` を足すかは S5 の C で見る（試作のソースはタグ r13-proto-1 で止まっている）。
6. SyncEngineSpanTests の待ち方（yield だけで、実時間の待ちなし）は今のまま。CI で揺れたら実時間の待ちを足す。
7. `r13` には早送りで入れた（r13-s4 は ac3e896 の上にあった）。作業用の枝 r13-w-lint・r13-w-l・r13-w-y・r13-s4 は消さない（消すときは本人に聞く）。
8. `pagesOpened` は 1.2.3 の `pageOpened` と同じ門に加え、「全て消す」の iCloud の分が残る間と、呼んだ後に epoch が動いたときは取りに行かない（1c8a356）。S5 の窓はこちらだけを使う。
9. 1.2.3 の `pageOpened`／`fetchPage` には、見直しの Y-1 と同じ穴が残る（「全て消す」の iCloud の分が残る間、または消す前に並んだ取りに行く仕事が、消したページを端末に戻し、次の起動で iCloud に送り直す）。§6.4 で既存の関数は変えないので、S4 では直さない。H4 の候補として、再現と直し方を Workflow wf_654e5eb9-c16 で確かめ、1.2.4 を作るかの判断（S1' の後）に入れる。1.3 の 1 ページの道も同じ関数を使うので、1.2.4 を作らないときは 1.3 で直すかを本人に聞く（§6.4 の表を広げる話になる）。

## H4（1.2.3 の穴。2026-11-13 00:40）

S4 の見直し（Y-1）の残りを、Workflow wf_654e5eb9-c16（再現 3・反証役 3・直しの設計 1・批判 1）で確かめた。43fe366 の本物の同期のファイル（SyncEngine・InMemoryCloudDatabase・InkPageStore・SyncStateStore ほか、sha256 で 43fe366 と同じ）と 43fe366 の TegakiKit を、この Mac の swiftc で組んだ試験の場で動かした。

### 起きること

- **A（消す前に並んだ取りに行く仕事）**: 回線が遅く、別のページの取得が止まっている間にページ P を開き、続けて「全て消す」をすると、P の取得は列に積まれたまま残る。全消去は端末のファイルを消し、iCloud の削除を P の取得の後ろに積む。P の取得は消した後の世代（epoch）で走り、まだ iCloud にある P を取ってきてファイルを書き戻す（`fetchPage` は `pendingCloudErase` を見ない。SyncEngine.swift:812）。続く iCloud の削除は成功し、画面には「消しました」と出るが、端末には P が残り、表示中なら線も画面に戻る。前に出たときのアカウントの確かめが列を止めている場合も同じ（A1b）。
- **B（iCloud の分が失敗した後）**: 圏外などで iCloud の削除が失敗すると `pendingCloudErase` が残る。回線が戻ってから、自動のやり直し（15 秒〜5 分）より前にページを開くと、`pageOpened` → `fetchPage` が iCloud の P を取ってきて書き戻す（M4_CONTRACT §4.5 の 10「それまで pull をしない」に反する）。
- **どちらも**: 戻ったページは台帳（seen）に無いので、次の起動で `start()`（:219）が dirty にして iCloud へ送り直し、ほかの端末にも戻る。同じ起動の中でも、戻ったページに 1 本書けば送られる。
- 起きる見込み: まれ（「全て消す」自体がまれで、上の時の重なりが要る）。B の方が起きやすい。反証役 3 人とも再現し、user_reachable と判断した。

### 直し（枝 `h4-fix`、2470c5d。main にも r13 にも入れていない）

- `pageOpened` と `fetchPage` の guard に `!state.pendingCloudErase` を足す（コード 2 行・注 3 行）。`pageOpened` は冷却の前で断るので、消去が済んだ後に開けば取りに行く。それ以外の動きは変えない（世代を積んだときに取る形（r13 の `pagesOpened` の形）は、確かめた穴を余計に塞がず、1 ページの道の動きを変えるので入れない）。
- `tools/compat10/DATA_1_1.sha256` の SyncEngine の行を書き直した（R1_2_3.md §3.10 と同じ）。新しい `SyncEngineEraseFetchTests` 3 本（M4_CONTRACT §8.2 の 60〜62。54〜59 は 1.3 の `SyncEngineSpanTests`）を足し、20 回くり返しの段にも入れた。`SyncEngineTests.swift` は 43fe366 のまま（r13 の `TESTS_1_2_3.sha256` は OK のまま）。build.yml と README の「SyncEngine.swift だけ 1.2.3 の中身」の注も直した。
- 試験の場: 新しい 3 本は 43fe366 で 20 回とも失敗、直した後は 200 回とも合格。既存の SyncEngineTests は 20 回で 1,180 本合格。批判役は直しを壊せなかった（再現の試験 26 本が「戻らない」に変わった）。この Mac の typecheck・lint・DATA_1_1 OK。CI の run 43251126239（h4-fix、2470c5d）は 4 つのジョブが全部緑（11/13 02:16）: 単体テスト 471 本（skip 8・失敗 0、新しい 3 本を含む）、20 回くり返しの段 1,260 本・失敗 0（SyncEngineTests 1,200 ＋ SyncEngineEraseFetchTests 60）、compat-v1.0・UI テストも緑。
- この直しで塞がらないもの（画面の側。1.3 で直す）: H1（ほかの端末の画面に残った線が、次に書いたときに iCloud に戻る。二台使いでは一番起きやすい）、H3（「全て消す」の後の ↶）、全消去の確認の後の一瞬の窓（理屈の上だけ）。

### どの版で出すか（既定とリードの判断）

- 契約 §0.8 は、1.2.4 を「コードを変えない軽い版」にし、H1〜H3 は 1.3 で直すと本人に知らせている（「早く直したいときは言ってください」）。H4 も同じ種類の穴なので、**既定は 1.3 で直す**（S5 で `h4-fix` を `r13` に取り込む。§6.4 の SyncEngine.swift の行「今の関数の中は onRemoteDelete の 1 行のほかは変えない」に、H4 の 2 行を足す読み替えをする。DATA_1_1 の行はぶつかるので、取り込んだファイルから計算し直す）。
- 本人が「H4 を 1.2.4 で直す」と言ったときは、1.2.4 を「コードを変える版」にする（§9.2 と同じ扱い: 自分の確かめ表と本人の言葉、TestFlight の確かめは版の番号だけでは済まない。H1〜H3 も一緒に入れるかを同じ日に決める）。その場合 `r13` は main を取り込むだけでよい（`git merge-file` で SyncEngine.swift はぶつからない。DATA_1_1 の行だけ計算し直す）。

## S5（本体。2026-11-13 06:30〜）

本人の「進められるところは、どんどん進めていきましょう。予定に拘ることはありません。」（11/13）で、S5 を 11/19 から前倒しで始めた。試作の感想（期日 11/18）で変わりうる数（はじきの手ざわり・手のひら・iPhone 横の「今のまま」と「上限あり」）は、契約のおすすめ（§0.6、§3.16）で作り、感想が来たら直す。

### 段取り（リードの決定）

- 役ごとに枝を分けて並べて作る。第 1 陣（Workflow wf_edb4259f-ebc）: S（`SpanSession`・`PageSlot`・受け箱・`OnePageSession` と 1 ページの道の状態の移し替え・H1〜H3）、P（紙・固定見出し・終日帯・PDF の隣の線・iPhone 横の見出しの間引き）、C（S5 の CI のうち画面を待たない分）、U の前半（設定「ページ」・`page.span`・初めての案内の札）。各役は `r13-w-s5<役>` で作り、まとめの枝 `r13-s5a` で全部のジョブを回してから `r13` に入れる。
- 第 2 陣: L のキャンバス（§3.6。`SpanSession` の型を使うので S の後）。第 3 陣: 画面のつなぎ込み（2 本の道・設定の切り替え）、写真モードの引数と UI テスト、span-shots の写真。第 4 陣: 訳・逆翻訳・店の文・SUPPORT と見直し。
- 速い確かめの道を、役ごとの枝 `r13-q-<役>` でも使えるようにした（25c3fc6。`QUICK` と各ジョブの `if:` が `r13-q-*` も含む。ref ごとの concurrency なので、役どうしで止め合わない）。

### 第 1 陣（Workflow wf_edb4259f-ebc、11/13 06:30〜20:50。作る 4・見直し 4・直し 4・まとめ 1・最後の点検 1）

| 役 | 枝の先頭 | 中身 | 見直し（再現したもの） | CI（役の枝） |
| --- | --- | --- | --- | --- |
| S | 7867480（`r13-w-s5s`） | `Span/SpanSession.swift`（`PageSlot`・`PageSlot.persist`・`SpanInbox`・`SpanSession`。§2.1 の口とキャンバスが使う口の全部）、`Span/OnePageSession.swift`、`CalendarRootScreen` の 1 ページの道の状態と保存を `OnePageSession` へ（1.2.3 の行のまま）、H1（`onRemoteDelete` → 表示中のページを空にして作り直す）・H2（消して始めるは `await` の前に閉じる）・H3（全て消す・消して始めるで ↶ を捨てる）・識別子の門。`SpanSessionTests` 37 本・`ScreenEraseTests` 13 本（20 回くり返しの段にも） | major 2（窓の先頭の番号・窓を変えるのは compose だけ）・minor 5 → 直した（minor 1 は C のファイルの注で、C の枝で直っている） | run 43374089996 緑（単体 535・くり返し 238 秒） |
| P | e75ad84（`r13-w-s5p`） | 紙（`PaperView` の窓）、固定見出し（窓のページの列・iPhone 横の間引き、決定 4）、終日帯（窓の全部の日でレーンを詰める `AllDayBandLanes`）、PDF の隣の線（`neighborInk`、D17）と書き出し・取り込みの `TransferGuard`（§3.11）。1 ページでは 1.2.3 の出力。`PaperSpanTests` 20 本 | major 1（帯の重なりの数え方）・minor 4 → 直した（キャンバスの側の 1 つは第 2 陣へ） | run 43374019572 緑（UI テストの揺れ 1 件を走らせ直し） |
| C | ad24ad9（`r13-w-s5c`） | 13 インチのシートの写真を「画面が出たのを待つ」形に（`tools/shots/screen_ready.swift`）、「The app is not running」の誤った警告を止めた（決定 8）、compat-v1-0 の上限を測った時間から（決定 7）、`PrototypeIsolationTests` に `onRemoteDelete`（S4 の決定 5）、UI テストの grep に `span UI:`、くり返しの段のクラスの数え、ずらしの組の道具 `tools/shots/shift_pair.swift`、新しい J-4 の基準（run 43350270595） | minor 3 → 直した | run 43382429888 緑 |
| U | c859928（`r13-w-s5u`） | `page.span`（端末ごと、既定オン）、設定の節「ページ」（§3.14、N-1〜N-3）、`SpanGuideView`（N-4〜N-7、8 秒・触れて消える・端末と種類ごとに 1 回、注入の sleep/clock）、N-8 のキー。新しい 8 キーは訳が入るまで ja だけ（`build.py` の `APP_JA_ONLY_UNTIL_TRANSLATED`、この 8 つの名前だけ）。訳の無いキーがあると testflight.yml で止める段。`SettingsPageSectionTests` 12 本 | minor 6 → 5 直した（1 つは下の「違ってよい写真」でリードが受けた） | run 43383527000 緑 |

- まとめの枝 `r13-s5a`（7ec3c6c。4 つの取り込みでぶつかり無し、足した行 0）の run 43399030685 は 5 つのジョブが全部緑（blank-paper の 1 回目は実行機にシミュレータが無い揺れで、落ちたジョブだけ走らせ直して緑）。build-and-test 93.9 分（上限 120）: 単体テスト 567 本（skip 8・失敗 0）、20 回くり返し 2,380 本・失敗 0、UI テスト 29 本・失敗 0、compat-v1.0 16.4 分、l10n-shots 45.3 分（写真 63 枚）、span-shots 38.2 分（`PrototypeIsolationTests` 4・失敗 0）。
- リードがこの Mac で 7ec3c6c を確かめた: KitChecks 36,968・失敗 0、typecheck は試作の印なし・ありとも all OK（アプリの警告 0、TegakiCalendarTests 45 ファイル・UITests 6 ファイル）、lint OK、DATA_1_1 18/18・TESTS_1_2_3 8/8、`prototype_gate_test.py` 14 件 OK。`r13` を 7ec3c6c まで早送りした（同じ commit を r13-s5a で全部のジョブで確かめたので、`r13` の push は CI を回さない）。
- 最後の点検: §2.1 の宣言とそろっている。1 ページの道の 43fe366 との差を 1 行ずつ読み、意図した違いは H1〜H3・識別子の門・D14 の保存の入口の `SpanGuard`・作り直しのときの viewport・設定の節・書き出しと取り込みと PDF の門だけ。H1〜H3 のテストは、直しを外すと落ちる（写しの試験の場で変異を入れて確かめた）。§8.1 の N-1〜N-8 は契約の文と 8/8 一致、既存のキーの変更 0。

### 第 1 陣のリードの決定

1. `PageSlot` は紙を持たない（S のずれ）。1 ページの道の紙は画面に残し、窓の紙は `SpanSession.layout` が持つ。
2. H2（1 ページの道）: 消して始めるの `await` の間に空のキャンバスに書いた線は残さない（契約の文のとおり）。
3. `OnePageSession` が ObservableObject なので画面の評価の回数が増えるが、動きは同じなので受ける。
4. 識別子の門は、月のページで週の始まりを替えたときの古いキャンバスの遅れた書き込みも捨てる（§2.1 の最後の点の意図どおり）。
5. `runImport` の 1 行（S のファイル）は P の枝のまま入れた。取り込みで断ったページは「読み飛ばし」に数える（新しい文は足さない）。
6. 見出しの間引きのしきい値（週 50/34 pt、日 100/64 pt）と、つないだ週の時刻の列に月を出すことは、試作の感想の後に見直す。
7. UI テストを別のジョブに分けるかは、第 3 陣で `SpanRerunUITests` が入った最初の run で測ってから決める（今の build-and-test は 82〜94 分、上限 120）。
8. J-4 の基準は新しい run 43350270595（ja-baseline-43fe366、11/13。1.3 の build.yml と同じシートの待ちで撮った）を使う。前の基準 43158921131（決まった 9 秒）は使わない。
9. N-8（段 2 の案内、§8.1「1 回」）は、端末ごと・種類ごとに 1 回（案内の札と同じ形）。第 3 陣で作る。
10. 速い道（`r13-q-*`）に `SettingsPageSectionTests` を足すのは第 3 陣の C で（`ScreenshotModeSpanTests` は名前で当たる）。
11. **J-4 の違ってよい写真**: `ipad13-portrait-sheet-sync.png`（設定のシートの同期の行の上に新しい節「ページ」が写る。U-R6）と、ja-baseline.yml の同じ写真。`sheet-settings.png` と `store/ipad13/06-settings.jpg` の差は時計と数画素で、新しい節によるものではない。
12. 最後の点検の S5A-C1: H1〜H3 の直しのうち画面の側の行（`CalendarRootScreen`）は、まだどの自動テストも通らない（セッションの側の半分だけを変異で確かめた）。第 3 陣（画面）で、画面の行を通るテスト（画面の呼び口を切り出した単体テストか UI テスト）を足し、直しを外すと落ちることを確かめる。
13. 最後の点検の S5A-C2: 新しい 3 キー（`settings.page.header`・`settings.page.span`・`settings.page.span.footer`）は、訳が入るまで ja 以外の設定のシートで**キーの名前がそのまま出る**（日本語の文ではない）。l10n-shots の「3 keys the app did not find」の警告はこのため。第 4 陣（X の訳）で 0 に戻し、testflight.yml の段が訳の無いまま TestFlight に出すのを止める。

### 第 2 陣・第 3 陣に残したもの（最後の点検と各役の報告から）

- 第 2 陣（L のキャンバス、§3.6）: `InkCanvasSpanTests` の 12 本、キャンバスが `span: SpanSession?`・`inbox: SpanInbox?` を受け、日誌を `SpanInbox.put`、`takeHistoryPrune` → `pruneHistory(touching:)`、`windowVersion` で台帳を `keepHistory` で読み直す、持ち主のページごとの線の予算（D21）、`onInkBoundsChanged` → `relayoutPages`、ずらしとはじき、`PaperView` に窓の紙を渡す門（P-3 のキャンバスの側）。
- 第 3 陣（画面）: `CalendarRootScreen` の横の道（2 本の道・`page.span` での切り替え・§3.5 の表の全部の呼び口・題名と remember・評価の印 D20・保存の失敗の案内・段 2 の案内 N-8・`onRemoteUpdate`/`onRemoteDelete` の振り分け）、画面の半分が残る S のテスト 10 本（`testPathSwitchSavesThenReopens` ほか）、S5A-C1 の画面の行のテスト、写真モードの 6 つの引数（§3.12）と `ScreenshotModeSpanTests`、UI テスト（§10.3、`SpanUITests`・`SpanRerunUITests`）、span-shots のふつうのビルドの写真（§10.5 の (2)）、予定をページごとに読む画面の側（`EventStoreModel`・`EventKitService`）。
- 第 4 陣: 新しい 8 キーの訳（9 言語）と逆翻訳、16 ロケールの新機能の文、審査メモ、App Store の写真、SUPPORT。

### 第 1 陣の 1 ページの道の記録（§6.4・D9。各役の報告のまま）

凍結の表のファイルは、この陣ではどれも変えていない（DATA_1_1 18/18・TESTS_1_2_3 8/8）。下は、1 ページの道が通るコードを変えた commit の行（commit・ファイル・通る行・理由・通る既存のテスト）。

**S（セッション・OnePageSession・H1〜H3）**

- f0dc062・Views/CalendarRootScreen.swift・+65/−71 行。この陣の画面には横の道がまだ無いので、変えた行は全部 1 ページの道が通る。以下 43fe366 の行番号ごと。通る既存のテスト: 1.2.3 の単体テスト（TESTS_1_2_3 の 8 ファイル）はどれも画面を作らない（CalendarRootScreenTests は static の関数だけ: weekStartSwitch・startState・tapTarget・growthCapToast など。変えていない）。画面を動かすのは UI テスト（EraserAndBelowDayUITests 8・YearTapUITests 5・HeaderAndPaperUITests 3・WeekStartUITests 1・LanguageUITests 11・BlankPaperShotsUITests 1。すべて写真モードで、エンジンは何もしない版）と build-and-test の写真の段（J-4）。run 43315186882・43351232408 で全部緑
- f0dc062・CalendarRootScreen :154 `@State page` → `@StateObject onePage: OnePageSession`（注 3 行）・D3 の 7・上の UI テストと写真の全部
- f0dc062・CalendarRootScreen :187-188（capNoticedPageId）と :272-273（saveTask・pageDirty）を消した（PageSlot と OnePageSession へ）・D3 の 7・同上
- f0dc062・CalendarRootScreen :445 `_page = State(initialValue: startPage)` → `_onePage = StateObject(wrappedValue: OnePageSession(sync: SyncEngine.shared, page: startPage))`・D3 の 7・起動する全部の UI テストと写真
- f0dc062・CalendarRootScreen :473 canvasIdentity = canvasBase（今の "<pageId>|<weekStart>"）＋ "|<epoch>"・D7、§6.6 H1〜H3・全部（キャンバスの .id。起動時は epoch 0 で、1.2.3 と同じ時にだけ作り直す）
- f0dc062・CalendarRootScreen :953-955 growthCapReached の capNoticedPageId → onePage.noteGrowthCap(pageId:)（同じ規則）・D3 の 7・UI テストで上限に届くものは無い
- f0dc062・CalendarRootScreen :1144-1152 pageBinding: 作ったときの canvasIdentity を閉じ込め、onePage.canvasWrote(_:madeFor:base:)（識別子とページ id が今と同じときだけ受け、dirty と 1.5 秒の予約は 1.2.3 のまま）・§2.1 の最後、§6.6 H1/H3・書く・消す UI テスト（EraserAndBelowDayUITests ほか）。新しい ScreenEraseTests.testLatePublishFromTheOldCanvasIsDropped
- f0dc062・CalendarRootScreen :1188/:1190 appear に onePage.onSaveFailed と sync.onRemoteDelete = remoteDeleted を足した・D3 の 7、§6.6 H1、§7・起動する全部（写真モードのエンジンは呼ばない）
- f0dc062・CalendarRootScreen :1341・:1349 show の capNoticedPageId = nil → onePage.forgetGrowthCap()・D3 の 7・ページを移る UI テスト（HeaderAndPaperUITests・YearTapUITests）
- f0dc062・CalendarRootScreen :1368-1373 show の migrate・dirty・予約 → onePage.open(loaded)（同じ行）・D3 の 7・ページを開く全部の UI テストと写真
- f0dc062・CalendarRootScreen :1442 relayout の page → onePage.page・D3 の 7・全部
- f0dc062・CalendarRootScreen :1476（switchWeekStart の apply）capNoticedPageId = nil → forgetGrowthCap・:1507（runWeekStartCheck）pageDirty → onePage.isDirty・:1534（noticeHiddenInk）`let page = onePage.page`・D3 の 7・WeekStartUITests、CalendarRootScreenTests の weekStartSwitch 3 本（static、変えていない）
- f0dc062・CalendarRootScreen :1580-1590 applyRemote の本体 → onePage.applyRemote（同じ行）＋ relayout・D3 の 7・UI テストでは呼ばれない（何もしないエンジン）。新しい ScreenEraseTests.testOnePageSessionKeepsTheOneTwoThreeSaving
- f0dc062・CalendarRootScreen 新しい remoteDeleted(_:)（表示中のページなら OnePageSession.remoteDeleted、selection = nil、relayout）・§6.6 H1・新しい ScreenEraseTests の H1 の 3 本。写真モードでは呼ばれない
- f0dc062・CalendarRootScreen :1764（予定にする）page.strokes → onePage.page.strokes・:2050（PDF の runExport）page → onePage.page・D3 の 7・該当する UI テストは無い
- f0dc062・CalendarRootScreen :1868-1874 eraseAllInk の予約の取り消し・空にする・dirty = false → onePage.eraseAll()（同じ動き＋番号を進めてキャンバスを作り直す）・§6.6 H3、D3 の 7・UI テストは全て消すを使わない。新しい testUndoIsEmptyAfterEraseAllAndEraseAndStart
- f0dc062・CalendarRootScreen :2129-2140 chooseAccount: .eraseInk のとき await の前に onePage.beginEraseAndStart()・selection = nil・relayout、await の後は reloadShownPage の後（later と写真モードではすぐ）に endEraseAndStart()。.keepInk の saveNow は 1.2.3 のまま・§6.6 H2・H3・UI テストは無い。新しい testEraseAndStartClosesTheScreenBeforeAwait
- f0dc062・CalendarRootScreen :2148-2156 reloadShownPage → onePage.reload(sync.load(pageId))（予約の取り消し＋open、同じ行）・D3 の 7・同上
- f0dc062・CalendarRootScreen :2520-2541 scheduleSave を消し（OnePageSession.scheduleSave へ。sleep を注入、cancel ＋世代の確かめ）、saveNow → onePage.saveNow()（PageSlot.persist: SpanGuard → sync.save。1.2.3 のデータでは .ok で、書く中身は同じ。写真モードでは 1.2.3 と同じく何もしない）・D3 の 7、D14、D3 の (2)・書く UI テスト全部。新しい testOnePageSaveTimerRunsAfterTheLastChange・testOnePageSaveGoesThroughTheGuard
- f0dc062・Span/OnePageSession.swift（新しい、228 行。全部 1 ページの道が通る）・D3 の 7、§6.6 H1〜H3、D7、D14・UI テスト（画面経由）と ScreenEraseTests の 1 ページの道の 8 本
- f0dc062・Span/SpanSession.swift のうち 1 ページの道が通るのは :21-102（PageSlot と PageSlot.persist）と :244（SpanSession.onFault。修理があったときだけ）・D14、D3 の (2)・同上。残り（SpanInbox・SpanSession）は 1 ページの道から呼ばれない
- a15a08e・テストのファイル 2 つと build.yml だけ・アプリのコードは 0 行
- 3fb5902・Span/SpanSession.swift の saveDirtyPages だけ（横の道）・1 ページの道が通る行は 0
- 042d46f・テストのファイル 2 つだけ・0 行
- 1 ページの道の 43fe366 との意図した違い: H1（ほかの端末の全て消すで表示中のページが空になりキャンバスを作り直す）、H2（消して始めるは await の前に空にし、読み直すまで保存しない）、H3（全て消すでキャンバスを作り直し ↶ が空。新しいキャンバスなので紙は開いたときの位置に戻る）、識別子の門（作り直す前のキャンバスの遅れた書き込みを捨てる。月のページで週の始まりを替えたとき、id は同じでも識別子が変わるので捨てる）、保存の入口の SpanGuard（1.2.3 のデータでは何もしない）。凍結の表のファイルはこの役では触っていない（DATA_1_1 18/18・TESTS_1_2_3 8/8）
- f5751e1・Sources/TegakiCalendar/Views/CalendarRootScreen.swift・1 ページの道が通る行は 3 行（ほかの 4 行は注）。:1598 remoteDeleted（他の端末の『全て消す』で表示中のページが空になり、OnePageSession.remoteDeleted が true のときだけ）、:1884 eraseAllInk、:2150 chooseAccount(.eraseInk)（await の前）。どれも `viewport = .zero`・理由: §6.6 H1〜H3 と D3 の (1)・(5)・(6)。キャンバスを作り直すこの 3 か所でも、show（:1347・:1354）や switchWeekStart（:1477）と同じく、見出しと帯が初めの位置（initialViewport）を使う。新しいキャンバスが次のターンに自分の viewport を知らせるまでの 1 ターンだけの見た目の違いで、線と保存は変えない。通る既存のテスト: 無い。1.2.3 の単体テストは static の関数だけを呼ぶ。全て消す・アカウントの問い・記録の削除を使う UI テストも無い。run 43374089996 の UI テスト 29 本と写真の段は全部緑
- 40fe699・Sources/TegakiCalendar/Span/SpanSession.swift・1 ページの道が通る行は 0。変えたのは class SpanSession の中だけ（元の :255 以降）。1 ページの道が通る PageSlot と PageSlot.persist（:21-102）と SpanSession.onFault は変えていない
- d28eba2・テストのファイルだけ・アプリのコードは 0 行
- 47cbcf0 と 7867480・.github/workflows/build.yml の注だけ。2 つで差し引き 0 なので 042d46f と同じバイト・アプリのコードは 0 行
- 凍結の表はこの回でも触っていない（DATA_1_1 18/18 OK、TESTS_1_2_3 8/8 OK）

**P（紙・見出し・終日帯・PDF）**

- 2d1ba54・Paper/PaperView.swift・draw() の :317 の `if let span = span` の 1 か所（新しい span は既定 nil。nil なら 1.2.3 の switch へそのまま進む。drawSpan は 1 ページの道では走らない）・§3.8、D2・PaperViewTests（9 本）、InkCanvasViewTests（キャンバスの下の PaperView）、PaperFitTests
- 2d1ba54・Views/StickyHeaderView.swift・body の :46 の `if let span = span, span.isJoined` の 1 か所（else の中は 1.2.3 の switch を字下げしただけで同じ。つないだ道の関数は走らない）・§3.8、§3.13、決定 4・PaperFitTests（StickyHeaderView を描く）、新しい PaperSpanTests.testAWindowOfOnePageKeepsThePageHeading
- 2d1ba54・Views/AllDayBandView.swift・:66-90（placedBands・placed・laneCount・bandKind・metrics）、:95（body）、:116-135（content）、:141-166（column）、:175-191（gutterLabel）、:205-206（barView）、:235（columnTint を static に）。span が nil なら帯 1 つ・slot 0・原点 0 で同じ値（laneCount = band.laneCount、bandKind = band.kind、x に 0 を足すだけ）、重なりの順も 1.2.3 と同じ（列 → 「終日」 → バー）・§3.8・PaperFitTests（AllDayBandView を描く）、新しい PaperSpanTests.testABandOfOnePageIsThePageBand
- 26ed07e・Export/PDFPageRenderer.swift・paperRect :62-80（neighborInk 既定 [] → incoming は nil → 1.2.3 の矩形）、pageSize :140-142、render :178-180（TransferGuard.allowsPDFPage の入口: アプリが保存したページは全部通る。cleanNeighborInk は [] では呼ばない）、:217-221（neighborInk が空なら 1.2.3 の絵）・§3.11、D14、D17・ExportBuilderTests（testPDFHasOnePageAndOverviewSize・testPDFDoesNotCarryTheBlankMemo・testPDFRendersEveryKind・testDayPDFIncludesTheExtraOnlyWithInk・testSundayPDFFileName・testPDFFileNameAndMetadata）、PaperViewTests、PaperFitTests
- 26ed07e・Export/ExportBuilder.swift・exportJSON :131-147（ページごとに TransferGuard.exportable: アプリが保存したページは全部通るので同じファイル）、exportPDF :200-205（neighborInk 既定 [] をそのまま渡す）・§3.11、D14・ExportBuilderTests（testJSONExportWritesEveryStoredPageSorted・testJSONExportMigratesBandCells・testJSONExportRoundTripsThroughImport・testJSONExportReportsProgress・testNothingToExport・testCleanUpRemovesPreviousFiles・testLargeExportImportsPageByPage・testExportKeepsBothWeekForms と testPDF* の全部）
- 91b0e79・Views/CalendarRootScreen.swift・runImport :1941-1943（`outcome = TransferGuard.importable(value)`。窓の名前のページが無ければ同じ値を返すので、本物のファイルの取り込みは 2 本の道とも 1.2.3 のまま）・§3.11、D14・runImport は private で、既存の XCTest は届かない（解析の道は ExportBuilderTests.testJSONExportRoundTripsThroughImport が通る）。新しい PaperSpanTests.testTheImportDoorStopsWhatTheParseCarries と testDataFileAndImportDoorsRefuseWindowNames
- aa9aece・d068044 はテストのファイルだけ（1 ページの道のコードは変えない）
- d6a83e3・Views/StickyHeaderView.swift・weekDayCell の :116（weekColumnStacksWeekday(language)）、:141（weekColumnShortHoliday(label, language)）、:164（weekDayWeekday の weekColumnWeekday(…, language)）。L.language を language に変えた。アプリでは StickyHeaderView を language なしで作るので（CalendarRootScreen.swift:640、SpanPrototypeScreen も同じ）、既定の L.language と同じ値になる・§3.8、F-9、K-6（P5-2: 細い形の高さをテストで言語ごとに測るため）・既存のテストで週の見出しを描くものは無い（PaperFitTests:197 は日の見出しだけ）。新しい PaperSpanTests.testAWindowOfOnePageKeepsThePageHeading が、43fe366 の写しと画素で比べる（週 54 回）。ほかに build-and-test の Screenshots の週のページ（J-4）
- d6a83e3・Views/AllDayBandView.swift・AllDayBandLanes.bands と uniqueEvents。1 ページの道では呼ばない（窓の帯だけ）・§3.8・—
- d6a83e3・Paper/PaperView.swift・doc のコメントだけ・—・—
- e75ad84・テストのファイルだけ（PaperSpanFrozen123.swift は新しい、PaperSpanTests.swift）。1 ページの道のコードは変えていない
- 前の回の記録の訂正（2d1ba54・Views/AllDayBandView.swift の行）: 「既存のテスト」の欄の PaperFitTests は誤り（AllDayBandView を描かない）。描いて確かめるのは、新しい PaperSpanTests.testTheOnePageBandIs1_2_3OnScreen（span nil と窓 1 ページを 43fe366 の写しと画面で画素ごとに比べる。週・日、0.1068・0.0854・0.5、レーンの倍率を固めた形）と testABandOfOnePageIsThePageBand（データ）。ほかに build-and-test の Screenshots（J-4）
- 前の回の記録の補い（2d1ba54・Views/StickyHeaderView.swift の行）: 1 ページの週の見出しを描く既存のテストは無い。PaperFitTests が描くのは日の見出しだけ。今は testAWindowOfOnePageKeepsThePageHeading が、週と日を 43fe366 の写しと 90 回比べる（span nil と窓 1 ページ、iPhone 横の倍率を含む）

**C（CI）**

- 4644353・.github/workflows/build.yml・ja-baseline.yml・tools/shots/screen_ready.swift・アプリのコード 0 行（CI の写真の段と CI の道具だけ）・§10.5・—
- a10ad0d・build.yml・ja-baseline.yml・store-shots.yml・アプリのコード 0 行・決定 8・—
- b8e1689・build.yml・0 行・§10.4・—
- bdca47f・build.yml・0 行・§10.3・§10.6・—
- 99545a8・Tests/TegakiCalendarTests/PrototypeIsolationTests.swift・0 行（ファイル全体が #if SPAN_PROTOTYPE の中で、ふつうのビルドでは 0 本。TESTS_1_2_3 の 8 ファイルの外）・§10.2 の T の行・S4 の決定 5・—
- 993192f・8718a51・7d0581a・62710e8・build.yml（と ja-baseline.yml）・0 行・§10.5・§10.6・§6.4 の注記・—
- まとめ: git diff 25c3fc6..62710e8 -- Sources TegakiKit project.yml tools/compat10 tools/span は空。1 ページの道が通るコードには触れていない
- f8223b2・tools/shots/screen_ready.swift（注記だけ）・アプリのコード 0 行・§10.5・—
- 316f383・.github/workflows/build.yml（20 回くり返しの段）・アプリのコード 0 行・§10.6・—
- ad24ad9・.github/workflows/build.yml（span-shots の段）・tools/shots/shift_pair.swift（新しい CI の道具）・アプリのコード 0 行・§10.5・—
- まとめ: git diff 62710e8..ad24ad9 -- Sources TegakiKit project.yml tools/compat10 tools/span Tests は空。1 ページの道が通るコードには触れていない。DATA_1_1.sha256 は 18/18 OK、TESTS_1_2_3.sha256 は 8/8 OK

**U（設定「ページ」・案内の札）**

- 79aa1e0・Sources/TegakiCalendar/Views/SettingsScreen.swift・設定のシートを開くたびに通る: Form の 1 行 pageSection（:217 相当）、@State pageSpan の初期値（AppSettings.pageSpan を読むだけ、書かない）、pageSection の View（Toggle・見出し・脚注、:468-476 相当）。.onChange(of: pageSpan) はスイッチを切り替えたときだけ。onPageSpanChange は既定で何もしない。シートのほかの行・節の順・既存の .onChange は変えていない・§3.14、D3 (3)（1 ページの道に入れてよい 7 つのうち (3) 設定の「ページ」の節）・通る既存のテスト: WeekStartUITests.testSwitchShowsTheSentenceAndChangesTheHeader（写真モードで設定のシートを開く）、SettingsScreenTests 14 本（静的な文）、build-and-test の写真 --screenshot-sheet settings（ipad13-portrait-sheet-settings.png・store/ipad13/06-settings.jpg。8a35df3 の写真を開いて見たところ、新しい節は画面の下で写っていない）
- 79aa1e0・Sources/TegakiCalendar/Persistence/AppSettings.swift・既存の行は doc の注だけ変更。新しい static（pageSpanKey・pageSpan・spanGuideShownKey・spanGuideShown・markSpanGuideShown）は 1 ページの道ではシートの @State の初期値（pageSpan の get）からだけ呼ばれる。既存のキーと関数は変えていない・§2 の U 行・AppSettingsTests（変えていない、CI 緑）
- 79aa1e0・Sources/TegakiCalendar/Views/SpanGuideView.swift（新規）・1 ページの道が通る行 0（まだどこからも呼ばれない）・§3.14・—
- 79aa1e0・Resources/Localizable.xcstrings・tools/l10n/source/app-U.json・tools/l10n/build.py・新しい 8 キー（ja だけ）を足しただけで、既存の項目は 1 バイトも変わっていない（スクリプトで変更 0 を確認）。build.py の例外は 8 つの名前に限る・§8.1、§8.2・LocalizationBundleTests（jaOnly を飛ばす。変えていない）・L10nTests
- 8a35df3・SpanGuideView.swift と SettingsPageSectionTests.swift・名前の変更だけ。1 ページの道が通る行 0・—・—
- 1771933・Sources/TegakiCalendar/Views/SettingsScreen.swift・@State pageSpan の初期値と .onChange の中身を static の initialPageSpan(screenshot:)・pageSpanChanged(to:screenshot:notify:) に移しただけ（動きは 79aa1e0 と同じ）・§3.14、D3 (3)・上の SettingsScreen の行と同じテスト ＋ 新しい testSpanToggleStoresThenTellsTheOwner
- e8071ef・Sources/TegakiCalendar/Views/SpanGuideView.swift・1 ページの道が通る行は 0（SpanGuideModel と SpanGuideView を呼ぶ画面はまだ無い）・§3.14、§3.16・—
- e8071ef・Tests/TegakiCalendarTests/SettingsPageSectionTests.swift（U の新しいファイル。1.2.3 のテストではない）・アプリのコードではない・§10.2 U・—
- 9f6e722・.github/workflows/testflight.yml（C のファイル。段を 1 つ足した）と tools/l10n/build.py（注の 2 行だけ）・アプリのコードではない。build.py --check では、生成される表は変わっていない・§8.1、§8.2、§11.1・—
- c859928・.github/workflows/testflight.yml・頭の説明の字だけで、1 ページの道は 0・§8.2・—
- これより前の 79aa1e0・1771933 の行（SettingsScreen.swift の pageSection・@State pageSpan・.onChange、AppSettings.swift）は、実装役の報告のまま変わっていない。e8071ef・9f6e722・c859928 は SettingsScreen.swift と AppSettings.swift に触れていない
