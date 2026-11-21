# M7D（1.4）の下調べ: Web の事実（調査担当）

- 調べた日: **2026-11-20（JST、午前 4 時台）**。下の出典は全部この日に読んだ。
- 読み方: Apple と GitHub の公式の物を先に読んだ。Apple のページは `curl` で本文を取り、Apple の文書（developer.apple.com/documentation と HIG）は同じ文書の JSON（`developer.apple.com/tutorials/data/...json`）で読んだ。GitHub は `gh api`（読むだけ）で読んだ。
- 印: 【事実】は出典の文をそのまま確かめた物。【未確認】は確かめられなかった物。【推定】は事実から考えた物。【コード】はこのリポジトリ（origin/main 7895d40）を読んだ物。
- `[S番号]` は末尾の出典の表（URL と読んだ日）を指す。
- リポジトリと本人の作業場所には何も書いていない。commit・push・CI は無し。

---

## 0. 要点（リード向け、10 行）

1. Xcode 27 系で出ているのは **27.0（9/14）・27.1（10/15）・27.2（10/29）**。27.3 は beta 2（11/16）まで。SDK は順に iOS 27.0・27.1・27.2・27.3 beta 2 [S1][S2]。
2. Xcode 27.x の配布の最低版（deployment target）は **iOS 15〜27**。**iOS 17.0 のままでよい**（Apple の表）[S2]。実機のデバッグとシミュレータは iOS 17 以上 [S2][S3]。
3. GitHub の **`xcode-27`**（と `xcode-27-xlarge`）の環境に Xcode 27.0・**27.1（標準）**・27.2 がある。`macos-26` と `macos-15` には Xcode 27 は無い [S28][S29][S30][S32]。
4. シミュレータの機種の名前は **`iPhone Duo`**（そのまま）。iOS 27.1 の実行環境は iPhone Duo だけ。iOS 27.2 は「ふつうの機種の組」と「iPhone Duo だけの組」の 2 つ [S29][S41]。
5. 今の CI で使う `iPhone 17 Pro Max`・`iPhone 17 Pro`・`iPhone 16 Pro Max` は `xcode-27` の iOS 27.x に無い。代わりに `iPhone 18 Pro Max`・`iPhone 18 Pro` がある [S29]【コード】。
6. Duo の店の写真: 外側 **1398 × 2034**、内側 **2007 × 2853**（横向きも可）。**2027 年 4 月から必須**。対象の書き方が、仕様のページ（iOS 27.1 SDK 以降）と開発者ニュース（提出される全てのアプリ）で今も食い違う [S9][S13]。
7. **App Store Connect API で Duo の写真を上げるには、新しい Asset Library（`IPHONE_DUO`）を使う**。前からの `appScreenshotSets` などは API 4.5.1 で非推奨になり、Duo の値も無い [S21][S24][S25][S26]。
8. iOS 27 SDK の義務: 「**2027 年 4 月から**、App Store Connect に上げるアプリは iOS 27 SDK 以降で作る」。日付（何日か）はまだ出ていない [S8][S12]。
9. 年齢区分の 2 問（Shared Location・Dating and Relationships）は **API 4.6.1（11/18）で `sharedLocation`・`datingAndRelationships` として入った**。期限は 2027-01-12 [S11][S20][S23]。
10. python-holidays の最新は **0.109（11/17）**。**中国の 2027 年はまだ入っていない**（0.109 にも開発中の `dev` にも無い。PR も issue も無い）[S45][S46]。

---

## 1. Xcode 27 系（質問 1）

### 1.1 出ている版【事実】

| 版 | build | 日付 | 中の iOS SDK | 出典 |
| --- | --- | --- | --- | --- |
| Xcode 27 | 27A266a | 2026-09-14 | iOS 27.0 | [S1][S2][S3][S7] |
| Xcode 27.1 beta | 27A9269 | 2026-09-18 | iOS 27.1 beta | [S1] |
| Xcode 27.1 | 27A9275 | 2026-10-15 | **iOS 27.1**（tvOS など他は 27） | [S1][S2][S4] |
| Xcode 27.2 | 27B52 | 2026-10-29 | **iOS 27.2** | [S1][S2][S5][S7] |
| Xcode 27.3 beta 2 | 27C5035i | 2026-11-16 | iOS 27.3 beta 2 | [S1][S2][S6] |

- Xcode 27.3 beta 1 は 11/3 ごろ（TestFlight が 11/3 に「Xcode 27.3 beta」の受け付けを始めた）[S14]。GitHub の新しい環境に入った 27.3 beta の build は 27C5020n [S37]。
- Xcode 27.2 の正式版の前に 27.2 RC があった（App Store Connect は 10/20 に 27.2 RC を受け付け）[S14]。
- App Store Connect は、Xcode 27.1 RC を 10/5 から、Xcode 27.2 を 10/30 から、**App Store への提出にも**受け付けている [S14]。27.3 beta は TestFlight だけ [S14]。

### 1.2 配布の最低版と動く Mac【事実】

Apple の「SDK and system requirements」の表 [S2]:

| 版 | 動く macOS | 配布の最低版（Deployment Targets） | 実機のデバッグ | シミュレータ | Swift |
| --- | --- | --- | --- | --- | --- |
| Xcode 27・27.1・27.2・27.3 beta 2 | macOS Tahoe 26.6 以降 | **iOS 15–27**、iPadOS 15–27 | iOS 17 以降 | iOS 17 以降 | 6.4（言語モード 6・5・4.2・4） |
| （比較）Xcode 26.6 | macOS Tahoe 26.2 – 26.x | iOS 15–26.5 | iOS 15 以降 | iOS 15 以降 | 6.3 |

