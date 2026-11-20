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

1. D0 の commit の `Sources`・`TegakiKit/Sources`・`Tests` は 955fe67 と 1 バイトも同じ（`git diff 955fe67 -- Sources TegakiKit/Sources Tests` が空）。**D0 の commit の前に確かめた: 空、追跡外のファイルも無し**（11/20 07:50）。
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

### D0 の commit（Workflow wf_c4f93814-c94 の D0 の組: 作る → 2 つの別の目 → 直す。11/20 06:50〜07:50）

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

## D0 の最初の run（run 44632524223 の attempt 1、r14 0067216、11/20 07:51〜09:44）

- **結果: 関門 1 が落ちた**。緑は compat-v1.0（11.7 分）・UI テスト（53 本のうち 43 本が走って失敗 0、10 本は飛ぶ。30.4 分）・l10n-shots（43.2 分）・blank-paper（52.4 分）。build-and-test は 110 分の上限で切れた（112.7 分）。span-shots-app は「Shots on four devices」が 36 分で `The operation was canceled.`（上限の 65 分・90 分には届いていない。理由は調べ中）。
- **関門 2（保存のバイト）は通った**: `InkLedgerTests.testLedgerWritesTheCompatShapes`・`ScreenshotModeTests.testDemoPagesMatchCompatFixtures`・`SpanSessionTests.testSpanSessionWritesTheCompatSpanShapes` の 3 つとも、作り直さずに今の fixture と同じ。新しい Foundation でも JSON のバイトは同じ。
- KitChecks 40,020（閾値 39,970）。`TESTS_1_3`・`FIXTURES_1_3` の段は緑。
- env: Xcode 27.2（27B52、`/Applications/Xcode_27.2.app`）、XcodeGen 2.46.0、Python 3.15.2、実行環境 iOS 27.2（24B8117）・Duo の組（24B91016s）・iOS 27.1・iOS 27.0（24A434）。**実行機の環境の版がジョブで違った**: 20261119.0378.1 と 20261104.0337.1（§3.8 の配り中の環境。J-4 は同じ版の組でだけ合否を決める）。
- **単体テスト 745 本のうち 2 つのテストが落ちた**（失敗 5 件）:
  1. `PaperSpanTests.testTheOnePageBandIs1_2_3OnScreen`（`TESTS_1_3` の 1 つ）: 日の帯の 2 つの場合（倍率 0.0854 と 0.5）だけ、帯の青（#2563eb）の点が 0 個（「the band is drawn」）。週の 3 つの場合は通った。凍結の写し（`Frozen123AllDayBand`）とアプリの帯（1 ページ・1 ページの窓）は点ごとに同じ（違いの確かめは落ちていない）。
  2. `StoreKitSessionTests.testIneligibleAfterATrial`（凍結の表の外）: 試用の期限切れは読めた（`.readOnly(.expired)`）が、5 秒たっても 2 つの商品が「お試しを受けられる」（`eligible=true`）のまま。
- **時間**: 単体テストの段 25 分（1.3 は 10.5 分。lockdown の 120 秒の待ちと、終わってから結果の束を書くまで 4.5 分を含む）。シミュレータの起動は 1 台 5〜11 分（`iPhone 17` 4:41、`iPhone 18 Pro Max` 6:26、`iPad mini (A17 Pro)` 10:36、選んでから起動の確かめまで）。4 台の写真の段は 56 分で切れた（1.3 は 36.5 分。`ipad11` は撮れていない）。span-shots-app は `ipad11` の `testBands` で XCUITest の「Setting device orientation to Portrait」が 32 分止まり、`Failed to get list of active applications: Accessibility error kAXErrorIPC` で落ちた。
- 成果物とログは `~/.local/share/tegaki-backup/1.4/run-44632524223-a1/` に控えた（attempt 2 で同じ名前の成果物が上書きされるため）。
- 次: 落ちた 2 つのジョブを 1 回だけ走らせ直す（§3.8 の FLAKE と同じ扱い。attempt 2、09:55〜）。揺れか、新しい SDK で決まって起きる差かを見る。並行して原因の調べ（Workflow wf_43c5ad9d-19e: 帯・StoreKit・時間・SDK の差の地図の下書き）。

## D1 のアプリ側（Workflow wf_05b99cd8-494、11/20 08:00〜09:55。枝 `r14-w-d1` 5ede8ad、r14 には未だ入れない）

- 組: S（PencilPhone・設定・画面の糊・SpanSession の上限の窓・S のテスト）、U（シートの窓の大きさ・写真モードの `--screenshot-measure`・`--screenshot-pencil-phone`・DuoLayoutUITests・DuoHingeUITests）、P+X（PaperView の倍率の trait・8 つのキーの注）、C（`tools/duo/idiom_check.py`・`shot_checks.py`・build.yml の D1 分・duo.yml の duo-shots と duo-hinge）。4 つの枝を `r14-w-d1`（c2de616 = r14 ba80f74 + Kit + compat の枝）にまとめ、2 つの別の目（A: 契約と動き、B: データとテストと CI）で調べ、直した。
- 手元の確かめ（最後の 5ede8ad）: typecheck（ふつう・DEBUG・DEBUG DUO_HINGE）0 警告、KitChecks 40,794（閾値 40,744）、`shasum -c` DATA_1_1 20・TESTS_1_2_3 8・TESTS_1_3 29・FIXTURES_1_3 37 全部 OK、lint・build.py・baseline.py OK、YAML 5 つ、shot_checks と idiom_check の self-test OK、idiom の許しの表 10 行・問題 0。**新しいテストはまだ 1 本も走っていない**（この Mac にシミュレータが無い）。速い道 `r14-q-d1`（run 44649291195）で回し始めた。
- `git diff 0067216 --stat -- Sources TegakiKit/Sources Tests`: 27 ファイル、+4305 / −55（新しいテストのファイル 9、アプリ 11、Kit 7）。凍結の表のファイルは 1 つも変えていない。
- リードが受けた、契約の字との違い（凍結のテストのため、または契約の文の穴）:
  1. `makeSession` は `overviewCap: true` のまま（凍結の `ScreenPathsSpanTests.testEveryJoinedPlanCarriesTheCap` がこの字を求める）。窓の答えは別の引数 `wideWindow` で渡し、使う上限は「頼んだ ∧ 広くない」。redecide も「頼んだ ∧ `overviewCapNow()`」。画面の動きは契約の形と同じ。
  2. `Device.wide` は iPhone だけ（凍結の 2 つのテストが広い iPad の窓を `Device(deviceClass:orientation:)` と比べる。iPad の plan には元から上限が無い）。
  3. `PencilPhone.launchDefault` が `appear()` の 1.3 の既定を書く（同じ時・同じ鍵と値）。書いた起動では書いた origin（`.app`）を返すので、`-allowFingerDrawingChosen NO -allowFingerDrawingAuto ""` の起動も初めての起動と同じに読む（引数の領域が鍵を隠し続けるため）。**契約 §2.1 の最後の行は直さなくてよい**（どちらの引数の組でも origin は `.app`）。
  4. 初めて開くページの決めは `isPad: idiom != .phone`（1.3 の「iPhone 以外は月」のまま）。PencilPhone は `idiom == .pad`。
  5. 予定のシートの form sheet の側は 1.3 の iPad と同じ素の sheet（`.form.fitted` を足すと iPad が変わる）。
  6. 写真モードの測りの行（`ScreenshotMode.measurePlan`）は SpanPlan を作らず Kit の static で数える（凍結のテストが ScreenshotMode.swift の `SpanPlan(` を 1 つだけ許す）。スクラッチの比べで 152,576 通り違い 0。
  7. `--screenshot-pencil-phone` は `allowFingerDrawingChosen=true` も書き、印を消す（「持ち越し・オフ」で、何も替えない）。
  8. PaperView の倍率は窓にある時だけ追う（PDF の描き手のダミーの倍率を守る）。そのテストを 1 本足した。
  9. `DuoLayoutUITests` の「指でも書く」オンの横の道は 2 本指の pan が XCUITest に無いので、1 本指で線が書けてページと題が動かないことを見る。2 本指は本人の Duo で（§10）。シートは両方の画面でスクロールしてよい形で見て、スクロール無しの (a) は内側でだけ記録する（`formSheetOnWide` を決める材料）。
  10. `DuoHingeUITests` は XCUIHinge の名前が分からない（27.3 は beta で SDK が無い）ので、Objective-C の実行時で探して角度を入れる。無ければ飛んで、見つけた名前を書く。
  11. duo-probe は D1 から dispatch だけで走る（duo-shots が push で走る）。D0 の関門 6 の duo-probe は、D1 を入れる前の r14 を `r14-duo-probe` に push して D0 の duo.yml で走らせる。
