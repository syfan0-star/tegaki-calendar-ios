# てがきカレンダー（iPad アプリ版）

iPad の「カレンダー」に入っている予定（Google カレンダーを含む）の上に、Apple Pencil で手書きできる **iPad 用のアプリ** です。
Web 版（<https://github.com/syfan0-star/tegaki-calendar>）で確かめた使い勝手を、App Store で売れる本物のアプリとして作り直しています。

- Web 版の使い方・画面の考え方: [tegaki-calendar/README.md](https://github.com/syfan0-star/tegaki-calendar/blob/main/README.md)
- Web 版の設計書: [tegaki-calendar/docs/SPEC.md](https://github.com/syfan0-star/tegaki-calendar/blob/main/docs/SPEC.md)
- Web 版はこれからも、ご本人用・お試し用としてそのまま使えます。

## このリポジトリの文書

| 文書 | 内容 |
| --- | --- |
| [docs/DESIGN.md](docs/DESIGN.md) | 設計書。決まったこと、手書きを日付のマスに紐付ける仕組み、同期・課金、段階計画（M1〜M6）、本人の判断待ちリスト |
| [docs/M2_CONTRACT.md](docs/M2_CONTRACT.md) | M2 の実装契約（公開 API・データ形状・ファイル所有） |
| [docs/M2.md](docs/M2.md) | M2 の実装結果（作ったもの・確かめ方・本人が見るもの・既知の制限） |
| [docs/M3A_CONTRACT.md](docs/M3A_CONTRACT.md) | M3a の実装契約（週・日・年ページ、表示の切替、ページごとの手書き） |
| [docs/M3A.md](docs/M3A.md) | M3a の実装結果（作ったもの・確かめ方・本人が見るもの・既知の制限） |
| [docs/M3B_CONTRACT.md](docs/M3B_CONTRACT.md) | M3b の実装契約（予定の作成・編集・削除、予定ツール、投げなわ、設定画面、iPhone の見た目） |
| [docs/M3B.md](docs/M3B.md) | M3b の実装結果（作ったもの・確かめ方・本人が見るもの・既知の制限） |
| [docs/M4_CONTRACT.md](docs/M4_CONTRACT.md) | M4 の実装契約（iCloud 同期、Web 版からの手書きの引っ越し、CloudKit のスキーマ） |
| [docs/M4.md](docs/M4.md) | M4 の実装結果（作ったもの・確かめ方・本人がやること（CloudKit Console の手順）・本人が見るもの・既知の制限） |
| [docs/M4B_CONTRACT.md](docs/M4B_CONTRACT.md) | M4b の実装契約（iPhone・iPad mini・11 インチ・13 インチで読める紙にする: ページごとの最小倍率と横スクロール、固定の終日帯、手書きの移し替え、文字のクリップ、4 機種の CI） |
| [docs/M4B.md](docs/M4B.md) | M4b の実装結果（作ったもの・確かめ方・本人が見るもの（4 機種の写真の確認表）・既知の制限） |
| [docs/M4C_CONTRACT.md](docs/M4C_CONTRACT.md) | M4c の実装契約（一覧（fitAll）を基本の状態にしてピンチで拡大縮小、ピンチが効かなかった原因と直し F1〜F4、文字の比例縮小、倍率の記憶、指のダブルタップでその日へ） |
| [docs/M4C.md](docs/M4C.md) | M4c の実装結果（作ったもの・確かめ方・ピンチの診断（CI のログ）・本人が見るもの（写真の確認表）・既知の制限） |
| [docs/PRICING.md](docs/PRICING.md) | 価格の仮説（月 300 円・年 2,400 円・14 日間無料。数字は本人が決めます） |
| [docs/APPLE_ENROLLMENT.md](docs/APPLE_ENROLLMENT.md) | Apple Developer Program の登録手順（本人向け） |
| [docs/TERMS.md](docs/TERMS.md) ／ [docs/PRIVACY.md](docs/PRIVACY.md) ／ [docs/SUPPORT.md](docs/SUPPORT.md) | 利用規約・プライバシーポリシー・サポートページの下書き（公開前に専門家の確認を勧めます） |

## いま出来ていること（第 4 段階 M4c）

月・週・日・年の 4 ページに手書きし、予定を読み取って紙の上に並べ、紙の上から予定を作る・直す・消し、手書きをご本人の iCloud でほかの iPad や iPhone と同期し、Web 版の手書きを取り込み、iPhone・iPad mini・11 インチ・13 インチのどれでも、ページ全体が画面に入る「一覧」で開いてピンチで拡大縮小し、週・月・年の指のダブルタップでその日へ飛ぶところまでです（詳しくは [docs/M2.md](docs/M2.md)、[docs/M3A.md](docs/M3A.md)、[docs/M3B.md](docs/M3B.md)、[docs/M4.md](docs/M4.md)、[docs/M4B.md](docs/M4B.md)、[docs/M4C.md](docs/M4C.md)）。

| 機能 | 内容 |
| --- | --- |
| 4 つのページ | ヘッダー右の「日 \| 週 \| 月 \| 年」で切り替え（切り替えても見ている日は変わりません）。◀ ▶ で前後へ（日は 1 日、週は 7 日、月は 1 か月、年は 1 年）、「今日」で今日へ。月の日付の数字・年の曜日の字・週の日付見出しをタップするとその日の日ページへ、年の月名をタップするとその月の月ページへ。週・月・年では **指のダブルタップ** でその日の日ページへ（マス・列・終日帯の列。メモ欄・時刻帯・存在しない日では何も起きない。日ページでは何も起きない） |
| 月のページ | 月曜はじまり 6 行 × 7 列。今日に青い丸、土曜は青、日曜と祝日は赤（祝日名つき）、月外の日は薄く。グリッドの下にメモ欄 |
| 週のページ | 左に時刻帯、7 列の 24 時間の時間軸（1 時間 80 lu）。上に終日の帯（固定、書けない。タップで編集、空きをタップで追加）。紙は 0:00 から。時間指定の予定は色の箱（重なると列に分かれる、過ぎた予定は薄く）。今日の列に赤い現在時刻の線。一覧（基本の状態）では 0:00〜24:00 が全部入り、拡大して開くときは今日が見えていれば「今の 1 時間前」の位置から |
| 日のページ | 1 日の時間軸（1 時間 100 lu）と、右側のメモ欄（罫線）。上に終日の帯（固定、書けない。タップで編集、空きをタップで追加）。紙は 0:00 から |
| 年のページ | 12 列 × 31 行。土曜は薄い青、日曜・祝日は薄い赤、今日は青い枠。各マスの左上に曜日の字（祝日名つき）、右側に終日の予定のチップ（複数日は帯でつなぐ）。存在しない日（2/30 など）は斜線 |
| 予定を見る | iPad の「カレンダー」の予定を読み取り（フルアクセスの許可が必要）。月は終日の帯＋「● 9:00 題名」のチップ（1 日 3 件まで。4 件以上は 2 件＋「+n件」。タップでその日の日ページへ）。表示するカレンダーは設定画面で選べます |
| 予定を作る | ツールバーの「予定」で紙をなぞる（週・日は時間軸の範囲を 15 分に丸め、30 分未満は 1 時間。タップはその半時間から 1 時間。月・年はその日の終日）か、ヘッダーの「＋予定」（今日の 9:00〜10:00、月・年は今日の終日）。「予定を追加」のシートで、タイトル（Apple Pencil で書けば文字になります）・終日・開始と終了・登録先のカレンダー・場所・メモを入れて保存。iPad の「カレンダー」に登録されます |
| 予定を直す・消す | 帯・チップ・箱をタップ（指でも「予定」の道具でも）で「予定を編集」。繰り返しの予定は「この回だけ」か「以降すべて」を選びます。変更できないカレンダー（購読など）は閲覧だけ |
| 投げなわ | 手書きを囲んで選び、枠の中をドラッグで動かす（別の日のマスへ動かすとその日の手書きになります）、「削除」、「予定にする」（囲んだ手書きの画像が付いた作成シート。保存後にその手書きを消すかどうかは設定の初期値どおり）。どれも「元に戻す」が効きます |
| 伸びる紙 | 月の行と年の行は、予定が多いときと手書きがはみ出したときだけ伸びます（上限あり）。週・日の時間軸は伸びません。見えている場所が動かないようにスクロールも補正します |
| 手書き | Apple Pencil で書きます。ペン（6 色 × 細・中・太）、マーカー（4 色）、消しゴム（触れた線をまるごと消す）、元に戻す／やり直す。指はスクロール・ピンチ拡大・タップ用（「指でも書く」で指でも書けます）。手書きはページごと（月・週・日・年）に iPad の中へ保存され、最後に見ていたページで開き直します |
| 一覧とピンチ | どのページも、ページ全体（月は 6 行の格子、週は 24 時間、日と年は紙全体）が画面に入る **一覧** の倍率で開きます（iPad の月は幅ぴったりのまま）。ピンチで一覧（これより小さくはならない）〜幅ぴったりの 4 倍まで拡大縮小でき、一覧のままでも書けます。一覧では文字が比例して小さくなり（罫線は 1 pt のまま）、iPhone の一覧は地図のような縮図で、ピンチで拡大して読みます。指を離した倍率はページの種類（月・週・日・年）ごとに覚え、同じ種類の次のページも同じ倍率で開きます。向きを変えても一覧は一覧のまま、拡大中は手書きの大きさが変わりません。紙が画面より小さいときは机の色の余白の中央に寄せ、余白に書いた線は保存しません |
| iCloud 同期 | iPad で iCloud にサインインしていれば自動で、手書きがご本人の iCloud（CloudKit のプライベートデータベース）にも保存され、同じ Apple ID のほかの iPad や iPhone で同じ手書きが見えます。ヘッダー右の ☁ に状態（保存済み／同期中／オフライン／この iPad のみ／エラー／停止中。タップで設定画面）。書いてから約 3 秒で送り、相手の線はアプリを前面に戻したとき・ページを開いたとき・サイレントプッシュが届いたときに取り込みます。オフラインでも全部使え、回線が戻れば送ります。iPad の中のファイルが常に主で、iCloud は「ほかの端末へ届ける経路」と「バックアップ」。別の Apple ID にサインインし直したときは、残すか消すかを聞いてから使い始めます。開発者には手書きは見えません |
| Web 版からの取り込み | Web 版の設定で「手書きを書き出す（iPad アプリ用）」をすると、全ページ・全端末の手書きが 1 つの JSON ファイルになり、iPad の「ファイル」アプリに入ります。アプリの設定 › データ › 「Web 版の手書きを取り込む」でそのファイルを選ぶと、月・週・日・年の 4 ページに Web 版と同じ位置で入ります（線の id をそのまま使うので、同じファイルを二度取り込んでも二重になりません。Web 版で消した線は戻りません） |
| Apple Pencil のダブルタップ／スクイーズ | iPad の「設定 › Apple Pencil」で選んだ動作どおりにペン ⇄ 消しゴム |
| 初回案内 | カレンダーのアカウント → フルアクセスの説明 → ペンと指の使い分け → iCloud と手書きの保存、の 4 枚。最後のボタンで許可の画面が出ます（iCloud に許可の画面はありません） |
| 設定画面 | ヘッダーの ⚙ か ☁。表示するカレンダー（アカウントごと）、予定の登録先、カレンダーへのアクセス、Google カレンダーの使い方、指でも書く、予定にした手書きを消す、iCloud 同期の状態と「最後に同期」「今すぐ同期」、Web 版の手書きを取り込む、この iPad の手書きを全て消す（2 回確認。iCloud が使える状態なら iCloud の分も消え、ほかの端末からも消えます）、利用規約・プライバシーポリシー・サポート・バージョン。アプリからの書き出しと購入は「準備中」 |
| iPhone | ヘッダーが 2 段（切替は 2 段目。☁ は記号だけ）、ツールバーは横にスクロール、最初は週ページ、「指でも書く」は最初からオン。一覧ではページ全体が画面に入り（文字は 4〜7 pt の縮図）、拡大すると月・週・日は今日の列から、年は今月の列から横にスクロール。「指でも書く」がオンのときは 2 本指で動かす（ツールバーで切れる）。投げなわ・予定の道具を使っているときも 1 本指が道具、2 本指がスクロールとピンチ |
まだ無いもの（M5 以降）: 課金・閲覧専用モード、アプリからの手書きの書き出し（JSON・PDF・画像）、設定（表示するカレンダーなど）の同期。これらは[設計書の段階計画](docs/DESIGN.md#9-段階計画)の順に足していきます。

## 仕組み（Web 版との違い）

| | Web 版 | iPad アプリ版 |
| --- | --- | --- |
| 予定の読み書き | Google カレンダー API（Google へのログインが必要） | iPad の「カレンダー」経由（EventKit）。iPad の設定で Google アカウントを追加しておけば、その予定がそのまま見えます。Google へのログイン画面は出ません |
| 手書きの保存 | Google ドライブ（1 ページ × 1 端末 = 1 ファイル） | iPad の中（Application Support。JSON を LZFSE で圧縮）が主で、ご本人の iCloud（CloudKit のプライベートデータベース。1 ページ = 1 レコード、衝突は「和集合＋墓標」で merge）にも保存。Google へのログインは要りません |
| 手書きの描画 | ブラウザの Canvas | iPad 標準の PencilKit（遅れの少ない描画、Apple Pencil のホバーにも対応） |
| ペン ⇄ 消しゴムの切り替え | 2 本指でページを叩く | Apple Pencil のダブルタップ／スクイーズ（iPad の設定どおり） |

予定を読むには、iOS の決まりで「カレンダーへのフルアクセス」の許可が必要です（読み取りだけの許可は iOS にありません）。許可の画面に出る文は [docs/PRIVACY.md 付録 B](docs/PRIVACY.md) と同じです。

## ビルドの仕組み（GitHub Actions）

このリポジトリは **手元の Mac に Xcode が無くてもビルドできる** ようにしてあります。

- `git push` するたびに、GitHub の macOS マシン（`macos-26`、Xcode 26.6）が自動で次をします（[.github/workflows/build.yml](.github/workflows/build.yml)）。
  1. 純粋な部分（`TegakiKit`）を macOS 上でビルド → `KitChecks`（22900 項目の検査。22850 以上であることを数字で確かめる）→ `swift test`
  2. `brew install xcodegen` → `xcodegen generate` で Xcode プロジェクト（`TegakiCalendar.xcodeproj`）を作る
  3. iOS シミュレータ向けにビルド（署名なし）
  4. 13 インチ iPad のシミュレータでアプリのユニットテスト（PencilKit の台帳と選択の操作・手書きの画像・予定シートの状態・予定の書き込み・スクリーンショットモード・同期エンジン（メモリ上の偽の iCloud に対して。iCloud アカウントは不要）・レコードの写像・CloudKit の誤りの写像・状態ファイル・紙の文字のクリップと窓・キャンバスの viewport の通知・一覧の倍率とピンチの終端の経路・ダブルタップの認識器・保存比率・スクリーンショットの倍率の引数）を実行
  5. 同じ 13 インチのシミュレータでアプリをスクリーンショットモードで 13 回起動し（月・週・日・年の 4 ページ（一覧）、月・週・年を 2 倍に拡大した 3 枚、月ページで「予定を追加」「予定を編集」「投げなわの選択」「設定」「同期（設定の「同期」の節）」「Web 版の取り込みの結果」の 6 つのシート）、続けて iPhone 17・iPad mini・11 インチ iPad を 1 台ずつ起動して 4 ページずつ（iPhone はさらに今日が日曜の週・6/1 の週・週を 3 倍に拡大した 1 枚ずつと横向き 4 枚）、画面を撮って成果物 `screenshots`（7 日保存）に置く。13 インチ 13 枚 + iPad mini 4 枚 + 11 インチ 4 枚 + iPhone 縦 7 枚 + iPhone 横 4 枚 = 32 枚。アプリのログ（4 本）には倍率の診断行（`zoom:`）が残る
- 結果は GitHub の「Actions」タブで見られます。緑のチェックなら成功です。成果物の 32 枚の画像（4 機種）で、Xcode が無くても画面を確かめられます。CI のシミュレータは iCloud に触りません（署名なしのビルドで entitlements は埋め込まれず、スクリーンショットモードとテストは偽の iCloud を使います）。
- [.github/workflows/testflight.yml](.github/workflows/testflight.yml) は **手動実行** で、署名付きでビルドして TestFlight へ送ります。Apple Developer Program の承認後に 7 つの Secrets（証明書・プロファイル・App Store Connect の API キー）を登録すると使えます。未設定のまま実行すると、何が足りないかを日本語で表示して止まります。M4 からは App ID に iCloud（CloudKit）と Push Notifications を付けたプロファイルが必要です（[docs/M4.md §2.3](docs/M4.md)）。
- 成果物（ビルドしたアプリ）は保存していません。

## 手元の Mac で確かめる（Xcode が無くても）

Command Line Tools の `swift` だけで、純粋な部分の検査が通ります。

```bash
cd TegakiKit
swift build            # DayKit / Holidays / Layout / InkModel / KitChecks をビルド
swift run KitChecks    # 「KitChecks: all 22900 checks passed」と出れば OK
```

アプリ側（UIKit / PencilKit / EventKit / CloudKit）は Xcode でしかコンパイルできないので、構文だけ確かめます。

```bash
for f in $(find Sources Tests -name '*.swift'); do swiftc -parse -swift-version 5 "$f"; done
```

XCTest も Command Line Tools には無いため、`swift test` とシミュレータのテストは GitHub Actions でだけ走ります。

## 手元の Mac で開く場合（Xcode がある人向け）

`.xcodeproj` と `Support/Info.plist` はリポジトリに入れていません（どちらも `xcodegen generate` が毎回作ります）。

```bash
brew install xcodegen      # 初回だけ。Homebrew が無ければ XcodeGen の GitHub リリースの zip を展開して ~/.local/bin に置いても動きます
xcodegen generate          # TegakiCalendar.xcodeproj と Support/Info.plist が出来る
open TegakiCalendar.xcodeproj
```

Xcode で「TegakiCalendar」スキームを選び、iPad シミュレータか実機で実行します。実機で動かすときは、Signing & Capabilities で自分の Team を選んでください（`project.yml` の `DEVELOPMENT_TEAM` に書いておくこともできます）。

コマンドラインだけで試す場合（シミュレータの名前は `xcrun simctl list devices available` で確認）:

```bash
swift test --package-path TegakiKit
xcodebuild -project TegakiCalendar.xcodeproj -scheme TegakiCalendar \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5)" test
```

## フォルダの中身

```
project.yml                         XcodeGen の設定（アプリ名・Bundle ID・Info.plist の内容・entitlements・TegakiKit への依存・テスト）
Support/Info.plist                  xcodegen generate が作る（git には入れない。手では編集しない）
Support/TegakiCalendar.entitlements iCloud（CloudKit、コンテナ iCloud.com.syfan0.tegakicalendar）とサイレントプッシュ（aps-environment）
TegakiKit/                          ローカル Swift パッケージ（Foundation だけ。Xcode 無しの Mac でもビルド・検査できる）
  Package.swift
  Sources/DayKit/DayKey.swift       「年・月・日」だけの日付（時差に左右されない計算用）と YearMonth
  Sources/Holidays/JapaneseHolidays.swift  日本の祝日（2000〜2099 年、Web 版と同じ規則）
  Sources/Layout/                   紙の寸法・マスの鍵・予定の正規化形・4 ページの配置（PageLayout、月・週・日・年の engine、時間指定の重なり処理、レーンの間引き、ページの id と移動と初期位置、矩形 ⇄ 予定の範囲 EventRange）、ページごとの一覧の倍率・上限・保存比率と見えている範囲（ZoomPolicy / PaperViewport）、ダブルタップの点から日を引く dayAt、週・日の固定の終日帯（AllDayBand）
  Sources/InkModel/                 手書きの台帳（InkPage / InkStroke、merge、JSON、LZFSE）、投げなわの数学（LassoGeometry）、Web 版の書き出しの解析と変換（WebImport）、同期の状態ファイルの型（SyncState）と再試行の間隔（SyncBackoff）、週・日の帯の手書きの移し替え（BandMigration）
  Sources/KitChecks/main.swift      Xcode 無しの Mac で走る検査（swift run KitChecks）
  Tests/                            LayoutTests / HolidaysTests / InkModelTests（swift test。CI で実行）
Sources/TegakiCalendar/
  App.swift                         アプリの入口（AppDelegate を付ける）
  ContentView.swift                 CalendarRootScreen を出すだけ
  PrivacyInfo.xcprivacy             プライバシーマニフェスト（追跡なし・収集なし、UserDefaults の理由 CA92.1）
  Views/CalendarRootScreen.swift    唯一の画面（表示と日付の状態、ヘッダー・固定見出し・キャンバス・投げなわのメニュー・ツールバー・トースト・シート・初回案内・ページごとの保存、予定の作成・編集・削除の流れ）
  Views/PageHeaderView.swift        ◀ 今日 ▶・題名・日/週/月/年 の切替・＋予定・⚙（幅 600 pt 未満は 2 段）
  Views/StickyHeaderView.swift      紙の上に固定する見出し（月の曜日行・週の日付見出し・日の日付・年の月名。紙の横スクロールと倍率に追随）
  Views/AllDayBandView.swift        週・日の固定の終日帯（紙の外、書けない。バーをタップで編集、列の空きをタップで作成）
  Views/OnboardingView.swift        初回案内 4 枚
  Views/ToolbarView.swift           ペン・マーカー・消しゴム・投げなわ・予定・元に戻す／やり直す・指でも書く
  Views/EventEditorSheet.swift      予定の作成・編集・閲覧のシート
  Views/EventEditorForm.swift       シートの純粋な状態（終日 ⇄ 時間指定、開始を動かすと長さを保つ、検証）
  Views/RecurrenceScopeDialog.swift 繰り返しの予定の「この回だけ／以降すべて」
  Views/SelectionMenuView.swift     投げなわの「予定にする／削除／選択解除」と置き場所の計算
  Views/SettingsScreen.swift        設定画面（同期・データの節を含む）
  Views/WebImportSheet.swift        Web 版の手書きの取り込み（ファイル選択、進捗、結果）
  Views/AccountChangeDialog.swift   「別の iCloud アカウントです」の問い合わせ
  Views/ToastView.swift             画面下のトースト
  Views/EventDateText.swift         日時の日本語表記
  Paper/PaperView.swift             紙ビュー本体（見えている範囲の周りだけを持つ窓）、PaperContent（月・週・日・年）、色の表
  Paper/PaperText.swift             文字の大きさ・ヘアライン・文字描画の共通部品（枠で切る、時刻ラベルの上限）
  Paper/MonthPaper.swift            月ページの紙（罫線・日付・祝日・帯・チップ・メモ欄）
  Paper/TimeGridPaper.swift         週・日で共用する時間軸・時間指定の箱・現在時刻の線
  Paper/WeekPaper.swift / DayPaper.swift / YearPaper.swift   各ページの紙
  Ink/InkCanvasView.swift           PencilKit のキャンバス＋紙ビュー（スクロール・一覧の倍率と上限・中央寄せ・ピンチ中の引き伸ばしと終端の経路・倍率の記憶と報告・指のダブルタップ・余白の線の破棄・初期スクロール・伸び縮みの反映・見えている範囲の通知）
  Ink/InkLedger.swift               台帳 ⇄ PKDrawing の変換、指紋、合成し直し、履歴、選択の削除・移動（どのページでも同じ）、読込時の帯の線の移し替え
  Ink/InkOverlayView.swift          投げなわ・移動・予定ツールの入力と描画（PencilKit の上に重ねる。Pencil は hitTest で、指は容器の認識器 InkFingerGestureRecognizer から受ける）
  Ink/InkSnapshot.swift             選んだ手書きの画像（作成シートの「書いた内容」、移動中の絵）
  Ink/InkTools.swift                道具（色・太さ・投げなわ・予定）と PencilKit の道具への変換
  Ink/PencilInteraction.swift       Apple Pencil のダブルタップ／スクイーズ
  Calendar/EventKitService.swift    iPad のカレンダーの予定を読む・作る・直す・消す（許可・任意の日付範囲の取得・正規化・EKSpan）
  Calendar/EventStoreModel.swift    画面用の予定モデル（許可状態・ページの予定・カレンダーの選択肢と登録先・書き込み・変更の購読）
  Calendar/EventDraft.swift         シートが扱う予定の内容、書き込みの失敗の文言、カレンダーの写し
  Persistence/AppSettings.swift     UserDefaults の鍵と既定値（ページの種類ごとの表示倍率の比率を含む）
  Persistence/InkPageStore.swift    手書きの保存（Application Support/TegakiCalendar/ink/<pageId>.json.lzfse）と全消去、ページの一覧
  Persistence/SyncStateStore.swift  同期の状態ファイル（ink/state.json）の原子的な読み書き
  Sync/CloudDatabase.swift          CloudKit を隠すプロトコルと値の型（CloudKit を import しない）
  Sync/CloudKitDatabase.swift       本物の CKDatabase の adapter（CloudKit を import する唯一のファイル。CKError の写像、変更トークン、Asset）
  Sync/InMemoryCloudDatabase.swift  メモリ上の偽の iCloud（テスト・スクリーンショットモード・XCTest のホスト用）
  Sync/InkPageRecord.swift          InkPage ⇄ レコード、Meta レコード
  Sync/SyncStatus.swift             同期の状態の型と、ヘッダー・設定画面の文言
  Sync/SyncEngine.swift             同期エンジン（dirty の帳簿、1.5 秒デバウンス、差分取得、衝突の merge、再試行、全消去、取り込み、アカウントの切替）
  Support/ScreenshotMode.swift      CI のスクリーンショットモード（見本の予定と手書き、--screenshot-page、--screenshot-sheet、--screenshot-landscape、--screenshot-zoom、--screenshot-offset）
  Support/AppDelegate.swift         サイレントプッシュの登録と受け口、同期エンジンの開始
Tests/TegakiCalendarTests/
  InkLedgerTests.swift              PencilKit の台帳のテスト（指紋・墓標・戻す・合成し直し・週日年のマス割り当て・選択の削除と移動・帯の線の移し替え）。シミュレータで実行
  PaperTextTests.swift              文字のクリップと時刻ラベルの上限のテスト
  PaperViewTests.swift              紙の窓（見えている範囲の周り 2 × 2 画面）の計算のテスト
  InkCanvasViewTests.swift          キャンバスのテスト（一覧の倍率と中央寄せ、ピンチの終端の経路と比率の報告、回転・高さ・行の伸びでの倍率、ダブルタップの認識器、余白の線の破棄、viewport の通知）
  InkSnapshotTests.swift            選んだ手書きの画像のテスト
  EventEditorFormTests.swift        予定シートの状態のテスト
  EventKitServiceTests.swift        終日の予定の正規化・色の変換・予定の書き込み（apply）のテスト
  ScreenshotModeTests.swift         スクリーンショットモードの起動引数と見本のテスト
  AppSettingsTests.swift            表示倍率の比率の保存のテスト
  CalendarRootScreenTests.swift     紙の領域の高さ（帯を引く）のテスト
  SyncEngineTests.swift             同期エンジンのテスト（偽の iCloud と TestSleeper で。アカウント確認・デバウンス・衝突・取得・削除・再試行・ゾーン消失・プッシュ・アカウント切替・全消去・取り込み）
  InkPageRecordTests.swift          レコードの写像のテスト
  SyncStateStoreTests.swift         状態ファイルの読み書きのテスト
  CloudKitDatabaseMapTests.swift    CKError → CloudError の写像のテスト
  TestSleeper.swift                 テスト用の sleep
.github/workflows/build.yml         GitHub Actions の設定（push ごと）
.github/workflows/testflight.yml    TestFlight への配信（手動実行。Secrets が必要）
docs/                               設計書・契約・実装結果・価格・登録手順・規約類（上の表）
```

## 対応機種・条件

- アプリ名: **てがきカレンダー**（Bundle ID: `com.syfan0.tegakicalendar`）
- iPadOS / iOS 17 以降。iPhone・iPad mini・11 インチ・13 インチの iPad のどれでも読める大きさで出します（主役は iPad と Apple Pencil です）
- 縦向き・横向きのどちらでも使えます
- iCloud 同期は、iPad で iCloud にサインインしていれば自動で使われます（サインインしていなければ iPad の中だけに保存。アプリ側の設定は要りません）
- 配信は日本を中心に、EU を除く予定です（理由は [docs/APPLE_ENROLLMENT.md 4-5](docs/APPLE_ENROLLMENT.md)）
