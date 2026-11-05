# M7b（1.2）の実装結果

各役が自分の節を足す（C が最後に整える）。

## S0（`tools/l10n/build.py` の Kit 用の出力。統合の順番の「S の最初」）

### 入れたもの

- `tools/l10n/build.py`（新規。実行権つき）: `python3 -I tools/l10n/build.py [<リポジトリ>]`（省くと、この script のあるリポジトリ）。`tools/l10n/source/kit-*.json`（K・H の元）と `tools/l10n/translations/<言語>.json`（X の訳。9 言語）を読み、`TegakiKit/Sources/DayKit/KitStrings.generated.swift` を書く。先頭の行は「// 生成物。直さない。tools/l10n/build.py」。同じ元からはいつも同じ bytes（キーは辞書順。日付・機械のパスを入れない）で、中身が同じなら書き直さない。
- 生成物の形: `public enum KitStrings` に、§0 の `keys`・`text`・`format`・`plural`（形はそのまま）と `value`（下のずれの 1）。表は言語ごとの `private static let ja / en / zhHans / … : [String: String]` で、`switch language` で選ぶ（§2.3）。`import` は無い（標準ライブラリだけ）。K の `UILanguage`（§0 の 10 の case の名前）と `PluralCategory`（rawValue が "one"・"other"）を使う。
- 表に入るもの: ふつうのキーは ja を元から、ほかの言語はその言語の訳のファイルにあれば。`fixed: true` は `fixedValues` の 10 言語（訳は使わない）。`jaOnly: true` は ja の表だけ（訳は使わない）。Kit の元に無いキーの訳（アプリのキー・古いキー）は使わない。
- 元が空でも作れる: `tools/l10n/` が無い・`source/` が空・`{"owner": "K", "keys": {}}` のどれでも、空の表（`keys` は `[]`、各表は `[:]`）の生成物になり、組み立つ。
- 止めるもの（何も書かずに終了状態 1。ファイルとキーを出す）: 2 つのファイルにある同じキー、1 つの JSON の中の同じ名前（json は黙って後ろを採るため）、§2.4 の形でないキー・`kit.` で始まらないキー、`target` が `kit` でない、`ja` が無い・空、知らない項目（`jaonly` のような綴りの誤りが、黙ってふつうのキーにならないように。項目は §2.3 の 14 個）と項目の型、`fixed` の `fixedValues` が 10 言語ちょうどでない・その ja が `ja` と違う、`fixed` と `jaOnly` の両方、`owner` とファイル名の食い違い、`app-<持ち主>.json`・`kit-<持ち主>.json` でない名前（iCloud の複製「kit-K 2.json」など。訳のファイルも 9 言語の名前だけ）、JSON でない・UTF-8 でない・BOM・NaN、対の無い surrogate、空の訳。`.` で始まる名前は飛ばす。`app-*.json` の中身はまだ読まない（S1）。
- 注意の 1 行: `DayKit/UILanguage.swift` が無いときは、生成の後に「まだ無い（生成物はその型を使うので組み立たない）」と stderr に出す（終了状態は 0）。

### 契約からのずれ・契約が黙っている所の決め方

1. **`KitStrings.value(_ key: String, _ language: UILanguage) -> String?` を足した**（§0 に無い public の関数。§0 の 4 つの形は変えていない）。その言語の表そのものの値で、`text` の受け皿（en → キー）を通らない（無ければ nil）。理由: §7.1 の「kit strings (1.2)」の「全キー × 10 言語が空でない」と K の `testEveryKeyHasTenLanguages` は、`text` だけでは確かめられない（de の訳が無くても en が返るので、訳し漏れが見えない）。
2. **`keys` に `jaOnly` のキーを入れない**（契約は `keys: [String]` とだけ書いている）。`keys` は「10 言語の値を持つべきキー」で、L-2 の「全キー（`jaOnly` は ja だけ）」と同じ範囲。`jaOnly` を入れると、上の「全キー × 10 言語」が契約どおりの実装で必ず落ちる（`kit.date.ja.*` の en は無い）。`jaOnly` のキーは `text(key, .ja)`・`value(key, .ja)` で引け、中身は J-3 が確かめる。複数形の `.one`・`.other` はそれぞれ 1 つのキーとして入る。
3. **生成物はまだ作業の木に置いていない**。生成物は K の `UILanguage`・`PluralCategory` を使うので、`UILanguage.swift` より先に置くと TegakiKit が組み立たなくなり、並行の H の作業も止まる。K が `UILanguage.swift` と `kit-K.json` を書いてから `build.py` を走らせた時に木に入る（統合の順番の「K の前半」の手順のとおり。commit は最後の C）。
4. **`format` の細部**（契約は「`%@` と `%n$@` だけを置き換える。`String(format:)` を使わない」）: `%@` は前から順に `args[0]`・`args[1]`…（`%n$@` はこの数を進めない）。`%n$@` の n は 1〜99（L-5 が許すのは 1〜9）。`%%`・`%d`・ほかの `%` はそのまま残す（`%%` を `%` にしない。Kit の文は `String(format:)` を通らないので、字の `%` はそのまま書ける）。引数の足りない埋め込みは字のまま残す（落ちない・空にしない）。差し込んだ引数の中の `%@` は埋め直さない。
5. **複数形の受け皿**: 形（one・other）は求めた言語の規則で選び、その言語の表に無ければ同じ形のキーを en から引く（例: 訳の前の ko は常に other なので、1 本でも en の `.other`「1 strokes」）。訳がそろえば起きない。
6. 読む元は `kit-*.json` だけ（S0 の指示のとおり）。`kit.` で始まるキーは `kit-*.json` にだけある決まりなので、アプリの元とのキーの重なりは起きない。アプリの元を読み、アプリのキーが `kit.` で始まらないことを見るのは S1。

### 確かめたこと

commit の前なので、`git archive HEAD` で scratchpad に取り出した木に、`build.py` と、K の `UILanguage.swift` の代わり（§0 の形。写しの中だけ）を足して確かめた。

- 生成器: Python 3.9.6（`python3` と `/usr/bin/python3`）と 3.12.16 で 66 項目が全部期待どおり（壊れた入力 57 通りが終了状態 1 で何も書かず、出す文がファイルとキーを指す。空の元 3 通り、アプリの元を読まない、アプリの訳を使わない、`.` の名前を飛ばす、注意の 1 行、いつも同じ結果: 2 回目は書かない・JSON の順と字下げと \u の escape を変えても同じ bytes）。3 つの Python の生成物が 1 byte も違わない。
- 空の元: `swift build --package-path TegakiKit` 緑、KitChecks「all 24446 checks passed」（1.1 と同じ数）、`tools/typecheck/typecheck.sh`（リポジトリの外の空のフォルダ）all OK・警告 0、DayKit を `-warnings-as-errors` で Swift 5 と 6 の両方の mode で組んで警告 0。
- 見本の元（23 キー: `jaOnly`・`fixed`・複数形・改行・引用符・`\(`・全角空白・NBSP・ZWJ・BOM・NUL・結合文字・絵文字・埋め込みの境目）: 生成物を使う確かめの program（写しの中だけ）で 58 項目が合格（en へ・キーへの受け皿、`value`、`%2$@ %1$@` の順、2 桁の n、足りない引数、`%%@`、複数形の 0-8）。KitChecks 24,446・`typecheck.sh` 警告 0。
- 速さ（debug）: `format`（ja の日の題名の型）30 万回 ＋ `text` 30 万回で約 0.85 秒。J-3 の全日付でも数秒の見込み。
- 組み立ての時間（生成物だけ）: 150 キー × 10 言語で -O 3.3 秒・-Onone 0.6 秒、500 キー × 10 言語（0.6 MB）で -O 17.6 秒・-Onone 2.5 秒（ほぼ比例）。辞書の代わりに (キー, 値) の配列にしても 3.0 秒で変わらない（費用は字の literal そのもの）ので、契約どおり辞書の literal のまま。

### 次の役へ

- K: `UILanguage.swift`（§0 の case の名前のまま。`PluralCategory` の rawValue は "one"・"other"）を置き、`kit-K.json`（`owner` は "K"、各キーに `"target": "kit"`）を書いたら `python3 -I tools/l10n/build.py .`。`fixed` のキー（`kit.weekday.letter.0`〜`.6`）は `fixedValues` に 10 言語（ja は `ja` と同じ字）。`jaOnly` は `kit.date.ja.*` など。「全キー × 10 言語」は `KitStrings.keys` と `KitStrings.value` で書ける（「無い言語 → en、無いキー → キー」も、全キー・全言語で `text(k, l) == value(k, l) ?? value(k, .en) ?? k` として確かめられる）。訳（X）の前は、ja 以外は en、en も無ければキーそのものが返る（en の値も X の訳のファイルから来るので、英語の字を期待するテストは X の訳が入るまで通らない）。
- H: `kit-H.json`（`owner` は "H"）に `kit.holiday.estimatedSuffix`・`kit.holiday.dayOff` を書いて同じく生成する。生成物は `UILanguage` が要る（K の `UILanguage.swift` の後）。
- S1: `build_outputs(repo)` が {出力のパス: (中身, 要約)} を返すので、アプリの出力を足し、`--check` は書かずに比べるだけにできる。`app-*.json` の検査（`infoplist` のキーは §2.4 の形の外、アプリのキーは `kit.` で始まらない）と lint は S1。`ESCAPED_RANGES`（Swift の literal で `\u{…}` にする字）は、Python の版で結果が変わらないように Unicode の表に頼らない固定の表にしてある。

## LA（規約類の原稿・App Store の原稿・サポートの返事の定型文。統合の順番の「L・A」）

### 入れたもの

- **L（§6.4）**: `docs/TERMS.md`・`docs/PRIVACY.md`・`docs/SUPPORT.md`（e7b4d2f の文に §6.4 の 4 つを足し、3 つとも「最終更新」を 2026年11月1日 に）。新規 `docs/TERMS.en.md`・`docs/PRIVACY.en.md`・`docs/SUPPORT.en.md`（直した日本語版の英訳。冒頭は契約の 1 文 “This is a translation for convenience. The Japanese version prevails.” と、日本語版へのリンク「日本語版（正本）」）。
- **A（§6.6）**: 新規 `docs/store/`: `README.md`（置き方・欄の決まり・名前の 3 案・新機能の文の組み立て・サブスクリプション・審査メモ・X への手引き・英語の画面の名前の表）、`locales.json`（13 のロケールと ja、Connect の名前、店頭、写し、新機能の文の元）、`ja/whatsnew.txt`（§6.3 の文そのまま）、`en-US/` の 7 つの欄、`source-ja/`（ja 以外の 8 言語の日本語の元。名前・サブタイトル・キーワードの語の意味・promo・説明・新機能の文 2 つ）、`subscriptions/en-US.json`・`subscriptions/source-ja.json`、`review-note.txt`。
- **A（§6.7）**: 新規 `docs/support-replies/`: `README.md`（返事の流れ＝本人の手順、決まり）と、英文と逆翻訳の組の定型文 6 つ（`cancel.md`・`refund.md`・`restore.md`・`language.md`・`holiday-error.md`（「python-holidays に報告する／次の版で直す」の判断表つき）・`translation-error.md`）。

訳（ja・en 以外の 8 言語のストアの文とサブスクリプション）は、この作業の分け方で X がする（契約 §6.3・§6.6 は「A が他の言語へ」。A は日本語と英語の元まで）。

### 契約からのずれ・契約が黙っている所の決め方

規約類（L）:

1. **① 消費者保護の 1 文**（「第 12 条の後」）は、第 12 条の **4 項** として足した。新しい条を立てると第 13 条「連絡先」の番号が変わり、Web の差分も増える。中身は第 12 条（準拠法と裁判所）の続き。
2. **② 日本以外の祝日の 1 文**（「免責の条」）は、第 9 条の **1 項**（その時点の状態で提供・保証しない）の最後に足した。項を足すと 2〜6 項の番号が変わる。中身は 1 項の「保証しない」の具体化。
3. **③ PRIVACY の 1 文**は、§1 の 2 つ目の点（通信する相手は iCloud と App Store だけ）のすぐ後に、点として足した。
4. **④ FAQ の 2 つ**は、よくある質問の最後（「iPad と iPhone で版が違うと？」の後）に、契約の順で足した。契約が決めた 2 文（言語を足すとき）と python-holidays の 1 文（§5.9）は 1 字も変えずに入れた。契約が挙げた中身のほかに足したもの: iOS・iPadOS 17 の道（新機能の文と同じ）、**英語の端末の道「Settings › Apps › Tegaki › Language」と「日本語以外の端末ではアプリの名前が Tegaki」**（1.2 で英語の表示になった日本の人がいちばん読む答えなので）、アプリの中の設定に言語の項目が無いこと、言語・祝日を変えても紙の形と手書きの位置が変わらないこと、週はどの言語でも月曜始まり、祝日の設定は端末ごと、1.1 からの人は日本のまま、名前の言語、利用規約 第 9 条へのリンク。注記の例の年（「2027 年は発表前の推定」「2026 年以降のデータがありません」）はただの例。
5. **最終更新の日付**: 3 文書とも 2026年11月1日（原稿の日。1.1 も原稿の日の 10月31日 にした、21ceba5）。公開の前に文を直したら、その日に直す。施行日の行（本アプリの App Store 公開日）は変えない。
6. **第 11 条（変更の 30 日前の知らせ）**: ① は利用者に有利な変更、② は第 9 条 1 項の具体化で 1.2 の新しい機能にだけ関わる軽い変更、③・④ は規約ではないので、30 日前の知らせは要らない見込み。判断はリード（公開の前の確認で、本人にこの見方を平易に伝える）。
7. **第 3 条 4 の「日本の祝日の表示」**は、1.2 の世界の祝日を書いていない。日本語に足すのは §6.4 の 4 つだけなので直していない（「おおむね次の機能」なので誤りではない）。英語版もそのまま訳した。直すなら次の版で、本人に聞いてから。

英語の 3 文書（L）:

8. **iOS の画面の名前は英語の iOS の語**（Settings > your name > Subscriptions、Privacy & Security、Language & Region など）。解約の道は Apple の 118428 の英語版（公開のページを読んだだけ）の “Settings > [your name] > Subscriptions > … > Cancel Subscription” に合わせた。アプリの名前は英語の端末に出る「Tegaki」。「[your name]」の角括弧は check-legal が英語のページで拒む（`[`）ので使わず、「your name」と書いた。同じ理由で「draft」（DRAFT）も使っていない。
9. **英語版だけにある所**（契約が SUPPORT.en に求めたもの）: 連絡の節の機械翻訳の 1 文（契約の英文そのまま）、解約の節の Apple の 118428 へのリンク、「About the translations」の節（訳が AI で母語の人の確認が無いこと、§6.1）、「Holiday data license」の節（python-holidays 0.107 の MIT の全文。LICENSE と 1 バイトも違わない。CONTRIBUTORS は `https://github.com/vacanza/holidays/blob/v0.107/CONTRIBUTORS`。開くことを確かめた）。FAQ「How do I change the display language?」の 2 つ目の点は、日本語版の「英語の端末の道」の裏返しで「日本語の端末の道」にした。
10. **英語版で URL を英語の同じものに替えた所**: PRIVACY §6 の Apple のプライバシーポリシー（`/jp/legal/privacy/` → `/legal/privacy/`）、連絡先のサポートページ（`app/en/support.html`。英語の 3 ページは一緒に公開する）。Apple メディアサービス利用規約は日本の店頭の規約なので `/jp/` のまま。
11. **作成の経緯の 1 文**: 日本語版の「開発者が AI の草稿をもとに作成し、内容を確認しています」は、英語版では「日本語版は開発者が AI の文をもとに書いて確かめた。英語版は AI が訳し、日本語へ訳し戻して確かめた。英語を母語とする人の確認は無い」にした（開発者は英語を読まないので、英語の中身を確かめたとは書けない）。
12. **PRIVACY.en の付録 B の許可の文**は、日本語の文を引いて意味を添え、「他の言語の端末ではその訳が出る」を足した（英語の許可の文は X が InfoPlist の訳に書くので、ここでは英語の文を決めない）。
13. 価格は日本語版のとおり円で書いた（「価格は App Store の表示が正」も訳した）。

App Store（A）:

14. **置き方**: en-GB・en-AU・en-CA・fr-CA はフォルダを作らず、`locales.json` の `copyOf`。`source-ja/` は入力しない元。キーワードの元は語の意味の一覧なので `keyword-ideas.txt`（ロケールの `keywords.txt` と取り違えないように）。
15. **L-9 の読み方**（S が lint を書くとき用。README にも書いた）: 字数はファイルの末尾の改行 1 つを除いて数える。L-9 が見るのは `locales.json` の code のフォルダ（`source-ja` は見ない）。キーワードの「アプリ名の語」は `name.txt` の 3 行すべての 3 字以上の語（en-US は Tegaki・Calendar・Handwritten・Planner・Ink・Your）。どの案が通っても重ならないように。
16. **サブタイトル**（en-US）は “A planner you write by hand”（27 字）。ja の「予定の上にそのまま手書きできる手帳」は 30 字に入らないので「予定の上に」を落とした。キーワードに名前の語の「planner」を入れられないので、サブタイトルに持たせた。
17. **ja 以外の新機能の文**: 2 つ目の点の「アプリだけ日本語のままにしたいときは」を「アプリだけ端末と違う言語で使いたいときは」に、道のアプリの名前を「Tegaki」に読み替えた（ja 以外の端末で読む人には、日本語に戻す話は当てはまらない）。1 つ目の点に「これまでの日本語に加えて」。
18. **en-US の新機能の文**の並びは、4 つの点 → 端末の言語の 1 文 → 訳の 1 行 → 日本語の 1 文。**日本語の 1 文には、英語の画面の名前を括弧で足した**（「設定」アプリ（Settings）›「アプリ」（Apps）›「てがきカレンダー」（Tegaki）›「言語」（Language））。読むのは英語などの端末の人で、「設定」アプリの画面は英語、アプリの名前も「Tegaki」と出るため。契約の文は「そのまま」なので、ずれとして書く。
19. **説明**: 価格の額を書かない（「価格は App Store に、お住まいの国の通貨で表示されます」）。規約とプライバシーポリシーの URL に “(in Japanese)”。書き出しは “Tegaki is…”（名前の退き先を使っても合う）。ja の説明に無い 4 点（世界の祝日・10 の言語・週は月曜始まりで時刻は 24 時間（米国などで不具合と思われないように）・アカウントの登録が無い）を足した。最後の 1 文は訳についての文。
20. **promo**: ja の 127 字の文を 1.2 に合わせて短くした（世界の祝日は 170 字に入らないので説明だけに）。
21. **サブスクリプション**: 表示名「Tegaki Monthly」「Tegaki Yearly」、グループの表示名「Tegaki」（App 名を使う）。名前の退き先を使っても合う。英語の月額の説明は 45 字に入れるため「月額プラン」を表示名に任せた。価格は書かない（M7B-16）。
22. **審査メモ**: §6.6 の中身のほかに、週は月曜始まりで時刻は 24 時間（設計の上の決め。手書きの位置を変えないため）と、規約とプライバシーポリシーのページが日本語（正本）であることを足した。3,883 バイト（4,000 バイト以内）。
23. **英語の画面の名前**（Settings > Purchase > Restore Purchases、Holidays to Show、Open Source Licenses など）は仮。`docs/store/README.md` の表に一覧を置いた（★ は §6.2 の用語集が決めた語）。X の用語集が固まったら合わせる。

サポートの返事（A）:

24. 定型文の逆翻訳は A が英文を訳し戻したもの（日本語の元を見ない R の逆翻訳ではない）。英語以外の言語の返事は、そのとき Claude が英語の定型文から訳し、その言語の文から逆翻訳を作る。
25. 本人の手順（§6.7）は `docs/support-replies/README.md` に書いた。日本語の SUPPORT には足していない（足すのは §6.4 の 4 つだけ）。英語の SUPPORT には契約の 1 文（返事は英語か日本語、機械翻訳の助け）だけ。python-holidays への報告（GitHub の issue）は公開の場に書くので、毎回本人の「はい」を得てから出す、と判断表に書いた。

### 本人の手順（英語などの問い合わせ、§6.7）

1. 英語などのメールが届く。2. 本人が Claude に「訳して」と頼む。3. Claude が日本語の訳と要点を出す。4. 本人が返事の中身を日本語で決める。5. Claude が相手の言語の返事と逆翻訳（日本語）を付けて、Gmail の **下書き** を作る。6. 本人が逆翻訳を読み、自分で送る（Claude は送らない）。定型文は `docs/support-replies/`。

### 確かめたこと

コードは変えていないので、swift build・KitChecks・typecheck は走らせていない（この役のファイルはコードに入らない）。commit の前なので、作業の木のファイルをリポジトリの外の使い捨てのスクリプト 2 つで確かめた（e7b4d2f の 3 文書は `git show` で取り出して比べた）。

- 日本語の 3 文書: e7b4d2f からの差は、足した 4 つ（TERMS 2 文・PRIVACY 1 文・SUPPORT の FAQ 2 つ）と 3 つの日付だけ（消えた・変わった行は日付の 3 行と第 9 条 1 項の 1 行）。価格・試用・解約の道・連絡先・氏名など 17 の文字列の数が編集の前と同じ（`grep -c '「設定」›「Apple Account」›「サブスクリプション」' docs/TERMS.md` は 1 のまま）。【 と「下書き」は無い。契約が決めた 3 つの文がそのまま入っている。
- 英語の 3 文書: リンク先のファイルと見出しの id（GitHub の作り方で作った id）が全部ある。リンクの外に `TODO`・`DRAFT`・`【`・`[` が無い（大文字小文字を区別せず）。冒頭の 1 文が契約の英文そのまま、日本語版へのリンク・“Last updated: November 1, 2026”・連絡先がある。見出しの数が日本語版と同じ（SUPPORT は英語だけの 2 節の分だけ多い）。MIT の文が LICENSE（venv の `holidays-0.107.dist-info/licenses/LICENSE`）と 1 バイトも違わない。Apple EULA の URL は TERMS.en にある（PRIVACY.en・SUPPORT.en には無い。日本語版と同じ）。
- ストア（L-9 の文のとおりに数えた）: en-US の名前 15・27・29 字、サブタイトル 27 字、キーワード 98 バイト（13 語。3 字以上、名前の語と重ならない、禁止語なし）、promo 164 字、説明 2,596 字、新機能の文 1,565 字、URL 2 行は日本語のページ、説明に日本語の規約の URL と EULA の URL。ja の新機能の文が契約 §6.3 と 1 字も違わない。訳の 1 文と端末の言語の 1 文が契約の英文そのまま（説明は訳の 1 文で終わる）。サブスクリプションの表示名 14・13 字・説明 43・32 字（数字と通貨の記号なし）。審査メモ 3,333 字・3,883 バイト。`source-ja` も字数・禁止語は通る。

### 次の役へ

- **X**: `docs/store/source-ja/` と `subscriptions/source-ja.json` から 8 言語（`docs/store/README.md` の「X への手引き」）。英語の画面の名前の表（同じ README）をアプリの英語の訳とそろえ、違えば英語の 3 文書・en-US の文・審査メモ・定型文も直す。en の訳についての 1 文と端末の言語の 1 文は契約の英文のまま。
- **R**: `docs/TERMS.en.md`・`PRIVACY.en.md`・`SUPPORT.en.md` だけを読んで `docs/i18n/back/legal-en.md`、`docs/store/en-US/*`・`subscriptions/en-US.json`・`review-note.txt` から `docs/i18n/back/store-en-US.md`。その後、L が元の日本語との食い違いを表にして REVIEW.md に足す（§6.4）。上の 8〜13・16〜19 は「意図した違い」として書く。
- **W**: 日本語の 3 ページは Markdown と文字単位で一致させる（差は 4 つと日付）。英語の 3 ページは `docs/*.en.md` から作る（リンクは `TERMS.en.md` → `terms.html`、`TERMS.md` → `../terms.html`、見出しの id は GitHub の作り方、例 `article-5-fees-subscription`）。`tests/app-pages.test.mjs` の (10) は、Apple EULA の URL を terms にだけ求めるのがよい（PRIVACY.en・SUPPORT.en には無い）。連絡先・“Last updated”・日本語版へのリンクは 3 つとも。SUPPORT.en の MIT の文は改行を保つ（`<pre>` など）。
- **S**: `Support/Products.storekit` の en_US の localizations は `docs/store/subscriptions/en-US.json` の値（グループ「Tegaki」、月額「Tegaki Monthly」、年額「Tegaki Yearly」と説明）。L-9 の読み方は上の 15。
- **リード**: 「設定」アプリの道（iOS 18 以降の「アプリ」›「言語」、iOS 17 の「優先する言語」、英語の Settings > Apps > Tegaki > Language）を TestFlight で確かめたら、`docs/store/ja/whatsnew.txt`・`en-US/whatsnew.txt`・`source-ja/whatsnew*.txt`・SUPPORT の FAQ（日本語・英語）・`docs/support-replies/language.md` を一緒に直す。公開の日（1.2 を出す日）の前の確認で、日付と第 11 条の見方（上の 5・6）を本人に伝える。Connect が名前の第 1 案を拒んだら、英語の 3 文書の題名（Tegaki Calendar）を見直す（「てがきカレンダー」の英語の言い方なので残してもよい）。
- **C**: この節の整え。

### 残る危険

- 英語の画面の名前（仮）が X の訳と食い違うと、英語のページ・ストアの文・審査メモ・定型文が実際の画面と合わない（X の用語集が固まった後に一度そろえる）。
- 「設定」アプリの道と、言語を足すときに出る問いの言い方は、この Mac で確かめられない（§2.1。リードが TestFlight で）。
- 規約の英語版は、英語を母語とする人も法律の専門家も見ていない（D11・M7B-4 で受け入れた危険。冒頭で「日本語版が優先する」と書いた）。第 11 条の扱いも法律の判断を経ていない。
- 名前の 3 案がどれも重複で拒まれることがありうる（そのときは確認表を作り直して本人に聞く）。キーワードの語は検索の実績を見て選んだものではない。

## C1（J-4 の道具: `ja-baseline.yml`・`compare_shots.swift`・`ja-baseline-ref.txt`。統合の順番の「C の前半」）

J-4 の比べる相手の commit: **e7b4d2f9c99dcfe4f7ba27ef9f81fe0466bf093d**（1.1 を main に merge した commit。親は 6f5ac42（1.0.1）と adc1fd4（m7a の最後）。今の origin/main もこの commit）。

