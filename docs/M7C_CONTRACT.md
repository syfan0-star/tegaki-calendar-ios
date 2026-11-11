# M7c 実装契約（1.3「横につなげる B-1」: 土台 ＋ 週・日、段 0、週の下のメモ）

> **本人が読む所**: すぐ下の §0（まとめ）だけで足ります。§11.3 の確かめ表は、TestFlight のビルドが届いたときに Claude が番号を書いて改めて渡します（今は開かなくて大丈夫です）。§1〜§10 と §12 から後は、作る人のための約束です。
>
> **この文書の決まり**: 1.3 の作業はこの文書に従います。設計の元は [B_DESIGN.md](B_DESIGN.md)（2026-11-01 の第 2 版）ですが、**食い違う所はこの文書が優先**です（版の番号・行番号・その後に入った変更を、ここで今に合わせました。§1.2）。結果は [M7C.md](M7C.md) に書きます（この文書の §18 は空のまま）。

---

## 0. まとめ（本人向け）

### 0.1 1.3 でできるようになること

- **週と日のページが、前後のページと横につながります。** 指で横にすべらせると、となりの週（日）が続いて出てきます。
- **境目をまたいで、そのまま Apple Pencil で書けます。** たとえば日曜の夜から月曜の朝へ、1 本の線で書けます。時刻は今までどおり上から下なので、夜中をまたぐ線は斜めになります。
- 日のページの 24 時の下の「自由メモ」は、となりの日と横に 1 本の帯になります。
- **週のページにも、24 時の下に「自由メモ」が付きます。** これは 1.3 の最後に作る部品です。横につなげる本体が 1 月 15 日までにできていなければ、メモは 1.3 に入れず、後の小さな版に回します。
- iPhone（「指でも書く」がオン）では、横に動かすのは 2 本指です。
- 指ではじくと、となりのページでぴたりと止まります。ゆっくり動かせば、好きな所で止まります。
- ◀ ▶ は今までどおり 1 ページずつ動きます。「今日」も今までどおりです。
- Apple Pencil で書いている間と、離してから 0.5 秒は、手のひらが触れても紙が横に動かないようにします。
- 設定に新しい欄「ページ」ができます。「前後のページを横につなげる」でオンとオフを選べます（ふだんはオン）。オフにすると、今と同じ 1 ページずつに戻ります。
- 更新して初めて週（日）を開いたとき、使い方の小さな札が 8 秒だけ出ます。

### 0.2 変わらないこと

- **月と年のページは、1.3 では今のまま**（1 ページずつ）です。月は 1.7、年は 1.8 で横につなげます。
- 書いた線の保存の形・iCloud の記録の形・書き出しの形は変えません。またいで書いた線は、線の真ん中があるページに 1 本で保存します。
- **今までに書いた手書きは 1 本も動きません。**
- 今の画面の日本語の文は変えません（新しい文が足されるだけです）。
- データは集めません。広告もありません。値段も同じです。

### 0.3 古い版の端末と Web 版

- 古い版（1.2.3 まで）の端末では、またいだ線は、保存された側のページにだけ出ます。**消えてはいません。**
- 古い版でその線を消すと、新しい版でも消えます（正しい動きです）。
- 週の自由メモは、古い版では見えません（消えてはいません）。
- 古い版の iPad で、はみ出した部分が紙の横の余白に見えるか、紙の端で切れるかは、まだ確かめていません【未確認】。見本の写真で確かめてから、新機能の文に書きます。
- Web 版は変えません。
- ですから、**iPad と iPhone の両方を 1.3 にしてください**（新機能の文にも書きます）。

### 0.4 段取りと目安の日

| いつ（目安） | すること | 本人にお願いすること |
| --- | --- | --- |
| 11/11 | この契約 | このまとめを読む（返事は要りません） |
| 11/12〜11/19 | 見えない土台の部品と、段 0（手書きを壊さない約束とその確かめ） | なし |
| 11/16〜11/20 | Apple の年齢区分の新しい 2 問に、版を作らずに答えられるか試す（§9） | 試せないときだけ、App Store Connect の画面で 1 回操作をお願いすることがあります |
| 11/20 ごろ | 見本の画像（1 枚の確認ページ） | 見て、気になる所があれば教えてください |
| 11/21 ごろ | 試作版を TestFlight に出す（設定 › 情報 の一番下の「横につなげる試作」） | 11/21〜11/23 の連休のどこかで、手順のとおりに触ってください（手順は試作と一緒に送ります） |
| 11/24〜12 月 | 本体を作る（11/26 までに試作の感想が無ければ、おすすめのまま進めます） | なし |
| 12/9 | 12 月に出すか、1 月に出すかを決めて知らせる | 知らせるだけ |
| 1/15 | 週のメモを 1.3 に入れるかの関門 | 知らせるだけ |
| 1 月下旬（早ければ 12 月中旬） | TestFlight 1.3 → 確かめ表 | 確かめ表（§11.3） |
| その後 | 提出 → 公開 → まとめる | 下の 3 つの言葉 |
| 2/15 | ここまでに出せなければ、iPhone Duo の版を先に出す | 知らせるだけ |

- 12 月中旬に出すのは、12/9 までに本体が全部の自動の確かめ（CI）を通ったときだけです。年末年始（12/19〜1/4）は Apple の審査が遅れることがあるので【未確認】、その間は審査に出しません。
- Claude の 1 週間の使える量が 95% に届いたら、その週の作業は止まります。止まっても間に合うように、どの関門の前にも 1 週以上の余裕を置いています。

### 0.5 見てもらうものと、要る言葉

- 見本の画像（11/20 ごろ）と試作版（11/21 ごろ）。答えが無くても進めます。
- TestFlight 1.3 の確かめ表（§11.3）。**ここは本人の端末でしか確かめられません。**
- 新しい文と App Store の文の確認ページ。「この内容で入れてよい」の言葉をください。
- 言葉: 「**1.3 を審査に提出して良い**」「**1.3 を公開して良い**」「**まとめて良い**」（1.3 を本流にまとめること）。公開の言葉は前もってもらっても構いません（1.2.3 と同じ）。
- 公開の日に直すサポートページ（日本語・英語）は、全文を見せてから「はい」をもらいます。
- 年齢区分の 2 問のために小さな版 1.2.4 が要るときだけ（§9）、「1.2.4 を審査に提出して良い」「1.2.4 を公開して良い」も聞きます。

### 0.6 「全部おすすめで」（11/7）で決めたこと

- はじいたとき: となりのページで止まる（P-B5 ア）。
- iPhone を横にして一番縮めたとき: 今のまま 24 時間全部が入る（P-B6 ア）。
- 一覧よりさらに縮めない（P-B10 ア）。月の並べ方（P-B3）は月の版（1.7）の見本で見てもらいます。
- 週のメモの形: 罫線だけの白紙（見本の画像で最終確認）。
- App Store の写真の先頭に、週の境目をまたいで書いた見本を 1 枚足します（16 の言語すべて）。
- App Store の「主な言語」を日本語から英語に替えます。日本では今までどおり日本語で出る見込みです（Apple の決まりによる見込み【未確認】。公開の後に日本の App Store の表示で確かめます）。訳の無い国（オランダ・スウェーデンなど）で、日本語ではなく英語が出るようになります。
- そのほかの細かい決めごとは §15 にまとめました。見本や試作を見て「違う」と思ったら、いつでも変えられます。

### 0.7 本人でないと決められないこと

- 今、決めてほしいことはありません。
- 本人の言葉が要るのは、上の 0.5 の所（実機の確かめ・提出・公開・まとめる）だけです。
- 中国の 2027 年の祝日のデータを入れるために外からデータを取り寄せるときは、そのときに了承を聞きます（§9.3。入れるのは 1.2.4 を作るときだけ）。

---

## 1. 土台・決定・範囲

### 1.1 土台のコード

- ブランチ `r13`。main の **43fe366**（2026-11-10、公開中の 1.2.3 ＝ ビルド 23 を main にまとめた commit）から切り、db816ba（`docs/B_DESIGN.md` を中身そのままで入れた）と a663781（1.2.3 の記録）を足した。`Sources`・`TegakiKit`・`Tests`・`tools`・`.github`・`project.yml` は 43fe366 と 1 バイトも違わない。
- **コードの行番号は 43fe366 のもの。** `docs/B_DESIGN.md` の行番号はこのリポジトリの写しのもの（先頭に 3 行の注があるので、元の控えより 3 行下。2 行目の空行を、この文書を指す 1 行に置き換えたので行数は変わらない）。B_DESIGN の **中で** 引いているコードの行は m7a ffb645e のもので、今の行は §1.2 の表で読み替える。
- `docs/M7_PLAN.md` はこの文書と同じ commit で書き直した（B_DESIGN §13 の差し替え）。M7_PLAN を行番号で引くときは、書き直す前の a663781 の行で、節の名前を添える。
- 版は `MARKETING_VERSION "1.3"`（今は `project.yml:23` で "1.2.3"）。配る先は iOS 17.0 のまま（`project.yml:8, :21`）。
- この Mac には Xcode もシミュレータも無い。TegakiKit は `swift build` と KitChecks、アプリは `tools/typecheck/typecheck.sh`（Mac Catalyst での型の確かめ）まで。PencilKit・キャンバス・画面の確かめは GitHub Actions の CI だけ（M7B.md:1426）。

### 1.2 読み替えの表（B_DESIGN と古い計画 → 今）

**版の番号**（本人の答え 2026-11-01 と 2026-11-07。M7_PLAN §5 の「本人の答え（2026-11-07）」に「§4 の表と食い違う所はこちらが優先」とある）

| B_DESIGN の書き方 | M7_PLAN 第 3 版・M7B 0-27 の書き方 | 今（この文書） |
| --- | --- | --- |
| B-1 土台＋週・日 = 1.5 | 1.3 | **1.3** |
| B-2 年 = 1.6 | 1.7 | **1.8** |
| B-3 月 = 1.7 | 1.6 | **1.7** |
| 指で予定 1.3・1.3.1 | 1.5・1.5.1 | 1.5・1.5.1 |
| Duo と Xcode 27 = 1.4 | 1.4 | 1.4（2/15 の決まりで 1.3 と入れ替わりうる、§12.4） |
| 重点欄 = 1.8 | 1.8 | **1.9** |
| 書ける終日欄（`wb-`/`db-`）= 1.9 | 1.9 | **1.10** |
| — | — | 1.4.1 ペンの色・メモ欄の紙、1.6 写真と文字の札 |
| 「1.1 のままの道」 | 「1.2 のままの道」（M7B_CONTRACT.md:1093） | **「1.2.3 のままの道」**（この文書では「1 ページの道」） |
| 見本の画像と試作版は「1.4 の頃」「1.4 から分けたブランチ」「2027 年 3 月」（B_DESIGN.md:567, :587, :593） | 1.2 の後・B-1 を作り始める前 | 同じ。**`r13` の中で、`SPAN_PROTOTYPE` の条件つき**（D12） |
| 古い道を消すかは「1.8 の契約」（:145） | — | 月・年がそろった後（1.8 の後）の版の契約 |
| 「1.3 の `isDraggingEvent`」（:148） | — | 1.5（今のコードに予定のドラッグは無い） |

- この作業の指示の文にある「月 1.6・年 1.7」は 11/7 より前の番号なので使わない（§15 の 1）。

**コードの行**（ffb645e → 43fe366。主な所だけ。B_DESIGN 付録 A のほかの行も同じ考えで読み替える）

| B_DESIGN の行（ffb645e） | 今（43fe366） |
| --- | --- |
| `CalendarRootScreen` `.id(pageId)` :842 | `.id(canvasIdentity)` :1028。`canvasIdentity = "\(pageId)\|\(weekStart.rawValue)"` :473（1.2 から週の始まりを含む） |
| `pageBinding` :959-969（門 :963） | :1145-1162（門 :1149）。1.2.1 の評価の印 :1156-1160 |
| `sync.onRemoteUpdate = { applyRemote($0) }` :996 | :1190（代入はアプリでここ 1 か所） |
| 裏へ回る・非アクティブの保存 :1028-1031 | `scenePhaseChanged` :1245-1262（saveNow :1248、`applicationDidEnterBackground` :1253） |
| `show(kind:focus:)` :1091-1127 | :1325-1377（訪問の印 :1328-1331、saveNow :1334、`sync.load` :1361、`pageOpened` :1364、`BandMigration` :1368、`model.load` :1375、`noticeHiddenInk` :1377） |
| `move(by:)` :1129、`goToday` :1133 | :1382-1387、:1392-1397（`remember` :1400-1406） |
| `applyRemote` :1191-1202（門 :1192） | :1581-1592（門 :1582） |
| `eraseAllInk` :1476 | :1869-1889 |
| `openExport` :1618 | :2019-2020（`runExport` :2032-2068、PDF に渡す :2051） |
| アカウントの「残す」:1722 | `chooseAccount` :2130-2142、`reloadShownPage` :2147-2160 |
| `scheduleSave`/`saveNow` :1917-1938 | :2520-2527 / :2531-2541 |
| `newEventPlan` :1330 | :1722-1727 |
| ページの状態 :131-206 | `page` :154、`paper` :156、`capNoticedPageId` :188、`inkChangedThisVisit` :211、`lastInkChangeAt` :213、`selection` :247、`saveTask`/`pageDirty` :272-273、`viewport` :281 |
| `InkCanvasView` :499/:503 | :626 `alwaysBounceHorizontal = false` / :630 `isDirectionalLockEnabled = true` |
| `detach` :541-550 | :758-778 |
| pageId の門 :590、別 id で作り直す :599-610 | :588-590 と :836、:845-857 |
| `PageSignature` :274-286 | :305-317 |
| `requestApply` :693-696 | :948-951（`isUsingTool`/`isSettling` :408-409） |
| 軽い道 :737-768 | `applyPending` :953-1070（tailOnly :992-993、軽い道 :998-1016） |
| `publishPage` :1181-1189、`deliver` :1201-1209 | :1478-1486、:1498-1508 |
| 描き変わりの門・PencilKit の ↶ 止め :1415-1418 | `applyCanvasDrawing` :1889-1958（門 :1890、↶ 止め :1895） |
| ⑦ `isTail` :1473、`budgetCount` :1453/:1514 | :1952、:1926/:1994 |
| `screenNewStrokes` :1499-1535（drop :1506） | :1979-2017（drop :1986） |
| scroll の delegate :1547-1600 | :2033-2120（DidScroll・DidZoom・WillBeginZooming・DidEndZooming・viewForZooming だけ） |
| 投げなわの候補 :1642-1656、`overlay.pageSize` :531/:749/:764 | :2129-2147、:664/:1006/:1021 |
| `InkLedger.needsMoreRoom` :345-347 | :346-349（このファイルは ffb645e から注記 1 行だけ違う） |
| `SyncEngine` `onRemoteUpdate` :68、`workEpoch` :93、save :136-158、`pageOpened` :160-175、記録の削除 :605-617、`mergeRemote` :625、push :690-727 | :72、:102、:161-182、:185-203（G2 の門 :196）、:759-772、:779-806、:848-913 |
| `PaperGrowth` drop :66-77、tail :81-110 | :77-89、:92-121（`tailHeight = max(6000, b+50)` :23-34） |
| `growsWithInk` 日 :100-102・週 :96・月 :223・年 :155 | 日 `DayLayoutEngine.swift:106-108`（:100-103 は今は `inkCell`）・週 `WeekLayoutEngine.swift:105-107`・月 `MonthPageLayout.swift:227-229`・年 `YearLayoutEngine.swift:161-163` |
| `ZoomPolicy.overviewSize` :63-71 | :77-85（:63-70 は 1.1.1 の `baseSize`、`bounds` :135-146、`centeringInsets` :180-189） |
| `PDFPageRenderer` isMemo/isExtra :59/:63、render :119-161 | :60/:65、:122-165（clip :150、`InkSnapshot.image` :159） |
| `ScreenshotMode.demoPage` :349、月の見本の id :379/:383/:387 | :473-491、:510/:514/:518 |
| `StickyHeaderView` の `PaperRow` :292-333 | :359-400 |
| `SettingsScreen` の節 :150-155 | :171-184（カレンダー → 週の始まり → 祝日 → 入力 → 同期 → データ → 購入 → 情報） |

**その後の変更で前提が変わった所**

- 1.1.1: 月のメモ欄と日の自由メモは最初から 6,000 lu（`PaperGrowth.swift:23-34`、`DayLayoutEngine.swift:187-189`）。日の紙は 1000 × 8400 lu。B_DESIGN の「隣の長い日の分だけ白紙が続く」（:40, :310）と V2Probe §1 の数字（:160, :883）は 1.1 の 400 lu 刻みの話。今、下の端のそろえが効くのは、線の下端が 5,950 lu を超えたときだけ。台帳の変更 4（前置を外して `needsMoreRoom`）は正しさのために要る。
- 1.1.1: 開く倍率（`baseSize` の fitAll）と下限（`overview` の fitAll）が分かれた（`ZoomPolicy.swift:135-146`）。週と日は同じ大きさなので窓の表（B_DESIGN.md:496-513）は変わらない見込み【推論】。KitChecks で計算し直して固定する（§10.1）。
- 1.1（a535074）: ページが替わった後、絵を作り直すまでは画面と台帳を比べない守り（`resetScroll`、`InkCanvasView.swift:1890, :1733`）。B_DESIGN §2.1 の「門は 3 層」に無い 4 つ目。窓のずらしでもそのまま要る（§3.6）。
- 1.2: 週の始まり（K-11）。`w-` は月曜か日曜。`canvasIdentity` に週の始まり。10 言語（画面の新しい文は全部キーにする、lint L-1〜L-14）。データのコードの凍結（`tools/compat10/DATA_1_1.sha256`）。
- 1.2.1・1.2.2: 評価の依頼と年齢の確かめの印が 1 ページの道に結び付いている（`CalendarRootScreen.swift:901-915, :1156-1160, :1328-1331, :1382-1387, :2389-2447`）。
- 1.2.3: SyncEngine の G1〜G3（アカウントの確かめ）、`enqueue`/`spawn` だけで仕事を足す決まり、同期のテストの 20 回くり返し（R1_2_3.md:73-120, :155-169）。
- Layout は InkModel を import できない（`TegakiKit/Package.swift:38-52`。`CellKey` は Layout の `PaperSpec.swift:132`）。B_DESIGN §2.3 の「`InkModel/SpanName.swift`」と「`Layout/SpanLayout.swift` が前置を外す」はそのままでは組めない（D4 で置き場所を決めた）。
- KitChecks の数は 29,982 件、閾値 29,932（`.github/workflows/build.yml:108-126`）。B_DESIGN §11.1 の「24,446 件」は古い。
- 互換の fixture の置き場は `TegakiKit/Tests/Fixtures/compat11`（16 ファイル）。B_DESIGN §11.2 の「`Tests/Fixtures/compat-span/`」は `TegakiKit/Tests/Fixtures/compat-span/` と読む。本物の古い版は、今の CI では 1.0（a21e469）と <1.1.1>（9cbc3c9）。
- 0-38（英語の規約のページ）は 1.2.1 で済んだ（`TegakiKit/Sources/Access/LegalLinks.swift:10`、R1_2_1.md:17, :245-261）。M7_PLAN の 1.3 の注の「0-38」は古い。
- 週の下のメモ（PLAN_WEEK_MEMO.md）で、B_DESIGN の「1 ページの道への変更は 3 つだけ」（:144）と「週はそろえる物が無い」（:297-304）が変わる（§5）。

