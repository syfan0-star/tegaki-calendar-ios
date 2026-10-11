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
| [docs/PRICING.md](docs/PRICING.md) | 価格の仮説（月 300 円・年 2,400 円・14 日間無料。数字は本人が決めます） |
| [docs/APPLE_ENROLLMENT.md](docs/APPLE_ENROLLMENT.md) | Apple Developer Program の登録手順（本人向け） |
| [docs/TERMS.md](docs/TERMS.md) ／ [docs/PRIVACY.md](docs/PRIVACY.md) ／ [docs/SUPPORT.md](docs/SUPPORT.md) | 利用規約・プライバシーポリシー・サポートページの下書き（公開前に専門家の確認を勧めます） |

## いま出来ていること（第 1 段階 M1）

まずは「ビルドが通る土台」です。画面はひとつだけで、次が見られます。

| 機能 | 内容 |
| --- | --- |
| 月のページ | 今月のカレンダー（月曜はじまり・7 列・曜日は日本語・今日に印・日曜と祝日は赤、土曜は青、祝日名つき）。‹ › で前後の月へ、「今月」で戻ります |
| 手書き | カレンダーの上に Apple Pencil で書けます。ペン（紺）・マーカー（黄）・消しゴム（触れた線をまるごと消す。Web 版と同じ）。「消す」で全部消去。初期設定では指は書きません（指はスクロールやタップ用）。「指でも書く」を押すと指でも書けます（iPhone では最初からオン） |
| Apple Pencil のダブルタップ | iPad の「設定 › Apple Pencil」で選んだ動作（ペン ⇄ 消しゴム など）どおりに切り替わります。Apple Pencil Pro のスクイーズも同じです |
| 予定の一覧 | 「予定を読み込む」を押して許可すると、この月の予定が下に並びます（終日の予定が先）。許可しなかったときは「設定を開く」で許可の画面へ行けます |

まだ無いもの: 色と太さの選択、手書きの保存と iCloud 同期、日・週・年のページ、投げなわ、「予定にする」、行の高さが予定に合わせて伸びる表示、課金、Web 版からの手書きの引っ越し。これらは[設計書の段階計画](docs/DESIGN.md#9-段階計画)の順に足していきます。

## 仕組み（Web 版との違い）

| | Web 版 | iPad アプリ版 |
| --- | --- | --- |
| 予定の読み書き | Google カレンダー API（Google へのログインが必要） | iPad の「カレンダー」経由（EventKit）。iPad の設定で Google アカウントを追加しておけば、その予定がそのまま見えます。Google へのログイン画面は出ません |
| 手書きの保存 | Google ドライブ | （予定）ご本人の iCloud（CloudKit） |
| 手書きの描画 | ブラウザの Canvas | iPad 標準の PencilKit（遅れの少ない描画、Apple Pencil のホバーにも対応） |
| ペン ⇄ 消しゴムの切り替え | 2 本指でページを叩く | Apple Pencil のダブルタップ／スクイーズ（iPad の設定どおり） |

予定を読むには、iOS の決まりで「カレンダーへのフルアクセス」の許可が必要です（読み取りだけの許可は iOS にありません）。許可の画面に出る文は [docs/PRIVACY.md 付録 B](docs/PRIVACY.md) と同じです。

## ビルドの仕組み（GitHub Actions）

このリポジトリは **手元の Mac に Xcode が無くてもビルドできる** ようにしてあります。

- `git push` するたびに、GitHub の macOS マシン（`macos-26`、Xcode 26.6）が自動で次をします。
  1. `brew install xcodegen` → `xcodegen generate` で Xcode プロジェクト（`TegakiCalendar.xcodeproj`）を作る
  2. iOS シミュレータ向けにビルド（署名なし）
  3. iPad のシミュレータ（無ければ iPhone）でユニットテストを実行（祝日の計算・月の並び）
- 結果は GitHub の「Actions」タブで見られます。緑のチェックなら成功です。
- 設定ファイルは [.github/workflows/build.yml](.github/workflows/build.yml) です。成果物（ビルドしたアプリ）はまだ保存していません。TestFlight への配信は Apple Developer Program の登録後に足します（`testflight.yml`）。
- 初回は XcodeGen の導入を含めて 10〜15 分ほどかかる見込みです。

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
xcodebuild -project TegakiCalendar.xcodeproj -scheme TegakiCalendar \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M4)" test
```

## フォルダの中身

```
project.yml                         XcodeGen の設定（アプリ名・Bundle ID・Info.plist の内容・テスト）
Support/Info.plist                  xcodegen generate が作る（git には入れない。手では編集しない）
Sources/TegakiCalendar/
  App.swift                         アプリの入口
  ContentView.swift                 M1 の画面（月のページ＋手書き＋予定一覧）
  Views/MonthGridView.swift         月のマス目（月曜はじまり・祝日名・今日の印）
  Views/EventListView.swift         予定の一覧と、許可を求める案内
  Ink/CanvasView.swift              手書きキャンバス（PencilKit）とペン・マーカー・消しゴム
  Ink/PencilInteraction.swift       Apple Pencil のダブルタップ／スクイーズ
  Calendar/DayKey.swift             「年・月・日」だけを持つ日付（時差に左右されない計算用）
  Calendar/MonthLayout.swift        月のマス目の並び（42 日・行数）
  Calendar/EventKitService.swift    iPad のカレンダーから予定を読む
  Holidays/JapaneseHolidays.swift   日本の祝日（2000〜2099 年、Web 版と同じ規則）
Tests/TegakiCalendarTests/
  MonthLayoutTests.swift            月の並びのテスト（2026 年 10 月は 9/28 月曜から、など）
  JapaneseHolidaysTests.swift       祝日のテスト（内閣府の一覧 2000〜2027 年・国立天文台の春分秋分 2020〜2050 年）
.github/workflows/build.yml         GitHub Actions の設定
docs/                               設計書・価格・登録手順・規約類（上の表）
```

## 対応機種・条件

- アプリ名: **手書きカレンダー**（Bundle ID: `com.syfan0.tegakicalendar`）
- iPadOS / iOS 17 以降（iPhone でも動きますが、主役は iPad と Apple Pencil です）
- 縦向き・横向きのどちらでも使えます
- 配信は日本を中心に、EU を除く予定です（理由は [docs/APPLE_ENROLLMENT.md 4-5](docs/APPLE_ENROLLMENT.md)）
