# 手書きカレンダー（iPad アプリ版）

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
| [docs/PRICING.md](docs/PRICING.md) | 価格の仮説（月 300 円・年 2,400 円・14 日間無料。数字は本人が決めます） |
| [docs/APPLE_ENROLLMENT.md](docs/APPLE_ENROLLMENT.md) | Apple Developer Program の登録手順（本人向け） |
| [docs/TERMS.md](docs/TERMS.md) ／ [docs/PRIVACY.md](docs/PRIVACY.md) ／ [docs/SUPPORT.md](docs/SUPPORT.md) | 利用規約・プライバシーポリシー・サポートページの下書き（公開前に専門家の確認を勧めます） |

## いま出来ていること（第 3 段階前半 M3a）

月・週・日・年の 4 ページに手書きし、予定を読み取って紙の上に並べるところまでです（詳しくは [docs/M2.md](docs/M2.md) と [docs/M3A.md](docs/M3A.md)）。

| 機能 | 内容 |
| --- | --- |
| 4 つのページ | ヘッダー右の「日 \| 週 \| 月 \| 年」で切り替え（切り替えても見ている日は変わりません）。◀ ▶ で前後へ（日は 1 日、週は 7 日、月は 1 か月、年は 1 年）、「今日」で今日へ。月の日付の数字・年の曜日の字・週の日付見出しをタップするとその日の日ページへ、年の月名をタップするとその月の月ページへ |
| 月のページ | 月曜はじまり 6 行 × 7 列。今日に青い丸、土曜は青、日曜と祝日は赤（祝日名つき）、月外の日は薄く。グリッドの下にメモ欄 |
| 週のページ | 左に時刻帯、7 列の 24 時間の時間軸（1 時間 80 lu）。上に終日の帯。時間指定の予定は色の箱（重なると列に分かれる、過ぎた予定は薄く）。今日の列に赤い現在時刻の線。今日が見えていれば「今の 1 時間前」の位置で開きます |
| 日のページ | 1 日の時間軸（1 時間 100 lu）と、右側のメモ欄（罫線）。上に終日のチップ |
| 年のページ | 12 列 × 31 行。土曜は薄い青、日曜・祝日は薄い赤、今日は青い枠。各マスの左上に曜日の字（祝日名つき）、右側に終日の予定のチップ（複数日は帯でつなぐ）。存在しない日（2/30 など）は斜線 |
| 予定 | iPad の「カレンダー」の予定を読み取り（フルアクセスの許可が必要）。月は終日の帯＋「● 9:00 題名」のチップ（1 日 3 件まで。4 件以上は 2 件＋「+n件」。タップでその日の日ページへ）。タップで内容を表示（閲覧のみ）。表示するカレンダーはヘッダーのメニューで選べます |
| 伸びる紙 | 月の行、週・日の終日帯、年の行は、予定が多いときと手書きがはみ出したときだけ伸びます（上限あり）。週・日の時間軸は伸びません。見えている場所が動かないようにスクロールも補正します |
| 手書き | Apple Pencil で書きます。ペン（6 色 × 細・中・太）、マーカー（4 色）、消しゴム（触れた線をまるごと消す）、元に戻す／やり直す。指はスクロール・ピンチ拡大・タップ用（「指でも書く」で指でも書けます）。手書きはページごと（月・週・日・年）に iPad の中へ保存され、最後に見ていたページで開き直します |
| Apple Pencil のダブルタップ／スクイーズ | iPad の「設定 › Apple Pencil」で選んだ動作どおりにペン ⇄ 消しゴム |
| 初回案内 | カレンダーのアカウント → フルアクセスの説明 → ペンと指の使い分け、の 3 枚。最後のボタンで許可の画面が出ます |