### 1.3 本人の決定（確定。再検討しない）

- P-9 = **B**（2026-11-01）。「Bでお願いします。これは紙のカレンダーを超える部分です。」（B_DESIGN.md:76）。手書きの安全（K-1〜K-11）は一切ゆるめない。
- P-B11 = ア（月はこの形でよい）、P-B1 = **ウ**（週・日を一番先に）、P-B2 = **月**（B_DESIGN.md:907-913）。
- 段 0 は 1.3 の中。見本の画像と試作版は 1.2 の後、B-1 を作り始める前に本人に見てもらう（B_DESIGN.md:913）。
- 2027-02-15 までに B-1 を提出できなければ、Xcode 27・iPhone Duo の版を先に出す（M7_PLAN §4「順の決まり」）。
- 2026-11-07「全部おすすめで」: 版の番号を 1 つずつ下げる（1.6 写真と文字の札、1.7 月、1.8 年、1.9 重点欄、1.10 書ける終日欄）、週の下のメモは 1.3 の最後の部品（1/15 の決まり）、形は罫線だけの白紙（PLAN_WEEK_MEMO.md:5, :11-12）。1.3 以降の案は全部おすすめ。
- 立てつけの決まり: 途中で許可を取らず、既定で決めて記録し、最後にまとめて報告する。本人の言葉が要るのは、実機の確かめ・提出・公開・main へまとめることだけ。

### 1.4 リードの決定（D1〜D26）

**D1 版の番号は 11/7 のもの。** 1.3 = B-1、1.7 = 月、1.8 = 年。理由: M7_PLAN §5 に「食い違う所はこちらが優先。表の書き直しは 1.3 の契約で」とある。

**D2 新しい道を通るのは「週・日、かつ設定オン」だけ。** 月・年・設定オフは 1.2.3 の 1 ページの道（`.id(canvasIdentity)`・`pageBinding`・単独の `InkLedger`）。理由: 設定オフが本物の安全弁になる（B_DESIGN.md:139-145）。

**D3 1 ページの道に入れる変更は、この 6 つだけ。** (1) 記録の削除（他の端末の「全て消す」）を画面に合わせる（§6.6 の H1）、(2) 保存の入口の `SpanGuard`（1 ページの道では前置名が無いので何もしない）、(3) 設定の「ページ」の節、(4) 週の下のメモ（紙の形だけ。台帳とキャンバスの道は同じ）、(5) 「消して始める」の前に保存の予約を止める（H2）、(6) 「全て消す」「消して始める」の後に ↶ を捨てる（H3）。どれも線を新しく消す道を増やさない。

**D4 新しいファイルの置き場所。** Layout に `SpanPlan`・`SpanLayout`・`SpanAlign`・`SpanName`（`CellKey` と文字列の前置・分割・外す）。InkModel に `SpanGuard`（`InkPage` を確かめる）・`SpanComposer`・`PageDelta`。InkModel の既存の 7 ファイルは 1 バイトも変えない。理由: Layout は InkModel を import できず、InkModel は Layout を使える（`Package.swift:38-52`）。

**D5 `SyncEngine` に足すのは 2 つの口だけ。** `pagesOpened(_:)`（窓のページをまとめて 1 回の取得）と `onRemoteDelete`（記録の削除の知らせ）。今の関数は変えない。1.2.3 の約束（G2・epoch・`enqueue`/`spawn`）を全部守る（§7）。理由: 「空のページでファイルが無い」から画面で見分ける案もあるが、推し量りより明示の口の方が壊れにくい。窓は最大 15 ページ（iPhone 横の日）で、1 ページずつの取得は費用が大きい。

**D6 隣のページは、B-1 では主スレッドで 1 ページずつ読む。** 焦点のページを先に、隣は近い順に、1 ターンに 1 ページ（`Task.yield` を挟む）。読むのは `sync.load`（写真モードと何もしないエンジンの分かれ道を通る、`SyncEngine.swift:151-154`）。理由: `InkPageStore.load` は読めないファイルを `.bak` に移すので主スレッドの外で使うと順番の危険がある（`InkPageStore.swift:65-78, :113-125`）。P-B9 の答え（いちばん線の多いページ 1016 本、M7B.md:1937）なら 1 ページは軽い。試作版で 1 ページの読み込みが 16 ms を超えたら、外へ出す道（読むだけの道と世代）を 1.3 の中で足す（§4.6）。主スレッドで読む間は、先読み中に `onRemoteUpdate` が割り込むことは無い（同じ main の上で順に走る）。

**D7 画面の番号（`SpanSession.epoch`）はエンジンの `workEpoch` と別に持つ。** 進めるのは、この端末の「全て消す」と「消して始める」と取り込みのときだけ。理由: エンジンの epoch は裏からの戻りや `.CKAccountChanged` でも進む（`SyncEngine.swift:264, :281, :662`）ので、結び付けると保存していない線を捨ててしまう。

**D8 保存の予約はセッションに 1 本**（1.5 秒、今の `scheduleSave` と同じ）。`saveAll()` は決まった順で保存する（線を足したページが先、ページをまたぐ移動では行き先が先）。行き先の保存に失敗したら、組になっている元のページ（墓標の側）は保存しない（失うより二重に残る方を選ぶ）。理由: 眠りから起きる順番は決まらない（R1_2_3.md:151）。

**D9 凍結の表の作り直し。** ファイル名 `tools/compat10/DATA_1_1.sha256` は変えない（`lint.py:663-679` と `build.yml:182` が名前で読む）。変えてよいファイルを §6.4 に列挙し、そのファイルを変える commit で同じ表の行も書き直す。最後に、提出する commit の中身から表を作り直し、新しい InkModel のファイル（`SpanGuard.swift`・`SpanComposer.swift`）を足す。CI の段の名前は「Data code frozen (re-based in 1.3)」にする。

**D10 互換（K-7）の fixture は `TegakiKit/Tests/Fixtures/compat-span/` に置く。** 月曜の形の fixture は、CI で compat11 の一時フォルダに写して 1.0 の写し・本物の 1.0・`Real10LedgerTests` に読ませる。日曜の形の fixture は新しいターゲット `CompatSpanTests` と、`tools/weekstart-compat` の形（本物の 1.0 と <1.1.1>）だけで読む。compat11・Compat10・`tools/compat10/EXPECTED_MIN`（225）は 1 バイトも変えない（§6.3）。

**D11 B-1 の写真は新しいジョブ `span-shots` で撮る。** build-and-test の 120 分を守るため（1.2.3 の CI は 72〜82 分、R1_2_3.md:326, :342）。ずらす前と後の比べは、このジョブで落とす（§10.5）。

**D12 試作版は `r13` の中に、コンパイルの条件 `SPAN_PROTOTYPE` つきで置く。** `testflight.yml` の入力 `span_prototype` だけで付ける（1.2.2 の `age_force` と同じ形）。`project.yml` に入っていたら build.yml が落とす。試作の画面の文は ja だけのキー（L-2 の `jaOnly`）にする。理由: 別のブランチだと土台の部品が二重になる。枝だけの lint の例外は作らない。

**D13 試作版のエンジンは、`SyncEngine` を変えずに作る。** 一時フォルダの `InkPageStore(directory:)`・`SyncStateStore`・`InMemoryCloudDatabase` で `SyncEngine` を作り、`start()` しない（`SyncEngine.swift:134-146, :186, :449`）。B_DESIGN.md:584 の「工場の関数に `store` の引数を足す」は要らない。

**D14 `SpanGuard` は `SyncEngine` の中ではなく、画面の保存の 1 か所（`PageSlot.persist`）で働かせる。** 1 ページの道の `saveNow` もここを通す。取り込み・書き出し・PDF の入口にも置く。試作は自分専用の `SpanGuard.prototype`（`proto-` の id だけを通す）を使う。理由: エンジンを変える所を 2 つの口に限るため。保存に渡るのは画面の 1 か所だけ（`sync.save` を呼ぶのは画面の保存と、`show` の移し替えの保存だけ）。

**D15 線の持ち主は、外接矩形の中心の x が入るページ**（半開区間、境目ちょうどは右）。書いた端末が書いたときに 1 回だけ決める。点は切らない。帯の外に中心がある新しい線は捨てる（今の M4C-25 と同じ）。

**D16 日の自由メモと週のメモの「下の端をそろえる」は、`SpanAlign` の下限で作る。** 今はどの日も 6,000 lu あるので、効くのは 5,950 lu を超えた線のときだけ。部品は小さいが、週のメモと同じ部品なので 1.3 で作る（B_DESIGN §3.3）。

**D17 PDF は、隣のページから入ってくる線の紙の中の部分も描く**（P-B8 は既定）。隣の線は前置名のまま `InkSnapshot.image(strokes:cells:…)` に渡し、凍結の `InkSnapshot` は変えない。日の自由メモ（と週のメモ）を PDF に入れるかの判定は、そのページの紙の上にある線（入ってくる線を含む）で決める（§3.11）。

**D18 窓の線の上限は、口と段 2（その種類だけ 1 ページの道に戻して 1 回案内する）まで。** 最初の数は iPad 20,000 本・iPhone 12,000 本。試作版で測って決め直し、`SpanPlan` の定数と KitChecks で固定する。P-B9 の答えでは、本人のいちばん多いページは 1016 本なので、ふだんは届かない（§3.15）。

**D19 決めた数字**（§3.16 の表）は KitChecks か XCTest で固定する。試作版で測ってから変えるものは、その印を付ける。

**D20 評価の依頼（1.2.1）の「訪問」は、新しい道では焦点のページで数える。** 焦点が別のページに替わり、止まったときを「ページを離れた」とする（今の ◀ ▶ と同じ意味）。差分に足した線があれば `inkChangedThisVisit`・`lastInkChangeAt`・`noteReviewInk` を立てる（今の `pageBinding` :1156-1160 と同じ）。年齢の確かめの `penDown`（:910）はそのまま。

**D21 線の予算（K-9）と「メモ欄はここまでです」は、持ち主のページで数えて、ページ id 付きで知らせる。** 今のキャンバスの知らせ `onStrokeBudget`・`onGrowthCapReached`（`InkCanvasView.swift:199-208`）にはページが入っていないので、引数にページ id を足す（1 ページの道では今のページ id）。

**D22 今の 1.2.3 の穴 H1〜H3 は 1.3 で 2 本の道の両方を直す**（画面の側だけ。凍結の Ink の行は §6.4 の範囲で書き直す）。理由: B の安全網の merge と取り合いになる所なので、B と一緒に確かめる（§6.6）。

**D23 段 0 の予定の 2 つは、1.3 では「口」と「印」だけ作る。** 予定の行き先を「ページ・マス」で受ける純粋な関数（`SpanLayout.eventTarget`）を作り、今の予定ツールと「予定にする」はこれを通す（同じページの中だけ）。取り消しの組は、台帳の履歴の 1 歩に「触れたページ id」と「組の印」の場所を作り、`pruneHistory` が組を一緒に捨てられるようにする。予定のドラッグと予定の ↶ は 1.5（今のコードに無い）。

**D24 年齢区分の 2 問（期限 2027-01-12）は、版を作らずに答えるのを先に試し、だめなら 12/9 に決めて、1.3 か小さな版 1.2.4 で答える**（§9）。

**D25 0-37 は分ける。** `InkCanvasView.swift:679`「手書きの紙」は、1.3 でこのファイルを変えるのでキーに移す（9 言語の訳が要る）。`InkTrace.swift` の 5 件は例外のまま残し、理由の字を「1.2 の間だけ」から「TestFlight と審査のビルドだけの記録のシート。日本語のまま（審査メモに書いてある）」に書き直す（`tools/l10n/ja-exceptions.txt:11-16`）。`InkTrace.swift` は変えない。

**D26 1.3 の App Store の写真は、先頭に「週の境目をまたいで書いた見本」を 1 枚足す**（B_DESIGN §9.4。全 16 ロケール。ja も新しく撮る）。今の写真は残す。

### 1.5 範囲

| # | 何をする | どこ（役） |
| --- | --- | --- |
| 1 | TegakiKit の純粋な部品: `SpanPlan`・`SpanLayout`・`SpanAlign`・`SpanName`（Layout）、`SpanGuard`・`SpanComposer`・`PageDelta`（InkModel）と KitChecks | K |
| 2 | 台帳の 5 か所（§3.3）と履歴の組の印（§4.4） | L |
| 3 | キャンバスの窓・ずらし・はじき・見張り・削除の守り・手のひら（§3.6） | L |
| 4 | `SpanSession`・`PageSlot`・受け箱・安全網・`saveAll`/`cancelAll`/番号・予定のページごと・題名・◀ ▶・今日（§3.5、§3.7） | S |
| 5 | 2 本の道と切り替え（設定・種類・週の始まり）（§3.1、§3.9） | S |
| 6 | 紙・固定見出し・終日帯（窓のページを並べる、レーンを窓でまとめて詰める）（§3.8） | P |
| 7 | `SyncEngine` の 2 つの口（§7） | Y |
| 8 | PDF（隣から入る線）・写真モード（§3.11、§3.12） | P・U |
| 9 | 設定「ページ」・初めての案内・窓の上限の口と段 2（§3.14、§3.15） | U |
| 10 | 段 0: 紙の外の点を切らない約束・はみ出す線の fixture・予定の口・取り消しの組・見本の画像・試作版（§4） | K・C・L・T・リード |
| 11 | 今ある穴 H1〜H3 の直し（§6.6） | S |
| 12 | 互換（K-7）・凍結の表の作り直し・CI・写真（§6.3、§6.4、§10） | C |
| 13 | 新しい文の 9 言語の訳と逆翻訳、16 ロケールの新機能の文、審査メモ、App Store の写真、SUPPORT（§8） | X・R・A・W |
| 14 | 週の下のメモ（最後の部品。1/15 の関門）（§5） | K・P・C |
| 15 | M7_PLAN の差し替え（B_DESIGN §13）と B_DESIGN の頭の 1 行（この commit で済み） | リード |

### 1.6 範囲外（1.3 ではしない）

- 月の横つなぎ（1.7）、年の横つなぎ（1.8）、その重さの対策（平行移動のずらし・照合の速い道・見るだけの段 1・保存を外へ出す直列の actor・年の予定の計測。B_DESIGN.md:523-526）。月・年は 1.3 では 1 ページの道のまま。
- 指で予定（予定のドラッグ・長押し・予定の ↶）は 1.5。1.3 では段 0 の口と印だけ。
- 重点欄（1.9）、書ける終日欄・週の重点（1.10）、写真と文字の札（1.6）、ペンの色・メモ欄の紙（1.4.1）。
- Xcode 27・iPhone Duo（1.4）。B-1 は今の Xcode 26.6 で作り、1.4 で確かめ直す（§14 にその分の見積もり）。
- 一覧よりさらに縮める形（P-B10 イ）、iPhone 横の大きさの上限（P-B6 イ）。
- 古い道（1 ページの道）を消すこと。
- 1.2 から持ち越した細かい訳の直し（M7B.md:61, :903, :1638-1649, :1952, :1958）。2/15 を守るため 1.3 には入れない。
- Web 版の変更。

### 1.7 決めどころの決着（番号は 0c-n。M7B の 0-n と区別する）

| # | 決めどころ | 決着 |
| --- | --- | --- |
| 0c-1 | 版の番号 | 11/7 の番号（D1） |
| 0c-2 | 新しい道の範囲 | 週・日で設定オン（D2） |
| 0c-3 | 1 ページの道への変更 | 6 つ（D3） |
| 0c-4 | Span の部品のモジュール | D4 |
| 0c-5 | `SyncEngine` の変更 | 2 つの口だけ（D5、§7） |
| 0c-6 | 隣のページの読み方 | 主スレッドで 1 ページずつ（D6） |
| 0c-7 | 画面の番号 | エンジンの epoch と別（D7） |
| 0c-8 | 保存の予約と順番 | セッションに 1 本、決まった順（D8） |
| 0c-9 | 凍結の表 | 名前はそのまま、行を同じ commit で書き直し、最後に作り直す（D9、§6.4） |
| 0c-10 | 互換の fixture の置き場と読む相手 | D10、§6.3 |
| 0c-11 | 写真のジョブ | 新しい `span-shots`（D11） |
| 0c-12 | 試作版の置き場 | `r13` の中、`SPAN_PROTOTYPE`（D12） |
| 0c-13 | 試作の文の lint | ja だけのキー（D12） |
| 0c-14 | 試作のエンジン | `SyncEngine` を変えずに一時フォルダで（D13） |
| 0c-15 | `SpanGuard` の場所 | 画面の保存の 1 か所と、取り込み・書き出し・PDF の入口（D14） |
| 0c-16 | 先読みを主スレッドの外へ出す条件 | 試作で 1 ページの読み込みが 16 ms を超えたとき（D6） |
| 0c-17 | はじき（P-B5） | ア（隣で止まる）。試作の感想で変えうる |
| 0c-18 | iPhone 横（P-B6） | ア（今のまま） |
| 0c-19 | さらに縮める（P-B10） | ア（しない） |
| 0c-20 | 見本の画像の範囲 | 週・日、iPhone 横、古い版の見え方、案内の札、週のメモの形。月の 3 通り（P-B3）と年は 1.7・1.8 の契約で（§4.5） |
| 0c-21 | PDF（P-B8） | 隣から入る線も描く（D17） |
| 0c-22 | 評価の依頼の「訪問」 | 焦点のページ（D20） |
| 0c-23 | 予算と上限の案内 | 持ち主のページ、ページ id 付き（D21） |
| 0c-24 | H1〜H3 | 1.3 で直す（D22） |
| 0c-25 | 段 0 の予定の 2 つ | 口と印だけ（D23） |
| 0c-26 | 年齢区分の 2 問 | D24、§9 |
| 0c-27 | 0-37（凍結した Ink の日本語 6 件） | D25 |
| 0c-28 | 0-38（英語の規約のページ） | 1.2.1 で済み。1.3 では L-9 が緑のままであることだけ確かめる |
| 0c-29 | App Store の写真 | 先頭に 1 枚足す（D26） |
| 0c-30 | 主言語を en-US に | 替える。11/16 の後に最初に作る Connect の版（1.2.4 か 1.3）で（§8.6） |
| 0c-31 | nl-NL・sv | 足さない（主言語が en-US なら英語が出る）（§8.6） |
| 0c-32 | CRA | 1.3 では当たらない。申し送りだけ（§8.6） |
| 0c-33 | 古い本物の版の相手 | 1.0 と <1.1.1>（1.2.3 のデータのコードは SyncEngine 以外 1.1.1 と同じ）（§6.3） |
| 0c-34 | KitChecks の閾値 | 1.3 の新しい数 − 50（§10.1） |
| 0c-35 | J-4（日本語の写真の基準） | 1.2.3（43fe366）を基準にした別のファイル `tools/l10n/ja-baseline-ref-1.3.txt`。`ja-baseline-ref.txt`（<1.1.1>、compat-v1.0 と共用）は変えない（§10.5） |
| 0c-36 | 1.4 の確かめ直しの里程 | 0.2〜0.3 里程（§14） |
| 0c-37 | 1/15 の関門の「CI を通る」の意味 | §1.5 の表の 1〜12 が `r13` に入り、全部のジョブが緑（§5.1） |
| 0c-38 | 12 月に出すかの判断 | 12/9（§12.2） |