- 2 つの別の目の指摘と直し（直す役 b7271fd・5ede8ad）:
  - A-1: Pencil でツールバーの「指でも書く」を押すと、離した時にアプリがオフを書き、同じ離しでトグルが読んで「本人」がオンに戻すおそれ → 離しで決めた動きは main actor の次の回で書き、その間に本人が触れていたら捨てる（`afterTheLift`）。テストを 1 本足した。**リードの判断: 受ける**（「全部が離れた時に替える」は守られ、1 回だけ後になる）。
  - A-2: iPad の初めての起動の印が、iPhone に戻したバックアップで「移ってきた・オフ」と読まれてオンに戻る → **iPad は印を書かない**（読むと「持ち越し」）。**リードの判断: 受ける**。§4.8 の「1.4 の appear() が初めての起動の既定を書いたとき、その端末の印を書く」は「iPad 以外で」と読む（「iPad では何も付けない・何もしない」と、今の端末を 1.3 と同じに保つ方を取る）。
  - A の注 a: 戻し（turnOnAgain）の後に Pencil が触れると「アプリ」の行でオフにし、札を出し直す。F10（移ってきた人に札を出さない）と食い違うように見える → **リードの判断: §4.8 の表の字のまま**（「どちらも以後は『アプリ』の行で動く」）。戻しが起きるのは 1.4 が印を書いた端末から運ばれた値だけで、その人は 1.4 を使っていた人なので、札の文は 1.3 の人に合わないという F10 の理由に当たらない。起きるのは折り目の答えが無い Duo（`usesHinge` が false）だけで、札が 1 回出るだけ。
  - A の注 b: 「移ってきた・オフ」に Pencil が触れたら rebind（§4.8 の表に無い行）→ **リードの判断: 受ける**（Pencil が使える iPhone は Duo だけなので、折り目と同じく「この端末はオフでよい」の証拠）。FingerDefault の頭の注に書いてある。
  - A の注 c: 窓の触れの見張りが iPhone の手振りを遅らせないことは CI の iPhone の UI テストで見る。
  - B-1: スイッチの Binding（`personSet`・`personSwitched`）を見るテストが無かった → `testPersonSetMarksThePerson` がソースを読んで確かめる形に（4 つの変異を手元の写しで捕まえた）。
  - B-2: duo-shots が内側の画面のテストを走らせられなかった → 道 1 のときは外側・内側の 2 回走らせ、`DUO_UI_MIN_RAN_INNER` = 8。
  - B-3: 道 3（内側を開けない）では §6 の U の行の「見出しの変異」を見るテストが無い（外側の縦は幅でも idiom でも 2 段）。**記録: 道 3 の間はこの変異を `r14-duo-m1` に入れない**。内側の道ができたら入れる。
  - B-4: `DUO_SIZE_RULE` の既定 "fail" → "warn"（§7.1「ほかの寸法なら警告して使わない」）。duo-shots で 1398×2034 を見てから "fail" に。
- 測ってから決める物（duo-shots の後）: `PencilPhone.usesHinge`（false）・`DUO_USES_HINGE`（unknown）・DuoLayoutUITests の `usesHinge`/`hingeRead`、`WindowClass.formSheetOnWide`（false）、DuoFoldTests の推定の大きさ、DuoChecks の測った行、`DUO_OPEN` などの道の変数、`DUO_UI_MIN_RAN_PATH3`（4）。
- 規則の外れ（記録）: C の役が自分のスクラッチのフォルダに `rm -rf` を 2 回打った（作業の木には触れていない）。
- 順番の外れ（記録、10:05）: 契約 §3.3 の順（build.yml → ja-baseline → testflight → duo-probe、同じ時に別の workflow を足さない）を、D0 の build.yml の走らせ直し（2 ジョブ）と D1 の速い道（1 ジョブ）の間に、duo-probe（`r14-duo-probe` に 0067216、run 44649975338）と testflight（r14、run 44649976250、ビルド 27）を足した。同時の macOS のジョブはちょうど 5（上限 [S55]）。順の理由（同時の上限と、J-4 の同じ UTC の日）は守れる: ja-baseline は走らせ直しの後に同じ UTC の日（11/20）に回す。duo-probe は合否に使わず、testflight は写真を撮らない。`r14` の頭（ba80f74）は [skip ci] なので、duo-probe には D0 の commit を push した。

## D0 の関門 5・6 と年齢区分（11/20 10:00〜10:20）

- **関門 5 ○**: testflight（r14 ba80f74、run 44649976250、ビルド **27**、環境 20261104.0337.1、XcodeGen 2.46.0）。アーカイブの確かめ: `DTSDKName iphoneos27.2`・`MinimumOSVersion 17.0`・`UIDeviceFamily 1, 2`・`DTXcode 2720`・`DTXcodeBuild 27B52`・`DTPlatformVersion 27.2`。アップロード成功、Connect で **VALID**（10:10 に読んだ。版 1.4、minOs 17.0）。
- **0d-6**: 内部テストのグループが「全部のビルドを受ける」設定なので、ビルド 27 は自動で配られていた（`IN_BETA_TESTING`）。VALID を確かめた直後に**期限切れ**にした（PATCH `expired: true` → 読み戻し `EXPIRED`。1.3 の試作のビルド 24 と同じ）。
- **年齢区分の 2 問（§9.5 の 2）○**: 版 1.4 の入れ物を作った（`appStoreVersions` e32a8b9c-…、PREPARE_FOR_SUBMISSION、MANUAL、著作権は 1.3 と同じ。直せる App 情報 fb8d76d7-…）。その `ageRatingDeclaration` に `sharedLocation: false`・`datingAndRelationships: false` を PATCH（200）、読み戻し 2 つとも false、区分は **FOUR_PLUS** のまま。1.4 の提出で一緒に出る。本人の言葉（11/20 07:20 ごろ）「年齢区分の2問をいいえで入れて良い」。
- **関門 6 ○**: duo-probe（`r14-duo-probe` 0067216、run 44649975338、環境 20261104.0337.1）が env と写真を残した。Duo は `iPhone Duo`（`iPhone19,4`、iOS 27.2 24B91016s、この実行環境の機種は Duo だけ、起動 99 秒）。写真は primary の画面だけで **1398×2034**（外側の見込みと同じ）。外側の写真では、アプリの窓の右に時刻と電池の帯が縦に出て、アプリは幅の約 82% に描かれている（D1 の duo-shots の `duo measure:` の `safe=` で測る）。環境の Xcode は 27.0（27A266a）・27.1（27A9275）・27.2（27B52）で、27.3 は無い（duo-hinge はまだ走らせられない）。成果物は `~/.local/share/tegaki-backup/1.4/duo-probe-44649975338/` にも控えた。

## D0 の走らせ直し（attempt 2、11/20 09:52〜11:12）と D1 の速い道（run 44649291195）

- attempt 2（落ちた 2 ジョブだけ、同じ 0067216）: build-and-test は環境 20261104.0337.1 で **79 分で全部の写真まで終わった**（attempt 1 は 20261119.0378.1 で 110 分で切れた。遅さは主に環境の版による）。単体テストは **同じ 2 つが同じ形で落ちた**（帯の日の 2 つの場合の青 0、StoreKit の試用後の資格）。これで帯は 3 回（D0 の 2 回と D1 の速い道）、StoreKit は 2 回、同じ落ち方: **揺れではなく、新しい SDK・実行環境で決まって起きる差**。
- attempt 2 ではテストの入れ物（アプリ）が `InkCanvasViewTests.testHeightChangeAtTheOverviewFollowsTheNewFitAll` の始めで 1 回止まり、xcodebuild が「Restarting after unexpected exit, crash, or test timeout」で立ち上げ直した（そのテストは 2 回目に通った。最後の数は 2 回目の分だけの 552 本）。attempt 1 には無い。結果の束（xcresult）は成果物に無いので原因は分からない。**揺れとして記録**（§3.8 の FLAKE と同じ扱い）。
- span-shots-app は attempt 2 も `The operation was canceled.`（段の始めから 39 分、ジョブの始めから 43 分。ipad11 は 4 本とも通り 19 枚・25.5 分、次の `iPad mini (A17 Pro)`（iOS 27.0）の起動の途中で切れた）。attempt 1 は ipad11 の向きの切り替えで 32 分止まった所で切れた。どちらも上限には届いていない。GitHub は理由を残さない。**推定**: シミュレータが止まって実行機の VM が応えなくなり、実行機の側でジョブが切られた。
- D1 の速い道（`r14-q-d1` 5ede8ad、run 44649291195、環境は env.txt）: KitChecks 40,794（閾値 40,744）、idiom の見張り 10 行・問題 0。単体テスト 284 本のうち落ちたのは 3 つ: 帯（D0 と同じ）、**`PaperSpanTests.testWithoutNeighborInkThePDFIsTheDefaultCallsPDF`**（2 つの PDF が同じ長さで中身が違う。D0 の 2 回では通った）、**`PencilPhoneTests.testHingeIsNilOffTheDuo`**（D1 のテスト。折り目の無い iPad Pro 13 では `UIHingeInteraction` の知らせが 5 秒間 1 回も来なかった。Apple の文書の「最初の状態で 1 回呼ぶ」と違う）。D1 の新しいテストの組 7 つのうち 6 つ（CappedOverviewWide・DuoFold・OnePageReveal・PaperViewScale・SnapshotScale・WindowClass）は全部通った。
- 折り目のテストの直し（b21d7e0、D1 の直す役 → 別の目で確かめ）: 3 秒の間に「折り目あり」の知らせが来ないことを見る形に（知らせが来ない・来て nil、のどちらも通る。折り目が来れば落ちる）。PencilPhone は知らせが無いときに `hinge(false)` を返す（`usesHinge` が false の今はすぐ）ことを確かめ、取り消した待ちが答えを返さないように 1 か所直した。
- 調べの試し（`r14-q-probe` 8aead6d = r14 + 新しいテストのファイル 3 つ、何も落とさない）: 帯（窓の位置 y 0 と y 300、四隅が直角の形と丸い形、ScrollView の有無、待ち 0.05 秒と 1 秒、描き方 2 通り）、PDF（同じ PDF を 4 回ずつ作り、違うバイトの場所と種類を書く）、StoreKit（資格を買う前に読む順と、履歴を見てから初めて読む順）。run 44659376399。D1 の直しは `r14-q-d1` に push（run 44659380308）。
- 控え: `~/.local/share/tegaki-backup/1.4/run-44632524223-a2/`、調べの報告は `~/.local/share/tegaki-backup/1.4/d0b/`。

