# tools/span-compat — 古い版の本物で compat-span の見本を読む

1.3 は、ページをまたいで書いた線（紙の外の点を持つ線）・ページをまたぐ移動・日曜始まりの週の帯・写真と文字の札の形の知らない道具の項目を保存する（`docs/M7C_CONTRACT.md` の §4.2、§6.3）。その見本 `TegakiKit/Tests/Fixtures/compat-span/` を、**古い版の本物の TegakiKit とアプリ**が読んでも、消さない・切らない・動かさない・変えないことを確かめる（K-7）。`tools/compat10` と `tools/weekstart-compat` は変えず、ここに別に置く。

| ファイル | 役目 |
| --- | --- |
| `Probe/Common.swift`・`Probe/main.swift` | 3 つの版で同じ確かめ。3 つの版のどれにもある API だけを使う |
| `v10/Version.swift` | 1.0（a21e469）のレイアウトの作り方と、各見本で描く線の数 |
| `v11/Version.swift` | `<1.1.1>`（`tools/l10n/ja-baseline-ref.txt` の commit、9cbc3c9）の同じもの |
| `v123/Version.swift` | 1.2.3（43fe366）の同じもの。日曜の `w-` は日曜始まりで開く（K-11） |
| `run.sh` | 版の TegakiKit を指す Swift のパッケージを作業フォルダに作り、`Probe` を組み立てて走らせる |
| `AppTests/Real123LedgerTests.swift` | 1.2.3 のアプリの台帳と同期のエンジンで、全部の見本を読む XCTest（`tools/compat10/AppTests/Real10LedgerTests.swift` と同じ形） |

## Probe が確かめること（見本のファイルごと）

- `MANIFEST` とフォルダの `*.json` が両方向で同じ。月曜と日曜の行がある。全部の行に、その版の期待（描く線の数、または「開かない」）が `Version.swift` にある。
- 読める・ページ id がファイル名のとおり・書き戻すバイトが同じ・JSON と圧縮した形の往復が同じ。
- ファイルの項目（線と知らない道具の項目）と墓標が全部残り、どの線も書かれたまま（マス・点。切らない・動かさない）。
- その版のレイアウト（予定なし・そのページの線の下端・東京）で、描く線（`InkLedger.drawing()` と同じ: 点があり、マスがレイアウトにある生きた線）の数が期待どおり。投げなわの候補が描く線と同じ。描く線は紙の上の範囲を持つ。開かないページ（1.0・<1.1.1> の日曜始まりの週。その日の週は `w-2026-11-02`）は「開かない」と期待どおり。
- 開いても何も動かない（帯の移し替え）・自分との merge で変わらない・その版が描く線を全部消しても、ほかの項目は 1 バイトも変わらない・その版の端末が自分のマスに書いた線と両方向で merge しても、ほかの項目と墓標は変わらない。
- 全部のページの書き出し → 取り込みで全部がそのまま入り（飛ばし 0）、書き出し直すと同じバイト。

最後の行が `span-compat <版>: N checks, 0 failed` で、終了の状態が 0 なら合格。失敗は `FAIL` の行に出て、終了の状態は 1。

## 走らせ方

古い版の TegakiKit を取り出し、`run.sh` に渡す。作業フォルダはリポジトリの外（省くと一時フォルダ）。

```sh
# <dir> はリポジトリの外の空のフォルダ
mkdir -p <dir>/v10 <dir>/v11 <dir>/v123
git archive a21e4692109e504701b507ad9c695181fdecddfd TegakiKit | tar -x -C <dir>/v10
git archive "$(tr -d '[:space:]' < tools/l10n/ja-baseline-ref.txt)" TegakiKit | tar -x -C <dir>/v11
git archive 43fe36666a2120e8a23adf4fc76244151a395e6f TegakiKit | tar -x -C <dir>/v123
tools/span-compat/run.sh v10 <dir>/v10/TegakiKit <dir>/work
tools/span-compat/run.sh v11 <dir>/v11/TegakiKit <dir>/work
tools/span-compat/run.sh v123 <dir>/v123/TegakiKit <dir>/work
```

CI は `compat-v1.0` のジョブで、既にある `v10`・`v11` の checkout と、`git archive 43fe366 TegakiKit` で取り出した `v123` に対して同じことをする。同じジョブで、43fe366 の木全体（`v123app`）のアプリの単体テストに `AppTests/Real123LedgerTests.swift` を足し、そのクラスだけをシミュレータで走らせる（見本のフォルダは `TEST_RUNNER_TEGAKI_COMPAT_SPAN_FIXTURES`）。

## 見本を足すとき

週のメモの見本（fixture 4、§5）を `MANIFEST` に足すと、Probe（3 つの `Version.swift` の `expectedDrawn`）・`Real123LedgerTests`（`drawnBy123`）・`TegakiKit/Tests/CompatSpanTests` が、その行の期待が無いことで落ちる。見本のファイルから数を書き出して、それぞれに 1 行足す（1.2.3 までの週には `extra` のマスが無いので、週のメモの線は描かれず残る）。月曜の形なら、CI が compat11 の一時フォルダにも写すので、`tools/compat-span/EXPECTED_MIN` も数え直す。