- つまり **`IPHONEOS_DEPLOYMENT_TARGET: "17.0"`（`project.yml:21`）は Xcode 27 系で使える範囲の中**【事実 [S2]＋コード】。
- `SWIFT_VERSION: "5.0"`（`project.yml:19`）の言語モード 5 も Xcode 27 系で使える [S2]【コード】。
- App Store Connect 側の最低: 「2026-09-09 から、iOS と iPadOS のアプリは iOS 13 以降を対象にすること」[S12]。17.0 は満たす。
- Xcode 26.6 の SDK は iOS 26.5 [S2]。Apple のメール ITMS-90725（11/18）の「iOS 26.5 SDK で作った」と合う。

### 1.3 Xcode 27 系の注意（このアプリに関係しそうな物）【事実】

- **Xcode 27.1**: 最初のシミュレータの起動に数分かかることがある。iPhone Duo のシミュレータでは StandBy と、ほとんどの app extension の実行が使えない [S4]。
- **Xcode 27.2**:
  - Device Hub で「iPhone Duo の写真と録画が、起動から数分は黒くなることがある」（187146039）[S5]。**CI で Duo の写真を撮るとき、起動直後は黒い写真になる恐れ**【推定】。
  - 「iOS 27.2 の実行環境のシミュレータを複製（clone）すると、権限の誤りで失敗することがある」（188407822）[S5]。xcodebuild の並列テストは機種を複製する【推定】。
  - Device Hub が iOS 17.x のシミュレータへの入力に対応 [S5]。
  - Xcode 27.2 は JSON の新しいプロジェクト形式 `.xcproj` を選べる（任意）[S5]。
- **Xcode 27.3 beta**:
  - **`XCUIAutomation` に `XCUIHinge` が入り、UI テストから iPhone Duo のヒンジの角度を変えられる**（187479559）[S6]。27.1・27.2 には無い。
  - Swift Testing で UI テストを書ける [S6]。
  - Xcode 27.3 は `.xip` 形式で配る最後の版。以後は `.aea` [S6]。
  - 既知の不具合: ディスクイメージで載せた実行環境を cryptex で載せ直すと、シミュレータが突然止まることがある（191574717）[S6]。GitHub の環境の不具合（§2.4）の元とされている [S38]。
- **UIScene の義務**: Apple の技術メモ TN3187 は「iOS 26 の次の大きな版から、最新の SDK で作るときは UIScene のライフサイクルが必須。無いとアプリが起動しない」と書く [S50]。このアプリは SwiftUI の `App`（`Sources/TegakiCalendar/App.swift:6` `struct TegakiCalendarApp: App`、`@UIApplicationDelegateAdaptor`）なので、シーンのライフサイクルを使っている【コード＋推定】。

### 1.4 iOS 27 系の公開【事実】（Apple のセキュリティ更新の一覧 [S7]）

| 版 | 日付 | 対象 |
| --- | --- | --- |
| iOS 27 | 2026-09-14 | iPhone 11 以降など |
| iOS 27.0.1 | 2026-09-28 | 同上 |
| iOS 27.1 | 2026-10-23 | **iPhone Duo だけ** |
| iOS 27.2 | 2026-10-26 | iPhone 11 以降など |
| iOS 27.2.1 | 2026-11-09 | 同上（開発者の一覧では 24B91034 と 24B156 の 2 つの build [S1]） |

---

## 2. GitHub Actions の macOS の環境（質問 2）

### 2.1 名前（ラベル）と状態【事実】

| 環境 | `runs-on` のラベル | CPU | 中の Xcode | 出典 |
| --- | --- | --- | --- | --- |
| Xcode 27 | **`xcode-27`**、`xcode-27-xlarge` | arm64（3 コア M1・7 GB は標準） | 27.0・**27.1（標準）**・27.2 | [S28][S29][S36] |
| macOS 26 Arm64 | `macos-latest`、`macos-26`、`macos-26-xlarge` | arm64 | 26.0.1〜26.6（標準 26.6） | [S28][S30] |
| macOS 26（Intel） | `macos-26-intel`、`macos-26-large`、`macos-latest-large` | x64 | 26.x | [S28][S31] |
| macOS 15 Arm64 | `macos-15`、`macos-15-xlarge` | arm64 | 16.0〜16.4（標準 16.4）・26.0.1〜26.3 | [S28][S32] |

- **`macos-xlarge` という名前は無い**。`macos-26-xlarge` はある（有料の大きい環境）[S28]。
- `xcode-27` の環境の OS は **macOS 27**（今の一般向け 20261104.0337.1 は macOS 27.0.1）[S29]。
- GitHub は 2026-10-15 に「Xcode 27 の環境は一般提供（GA）」と告知した [S34]。ただし runner-images の README の表と固定の issue #14404 は**まだ「preview」の印のまま**（11/20 時点）[S28][S33]。docs.github.com の表には `xcode-27` が `macos-26` などと同じ並び（3 コア・7 GB・14 GB）で載っていて、preview の印は無い [S36]。
- GitHub の新しい方針: 「1 つの環境は Xcode の 1 つの大きな版に合わせる（OS ではなく）」[S34][S35]。README も「macOS の版ごとに Xcode の大きな版は 1 つ」「Xcode の版ごとに、道具とシミュレータの実行環境は 3 つの x.y まで」「新しい x.y.z が出たら前の x.y.z は置き換え」と書く [S28]。**`macos-26` に Xcode 27 が入ることは無い**と読める【推定、方針から】。
- 公開リポジトリの標準の環境は無料（今の CI と同じ扱い）【未確認: 料金のページは読んでいない】。