### 入れたもの

- `tools/l10n/ja-baseline-ref.txt`（新規）: 上の sha の 1 行だけ。0-39 で比べる相手を読み替えるときは、この 1 行を直す（成果物の名前も `ja-baseline-<先頭 7 字>` に変わる）。
- `.github/workflows/ja-baseline.yml`（新規、662 行）: ブランチ `ja-baseline` への push と workflow_dispatch で走る（workflow_dispatch は main に入った後の分）。手順: push された commit から `ja-baseline-ref.txt` を読む（中身が 40 字の小文字の 16 進の 1 行でなければ失敗）→ その commit を `baseline/` に取り出し、HEAD が同じかを確かめる → Xcode を選ぶ → XcodeGen → 組み立て → build.yml と同じ写真の段（13 インチの 4 ページ・拡大 3・閲覧専用・1.1 の 5 枚・シート 9、iPhone・6.9 インチ・mini・11 インチ、「Store listing set」）→ 要約（run の Summary に commit・成果物の名前・枚数・env.txt）→ 成果物 `ja-baseline-e7b4d2f`（30 日）。テストは走らせない。ジョブの上限 75 分。
  - 写真の段は、e7b4d2f の build.yml から行の範囲で切り出す小さな script で写した（手で写していない）。build.yml と違うのは 3 つだけ: (1) 7 つの `simctl launch`（契約の :352・:364・:371・:384・:404・:529・:538）の最後に `$JA_ARGS`。`JA_ARGS` はジョブの `env` に `"-AppleLanguages (ja) -AppleLocale ja_JP"` の 1 行で置き、引用符なしで展開して 4 語にする（この Mac の /bin/bash 3.2 で 4 語になることを確かめた）。(2) 13 インチの写真の段の最初と他機種の段で env.txt を書く（下の「ずれ」の 1）。(3) `run` の段の作業フォルダが `baseline/`（ジョブの `defaults`）。段の名前・`if`・`id`・`continue-on-error` と、ほかの 10 段の `run` は 1 字も違わない（Ruby の YAML で読んで段ごとに比べた）。シートは 1.1 の 9 つ（`holidays` は 1.1 の app が知らないので撮らない）。
  - 成果物の中身（1.1 の CI の `screenshots` と同じ名前・同じ数）: 写真 53 枚（13 インチ 22・iPhone 17・6.9 インチ 5・mini 4・11 インチ 5）、`store/` の JPEG 20 枚、記録 5 つ（`app-log.txt` と `<機種>-log.txt`）、`env.txt`。`fixtures/` と `ui-tests/` は無い（テストを走らせないため）。
- `tools/l10n/compare_shots.swift`（新規、563 行）: `swift tools/l10n/compare_shots.swift <基準のフォルダ> <新しいフォルダ> <出力のフォルダ>`。2 つのフォルダを下のフォルダまでたどり、同じ相対パスの `.png`・`.jpg`・`.jpeg` を 1 画素ずつ比べる（ほかのファイルと隠しファイルは見ない）。2 枚とも基準の写真の色の空間（シミュレータの PNG は 8 bit の sRGB なので変換は起きない）の 8 bit RGBA に拡大縮小なしで描き、R・G・B・A のどれかが違えば「違う画素」。出力のフォルダ（新しいか空で、比べる 2 つのフォルダの外。無ければ、親があるときだけ最後の 1 段を作る）に書くもの:
  - `report.tsv`: 写真ごとに、結果（同じ・違う・大きさが違う・基準だけ・新だけ・読めない）・大きさ・違う画素・強い差（どれかの色の差が 32 を超える画素）・最大の差（255 まで）・違いの範囲（違いのある行を、16 行より近ければまとめた帯ごとに「y 上端-下端 x 左端-右端 (画素数)」。y は上から）・書いた画像・注記（色の空間や bit の深さが違ったとき）。
  - `<写真>.diff.png`: 新の写真を薄くし、弱い差を青・強い差を赤で塗り、帯を紫の枠で囲んだ印の画像。
  - `<写真>.crop-<n>.png`: 違いの大きい帯（3 つまで）の原寸の切り抜きを横に 3 つ並べたもの（左 = 基準・中 = 新・右 = 印。1 つ 1600 × 1200 px まで）。縮めて見ると 1 画素の差が見えなくなるので、中身はこれで見る。
  - 画面には、結果ごとの数、違う写真ごとの画素の数と帯、片方だけの写真（1 つのフォルダに 6 枚以上あれば 1 行にまとめる）。終了の状態は 0 = 全部同じ、1 = 違う・片方だけ・読めない写真がある、2 = 引数やファイルの誤り。.html は書かない（書くと本人の画面に開くため）。

### 走らせ方（リード）

この Mac の作業は書類フォルダの外（scratchpad）で行う。下の `<j4>` は scratchpad の中の新しいフォルダ。

1. **push**: `.github/workflows/ja-baseline.yml` と `tools/l10n/ja-baseline-ref.txt` の入った commit を push する（写真は ref の commit から作るので、push する commit のほかの中身は写真に関係しない）。例: `git push origin m7b:ja-baseline`。2 回目は、`ja-baseline` より先に進んだ commit ならそのまま、進んでいなければ `--force`。同じ commit のまま撮り直すなら `gh run rerun <run の番号>`（成果物は `overwrite: true` で上書きされる）。
   - この push で build.yml（`on: push` は全部の枝）も `ja-baseline` の枝でもう 1 本走る。要らなければ `gh run cancel <run の番号>`（下の「次の役へ」の 3）。
2. **待つ**: `gh run list --workflow ja-baseline.yml --branch ja-baseline --limit 3` → `gh run watch <run の番号>`。見込み 40 分ほど（e7b4d2f の CI（run 41264726309、57.6 分）を含む 1.1 の 9 回の CI で、写真の段は組み立てを含めて 36〜45 分）。
3. **取り出す**: `gh run download <ja-baseline の run> -n ja-baseline-e7b4d2f -D <j4>/base` と `gh run download <1.2 の最後の CI の run> -n screenshots -D <j4>/new`（成果物の中身がそのフォルダの直下に出る。`screenshots` は 7 日、`ja-baseline-…` は 30 日で消える）。
4. **環境を照らす**: `diff <j4>/base/env.txt <j4>/new/env.txt`。違えば（Xcode・runtime・機種のどれか）ja-baseline を撮り直してから比べる（§1.3）。env.txt は `xcodebuild -version` の 2 行と、機種ごとの「`<id>: <機種名> | <runtime の名前> (<runtime の build>)`」の 5 行（ipad13・iphone・iphone69・ipadmini・ipad11 の順）。runner の image の版は入れていない（同じ日でも 2 つの image が混ざって使われる（11-01 の実測: 20261021.0445.8 と 20261026.0455.2）ので、入れると env.txt が無駄に違う）。見たいときは run の記録の「Set up job › Runner Image」。
5. **比べる**: `swift tools/l10n/compare_shots.swift <j4>/base <j4>/new <j4>/out`（73 枚どうしで約 9 秒・メモリ約 0.9 GB。出力のフォルダは毎回新しく）。
6. **読み方**（1.0.1 の CI の 3 つの run（41164839330・41172398011・41176284773、どれも 10-31）を互いに比べた実測から）:
   - コードが同じでも、run ごとに **弱い差だけ**（強い差 0、最大 11〜20/255）の写真が 14〜22 枚出る（シートのガラスとぼかし、年の拡大、iPhone の横向きなど）。後戻りではない（M7A の比べ方の「最大 9/255」と同じ種類）。
   - **強い差** が出たのは、13 インチの週か日の写真の上の 240 行（と、それから作る `store/ipad13/02-week`・`03-day`）だけで、中身はシステムの通知「Ready for Apple Intelligence」（切り抜きの左か中に見える）。3 回のうち 2 回で入った（「Boot the simulator」の終わりから約 85〜105 秒。13 インチは写真の直前に boot している、下の「ずれ」の 3）。写真の撮り方の揺れで、アプリの差ではない。入っていたら、入った方を撮り直して比べ直す（「次の役へ」の 1 で減らせる見込み）。
   - iPad の状態の帯の日付（13 インチで y 21〜42・x 176〜321 のあたり）は、2 つの run の **UTC の日** が違うと全部の iPad の写真で強い差になる（1.0 と 1.0.1 の 2 つの run の実測）。日本時間の 9:00 から翌日の 8:59 までが同じ UTC の日。
   - これら以外の **強い差** は本物の違いとして、切り抜きで中身を見る。J-4 で違ってよいのは `ipad13-portrait-sheet-settings.png`・`ipad13-portrait-sheet-info.png`・`store/ipad13/06-settings.jpg` と、「新だけ」の `ipad13-portrait-sheet-holidays.png`。`ipad13-portrait-sheet-sync.png` は変わらない見込みで、違ったら祝日の節の分だけかを見る（§1.3）。
   - 「新だけ」には 1.2 の CI の `ui-tests/attachments/`（UI テストが残した写真）が 1 行にまとめて出る。`fixtures/` は JSON なので比べない。
7. **1 回目の run の後の確かめ**（写真の手順の誤りを早く見つける）: e7b4d2f の CI（run 41264726309、成果物 `screenshots`、2026-11-08 に消える）の写真を基準、ja-baseline の写真を新にして比べる。53 枚と `store/` の 20 枚が両方にそろい（「基準だけ」は `ui-tests/attachments/` だけ、「新だけ」は無し）、違いは漢字・かなの書体（中国語用 → 日本語用）と日時の書式だけのはず。
8. M7B.md に書くもの（§1.3、§8 の 3）: 2 つの run の番号、2 つの env.txt、compare_shots の数の表と、違った写真の名前と画素の数（強い差と弱い差）、「1.1 の CI の写真は英語の環境で撮っていたので、漢字が中国語用の書体だった」こと。

### 契約からのずれ・契約が黙っている所の決め方

1. **env.txt の形**（契約は「`xcodebuild -version` と使ったシミュレータの runtime」とだけ書いている）: 上の「走らせ方」の 4 の 7 行。UDID と時刻は入れない（環境が同じなら 2 つの run の `diff` が空になるように）。build.yml にも **同じ行を同じ場所に** 入れる（13 インチの写真の段の `mkdir -p shots` の後に `sim_env` の関数と 3 行、他機種の段では `mkdir -p shots` の後に同じ関数、`echo "$ID: $NAME ($UDID)"` の次に 1 行）。
2. **`JA_ARGS` の置き方**（契約は「変数 `JA_ARGS` で」）: ジョブの `env` の 1 行と、各 `simctl launch` の最後の `$JA_ARGS`（引用符なし）。build.yml も同じ形にする。
3. **テストを走らせない**（契約の手順のとおり）ので、13 インチの状態が build.yml と違わないかを CI の記録で確かめた: e7b4d2f の CI では、13 インチの写真は単体テストの機（iOS 26.5。xcodebuild はいちばん新しい runtime を選ぶ）とは別の機（iOS 26.4。何も起動していないときの simctl の JSON の最初の 1 台）で、写真の直前に boot していた（「Boot the simulator」が毎回 111〜193 秒）。ja-baseline も何も起動していない所で同じ選び方（段は写したまま）をするので、同じ runtime の同じ機種を選び、同じく boot の直後に撮る。1.1 の 9 回の CI（2 つの runner image）で写真の機は全部 iOS 26.4。違えば env.txt に出る。
4. **成果物の `overwrite: true`**: `gh run rerun` で撮り直したとき、同じ名前の成果物で上げ損ねないため。
5. **ジョブの上限 75 分**（契約に数が無い）: 1.1 の 9 回の CI で写真の段は 36〜45 分（組み立て 42〜71 秒、13 インチの boot 111〜193 秒、13 インチの写真 5〜7 分、他機種 26〜33 分）。上限で切られると成果物を上げる段まで行かないので余裕を取った。
6. `permissions: contents: read`、2 つの checkout は `persist-credentials: false`（書き込みも push もしない仕事なので）。
7. **compare_shots の細部**（契約は「違う画素の数と違いの印の画像」）: 強い差（32 を超える）と弱い差を分けて数え、帯と原寸の切り抜きを足した（1.1 の比べ方では、ガラスの揺れが最大 9/255、本物の字のずれが 176/255 で、画素の数だけでは見分けにくい）。出力のフォルダは新しいか空で入力の外（前の結果と混ざらず、入力を汚さない）。無いときは親があるときだけ最後の 1 段を作る（下の「事故」のため）。

### 確かめたこと（push・CI は無し。指示のとおり）

- compare_shots: `swiftc -typecheck -warnings-as-errors`（Swift 5 と 6 の mode）で警告 0。作り物の写真で 46 項目（終了の状態 0・1・2、出力のフォルダの決まり（空でない・入力の中・`/tmp` と `/private/tmp` の言い換え・親が無い）、差 32 は弱く 33 は強い、1 画素の 1 段の差、JPEG、sRGB と Display P3、16 bit、半透明、隠しファイルと文字のファイルを見ない、印の色と枠、切り抜きの 3 つの絵が基準・新・印の同じ場所と 1 画素も違わない（上下が逆になっていない））が全部合格。本物の写真（1.0.1 の CI の 3 つの run、73 枚ずつ）で上の「読み方」の結果。試験の材料と script は `/private/tmp/claude-501/-Users-ikedamasataka-Documents-Codex/1d1a8054-037e-4e4c-982f-6008fda67420/scratchpad/m7b-impl/C1/tests/`（作業のファイル。commit しない）。
- ja-baseline.yml: Ruby の YAML で読めて 19 段、`run` の 16 本が `bash -n` で通る。build.yml（e7b4d2f）から写した 13 段を段ごとに比べて、10 段の `run` が同じ・3 段の差が上の (1)(2) だけ（切り出しと比べの script は `/private/tmp/claude-501/-Users-ikedamasataka-Documents-Codex/1d1a8054-037e-4e4c-982f-6008fda67420/scratchpad/m7b-impl/C1/assemble/`）。参照の読み取りを 8 通り（正しい・2 行・大文字・短い・前後の空白・空・無い・CRLF）、`sim_env` を作り物の `simctl list -j` で、要約の段を作り物の `shots/` で動かした。この Mac に actionlint と shellcheck は無い。本物の runner ではまだ走らせていない（1 回目の run が最初の確かめ）。
- **事故（報告）**: compare_shots の試験の 1 つで、私の試験のパスの書き誤り（`\/tmp/…`）が相対パスになり、書類フォルダの作業ツリー（`tegaki-calendar-ios`）に `\` という名前のフォルダ（中は試験の `report.tsv` 1 つ）を作ってしまった（11-01 19:01）。すぐに消し、`git status` が元のとおり（未追跡は前からの複製 6 つだけ）であることを確かめた。iCloud に一時上がった可能性はある。これを受けて compare_shots は、出力のフォルダの親が無ければ何も作らずに止まるようにし、試験の script は書類フォルダの下では走らないようにした。

### 次の役へ（C の後半・リード）

1. **13 インチの通知の待ち（勧め。入れるなら build.yml と ja-baseline.yml の両方に同時に、同じ行で）**: 上の「読み方」のとおり、13 インチの週か日の写真に「Ready for Apple Intelligence」が 3 回に 2 回入る。J-4 は 2 つの run を比べるので、どちらかに入る見込みが高い。13 インチの写真の段の最初（env.txt の行の後）に、他機種と同じ形の待ちを入れれば避けられる見込み:
   ```
   xcrun simctl launch "$UDID" "$BUNDLE" --screenshot-mode --screenshot-month 2026-10 --screenshot-page month $JA_ARGS || true
   sleep 120
   xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
   ```
   他機種の 40 秒では足りない（通知は boot の段の終わりから約 85〜105 秒で、13 インチの最初の写真は 3 回の実測で boot の段の終わりから 71・90・166 秒）。入れると 13 インチの段が 2 分延び、「Collect the app log」の `--last 10m` に 13 インチの写真の全部が入るかが際どくなる（今 5〜7 分 ＋ 2 分 ＋ 1.2 の祝日のシート）ので、両方の `10m` を `12m` にする。入れるかはリードが決める。入れないなら、上の「読み方」のとおり、通知の入った方を撮り直す。
2. **build.yml の 1.2 の写真の段**（§7.5）: `JA_ARGS` をジョブの `env` に（ja-baseline.yml と同じ 1 行）、7 つの launch に `$JA_ARGS`、env.txt の行（ja-baseline.yml の 13 インチと他機種の段から写す）、シートに `holidays`（ja-baseline.yml は 9 のまま）、ja-baseline.yml を指すコメント（ja-baseline.yml の頭のコメントは「1.2's build.yml points back here」と書いてある）。写した後、段ごとに `run` を比べて、違いが `holidays` とその段の名前（9 → 10 sheets）・コメントだけであることを確かめる（私の比べ方: `/usr/bin/ruby /private/tmp/claude-501/-Users-ikedamasataka-Documents-Codex/1d1a8054-037e-4e4c-982f-6008fda67420/scratchpad/m7b-impl/C1/assemble/diff_steps.rb .github/workflows/ja-baseline.yml .github/workflows/build.yml`。build.yml のジョブの名前 `build-and-test` を読む）。
3. **build.yml の `on: push`** に `branches-ignore: [ja-baseline, store-shots]` を足すかどうか（足さないと、その 2 つの枝への push で build.yml がもう 1 本走る。害は無いが runner の時間を使い、m7b と同じ CI の結果が 2 つ並ぶ）。
4. 日付の揺れを無くす案（未確認）: `xcrun simctl status_bar … override --time` は ISO 8601 の日時を受けると日付も固定する、と simctl の説明にあったはず（覚えの範囲。この Mac には simctl が無く確かめられない）。runner で `xcrun simctl help status_bar` を見て、使えるなら両方の workflow に同じ値で入れる。入れれば「同じ UTC の日」の縛りが無くなる。

## K1（Kit の土台: `Package.swift`・`UILanguage`・`kit-K.json`・`Text11`・`DateText`・`LayoutWords`・`DATA_1_1.sha256`。統合の順番の「K の前半」）

### 入れたもの

- `TegakiKit/Package.swift`（§2.6 の 4 つの依存だけ）: `Access` → `["DayKit"]`、`InkModel` → `["Layout", "Holidays"]`、`AccessTests` → `["Access", "DayKit"]`、`InkModelTests` → `["InkModel", "Holidays"]`。:8-9 の注記を「Foundation and DayKit only: UILanguage and KitStrings, since 1.2」に。ほかの行は変えていない（DayKit の行の説明も、契約の「変えるのはこれだけ」のとおり触っていない）。
- `TegakiKit/Sources/DayKit/UILanguage.swift`（§0 の形のまま。case の名前・rawValue・`PluralCategory` の "one"・"other"）: `resolve`（大文字小文字と "_" を区別しない。中国語は書体の subtag（Hans・Hant）が先、無ければ地域（TW・HK・MO → zhHant、ほか → zhHans）、"yue" は Hans と書いていなければ zhHant。"-u-…" などの拡張の後ろは読まない。ほか・nil・空は en）、`current`、`locale(region:)`、`pluralCategory`（CLDR と同じく符号は見ない）、`isCJK`。
- `TegakiKit/Sources/DayKit/DateText.swift`（§0・§3 の形のまま）と `YearMonth.title(language:)`。ja はすべて 1.1 の手作りの式で、字は `kit.date.ja.*` と `kit.weekday.letter.*` から（Kit のソースに日本語の文字列は無い。L-1 で 0 件）。ja 以外は §3.1 の 3 の雛形。`numericDate`・`numericDateTime` は 0-33 のとおり ja も ICU（`Locale.current` の言語が ja ならそれ、違えば ja_<region>）。暦は全部グレゴリオ暦。書式の器（DateFormatter・DateIntervalFormatter・NumberFormatter）は型と locale ごとに 1 つ作って使い回す（中で NSLock）。
- `TegakiKit/Sources/Layout/LayoutWords.swift`（§0 の形 ＋ 下のずれの 3）。`japanese` は `of(.ja)`。
- `tools/l10n/source/kit-K.json`（21 キー。`build.py` で生成済み。S1 の `build.py --check` で一致）:
  - `fixed`（契約が 10 言語の値を決めたもの。X は訳さない）: `kit.weekday.letter.0`〜`.6`（§3.3 の表）、`kit.layout.tailPrefix`・`kit.layout.timeRange`（§3.1 の 4。ja「〜」「%1$@〜%2$@」、ko「~」「%1$@~%2$@」、ほか「–」（U+2013）「%1$@–%2$@」）。
  - `jaOnly`（9）: `kit.date.ja.dayTitle`「%1$@年%2$@月%3$@日(%4$@)」・`shortDay`「%1$@月%2$@日(%3$@)」・`monthTitle`「%1$@年%2$@月」・`yearTitle`「%@年」・`weekTitle`「%1$@年%2$@月%3$@日〜%4$@月%5$@日」・`weekTitleCrossYear`「%1$@年%2$@月%3$@日〜%4$@年%5$@月%6$@日」・`weekTitleCompact`「%1$@/%2$@〜%3$@/%4$@」・`weekdayFull`「%@曜日」・`monthName`「%@月」。
  - X が訳すもの（3）: `kit.layout.more.one`・`.other`「+%@件」（`maxEm: 7`）、`kit.app.name`「てがきカレンダー」（ほかの言語は既定で「Tegaki」と comment に書いた）。
  - 「〜」は 1.1 と同じ U+301C（WAVE DASH）。打ち間違いが入らないよう、JSON は scratchpad の生成の script で書いた。
- `TegakiKit/Sources/KitChecks/Text11.swift`（新規。以後は誰も変えない）: e7b4d2f の `PageNavigation.title`・`compactTitle`・`weekdayLetters`・`mondayOnOrBefore`、`YearMonth.title`、`StrokeBudget.pageLabel`・`countText`、`PlanText` の全部、`AppExport.jsonFileName`・`pdfFileName`・`kindLabel`・`safeFileName`、`MonthLayoutEngine.timeText(for:…)`・`formatTime`、`TimedEventEngine.timeText`・`timeRangeText` を、型の名前に `11` を付けて写した（`PageNavigation11` など。先頭に commit と行の範囲）。本体は 1.1 と 1 字も違わない（写した同士の呼び出しの名前だけ変えた）ことを、`git show e7b4d2f:…` の行と並べて確かめた。
- `TegakiKit/Sources/KitChecks/main.swift`: 「compat with 1.0 (K-7)」の後、Summary の前に 3 つの節（§7.1 の順）。その後ろに、H の「holidays (1.2)」と K の後半の「holiday geometry (1.2)」が入る場所の注記だけ。
  - `languages (1.2)`（113 件）: `resolve` の 30 通り（§0 の名前 ＋ "pt_PT"・"ZH-hant-hk"・"JA_jp"・"th"・"ar"・nil・空）、rawValue の往復、`pluralCategory` の 10 言語 × 0・1・2・5・21、`locale(region:)`（言語・書体・地域・variant で比べる）、`isCJK`。
  - `kit strings (1.2)`（キーの数で動く。14 キーで 230 件）: キーの並び、K のキーと ja だけのキー、各キーが「ja だけ（X の前）か 10 言語全部」、埋め込みが全言語で ja と同じ、`.one`・`.other` の対と ja・ko・zh の同じ文、受け皿（`text == value ?? value(en) ?? key`）、`format` の順と残し方、`plural`、`LayoutWords`（ja の字・10 言語の区切り・`more` が複数形の規則・`fill` が `KitStrings.format` と同じ規則）。
  - `date text (1.2)`（435 件）: **J-3**（2000〜2099 年の 36,525 日 × 4 種類のページ。関数ごと・10 年ごとに 1 件）、PlanText の 17 の購読の状態、線の数、全部の分の時刻、§3.1 の見本、グレゴリオ暦の固定、§3.3 の表、曜日と月の名前、年に区切りが無い、`number`、`numericDate`・`numericDateTime`、64 の thread で同じ字。
- `tools/compat10/DATA_1_1.sha256`（新規。18 行）: e7b4d2f の git の中身から作った sha256（`Ink/*.swift` 8・`Sync/SyncEngine.swift`・`Sync/InkPageRecord.swift`・`Persistence/InkPageStore.swift`・InkModel の 7）。パスはリポジトリの直下から、並びは辞書順、注記の行は無し。CI の「Data code frozen since 1.1」は直下で `shasum -a 256 -c tools/compat10/DATA_1_1.sha256` と書けばよい（C）。

### 契約からのずれ・契約が黙っている所の決め方

1. **`UILanguage.locale(region:)` の pt-BR**: 契約の「<rawValue>_<地域>」をそのまま作ると "pt-BR_US" になり、Foundation は「地域 BR・variant US」と読む（この Mac の実測。"pt-BR_PT" も地域 BR）。pt-BR だけ「pt_<地域>」（pt_BR・pt_PT・pt_US）、地域なしは "pt-BR" にした。ほかの 9 言語は契約どおり（.en, "JP" → en_JP、.zhHant, "HK" → zh-Hant_HK。後者の `identifier` は Foundation が "zh_HK" に縮めるが、書体は Hant のまま）。
2. **書式の locale に `calendar=gregorian` を入れる**（DateText の中だけ。`UILanguage.locale(region:)` の値は契約どおり）: 暦をグレゴリオ暦にしても、locale の既定の暦が別だと雛形に紀元が付く（実測: en_TH は仏暦が既定で「Sun, 4 October 2026 AD」、ja_JP@calendar=japanese で「西暦2026年…」）。`Locale.Components` で暦をグレゴリオ暦にした locale から雛形を作ると付かない。`numericDate`・`numericDateTime` は契約どおり `Date.FormatStyle` に `calendar:` を渡す形（紀元は付かないことを確かめた）。
3. **`LayoutWords` に public の `range(_:_:)` と `tail(_:)` を足した**（§0 は `more(_:)` だけ）: `timeRange` に 2 つの字を入れる・`tailPrefix` を前に付ける、の 2 つ。K の後半の `TimedEventEngine.timeRangeText(…words:)`・`MonthLayoutEngine.timeText(…words:)` と、S の `EventDateText`（§3.2 の「`LayoutWords.timeRange`」）で使う見込み。埋め込みの規則は `KitStrings.format` と同じで、`LayoutWords` の中に同じ規則の `fill`（internal）を置いた。S1 の新しい `build.py` は `KitStrings.fill` を public にしているので、それが固まったら K の後半でそちらに寄せてよい（KitChecks が 11 の型で 2 つの結果が同じことを見ている）。
4. **KitChecks の「全キー × 10 言語」**（§7.1）: X の訳はキーの凍結の後なので、今は ja だけのキーがある。「ja だけ（まだ訳していない）か 10 言語全部」を確かめ（一部の言語だけのキーは失敗）、ja だけのキーの一覧を 1 行出す（今は 5: `kit.app.name`・`kit.holiday.dayOff`・`kit.holiday.estimatedSuffix`・`kit.layout.more.one`・`.other`）。訳し漏れの本当の関門は lint の L-2。X の後は全部が 10 言語になり、件数は変わらない。
5. **ja 以外の見本の確かめ方**: 字まで比べるのは en_US の全部（§3.1 の例）と es・fr の §3.1 の例、de_DE・fr_CH・pt_BR・zh_TW・ko_KR は月の題名（「Oktober 2026」「octobre 2026」「outubro de 2026」「2026年10月」「2026년 10월」）。この 5 つの日・週・短い日付・読み上げは、年・日・月の名前・曜日の名前が入っているかで見る（句読点や括弧は OS の ICU の版で変わりうるので、CI の macos-26 とこの Mac（27.2）で割れないように）。ICU の空白（U+00A0・U+2009・U+202F）は空白 1 つとして比べる。
6. **ja の `weekdays(.full)` と `monthName`**: §3.3 の「`.full` は `standaloneWeekdaySymbols`（ja「日曜日」）」は、D6（ja は ICU に任せない）に合わせ、ja は記号 ＋「曜日」（`kit.date.ja.weekdayFull`）、月は「n月」（`kit.date.ja.monthName`）を手で作る。字は ICU の ja と同じ。
7. **ja 以外の週の題名の compact**: `DateIntervalFormatter` の `Md` は、年をまたぐ週に ICU が年を足す（en_US「12/28/2026 – 1/3/2027」）。契約どおりの雛形なのでそのまま（ja は 1.1 のまま年を書かない「12/28〜1/3」）。iPhone の縦の見出しで年に 1 週だけ長くなる（P が写真で見る）。
8. **J-3 の今の形**: 今の Kit の関数（既定の引数。中身はまだ 1.1 のコード）と `Text11` を全範囲で比べ、加えて新しい部品（`DateText` の ja・`LayoutWords.japanese`）を `Text11` と直接比べている。K の後半が関数に `language:` を足したら、同じ場所に `language: .ja` の呼び出しを足す（契約の「既定の引数と `language: .ja` の両方」）。
9. **`was`・`composedOf` の書き方**: S1 の `ja-baseline.tsv` と同じく、パスは `Sources/TegakiCalendar/`・`TegakiKit/Sources/` を省いた形（`Layout/PageNavigation.swift:110`）。S1 の L-3 で、K のキーが指す 47 行は全部「キーにある」と数えられた（L-4 も ok）。H の `kit-H.json` の `where` は前を付けた形（S1 の L-3 は `was`・`composedOf` の前の有無を同じに読む。`where` は読まない）。
10. **K が引き受けたアプリの行**（§3.2 で Kit の関数に置き換わると契約が書いた行。同じ行を自分のキーで引き受けないこと）: `Paper/YearPaper.swift:12`・`Views/StickyHeaderView.swift:34, 35`・`Export/PDFPageRenderer.swift:36`（曜日の記号 → `kit.weekday.letter.*` の `was`）、`Views/StickyHeaderView.swift:177`（「曜日」→ `kit.date.ja.weekdayFull`）、`Views/StickyHeaderView.swift:174, 208`・`Export/PDFPageRenderer.swift:252`・`Views/CalendarRootScreen.swift:1172`（「\(m)月」→ `kit.date.ja.monthName`）、`Views/EventDateText.swift:12, 21`（"yyyy年M月d日(E)"・"M月d日(E)" → `kit.date.ja.dayTitle`・`shortDay`）。P・U・S がこれらを `DateText`・`PaperWords` で置き換えない形にしたら、K（後半）に知らせて `kit-K.json` から外す。
11. **引き受けていない近くの行**: `Paper/MonthPaper.swift:189`（「+\(chip.moreCount)件」）と `Views/EventDateText.swift:46, 48, 54, 56`（「〜」「終日」をつなぐ文）。P・S が `LayoutWords`（`kit.layout.more.*`・`timeRange`）で作るなら、その行を `kit-K.json` の `composedOf` に足すよう K に頼むか、自分の C 型のキーで引き受ける。`kit.app.name` の `was` は無い（1.1 の `InkModel/AppExport.swift:138, 144` は K の後半の AppExport のキーの C 型で引き受ける）。`kit.app.name` はまだコードで使っていない（K の後半が `pdfFileName` で使う。L-8 はそれまで「使われていないキー」と言いうる）。
12. **ほかに気づいたこと**: `Access/Plan.swift:2` の注記「depends on nothing else, not even DayKit」は 1.2 で古くなる（契約は `Package.swift` の注記だけを挙げている）。Access を変える K の後半が直すとよい。

### 確かめたこと

この Mac（Swift 6.4.2、Command Line Tools）。他の役が同時に書いているので、主な確かめは `git archive HEAD` で取り出した木（`m7b-impl/K1/tree`）に K1 のファイルだけを重ね、`build.py` で生成した写しで行った。

- `swift build --package-path TegakiKit`: 成功。新しい警告 0（main.swift:2256・2277・2308 の「no calls to throwing functions occur within 'try'」の 3 つは e7b4d2f からあり、この版の Swift だけで出る）。DayKit は `-warnings-as-errors` で Swift 5・6 の両方の mode で警告 0。
- `swift run --package-path TegakiKit KitChecks`: 「all 25220 checks passed」（1.1 の 24,446 ＋ 774）。時間は 1.1 より約 3.5 秒増えた（debug、約 32 秒）。
- `tools/typecheck/typecheck.sh`（リポジトリの外の空のフォルダ）: all OK・警告 0（アプリ 59 ファイル、TegakiCalendarTests 26、UI テスト 2、Kit のテスト 5 つ）。
- 作業の木の全部（H の途中の Holidays・S1 の `L10n.swift` と生成物を含む。19:15 時点）を写した木でも、build 成功・KitChecks「all 25224 checks passed」（H の 2 キーで 4 件増える）・typecheck all OK・警告 0。
- `python3 -I tools/l10n/build.py . --check`（S1 の版）: 一致。S1 の `lint.py --only L-3,L-4`: K のキーの 47 行に指摘なし、L-4 ok（ほかの行の L-3 の失敗は、まだキーの無い役の分）。
- `Text11.swift` の本体が e7b4d2f の行と同じ（script で並べて比べた）。`DATA_1_1.sha256` は作業の木と写しの両方で 18 件 OK、1 字足すと FAILED になる。
- `DateText` の出力を 18 の言語と地域で目で見た（ja は 1.1 と同じ。en_TH・和暦の locale でも紀元なしの 2026）。

### 次の役へ

- **K の後半**: §5.4 の 12 か所・tone（`workday:` は既定値なし）・`PageNavigation.title(_:focus:holidays:language:)`・`compactTitle(_:focus:language:)` は、ja の日・週・月・年を `DateText.dayTitle`・`weekTitle(monday: PageNavigation.mondayOnOrBefore(focus), …)`・`monthTitle`・`yearTitle`、compact を `shortDay`・`weekTitle(…, compact: true)` で作れば J-3 がそのまま通る（祝日名は `" " + 名前`）。`MonthLayoutEngine` のチップは `words.more(n)`・`words.tail(time)`、`TimedEventEngine.timeRangeText` は `words.range(a, b)`、時刻は `DateText.time(hour:minute:)`。`StrokeBudget.countText` の ja は `DateText.number(n, .ja)` ＋ `kit.budget.count.other`「%@ 本」。J-3 の節（`date text (1.2)`）の比べる所に `language: .ja` の呼び出しを足す。`kit-K.json` の残りのキーは scratchpad の `m7b-impl/K1/gen/make_kit_k.py` に足して作り直すか、JSON を直接直す（どちらでもよい。直したら `build.py`）。KitChecks の実数 N（キーの数で動く）を M7B.md に。`DateTextTests`・`KitStringsTests`・`LayoutWordsTests`（§7.2）はまだ無い。
- **H**: `HolidayChecks.swift` の関数を main.swift の「1.2, still to come here」の注記の所（`date text (1.2)` の後）から呼ぶ（main.swift は K の持ち物なので、呼び出しの 1 行は K の後半が足すか、H が足して知らせる）。
- **P・U・S**: 曜日・月の名前・日付は `DateText`（ja は 1.1 の字）。上の 10・11 の行の引き受けに注意。`DateText.weekdays` は日曜始まり（`DayKey.weekday` の順）で、月曜始まりの列は `DateText.mondayFirst.map { weekdays[$0] }`。
- **X**: `kit.layout.more.one`・`.other`（F-5 の 7 em）と `kit.app.name`（既定「Tegaki」）だけ。曜日の記号・区切り・`kit.date.ja.*` は訳さない（`fixed`・`jaOnly`）。
- **C**: build.yml の「Data code frozen since 1.1」は `shasum -a 256 -c tools/compat10/DATA_1_1.sha256`（直下で）。閾値は K の後半の N から。

### 残る危険

- §3.1 の en_US の見本は ICU の字そのものを比べている（空白の種類だけ寄せた）。CI の macos-26 の ICU で月の略し方などが変われば KitChecks が落ちる。落ちたら CI の字を見て、ICU の違いなら見本を構造の確かめに替える。
- `numericDateTime` の ja の「2026/10/25 12:00」は、Mac の言語が日本語なら Mac の「24 時間表示」の設定がそのまま効く（契約どおり）。この Mac を 12 時間表示にすると、この 1 件がこの Mac でだけ落ちる。

## S1（S の前半: `baseline.py`・`ja-baseline.tsv`・`ja-exceptions.txt`、`build.py` のアプリ用の出力と `--check`、`lint.py` の L-1・L-3・L-4・L-10、`L10n.swift`）

### 入れたもの

- `tools/l10n/baseline.py`（新規・実行権つき）: `python3 -I tools/l10n/baseline.py [<リポジトリ>] [--commit <rev>] [--tree <フォルダ>] [--check]`。既定の commit は e7b4d2f9c99dcfe4f7ba27ef9f81fe0466bf093d（0-39 で動いたら `--commit`）。`git archive` で取り出した `Sources/TegakiCalendar` と `TegakiKit/Sources`（KitChecks を除く）の文字列のうち、日本語を含むものを全部 `ja-baseline.tsv` に書く。文字列は正規表現でなく小さな Swift の字句解析で拾う（埋め込み `\(…)` の中の文字列も 1 つと数える、文字列の中の `//` はコメントにしない、入れ子の `/* */`、生の文字列 `#"…"#`、複数行 `"""`）。lint の L-1 も同じ解析を使う。「日本語」の字は、かな・漢字・ハングル・全角の記号（U+3000–303F、U+FF00–FFEF）とその近くの CJK の区画（`JA_RANGES` の固定の表）。
- `tools/l10n/ja-baseline.tsv`（生成物）: e7b4d2f の **515 行・42 ファイル**。頭に `# commit: <40 字>`・`# strings: 515 in 42 files`。1 行は「ファイル（`Sources/TegakiCalendar/`・`TegakiKit/Sources/` を省いた形。`Views/SettingsScreen.swift`・`Access/PlanText.swift`）TAB 行（開きの引用符の行）TAB 字（Swift のソースの書き方のまま、引用符の内側）」。1 つの行の字はソースの左から順。
- `tools/l10n/ja-exceptions.txt`（新規）: 契約（§2.5・§2.6）が列挙したものだけの 31 行。凍結した Ink の 6 件（`Ink/InkTrace.swift` の記録の 1 行目・「記録」「閉じる」「コピーしました」「コピー」、`Ink/InkCanvasView.swift` の「手書きの紙」）、§5.8 の判定の語 5 つ（「祝日」は 1.1 にある。「节假日」「節假日」「假日」「공휴일」は U が足す語で、足すまでは L-1 の警告）、Kit の 1.1 の公開 API（`PlanText` の 4・`LegalLinks.appleEULATitle`・`PageNavigation.weekdayLetters` の 7・`YearMonth.title`）、`Plan.swift` の参照名、`Holidays/JapaneseHolidays.swift|*`。
- `tools/l10n/build.py`（S0 の上に足した）:
  - `app-*.json` を読む。`target` は `"app"`（Localizable）か `"infoplist"`（InfoPlist）。アプリのキーは §2.4 の形で `kit.` で始まらない、`infoplist` のキーは Info.plist のキーの形（`^[A-Z][A-Za-z0-9]*$`）、`jaOnly` はアプリのキーに付けられない、`allowJapanese` は契約の 2 つの字だけで、その字が ja にあること（Kit のキーにも効く）。1 つのキーはアプリと Kit を通して 1 つのファイルだけ。
  - アプリ用の出力: `Sources/TegakiCalendar/Resources/Localizable.xcstrings`・`InfoPlist.xcstrings`。`"sourceLanguage": "en"`、`"version": "1.0"`、全キー `"extractionState": "manual"`、値のある言語だけ `stringUnit`（`"state": "translated"`）、`comment` は元の `comment`。Xcode と同じ形（2 字下げ・`" : "`・名前の辞書順・末尾に改行）。
  - `--format strings`（0-4 の退き先）: 10 の `<言語>.lproj/Localizable.strings`・`InfoPlist.strings`（UTF-8、キーの辞書順、comment 付き）を書き、カタログを消す。`--format` を省くと今ある形を保つ（どちらも無ければカタログ）。`--format xcstrings` で戻すと 10 の `.lproj` の 2 つの `.strings` を消す（空になった `.lproj` も。ほかのファイルは触らない）。
  - `--check`: 何も書かずに比べ、違う・無い・他方の形が残っているファイルを 1 行ずつ出して終了状態 1。lint の L-10 も同じ関数（`check_outputs`）。
