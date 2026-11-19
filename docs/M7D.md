# M7d（1.4「新しい開発環境（Xcode 27）と iPhone Duo」）の実装結果

契約は [M7D_CONTRACT.md](M7D_CONTRACT.md)。ここはリードの記録で、段ごとに節を足す。**今の状態は最初の「今の状態」の節を読む。** 各節は書いた時点の記録で、後から直さない（間違いは後の節で直す）。

## 今の状態（リード、2026-11-20 06:40）

- 契約の第 2 版（1,259 行）を 11/20 06:23 に作った（Workflow: 調べる 2 役 → 下書き → 2 つの批評 33 件 → 直し）。本人の決定（11/20「Duoでもペンシルを使うので、その前提で作って下さい。」）は §1.2・§4.8 に入れた。
- 枝 `r14` を main の 7895d40 から切った。`r13` の最後の記録 ff4e3c4（`docs/M7C.md` の 3 行）を写した。
- S0'（11/20）: 955fe67 の run 44474759145 の成果物 6 つを `~/.local/share/tegaki-backup/1.4/run-44474759145/` に控え中（11/26 の 16〜17 時（日本時間）に消える。契約 §3.6）。
- 次: D0（契約 §3.3）。

## S0（契約・枝・前もっての宣言、2026-11-20）

### 契約の材料

- [m7d/FACTS.md](m7d/FACTS.md): Web の事実（2026-11-20 に読んだ。51 の出典）。
- [m7d/CODE_SURVEY.md](m7d/CODE_SURVEY.md): コードの調べ（origin/main 7895d40）。
- [m7d/duo_span_calc.py](m7d/duo_span_calc.py): Duo の窓の推定の計算（CODE_SURVEY §3.2）。
- Apple の文書の写し（Web の控え）はリポジトリに入れない（スクラッチパッドの `m7d/web/` と、控えの `~/.local/share/tegaki-backup/`）。

### 前もっての宣言（契約 §3.7。D0 の最初の run より前に書く）

1. D0 の commit の `Sources`・`TegakiKit/Sources`・`Tests` は 955fe67 と 1 バイトも同じ（`git diff 955fe67 -- Sources TegakiKit/Sources Tests` が空）。D0 の commit を作った時に、ここに結果を書く。
2. J-4 で違ってよい写真（§3.5）: `ipad13-portrait-sheet-info.png` の版の字の所（「1.3」→「1.4」）だけ。
3. env.txt で見込む値: Xcode 27.2（Build 27B52）、実行環境 iOS 27.2（24B8117）、`ipadmini` だけ iOS 27.0、Duo は iOS 27.2 の Duo の組（24B91016s）、XcodeGen 2.46.0。
4. 機種の替わり: `iphone69` は `iPhone 18 Pro Max`（`iPhone 17 Pro Max`・`iPhone 17 Pro`・`iPhone 16 Pro Max` は `xcode-27` の環境に無い）。SDK の差の地図は §3.6 の 4 つの組で読む。
5. 関門 3 は 2 段: `toolbar: paperArea=` が同じなら状態の行（`pages`・`zoom`・`ox`・`oy`・`span cap:`）も同じ数。違えば `swift run KitChecks --span-state` で計算し直す。止めるのは、同じ紙の領域で数が違うときだけ。
6. `duo-probe` で測る物は §4.2 の一覧。内側を開く道の既定は道 3（開けない。11/23 まで）。
7. KitChecks の今の数 40,020（閾値 39,970）。D1 で 2 つの節を足した後の数と閾値（数 − 50）は、足した commit で書く。
8. D1 の J-4 で違ってよい写真は D0 と同じ 1 枚だけ（D1 の前にもう一度書く）。
9. §4.7 の広い窓の数（短い辺 600 pt）。測った内側の短い辺は 600 以上、外側は 600 未満であるべき。
10. 組 3 の切り抜きの一覧: 控えの成果物から選んで、D0 の run の前にここに足す。
11. `TESTS_1_3`・`FIXTURES_1_3` の行の数と、955fe67 の blob から作ったこと: D0 の commit で書く。
