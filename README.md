# てがきカレンダー（iPad アプリ版）

iPad の「カレンダー」に入っている予定（Google カレンダーを含む）の上に、Apple Pencil で手書きできる **iPad 用のアプリ** です。
Web 版（<https://github.com/syfan0-star/tegaki-calendar>）で確かめた使い勝手を、App Store で売れる本物のアプリとして作り直しています。

**2026-10-30 に 1.0（ビルド 10）を App Store で公開しました**（審査は 10-18 提出 → 2 回の差し戻し（掲載写真の価格、サブタイトルの Apple Pencil）→ 10-29 承認。App Store のページ: <https://apps.apple.com/jp/app/id6822762089>。反映まで最大 24 時間）。

その後の版: **1.0.1**（iPhone で年のページから日のページへ移れない不具合の直し。[docs/R1_0_1.md](docs/R1_0_1.md)）は公開済み。**1.1**（ツールバーをしまう・消しゴムから自動でペンへ・下に伸びるメモと日の「自由メモ」・日付の当たり・年の左端の数字・線の予算・「この端末」。[docs/M7A_CONTRACT.md](docs/M7A_CONTRACT.md)・[docs/M7A.md](docs/M7A.md)）は main に取り込み済み（e7b4d2f）で公開済み。**1.1.1**（予定の少ない月・年の上の空白、年の大きさが年ごとに違う不具合、メモ欄を最初から全開、ピンチの案内、「今日」を右へ。[docs/R1_1_1.md](docs/R1_1_1.md)）は 2026-11-06 に公開済み。**1.2「世界対応」**（10 の表示言語、国ごとの祝日、週の始まりを月曜と日曜から選べる、英語の規約類、App Store の各国語、EU 27 か国での販売。[docs/M7B_CONTRACT.md](docs/M7B_CONTRACT.md)・[docs/M7B.md](docs/M7B.md)）は 2026-11-06 に公開済み（ビルド 18。EU での配信は本人の届け出が通ってから）。**1.2.1**（App Store の評価のお願い、日本語以外の画面で英語の規約類、検索の語。[docs/R1_2_1.md](docs/R1_2_1.md)）はブランチ `r121` で、2026-11-08 に審査に提出（ビルド 20）し、審査を待っています。**1.2.2**（年齢区分の確認。米国の一部の州など法律で求められる地域の人にだけ、Apple の年齢区分の画面を出す。[docs/R1_2_2.md](docs/R1_2_2.md)）はブランチ `r122` で作っています。main への取り込みは本人の了承の後です。

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
| [docs/M5_CONTRACT.md](docs/M5_CONTRACT.md) | M5 の実装契約（サブスクリプション（StoreKit 2）、権利の状態機械と控え、閲覧専用モード、ペイウォール、設定 › 購入、規約類の公開版、App Store Connect の手順、サンドボックスの試験） |
| [docs/M5.md](docs/M5.md) | M5 の実装結果（作ったもの・確かめ方・CI の結果と写真の確認表・StoreKitTest の可否・本人がやること（Connect・サンドボックス試験）・既知の制限） |
| [docs/M6_CONTRACT.md](docs/M6_CONTRACT.md) | M6 の実装契約（手書きの書き出し（データファイル `tegaki-app-export` v1 と PDF）、取り込み口の 2 形式化、App Store の審査資料（写真・サブタイトル・キーワード・審査メモ・年齢区分・App Privacy）、App Store Connect の手順、規約類の「提供中」への更新、版 1.0） |
| [docs/M6.md](docs/M6.md) | M6 の実装結果（作ったもの・確かめ方・CI の結果と写真の確認表・`store/` の一覧・大きなファイルの実測・本人とリードがやること（Connect の入力・TestFlight 1.0 の実機確認・提出）・既知の制限） |
| [docs/M7_PLAN.md](docs/M7_PLAN.md) | 1.0 の後の改善計画（本人の 12 項目、データ互換の規則 K-1〜K-9・K-11、1.0.1〜1.9 の段階計画、本人に決めてもらうこと） |
| [docs/R1_0_1.md](docs/R1_0_1.md) | 1.0.1 の記録（iPhone で年のページから日のページへ移れない不具合の原因と直し、iPhone の UI テスト、CI の結果） |
| [docs/M7A_CONTRACT.md](docs/M7A_CONTRACT.md) | 1.1（M7a）の実装契約（ツールバーの 3 状態、消しゴムの自動復帰、下に伸びるメモと日の `extra`「自由メモ」、日付の当たり `DateTap`、線の予算 K-9、「この端末」の文言、互換テスト K-7（1.0 の凍結した写し `Compat10` と本物の 1.0 で fixture を確かめる）） |
| [docs/M7A.md](docs/M7A.md) | 1.1（M7a）の実装結果（担当ごとの結果・契約からのずれと決め方・KitChecks の数・互換テストの結果・CI の run と写真の確認表・本人とリードがやること） |
| [docs/R1_1_1.md](docs/R1_1_1.md) | 1.1.1 の記録（上の空白と年の大きさの原因と直し、メモ欄の全開、ピンチの案内、「今日」の場所、確かめ、新機能の文、審査メモ、本人の確かめ表、1.2 への申し送り） |
| [docs/M7B_CONTRACT.md](docs/M7B_CONTRACT.md) | 1.2（M7b「世界対応」）の実装契約（言語の選ばれ方と文字列の仕組み、書式、紙に字を入れるきまり、世界の祝日、週の始まり（K-11）、規約類と App Store の文、EU での販売、CI、本人の確かめの表） |
| [docs/M7B.md](docs/M7B.md) | 1.2 の実装結果（担当ごとの結果・契約からのずれと決め方・KitChecks の数・祝日データの弱い所・CI で初めて分かること・本人とリードがやること） |
| [docs/R1_2_1.md](docs/R1_2_1.md) | 1.2.1 の契約と記録（App Store の評価のお願いの決まりと呼ぶ所、日本語以外の画面で英語の規約類へのリンク、版、本人の確かめ表、公開までの順番、既定で決めたこと、確かめ） |
| [docs/R1_2_1_STORE.md](docs/R1_2_1_STORE.md) | 1.2.1 の App Store の文（キーワードの直しと訳し戻し、新機能の文、説明の利用規約・プライバシーポリシーの行、URL、lint の L-9 の直し、審査メモ、Connect に入れるもの） |
| [docs/R1_2_2.md](docs/R1_2_2.md) | 1.2.2 の契約と記録（Apple の Declared Age Range の最小の実装、いつ・どこで聞くか、署名と権限、プライバシーポリシーの 1 項目、テスト、本人の確かめ表、段取り、既定で決めたこと、確かめ） |
| [docs/R1_2_2_STORE.md](docs/R1_2_2_STORE.md) | 1.2.2 の App Store の文（新機能の文と訳し戻し、審査メモ、プロモーションテキスト、Connect に入れるもの） |
| [docs/US_AGE_LAWS.md](docs/US_AGE_LAWS.md) | 米国の州の年齢確認の法律の覚え書き（本人が決めるため。法律の助言ではない。1.2.1 では何も変えない） |
| [docs/i18n/GLOSSARY.md](docs/i18n/GLOSSARY.md) ／ [docs/i18n/REVIEW.md](docs/i18n/REVIEW.md) | 9 言語の用語集と、訳を日本語へ逆に訳して照らした結果（`docs/i18n/back/` が逆翻訳。ネイティブの確認は無いことも書いてある） |
| [docs/store/](docs/store/README.md) ／ [docs/support-replies/](docs/support-replies/README.md) | App Store の文の原稿（15 ロケール。入力は確認表を本人に見せた後）と、サポートの返事の定型文（送るのは本人） |
| [docs/PRICING.md](docs/PRICING.md) | 価格（月 300 円・年 2,400 円・14 日間無料。2026-10-11 の決定、M5 で実装） |
| [docs/APPLE_ENROLLMENT.md](docs/APPLE_ENROLLMENT.md) | Apple Developer Program の登録手順（本人向け） |
| [docs/TERMS.md](docs/TERMS.md) ／ [docs/PRIVACY.md](docs/PRIVACY.md) ／ [docs/SUPPORT.md](docs/SUPPORT.md) | 利用規約・プライバシーポリシー・サポートページ（M5 で公開版に。Web 版の Pages の `app/` に HTML で公開する。専門家の確認は本人の任意）。1.2 で英語の参考訳 `*.en.md` を足した（正本は日本語。公開は 1.2 を出す日） |

