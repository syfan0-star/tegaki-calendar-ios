# tools/span-compat — 古い版の本物で compat-span の見本を読む

1.3 は、ページをまたいで書いた線（紙の外の点を持つ線）・ページをまたぐ移動・週のメモ・日曜始まりの週の帯・写真と文字の札の形の知らない道具の項目を保存する（`docs/M7C_CONTRACT.md` の §4.2、§6.3）。その見本 `TegakiKit/Tests/Fixtures/compat-span/` を、**古い版の本物の TegakiKit とアプリ**が読んでも、消さない・切らない・動かさない・変えないことを確かめる（K-7）。`tools/compat10` と `tools/weekstart-compat` は変えず、ここに別に置く。

1.4 から、**本物の 1.3（955fe67、ビルド 26）**も相手に入る（`docs/M7D_CONTRACT.md` の §5.3）。1.3 はデータのコード（`InkLedger`・`InkCanvasView`・`SyncEngine`）を作り直したので、1.1.1 の凍結の表とは別に、1.3 そのものが今の見本を読んで何も変えないことを確かめておく。

| ファイル | 役目 |
| --- | --- |
| `Probe/Common.swift`・`Probe/main.swift` | 4 つの版で同じ確かめ。4 つの版のどれにもある API だけを使う。`main.swift` は最後に、版ごとの確かめの口 `versionExtraChecks(pages:)` を 1 回呼ぶ |
| `v10/Version.swift` | 1.0（a21e469）のレイアウトの作り方と、各見本で描く線の数。`versionExtraChecks` は何もしない |
| `v11/Version.swift` | `<1.1.1>`（`tools/l10n/ja-baseline-ref.txt` の commit、9cbc3c9）の同じもの。`versionExtraChecks` は何もしない |
| `v123/Version.swift` | 1.2.3（43fe366）の同じもの。日曜の `w-` は日曜始まりで開く（K-11）。`versionExtraChecks` は何もしない |
| `v13/Version.swift` | 1.3（955fe67）の同じもの。1.3 の画面と同じに、週はメモ付き（`WeekLayoutInput(..., freeMemo: true)`。省くと 1.2.3 の週になる）、週と日の最後のマスに窓の床（`extraFloor`、`SpanAlign`）を渡す。日曜の `w-` は日曜始まり。`versionExtraChecks` は全部の見本を 1.3 の `SpanGuard` に通す（下） |
| `run.sh` | 版の TegakiKit を指す Swift のパッケージを作業フォルダに作り、`Probe` を組み立てて走らせる |
| `AppTests/Real123LedgerTests.swift` | 1.2.3 のアプリの台帳と同期のエンジンで、全部の見本を読む XCTest（`tools/compat10/AppTests/Real10LedgerTests.swift` と同じ形） |
| `AppTests/Real13LedgerTests.swift` | 1.3 のアプリで、全部の見本を読む XCTest（`Real123LedgerTests.swift` の形）。1 ページの道（1.3 の画面のレイアウト `CalendarRootScreen.makePaper` と `InkLedger(page:layout:)`、保存の口 `PageSlot.persist`）、同期（live の `SyncEngine` の取り込みと 1.3 の窓の取り寄せ `pagesOpened`、保存し直し）、横の道（週と日の見本のまわりの `SpanSession` の窓。月曜始まりと日曜始まり、iPad 11 の縦と iPhone の横） |

## Probe が確かめること（見本のファイルごと）

- `MANIFEST` とフォルダの `*.json` が両方向で同じ。月曜と日曜の行がある。全部の行に、その版の期待（描く線の数、または「開かない」）が `Version.swift` にある。
- 読める・ページ id がファイル名のとおり・書き戻すバイトが同じ・JSON と圧縮した形の往復が同じ。
- ファイルの項目（線と知らない道具の項目）と墓標が全部残り、どの線も書かれたまま（マス・点。切らない・動かさない）。
- その版のレイアウト（予定なし・そのページの線の下端・東京）で、描く線（`InkLedger.drawing()` と同じ: 点があり、マスがレイアウトにある生きた線）の数が期待どおり。投げなわの候補が描く線と同じ。描く線は紙の上の範囲を持つ。開かないページ（1.0・<1.1.1> の日曜始まりの週。その日の週は `w-2026-11-02`）は「開かない」と期待どおり。
- 開いても何も動かない（帯の移し替え）・自分との merge で変わらない・その版が描く線を全部消しても、ほかの項目は 1 バイトも変わらない・その版の端末が自分のマスに書いた線と両方向で merge しても、ほかの項目と墓標は変わらない。
- 全部のページの書き出し → 取り込みで全部がそのまま入り（飛ばし 0）、書き出し直すと同じバイト。
- 版ごとの確かめ（`versionExtraChecks(pages:)`、下）。