- `tools/l10n/lint.py`（新規・実行権つき）: `python3 -I tools/l10n/lint.py [<リポジトリ>] [--only L-1,L-3,…]`。この版は L-1・L-3・L-4・L-10。ほかの L は最後の行に「not in this lint yet」と出す。`build.py` と `baseline.py` をパスで読み込む（`-I` では script のフォルダが `sys.path` に無いため）。`__pycache__` を書かない。
- `Sources/TegakiCalendar/Support/L10n.swift`（新規）: `enum L`（§0 の `language`・`locale`・`text(_:)`・`text(_:in:)`・`format`・`plural` と、下のずれの 7 の `value(_:in:)`）。
- 作業の木の生成物を作り直した: `KitStrings.generated.swift`（K・H の今の元から。S0 の版の build.py で作られていたもので、`fill` が public になった分だけ違う）と、空の `Localizable.xcstrings`・`InfoPlist.xcstrings`（アプリの元がまだ無いので 0 キー）。

### 契約からのずれ・契約が黙っている所の決め方

1. **`was`・`composedOf` の書き方**: 1 つは「<ファイル>:<行>」（ファイルは ja-baseline.tsv の形。`Sources/TegakiCalendar/`・`TegakiKit/Sources/` を付けても同じに読む）。1.1 には日本語の字が 1 行に 2 つ以上ある行が 26 ある（曜日の表、三項演算子など）ので、`was` はその行の字のうち **ja と同じ字** を指す。同じ字が 2 つある行（`Views/A.swift:6` の "同じ" + "同じ" のような）・ja と同じ字が無い行・`composedOf` で行に字が 2 つ以上あるときは「<ファイル>:<行>#<n>」（左から n 番目）と書く。契約は `file:line` の形しか書いていない。
2. **「ちょうど 1 つのキー」の数え方**（L-3）: 1.1 の 1 つの字を `was` に書けるのは 1 つのキーだけ（`.one` と `.other` は 1 つと数える）。`composedOf` には何本のキーが同じ字を書いてもよい（部品を別の文でも使う場合。そのキーのほかに `was` を書くキーがあってもよい）。キーと例外の両方に当たる行もよい（Kit の `static let yearlyBadge` などは例外のまま残り、同じ字のキーも `was` で 1.1 の字と照らせる）。どの持ち主のキーも、どのファイルの行を書いてもよい（アプリのファイルの曜日の字は K の `kit.weekday.letter.*` の `was` が指す。K は既にそうしている）。
3. `was` の字に `\(…)` があれば失敗（C 型は `composedOf` へ）。`was` の字は、Swift の escape（`\n`・`\t`・`\"`・`\\`・`\0`・`\'`・`\u{…}`）をほどいて JSON の ja と比べる。`composedOf` の字は lint では照らさない（組み上がった ja は持ち主のテスト、§1.3）。
4. 例外は「パス|字」で当たる（契約の形のまま。行を持たないので、そのファイルの同じ字は全部当たる）。「理由」は最後の `|` の後ろなので `|` を書けない。どの字にも当たらない例外は警告（失敗にしない）。
5. **L-4 で `args` も照らす**: ja の埋め込みの番号の集まりが 1〜（`args` の数）と同じこと（`args` があるときだけ）。契約は「全言語で同じ」とだけ書いている。複数形の `.one`・`.other` は同じファイルに置く。埋め込みの数え方は `KitStrings.fill` と同じ（`%@` は前から順に 1, 2, …、`%n$@` は n）。
6. **`KitStrings.fill(_:_:)` を public にした**（S0 の private の `fill`。§0 に無い public の関数）。アプリの `L.format`・`L.plural` が Kit と同じ埋め込みの規則（`%@`・`%n$@` だけを置き換え、`String(format:)` を使わない。訳の中の `%` で落ちない・引数を食わない）を使うため。中身は 1 バイトも変えていない。
7. **`L.value(_:in:)` を足した**（§0 に無い）。その言語の `.lproj` の値そのもの（受け皿なし、無ければ nil）。S の `testEveryLanguageBundleHasEveryKey` は、`text(_:in:)` の受け皿（en → キー）では訳し漏れが見えないため（S0 の `KitStrings.value` と同じ理由）。
8. **`L.text(_:)` の引き方**: `Bundle.main.localizedString`（iOS が選んだ `.lproj`。`L.language` と同じ）で引き、無ければ `en.lproj` の bundle、それも無ければキー。`text(_:in:)`・`value(_:in:)` は `Bundle(path: <言語>.lproj)`。無い印に渡す値は大文字の無い私用の字 3 つ: この Mac の Foundation で測ると、`-NSShowNonLocalizedStrings YES`（l10n-shots の訳し漏れの数え方）では **渡した値を大文字にして** 返し（英字の印だと「L10N-MISSING」が画面に出た）、`-NSDoubleLocalizedStrings YES` では値を 2 回にして返す。どちらでも印で始まるので受け皿が働く。見つかった字は、`-NSDoubleLocalizedStrings` で最初の `%` が落ちて 2 回になる（「%@ Striche」→「@ Striche %@ Striche」。埋め込みの数を保つための Foundation の作り。二倍長の写真ではそう見える）。「l10n: missing <キー>」のログは DEBUG と写真モードで、キーごとに 1 回だけ。
9. **非文字を止める**: 値に非文字（U+FDD0–U+FDEF・U+FFFE・U+FFFF・U+1FFFE など）があれば build.py が止まる。S0 の `ESCAPED_RANGES` は U+FDD0–U+FDEF を `\u{FDD0}` と書くが、swiftc はそれを "invalid unicode scalar" で拒む（この Mac で実測。生の字なら通る）ので、そのままだと Kit が組み立たない。字ではないので止めることにした。
10. `infoplist` のキーは形だけを見る（2 つに固定しない）。ja が project.yml の値と同じかは lint では見ない（S の後半の `testInfoPlistIsLocalized` で `Bundle.main.infoDictionary` の値と比べるのがよい）。
11. ja-baseline.tsv は、生の改行・タブの無い普通の 1 行の文字列だけを持つ（1.1 は KitChecks の外に生の文字列・複数行の文字列が無い。あれば baseline.py が止まる）。
12. この Mac の `python3` は x86_64 の python.org 3.9.6（Rosetta）で、そこから `/usr/bin/git` を動かすと xcrun が libxcrun を読めずに落ちる。baseline.py は `/usr/bin/python3`（arm64 の 3.9.6）で走らせるか、`git archive <commit> | tar -x -C <フォルダ>` で取り出して `--tree <フォルダ> --commit <40 字>` を渡す（どちらも同じ結果を確かめた）。build.py と lint.py は git を使わないので、どの Python でも走る。

### 確かめたこと

- baseline.py: e7b4d2f で 515 行・42 ファイル。偵察の `l10n_lint.py` の出力（`scratchpad/m7b/lint-e7b4d2f.txt`）と、ファイル・行・字が 1 行ずつ同じ。`--check` が `/usr/bin/python3`・3.12.16 の venv・`--tree`（Rosetta の `python3`）で一致。
- build.py: S0 の 66 項目（app-*.json を読むようになったので、そのうち 1 項目は期待を「読んで止まる」に変えた）、S1 の 53 項目（app-*.json の誤り 34 通り・非文字 7 通り・カタログの中身と形・2 回目は書かない・並べ替えた元でも同じ bytes・`--check`・`--format strings` と戻し・残った `.strings`・元が無いとき）が、Python 3.9.6（`python3`・`/usr/bin/python3`）と 3.12.16 で全部合格。3 つの Python の生成物が同じ bytes。`.strings` は `plutil -convert json` で読み戻すと元の値と同じ（改行・引用符・バックスラッシュ・タブ・`%@`）。S0 の版との Kit の生成物の差は `fill` の所だけ（表は同じ）。
- lint.py: 作り物の木で 21 項目が合格（L-1: 字句の難所 6 種類とコメント・KitChecks と生成物とテストを見ない・`*`・例外の形 6 種類・UTF-8 でないファイル・例外のファイルが無い。L-3: `was` を ja で選ぶ・長いパス・`#n`・`composedOf`・escape・誤り 11 種類・2 つのキーの `was`・複数形の対・キーと例外の重なり・TSV が無い・頭と行の数が合わない。L-4: 10 種類。L-10: 一致・元の変更・壊れた元）。`__pycache__` を書かない。
- e7b4d2f の木で lint: L-1 は 462 件（515 − 例外に当たる 53）、L-3 は 53 が例外・462 がどれにも当たらない、L-4・L-10 は緑。今の作業の木（K と H の途中の元）で、L-3 は 47 行が K の `was` に当たり参照の誤り 0、L-1 で K の新しい `DateText.swift`・`LayoutWords.swift` と `L10n.swift` に日本語の字は無い。
- `L10n.swift`: 実際のファイルを macOS の .app に入れ（`-D DEBUG` と `-O`。`ScreenshotMode` だけ代わり）、`--format strings` で作った 10 の `.lproj` で動かした（`scratchpad/m7b-impl/S1/lprobe`）: ja・de・fr の字、en への受け皿、キーへの受け皿、ログはキーごとに 1 回で release は写真モードだけ、`format` の順番（`%2$@ %1$@`）、複数形（fr の 0 は one、de の 0 は other）、`text(_:in:)`・`value(_:in:)`、言語の選ばれ方（th → en、(ru, ja) → ja、zh-HK → zh-Hant、pt-PT → pt-BR、es-MX → es、ar → en。§2.1 の表と同じ）、`-NSShowNonLocalizedStrings YES`・`-NSDoubleLocalizedStrings YES` でも受け皿が働く。
- 型と Kit: `git archive HEAD`（88df31c）に私のファイル（tools/l10n の 5 つと `L10n.swift`）と、`L10n.swift` と生成物が使う K の `UILanguage.swift` を重ね、build.py で生成した写し（`scratchpad/m7b-impl/S1/overlay`）で、`swift build --package-path TegakiKit` 緑、KitChecks「all 24446 checks passed」（1.1 と同じ数）、`tools/typecheck/typecheck.sh scratchpad/m7b-impl/S1/tc` all OK・警告 0（アプリ 60 ファイル、TegakiCalendarTests 26、UI テスト 2、Kit のテスト 5 つ）。作業の木そのままでは、手順 1〜5（`L10n.swift` を含むアプリと 2 つのテスト）は OK・警告 0 で、手順 6 が H の書きかけの `HolidayCalendar.swift` で落ちた（私のファイルではない）。
- 試験の材料は `/private/tmp/claude-501/-Users-ikedamasataka-Documents-Codex/1d1a8054-037e-4e4c-982f-6008fda67420/scratchpad/m7b-impl/S1/pytest/`（`cases_s0.py`・`cases_s1.py`・`cases_lint.py`。`python3 -I cases_lint.py <作業の木>/tools/l10n <python>`）。

### 次の役へ

- **キーを足す人（S・U・P・K・H）**: 1.1 の字を 1 つの文のまま移したキーは `was` に ja-baseline.tsv の行を、つないでいた字（`\(…)` のある字、`+` でつないだ字）は `composedOf` に。行に字が 2 つ以上あって `composedOf` に書くとき、同じ字が 2 つあるときは `#n`。元を変えたら `python3 -I tools/l10n/build.py .` → `python3 -I tools/l10n/lint.py . --only L-3,L-4,L-10`（L-1 と L-3 は全員の移しが終わるまで落ちる。自分のファイルは L-1・L-3 の最後の行の「<ファイル> <件数>」と、行ごとの出力で見る）。
- **U**: §5.8 の語（`["祝日", "holiday", "feiertag", "ferie", "festiv", "feriado", "节假日", "節假日", "假日", "공휴일"]`）の漢字とハングルの 5 つは例外に入れてある（`Calendar/EventKitService.swift|<語>|…`）。字を変えるなら S に（ja-exceptions.txt は S の持ち物）。写真モードの 31 の字は例外に無い（契約のとおり `demo.*` のキーへ）。
- **S（後半）**: L-2・L-5〜L-9・L-11・L-12 を lint.py に足す（`CHECKS` に名前、`check_l<n>` を足し、`LATER` から消す。元と訳は `build.load_sources`・`build.load_translations`・`build.values_of`、Swift の字は `baseline.swift_literals`）。`L10nTests`・`LocalizationBundleTests`（`L.value(_:in:)` を使う。TSV の形は上の「入れたもの」、escape のほどき方は `baseline.unescape`）。InfoPlist の 2 キーは app-S.json に（ja は project.yml の値のまま）。
- **C**: CI の「Localization lint」は `python3 -I tools/l10n/lint.py .`（git も書き込みも無い）。生成物の確かめは `python3 -I tools/l10n/build.py --check .` でもよい（lint の L-10 と同じ）。

### 残る危険