## D0b の調べの結果（試しの run 44659376399、`r14-q-probe` 8aead6d、11/20 11:15〜11:35、環境 20261104.0337.1）

- **帯（`PaperSpanTests.testTheOnePageBandIs1_2_3OnScreen`）の原因**: iOS 27 の UIKit が、テストの描画の道具（`renderOnScreen` の窓）の中の SwiftUI の `HostingScrollView` の**上の端に「スクロールの端の効果」（`UIKit.ScrollEdgeEffectView`、`CABackdropLayer` とグラデーションの覆い、高さ約 24 pt）**を自動で付け、`drawHierarchy` の写しにそれが写る。帯の上の約 24 pt が白っぽくぼける（帯の青 #2563eb が #3971ec などになり、許しの幅 12 を超える）。
  - 証拠: ScrollView の中の棒は、四隅が直角・丸い・ただの長方形のどれでも、窓の y が 0 でも 300 でも、待ちが 0.05 秒でも 1 秒でも青 0。ScrollView の外の同じ棒は青 4,582〜4,591。`layer.render(in:)` で描くと日の帯の棒は青 722・4,912（棒は正しく描かれている）。週の帯は 2 段目（y 23〜）が効果の下から出るので通る。日の帯は 1 段で高さ 25 pt なので、棒が全部効果の下に入る。
  - **使う人への影響は無い**: アプリの写真（D0、Xcode 27.2 で作り iOS 27.2 で撮った）では日のページの「締切」の帯は 1.3 と同じ色と位置（差は角の丸みと字のふちだけ）。効果はテストの道具の窓の中だけで出る。アプリのコードは直さない。
- **PDF（`testWithoutNeighborInkThePDFIsTheDefaultCallsPDF`）の原因**: iOS 27.2 の Quartz は情報の辞書に `/ModDate\n(D:…)`（空白でなく改行）と書く（`/CreationDate` は書かない）。テストの `stableBytes` の正規表現 `/ModDate \(D:…\)` は空白を前提にしているので日時が残り、2 つの PDF を作る間に秒が変わると 1 バイト違って落ちる。D0 の 2 回は同じ秒で通り、D1 の速い道は秒をまたいで落ちた。試しでは同じ呼び方どうしでも秒が変われば違った。**時刻で揺れるテスト**（§5.5 の (a): 2 回以上の run と原因がそろった）。
- **StoreKit（`StoreKitSessionTests.testIneligibleAfterATrial`）の原因**: iOS 27.2（24B8117）の StoreKit の試しの環境は、**お試し（FREE_TRIAL）の取引が履歴にあり期限が切れた後も、お試しの資格を true のまま返す**。買う前に資格を読まない順（試し 1）でも、読む順（試し 2）でも、`Product.SubscriptionInfo.isEligibleForIntroOffer(for:)` と商品の値が 15 秒の間 41〜42 回とも true。`clearTransactions()` の後も true。アプリは資格を自分で計算せず StoreKit の答えをそのまま見せるので、これは試しの環境の振る舞い（1.3 の CI では古いシミュレータの不具合で StoreKit のテストが全部飛んでいて、このテストは初めて走った）。
- **写真の手書きの欠け（関門 7 の組 4）**: B1（D0 attempt 1）の 16 枚で、見本の手書き（ペンの波・マーカー・メモの点・年の線）が一部欠けた。欠けの縁は PencilKit の区画（紙の 512 単位）の境目にそろう。**欠けたのは実行機の OS が macOS 27.2（環境 20261119.0378.1）のジョブだけ**: build-and-test の B1 54 枚中 4 枚、l10n 手書きのある 50 枚中 11 枚、span-shots の attempt 2 で 19 枚中 9 枚。**macOS 27.0.1（環境 20261104.0337.1）のジョブは欠けない**: build-and-test の attempt 2 は 59 枚中 0 枚（B1 との違いは欠けた 4 枚の手書きの所だけで、ほかは点ごとに同じ）、UI テストは 70 枚中 1 枚（インストール後の最初の起動。1.3 の FIX3 と同じ形）。実行環境（iOS 27.2 24B8117）は同じなので、**シミュレータの外側（実行機の OS の描き方）の不具合**と読む（推定。遅れて描くのか描かないのかは分からない。`ipad13-portrait-week` は macOS 27.2 の起動 3 回とも同じ区画が欠けた）。キャンバスには全部の線が入っていた（試しの読み上げ `pk=17;ink=17` など）。**使う人への影響は低いと読む**（同じ iOS が古い OS の実行機では全部描く）が、本人の確かめ表に 1 行足す（下の L4）。
- **アプリのログの文が読めない**: iOS 27.x のシミュレータでは `log show` がアプリの中の共有のライブラリ（dyld の共有の写し）の文の元を引けず、NSLog の行が全部 `<compose failure [shared UUID]>` になる（B の全部のログ、両方の環境、3 つの実行環境。1.3 の iOS 26.4 は 0）。テストの道具がアプリに入れる行は読める。**関門 3 は span-shots-app の `lines/<機種>.txt` の `frame=`（キャンバスの実際の大きさ）と状態の欄で読む**（1.3 の run で `frame=` の大きさは全部その機種の `toolbar: paperArea=` の値のどれかと同じ。手順の替わりとして記録）。attempt 2 の ipad11 は 19 枚・9 行の frame・pages・zoom・ox・oy が 1.3 と全部同じ。残り 3 機種は span-shots が最後まで走った run で読む。

### D0b のリードの決定（11/20 12:30、契約の外れと足し。§0.5「自動の確かめのやり方」は本人が決めなくてよいこと）

- **L1（§5.5 に (c) を足す）**: `TESTS_1_3` のファイルを、(a)(b) のほか、(c)「新しい SDK の UIKit が、テストの描画の道具（テストのファイルの中の手順）に、アプリの描く物ではないシステムの飾りを足すことを、試しの run で示したとき」に替えてよい。直しはその飾りを消すことだけで、比べる物・期待の数・比べ方は変えない。同じ commit で表の行を書き直す。今回は `PaperSpanTests.swift` の `renderOnScreen` で、ScrollView の端の効果（iOS 26 から）を隠すだけ。
- **L2（§5.5 の (a)）**: `stableBytes` の日時の取り除きを、鍵と値の間の空白・改行を許す形に（iOS 27.2 の Quartz は `/ModDate\n(`）。
- **L3**: `StoreKitSessionTests.testIneligibleAfterATrial`（凍結の外）は、買う前に資格を読まない順にし、期限切れを確かめ、履歴に期限の切れたお試しの取引があるのに資格が true のままのときだけ、理由（iOS 27.2 24B8117 の試しの環境、試しの run 44659376399）を書いて飛ばす。資格が false になれば今の強い確かめのまま。証拠がそろわなければ落とす。アプリのコードは変えない。
- **L4（§3.5 に (f)(g) を足す）**: (f) 写真の段に、手書きの確かめ（`tools/shots/ink_check.swift` と基準の行）と、手書きが足りないときの起動し直しによる撮り直し（1 枚 2 回まで）を、build.yml と ja-baseline.yml で**同じ字で**足してよい。結果は全部 `shots/ink.txt` に書く。(g) iPhone の横の写真は、縦長のときだけ回す（iOS 27.2 は横で書く。今は 2 回回って縦になっていた）。本人の確かめ表（§10）に **行 28**「週のページの手書き（マーカー・ペン）が欠けずに出る（iPad・iPhone、iOS 27）」を足す（行 18〜27 の番号は替えない）。
- **L5（§3.3 の 9・§3.8）**: 上限を build-and-test 160 分・同期の繰り返し 14 分・blank-paper の段 70 分とジョブ 80 分・span-shots-app の段 80 分とジョブ 110 分・ja-baseline 130 分に。13 インチの起動を macOS の段の間に始める。span-shots-app に機種ごとの見張り（テストのログが 600 秒伸びなければ止める）と、`kAXErrorIPC` などの走らせ直しの印、走らせ直しの前のシミュレータの起動し直し。
- **L6**: J-4 の写真の起動の仕方は変えない。ログを集めた後に `<compose failure` の数と、要る印が無いときの警告。l10n-shots は `l10n: holidays loaded` が無ければ警告。XCUITest が起動したアプリの NSLog は結果の束（xcresult）から書き出す（できる範囲で）。
- **SDK の差の地図の受け方**（関門 7）: 組 4 の (c)（字の間隔「日 (水)」→「日(水)」など）は受ける。**角の形**（終日の帯の棒の角が円から連続の曲線に。SwiftUI の `UnevenRoundedRectangle` の描き方の差）は、(a) が同じで説明がつくので受け、確認ページの前と後に載せる。**手書きの欠け**は上のとおり実行機の OS の描き方として受け、(f) で写真の欠けを捕まえる。UI テストの 1 枚（`A1 cross — after the eraser`）でツールバーが選んだ色の所まで横に送られていた（マーカーが左の端で切れる）。アプリの状態は同じで、iOS 27 の ScrollView の動き（選んだ物を見せる）と読み、受ける（ツールバーは確かめ表の行で本人が見る）。組 3 の切り抜き 22 枚は全部 ○。
- 写真モードの実行機の打ち切り（`The operation was canceled.`、理由を残さない）は 3 回（span-shots ×2、D1 の速い道の単体テスト ×1）。§3.8 の「落ちたジョブを 1 回走らせ直す」で扱い、2 回続けばその日は止めて環境の版を見る。

### D0b の直し（11/20、枝 r14-w-d0b、HEAD 514e046）