まだ無いもの（M3b 以降）: 予定の作成・編集・削除、予定ツール、投げなわ、「予定にする」、設定画面、iPhone 向けの見た目、iCloud 同期、課金、Web 版からの手書きの引っ越し。これらは[設計書の段階計画](docs/DESIGN.md#9-段階計画)の順に足していきます。

## 仕組み（Web 版との違い）

| | Web 版 | iPad アプリ版 |
| --- | --- | --- |
| 予定の読み書き | Google カレンダー API（Google へのログインが必要） | iPad の「カレンダー」経由（EventKit）。iPad の設定で Google アカウントを追加しておけば、その予定がそのまま見えます。Google へのログイン画面は出ません |
| 手書きの保存 | Google ドライブ | iPad の中（Application Support。JSON を LZFSE で圧縮）。（予定）ご本人の iCloud（CloudKit） |
| 手書きの描画 | ブラウザの Canvas | iPad 標準の PencilKit（遅れの少ない描画、Apple Pencil のホバーにも対応） |
| ペン ⇄ 消しゴムの切り替え | 2 本指でページを叩く | Apple Pencil のダブルタップ／スクイーズ（iPad の設定どおり） |

予定を読むには、iOS の決まりで「カレンダーへのフルアクセス」の許可が必要です（読み取りだけの許可は iOS にありません）。許可の画面に出る文は [docs/PRIVACY.md 付録 B](docs/PRIVACY.md) と同じです。

## ビルドの仕組み（GitHub Actions）

このリポジトリは **手元の Mac に Xcode が無くてもビルドできる** ようにしてあります。

- `git push` するたびに、GitHub の macOS マシン（`macos-26`、Xcode 26.6）が自動で次をします（[.github/workflows/build.yml](.github/workflows/build.yml)）。
  1. 純粋な部分（`TegakiKit`）を macOS 上でビルド → `KitChecks`（724 項目の検査）→ `swift test`
  2. `brew install xcodegen` → `xcodegen generate` で Xcode プロジェクト（`TegakiCalendar.xcodeproj`）を作る
  3. iOS シミュレータ向けにビルド（署名なし）
  4. iPad のシミュレータ（無ければ iPhone）でアプリのユニットテスト（PencilKit の台帳・予定の正規化・スクリーンショットモード）を実行
  5. 同じシミュレータでアプリをスクリーンショットモードで 4 回起動し（月・週・日・年）、画面を撮って成果物 `screenshots`（7 日保存）に置く
- 結果は GitHub の「Actions」タブで見られます。緑のチェックなら成功です。成果物の 4 枚の画像で、Xcode が無くても画面を確かめられます。
- [.github/workflows/testflight.yml](.github/workflows/testflight.yml) は **手動実行** で、署名付きでビルドして TestFlight へ送ります。Apple Developer Program の承認後に 7 つの Secrets（証明書・プロファイル・App Store Connect の API キー）を登録すると使えます。未設定のまま実行すると、何が足りないかを日本語で表示して止まります。
- 成果物（ビルドしたアプリ）は保存していません。

## 手元の Mac で確かめる（Xcode が無くても）

Command Line Tools の `swift` だけで、純粋な部分の検査が通ります。

```bash
cd TegakiKit
swift build            # DayKit / Holidays / Layout / InkModel / KitChecks をビルド
swift run KitChecks    # 「KitChecks: all 724 checks passed」と出れば OK
```

アプリ側（UIKit / PencilKit / EventKit）は Xcode でしかコンパイルできないので、構文だけ確かめます。

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
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M4)" test
```

## フォルダの中身

```
project.yml                         XcodeGen の設定（アプリ名・Bundle ID・Info.plist の内容・TegakiKit への依存・テスト）
Support/Info.plist                  xcodegen generate が作る（git には入れない。手では編集しない）
TegakiKit/                          ローカル Swift パッケージ（Foundation だけ。Xcode 無しの Mac でもビルド・検査できる）
  Package.swift
  Sources/DayKit/DayKey.swift       「年・月・日」だけの日付（時差に左右されない計算用）と YearMonth
  Sources/Holidays/JapaneseHolidays.swift  日本の祝日（2000〜2099 年、Web 版と同じ規則）
  Sources/Layout/                   紙の寸法・マスの鍵・予定の正規化形・4 ページの配置（PageLayout、月・週・日・年の engine、時間指定の重なり処理、レーンの間引き、ページの id と移動）
  Sources/InkModel/                 手書きの台帳（InkPage / InkStroke、merge、JSON、LZFSE）
  Sources/KitChecks/main.swift      Xcode 無しの Mac で走る検査（swift run KitChecks）
  Tests/                            LayoutTests / HolidaysTests / InkModelTests（swift test。CI で実行）