- `text(_:in:)`・`value(_:in:)` の `Bundle(path: <言語>.lproj)` の引き方は、macOS の同じ API で確かめただけ。iOS では S の `LocalizationBundleTests`（CI）で確かめる。Xcode がカタログを `.lproj/*.strings` でない形に組むと、この 2 つが nil を返す（`text(_:)` は `Bundle.main` なので影響しない）。そのときは `--format strings`（0-4）。
- カタログの形（Xcode の並び、`"version": "1.0"`）が CI の Xcode 26 で書き換えられないかは、CI の `git diff --exit-code -- Sources/TegakiCalendar/Resources`（0-5）で。
- 例外は「パス|字」で当たるので、例外のあるファイルで同じ字を新しく書いても L-1 は見逃す（例: `Layout/PageNavigation.swift` に新しく `"日"` を書く）。

## H（§5 の全部: 祝日のデータと生成器・`Holidays` の型・`HolidayChecks`・`WorldHolidaysTests`。第 4 版の足しを含む）

前の H（2026-11-01 に利用枠で止まった）の途中の変更を下書きとして続けた。作り直したのは `HolidayData` の `index.json`・`SOURCE.json` だけ（国のファイルは 1 バイトも変わっていない）。

### 入れたもの

- `tools/holidays/`（新規）: `gen.py`（試作を土台に §5.1・§5.2 の全部）、`requirements.txt`（版と sha256）、`iso_regions.swift`・`iso-regions.txt`（Foundation の 2 字の地域 261）、`summarize.py`（2 つの `HolidayData` の差を日本語で）、`README.md`（作り方と毎年の更新。§5.11）。
- `TegakiKit/HolidayData/`（新規、254 ファイル）: `<国>.json` **250**・`index.json`・`SOURCE.json`・`LICENSE-python-holidays.txt`・`CONTRIBUTORS-python-holidays.txt`。python-holidays 0.107 から生成。**2 回作って `diff -r` が空**。大きさ 4,228,506 B（国のファイル 4,127,695 B、`index.json` 75,708 B）、zlib で 1,635,839 B。全国の祝日 326,948 件、州・地域の差 124,286 件。全国と差のある州・地域 469（32 か国）、差が無くて書かなかった州・地域 157。
- `tools/l10n/source/kit-H.json`（新規。`kit.holiday.estimatedSuffix`「（推定）」・`kit.holiday.dayOff`「振替の休み」）を書いて `build.py` で生成した。X が訳す。
- `TegakiKit/Sources/Holidays/` の新しい 5 ファイル（`HolidayCalendar`・`HolidaySetting`・`HolidayFile`・`HolidayStore`・`JapanHolidayBridge`）と `HolidayDataLicense`。§0 の形のまま（足した物はずれの 6）。
- `TegakiKit/Sources/KitChecks/HolidayChecks.swift`（新規。「holidays (1.2)」**243 件**。`main.swift` からの呼び出しは K1 の注記の所に 1 行）。
- `TegakiKit/Tests/HolidaysTests/WorldHolidaysTests.swift`（新規。§7.2 の 21 本 ＋ `testOneLowYearDoesNotEndTheCoverage`・`testEUCountriesHaveData` の 23 本）・`HolidayDataLocation.swift`。

**第 4 版で足した物**: (1) `holidayCheckSoldRegions` に EU 27 を足して 175（「148」「O-4」のコメントも）。(2) `gen.py` の `coverage_range` を 0-30 の形に（下の「coverage の直し」）。(3) この節の販売中の表。

### 取り寄せた物（§5.1）

本人の了承（M7B-10）で 2026-11-01 に PyPI から 1 回だけ取り寄せた。置き場所は `~/.local/share/tegaki-python/holidays-0.107/wheels/`（リポジトリの外。消すときはそのフォルダを消すだけ）。

| ファイル | 大きさ | sha256 | Requires-Python |
| --- | --- | --- | --- |
| `holidays-0.107-py3-none-any.whl` | 1,694,848 B | `5e4582d543b145d8ebb80ce8943e60ea5c8b6a30b74201ad0f95af0cbe67cb14` | `>=3.10` |
| `python_dateutil-2.9.0.post0-py2.py3-none-any.whl` | 229,892 B | `a8b2bc7bffae282281c8140a97d3aa9c14da0b136dfe83f850eea9a5f7470427` | `!=3.0.*,!=3.1.*,!=3.2.*,>=2.7` |
| `six-1.17.0-py2.py3-none-any.whl` | 11,050 B | `4721f391ed90541fddacab5acf947aa0d3dc7d27b2e1e8eda2be8970586c3274` | `>=2.7, !=3.0.*, !=3.1.*, !=3.2.*` |

生成に使った Python は **3.12.16**（`~/.local/share/tegaki-python/python`。venv は `<scratchpad>/hol3/venv`、版は `pip freeze` で `holidays==0.107`・`python-dateutil==2.9.0.post0`・`six==1.17.0`）。0.107 は 3.10 以上が要るので、この Mac の 3.9.6 では入らない（0-14 の「3.9 で入る版」から変わった。版と Python はリードが本人の了承を得て用意した物をそのまま使った）。`tzdata` は依存から消えた。`SOURCE.json` に Python と 3 つの版、各 dist-info の `RECORD` の sha256、2 つのライセンスの sha256、`gen.py` の sha256 がある。

### 0.83 → 0.107（0-14）

| 項目 | 0.83 | 0.107 |
| --- | --- | --- |
| 国・地域 | 249 | **250**（コソボ XK が増えた。消えた国は無い） |
| 全国の祝日 | 327,685 件 | 326,948 件 |
| 全国と差のある州・地域 | 463 | 469 |
| 全部の大きさ | 4,117,869 B | 4,228,506 B |
| 振り替え休日の型のある国 | 11 | 15（AM AZ BG BY CN HU KG KZ LV MM RU TW UA UZ VN） |
| 中国の振り替え休日の型 | 休息日（%s日起取代） | 休息日（由 %s 调休）。台湾は 放假日（%s 補班）。英語の型は同じ。`short` は「休息日」「放假日」「Day off」 |
| `observed_label` が "%s" だけの国 | 14 | 13（RU が外れた。AW BQ BR CH CL CW DO GT JP MO NL SX UY） |
| `substFmt` の型 | 7 通り | 同じ 7 通り |
| `short` が空になる型 | — | 0.107 には無い（`kit.holiday.dayOff` は受け皿のまま残した） |

**`lastOfficialYear` と `coverage` の主な変化**（年は全部 0.107 の実測。`summarize.py` の全文 218 行は 0.83 のデータがこの木に無いので載せない。主な物は下）:

| 国 | `lastOfficialYear` | `coverage` | 意味 |
| --- | --- | --- | --- |
| CN | 2025 → **2026** | 2008〜2099 のまま | **2026 年の発表が入った**（春節 2/16〜2/23 の連休、振替出勤 1/4・2/14・2/28・5/9・9/20・10/10 の 6 日。件数 13 → 22）。発表前は 2027 年から |
| VN | 2024 → **2026** | 同じ | 発表前は 2027 年から |
| RU | 2025 → **2027** | 同じ | 発表前は 2028 年から |
| BY・UZ | 2025 → **2026** | 同じ（UZ は until 2077） | 発表前は 2027 年から |
| TW・KZ | 2025 のまま | 同じ | **今年（2026 年）が「発表前の推定」と出る**（下の「弱い所」） |
| KR・SG・NP・AE | 変わらない（2025・2025・2025・2024） | 同じ | KR は件数が増えた（2027 年 20 → 24 件など。合計 +192） |
| LK | 2025 → 2026 | 〜2025 → **〜2026** | 2026 年の祝日 26 件が入った。**今年は欠けない**（2027 年から） |
| GB・MY | 2023 → 2026 | 同じ | |
| US ほか米国の領土 | 1917 → 2025 | 同じ | 特別の表に 2025 年の日が入った |
| ES | 2022 のまま | 2000〜 → **2008〜** | 2000〜2009 年の件数が減った（過去の年だけ） |
| RO | — | 2012〜 → **2017〜** | 過去の年だけ |
| BD | None → 2024 | 〜2099 → **〜2077** | 件数が年 7 件 → 17〜24 件（イスラム暦などの祝日が入り、その表の終わりで範囲が切れる） |
| GH・KG | None → 2026・2025 | 〜2099 → **〜2077**（`from` も 2002 に） | 同じ |
| MA | — | 〜2077 → **〜2099** | |

**ほかの大きな差**: スウェーデンは 6,818 → 1,300 件（0.83 は日曜が全部祝日「Söndag」だった。直って良くなった）。バングラデシュ +917、キルギス +457、ガボン +265、ラトビア +236、韓国 +192、イタリア +174、ガーナ −162、スペイン −179。

**州・地域**: インドの AP・BR・CG・DL・NL・TS が無くなり（全国と差が無くなったか消えた）、AR・DH・LD・TR が増えた。新しいのは AM-LO・AM-SH・AR-C・AR-X・AU-NSW Western・BR-Sao Paulo Capital・CH-Stadt Zurich・ES-Barcelona。**1.2 が最初のデータなので、記録済みの州の改名は起きない**（`renamed` は全部空）。

**テストの期待のうち 0.107 で変えたもの**（§7.1・§7.2 の「版で動く」の所。日本の日は変わらない）:

| 所 | 契約（0.83） | 0.107 | 理由 |
| --- | --- | --- | --- |
| `testKnownDates` 中国 2025-02-03 zh-Hans の full | 休息日（2025-01-26日起取代） | 休息日（由 2025-01-26 调休） | 振り替え休日の型 |
| `testYearNotes` CN の発表前 | 2026 | 2027 | 2026 年の発表が入った。CN 2027 の規則の「（补假）」2/9・2/10・5/3・5/4・10/4・10/5 が祝日でなく、10/1 に estimated |
| `testYearNotes` LK | `.incomplete` が 2026 年から | 2027 年から（until 2026） | |
| 件数 249 | 249 | 250 | コソボ |

アラブ首長国連邦 2026-03-20 Eid al-Fitr は 0.107 でも推定（en の full に印、short に無い）なので、見本の日は変えていない。

### 本人に見せる期待の確かめ直し（0-14。§8 の 8・§8 の 9）

0.107 の `HolidayData` で全部確かめた。**どれも契約の期待のまま**で、直す所は無い（KitChecks と `WorldHolidaysTests` に入れた）。

| 期待 | 0.107 |
| --- | --- |
| 米国 10/12 Columbus Day・11/26 Thanksgiving Day | 同じ |
| カリフォルニア州 10/12 は祝日なし・11/27 Day After Thanksgiving | 同じ（`US-CA` の州の差は add と remove のまま） |
| ドイツの州の表示名 Bayern | 同じ（`DE-BY` の `display`） |
| カナダ「全国共通のみ」（州が 13。国全体は 2026 年に New Year's Day・Good Friday・Canada Day・Labour Day・Christmas Day の 5 つ） | 同じ |
| 台湾 10/9「國慶日（補假）」・10/10「國慶日」 | 同じ |
| 日本の英語名 Sports Day（10/12） | 同じ |
| 韓国は州の画面が無い・ノルウェーは州が 0 | 同じ |

**変わった所は例の文だけ（§5.7、0-20）**: 「スリランカ（2026 年以降のデータがありません）」は 0.107 では今年は出ない（「2027 年以降」が 2027 年に出る）。「中国（2026 年は発表前の推定）」も今年は出ず、今年出るのは台湾・カザフスタン。「自動（コソボ・祝日のデータがありません）」はコソボにデータがあるので出ない（次の役への U の所）。本人の手順と写真の期待にはこの 3 つの国は無いので、本人に渡す物は変わらない。

### coverage の直し（0-30、§5.10。第 4 版）

`coverage_range` の規則を足した: 基準を下回る年が 1 年だけで、0 件でなく、前の年と次の年が基準以上のときは範囲を切らない。**結果は契約の見込みと全部同じ**:

| 国 | 前 | 後 | 件数（基準） |
| --- | --- | --- | --- |
| SK | 2000〜**2025** | 2000〜**2099** | 2026 年 11 件（12）、2027 年から 13 件 |
| AM | **2003**〜2099 | **2001**〜2099 | 2002 年 10 件（10.4） |
| CD | **2015**〜2099 | **2000**〜2099 | 2014 年 6 件（7.2） |
| KE | **2011**〜2099 | **2000**〜2099 | 2010 年 9 件（9.2） |
| PH | **2012**〜2099 | **2010**〜2099 | 2011 年 15 件（15.6） |

ほかの 245 は変わらない。**LK は 2003〜2026、UA は 2000〜2021 で止まる**（UA の 2022 年は 3 件で、次の年が 0 件なので切る）。EU の 27 か国の `until` は全部 2099。LK・UA・SK・4 か国の `from`・EU の 27 か国を `HolidayChecks` と `WorldHolidaysTests.testYearNotes`・`testOneLowYearDoesNotEndTheCoverage`・`testEUCountriesHaveData` で固定した。「前の年も基準以上」を条件にしたのは、契約の「範囲を切らない」の読み（範囲の途中の 1 年だけ）で、付けないと 2000 年や範囲の頭の 1 年が足されて 40 か国が変わり、契約の見込みと合わない。規則の境目（0 件・2 年続き・2000 年・2099 年・2020 年そのもの）はリポジトリの外の 12 通りで確かめた。

### データの弱い所（§5.10。0.107 の実測）

| 弱い所 | 0.107 の実測 | 画面での知らせ方 |
| --- | --- | --- |
| イスラム暦の祝日が消える | 2078 年ごろから（サウジアラビア 2077 年 13 件 → 2078 年 3 件 → 2099 年 2 件）。until が 2076・2077 の国は 51、販売中で 39。シンガポールは 2078 年以降も年 9〜12 件で範囲は切れない（契約の 0.83 の「2083 年」は今は当たらない） | `coverage` の外（0-30） |
| ヒンドゥー暦 | ネパール 2035 年 30 件 → 2036 年 6 件、インド 19 → 10 件、モーリシャス 15 → 11 件（until 2035） | 同じ |
| スリランカ | 2027 年以降 0 件。until 2026 | **来年から**「2027 年以降のデータがありません」 |
| ウクライナ | 2022 年 5 件（祝日 3）、2023 年以降 0 件（戒厳令）。until 2021 | **今年も**「2022 年以降のデータがありません」 |
| スロバキア | 2026 年は 11 件で 2027 年から 13 件。データは 2099 年まで | 出ない（直した） |
| 今年が「発表前」と出る国 | **台湾・カザフスタン**（`lastOfficialYear` 2025）。台湾は 2026 年の特別の表が無いだけで、調整の日が無い年の可能性がある（確かめていない）。そうなら「発表前の推定」は言い過ぎだが、0-29 の決まりのとおりにした | 設定の行と選ぶ画面に「2026 年は発表前の推定」 |
| 来年（2027 年）に「発表前」になる国 | 中国・ベトナム・ベラルーシ・ウズベキスタン（と台湾・カザフスタン）。CN と VN は全部の祝日に「（推定）」。CN は規則で作った「（补假）」の日を書かない（270 日）。ロシアは 2028 年から | 毎年の更新で動く（§5.11） |
| 2026 年でも推定の祝日がある国 | 販売中の 48 か国（モルディブ・イエメン 13 件、オマーン 12、イラク 11、バーレーン・ヨルダン・クウェート 10、アラブ首長国連邦 9、エジプト 6 など）。**パキスタン・インドネシア・マレーシア・インドは 0.107 で 2026 年の公式の表が入って推定でなくなった**（契約の 0.83 の例から変わった） | 名前に「（推定）」（0-17） |
| 州の振替出勤 | アルメニアの AM-LO・AM-SH は振替出勤の日が全国と違うが、§5.2 の形に州の `workdays` が無いので書いていない（色だけの差。名前と休みは正しい）。gen.py が標準エラーに出す | 無し |
| 訳の照らし合わせ | 台湾の zh-Hans の列の 23 日（臺灣光復… の振替）は、ライブラリの訳に照らせず同じ日の名前を使った（名前は正しい）。ほかの 106 万件は訳の表で照らせた | 無し |
| 祝日がほぼ無い地域（FIX が足した） | ブーベ島・ハード島とマクドナルド諸島・英領インド洋地域（BV・HM・IO。販売外）は祝日が 0 件で、`coverage` は 2000〜2099。ギニアビサウ（GW。販売中）はデータが 2023 年からなのに `coverage` は 2000〜2099。どれも 2015〜2024 年の中央値が 0 なので、`coverage_range` が全部の年を「揃っている」と見る | 知らせは出ない。BV・HM・IO は選べて、選ぶと何も出ない（0-20 の「祝日のデータがありません」も出ない。ほぼ無人の地域）。GW は 2026 年に祝日があるので今年は問題ない |

**販売中の地域でデータが無い所は無い**（0.107 でコソボが入った。ずれの 2）。

### 販売中の 175 の国・地域（§5.10。KitChecks が同じ一覧を書き出す）

名前の言語の数（§5.5）: 英語 175、フランス語 21、スペイン語 19、ポルトガル語 8、ドイツ語 7、簡体字 5、繁体字 4、イタリア語 2、日本語 1、韓国語 1（10 言語がそろう国は無い。いちばん多いカーボベルデで 5）。「州」は全国と差のある州・地域の数。「2026 年の注記」は今年の設定の行に出る文。

| コード | 国・地域 | 公式の表の最後の年 | 政府の発表 | データの揃っている年 | 州 | 2026 年の注記 |
| --- | --- | --- | --- | --- | --- | --- |
| AE | アラブ首長国連邦 | 2024 |  | 2000〜2076 |  |  |
| AF | アフガニスタン | — |  | 2001〜2077 |  |  |
| AG | アンティグア・バーブーダ | 2023 |  | 2000〜2099 |  |  |
| AI | アンギラ | 2025 |  | 2001〜2099 |  |  |
| AL | アルバニア | 2024 |  | 2004〜2099 |  |  |
| AM | アルメニア | 2021 |  | 2001〜2099 | 2 |  |
| AO | アンゴラ | 2017 |  | 2000〜2099 |  |  |
| AR | アルゼンチン | 2026 |  | 2010〜2099 | 16 |  |
| AT | オーストリア（EU） | — |  | 2000〜2099 |  |  |
| AU | オーストラリア | 2022 |  | 2000〜2099 | 9 |  |
| AZ | アゼルバイジャン | 2072 |  | 2000〜2099 |  |  |
| BA | ボスニア・ヘルツェゴビナ | — |  | 2000〜2077 | 3 |  |
| BB | バルバドス | 2023 |  | 2000〜2099 |  |  |
| BE | ベルギー（EU） | — |  | 2000〜2099 |  |  |
| BF | ブルキナファソ | — |  | 2000〜2099 |  |  |
| BG | ブルガリア（EU） | 2026 |  | 2000〜2099 |  |  |
| BH | バーレーン | — |  | 2000〜2076 |  |  |
| BJ | ベナン | — |  | 2000〜2077 |  |  |
| BM | バミューダ | 2023 |  | 2000〜2099 |  |  |
| BN | ブルネイ | 2017 |  | 2000〜2077 |  |  |
| BO | ボリビア | — |  | 2009〜2099 | 9 |  |
| BR | ブラジル | — |  | 2000〜2099 | 28 |  |
| BS | バハマ | 2022 |  | 2000〜2099 |  |  |
| BT | ブータン | — |  | 2007〜2099 | 1 |  |
| BW | ボツワナ | 2019 |  | 2000〜2099 |  |  |
| BY | ベラルーシ | 2026 | はい | 2000〜2099 |  |  |
| BZ | ベリーズ | — |  | 2000〜2099 |  |  |
| CA | カナダ | 2022 |  | 2000〜2099 | 13 |  |
| CD | コンゴ民主共和国（キンシャサ） | — |  | 2000〜2099 |  |  |
| CG | コンゴ共和国（ブラザビル） | — |  | 2000〜2099 |  |  |
| CH | スイス | — |  | 2000〜2099 | 27 |  |
| CI | コートジボワール | 2024 |  | 2000〜2077 |  |  |
| CL | チリ | 2022 |  | 2000〜2099 | 2 |  |
| CM | カメルーン | 2021 |  | 2000〜2077 |  |  |
| CN | 中国本土 | 2026 | はい | 2008〜2099 |  |  |
| CO | コロンビア | — |  | 2000〜2099 |  |  |
| CR | コスタリカ | — |  | 2000〜2099 |  |  |
| CV | カーボベルデ | — |  | 2000〜2099 | 22 |  |
| CY | キプロス（EU） | — |  | 2000〜2099 |  |  |
| CZ | チェコ（EU） | — |  | 2000〜2099 |  |  |
| DE | ドイツ（EU） | 2028 |  | 2000〜2099 | 17 |  |
| DK | デンマーク（EU） | — |  | 2000〜2099 |  |  |
| DM | ドミニカ国 | 2019 |  | 2000〜2099 |  |  |
| DO | ドミニカ共和国 | — |  | 2000〜2099 |  |  |
| DZ | アルジェリア | — |  | 2000〜2077 |  |  |
| EC | エクアドル | — |  | 2000〜2099 |  |  |
| EE | エストニア（EU） | — |  | 2000〜2099 |  |  |
| EG | エジプト | 2024 |  | 2002〜2077 |  |  |
| ES | スペイン（EU） | 2022 |  | 2008〜2099 | 20 |  |
| FI | フィンランド（EU） | — |  | 2000〜2099 | 1 |  |
| FJ | フィジー | — |  | 2016〜2099 |  |  |
| FM | ミクロネシア連邦 | — |  | 2004〜2099 | 4 |  |
| FR | フランス（EU） | — |  | 2000〜2099 | 12 |  |
| GA | ガボン | 2025 |  | 2000〜2099 |  |  |
| GB | イギリス | 2026 |  | 2000〜2099 | 4 |  |
| GD | グレナダ | 2023 |  | 2000〜2099 |  |  |
| GE | ジョージア | 2025 |  | 2000〜2099 |  |  |
| GH | ガーナ | 2026 |  | 2002〜2077 |  |  |
| GM | ガンビア | — |  | 2000〜2077 |  |  |
| GR | ギリシャ（EU） | — |  | 2000〜2099 |  |  |
| GT | グアテマラ | — |  | 2000〜2099 |  |  |
| GW | ギニアビサウ | — |  | 2000〜2099 |  |  |
| GY | ガイアナ | 2020 |  | 2001〜2077 |  |  |
| HK | 香港 | 2015 |  | 2000〜2099 |  |  |
| HN | ホンジュラス | — |  | 2000〜2099 |  |  |
| HR | クロアチア（EU） | — |  | 2002〜2099 |  |  |
| HU | ハンガリー（EU） | 2026 |  | 2000〜2099 |  |  |
| ID | インドネシア | 2027 |  | 2003〜2077 |  |  |
| IE | アイルランド（EU） | 2022 |  | 2000〜2099 |  |  |
| IL | イスラエル | — |  | 2000〜2099 |  |  |
| IN | インド | 2026 |  | 2001〜2035 | 28 |  |
| IQ | イラク | — |  | 2000〜2076 |  |  |
| IS | アイスランド | — |  | 2000〜2099 |  |  |
| IT | イタリア（EU） | 2011 |  | 2000〜2099 | 112 |  |
| JM | ジャマイカ | — |  | 2000〜2099 |  |  |
| JO | ヨルダン | — |  | 2000〜2077 |  |  |
| JP | 日本 | 2019 |  | 2000〜2099 |  |  |
| KE | ケニア | 2024 |  | 2000〜2099 |  |  |
| KG | キルギス | 2025 |  | 2002〜2077 |  |  |
| KH | カンボジア | 2024 |  | 2000〜2099 |  |  |
| KN | セントクリストファー・ネーヴィス | 2024 |  | 2000〜2099 |  |  |
| KR | 韓国 | 2025 |  | 2000〜2099 |  |  |
| KW | クウェート | — |  | 2000〜2077 |  |  |
| KY | ケイマン諸島 | 2025 |  | 2006〜2099 |  |  |
| KZ | カザフスタン | 2025 | はい | 2006〜2099 |  | 2026 年は発表前の推定 |
| LA | ラオス | 2020 |  | 2000〜2099 |  |  |
| LB | レバノン | — |  | 2000〜2077 |  |  |
| LC | セントルシア | — |  | 2000〜2099 |  |  |
| LK | スリランカ | 2026 |  | 2003〜2026 |  |  |
| LR | リベリア | — |  | 2000〜2099 |  |  |
| LT | リトアニア（EU） | — |  | 2000〜2099 |  |  |
| LU | ルクセンブルク（EU） | — |  | 2000〜2099 |  |  |
| LV | ラトビア（EU） | 2026 |  | 2000〜2099 |  |  |
| LY | リビア | 2023 |  | 2000〜2077 |  |  |
| MA | モロッコ | — |  | 2000〜2099 |  |  |
| MD | モルドバ | — |  | 2013〜2099 |  |  |
| ME | モンテネグロ | 2024 |  | 2007〜2099 |  |  |
| MG | マダガスカル | — |  | 2000〜2099 |  |  |
| MK | 北マケドニア | 2024 |  | 2007〜2099 |  |  |
| ML | マリ | — |  | 2000〜2077 |  |  |
| MM | ミャンマー (ビルマ) | 2025 |  | 2000〜2099 |  |  |
| MN | モンゴル | — |  | 2011〜2099 |  |  |
| MO | マカオ | 2020 |  | 2000〜2099 |  |  |
| MR | モーリタニア | — |  | 2000〜2077 |  |  |
| MS | モントセラト | 2023 |  | 2017〜2099 |  |  |
| MT | マルタ（EU） | — |  | 2000〜2099 |  |  |
| MU | モーリシャス | 2019 |  | 2001〜2035 |  |  |
| MV | モルディブ | — |  | 2000〜2077 |  |  |
| MW | マラウイ | — |  | 2000〜2099 |  |  |
| MX | メキシコ | — |  | 2000〜2099 |  |  |
| MY | マレーシア | 2026 |  | 2000〜2077 | 16 |  |
| MZ | モザンビーク | — |  | 2000〜2099 |  |  |
| NA | ナミビア | 2025 |  | 2000〜2099 |  |  |
| NE | ニジェール | — |  | 2000〜2077 |  |  |
| NG | ナイジェリア | 2025 |  | 2000〜2077 |  |  |
| NI | ニカラグア | — |  | 2000〜2099 | 1 |  |
| NL | オランダ（EU） | — |  | 2000〜2099 |  |  |
| NO | ノルウェー | — |  | 2000〜2099 |  |  |
| NP | ネパール | 2025 |  | 2021〜2035 |  |  |
| NR | ナウル | — |  | 2018〜2099 |  |  |
| NZ | ニュージーランド | 2022 |  | 2000〜2099 | 13 |  |
| OM | オマーン | — |  | 2000〜2077 |  |  |
| PA | パナマ | 2024 |  | 2000〜2099 |  |  |
| PE | ペルー | — |  | 2000〜2099 |  |  |
| PG | パプアニューギニア | 2023 |  | 2000〜2099 |  |  |
| PH | フィリピン | 2027 |  | 2010〜2099 |  |  |
| PK | パキスタン | 2026 |  | 2000〜2077 |  |  |
| PL | ポーランド（EU） | 2018 |  | 2000〜2099 |  |  |
| PT | ポルトガル（EU） | — |  | 2016〜2099 | 20 |  |
| PW | パラオ | 2020 |  | 2017〜2099 |  |  |
| PY | パラグアイ | 2025 |  | 2000〜2099 |  |  |
| QA | カタール | 2025 |  | 2012〜2077 |  |  |
| RO | ルーマニア（EU） | — |  | 2017〜2099 |  |  |
| RS | セルビア | — |  | 2007〜2099 |  |  |
| RU | ロシア | 2027 | はい | 2000〜2099 |  |  |
| RW | ルワンダ | — |  | 2015〜2099 |  |  |
| SA | サウジアラビア | 2022 |  | 2005〜2077 |  |  |
| SB | ソロモン諸島 | 2024 |  | 2000〜2099 | 9 |  |
| SC | セーシェル | 2020 |  | 2000〜2099 |  |  |
| SE | スウェーデン（EU） | — |  | 2000〜2099 |  |  |
| SG | シンガポール | 2025 |  | 2000〜2099 |  |  |
| SI | スロベニア（EU） | 2023 |  | 2000〜2099 |  |  |
| SK | スロバキア（EU） | 2018 |  | 2000〜2099 |  |  |
| SL | シエラレオネ | — |  | 2000〜2077 |  |  |
| SN | セネガル | 2022 |  | 2000〜2077 |  |  |
| SR | スリナム | — |  | 2012〜2099 |  |  |
| ST | サントメ・プリンシペ | — |  | 2014〜2099 | 1 |  |
| SV | エルサルバドル | — |  | 2000〜2099 | 1 |  |
| SZ | エスワティニ | 2000 |  | 2000〜2099 |  |  |
| TC | タークス・カイコス諸島 | — |  | 2000〜2099 |  |  |
| TD | チャド | 2021 |  | 2000〜2077 |  |  |
| TH | タイ | 2026 |  | 2000〜2099 |  |  |
| TJ | タジキスタン | — |  | 2000〜2077 |  |  |
| TM | トルクメニスタン | 2026 |  | 2000〜2077 |  |  |
| TN | チュニジア | — |  | 2000〜2077 |  |  |
| TO | トンガ | 2021 |  | 2000〜2099 |  |  |
| TR | トルコ | 1999 |  | 2009〜2077 |  |  |
| TT | トリニダード・トバゴ | — |  | 2000〜2099 |  |  |
| TW | 台湾 | 2025 | はい | 2000〜2099 |  | 2026 年は発表前の推定 |
| TZ | タンザニア | 2022 |  | 2000〜2099 |  |  |
| UA | ウクライナ | 2022 |  | 2000〜2021 |  | 2022 年以降のデータがありません |
| UG | ウガンダ | 2026 |  | 2000〜2099 |  |  |
| US | アメリカ合衆国 | 2025 |  | 2000〜2099 | 57 |  |
| UY | ウルグアイ | 2020 |  | 2000〜2099 |  |  |
| UZ | ウズベキスタン | 2026 | はい | 2000〜2077 |  |  |
| VC | セントビンセント及びグレナディーン諸島 | 2021 |  | 2000〜2099 |  |  |
| VE | ベネズエラ | 2025 |  | 2000〜2099 |  |  |
| VG | 英領ヴァージン諸島 | 2023 |  | 2000〜2099 |  |  |
| VN | ベトナム | 2026 | はい | 2006〜2099 |  |  |
| VU | バヌアツ | 2022 |  | 2000〜2099 |  |  |
| XK | コソボ | — |  | 2009〜2099 |  |  |
| YE | イエメン | — |  | 2000〜2077 |  |  |
| ZA | 南アフリカ | 2026 |  | 2000〜2099 |  |  |
| ZM | ザンビア | 2022 |  | 2000〜2099 |  |  |
| ZW | ジンバブエ | — |  | 2000〜2099 |  |  |