### 2.2 `xcode-27` の中身（今の一般向け: 20261104.0337.1、macOS 27.0.1）【事実 [S29]】

- Xcode のパス: `/Applications/Xcode_27.2.app`（27B52）、`/Applications/Xcode_27.1.app`（27A9275、**標準**、`/Applications/Xcode.app` もこれ）、`/Applications/Xcode_27.app`（27A266a）。
- iOS SDK: `iphoneos27.0`（27.0）、`iphoneos27.1`（27.1）、`iphoneos27.2`（27.2）。
- 入っているシミュレータ:

| 実行環境 | 機種 |
| --- | --- |
| iOS 27.0 | iPhone 17、iPhone 17e、iPhone 18 Pro、iPhone 18 Pro Max、iPhone Air、iPad (A16)、iPad Air 11-inch (M4)、iPad Air 13-inch (M4)、iPad mini (A17 Pro)、iPad Pro 11-inch (M5)、iPad Pro 13-inch (M5) |
| iOS 27.1 | **iPhone Duo だけ** |
| iOS 27.2 | iPhone 17、iPhone 17e、iPhone 18 Pro、iPhone 18 Pro Max、iPhone Air、iPad (A16)、iPad Air 11-inch (M4)、iPad Air 13-inch (M4)、**iPad mini (A20 Pro)**、iPad Pro 11-inch (M5)、iPad Pro 13-inch (M5) |
| iOS 27.2 | **iPhone Duo**（別の実行環境） |

- **iOS 26.x と iOS 17.x のシミュレータは入っていない** [S29]。
- iOS 27.1 の実行環境が Duo だけなのは Apple の実行環境（24A94425）そのものの性質。Xcode 27.1 で Duo 以外を試すときは iOS 27.0 の実行環境を使う、と利用者が書いている（issue #15000、未解決）[S39]。
- iOS 27.2 の 2 つの実行環境は、24B8117（ふつうの機種）と 24B91016s（Duo）。どちらも約 8 GB。`OS=27.2` だけでは区別できない恐れがあり、`id=<UDID>` で指すのが安全、と Apple のフォーラムで言われている（Apple の人の答えではない）[S41]。
- 機種の識別子（`com.apple.CoreSimulator.SimDeviceType.…`）の正確な文字は Web で見つからなかった【未確認】。名前は `iPhone Duo`【事実 [S29]】。実機の機種名は iPhone19,4（フォーラムの利用者の書き込み）【未確認】[S42]。

### 2.3 今の `macos-26`（今の CI）【事実】

- 一般向け 20261102.0473.1（macOS 26.7.2）: Xcode 26.0.1〜26.6、標準は 26.6。iOS SDK は 26.0〜26.5。シミュレータは iOS 26.2・26.4・26.5（iPhone 17 Pro Max・iPhone 17 Pro・iPad mini (A17 Pro) などあり）。**Duo は無い** [S30]。
- 今の CI は `runs-on: macos-26` と `sudo xcode-select -s /Applications/Xcode_26.6.app`（`build.yml:79, :123`）【コード】。

### 2.4 `xcode-27` の最近の不具合と、配り中の新しい環境【事実】

- 新しい環境 **20261112.0361.1**（OS が macOS 27.2 に、Xcode 27.3 beta を追加）で、**シミュレータの実行環境が起動中・実行中に外れて**、UI テストが失敗する報告が 2 件（#15334: 27 件中 20 件で起きた、#15337）[S38]。
- GitHub は直しの PR #15342 を 11/18 に閉じた（各 Xcode 27 で `-runFirstLaunch` を先に走らせてから実行環境を取る。機種の実行環境が無いと環境作りを止める試験も追加）[S38]。
- **20261119.0378.1**（macOS 27.2、Xcode 27.3 beta 27C5020n を追加）は 11/19 に「prerelease」として配り始め（11/20 時点で一般向けはまだ 20261104.0337.1）[S37]。
- #15337 は、20261112 の環境の説明に Xcode 27.3 beta が載っているのに実物には無い、とも報告している（11/19 に閉じた）[S38]。
- 1.4 の最初の CI が当たる環境の版は、走らせる日で変わる【推定】。

### 2.5 このリポジトリの CI が使う機種名との差【コード＋事実】

- `build.yml`・`ja-baseline.yml`・`store-shots.yml` は `iPhone 17 Pro Max`（6.9 インチの写真）、`iPhone 17 Pro`、`iPhone 16 Pro Max`、`iPad mini (A17 Pro)`、`iPad Pro 13-inch (M5)`、`iPad Pro 11-inch (M5)`、`iPad Air 11-inch (M4)` などの名前を使う【コード】。
- `xcode-27` の iOS 27.2 には `iPhone 17 Pro Max`・`iPhone 17 Pro`・`iPhone 16 Pro Max` が無く、iPad mini は `iPad mini (A20 Pro)`。`iPad mini (A17 Pro)` は iOS 27.0 の実行環境にだけある [S29]。
- 6.9 インチの写真の機種の候補の並び（`build.yml:990` と `:1977`、`ja-baseline.yml:559`、`store-shots.yml:171` の `iPhone 17 Pro Max,iPhone 17 Pro,iPhone 16 Pro Max`）は、`xcode-27` の iOS 27.x に**1 つも無い**。iPad mini の並び（`build.yml:991` など）は最後の `iPad mini` の前方一致で `iPad mini (A20 Pro)` に当たる見込み【コード＋推定】。
- 店の写真の表では、6.9 インチ（Dynamic Island large）に iPhone 18 Pro Max と iPhone 17 Pro Max が同じ組で並ぶ。6.3 インチ（medium）に iPhone 18 Pro と iPhone 17 Pro が並ぶ [S13]。iPhone 18 Pro Max の画面の画素が 17 Pro Max と同じ 1320 × 2868 かは表の書き方からは分からない【未確認】。

