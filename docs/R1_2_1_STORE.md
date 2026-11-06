# 1.2.1 の App Store の文 — キーワード・新機能の文・規約の URL

- 版: 1.2.1（Connect の版 `73e81f09-1093-4356-a344-9bfe8f15640b`、PREPARE_FOR_SUBMISSION。編集できる App 情報 `8cd77094-725b-43d9-84b4-aed652a490f2`）。作業ブランチ `r121`（`main` の a0f61cb から）。
- 本人の決定（2026-11-07「1〜7どうぞ」）のうち、この文書が受け持つのは **2（キーワード）** と **3 の後半（説明の利用規約の URL）**、それに 1.2.1 の **新機能の文**・`urls.txt`・**審査メモ**（§11。2026-11-07 のレビューの指摘で受け持ちに入れた）です。
- **Connect にはまだ何も入れていません。** 本人がこの文書の表を見て「この内容で入れてよい」と言った後に、リードが入れます。審査への提出と公開は、そのとき改めて本人の言葉をもらいます。
- 評価のお願い（決定 1）は、本人の指示どおり新機能の文に書きません（「細かな改善」に含めます）。
- 原稿は `docs/store/`（[README](store/README.md)）。数え方は README と同じで、ファイルの末尾の改行 1 つを除いて数えます。

## 1. キーワードの決まり（Apple）

| 決まり | 出どころ |
| --- | --- |
| **100 字まで。Apple は「字」で数える（バイトではない）** | 下の「字かバイトか」 |
| 語は半角の「,」で区切る。「,」の前後に空白を入れない（語の中の空白はよい。例 “Real Estate”） | Apple「App Store での検索」<https://developer.apple.com/app-store/search/> |
| 名前・サブタイトル・カテゴリの語を繰り返さない（複数形も同じ語とみなす） | 同上（名前・サブタイトル・カテゴリと検索の関係もこのページ） |
| 他のアプリの名前・競合の名前・商標を入れない | 同上、App Review Guidelines 2.3.7 <https://developer.apple.com/app-store/review/guidelines/> |
| Apple の商標（Apple Pencil など）を名前・サブタイトル・キーワードに入れない | 1.0 でサブタイトルの「Apple Pencil」が 5.2.5 で差し戻された（[M6.md](M6.md) の「2 回目の差し戻し」）。キーワードの「Pencil」もそのとき「ペン入力」に替えた |
| 価格・「無料」・「いちばん」のような語を入れない | 2.3.7（価格の情報や、関係の無い語で埋めない）、README の「事実だけを書く」 |
| 1 つの語は 2 字より長く | Apple のヘルプ「プラットフォームのバージョン情報」<https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information> |

**字かバイトか**: Apple の文書は言い方がそろっていません。「App Store での検索」と「製品ページ」<https://developer.apple.com/app-store/product-page/> は「100 字」、ヘルプの「プラットフォームのバージョン情報」は「100 バイト」と書いています。決め手は Connect の実際の動きです。**ja のキーワード（1.0 から）は 68 字で、UTF-8 では 160 バイト**あります。Connect はこれを受け付け、1.0〜1.2 の 5 回の審査を通り、いま公開中の 1.2 にも 1.2.1 の版にも入っています。100 バイトで数えるなら拒まれているはずなので、**Connect は字で数えています**（UTF-16 でも 136 バイト、Shift_JIS でも 114 バイトで、どのバイトの数え方でも 100 を超える）。2013 年に Apple が全言語で「100 字」に改めたという記録もあります（<https://www.ibabbleon.com/copywriter-translator/2013/06/apple-finally-allows-100-characters-of-keywords-in-all-languages-of-the-app-store/>。Apple の文書ではない）。

1.2 の原稿は「100 バイト（漢字・かな・ハングルは 1 字 3 バイト）」で書いていたので、ko・zh-Hans・zh-Hant は 100 字の 4 割ほどしか使っていませんでした。1.2.1 で埋め直します。lint（L-9）も字で数えるように直しました（§7）。

1 つの語の長さは、ヘルプの「2 字より長く」に対して、ja の 2 字の語（メモ・日記・週間など）が 1.0 から通っています。lint は今までどおり、ラテン文字は 3 字以上、漢字・かな・ハングルは 2 字以上を求めます。

**念のため**: 新しい ko・zh・ja の文字列は 87〜92 字（UTF-8 では 213〜226 バイト）で、160 バイトより長いのは初めてです。Connect が長さで拒んだら、リードはその場で止めて本人に知らせます（自分で語を削って入れ直さない）。拒まれても Connect の値は 1.2 のままで、何も壊れません。

カテゴリは 主「仕事効率化」・副「ライフスタイル」（[M6_CONTRACT.md](M6_CONTRACT.md) §4.6）なので、その語（productivity・lifestyle・效率・생산성 など）も入れていません。

## 2. 今の Connect と原稿の照らし合わせ（2026-11-07、GET だけ）

読んだもの: 1.2.1 の版の 16 ロケール（キーワード・説明・新機能の文・プロモーションテキスト・サポート URL）、1.2.1 の App 情報の 16 ロケール（名前・サブタイトル・プライバシーポリシー URL）。比べるために、公開中の 1.2 の版（`e38db288…`）と App 情報（`cd41d126…`）も読みました。