- **commit**: 32e9617（テスト: L1〜L3）、d84bf98（CI: L5・L6）、5b0b304（CI: L4）、a82021d（まとめ）、535a6aa・514e046（2 つの見直しの後の直し）。アプリのコード（`Sources`・`TegakiKit/Sources`）は 0 バイト。凍結の表で替わったのは `TESTS_1_3` の `PaperSpanTests.swift` の 1 行だけ（cac9e14c… → b684eb34…。§5.5 の (c) と (a)）。`DATA_1_1` 20・`TESTS_1_2_3` 8・`TESTS_1_3` 29・`FIXTURES_1_3` 37 行、全部 OK。手元の型の確かめ（ふつうと DEBUG）・`lint.py`・5 つの workflow の YAML・`bash -n`・J-4 の写真の段の字が同じこと（`j4eq.rb`）も OK。
- **見直し**: テストの目 5 件（重い物 0）、CI の目 11 件（止める物 1・重い物 2）。15 件を直し、1 件（§5.5 (c) の引用。この記録で契約に足したので正しくなった）は直さない。
- **L1〜L6 の字より広げた所（リードが受ける）**:
  - L1: 端の効果を隠すのは style が `automatic` の物だけ（アプリが選んだ style は残す）。隠すのは 1 回目の配置の後と 2 回目の配置の後の 2 回、動きなしで。**次の CI が 27.2 での最初の確かめ**。
  - L3: 買った後、履歴にお試しの取引が見えるまで資格を読まない（最初の `refresh()` も履歴を待つ）。飛ばす前の失敗は全部その場で終える。**飛ばすのは 24B8117 に限らない**（記録の行に本当の OS の版が出る。後の版で飛び続けたらここで見直す）。
  - L4: 撮り直しは段ごとに 180 秒まで（時間の上限に収めるため。見込みは最悪でも build-and-test 160 分のうち約 150、ja-baseline 130 分のうち約 124）。シートは確かめて書くが撮り直さない。撮り直しで足りた写真は `::notice::`。手書きの確かめは隣の 8 区画の増えも数える（1.3 の写真で横の年の「•••」が区画の境をまたいで欠けと読まれたため。1.3 の 45 枚・D0 の既知の欠け 4 枚と l10n の 11 枚で、誤りなし）。`ink_ref.tsv` の l10n の 11 行は 1.3 の run 44474759145 の写真から作った物（頭の注に書いた）。D0b の run の欠けの無い写真で作り直す。
  - L4 (g) を span-shots-app にも: 写真を回すのは PNG が縦長のときだけ（D0 の attempt 2 の ipad11 の横の余白の写真は 1640x2360 で、`span_margin` が数えられず落ちるところだった）。凍結の `SpanShotsUITests.swift` は替えない。
  - L5: 13 インチの iPad は単体テストと同期の繰り返しの後に止める（build.yml だけの新しい段）。J-4 の写真は 1.3 と ja-baseline と同じく起動し直した iPad で撮る。D0b の run の「Boot the simulator」は数分かけて起動するはず（「Booted」と出たら見直す）。前もっての起動が 20 分で終わらなければ止めて、xcodebuild に起動を任せる。見張りが止めた run は xcodebuild が 0 で終わっても失敗に数える。
  - L6: ログの読める度合いの段を ja-baseline にも（写真の段の外。§3.5 (h)）、duo.yml の duo-probe のログにも。
  - ja-baseline の手書きの確かめを前もって作る段（§3.5 (h)）: ja-baseline では最初の macOS の swiftc になり、写真の待ちと重なるため。build.yml にも同じ字で。
- **D1 の duo.yml** は D0b の duo.yml の 1 行（ログの読める度合い）と合わせる。

## D1b（D1 を D0b の後の r14 に載せ直し、Duo の測りの行をファイルで受け取る。Workflow wf_2d3c30cc-479、11/20 13:45〜15:50、枝 `r14-w-d1b` 015fa73）

- **載せ直し**: `r14-w-d1`（b21d7e0）を 755d611 に `--no-ff` で（8b7ebb0）。字の衝突は 0。意味の衝突 1 つ: duo-shots の `shot()` が横の写真を全部回していた → 縦長のときだけ回す（bf79ba0。L4 (g) を duo.yml にも）。D0b の CI の強化と D1 の足し（KitChecks 40,744、idiom の見張り、DUO_HINGE、速い道の D1 の 7 組、compat-v1-0）は両方そろっている（読み比べ）。
- **測りの行のファイル**（iOS 27.x の `log show` はアプリの NSLog を読めないため。D0b の調べ）: 写真モードで `--screenshot-measure` のときだけ、`duo measure:` の行を NSLog と同じ字でアプリの入れ物の `Library/Caches/duo-measure.txt` に足す（足すだけ・消さない・同期の待ちなし）。duo.yml は起動の前に消し、写真の後に `simctl get_app_container … data` で読む。次に結果の束（xcresult）の出力、最後に `log show`。`--screenshot-measure` が無いときは何もしない（ふだんの使い方と J-4 の写真は変わらない）。新しいテスト `MeasureLineFileTests`（速い道にも入れた）。測る物を差し替えられる引数 `measurer` は試しのための口。
- **2 つの見直しの後の直し**（886cabb・015fa73）:
  - Duo の外側の写真は `--display=primary` が要る（duo-probe の run 44649975338 で、指定なし・internal・main は「2 つの画面から選べない」で落ちた）。画面の誤りは撮り直さず 1 回で `::error::`。
  - duo-shots の DuoLayoutUITests の段に span-shots-app と同じ見張り（600 秒）・`kAXErrorIPC` の走らせ直し・走らせ直しの前の起動し直し（L5 を duo.yml にも）。
  - 写真の段は、黒い写真の確かめの自己試験が落ちても走る（確かめと撮り直しなし。ジョブは落ちる）。
  - 消せなかったファイルから読んだ行は `measure-sources.tsv` の 4 列目に「not cleared」と書き、警告（混ざりを防ぐのではなく見えるようにする）。
  - DuoHingeUITests は `--screenshot-measure` で起動（道 2 の内側の測り）。DuoLayoutUITests は付けない。
- **リードの決定（受ける）**: duo-hinge は D1 のまま（見張りなし、段 30 分。27.3 が出て合否に使う前に見直す）。道 1（DUO_OPEN）を入れるときは写真の段 55→90 分、ジョブ 120→150 分に上げる。duo-shots の `log-reach.sh` の警告（compose failure）は毎回出るが、そのまま（L6 の道具は build.yml・ja-baseline と同じ）。
- **確かめ（手元）**: 凍結の 4 表 OK、型の確かめ 3 通り（ふつう・DEBUG・DEBUG DUO_HINGE）OK、lint・idiom・shot_checks の自己試験・YAML・`bash -n`・J-4 の字の一致 OK、KitChecks 40,794（閾値 40,744）。CI の試し: 速い道 `r14-q-d1b`（run 44690586694）と Duo の写真 `r14-duo-d1b`（run 44690590720）。

## D0b の run（run 44676125566 と ja-baseline 44676133732、11/20 13:41〜16:21）

- 走らせた物: `r14` 755d611（D0b を入れた頭）の push の build.yml（run 44676125566、6 ジョブ、13:41〜15:26）と、ja-baseline（run 44676133732、基準 955fe67、14:26〜15:32）。UI テストのジョブだけ 1 回走らせ直した（attempt 2、15:45〜16:21）。
- 環境: attempt 1 の全部のジョブと ja-baseline は `xcode-27` の 20261104.0337.1（macOS 27.0.1）。compat-v1.0 だけ `macos-26` の 20261102.0473.1（Xcode 26.6、17F113）。**UI テストの 2 回目は 20261119.0378.1**（macOS 27.2。§3.8 の配り中の遅い環境）。Xcode 27.2（27B52）、XcodeGen 2.46.0、Python 3.15.2、実行環境 iOS 27.2（24B8117）、`ipadmini` だけ iOS 27.0（24A434）、`iphone69` は iPhone 18 Pro Max（1320×2868）。
- **結果: 関門 1 が UI テストで落ちた（2 回とも 1 本ずつ、別のテスト）。ほかの数は全部 ○。関門 2・3・4・8 は ○、5・6 は D0 から ○、7 は ?。**
- 調べ: Workflow の 6 役（関門 1・2・8 の数、J-4、関門 3、SDK の差の地図、UI テストの失敗、全部を確かめ直す批評）。役と批評が違うときは批評を取った（警告の数、UI テストで切れた問い合わせ、手書きの欠けの読み、地図の組の数）。
- ログの行の番号は GitHub のジョブのログの行。BT = build-and-test（ジョブ 136088274710）、UI = UI テストの 1 回目（136088274724）、UI2 = 2 回目（136133397077）、SS = span-shots（136088274465）、BP = blank-paper（136088274668）、L10N = l10n-shots（136088274717）、CV = compat-v1.0（136088274823）、JA = ja-baseline（136088302592）。
- 控え: attempt 1 の成果物とログ、ja-baseline の成果物は、リポジトリの外の `tegaki-backup/1.4/run-44676125566/` に写した（成果物は 7 日で消える）。

### 関門（契約 §3.3）