### 2.6 XcodeGen（CI は `brew install xcodegen` で版を固定していない、`build.yml:264`）【事実＋コード】

- XcodeGen 2.47.0（2026-11-17）で `projectFormat: xcode27_0`（objectVersion 110）が入った。2.48.0（2026-11-19）で Xcode 27.2 の JSON 形式 `.xcproj` を試験的に書ける。2.48.0 から XcodeGen 自体の実行に macOS 14 と Swift 6.1 が要る [S51]。
- 版を固定していないので、1.4 の最初の CI で入る XcodeGen は 2.48.0 以降になる【推定】。

---

## 3. App Store の写真の決まり（質問 3）

### 3.1 iPhone Duo の写真の寸法と必須の時期【事実】

- 仕様のページ [S13]（「iPhone Duo」の行）:
  - 外側: **1398 × 2034**（縦）／**2034 × 1398**（横）。
  - 内側: **2007 × 2853**（縦）／**2853 × 2007**（横）。
  - 注: 「Starting in April 2027, screenshots will be required for any app using the iOS 27.1 SDK or later.」
  - 注: Duo の写真を出すと、店のページに「made for iPhone Duo」の印が出る。
- 開発者ニュース（2026-10-05）[S9] と App Store Connect のお知らせ（10/5）[S14]: 「Starting April 2027, any apps or games submitted will need to include screenshots for iPhone Duo.」印は「optimized for iPhone Duo」。
- **食い違いは今も残っている**（仕様: iOS 27.1 SDK 以降のアプリ／ニュース: 提出される全てのアプリ）。計画（M7_PLAN §6.2）の「厳しい方に合わせる」の前提は変わらない。1.4 は iOS 27.1 以降の SDK で作るので、**どちらの読み方でも Duo の写真が要る**【推定】。
- 内側・外側の両方が必須か、どちらか 1 つでよいかは、ページに書いていない【未確認】。計画の「内側・縦は必須」は今回の出典では確かめられなかった【未確認】。
- 2026-09-09 に Duo の写真の仕様が載り、「Duo の写真を上げる機能は年内に」とされた。10/5 から提出できる [S14]。App Store Connect のアプリ 3.3.1（11/4）と TestFlight 4.4.1（10/22）が Duo に対応 [S14]。

### 3.2 必須の写真（iPhone と iPad）の今の書き方【事実 [S13]】

- 「Required device sizes」: 「iPhone: At least one screenshot for iPhone with Dynamic Island (medium display).」「iPad (if your app supports iPadOS): At least one screenshot for iPad 13-inch display.」
- 同じページの「iPhone with Face ID (large display)」の行には「Required if app runs on iPhone and screenshots for iPhone with Dynamic Island (large display) aren't provided」とあり、上の書き方と合わない。いつ書き換えたかは書いていない【未確認】。
- 今のアプリは 13 インチ iPad・6.9 インチ・6.3 インチを出している（M7C.md:9）ので、どちらの読み方でも足りている【コード＋推定】。

### 3.3 App Store Connect API で写真を上げる道【事実】

- **API 4.5.1** で App Asset Library が入った: 画像は `POST /v1/appAssetLibraryImages`、置き場所は `POST /v1/appAssetLibraryPlacements`、順番は `POST /v1/appAssetLibraryPlacementOrderingRequests` [S21]。
- 同じ 4.5.1 で「**iPhone Duo の写真と動画は新しい `IPHONE_DUO` の display class で指す**。置き場所の組（placement group）と画面の寸法は `GET /v1/appAssetLibraryRefData` で読む」[S21]。
- 同じ 4.5.1 で **`app-screenshot-sets`・`app-screenshots`・`app-preview-sets`・`app-previews` は非推奨**。移り方は「Migrating to the App Asset Library」[S21][S26]。
- 前からの `ScreenshotDisplayType` の値（`APP_IPHONE_67` など）に **Duo の値は無い** [S24]。`AppAssetLibraryDisplayClass` には `IPHONE_DUO`・`IPHONE_DYNAMIC_ISLAND_LARGE_DISPLAY`・`IPHONE_DYNAMIC_ISLAND_MEDIUM_DISPLAY`・`IPAD_13_DISPLAY` などがある [S25]。
- 移り方の文書: 「置き場所の組の名前（例 `IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE`）は参照データから読むこと。Apple は API の版を上げずに新しい機種の組を足す」「上げた後の確定は `uploaded: true` だけで、checksum は要らない」「置き場所が残っている画像は消せない（`STATE_ERROR.ASSET_HAS_PLACEMENTS`）。先に置き場所を消す」[S26]。
- 4.5.1 の公開日は、読んだページからは分からなかった（10/5 の Asset Library の公開と同じころ）【未確認】。
- 1.3 の写真を上げた `asc12/shots13.py` はリポジトリの外にあり、どの API を使うかは今回は読んでいない【未確認】。非推奨の API がいつ使えなくなるかは書いていない【未確認】。

---

## 4. iPhone Duo の画面と Apple Pencil（質問 4）

### 4.1 画面【事実 [S18]】

- 内側: 7.6 インチ、**1878 × 2670 ピクセル、430 ppi**。外側: 5.4 インチ、**1398 × 2034 ピクセル、460 ppi**。両方に Dynamic Island。OS は iOS 27。
- 発売は 2026-10-23。発売時の OS は iOS 27.1 [S9][S10][S7]。