| 欄 | 1.2.1 の Connect | 原稿（直す前） | ずれと扱い |
| --- | --- | --- | --- |
| 説明・キーワード | 15 ロケールとも原稿と 1 字も違わない。ja は 1.2 と同じ | — | なし |
| 名前・サブタイトル | 原稿どおり。en-US・en-GB・en-AU・en-CA は `name.txt` の 2 行目「Tegaki: Handwritten Planner」、ほかの 11 は 1 行目 | — | なし（`locales.json` の en-US に `"nameLine": 2` と書いた。§7） |
| サポート URL・プライバシーポリシー URL | ja 以外の 15 は英語のページ（`app/en/`）、ja は日本語のページ | 11 のフォルダの `urls.txt` が日本語のページ | **原稿が古かった** → `urls.txt` を Connect に合わせた（§6） |
| 新機能の文 | 16 ロケールとも空 | 1.2 の文 | 新しい版なので当然。1.2.1 の文を書いた（§4） |
| **プロモーションテキスト** | **16 ロケールとも空** | 15 は 1.2 の文、ja は原稿に無し | **新しい版を作ったときに写らなかった**（公開中の 1.2 には 16 とも入っている）。**入れないまま 1.2.1 を公開すると、店頭のプロモーションテキストが消えます。** 1.2.1 の版に、1.2 と同じ文を入れ直す（ja は `ja/promo.txt` に 1.2 の値 127 字を写した。ほかは各 `promo.txt` のまま） |
| ja の名前・サブタイトル・キーワード | — | 原稿に無し | `ja/` に写しを置いた（`name.txt`・`subtitle.txt` は変えない。lint でキーワードの重なりを見るため） |

公開中の 1.2 の版と App 情報は、1.2 を出したときの原稿どおりです（URL は日本語のページ。公開中の版では URL を替えられず 409 になった記録は [M7B.md](M7B.md) の「審査の通過と EU の届け出」）。

## 3. キーワード（ロケールごと）

「残す」は 1.2 からある語、「足す」は 1.2.1 で入れる語、「外す」は 1.2.1 で抜く語です。日本語はその語の意味（逆に訳したもの）。

### ja（日本）

名前「てがきカレンダー」、サブタイトル「予定の上にそのまま手書きできる手帳」。

| | 字数 | キーワード |
| --- | --- | --- |
| 1.2（今） | 68 | 手書き,手帳,予定,スケジュール,ペン入力,ペン,メモ,日記,週間,月間,年間,iCloud,同期,ノート,祝日,スタイラス,プランナー |
| **1.2.1（案）** | **92** | スケジュール,ペン入力,ペン,メモ,日記,週間,月間,年間,iCloud,同期,ノート,祝日,スタイラス,プランナー,デジタル,バーチカル,マンスリー,ウィークリー,デイリー,書き込み |

| 語 | 扱い | 理由 |
| --- | --- | --- |
| 手書き・手帳・予定 | 外す | サブタイトルにある（Apple は名前・サブタイトルの語をもともと検索に使うので、字数の無駄） |
| スケジュール・ペン入力・ペン・メモ・日記・週間・月間・年間・同期・ノート・祝日・スタイラス・プランナー | 残す | 名前・サブタイトルに無い語 |
| iCloud | 残す | 本人の決定（1.0 からあり、5 回の審査を通った。[M7B.md](M7B.md) の「Connect への入力」）。Apple の商標なので、lint では ja だけの例外として書いた（`keywordMarks`） |
| デジタル | 足す | サブタイトルの「手帳」と組んで「デジタル手帳」で探す人に当たる |
| バーチカル | 足す | 週のページ（7 列の時間軸）は、紙の手帳で「バーチカル」と呼ぶ形 |
| マンスリー・ウィークリー・デイリー | 足す | 紙の手帳の言い方（月・週・日のページ）。「週間・月間」とは別の語で探される |
| 書き込み | 足す | 「カレンダー 書き込み」のように探す人に当たる（「手書き」とは別の語） |

**別の案（外すだけ）**: スケジュール,ペン入力,ペン,メモ,日記,週間,月間,年間,iCloud,同期,ノート,祝日,スタイラス,プランナー（58 字）。決定の言葉は「重なる語を外す」なので、足す 6 語が要らなければこちらにします。既定は上の「案」です（空いた 42 字を使わないのはもったいないため）。

### en-US（en-GB・en-AU・en-CA も同じ文）

名前「Tegaki: Handwritten Planner」、サブタイトル「A planner you write by hand」。

| | 字数 | キーワード |
| --- | --- | --- |
| 1.2（今） | 98 | handwriting,notes,journal,diary,schedule,agenda,stylus,pen,weekly,monthly,holidays,notebook,events |
| **1.2.1（案）** | **97** | handwriting,notes,journal,diary,schedule,agenda,stylus,pen,weekly,monthly,holidays,calendar,daily |

| 語 | 日本語 | 扱い | 理由 |
| --- | --- | --- | --- |
| handwriting | 手書き | 残す | いちばん大事な語。名前の Handwritten とは別の語（語ごとに比べると重ならない） |
| notes | メモ・ノート | 残す | |
| journal | 日誌・ジャーナル | 残す | |
| diary | 日記（英国では「手帳」） | 残す | en-GB・en-AU の店頭で強い |
| schedule | 予定・スケジュール | 残す | |
| agenda | 予定表・手帳 | 残す | |
| stylus | スタイラス（タッチペン） | 残す | |
| pen | ペン | 残す | |
| weekly | 週の | 残す | 名前の Planner と組んで「weekly planner」 |
| monthly | 月の | 残す | 同じく「monthly planner」 |
| holidays | 祝日・休日 | 残す | 1.2 の世界の祝日。足す calendar と組んで「holiday calendar」 |
| **calendar** | カレンダー | **足す** | 本人の指摘。1.2 は名前の案に「Tegaki Calendar」があったので避けていたが、Connect の名前は「Tegaki: Handwritten Planner」に決まり、カレンダーの語がどこにも無かった |
| **daily** | 毎日の・日の | **足す** | 日のページ。「daily planner」「daily calendar」 |
| notebook | ノート帳 | 外す | notes とは別の語なので、「notebook」「digital notebook」で探す人には出にくくなる。calendar を入れる字数のための引き換え（100 字に収めるため。Apple が同じ語とみなすのは複数形だけ） |
| events | 予定・行事 | 外す | 一般的すぎる。calendar で足りる |