---

## 2. 構成とファイル所有

1 つのファイルの持ち主は 1 つの役。commit は `git add <ファイル名>` で、持ち主のファイルだけを入れる。役の表は §12.1。

```
TegakiKit/Sources/Layout/
  SpanPlan.swift            K  新しい。番号と id の往復（weekStart を受ける）・原点・半開区間・焦点・窓・ずらし量・はじき・見積もり・定数
  SpanLayout.swift          K  新しい。合成レイアウト（PageLayout に従う）・eventTarget（段 0）
  SpanAlign.swift           K  新しい。下の端の下限（日の extra・週の extra）
  SpanName.swift            K  新しい。前置・分割・外す（CellKey と文字列）
  PaperGrowth.swift         K  週の extra を tail に足す（§5。週のメモの段だけ）
  WeekLayoutEngine.swift    K  週の extra（§5）・下限の入力（省けば今と同じ）
  DayLayoutEngine.swift     K  下限の入力（省けば今と同じ）
  ZoomPolicy.swift          K  週の一覧は 24 時間（1,920 lu）に（§5）
  AllDayBand.swift          K  日の並びを受ける口（今の week(firstDay:weekStart:) は残す）
TegakiKit/Sources/InkModel/
  SpanGuard.swift           K  新しい。仮想の名前・前置名・書く形の確かめ（Release でも）
  SpanComposer.swift        K  新しい。仮想ページ・PageDelta・安全網の範囲・別名
  （既存の 7 ファイル）      —  1 バイトも変えない
TegakiKit/Sources/KitChecks/
  SpanChecks.swift          K  新しい。§10.1 の節
  main.swift                K  節を呼ぶ 1 行
Sources/TegakiCalendar/Ink/
  InkLedger.swift           L  台帳の 5 か所・履歴の組の印（§3.3、§4.4）
  InkCanvasView.swift       L  窓・ずらし・はじき・見張り・受け箱・削除の守り・手のひら・知らせにページ id・「手書きの紙」をキーに
  InkOverlayView.swift      L  投げなわの帯（要るときだけ。§6.4 の表）
  （ほかの 5 ファイル）      —  変えない
Sources/TegakiCalendar/Span/
  SpanSession.swift         S  新しい。PageSlot・受け箱 SpanInbox・saveAll/cancelAll/epoch・先読み・予定のページごと
  SpanPrototype*.swift      T  新しい。#if SPAN_PROTOTYPE の中だけ
Sources/TegakiCalendar/Views/
  CalendarRootScreen.swift  S  2 本の道・呼び口の置き換え・H1〜H3・題名と remember・評価の印
  SettingsScreen.swift      U  節「ページ」・試作の入口（#if SPAN_PROTOTYPE）
  StickyHeaderView.swift    P  窓のページの列を並べる
  AllDayBandView.swift      P  窓の日の並びのレーン
  SpanGuideView.swift       U  新しい。初めての案内の札
Sources/TegakiCalendar/Sync/
  SyncEngine.swift          Y  pagesOpened(_:)・onRemoteDelete を足すだけ
Sources/TegakiCalendar/Paper/       P  週の紙の色と線を 24 時で止める（§5）
Sources/TegakiCalendar/Export/      P  PDF に隣から入る線（D17）・SpanGuard の入口
Sources/TegakiCalendar/Support/     U  写真モードの 6 つの引数（§3.12）
Sources/TegakiCalendar/Persistence/AppSettings.swift  U  キー page.span（端末ごと、既定 true）
Tests/TegakiCalendarTests/          L・S・Y・T・U  §10.2 の表（ファイルごとの持ち主もそこ）
Tests/TegakiCalendarUITests/         U  span UI: のテスト
TegakiKit/Tests/Fixtures/compat-span/  C  新しい。§6.3
TegakiKit/Tests/CompatSpanTests/        C  新しい。日曜の形を含む全部の compat-span を読む
tools/compat10/DATA_1_1.sha256      C  §6.4 の手順でだけ書き直す
tools/l10n/                         X・R・C  訳・逆翻訳・ja-exceptions の理由の字・ja-baseline-ref-1.3.txt
.github/workflows/build.yml         C  §10.6
.github/workflows/testflight.yml    C  入力 span_prototype
.github/workflows/ja-baseline.yml   C  基準の写し直し（§10.5）
.github/workflows/store-shots.yml   C  ja の組と、またぐ見本の 1 枚
docs/store/                          A  16 ロケールの新機能の文・審査メモ
docs/SUPPORT.md・SUPPORT.en.md       W  またいで書く・週のメモの FAQ（公開の日に Web へ）
project.yml                          C  MARKETING_VERSION "1.3"
docs/M7C.md                          リード  記録
```

### 2.1 接点（宣言。新しい引数には既定値を付け、省けば 1.2.3 と同じ動き）

```swift
// Layout/SpanName.swift
public enum SpanName {
    public static let separator: Character = "|"
    public static func prefixed(_ cell: CellKey, page: String) -> CellKey      // "<page>|<cell>"
    public static func prefixed(id: String, page: String) -> String
    public static func split(_ name: String) -> (page: String, local: String)? // 最初の | で分ける
    public static func strip(_ cell: CellKey) -> CellKey                         // 前置が無ければそのまま
    public static func isPrefixed(_ name: String) -> Bool
    public static let virtualPrefix = "span~"                                    // span~<kind>~<n>
}

// Layout/SpanPlan.swift
public struct SpanPlan: Sendable, Equatable {
    public init(kind: PageKind, weekStart: WeekStart, deviceClass: SpanDeviceClass, orientation: SpanOrientation)
    public func index(of pageId: String) -> Int?        // 日 = 日の通し番号、週 = ⌊first.dayNumber ÷ 7⌋
    public func pageId(at index: Int) -> String          // 週の逆: n × 7 + (月曜 4 / 日曜 3) の日
    public func origin(of index: Int, around focus: Int) -> CGFloat
    public func owner(ofCenterX x: CGFloat) -> Int       // 半開区間 [X_i, X_i + W)、ちょうどは右
    public func focus(midX: CGFloat, previous: Int) -> Int   // ヒステリシス 6 %
    public var radius: Int { get }                       // R = ⌈(V − 0.05)/2 + 1⌉
    public func shiftAmount(pages: Int, zoom: CGFloat) -> CGFloat
    public func flingTarget(offsetX: CGFloat, velocity: CGFloat, zoom: CGFloat) -> CGFloat
    public static func estimatedStrokes(fileBytes: Int) -> Int   // 1 本 0.25 KB で割る（多めに数える）
    public static let windowStrokeCap: (iPad: Int, iPhone: Int)  // 20_000 / 12_000（試作で決め直す）
}

// Layout/SpanLayout.swift
public struct SpanLayout: PageLayout {
    public init(pages: [any PageLayout], plan: SpanPlan, firstIndex: Int, floors: SpanAlign.Floors = .none)
    public var pageId: String { get }                    // span~<kind>~<セッションの番号>。ずらしても変えない
    public func drop(center: CGPoint) -> SpanDrop        // .keep(page, cell) / .outsidePaper / .belowCap / .viewOnly
    public func onlyTailHeightChanged(from old: SpanLayout) -> Bool
    public func eventTarget(at point: CGPoint) -> (pageId: String, local: CGPoint)?   // 段 0（D23）
    public func page(containing name: CellKey) -> Int?
}

// InkModel/SpanGuard.swift
public enum SpanGuard {
    public enum Mode: Sendable { case release, prototype }
    public static func checkForSave(_ page: InkPage, mode: Mode = .release) -> Bool   // id の書く形 ＋ 鍵と cell に前置名なし
    public static func checkForTransfer(_ page: InkPage) -> Bool                     // 取り込み・書き出し・PDF: span~ と前置名だけ
}

// InkModel/SpanComposer.swift
public struct PageDelta: Sendable, Equatable {
    public let pageId: String; public let added: [InkStroke]; public let removed: [String]
    public let at: Int; public let epoch: Int; public let group: UUID?    // 組の印（§4.4）
}
public enum SpanComposer {
    public static func compose(_ pages: [InkPage], plan: SpanPlan) -> SpanVirtualPage
    public static func deltas(from journal: [SpanJournalEntry], epoch: Int) -> [PageDelta]
    public static func apply(_ delta: PageDelta, to page: InkPage) -> InkPage
    public static func extract(pageId: String, from virtual: SpanVirtualPage) -> InkPage   // 安全網。pageId は必ず本物
}

// Sources/TegakiCalendar/Ink/InkLedger.swift（変える所だけ）
var makeId: (CellKey) -> String = { _ in InkStroke.newId() }          // 1 ページの道は今と同じ UUID
var journal: [SpanJournalEntry]                                          // 生きていた id の削除だけ
func pruneHistory(touching pageIds: Set<String>)
func applyCanvasChange(_ drawing: PKDrawingLike, allowRemovals: Bool = true) -> CanvasChangeResult

// Sources/TegakiCalendar/Sync/SyncEngine.swift（足すだけ）
var onRemoteDelete: ((String) -> Void)?             // 記録の削除の後、onRemoteUpdate(空) の後に呼ぶ
func pagesOpened(_ pageIds: [String])               // pageOpened と同じ門。1 回の fetchRecords

// Sources/TegakiCalendar/Span/SpanSession.swift
@MainActor final class SpanSession {
    init(kind: PageKind, weekStart: WeekStart, focus: DayKey, sync: SyncEngine, guardMode: SpanGuard.Mode = .release)
    let id: String                      // .id(...) に使う。種類＋週の始まり＋開き直した回数
    private(set) var epoch: Int
    func deliver(_ deltas: [PageDelta]) // 受け箱から。古い epoch・窓に無いページは捨てて記録
    func saveAll() -> [String]          // 保存できなかったページ id
    func cancelAll()
    func remoteUpdated(_ page: InkPage) // applyRemote の振り分け
    func remoteDeleted(_ pageId: String)
}
```

- キャンバスへの新しい入力（`InkCanvasView`）: `span: SpanSession?`（nil なら今の 1 ページの道）、`inbox: SpanInbox?`。知らせ `onStrokeBudget(pageId:event:)`・`onGrowthCapReached(pageId:)`（D21）。
- `SpanVirtualPage` は保存・同期・書き出し・PDF の型に変換できない包み（型で漏れを防ぐ）。

---

## 3. 設計（B_DESIGN §2〜§3 を今のコードに当てた形）

### 3.1 2 本の道

- 新しい道: 週・日で、設定「前後のページを横につなげる」がオン（`AppSettings` の `page.span`、既定 true、端末ごと、iCloud に送らない）。画面は `SpanSession` を作り、キャンバスは `.id(session.id)`。窓のずらしでは作り直さない。
- 1 ページの道: 月・年と、設定オフの週・日。1.2.3 のまま（`.id(canvasIdentity)`・`pageBinding`・単独の台帳）。1.1 からのテスト（`PaperGrowthTests`・`InkCanvasViewTests`・`InkLedgerTests` など）はこの道で今のまま走る。
- 道を替えるとき（設定の切り替え・種類の切り替え・週の始まりの切り替え）は、今の道の全ページを保存してから開き直す（新しい道は `saveAll()`、1 ページの道は `saveNow()`）。同じページを 2 つの道で同時に開かない（K-3）。
- 開き直す（新しいセッション。キャンバスを作り直す）のは: 種類の切り替え、日付のタップ・ダブルタップ、遠い「今日」、設定の切り替え、週の始まりの切り替え、全て消す、消して始める、取り込み。
- 段 2（§3.15）で窓が重すぎるときは、その種類だけ 1 ページの道に戻す。

### 3.2 TegakiKit の部品

- `SpanPlan`（B_DESIGN.md:172-174、M7B_CONTRACT.md:1669）: 番号は日 = 日の通し番号、週 = `⌊first.dayNumber ÷ 7⌋`（月曜も日曜も同じ式で、逆は `n × 7 + 4`（月曜）か `+ 3`（日曜）。1970-01-01 は木曜）。`weekStart` を必ず受ける（L-13 に `SpanPlan(` を足す）。1 つの `SpanPlan` は 1 つの形だけ。
- `SpanLayout`（B_DESIGN.md:183-189）: `cells` は `<pageId>|<マス>` で x に原点を足したもの。`inkCell` は中心の x で持ち主のページを選び（ちょうどは右）、局所座標でそのページの `inkCell`。帯の右端は今の単独ページの規則のまま。`hit`・`dayAt`・`eventRange`・`snapRect`・`growsWithInk` は前置を外して点の下のページへ。`drop` は点の下のページの局所座標でそのページの `PaperGrowth.drop`、帯の外は `.outsidePaper`。型で決め打ちしている所（`ZoomPolicy.overviewSize` :77-85、`PageNavigation.initialScrollX/Y` :150-183、`DateTap.target`、`newEventPlan` :1722-1727）は、点の下のページに振り分けてから呼ぶ。窓 1 ページの `SpanLayout` は今のレイアウトと同じ答え（KitChecks で固定。古い道を消す日のため）。
- `SpanAlign`（D16）: 窓の中の日（週）の extra の高さを、一番長いものにそろえる下限。横に動いても下げず、消して縮むときは下げる（B_DESIGN.md:288）。入力を省けば今の出力と `==`。
- `SpanName`・`SpanGuard`（D4、D14）: 前置は最初の `|` で分ける（ページ id に `|` は無い。K-10）。128 バイトを超える id は端末の中だけの別名 `<pageId>|~<n>` にし、差分と墓標で必ず元の id に戻す（`InkPage.add`・`remove` は 128 バイト超を黙って無視する、`InkPage.swift:114-143`、`InkStroke.swift:134-137`）。
- `SpanComposer`（B_DESIGN.md:190-193）: 読んだ本物のページに **ページごとに `BandMigration.migrate`** をかけてからまとめる（前置名では `isBandCell` が false、`BandMigration.swift:17-19`）。中身が変わったら、そのページを保存する（今の `show` :1366-1373 と同じ）。`v`・`updatedAt`・知らない最上位の項目は `PageSlot` に残す。

### 3.3 台帳の 5 か所と、前置名が届く所

台帳（`InkLedger`、UIKit を import しない、:7-8）の変更は次の 5 つだけ（B_DESIGN.md:149-155）。

1. `makeId: (CellKey) -> String`（今 :166 は `() -> String`）。新しい道では持ち主のページを前置した id を返す。1 ページの道は今と同じ UUID。`testLedgerWritesTheCompatShapes` の種の渡し方は書き直すが、作る JSON は compat11 と 1 バイトも違わないこと（§6.3）。
2. `journal`: `applyCanvasChange`・`perform`（:414-441）・`removeStrokes`（:478-487）・`moveStrokes`（:495-522）の 4 か所で記録を足す。**削除を記録するのは、その時点で仮想ページで生きていた id だけ。**
3. `pruneHistory(touching:)`: 出るページにかかわる ↶ ↷ と、それより古い操作を捨てる。組の印が同じものは一緒に捨てる（§4.4）。
4. `needsMoreRoom`（:346-349）: 前置を外してから `PaperGrowth.needsMoreRoom` を呼ぶ。
5. `applyCanvasChange(_:allowRemovals:)`（:289-337。墓標 :306-318）: 消しゴムでないとき、または 1 回の変化で消える線が多すぎるとき（§3.16）、墓標にせず「作り直しが要る」を返す。1 ページの道は今どおり（常に許す）。

そのほか（`drawing()` の F1 :225-243、指紋、↶ を新しい id の写しで戻す規則、投げなわの移動）はそのまま。

**前置した名前が、名前で判断する関数に届く所**（B_DESIGN.md:158-169 を今の行に直した。新しい道での扱いを守る）