| 関門 | 判定 | 証拠 |
| --- | --- | --- |
| 1 全部のジョブが緑 | **×** | UI テストが 2 回とも落ちた。1 回目は `testToolbarEraserReturnsToTheRedThickPenAfterErasingALine`（環境 20261104.0337.1）、2 回目は `testEraserChosenFromTheFoldedToolbarReturnsToThePen`（環境 20261119.0378.1）。どちらも `EraserAndBelowDayUITests`。ほかの数は全部 ○（下の「関門 1 の数」） |
| 2 保存のバイト | ○ | 3 つのテストが作り直さずに通った（BT:7816・8291・8507）。`InkLedgerTests` は違えば fixture を書き出して落ちる形（`InkLedgerTests.swift:1016-1039`）なので、通ったのは同じバイトの証拠。`FIXTURES_1_3` の段も緑 |
| 3 レイアウトの数 | ○ | span-shots-app の状態の行 71 行（ipad11 19・ipad13 12・ipadmini 12・iphone 28）で、frame・pages・zoom・ox・oy・pw・ph・pk・ink が全部 1.3 と同じ。違うのは時間の欄（`trace`・`waited=`）だけ。`toolbar: paperArea=` の数は、結果の束から書き出したアプリの出力で ipad11 44・ipadmini 28・ipad13 28・iphone 50。1.3 の `log show` と同じ。(a) だけで足り、(b) に当たる行は 0。`span cap` は pages=7/9・expected=7/9 |
| 4 J-4 | ○ | 77 枚（PNG 57・店の JPEG 20）で、同じ 54・違う 23・大きさの違い 0・片方だけ 0。強い差は `ipad13-portrait-sheet-info.png` の版の字だけ（379 画素、x 1450〜1489・y 1607〜1632、「1.3 (1)」→「1.4 (1)」）。残りの 22 枚は強い差 0（最大 12/255）で、M7C.md の決まり（強い差 0 は「違う写真 0 枚」）で違わない |
| 5 testflight と VALID | ○（D0 から） | ビルド 27（r14 ba80f74、run 44649976250）が VALID（「D0 の関門 5・6 と年齢区分」の節）。ba80f74 と 755d611 で `Sources`・`TegakiKit/Sources`・`project.yml`・`testflight.yml`・`install-xcodegen.sh` の差は空。作り直しても同じアーカイブになる |
| 6 duo-probe | ○（D0 から） | run 44649975338 の env と写真（1398×2034）。同じ節 |
| 7 SDK の差の地図 | **?** | 組 3 は全部 ○。組 4 は受けた種類か説明がついた。残りは 2 つ: (1) es_MX の時刻の字（下の「リードの決定」で受ける）、(2) UI テストの 2 回目の写真の新しい差 1 つ（`SpanUITests … slide — after.png` の紙の位置。下の「関門 7」）。黒の輪と `A1 cross — after the eraser` は 2 回目の写真で読んだ（○）。2 回目の写真の手書きの欠け 13 枚は D0b で受けた種類（下の「関門 7」） |
| 8 XcodeGen の版 | ○ | env.txt 6 つ（screenshots・ui-tests・l10n・blank-paper・span-shots-app・ja-baseline）と UI テストの 2 回目の env.txt の 5 行目が `xcodegen: Version: 2.46.0`。7 つのジョブのログに `xcodegen --version: Version: 2.46.0` と zip の sha256 `4d9e34b6…6806` が 1 回ずつ（compat-v1.0 は env.txt が無いので CV:1139 で読む。UI2:241 も同じ） |

### 関門 1 の数

- KitChecks 40,020（閾値 39,970、BT:573-574）。Kit のテスト 364 本（163+95+38+5+3+23+37）、失敗 0。
- アプリの単体テスト **745 本・飛ばし 2・失敗 0**（BT:9105）。立ち上げ直しは無い。飛ばした 2 本はどちらも `StoreKitSessionTests`:
  1. `testIneligibleAfterATrial`（L3 の飛ばし、BT:8609-8611）。証拠の行は「iOS 27.2（24B8117）、5.1 秒に 32 回読み、お試しの資格はグループも 2 つの商品も true のまま。アクセスは readOnly(expired)。履歴に、確かめ済みで期限の切れたお試しの取引が 1 つ」。
  2. `testUSStorefrontPrices`（BT:8659-8660）。「試しの環境では米国の値が 300 で、App Store の $1.99 ではない」。955fe67 からある飛ばしで、D0b の変更ではない。
- StoreKit のテストは 1.3 の CI では 8 本全部が飛んでいた（飛ばしの字は「Xcode 26.3–26.6 defect」: 試しの環境の店が米国のまま）。Xcode 27.2 の D0 から走り、残りの 6 本（`testBuyingMonthlyStartsATrial`・`testConfigurationLoadsBothProducts`・`testExpiringMakesItReadOnly`・`testRefundRevokes`・`testRestoreAfterClearingTransactions`・`testUpdatesStreamTriggersRefresh`）は D0 の 1 回目・2 回目でも今回も通った（BT:8550-8656）。単体テストの段が緑の run でこの 6 本が通ったのは、今回が初めて。
- 同期の繰り返し 4,000 本・失敗 0（BT:9287）。組ごとの数（20 回 × テストの数）は 1.3 と同じ。
- `TESTS_1_3` 29・`FIXTURES_1_3` 37 OK、表の 3 つのフォルダのファイル 35 と実物の 35 が同じ（BT:1899）。`DATA_1_1` 20・`TESTS_1_2_3` 8・compat10 の FROZEN 11 も OK。
- compat-v1.0: 599 の確かめ・失敗 0（CV:621）。span-compat は 1.0 274・<1.1.1> 274・1.2.3 278、どれも失敗 0（CV:984・1050・1128）。
- l10n-shots 63 枚、blank-paper 43 枚（4 機種の `testShots` が通った、BP:3446・3822・4204・4526）。名前は 1.3 と同じ。
- span-shots-app: ipad11 19・ipadmini 12・ipad13 12・iphone 20 の 63 枚と PDF 1 枚（帯 21・ずらしの組 8・余白 30・週のメモ 4）。テストの結果は機種ごとに 1.3 と同じ。ずらしの組 4 つの説明のつかない画素は 6/32/25/63（1.3 は 6/31/25/63、上限 100）。`span-margin.txt` は 1.3 と 1 バイトも同じ。PDF のテストも通った。言語の写真は 10 言語 × 6 = 60 枚で、「アプリが見つけられなかった鍵 0」（SS:5261）。
- 写真の大きさ: 5 つの成果物の 287 組で、1.3 と違う物 0。
- UI テスト: 1 回目は 53 本・飛ばし 10・失敗 1（UI:7199、exit 65 は UI:7214）。飛ばしの 10 本は 1.3 と同じ。1.3 と結果が違うのは落ちた 1 本だけ。2 回目も 53 本・飛ばし 10・失敗 1（UI2:7330・7345）で、落ちたのは別の 1 本。

### UI テストの 1 回目（attempt 1、環境 20261104.0337.1）

- `EraserAndBelowDayUITests.testToolbarEraserReturnsToTheRedThickPenAfterErasingALine`（`EraserAndBelowDayUITests.swift:345`）が、299.5 秒の後に「Failed to get matching snapshot: Timed out while evaluating UI query.」で落ちた（UI:4680-4682）。ペン・赤・太・消しゴムの選びと 2 本の線は通った。その後の確かめで、キャンバス（`ink-canvas`）の**値の読み**が 3 回とも約 31 秒で切れた（存在の確かめは 12.5 秒かかって返った）。
- **アプリは止まっていなかった**: XCTest が取ったスピンダンプで、アプリの main thread は 344 回中 344 回とも待ちで、CPU は 0.002 秒。UI の木とキャンバスの値は、止まる前の読みと同じ。録画は 4 分間同じ画面で、時計だけが進んだ。
- **実行機が止まっていた**（13:52:10〜13:54:30 ごろ）: CI のログの遅れが最大 26.1 秒（ほかのテストは 1.3 秒以下）。3 つの CPU で 5 秒のうち 14.9 秒を使い、VM の圧縮に 1.3 秒。プロセスのメモリの和は約 9.0 GB（VM は 7 GB）。引き金は成果物からは分からない。
- 同じテストは、D0 の 1 回目（同じコード・同じ環境の版）で 47.5 秒、1.3 で 51.7 秒で通った。UI テストのジョブの字は 0067216 と 755d611 で同じ（376 行）。`Sources`・`TegakiKit/Sources`・UI テストのファイルは 955fe67 から変わっていない。
- 読み: **D0b の変更とは関係の無い、実行機の揺れ**（1.3 の FLAKE-1 と同じ種類の、問い合わせの遅れ）。§3.8 のとおり、UI テストのジョブだけ 1 回走らせ直した。テストもアプリも直さない（問い合わせは約 30 秒を 3 回まで待つので、90 秒を超える止まりはテストの側の待ちでは越えられない。待ちを延ばすと本当の止まりを隠す）。

### UI テストの 2 回目（attempt 2、環境 20261119.0378.1、15:45〜16:21）

- 1 回目に落ちた A1 は 81.5 秒で通った（UI2:4809）。
- 代わりに `testEraserChosenFromTheFoldedToolbarReturnsToThePen`（A3 dock）が `EraserAndBelowDayUITests.swift:609` で落ちた（UI2:3695）。落ちたのは `XCTAssertNotNil` で、確かめの文は「the toolbar's eraser went back to the pen within 3.00 s of the lift」（離して 3 秒のうちに、ツールバーの消しゴムがペンに戻る）。テストの見張りの 3 秒の間に、戻ったのを読めなかった（線は消え、台帳も消した: UI2:3685）。trace の最後は `Uf@23410 … R1@25843 T:pen:#1f2937:3.5@25855`。
- 同じテストは 1.1.1 の run 79 で 1 回落ちたことがある（R1_1_1.md。そのときの形は「指の線が増えない」で、今回と違う）。
- 調べ（役 U2、批評で確かめた）: **アプリは遅れていない側の失敗**。アプリはリフトの後 **2.33 秒**でペンに戻した（失敗の録画のフレーム: 32.565 秒で消しゴム、35.020 秒でペン。3 秒の枠の内）。テストの待ちの輪は、枠の中でツールバーを 1 回しか読めなかった（最初の読みはアプリの設計の 0.5 秒より前）。次の `canvas.exists` に 2.12 秒、値に 0.94 秒かかり、枠を過ぎた。アプリの報告も設計より 1.93 秒遅れたが、ちょうど 2.12 秒の問い合わせと重なった時（問い合わせの答えはアプリの主スレッドで作られる、と読む。推定）。
- 2 回の共通の原因: シミュレータの起動の後の数分、アクセシビリティの読みが遅い（実行機の側）。2 回目の環境では `simctl boot` 274 秒（1 回目 108 秒）、読みの中央値 0.34 秒（1 回目 0.16）、最大 17.8 秒。1 回目はアプリの主スレッドは待つだけ（spindump の 344 サンプル、CPU 0.002 秒）で、VM の CPU は 15 秒中 14.9 秒使われていた。アプリとテストのコードは 955fe67 から 1 バイトも変わっていない。
- 扱い: §3.8 の「2 回続けば、その日は止める」を**ジョブごと**と読み、UI テストのジョブは 11/20（UTC）にはもう走らせない。次の試しは D1 を入れた r14 の CI（11/21 UTC）。テストは今は変えない（同じ形で落ちたら、3 秒の枠はそのままで読みを細かくする直しを §5.5 (a) で入れる。強さは同じで、3 秒より遅い戻りは今と同じく落ちる）。