（daily の代わりに digital（デジタル。「digital planner」）も考えました。日のページがあることをそのまま表す daily を選びました。）

### zh-Hans（中国本土・シンガポール）

名前「Tegaki 手写日历」、サブタイトル「在日程上直接手写的手帐」。

| | 字数 | キーワード |
| --- | --- | --- |
| 1.2（今） | 39 | 笔记,备忘录,日记,时间表,计划,触控笔,钢笔,周计划,月计划,节假日,记事本 |
| **1.2.1（案）** | **88** | 笔记,备忘录,日记,时间表,计划,触控笔,钢笔,周计划,月计划,节假日,记事本,手账,电子手账,月历,年历,日志,记录,时间管理,计划表,年计划,安排,规划,电容笔,书写,同步 |

| 語 | 日本語 | 扱い | 理由 |
| --- | --- | --- | --- |
| 笔记・备忘录・日记・时间表・计划・触控笔・钢笔・周计划・月计划・节假日・记事本 | ノート・メモ帳・日記・時間表・計画・タッチペン・ペン（万年筆）・週の計画・月の計画・祝日と休日・メモ帳 | 残す | 1.2 のまま |
| 手账 | 手帳 | 足す | サブタイトルは「手帐」と書いたが、中国本土でふつうに打たれる字は「手账」（同じ語の別の字）。検索は字が違うと別の語になるので足す |
| 电子手账 | 電子手帳（デジタル手帳） | 足す | |
| 月历・年历 | 月のカレンダー・年のカレンダー | 足す | 月・年のページ。名前の「日历」とは別の語 |
| 日志 | 日誌 | 足す | |
| 记录 | 記録 | 足す | |
| 时间管理 | 時間管理 | 足す | |
| 计划表 | 計画表 | 足す | |
| 年计划 | 年の計画 | 足す | 年のページ |
| 安排 | 予定を組む | 足す | サブタイトルの「日程」と組んで「日程安排」 |
| 规划 | 計画を立てる | 足す | |
| 电容笔 | タッチペン（静電式） | 足す | 中国で iPad 用のペンをこう呼ぶ（一般の語で、商標ではない） |
| 书写 | 書くこと | 足す | 名前・サブタイトルの「手写」とは別の語 |
| 同步 | 同期 | 足す | iCloud の同期（iCloud の語は入れない） |

### zh-Hant（台湾・香港・マカオ）

名前「Tegaki 手寫行事曆」、サブタイトル「在行程上直接手寫的手帳」。

| | 字数 | キーワード |
| --- | --- | --- |
| 1.2（今） | 38 | 筆記,備忘錄,日記,時間表,計畫,觸控筆,鋼筆,週計畫,月計畫,假日,記事本 |
| **1.2.1（案）** | **87** | 筆記,備忘錄,日記,時間表,計畫,觸控筆,鋼筆,週計畫,月計畫,假日,記事本,日曆,月曆,年曆,日誌,記錄,時間管理,計畫表,年計畫,安排,規劃,國定假日,電容筆,書寫,同步 |

| 語 | 日本語 | 扱い | 理由 |
| --- | --- | --- | --- |
| 筆記・備忘錄・日記・時間表・計畫・觸控筆・鋼筆・週計畫・月計畫・假日・記事本 | ノート・メモ帳・日記・時間表・計画・タッチペン・ペン（万年筆）・週の計画・月の計画・休日・メモ帳 | 残す | 1.2 のまま |
| 日曆 | カレンダー | 足す | 名前は「行事曆」（予定表としてのカレンダー）で、「日曆」は別の語。台湾でよく探される |
| 月曆・年曆 | 月のカレンダー・年のカレンダー | 足す | 月・年のページ |
| 日誌 | 日誌 | 足す | |
| 記錄 | 記録 | 足す | |
| 時間管理 | 時間管理 | 足す | |
| 計畫表 | 計画表 | 足す | |
| 年計畫 | 年の計画 | 足す | 年のページ |
| 安排 | 予定を組む | 足す | |
| 規劃 | 計画を立てる | 足す | |
| 國定假日 | 国の祝日 | 足す | 台湾で祝日をこう探す（1.2 の世界の祝日） |
| 電容筆 | タッチペン（静電式） | 足す | 台湾でも iPad 用のペンをこう呼ぶ |
| 書寫 | 書くこと | 足す | |
| 同步 | 同期 | 足す | |

### ko（韓国）

名前「Tegaki 손글씨 캘린더」、サブタイトル「일정 위에 바로 쓰는 플래너」。

| | 字数 | キーワード |
| --- | --- | --- |
| 1.2（今） | 39 | 메모,일기,저널,스케줄,다이어리,스타일러스,주간,월간,공휴일,노트,필기 |
| **1.2.1（案）** | **89** | 메모,일기,저널,스케줄,다이어리,스타일러스,주간,월간,공휴일,노트,필기,달력,메모장,일기장,저널링,스케줄러,계획표,기록,데일리,위클리,먼슬리,연간,디지털,동기화 |

| 語 | 日本語 | 扱い | 理由 |
| --- | --- | --- | --- |
| 메모・일기・저널・스케줄・다이어리・스타일러스・주간・월간・공휴일・노트・필기 | メモ・日記・ジャーナル・スケジュール・ダイアリー（手帳）・スタイラス・週間・月間・祝日・ノート・筆記 | 残す | 1.2 のまま |
| 달력 | カレンダー（暦） | 足す | 名前の「캘린더」とは別の語で、韓国でよく使う |
| 메모장 | メモ帳 | 足す | |
| 일기장 | 日記帳 | 足す | |
| 저널링 | ジャーナリング | 足す | |
| 스케줄러 | スケジューラー | 足す | 韓国で手帳アプリをこう探す |
| 계획표 | 計画表 | 足す | |
| 기록 | 記録 | 足す | |
| 데일리・위클리・먼슬리 | デイリー・ウィークリー・マンスリー | 足す | 韓国の手帳の言い方（日・週・月のページ） |
| 연간 | 年間 | 足す | 年のページ |
| 디지털 | デジタル | 足す | サブタイトルの「플래너」と組んで「디지털 플래너」、「디지털 다이어리」 |
| 동기화 | 同期 | 足す | iCloud の同期 |