| 所（今の行） | 今の判定 | 前置名が届くと | 新しい道での扱い |
| --- | --- | --- | --- |
| `InkLedger.needsMoreRoom` :346-349 | `growsWithInk`・`PaperGrowth.needsMoreRoom`（`isTail` = memo・extra、`PaperGrowth.swift:11-13`） | 伸びが効かない（1.1.1 からは b > 5,950 lu のときだけの差） | 変更 4 |
| キャンバスの ⑦ `InkCanvasView.swift:1952` | `PaperGrowth.isTail && reachesCap` | 常に false。「メモ欄はここまでです」が出ない | 前置を外してから |
| 軽い道 :992-1016 | `onlyTailHeightChanged`・`tail(of:)` | 常に false（遅いだけ） | `SpanLayout.onlyTailHeightChanged` |
| `screenNewStrokes` の drop :1986 | `tail(of: layout)` | 上限より下の線を捨てない | `SpanLayout.drop` |
| `layout.growsWithInk`（§1.2 の表の行） | 素の名前 | false | 前置を外してページへ |
| `layout.cells[…]`（台帳、投げなわ :2131） | 名前で引く | 前置名の鍵で引ける | 変えない |
| `ledger.page.budgetCount` :1926, :1994 | ページ全体 | 窓全体を数える | 持ち主のページごと（K-9、D21） |
| `BandMigration.isBandCell` :17-18 | 素の名前 | false | まとめる前にページごと |
| `inkCell`・`hit`・`dayAt`・`eventRange`・`snapRect`・`DateTap.target` | 局所座標・素の名前 | — | 点の下のページへ振り分け |
| 紙・PDF（`PDFPageRenderer` :60, :65）・`InkSnapshot`・`StrokeCensus` | 本物のページ | 届かない作り | 本物のページだけ渡す。隣の線は前置名のまま描くだけ（D17） |
| `InkPage.merge` の `pickPageId`（`InkPage.swift:236-240`） | 辞書順で小さい id | `span~…` は `w-`・`y-` より小さいので、本物の id が仮想の id に化ける | 安全網の範囲は必ず本物の id で作る。merge の後に id が変わっていないことを確かめる |
| `compareStrokes` のマス名（`InkPage.swift:207-229`、F4） | 大きいマス名が勝つ | `w-…\|grid` > `grid` なので、漏れた方が全端末で勝ち、どの版でも描かれない（戻らない） | `SpanGuard` で保存の前に止める（§6.1） |

### 3.4 差分・受け箱・安全網・削除の守り

B_DESIGN §2.4 の 5〜6（:203-215）をそのまま約束にする。

- **差分**: キャンバスは台帳の日誌を `PageDelta` にして出す。画面は `PageSlot.page` に `InkPage.add`/`remove` を当てて dirty にする。**ページを丸ごと書き戻すことは無い。**
- **(a) ためない**: 台帳を変えた同じターンで受け箱 `SpanInbox`（SwiftUI の状態ではない参照型）に入れる。`deliver` で 1 回だけ空にする予約。画面は bounds の変化・ずらし・保存・裏へ回る・開き直し・全て消すの入口で、まず受け箱を空にする。`detach()`（:758-778）で delegate を外す前に日誌を出し切る。
- **(b) 間引かない**: 差分には `publishPage` の superseded（:1478-1486）を使わない。
- **(c) 安全網**: 保存とずらしのたびに、台帳の仮想ページからそのページの範囲を取り出し（**pageId は本物**）、`InkPage.merge` で `PageSlot` に混ぜる。`contentDiffers` のときだけ置き換えて dirty にし、「安全網で回収した」を記録（Debug では止める）。merge の後に pageId が本物のままかを確かめる（§3.3 の表の `pickPageId`）。
- **(d) 差分はそれを出したセッションにだけ当てる。** セッションは受け箱を空にして `saveAll()` し終えるまで閉じない。窓に無いページへの差分と古い epoch の差分は当てずに記録（Debug では止める）。
- **削除の守り**: (a) 日誌の削除は生きていた id だけ、(b) 消しゴム以外で線が減ったら作り直し、1 回に多すぎる削除も同じ（§3.16）、(c) 窓に無いページへ差分を当てる道は作らない。

### 3.5 `SpanSession` と `PageSlot`、1 ページ分の呼び口の置き換え

- `PageSlot` = 今の `page`・`paper`・`pageDirty`・`capNoticedPageId`（`CalendarRootScreen.swift:154, :156, :188, :273`）をページごとに。保存の予約は **セッションに 1 本**（D8）。
- `saveAll()`: 受け箱を空にする → 各ページに安全網の merge → dirty なページを決まった順に `PageSlot.persist`（`SpanGuard` → `sync.save`）。失敗したページは dirty のまま、まとめて 1 回案内（今の「手書きを保存できませんでした」）。
- `cancelAll()`: 予約を止め、受け箱を捨て、epoch を進める。
- 先読み: D6。読むたびに `PageSlot` を作り、`BandMigration` をかけ、予定を読む。`sync.pagesOpened` は窓が決まったときに 1 回。
- 外から来た更新（`applyRemote` :1581-1592）: 窓のどのページでも `SpanSession.remoteUpdated` に振り分け、`PageSlot` に merge。この端末にしか無い線があれば dirty。キャンバスには「外から来た版」の数で知らせ、台帳を `reload(keepHistory: true)`。窓に無いページの更新は何もしない（次に入るときに読む）。

| 今の呼び口（1 ページ分） | 新しい道 |
| --- | --- |
| 裏へ回る・非アクティブ `scenePhaseChanged` :1245-1256（`applicationDidEnterBackground` :1253 より前） | `saveAll()` |
| `show` :1334 | `saveAll()` → 新しいセッション |
| 書き出しの前 `openExport` :2019-2020 | `saveAll()` |
| アカウントの「残す」 `chooseAccount` :2130-2132 | `saveAll()` |
| 全て消す :1869-1889 | `cancelAll()` → 新しいセッション（H3） |
| 消して始める :2130-2141 | `await` より前に `cancelAll()`（H2）→ 後で新しいセッション |
| アカウントの答えの後の読み直し `reloadShownPage` :2147-2160 | 新しいセッション |
| 取り込み | 前に `saveAll()`、後で新しいセッション |
| 週の始まりの切り替え `switchWeekStart` :1466-1480 | `saveAll()` → 形を替える → 新しいセッション（`weekStartSwitch` :1459-1464 の順のまま） |
| `runWeekStartCheck` の dirty なページ :1507 | `saveAll()` の後に確かめる（dirty は 0 のはず） |
| PDF `runExport` :2051 | 焦点のページの本物のページと、隣から入る線（D17） |
| `sync.onRemoteUpdate` :1190 | 1 本のまま。中で道を振り分ける |

### 3.6 キャンバス（窓・ずらし・はじき・手のひら）

- 窓 = 焦点の前後 R ページ。B-1 の窓（週/日のページ数。B_DESIGN.md:496-513）: iPad 11 縦 5/7・横 7/9、13 縦 5/7・横 7/9、mini 縦 5/5・横 7/9、iPhone 縦 5/5・横 9/15、Duo 内側 5/7（1.4 で確かめる）。
- `contentSize` = 帯 × 倍率。紙が画面より狭い今の中央寄せ（`applyInsets` :1280-1289）は、帯では左右の余白を出さない（帯が画面より広い）。`alwaysBounceHorizontal`（:626）は新しい道では true。
- **ずらす条件**: ペンが離れて落ち着いた後（`isUsingTool`・`isSettling` :408-409）、指が離れ、慣性も止まり、ピンチ中でなく、投げなわの選択が無く、シートが出ていないとき。scroll の delegate に `scrollViewWillBeginDragging`・`WillEndDragging`・`DidEndDragging`・`DidEndDecelerating`・`DidEndScrollingAnimation` を足す（今は無い）。止まりの取りこぼしに備えて 0.5 秒の見張りのタイマー。
- **ずらしの手順**（B_DESIGN.md:194-201）: 受け箱を空にする → 出るページの安全網と保存（**失敗したらずらさない**）→ `pruneHistory` → `SpanComposer` で入るページを足す → `ledger.reload(keepHistory: true)` → `relayout`（B-1 は全部作り直す）→ `contentOffset.x` を「ページ数 × W × 倍率」だけ戻す（11 インチ縦の一覧で週 696 pt・日 396 pt）→ 版つきの `PaperViewport` を同じターンで見出しへ → 入るページの予定と `pagesOpened`。
- **今の守りを残す**: page と layout の id の門（:836）、`resetScroll` の間は画面と台帳を比べない（:1890、:1733）。ずらしでは `resetScroll` を立てない代わりに、ずらしの間は `isApplyingDrawing` を立てて、古い絵と新しい台帳を比べない（`testAPageChangeDuringTheSettleWaitCopiesNothingIntoTheNewPage`、`InkCanvasViewTests.swift:2570` と同じ考えのテストを足す）。
- **はじき**（P-B5 ア）: `scrollViewWillEndDragging` で、一覧の倍率では隣のページの境目に行き先をそろえる。ゆっくりなら止まった所。止まった所がページの端から画面の幅の 6% 以内ならそろえる。
- ◀ ▶: ちょうど 1 ページすべる（境目を真ん中にしていたら、真ん中のまま 1 ページ）。「今日」: 窓の中ならすべる、遠ければ開き直す（今の `revealRect` :1392-1397 を使う）。
- **手のひら**（B_DESIGN.md:354-360）: Pencil が触れている間と離してから 0.5 秒は、`gestureRecognizerShouldBegin` で横の動きの始まりを断る（`InkTouchObserver` の Pencil の数を使う、:1795-1833）。一覧では動き出しに約 24 pt 要る。`majorRadius` の大きい接触を数えない案は【推論】なので、試作で確かめてから入れる。
- 回転・Split View では、止まったときに窓を決め直し、焦点のページを保つ。

### 3.7 画面（題名・remember・評価の印）

- 焦点 = 画面の真ん中の x を含むページ。境目を 6% 越えてから切り替える（§3.16）。題名は今の `PageNavigation.title`（:110-140、`weekStart` を受ける）。`remember()`（:1400-1406）は止まったときの焦点。
- 評価の依頼（1.2.1）: D20。年齢の確かめ（1.2.2）の `ageRangePenDownAt`（:910）と `ageRangeInkIsRecent`（:2401-2407）は、差分の時刻で `lastInkChangeAt` を立てれば今のまま働く。
- 線の予算と上限の案内: D21。ページ id ごとに 1 回（今の `strokeBudgetReached` :933-950、:952-957 の考え方）。

### 3.8 週・日の紙、固定見出し、終日帯

- 週（B_DESIGN.md:297-304）: どの週も 1,400 × 1,920 lu（週のメモが入れば 24 時の下に extra。§5）。見出しは「その週の最初の日の月」。夜中をまたぐ線は斜め。
- 日（B_DESIGN.md:306-312）: 自由メモ extra は窓でそろえる（D16）。上限 6,000 lu はページごと。ダブルタップは何もしない（今のまま）。
- 固定見出し: `PaperRow`（`StickyHeaderView.swift:359-400`）に窓のページの列を原点付きで並べる。
- 終日帯: `AllDayBandEngine` に「日の並び」を受ける口を足し、窓の全部の日をまとめてレーンを詰める（週ごとに詰めると、週をまたぐ予定のレーンが境目で入れ替わる）。レーンの数は横に動いている間は変えず、セッション中は減らさない。
- 予定はページごとに読む（`[pageId: [LayoutEvent]]`、1 回の述語は 4 年未満、焦点を先に、`EKEventStoreChanged` では焦点から順に読み直す。`EventStoreModel` :105-147、`EventKitService` :126-170）。

### 3.9 週の始まり（M7B_CONTRACT §10.6 の 6 行）

1. `SpanPlan` は `weekStart` を受け、番号と id の往復を両方の形で確かめる。
2. `SpanGuard` の書く形の `w-` は月曜と日曜の両方。
3. 見出しは「その週の最初の日の月」。日曜始まりの境目は土曜 → 日曜（並びは「土 │ 日 月 … 土」）。
4. 週の始まりを切り替えるときは `saveAll()` してから新しいセッション。`SpanSession` は形ごとで、**1 つの窓に 2 つの形を混ぜない**（K-11 の 6）。セッションの id にも週の始まりを入れる（今の `canvasIdentity` と同じ）。
5. 古い端末の表に K-11 の行（§6.5）。
6. 週の帯の fixture を日曜でも 1 組（§6.3）。月は 1.3 では 1 ページの道なので、月の帯の fixture は 1.7。

### 3.10 取り消し・投げなわ・消しゴム・予定

- ↶ は窓全体で 1 本の履歴（今の 200 歩、`InkLedger.swift:152`）。ページが窓から出るときは `pruneHistory`。全て消す・消して始める・取り込み・開き直しでは新しいセッション（履歴は捨てる）。
- 投げなわ: 帯の上で選べ、ページをまたいで動かせる（元に墓標・行き先に新しい id、K-2）。**選んでいる間はずらさない。** 動かせる範囲（`LassoGeometry.clampedMoveDelta`、:194-206）は帯の端まで。
- ページをまたぐ操作（投げなわの移動、↶ の写し）は、行き先のページを先に保存する（D8）。
- 消しゴム（.vector）: 隣のページの線も消せる。⑥ の数え方（:1931-1944）・日付のタップの `undoEraserTap`（:1562-1578）・指の点消し `recentAdds`（:1599-1646）は窓全体の台帳で働く。
- 予定ツール・「予定にする」（:1691-1767）: 行き先は `SpanLayout.eventTarget` で決める（段 0）。予定を作った後に線を消すのは、`EventEditorRequest.pageId` が窓の中のページのとき（今は表示中のページと同じとき、:9-19, :1837）。

### 3.11 PDF・書き出し・取り込み

- PDF（「このページ」）: 焦点のページの本物のページの線と、隣のページから入ってくる線（紙の中の部分）を描く（D17）。日の自由メモ（`paperRect` :57-73 の判定）は、入ってくる線も数える。仮想ページは渡さない。入口で `SpanGuard.checkForTransfer`。
- 書き出し（JSON v1）: `saveAll()` の後に store から読む（今と同じ）。形は変えない。入口で `SpanGuard.checkForTransfer`。
- 取り込み: 前に `saveAll()`、後で新しいセッション。入口で `SpanGuard.checkForTransfer`（前置名と `span~` を断る。F2 の「知らないページ id も運ぶ」を壊さないため、書く形の確かめはしない）。

### 3.12 写真モード

- 引数を付けなければ、今の写真と compat11 の `screenshot-*.json` は 1 バイトも変えない（K-7）。
- 新しい引数（B_DESIGN.md:468 の 6 つ）: `--screenshot-span on|off`、`--screenshot-offset-x <ページ数>`（例 −0.5 で境目を真ん中に）、`--screenshot-span-shift`（ずらす前と後の組）、`--screenshot-single-page`（古い版の見え方）、`--screenshot-span-guide`（初めての案内の札）、`--screenshot-week-memo`（週のメモの形）。
- 窓の隣のページの見本は、ページごとに違う id にする（今は週・月・日・年とも、ページに関係なく同じ id、`ScreenshotMode.swift:510-577`）。焦点のページの見本は今と同じ（`testDemoPageIdsMatchTheNavigation`、`ScreenshotModeTests.swift:52` は残す）。
- 写真モードのエンジンは今どおり何もしない版（`SyncEngine.swift:19-30, :58-63`）。

### 3.13 iPhone と iPad

- iPhone の「指でも書く」は既定でオン（`CalendarRootScreen.swift:1171-1176`）。指 1 本で書き、横は 2 本指（PencilKit の `.anyInput`、`InkCanvasView.swift:635, :864-867`）。iPad はオフが既定で、指 1 本で横に動く。
- iPhone の初めて開くページは週（:421）なので、iPhone では初めての案内が一番大事。
- 幅 600 pt 未満の 2 段の見出し（:307, :611-620）は、焦点のページの題名で今のまま。
- アプリは窓 1 つのまま（`UIApplicationSupportsMultipleScenes` を入れない。入れると K-3 が破れうる。`project.yml:88-110`）。

### 3.14 設定「ページ」と初めての案内

- 設定の節の並び（`SettingsScreen.swift:171-184`）で、`inputSections`（:180）と `syncSection`（:181）の間に節「ページ」。1 行「前後のページを横につなげる」（既定オン）。脚注は §8.1 の文。
- 初めての案内（B_DESIGN.md:290-295）: 横につないだ種類を更新後に初めて開いたとき（端末ごと・種類ごとに 1 回）、紙の上の端（終日帯のすぐ下）に札。8 秒で消える。触れても消える。写真モードと設定オフでは出さない。文は §8.1。

### 3.15 重さの守り（B-1 の分）

- ずらしは止まった後だけ。書いている手は止めない。
- 読む前にファイルの大きさから本数を見積もる（`SpanPlan.estimatedStrokes`）。読んだら実数に置き換える。
- 窓の線の合計が上限（D18）を超えたら、段 2: その種類だけ 1 ページの道に戻し、1 回だけ案内（§8.1 の文）。段 1（見るだけの外側）は 1.8 で。
- 試作版で測る（§4.6）。

### 3.16 決めた数字（KitChecks か XCTest で固定）

| 数 | 値 | 元 | 固定する所 | 試作で変えうる |
| --- | --- | --- | --- | --- |
| 焦点の切り替えのヒステリシス | ページの幅の 6% | B_DESIGN.md:181（5〜8%） | KitChecks（SpanPlan） | はい |
| はじきでそろえる近さ | 画面の幅の 6% | :276 | KitChecks | はい |
| 手のひらで横の動きを断る時間 | Pencil を離してから 0.5 秒 | :355 | XCTest | はい |
| 一覧での動き出し | 約 24 pt | :356 | XCTest | はい |
| 初めての案内 | 8 秒 | :291 | XCTest | いいえ |
| 多すぎる削除 | 1 回に 50 本を超える、または窓のあるページの生きている線の半分以上かつ 20 本以上 | :213 | XCTest | はい（試作で測る） |
| 窓の線の上限 | iPad 20,000 本、iPhone 12,000 本 | :522、P-B9（1016 本） | KitChecks | はい（試作で測る） |
| 本数の見積もり | ファイルの大きさ ÷ 0.25 KB | :519 | KitChecks | いいえ |
| 保存の予約 | 1.5 秒（今と同じ） | `CalendarRootScreen.swift:2520-2527` | XCTest | いいえ |
| 見張りのタイマー | 0.5 秒 | この契約 | XCTest | いいえ |
| 先読みを外へ出す条件 | 1 ページの読み込みが 16 ms を超える | D6 | 試作の計測 | — |

- 試作で数を変えたら、M7C.md に元の数と測った値を書き、KitChecks とテストの数を同じ commit で直す。

---

## 4. 段 0（B-1 を作り始める前の分）

段 0 は B_DESIGN.md:604 と :913 のとおり 1.3 の中。今の木には予定のドラッグも予定の ↶ も無い（`isDraggingEvent`・予定の取り消しは grep で 0 件）ので、予定の 2 つは「口」と「印」だけ（D23）。

### 4.1 紙の外の点を切らない・捨てない約束（1.3 から全部の版）