### 4.2 pt（ポイント）の寸法: **Apple はまだ出していない**【事実＋未確認】

- Apple の HIG「Designing for iPhone Duo」（2026-09-09 の新しいページ）に pt の寸法は無い。外側は compact の幅、内側は regular の幅を前提にせよ、とだけある [S16]。
- HIG「Layout」は 2026-09-09 に書き直され、前にあった機種ごとの寸法の表が見当たらない（JSON に iPhone の機種名は変更の記録にしか出てこない）[S17]。
- Apple の「Three steps to make your app shine on iPhone Duo」にも pt は無い [S15]。
- 第三者の推定（**Apple の数字ではない**）:
  - 内側 669 × 951 pt（店の写真 2007 × 2853 を 3 で割った値）。初めは 626 × 890（1878 × 2670 を 3 で割った値）と書き、9/10 に直した。外側 466 × 678 pt。「Device Hub で確かめるまでは推定」と本人が書いている（11/18 更新）[S44]。
  - フォーラムの利用者（Apple の人ではない）: Duo のシミュレータは外側だけで起動し、ウィンドウは 382 × 644 pt。`xcrun simctl io <udid> screenshot` では 2 つ目の画面（LCD-1、**2007 × 2853 px**）も見えた。コマンドでも XCTest でも開く方法は見つからない（Apple の答えは無し）[S40]。
- 計画（M7_PLAN §6.2）の「シミュレータの写真（1878 × 2670）を `sips` で 2007 × 2853 に拡大」は、上の利用者の報告どおりならシミュレータが初めから 2007 × 2853 で撮れることになる【未確認】。1.4 の最初の CI で `UIScreen`・`window.bounds`・写真の寸法を記録して確かめるのが確実【推定】。

### 4.3 開閉をシミュレータで試せるか【事実＋未確認】

- Xcode 27.1 の Duo のシミュレータと Device Hub で、全ての姿勢（Closed・Book・Open など）と向きを試せる、と Apple は書く（手で操作）[S9][S10][S15]。
- **コマンド（`simctl`）で開閉する方法は、Apple の文書にもフォーラムにも見つからない**【未確認】[S40]。
- **UI テストからは Xcode 27.3 の `XCUIHinge` で角度を変えられる**（27.3 はまだ beta。27.3 の正式版の日付は出ていない）[S6]【日付は未確認】。

### 4.4 Apple Pencil【事実】

- Apple のサポートの記事（公開日 2026-11-05）: 「You can use Apple Pencil (USB-C) with these iPad models with iPadOS 17.1.1 or later, and with **iPhone Duo with iOS 27.2**」。表に iPhone Duo がある。Apple Pencil Pro・第 2 世代・第 1 世代の表に Duo は無い [S19]。
- 仕様のページ: 「Supports Apple Pencil (USB-C)」、注「Hover is not supported when using Apple Pencil (USB-C) with iPhone Duo.」[S18]。
- iOS 27.2 は 2026-10-26 に公開済み [S7]。つまり**今の Duo の利用者は Pencil を使える**（27.2 に上げていれば）【推定】。
- 計画の「Pencil は iOS 27.2 で動くとの報道」は、**Apple の公式の記事で確かめられた**。

### 4.5 Apple がやめるよう求める書き方（計画のとおり、今も同じ）【事実 [S15][S43]】

- `UIScreen.main` で寸法や倍率を取らない（`traitCollection.displayScale` か SwiftUI の `@Environment(\.displayScale)`、画面が要るときは `view.window?.windowScene?.screen`）。
- 端末の向き（`UIDevice.current.orientation`、`interfaceOrientation`）でレイアウトを決めない。
- `userInterfaceIdiom == .phone / .pad` やサイズクラスで端末を見分けない。「regular の幅＝iPad」と思わない。
- Apple のフォーラムで DTS の答え（約 3 週間前）: 「main screen は 2 画面の端末では曖昧。環境・trait・シーンの寸法を使う」[S43]。
- SDK ごとの見え方（iOS 26 以前は中央に小さく、iOS 27 はほぼ全体、iOS 27.1 以降は全体でツールバーとタブバーが縦に並ぶ）も計画のとおり [S15]。
- HIG: 外側の画面では、システムのツールバーとタブバーは**横（側面）に縦に並ぶ**。開いて横向きにしても側面のまま [S16]。半開きのときの折り目を避ける API は `ReservedRegion`（SwiftUI と UIKit）[S16]。

---

## 5. iOS 27 SDK の義務の日付（質問 5）【事実】

- 開発者ニュース（2026-09-09）: 「**Starting April 2027**, apps and games uploaded to App Store Connect need to meet the following minimum requirements: iOS and iPadOS apps must be built with the iOS 27 & iPadOS 27 SDK or later」[S8]。
- 「uploaded to App Store Connect」なので、**TestFlight に上げるビルドも含む**と読める【推定】。
- 4 月の何日かは、まだ出ていない。Apple の「Upcoming Requirements」のページにも、2027 年の項目（iOS 27 SDK と Duo の写真）はまだ載っていない（今載っている一番新しい物は「2026-09-09 から iOS 13 以上を対象」）[S12]【日付は未確認】。
- 去年の例: iOS 26 SDK の義務は「2026-04-28 から」で、ニュースは 2026-02-03 に出た [S12]。今年も 2 月ごろに日付が出るかもしれない【推定】。
- 本人に届いた ITMS-90725（11/18）の「2027 年 4 月から iOS 27 SDK 以降」は、上のニュースと合う。

---