最後の行が `span-compat <版>: N checks, 0 failed` で、終了の状態が 0 なら合格。失敗は `FAIL` の行に出て、終了の状態は 1。手元で走らせた数（2026-11-20、`run.sh`）: v10 274・v11 274・v123 278・v13 310。

### 版ごとの確かめ `versionExtraChecks(pages:)`

`run.sh` は `Common.swift`・`main.swift`・`Version.swift` を 1 つのパッケージにまとめる。上から順に動くコードは `main.swift` にしか書けないので、ある版にだけある確かめは、`main.swift` が見本を全部読んだ後に 1 回呼ぶ `versionExtraChecks(pages:)`（読めた見本のページ全部）に書く。どの `Version.swift` にもこの関数が要る（無いと組み立てが落ちる）。確かめの無い版（v10・v11・v123）は何もしない同じ名前の関数を持つ。

- **v13**: 全部の見本のページを 1.3 の `SpanGuard.checkForSave`（`PageSlot.persist` が両方の道で保存の前に通す）に通し、`.ok`（直した項目が 0、ページ id も 1.3 の書く形）であること。1.3 の端末がその見本を保存し直しても何も落とさない。あわせて `SpanGuard.checkForTransfer`（書き出し・取り込み・PDF のページ）も通ること。見本に窓の名前（`<pageId>|…`・`span~…`）が混じると落ちる。最後に `SpanGuard of 1.3 (955fe67): 16 pages …, 0 repaired or refused` の行を出す。

## 走らせ方

古い版の TegakiKit を取り出し、`run.sh` に渡す。作業フォルダはリポジトリの外（省くと一時フォルダ）。

```sh
# <dir> はリポジトリの外の空のフォルダ
mkdir -p <dir>/v10 <dir>/v11 <dir>/v123 <dir>/v13
git archive a21e4692109e504701b507ad9c695181fdecddfd TegakiKit | tar -x -C <dir>/v10
git archive "$(tr -d '[:space:]' < tools/l10n/ja-baseline-ref.txt)" TegakiKit | tar -x -C <dir>/v11
git archive 43fe36666a2120e8a23adf4fc76244151a395e6f TegakiKit | tar -x -C <dir>/v123
git archive 955fe678ec9f999ac45fac1b372f246e43c02f95 TegakiKit | tar -x -C <dir>/v13
tools/span-compat/run.sh v10 <dir>/v10/TegakiKit <dir>/work
tools/span-compat/run.sh v11 <dir>/v11/TegakiKit <dir>/work
tools/span-compat/run.sh v123 <dir>/v123/TegakiKit <dir>/work
tools/span-compat/run.sh v13 <dir>/v13/TegakiKit <dir>/work
```

Xcode は要らない（Probe は Kit だけを使う。この Mac の Command Line Tools の `swift build` で通る）。組み立てた Probe は見本のフォルダを引数に取るので、変異の確かめ（`docs/M7D_CONTRACT.md` §5.3 の 6）は、見本のフォルダをリポジトリの外に写し、写しの 1 つを変えて `<dir>/work/span-compat-v13/.build/debug/Probe <写したフォルダ>` を走らせる（リポジトリの見本は変えない）。前置名のマス（`w-2026-12-14|grid`）の線を 1 本足すと v13 の `SpanGuard` の 2 つの確かめが落ち、線を 1 本消すと描く数の確かめが落ちる。

CI は `compat-v1.0` のジョブで、既にある `v10`・`v11` の checkout と、`git archive` で取り出した `v123`（43fe366）・`v13`（955fe67）に対して同じことをする。同じジョブで、43fe366 の木全体（`v123app`）のアプリの単体テストに `AppTests/Real123LedgerTests.swift` を、955fe67 の木全体（`v13app`）のアプリの単体テストに `AppTests/Real13LedgerTests.swift` を足し、そのクラスだけをシミュレータで走らせる（見本のフォルダは `TEST_RUNNER_TEGAKI_COMPAT_SPAN_FIXTURES`）。このジョブは `macos-26`（Xcode 26.6）のまま（`docs/M7D_CONTRACT.md` §3.9）。