### 契約からのずれ・契約が黙っている所の決め方

1. **韓国語の画面の日本は英語の名前**（§5.5 に従った）。§5.3 と §7.1 は「韓国語の画面でも 2 番目の規則で ja の列」と書くが、§5.5 の系統の表では ko はハングルで ja は漢字なので 2 番目の規則に当たらず、0-15 の趣旨（読めない字を出さない）にも合う。`JP.json` に ko の列は無いので英語（Sports Day）。§7.1 の確かめも ja・zh-Hans・zh-Hant が `JapaneseHolidays` の名前、ko が英語にした。
2. **コソボにデータがある**。契約の「175 のうち 174、無いのはコソボだけ」（0-13・§5.10・§7.1）と、0-20・§5.3・§5.7 の例の「コソボ」は 0.83 の話で、0.107 には `XK.json` がある（アルバニア語と英語）。指示の「174」は事実に合わないので、表は **175 全部** にした。データの無い地域は AC・CP・CQ・DG・EA・EU・EZ・IC・QO・TA・UN の 11（どれも販売外）。
3. **`coverage` の「件数」は日の数でなく祝日の数**（名前の種類。`short` の種類を数え、振り替え休日を除く）。0-30 は「全国の祝日の件数」と書くが、日を数えると、振替で年の日数が動く notice の国が `lastOfficialYear` で切れて（CN 2027 が「発表前」でなく「データがありません」になる）、台湾が 2021 年で切れる。契約の見込み（SK の 11 件・13 件）もこの数え方と同じ。
4. **州・地域のコードを ASCII に畳んだ**（0-28 は `[A-Za-z0-9 ]` だが、0.107 に BR「São Paulo Capital」・CH「Stadt Zürich」がある）。コードは "Sao Paulo Capital"・"Stadt Zurich"、`display` はライブラリの表記のまま。`local` は 13（AU-NSW Western・BR-Sao Paulo Capital・CH-Stadt Zurich・DE-Augsburg・ES-Barcelona・IT の 7 市・NZ-South Canterbury）。
5. **`index.json` の頭と `SOURCE.json` の足し**: `index.json` は `format`（"tegaki-holidays-index/1"）・`source`・`countries`。`SOURCE.json` に `isoRegions`（`iso-regions.txt` の sha256）を足した。読み込みの検査は `format` も見る。`index.json` は 75,708 B（§5.1 の 38,896 B と §5.3 の「39 KB」は試作の値。0.83 でも今の形では 74,732 B。起動では読まないので速さの決まりには響かない）。
6. **§0 に足した public**: `HolidayCalendar.entries(forYear:)`（U の設定と確かめ用）・`HolidayCalendar.separator`・`HolidayRegion.wholeCountry`・`HolidayIndex.Country` と `Subdivision` の `init`・`CountryHolidays`（`parse`・`entries`・`workdays`・`column` など。KitChecks とテストが直接ファイルを調べるため）・`HolidayStore.directory`。§0 の形は変えていない。
7. **`note` の `.incomplete` は `coverage` の前の年にも出る**（§5.3 のとおり）。`until` は最後の年なので文は「<until + 1> 年以降…」。今年より後に範囲が始まる国は販売中に無いので（いちばん遅い NP でも 2021 年）、端末の時計が大きくずれていない限り、設定の行でこの文が過去の年に出ることはない。
8. `gen.py` は `-I` が無いと止まり、venv の版が `requirements.txt` と違っても止まる。消えた国の `<国>.json` は消すが、ほかのファイルには触らない。`--previous` の既定は出力先の今の `index.json`。**`--report`** を足した（国ごとの年の件数と注意を JSON で。M7B.md の表のため。リポジトリには入れない）。
9. **Web の URL**: `HolidayDataLicense.contributorsURL` は `https://github.com/vacanza/holidays/blob/v0.107/CONTRIBUTORS`（W が同じ版を使う。§5.9）。形は §0 のまま。開くかはネットで確かめていない（公開の前に W かリードが `curl -sI` で見る）。

### 確かめたこと（push・CI は無し）

- `swift build --package-path TegakiKit`・`swift run --package-path TegakiKit KitChecks`: **all 25467 checks passed**（作業の木。H の分は 243 件）。`git archive HEAD` に H のファイルと K の `UILanguage` と生成物だけを重ねた木でも **all 24689 checks passed**（= 24,446 ＋ 243）で、`Holidays`・`HolidayChecks` に警告は無い。N は K2 が取り込みの後に数える（§7.1）。
- `tools/typecheck/typecheck.sh`: all OK・警告 0（作業の木。`HolidaysTests` を含む）。
- `WorldHolidaysTests` はこの Mac に XCTest が無いので、リポジトリの外の小さな XCTest の代わりで **実際に走らせた**: 23 本・2,265 件・失敗 0。CI の `swift test` が本番（`swift test` は CI-0 で初めて走る）。
- `gen.py` を 2 回: `diff -r` が空、`--report` も同じ。作業の木の `HolidayData` も同じ中身。前の `HolidayData` との差は `index.json`（上の 5 か国の `coverage` だけ）と `SOURCE.json`（`gen.py` の sha256 と `index.json` の sha256）だけ。
- `python3 -I tools/l10n/build.py . --check`: 一致。`lint.py` の L-1・L-3 の失敗は S2 以後の分で、`Holidays` のファイルと kit-H のキーは 1 件も出ていない。
- 凍結の 18 ファイル・`InkCanvasViewTests` は触っていない。

### 次の役へ

- **B11**: 作業の木を commit するときの H のファイルは `tools/holidays/` の 6 つ（`gen.py`・`requirements.txt`・`summarize.py`・`iso_regions.swift`・`iso-regions.txt`・`README.md`。`__pycache__` は入れない。`gen` を import したときだけできる。今は無い）・`TegakiKit/HolidayData/`・`TegakiKit/Sources/Holidays/` の 6 つ・`TegakiKit/Sources/KitChecks/HolidayChecks.swift`・`main.swift` の呼び出しの 1 行（K1 と同じファイル）・`TegakiKit/Tests/HolidaysTests/` の 2 つ・`tools/l10n/source/kit-H.json`。
- **K2**: `HolidayGeometryTests` は `holidayDataDirectory()`（`HolidayDataLocation.swift`）と `HolidayStore(directory:)` を使う。中国の出勤日 2024-02-04・2024-05-11、米国 2026-11-23・11-26 は 0.107 でも同じ。作り物の暦「X」「W」は `HolidayCalendar(id:region:source:)` と `HolidaySource` で作れる。
- **U**: `testSummaryTexts` の例は 0.107 では **`HolidayChoice.summary(…, year:)` の `year` を選ぶ**: 「スリランカ（2027 年以降のデータがありません）」は `year: 2027`（`incomplete(until: 2026)`）、「中国（2027 年は発表前の推定）」は `year: 2027`。今年の例なら「台湾（2026 年は発表前の推定）」「ウクライナ（2022 年以降のデータがありません）」。**「自動（コソボ・祝日のデータがありません）」は使えない**: データの無い地域で確かめる（`deviceRegion: "AC"`。名前は「アセンション島」）。`note` の `.incomplete(until:)` の `until` は最後のデータの年なので、文の年は **until + 1**。国の一覧は index の **250**。`hasCountry("XK")` は true。
- **W**: サポートの著作権と CONTRIBUTORS の URL は v0.107。ライセンスの文は `LICENSE-python-holidays.txt` のまま。
- **X**: `kit.holiday.estimatedSuffix`（語の間に空白を置く言語は先頭に空白。en「 (est.)」）と `kit.holiday.dayOff`（en「Day off」、zh-Hans「休息日」）。0.107 では `dayOff` が出る型が無いが、次の版の受け皿なので訳す。
- **C**: README・DESIGN に国の数を書くなら **250**（0.83 の 249 ではない）。`HolidayData` は 254 ファイル・約 4.2 MB（zlib で約 1.6 MB）。
- **リード**: 取り寄せの報告は §5.1 のとおり（上の表）。§5.7 と 0-20 の例の文、§7.1 の「174」、§5.3 の「韓国語の画面」は 0.107 の事実に合わないので、契約を読むときは上のずれの 1・2 を。

### 残る危険

- **作業の木が一時フォルダにある**: 2026-11-05 00:00 ごろ、10-31 に作った 0.83 の venv（`/private/tmp` の下）の `.py` と `pyvenv.cfg` が消えていた（ディレクトリと一部のファイルだけ残る）。古いファイルが消される動きがあるらしい。`wt-m7b` の未 commit の成果と `hol3/venv` も、数日触らないと同じことが起きるかもしれない。**早めに commit すること**（B11 の手順 1）。venv は `~/.local/share/tegaki-python` の wheel からいつでも作り直せる（README）。0.83 の差の比較には、消える前に作ったデータ（`m7b-impl/H/gen/out083`）を使い、`coverage` だけ今の規則で計算し直した。
- データは python-holidays の誤りをそのまま持つ。日本以外の祝日は公開データにもとづく参考の情報（T-9・§6.4）。特に新しく売る EU の国の祝日は本人もリードも目で確かめていない（2026 年の件数と主な国の一覧を見て不自然な物は無かった、という程度）。
- 台湾の「2026 年は発表前の推定」は言い過ぎの可能性がある（上の表）。§8 の 8 の台湾の写真は月のページなので、この文は写らない。

## B11（1.1.1 の取り込みと基準の移し替え。§1.5 の 1 回目）

**基準を移した。** この節より後の「1.1 と同じ」は、仮の `<1.1.1>` と同じを指す（例外は §1.5）。

- **仮の `<1.1.1>`**: `31d243c725f141f60ff62c9ad8d12148d5f7e86d`（`fix-1-1-1` の先頭、リードが渡した。§1.5 の「いつ」の定義の commit。main にはまだ入っていない。1.1.1 の CI と本人の確かめはこれから）。

### 手順 1: 済んだ役の commit（`git add` はファイル名で。push なし）

| commit | 役 | 中身 |
| --- | --- | --- |
| 9c056fd | 契約 | `docs/M7B_CONTRACT.md` の第 4 版 |
| f0c3970 | S0 | `tools/l10n/build.py`（S0 の版）、この文書の S0 の節 |
| 1c30384 | K1 | `Package.swift`・`UILanguage`・`DateText`・`LayoutWords`・`Text11`・`kit-K.json`・`main.swift`・`DATA_1_1.sha256`（e7b4d2f）・生成物（K の元だけ） |
| 81383e8 | S1 | `baseline.py`・`ja-baseline.tsv`（e7b4d2f）・`ja-exceptions.txt`・`lint.py`・`build.py`（S0 ＋ S1）・`L10n.swift`・カタログ 2 つ（0 キー）・生成物 |
| 8db61c2 | C1 | `ja-baseline.yml`・`compare_shots.swift`・`ja-baseline-ref.txt` |
| d00dd86 | LA | 規約類と英語版・`docs/store/`・`docs/support-replies/` |
| 58de668 | H | `tools/holidays/` の 6 つ・`TegakiKit/HolidayData/`（254）・`Holidays` の 6 つ・`HolidayChecks`・`main.swift` の呼び出しの 1 行・`HolidaysTests` の 2 つ・`kit-H.json`・生成物（K と H の元） |

1 つのファイルに 2 つの役が入っている物は、役ごとの中身を別に作って入れた（作業の木のファイルは変えない）: この文書（節ごと）、`build.py`（S0 の版は `m7b-impl/S0/tree` の写し）、`main.swift`（K1 の commit は H の 1 行なし）、生成物（その commit の元と `build.py` で作り直した）。K1 の commit を別のフォルダに取り出して走らせると KitChecks「all 25220 checks passed」（K1 の節の数と同じ）。58de668 の木は commit の前の作業の木と同じ。

### 手順 2: merge（3588793）

**衝突は 0。** `TegakiKit/Sources/KitChecks/main.swift` と `docs/SUPPORT.md` は自動で合わさった。

- `docs/SUPPORT.md`: 1.1.1 の FAQ の 2 か所の直しと「拡大・縮小するには？」、m7b の FAQ の両方が残り、最終更新は m7b の側（2026年11月1日）。契約の決め方どおり。
- `main.swift`: 節の順は「opening zoom and top-aligned paper (1.1.1)」が 1.1 の節の間、1.2 の 3 節と `runHolidayChecks()` は Summary の前。
- `project.yml` は 1.1.1（1）、`build.yml` は 1.1.1 のまま（`git diff 31d243c HEAD` が空）。
- 凍結の 18 ファイルと `InkCanvasViewTests` は 1.1.1 と同じバイト。m7b は 1.1.1 に対して `Tests` を 1 行も消していない（足したのは `HolidaysTests` の 2 ファイルだけ。J-2 の下ごしらえ）。

### 手順 3〜6 の差の結果

| 手順 | 結果 |
| --- | --- |
| 3（D14） | 18 のパスで変わったのは `Ink/InkCanvasView.swift`（+138 −72）と `Ink/InkLedger.swift`（注記の 1 文、+2 −1）**だけ**。InkModel の 7・`SyncEngine`・`InkPageRecord`・`InkPageStore` は同じ。`DATA_1_1.sha256` を 31d243c の git の中身から作り直した（18 行、辞書順、注記なし。変わった行は上の 2 つ）。基準の commit はファイルでなくこの節に書く |
| 3（凍結のテスト） | `InkCanvasViewTests.swift` は 3,057 行 → **3,371 行**（1.1.1 のものを新しい凍結に。契約 §0 の行数の読み替え） |
| 4（K-7） | `git diff --quiet e7b4d2f 31d243c -- TegakiKit/Tests/Fixtures TegakiKit/Tests/Compat10 TegakiKit/Tests/CompatFixtures` は空。`tools/compat10/` の差は `DATA_1_1.sha256` だけ |
| 5（J-3） | **写した関数の本体に差は無い。** 7 つのファイルで差があるのは `PageNavigation.swift`（末尾に `todayRect` を足しただけ。既存の行は動かない）と `MonthLayoutEngine.swift`（`memoHeight` の注記 2 行、行数は同じ）だけ。`Text11.swift` は変えていない。KitChecks の「date text (1.2)」の J-3 も通った |
| 6（J-1） | `ja-baseline.tsv` を 31d243c で作り直した: 515 → **516 行・42 ファイル**。増えたのは見込みどおり `Views/CalendarRootScreen.swift:282`「2 本の指を広げると拡大、つまむと縮小します」の 1 行だけ。消えた字は無い。行が動いたファイルは `Export/PDFPageRenderer.swift`・`Ink/InkCanvasView.swift`・`Support/ScreenshotMode.swift`・`Views/CalendarRootScreen.swift`・`Views/PageHeaderView.swift`。`ja-exceptions.txt` は変えていない（行を持たないので全部当たる） |
| 6（キー） | `kit-K.json` の `composedOf` を 2 つ直した: `Export/PDFPageRenderer.swift:252` → `:256`、`Views/CalendarRootScreen.swift:1172` → `:1222`（どちらも `kit.date.ja.monthName`）。K1 の節の「10」の行番号はこの読み替えで読む。`kit-H.json` は `was` も `composedOf` も無いので変わらない。`lint.py --only L-3,L-4`: K のキーは 47 行に当たって指摘なし、L-4 ok。L-3 の 416 行（前は 415）はまだキーの無い役の分で、増えた 1 行は `toast.pinchHint`（U） |

`baseline.py` は既定の commit（`BASE_COMMIT`）を直し、説明の「1.1」を「1.1.1」に読み替えた。S1 の試験の材料（`cases_s0.py`・`cases_s1.py`・`cases_lint.py`）は全部合格。

### 手順 7: 写真の基準（J-4）

- `tools/l10n/ja-baseline-ref.txt` を 31d243c の 40 字に。成果物の名前は `ja-baseline-31d243c` になる（C1 の節の `ja-baseline-e7b4d2f` はこれに読み替える）。
- `ja-baseline.yml` の写真の手順を 31d243c の `build.yml` に合わせた: offset の 4 か所（`0,1700`・`0,2300`）、pinch-hint の 2 枚（13 インチと iPhone）、段の名前「… + 5 of 1.1 + the hint」、その段のコメント。頭のコメントとジョブの名前も 1.1.1 に。頭のコメントは sha を書かず「`ja-baseline-ref.txt` の commit」と書いたので、手順 8 で直さなくてよい。
- 写真は 53 → **55 枚**（13 インチ 23・iPhone 18・6.9 インチ 5・mini 4・11 インチ 5）。`store/` の 20 枚は同じ。`blank-paper` のジョブは写さない（テストなので。J-4 の比べる相手ではない）。
- `diff_steps.rb`（C1 の材料）で 31d243c の `build.yml` と段ごとに比べて、`run` の差は `$JA_ARGS` と env.txt の行だけ。ほかの 10 段は同じ。写した段の前のコメントも同じ。`check_workflow.rb` は OK（19 段、`run` は全部 `bash -n` が通る）。走らせていない（CI-0 と同じとき）。

### 手順 7b: 古い版で確かめる材料（`tools/weekstart-compat/`）

`m7b-v4/probe-week/` から `common.swift` と `v10/run`・`v11/run` の `Package.swift`・`Sources/Probe/main.swift` を移した。`tools/compat10` は変えていない。段を足すのは C。走らせ方は同じ場所の `README.md`。

この Mac で本物の Kit に対して走らせた: **1.0（a21e469）で 16 件・失敗 0、31d243c で 18 件・失敗 0**（`git archive` で取り出した木の中に `run/` を置く形）。

### 手順 9: 確かめ（merge の後の木。この Mac、Swift 6.4.2、Command Line Tools。push・CI は無し）

| 確かめ | 結果 |
| --- | --- |
| `swift build --package-path TegakiKit` | 成功。新しい警告 0（`main.swift`:2256・2277・2308 の 3 つは e7b4d2f からある、この版の Swift だけの物。ld の search path の警告はこの Mac の Command Line Tools の物） |
| `swift run --package-path TegakiKit KitChecks` の N | **merge の前 25,467 → merge の後 25,950**（= 1.1.1 の 24,929 ＋ これまでの 1.2 の 1,021）。失敗 0。compat10 は 361 件・失敗 0 |
| `tools/typecheck/typecheck.sh`（リポジトリの外の空のフォルダ） | all OK・警告 0。この段階の XCTest は型だけ（走るのは CI-0） |
| `shasum -a 256 -c tools/compat10/DATA_1_1.sha256` | 18 件 OK |
| `python3 -I tools/l10n/baseline.py . --check` | 一致（516 行・42 ファイル・31d243c）。`/usr/bin/python3` で（S1 のずれの 12） |
| `python3 -I tools/l10n/build.py . --check` | 一致 |
| `python3 -I tools/l10n/lint.py . --only L-4,L-10` | ok。L-1 は 463 件、L-3 は 416 件で、どちらも 1.1 のときより 1 件多い（`pinchHintToast`）。全員の移しの後で緑 |

### 契約からのずれ

1. **merge の形**: 契約の `git merge --no-ff --no-edit` でなく `--no-ff --no-commit` の後に `git commit -F`。第 4 版の読み替えの「メッセージは日本語、最後の行は Co-Authored-By」に合わせるため。結果の木は同じ。
2. **`tools/weekstart-compat` の材料を 3 か所変えた**（ほかは同じバイト）: 2 つの `main.swift` の最後に `exit(fails == 0 ? 0 : 1)`（CI の段が終了の状態で判定できるように）、`v11` の最後の行の字を「1.1 real code (e7b4d2f)」から「<1.1.1> real code (tools/l10n/ja-baseline-ref.txt)」に（読む commit が変わったので）。`README.md` を足した。フォルダの名前 `v11` は契約のとおり残した。
3. **commit を 2 つ足した**（merge の後の `tools/weekstart-compat` と、基準の移し替え ＋ この節）。契約は手順 2 の後の commit を書いていないが、S2・U・P がこの上で始めるのと、H の「残る危険」のとおり作業の木が一時フォルダにあるため。

### 次の役へ

- **B11 の 2 回目（手順 8）**: main を merge する。木が 31d243c と同じなら、直すのは `tools/l10n/ja-baseline-ref.txt`・`baseline.py` の `BASE_COMMIT` の 1 行（`baseline.py .` で `ja-baseline.tsv` の頭も）・この文書の commit だけ。`ja-baseline.yml` は直さなくてよい。**ただし `fix-1-1-1` は作り直されることがある**（commit 0 は d0fdbff → 69ac828 になった）。31d243c より前の 1.1.1 の commit が履歴に入っているので、作り直された物を merge すると同じ場所に別の commit が並ぶ。木を `git diff 31d243c main` で見て、違えば手順の 3〜7 をもう一度。
- **U**: `toast.pinchHint` の `was` は `Views/CalendarRootScreen.swift:282`。`Support/ScreenshotMode.swift`（写真モードの 31 の字、`demo.*`）と `Views/PageHeaderView.swift`（15 の字）には行の動いた字があるので、`was` は今の `ja-baseline.tsv` の行で書く。
- **K2**: 1.1.1 の `todayRect`・`ZoomPolicy`・`PaperGrowth` の上で始める。J-3 の `Text11` は変えない。KitChecks の N は 25,950 から数える。
- **LA2**: `docs/SUPPORT.md` の 1.1.1 の 3 か所は入った。`docs/SUPPORT.en.md` はまだ（:70 の「Tap the date in the header」と FAQ「拡大・縮小するには？」の英訳）。`docs/store/review-note.txt` は診断の記録の文を既に持っている（:12。§1.5 のとおり足さない。`R1_1_1.md` §9 は「§7.2 の診断の段落を足す」と書くが、1.2 の原稿には LA が入れた同じ趣旨の文があるので、言い方が 1.1.1 の文と合っているかだけ見る）。
- **C**: `compat-v1.0` の段は `tools/weekstart-compat/README.md` の形（`cp -R` して `swift run --package-path … Probe`、終了の状態で判定）。読む commit は `ja-baseline-ref.txt`。`build.yml` の閾値は今 24,879（1.1.1 の 24,929 − 50）で、1.2 は最後に数え直す。`build.yml` の写真の段に `$JA_ARGS` を入れた後の確かめは、今の `ja-baseline.yml` と `diff_steps.rb` で。
- **リード**: J-2 の比べる相手は今 31d243c。今の差は足しただけ（消した行 0）。