- 紙の外の点を持つ線を、**読み込み・merge・書き戻し・投げなわ・取り込みのどこでも捨てない・切らない**（B_DESIGN.md:420）。座標の上限 ±100,000 lu（`InkStroke.swift:25`）の中なら、点は持ち主のマスからの相対のまま残す。
- 捨ててよいのは、今と同じく「その端末で新しく書いた、中心が帯（1 ページの道では紙）の外の線」だけ（M4C-25、`InkCanvasView.swift:1979-2017`）。
- 古い端末の投げなわは、紙の外の枠を内向きにしか動かさない（`LassoGeometry.swift:191-206`）ので、押し戻しや切り取りは起きない（【コード】）。

### 4.2 はみ出す線の fixture（§6.3 で読む）

- 週は左へ 300 lu（日曜の夜 → 前の週へ）、日は右へ 300 lu と extra の帯（自由メモ）、1.3 では使わないが後の版のために月（右へ 250 と memo）、年（12 月から右へ 288、1 月の x < 0）も同じ commit で入れる（B_DESIGN.md:405, :686）。1.3 から後のどの版でも緑であること。

### 4.3 予定の行き先を「ページ・マス」で受ける口

- `SpanLayout.eventTarget(at:)` は、点の下のページ id と局所座標を返す純粋な関数。窓 1 ページのときは、今の `layout.eventRange`（週 `WeekLayoutEngine.swift:151-157`）と同じ答え。
- 1.3 では、予定ツール（`eventRectFinished` → `newEventPlan`、`CalendarRootScreen.swift:1691-1727`）と「予定にする」（`convertSelection` :1757-1767）が、新しい道でこの口を通す。境目をまたいで予定ツールで描いた枠は、枠の中心のページの日で作る。
- 1.5（指で予定）は、予定のドラッグの行き先をこの口で受ける（別のページでもよい形）。

### 4.4 取り消しの組の印

- 台帳の履歴の 1 歩に「触れたページ id の組」と「組の印（`group: UUID?`）」の場所を作る。`pruneHistory(touching:)` は、触れたページが窓から出る歩と、それと同じ組の歩を一緒に捨てる。
- 1.3 で印を付ける操作は、ページをまたぐ投げなわの移動だけ（元と行き先の 2 ページ）。1.5 で予定の取り消しと手書きの組に使う。
- 1.5.1 の「予定と一緒に動く手書き」は台帳の `moveStrokes`（:495-522）を通す約束を、M7_PLAN §4.4 に書いた（行き先が別のページでもよい形）。

### 4.5 見本の画像（11/20 ごろ。本人に 1 枚の確認ページで）

- 撮るもの（CI の写真モード、§3.12 の引数）:
  - 週と日の帯で、境目を真ん中にした写真（またぐ見本の線つき）: iPad 11 縦・横、mini 縦・横、13 縦・横、iPhone 縦・横。
  - 日曜始まりの週の帯 1 枚。
  - iPhone 横の一番縮めた形（P-B6 ア、今のまま）。
  - 一覧（P-B10 ア、今の 1 ページまで）。
  - 古い版の見え方（`--screenshot-single-page`、iPhone と iPad）。→ §6.5 と新機能の文の 1 文の根拠。
  - 初めての案内の札。
  - 週のメモの形（罫線だけ／日の自由メモと同じ方眼の 2 つを並べて。既定は罫線だけ）。
- 月の 3 通り（P-B3）と年のそろえは、1.7・1.8 の契約の前に撮る（0c-20）。
- 確認ページは全部の写真がそろってから 1 回で書き、頭に「見本の画像（1.3 の前）・commit」を書く（書きかけの HTML は本人の画面に開くため）。
- 本人の答えが無くても進める（おすすめのまま）。

### 4.6 試作版（11/21 ごろ。TestFlight の内部テストだけ）

- 中身: 週の帯（窓・ずらし・はじき・境目の書き込み・手のひらの手当て）と重さの計測（数を画面の隅に出す）。週のメモの欄も入れる。iPhone 横の「今のまま／上限あり」の切り替え。
- 測ること（B_DESIGN.md:581 に足した）: 窓 2,500・10,000・25,000 本の差し替えの時間・ちらつき・メモリ、最大倍率 × 一番広い窓（iPhone 横の日、紙の高さ 8,400 lu × 15 ページ）の描画とメモリ、ずらした瞬間のメモリの山、ペンを離すたびの主スレッドの止まり、消しゴムの 1 回の変化で消える線の数、1 ページの読み込みの時間（D6 の 16 ms）。
- **本人のデータと iCloud から作りで切り離す**（B_DESIGN.md:582-586、D13）:
  - (a) ページ id は `proto-` で始まるものだけ（`SpanGuard.prototype` が `proto-` 以外を断る）。
  - (b) 一時フォルダの `InkPageStore(directory:)`・`SyncStateStore`・`InMemoryCloudDatabase` で作り、`start()` しない `SyncEngine`。試作の画面からは `SyncEngine.shared` と本物の `InkPageStore` が見えない作り（引数で渡す）。予定は写真モードの見本の予定だけで、EventKit に書かない。
  - (c) `sync.onRemoteUpdate` には触らない（1 本だけの差し替え式、`CalendarRootScreen.swift:1190`）。
  - XCTest `PrototypeIsolationTests`: 試作を開いて書いて閉じても、本物の store にファイルが増えない・`shared` の `save` と `pageOpened` が呼ばれない・`shared.onRemoteUpdate` が同じまま。
- コンパイルの条件 `SPAN_PROTOTYPE`（D12）。入口は 設定 › 情報 の一番下の「横につなげる試作」（試作のビルドだけ）。ふつうの画面は 1.2.3 と同じ（試作のビルドの時点の `r13` は、ふつうの画面のコードを変えていないこと。§12.2）。
- 版は 1.3、ビルドは次の run（今の見込みは 24）。後で本物の 1.3 を出すときに取り違えないよう、試作のビルドの番号を M7C.md に書き、提出のスクリプトは版に付けるビルドが試作の番号でないことを確かめる。試作のビルドは、次のふつうのビルドが TestFlight で使えるようになって（VALID）から期限切れにする（先に切ると本人のアプリが開けなくなる、R1_2_2.md:928）。
- **本人の手順**（試作を渡すときにこのまま送る）:
  1. TestFlight で「てがきカレンダー」の試作のビルドを入れます（ふつうの画面は今の版と同じです）。
  2. 設定 › 情報 のいちばん下の「横につなげる試作」を開きます。見本の週が出ます。ここで書いたものは、どこにも保存されず、iCloud にも送られません。
  3. 試してください: ① 指で横にすべらせる・はじく（となりの週で止まるか）② Apple Pencil で書きながら手のひらを紙に置く（紙が横に動かないか。一覧でも、拡大しても）③ 境目をまたいで書く ④ 右上の「線の数」で 2,500・10,000・25,000 本を選んで、横に動かしたときの引っかかりやちらつき ⑤ iPhone を横にして一番縮める ⑥ 週の下へすべらせて、メモ欄に書く。
  4. 気になったことがあれば教えてください（はじいたときの好み、手のひらで紙が動いたか、重さ）。答えが無ければ、おすすめのまま進めます。
- だめなとき（ちらつく・重い）は、B_DESIGN §6.3 の「固定の座標」の案に寄せてから B-1 の本体に入る。その判断は M7C.md に書き、§0 のまとめの日にちを直して本人に知らせる。

---

## 5. 週の下のメモ（1.3 の最後の部品）

### 5.1 関門（1/15）

- 横につなげる本体（§1.5 の表の 1〜12）が 2027-01-15 までに `r13` で全部のジョブ緑にならなければ、週のメモは作り始めず、1.4 の後の小さな版（1.4.1。ペンの色・メモ欄の紙と同じ版）へ回す（PLAN_WEEK_MEMO.md:11-12, :50-51）。
- 1/15 にメモを始めた後で 1.3 が 2/15 に間に合わなくても、メモは横つなぎと一緒に出る。
- 試作版と見本の画像には、関門の前でもメモを入れる（形を選んでもらうため）。試作は `proto-` の中だけなので、本人のデータに週のメモは残らない。

### 5.2 中身（PLAN_WEEK_MEMO.md:29-61）

- 新しいページは作らず、`w-` のページの中のマス `extra`（K-1 の安全な名前）。線・`v`・書き出し v1 は変えない。凍結の InkModel は変えない。
- `PaperGrowth.tail` に週を足す（:92-121）。`WeekLayoutEngine` に extra（高さ = `PaperGrowth.tailHeight`、空でも 6,000 lu）。週の紙は 1,400 × 約 7,920 lu。
- 週の一覧は 24 時間（1,920 lu）に直す（K-6。直さないと一覧がとても小さくなる）。
- `WeekPaper` の今日・土日の色と時刻の列の線は 24 時で止める。形は罫線だけの白紙（Q2 A）。
- メモの中では予定を作らない（日の自由メモと同じ守り）。
- PDF は、メモに手書きがあるときだけメモを含める（隣から入る線も数える、D17）。
- **2 本の道の両方で作る**（設定オフでも週の紙の形は 1.2.3 と変わる。台帳とキャンバスの道は同じ）。新しい道では窓の中で下の端をそろえる（D16、日と同じ部品）。
- 週の始まりの形ごとに別のメモになる（K-11 の 6。切り替えて戻すとまた出る）。
- 1.2 までに投げなわで 24 時の下へ動かした週の `grid` の線（あれば）は、メモ欄の上に見えるようになる（線は時間の欄のまま。消えない）【未確認】。互換の fixture に 1 本足す（§6.3）。
- 文: 画面の新しい文は要らない見込み（「自由メモ」と予定を作れないお知らせは 10 言語の訳がある）。SUPPORT（日本語・英語）の「日のページの 24 時の下の自由メモ」の 2 段落を「日と週のページの」に直し、英語は逆翻訳で確かめる。`tools/l10n/source/app-U.json` の comment（:2271, :2287）の「日のページの」を直す。新機能の文に 1 行。

---

## 6. データ互換

### 6.1 保存の形（変えない）

- 新しいページ id・マス名・線の項目を作らない。`v` と書き出し `tegaki-app-export` v1 を上げない（K-5）。週のメモの `extra` は K-1 の一覧にある名前。
- またいだ線は、外接矩形の中心の x が入るページ（半開区間、ちょうどは右）に 1 本で保存（D15）。点は持ち主のマスからの相対で、切らない（§4.1）。
- **仮想の名前（`span~…`・`<pageId>|…`）は端末のメモリの中だけ。** 保存（`PageSlot.persist`）・取り込み・書き出し・PDF の入口で `SpanGuard`（Release でも）。違えば保存せず、今の「手書きを保存できませんでした」を出し、記録を残す。
- 守る理由（契約に書く）: 前置名のマスが同じ id のまま本物のページに漏れると、F4（`InkPage.swift:207-229`）で「マス名が辞書順で大きい方」が勝つ。`w-…|grid` > `grid`、`m1-…|2026-11-01` > `2026-11-01`、`y-…|01-20` > `01-20` なので、漏れた方が merge で全端末に勝ち、どの版のレイアウトにも無いマスなので描かれない（F1）。merge では元に戻らない。仮想の id が `PageSlot` に混ざると、`pickPageId`（:236-240）で `w-`・`y-` のページの id が `span~…` に化ける（`'s' < 'w', 'y'`）。
- 書く形（`SpanGuard.checkForSave`）: ページ id が `^(d-\d{4}-\d{2}-\d{2}|w-\d{4}-\d{2}-\d{2}|m1-\d{4}-\d{2}|y-\d{4})$` に合い、`w-` の日が月曜か日曜。`strokes`・`deleted`・`unknownStrokes` の鍵と `cell` に `|` が無く、`span~` で始まらない。前置名の見分けは `^(?:[dw]-\d{4}-\d{2}-\d{2}|m1-\d{4}-\d{2}|y-\d{4})\|`（B_DESIGN.md:246-251。実在の形 20 個で 0 件、前置名 7 個は全部引っかかる【実測、V2Probe §5】）。

### 6.2 K-1〜K-11 とこの版での当てはめ

規則の正文は [M7_PLAN.md](M7_PLAN.md) §1.3。

| 規則 | 1.3 での当てはめ |
| --- | --- |
| K-1 `allday` で始まる名前を使わない | 新しい名前は無い。週のメモは `extra`（安全な名前）。KitChecks で `BandMigration.isBandCell(extra) == false` を固定 |
| K-2 同じ id の線を付け替えない | ページをまたぐ投げなわの移動は、行き先に新しい id、元に墓標。仮想の id（前置した id）は保存の前に外し、同じ生の id が 2 ページにあれば 2 本として扱う |
| K-3 1 つのページに 2 枚のキャンバスで書かない | 窓の各ページは 1 つのセッションにだけ属す。書き戻しはページごとの差分で、丸ごと上書きしない。2 本の道で同じページを同時に開かない。窓は 1 つ（シーンは 1 つ） |
| K-4 マスの意味を変えない | 変えない。日・週の extra のそろえは位置と高さだけ |
| K-5 線に項目を足さない、`v`・v1 を上げない | 足さない・上げない。InkModel の既存の 7 ファイルは 1 バイトも変えない |
| K-6 伸びる紙の一覧は固定部分 | 帯の一覧も伸びる欄を除いた高さ（日 2,400、週 1,920（週のメモが入ったら）） |
| K-7 互換テストは 1.0 のコードで | **必須**（§6.3） |
| K-8 古い端末での見え方を新機能の文に | §6.5 を新機能の文と SUPPORT に（§8.3） |
| K-9 線の予算 | **持ち主のページで数える**（窓全体ではない）。15,000 本の案内・19,000 本の拒否は、そのページの id で出す（D21） |
| **K-10 名前の文字（1.3 で足す）** | 新しいページ id とマス名に `\|` と `~` を使わない。線の id に `\|` を使わない（Web の線の id には `~w1` の付いたものがあるので、線の id の `~` は禁じない）。仮想 id `span~…` と前置した名前 `<pageId>\|…` は端末のメモリの中だけで、Release でも保存・取り込み・書き出し・PDF の入口で確かめる。KitChecks で固定（`PageNavigation.pageId`・`CellKey` の作り方が `\|` と `~` を作らない） |
| K-11 週の始まりとページ | §3.9。1 つの窓に 2 つの形を混ぜない。週のメモも形ごとに別 |

### 6.3 K-7 の互換テスト（必須）

- 新しいフォルダ `TegakiKit/Tests/Fixtures/compat-span/` に次を置く（書くのは新しいコード）:
  1. はみ出す線 4 種（§4.2）。
  2. ページをまたぐ移動（元に墓標・行き先に新しい id）。
  3. 日の extra の帯をまたぐ線（自由メモ）。
  4. 週のメモの `extra` の線（週のメモの段で）と、投げなわで 24 時の下へ動かした週の `grid` の線。
  5. 日曜始まりの週の帯のはみ出す線（`w-<日曜>`）。
  6. 月の重なる日の 2 つのマス（後の版のために今入れる）。
- 読むもの:
  - 1.0 の写し（`TegakiKit/Tests/Compat10`。`drawnIds`・`lassoCandidates`・merge・`BandMigration`・書き出しの往復）: 線の数・座標・マス名・墓標・知らない項目が変わらない。1.0 が書き戻すバイトは同じ。
  - 本物の 1.0（compat-v1.0 のジョブ）と、本物の <1.1.1>（`tools/weekstart-compat` の流れ）: 同じ。1.2.3 のデータのコードは `SyncEngine.swift` を除いて <1.1.1> と同じバイト（`DATA_1_1.sha256`）なので、相手は 1.0 と <1.1.1> で足りる（0c-33）。
  - 月曜の形の fixture（1〜4、6）: CI で compat11 の一時フォルダに写して、`RunReal`・`RunFrozen`・`Real10LedgerTests` に読ませる（`Compat10Checks` はフォルダの `*.json` を全部読む、`Compat10Checks.swift:73-121`）。
  - 日曜の形の fixture（5）: `Real10LedgerTests` は `w-` に月曜のレイアウトを作る（`tools/compat10/AppTests/Real10LedgerTests.swift:73-91`）ので、同じフォルダに置かない。新しいターゲット `CompatSpanTests`（`Compat12Tests` の形）と weekstart-compat の形で読む。
- compat11・Compat10・Compat10Tests・CompatFixtures・`tools/compat10/EXPECTED_MIN`（225）は 1 バイトも変えない。新しい fixture が欠けたことは `CompatSpanTests` が自分の一覧（`compat-span/MANIFEST`）で見つける。
- 1 ページの道が変わっていない証拠: `InkLedgerTests.testLedgerWritesTheCompatShapes` の `ledger-*.json` と、写真モードの `screenshot-*.json` が、作り直さずに compat11 と同じ（`build.yml:321-330`、`Compat10FixtureTests.swift:10-31`）。
- 書き出し → 取り込みの往復で `==`。

### 6.4 凍結の表の作り直し（`tools/compat10/DATA_1_1.sha256`）

- **前の基準**: 43fe366 の 18 行（17 行は 1.1.1 のバイト、`Sync/SyncEngine.swift` の行だけ 1.2.3 のバイト。R1_2_3.md:134-136）。r13 で `shasum -a 256 -c` は 18 行とも OK。
- **1.3 で変えてよいファイル**（この表に無いものは 1 バイトも変えない）:

| ファイル | 変えてよい所 |
| --- | --- |
| `Sources/TegakiCalendar/Ink/InkLedger.swift` | §3.3 の 5 か所と履歴の組の印 |
| `Sources/TegakiCalendar/Ink/InkCanvasView.swift` | §3.6・§3.4・D21・「手書きの紙」をキーに（D25）・知らせの引数 |
| `Sources/TegakiCalendar/Sync/SyncEngine.swift` | 2 つの口を足すだけ（§7）。今の関数の中は、`onRemoteDelete` を呼ぶ 1 行のほかは変えない |
| `Sources/TegakiCalendar/Ink/InkOverlayView.swift` | 帯の上の投げなわに要るときだけ（動かせる範囲の口） |