## 6. 年齢区分の新しい 2 問（質問 6）【事実】

- 開発者ニュース（2026-11-02）[S11]: 2026-11-16 から質問票に 2 つ増える。
  - **Shared Location**: 「Sharing of real-world location with another person or group.」
  - **Dating and Relationships**: 「Features that enable dating or relationship connections between real people and/or a virtual companion that engages a user in sexual or romantic content.」
  - 「You must provide these declarations when submitting an app update or making changes to your age rating questionnaire. All apps must have these declarations completed by **January 12, 2027**.」
  - Dating and Relationships は最低 18+。ブラジルでは Shared Location が A16、Dating and Relationships が A18。
- App Store Connect のお知らせ（2026-11-19 付け）は「**Starting November 19, 2026**」と書く（ニュースの 11/16 と違う）[S14]。
- **API に入った**: App Store Connect API **4.6.1（2026-11-18）**の「Added」: 「Added the **`sharedLocation`** and **`datingAndRelationships`** Boolean attributes to `AgeRatingDeclaration` and `AgeRatingDeclarationUpdateRequest`. Set them with `PATCH /v1/ageRatingDeclarations/{id}`. The answers currently affect only the age rating in Brazil.」[S20]
- 属性の一覧の文書にも 2 つとも載っている（どちらも boolean）[S23]。
- 同じ一覧に `socialMedia`・`socialMediaAgeRestricted`（API 4.4.1 で追加）と `ageAssurance` もある [S22][S23]。ソーシャルメディアの質問は 2026-07-09 から答えられ、9 月から必須 [S14]。
- 定義のページ [S27]: Shared Location は「現在の位置や続けての位置を、人や集まりと共有。常時・背景での共有、正確・おおよその位置を含む」。
- M7C.md:9（11/19 の記録）の「年齢区分の新しい 2 問はまだ API に無い」は、**11/18 の API 4.6.1 で変わった**。
- このアプリは位置を共有せず、出会い・交際の機能も無いので、2 問とも「いいえ」で 4+ のままの見込み【推定、M7B.md:2001 と同じ】。

---

## 7. python-holidays と中国の 2027 年（質問 7）

### 7.1 版【事実 [S45][S47]】

| 版 | PyPI に上がった日（UTC） | Requires-Python | wheel の大きさ | wheel の sha256 |
| --- | --- | --- | --- | --- |
| 0.107（今のアプリ） | 2026-10-19 | >=3.10 | 1,694,848 | `5e4582d5…7cb14`（`requirements.txt` と一致） |
| 0.108 | 2026-11-02 | **>=3.11** | 1,712,876 | `5a08fdcc…48749c7` |
| **0.109（最新）** | 2026-11-17 | **>=3.11** | 1,744,125 | `7d39c910167116d41fa6aae18d5e72b4541700cdd37743d799c83db3419201b0` |

- 0.108 で「Drop Python 3.10 support」[S47]。手元の Python 3.12.16（tools/holidays/README.md）は 3.11 以上なので入る【推定】。
- 0.110 の開発版（`0.110.devYYYYMMDD…`）が毎日のように上がっている。正式版はおおむね 2 週間ごと（0.105 9/21、0.106 10/5、0.107 10/19、0.108 11/2、0.109 11/17）[S45]。次の 0.110 は 12 月の初めごろ【推定】。
- 0.108・0.109 には中国以外の変更がたくさんある（例: ハンガリーの 2026 年からの 12/24、香港・フィンランドの直しなど）[S47]。版を上げると中国以外のデータも変わる【推定】。

### 7.2 中国の 2027 年【事実】

- **0.109 の `holidays/countries/china.py` に 2027 年は無い**。調整の表（`special_public_holidays` など）の最後は 2026 年。出典の一覧の最後も 2026 年の通知 [S46]。
- 開発の枝 `dev`（最新 commit 83be068、2026-11-19 15:54 UTC）の `china.py` にも 2027 年は無い [S46]。`china.py` の最後の変更は 2026-09-21（cc9c9bc）[S46]。
- vacanza/holidays に、中国の 2027 年の PR も issue も無い（11/20 に「China」と「2027」で検索）[S46]。
- 去年の例: 2026 年の分は PR #3052 で **2025-11-12** に入った（commit 208cd1e）[S48]。去年は通知の約 1 週間後に入ったが、今年は通知（11/5）から 15 日たってもまだ【事実】。
- 中国政府の通知（国办发明电〔2026〕10号、2026-11-05、新華網に転載）[S49]:
  - 元旦 1/1〜1/3（3 日）。
  - 春節 2/5〜2/13（9 日）。1/31（日）・2/14（日）は出勤。
  - 清明 4/3〜4/5（3 日）。
  - 労働節 5/1〜5/5（5 日）。5/8（土）は出勤。
  - 端午 6/9（1 日）。中秋 9/15（1 日）。
  - 国慶 10/1〜10/7（7 日）。9/26（日）・10/9（土）は出勤。
- つまり**今 0.109 を取り寄せても、中国の 2027 年は「発表前の推定」のまま**。M7C_CONTRACT §9.3 の条件（「新しい版に 2027 年の中国の祝日が入っていれば」）は、11/20 の時点では満たされていない【事実から】。

---

## 8. 計画（M7_PLAN §4.5・§6.2）を書いた後に変わったこと

