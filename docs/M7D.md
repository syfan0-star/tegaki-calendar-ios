# M7d（1.4「新しい開発環境（Xcode 27）と iPhone Duo」）の実装結果

契約は [M7D_CONTRACT.md](M7D_CONTRACT.md)。ここはリードの記録で、段ごとに節を足す。**今の状態は最初の「今の状態」の節を読む。** 各節は書いた時点の記録で、後から直さない（間違いは後の節で直す）。

## 今の状態（リード、2026-11-20 06:40）

- 契約の第 2 版（1,259 行）を 11/20 06:23 に作った（Workflow: 調べる 2 役 → 下書き → 2 つの批評 33 件 → 直し）。本人の決定（11/20「Duoでもペンシルを使うので、その前提で作って下さい。」）は §1.2・§4.8 に入れた。
- 枝 `r14` を main の 7895d40 から切った。`r13` の最後の記録 ff4e3c4（`docs/M7C.md` の 3 行）を写した。
- S0'（11/20）: 955fe67 の run 44474759145 の成果物 6 つを `~/.local/share/tegaki-backup/1.4/run-44474759145/` に控え中（11/26 の 16〜17 時（日本時間）に消える。契約 §3.6）。
- **本人の言葉（11/20 07:20 ごろ、チャット）**: 「年齢区分の2問をいいえで入れて良い」「祝日のデータの元に入ったら、取り寄せてアプリに入れてよい」。契約 §0.4 の問い 1（中国の 2027 年の祝日）は前もっての了承をもらった（§9.6: 正式版に入ったら、聞き直さずに入れる）。
- 年齢区分の 2 問（§9.5 の 1）: 11/20 07:22 に公開中の App 情報の `ageRatingDeclaration`（622bab33-…）へ `sharedLocation: false`・`datingAndRelationships: false` を PATCH → **409 STATE_ERROR**（「This age rating declaration is not editable」。公開中の App 情報は READY_FOR_DISTRIBUTION で直せない）。読み戻しは 2 つとも null のまま、区分は FOUR_PLUS のまま。§9.5 の 2 の道へ: D0 の VALID の後に版 1.4 の入れ物を作り、直せる App 情報で入れる（本人の言葉はもらってある）。
- 次: D0（契約 §3.3）。

## S0（契約・枝・前もっての宣言、2026-11-20）

### 契約の材料

- [m7d/FACTS.md](m7d/FACTS.md): Web の事実（2026-11-20 に読んだ。51 の出典）。
- [m7d/CODE_SURVEY.md](m7d/CODE_SURVEY.md): コードの調べ（origin/main 7895d40）。
- [m7d/duo_span_calc.py](m7d/duo_span_calc.py): Duo の窓の推定の計算（CODE_SURVEY §3.2）。
- Apple の文書の写し（Web の控え）はリポジトリに入れない（スクラッチパッドの `m7d/web/` と、控えの `~/.local/share/tegaki-backup/`）。

### 前もっての宣言（契約 §3.7。D0 の最初の run より前に書く）