### 残る危険

- 31d243c は仮の物で、1.1.1 の CI も本人の確かめもまだ。直しが入れば手順 8 で 3〜7 をやり直す。
- この Mac では XCTest は型だけ。1.1.1 と 1.2 の分を合わせた `swift test` とアプリのテストは CI-0 で初めて走る。
- `ja-baseline.yml` の変更は `bash -n` と段ごとの比べまで。実際の写真は CI-0 で初めて撮る。

## K2（K1+・K の後半・週の始まりの Kit の全部。§12.1 の K2）

**実数 N = 29,432**（`swift run --package-path TegakiKit KitChecks`「all 29432 checks passed」。B11 の後の 25,950 から +3,482。閾値は C が最後に数え直して N − 50。今の数なら 29,382）。commit はしていない（K2 は commit しない役）。

| 節 | 件数 | 内訳 |
| --- | --- | --- |
| 1.1.1 まで | 24,929 | B11 の節のまま |
| `languages (1.2)` | 113 | K1 のまま |
| `kit strings (1.2)` | 583 | K1 の確かめ（キーの数で動く。K2 で 61 キーに）＋ ずれの 8 の「各言語の字はキーから」 |
| `date text (1.2)` | 708 | K1 の 435 ＋ J-3 に足した `language: .ja`・`weekStart: .monday` の呼び出しと、ja だけの `plainDay` |
| `holidays (1.2)` | 243 | H のまま |
| `holiday geometry (1.2)` | 2,159 | G-1 1,293（431 ページ × 3 つの暦）、G-2 431 ＋ 字が届く確かめ、G-3 390、G-4 ＋ 本物のデータ（米国の週・中国の出勤日）。§7.1 の見込み +1,900〜2,200 の中 |
| `week start (1.2)` | 697 | 型、W-1〜W-5、G-5。W-1・W-3 は関数ごと・10 年ごとに 1 件（試しの 504,367 件をそのまま数えない） |

### 入れたもの

- **K1+**: `DateText.weekTitle(first:…)`（KitChecks の呼び出しも）。`DateText` の注記（曜日の並びは `WeekStart.order` から、`firstWeekday` を読まない）。`kit-K.json` の `kit.date.ja.weekTitle` の comment と `weekTitle*` の 3 つの `args`（値は変えていない）。
- **§5.4 の 12 か所と tone**: 全部 `holidays` から。`LayoutMath.tone(of:holiday:workday:)`（既定値なし）を 5 か所が渡す。月のエンジンのその場の式は消した。`MonthLayoutInput`・`WeekLayoutInput`・`DayLayoutInput`・`YearLayoutInput` に `holidays:`・`words:`（既定 `.japan`・`.japanese`）。`words` はチップの「+n件」・日をまたぐ印・箱の時刻の範囲に効く。`Layout` の中に `JapaneseHolidays` の呼び出しは残っていない。
- **`PageNavigation`**: `title(_:focus:holidays:language:weekStart:)`・`compactTitle(_:focus:language:weekStart:)` は `DateText` で組む。`pageId`・`dayRange` に `weekStart:`。`parse`・`move`・`initialScroll*` は変えていない。
- **`PlanText`**: §0 の全部（`name`・`perPeriod`・`savingsText`・`statusTitle`・`dateLabel`・`readOnlyNote` に `language:`、`yearlyBadge(language:)`・`readOnlyBadgeText(language:)`・`cancelPath(language:)`・`paymentPath(language:)`。今の `static let` は残した）。字は全部 `KitStrings` から。
- **`LegalLinks`**: `englishPagesPublished = false`、`terms(for:published:)`・`privacy(for:published:)`・`support(for:published:)`・`appleEULATitle(_:)`。ja は published でも日本語のページ。`Access/Plan.swift:2` の注記も直した（K1 の申し送り）。M7B-23 の答えは (ア) なので `LegalLinks` には関係しない。
- **`StrokeBudget`**: `pageLabel(_:)` と `pageLabel(_:language:)` の 2 つの形（週の形は日付から読む）、`countText(_:language:)`。**`AppExport`**: `jsonFileName(exportedAt:calendar:language:)`・`pdfFileName(kind:focus:holidays:language:weekStart:)`・`kindLabel(_:language:)`。データの関数は 1 行も変えていない。InkModel の凍結 7 ファイルは同じバイト。
- **`kit-K.json`**: 21 → **61 キー**。X が訳すのは K の分で 42（`kit.plan.*` 27、`kit.budget.*` 6、`kit.export.*` 5、`kit.legal.appleEULATitle`、K1 の 3）。`jaOnly` は `kit.date.ja.plainDay` を足して 10。`build.py` で生成済み。Kit の日本語の文字列は L-1 で 0 件、Kit の行は L-3 で全部キーか例外に当たる（K のキーが引き受けた行は全部で 85）。
- **§10.1**: `DayKit/WeekStart.swift`（`firstWeekday`・`order`・`column(of:)`・`firstDay(of:)`・`init?(weekPageDate:)`・`automatic(region:firstDayOfWeek:)`）、`InkModel/WeekStartImpact.swift`（`hiddenStrokeIds(in:weekStart:)`・`weekPages(_:)`）。`MonthLayout.firstGridDay`・`rowCount`・`grid`（2 つ）・`MonthLayoutInput`・`WeekLayoutInput`（項目 `monday` は `firstDay` に）に最後の引数 `weekStart: WeekStart = .monday`。`AllDayBandEngine.week(firstDay:weekStart:events:now:calendar:holidays:)` を本体にし、`week(monday:…)` は `.monday` で呼ぶだけ。「Monday」の注記（`MonthLayout`・`MonthPageLayout`・`AllDayBand`・`WeekLayoutEngine`・`PageLayout`・`DayKey`）。
- **KitChecks**: J-3 に新しい呼び出し、§7.1 の G-1〜G-4（「X」「W」「40 字」の作り物の暦 `MadeUpHolidays`）、§10.8 の W-1〜W-5・G-5。
- **XCTest**: 新規 `DateTextTests`・`KitStringsTests`・`LayoutWordsTests`・`WeekStartLayoutTests`（LayoutTests）、`HolidayGeometryTests`（HolidaysTests）、`LegalLinksTests`（AccessTests）、`WeekStartImpactTests`（InkModelTests）、`Compat12Tests`（新しいターゲット。`Package.swift` に 1 行）。足すだけ: `PageNavigationTests.testTitlesInEnglish`、`PlanTextTests.testPlanTextInEnglish`・`testEuroSavings`、`StrokeBudgetTests.testCountTextInGerman`、`AppExportTests.testPdfFileNameInEnglish`。

### 契約からのずれ・契約が黙っている所の決め方

1. **`DateText.plainDay(_:_:region:)` と `kit.date.ja.plainDay` を足した**（§0 に無い public）。1.1 の日のページの呼び方「日のページ（2026年10月7日）」は曜日が無く、`dayTitle`・`shortDay` では作れない。他の言語は雛形 `yMMMMd`（en_US「October 7, 2026」）。
2. **`testHolidayInTheDayTitle` は `PageNavigationTests` でなく `HolidayGeometryTests`（HolidaysTests）に置いた**。LayoutTests の依存は `Layout` だけで（§0 の「`Package.swift` をこれ以上変えない」）、`HolidayCalendar` を名前で使えず、米国のデータの場所の関数も HolidaysTests にある。
3. **§7.2 の英語の日付の字は、地域を渡せない関数では字のまま比べない**: `PageNavigation.title(…language: .en)` の形は端末の地域に従う（契約の形に `region:` が無い。en_JP なら「Thu, 26 November 2026」）。CI の地域に左右されないよう、`testTitlesInEnglish`・`testHolidayInTheDayTitle`・`testPdfFileNameInEnglish` は `DateText` の結果と比べ、契約の「Thu, November 26, 2026 Thanksgiving Day」は `region: "US"` を渡した `dayTitle` ＋ 祝日名で確かめる。
4. **W-4 の `WebImportV10`**: 凍結の写しの `WebImportV10` は `ParseError` だけで、Web の形式を読む処理が無い（`PageId` も `convert` も無い）。写しでは「Web のファイルは `.notAnExport`」だけを確かめ、「Web の形式の日曜 `w-` を断る」は新しいコードの `WebImport`（W-5）と、本物の 1.0 の `tools/weekstart-compat`（A9）で確かめる。
5. **StrokeBudget の中の `PageNavigation.title` は `holidays: .none` を渡す**（年・月・週の題名に祝日は出ないので意味は同じ。L-7 の Kit の規則が `holidays:` を求めるため）。
6. **`kit-K.json` の引き受け方**: `kit.app.name` に `composedOf` `InkModel/AppExport.swift:144` を足した（ファイル名の空白はコードで置く）。`kit.budget.count.*` は「 本」の行（字が空白つき）を `composedOf` で引き受ける。`kit.plan.badge.readOnly`・`cancelPath`・`paymentPath`・`kit.legal.appleEULATitle` の `was` は例外の行でもある（1.1 の `static let` を残すため。L-3 はどちらでも通る）。
7. **`LayoutWords.fill` を消した**: K1 の申し送りのとおり、S1 で public になった `KitStrings.fill` に寄せた（KitChecks の `layout words` が同じ規則を確かめている）。
8. **KitChecks に足した節の外の確かめ**: `kit strings (1.2)` の末尾に、10 言語で「`PlanText`・`StrokeBudget`・`AppExport`・題名の字がキーと `DateText` から来る」「`LegalLinks` の URL」を置いた。X の前でも通る形（字そのものは見ない）で、件数は X の後も変わらない。
9. **G-3 の日のページは 12 日**（各月の 1 日）。月 12・週 53・年 1 は全部。5 つの暦 × 365 日は増やしても見つかるものが増えない（`calendar` を読む道は同じ）。
10. **`WeekStartImpact.hiddenStrokeIds` は id の順に並べて返す**（§10.1 は順を書いていない。テストとトーストで安定するように）。

### 確かめたこと（この Mac、Swift 6.4.2、Command Line Tools。push・CI は無し）

| 確かめ | 結果 |
| --- | --- |
| `swift build --package-path TegakiKit` | 成功。新しい警告 0（`main.swift` の「no calls to throwing functions」の 3 つは e7b4d2f からある、この版の Swift だけの物） |
| `swift run --package-path TegakiKit KitChecks` | **all 29432 checks passed**。compat10 は 361 件・失敗 0。debug で約 48 秒（前は 37 秒） |
| `tools/typecheck/typecheck.sh`（リポジトリの外の空のフォルダ） | all OK・警告 0（アプリ 60 ファイル、TegakiCalendarTests 26、UI テスト 4、Kit のテスト 6 つ。`Compat12Tests` を含む） |
| XCTest を**実際に走らせた**（この Mac に XCTest が無いので、リポジトリの外の小さな代わり `m7b-impl/K2/xctrun` で。木を写して `LayoutTests`・`HolidaysTests`・`InkModelTests`・`AccessTests`・`Compat10Tests`・`Compat12Tests` の全部を組み、テストの関数を順に呼ぶ） | 翻訳なし: 343 本・失敗は**下の 5 本だけ**（X の訳が要る）。写しの中に仮の訳（en・de と、残りは en の写し）を入れると 320 本（`Compat10Tests` の 23 本を除く）・65,737 件・**失敗 0**。`Compat10Tests` は翻訳なしで 23 本・失敗 0。本番は CI-0 の `swift test` |
| `shasum -a 256 -c tools/compat10/DATA_1_1.sha256` | 18 件 OK（D14） |
| K-7 | `Tests/Fixtures`・`Tests/Compat10`・`Tests/CompatFixtures`・`Tests/Compat10Tests`・`tools/compat10` は HEAD と同じ。`testFixturesAreWhatTheNewCodeWrites` は作り直さずに通った |
| J-2 | `git diff 31d243c -- Tests TegakiKit/Tests` の削除行 **0**（足しただけ。§10.8 の 2） |
| `Text11.swift` | HEAD と同じ（J-3 の基準は変えていない） |
| `python3 -I tools/l10n/build.py . --check`・`baseline.py . --check` | 一致（516 行・31d243c） |
| `lint.py --only L-1,L-3,L-4,L-10` | Kit の行の指摘 0、L-4・L-10 ok。L-1・L-3 の失敗（417・382）はアプリの、まだキーの無い役の分 |
| L-7 の Kit の規則 | lint にはまだ無いので（S2）、同じ規則の小さな script で見た: `Layout`・`InkModel` の呼び出し 8 か所に漏れなし |

**X の訳が入るまで落ちるテスト**（CI-0 は X の後なので問題にならない。訳の字を決めているので X は下の「次の役へ」を見る）: `KitStringsTests.testEveryKeyHasTenLanguages`、`LayoutWordsTests.testMoreChipsPerLanguage`、`PlanTextTests.testPlanTextInEnglish`、`StrokeBudgetTests.testCountTextInGerman`、`AppExportTests.testPdfFileNameInEnglish`。

### 次の役へ

- **X**: K のキーで訳すのは 42（`fixed`・`jaOnly` を除く）。テストが字を見ているので次は崩さない: `kit.plan.monthly`・`yearly`「Monthly」「Yearly」（§6.2）、`kit.plan.perPeriod.*`「/month」「/year」、`kit.plan.savings.*`「Save %@ month」「Save %@ months」、`kit.layout.more.*` の en「+%@ more」・de「+%@ weitere」、`kit.budget.count.*` の en「%@ stroke」「%@ strokes」・de「%@ Strich」「%@ Striche」、`kit.export.kind.*` の en「Month」「Week」「Day」「Year」（§6.2）、`kit.app.name` の en「Tegaki」、`kit.export.jsonFileName` の en は「Tegaki 」で始まり「 %@.json」で終わる、`kit.budget.page.*` の en は「Year page」などの語を含む（§6.2）。`kit.plan.cancelPath`・`paymentPath` は §6.1 の 4。ja 以外の値に漢字・かなを入れない（L-2）。
- **S2**: `ExportBuilder` は `title(…holidays:language:weekStart:)`・`pdfFileName(kind:focus:holidays:language:weekStart:)`・`jsonFileName(exportedAt:calendar:language:)`。`StrokeCensus.pageLabel(_:language:)` は `StrokeBudget.pageLabel(_:language:)` と `countText(_:language:)` を呼ぶ。`EventDateText` の「〜」は `LayoutWords.of(language).range(_:_:)`。**L-8**: Kit の `KitStrings.plural("kit.plan.savings", …)`・`("kit.budget.count", …)`・`("kit.layout.more", …)` は `.one`・`.other` を付けない形で呼んでいる。`kit.plan.status.*`・`kit.plan.note.*`・`kit.plan.date.*`・`kit.export.kind.*` はみな文字列の直書きで引いている（`KitStrings.text("kit.…", language)`）。**L-7 の Kit の規則**: 上の 8 か所は今通る。`Views/ExportSheet.swift:49` の `AppExport.kindLabel(kind)` は S2 の C 型のまま。
- **U**: `MonthLayoutInput`・`WeekLayoutInput` の引数の順は `calendar:, holidays:, words:, weekStart:`、`DayLayoutInput`・`YearLayoutInput` は `calendar:, holidays:, words:`。`PageNavigation.pageId`・`dayRange`・`title`・`compactTitle`・`MonthLayout.grid` の `weekStart:` は最後。`LegalLinks.terms(for: L.language)` など（`published:` は渡さない）。`WeekStart.automatic(region:firstDayOfWeek:)`、`WeekStartImpact.weekPages(_:)`（`(monday:, sunday:)`）。`large.map(StrokeBudget.pageLabel)` は `{ StrokeBudget.pageLabel($0, language: L.language) }` に（§2.7）。
- **P**: 並びは `layout.rows[0].days`（月）・`layout.days`（週）から読む（レイアウトに `weekStart` の項目は足していない、§10.1）。曜日は `DateText.weekdays(_:_:)` を `WeekStart.order` で並べる。年の `DateLabel.holidayName` は `short`、ほかは `full`（§5.4 の表の 6）。`TimedChip.title` には `words.more(_)` の字が入る。`Paper/MonthPaper.swift:189` の「+\(n)件」は `title` が空のときの受け皿で、行の引き受けは K1 の節の 11 のまま（P が自分のキーか `composedOf` で）。
- **C**: 閾値は最後に数え直す（今は N = 29,432）。`Compat12Tests` は `swift test` で自動で走る。KitChecks は debug で約 48 秒。`build.yml` の数の説明の行に、1.2 の節の内訳（上の表）を書ける。
- **リード**: J-2 の相手は今 31d243c で、K2 の分のテストは足しただけ。

### 残る危険

- XCTest は CI-0 まで本物で走らない。この Mac の代わりは `XCTAssert*` の意味だけを写した物で、`testEnglishSamples` などの ICU の字（en_US・es_ES・fr_FR）はこの Mac の ICU の値（K1 の「残る危険」と同じ。CI の macos-26 で字が違えば、KitChecks と同じく構造の確かめに替える）。
- `HolidayCalendar.japan` の `name(of:)` は 1.1 の `JapaneseHolidays.name(of:)` と同じく呼ぶたびに年の表を作る（橋の分だけ少し重い）。題名は 1 回に 1 度で問題にならない見込み（KitChecks の J-3 は 36,525 日 × 複数でも全体で約 10 秒増えただけ）。
- 祝日の暦を読む時間（§5.3 の `l10n: holidays loaded`）は U の接続の後に CI で測る。年のページは 365 回 `isWorkday` を呼ぶ（中で lock と辞書を引くだけ）。

## LA2-EU（§12.1 の LA2 のうち EU の分。docs だけ。英語版も同じまとまり）

週の始まりの文と 1.1.1 の文は触っていない（LA2 の残り）。commit・push はしていない（C）。

### 入れたもの

- **規約類（§11.3）**: `docs/TERMS.md`・`TERMS.en.md` に T-1〜T-9（T-4b、英語だけの T-8 を含む）、`docs/PRIVACY.md`・`PRIVACY.en.md` に P-1〜P-4（第 12 節・第 13 節を第 11 節の後に）、`docs/SUPPORT.md`・`SUPPORT.en.md` に S-1〜S-6（S-5 の `XX`・`Month DD` は残した）。文は契約の §11.3 から script で取り出して入れた（打ち直していない。`m7b-impl/LA2-EU/apply_legal.py`）。
- **ストア**: `docs/store/locales.json`（es-ES・pt-PT を足して ja のほかに 15。fr-FR・de-DE・it・en-GB の店頭を §6.6 の表に。上げる写真の組 `shots`）。`docs/store/README.md`（EU を入れる順の 1 段落、15 ロケール、価格の決まりの足し、審査メモに EU の文を足さないこと、新しい「写真」の節（11 組と 15 ロケールの対応）、「X への手引き」の店頭の書き方を de・fr・it・es・pt の読み手に）。「EU では売らない」と、ドイツ語についてのスイスの書き方の指示はやめた。es-ES・pt-PT のフォルダの中身は X が書く。
- **定型文**: `docs/support-replies/refund.md`（EU の段落とドイツの 1 文と逆翻訳）、新しい `privacy-request.md`（中身と本人の手順）、`README.md`（一覧を 7 つに、流れの 7）。

### 契約からのずれ・契約が黙っている所の決め方

1. **最終更新**: 6 文書とも 2026年11月5日・November 5, 2026 にした（LA の 5「公開の前に文を直したら、その日に直す」、§1.5「W・LA2 が決める」）。公開の日にリードが公開の日付に入れ直す（§11.1 の順 5）。LA2 の残りで文を直したら、その日にまた直す。
2. **T-4b の英語の句点**: 案文の括弧は文で終わる（“…those apply.)”）ので、「.).」にならないよう、括弧の後の「.」を落とした。日本語は「（…従います）。」のまま。
3. **P-3 の日本語の URL だけ `<…>` で囲んだ**（字は案文のまま）。裸の URL だと GitHub の表示でリンクが「）をご覧ください。」まで伸びる。文書のほかの URL と同じ書き方。英語の P-3 と S-4 は伸びないので案文のまま。
4. **S-5 は「足す」でなく「置き換え」**: 「現在、重要なお知らせはありません。」のまま足すと同じ節で食い違うので、今の 1 行を S-5 の行に置き換えた（英語も）。Web の ② は今の 1 行のまま（§6.5）で、**公開の日にリードがその 1 行を置き換える**。
5. **T-8 の場所**: 冒頭の文と同じ行に続けた。`TERMS.en.md` だけ（§11.3 の利用規約の表の行なので、PRIVACY.en・SUPPORT.en には足さない）。
6. **`locales.json` に足した項目**: `shots`（§7.5 の組）、es-ES・pt-PT の `writerNote`。`language` は画面の言語と読み、pt-PT は `pt-BR`、es-ES は `es` にした（`about` に書いた）。ja は組に入らないので `shots` なし。L-9 が見ない項目なので lint には響かない。
7. **pt-PT の説明の 1 文の元**: 契約は「説明に正直に書く」だけなので、日本語の元を README の手引きに書いた（言語の点のすぐ後に「・アプリの画面のポルトガル語は、ブラジルのポルトガル語です。」）。`source-ja/description.txt` は pt-PT 以外に要らないので変えていない。新機能の文の言語の点も「ポルトガル語（ブラジル）」と手引きに書いた（契約は説明だけ。更新のときに読まれる文なので合わせた）。
8. **手引きに足した注意**: iOS の画面の名前は同じ言語でも国で違う（「設定」が pt-BR の Ajustes と pt-PT の Definições、es-ES の Ajustes と中南米の Configuración）。**この語は Apple の記事で確かめていない**（覚えている語。X が §6.1 の 4 で確かめる）。pt-PT の文でも、アプリの中の画面の名前はアプリの pt-BR の語のまま書く（そう表示されるため）。
9. **`privacy-request.md` で契約に足した所**: 誰から来ても同じに答える（EU に限らない）／依頼が同じアドレスから来ているかを見る（別の人に渡さないため）／メモに相手の名前やアドレスを書いていないかを見る／今回の依頼のメールと返事は送った後で消す（返事に「送った後で消す」と書く。「消せたものだけ消したと書く」と両立させるため）／Claude Code で渡した本文はこの Mac の記録にも残る／Google と Anthropic の側の写しは「しばらく持っていることがある」（期間は確かめていないので書かない）／第 13 節のほかの権利の答え方／消すのは本人。URL は `app/en/privacy.html`（この定型文を使うのは 1.2 の公開の後）。
10. **`support-replies/README.md`**: 「公開していない情報は書かない」を「電話番号・住所は書かない（EU の App Store のページには出るが、返事には書かない）」にした（EU に出すと「公開していない」では守れないため）。流れに 7（解決したら本人が消す。§6.7、§12.4 の (11)）を足した。

### 本人の手順（§6.7・§11.3）

`docs/support-replies/README.md` の流れの 7 と、`docs/support-replies/privacy-request.md` の「本人の手順」。**届いた日から 1 か月以内に答える。** メールを消すのも送るのも本人。

### 確かめたこと（コードは変えていないので swift build・KitChecks・typecheck は走らせていない）

| 確かめ | 結果 |
| --- | --- |
| §11.3 の文（`m7b-impl/LA2-EU/check_eu.py`。契約から取り出して字で照らす。結果は同じ場所の `check_eu.out`） | T-1〜T-9・P-1〜P-4・S-1〜S-6 の日本語と英語が各 1 回だけある。置き場所（第 9 条 7 項・第 12 条 5 項・返金の行の後・第 11 節の後・「解約するには？」の後）と古い文が無いことも見た。問題 0 |
| §11.8 の 1 の grep（`EU には配信`・`not distributed in the EU`。PRIVACY も足して） | 0 件 |
| §6.4 | `grep -c '「設定」›「Apple Account」›「サブスクリプション」' docs/TERMS.md` は編集の前後とも 1。価格・試用・解約の経路・連絡先・氏名など 33 の字の数を前後で比べ、変わったのは `SUPPORT.en.md` の “14 days”（0 → 1）だけ（S-4 の撤回の期間で、試用の字ではない）。日本語の「14 日間」は変わらず |
| リンクと見出しの id | 6 文書の内側のリンクと id が全部ある。`.en.md` のリンクの外に `TODO`・`DRAFT`・`【`・`[` が無い。【 と「下書き」は 6 文書に無い。見出しの数は TERMS 14/14、PRIVACY 15/15 |
| `XX`・`Month DD` | S-5 の行だけ |
| Apple の規約の URL（`curl -sL` で読むだけ。2026-11-05） | `…/itunes/ie/terms.html` に `Right of withdrawal`・`Withdraw Transaction`・`Choose your country/region`、14 日と初回だけの文がある（§11.9 と同じ。版は September 14, 2026）。国を選ばない URL はどの文書にも書いていない |
| 定型文 | 7 つで README の一覧と一致。`refund.md` の EU の段落とドイツの 1 文は契約の英文と字で一致。7 つとも機械翻訳の 1 文がある |
| `locales.json` | JSON として読める。ja ＋ 15 の順。15 ロケールが 11 組に対応（§7.5 と同じ） |
| 審査メモ | 変えていない（3,884 バイト、改行を除くと 3,883）。EU の文なし |
| `m7b-impl/LA/check_store.py`（LA の確かめ） | `ja/whatsnew.txt` が §6.3 と違うとだけ出る（契約の第 4 版で週の始まりの点が足されたため。LA2 の残りの分）。ほかは問題なし |

**X も R もまだなので、es-ES・pt-PT の文の確かめは無い**（L-9 はフォルダのあるロケールを見る。L-9 自体もまだ S2 の分）。

### 次の役へ