サブタイトルの「일정」（予定）を含む「일정관리」（予定管理）はよく探される語ですが、サブタイトルの語の繰り返しになるので入れていません。

### ほかの 8 ロケールのキーワード

fr-FR（fr-CA）・de-DE・it・pt-BR・pt-PT・es-MX・es-ES は **変えません**（決定 2 の対象外）。新しい lint の決まり（§7）でも 7 つとも通ります。

## 4. 新機能の文（1.2.1、16 ロケール）

ja が元です。ja 以外は `source-ja/whatsnew.txt`（ja と同じ 2 つの点に、訳についての 1 行を足したもの）を訳しました。訳についての 1 行は、どのロケールも 1.2 の新機能の文の最後の行と 1 字も違いません。iOS の画面の名前は出てこず、アプリの中の名前（利用規約・プライバシーポリシー・サポート）は、アプリのその言語の訳（`tools/l10n/translations/`、設定 › 情報 の行）と同じ語にし、1.2 の新機能の文がアプリの中の名前を囲んだのと同じ引用符で囲みました（en・it・es・pt と zh-Hans は “…”、fr は « … »、de は „…“、zh-Hant は「…」、ko は ‘…’。2026-11-07 のレビューの指摘で、初めの案では fr・it・es・pt・en・ko が囲んでいなかった）。pt-PT もアプリの画面の語（ブラジルのポルトガル語）のままです（README の決まり）。

1.2 の en-US には「これまで日本語でお使いの方へ」の日本語の 1 文がありましたが、1.2.1 では要らないので入れません（`source-ja/whatsnew.en-US.txt` は消し、en-US もほかと同じ元にしました）。

### ja（94 字）

```text
・日本語以外の言語で表示しているときは、アプリの中の利用規約・プライバシーポリシー・サポートのリンクが、日本語のページではなく英語のページを開くようになりました。
・細かな改善をしました。
```

### source-ja（ja 以外の元。入力しない。139 字）

```text
・日本語以外の言語で表示しているときは、アプリの中の利用規約・プライバシーポリシー・サポートのリンクが、日本語のページではなく英語のページを開くようになりました。
・細かな改善をしました。

訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。
```

### 各ロケール