### 関門 3 の中身

- 状態の行は、`lines/<機種>.txt` を欄ごとに比べた。違ったのは `trace`（21 行）、`c@ms` の印（23 行）、`waited=`（4 行。iphone の `span cap` の待ち 0.2〜0.7 秒 → 0.1 秒）だけで、レイアウトの欄の違いは 0。
- `toolbar: paperArea=` の値の組は、4 機種とも 1.3 と同じ。起動 1 回の途中の値の並びが 1 か所ずつ違った（ipad11 の `week-memo-band`、ipad13 の `week-boundary`）。最後の値は同じで、写真の `frame=` と同じ。
- `trace` の `c`（アプリが受け流す PencilKit の変化の知らせ）は 28 → 41 個。iOS 27 の PencilKit が知らせを 1 つ多く出すだけで、pk と ink は全部の行で同じ（線は失われていない）。
- 足しの確かめ（要らないが行った）: `r14-w-d1b` 015fa73 の Kit の `--span-state` に 10 の紙の領域を入れ、zoom と pages が 10/10 で行と同じ。手の式（`ScreenPaths.shotPaperOffset`）で ox を出すと 21 行のうち 19 行が合い、2 行は 0.5 pt（1 画素）ずれた。**後で (b) を使うときは ox・oy に端末の 1 画素の許しを付ける**。

### 関門 4 の中身

- 比べの正しさ: 2 つの env.txt は 1〜6 行目と機種の行が同じ（違うのは iOS 27.2 の 2 つの実行環境の行の並びだけ）。ja-baseline は 955fe67 を取り出した（JA:142・217）。写真は両方とも 11/20 UTC（run 05:28:57Z〜06:26:28Z、基準 05:36:49Z〜06:32:24Z）。`compare_shots.swift` は変わっていない。755d611 の 2 つの workflow で `j4eq.rb` は「J-4 check: OK」（(h) の 2 つの段を含む）。
- 弱い差だけの 22 枚: iOS の部品のガラスとぼかし（最大は `ipad13-portrait-sheet-create` の「キャンセル」「保存」の 12/255、`ipad11-portrait-readonly` のツールバーのガラス 122,995 画素・最大 5）、アプリの字・格子・終日帯の縁（1〜2/255）、手書きの縁（線は両側にある）、店の JPEG 4 枚（違う PNG の焼き直し）。1.3 の J-4 の合格も弱い差だけの写真が 16〜25 枚あった。
- 撮り直した 2 枚（下の「D0b の確かめ」）は、相手側の 1 回目と点ごとに同じ。違う写真に撮り直しの物は無い。

### 関門 7（SDK の差の地図、§3.6）

- 453 組を 1.3（run 44474759145、Xcode 26.6、iOS 26.4）と比べた: screenshots 77・ja-baseline 77・l10n 63・blank-paper 43・span-shots-app 64・言語の写真 60・UI テスト 69。無いのは UI テストの `A1 cross — after the eraser` 1 枚だけ（1 回目はそのテストが落ちたため。2 回目にはある、下の「UI テストの 2 回目の写真」）。build.yml の写真と ja-baseline は同じ画素（77 組のうち 76 が強い差 0、残りは版の字）。
- **組の数**（強い差 = 色の差が 48 を超える画素。状態の帯は隠して数える）:

| 成果物（組） | 組 1 | 組 2 | 組 3 | 組 4（うち小さい差） |
| --- | ---: | ---: | ---: | ---: |
| screenshots（77） | 2 | 0 | 17 | 58（16） |
| ja-baseline（77） | 2 | 0 | 17 | 58（16） |
| l10n（63） | 1 | 0 | 13 | 49（38） |
| blank-paper（43） | 14 | 0 | 0 | 29（29） |
| span-shots-app（64） | 0 | 0 | 0 | 64（29） |
| 言語の写真（60） | 2 | 0 | 10 | 48（34） |
| UI テスト（69） | 0 | 0 | 6 | 63（4） |
| **計（453）** | **21** | **0** | **63** | **369（166）** |

  - **数え直し**: 地図の役の道具は D0b と同じ「強い差が 100 画素未満なら組 1」で数え、組 1 を 187・組 4 を 203 とした。しかし組 1 は状態の帯の差なので、帯の外に 1〜90 画素の強い差がある 166 枚は組 1 ではない。組 4 の「小さい差」に数え直した。組 1 に残るのは、帯の外の強い差 0 の 9 枚と、blank-paper の iPad の横の 12 枚（強い差は全部、横に描かれた状態の帯の列の中）。
  - 166 枚の中身: 批評の役が 2 枚を見た（es の `guide-week-one` 80 画素は終日帯の札の角、de の `sheet-lasso` 90 画素は投げなわと menu の縁）。どちらも受けた種類で、目では同じ。帯のある写真の 100 画素未満の差は、角の形と同じ 4 つの角の並び（地図の役）。166 枚全部は見ていない。見た 2 枚と角の並びから、判定は変わらないと読む。
- **組 2**: 無し。`iphone69` は 1.3 と同じ 1320×2868。
- **組 3: ○**。§3.7 の 10 の切り抜き 22 枚は全部 ○（19 枚は D0 の写真と強い差 0。残りの 3 枚は iPhone の横の 2 枚（D0 では横倒し、今は立っている）と `ipad13-portrait-week`（D0 で欠けたマーカーが戻った所だけ））。ほかの 29 枚（l10n 13・言語の設定のページ 10・UI テスト 6）も、ボタン・トグル・行が全部見える。店の JPEG 8 枚はその PNG の写し。スクロールの端の効果は、システムのシートの見出しのぼかしとしてだけ出る（`sheet-sync`・`sheet-info`・iPhone の設定のページ。部品は見える）。アプリのページには出ない。
- **組 4**: 受けた種類（「D0b のリードの決定」の「SDK の差の地図の受け方」）と写真の数（1 枚に複数の種類があり得る）:
  - (c) 日の題「日 (水)」→「日(水)」78 枚（2,031〜4,667 画素）。
  - (c) 括弧の間隔（出張（大阪）・国庆节（补假）など）93 枚（88〜1,495 画素。年のページ 24 枚を含む）。
  - (c) zh-Hans・zh-Hant・疑似の字の描き直し 19 枚（824 画素まで）、消しゴムの注 3 枚。
  - (c) ja の案内の行の折り返し（同じ字）4 枚（3,718〜16,222 画素）。
  - 終日帯の棒と札の角の形 8 枚。UI テストの投げなわの点線の位相 10 枚（169〜171 画素）。
  - (a) は同じ: 保存のバイトのテスト 3 つが通り（関門 2）、状態の行 71 行が同じ（関門 3）。
- **新しい差 1 つ**: es_MX の時刻の字（写真は組 3 の設定のページ、差は組 4 の字）。下の「リードの決定」で受ける。
- **SDK ではない差**: UI テストの 35 枚で、黒の色の丸に青い輪が無い。1 回目の A1 が赤と太を選んで落ち、`restoreDefaultPen`（`EraserAndBelowDayUITests.swift:116`・`:649-653`）まで行かなかったので、`toolbar.penColor` が赤のまま残った。ツールバーはその値で輪を付ける（`ToolbarView.swift:38-51`・`:234-245`）。落ちる前の写真には輪がある。1.3 でも同じ失敗の後は同じになる。
- **UI テストの 2 回目の写真**（attempt 2、環境 20261119.0378.1、70 枚。批評の役 K2 が 1.3 と 1 回目に比べた）:
  - **輪は戻った ○**: 上の 35 枚は、写真の下の 12%（ツールバー）で 1.3 との強い差が 35 枚とも 0（1 回目は縦 1,853・横 926 画素）。
  - **`A1 cross — after the eraser` はある ○**: 1.3 との強い差は、状態の帯のほかはツールバー（31,776 画素。選んだ赤まで横に送られ、マーカーが左の端で切れる）と括弧の間隔（364 画素）だけ。ツールバーの送りは「D0b のリードの決定」で受けた種類と同じ。
  - **手書きの欠け 13 枚**（`pnginkloss` で、1.3 にあって消えた暗い画素が 1 回目より 200 以上多い物。紙の位置が違う `slide — after` は除く。4 枚は目で見た）: `B2 preselected below 2400` の start・selected・after が 2 つのクラスで 6 枚、`B3 preselected above 2400 — start`（SpanRerun）1 枚、`SpanUITests … setting — off` 1 枚（ペンの波とマーカー）、YearTap の縦の `— after` 5 枚（メモの波と丸）。B2・B3 は投げなわの選択の枠があるのに、中の線が描かれていない。上の「線は入ったが描かれない」と同じ形で、20261119 の環境の XCUITest の写真でも起きた。自動の確かめが無いので、テストは通った。
  - ほかの写真は 1 回目と同じ種類の差（強い差の数で見た。目では見ていない）。新しい差が 2 つ: `LanguageUITests … paywall-de-bottom.png` はシステムのシートのスクロールの印（右の縦の棒）が出たまま（組 3、部品は見える）。**`SpanUITests/testSlideChangesTheTitleOnce :: slide — after.png`** は、紙が 1.3 と 1 回目より約 80 pt（1 日の列ほど）少なく送られた位置で撮れた（1.3 との強い差 121,652 画素）。テストは通り、ログの state の行（focus・shifts・stops）は 1 回目と同じ。遅い環境で指の動きの初めが紙に届かなかったと読むのが自然だが、示してはいない（指を離した後の位置は記録に無い）。**組 4 の (a)(b)(c) のどれでもないので、リードが読む**。