Sources/TegakiCalendar/
  App.swift                         アプリの入口
  ContentView.swift                 CalendarRootScreen を出すだけ
  Views/CalendarRootScreen.swift    唯一の画面（表示と日付の状態、ヘッダー・固定見出し・キャンバス・ツールバー・シート・初回案内・ページごとの保存）
  Views/PageHeaderView.swift        ◀ 今日 ▶・題名・日/週/月/年 の切替・カレンダーのメニュー
  Views/StickyHeaderView.swift      紙の上に固定する見出し（月の曜日行・週の日付見出し・日の日付・年の月名）
  Views/OnboardingView.swift        初回案内 3 枚
  Views/ToolbarView.swift           ペン・マーカー・消しゴム・元に戻す／やり直す・指でも書く
  Views/EventDetailSheet.swift      予定の内容（閲覧のみ）
  Paper/PaperView.swift             紙ビュー本体、PaperContent（月・週・日・年）、色の表
  Paper/PaperText.swift             文字の大きさ・ヘアライン・文字描画の共通部品
  Paper/MonthPaper.swift            月ページの紙（罫線・日付・祝日・帯・チップ・メモ欄）
  Paper/TimeGridPaper.swift         週・日で共用する時間軸・終日帯・時間指定の箱・現在時刻の線
  Paper/WeekPaper.swift / DayPaper.swift / YearPaper.swift   各ページの紙
  Ink/InkCanvasView.swift           PencilKit のキャンバス＋紙ビュー（スクロール・拡大・初期スクロール・伸び縮みの反映）
  Ink/InkLedger.swift               台帳 ⇄ PKDrawing の変換、指紋、合成し直し、履歴（どのページでも同じ）
  Ink/InkTools.swift                道具（色・太さ）と PencilKit の道具への変換
  Ink/PencilInteraction.swift       Apple Pencil のダブルタップ／スクイーズ
  Calendar/EventKitService.swift    iPad のカレンダーから予定を読む（許可・任意の日付範囲の取得・正規化）
  Calendar/EventStoreModel.swift    画面用の予定モデル（許可状態・ページの予定・表示するカレンダー・変更の購読）
  Persistence/InkPageStore.swift    手書きの保存（Application Support/TegakiCalendar/ink/<pageId>.json.lzfse）
  Support/ScreenshotMode.swift      CI のスクリーンショットモード（見本の予定と手書き、--screenshot-page）
Tests/TegakiCalendarTests/
  InkLedgerTests.swift              PencilKit の台帳のテスト（指紋・墓標・戻す・合成し直し・週日年のマス割り当て）。シミュレータで実行
  EventKitServiceTests.swift        終日の予定の正規化・色の変換のテスト
  ScreenshotModeTests.swift         スクリーンショットモードの起動引数と見本のテスト
.github/workflows/build.yml         GitHub Actions の設定（push ごと）
.github/workflows/testflight.yml    TestFlight への配信（手動実行。Secrets が必要）
docs/                               設計書・契約・実装結果・価格・登録手順・規約類（上の表）
```

## 対応機種・条件

- アプリ名: **手書きカレンダー**（Bundle ID: `com.syfan0.tegakicalendar`）
- iPadOS / iOS 17 以降（iPhone でも動きますが、主役は iPad と Apple Pencil です）
- 縦向き・横向きのどちらでも使えます
- 配信は日本を中心に、EU を除く予定です（理由は [docs/APPLE_ENROLLMENT.md 4-5](docs/APPLE_ENROLLMENT.md)）