| ロケール | 字数 | 文 | 日本語に訳し戻すと |
| --- | --- | --- | --- |
| en-US（en-GB・en-AU・en-CA も同じ） | 316 | • When the app is shown in a language other than Japanese, the “Terms of Service”, “Privacy Policy” and “Support” links in the app now open English pages instead of Japanese pages.<br>• Small improvements.<br><br>Translations were made with AI and have not yet been reviewed by native speakers. Please tell us about mistakes. | ・アプリが日本語以外の言語で表示されているとき、アプリの中の「サービス規約」「プライバシーポリシー」「サポート」のリンクが、日本語のページではなく英語のページを開くようになりました。<br>・小さな改善。<br><br>訳は AI で作られ、まだ母語の人の確認を受けていません。誤りを教えてください。 |
| zh-Hans | 99 | • 以日语以外的语言显示时，App 内的“服务条款”“隐私政策”和“支持”链接现在会打开英语页面，而不是日语页面。<br>• 细节改进。<br><br>译文由 AI 生成，尚未经过母语人士审核。如有错误，请告诉我们。 | ・日本語以外の言語で表示しているとき、App の中の「サービス規約」「プライバシーポリシー」「サポート」のリンクが、日本語のページではなく英語のページを開くようになりました。<br>・細かな改善。<br><br>訳文は AI が作り、まだ母語の人の確認を受けていません。誤りがあれば教えてください。 |
| zh-Hant | 100 | • 以日文以外的語言顯示時，App 內的「服務條款」「隱私權政策」和「支援」連結現在會開啟英文頁面，而不是日文頁面。<br>• 細節改進。<br><br>譯文由 AI 製作，尚未經過母語人士審閱。如有錯誤，請告訴我們。 | ・日本語以外の言語で表示しているとき、App の中の「サービス規約」「プライバシーポリシー」「サポート」のリンクが、日本語のページではなく英語のページを開くようになりました。<br>・細かな改善。<br><br>訳文は AI が作り、まだ母語の人の確認を受けていません。誤りがあれば教えてください。 |
| ko | 156 | • 일본어 이외의 언어로 표시할 때, 앱 안의 ‘서비스 약관’, ‘개인정보 처리방침’, ‘지원’ 링크가 일본어 페이지가 아닌 영어 페이지를 열도록 바뀌었어요.<br>• 자잘한 부분을 개선했어요.<br><br>번역은 AI로 만들었고 아직 원어민의 검토를 받지 않았어요. 오류가 있으면 알려 주세요. | ・日本語以外の言語で表示するとき、アプリの中のサービス規約・個人情報の取り扱い方針・サポートのリンクが、日本語のページではなく英語のページを開くように変わりました。<br>・細かい所を直しました。<br><br>訳は AI で作り、まだ母語の人の確認を受けていません。誤りがあれば教えてください。 |
| fr-FR（fr-CA も同じ） | 382 | • Quand l’app s’affiche dans une autre langue que le japonais, les liens « Conditions de service », « Politique de confidentialité » et « Assistance » de l’app ouvrent désormais des pages en anglais au lieu des pages en japonais.<br>• Petites améliorations.<br><br>Les traductions ont été faites avec une IA et n’ont pas encore été relues par des locuteurs natifs. Signalez-nous les erreurs. | ・アプリが日本語以外の言語で表示されるとき、アプリの「サービス規約」「プライバシーポリシー」「サポート」のリンクは、これからは日本語のページの代わりに英語のページを開きます。<br>・小さな改善。<br><br>訳は AI で作られ、まだ母語の人に読み直されていません。誤りをお知らせください。 |
| de-DE | 356 | • Wenn die App in einer anderen Sprache als Japanisch angezeigt wird, öffnen die Links „Nutzungsbedingungen des Dienstes“, „Datenschutzerklärung“ und „Support“ in der App jetzt englische statt japanische Seiten.<br>• Kleine Verbesserungen.<br><br>Die Übersetzungen wurden mit KI erstellt und noch nicht von Muttersprachlern geprüft. Bitte teilen Sie uns Fehler mit. | ・アプリが日本語以外の言語で表示されるとき、アプリの中の「サービスの利用規約」「データ保護の説明」「サポート」のリンクが、今は日本語のページではなく英語のページを開きます。<br>・小さな改善。<br><br>訳は AI で作られ、まだ母語の人の確認を受けていません。誤りをお知らせください。 |
| it | 355 | • Quando l’app è mostrata in una lingua diversa dal giapponese, i link “Condizioni del servizio”, “Informativa sulla privacy” e “Supporto” nell’app ora aprono pagine in inglese invece che in giapponese.<br>• Piccoli miglioramenti.<br><br>Le traduzioni sono state fatte con l’IA e non sono ancora state riviste da madrelingua. La preghiamo di segnalarci gli errori. | ・アプリが日本語以外の言語で表示されているとき、アプリの中の「サービス規約」「プライバシーの説明」「サポート」のリンクが、今は日本語ではなく英語のページを開きます。<br>・小さな改善。<br><br>訳は AI で作られ、まだ母語の人に見直されていません。誤りをお知らせください。 |
| pt-BR | 324 | • Quando o app é exibido em um idioma diferente do japonês, os links “Termos de Serviço”, “Política de Privacidade” e “Suporte” do app agora abrem páginas em inglês, em vez de páginas em japonês.<br>• Pequenas melhorias.<br><br>As traduções foram feitas com IA e ainda não foram revisadas por falantes nativos. Avise-nos sobre erros. | ・アプリが日本語以外の言語で表示されるとき、アプリの「サービス規約」「プライバシーポリシー」「サポート」のリンクが、今は日本語のページの代わりに英語のページを開きます。<br>・小さな改善。<br><br>訳は AI で作られ、まだ母語の人の確認を受けていません。誤りを知らせてください。 |
| pt-PT | 336 | • Quando a aplicação é mostrada num idioma que não o japonês, as ligações “Termos de Serviço”, “Política de Privacidade” e “Suporte” na aplicação abrem agora páginas em inglês, em vez de páginas em japonês.<br>• Pequenas melhorias.<br><br>As traduções foram feitas com IA e ainda não foram revistas por falantes nativos. Informe-nos sobre erros. | ・アプリが日本語ではない言語で表示されるとき、アプリの中の「サービス規約」「プライバシーポリシー」「サポート」のリンクが、今は日本語のページの代わりに英語のページを開きます。<br>・小さな改善。<br><br>訳は AI で作られ、まだ母語の人に見直されていません。誤りをお知らせください。 |
| es-MX | 347 | • Cuando la app se muestra en un idioma distinto del japonés, los enlaces “Condiciones del servicio”, “Política de privacidad” y “Soporte” de la app ahora abren páginas en inglés en lugar de páginas en japonés.<br>• Pequeñas mejoras.<br><br>Las traducciones se hicieron con IA y todavía no las han revisado hablantes nativos. Avísenos si encuentra errores. | ・アプリが日本語以外の言語で表示されるとき、アプリの「サービス規約」「プライバシーポリシー」「サポート」のリンクが、今は日本語のページの代わりに英語のページを開きます。<br>・小さな改善。<br><br>訳は AI で作られ、まだ母語の人の確認を受けていません。誤りがあればお知らせください。 |
| es-ES | 348 | （es-MX と同じ 2 つの点）<br><br>Las traducciones se han hecho con IA y todavía no las han revisado hablantes nativos. Avísenos si encuentra errores. | （es-MX と同じ）<br><br>訳は AI で作られ、まだ母語の人の確認を受けていません。誤りがあればお知らせください。（最後の 1 行は 1.2 の es-ES の文のまま） |

字数は Connect の上限 4,000 字の 1 割未満です。価格・Apple の商標の語は入れていません。

## 5. 説明（ja 以外の 11 のフォルダ。利用規約とプライバシーポリシーの 2 行だけ）

本人の決定 3「説明の利用規約の URL が日本語のページなら替える」に従い、説明の **利用規約の 1 行だけ** を直しました。ほかの行は 1 字も変えていません。ja の説明は日本語のページのまま（変えない）。

URL を英語のページに替えると、行の頭の「（日本語）」の札が嘘になるので、札も替えました。1.2 の決まり（読む人の言語でないページには、その言語名の札を付ける）のとおり、ja 以外の言語では「（英語）」、en-US は札なしです。