- **変えないもの**: InkModel の 7 ファイル、`Persistence/InkPageStore.swift`、`Sync/InkPageRecord.swift`、`Ink/InkSnapshot.swift`、`Ink/InkTools.swift`、`Ink/InkTouchObserver.swift`、`Ink/InkTrace.swift`、`Ink/PencilInteraction.swift`。
- **手順**:
  1. 上の表のファイルを変える commit で、そのファイルの行も同じ commit で書き直す（CI を緑に保つ。ほかの行は `shasum -c` が守る）。lint の L-7・L-8・L-13・L-14 は表のファイルを読まない（`tools/l10n/lint.py:51, :663-679`）ので、表から外さないことで lint の範囲も今のまま。
  2. 書き直すたびに、リードが diff を見て、許した所だけが変わったことを確かめる（M7C.md に commit と理由を 1 行）。
  3. 提出する commit で、その commit の git の中身から、根からのパス・辞書順・注記の行なしで表を作り直す。新しい `TegakiKit/Sources/InkModel/SpanGuard.swift`・`SpanComposer.swift` を足す（20 行）。1.4 はこの表で守る。
  4. CI の段の名前を「Data code frozen (re-based in 1.3)」にし、`build.yml:175-178` の注記を直す。基準の commit は M7C.md に書く。
- 2/15 の決まりで Duo の版が先になったら、この作り直しはその版の上でやり直す。1.2.4（§9）を main に入れたら、`r13` に main を取り込み、表の基準が変わっていないことを確かめる（1.2.4 は表のファイルを変えない）。
- 1.4.1（ペンの色、PLAN_PEN_COLORS.md:103 の `PencilInteraction`）は、この表を作り直した後に、その版の契約で変えてよいファイルを足す。

### 6.5 古い端末と Web 版での見え方（許す範囲）

| 変わること | 古い版（1.0〜1.2.3）の端末で | 気をつけること |
| --- | --- | --- |
| ページをまたいで書いた線 | 保存されたページにだけ出る。もう一方のページには入ってくる部分も出ない。iPhone の一覧では紙の端の先は画面の外で切れて見える。iPad の一覧で余白の上に出るか切れるかは【未確認】（§4.5 の写真で確かめる）。古い版の PDF では紙の端で切れる | 消えない・壊れない・動かない（1.0 の写しで確かめた、B_DESIGN.md:405）。古い版で消すと新しい版でも消える（墓標） |
| 週の下のメモ（`w-` の `extra`） | 見えない・残る（F1）。PDF に出ない。「全て消す」では消える | K-8 |
| 日曜始まりの週の帯 | 日曜のページは開かない・運ぶ（F2） | K-11 |
| 設定オフの端末（1.3） | 古い版と同じ見え方 | 新機能の文と脚注に書く |

- Web 版はアプリの線を読まない（B_DESIGN.md:413。Web のリポジトリはこの作業場所に無く【未確認】）。Web からの取り込み（4 種、`WebImport.swift`）も変わらない。Web 版は変えない。

### 6.6 今ある穴 H1〜H3（1.2.3 のコードを読んで見つけた。実測はしていない）

- **H1 他の端末の「全て消す」が戻ってくる**: 記録の削除が届くとエンジンはファイルを消して `onRemoteUpdate(InkPage.empty)` を呼ぶ（`SyncEngine.swift:759-771`）が、画面は `merge(page, 空) == page` で早く帰る（`CalendarRootScreen.swift:1581-1592`）。メモリのページは線を持ったまま残り、次の保存でページ丸ごとが iCloud へ戻る。**直し（2 本の道）**: `onRemoteDelete` で、そのページを空にし、そのページの保存の予約を取り消し、↶ のそのページの分を捨てる。新しい道では、キャンバスがそのページを空にしたと確かめるまで、そのページに安全網の merge をかけない（外から来た版の数で順を守る）。
- **H2 「消して始める」の前に保存の予約を止めていない**: `chooseAccount(.eraseInk)`（:2130-2141）は予約を止めずに `await sync.resolveAccountChange` に入る。その間に 1.5 秒の保存が走ると、前のアカウントのページが新しいアカウントへ送られうる。**直し**: `await` の前に予約を止める（新しい道は `cancelAll()`）。
- **H3 「全て消す」「消して始める」の後も ↶ が残る**: キャンバスの識別子は変わらず、`update(from:)` は `keepHistory: true` で読み直す（`InkCanvasView.swift:857-861`、`InkLedger.swift:417-427`）。空のページには墓標が無いので、↶ で消した線が同じ id で戻り、送られる。**直し**: 1 ページの道は `canvasIdentity` に画面の番号（D7）を足してキャンバスを作り直す。新しい道は新しいセッション。
- テスト: §10.2 の `ScreenEraseTests`。

---

## 7. 同期（1.2.3 の約束を守る）

- 記録の形・`InkPageStore`・`InkPageRecord`・`state.json` の形は変えない。
- `pagesOpened(_ pageIds:)`: `pageOpened`（:185-203）と同じ門を持つ。呼んだときと走るときの両方で `!needsAccountCheck`（G2、:196, :812）、ページごとの 30 秒の冷却、epoch を要求の前に取り後で確かめる（`checkEpoch` :513-515）、裏にいる間は `checkStillFresh`。仕事は `enqueue` か `spawn` を通す（素の `Task` は使わない。`waitUntilIdle` が数えるため、:424-426）。`fetchRecords` は名前をまとめて 1 回（無い記録は結果に入らないだけ、`CloudKitDatabase.swift:172-210`）。結果は今の `mergeRemote`（:779-806）に 1 件ずつ渡す。
- `onRemoteDelete`: 記録の削除の扱い（:759-772）で、今の `onRemoteUpdate(empty)` の **後に** 呼ぶ。今の `onRemoteUpdate(empty)` は残す（`test11DeletedNamesRemoveTheFile`、`SyncEngineTests.swift:341-356` は緑のまま）。削除を起こすのは今も `cloudErase` だけ（:952-990）。
- 何もしないエンジン（写真モード・テストの宿主、:19-30）では、2 つの口とも何もしない。
- 新しいテストは M4_CONTRACT §8.2 の表の **54 番から**（§10.2）。`SyncEngineTests` の 20 回くり返しの段（`build.yml:364-389`）で一緒に回る。`TestSleeper` の注意（2 本以上の sleep を止めたまま pause しない、`advance` を 2 つのタスクから同時に呼ばない。R1_2_3.md:157-162）を守る。
- 1.2.3 のテスト（M4_CONTRACT §8.2 の 37〜53）と、本人の確かめ（R1_2_3 §9 の 2〜6）は 1.3 でも全部通す（§11.3 に入れた）。

---

## 8. 文字・訳・App Store

### 8.1 新しい日本語の文（固定。キーは各持ち主の元に。今の日本語の文は 1 字も変えない、L-3）

| # | 場所 | 日本語（固定） | 持ち主 |
| --- | --- | --- | --- |
| N-1 | 設定の節の題 | ページ | U |
| N-2 | 設定の行 | 前後のページを横につなげる | U |
| N-3 | 設定の脚注 | 週と日のページで、前後のページが横につながり、境目をまたいで書けます。月と年は、次の版から順に対応します。オフにすると、今までどおり 1 ページずつになります。オフにした端末では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。 | U |
| N-4 | 初めての案内（週・「指でも書く」オフ） | 前後の週が横につながりました。指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | U |
| N-5 | 初めての案内（週・「指でも書く」オン） | 前後の週が横につながりました。2 本指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | U |
| N-6 | 初めての案内（日・オフ） | 前後の日が横につながりました。指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | U |
| N-7 | 初めての案内（日・オン） | 前後の日が横につながりました。2 本指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | U |
| N-8 | 段 2 の案内（1 回） | このページは線がとても多いので、横につなげずに 1 ページずつ表示しています。書いたものはそのままです。 | U |
| N-9 | 読み上げ（`--screenshot-probe` だけ、`InkCanvasView.swift:679`） | 手書きの紙 | L（D25） |

- 保存に失敗したときは今の文（「手書きを保存できませんでした」）をそのまま使う。
- 試作の文（「横につなげる試作」・「線の数」など）は ja だけのキー（`jaOnly`、L-2）。訳さない。
- 週のメモの分は新しい文なし（§5.2）。

### 8.2 訳と逆翻訳（X・R）

- 流れ: リードがキーを固める宣言 → 9 言語の訳（X、`docs/i18n/GLOSSARY.md` に従う）→ 元を見ない逆翻訳（R、`docs/i18n/back`）→ `REVIEW.md` の × を 0 に → `lint.py`（L-1〜L-14）・`build.py --check`・`baseline.py --check` が全部緑。
- 量の見込み: 画面の文 9 キー × 9 言語 ＝ 81 件と、店の文（§8.3、§8.4）。M7B-18 の「はい」は 1.2 の分だけなので、店に入れる前に言語ごとの確認表を本人に見せて「この内容で入れてよい」をもらう（M7B_CONTRACT.md:1089）。確認表は 15 ロケール（ja を除く）で、全部そろってから 1 回で書く。
- 日本語の基準（J-1）は 516 字に新しい 9 字を足した数（R1_2_3.md:18）。

### 8.3 新機能の文（16 ロケール。ja はこの文、ほかは訳。最後の行は AI の訳の断り（ja 以外））

> ・週と日のページが、前後のページと横につながりました。指で横にすべらせると、となりの週（日）が続いて出てきます。境目をまたいで、そのまま書けます（「指でも書く」がオンのときは、2 本指で横に動かします）。
> ・週のページにも、24 時の下に自由メモができました。（週のメモが入ったときだけ）
> ・設定の「ページ」で、横につなげるのをオフにできます。
> ・ほかの端末で手書きを全て消したとき、この端末に残っていた手書きが iCloud に戻ってしまうことがあったのを直しました。
> ・iPad と iPhone の両方をこの版にしてください。古い版では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。古い版でその線を消すと、こちらでも消えます。（ここに iPad での見え方の 1 文を、§4.5 の写真の後に足す）

- 無い改善は書かない（R1_2_2.md:694）。4,000 字まで。en-GB・en-AU・en-CA は en-US の写し、fr-CA は fr-FR の写し（`docs/store/locales.json`）。
- プロモーションテキストは新しい版で空になるので、今の文を入れ直して読み戻す（`docs/store/README.md:12`）。

### 8.4 審査メモ（`docs/store/review-note.txt`。英語が主で日本語の要約、4,000 バイトまで）

- 書くこと: 週と日のページで、横にすべらせると前後のページが続き、境目をまたいで書けること。確かめ方（週のページを開き、指で横にすべらせる。日曜と月曜の境目をまたいで Apple Pencil か指で書く。設定 › ページ で切り替える）。データの扱い（収集なし）・手書きの保存先（端末と本人の iCloud）・購入・年齢区分は変わらないこと。「記録」のシートは TestFlight と審査のビルドだけで日本語のまま（今の文のまま）。

### 8.5 App Store の写真（D26）

- 先頭に「週の境目をまたいで書いた見本」を 1 枚（`--screenshot-span on --screenshot-offset-x -0.5`、`--screenshot-store-ink` の見本の字）。3 つの枠（13 インチ・6.9 インチ・6.3 インチ）× 16 ロケール。
- `store-shots.yml` に ja の組を足す（今は ja を撮らない、`store-shots.yml:12-17`）。今の写真は残す。価格と Apple の商標は入れない（M6.md §4.6）。
- 本人に確認ページで見てもらってから入れる（§8.2 の確認表と同じページ）。

### 8.6 M7_PLAN の注の各項目（既定の決定）

| 項目 | 既定 | 理由 |
| --- | --- | --- |
| 主言語を en-US に替える案（M7B_CONTRACT §11.2） | **替える**。11/16 の後に最初に作る Connect の版（1.2.4 か 1.3）で。公開の後、日本・米国・オランダの App Store の表示を読んで確かめる | 訳の無い国で日本語ではなく英語が出る。日本は ja の訳があるので変わらない見込み【未確認】。1.2 で en-US は承認済み |
| nl-NL・sv（M7B_CONTRACT §11.2） | **足さない** | 主言語を en-US にすれば英語が出る。足すと 2 ロケール分の確認と維持が増える。ロシアの店頭の結果は記録に無い（M7B.md:2012） |
| 0-37 凍結した Ink の日本語 6 件 | D25（1 件はキーへ、5 件は例外のまま、理由の字を直す） | `InkCanvasView.swift` は 1.3 で変わる。`InkTrace.swift` は変えずに済む |
| 0-38 英語の規約のページ | **済み**（1.2.1、`LegalLinks.swift:10`）。1.3 では L-9 が緑のままであることだけ | M7_PLAN の注は古かった |
| P-B9 の答え（1016 本・年 152 本、M7B.md:1937） | 窓の線の上限の目安（D18）。もう 1 台の本数と、古い版のまま使う期間は、TestFlight の確かめ表の最後に「分かれば」で聞く（答えが無くても進める） | 答えは本人のいつもの端末の 1 台分だけ |
| CRA（M7B_CONTRACT §11.6） | 1.3 では当たらない（本体は 2027-12-11 から、それより前に出した製品は実質的な変更をしなければ当たらない）。報告の義務（2026-09-11 から）は続く。EU で売り始めた後に 2026-12-09 より後に出す版は、新しい製造物責任指令の対象になる（データの破損も損害、規約で制限できない。M7B_CONTRACT.md:2015-2018）。見直しは 2027 年 12 月より前の版の契約で | EU は 2026-11-09 の時点でまだ売っていない（R1_2_2.md:955） |
| 1.2 から持ち越した細かい訳の直し | 1.3 には入れない（§1.6） | 2/15 を守る |

### 8.7 SUPPORT（日本語・英語。W。公開の日に Web へ。本人に全文を見せて「はい」）

- 「マスをまたぐ手書き」（`docs/SUPPORT.md:210` あたり）に、週と日のページの横つなぎ・古い版での見え方・設定のオフを足す。
- 「自由メモ」（:155, :159 あたり）の 2 段落を「日と週のページの」に（週のメモが入ったとき）。
- 日曜始まりの古い端末の案内（M7B.md:1958 の持ち越し）は 1.3 では足さない。
- 英語は逆翻訳で確かめる。Web 版のアプリは変えない（サポートのページの文だけ）。

---

## 9. 年齢区分の 2 問と、年末までの期限

### 9.1 年齢区分の新しい 2 問（期限 2027-01-12）

- Apple が 2026-11-16 から足す 2 問（Shared Location・Dating and Relationships）に、**2 問とも「いいえ」**。1.2.1〜1.2.3 では API に無く、答えていない（R1_2_3.md:258-263, :334）。1.3 は早くても 12 月中旬、ふつうは 1 月下旬に提出なので、1.3 だけでは期限に間に合わないおそれがある。
- 手順:
  1. **11/16〜11/20**: 版を作らずに、Connect の API で、公開中の App 情報の年齢区分に 2 問を「いいえ」で入れられるか試す。入れられたら読み戻して 4+ のままかを確かめ、M7C.md に記録して終わり。
  2. API でだめなら、本人に Connect の画面で 1 回操作をお願いする（R1_2_3 §8 の手順。画面の言葉は【未確認】で、その時の画面に合わせて書き直して渡す）。画面でも「新しい版を作ってください」と出たら 3 へ。
  3. **12/9 に決める**: 1.3 を 12/16 までに提出できる見込み（§12.2 の早い道）なら、1.3 の提出で答える。そうでなければ、**小さな版 1.2.4** を main から作り（ブランチ `r124`。アプリのコードは 1.2.3 と同じで、版の番号だけ）、12/16 までに提出して答える。主言語の en-US（§8.6）も 1.2.4 で替える。新機能の文は正直に書く（「App Store の情報を更新しました」程度。無い改善は書かない）。
- 1.2.4 の本人の言葉: 「1.2.4 を審査に提出して良い」「1.2.4 を公開して良い」（と「まとめて良い」）。TestFlight の確かめは版の番号を見るだけ（コードが同じため）。
- 1.2.4 を main に入れたら、`r13` に main を取り込む（凍結の表のファイルは変わらないので、表の基準は同じ）。1.3 の版の番号は 1.3 のまま。

### 9.2 米国の年齢の法律（2027-01-01、カリフォルニア州・アラバマ州）

- 1.2.2 の約束どおり、12 月に Apple の発表を見直す（R1_2_2.md:12, :758）。直しが要れば、1.2.4 に入れられる大きさかを 12/9 に一緒に決める。要らなければ M7C.md に「見直した」と記録する。

### 9.3 中国の 2027 年の祝日データ

- 通知は 2026-11-05 に出た。データに入るのは `python-holidays` の次の版を取り寄せた後で、取り寄せは毎回本人の了承が要る（M7B_CONTRACT.md:2251、M7B.md:1522, :1590）。
- 既定: 1.2.4 を作るときだけ、その時点で `python-holidays` の新しい版に 2027 年の中国の祝日が入っていれば、本人に取り寄せの了承を聞いて 1.2.4 に入れる（祝日のデータだけで、アプリのコードは変えない）。1.2.4 を作らないときは 1.3 に入れる（1 月中は、中国の人に 2027 年の祝日が「発表前の推定」と出る）。

### 9.4 Apple の年末の審査

- 年末年始は審査が遅れることがある【未確認】。12/19〜1/4 には審査を待つ工程を置かない。本人のサポートの休み（2026-12-29〜2027-01-03、`docs/SUPPORT.md:215`）にも頼らない。

---

## 10. テスト・CI・写真

### 10.1 KitChecks（K。この Mac の `swift run KitChecks` と CI）

- 新しい節「span (1.3)」を「compat with 1.0 (K-7)」の節の後に足す（`SpanChecks.swift`）:
  - `SpanPlan`: 4 種の番号と id の往復（年・月・週の境目、年をまたぐ週と日、**月曜と日曜の両方の週**）、半開区間とちょうど、焦点のヒステリシス（6%）、窓の大きさ V と R（§3.6 の表。1.1.1 の倍率で計算し直した値）、ずらし量（11 インチ縦の週で 696 pt、日で 396 pt）、はじきの行き先（6%）、本数の見積もり、窓の線の上限の定数。
  - `SpanLayout`: 週・日 × 境目の左・右・ちょうど・ガター・帯の外での `inkCell` と `drop`、`hit`・`dayAt`・`eventRange`・`snapRect`・`growsWithInk` の振り分け（前置名で呼んでも素の名前と同じ答え）、`onlyTailHeightChanged` のページごと、**窓 1 ページは今のレイアウトと同じ答え**、`eventTarget`（窓 1 ページで `eventRange` と同じ）。
  - `SpanName`・`SpanGuard`: 実在の名前（Web の `~w1` の id、`allday:`・`band:`・`focus:`・`plan:`、各ページ id、日曜の `w-`）は引っかからず、前置名と `span~` は必ず引っかかる。前置を外した名前で `isTail`・`needsMoreRoom`・`growsWithInk` が素の名前と同じ答え。`proto-` の扱い（`.prototype` だけが通す）。
  - `SpanAlign`: 入力を省けば今の出力と `==`。下限の下げ方（ずらしでは下げず、消して縮むときは下げる）。
  - `SpanComposer` と `PageDelta`: 無作為の編集 300 回以上（新しい線・消す・ページをまたぐ移動・↶ の写し）で、差分を当てた本物のページ ＝ 直接編集した結果（JSON まで）。順番を入れ替えても、2 回当てても `==`。差分を 1 つ落としても安全網の merge で同じ中身に戻る。編集しないページはバイト単位で同じ。同じ生の id が 2 ページにあっても 2 本。128 バイトを超える id の別名。`BandMigration` はまとめる前。**安全網の範囲の pageId は本物**（`w-`・`y-` で仮想 id を merge しても id が変わらない）。
  - K-10: `PageNavigation.pageId` と `CellKey` の作り方が `|` と `~` を作らない。
  - 週のメモの段: `PaperGrowth.tail` の週、週の一覧が 1,920 lu、`isBandCell(extra) == false`。