1. D0 の commit の `Sources`・`TegakiKit/Sources`・`Tests` は 955fe67 と 1 バイトも同じ（`git diff 955fe67 -- Sources TegakiKit/Sources Tests` が空）。**D0 の commit の前に確かめた: 空、追跡外のファイルも無し**（11/20 08:40）。
2. J-4 で違ってよい写真（§3.5）: `ipad13-portrait-sheet-info.png` の版の字の所（「1.3」→「1.4」）だけ。
3. env.txt で見込む値: Xcode 27.2（Build 27B52）、実行環境 iOS 27.2（24B8117）、`ipadmini` だけ iOS 27.0、Duo は iOS 27.2 の Duo の組（24B91016s）、XcodeGen 2.46.0。
4. 機種の替わり: `iphone69` は `iPhone 18 Pro Max`（`iPhone 17 Pro Max`・`iPhone 17 Pro`・`iPhone 16 Pro Max` は `xcode-27` の環境に無い）。SDK の差の地図は §3.6 の 4 つの組で読む。
5. 関門 3 は 2 段: `toolbar: paperArea=` が同じなら状態の行（`pages`・`zoom`・`ox`・`oy`・`span cap:`）も同じ数。違えば `swift run KitChecks --span-state` で計算し直す。止めるのは、同じ紙の領域で数が違うときだけ。
6. `duo-probe` で測る物は §4.2 の一覧。内側を開く道の既定は道 3（開けない。11/23 まで）。
7. KitChecks の今の数 40,020（閾値 39,970）。D1 で 2 つの節を足した後の数と閾値（数 − 50）は、足した commit で書く。
8. D1 の J-4 で違ってよい写真は D0 と同じ 1 枚だけ（D1 の前にもう一度書く）。
9. §4.7 の広い窓の数（短い辺 600 pt）。測った内側の短い辺は 600 以上、外側は 600 未満であるべき。
10. 組 3 の切り抜きの一覧（11/20 07:00、控えた run 44474759145 の `screenshots` から選んだ。J-4 の写真の名前と、その中で見えて押せる形であるべき部品）:
    - `ipad13-portrait-sheet-create.png`: 予定の画面の「キャンセル」「保存」、題名の欄（「ここにペンで書くと文字になります」）、「終日」のトグル、日付の 2 つの欄、「カレンダー」の行（›）。
    - `ipad13-portrait-sheet-edit.png`: 同じ部品（直す画面）。
    - `ipad13-portrait-sheet-paywall.png`・`iphone-portrait-sheet-paywall.png`・`iphone69-portrait-sheet-paywall.png`: 上の「あとで」、年額と月額の 2 つの枠、「14 日間無料で試す」、「購入を復元」「利用規約」「プライバシーポリシー」「使用許諾契約（Apple 標準 EULA）」の行、下の「あとで」。
    - `ipad13-portrait-sheet-settings.png`: 「完了」、チェックの行（✓）、› のある行（「予定の登録先」「カレンダーへのアクセス」「Google カレンダーを使うには」「週の始まり」）。
    - `ipad13-portrait-sheet-week-start.png`・`ipad13-portrait-sheet-holidays.png`・`ipad13-portrait-sheet-sync.png`・`ipad13-portrait-sheet-info.png`: 戻る・閉じるボタンと、選ぶ行。
    - `ipad13-portrait-sheet-export.png`・`ipad13-portrait-sheet-import.png`・`ipad13-portrait-sheet-lasso.png`: ボタンとメニューの行（`sheet-lasso` は「予定にする」を含む投げなわのメニュー）。
    - `ipad13-portrait-week.png`・`ipad13-portrait-month.png`: 見出しの ◀ ▶・年月・「日 週 月 年」の切り替え・「今日」・「＋ 予定」・保存の印・⚙、ツールバーの左端（ペン・マーカー・消しゴム・投げなわ・予定）・色・線の太さ・↶ ↷・「指でも書く」・「しまう」。
    - `iphone-portrait-week.png`: 見出しの 2 段（◀ ▶・日付・「今日」・＋・保存の印・⚙ と、「日 週 月 年」の切り替え）、ツールバー（ペン・マーカー・消しゴム・投げなわ・予定・色・「しまう」）。
    - `iphone-landscape-week.png`・`iphone-landscape-month-toolbar-collapsed.png`・`ipad13-portrait-toolbar-collapsed.png`・`ipad13-portrait-toolbar-collapsed-right.png`: 横の見出しとツールバー、しまったツールバーのボタン。
    - `ipad13-portrait-readonly.png`・`iphone-portrait-readonly.png`: 閲覧専用の表示と、その画面のボタン。
    - アラートの写真は J-4 の組に無い（あれば足す）。