| ロケール | 1.2 の行 | 1.2.1 の行（URL は `…/app/en/terms.html`） | 字数（説明の全体） |
| --- | --- | --- | --- |
| en-US（en-GB・en-AU・en-CA） | Terms of Service (in Japanese): …/app/terms.html | Terms of Service: …/app/en/terms.html | 2,587 → 2,576 |
| zh-Hans | 服务条款（日语）：… | 服务条款（英语）：…（英語） | 1,107 → 1,110 |
| zh-Hant | 服務條款（日文）：… | 服務條款（英文）：…（英語） | 1,106 → 1,109 |
| ko | 서비스 약관(일본어): … | 서비스 약관(영어): …（英語） | 1,437 → 1,439 |
| fr-FR（fr-CA） | Conditions de service (en japonais) : … | Conditions de service (en anglais) : …（英語） | 2,878 → 2,880 |
| de-DE | … des Dienstes (auf Japanisch): … | … des Dienstes (auf Englisch): …（英語） | 2,859 → 2,861 |
| it | Condizioni del servizio (in giapponese): … | Condizioni del servizio (in inglese): …（英語） | 2,713 → 2,713 |
| pt-BR | Termos de Serviço (em japonês): … | Termos de Serviço (em inglês): …（英語） | 2,639 → 2,641 |
| pt-PT | Termos do serviço (em japonês): … | Termos do serviço (em inglês): …（英語） | 2,785 → 2,787 |
| es-MX・es-ES | Condiciones del servicio (en japonés): … | Condiciones del servicio (en inglés): …（英語） | 2,730 → 2,732・2,720 → 2,722 |

日本語の元の `source-ja/description.txt` も「サービス規約（英語）: …/app/en/terms.html」に直しました（入力はしない）。

**プライバシーポリシーの行（リードの判断、2026-11-07）**: 担当は指示どおり利用規約の行だけを直し、プライバシーポリシーの行は日本語のページと「（日本語）」の札のまま残していました。レビューの勧めとリードの判断で、こちらも同じ形（URL を `app/en/privacy.html`、札を「（英語）」にあたる語、en-US は札なし）にそろえました。理由: Connect のプライバシーポリシーの欄（本人の「替えて」、2026-11-06）とアプリの中のリンクはもう英語のページで、説明は次の版まで直せないため。11 のフォルダと `source-ja` の 12 行で、説明の字数は en-US が 11 字減り、ほかは 0〜3 字増えます（4,000 字よりずっと少ない）。ja の説明は日本語のページのまま（§9 の 1）。

英語のページ 3 つは 2026-11-07 に `curl` で 200 を返すことを確かめました。利用規約の英語のページには「日本語の版が優先する参考訳」と書いてあります。

## 6. URL（`urls.txt`）

ja 以外の 11 のフォルダ（en-US・zh-Hans・zh-Hant・ko・fr-FR・de-DE・it・pt-BR・pt-PT・es-MX・es-ES）の `urls.txt` を、Connect の 1.2.1 の今の値に合わせました。

| 行 | 1.2 の原稿 | 1.2.1（Connect と同じ） |
| --- | --- | --- |
| 1 行目（サポート URL、版の欄） | `https://syfan0-star.github.io/tegaki-calendar/app/support.html` | `https://syfan0-star.github.io/tegaki-calendar/app/en/support.html` |
| 2 行目（プライバシーポリシー URL、App 情報の欄） | `https://syfan0-star.github.io/tegaki-calendar/app/privacy.html` | `https://syfan0-star.github.io/tegaki-calendar/app/en/privacy.html` |

ja は `urls.txt` を置かず、Connect も日本語のページのまま。en-GB・en-AU・en-CA・fr-CA は写し（`copyOf`）なので同じ値で、Connect でも英語のページになっています。Connect に入れ直す物はありません。

## 7. lint（L-9）の直し

`tools/l10n/lint.py` の L-9 のキーワードの決まりを、Apple の本当の決まりに合わせました。

| | 1.2 | 1.2.1 |
| --- | --- | --- |
| 長さ | UTF-8 で 100 バイト | **100 字**（§1） |
| 避ける名前の語 | `name.txt` の 3 案すべての語（en-US は Calendar も） | **Connect に入っている名前**（`locales.json` の `nameLine` 行目、無ければ 1 行目）と **サブタイトル** の語 |
| 比べ方 | 名前の語がキーワードの中に字として含まれていたら止める | ラテン文字は **語ごと**（英語の複数形 s・es・y→ies は同じ語。「hand」は「handwriting」と重ならない）。漢字・かな・ハングルは、名前かサブタイトルにその語がまるごとある、またはその語が名前・サブタイトルの語（空白や記号で区切られた語）を含むと止める。**ja・zh-Hans・zh-Hant** は名前とサブタイトルに空白が無く、全体が 1 語になって中の語を見分けられないので、その語を `locales.json` の `nameWords` に手で書き、キーワードがその語を含むと止める |
| ほか | 「,」の横の空白は黙って無視 | 「,」の横の空白、同じ語の 2 度入れも止める。`nameWords` の語が名前にもサブタイトルにも無いとき（書き違い）も止める |
| Apple の商標 | どのロケールも止める | ja の `iCloud` だけ、本人の決定として通す（`locales.json` の `keywordMarks`） |

`locales.json` には、en-US の `"nameLine": 2`、ja・zh-Hans・zh-Hant の `nameWords`（ja: てがき・カレンダー・予定・手書き・手帳、zh-Hans: 手写・日历・日程・手帐、zh-Hant: 手寫・行事曆・行程・手帳）、ja の `fields`（`name.txt`・`subtitle.txt`・`keywords.txt`・`promo.txt`・`whatsnew.txt`）と `keywordMarks`、en-US の `whatsnewSource` の変更を書き、`about` に `nameLine`・`keywordMarks` の説明を足しました。`docs/store/README.md` の「100 バイト」と、キーワード・URL の決まりの段も直しました。

止めるべき物を止めるか、使い捨ての写しで試しました: 1.2 の ja のキーワード（手書き・手帳・予定）、「カレンダー」、en-US の planners・hand・write、「, notes」の空白、notes の 2 度入れ、149 字、ko の iCloud・일정관리・플래너・캘린더앱・손글씨 が止まり、handwriting・calendar・Real Estate は通りました。