- **手書き**: 453 組の手書きの欠けの比べで、1.3 より欠けた写真は 0。D0 の欠け（ipad13・mini の週、iPhone のつまみの案内、iphone69 の年、l10n の週、UI の B0）は全部戻った。逆に 1 枚、1.3 の方が欠けていた（`span-shots-app/ipadmini-portrait-week-boundary.png`、下の「前の節の直し」）。
- **横の写真（L4 (g)）**: screenshots・ja-baseline・span-shots-app の iPhone の横は 2622×1206 で立っている（1.3 と同じ）。blank-paper の iPad の横と XCUITest の横の写真は、横の大きさの PNG の中に横倒しで描かれる。これは 1.3 と同じ。

### D0b の確かめ

- **帯のテスト（L1）**: `PaperSpanTests.testTheOnePageBandIs1_2_3OnScreen` が 5.8 秒で通った（BT:7984）。27.2 での最初の確かめ ○。
- **PDF のテスト（L2）**: `testWithoutNeighborInkThePDFIsTheDefaultCallsPDF` が通った（BT:7992）○。直す前も秒をまたいだときだけ落ちたので、1 回の通りでは直しの強さは示せない。run を重ねて見る。
- **StoreKit（L3）**: 証拠の行を書いて飛んだ（上の「関門 1 の数」）○。
- **13 インチの前もっての起動（L5）**: 13:42:11 に始め、129 秒で終わった（「0 129」、BT:266・5218）○。単体テストの段は待たずに始まり（状態のファイルは段の 0.6 秒目にあった）、5.7 分で終わった（同じ環境の版の D0 の 2 回目 17.3 分、D0 の 1 回目 25.2 分（20261119）、1.3 10.5 分）。ただし起動の間に macOS の段が遅れ、単体テストの終わりまでは長くなった（下の「時間」）。
- **写真の前の止めと起動**: 14:21:01 に Booted、14:21:05 に Shutdown（BT:9321-9322）。次の「Boot the simulator」の `simctl boot` は 14:21:07〜14:23:52 の 2 分 45 秒で、本当の冷えた起動。その後の「Device already booted, nothing to do.」（BT:9424-9425）は、待った起動の後の bootstatus の言葉で、起動を飛ばしたのではない ○。ja-baseline の起動は 4 分 40 秒（JA:3560-3561 まで）。
- **span-shots-app の見張り（L5）**: 見張りの止め 0（見張りのファイルも「watchdog:」の行も無い）。走らせ直し 0。4 つのテストのログで `kAXErrorIPC`・「Timed out while」・「Lost connection」が 0 ○。
- **手書きの確かめと撮り直し（L4 (f)）**:
  - build.yml の写真: 57 枚のうち 45 枚を確かめた（12 枚は基準の無いシート）。1 回目で足りなかったのは `ipad13-portrait-month.png` だけ（72,098 画素・287 区画、BT:9605）。2 回目で足り、それを残した（BT:9608）。
  - ja-baseline: 45 枚を確かめ、`iphone-portrait-readonly.png` だけ 1 回目で足りなかった（10,626 画素・44 区画、JA:4315）。2 回目を残した（JA:4318）。
  - l10n: 63 枚のうち 50 枚を確かめ、足りない 0（`zh-Hant/iphone-portrait-year` は「complete (18 px short)」）。
  - 残した写真は全部足りている ○。基準の無い ipad13 のシート 11 枚は、J-4 の役が自分の道具でメモの点とマーカーが両側にあることを見た（数も同じ）。
- **ログの読める度合い（L6）**:
  - **XCUITest が起動したアプリは読めるようになった**。span-shots-app の `<機種>-app-output.txt`（結果の束から書き出した物）にアプリの NSLog の行があり、compose failure は 0。`toolbar: paperArea=` と `span shot:` の数は 1.3 の `log show` と同じ。言語の写真の出力にも `l10n: ui=` が 60 行（起動 1 回に 1 行）。
  - **`simctl` で起動する写真（build-and-test・ja-baseline・l10n-shots）は今も読めない**。compose failure の警告が BT 5・JA 5・L10N 2。l10n は「holidays loaded」が 0 行で、37,114 行が compose failure（L10N:3844）。だから l10n-shots の「無い鍵」「訳していない字」の 2 つの数（0）は証拠にならない。BT の「The app's l10n lines」の段も同じ理由で空。
  - 代わりの証拠: 地図の役が l10n の 63 枚全部を 1.3 と画素で比べた（説明のつかない差 0）ことと、言語の写真のアプリの出力から読めた「アプリが見つけられなかった鍵 0」（SS:5261）。
- **警告**: `##[warning]` 28（BT 6・JA 6・SS 9・BP 1・L10N 4・CV 1・UI 1）、notice 2、error 1（UI の exit 65）。中身は、ログの読める度合い 18（compose failure 17 と「holidays loaded」が無い 1）、ずらしの組の 1 画素未満の差 3（1.3 と同じ）、Node.js 20 の終わりの知らせ 7（ジョブに 1 つ）。notice 2 つは撮り直し。
- この run の走らせ直しは、UI テストのジョブの 1 回（attempt 2）と、手書きの撮り直し 2 枚だけ。

### 時間（関門ではない）

| ジョブ | ジョブ / 上限（分） | 段 / 上限（分） |
| --- | --- | --- |
| build-and-test | 104.8 / 160 | 同期の繰り返し 3.9 / 14 |
| span-shots-app | 75.6 / 110 | 写真 51.5 / 80、言語 19.0 / 25 |
| blank-paper | 64.4 / 80 | 写真 61.9 / 70（余り 8 分） |
| ja-baseline | 66.3 / 130 | |
| l10n-shots | 46.4 / 75 | 写真 43.7 / 55 |
| UI テスト（1 回目） | 34.4 / 60 | テスト 32.1 / 40 |
| UI テスト（2 回目） | 35.8 / 60 | テスト 33.9 / 40 |
| compat-v1.0 | 10.2 / 45 | |

- 全部が上限の中。blank-paper の写真の段は余りが 8 分しかない。
- **前もっての起動の間、macOS の段がずっと遅かった**（同じ環境の版の D0 の 2 回目と比べて）: `swift --version` 5 分 18 秒（3.4 秒。BT:267-280）、Kit のビルド 15.1 分（0.8）、KitChecks 5.0 分（1.35）、Kit のテスト 5.2 分（1.1）、シミュレータ向けのビルド 2.9 分（0.95）。単体テストの終わりまで 35.1 分（22.0 分）。起動そのものは 129 秒で終わったのに、遅さは約 30 分続いた。`swift --version` の約 100 倍は 3 つの CPU を分け合うだけでは説明しにくい。仕組みは示していない。
- 調べ（役 T、批評で確かめた）: **D0b の前もっての起動は差し引きで損**。同じ環境（20261104）の D0 の 2 回目と比べ、`swift --version` 318 秒（3.4 秒）、`swift build` 498 秒（32 秒）、Build TegakiKit 15.1 分（0.8）、KitChecks 5.0 分（1.4）、Kit のテスト 5.2 分（1.1）。単体テストは 5.7 分（17.3）で速くなったが、ジョブは 104.8 分（79.4）。起動そのものは 129 秒で終わっていた。仕組みは示せていない（CPU の取り合いだけでは 100 倍の遅さは説明しにくい）。→ D0c で取りやめた（下）。

### 前の節の直し

- **手書きの欠けの読みを書き直す**（「D0b の調べの結果」の節の「写真の手書きの欠け」）。あの節は「欠けたのは macOS 27.2 の環境（20261119.0378.1）のジョブだけ」「同じ iOS が古い OS の実行機では全部描くので、使う人への影響は低い」と書いた。今回の run で次の 2 つが分かり、この読みは狭すぎた:
  1. **macOS 27.0.1 の環境（20261104.0337.1）でも、1 回目の撮りで 2 回欠けた**。build-and-test の `ipad13-portrait-month.png` は 72,098 画素・287 区画が足りず、欠けはページ全体に散っていた（BT:9605）。ja-baseline の `iphone-portrait-readonly.png` は 10,626 画素・44 区画（JA:4315）。どちらも、その機種で手書きを確かめた最初の写真（起動やインストールの後）。
  2. **1.3 の CI（Xcode 26.6、iOS 26.4）の写真にもあった**。run 44474759145 の `span-shots-app/ipadmini-portrait-week-boundary.png` は、状態の行が `pk=12;ink=12`（線は全部入っている）なのに、締切の下の波と 2 つの曲線が描かれていない。今回の同じ写真には描かれている。
  - **新しい読み**: 「線は入ったが描かれない」ことが、環境の版と Xcode の版をまたいで、たまに起きる。macOS 27.2 の環境で多い（D0b の調べ）が、それだけではない。1.3 の CI にもあったので、1.4 で新しく入った物とは限らない。
  - 写真の扱い: build.yml・ja-baseline・l10n の写真は、L4 (f) の確かめと撮り直しで捕まえる（今回の残りの欠けは 0）。**span-shots-app と UI テストの写真には自動の確かめが無い**。1 回目の写真が欠けていないことは、地図の役の比べ（1.3 より欠けた写真 0）で見た。UI テストの 2 回目（20261119）の写真は 13 枚が欠けていた（上の「UI テストの 2 回目の写真」）。
  - **使う人への影響は「低い」とは言わない**。本人の確かめ表の行 28（実機）で見て決める。