## いま出来ていること（第 6 段階 M6）

月・週・日・年の 4 ページに手書きし、予定を読み取って紙の上に並べ、紙の上から予定を作る・直す・消し、手書きをご本人の iCloud でほかの iPad や iPhone と同期し、Web 版の手書きを取り込み、iPhone・iPad mini・11 インチ・13 インチのどれでも、月と年はどのページも同じ大きさで開いて（予定や手書きの多いページは下へスクロール）ピンチで拡大縮小し、週・月・年の指のダブルタップでその日へ飛び、App Store のサブスクリプション（14 日間無料）で手帳の機能を解放し、購読していないときは閲覧専用で使え、手書きを全ページのデータファイル（JSON）や開いているページの PDF に書き出せるところまでです（詳しくは [docs/M2.md](docs/M2.md)、[docs/M3A.md](docs/M3A.md)、[docs/M3B.md](docs/M3B.md)、[docs/M4.md](docs/M4.md)、[docs/M4B.md](docs/M4B.md)、[docs/M4C.md](docs/M4C.md)、[docs/M5.md](docs/M5.md)、[docs/M6.md](docs/M6.md)）。

| 機能 | 内容 |
| --- | --- |
| 4 つのページ | ヘッダー右の「日 \| 週 \| 月 \| 年」で切り替え（切り替えても見ている日は変わりません）。◀ ▶ で前後へ（日は 1 日、週は 7 日、月は 1 か月、年は 1 年）、右側の「今日」で今日へ（月と年では今日のマスが見える位置まで動きます。1.1.1）。月の日付の数字・年の曜日の字・週の日付見出しをタップするとその日の日ページへ、年の月名をタップするとその月の月ページへ。週・月・年では **指のダブルタップ** でその日の日ページへ（マス・列・終日帯の列。メモ欄・時刻帯・存在しない日では何も起きない。日ページでは何も起きない） |
| 月のページ | 6 行 × 7 列（月曜はじまり。1.2 から日曜はじまりも選べます）。今日に青い丸、土曜は青、日曜と祝日は赤（祝日名つき）、月外の日は薄く。グリッドの下にメモ欄 |
| 週のページ | 左に時刻帯、7 列の 24 時間の時間軸（1 時間 80 lu）。月曜はじまりの週と日曜はじまりの週は別のページで、手書きは別々に保存します（1.2、下の「週の始まり」）。上に終日の帯（固定、書けない。タップで編集、空きをタップで追加）。紙は 0:00 から。時間指定の予定は色の箱（重なると列に分かれる、過ぎた予定は薄く）。今日の列に赤い現在時刻の線。一覧（基本の状態）では 0:00〜24:00 が全部入り、拡大して開くときは今日が見えていれば「今の 1 時間前」の位置から |
| 日のページ | 1 日の時間軸（1 時間 100 lu）と、右側のメモ欄（罫線）。上に終日の帯（固定、書けない。タップで編集、空きをタップで追加）。紙は 0:00 から |
| 年のページ | 12 列 × 31 行。土曜は薄い青、日曜・祝日は薄い赤、今日は青い枠。各マスの左上に曜日の字（祝日名つき）、右側に終日の予定のチップ（複数日は帯でつなぐ）。存在しない日（2/30 など）は斜線 |
| 予定を見る | iPad の「カレンダー」の予定を読み取り（フルアクセスの許可が必要）。月は終日の帯＋「● 9:00 題名」のチップ（1 日 3 件まで。4 件以上は 2 件＋「+n件」。タップでその日の日ページへ）。表示するカレンダーは設定画面で選べます |
| 予定を作る | ツールバーの「予定」で紙をなぞる（週・日は時間軸の範囲を 15 分に丸め、30 分未満は 1 時間。タップはその半時間から 1 時間。月・年はその日の終日）か、ヘッダーの「＋予定」（今日の 9:00〜10:00、月・年は今日の終日）。「予定を追加」のシートで、タイトル（Apple Pencil で書けば文字になります）・終日・開始と終了・登録先のカレンダー・場所・メモを入れて保存。iPad の「カレンダー」に登録されます |
| 予定を直す・消す | 帯・チップ・箱をタップ（指でも「予定」の道具でも）で「予定を編集」。繰り返しの予定は「この回だけ」か「以降すべて」を選びます。変更できないカレンダー（購読など）は閲覧だけ |
| 投げなわ | 手書きを囲んで選び、枠の中をドラッグで動かす（別の日のマスへ動かすとその日の手書きになります）、「削除」、「予定にする」（囲んだ手書きの画像が付いた作成シート。保存後にその手書きを消すかどうかは設定の初期値どおり）。どれも「元に戻す」が効きます |
| 伸びる紙 | 月の行と年の行は、予定が多いときと手書きがはみ出したときだけ伸びます（上限あり）。週・日の時間軸は伸びません。見えている場所が動かないようにスクロールも補正します |
| 手書き | Apple Pencil で書きます。ペン（6 色 × 細・中・太）、マーカー（4 色）、消しゴム（触れた線をまるごと消す）、元に戻す／やり直す。指はスクロール・ピンチ拡大・タップ用（「指でも書く」で指でも書けます）。手書きはページごと（月・週・日・年）に iPad の中へ保存され、最後に見ていたページで開き直します |
| 開く大きさとピンチ | どのページも、基準の紙（月は 6 行 × 175 lu の格子、週と日は 24 時間、年は 31 行 × 60 lu）が画面に入る倍率で開きます（1.1.1。予定や手書きの量では変わらないので、同じ端末ならどの月もどの年も同じ大きさ。iPad の月は幅ぴったりのまま）。予定や手書きの多いページは下へスクロールします。ピンチで **一覧**（ページ全体が画面に入る倍率。月は 6 行の格子、週と日は 24 時間、年は紙全体。これより小さくはならない）〜幅ぴったりの 4 倍まで拡大縮小でき、どの倍率でも書けます。小さい倍率では文字が比例して小さくなり（罫線は 1 pt のまま）、iPhone は地図のような縮図で、ピンチで拡大して読みます。拡大した倍率はページの種類（月・週・日・年）ごとに覚え、同じ種類の次のページも同じ倍率で開きます（開く倍率より縮めた大きさは覚えません）。向きを変えても開く倍率は開く倍率のまま、拡大中は手書きの大きさが変わりません。紙はいつも画面の上から始まり、余りは紙の下に残ります（1.1.1）。紙が画面より細いときは左右の机の色の余白の中央に寄せ、余白に書いた線は保存しません。ピンチできることは、初めて開いたときに一度だけトーストで知らせます |
| iCloud 同期 | iPad で iCloud にサインインしていれば自動で、手書きがご本人の iCloud（CloudKit のプライベートデータベース）にも保存され、同じ Apple ID のほかの iPad や iPhone で同じ手書きが見えます。ヘッダー右の ☁ に状態（保存済み／同期中／オフライン／この端末のみ（1.0 では「この端末のみ」）／エラー／停止中。タップで設定画面）。書いてから約 3 秒で送り、相手の線はアプリを前面に戻したとき・ページを開いたとき・サイレントプッシュが届いたときに取り込みます。オフラインでも全部使え、回線が戻れば送ります。iPad の中のファイルが常に主で、iCloud は「ほかの端末へ届ける経路」と「バックアップ」。別の Apple ID にサインインし直したときは、残すか消すかを聞いてから使い始めます。開発者には手書きは見えません |
| Web 版からの取り込み | Web 版の設定で「手書きを書き出す（iPad アプリ用）」をすると、全ページ・全端末の手書きが 1 つの JSON ファイルになり、iPad の「ファイル」アプリに入ります。アプリの設定 › データ › 「Web 版の手書きを取り込む」でそのファイルを選ぶと、月・週・日・年の 4 ページに Web 版と同じ位置で入ります（線の id をそのまま使うので、同じファイルを二度取り込んでも二重になりません。Web 版で消した線は戻りません）。M6 からは同じ行で、このアプリ自身が書き出したデータファイル（下の行）も取り込めます（復元。完成文は「手書きを取り込みました（N ページ・M 本）」。取り込みは購読中に） |
| 手書きの書き出し | 設定 › データ › 「手書きを書き出す」（閲覧専用でも使えます。iPhone でも）。**データファイル（JSON、すべてのページ）** は、この端末に保存されている手書きの全ページ（月・週・日・年）を 1 つの読める整形 JSON（形式 `tegaki-app-export` v1。[設計書 §3.9](docs/DESIGN.md#39-保存形式とバージョン)）にしたもので、ファイル名は「てがきカレンダー 手書き YYYY-MM-DD.json」。「Web 版の手書きを取り込む」から取り込み直せます（同じファイルを二度取り込んでも二重にならず、書き出した後に消した線は戻りません。全部を元に戻すときは「この端末の手書きを全て消す」の後に取り込みます）。**このページを PDF** は、いま開いているページを 1 枚の PDF に（紙・予定・祝日・手書きが画面のとおり。紙と文字はベクタ、手書きは 2 倍の画像。現在時刻の赤線は入れません。ファイル名は「てがきカレンダー 2026年10月 月.pdf」の形）。できあがると「共有…」で「ファイル」アプリに保存、AirDrop、メールなどへ |
| Apple Pencil のダブルタップ／スクイーズ | iPad の「設定 › Apple Pencil」で選んだ動作どおりにペン ⇄ 消しゴム |
| 初回案内 | カレンダーのアカウント → フルアクセスの説明 → ペンと指の使い分け → iCloud と手書きの保存、の 4 枚。最後のボタンで許可の画面が出ます（iCloud に許可の画面はありません） |
| 設定画面 | ヘッダーの ⚙ か ☁。表示するカレンダー（アカウントごと）、予定の登録先、カレンダーへのアクセス、Google カレンダーの使い方、週の始まりと表示する祝日（1.2）、指でも書く、予定にした手書きを消す、iCloud 同期の状態と「最後に同期」「今すぐ同期」、Web 版の手書きを取り込む（Web 版の書き出しと、このアプリの書き出したデータファイルの 2 形式）、手書きを書き出す（データファイル `tegaki-app-export` v1（JSON、すべてのページ）か、いま開いているページの PDF。閲覧専用でも青いまま押せます）、この端末の手書きを全て消す（2 回確認。iCloud が使える状態なら iCloud の分も消え、ほかの端末からも消えます）、購入（現在のプラン・購入を復元・サブスクリプションの管理）、利用規約・プライバシーポリシー・使用許諾契約（Apple 標準 EULA）・サポート（1.2.1 から、日本語以外の画面では利用規約・プライバシーポリシー・サポートが英語のページを開く）・オープンソースのライセンス（1.2）・バージョン |
| 購入と閲覧専用 | 月額 300 円・年額 2,400 円・14 日間無料のサブスクリプション。購読していないときは閲覧専用（予定と手書きの閲覧、ページ移動、拡大はできる。書く・消す・予定の作成はペイウォールの案内）。購入画面は初回案内の後（未購読と確認できたとき）、ヘッダーの「閲覧専用」バッジ、止めた操作を試みたとき（1 セッション 1 回、2 回目以降はトースト）、設定 › 購入 から。権利の判定は Apple（StoreKit 2）が正で、最後に分かった状態を端末に控えるので機内モードでも書けます |
| 表示の言語（1.2） | 日本語・英語・簡体字中国語・繁体字中国語・韓国語・フランス語・ドイツ語・スペイン語・イタリア語・ポルトガル語の 10 言語。端末の言語に従い、それ以外の言語の端末は英語（右から左へ書く言語は対象外）。アプリの中に言語の設定は作らず、iOS の「設定」アプリの「言語」で選びます。日付・月・曜日の名前も言語に従いますが、紙の時刻は全言語で 24 時間の「9:00」。日本語の利用者の画面は 1.1.1 と 1 文字も変わりません。訳は Claude が書いて別の Claude が逆に訳して確かめたもので、ネイティブの確認はありません（[docs/i18n/REVIEW.md](docs/i18n/REVIEW.md)） |
| 祝日（1.2） | 設定 › 表示する祝日 で、自動（端末の地域）・250 の国と地域・なしから選べます。州や地域で祝日が違う国は州・地域も選べます。日本は今までどおり自前の計算（`JapaneseHolidays`）で、1.1.1 までお使いの方は「日本」のまま。他の国のデータは python-holidays 0.107（MIT）から作ってアプリに同梱し、通信はしません。祝日と言語は紙の形を変えず、変わるのは字と休日の色だけで、手書きの位置は動きません |
| 週の始まり（1.2） | 設定 › 週の始まり で、自動（端末の地域）・月曜・日曜から選べます（端末ごと。iCloud に送りません）。今お使いの方は月曜のまま。週のページの手書きは月曜はじまりと日曜はじまりで別々に保存し、切り替えるともう一方は戻すまで見えませんが消えません。月のページの手書きは日付についていきます（片方の並びにしか無い前後の月の日に書いた線は、もう片方では隠れるだけで消えません）。規則は K-11（[docs/M7_PLAN.md §1.3](docs/M7_PLAN.md)） |
| iPhone | ヘッダーが 2 段（切替は 2 段目。☁ は記号だけ）、ツールバーは横にスクロール、最初は週ページ、「指でも書く」は最初からオン。開いたときは基準の紙が画面に入り（文字は 4〜7 pt の縮図）、拡大すると月・週・日は今日の列から、年は今月の列から横にスクロール。「指でも書く」がオンのときは 2 本指で動かす（ツールバーで切れる）。投げなわ・予定の道具を使っているときも 1 本指が道具、2 本指がスクロールとピンチ |
まだ無いもの（公開後）: 設定（表示するカレンダーなど）の同期。[設計書の段階計画](docs/DESIGN.md#9-段階計画)の順に足していきます。

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
  1. 純粋な部分（`TegakiKit`）を macOS 上でビルド → `KitChecks`（1.2.2 で 29982 項目の検査。29932 以上であることを数字で確かめる）→ `swift test`（1.1 から互換テスト `Compat10Tests`、1.2 から `Compat12Tests` を含む）→ 1.0 の凍結した写し（`TegakiKit/Tests/Compat10`）が凍結したときのままか（`FROZEN.sha256`）→ 言語の lint（`tools/l10n/lint.py`、14 の規則）→ 1.2.2 から、`import DeclaredAgeRange` が `Views/AgeRangeAsker.swift` の 1 つだけか・entitlements に年齢区分の権限があるか・`project.yml` に `AGE_FORCE` が無いか（Age range isolation）→ 手書きのデータの 18 ファイルが 1.1.1 のままか（`tools/compat10/DATA_1_1.sha256`）
  2. `brew install xcodegen` → `xcodegen generate` で Xcode プロジェクト（`TegakiCalendar.xcodeproj`）を作る
  3. iOS シミュレータ向けにビルド（署名なし）。1.2 から、組み上がったアプリに 10 言語の `.lproj`・祝日のデータとライセンス・プライバシーマニフェストの理由があるかを確かめる（Localized bundle check）。1.2.2 から、DeclaredAgeRange が弱いリンク（`LC_LOAD_WEAK_DYLIB`）かも確かめる（Weak link of DeclaredAgeRange）
  4. 13 インチ iPad のシミュレータでアプリのユニットテスト（PencilKit の台帳と選択の操作・手書きの画像・予定シートの状態・予定の書き込み・スクリーンショットモード・同期エンジン（メモリ上の偽の iCloud に対して。iCloud アカウントは不要）・レコードの写像・CloudKit の誤りの写像・状態ファイル・紙の文字のクリップと窓・キャンバスの viewport の通知・一覧の倍率とピンチの終端の経路・ダブルタップの認識器・保存比率・スクリーンショットの倍率の引数・購読の状態機械と `StoreModel`（偽の App Store と、StoreKit のテスト環境 `SKTestSession` に対して。App Store Connect は不要）・ペイウォールと設定の文言・閲覧専用の判定）を実行。1.2 から日本語に固定（`-testLanguage ja -testRegion JP`）。1.1 の後半から、後の段（The unit tests' repro lines）が `repro:` の行を 1 回ずつ出す
  5. 同じ 13 インチのシミュレータでアプリをスクリーンショットモードで 16 回起動し（月・週・日・年の 4 ページ（一覧）、月・週・年を 2 倍に拡大した 3 枚、閲覧専用の月ページ（「閲覧専用」バッジとトースト）、月ページで「予定を追加」「予定を編集」「投げなわの選択」「設定」「同期（設定の「同期」の節）」「Web 版の取り込みの結果」「購入（ペイウォール）」「手書きを書き出す（書き出しのシート）」の 8 つのシート）、続けて iPhone 17・iPhone 17 Pro Max（6.9 インチ）・iPad mini・11 インチ iPad を 1 台ずつ起動して 4 ページずつ（11 インチはさらに閲覧専用の日ページ、iPhone と 6.9 インチはさらに購入画面のシート、iPhone はさらに今日が日曜の週・6/1 の週・週を 3 倍に拡大した 1 枚ずつ・閲覧専用の週と横向き 4 枚）、画面を撮って成果物 `screenshots`（7 日保存）に置く。13 インチ 16 枚 + iPad mini 4 枚 + 11 インチ 5 枚 + iPhone 縦 9 枚 + iPhone 横 4 枚 + 6.9 インチ 5 枚 = 43 枚。さらに App Store の掲載用に `store/<機種>/NN-<名前>.jpg`（13 インチ 6 枚・iPhone 5 枚・6.9 インチ 5 枚・11 インチ 4 枚 = 20 枚。アルファ無しの JPEG。画素が Apple の受理サイズのどれかであることを照合し、違えば警告）。アプリのログ（5 本）には倍率の診断行（`zoom:`）が残る（購入の診断行 `store:` はスクリーンショットモードでは偽の App Store なので 0 行）
  6. 1.0.1 から、写真の後に iPhone 17 のシミュレータで UI テスト（`YearTapUITests`、年のページの本物のタップ）。1.1 の後半で `EraserAndBelowDayUITests`（消しゴムからペンへ、24 時の下は予定にならない。`YearTapUITests` と合わせて 13 本）。1.1 から、13 インチはさらに 6 回（しまったツールバーの左下と右下、ツールバーで選んだ消しゴム、伸びた月のメモ欄、日の 24 時の下の「自由メモ」、設定の「情報」）、iPhone は 4 回（しまったツールバーの縦と横、伸びた月のメモ欄、「自由メモ」）増えて **53 枚**。1.1.1 で 13 インチと iPhone にピンチの案内を 1 枚ずつ足して **55 枚**、UI テストに `HeaderAndPaperUITests`（「今日」の場所と効き目、空のページが画面の上から始まること）。1.2 で 13 インチに祝日と週の始まりのシートを足して **57 枚**、UI テストに `LanguageUITests`（iOS がどの言語を選ぶか）と `WeekStartUITests`。写真は全部、日本語の起動の引数（`JA_ARGS`）で撮り、`shots/env.txt` に Xcode とシミュレータの版を書く。ユニットテストが互換の fixture（`ledger-*.json`・`screenshot-*.json`）の違いを見つけたときは、その JSON が成果物の `fixtures/` に入る
  7. 1.1 から、別のジョブ **compat-v1.0** が、1.0（コミット a21e469）を取り出し、凍結した写しが 1.0 のファイルと行から作られたものかを照合し、1.1 の fixture を **本物の 1.0 の TegakiKit** と凍結した写しの両方で確かめ（同じ数・失敗 0）、1.0 のアプリの台帳と同期エンジンでもシミュレータで確かめる（[docs/M7A_CONTRACT.md §1.4](docs/M7A_CONTRACT.md)。1.0 の端末と 1.1 の端末が同じ iCloud を使っても、相手の手書きを消したり動かしたりしないことの確かめ）。1.2 から、`tools/weekstart-compat` で、日曜はじまりの週のページと日曜の並びで書いた月のページを本物の 1.0 と本物の 1.1.1 が読んでも、消えない・動かないことも確かめる（K-11）
  8. 1.1.1 から、別のジョブ **blank-paper** が、予定も手書きも無い紙を 4 機種で撮る（成果物 `blank-paper`）
  9. 1.2 から、別のジョブ **l10n-shots** が、9 言語の 13 インチと iPhone の画面（成果物 `l10n-screenshots`、63 枚）、日曜はじまりの日本語、文字を 2 倍にした試し、訳し漏れの数を出す（写真の失敗ではジョブを落とさない）
- 結果は GitHub の「Actions」タブで見られます。緑のチェックなら成功です。成果物の 57 枚の画像（5 機種）と `store/` の 20 枚で、Xcode が無くても画面を確かめられます。CI のシミュレータは iCloud に触りません（署名なしのビルドで entitlements は埋め込まれず、スクリーンショットモードとテストは偽の iCloud を使います）。
- [.github/workflows/testflight.yml](.github/workflows/testflight.yml) は **手動実行** で、署名付きでビルドして TestFlight へ送ります。Apple Developer Program の承認後に 7 つの Secrets（証明書・プロファイル・App Store Connect の API キー）を登録すると使えます。未設定のまま実行すると、何が足りないかを日本語で表示して止まります。M4 からは App ID に iCloud（CloudKit）と Push Notifications を付けたプロファイルが必要です（[docs/M4.md §2.3](docs/M4.md)）。1.2.2 からは Declared Age Range（年齢区分）の権限も要ります（[docs/R1_2_2.md §4](docs/R1_2_2.md)。権限の無いプロファイルでは日本語で止まる）。
- [.github/workflows/ja-baseline.yml](.github/workflows/ja-baseline.yml)（ブランチ `ja-baseline` への push で走る）は、1.1.1 の写真を 1.2 と同じ日本語の引数で撮り直す。1.2 の日本語の写真が 1.1.1 と同じことを `tools/l10n/compare_shots.swift` で画素ごとに比べる相手です。写真の段は `build.yml` と同じにしておく決まりです。
- [.github/workflows/store-shots.yml](.github/workflows/store-shots.yml)（ブランチ `store-shots` への push で走る）は、App Store の各国語の写真を 11 組撮る（成果物 `store-<組>`）。`build.yml` はこの 2 つのブランチでは走りません。
- 成果物（ビルドしたアプリ）は保存していません。

## 手元の Mac で確かめる（Xcode が無くても）

Command Line Tools の `swift` だけで、純粋な部分の検査が通ります。

```bash
cd TegakiKit
swift build            # DayKit / Holidays / Layout / InkModel / Access / KitChecks をビルド
swift run KitChecks    # 「KitChecks: all 29982 checks passed」と出れば OK（1.2.2）
cd ..
python3 -I tools/l10n/lint.py .         # 言語の lint（L-12 は警告だけ）
python3 -I tools/l10n/build.py . --check   # 文字の生成物が元のファイルと合っているか（元を直したら --check なしで作り直す。生成物は手で直さない）
shasum -a 256 -c tools/compat10/DATA_1_1.sha256   # 手書きのデータの 18 ファイルが 1.1.1 のままか
```

アプリ側（UIKit / PencilKit / EventKit / CloudKit）は Xcode でしかコンパイルできないので、構文だけ確かめます。

```bash
for f in $(find Sources Tests -name '*.swift'); do swiftc -parse -swift-version 5 "$f"; done
```

XCTest も Command Line Tools には無いため、`swift test` とシミュレータのテストは GitHub Actions でだけ走ります。1.0.1 からは、アプリとテストの型だけを Mac Catalyst の SDK で確かめる `tools/typecheck/typecheck.sh <作業フォルダ>`（作業フォルダはリポジトリの外）も使えます（[docs/R1_0_1.md](docs/R1_0_1.md)、1.1 で互換テストのターゲットも対象に）。

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
project.yml                         XcodeGen の設定（アプリ名・Bundle ID・Info.plist の内容・entitlements・TegakiKit への依存・テスト・StoreKit の設定ファイル）
Support/Info.plist                  xcodegen generate が作る（git には入れない。手では編集しない）
Support/TegakiCalendar.entitlements iCloud（CloudKit、コンテナ iCloud.com.syfan0.tegakicalendar）とサイレントプッシュ（aps-environment）、1.2.2 から年齢区分（com.apple.developer.declared-age-range）
Support/Products.storekit           StoreKit の設定ファイル（月額・年額の 2 商品と 14 日間の導入オファー。CI のテスト（SKTestSession）と手元の Xcode で App Store Connect の代わりになる）
TegakiKit/                          ローカル Swift パッケージ（Foundation だけ。Xcode 無しの Mac でもビルド・検査できる）
  Package.swift
  HolidayData/                      世界の祝日のデータ（250 の国と地域、2000〜2099 年。python-holidays 0.107 から tools/holidays/gen.py が作る。手では直さない。アプリの bundle に HolidayData/ として入る）
  Sources/DayKit/DayKey.swift       「年・月・日」だけの日付（時差に左右されない計算用）と YearMonth
  Sources/DayKit/UILanguage.swift   10 の表示言語と複数形の分け方
  Sources/DayKit/DateText.swift     日付・曜日・月・数の書式（日本語は 1.1 の手作りのまま、他の言語は雛形。暦はグレゴリオ暦に固定）
  Sources/DayKit/WeekStart.swift    週の始まり（月曜・日曜、曜日の並び、地域からの自動）
  Sources/DayKit/KitStrings.generated.swift  Kit の文字の表（tools/l10n/build.py が作る。手では直さない）
  Sources/Holidays/JapaneseHolidays.swift  日本の祝日（2000〜2099 年、Web 版と同じ規則）
  Sources/Holidays/                 祝日の暦 HolidayCalendar、設定の値 HolidaySetting、データの読み込みと検査 HolidayStore・HolidayFile、日本の橋 JapanHolidayBridge、ライセンス HolidayDataLicense
  Sources/Layout/                   紙の寸法・マスの鍵・予定の正規化形・4 ページの配置（PageLayout、月・週・日・年の engine、時間指定の重なり処理、レーンの間引き、ページの id と移動と初期位置、矩形 ⇄ 予定の範囲 EventRange）、ページごとの一覧の倍率・上限・保存比率と見えている範囲（ZoomPolicy / PaperViewport）、ダブルタップの点から日を引く dayAt、週・日の固定の終日帯（AllDayBand）
  Sources/InkModel/                 手書きの台帳（InkPage / InkStroke、merge、JSON（圧縮形と整形）、LZFSE）、投げなわの数学（LassoGeometry）、Web 版の書き出しの解析と変換（WebImport）、このアプリの書き出しファイル tegaki-app-export v1 の組み立て・解析・ファイル名（AppExport）、取り込み口の 2 形式の入口とページ単位の切り分け（InkImport）、同期の状態ファイルの型（SyncState）と再試行の間隔（SyncBackoff）、週・日の帯の手書きの移し替え（BandMigration）、週の始まりで隠れる線とページの数（WeekStartImpact）
  Sources/Access/                   購読の権利（Plan / ProductIDs、AccessState、AccessPolicy の状態機械と控えとの突き合わせ、AccessSnapshot / AccessCache、文言と数字の純関数 PlanText、公開文書の URL LegalLinks、1.2.1 から App Store の評価のお願いの決まり ReviewPrompt、1.2.2 から年齢区分の決まり AgeAssurance）
  Sources/KitChecks/main.swift      Xcode 無しの Mac で走る検査（swift run KitChecks）。HolidayChecks.swift は祝日の節、Text11.swift は 1.1 の字の写し（日本語が変わっていないことの確かめ）
  Tests/                            LayoutTests / HolidaysTests / InkModelTests / AccessTests、互換の Compat10Tests / Compat12Tests（swift test。CI で実行）
Sources/TegakiCalendar/
  App.swift                         アプリの入口（AppDelegate を付ける）
  ContentView.swift                 CalendarRootScreen を出すだけ
  PrivacyInfo.xcprivacy             プライバシーマニフェスト（追跡なし・収集なし、UserDefaults の理由 CA92.1、1.1 から端末の起動からの時間 System boot time の理由 35F9.1）
  Resources/*.xcstrings             アプリの文字（Localizable と InfoPlist の String Catalog。tools/l10n/build.py が作る。手では直さない）
  Views/CalendarRootScreen.swift    唯一の画面（表示と日付の状態、ヘッダー・固定見出し・キャンバス・投げなわのメニュー・ツールバー・トースト・シート・初回案内・ページごとの保存、予定の作成・編集・削除の流れ）
  Views/PageHeaderView.swift        ◀ ▶・題名・日/週/月/年 の切替・今日・＋予定・⚙（幅 600 pt 未満は 2 段）
  Views/StickyHeaderView.swift      紙の上に固定する見出し（月の曜日行・週の日付見出し・日の日付・年の月名。紙の横スクロールと倍率に追随）
  Views/AllDayBandView.swift        週・日の固定の終日帯（紙の外、書けない。バーをタップで編集、列の空きをタップで作成）
  Views/OnboardingView.swift        初回案内 4 枚
  Views/ToolbarView.swift           ペン・マーカー・消しゴム・投げなわ・予定・元に戻す／やり直す・指でも書く
  Views/EventEditorSheet.swift      予定の作成・編集・閲覧のシート
  Views/EventEditorForm.swift       シートの純粋な状態（終日 ⇄ 時間指定、開始を動かすと長さを保つ、検証）
  Views/RecurrenceScopeDialog.swift 繰り返しの予定の「この回だけ／以降すべて」
  Views/SelectionMenuView.swift     投げなわの「予定にする／削除／選択解除」と置き場所の計算
  Views/SettingsScreen.swift        設定画面（同期・データ・購入・情報の節を含む）
  Views/HolidaySettingsSection.swift / HolidayPickerScreen.swift   設定の祝日の節と、国・州を選ぶ画面
  Views/WeekStartSettingsSection.swift   設定の週の始まりの節と、切り替えるときの説明
  Views/LicenseScreen.swift         オープンソースのライセンス（python-holidays）
  Views/PaperWords.swift            紙と見出しの言語ごとの字の選び方（曜日の記号、月名、終日の札。枠に入らないときの縮め方）
  Views/PaywallSheet.swift          購入画面（ペイウォール: 2 プラン・試用の行・自動更新の説明・購入を復元・規約へのリンク・あとで）
  Views/ReviewRequester.swift       App Store の評価のお願い（StoreKit の requestReview を呼ぶだけ。`import StoreKit` はこのファイルだけ。1.2.1）
  Views/AgeRangeAsker.swift         Apple の年齢区分の確認（Apple の旗を読み、法律で求められる人にだけ Apple の画面を出す。`import DeclaredAgeRange` はこのファイルだけ。1.2.2）
  Views/WebImportSheet.swift        手書きの取り込み（Web 版の書き出しと、このアプリの書き出し。ファイル選択、進捗、結果の出し分け）
  Views/ExportSheet.swift           手書きの書き出し（「データファイル（JSON、すべてのページ）」「このページを PDF」の選択、進行、完成（共有…）、失敗）
  Export/ExportBuilder.swift        書き出しの実行（JSON をページ 1 枚ずつ tmp/TegakiCalendarExport に流し書き、PDF を書く、前回の後始末、失敗の種類）
  Export/PDFPageRenderer.swift      いま開いているページ 1 枚を PDF に（見出し帯（題名・曜日／日付／月名・終日帯）＋紙の描画（ベクタ）＋手書き（2 倍の画像）。現在時刻の線は描かない）
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
  Ink/InkOverlayView.swift          投げなわ・移動・予定ツールの入力と描画（PencilKit の上に重ねる。Pencil は容器の InkPencilGestureRecognizer から受ける（overlay の hitTest は常に nil、M7A のずれ 47）、指は容器の認識器 InkFingerGestureRecognizer から受ける）
  Ink/InkTouchObserver.swift        消しゴムが消して離したかを見る触れ方の観察（ペンへ戻す時機。M7A のずれ 46）
  Ink/InkTrace.swift                TestFlight だけの「記録」（設定 › 情報 の「バージョン」の長押し）
  Ink/InkSnapshot.swift             選んだ手書きの画像（作成シートの「書いた内容」、移動中の絵）
  Ink/InkTools.swift                道具（色・太さ・投げなわ・予定）と PencilKit の道具への変換
  Ink/PencilInteraction.swift       Apple Pencil のダブルタップ／スクイーズ
  Calendar/EventKitService.swift    iPad のカレンダーの予定を読む・作る・直す・消す（許可・任意の日付範囲の取得・正規化・EKSpan）
  Calendar/EventStoreModel.swift    画面用の予定モデル（許可状態・ページの予定・カレンダーの選択肢と登録先・書き込み・変更の購読）
  Calendar/EventDraft.swift         シートが扱う予定の内容、書き込みの失敗の文言、カレンダーの写し
  Store/StoreClient.swift           App Store を隠すプロトコル（StoreClient）と値の型（StoreProduct / StorePurchaseResult）
  Store/LiveStoreClient.swift       本物の StoreKit 2（Product / Transaction / Product.SubscriptionInfo.status / Transaction.updates / AppStore.sync）
  Store/StoreModel.swift            購入の状態（StoreModel / StoreSnapshot: 権利・価格・購入中・結果の文言。refresh の重なりは合流せず再走）、写真モードの偽の App Store
  Store/AccessCacheStore.swift      最後に分かった権利の控え（UserDefaults の accessStateCache）
  Store/StoreStrings.swift          購入の結果・失敗の文言
  Persistence/AppSettings.swift     UserDefaults の鍵と既定値（ページの種類ごとの表示倍率の比率、初回ペイウォールを出したか、1.2.1 の評価のお願いの記録を含む）
  Persistence/HolidayChoice.swift   祝日の設定（1.1 からの方は「日本」、新しい方は「自動」）と今の暦、行の値の文
  Persistence/WeekStartChoice.swift 週の始まりの設定（今お使いの方は月曜、新しい方は「自動」）と iCloud のページとの照らし合わせ
  Persistence/InkPageStore.swift    手書きの保存（Application Support/TegakiCalendar/ink/<pageId>.json.lzfse）と全消去、ページの一覧
  Persistence/SyncStateStore.swift  同期の状態ファイル（ink/state.json）の原子的な読み書き
  Sync/CloudDatabase.swift          CloudKit を隠すプロトコルと値の型（CloudKit を import しない）
  Sync/CloudKitDatabase.swift       本物の CKDatabase の adapter（CloudKit を import する唯一のファイル。CKError の写像、変更トークン、Asset）
  Sync/InMemoryCloudDatabase.swift  メモリ上の偽の iCloud（テスト・スクリーンショットモード・XCTest のホスト用）
  Sync/InkPageRecord.swift          InkPage ⇄ レコード、Meta レコード
  Sync/SyncStatus.swift             同期の状態の型と、ヘッダー・設定画面の文言
  Sync/SyncEngine.swift             同期エンジン（dirty の帳簿、1.5 秒デバウンス、差分取得、衝突の merge、再試行、全消去、取り込み、アカウントの切替）
  Support/L10n.swift                アプリの文字の入口 L（言語、キーから文字、埋め込み、複数形）
  Support/ScreenshotMode.swift      CI のスクリーンショットモード（見本の予定と手書き、--screenshot-page、--screenshot-sheet、--screenshot-landscape、--screenshot-zoom、--screenshot-offset、--screenshot-readonly、1.2 の --screenshot-holidays、--screenshot-week-start）
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
  CalendarRootScreenTests.swift     紙の領域の高さ（帯を引く）・閲覧専用の判定・取り込みの失敗文・評価のお願いの 2 つの関門（1.2.1）のテスト
  AgeRangeAskerTests.swift          年齢区分の確認がテストの入れ物では Apple を呼ぶ前に止まること・OS の帯（1.2.2）のテスト
  ExportBuilderTests.swift          書き出しのテスト（全ページの JSON と pageId 順・帯の線の移し替え・取り込み口との往復・進行・空のとき・後始末・大きなファイル（8 ページ × 1,000 本）の常駐メモリ・PDF の 1 ページと大きさ・4 種の PDF・ファイル名と題名）
  ExportSheetTests.swift            書き出しシートの文言・進行・完成文・大きさの表記・失敗文のテスト
  WebImportSheetTests.swift         取り込みの完成文の出し分け（Web 版／このアプリ）のテスト
  SyncEngineTests.swift             同期エンジンのテスト（偽の iCloud と TestSleeper で。アカウント確認・デバウンス・衝突・取得・削除・再試行・ゾーン消失・プッシュ・アカウント切替・全消去・取り込み）
  InkPageRecordTests.swift          レコードの写像のテスト
  SyncStateStoreTests.swift         状態ファイルの読み書きのテスト
  CloudKitDatabaseMapTests.swift    CKError → CloudError の写像のテスト
  StoreModelTests.swift             購入の状態のテスト（偽の App Store と控えで。起動時の控え・オフライン・購入・復元・refresh の重なり・価格の再取得）
  FakeStoreClient.swift             テスト用の偽の App Store とメモリ上の控え
  StoreKitSessionTests.swift        StoreKit のテスト環境（SKTestSession と Products.storekit）で本物の LiveStoreClient を回すテスト（購入・期限切れ・返金・試用の資格）
  PaywallSheetTests.swift / SettingsScreenTests.swift / EventEditorSheetTests.swift   購入画面・設定 › 購入・閲覧シートの脚注の文言のテスト
  TestSleeper.swift                 テスト用の sleep
  L10nTests.swift / LocalizationBundleTests.swift / ToolbarFitTests.swift / PaperFitTests.swift   言語の仕組みと、訳語が枠に入ることのテスト（1.2）
  HolidayChoiceTests.swift / WeekStartChoiceTests.swift / WeekStartLedgerTests.swift   祝日と週の始まりの移行と切り替えのテスト（1.2）
Tests/TegakiCalendarUITests/        iPhone の UI テスト（YearTapUITests・EraserAndBelowDayUITests・HeaderAndPaperUITests・BlankPaperShotsUITests・LanguageUITests・WeekStartUITests）
tools/l10n/                         言語の道具: build.py（元のファイル source/・translations/ から文字の生成物を作る）、lint.py（14 の規則）、baseline.py と ja-baseline.tsv（1.1.1 の日本語の一覧）、compare_shots.swift（写真の画素の比べ）
tools/holidays/                     祝日のデータの生成器（gen.py、版を固定した requirements.txt、毎年の更新の手順 README.md）
tools/compat10/ / tools/weekstart-compat/   本物の 1.0 で確かめる互換の道具（K-7）と、古い版の本物で週の始まりを確かめる道具（K-11）
tools/typecheck/                    Xcode の無い Mac でアプリとテストの型を確かめる道具
.github/workflows/build.yml         GitHub Actions の設定（push ごと。ジョブは build-and-test・compat-v1.0・l10n-shots・blank-paper）
.github/workflows/testflight.yml    TestFlight への配信（手動実行。Secrets が必要）
.github/workflows/ja-baseline.yml   1.1.1 の日本語の写真を撮り直す（ブランチ ja-baseline への push）
.github/workflows/store-shots.yml   App Store の各国語の写真を撮る（ブランチ store-shots への push）
docs/                               設計書・契約・実装結果・価格・登録手順・規約類（上の表）
```

## 対応機種・条件

- アプリ名: **てがきカレンダー**（Bundle ID: `com.syfan0.tegakicalendar`）
- iPadOS / iOS 17 以降。iPhone・iPad mini・11 インチ・13 インチの iPad のどれでも読める大きさで出します（主役は iPad と Apple Pencil です）
- 縦向き・横向きのどちらでも使えます
- iCloud 同期は、iPad で iCloud にサインインしていれば自動で使われます（サインインしていなければ iPad の中だけに保存。アプリ側の設定は要りません）
- 1.1 までの配信は EU を除く 148 の国と地域です。本人の決定（2026-11-04）で **EU 27 か国でも売ります**。入れるのは 1.2 を公開した後で、本人の届け出（デジタルサービス法の trader）が通ってから（手順と順番は [docs/M7B_CONTRACT.md §11](docs/M7B_CONTRACT.md)、[docs/APPLE_ENROLLMENT.md 4-5](docs/APPLE_ENROLLMENT.md)）。届け出が間に合わなければ 1.2 を 148 の国と地域で先に出します