2026-11-07 のレビューの指摘（ja・zh は空白が無いので「デジタル手帳」「予定表」「手帳アプリ」「日程安排」「手写笔记」が通っていた。複数形は s・es だけで、diaries と diary を同じ語と見ていなかった）で `nameWords` と y→ies を足し、同じように試しました: 「デジタル手帳」（手帳）・「予定表」（予定）・「手帳アプリ」・「日程安排」（日程）・「手写笔记」（手写）・「行程表」（行程）・名前に Diary があるときの diaries、`nameWords` の書き違い（zh-Hant に簡体字の「手写」）が止まり、今の 16 ロケールのキーワード（ja の書き込み・デジタル、zh-Hans の手账・电子手账・月历、zh-Hant の日曆 など）は通りました。**まだ見ないもの**: 英語以外の複数形（it の agenda と agende など）と、`nameWords` に書いていない語（ja・zh のサブタイトルの「そのまま」「直接」のような、検索の語ではない語は書いていない）。

## 8. 確かめ（この Mac、2026-11-07）

| コマンド | 結果 |
| --- | --- |
| `python3 -I tools/l10n/lint.py .`（作業ツリーのまま） | L-9 だけ **FAILED (33)**: 11 のフォルダの説明と `urls.txt` が英語のページ、`LegalLinks.englishPagesPublished = false` が日本語のページを求めるため。キーワードと新機能の文の失敗は 0。ほかの 13 の検査は ok（アプリの担当が値を true にする前の記録。直しの後の結果は §12） |
| 同じ（作業ツリーの写しで `englishPagesPublished = true` にしたもの） | **lint.py: ok — ran L-1 … L-14**（L-9: ok: 12 locales, the URLs on the English side） |
| `python3 -I tools/l10n/build.py . --check` | build.py: every output is what the sources give (xcstrings) |

L-9 は、決定 3 のアプリの直し（`LegalLinks.englishPagesPublished = true`）が同じブランチに入ると通ります。アプリの直しを入れずにこの原稿だけを入れることはしません（逆も同じ。0-38 のとおり、アプリと店頭の文は同じ側を指す）。

## 9. 本人に聞くこと（既定で決めた）

1. **説明のプライバシーポリシーの行も英語のページにそろえるか**。リードの判断: **そろえた**（§5。Connect の欄とアプリの中のリンクに合わせた）。日本語のページに戻すなら 12 行を元の形に戻します。
2. **ja のキーワードに 6 語（デジタル・バーチカル・マンスリー・ウィークリー・デイリー・書き込み）を足すか、重なる 3 語を外すだけにするか**。既定: 足す（§3 の ja）。
3. **en-US の 2 つ目の新しい語**。既定: daily（日のページ）。代わりに digital（デジタル。「digital planner」）にもできます。
4. **審査メモに評価のお願いを書くか**。既定: 書く（§11。Apple の仕組みであること、まれにしか出ないこと、審査と TestFlight の版では呼ばないので審査の人には出ないことを、先に知らせておくため）。書かないなら §11 の 2 の点を消します。

## 10. Connect に入れるとき（リード向け。本人の「この内容で入れてよい」の後）

| 欄 | ロケール | 値 |
| --- | --- | --- |
| キーワード | ja・en-US・en-GB・en-AU・en-CA・zh-Hans・zh-Hant・ko | 各 `keywords.txt`（en-GB・en-AU・en-CA は en-US の値） |
| 新機能の文 | 16 すべて | 各 `whatsnew.txt`（en-GB・en-AU・en-CA は en-US、fr-CA は fr-FR の値） |
| 説明 | ja 以外の 15 | 各 `description.txt`（利用規約とプライバシーポリシーの 2 行だけ違う） |
| プロモーションテキスト | 16 すべて | 各 `promo.txt`（1.2 と同じ文。1.2.1 の版で空になっているのを戻す。審査なしで直せる欄だが、1.2.1 を公開する前に入れる） |
| サポート URL・プライバシーポリシー URL | — | 入れ済み（§6） |
| 審査メモ（App Review に関する情報の「メモ」） | — | `docs/store/review-note.txt`（§11）。1.2.1 の版には今、1.2 のメモがそのまま写っているので必ず入れ替える。ほかの欄（連絡先・デモアカウント無し）は変えない |

- 入れた後は読み戻して原稿と 1 字も違わないことを確かめます（1.2 と同じ形）。
- キーワードが長さで拒まれたら止めて本人に知らせます（§1）。
- 審査メモは §11 の 1.2.1 の文に入れ替えます。入れた後に読み戻して、`review-note.txt`（末尾の改行 1 つを除く）と 1 字も違わないことを確かめます。

## 11. 審査メモ（1.2.1）

2026-11-07 のレビューの指摘で、この文書の受け持ちにしました。Connect の 1.2.1 の版の審査メモ（GET で読んだ。3,500 字・3,942 バイト）は、1.2 の `review-note.txt` と 1 字も違わない写しで、「What is new in 1.2」で始まり、「規約とプライバシーポリシーのページは日本語（正本）」と日本語のページの URL 3 つを書いていました。1.2.1 では、英語の画面で審査する人が開くのは英語のページなので、ビルドと食い違います。`docs/store/review-note.txt` を 1.2.1 の文に書き直しました。

- 大きさ: **3,567 字・3,891 バイト**（上限 4,000 バイト。lint の L-9 が見る）。1.2 の新機能（言語・祝日・週の始まり）の説明は外し、言語の 1 行だけ残した。
- 1.2 から残したもの: サインイン不要、動作の確かめ方、購読と価格が変わらないこと・購入画面の開き方・復元、審査の版の「記録」、サーバーが無いこと。
- 変えたもの: 「What is new in 1.2.1」の 3 つの点（英語のページ・評価のお願い・ほかは変えていない）、規約の文（日本語が正本、英語は参考訳）、URL を日英の 6 つに。
- 評価のお願いに触れるか（R1_2_1.md §8 の 12 がこの文書に任せた）: 触れる（§9 の 4）。