アプリのテスト（`Real123LedgerTests`・`Real13LedgerTests`）はシミュレータが要るので手元では走らない。手元では型の確かめだけをする: その版の木全体を `git archive <SHA> | tar -x -C <dir>/v13app` で空のフォルダに出し、テストのファイルを `<dir>/v13app/Tests/TegakiCalendarTests/` に写して、`(cd <dir>/v13app && TYPECHECK_DEFINES=DEBUG tools/typecheck/typecheck.sh <dir>/tc13)`（その版の `tools/typecheck/typecheck.sh`。Mac Catalyst の型の確かめ）。

## 見本を足すとき

見本を `MANIFEST` に足すと、Probe（4 つの `Version.swift` の `expectedDrawn`）・`Real123LedgerTests`（`drawnBy123`）・`Real13LedgerTests`（`drawnBy13`。v13 の `expectedDrawn` と同じ数）・`TegakiKit/Tests/CompatSpanTests` が、その行の期待が無いことで落ちる。見本のファイルから数を書き出して、それぞれに 1 行足す（版のレイアウトにあるマスの、点のある生きた線の数。1.3 は週にメモの `extra` があるので、週のメモの線も数える）。月曜の形なら、CI が compat11 の一時フォルダにも写すので、`tools/compat-span/EXPECTED_MIN` も数え直す（1 ファイル 17 件）。

見本は v13 の `versionExtraChecks` で 1.3 の `SpanGuard.checkForSave` も通る。窓の中だけの名前（`<pageId>|…`・`span~…`）を持つ見本は 1.3 が保存し直すときに直す（＝変える）ので、足してはいけない（足すと v13 の Probe と `Real13LedgerTests` が落ちる）。版ごとの確かめを足したときは、その確かめが新しい見本にも当たることを、手元の `run.sh` で見る。

1.3 の数え方（v13・`drawnBy13`、2026-11-20 に見本のファイルから数えた）: 日は `grid` と `extra`、週は `grid` と週のメモの `extra`、月は日のマスと `memo`、年は日のマスにある、点のある生きた線（墓標の線と知らない道具の項目は数えない）。1.2.3 と違うのは週のメモの 3 つだけ: `w-2026-12-14` は 4（`grid` 2・`extra` 2。1.2.3 は 2）、`w-2026-12-21` は 1（1.2.3 は 0）、`w-2026-12-20` は 1（1.2.3 は 0）。

## 版を足すとき

1. `v<版>/Version.swift` を作る: `versionName`・`versionFolder`、全部の `MANIFEST` の行の `expectedDrawn`、その版の画面と同じ `versionLayout`、`versionExtraChecks(pages:)`（その版だけの確かめが無ければ、何もしない関数）。使う API はその版の TegakiKit にある物だけ（`Common.swift`・`main.swift` の API も、その版にあること）。
2. `run.sh` の注（版と commit）と `case` に版を足す。
3. `.github/workflows/build.yml` の `compat-v1-0`: その版の取り出し（`git fetch --depth=1 origin <SHA>` → `git archive`）と、`for V in …` に版を足す。アプリのテストがあれば、その木全体に写して走らせる段を足す。
4. この README の表・走らせ方・数を直す。手元の `run.sh` で、新しい版と前からの版が全部 0 failed になることを見る。

週のメモの見本（fixture 4、§5.2）は 3 つ足した: 月曜の `w-2026-12-14.week-memo.json`（メモの線 2 本と、24 時をまたいで書いた `grid` の線・中心まで 24 時の下にある `grid` の線（取り込みか手で直したファイルの形。手で書いた JSON））、月曜の `w-2026-12-21.week-memo-neighbor.json`（左の週から入るメモの線）、日曜の `w-2026-12-20.week-memo-sunday.json`（日曜の形の週のメモ）。1.2.3 までの週には `extra` のマスが無いので、メモの線は描かれず残る（`grid` の 2 本は描かれる）。1.0・<1.1.1> は日曜の週を開かない。`EXPECTED_MIN` は月曜の 2 ファイルの分（2 × 17）を足した。