- **D0b の直しの節の commit の中身を足す**: 32e9617 は `PaperSpanTests` のほかに、`ExportBuilderTests.swift` の `stableBytes` にも同じ直し（`/ModDate` などの鍵と値の間の空白・改行を許す）を入れた。凍結の表の外。その 14 本は今回通った（BT:6804-6833）。
- **D0 の走らせ直しの節の打ち切りの行を直す**: attempt 2 の span-shots-app は「次の `iPad mini (A17 Pro)`（iOS 27.0）の起動の途中で切れた」と書いたが、起動は終わっていた。段の字は `simctl bootstatus -b` が通り 60 秒待ってから xcodebuild を `ipadmini-tests.log` に書かせる形で、そのログがあり、中身は xcodebuild の始めの 4 行（最後は「Resolve Package Graph」）だけ。ジョブのログは `ipadmini:` の行（01:22:23 UTC）から打ち切り（01:35:30）まで 13.1 分、何も出ていない。正しくは「iPad mini の起動の後、xcodebuild が「Resolve Package Graph」から先へ進まないまま切れた」。

### 順番の外れ（記録）

- 契約 §3.3 の順（build.yml が終わってから ja-baseline）を外れ、ja-baseline を build.yml の push の 5 秒後（13:41:55）に dispatch した。ジョブは待ちに入り、compat-v1.0 が終わって空いた枠で 14:26:37 に始まった。そのとき動いていた macOS のジョブは 5（build-and-test・span-shots・blank-paper・l10n・ja-baseline。上限ちょうど [S55]）。
- build.yml の 6 つのジョブはそのとき全部始まっていたので、ja-baseline のせいで待ったジョブは無い。順の理由は守れた: 同時は 5 まで、J-4 の 2 つは同じ環境の版（20261104.0337.1）、写真は両方とも 11/20 UTC。UI テストの実行機が止まったのは 13:52 で、ja-baseline が始まる前（別の VM でもある）。前の外れ（「D1 のアプリ側」の節の最後）と同じ扱い。

### リードの決定（es_MX の時刻の字、関門 7）

- 何: `span-shots-app-languages/es/iphone-portrait-settings-page.png` の「最後に同期」の時刻が、1.3 の「7/10/2026, 9:57 a.m.」から「7/10/2026, 9:57 am」になった。字が違うので、§3.6 の (b)(c) のどちらでもない。§3.6 の字のままなら止める差。
- 調べ: この字はアプリが自分で組まず、`DateText.numericDateTime` から `Date.FormatStyle(date: .numeric, time: .shortened, locale: es_MX)` で OS に作らせる（`TegakiKit/Sources/DayKit/DateText.swift:191`・`:254-264`）。言語の写真は es_MX で起動する（`SpanShotsUITests.swift:79`）。アプリと Kit のコードは 955fe67 と同じ。macOS 27.2.1 の Mac で同じ書式を小さな道具で作ると、es_MX は「7/10/2026, 9:57 am」（am の前は U+202F）、es_US は「a.m.」のまま。iOS・macOS 27 の地域のデータ（CLDR）の替わりと読む。表示だけで、関門 2・3 は同じ（§3.6 の (a)）。ほかの 9 言語の同じ行は替わらない。J-4 は日本語だけなので、この差を捕まえない。
- **リードの決定: 受ける**。地図の組 4 に新しい種類「(d) OS の地域の書式のデータの差」を足す。受けるのは、(a) が同じで、その字をアプリが OS の書式（`Date.FormatStyle` など）に任せていると示せたときだけ。
- 理由: 止める規則は、アプリが描く物の思わぬ悪化を捕まえるための物。これはアプリの悪化ではなく、OS がその地域の今の書き方を替えた物。アプリで「a.m.」に戻すと、その地域の OS のほかの画面の書き方から外れる。確認ページの前と後の候補に入れる。

### 実行機の打ち切り（続き）

- 速い道 `r14-q-d1b`（run 44690586694、ジョブ 136135154680、環境 20261119.0378.1）が、始まって 8 分（15:58:36）、「Build TegakiKit (macOS)」の最初の `swift --version` が 8.4 分たっても何も出さないまま（`swift build` はまだ始まっていない）、`##[error]The operation was canceled.` で切れた。理由は残っていない。`if: always()` の段はその後も走った。リードの側で取り消しは打っていない（記録を見た）。理由の無い打ち切りは今日これで 4 つ目（run 44632524223 の span-shots の 1 回目・2 回目、速い道 run 44659380308）。
- 調べ（役 X、批評で確かめた）: 理由の無い打ち切りは今日 4 回（D0 の span-shots の 1 回目と 2 回目、`r14-q-d1` の速い道 44659380308、`r14-q-d1b` の速い道 44690586694）。アカウントの打ち切り 118 のうち、理由の無いのはこの 4 つだけで、全部 `xcode-27`。共通点は「シミュレータの起動の後の数分か、固まった XCUITest の中」。始まってからの時間（8.6〜43.1 分）・段・同時のジョブの数（2〜3、5 の時は 0 回）は関係が無い。20261119 の環境に多い（6 ジョブ中 3、20261104 は 15 中 1。片側 p ≈ 0.05）。打ち切りの後も `always()` の段は走った。runner の不具合の報告（actions/runner #4820）と同じ見え方。**実行機の側の打ち切りと読む**（推定）。4 回目は `swift --version` が 8.4 分止まっていた間（前もっての起動の窓の中）。
- 扱い: 注が「The operation was canceled.」だけの打ち切りは基盤の打ち切りとして関門に数えず、そのジョブを 1 回走らせ直す。同じジョブで 2 回続けばその日は止めて環境の版を見る。手動・同時の取り消し・時間切れは今までどおり。前もっての起動はやめた（D0c）。打ち切りの時だけ診断の行（`uptime`・`memory_pressure`・`vm_stat`、runner の `_diag` の打ち切りの行だけ）を出す段を足す（公開のリポジトリなので全文は上げない。D1 の残り）。

### 残り

- 関門 1 はこの run では ×（UI テストが 2 回続けて落ちた）。2 つの失敗の読みは上の役 U2。通るかは次の run の UI テストで見る。
- 関門 7 は、es_MX（上の「リードの決定」）と、UI テストの 2 回目の `slide — after` の紙の位置（上の「UI テストの 2 回目の写真」）をリードが読んで決める。
- `ink_ref.tsv` の l10n の 11 行（「D0b の直し」の節の約束）は、この run の l10n の写真から作り直した（commit cbc0432、枝 `r14-w-d0c-ink`。まだ `r14` に入れていない）。確かめ: この run の 63 枚は 50 枚が足り 13 枚は基準無し、D0 の 1 回目の 11 枚の欠けは 11 枚とも捕まえる、1.3 の l10n も通る。
- span-shots-app と UI テストの写真には手書きの自動の確かめが無い（上の「前の節の直し」）。
- `simctl` で起動する写真のアプリのログは読めない。l10n の鍵の確かめは、画素の比べと言語の写真の数で代える（上の「D0b の確かめ」）。
- PDF のテストの直しの強さは run を重ねて見る。StoreKit の飛ばしが後の iOS でも続くかを見る（「D0b の直し」の節の L3）。

### D0c（11/20 16:50〜17:40。D0b の run の後の直し。枝 `r14-w-d0c-time` b36f8f6・`r14-w-d0c-ink` cbc0432、どちらも `r14-w-d1b` に入れた）

- **前もっての起動をやめた**（b36f8f6、build.yml だけ）: D0b の L5 の「13 インチの起動を macOS の段の間に始める」を取り下げる（上の「時間」）。xcodebuild が D0 までと同じく自分で起動する。「Shut down the 13-inch iPad before the photos」の段は残す（J-4 の写真はどちらでも起動し直しの iPad で撮る）。CI ではまだ走っていない。
- **手書きの基準の l10n の 11 行を作り直した**（cbc0432、`tools/shots/ink_ref.tsv`）: run 44676125566 の l10n の写真（Xcode 27.2・iOS 27.2 24B8117）から、置いてある道具で作った。この run の 63 枚（50 枚欠けなし、13 枚は基準なし）が通り、D0 の 1 回目の 11 枚の既知の欠けはそのまま捕まる（欠けの画素の数も同じ）。
- **§3.8 の読み方**: 「2 回続けば、その日は止める」はジョブごと。UI テストのジョブは 11/20（UTC）に止め、ほかのジョブと速い道は走らせてよい。
- **リードの決定（受ける）**: es_MX の時刻の字（上）。`slide — after` の紙の位置は、次の run の写真が 1.3 と同じに戻れば「遅い環境での指の入力の時間」と読む。戻らなければ止めて調べる（関門 7 はそれまで ?）。
- **D1 の残りに足す**: XCUITest の写真（ui-tests・span-shots-app）の手書きの確かめ（1.3 と比べ、警告だけ）。2 回目の UI テストの写真で 13 枚の手書きが欠け、テストは通った（確かめていないため）。打ち切りの時の診断の段。