英語の部分を日本語に訳したもの（本人の確認用。Claude が訳した。1.2 のような、別の Claude による逆翻訳ではない）:

> サインイン・アカウントの作成・デモアカウントは要りません。
>
> 1.2.1 の新しい点
> 1. 英語の規約類: アプリが日本語以外の言語で表示されているとき、設定 › 情報 の利用規約・プライバシーポリシー・サポートのリンク（と、購入画面の利用規約・プライバシーポリシーのリンク）が、日本語のページではなく英語のページ（下の app/en/）を開くようになりました。日本語では今までどおり日本語のページを開きます。
> 2. 評価のお願い: Apple の標準の評価の窓（StoreKit の requestReview）を、まれに、条件がすべてそろったときだけ出すことがあります（別の 3 日に書いた、使って 7 日、1 つの版で 1 回まで・90 日あける、書いたページをめくった後の間、ほかに何も出ていない）。初めての起動・書いている間・購入画面の上では出しません。TestFlight と審査の版（サンドボックスのレシート）では呼ばないので、審査の間は出ません。
> 3. ほかは変えていません: ページ・手書き・同期・祝日・週の始まり・購読・価格・データの扱いは 1.2 と同じです。App Privacy は「データの収集なし」のまま（評価のお願いの数と日は端末の中だけ）。
>
> アプリは端末の言語に従います（1.2 から 10 言語。ほかの言語は英語）。アプリごとの言語: 設定 › アプリ › Tegaki › 言語。
>
> 確かめ方:（1.2 と同じ文。「カレンダー」アプリに予定を 2〜3 件足してアプリを開くと、4 つのページに予定が出て、Apple Pencil か「指でも書く」で書ける。予定が無くても、iCloud が無くても書ける。）
>
> 購読と価格は変わりません。（購入画面の開き方と復元は 1.2 と同じ文。）利用規約・プライバシーポリシー・Apple 標準の EULA へのリンクは、購入画面と 設定 › 情報 にあります。利用規約とプライバシーポリシーは日本語が正本です。英語のページは参考訳で、ページにもそう書いてあります。
>
> （審査の版の「記録」と、サーバーが無いことの 2 つの段は 1.2 と同じ文。）
>
> 英語のページ 3 つと、日本語のページ（正本）3 つの URL。

メモの最後に添える日本語の要約（メモの中の文そのまま）:

> 変更は 2 つ。日本語以外の画面では、利用規約・プライバシーポリシー・サポートのリンクが英語のページを開きます。Apple の評価のお願いを、条件がそろったときだけまれに出します（初めての起動・書いている間・購入画面では出さず、審査と TestFlight の版では呼ばない）。ほかは 1.2 と同じ。規約類は日本語が正本で、英語は参考訳。サインイン不要。

英語の 3 ページは 2026-11-07 に `curl` で 200 を返しました。3 つとも頭に「日本語の版が優先する参考訳」と書いてあることは `docs/TERMS.en.md`・`PRIVACY.en.md`・`SUPPORT.en.md` の 3 行目で確かめました。

## 12. レビューの直し（2026-11-07、commit 前）

リードのレビューの指摘のうち、店の担当の 5 つを確かめてから直しました。5 つとも指摘のとおりでした。

| 指摘 | 確かめ | 直し |
| --- | --- | --- |
| 1.2.1 の審査メモを受け持つ人がいない（Connect の 1.2.1 の版に 1.2 のメモが写っている） | GET で読んだメモが `review-note.txt`（末尾の改行を除く）と同じ（3,500 字・3,942 バイト） | §11。`review-note.txt` を書き直し、§10 の表に審査メモの行、§9 の 4 |
| L-9 が ja・zh のサブタイトルの語を中に含むキーワードを止めない。複数形が s・es だけ | `keyword_repeats` を直接呼んで「デジタル手帳」「予定表」「手帳アプリ」「日程安排」が通るのを見た | `locales.json` の `nameWords`（ja・zh-Hans・zh-Hant）と y→ies（§7）。`docs/store/README.md` の決まりの段も |
| `docs/store/README.md` の 2 か所が 1.2.1 と合わない | :127 は説明の利用規約を「（日本語）」と書き、:67 の行は 1.2 の印が無い | :127 を 1.2 と 1.2.1 に分けて書き、:67 の行に「1.2」。審査メモの段にも 1.2.1 を足した |
| en-US の notebook を外す理由が「notes と同じ探し方」 | Apple「App Store での検索」が同じ語とみなすのは複数形だけ（“climbs” と “climb”） | §3 の en-US の表の理由を「notes とは別の語で、notebook で探す人には出にくくなる。calendar の字数との引き換え」に |
| 新機能の文で、アプリの中のリンクの名前を囲んでいない言語がある | 1.2 の文は fr « … »、it・es・pt・en “…”、ko ‘…’ で囲んでいた | en-US・fr-FR・it・es-MX・es-ES・pt-BR・pt-PT と、指摘に無かった ko も 1.2 と同じ引用符で囲んだ（§4 の表と字数も）。de・zh-Hans・zh-Hant は前から囲んでいた |

確かめ（この Mac、アプリの担当の直しも入った作業の木）:

| コマンド | 結果 |
| --- | --- |
| `/usr/bin/python3 -I tools/l10n/lint.py .` | **lint.py: ok — ran L-1 … L-14**（L-9: ok: 12 locales, the URLs on the English side） |
| `/usr/bin/python3 -I tools/l10n/build.py . --check` | build.py: every output is what the sources give (xcstrings) |
| L-9 だけを、使い捨ての写し（ja のキーワードに「デジタル手帳」、zh-Hans に「日程安排」、zh-Hant の `nameWords` に簡体字の「手写」）で | 3 つとも止まった。写しは消した |