- CI の閾値は、1.3 の新しい数 − 50（N − 50 の規則、`build.yml:108-126`）。数と内訳を `build.yml` の注記と M7C.md に書く。

### 10.2 XCTest（名前は固定。持ち主の役）

| 役 | ファイル | テスト |
| --- | --- | --- |
| L | `InkLedgerTests.swift` | `testMakeIdGetsTheOwnerCell`、`testJournalRecordsOnlyLiveRemovals`、`testJournalDeltasEqualThePageDifference`、`testPruneHistoryDropsTouchingStepsAndTheirGroup`、`testNeedsMoreRoomStripsThePrefix`、`testCanvasRemovalWithoutEraserRebuilds`、`testTooManyRemovalsAtOnceRebuild`。`testLedgerWritesTheCompatShapes` は JSON が compat11 と同じまま。`testReloadOrRelayoutWithAnotherPageIsIgnored`（:670）は 1 ページの道でそのまま |
| L | `InkCanvasViewTests.swift` | `testShiftKeepsVisibleStrokesInPlace`（0.5 pt 以内）、`testNoShiftWhileDrawingSettlingFlingingPinchingSelectingOrSheet`、`testShiftNeverComparesTheOldDrawingWithTheNewLedger`（:2570 の考えを広げる）、`testFlingStopsAtTheNextPage`、`testNewStrokeOwnerIsTheCenterPage`、`testBudgetCountsTheOwnerPage`、`testStrokeOutsideTheBandIsDropped`、`testInboxTakesTwoUndosInOneTurn`、`testInboxTakesTheLastStrokeBeforeDetach`、`testPalmCannotStartAHorizontalPan`、`testGrowthTestsThroughOneAndThreePageSessions`（`PaperGrowthTests` とメモ欄・自由メモ・⑦ の既存のテストを窓 1 ページと 3 ページで） |
| S | `SpanSessionTests.swift`（新しい） | `testSaveOrderAddsFirstAndDestinationFirst`、`testInboxDrainsBeforeRelayout`、`testSafetyNetRecoversADroppedDelta`、`testSafetyNetKeepsTheRealPageId`、`testFailedSaveStopsTheShift`、`testBackgroundSavesEveryDirtyPage`、`testExportSavesEveryPageFirst`、`testOldEpochDeltaAfterEraseAllIsDropped`、`testRemoteUpdateReachesAnyWindowPage`、`testRemoteDeleteEmptiesThePageAndItsUndo`、`testPagesOpenedOnceForTheWindow`、`testFocusHysteresisAndRemember`、`testEventsArePerPageUnderFourYears`、`testArrowsMoveOnePage`、`testTodayNearSlidesFarReopens`、`testVirtualNamesNeverReachSaveImportExportOrPDF`、`testPathSwitchSavesThenReopens`、`testWeekStartSwitchSavesThenReopensAndNeverMixes`、`testReviewVisitFollowsTheFocus`、`testStageTwoFallsBackToOnePage` |
| S | `ScreenEraseTests.swift`（新しい） | `testRemoteEraseIsNotUndoneByTheNextSave`（H1、2 本の道）、`testEraseAndStartStopsTheSaveBeforeAwait`（H2）、`testUndoIsEmptyAfterEraseAllAndEraseAndStart`（H3、2 本の道） |
| Y | `SyncEngineTests.swift` | M4_CONTRACT §8.2 の 54 番から: `testPagesOpenedWaitsForTheAccountCheck`、`testPagesOpenedHonorsTheCooldownAndEpoch`、`testPagesOpenedFetchesOnceAndMergesEach`、`testPagesOpenedIsCountedByWaitUntilIdle`、`testRemoteDeleteCallsBothHooksInOrder`、`testInactiveEngineIgnoresBothHooks`。`test11DeletedNamesRemoveTheFile`（:341-356）は緑のまま |
| T | `PrototypeIsolationTests.swift`（新しい。`SPAN_PROTOTYPE` のときだけ中身） | `testPrototypeWritesNothingToTheRealStore`、`testPrototypeNeverCallsSharedSaveOrPageOpened`、`testPrototypeLeavesOnRemoteUpdateAlone`、`testPrototypeGuardRejectsRealIds` |
| U | `ScreenshotModeTests.swift` | `testNeighborDemoIdsDifferPerPage`、`testSpanArgumentsOffKeepTheOldShots`。`testDemoPageIdsMatchTheNavigation`（:52）は残す |
| U | `SettingsPageSectionTests.swift`（新しい） | `testPageSectionSitsBetweenInputAndSync`、`testSpanToggleDefaultsOnPerDevice` |
| C | `CompatSpanTests`（TegakiKit の新しいターゲット） | `testEveryCompatSpanFixtureIsPresent`、`testOverhangingStrokesSurviveTheFrozenCopy`、`testSundayWeekOverhangSurvives` |

- `PrototypeIsolationTests` を CI で走らせるため、build-and-test の単体テストの段に `SPAN_PROTOTYPE` 付きのビルドをもう 1 つ足すのではなく、テストの宿主だけに条件を付けて同じビルドで走らせる形を C が選ぶ（ジョブの時間のため）。選んだ形を M7C.md に書く。

### 10.3 UI テスト（U。iPhone 17、「指でも書く」オン。印は `span UI:`）

- `SpanUITests`: 指 1 本で日曜から月曜へ境目をまたいで引く → 保存されたページで `w-…` の `grid` に x < 0 の点がある。2 本指で横に動かすと題名が 1 回だけ変わる。◀ ▶ で 1 週すべり、キャンバスの識別子が変わらない。設定をオフにすると 1 ページの道になり、オンに戻すとまたいだ線がつながって見える。
- `build.yml:897` の grep に `span UI:` を足す。

### 10.4 互換（K-7）

- §6.3 のとおり。compat-v1.0 のジョブ（`build.yml:994-1093`、上限 45 分）に、compat-span の月曜の fixture を compat11 の一時フォルダへ写す段と、日曜の fixture を weekstart-compat の形で本物の 1.0 と <1.1.1> に読ませる段を足す。時間が 45 分に近づいたら上限を 55 分にする（M7C.md に書く）。

### 10.5 写真モードと CI の写真（新しいジョブ `span-shots`）

- 撮るもの: §4.5 の見本の全部、ずらす前と後の組（`--screenshot-span-shift`。見出しを除いた 2 枚の差がほぼ 0 でなければジョブを落とす）、古い版の見え方（`--screenshot-single-page`、iPhone と iPad 11 と mini）、隣の線を重ねた PDF、App Store の見本の 1 枚。iPad 11 インチと mini を必ず入れる。
- 既存の写真は `--screenshot-span` を付けなければ変わらない（J-4）。
- **J-4（日本語の写真の基準）**: 1.3 の日本語の写真は、`--screenshot-span` を付けない限り 1.2.3 と同じであること。基準は新しいファイル `tools/l10n/ja-baseline-ref-1.3.txt`（43fe366）。`ja-baseline-ref.txt`（<1.1.1>）は compat-v1.0 の weekstart-compat と共用なので変えない（`build.yml:1059-1083`）。`ja-baseline.yml` の写真の段を基準の `build.yml` から写し直す。違ってよい写真（設定のシートの新しい節・週のメモが写る週・blank-paper の週）を前もって M7C.md に並べる。
- 成果物は 7 日で消える（`build.yml:973-980`）。本人の確認ページはその間に作る。

### 10.6 CI の変更

| 場所 | 変更 |
| --- | --- |
| build-and-test | KitChecks の閾値（§10.1）、「Data code frozen (re-based in 1.3)」（§6.4）、`SPAN_PROTOTYPE` が `project.yml` に無いことの検査（`AGE_FORCE` の検査 :169-173 と同じ形）、新しい単体テスト、UI テストの grep、上限 120 分のまま |
| Sync engine tests, repeated (1.2.3) | そのまま（新しいテスト 54〜 も一緒に回る） |
| compat-v1-0 | §10.4 |
| span-shots（新しい） | §10.5。needs なし |
| l10n-shots・blank-paper | そのまま（新しい節・週のメモの写真が増える分だけ） |
| testflight.yml | 入力 `span_prototype`（`age_force` :31-35, :190-203 と同じ形。アーカイブの中身の確かめも） |
| ja-baseline.yml・store-shots.yml | §10.5、§8.5 |

---

## 11. 完了の定義

### 11.1 完了の条件（全部そろって「1.3 を提出してよい状態」）

1. §1.5 の表の 1〜13 が `r13` に入り、CI の全部のジョブ（build-and-test・「Sync engine tests, repeated (1.2.3)」の段・compat-v1-0・l10n-shots・blank-paper・span-shots）が緑。週のメモは 1/15 の関門で入れたときだけ（§5.1）。
2. KitChecks の数と閾値（§10.1）、`CompatSpanTests`、§10.2 の XCTest の全部、`span UI:` の UI テストが緑。
3. 1 ページの道が変わっていない: `ledger-*.json` と `screenshot-*.json` が compat11 と同じ。J-4 の日本語の写真が、違ってよい一覧の外で 1.2.3 と同じ。
4. 凍結の表を §6.4 の手順で作り直し、基準の commit と diff の確かめを M7C.md に書いた。
5. lint L-1〜L-14・`build.py --check`・`baseline.py --check` が緑。`REVIEW.md` の × が 0。
6. 新機能の文（16 ロケール）・審査メモ・App Store の写真・SUPPORT の差分を本人の確認ページで見せ、「この内容で入れてよい」をもらった。
7. 本人の TestFlight の確かめ表（§11.3）が全部○（×があれば直して出し直した）。
8. `MARKETING_VERSION "1.3"`。版に付けるビルドが試作のビルドでない（§4.6）。
9. 年齢区分の 2 問が答え済み（§9.1。1.3 で答えるなら提出のとき）。

### 11.2 写真（CI の `span-shots`。本人の確認ページにも使う）

| 写真 | 見えていなければならないもの |
| --- | --- |
| 週の帯（iPad 11 縦・横、mini 縦・横、13 縦・横、iPhone 縦・横） | 境目が真ん中で、日曜から月曜へまたぐ見本の線が 1 本につながっている。見出しの日付が線の下の日と合っている |
| 日の帯（同じ機種） | 前の日の自由メモから次の日へ続く見本の線。下の端がそろっている |
| 日曜始まりの週の帯 | 境目が土曜 → 日曜。見出しは「その週の最初の日の月」 |
| ずらす前と後の組 | 見出しを除いた 2 枚の差がほぼ 0 |
| iPhone 横の一番縮めた形 | 24 時間全部が入り、左右に前後の週が小さく並ぶ |
| 古い版の見え方（`--screenshot-single-page`） | 保存されたページにだけ線が出る。iPad の余白の上か、紙の端で切れるか（どちらかを記録） |
| 初めての案内の札 | 紙の上の端（終日帯のすぐ下）。日の自由メモを隠さない |
| 設定のシート | 「入力」と「同期」の間に「ページ」 |
| PDF | 隣から入る線の紙の中の部分が出る |
| 週のメモ（入れたとき） | 24 時の下に罫線の白紙。今日・土日の色と時刻の列の線は 24 時で止まる |
| App Store の見本（16 ロケール × 3 枠） | 週の境目をまたいで書いた見本。価格と Apple の商標が無い |

### 11.3 本人の確かめ表（TestFlight 1.3）

**対象の版: 1.3（TestFlight。ビルドの番号は Claude が渡すときに書きます）**。試作のビルドではありません。この表は、ビルドが本人の端末に届いた後に、番号を書いて改めて渡します。上から順に○か×。×のときは画面の写真を送ってください。

**準備**: どれか 1 台（たとえば iPad Pro 13）は TestFlight で 1.3 を入れず、App Store の 1.2.3 のまま残してください（古い版の端末として使います）。その端末は App Store の自動アップデートを止めておいてください。

| # | 端末 | すること | こうなれば合格 |
| --- | --- | --- | --- |
| 1 | 1.3 の端末 | 設定 › 情報 で「バージョン」を見る | 1.3（括弧の中は Claude が知らせたビルドの番号） |
| 2 | iPad | 週のページで、指で横にすべらせる | となりの週が続いて出てくる。上の題名が変わる |
| 3 | iPad | Apple Pencil で、日曜の夜から月曜の朝へ 1 本の線を書く | 途中で切れない。ペンを離しても線が動かない |
| 4 | iPad | Apple Pencil で書きながら、手のひらを紙に置く（縮めたときと、拡大したときの両方） | 紙が横に動かない |
| 5 | iPad | 指で横にはじく。次に、ゆっくり動かして止める | はじくと、となりの週でぴたりと止まる。ゆっくりなら止めた所で止まる。止まった後に見た目が動かない |
| 6 | iPad | ◀ ▶ と「今日」を押す | 1 週ずつ動く。「今日」で今週に戻る |
| 7 | iPad | 日のページの 24 時の下（自由メモ）で、前の日から次の日へ続けて書く | 続けて書ける |
| 8 | iPad | 週のページで 24 時の下へすべらせる（週のメモが入ったときだけ） | 罫線の白紙があり、書ける |
| 9 | iPhone | 指 1 本で書く。2 本指で横に動かす | 指 1 本では書ける。2 本指で、となりの週が出てくる |
| 10 | iPhone | 横にして、いちばん縮める | 24 時間全部が見える。2 本指で横に動く |
| 11 | iPad | 消しゴムで、となりの週の線を消す。投げなわで、線をとなりの週へ動かす。↶ を押す | 消せる。動かせる。↶ で元に戻る |
| 12 | iPad | となりの週に書いて、すぐにアプリを完全に閉じ、開き直す | 書いた線が残っている |
| 13 | 1.3 の端末と古い版の端末 | 1.3 でまたいで書いた線を、古い版の端末で見る | 片方の週にだけ出る（消えていない）。1.3 の端末ではつながって見える |
| 14 | iPad | 設定 › ページ の「前後のページを横につなげる」をオフにする。またオンに戻す | オフで 1 ページずつになる。オンに戻すと、またいだ線がつながって見える |
| 15 | iPad | 週のページの PDF を書き出す | となりの週から入ってくる線の、紙の中の部分が出る |
| 16 | iPad | 設定で週の始まりを日曜にする。また月曜に戻す | 日曜始まりで横につながる。月曜に戻すと前の線が見える |
| 17 | 1.3 の iPad と iPhone | 片方で書き足し、もう片方を開く | 書き足した線が届く。上の印は「保存済み」 |
| 18 | 1.3 の iPad と iPhone | 片方でホーム画面に戻って 1 分置き、また開いて書き足す。もう片方を開く | 届く。「停止中」や「別の iCloud アカウントです」は出ない |
| 19 | どれか 1 台 | 機内モードにして書く → 機内モードを切って開き直す | 書いている間は「オフライン」、戻すと「保存済み」。もう片方にも届く |
| 20 | 月と年のページ | いつもどおり書く・動かす | 今までと同じ（1 ページずつ） |
| 21 | （分かれば） | もう 1 台の 設定 › 情報 の 2 行の本数と、古い版のまま使う期間 | 答えが無くても進めます |

---

## 12. 段取り・役・出し方

### 12.1 役

| 役 | 仕事 | 持ち物 |
| --- | --- | --- |
| K | TegakiKit の Span の部品と KitChecks、週のメモの Layout | §2 の TegakiKit の行 |
| L | 台帳とキャンバス（凍結の表の行を同じ commit で書き直す） | `Ink/InkLedger.swift`・`Ink/InkCanvasView.swift`・`Ink/InkOverlayView.swift` |
| S | `SpanSession` と画面、H1〜H3 | `Span/SpanSession.swift`・`Views/CalendarRootScreen.swift` |
| Y | `SyncEngine` の 2 つの口とテスト | `Sync/SyncEngine.swift`・`SyncEngineTests.swift` |
| P | 紙・見出し・終日帯・PDF | `Paper/`・`StickyHeaderView`・`AllDayBandView`・`Export/` |
| U | 設定・案内・写真モード・UI テスト | §2 の U の行 |
| T | 試作版 | `Span/SpanPrototype*.swift`・`PrototypeIsolationTests.swift` |
| C | CI・互換・凍結の表・版 | §2 の C の行 |
| X・R | 訳・元を見ない逆翻訳 | `tools/l10n` の訳と `docs/i18n` |
| A・W | 店の文・SUPPORT | `docs/store/`・`docs/SUPPORT*.md` |
| リード | 順番・確かめ・本人への知らせ・提出・M7C.md | — |

### 12.2 段と目安の日（2026-11-11 時点。M7C.md に実績を書いて直す）