| 計画の記述 | 11/20 の事実 | 出典 |
| --- | --- | --- |
| CI を `xcode-27` の **Xcode 27.1** へ | 27.1 は標準のまま。**Xcode 27.2（iOS 27.2 SDK）も同じ環境にあり、App Store に出せる** | [S14][S29] |
| `xcode-27`（macOS 27.0.1） | 一般向けは 27.0.1 のまま。macOS 27.2 の新しい環境を配り中（prerelease）。その前の版で実行環境が外れる不具合があり、直しが入った | [S29][S37][S38] |
| 一覧の表ではまだ「Preview」 | 今も README は preview。GitHub の告知と docs では GA | [S28][S34][S36] |
| Pencil は iOS 27.2 で動く**との報道** | **Apple の公式の記事**（11/05）で iOS 27.2 と確認。iOS 27.2 は 10/26 に公開済み | [S7][S19] |
| pt 寸法は Apple が公表していない | **今も公表していない** | [S15][S16][S17] |
| 写真の対象の書き方が食い違う | **今も食い違う** | [S9][S13] |
| シミュレータの写真 1878 × 2670 を拡大 | 利用者の報告では内側を 2007 × 2853 で撮れる【未確認】 | [S40] |
| 開閉をシミュレータで試せるかは未確認 | 手では試せる（Device Hub）。コマンドは無い【未確認】。UI テストは Xcode 27.3 の `XCUIHinge` で可（beta） | [S6][S9][S40] |
| （記述なし） | **写真を上げる API が Asset Library に替わり、Duo は `IPHONE_DUO` でしか指せない** | [S21][S24][S25] |
| （記述なし） | 年齢区分の 2 問が API 4.6.1 に入った | [S20] |

---

## 9. 分からないこと（未確認の一覧）

1. iPhone Duo の内側・外側の **pt の寸法**（Apple の公式の値）。1.4 の最初の CI のシミュレータで測るまで分からない。
2. Duo の写真で、**内側と外側の両方が必須か**、縦だけでよいか。
3. 「2027 年 4 月から必須」の**対象**（全てのアプリか、iOS 27.1 SDK 以降のアプリか）。Apple の 2 つの文が食い違ったまま。
4. iOS 27 SDK の義務の**正確な日付**（4 月の何日か）。
5. `simctl` で Duo の**外側だけ・内側だけを撮る**方法と、**開閉する**方法（コマンド）。利用者の報告だけで、Apple の文書は無い。
6. Duo のシミュレータの機種の**識別子**の正確な文字（`com.apple.CoreSimulator.SimDeviceType.…`）。
7. Xcode 27.3 の**正式版の日付**（`XCUIHinge` を提出用のビルドで使えるようになる日）。
8. 非推奨になった `appScreenshotSets` などが**いつ使えなくなるか**。`asc12/shots13.py` がどの API を使っているか（リポジトリの外なので読んでいない）。
9. API 4.5.1 の**公開日**。
10. `xcode-27` の環境で **iOS 17.x のシミュレータの実行環境を取り寄せて**動かせるか（環境に入っていない。Xcode 27 は iOS 17 以上のシミュレータに対応とだけある）。
11. python-holidays に中国の 2027 年が**いつ入るか**（PR がまだ無い）。
12. 新しい年齢区分の 2 問を、ふつうの更新の提出で**答えずに出せるのはいつまでか**（ニュースは「更新を出すときに答える」と「全部のアプリは 2027-01-12 まで」の両方を書く）。
13. iPhone 18 Pro Max のシミュレータで撮った写真の寸法が、6.9 インチの提出寸法（1320 × 2868 など）のどれになるか。
14. 公開リポジトリで `xcode-27` の標準の環境が無料か（料金のページは読んでいない）。

---

## 10. 出典（全部 2026-11-20 に読んだ）