11. `TESTS_1_3`・`FIXTURES_1_3`: **29 行・37 行**。どちらも 955fe67 の blob から契約 §5.5 の printf の形で作り（LC_ALL=C で並べた）、D0 の木で `shasum -a 256 -c` が 29/29・37/37 OK。内訳: TESTS_1_3 は `Tests/TegakiCalendarTests` 19・UI テスト 3・`CompatSpanTests` 1・`CompatSpanFixtures` の .swift 2・KitChecks 4。FIXTURES_1_3 は compat11 17（`.gitignore` を含む）・compat-span 17（`MANIFEST` を含む）・`CompatFixtures` 1・`EXPECTED_MIN` 2。段の確かめ: ファイルを 1 つ足す・消す、`PaperViewTests.swift` に 1 バイト足す、のどれでも手元で exit 1。

### D0 の commit（Workflow wf_c4f93814-c94 の D0 の組: 作る → 2 つの別の目 → 直す。11/20 07:00〜08:30）

- 中身は契約 §3.3 の 1〜9。`runs-on` は compat-v1-0 だけ `macos-26`（45 分のまま）、ほかは全部 `xcode-27`（build-and-test 110 分）。XcodeGen は 10 か所で `tools/ci/install-xcodegen.sh`（2.46.0、sha256 固定）。
- 作る役が決めた所（契約の字の外。受けた）:
  1. `build.yml` の `branches-ignore` に `r14-duo*`（duo.yml の枝で build.yml の 6 つも走ると同時の上限 5 を超える）。
  2. span-shots-app の「Language photos」を `r14` でも走らせる（§3.6 の (B) の `span-shots-app-languages` を D0 で得るため）。
  3. span-shots-app の Xcode の選びの上限 5 → 10 分（`-runFirstLaunch` の分）。
  4. 単体テストと同期の繰り返しは機種の名前でなく UDID で指す。同じ名前が 27.0 と 27.2 にあるときは新しい iOS を選ぶ。iOS 27.2 の 2 つの組（ふつうの機種・Duo）は、Duo 以外は Duo の無い組を、Duo は Duo だけの組を選ぶ（見分けがつかないときだけ警告）。
  5. 「表と同じ字か」は最後の別の段で env.txt を読んで確かめる。
  6. 新しい env.txt（ui-tests・l10n・blank・duo-probe と、store-shots は `env-store-<set>` の成果物）。compat-v1-0 と testflight は env.txt が無く、関門 8 はログの `xcodegen --version` で読む。
  7. **`r14-q-m1` は変異の枝**: 速い道（QUICK）のままで、単体テストは全部の組を走らせ、compat-v1-0 も走らせる（`MUTATIONS`）。契約 §3.10（r14-q-* は速い道）と §5.3 の 6・§6（変異を r14-q-m1 の単体テストと compat-v1-0 で見る）の食い違いをこれで解いた。ほかの `r14-q-*` と `r14-quick` は 1.3 と同じく build-and-test だけ。D1 の新しいテストの組は、速い道の単体テストの絞り（`build.yml` の Span の組だけの正規表現）に D1 で足す。
  8. duo-probe は写真モードの状態の行（`span.state` の読み上げのラベル）を出せない（写真モードでログに書かない。D0 はコードを変えない）。§4.2 との違いとして受け、D1 の `--screenshot-measure` で取る。
- 受けた注意（直さない）: blank-paper はジョブに `continue-on-error`（1.1.1 から）なので、機種が無いとジョブは赤になるが run は赤にならない。**関門 1 は blank-paper のジョブの結果で読む**。環境が更新されて「Select Xcode 27.2」が落ちたら、Build の字が小文字で終わる版でないかを見る（§3.1 の規則で、閉じる側に落ちる）。
- §3.9 の最後（`macos-26` に Xcode 26.6 が無ければ落とす）は D1 で入れる。
- 直す役の一度だけの規則の外れ: 自分の作業の場所で、まだ無いフォルダに `rm -rf` を 1 回打った（何も消えていない）。
