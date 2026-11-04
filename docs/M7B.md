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