| 段 | 目安 | 中身 | 関門 |
| --- | --- | --- | --- |
| S0 | 11/11 | この契約 | 本人がまとめを読む（返事は要らない） |
| S1 | 11/12〜11/19 | K の Span の部品と KitChecks、段 0 の約束と fixture・口（§4.1〜§4.4）、凍結の表の手順の準備 | この Mac の KitChecks が緑 |
| S1' | 11/16〜11/20 | 年齢区分の 2 問を版を作らずに（§9.1） | — |
| S2 | 〜11/20 | 見本の画像（span-shots の最初の形）と確認ページ | 全部そろってから 1 回で書く |
| S3 | 〜11/21 | 試作版を TestFlight へ（`span_prototype`）。このときの `r13` は、ふつうの画面のコードを変えていない | `PrototypeIsolationTests` が緑 |
| S4 | 11/21〜11/26 | 本人が試作を触る（連休 11/21〜23）。待つ間に L の台帳（§3.3）を始める（画面に出ない部品） | 11/26 までに感想が無ければおすすめのまま |
| S5 | 11/27〜12 月 | B-1 の本体（L のキャンバス・S・Y・P・U・C）。キーが固まったら X・R・A を並べて進める | — |
| 判断 | **12/9** | 本体が全部のジョブで緑か。緑なら早い道、そうでなければふつうの道。年齢区分の 2 問を 1.3 で答えるか 1.2.4 を作るか（§9.1） | 本人に知らせる |
| 早い道 | 12/10〜12/16 | 週のメモ（〜12/11）→ TestFlight 1.3 → 確かめ表（12/12〜13 の週末）→ 確認ページ →「提出して良い」→ 12/16 までに提出 | 12/16 までに出せなければふつうの道へ |
| ふつうの道 | 12/10〜1/15 | 本体を仕上げる。12/19〜1/4 は審査を待つ工程を置かない | **1/15**: 本体が緑なら週のメモを始める。緑でなければ週のメモは 1.4.1 へ |
| S6 | 1/16〜1/22 | 週のメモ（入れるとき）・凍結の表の作り直し・店の文の仕上げ → TestFlight 1.3 | — |
| S7 | 1/23〜1/24 | 本人の確かめ表（週末） | — |
| S8 | 1/25〜1/29 | 「1.3 を審査に提出して良い」→ 提出 | — |
| S9 | 2/1 ごろ | 審査に通ったら「1.3 を公開して良い」→ 公開 →「まとめて良い」→ main へ | — |
| 前ぶれ | **2/5** | 本人の確かめがまだ始まっていなければ知らせる | — |
| 決まり | **2/15** | B-1 を提出できなければ、Xcode 27・Duo の版を先に（§12.4） | — |

- Claude の週の使える量が 95% に届いたら、その週は止まる。どの関門の前にも 1 週以上の余裕を置いた（1/15 の前に 12/19〜1/4 の作業、2/15 の前に 2/1〜2/14）。進み具合は M7C.md に残し、止まっても再開できるようにする。
- 作業の木はスクラッチパッド（`/private/tmp` の下）にあり、毎日 0:00 の掃除で古いファイルが消えうる。実装が始まったらこまめに commit し、リードが `r13` を GitHub に上げて控えを残す（このワークフローの外の仕事）。

### 12.3 出し方（本人の言葉が要る所）

| 順 | だれ | すること | 本人の言葉 |
| --- | --- | --- | --- |
| 1 | 各役 | この契約のとおりに作り、`r13` に commit | 不要 |
| 2 | リード | `r13` を GitHub に上げ、CI が全部緑 | 不要 |
| 3 | リード | 見本の画像の確認ページ、試作版の TestFlight と手順 | 答えは任意 |
| 4 | リード | 新しい文・店の文・写真・SUPPORT の差分の確認ページ | 「**この内容で入れてよい**」 |
| 5 | リード | testflight.yml を `r13` で走らせ、TestFlight 1.3 を上げる。確かめ表（§11.3）を番号付きで渡す | 不要 |
| 6 | 本人 | 確かめ表 | 「全部○」か×の所 |
| 7 | 本人 → リード | 提出のお願い | 「**1.3 を審査に提出して良い**」 |
| 8 | リード | Connect に版 1.3 を作り、16 ロケールの新機能の文・プロモーションテキスト・審査メモ・写真・ビルド（試作の番号でないことを確かめる）を入れて読み戻す。主言語（§8.6）と年齢区分の 2 問（まだなら）。手動公開で提出（提出のスクリプト） | 2 問が API に無いときだけ「押した」の返事 |
| 9 | 本人 → リード | 審査に通ったら公開。同じお願いで、main へまとめてよいか、公開の日の SUPPORT の全文 | 「**1.3 を公開して良い**」と「**まとめて良い**」、SUPPORT の「はい」 |
| 10 | リード | 公開の後、日本の App Store の表示が 1.3 になったら M7C.md に記録。`r13` を main に `git merge --no-ff`、main の CI を見る。試作のビルドを期限切れに | — |

- 公開は、本人の確かめ（6）と本人の言葉（9）の後だけ。公開の言葉は前もってもらってもよい（1.2.3 と同じ、R1_2_3.md:333-339）。
- 提出のボタンは、本人の言葉の後にリードがスクリプトで押す（M7_PLAN §4「どの版にも共通」の「ボタンは本人」は、1.2 からこの形）。

### 12.4 2/15 の決まり

- 2027-02-15 までに 1.3（B-1）を提出できなければ、Xcode 27・iPhone Duo の版を先に出す。そのとき Duo の版が 1.3、横につなげる版が 1.4 になる（入れ替わるのはこの 2 つだけ）。本人への知らせは中身の名前で書く。
- 入れ替わったら、横につなげる版は Xcode 27 で作り、Duo の幅でも確かめる。凍結の表の作り直しと互換の fixture の基準は、先に出た版の上でやり直す。
- Duo の版は遅くとも 2027-03-15 に提出（2027 年 4 月から Duo の写真が要る見込み、M7_PLAN §4.5）。

---

## 13. 危険と減らし方

| 危険 | 減らし方 |
| --- | --- |
| 仮想の名前（`span~`・前置名）が保存・同期に漏れ、F4 で全端末に勝って線が見えなくなる | `SpanGuard`（Release でも、保存・取り込み・書き出し・PDF）、型の包み `SpanVirtualPage`、KitChecks と `testVirtualNamesNeverReachSaveImportExportOrPDF`（§6.1） |
| 安全網の merge で本物のページ id が `span~` に化ける（`pickPageId`） | 範囲は本物の id で作る。merge の後に確かめる。`testSafetyNetKeepsTheRealPageId` |
| 差分の取りこぼしで線が消える | 受け箱・間引かない・安全網・セッションに限る（§3.4）。回収が起きたら記録し Debug で止める |
| 墓標の取り違いで、画面に出ていないページの線が全端末から消える | 削除の守り (a)〜(c)、多すぎる削除は作り直し（§3.4、§3.16） |
| 古い絵と新しい台帳を比べて線を写す | `resetScroll` の守りを残し、ずらしの間も比べない（§3.6） |
| 出るページの保存に失敗して線が消える | 失敗したらずらさない（§3.6） |
| 他の端末の「全て消す」が戻る（H1）、アカウントの切り替えで前の線が送られる（H2・H3） | §6.6 の直しとテスト |
| 同期の確かめ（G1〜G3）を新しい口が素通りする | `pagesOpened` は `pageOpened` と同じ門、`enqueue`/`spawn`、テスト 54〜（§7） |
| 週の始まりの 2 つの形が 1 つの窓に混ざる | `SpanSession` は形ごと、切り替えは `saveAll` の後に新しいセッション（§3.9） |
| 手のひら・指で紙が横にずれる | Pencil の間と 0.5 秒は横の動きを断る。本人の実機（試作と確かめ表の 4）。だめなら設定のオフが最後の手段 |
| 見出しが 1 フレームずれる・ちらつく | 版つきの `PaperViewport` を同じターンで（§3.6）。span-shots のずらす前後の比べ |
| 重さ（線の多いページ、iPhone 横の日の広い帯） | 試作で測る。窓の上限と段 2（§3.15）。P-B9 では本人のいちばん多いページは 1016 本 |
| 中心の機能に気づかれない | 初めての案内（§3.14）、新機能の文、App Store の写真 |
| 古い版の端末との組み合わせで「線が消えた」と思われる | 新機能の文と SUPPORT に許す範囲を書く（§6.5）。確かめ表の 13 |
| 凍結の表のファイルを許していない所まで変える | §6.4 の表と、書き直すたびのリードの diff の確かめ |
| 試作が本人のデータに触れる | §4.6 の 3 つの作りと `PrototypeIsolationTests`、`SPAN_PROTOTYPE` は App Store のビルドに入らない検査 |
| 試作のビルドと本物の 1.3 の取り違え | 番号を M7C.md に書き、提出のスクリプトで照らす。期限切れは次のビルドが VALID になってから |
| 実機でしか分からないこと（PencilKit の大きな帯、手のひら、iOS 27） | 試作と確かめ表。CI のシミュレータは iOS 26.4、本人の端末は 27.2（M7A.md:494、R1_2_2.md:929） |
| 年末年始の審査の遅れ・本人の休み | 12/19〜1/4 に審査を待つ工程を置かない（§9.4） |
| 2/15 に間に合わない | 1/15 の関門で週のメモを外す。2/5 の前ぶれ。§12.4 |
| 年齢区分の期限（1/12）を過ぎる | §9.1 の 3 段（版なし → 画面 → 12/9 に 1.3 か 1.2.4） |
| Claude の週の使える量の上限 | 関門の前に 1 週以上の余裕。M7C.md に進み具合 |
| 作業の木が夜中の掃除で消える | こまめに commit、リードが GitHub に上げる |

---

## 14. 規模

| 部分 | 里程 | 元 |
| --- | --- | --- |
| 段 0（約束と fixture・予定の口と組の印 0.1〜0.2、見本の画像 0.1〜0.15、試作版 0.35〜0.45） | 0.55〜0.8 | B_DESIGN.md:661 |
| B-1 土台 ＋ 週・日（Span と KitChecks 0.55、台帳 0.2、キャンバス 0.9〜1.0、SpanSession 0.9〜1.0、2 本の道 0.15〜0.2、紙・見出し・終日帯 0.4〜0.45、PDF・写真モード・CI・互換 0.4、設定・案内・手のひら 0.2、SyncEngine の 2 つの口 0.1、App Store 0.05） | 3.8〜4.2 | B_DESIGN.md:662（先読みを主スレッドに残す D6 で約 0.05 減るが、試作の計測しだいで戻るので数えない） |
| 週の下のメモ | 0.4〜0.5 | PLAN_WEEK_MEMO.md:48 |
| H1〜H3 の直し | 0.05〜0.1 | この契約 |
| 訳・逆翻訳・16 ロケールの文・確認表・ja の店の写真 | 0.2〜0.3【推定】 | 1.2 は時間を測っていない（M7B.md:1563-1572） |
| **1.3 の合計** | **5.0〜5.9** | — |
| （1.2.4 を作るとき、別の版） | 0.1 | §9.1 |
| （1.4 に入れる、1.3 を Xcode 27 と Duo の幅で確かめ直す分） | 0.2〜0.3 | M7_PLAN §4.5（1.3 の契約で入れる約束）。窓の表の Duo の行・span-shots と UI テストを Xcode 27 で回す・本人の確かめの 2〜6 と 9〜10 をもう一度 |

- 本人向けの目安（1 里程 ≈ 1.5 週）では約 7.5〜9 週。これまでの実績はずっと速い（1.1 の約 1.5 里程は契約から main まで約 19 時間、1.2 は契約から公開まで約 6 日。git log の b4f7271 → e7b4d2f、M7B.md）。日程（§12.2）は、本人の確かめ・CI の 1 回 80 分ほど・審査・週の使える量の上限が律速になる前提で組んだ。

---

## 15. 既定で決めたこと（本人に報告する）

1. 版の番号は 11/7 の答えのもの（月 1.7・年 1.8）。作業の指示の文の「月 1.6・年 1.7」は 11/7 より前の番号なので使わなかった（M7_PLAN §5 に「こちらが優先」）。
2. はじき・iPhone 横・さらに縮める・月の並べ方は、全部おすすめ（P-B5 ア・P-B6 ア・P-B10 ア・P-B3 ア）。月の 3 通りの見本は月の版の前に撮る。
3. 試作と見本は、答えが無くても 11/26 から先へ進める。
4. 「B-1 を作り始める前に見てもらう」は、ふつうの画面に出る部分（キャンバス・画面）を指すと読み、画面に出ない部品（TegakiKit の Span・台帳）は試作のために先に作る。
5. 隣のページは主スレッドで 1 ページずつ読む（D6）。
6. `SyncEngine` には 2 つの口だけ足す（D5）。試作のエンジンは変えずに作る（D13）。
7. 凍結の表の名前は変えず、同じ commit で行を書き直す（D9）。
8. 0-37: 「手書きの紙」だけキーに移し、記録のシートの 5 件は日本語のまま（D25）。
9. 主言語を en-US に替え、nl-NL・sv は足さない（§8.6）。
10. App Store の写真の先頭に 1 枚足す（D26）。ja も撮る。
11. 今ある穴 H1〜H3 を 1.3 で直し、新機能の文に H1 の直しを 1 行書く（D22、§8.3）。
12. 年齢区分の 2 問: 版なしで試す → 画面 → 12/9 に 1.3 か 1.2.4（§9.1）。1.2.4 はコードを変えない。
13. 中国の 2027 年の祝日は、1.2.4 を作るときだけ、了承を聞いて入れる（§9.3）。
14. 12/19〜1/4 は審査に出さない（§9.4）。
15. 週のメモの形は罫線だけ（見本で最終確認）。1/15 の関門は「本体が全部のジョブで緑」。
16. 評価の依頼の「訪問」は焦点のページで数える（D20）。
17. 線の予算と「メモ欄はここまでです」は持ち主のページ（D21）。
18. PDF は隣から入る線も描き、自由メモを含めるかの判定にも数える（D17）。
19. 予定の 2 つは口と印だけ（D23）。
20. 互換の本物の相手は 1.0 と <1.1.1>。`EXPECTED_MIN` は変えない（D10）。
21. 日本語の写真の基準は新しいファイル（0c-35）。
22. B-1 の写真は新しいジョブ（D11）。
23. 確かめ表では、もう 1 台の本数と古い版の期間を「分かれば」で聞く（P-B9 の残り）。
24. 1.2 から持ち越した細かい訳の直しは 1.3 に入れない。
25. 1.4 の確かめ直しは 0.2〜0.3 里程と見積もった。

---

## 16. 確かめていないこと

- PencilKit が、iPhone 横の日の帯（最大倍率 × 15 ページ × 紙の高さ 8,400 lu）でちらつかず、メモリに収まるか（試作で測る）。
- 手のひらで紙が横に動かないか（本人の実機だけ）。`majorRadius` で手のひらを見分けられるか【推論】。
- 古い版の iPad で、紙の外の点が余白に描かれるか切れるか（§4.5 の写真で確かめる）。
- 1.1.1 の倍率の後も、週・日の窓の表（V と R）が B_DESIGN と同じか（KitChecks で計算し直す）。
- 年齢区分の 2 問を版を作らずに答えられるか（11/16 より後でないと試せない）。画面の言葉。期限を過ぎたときに何が起きるか。
- 主言語を en-US にしても、日本の App Store で日本語が出るか（公開の後に確かめる）。
- Apple の年末の審査の予定。
- 中国の 2027 年の祝日が `python-holidays` の新しい版に入る時期。
- 1.2 を出した日のロシアの店頭の結果（記録に無い、M7B.md:2012）と、EU の届け出の結果（2026-11-09 の時点で審査中）。
- 今ある穴 H1〜H3 はコードを読んで見つけた。実際に起きたという知らせは無く、実測もしていない。
- 週のメモで、1.2 までに投げなわで 24 時の下へ動かした線がメモ欄の上に見えるようになるか。
- Web 版がアプリの線を読まないこと（Web のリポジトリはこの作業場所に無い）。
- GitHub の macOS のランナーが同時にいくつ走れるか。`macos-26` のイメージに Xcode 26.6 が 2027 年 2 月まで残るか（無くなると既定の Xcode で走り、J-4 の env.txt で気づく）。
- fr・de の直した文が元を見ない逆翻訳を通ったか（M7B_CONTRACT.md:2268 #41、M7B.md:1470）。1.3 の訳の流れで、その 2 か所ももう一度逆翻訳に通す。
- 本人の iPad は 3 台（mini・Air 11・Pro 13、M7A.md:494）。B_DESIGN は 11 インチを「本人の iPad」と書き、P-B9 の答えの文脈は mini（M7B.md:1937）。写真と確かめ表では 11 インチと mini の両方を見る。

---

## 17. 採らなかった案と、読み手の指摘の扱い

| 案・指摘 | 扱い | 理由 |
| --- | --- | --- |
| 先読みを主スレッドの外で（B_DESIGN §2.4 の 10） | B-1 では採らない（D6）。試作で 16 ms を超えたら 1.3 の中で足す | `InkPageStore.load` は `.bak` に移すので読むだけではない。1 ページは軽い（P-B9） |
| 記録の削除を画面で見分ける（「空のページでファイルが無い」） | 採らない（D5） | 推し量りより明示の口 |
| 試作のために `SyncEngine` の工場に `store` の引数を足す（B_DESIGN.md:584） | 採らない（D13） | 今の `init` で作れる。凍結の行を増やさない |
| 試作を別のブランチに | 採らない（D12） | 土台の部品が二重になる |
| 凍結の表の名前を変える（`DATA_1_3` など） | 採らない（D9） | `lint.py:666` が名前で読み、名前を変えると L-7・L-8・L-13・L-14 が黙って凍結のファイルを読み始める |
| 互換の相手に本物の 1.2.3（43fe366）を足す | 採らない（0c-33） | データのコードは SyncEngine を除き <1.1.1> と同じバイト。ジョブの時間 |
| `EXPECTED_MIN` を上げる | 採らない（D10） | `tools/compat10` を変えない約束（M7B_CONTRACT.md:503）。欠けは `CompatSpanTests` の一覧で見つける |
| nl-NL・sv を足す | 採らない（§8.6） | 主言語を en-US にすれば要らない |
| 0-37 の 6 件を全部キーに | 採らない（D25） | `InkTrace.swift` を変えずに済む。記録のシートは日本語のまま（審査メモにある） |
| 月の 3 通りの見本を 1.3 の前に | 採らない（0c-20） | 1.7 で決めること。1.3 の見本を小さくして早く見てもらう |
| 日の自由メモのそろえを作らない（1.1.1 で 6,000 lu になったので） | 採らない（D16） | 週のメモと同じ部品で、5,950 lu を超えた線では要る |
| H1〜H3 を 1.2.4 で直す | 採らない（D22、§9.1） | 1.2.4 はコードを変えない版にして、審査と確かめを軽くする。B の安全網と合わせて確かめる |
| 週のメモを 1.3 の前の別の版で | 採らない | 本人の答え（11/7、1.3 の最後の部品） |

---

## 18. 記録

（結果は [M7C.md](M7C.md) に書く。ここは空のまま。）