- **LA2 の残り**: `docs/SUPPORT.en.md` の `Tap the date in the header`（FAQ “Events do not appear” の 4）と FAQ「拡大・縮小するには？」の英訳（SUPPORT の `###` が ja 20・en 19 なのはこの 1 つの差）、§10.4 の文、§6.3 の新機能の文（`ja/whatsnew.txt` は今 §6.3 と違う）、README の「4 つの点」と審査メモの節の「週は月曜始まり」、SUPPORT の言語の FAQ の括弧。文を直したら最終更新の日も。
- **X**: `docs/store/README.md` の「X への手引き」（10 のロケール）と「写真」。`locales.json` の `writerNote`。GLOSSARY に店頭の注（§6.1 の 9）。
- **R**: `docs/i18n/back/legal-en.md` の対象に §11.3 の英文が入った。S-5 の “Month DD, 2026” は公開の日に埋める字。
- **W**: 上の 4（S-5 は Web に入れない）。写すときの字の差は 3 のとおり URL をリンクにするだけ。変わる見出しの id: PRIVACY の日本語 `1-アプリが集める情報ありません`・`6-アプリのデータの第三者への提供ありません`、英語 `1-information-the-app-collects-none`・`6-sharing-the-apps-data-with-third-parties-none`。新しい id: 日本語 `12-問い合わせのメールとこのページを開いたとき`・`13-eu欧州連合アイスランドノルウェー英国スイスにお住まいの方へ`・`eu-で購入を取り消すには`、英語 `12-emails-to-support-and-opening-these-pages`・`13-if-you-live-in-the-eu-european-union-iceland-norway-the-uk-or-switzerland`・`how-do-i-cancel-a-purchase-in-the-eu`。S-3 の「下の「EU で購入を取り消すには？」」は案文ではただの字（リンクにするかは W が決めてよい）。
- **S2**: L-9 は `locales.json` の `shots`・`writerNote` を読まなくてよい。
- **リード**: 公開の日の S-5 は「今の 1 行を置き換える」（上の 4）。最終更新の日付も（上の 1）。公開の直前に Apple の URL をもう一度（§6.5）。下の「残る危険」の最初の 2 つは、公開の直前の確認で本人に見せる。
- **C**: LA の節の 7（第 3 条 4 項）は T-9 で直ったので整えるときに読み替える。commit のファイル名: `docs/TERMS.md`・`docs/TERMS.en.md`・`docs/PRIVACY.md`・`docs/PRIVACY.en.md`・`docs/SUPPORT.md`・`docs/SUPPORT.en.md`・`docs/store/README.md`・`docs/store/locales.json`・`docs/support-replies/README.md`・`docs/support-replies/refund.md`・`docs/support-replies/privacy-request.md`（と `docs/M7B.md` のこの節）。

### 残る危険

- **SUPPORT の窓口の節の 1 文**（`docs/SUPPORT.md`「送っていただいても、こちらで預かることはせず、確認後に削除します。」、英語も同じ）は、手書きや予定の中身を送られたときの文で、第 12 節（メールは必要な間だけ保存）と直接には矛盾しないと読んで変えていない。ただし、その本文も Claude を通りうる。契約の外の文なので、直すなら本人に聞いてから。
- **消す約束は本人の作業**: 第 12 節に「必要がなくなったら消します」と書くと、消す手間が公の約束になる（§12.4 の (11)）。忘れると文と事実が食い違う。
- 規約類と `privacy-request.md` は法律の専門家に見てもらっていない（§11.6、M7B-24 の答えのとおり 1.2 の後に 1 回聞く）。Google と Anthropic の側の保存の期間も確かめていない。
- `refund.md` のドイツの 1 文は、手続きが確かめられないので Apple のサポートに案内するだけ（§11.9）。

## LA2-rest（§12.1 の LA2 の残り: 週の始まりの文と 1.1.1 の文。docs だけ。英語版も同じまとまり）

commit・push はしていない（C）。.html は書いていない。契約の文は `m7b-impl/LA2-rest/apply_docs.py` で契約から取り出して入れた（打ち直していない）。

### 入れたもの

- **週の始まり（§10.4・§6.3）**: `docs/store/ja/whatsnew.txt`（§6.3 の 5 つの点そのまま）、`source-ja/whatsnew.txt`・`source-ja/whatsnew.en-US.txt`・`en-US/whatsnew.txt`、`source-ja/description.txt`・`en-US/description.txt`、`review-note.txt`、`docs/SUPPORT.md`・`SUPPORT.en.md` の括弧と FAQ、`docs/store/README.md`（5 つの点、ja の説明の 1 行の案、審査メモの節、英語の画面の名前の 2 行）。
- **1.1.1（§1.5、§6.4）**: `docs/SUPPORT.en.md` の “Tap the date in the header”、FAQ “How do I zoom in and out?”（「ツールバーをしまうには？」の後。日本語と同じ場所）、FAQ “How much can I write on one page?” のメモ欄の文。

### 契約からのずれ・契約が黙っている所の決め方