| 番号 | 中身 | URL |
| --- | --- | --- |
| S1 | Apple Developer の「Software Releases」（Xcode・iOS の版と日付） | https://developer.apple.com/news/releases/ |
| S2 | Xcode の「SDK and system requirements」（配布の最低版の表） | https://developer.apple.com/support/xcode/ |
| S3 | Xcode 27 Release Notes | https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes |
| S4 | Xcode 27.1 Release Notes | https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes |
| S5 | Xcode 27.2 Release Notes | https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes |
| S6 | Xcode 27.3 Release Notes（beta 2） | https://developer.apple.com/documentation/xcode-release-notes/xcode-27_3-release-notes |
| S7 | Apple security releases（iOS 27 系・Xcode 27 系の日付と対象） | https://support.apple.com/en-us/100100 |
| S8 | ニュース 2026-09-09「App Store submissions now open for the latest OS releases」（iOS 27 SDK の義務） | https://developer.apple.com/news/?id=k1mtkt1k |
| S9 | ニュース 2026-10-05「Prepare and submit your apps for iPhone Duo」 | https://developer.apple.com/news/?id=kkphp5qo |
| S10 | ニュース 2026-09-16「Get ready with the latest beta releases」（Duo は iOS 27.1） | https://developer.apple.com/news/?id=rfb1rooi |
| S11 | ニュース 2026-11-02「Upcoming: New age rating content descriptors in App Store Connect」 | https://developer.apple.com/news/?id=yxkh08us |
| S12 | Upcoming Requirements | https://developer.apple.com/news/upcoming-requirements/ |
| S13 | App Store Connect Help「Screenshot specifications」 | https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications |
| S14 | App Store Connect Help「Release notes」 | https://developer.apple.com/help/app-store-connect/release-notes/ |
| S15 | 「Three steps to make your app shine on iPhone Duo」 | https://developer.apple.com/iphone-duo/prepare/ |
| S16 | HIG「Designing for iPhone Duo」 | https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo |
| S17 | HIG「Layout」 | https://developer.apple.com/design/human-interface-guidelines/layout |
| S18 | iPhone Duo の仕様 | https://www.apple.com/iphone-duo/specs/ |
| S19 | Apple Pencil compatibility（公開日 2026-11-05） | https://support.apple.com/en-us/108937 |
| S20 | App Store Connect API 4.6.1 release notes（2026-11-18） | https://developer.apple.com/documentation/appstoreconnectapi/app-store-connect-api-4-6-1-release-notes |
| S21 | App Store Connect API 4.5.1 release notes | https://developer.apple.com/documentation/appstoreconnectapi/app-store-connect-api-4-5-1-release-notes |
| S22 | App Store Connect API 4.4.1 release notes | https://developer.apple.com/documentation/appstoreconnectapi/app-store-connect-api-4-4-1-release-notes |
| S23 | `AgeRatingDeclaration.Attributes` | https://developer.apple.com/documentation/appstoreconnectapi/ageratingdeclaration/attributes-data.dictionary |
| S24 | `ScreenshotDisplayType` | https://developer.apple.com/documentation/appstoreconnectapi/screenshotdisplaytype |
| S25 | `AppAssetLibraryDisplayClass` | https://developer.apple.com/documentation/appstoreconnectapi/appassetlibrarydisplayclass |
| S26 | 「Migrating to the App Asset Library」 | https://developer.apple.com/documentation/appstoreconnectapi/migrating-to-the-app-asset-library |
| S27 | App Store Connect Help「Age ratings values and definitions」 | https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions |
| S28 | actions/runner-images README（ラベルの表と方針） | https://github.com/actions/runner-images/blob/main/README.md |
| S29 | `xcode-27-arm64-Readme.md`（Image Version 20261104.0337.1、commit c0f5743 2026-11-09） | https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md |
| S30 | `macos-26-arm64-Readme.md`（20261102.0473.1） | https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md |
| S31 | `macos-26-Readme.md`（Intel、20260824.0517.1） | https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md |
| S32 | `macos-15-arm64-Readme.md`（20261104.0514.1） | https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md |
| S33 | issue #14404「Xcode 27 is now available as a public preview」（開いたまま、コメントに GA の指摘） | https://github.com/actions/runner-images/issues/14404 |
| S34 | GitHub Changelog 2026-10-15「Xcode 27 runner image generally available」 | https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available/ |
| S35 | GitHub Changelog 2026-07-16「Xcode 27 runner image now in public preview」 | https://github.blog/changelog/2026-07-16-xcode-27-runner-image-now-in-public-preview/ |
| S36 | GitHub Docs「GitHub-hosted runners」 | https://docs.github.com/en/actions/reference/runners/github-hosted-runners |
| S37 | issue #15369「xcode-27-arm64 (20261119) Image Update」と releases の一覧（prerelease） | https://github.com/actions/runner-images/issues/15369 ・ https://github.com/actions/runner-images/releases |
| S38 | issue #15334・#15337、PR #15342（実行環境が外れる不具合と直し） | https://github.com/actions/runner-images/issues/15334 ・ https://github.com/actions/runner-images/issues/15337 ・ https://github.com/actions/runner-images/pull/15342 |
| S39 | issue #15000「macOS 27: iOS 27.1 runtime only supports iPhone Duo」 | https://github.com/actions/runner-images/issues/15000 |
| S40 | Apple Developer Forums 847883（Duo のシミュレータをコマンドで開く方法。利用者だけ、Apple の答え無し） | https://developer.apple.com/forums/thread/847883 |
| S41 | Apple Developer Forums 854476（iOS 27.2 のシミュレータが 2 つ） | https://developer.apple.com/forums/thread/854476 |
| S42 | Apple Developer Forums 851886（Duo のシミュレータの起動の失敗。答え無し） | https://developer.apple.com/forums/thread/851886 |
| S43 | Apple Developer Forums 847909（`UIScreen.main`。Apple の DTS の答えあり） | https://developer.apple.com/forums/thread/847909 |
| S44 | 第三者のブログ「iPhone Duo for Developers」（pt の推定、11/18 更新） | https://blakecrosley.com/blog/iphone-duo-for-developers |
| S45 | PyPI の holidays（JSON とページ） | https://pypi.org/pypi/holidays/json ・ https://pypi.org/project/holidays/ |
| S46 | vacanza/holidays の `china.py`（タグ v0.109 と枝 dev 83be068）、PR と issue の検索、`china.py` の commit の記録 | https://github.com/vacanza/holidays/blob/v0.109/holidays/countries/china.py ・ https://github.com/vacanza/holidays/blob/dev/holidays/countries/china.py ・ https://github.com/vacanza/holidays/pulls?q=China ・ https://github.com/vacanza/holidays/commits/dev/holidays/countries/china.py |
| S47 | vacanza/holidays の v0.108・v0.109 の release notes | https://github.com/vacanza/holidays/releases/tag/v0.108 ・ https://github.com/vacanza/holidays/releases/tag/v0.109 |
| S48 | PR #3052「Update China holidays in 2026」（commit 208cd1e、2025-11-12） | https://github.com/vacanza/holidays/pull/3052 |
| S49 | 新華網「国务院办公厅关于2027年部分节假日安排的通知」（2026-11-05、出所は中国政府網） | https://www.news.cn/politics/20261105/f90cd6ad4df94ab4833b141e52ccfc13/c.html |
| S50 | TN3187「Migrating to the UIKit scene-based life cycle」 | https://developer.apple.com/documentation/technotes/tn3187-migrating-to-the-uikit-scene-based-life-cycle |
| S51 | XcodeGen の releases（2.47.0・2.48.0） | https://github.com/yonaskolb/XcodeGen/releases |