1. **1.1.1 の英訳は 3 か所直した**: §1.5 の LA2 の行は 2 つだけ書いているが、§6.4 は「英語版に同じ直し」で、`R1_1_1.md` §7.3 の直しは 3 か所。3 つ目の「最初から下まで開いています」を訳さないと、英語だけが 1.1.1 と違う動き（“continue with blank paper below as you write further down”）を説明し続けるので直した。
2. **「（日本は月曜）」は ja だけ**: `source-ja/whatsnew*.txt` と `en-US/whatsnew.txt` から落とした。ほかの店頭で読む人には当てはまらず、§10.4 の設定の脚注の英語にも無い（LA の 17 と同じ読み替え。README にも書いた）。R の照合では「意図した違い」。
3. **契約に英語が無い文は LA2 が書いた**（R の逆翻訳の対象）: `en-US/whatsnew.txt` の 2 つの点、`en-US/description.txt` の 1 行（§10.4 の審査メモの英文に合わせた）、`SUPPORT.en.md` の括弧 “(you can choose the week start in the App's settings)”、FAQ の “How do I zoom in and out?”。§10.10 の grep に当たらないよう、英語は “weeks start on Monday” の形を使っていない。
4. **週の始まりの FAQ の場所**: 契約は場所を決めていない。FAQ の最後（「祝日の国を変えるには？」の後）に置いた。LA が 1.2 の FAQ を最後に足したのと同じ。W も同じ場所に。
5. **審査メモの形**: §10.4 の英文は、元の “By design…” の行の場所に 1 字も変えずに入れた。“What is new” の 1 項目は “3. Week start:” として、既定と、週のページを別々に保存すること、切り替えても消えないことを書いた（審査の人が手書きの消えた不具合と取らないように）。元の行の「手書きが紙の決まった位置に結び付いているから」は、週の始まりを選べるので消した。
6. **審査メモの 4,000 バイト**: 足すだけだと 4,000 バイトを超える見込みだったので（概算で約 4,200）、次で詰めた（結果は 3,942 バイト。ファイルは改行を入れて 3,943）。(a) 日本語の要約を短くした（600 バイト台。1 字 3 バイトでいちばん高い。落としたのは「設定」アプリの項目・設定の道・購入画面と規約の場所で、英語の本文には残る。週の始まりの 1 文を足した）。(b) “users updating from 1.1” を “existing users” に、“the same products and prices as 1.1” を “Subscriptions and prices are unchanged” に（1.1.1 が先に出るので、版の番号を書かない方が正しい）。
7. **診断の記録の文を 1.1.1 と合わせた**（§1.5「足さない」のとおり段落は足していない）: 1.1.1 の審査メモ（`R1_1_1.md` §7.2）と比べると、1.2 の文の “it holds only …” の一覧に **アプリと OS の版・機種名が抜けていた**（`InkTrace.text` の頭の行に実際に入る）。「only」と書いて本人の名で Apple に出す文なので足した。1.1.1 の “nothing is sent automatically” も足した。1.1.1 の “never … which page” と 1.2 の “page types” は食い違わない（入るのは `A:<page kind>` の種類だけで、ページの id と日付は入らない）。**§6.6 の日本語の説明（「道具・ページの種類・本数・触れ方の種類と時刻だけ」）にも同じ抜けがある**（契約は直していない。リードの読み替え）。“EU excluded” の文は審査メモに無い。
8. **最終更新**: SUPPORT の 2 文書は既に 2026年11月5日 で、直した日も同じなのでそのまま。TERMS・PRIVACY は変えていない。公開の日にリードが入れ直す（§11.1 の順 5）。

### 確かめたこと（コードは変えていないので swift build・KitChecks・typecheck は走らせていない）

| 確かめ | 結果 |
| --- | --- |
| `m7b-impl/LA/check_store.py`（A の測り方。結果は `m7b-impl/LA2-rest/check_store.out`） | 問題なし。審査メモ 3,500 字・3,942 バイト（上限 4,000）。`ja/whatsnew.txt` が §6.3 と 1 字も違わない（709 字）。`en-US` の説明 2,587 字・新機能の文 2,189 字 |
| `m7b-impl/LA2-rest/check_rest.py`（契約から取り出して字で照らす。結果は同じ場所の `check_rest.out`） | §10.4 の説明・審査メモの英文・括弧・FAQ の日本語と英語が各 1 回、§6.3 の週の始まりの点、5 つの点、1.1.1 の 3 か所（古い文 0 件）、FAQ の数が ja 21・en 21 で並びも同じ、内側のリンク。問題 0 |
| §10.10 の 3 の grep（`docs/store`・`docs/SUPPORT*.md`） | 0 件（grep の終了の状態 1）。例外なし |
| §6.4 | TERMS・PRIVACY は変えていない。`SUPPORT` の価格・試用・解約の経路・連絡先などの 14 の字の数は LA2-EU の前の写しと同じ（違うのは LA2-EU の S-4 の “14 days” だけ） |
| `m7b-impl/LA2-EU/check_eu.py`（戻りの確かめ） | 問題なし（§11.3 の文はそのまま） |
| `SUPPORT.en.md` の禁止の字 | リンクの外に `TODO`・`DRAFT`・`【`・`[` なし。`Month DD` は S-5 の行だけ |

**確かめていないこと**: 英語の文の読み手の確認（R がこれから）。L-9 はまだ S2 の分なので、A の測り方だけ。

### 次の役へ

- **X**: `source-ja/whatsnew.txt` の 4・5 つ目の点と `source-ja/description.txt` の週の始まりの行が新しい元。画面の名前「週の始まり」はアプリの `settings.weekStart.title` の訳と同じ語に。README の「英語の画面の名前」に Week Starts On・Today を足した。審査メモの余裕は 58 バイトなので、英語の画面の名前を審査メモで直して長くなるときは測る。
- **R**: `legal-en.md` の対象に SUPPORT.en の FAQ 2 つと直した 2 文が入った。`store-en-US.md` の対象に新機能の文の 2 点・説明の 1 行・審査メモの項目 3 と診断の記録の文。意図した違いは上の 2。`toast.pinchHint` と同じく、FAQ の “Spread … zoom in / pinch … zoom out” の向きも見る。
- **W**: 英語の 3 ページは今の `docs/*.en.md` から（1.1.1 の 3 か所と FAQ 2 つ）。日本語の `support.html` に足すのは言語の FAQ の括弧と FAQ「週の手書きが見えなくなったときは？」（1.1.1 の 3 か所は `r111-legal` にある）。新しい id: `週の手書きが見えなくなったときは`・`my-week-handwriting-is-gone-what-should-i-do`・`how-do-i-zoom-in-and-out`。
- **リード**: §8 の 11 の確認表の ja の説明の 1 行（§6.6）は README の `ja/whatsnew.txt` の行に書いた。
- **C**: LA の節の 19・22 と LA2-EU の節の「週は月曜始まり」は、この節で読み替える。commit のファイル名: `docs/SUPPORT.md`・`docs/SUPPORT.en.md`・`docs/store/README.md`・`docs/store/review-note.txt`・`docs/store/ja/whatsnew.txt`・`docs/store/en-US/whatsnew.txt`・`docs/store/en-US/description.txt`・`docs/store/source-ja/whatsnew.txt`・`docs/store/source-ja/whatsnew.en-US.txt`・`docs/store/source-ja/description.txt`（と `docs/M7B.md` のこの節。SUPPORT の 2 つと README は LA2-EU の未 commit の分も入っている）。

### 残る危険

- **古い版の端末の案内が新機能の文にしか無い**: 「日曜始まりで書いた週の手書きは、古い版の端末では見えません」は §6.3 の新機能の文にあるが、次の版で消える。SUPPORT の FAQ（§10.4 の固定の文と「iPad と iPhone で版が違うと？」）には無い。§6.4 が「足すのはこれだけ」と決めているので足していない。足すなら本人に聞いてから。
- **審査メモは上限まで 58 バイト**: Connect の数え方がバイトでなく字なら余裕はもっとあるが、確かめていない（A の測り方はバイト）。
- 週の始まりの英語の文は、英語を母語とする人が読んでいない（R の逆翻訳だけ）。「設定」アプリの道はこれまでどおり TestFlight で確かめるまで仮。

## P（§4 の紙と見出しの字: `PaperWords`・F-0〜F-11・F-16・PDF、第 4 版の週の始まりの並びと色。§12.1 の P）

commit・push・CI なし。凍結の 18 ファイルと `InkCanvasViewTests` は変えていない（`shasum -a 256 -c tools/compat10/DATA_1_1.sha256` 全部 OK、`git diff --quiet HEAD -- Tests/TegakiCalendarTests/InkCanvasViewTests.swift`）。`PaperView` の口と `PaperContent` の各型の形も変えていない（`YearPaperContent.monthNames` は残した。ja の見出しだけが読む）。

### 入れたもの

- `Views/PaperWords.swift`（新規）: §0 の 5 つ（`yearWeekday`・`monthHeaderWeekdays`・`weekColumnWeekday`・`yearColumnTitles`・`allDayLabel`）と、足した 6 つ（`yearWeekdayScale`・`monthHeaderColumns`・`weekdayTone`・`yearHolidayFit`・`monthHolidayFit`・`dayHeadingFit`）。
- `Paper/PaperText.swift`: `drawFittedLine`（F-0）、`fittedScale`、`naturalWidth`、`LineFit`、`drawLine(_:in:font:color:fit:)`。今の `drawLine` は変えていない。
- `Paper/YearPaper.swift`（F-1・F-2）、`MonthPaper.swift`（F-3・F-5・F-6）、`DayPaper.swift`（F-6）。
- `Views/StickyHeaderView.swift`（F-8〜F-10、§4.2、§10.5。月の行は `layout.rows[0].days` から並びを読み、色は曜日で。読み上げの `.full` を足した）、`AllDayBandView.swift`（F-7、§4.2）、`PageHeaderView.swift`（F-11、§4.2、`page.title`、前へ・次へは 4 × 2 の完成した文）。
- `Export/PDFPageRenderer.swift`（§4.3、§10.5）。週の曜日は `PaperWords.weekColumnWeekday`、`PageNavigation.weekdayLetters` はアプリから消えた（L-7）。
- `tools/l10n/source/app-P.json`（新規、32 キー。`app.name`・`paper.*`・`allday.*`・`header.*`）。`kit-K.json` は `kit.layout.more.*` の `composedOf` に `Paper/MonthPaper.swift:189` を足しただけ（K1 の節の 11 と K2 の申し送りのとおり。字は `LayoutWords.more` から）。
- `Tests/TegakiCalendarTests/PaperFitTests.swift`（新規 12 本。§7.2 の 8 本と §10.8 の `testMonthHeaderOrderAndColors` に、`testFittedLineIsTheSameWhenItFits`・`testComposedJapaneseIsTheOneOneText`（J-1 の C 型の組み上がり）・`testTitlePartsSplitTheHolidayOff`）、`PaperViewTests.testPDFMonthRowSunday`。

### 契約からのずれ（理由つき）

1. **F-1 の数字の枠: 広げるのは今日のマスだけ、幅は 0.1 em**（契約は全部の日で 0.05 em）。この Mac（Mac Catalyst の UIKit で実際に描いた）では、15 lu の 2 桁は semibold 19.77 lu・heavy 20.89 lu で、契約の 20.1 lu は大きな字（100 pt）で測った値だった（システムの字は小さいほど字間が広く、幅が大きさに比例しない）。semibold の 19.77 lu は 1.1 の枠 19.5 lu をわずかに超えていて、はみ出した分だけ左に寄らず左端から描かれている。枠を 20.25 lu に広げると右寄せが効いて **10〜31 日の全部の数字が 0.27 lu 左へ動く**（古いコードと契約どおりのコードを描いて比べた結果、日本語の年の絵の 10〜31 日の 22 行が全部違った。PDF の年も同じ）。実機で同じ幅かは CI まで分からないが、同じなら J-4 が落ちて、契約の「数字の枠は 1.1 のままに戻す」になる。一方、heavy の 2 桁は枠 20.25 lu でも「…」のまま（1.1 も 19.5 lu で「…」。契約の「0.6 lu 欠ける」より目立つ）。そこで **今日でない日は 1.1 の枠のまま、今日だけ左へ 0.1 em（1.5 lu。今日の輪の内側）広げて 21 lu にした**。右端は 1.1 と同じ。J-4 の写真の今日は 7 日で 1 桁なので絵は変わらない。`§1` の「違ってよい」は「31 日」と書いているが、等幅の数字なので今日が 2 桁の日は全部同じ直しになる（今日が 10〜31 日のときの年のマス）。
2. **F-1 の曜日の率: 測り直しを足し、下限を 0.7 → 0.65 に**（`PaperWords.yearWeekdayMinScale`）。比例しないので、契約の `23.4 ÷ 最大幅` を 1 回かけるだけでは入らない（pt-BR の「dom」は heavy の 10.5 lu（0.7 倍）で 24.86 lu、枠 23.4 lu に入らず「d…」と描かれた。その言語の日曜が今日の日）。`PaperText.fittedScale` は小さくした字で測り直す。この Mac の pt-BR の率は約 0.66。下限は 7 字をそろえる率が入るために下げた（読める倍率で約 13 pt）。ほかの言語は en が約 0.97、残りは 1。**§3.3 の表の em も同じ理由で実際より小さい**（heavy 15 lu で en「We」1.59 em、pt-BR「dom」2.28 em）。
3. **`PageHeaderView.titleHoliday: String? = nil` を足した**（§0 に無い。F-11）。ヘッダーは題名の文字列しか受け取らず、日付と祝日名を分けられないので、題名の末尾の祝日名を別に渡す。無ければ 1 つの `Text` のままで動く。**U の呼び出しの 1 行がまだ要る**（下の「次の役へ」）。
4. **F-16 のテストの上限は 44.5 pt**（契約は 44 pt で「目安」）。de「Woche」は契約の測りで 43.7、この Mac で 44.2 で、契約が「入る」と書いた語が測り方の差で落ちないように 0.5 pt の余裕を置いた。「今日」は契約のとおりだったが、de「Heute」が上限まで 0.005 pt しか余らないので、検証の後に FIX が同じ 0.5 pt を足した（`todayLimit` は ja の幅 ＋ 16.5）。
5. **PDF の月名は `content.monthNames` を読まない**（§4.3 のとおり `monthName(.full)`）。ja の字は同じ。`monthNames` を読むのは ja の見出しだけ。
6. `StickyHeaderView.dayLabel` と `AllDayBandView.columnLabel` は `EventDateText` でなく `DateText.spokenDay` を呼ぶ（ja は `dayTitle` と同じ字、§3.1 の 2。§4.2）。`dayLabel` に `language:`（既定 `L.language`）を足した。
7. `allday.label.short` の ja は「終日」（ja の道では使わない。L-2 のために値が要る）。

### 確かめたこと

| 確かめ | 結果 |
| --- | --- |
| `tools/typecheck/typecheck.sh`（HEAD ＋ K2 の Kit ＋ 自分のファイルの写し、と、U・S2 が書いている途中の作業の木の両方） | 全部 OK・警告 0 |
| `python3 -I tools/l10n/lint.py .`（S2 の途中の lint） | L-1・L-3〜L-14 が ok。L-2 は訳が無いので 9 言語とも失敗（X の前は当然） |
| `python3 -I tools/l10n/build.py . --check` | 一致 |
| **本物の UIKit で XCTest を走らせた**（この Mac の Mac Catalyst で Kit とアプリを組み、XCTest の小さな代わりで走らせた。写し `m7b-impl/P/run`、仮の訳つき。リポジトリの外） | `PaperFitTests`・`PaperViewTests` 21 本・1,208 件・失敗 0。`PaperTextTests`・`ExportBuilderTests` も通る。例外は `testPDFRendersEveryKind` の「now line」の 2 件で、古いコードでも同じく時々落ちる（Mac の PDF のバイトが回ごとに違う。私の変更ではない） |
| **日本語の絵の古いコードとの比較**（J-4 の代わりの先取り。HEAD のコードと P のコードで、年・月・週・日の紙、PDF 4 種、`StickyHeaderView`・`AllDayBandView`・`PageHeaderView` を今日 3 通りで 89 枚描き、`compare_shots.swift` で比較） | **今日が 7 日の絵は全部同じ。** 違うのは今日が 12 日・31 日の年の紙と PDF の年の、今日のマスの数字だけ（「…」が「12」「31」に。ずれの 1）。`PageHeaderView` の分割の部品は UIKit なので描かれない。見出しの 1/255 の差は古いコード同士でも同じだけ出る |
| ほかの言語の絵（en・de・pt-BR・zh-Hans。仮の訳） | 年のマス・月の行（日曜始まり）・日の見出し・題名の分割を見た。切れない |

### 次の役へ

- **U（またはリード）: `CalendarRootScreen` の `PageHeaderView(...)` に 1 行足す**: `titleHoliday: !compact && kind == .day ? holidays.name(of: focus) : nil`。無いと、幅の狭い iPad の英語の日のページで「Thu, November 26, 202…」と日付が切れる（足すと「Thu, November 26, 2026」のまま祝日名が先に切れる。この Mac で描いて確かめた）。`monthNames` の値は U の `DateText.monthName($0, .short, L.language)` のままでよい（ja 以外は見出しが自分で幅に合わせて選ぶ）。
- **X**: 訳すのは `app-P.json` の 32 キーと `kit.layout.more.*`。上限はキーの `comment`・`maxEm`。**契約の em は大きな字の値なので、実際の字の大きさの幅は 1〜6% 広い**。`allday.label.short` は 10 pt で 24 pt 以内（`All-day` は入らない）。`header.today` の fr は略す、`header.picker.week` の fr・es・pt・it は略す（F-16）。テストが見ている幅は上の `PaperFitTests`。この Mac で本物の幅を測れるので、訳の後に `m7b-impl/P/run` の手順（`build.py --format strings`・`build.sh`・`runtests.sh`）で先に確かめられる。
- **C**: `testJapaneseTakesTheOneOnePath` が `repro: F-1 two digits …` の行を出す（「The unit tests' repro lines」の段に出る）。シミュレータの本当の幅が分かるので M7B.md に書く。
- **リード**: J-4 で年の写真に差が出たらずれの 1 を疑うより先に今日の日を見る（写真は 7 日なので今の作りでは差が出ない見込み）。**F-16 の読み替え**: 1.1.1 で「今日」が題名の右へ動いたので、狭い行の fr は `l10n-shots` の `fr/iphone-portrait-week.png`・`year.png` で題名の残りを見る（§1.5。略した「Auj.」なら約 26 pt より広く残る）。

### 残る危険

- 字の幅はこの Mac の Mac Catalyst で測った。iOS のシミュレータと実機では少し違いうる（`PaperFitTests` は CI-0 で初めて本物で走る）。`testAllDayLabelChoice`・`testHeaderPickerAndTodayFit`・`testMoreChipsFit` は X の訳の幅しだいで落ちるので、落ちたら X の語を短くする。
- 仮の訳で確かめたので、本物の訳での切れ方は `l10n-shots` を見るまで分からない。

## U（§1.4・§5.6〜§5.9・§7.3・§7.4・§10.3〜§10.5・§10.7、§1.5 の U の分。§12.1 の U）

commit・push・CI なし。凍結の 18 ファイルと `InkCanvasViewTests` は変えていない（`shasum -a 256 -c tools/compat10/DATA_1_1.sha256` 全部 OK、`git diff --quiet HEAD -- Tests/TegakiCalendarTests/InkCanvasViewTests.swift`）。§0 の接点の名前（`ScreenshotMode.current`・`isActive`・`Config.probe`・`Config.today`・`SettingsScreen.versionText`・`CalendarRootScreen.newEventPlan` など）も変えていない。

### 入れたもの

- **祝日**: `Persistence/HolidayChoice.swift`（`current`・`store`・`setting`・`migrateIfNeeded`（§1.4。新しい人にも "auto" を書く）・`calendar`・`summary`）。`CalendarRootScreen` の `holidaySettingRaw`・計算プロパティ `holidays`・1 つの暦を受ける `makePaper(…, holidays:, weekStart:)`（§5.6）。`Views/HolidaySettingsSection.swift`・`HolidayPickerScreen.swift`（州の画面 `HolidaySubdivisionScreen` を含む）・`LicenseScreen.swift`（読めなければ `HolidayDataLicense.mitText` と URL）。起動のログ `l10n: ui=… locale=… holidays=…`・`l10n: holidays loaded <ms> ms`（写真モードと DEBUG）。
- **週の始まり**: `Persistence/WeekStartChoice.swift`（`WeekStartChoice`・`WeekStartNotice`・`WeekStartNotices`）。`CalendarRootScreen` の `@State weekStart`・`weekStartRaw`・`penTouchedThisLaunch`・`pendingAdoption`・`weekStartNotices`、純関数 `weekStartSwitch`（save → apply → reload）。`runWeekStartCheck`（§10.3 の 4）を `syncStatusChanged`・`appear`・`show` の入口（`saveNow` の直後、`pendingAdoption` のとき）・`.active` の入口・取り込みの後で呼ぶ。キャンバスの `.id` はページの id と週の始まりの組。`Views/WeekStartSettingsSection.swift`（節と問い `weekStartQuestion`）。`EventStoreModel.load(kind:focus:weekStart:)`。
- **文字**: `tools/l10n/source/app-U.json` 171 キー（1.1 の字をそのまま引き受けた `was` が 109、つないでいた字の `composedOf` が 10、うち `demo.*` が 28。残りは §10.4 の 21 キーと §6.3 の新しい文）。`toast.pinchHint` は `was` が `Views/CalendarRootScreen.swift:282`、ja は 1.1.1 の文のまま。15,000 / 19,000 は `DateText.number` で埋める C 型（`composedOf`）。
- **その他**: `ScreenshotMode`（`Config.holidays`・`weekStart`（1.1.1 の `pinchHint` の後ろ）、`Sheet.holidays`・`.weekStart`、`demoEvents(…language:)`・`calendarTitle(…language:)`・`calendarOptions(language:)`、`demoPage(…, weekStart:)`、水曜の列を `weekStart.column(of:)` で）、`l10n.state` の部品（1 × 1 pt）、§5.8 の語（`EventKitService.holidayCalendarWords`・`isHolidayCalendarTitle`）、`events(in:calendars:)` を消した、`SettingsScreen.timeText`・`dateText`、`large.map` の直し、`otherWeekStart` を作って渡す・`closeImportSheet` のパターン 4 つ、`XCTestStandIn` に `otherElements`・`identifier` だけ。
- **テスト**: 新規 `HolidayChoiceTests`・`WeekStartChoiceTests`・`WeekStartLedgerTests`・`LanguageUITests`・`WeekStartUITests`。足しただけ: `CalendarRootScreenTests`・`SettingsScreenTests`・`ScreenshotModeTests`・`EventKitServiceTests`・`AppSettingsTests`・`SyncEngineTests`。UI テストの 4 つは起動の引数を足しただけ（日本語のコメントの行は変えていない）。`git diff HEAD -- Tests` の削除行は `Sheet.allCases` の 2 行（§7.2 の指定）と、末尾の `}` の付け直し 1 行だけ。

### 契約からのずれ・契約が黙っている所の決め方

1. **`demoPage` の `weekStart:` は `empty:` の直後でなく一番後ろ**（1.1.1 が `empty:` の後ろに `tallYear:` を足したので。§0 の「`empty:` の後ろ」は満たす）。
2. **`testSummaryTexts` の国名はシステムに聞く**（日本だけ字で確かめる）。この Mac の `localizedString(forRegionCode: "CN")` の ja は「中国本土」で、契約の例の「中国（…）」とは字が違う。Apple の表記なので直さない。例の年は H の申し送りのとおり（スリランカ・中国は 2027 年、台湾は 2026 年、データの無い地域は `AC`）。
3. **合わせる操作は `.onChange` を待たず、同じ `weekStartSwitch` をその場で呼ぶ**（`syncStatusChanged`・`appear`・`.active`・取り込み）。§10.3 の 4 の「設定を書いて `.onChange` の同じ道を通る」の道は同じで、1 ターン分短い。後から来る `.onChange` は `new == old` で何もしない（`show` の入口の道と同じ）。
4. **取り込みの後の判定の条件を決めた**（`WeekStartChoice.checksAfterImport`）: アプリの形式で、`.localOnly` か `readyToCheck` のときだけ。§10.5 の (2) は「まだのとき」だけ書いているが、§10.3 の (1) は iCloud を使わない人のための道と書いている。iCloud を使う人が offline で取り込んで判定すると、最初の pull の前に 1 回きりの判定を使い切って、月曜のページを知らせなしで見失う道が残る。Web の形式は常に月曜のページに入るので判定しない。`otherWeekStart` は両方の形式で作る（§10.2）。
5. **トーストの機会を 1 つ足し、出さない条件を 1 つ足した**: `.onChange(of: showAccountChange)`（§10.4 の 3 つの機会の外。問いが閉じた後に待っている知らせが次の機会まで残らないように）と、`accountChangePending` の間は出さない（問いが来る直前に出すと問いの下になり、`hiddenInk` が案内済みになる）。
6. **`WeekStartNotices.dropHiddenInk()` を足した**（§0 に無い）。月のページは両方の形で id が同じなので、シートの中で日曜 → 月曜と戻すと、日曜で数えた `hiddenInk` が月曜で（誤った本数で）出ていた。`show` の判定の頭で捨てて数え直す。
7. **§0 に無い小さな関数**: `AppSettings.isExistingUser`（3 つのキー。`hint.pinchShown` は見ない）、`WeekStartChoice.needsDataCheck`・`regionChange`・`checksAfterImport`・`otherForm`・`name`、`HolidayChoice.yearNote`・`noteText`・`countryName`・`deviceCountry`、`SettingsScreen.translationNote`。`yearNote` は一覧の 250 か国のファイルを読まないために index から決める（`note(forYear:)` と同じ結果であることをテストで照らす）。
8. **選ぶ画面の検索は `.searchable` でなく一覧の中の欄**（§5.7 の並び「近道の次に検索の欄」のとおり）。州の画面の欄の字は同じキー `holidayPicker.search`（§6.3 に州の画面の検索の文が無い）。
9. **問いは行でなくフォームに付けた**（`weekStartQuestion`）。`Form` は画面の外の行を持たないので、iPhone の `--screenshot-sheet week-start` で出ないことがある。ピッカーの一覧が戻る間は alert が出せないので、選んでから `sheetGap` 待つ。
10. **`monthNames` は `DateText.monthName($0, .short, L.language)`**（§3.2 の「U が P の関数を呼ぶ」の読み替え）。`makePaper` は幅を知らず、P の見出しは ja のときだけこの値を読む。ja の字は 1.1 と同じ。
11. **F-11 のために `PageHeaderView` に `titleHoliday` を渡す**（`!compact && kind == .day ? holidays.name(of: focus) : nil`）。F-11 は祝日名を別の `Text` にするので、題名だけでは足りない。ja は `titleParts` が nil で 1.1 の道。
12. **`dateText(_:locale:)` の既定は `L.locale`**（1.1 は `.current`）。形は残した。`.current` だと画面の言語と書式がずれる端末がある。
13. **§6.3 に文の無いキーを足した**: `alert.saveFailed.ok`「OK」、`settings.input.pencil`「Apple Pencil」、`license.contributors`「Contributors: %@」、`settings.holidays.note.join`、`settings.purchase.trial.one/.other`（`ProductIDs.trialDays` は複数形の 2 キーで）。`info.translationNote` の ja は契約に無いので書いた（日本語の画面には出ない。訳の元は §6.3 の英語の文）。〔やめる〕は S の `import.confirmLarge.cancel`（§10.4 の「今の語のキー」）。
14. **`testWeekStartToastsFitThreeLines` は 402 pt（iPhone 17）で落とす**。375 pt は `print` するだけ。字の大きさは既定（`.large`）に固定。行数は高さの割り算でなく `NSLayoutManager` の行で数える（漢字の代わりの書体は行が高く、3 行を 4 行と数えた）。ja は今の文で 375 pt でも 3 行に入る。

### 確かめたこと（この Mac、Swift 6.4.2、Command Line Tools。push・CI は無し）

| 確かめ | 結果 |
| --- | --- |
| `tools/typecheck/typecheck.sh`（リポジトリの外の空のフォルダ。S2・P の途中の作業の木のまま） | all OK・警告 0（アプリ 67 ファイル、TegakiCalendarTests 34、UI テスト 6、Kit のテスト 6 つ） |
| **アプリの XCTest を本物の UIKit で走らせた**（Mac Catalyst で Kit とアプリを組み、XCTest の小さな代わりで。`@State` は typecheck と同じ代わり。リポジトリの外 `m7b-impl/U/run/run.sh`。訳は無し） | `AppSettingsTests`・`CalendarRootScreenTests`・`EventKitServiceTests`・`HolidayChoiceTests`・`ScreenshotModeTests`・`SettingsScreenTests`・`SyncEngineTests`・`WeekStartChoiceTests`・`WeekStartLedgerTests` の 159 本・2,941 件。失敗は `testEraserFooterNeverNamesThePencilOnAnIPhone` の 9 件だけ（9 言語の `.footer.pad` に「Apple Pencil」があることを見るので、X の訳が要る）。`testPushOnlyLeavesNoZoneToken`（§10.3 の 4 の前提）・`testSwitchKeepsBothForms`・`testHiddenStrokeIsNotErased`・`testStrokeFollowsItsDateWhenLayoutChanges` は凍結のコードで本当に通った。`ExportBuilderTests` などを足して 210 本にしても新しい失敗は無い（`testPDFRendersEveryKind` の「now line」は P の節のとおり、Mac の PDF のバイトの差） |
| `python3 -I tools/l10n/lint.py .` | L-1・L-3〜L-14 が ok。L-2 は訳が無いので失敗（X の前は当然） |
| `python3 -I tools/l10n/build.py . --check` | 一致（S2・P の元と一緒に作り直した） |
| J-2 | `git diff HEAD -- Tests TegakiKit/Tests` の U の分の削除行に日本語・`w-20`・`Monday`・`Sunday` は無い（`Sheet.allCases` の 2 行と `}` の 1 行だけ） |

**動かしていないもの**: 画面そのもの（SwiftUI の `@State` がこの Mac で組めないので、`body` は型だけ）、UI テスト（`LanguageUITests`・`WeekStartUITests`・起動の引数を足した 4 つ）。CI-0 で初めて走る。

### 次の役へ

- **X**: U のキーで訳すのは 171（`app-U.json`）。§10.4 の 21 キーの英語は各キーの `comment` に書いた。トーストは 402 pt・15 pt で 3 行以内（`testWeekStartToastsFitThreeLines`。`m7b-impl/U/run/run.sh` か P の手順で訳の後に先に測れる）。`settings.input.eraserAutoReturn.footer.phone` に Apple Pencil・iPad を書かない、`.pad` には Apple Pencil を書く。`settings.data.importFooter` は `allowJapanese`。`settings.purchase.footer.readOnly` の `%@` の後ろの空白は語の間に空白を置く言語で。`settings.weekStart.monday`・`.sunday` は文の中の括弧にも入る。`demo.*` は `maxEm`（終日 4.2、時刻 5.7）。`demo.event.businessTrip` の大阪は各言語の地名。
- **C**: `project.yml` に `HolidayData` のフォルダ（`Bundle.main.url(forResource: "HolidayData", withExtension: nil)`。無くても日本は動くが、他の国は「なし」、ライセンスは退き先になる）。UI テストの grep に `l10n UI:` と `week-start UI:`、ジョブの UI テストの一覧に `LanguageUITests`・`WeekStartUITests`。写真の引数は `--screenshot-holidays`・`--screenshot-week-start`・`--screenshot-sheet holidays`・`--screenshot-sheet week-start`。`l10n: holidays loaded <ms> ms` の CI の値を M7B.md に（目安 50 ms、§5.3）。
- **リード**: 本人に見せる例の字: 中国の行は「中国本土（2027 年は発表前の推定）」になる（システムの表記）。問いの文（`settings.weekStart.confirm.message.*`）は §10.4 のまま。
- **検証**: 順番の確かめは `CalendarRootScreen.weekStartSwitch`・`switchWeekStart`・`runWeekStartCheck`・`show` の入口・`scenePhaseChanged` の `.active`・`penDown` の頭。ずれの 3・4・5・6 を見てほしい。

### 残る危険

- **画面の動きは CI-0 と本人の確かめまで未確認**: 州の画面で選んだときに 2 段戻るのは親の `.onChange(of: raw) { dismiss() }` に頼っている（戻らなければ、選択は記録されていて、戻るボタンで戻れる）。ピッカーの後の alert は 0.35 秒待つ作り。`l10n.state` は `otherElements` で見つかる前提（見つからなければ §7.3 のとおり 1 pt の `Text` に替える）。
- `testWeekStartToastsFitThreeLines` の字の幅は Mac Catalyst の測り。X の訳の長さで落ちたら X が短くする（§10.4）。`ToastView` は持ち主の無いファイルなので変えない。
- `l10n: holidays loaded` は未測定。50 ms を超えたら §5.3 のとおり main の外で先に読む直しが要る。

## S2（S の後半: 文字列の移し・lint の残り・ツールバーと投げなわのメニューの字・週の始まりの S の分。§12.1 の S2）

commit はしていない（S2 は commit しない役）。`git add` は C が、次の **S2 のまとまり** をファイル名で: `tools/l10n/source/app-S.json`、`tools/l10n/lint.py`、`Support/Products.storekit`、`Sources/TegakiCalendar/` の `Views/{ToolbarView,ToolbarLogic,ToolbarDock,EventEditorSheet,EventEditorForm,PaywallSheet,WebImportSheet,ExportSheet,OnboardingView,AccountChangeDialog,RecurrenceScopeDialog,SelectionMenuView,EventDateText}.swift`・`Sync/SyncStatus.swift`・`Store/StoreStrings.swift`・`Store/LiveStoreClient.swift`・`Calendar/EventDraft.swift`・`Persistence/StrokeCensus.swift`・`Export/ExportBuilder.swift`・`Support/L10n.swift`（`count` を足した）、`Tests/TegakiCalendarTests/` の新規 `L10nTests`・`LocalizationBundleTests`・`EventDateTextTests`・`ToolbarFitTests` と足すだけの `WebImportSheetTests`・`ExportBuilderTests`・`ExportSheetTests`・`StrokeCensusTests`・`PaywallSheetTests`・`StoreKitSessionTests`。生成物（`Resources/*.xcstrings`）は最後に元を足した人が作り直す。

### 入れたもの

- **`app-S.json`: 229 キー**（227 が Localizable、2 が InfoPlist。複数形は 11 組 22 キー）。S のファイルの 1.1 の 233 行を全部引き受けた（`was` か `composedOf`。`EventDateText.swift:12, 21` の 2 行は K の `kit.date.ja.*` の `composedOf` のまま）。1.2 の新しい文は `import.otherWeekStart.*` の 2 つだけ。ja は 1.1 の字（`was` のものは ja-baseline.tsv の行から作ったので打ち間違いが無い。L-3 も照らす）。
- **持ち主のコードを全部 `L` へ**（§0 の S のファイル）。`EventDateText` は `DateText`・`LayoutWords.range`・`event.allDay`・`DateText.time` で組み直し、3 つの DateFormatter を消した（形は §0 の 2 つ）。`PaywallSheet` は `PlanText.*(language:)`・`LegalLinks.terms(for:)`・`privacy(for:)`・`appleEULATitle(_:)`。`StrokeCensus` は `StrokeBudget.pageLabel(_:language:)`・`countText(_:language:)`。`ExportSheet.byteText(_:language:)` は ja 以外の数を `NumberFormatter`（§3.2。単位の B・KB・MB は訳さない）。`WebImportSheet.confirmLargeText` の 20,000 は `DateText.number`（§3.2）。
- **F-12〜F-15**: `ToolbarLogic.Row.labelFrameWidth(for:)`・`labelMinScale`（§0）、`ToolbarView.rowLabel`（ja は 1.1 のコードの道、ほかは 38 pt の枠で 0.8 倍まで）。`tool.pen` の識別子（§7.3）。F-13・F-14・F-15 は寸法を変えず、上限を `ToolbarFitTests` で測る。`eraserHint(returnsTo:)` はキーにせず今の形のまま（§4.4）。
- **週の始まりの S の分**（§10.5、§0）: `WebImportPhase.done(…, otherWeekStart: WeekStart? = nil)`、`toastText(…otherWeekStart:)`、`otherWeekStartText(_:)`。シートの完了の画面にも同じ 1 行を出す。`ExportBuilder` の題名とファイル名に `holidays: HolidayChoice.current`・`weekStart: WeekStartChoice.current`。
- **`lint.py` に L-2・L-5〜L-9・L-11〜L-14**（第 4 版の `.map(StrokeBudget.pageLabel`・L-9 の価格も）。これで §2.7 の 14 が全部入った。コードを読む L-7・L-8・L-13・L-14 は、コメントと文字列の中身を除いた写しで照らし、呼び出しは閉じ括弧まで読む（文字列の埋め込みの中のコードは読む）。
- **テスト**: §7.2 の S の全部（`testUSStorefrontPrices` を含む）、§10.8 の S2 の 3 本。足した分は `WebImportSheetTests.testJapaneseCountsAreNotGrouped`、`StrokeCensusTests.testSundayWeekLabel`、`PaywallSheetTests.testUSPricesOnTheYearlyNote`、`L10nTests.testCount`・`testTheTestsRunInJapanese`。既存の行は 1 つも変えていない（削除行 0、J-2）。
- `Support/Products.storekit`: グループと 2 つのプランに en_US（`docs/store/subscriptions/en-US.json` の字。§6.6）。

### 契約からのずれ・契約が黙っている所の決め方

1. **`L.count(_:in:)` を足した**（§0 に無い）。1.1 の `\(n)` は区切りなしで、1,000 以上で「1234 ページ」。契約の例（§2.5 の `DateText.number`）のまま ja に通すと「1,234 ページ」になり J-1 に反する。だから文に埋め込むふつうの数は ja は `String(n)`、ほかは `DateText.number`。1.1 がカンマで書いていた 20,000 だけ `DateText.number`（§3.2）。
2. **取り込みの結果は 2 つの数を別の複数形のキーで**: `import.result.app`・`.web`「手書きを取り込みました（%1$@・%2$@）」に `import.result.pages.*`「%@ ページ」・`import.result.strokes.*`「%@ 本」を入れる。§2.4 の「文全体を 1 つのキー」のままだと、数が 2 つで .one / .other が 4 通りになる（D5 の 2 キーでは選べない）。`.one`・`.other` を 2 つの数で持つ形はほかに無い。
3. **`event.when.dateTime`「%1$@ %2$@」を足した**: ja-baseline の `EventDateText.swift:54, 56` は「〜」だけが日本語で、「〜」は `LayoutWords` から来るのでキーが無い。日付と時刻の並べ方のキーとして行を引き受けた。`:46, :48` は `event.allDay`（§3.2）の `composedOf`。
4. **並びの区切り**: `WebImportSheet.swift:146-148` は `import.confirmLarge.separator`「、」と `import.confirmLarge.more.*`「ほか %@ ページ」。ページの数が決まらない並びで、文全体のキーにできない。
5. **`paywall.title` は `app.name` と別のキー**（`app.name` は §4.3 で P の物。同じキーを 2 つのファイルに置くと build.py が止まる）。
6. **試用の 14 日にも複数形のキー**（`paywall.cta.trial.*` は §2.4 の例の形。`paywall.blockedTrial.*`・`paywall.trialLead.*`・`store.trialStarted.*` も同じに）。14 は定数なので `.one` は今は使わないが、D5 の形にそろえた。
7. **文をつなぐ所が 3 つ残る**: `paywall.blockedLead` ＋ `paywall.blockedTrial`、`paywall.trialLead` ＋ `paywall.trialRest`（太字の分け目。§4.1 の画面の作りのまま）、線の数の行 ＋ `census.legacyNote`。文の間に空白を置く言語は、後ろのキーの値の頭に空白を入れる（キーの comment に書いた。build.py と L-2 は頭の空白を許す）。
8. **キーの名前は `.one` / `.other` で終えない**: 「その他の色」は `toolbar.color.unknown`（`toolbar.color.other` は L-4 が複数形の片割れと読む）。
9. **L-7 の読み方**: `PlanText.savingsMonths`・`perMonth` は数を返すので除いた（契約は `PlanText.` とだけ）。「言語の引数」は引数の中に `language`・`L.language`・`.ja` などの語があること（型は見られない）。`YearMonth` の `.title(` は `.title(` の呼び出し全部を見る。引数なしの性質 `month.title` は lint では見分けられないので、今のアプリに無いことを grep で見た。**凍結の 18 ファイルは L-7・L-8・L-13・L-14 で読まない**（直せないので。今は当たりも無い）。
10. **L-8**: `L.text("x." + y)` のように文字列の直書きでないキーは、**その行か上の 3 行以内**に `// l10n-dynamic: <接頭辞>` が要る。InfoPlist のキーは「使われている」を見ない。`Support/L10n.swift` は定義なので読まない。
11. **L-2**: 訳の無いキーは言語ごとに 1 行にまとめて出す（X の前は 1 行ずつだと 3,000 行を超えるため）。ko の値の漢字も失敗にした（§2.7 は「zh・ko 以外では漢字・ハングル」と書くが、ko の漢字は意図が無い。逆の指摘があれば緩める）。
12. **L-9**: 名前の語は 3 つの案の全部から（ラテン文字は 3 字以上、漢字・かな・ハングルは 2 字以上。`docs/store/README.md` と同じ）。`Apple` などの商標は大文字小文字を区別しない部分一致、`free` などは語の一致（`freehand` を通す）。審査メモの 4,000 はバイト（§10.4 の測り方）。通貨のコードは契約の例に CNY KRW TWD HKD BRL MXN CAD AUD CHF を足した。`source-ja` はロケールでないので見ない。`copyOf` のロケールと、まだフォルダの無いロケールも見ない（`locales.json` の about のとおり）。
13. **`testUSStorefrontPrices`**: `Products.storekit` の価格は円なので、壊れていない StoreKit の試験環境で storefront を USA にしても $1.99 にならない（M5 の注記の $1.99 は壊れた環境が App Store の値を返した場合）。だから $1.99 が返らないときは skip にし、数の確かめは試験環境に頼らない `PaywallSheetTests.testUSPricesOnTheYearlyNote` で常に行う。**CI でも skip のままになる見込み。**
14. **`de_JP` の数**: この Mac の Foundation で `Locale("de_JP")` の小数点は「.」（地域の値が勝つ。`de_DE` は「,」）。§3.1 の「言語 ＋ 端末の地域」のとおりなので直さない。`byteText` のテストは字を決め打ちせず同じ locale の `NumberFormatter` と比べた。ドイツ語で日本の地域の端末は「1.2 MB」になる。

### 確かめたこと（この Mac、push・CI は無し）

| 確かめ | 結果 |
| --- | --- |
| `tools/typecheck/typecheck.sh`（外の空のフォルダ） | all OK・警告 0（アプリ、TegakiCalendarTests 31、UI テスト 4、Kit のテスト 6 つ。U・P の成果が同じ木にある状態で） |
| `swift build`・`swift run KitChecks` | 成功、**all 29432 checks passed**（Kit のソースは変えていない） |
| `shasum -a 256 -c tools/compat10/DATA_1_1.sha256` | 18 件 OK |
| `python3 -I tools/l10n/lint.py .` | **L-2 だけ失敗**（X の訳がまだ無いので 9 言語とも無い）。L-1・L-3〜L-14 は ok（L-1: 114 ファイル、L-3: 516 行が全部キーか例外、L-7: 80 か所、L-8: 504 か所・495 キー、L-13: 14 か所、L-14、L-9: 2 ロケール） |
| lint の作り物の木の確かめ（`m7b-impl/S2/pytest/cases_lint2.py`） | 134 件合格（コメントと文字列の中で当たらない、埋め込みの中は当たる、複数行の呼び出し、定義の行を除く、凍結のファイルを読まない、L-9 の上限ちょうど、など）。S1 の `cases_lint.py` は、L-2 が入ったことを前提にしない 2 件の期待のほかは合格 |
| **アプリの XCTest を実際に走らせた**（この Mac に XCTest が無いので、リポジトリの外の代わり `m7b-impl/S2/apprun/run.sh`。Mac Catalyst の実行ファイルに組み、`.app` に build.py `--format strings` の `.lproj` を入れ、`-AppleLanguages (ja) -AppleLocale ja_JP`、TZ は東京。XCTest の意味だけを写した小さな代わりなので、本番は CI-0） | 427 本。**S の範囲で失敗 0**（日本語: `testJapaneseEventTextIsUnchanged` 2026 年の全部の日 × 14 通り、`ToolbarLogicTests`・`WebImportSheetTests`・`ExportSheetTests`・`ExportBuilderTests`・`PaywallSheetTests`・`StrokeCensusTests`・`EventEditor*Tests`）。仮の訳（§6.2 の英語の語、ほかは ja の写し）を入れると `ToolbarFitTests`・`LocalizationBundleTests`・`L10nTests`・`testEnglishEventText` も合格。残りの失敗は次の 3 種類で S の外: 本物の訳が要る（`PaperFitTests`）、test host でないと成り立たない（`SyncEngineTests.test00TestHostUsesTheFake`・`StoreModelTests.testMakeInTheTestHostIsInert`）、`ExportBuilderTests.testPDFRendersEveryKind` の `stableBytes` の比較（Catalyst の PDF の字のバイトが run ごとに揺れる。週か日の 1〜2 件。同じ大きさで違う。iOS のシミュレータでは 1.1 の CI で通っている） |
| J-2 | 既存のテストの行を消していない（足しただけ） |

**訳が入るまで落ちるテスト**（CI-0 は X の後なので問題にならない）: `LocalizationBundleTests.testEveryLanguageBundleHasEveryKey`、`ToolbarFitTests` の全部（ja の 1 本を除く）、`L10nTests.testMissingKeyFallsBackToEnglish`・`testPluralPicksOneOrOther`、`EventDateTextTests.testEnglishEventText`。

### 次の役へ

- **X**: S のキーで訳すのは 229（InfoPlist の 2 つを含む）。長さの上限はキーの `maxEm` と comment にある。測るのは `ToolbarFitTests` で、言い換えが要りそうな語は §4.4 の実測のとおり。**崩さない形**: `toolbar.hint.eraser.toPen`・`.toMarker` は `toolbar.hint.eraser` の字で始める（`testEraserHintsShareTheFirstLine`）。`toolbar.hint.*` は改行 1 つまで、各行が ja の幅以内（消しゴム 144 pt、投げなわと予定 155 pt）。`selection.makeEvent`・`.delete`・`.deselect` は 14 pt で 3 つの合計 220 pt 以内。`toolbar.tool.*`・`toolbar.collapse.title`・`toolbar.width.thin`・`.medium`・`.thick` は 10 pt で 47.5 pt まで。`toolbar.fingerToggle` は 13 pt で ja ＋ 76 pt まで（de は Mit Finger zeichnen）。頭に空白を入れるのが `paywall.blockedTrial.*`・`paywall.trialRest`・`census.legacyNote`（ずれの 7）。`import.result.pages.one` と `.other` は en で別の字（`testPluralPicksOneOrOther`）。`export.close` は en に値があること。
- **C**: 上の「S2 のまとまり」。`lint.py` の頭の説明に 14 の全部を書いた。CI の「Localization lint」は `python3 -I tools/l10n/lint.py .` のまま。XCTest を CI の前に見たいときは `m7b-impl/S2/apprun/run.sh [--translated] [テストのクラス…]`（REBUILD_KIT=0 で Kit の組み立てを省く。約 1.5 分。作業の木を写して組むので木には書かない）。
- **リード・検証**: `tool.pen` の識別子を足した後に `app.buttons["ペン"]`（YearTapUITests・EraserAndBelowDayUITests）が見つかるかは CI でしか分からない（§7.3。見つからなければ識別子をやめて LanguageUITests は名前で探す）。

### 残る危険

- `ToastView` は 3 行まで（`lineLimit(3)`）。取り込みのトーストは最大で 3 つの文（結果・飛ばした・週の始まり）で、iPhone で文が折り返すと最後の文が切れうる。シートの完了の画面には全文が出る。文を削る話ではないので 1.2 ではこのまま。
- `L.value`・`text(_:in:)` が `.lproj` を見つけるかは、Xcode の xcstrings の組み込みに依る（S1 の節の「残る危険」と同じ。CI の `LocalizationBundleTests` で見る）。
- `ToolbarFitTests` の幅は測る端末の書体で動く（±3%）。この Mac の Catalyst と CI の iOS シミュレータで少し違う。
- フランス語の「MB」（本来は Mo）は §3.2 のとおり訳していない。

