# M7b（1.2）の実装結果

各役が自分の節を足し、C が最後に整えた。**今の状態、commit の一覧、確かめ、CI で初めて分かること、リードの残作業は最後の「C」の節を先に読む。** 各節は書いた時点の記録で、書き直していない。後の役が変えた物は C の節の「節の記録の読み替え」で読む。節の順は書いた順で、S0・LA・C1・K1・S1・H（前半の役）→ B11（1.1.1 の取り込み）→ K2・LA2・P・U・S2 → X1・R・X2・R2（訳）→ W（Web）→ FIX（検証の直し）→ C → TW → リード（後片付け）。**C の後の今の状態は、最後の「リード（2026-11-05 の後片付け）」の節も読む。**

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
| TW・KZ | 表は 2025 のまま。公表と照らして **TW 2027・KZ 2026**（「TW」の節） | 同じ | 今年は出ない。発表前は TW 2028 年・KZ 2027 年から |
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

**変わった所は例の文だけ（§5.7、0-20）**: 「スリランカ（2026 年以降のデータがありません）」は 0.107 では今年は出ない（「2027 年以降」が 2027 年に出る）。「中国（2026 年は発表前の推定）」も今年は出ず、今年この注記の出る国は無い（「TW」の節）。「自動（コソボ・祝日のデータがありません）」はコソボにデータがあるので出ない（次の役への U の所）。本人の手順と写真の期待にはこの 3 つの国は無いので、本人に渡す物は変わらない。

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
| 今年が「発表前」と出る国 | **無し**。ライブラリの表が 2025 までの台湾・カザフスタンは、2026 年（台湾は 2027 年も）の公表とデータを日ごとに照らして合っていたので直した（「TW」の節） | 無し |
| 来年（2027 年）に「発表前」になる国 | 中国・ベトナム・ベラルーシ・ウズベキスタン・カザフスタン。CN と VN は全部の祝日に「（推定）」。CN は規則で作った「（补假）」の日を書かない（270 日）。台湾とロシアは 2028 年から。中国・ベトナム・ベラルーシの 2027 年は 2026-11-05 の時点で公表済みだが、データには入っていない（「TW」の節の表） | 毎年の更新で動く（§5.11） |
| 2026 年でも推定の祝日がある国 | 販売中の 48 か国（モルディブ・イエメン 13 件、オマーン 12、イラク 11、バーレーン・ヨルダン・クウェート 10、アラブ首長国連邦 9、エジプト 6 など）。**パキスタン・インドネシア・マレーシア・インドは 0.107 で 2026 年の公式の表が入って推定でなくなった**（契約の 0.83 の例から変わった） | 名前に「（推定）」（0-17） |
| 州の振替出勤 | アルメニアの AM-LO・AM-SH は振替出勤の日が全国と違うが、§5.2 の形に州の `workdays` が無いので書いていない（色だけの差。名前と休みは正しい）。gen.py が標準エラーに出す | 無し |
| 訳の照らし合わせ | 台湾の zh-Hans の列の 23 日（臺灣光復… の振替）は、ライブラリの訳に照らせず同じ日の名前を使った（名前は正しい）。ほかの 106 万件は訳の表で照らせた | 無し |
| 祝日がほぼ無い地域（FIX が足した） | ブーベ島・ハード島とマクドナルド諸島・英領インド洋地域（BV・HM・IO。販売外）は祝日が 0 件で、`coverage` は 2000〜2099。ギニアビサウ（GW。販売中）はデータが 2023 年からなのに `coverage` は 2000〜2099。どれも 2015〜2024 年の中央値が 0 なので、`coverage_range` が全部の年を「揃っている」と見る | 知らせは出ない。BV・HM・IO は選べて、選ぶと何も出ない（0-20 の「祝日のデータがありません」も出ない。ほぼ無人の地域）。GW は 2026 年に祝日があるので今年は問題ない |

**販売中の地域でデータが無い所は無い**（0.107 でコソボが入った。ずれの 2）。

### 販売中の 175 の国・地域（§5.10。KitChecks が同じ一覧を書き出す）

名前の言語の数（§5.5）: 英語 175、フランス語 21、スペイン語 19、ポルトガル語 8、ドイツ語 7、簡体字 5、繁体字 4、イタリア語 2、日本語 1、韓国語 1（10 言語がそろう国は無い。いちばん多いカーボベルデで 5）。「州」は全国と差のある州・地域の数。「2026 年の注記」は今年の設定の行に出る文。「公式の表の最後の年」は、TW と KZ だけ公表と照らした年（「TW」の節。ライブラリの表はどちらも 2025 まで）。

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
| KZ | カザフスタン | 2026 | はい | 2006〜2099 |  |  |
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
| TW | 台湾 | 2027 | はい | 2000〜2099 |  |  |
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

## X1（用語集・9 言語の訳・ストアの 10 ロケールの文。§12.1 の X・R の行の X の前半）

commit はしていない（X は commit しない役）。`git add` は C が、次の **X1 のまとまり** をファイル名で: `docs/i18n/GLOSSARY.md`、`docs/i18n/REVIEW.md`（X1 の節だけ。表は R の後）、`tools/l10n/translations/{en,zh-Hans,zh-Hant,ko,fr,de,es,it,pt-BR}.json`、生成物 `Sources/TegakiCalendar/Resources/{Localizable,InfoPlist}.xcstrings`・`TegakiKit/Sources/DayKit/KitStrings.generated.swift`、`docs/store/{zh-Hans,zh-Hant,ko,fr-FR,de-DE,it,pt-BR,es-MX,es-ES,pt-PT}/` の 7 つの欄、`docs/store/subscriptions/{zh-Hans,zh-Hant,ko,fr-FR,de-DE,it,pt-BR,es-MX,es-ES,pt-PT}.json`、`docs/store/README.md`（3 か所。LA2 の未 commit の分も入っている）、この節。

### 入れたもの

- **用語集** `docs/i18n/GLOSSARY.md`: 言語ごとの書き方と店頭の注（§6.1 の 9）、アプリの語の表（§6.2 の全部と週の始まり・ピンチの案内）、iOS の画面の名前（11 の国の Apple の記事で 2026-11-05 に確かめた語と URL）、確かめられなかった語、測った幅（F-5〜F-7、F-12〜F-16）と言い換えの理由。
- **9 言語の訳**: 476 キー × 9 = 4,284 件（S 229・U 171・P 32・K の 42・H 2。`fixed` 9 と `jaOnly` 10 は訳さない）。§10.4 の 23 キーと `toast.pinchHint` を含む。en は契約の英文と `docs/store/README.md` の「英語の画面の名前」のとおり。
- **ストアの文**: 10 ロケールの 7 つの欄とサブスクリプション。es-ES は es-MX から直し、pt-PT は別に書いた（説明に「画面はブラジルのポルトガル語」の 1 点）。fr-CA・en-GB・en-AU・en-CA は写し（`locales.json`）。ja 以外に価格を書いていない（L-9）。
- `docs/store/README.md`: 「X（これから）」の 2 か所、「英語の画面の名前」を確定の文に。**英語の 3 文書・en-US・審査メモ・定型文は直していない**（en の訳を表の語で書いたので違う所が無い。文書の中の画面の名前と en の値を機械で照らした）。

### 契約からのずれ・契約が黙っている所の決め方

1. **解約の道は「設定 > 自分の名前 > サブスクリプション」**（キーの comment の例は Apple Account）。§6.1 の 4 の「Apple の記事の語」に従った。9 言語の記事の手順がこの形で、iOS 17 の Apple ID を書き分けなくて済む（英語の TERMS.en も同じ）。en も同じ。
2. **fr の「予定」は Apple のつづり évènement**（契約の例は Événement）。Apple の fr-FR の記事の語。ツールバーと投げなわのメニューは RDV（F-12、F-15）。
3. **de の「予定」は Termin**（Apple の記事は Ereignis。契約の例が Termin で、手帳の語として自然）。
4. **fr・es の `selection.deselect` は Annuler・Cancelar**。Désélectionner・Deseleccionar だと、この Mac の Catalyst の字で F-15 の 220 pt を超える。
5. **es・pt-BR の `toolbar.tool.marker` は Marcar**（§4.4 の Marcador は 45.8 pt の見積もりだったが、Catalyst の字で 47.8 pt あり上限 47.5 を超える。契約の表の語のうち Mac の AppKit で測った値は Catalyst より約 4% 狭い）。
6. **es の画面の「設定」アプリは「Ajustes (Configuración)」**と 2 つ書いた（§6.1 の 9。スペインと中南米で iOS の語が違い、es の画面は 1 つ）。アプリの設定の題名は Ajustes。
7. **it は Lei**（§6.1 の 1。Apple の記事は tu）。
8. **en の `toast.weekStart.hiddenInk.*` と `toolbar.hint.*` は契約の英文から短くした**（3 行と 144 pt に入らなかった。§10.4 が許す範囲で、意味は同じ）。
9. **`demo.*` は短い語**（en の “Osaka trip” → Osaka など）。L-12 の警告の目安でなく、測った幅で決めた。
10. **`docs/i18n/REVIEW.md` を先に作った**（§6.1 の 3 は R の後に X が作る表）。F-16 の「fr の略の理由」と、意図して変えた所を先に残すため。R は訳し戻しの前に読まない（ファイルの頭に書いた）。

### 確かめたこと（この Mac、push・CI は無し）

| 確かめ | 結果 |
| --- | --- |
| `python3 -I tools/l10n/lint.py .` | **L-1〜L-14 すべて ok**（L-2 は 495 キー、L-6 は 4,284 件、L-9 は 12 ロケール）。L-12 の警告は 59 件残る（字数 × 0.6 の目安。本当の幅は下で測った） |
| `python3 -I tools/l10n/build.py . --check` | 一致 |
| `swift build`・`swift run KitChecks` | 成功、**all 29432 checks passed** |
| `shasum -a 256 -c tools/compat10/DATA_1_1.sha256` | 18 件 OK |
| `tools/typecheck/typecheck.sh`（外の空のフォルダ） | all OK・警告 0（最後のトーストの文の直しの前。直したのは訳の JSON と生成物のカタログだけで Swift は変わっていない） |
| **アプリの XCTest を Mac Catalyst の代わりで走らせた**（`m7b-impl/S2/apprun/run.sh`、本物の訳で。本番は CI-0） | 全部で 427 本。失敗 10 件は訳と関係のない 3 本だけ（S2・P の節の「test host でないと成り立たない」`testMakeInTheTestHostIsInert`・`test00TestHostUsesTheFake` と、Mac の PDF のバイトの差の `testPDFRendersEveryKind`）。**`ToolbarFitTests`・`PaperFitTests`・`testWeekStartToastsFitThreeLines`・`testEraserFooterNeverNamesThePencilOnAnIPhone`・`LocalizationBundleTests`・`L10nTests`・`testEnglishEventText` は全部通った**。427 本を走らせた後にトーストの文を短くしたので、その後は幅と訳に関わる 7 クラス 63 本を走らせ直して失敗 0 |
| 語のそろい（`m7b-impl/X/check_terms.py`） | 文の中のボタンの名前と本物のボタンの字、推定の印、消しゴムの説明の 1 行目など、9 言語で食い違い 0 |
| 英語の文書と en の値の照らし | 違う所なし |
| Web・Connect・本人の作業フォルダ | 触っていない（Apple の公開のサポート記事を読んだだけ） |

### 次の役へ

- **R**: `tools/l10n/translations/<言語>.json` の値とキーの `comment` を読み、`docs/i18n/back/<言語>.json` に。ストアは `docs/store/<ロケール>/`・`subscriptions/<ロケール>.json` から `docs/i18n/back/store-<ロケール>.md` に（en-US と審査メモは LA の申し送りのとおり）。**`docs/i18n/REVIEW.md` と GLOSSARY.md は書き終わるまで読まない**。照合で特に見る所は REVIEW.md の最後に書いた。
- **X（2 回目）**: R の後に REVIEW.md の表。**直すときの手順**: `m7b-impl/X/tr/<言語>-*.tsv` が下書き（`\n` は改行、`key.*` は .one と .other）で、`setkey.py <lang TAB key TAB text の file>` → `make_translations.py` → `build.py`。ストアは `m7b-impl/X/store/<ロケール>.txt` → `write_store.py`。JSON や `docs/store` を直接直すと、次にこの道具を走らせたときに消える（どちらかに決めて使う）。幅は `m7b-impl/X/gloss_rows.py`（Catalyst の字）か `run.sh ToolbarFitTests PaperFitTests WeekStartChoiceTests` で測る。
- **検証（言葉の観点）**: es の画面の語（§6.1 の 9）、pt-PT が写しでないこと、de の ß。GLOSSARY.md の「確かめられなかった語」。
- **C**: 上の「X1 のまとまり」。
- **リード**: GLOSSARY.md の 3 の「確かめられなかった語」（アプリごとの言語の項目の語、「15 分ごと」、iOS のフルアクセスの字）を TestFlight で見る（§2.1）。違えば X が直す。

### 残る危険

- **各言語を母語とする人の確認は無い**（O-6）。R の訳し戻しで見られるのは意味の大きな違いだけで、自然さは見られない。特に短くした語（RDV、Marcar、Ablegen、24h）は写真で確かめたい。
- **幅は Mac Catalyst の測り**。en・de の「今日」（47.3・47.4 / 47.4）、de の「自由メモ」（7.98 / 8.0 em）、de の Woche（44.2 / 44.5）はほとんど余裕が無い。契約が入ると決めた語で、シミュレータで 0.5% 広いと落ちる。CI-0 で落ちたら語を短くする（FIX2）。
- **幅 375 pt の iPhone では、週の始まりのトーストが 4 行になる文が 4 つある**（de・it の `otherForm`、pt-BR の `otherForm.other`。数が 99 のとき）。最後の語が切れる。テストの判定は 402 pt（§10.4）で、ログだけに出る。
- **アプリごとの言語の項目の語は未確認**（Apple の記事に見つからない）。新機能の文に書いているので、TestFlight で違えばストアの文を直す。
- `kit.plan.savings.*` の「N か月分節約」は購入の画面の札で、価格から計算する。ストアの文には書いていない。

## R（逆翻訳の 1 回目。§6.1 の 3、§12.1。commit は C）

**やったこと**: 日本語の元を見ずに、アプリの文字列 9 言語（各 476 キー、合わせて 4,284）・ストア 11 組（説明の最後の 1 文・promo・名前の退き先・サブスクリプションを含む。es-ES・pt-PT、言い直した説明と新機能の文を含む）・審査メモ・英語の 3 文書の全文（§11.3 の文を含む）を日本語に訳し戻した。§10.4 のキーと `toast.pinchHint` も 9 言語とも入っている。置き場所は `docs/i18n/back/`（`<言語>.json`・`store-<ロケール>.md`・`store-review-note.md`・`legal-en.md`）で、同じ表を `m7b-impl/R/` にも置いた。照合と判定は X がする。

**契約とずれたこと**:

- `comment` は読んでいない。§6.1 の 3 は「値とキーの `comment` を読む」と書くが、`translations/*.json` に `comment` は無く（`text` と `jaSha1` だけ）、`comment` のある `tools/l10n/source/*.json` は開かない約束なので。文脈はキーの名前で補った。
- `docs/i18n/back/<言語>.json` は `{キー: 日本語}` でなく `{キー: {"text", "back"}}` にした。X が訳を直した後に、訳し直すキーを機械で見つけるため（`m7b-impl/R/work/changed.py`）。
- 同じ言語で同じ綴りのキーは同じ逆翻訳にした。意味が違う語だけキーごとに分けた（fr の `Fin`（細）と `Annuler`（元に戻す・選択解除）、it の `Annulla`（元に戻す）と `Fine`（完了）、de の `Löschen`（消す）、es の `Cancelar`（選択解除））。
- es-ES は es-MX と字が同じ行（39 行のうち 29 行）に同じ逆翻訳を使い、違う 10 行を別に訳した。en-GB・en-AU・en-CA・fr-CA は `copyOf` なので表を作っていない。

**「日本語の元を見ない」の範囲**（照合のときに差し引いて読むこと）: 開いていないのは `tools/l10n/source`・`docs/store/source-ja`・`docs/store/ja`・`GLOSSARY.md`・`REVIEW.md`・契約の §6.3・§10.4・§11.3・この文書の他の節の本文。審査メモの日本語の 3 行も読まずに飛ばした。ただし次の日本語は目に入った: 契約の §6.2 の用語集の表（日本語と英語の対応。訳し戻す前に読んだので、用語が元に寄った可能性がある）、`docs/store/en-US/whatsnew.txt` の最後の日本語の段落、`PRIVACY.en.md` の付録 B のカレンダーの許可の文（その前に該当キーの逆翻訳は 9 言語とも済んでいた）、`SUPPORT.en.md` の日本語の画面の道。

**次の版で**: 説明の最後の 1 文（訳は AI で母語話者の確認が無い）は 11 組とも説明の最後にあり、新機能の文の最後にもある（§6.1）。訳し戻しの作業は R の別の Claude がしているので、X と同じ見落としをする危険は残る。

## X2（照合。§6.1 の 3、§12.1 の X・R の行の X の後半。commit は C）

**やったこと**: R の逆翻訳（アプリ 9 言語 × 476 キー、ストア 11 組と審査メモ、英語の 3 文書の全文）を日本語の元と全部突き合わせ、`docs/i18n/REVIEW.md` に判定を書いた。アプリの文字列は ○ 3,797・△ 463・× 24。ストアと英語の文書の × は 0。× の訳は全部直し、`build.py` で生成した。

**直した訳（× の 24 件。R の 2 回目の対象）**:

| キー | 言語 | 何が違ったか |
| --- | --- | --- |
| `settings.weekStart.confirm.message.sunday`・`.monday` | fr・es・it・pt-BR・ko | 「いま書いてある週の手書き」が「今の週の手書き」「さっき書いた手書き」と読めた |
| `toast.weekStart.otherForm.one`・`.other` | fr・it | 「切り替えると見える」が落ちていた |
| `onboarding.dayPageTap` | en・fr・de・es・it・pt-BR | 「指で」が最後のダブルタップにしか掛かっていなかった |
| `demo.event.morningMeeting`・`dentalCheck` | de | Morgen（明日とも読める）→ Daily、Zahn（歯）→ Zahncheck |
| `demo.event.payday` | es | Pago（支払い）→ Nómina |
| `demo.event.farewell` | it | Saluti（あいさつ）→ Addio |

R が引っかかった語のうち、残りは △ にして理由を REVIEW.md の 7 に書いた（`Marcar`・`Fin`・`Annuler`・`Cancelar`・`Ablegen`・`24h`・`RDV`、de の `otherForm`、見本の語）。どれも幅の上限（F-7・F-12・F-15）か見本の語で、押した動きや読んだ意味が元と食い違わない。

**確かめ**: `toast.pinchHint` の向き・切り替えの文の向きと「消えない」・`regionChanged` の向き・入力の脚注は 9 言語で元と同じ。§10.4 の 23 キーは契約の表と機械で照らして、持ち主と日本語が同じ。ストアの文と `subscriptions` に月数の語は 0 件、逆翻訳に「か月分」は 0 件。ストアと英語の文書の画面の語は `translations` の値と機械で照らして同じ。`toast.weekStart.otherForm` の直しの後、Mac Catalyst の字で `ToolbarFitTests`・`PaperFitTests`・`WeekStartChoiceTests` の 38 本が通った（本当の判定は CI-0 のシミュレータ）。

**契約とずれたこと**:

- §6.4 は英語の 3 文書の食い違いの表を「L が REVIEW.md に足す」と書くが、L（LA・LA2）は済んだ役で、この作業の指示が X2 だったので X2 が照らした。× は 0 なので `docs/*.en.md` は変えていない。
- §6.1 の 3 の表（キー・元の日本語・逆翻訳・判定・直した訳）は、同じ逆翻訳の言語を 1 行にまとめた（REVIEW.md の 9。約 1,450 行）。ストアと英語の文書は、逆翻訳の全文が `docs/i18n/back/` にあるので、REVIEW.md には欄ごとの判定と理由だけを書いた。

**残っていること（R の 2 回目）**:

1. `python3 -I m7b-impl/R/work/changed.py` が出す 24 件を訳し戻す。
2. 審査メモの TestFlight と審査のビルドの段落（「In TestFlight and App Review builds …」）を訳し戻す。段落の中の日本語の「記録」のせいで、R の 1 回目の手順で飛ばされていた。§8 の 11 の確認表に載せる文なので要る。
3. その後で X が 24 件を判定する。`m7b-impl/X2/review.py` の `SECOND` に判定を足して流すと REVIEW.md が作り直される（1 回目の逆翻訳は `m7b-impl/X2/back.first/` に残した）。**§8 の 5 の「× が 0」はこの後**。

**次の役へ**: 訳を直すときは、`m7b-impl/X/tr/<言語>-*.tsv` を直して `m7b-impl/X/make_translations.py` を流し、`build.py` で生成する（`translations/*.json` を直接直すと、次に流したときに戻る）。

## R2（逆翻訳の 2 回目。§6.1 の 3、§12.1。commit は C）

**やったこと**: X2 が直した訳 24 件（it 6・fr 5・es 4・de 3・pt-BR 3・ko 2・en 1。zh の 2 言語は 0）と、審査メモの行 13（TestFlight の段落）を訳し戻した。アプリの文字列は `m7b-impl/R/work/overrides.json` に足して `assemble.py` で `docs/i18n/back/<言語>.json` と `m7b-impl/R/<言語>.md` を作り直した。審査メモは `docs/i18n/back/store-review-note.md` の 9 に入れた（前の 9〜12 は 10〜13 になる）。照合用の表は `m7b-impl/R2/back2.md`、書き換える前の写しは `m7b-impl/R2/before/`。判定はしていない（X がする）。

**1 回目の見落とし**: 1 回目は審査メモの「かな・漢字を含む行」を日本語の要約として飛ばした。行 13 は英語の段落で、日本語は題の 4 字だけなのに、一緒に飛んでいた。今回はその 4 字を伏せて読んだ。同じ見落としが他に無いかも見た。ストア 11 組で日本語を含むのは en-US の新機能の文の 1 行だけで、1 回目の `whatsnew.8` に入っている。英語の 3 文書は見出しごとの行数を比べた。差は冒頭の区切りの `---` の行と、SUPPORT の MIT ライセンスの英文（訳さない理由を（ ）で書いた所）だけだった。

**「日本語の元を見ない」の範囲**（照合のときに差し引いて読むこと）: 開いていないのは `REVIEW.md`・`tools/l10n/source`・`docs/store/source-ja`・`docs/store/ja`・`GLOSSARY.md`・`m7b-impl/X2/back.first`・`comment`・契約の §6.2・§6.3・§10.4。見えてしまったものは次のとおり。

- X2 の申し送りに、審査メモの段落は逆翻訳に「長押し」があれば通るとあった。逆翻訳はこの語を含む。英語の “touching and holding” の普通の訳だが、合格の条件を知って書いたことになる。`review.py` の判定は語の有無だけなので、**X は 9 の全文を読んで判定してほしい**。
- 逆翻訳を書き終えた後、`review.py` の読み方を調べる grep で、審査メモの節の行が 140 字まで見えた（題の字の一部と要約の一部）。段落はその前に書き終えていて、後から直していない。
- 同じ見落としを探す途中で、en-US の新機能の文の日本語の行を 1 行見た。24 件にも段落にも関係しない。
- キーの名前は見えている。de の `Daily` の括弧の「「朝」にあたる語は入っていない」は、`demo.event.morningMeeting` というキーの名前を知って足した注。語そのものの訳は「デイリー」。

## W（Web の規約類: 英語の 3 ページと日本語の 3 ページの直し。§6.5、§12.1 の W）

**置き場所**: Web リポジトリのブランチ `m7b-legal`（`r111-legal` の先頭 f3f9c95 から。作業の木は scratchpad の `wt-m7b-legal`）。push も merge もしていない。Web の main は 8e1dac7 のまま。

### 入れたもの

| commit | 中身 |
| --- | --- |
| ① ef14be5 | `app/en/terms.html`・`privacy.html`・`support.html`、`tools/check-legal.mjs`、`tests/app-pages.test.mjs` の (10) の英語の分 |
| ② bd8b70c | `app/terms.html`・`privacy.html`・`support.html` を今の `docs/*.md` の文に。`tests/app-pages.test.mjs` の (10) の日本語の分 |
| ③ 0a932b3 | 日本語の 3 ページの一番上に `English` のリンク（M7B-23。答えは「足してよい」）とそのテスト |

- **作り方**: 手で写さず、`m7b-impl/W/md2html.mjs` で Markdown からページを作った。同じ生成器で 1.1.1 の Markdown（31d243c）から作ったページが `r111-legal` の 3 ページと 1 バイトも違わないことを先に確かめた。**`docs/*.md` を後で直したら** `m7b-impl/W/regen.sh <Web の木> <wt-m7b>` で作り直す（③ のリンクは残る。`git diff` に Markdown の差だけが出る）。
- **`check-legal`**: `app/` の下を全部（下の階層も）見る。全部のページで `【`・`】`・`下書き`・`XX`・`Month DD`。`app/en/` はさらに `[`・`TODO`・`DRAFT`。
- **見出しの id の参照（P-4）**: 今の第 1 節・第 6 節の id を指すリンクは Web にも `wt-m7b` にも無かった（古い版の記録 `M*.md` は見ていない。直さない文書なので）。直す所は 0 件で、代わりに、ページの間のリンクの先の id がそろっているかを (10) で確かめるようにした。

### 契約からのずれ・契約が黙っている所の決め方

1. **(10) の日本語の分は ② に置いた**（契約は ① に (10) を入れる形）。§6.5 は「ja の同じ節があること」「ja に『EU には配信』が無いこと」も (10) に求めるが、それを ① に入れると「① だけでも緑」が守れない（① の日本語のページはまだ 1.1.1 の文）。条件で飛ばす形にはせず、英語の分を ①、日本語の分を ②、③ の分を ③ に置いた。
2. **Apple EULA の URL は `en/terms.html` にだけ求めた**（§6.5 は 3 ページに求めるように読める）。LA の節の「W」のとおりで、`PRIVACY.en.md`・`SUPPORT.en.md` に無い（日本語版も同じ）。
3. **`XX`・`Month DD` は `check-legal` と `npm test` の (10) の両方で止める**（§6.5 は `check-legal`、この作業の指示は (10)。`【】` は今までどおり `check-legal` だけ）。
4. **お知らせの節**: S-5 の行は ①・② に入れない。日本語は今の 1 行「現在、重要なお知らせはありません。」のまま。英語の節が空にならないよう、LA の最初の英語の 1 行 “There are no important notices at this time.”（d00dd86）を置いた。`docs/SUPPORT*.md` はどちらも S-5 の行なので、**この 1 行だけページと Markdown が違う**。
5. **Markdown に無い英語の字**: 頭の “Tegaki Calendar (App) / Last updated: …”、足の “Web version “手書きカレンダー” (in Japanese)”。`TERMS.en.md` の 1 行は日本語のページと同じ形に 2 行に分けた（“Effective date: …” の後ろの句点は落とした）。どれも R の逆翻訳の外。
6. **英語のページの CSS だけ 2 つ足した**: リンクの `overflow-wrap: anywhere`（`…/v0.107/CONTRIBUTORS` が切れずに iPhone の幅からはみ出していた）と、`support.html` の `pre`（MIT の文を折り返す）。日本語のページの CSS は変えていない（§6.4「足すのはこれだけ」）。
7. **言語の違うリンクに `lang`**: 「日本語版（正本）」に `lang="ja"`、③ の English に `lang="en"`（読み上げの声のため）。`hreflang` は付けていない。
8. **③ のリンクの場所**: 題名の上、`<main>` の最初の行。読めない言語のページで最初に目に入る所にした。③ のリンクは `docs/*.md` に無い（原稿を変えていない）。
9. **S-3 の「EU で購入を取り消すには？」はリンクにしない**（決めてよいと LA2-EU の節にあった）。ページの文を Markdown と同じに保つため。
10. **`app/index.html` と Web の README は変えていない**（§6.5 の対象の外。`index.html` の最終更新は 2026年10月31日 のまま、英語のページへのリンクも無い）。

### 確かめたこと（push・CI は無し。`npm test` はこの Mac の Node 24.20）

| 確かめ | 結果 |
| --- | --- |
| commit ごとに `git archive` で取り出して `npm test`・`npm run check:legal` | ① 627・② 631・③ 632 件とも失敗 0、`check-legal` は 7 ファイルで OK |
| ページの字と Markdown（`m7b-impl/W/check_text.mjs`。生成器を通らない別の道で、タグと記号を外して行ごとに照らす） | 6 ページとも並びが同じ。違う行は頭の最終更新と足のリンクと上の 4 の行だけ（空の欄の表の 1 行は道具の見え方の差） |
| ② の差分（`git diff --word-diff` を全部読んだ） | §6.4 の 4 つ、T-1〜T-9（T-8 は英語だけ）・P-1〜P-4・S-1〜S-4・S-6、§10.4 の FAQ と括弧、最終更新の日付だけ |
| §11.3 の文（`m7b-impl/LA2-EU/check_eu.py`） | 今の `docs/*.md` で問題 0。ページの字は上で Markdown と同じ |
| §6.4 の字の数（価格・試用・解約の道・連絡先・氏名など 13 の字、3 ページ、f3f9c95 と今） | 違うのは `support.html` の「14 日」0 → 1 だけ（S-4 の撤回の期間で、試用の字ではない） |
| MIT の文 | ページの `pre` を戻すと `LICENSE-python-holidays.txt` と同じ（末尾の改行のほか） |
| わざと壊す（写しの木で） | `XX`（日本語）・`Month DD`（英語）は `check-legal` と (10) の両方で止まる。`[`・小文字の `draft`・`TODO`・下の階層の `【` は `check-legal` で止まる。古い id へのリンク・EU の古い文は (10) で止まる |
| 外へのリンク（`curl -sI -L`、2026-11-05） | 200。`https://reportaproblem.apple.com/` だけ 403（1.0 からあるリンク。curl を断っているだけに見えるが、ブラウザでは確かめていない）。`app/en/support.html` は公開まで 404（予定どおり） |
| Apple の規約の URL（`…/itunes/ie/terms.html`） | `right of withdrawal` 3 件・`Right of withdrawal` 1 件・`Choose your country/region` 1 件。**公開の直前にリードがもう一度**（§6.5） |
| iPhone の幅（Chrome を画面に出さずに測った。`m7b-impl/W/measure.sh`） | 英語の 3 ページは 390 pt の幅ではみ出さない |

### 次の役へ

- **検証**: 英語のページの字は上の「ページの字と Markdown」のとおり `docs/*.en.md` と同じなので、文の中身は R の逆翻訳（`docs/i18n/back/legal-en.md`）と REVIEW.md の 5 で見られる。ページの形を見るのは上の 5〜8。
- **FIX**: `docs/*.md` を直したら `regen.sh` で作り直し、`npm test`・`npm run check:legal` を緑にして `m7b-legal` に commit を足す。
- **リード（公開の日、§11.1 の順 5）**: `m7b-legal` に次の commit を足してから merge する。(a) 6 ページの最終更新: `てがきカレンダー（アプリ版）／最終更新：2026年11月5日`・`Tegaki Calendar (App) / Last updated: November 5, 2026` を公開の日に。(b) `app/support.html` の `<li>現在、重要なお知らせはありません。</li>` を `<li>2026年M月D日：1.2 に合わせて、利用規約とプライバシーポリシーを更新しました。</li>` に、`app/en/support.html` の `<li>There are no important notices at this time.</li>` を `<li>Month D, 2026: We updated the Terms of Service and Privacy Policy for version 1.2.</li>` に（`M月D日`・`Month D` は実際の日付）。(c) `docs/SUPPORT*.md` の `XX`・`Month DD` と 6 文書の最終更新も同じ日に（`regen.sh` は S-5 の行を入れないので、(a)(b) の後に流さない）。(d) `npm test`・`npm run check:legal`。
- **リード（merge の順）**: `r111-legal` が先（§6.5）。1.1.1 を出す日に `r111-legal` の最終更新を直すと、`m7b-legal` を merge するときに 3 ページの最終更新の行がぶつかる。そのときは 1.2 の日付を取る。**1.1.1 の Web がまだ動く**（今の `r111-legal` は仮）ので、`r111-legal` に commit が増えたら `m7b-legal` に merge してから確かめ直す。
- **リード（公開の直前の確認）**: 見せる物は `git diff r111-legal..m7b-legal -- app/terms.html app/privacy.html app/support.html` の全文、英語の 3 ページの R の要点と上の 5 の字、③ のリンクの 1 行、URL（`app/en/terms.html`・`privacy.html`・`support.html` と日本語の 3 つ）。③ は M7B-23 の答えのとおり入れるが、§9 のとおりこの確認でもう一度聞く。

### 残る危険

- **日本語の `app/terms.html` は iPhone の幅で少しはみ出す**（`https://www.apple.com/jp/legal/…` の URL で、測った枠で約 402 pt。1.1.1 から同じで、1.2 で増えてはいない）。§6.4 の範囲の外なので直していない。英語のページと同じ 1 行の CSS で直せる。入れるなら公開の直前の確認で本人に聞く。
- 英語のページの文は、英語を母語とする人も法律の専門家も見ていない（D11、M7B-24 の答えのとおり、1.2 を出してから 1 年以内に 1 回専門家に聞く）。
- 英語のページの見え方は、この Mac の Chrome で 390 pt の幅を測っただけで、iPhone の Safari では見ていない。

## FIX（6 観点の検証の指摘の直し。§12.1 の FIX）

commit はしていない（commit は C）。push・CI も無し。Web の作業の木 `wt-m7b-legal` には書いていない（下の「Web」）。契約 `docs/M7B_CONTRACT.md` も変えていない（案文の直しはリードに渡す。下の「契約からのずれ」）。

### 直したもの: major（6 件。blocker は 0 件）

| 指摘 | 直し | 確かめ |
| --- | --- | --- |
| 自分で選んだ「自動」が次の同期で戻される | `WeekStartChoice.choose(_:_:)` を足した。設定の画面で選ぶと、記録と一緒に `weekStart.dataChecked` を立てる（印が先）。`WeekStartSettingsSection` の 2 か所をこれに替えた | 新しい `testChoosingAutoIsNotComparedAgain` が通る |
| `WeekStartUITests` が見出しを「土」「日」で探している（2 観点で同じ指摘） | テストの方を「土曜日」「日曜日」に。読み上げの名前は §4.2 のとおりなので変えない | 型だけ。実行は CI-0 |
| `LanguageUITests.testEnglish` の「October 2026」 | iPhone の題名は §3.1 の `yMMM` なので `hasPrefix("Oct")`・`hasPrefix("October")` でない・`contains("2026")` に | 型だけ。実行は CI-0 |
| REVIEW.md が R の 2 回目を反映していない | `m7b-impl/X2/review.py` の `SECOND` に 24 件の判定を足して作り直した。○ 20（切り替えの文 10・`otherForm` 4・`onboarding.dayPageTap` 6）、△ 4（見本の語 4 つ、理由つき）。審査メモの 9 も全文を読んで ○。**× は 0**（§8 の 5）。§1・§2・§4・§6・§7 の古い文も直した | 合計 ○ 3,811・△ 473・× 0。「R の 2 回目待ち」は 0 件 |
| de-DE のサブタイトルの Handschreiben（手書きの書簡） | 「Planer zum Schreiben von Hand」（29 字）、退き先の名前は「Tegaki: Handschrift-Planer」 | `write_store.py` と逆翻訳を更新、L-9 が通る |
| サポートのメールの扱いが公開する文で食い違う | `SUPPORT.md`・`.en.md` の「預からず確認後に削除」を「対応が終わったら消す（第 12 節）」に。`PRIVACY.md`・`.en.md` の第 12 節の受け取る物と AI に渡す物に添付を足した。`privacy-request.md` の表と文にも添付を足した | **Web は下の「Web」のとおりまだ** |

### 直したもの: minor

- **KitChecks**: G-4 に full と short が違う作り物の暦を足した（年は short、月・週・日は full。`YearLayoutEngine` を full に変えた写しで FAIL を確かめた）。「kit strings」の「ja だけか 10 言語全部」の緩みをやめた。**N は 29,432 → 29,436**。
- **祝日**: `HolidayFile.swift` の罠を塞いだ（`abs` をやめて範囲で比べる、`workdays` も見る、`years` と `epoch` の年は 1〜9999、振替の日に from が無いファイルは「読めない」）。`testBadInputNeverCrashes` に 15 通り足した。`gen.py` の `record_digest` が `../../../bin/` の行を除くようにした（venv の場所で `SOURCE.json` が変わらない。2 つの venv で `diff -r` が空。作業の木では `SOURCE.json` だけが変わった）。祝日がほぼ無い 4 地域を H の「弱い所」の表に足した。
- **週の始まり**: シートの閉じた直後でなく、次のシートが上がった後にトーストを見る（`weekStartNoticeDelay`、§10.4。初回のペイウォールがまだなら 4 秒、ほかは `sheetGap` ＋ 0.15 秒）。`checksAfterImport` は `.noAccount`・`.restricted` だけ（`.unknown`・`.notAuthenticated` は offline と同じく待つ）。L-13 に `demoPage(kind` を足し、`pageId(` は第 1 引数が `.day`・`.month`・`.year` の字以外を全部見る。`StrokeCensus.demo` に `weekStart` を渡した。
- **州の画面**: 今選んでいる行をもう一度押しても戻らなかったのを、親の `choose` に集めて直した。
- **`PaperFitTests`**: 「今日」の上限に切り替えと同じ 0.5 pt。
- **訳**: es（`kit.plan.savings.*` を usted に、`adopted`・`regionChanged`、`toast.event.noAccess`）、pt-BR（`regionChanged`、`otherForm`、`event.scribbleNote`・`event.titlePlaceholder`）、zh-Hans（3 語）、de（`holidayPicker.*` を Regionen に、`otherForm`）、it（`otherForm`、`demo.event.morningMeeting` を Riunione に）の 25 件。全部 `docs/i18n/REVIEW.md` の 10 に前の字と今の字がある。
- **375 pt の iPhone のトースト**: de・it・pt-BR の `otherForm` を短くして、Mac Catalyst の字で全部の文が 3 行に入る。
- **ストア**: de-DE の Konto → Account、Bundesland の文、it の `Le`、fr-FR の `name.txt` の退き先の改行しない空白。
- **`docs/support-replies/README.md`** の古い 1 文、GLOSSARY の 3 か所、REVIEW.md の fr の Annuler の理由（読み上げが同じ語になること）。

### Web（major の残り。リードの判断がいる）

この役の指示は「Web は W だけが `wt-m7b-legal` を使う」「commit は B11 と C だけ」なので、`wt-m7b-legal` には書かず commit も足していない（W の節の「FIX は `m7b-legal` に commit を足す」とは食い違う。指示の方を取った）。

- `git archive` で取り出した写し（`m7b-impl/FIX/web`）で `regen.sh` を流して、**`npm test` 632 件・失敗 0、`check:legal` OK** を確かめた。差は 4 ページの 6 行だけ。
- 当てる物: `m7b-impl/FIX/web-m7b-legal.patch`（`git -C wt-m7b-legal apply --check -p1` が通る）か、W の `regen.sh <Web の木> <wt-m7b>`。commit ④ を足すのは W かリード。**これを足すまで、Web のサポートとプライバシーの文は食い違ったまま**。公開の直前の確認で本人に見せる差分に入れる。

### 契約からのずれ

1. **§11.3 の P-2 の 2 文**（固定の案文）。リードが案文を次のとおり直す。P-3 は案文のまま残した（第 12 節に添付を書けば第 13 節の文はそのまま成り立つ。公開する文の差を増やさない）。`m7b-impl/LA2-EU/check_eu.py` はこの 2 文で「found 0 times」を出す（案文を直すまで）。
   - 「サポートにメールを送ると、開発者はあなたのメールアドレス、メールに書かれたお名前、本文、添付（画面の写真など）を受け取ります。…」／ “When you email support, the developer receives your email address, any name you write, the text of your email and any attachments (such as screenshots). …”
   - 「…日本語以外のメールを読むときと返事を書くときは、本文や添付を AI の翻訳（Anthropic の Claude）に渡すことがあります。」／ “… the developer may pass the text of your email and its attachments to an AI translation service (Claude, by Anthropic).”
2. **§10.3 の 4 に足す文**: 「利用者が設定で選んだら、判定はそこで終わり（`WeekStartChoice.choose` が `dataChecked` を立てる）」。§10.3 は「設定が auto で `dataChecked` がまだなら」としか書いていないので、今お使いの方が「自動」を選ぶ道が穴だった。
3. **§10.3 の 4 (1)**: アプリの形式の取り込みで判定するのは `.localOnly(.noAccount)`・`.localOnly(.restricted)` だけ（契約は `.localOnly` 全部）。
4. **§10.4 の「トーストの出し方」**: `sheetsChanged()` の機会は、シートが閉じた時でなく少し待ってから。
5. **§7.3 の表**: `testEnglish` の題名は iPhone の字（「Oct 2026」）。「October 2026」は iPad の写真（§8 の 8）で見る。
6. **§5.3**: 検査に `years`・`epoch` の範囲と、振替の日の from を足した（同梱の 250 ファイルは全部通る）。
7. **§2.7 の L-13 の一覧**: `demoPage(kind`、`pageId(` の第 1 引数の見方。
8. **§6.1 の 3（逆翻訳）**: FIX が変えた字の逆翻訳は FIX が書いた。FIX は日本語の元を読んでいるので「元を見ない」逆翻訳ではない。`R/work/changed.py` は 0 件を出すが、それはこのため（`assemble.py` は位置で行を合わせるので使わず、`docs/i18n/back/<言語>.json` を `m7b-impl/FIX/back.py` で直接直した）。
9. **F-16**: 「今日」の上限は ja の幅 ＋ 16.5（P のずれ 4 に書いた）。

### 直さなかった指摘と理由

| 指摘 | 理由 |
| --- | --- |
| 台湾（TW）に「2026 年は発表前の推定」と出る | **いちばん気になる残り**。検証の見立てでは事実に反し、zh-Hant の人に出る。ただし指摘自身が「リードが決める」で、直すには 1 次資料の確かめと、0-29・§7.1・`testYearNotes`・`HolidayChecks` の期待の変更が要る。`gen.py` の `NOTICE` から外す案なら `index.json` と `SOURCE.json` だけが変わる |
| es・pt-BR の `toolbar.tool.marker` を Marcador に、pt-BR の Desenhar に戻す | Catalyst の字では上限を超える（47.8 / 47.5）。本当の幅はシミュレータでしか分からず、戻すと CI を落とす危険があるので「安全で小さい」に入らない。CI-0 の `ToolbarFitTests` の値を見て FIX2 が決める |
| fr の `selection.deselect` の字（Annuler） | 略の Désélect. は読みにくい。REVIEW.md の △ の理由に、読み上げが同じ語になることを足した（指摘が認めている形） |
| `testWeekStartToastsFitThreeLines` の判定を 375 pt に | 字は 375 pt に入るようにしたが、判定は 402 pt のまま（it の `hiddenInk.other` は 311 pt の幅で最後の行が 310 pt。シミュレータで 1 pt 動くと落ちる）。375 pt はログに残る |
| `HeaderAndPaperUITests` の題名の識別子 | 指摘のとおり今は変えない。下の FIX2 への申し送り |
| `coverage_range` を直して 0 件の国を消す（250 → 247） | 影響が 250 の数字の全部に及ぶ。指摘の「最小の直し」の、表に書く方を取った |
| P-2 の「日本語以外の」の言い切り | 本人に聞くこと（下のリードの 3） |
| §12.4 の (8)、「今日から 1 週間」の日付、§11.1 の順 5 と S-5 の文、§11.6 の問い、SUPPORT.en の cancelled と Canceling | どれも契約か公開する案文で、指摘が「リードが決める」としている。契約はこの役では変えない |
| README・DESIGN・APPLE_ENROLLMENT の EU の文、`store-shots.yml`、M7B-23・24 の答えの記録、§11.8 の 175 の読み替え | C の担当（順番はこの後） |
| `demo.event.camping` の Acampar | 切れるかは写真でしか分からない。リードの確認の項目に（下） |

### 確かめたこと（この Mac。push・CI は無し）

| 確かめ | 結果 |
| --- | --- |
| `swift run KitChecks` | **all 29436 checks passed**（compat10 は 361 件・失敗 0） |
| `tools/typecheck/typecheck.sh`（外の空のフォルダ） | all OK・警告 0 |
| `python3 -I tools/l10n/lint.py .` | L-1〜L-14 すべて ok（L-12 は警告だけ）。`StrokeCensus` の `weekStart` を外した写しで L-13 が落ちることを確かめた |
| `build.py --check`・`baseline.py --check`（`/usr/bin/python3`） | 一致。基準は 516 行のまま |
| `shasum -a 256 -c tools/compat10/DATA_1_1.sha256` | 18 件 OK |
| アプリの XCTest を Mac Catalyst の代わりで全部（`m7b-impl/FIX/apprun`） | 428 本・33,136 件。失敗 8 件は test host でないと成り立たない既知の 2 本（`testMakeInTheTestHostIsInert`・`test00TestHostUsesTheFake`）だけ。`ToolbarFitTests`・`PaperFitTests`・`WeekStartChoiceTests`・`LocalizationBundleTests` は通った |
| `WorldHolidaysTests` を小さな代わりで（`m7b-impl/FIX/xct-hol`） | 23 本・2,341 件・失敗 0 |
| トーストの行数（`m7b-impl/FIX/measure`） | 10 言語の 8 種類とも、311 pt・338 pt で 3 行以内（数は `.one` が 1、`.other` が 99） |
| `gen.py` | 2 つの venv で `diff -r` が空 |
| `m7b-impl/X/check_terms.py` | 食い違い 0 |
| `@AppStorage` のキーに点があるとき、別の画面の `@AppStorage` に届くか（気になったので macOS の SwiftUI で実測、`m7b-impl/FIX/appstorage`） | 届く（`.onChange` も発火する。`UserDefaults.set` でも同じ）。`choose` はこれに頼っている。iOS では未確認で、本人の確かめ（§8 の 9 の 4b）で分かる |

**実行していないもの**: UI テスト（直した 2 本を含む）と本物の XCTest は CI-0 から。`.onChange` とシートの動き、州の画面の 2 段戻りも同じ。

### 次の役へ

- **C**: 閾値は N = **29,436** から（N − 50）。FIX が変えたファイルは、Sources の `Persistence/WeekStartChoice.swift`・`Persistence/StrokeCensus.swift`・`Views/WeekStartSettingsSection.swift`・`Views/HolidayPickerScreen.swift`・`Views/CalendarRootScreen.swift`・`Resources/Localizable.xcstrings`、TegakiKit の `Sources/DayKit/KitStrings.generated.swift`・`Sources/Holidays/HolidayFile.swift`・`Sources/KitChecks/main.swift`・`Tests/HolidaysTests/WorldHolidaysTests.swift`・`HolidayData/SOURCE.json`、tools の `holidays/gen.py`・`l10n/lint.py`・`l10n/translations/{es,pt-BR,zh-Hans,de,it}.json`、Tests の `TegakiCalendarTests/{WeekStartChoiceTests,PaperFitTests,CalendarRootScreenTests}.swift`・`TegakiCalendarUITests/{WeekStartUITests,LanguageUITests}.swift`、docs の `SUPPORT.md`・`SUPPORT.en.md`・`PRIVACY.md`・`PRIVACY.en.md`・`support-replies/{privacy-request,README}.md`・`store/de-DE/{name,subtitle,description,whatsnew}.txt`・`store/it/whatsnew.txt`・`store/fr-FR/name.txt`・`i18n/REVIEW.md`・`i18n/GLOSSARY.md`・`i18n/back/{es,pt-BR,zh-Hans,de,it}.json`・`i18n/back/store-{de-DE,fr-FR,it}.md`・`i18n/back/legal-en.md`、この文書。多くは他の役の未 commit のファイルと同じなので、そのまとまりに混ぜてよい。**F-1 の読み替え**: P のずれ 1 の 2 桁の今日の字の差は契約 §1 の「31 日」より広い。§11.8 の 3 の 174 は 0.107 では 175（H のずれ 2）。
- **リード**:
  1. `wt-m7b-legal` に上の「Web」を当てる（W を走らせるか、自分で commit ④）。
  2. §11.3 の P-2 と上の「契約からのずれ」を契約に入れる。
  3. **公開の直前の確認で本人に聞く**: 日本語のメールを Claude に読ませることは無いか（P-2 の「日本語以外の」の言い切りが守れるか。無いと言い切れなければ外す）。
  4. 台湾の「発表前」を決める（上の表）。
  5. 逆翻訳を元を見ない別の Claude にもう一度させるなら、対象は REVIEW.md の 10 の表（25 件とストア 6 欄、英語の 3 文）。`docs/i18n/back/` の `back` を伏せて渡す。
  6. **§8 の 11 の確認表に足す**: de-DE のサブタイトルと名前の退き先の新しい字。**es・es-ES・pt-BR の年の写真で「Acampar」が切れていないか**（AppKit で 42.5 pt、上限 42 pt。`PaperFitTests` は `demo.*` を測らない。切れていれば短い語に）。
- **FIX2（CI-0 の後）**: `HeaderAndPaperUITests` が「▶ once」で落ちたら、§7.3 の `tool.pen` と同じく、題名の `accessibilityIdentifier("page.title")` をやめて `LanguageUITests` の題名を別の探し方にする。`ToolbarFitTests` の値を見て、es・pt-BR の Marcador と pt-BR の Desenhar に戻せるかを決める。`testPDFRendersEveryKind` は Mac でバイトが揺れる（今回は通った）。

### 残る危険

- UI テストの 2 本の直しは型しか確かめていない。`app.staticTexts["土曜日"]` は `.accessibilityLabel` の付いた `Text` が staticTexts に出る前提で、CI-0 で初めて分かる。
- 訳の字の幅は Mac Catalyst の測りで、シミュレータとの差は CI-0 まで分からない。
- FIX の訳の直しは、母語の人の確認も、元を見ない逆翻訳も通っていない。

## C（統合・CI・文書・最後の確かめ。§12.1 の C）

**今の状態（2026-11-05）**: 実装は全部 `m7b` に commit した。push・CI・Web の公開・Connect への入力はしていない。main にも Web の main にも merge していない。**単体テストと UI テストはまだ 1 度も本物で走っていない**（次の CI-0 が最初）。基準は仮の `<1.1.1>`（31d243c）のまま。

### commit（`git add` はファイル名で。メッセージは日本語、最後の行は Co-Authored-By）

| commit | 役 | 中身 |
| --- | --- | --- |
| d85e399 | K2 | Kit の後半と週の始まり。FIX の Kit の直しを含む |
| 945aa4a | LA2 | 規約類・ストア・サポートの原稿の直し（EU の分と残りを 1 つに。同じファイルに両方が入っているため） |
| 20c6641 | S2 | アプリの文字列の移し、lint の残り、F-12〜F-15、取り込みと書き出しの週の始まり |
| 9ed9ceb | U | 祝日と週の始まりの設定と移行、ライセンス、写真モード、UI テスト |
| 9e2c89e | P | 紙と見出しの字、`PaperFitTests` |
| d48c6a1 | FIX | FIX だけが変えたファイル（`HolidayFile`・`WorldHolidaysTests`・`SOURCE.json`・`gen.py`）。ほかの FIX の直しは持ち主の commit に入っている |
| 8a108a1 | X・R（と W の記録） | 用語集・訳・ストアの 10 ロケール・逆翻訳・`REVIEW.md`・生成物 |
| 492e442 | C | `project.yml`・`build.yml`・`store-shots.yml` |
| 9adf328 | C | `README.md`・`DESIGN.md`・`APPLE_ENROLLMENT.md`・`M7_PLAN.md` |
| この節の commit | C | この文書の頭とこの節 |

- この文書と生成物は、B11 と同じく、commit ごとにその時点の中身を作って入れた（作業の木のファイルは変えていない）。この文書は「その役の節まで」、生成物（`KitStrings.generated.swift`・カタログ 2 つ）は「その commit の元から `build.py` で作った物」。8a108a1 で作業の木と同じになった。
- **途中の commit の確かめ**: d85e399 は `swift build` が通り、KitChecks は 29,436 件のうち「10 言語そろっている」の 44 件だけ落ちる（訳は 8a108a1 で入る）。9e2c89e（S2・U・P がそろう所）は下の表のとおり型の確かめが通る。S2 と U の commit は単独では組み立たないことがある（3 つを同時に作ったため）。全部の確かめは最後の commit で通した。

### 入れたもの

- **`project.yml`（§2.2）**: `developmentLanguage: en`、`MARKETING_VERSION "1.2"`、`SWIFT_EMIT_LOC_STRINGS: NO`、`CFBundleDevelopmentRegion: en`、`CFBundleLocalizations` に 10 言語、`TegakiKit/HolidayData` を `type: folder`・`buildPhase: resources` で、`TegakiCalendarTests` の依存に `Holidays`。残した行: `UIApplicationSupportsIndirectInputEvents`、`CURRENT_PROJECT_VERSION "1"`、PrivacyInfo の注記、日本語の `CFBundleDisplayName` と許可の文。**PrivacyInfo は変えていない**。
- **`build.yml`（§7.5。1.1.1 の上に）**: 頭のコメント、ジョブ 110 分、`JA_ARGS`、閾値 **29,386**（N 29,436 − 50）、段「Localization lint」「Data code frozen since 1.1.1」「The project's known regions」「Localized bundle check」「The app's l10n lines」、単体テストに `-testLanguage ja -testRegion JP`、写真の 3 段（`$JA_ARGS`・`env.txt`・シート 11）、UI テストの段 40 分と `l10n UI:`・`week-start UI:` の行、`compat-v1.0` に `tools/weekstart-compat` の 3 段、新しいジョブ `l10n-shots`（62 枚）。**`blank-paper` のジョブと `header-paper UI:` の grep は変えていない**。
- **`store-shots.yml`（§7.5）**: push のブランチ `store-shots` と workflow_dispatch。matrix で 11 組。成果物 `store-<組>`（30 日）。購入画面は撮らない。
- **`ja-baseline.yml` の相互の確かめ**: 変えていない。`diff_steps.rb`（名前の 9 / 11 sheets だけ読み替えた写し `m7b-impl/C/diff_steps.rb`）で、`Select Xcode` から `Store listing set` までの 13 段のうち 12 段の `run` が同じで、残り 1 段の差はシートの `holidays week-start` だけ。
- **README・DESIGN・APPLE_ENROLLMENT**: 版の行、1.1 の後半の分（Ink の 2 行、`InkPencilGestureRecognizer` の文、CI の `EraserAndBelowDayUITests`・repro の段）、言語・祝日・週の始まりの行、CI の説明、フォルダの中身。DESIGN は §2.3・§2.8・§3.9・§4.1・§4.8・§6.3・§8.3・§9・§10 の注記と新しい **§11 世界対応**（§11.1 言語・§11.2 祝日・§11.3 週の始まり・§11.4 EU）。「EU を除く」の文は本人の決定に直した。古い版の記録（`M5*`・`M6*`・`M7A*`）は直していない。
- **`M7_PLAN.md` 第 3 版（§6.8）**: §0・§4 の表に 1.1.1 と 1.2、新しい順、本文の版の番号、順の文、K-11 の全文と 1.2 の注記、§1.2 の 2 行、§1.3 の表に週の始まり、2/15 の決まり（中身の名前で）、次の版の訳とストアの分、1.3 の注（§10.6、主言語、nl-NL・sv）、CRA の見直し、B の 1 行（§0 の番号 4・§3 の H・§4.8 の頭・§5 の P-9）、155 本、P-12 は使わない。

### 節の記録の読み替え（各節は書いた時点の記録なので直していない。今はこう読む）

| 節 | 記録 | 今 |
| --- | --- | --- |
| C1 | 成果物 `ja-baseline-e7b4d2f`、写真 53 枚、シート 9 の段の名前 | `ja-baseline-31d243c`（本物の 1.1.1 で変わる）、**55 枚**。1.2 の `screenshots` は **57 枚**（13 インチに `sheet-holidays`・`sheet-week-start`）。J-4 で「新だけ」は `sheet-holidays` と `sheet-week-start` |
| C1 の「走らせ方」1 | `ja-baseline` の push で `build.yml` がもう 1 本走る | 走らない（`branches-ignore`。下のずれの 1） |
| K1・C1 | 段の名前「Data code frozen since 1.1」 | 「Data code frozen since 1.1.1」（§1.5） |
| K2 | N = 29,432、閾値 29,382 | **N = 29,436**（FIX）、**閾値 29,386** |
| LA の 7 | 第 3 条 4 項 | T-9 で直った（LA2-EU の節） |
| LA の 19・22、LA2-EU の「週は月曜始まり」 | 説明と審査メモの週の文 | LA2-rest の節 |
| H のずれ 2、契約 §11.8 の 3 | 契約は「175 のうち 174、無いのはコソボだけ」 | **0.107 ではコソボにもデータがあるので 175 全部にある**。`holidayCheckSoldRegions` は 175、H の節の表も 175 行。§11.8 の 3 の「M7B.md の表が 174」はこれで読む |
| 契約 0-13 など | 249 の国・地域 | **250**、254 ファイル（H） |
| P のずれ 1、契約 §1 | F-1 の数字の枠は「31 日」だけ違う見込み | 広げるのは今日のマスだけで幅は 0.1 em。2 桁の今日の字の差は「31 日」より広い。J-4 の写真の今日は 7 日なので、年の写真に差は出ない見込み（P のずれの 1・2 は実測を根拠に契約から変えた） |
| B11 | `InkCanvasViewTests` 3,057 行 | 3,371 行（1.1.1 の物が新しい凍結） |
| 契約 §7.5 | :411 のコメントの「22 shots」を 24 に | 25（1.1.1 で 23 になっていたので。下のずれの 3） |
| H の「次の役へ」の U と「残る危険」、U のずれ 2、FIX の「直さなかった指摘」と「次の役へ」の 4 | 台湾に「2026 年は発表前の推定」と出る。今年の例の文は台湾 | 出ない。今年この注記の出る国は無い（「TW」の節。TW は 2028 年から、KZ は 2027 年から）。例の文の今の形は `HolidayChoiceTests` の `testSummaryTexts` |
| この節の確かめ、K2 | KitChecks N = 29,436 | **N = 29,447**（「TW」の節で 11 件足した）。閾値 29,386 のままでも通る |
| FIX のずれ 1 と「Web」、下の残作業の 2・3 | §11.3 の P-2 の案文と Web がまだ | 済み。案文は直し（契約 §12.6 の 29）、Web は `m7b-legal` の cb9b78e で `docs/` と同じ。`check_eu.py` も「found 0 times」を出さない |
| FIX のずれ 2〜9、P のずれ 1・2・4、下のずれ | 契約に入っていない | 契約 §12.6 に入れた（下のずれの 9 は §12.6 の 33） |
| FIX の「リードの 3」、下の残作業の 5 | 日本語のメールを Claude に読ませることは無いかを本人に聞く | 聞く項目から外した。リードの既定で「日本語以外の」を外し、公開の直前の確認で新しい第 12 節をそのまま見せる（契約 §12.6 の 29） |
| FIX のずれ 8・「リードの 5」・「残る危険」の 3 つ目、下の残作業の 4 の逆翻訳 | FIX の訳の直しは元を見ない逆翻訳を通っていない | 2026-11-05 に 33 件を通した（○ 12・△ 19・× 2、× は de の 2 件で直した）。**直した de の 2 件だけは通っていない**。母語の人の確認は今も無い。`REVIEW.md` の 10 |
| FIX の `REVIEW.md` の数字 | ○ 3,811・△ 473・× 0 | **○ 3,809・△ 475・× 0**（it の `otherForm` 2 件が FIX の短い字で ○ から △ へ） |
| FIX の「直さなかった指摘」の §12.4 の (8)・「今日から 1 週間」・§11.1 の順 5 と S-5・§11.6 の問い・cancelled と Canceling | 契約か公開する案文なので FIX では直さない | 済み（契約 §12.6 の 24〜28。Web のつづりは `m7b-legal` の 88d4861） |

### 契約からのずれ・契約が黙っている所の決め方

1. **`build.yml` の `on.push` に `branches-ignore: [ja-baseline, store-shots]`**（C1 の申し送りの 3。契約に無い）。その 2 つの枝は別の workflow を動かすためだけの物で、同じ CI がもう 1 本走ると 4 ジョブ分の runner を取る。CI-0 の J-4 が比べる `screenshots` は `m7b` の run から取る。
2. **段を分けた**: `knownRegions` は「Generate the Xcode project」に足さず別の段に、`l10n:` の行は「Collect the app log」に足さず別の段に（どちらの段も `ja-baseline.yml` と 1 字も同じままにするため）。
3. **13 インチの枚数のコメントは 25**（上の表）。`--last 10m` のままで入る（1.1.1 の run で 13 インチの写真は 4.6 ＋ 2.0 分）。
4. **ジョブの上限は 110 のまま**。契約の式「e7b4d2f の時間 − UI の段 ＋ 3 ＋ 40 ＋ 10」は 57.6 − 9.6 ＋ 53 = 101。実際にいちばん長い 1.1.1 の run（41922318959）でも 67.9 − 11.9 ＋ 53 = 109。
5. **`grep` に `week-start UI:` も足した**（U の申し送り。契約の表は `l10n UI:` だけ）。
6. **`l10n-shots` の細部**（契約は枚数と引数まで）: 組み立ては `generic/platform=iOS Simulator` で 1 回。機種の選び方は `blank-paper` と同じ形（新しい iOS。13 インチは `iPad Pro 13-inch (M5)`、無ければ `iPad Pro 13`・`iPad Air 13` で始まる物）。boot の後に 120 秒（C1 の実測の通知のため）。訳し漏れの起動は **機種ごとに 1 回**、de の設定のシートで（契約は「1 回」。キーの多い画面で、de なら de と en の両方の漏れが出る）。`log show --last 40m` を両機種の分まとめて `pseudo/l10n-log.txt` に（§7.6 の書き方はどちらにも読める）。「`l10n: missing` のキーの数」「アプリの bundle の `not found in strings table` の行の数」「写真の数」「`l10n: holidays loaded` のいちばん遅い値」を Job Summary に。上限は 75 分のまま（見込み 30 分）。写真の失敗ではジョブを落とさない（組み立てが落ちれば落ちる）。
7. **`store-shots.yml` の細部**: `max-parallel: 4`（macOS の runner の同時の数を使い切らないように）、機種ごとに 120 秒待ち、4 ページを 2 回撮って後を残す（ストアの写真に通知を入れないため）、成果物 30 日、`overwrite: true`。言語の引数は契約の組の名前どおり `(en-GB)`・`(es-ES)`（iOS は `en`・`es` の `.lproj` を選ぶ）。
8. **`compat-v1.0` の段の場所**: ⑤ の後、XcodeGen の前（⑥ が `v10` に手を入れる前で、⑤ までの結果を変えない）。`git archive` でなく `actions/checkout`（`v10` と同じ）で取り出し、`run/` を中に写して `swift run`。上限 45 分は変えない（1.1.1 の run で 7.6 分。2 回の `swift run` の分は足りる）。
9. **C1 の勧め（13 インチの通知の待ち）と、`status_bar` の日付の固定は入れていない**。リードが決めることで、入れるなら `build.yml` と `ja-baseline.yml` の両方に同じ行で（C1 の節の「次の役へ」の 1・4）。今のままなら、通知の入った方を撮り直して比べる。
10. **`M7_PLAN.md` の「前の版の番号を残す」**: 見出しと表は「（計画の第 2 版では 1.2）」の形で残し、本文の 100 か所ほどには付けず、文書の頭に読み替えの表を置いた（読みにくくなるので）。§4 の 1.3 の規模は B_DESIGN §10 の段 0 と B-1 の和（4.35〜5.0）、1.6・1.7 は同じ節の値。§4.5 の確かめ直しの数字と次の版の訳の目安はリードの分のまま。`docs/B_DESIGN.md` は repo に入れていない（§6.8 のとおりリードが決める。1.3 の契約まで待ってよい）。凍結した Ink の 6 件と主言語は 1.3 の注に書いた。
11. **DESIGN は新しい §11 にまとめた**（契約は「言語」と「祝日」の節、「週の始まり」の節とだけ書いている）。今ある節の番号を動かさないため。
12. **LA2 を 1 つの commit に**（EU の分と残りが同じファイルに混ざっているため）。

### 確かめ（この Mac、Swift 6.4.2、Command Line Tools。`git archive HEAD` で取り出した木で。push・CI は無し）

| 確かめ | 結果 |
| --- | --- |
| `swift build --package-path TegakiKit` | 成功。新しい警告 0（`main.swift`:2256・2277・2308 の 3 つは e7b4d2f からある、この版の Swift だけの物） |
| `swift run --package-path TegakiKit KitChecks` | **all 29436 checks passed**。compat10 は 361 件・失敗 0。閾値 29,386 |
| `tools/typecheck/typecheck.sh`（リポジトリの外の空のフォルダ） | all OK・警告 0（アプリ、TegakiCalendarTests 34 ファイル、UI テスト 6、Kit のテスト 6 つ）。9e2c89e でも all OK |
| `python3 -I tools/l10n/lint.py .` | **L-1〜L-14 すべて ok**（Python 3.9.6 と 3.12.16）。L-12 の警告は 59 件 |
| `build.py . --check`・`baseline.py . --check`（`/usr/bin/python3`） | 一致（xcstrings。基準は 516 行・42 ファイル・31d243c） |
| `shasum -a 256 -c tools/compat10/DATA_1_1.sha256`、`FROZEN.sha256` | 18 件 OK、11 件 OK（D14、K-7） |
| `HolidayData` の 2 回の生成（`hol3/venv` の Python 3.12.16、`-I`） | 2 回の `diff -r` が空で、commit の 254 ファイルとも同じ（4.5 MB） |
| `tools/weekstart-compat`（README の形で） | 1.0（a21e469）failures 0、31d243c failures 0。終了の状態 0 |
| K-7・凍結 | `git diff --quiet 31d243c HEAD -- TegakiKit/Tests/Fixtures TegakiKit/Tests/Compat10 TegakiKit/Tests/CompatFixtures TegakiKit/Tests/Compat10Tests Tests/TegakiCalendarTests/InkCanvasViewTests.swift` が同じ。`Sources/TegakiCalendar/Ink` も同じ。`tools/compat10` の差は `DATA_1_1.sha256` だけ |
| J-2 | `git diff 31d243c HEAD -- Tests TegakiKit/Tests` の削除行は 3 行（`EventKitServiceTests` の `}`、`ScreenshotModeTests` の `Sheet.allCases` の 2 行。§7.2 のとおり）。日本語・`w-20`・`Monday`・`Sunday` は無い |
| §10.10 の 3・§11.8 の 1 と 2 と 4 の grep | 週の文 0 件、EU の文 0 件、「ß を使わず」0 件、定型文 7 つ |
| workflow の形（Ruby の YAML と `bash -n`、`check_workflow.rb`） | `build`・`ja-baseline`・`store-shots`・`testflight` の全部の `run` が通る。この Mac に actionlint は無い |
| `diff_steps.rb`（`ja-baseline.yml` と `build.yml`） | 写した 13 段のうち 12 段の `run` が同じ。残り 1 段の差はシートの `holidays week-start` だけ |
| 作り物の `xcrun`・`sleep` で段を動かした（`m7b-impl/C/sim`。本物の simctl ではない） | `l10n-shots`: 62 枚の名前が §7.6 と同じ、引数の組、Job Summary の数。`store-shots`: 8 枚の名前、引数、`sips` の JPEG と大きさの確かめ（違う大きさで警告）。「Localized bundle check」: そろった形で 0、`.lproj`・`US.json` が無い・`UK.json`・`ar.lproj` がある・カタログが変わった形でそれぞれ `::error` |

### CI で初めて分かること（§12.2 の CI-0。この Mac に XCTest と Xcode が無いので、ここまでは型と、Mac Catalyst の小さな代わりでしか確かめていない）

1. **組み立ての形**: XcodeGen が `TegakiKit/HolidayData` を `type: folder` で受けるか、`knownRegions` に 10 言語が入るか、String Catalog から 10 の `.lproj` ができるか。「Localized bundle check」が落ちたら、カタログは 0-4（`build.py --format strings`）、データは §2.2（`Resources/HolidayData`）。Xcode がカタログを書き換えないか（0-5）。
2. **本物の XCTest**: `swift test`（`Compat12Tests`・`WorldHolidaysTests`・`DateTextTests` などの ICU の字は macos-26 で違いうる。K1・K2 の「残る危険」）、アプリの単体テスト（`-testLanguage ja`、`LocalizationBundleTests`、`ToolbarFitTests`・`PaperFitTests` の幅。Catalyst の字との差）、`testPDFRendersEveryKind`（Mac でバイトが揺れた）。
3. **UI テスト**: `LanguageUITests`（iOS が選ぶ言語。特に pt-PT → pt-BR、0-2）・`WeekStartUITests`（`staticTexts["土曜日"]`）・`testEnglish`。`tool.pen` の後も `app.buttons["ペン"]` が見つかるか（§7.3）。`page.title` の後も `HeaderAndPaperUITests` が通るか（「▶ once」で落ちたら FIX の節の FIX2 へ）。段の時間（40 分に入るか）。
4. **`compat-v1.0`** の新しい 3 段（この Mac では同じ `swift run` が 16 件・18 件で通っている。`actions/checkout` で 31d243c を取れるかは本物で）。
5. **`l10n-shots`**: 62 枚そろうか、訳し漏れが 0 か（`-NSShowNonLocalizedStrings` の行の形はこの Mac で確かめていない。grep の語が違えば数が 0 のままになるので、1 回目は `pseudo/l10n-log.txt` を目で見る）。es・es-ES・pt-BR の年の写真の「Acampar」（FIX の節）。
6. **`ja-baseline.yml` の 1 回目**: 写真の手順の確かめ。`env.txt` が 2 つの run で同じか。
7. **数字**: `l10n: holidays loaded` の ms（目安 50 ms）、`repro: F-1 two digits`（P）、`ToolbarFitTests` が 38 pt を超えたと出す名前、F-15・F-16 の幅、ジョブの時間（110 分に入るか）。
8. **macos-26 の `python3`** で lint が通るか（3.9.6 と 3.12.16 では通る）。

### CI-0 の後に書く欄（§8 の 10。リードか FIX2 が埋める。分かっている物は埋めた）

| 項目 | 値 |
| --- | --- |
| e7b4d2f の CI | run 41264726309、ジョブ 57.6 分、UI テストの段 9.6 分、`EraserAndBelowDayUITests` 8 本とも合格、`repro: A17 PencilKit's drawingGestureRecognizer.allowedTouchTypes pencilOnly=[2] anyInput=[0, 2, 3]`、`repro: B8 PencilKit's pan.allowedTouchTypes=[0]`（direct 0、pencil 2、indirectPointer 3） |
| 1.1.1 の CI（参考） | run 41922318959（8d81b89）、ジョブ 67.9 分、UI テストの段 11.9 分、`compat-v1.0` 7.6 分 |
| `xcodegen --version`、`knownRegions` | CI-0 |
| Localized bundle check | CI-0（xcstrings か strings か、`HolidayData` の場所） |
| `LanguageUITests`（0-2 の pt-PT を含む）、週の始まりの地域の値 | CI-0 |
| 「言語」の項目が出る条件 | TestFlight（§2.1） |
| 祝日データを読んだ時間 | CI-0 |
| J-4 の 2 つの run の `env.txt`、写真の比較、F-1 の数字の枠 | CI-0 と本物の `<1.1.1>` の後（1.1 の CI の写真は英語の環境で撮っていたので、漢字が中国語用の書体だった） |
| ツールバーの L-12 の警告 | 今 59 件（全部で。ツールバーの分は 49 件）。字数 × 0.6 の目安で、本当の幅は `ToolbarFitTests`。一覧は `python3 -I tools/l10n/lint.py .` の出力 |
| `ToolbarFitTests` が 38 pt を超えたと出した名前、F-15・F-16 の幅 | CI-0 |
| `tools/weekstart-compat` | この Mac: 1.0（a21e469）16 件・失敗 0、31d243c 18 件・失敗 0。CI-0 |
| `englishPagesPublished` | false（1.2）。英語の規約の URL にするのは 1.3 の説明から（0-38）。公開の日に Connect の URL を替えたかは公開の日に |
| 記録のシート | 英語などの TestFlight と審査の端末でも、「バージョン」の長押しの記録は日本語で出る（§2.5、0-37。使うのは本人だけ） |
| `REVIEW.md` | ○ 3,809・△ 475・× 0（§8 の 5）。元を見ない逆翻訳（33 件）の後。de の `toast.weekStart.otherForm.*` の直した字だけは通っていない（`REVIEW.md` の 10） |
| 隠れる線のトースト | 本人の確かめ（§8 の 9 の 4d） |
| P-B9 の答え、1.3 以降の訳とストアの目安 | TestFlight の手順 13、リード（量の実測は「リード（2026-11-05 の後片付け）」の節。時間の実績は測っていない） |
| EU の届け出の日付と日数、`contentStatuses`、`PATCH` が効いたか、ロシアの店頭 | 公開の日まで（§11.1） |
| CRA の報告の手順 | 悪用された弱点か重大な事故が分かったら、本人が 24 時間以内に ENISA の窓口へ早期の警告、72 時間以内に通知する（零細企業は 24 時間の遅れに罰金なし。§11.6。リードが案内する） |

### 本人の答え（§11.8 の 6）

- **M7B-23**: 「足してよい」（(ア)、2026-11-05）。日本語の 3 ページの上に `English` のリンク（Web の commit ③ 0a932b3）。公開は 1.2 を出す日で、公開の直前に全文を見せる。
- **M7B-24**: 「予定どおり 1.2 で出す」（2026-11-05）。1.2 を出してから 1 年以内、遅くとも 2027 年 12 月より前に 1 回専門家に聞く（§11.6 の 2・5・8。問いはリードが英語の相談票にまとめる）。

### リードの残作業（順に）

1. **CI-0**: 1 回目が走っている（「リード（2026-11-05 の後片付け）」の節）。失敗は FIX2 へ（J と K-7 の期待は変えない）。その節の commit は次の push で初めて CI を通る。
2. **Web**: 済み（`m7b-legal` の cb9b78e、88d4861）。
3. **契約に入れる**: 済み（§12.6）。
4. **決めること**: 13 インチの通知の待ちと `status_bar` の日付の固定は CI-0 の写真を見て決める（§12.6 の 33）。`docs/B_DESIGN.md` は 1.3（B-1）を始めるときに入れる（§12.6 の 32）。残るのは、de の直した 2 件を元を見ない逆翻訳にもう一度通すか、`M7_PLAN.md` §4.5 の確かめ直しの里程（1.3 の契約のとき）。
5. **本人に知らせる**: 公開の直前の確認で、言語の限定を外した新しい第 12 節をそのまま見せる（§12.6 の 29）。中国の 2027 年（「TW」の節の「リードへ」の 1。1.2 に入れるか次の版か）。中国の行は「中国本土（2027 年は発表前の推定）」と出る（U）。
6. **§8 の 11 の確認表に足す**: de-DE の新しいサブタイトルと名前の退き先、es・es-ES・pt-BR の年の写真の Acampar。
7. **B11 の 2 回目**: `fix-1-1-1` は今 b2f34b5（ビルド 15）。31d243c からの差は `build.yml` の `blank-paper` の上限（45 → 55 分、36 → 46 分）と `docs/R1_1_1.md` だけで、この節の `build.yml` の変更とは別の行。木の差はそれだけなので、main に入ったら手順 8 の軽い方で済む見込み（`git diff 31d243c main` で確かめる）。
8. その後は §12.2 のとおり（`ja-baseline.yml` の 2 回目 → J-4 → 写真の確認ページ → TestFlight → `store-shots` → 確認表 → 入力 → merge の「はい」→ 提出 → 公開の日）。`store-shots` は `git push origin m7b:store-shots`。

## TW（祝日の「発表前の推定」を 1 次資料で照らした。2026-11-05。commit は Record）

FIX と C の節に残した「台湾に 2026 年は発表前の推定と出る」を確かめて直した。カザフスタンも同じだった。データで変わったのは `index.json` の 2 つの数（TW 2025 → 2027、KZ 2025 → 2026）と `SOURCE.json` で、国のファイルは 1 つも変わらない。

### 7 か国（2026-11-05 の時点）

「注記の最初の年」は `lastOfficialYear` ＋ 1。設定の行と選ぶ画面の年は今年なので、2026 年の今は 7 か国とも出ない。

| 国 | ライブラリの表の最後の年 | `lastOfficialYear` | 注記の最初の年（前 → 今） | 政府の公表 | データとの照らし |
| --- | --- | --- | --- | --- | --- |
| TW | 2025 | **2027** | 2026 → **2028** | 115 年（2026）は 114.06.13、116 年（2027）は 115.05.21 に公表 | 2026 年 22 日・2027 年 24 日が全部同じ（公表の CSV と機械で照らした）。補行上班は両年 0 |
| KZ | 2025 | **2026** | 2026 → **2027** | 2026 年は政府のサイトの頁（22.04.2026 更新）。2027 年は確かめられなかった | 2026 年 19 日が全部同じ（頁の文を読んで照らした） |
| BY | 2026 | 2026 | 2027 | 2027 年は公表済み（閣僚会議決定 499 号、2026-10-03。5/10 の勤務を 5/8 へ） | データに入っていない。直さない |
| CN | 2026 | 2026 | 2027 | 2027 年は**今日**公表（国办发明电〔2026〕10号、2026-11-05） | データは規則の推定で合わない（春節は 2/5〜2/13 の 9 日、データは 2/5〜2/8。出勤 1/31・2/14・5/8・9/26・10/9 はデータに無い）。直さない |
| VN | 2026 | 2026 | 2027 | 2027 年は公表済みの報道（内務省 11483/TB-BNV、2026-10-09。1 次資料の頁は読めなかった） | 報道の Tet 2/4〜2/10・Quốc khánh 9/2・9/3 はデータと同じ。直さない |
| UZ | 2026 | 2026 | 2027 | 2027 年の決定は見つからない（2026 年の PF-257 は 2025-12-24 だった） | — |
| RU | 2027 | 2027 | 2028 | 確かめていない（2027 年はライブラリにある） | — |

### 見た 1 次資料

- **台湾・公表の日**: `https://www.dgpa.gov.tw/informationlist?uid=30`（一覧。114.06.13 の 115 年、115.05.21 の 116 年）、`https://www.dgpa.gov.tw/information?uid=41&pid=12573`（115 年。行政院院授人培字第 11430248312 號函）、`https://www.dgpa.gov.tw/information?uid=30&pid=12982`（116 年。院授人培字第 1153026132 號函。紀念日及節日實施條例 第 8 条の「逢例假日者，應予補假」と「調整放假及補行上班日期…由目的事業主管機關調移並公告之」も載っている）。
- **台湾・日の照らし**: 行政院人事行政總處が `https://data.gov.tw/dataset/14718` に載せている CSV（`dgpa/files/202506/a52331bd-…csv` が 115 年、`dgpa/files/202607/f538b1ff-…csv` が 116 年。365 行ずつ）を読み、`m7b-impl/TW/compare_tw.py` で `TW.json` と 1 日ずつ比べた。「公表にだけある日」「データにだけある日」とも 0。
- **カザフスタン**: `https://www.gov.kz/article/33969?lang=ru`（政府のサイト「2026 年の祝日と休日」、公開 05.01.2021・更新 22.04.2026）。1/1・1/2・1/7、3/8→3/9、3/21〜23→3/24・25、5/1、5/7、5/9→5/11、5/27、7/6、10/25→10/26、12/16。憲法記念日は載っていない。**読めなかった**: `egov.kz`・`adilet.zan.kz`（WebFetch では題だけ）、`web.archive.org`（取れない）。だから法律の本文（報道が 306-VIII 号と言う、憲法記念日を 3/15 へ移す法律）は読んでいない。ライブラリは 2026 年に憲法記念日を置かず（2027 年から 3/15）、政府の頁と同じ。2025-12 の省の暦（`gov.kz/uploads/2025/12/5/…doc`）には 8/30→8/31 があるが、22.04.2026 の更新の前の物。4 月より後の決定は 1 次資料で確かめられず、2026-10-27 の報道（digitalbusiness.kz）に「年末まで移し替えは無い」とあるのが根拠。
- **ベラルーシ**: `https://etalonline.by/document/?regnum=C22600499`（国の法情報センターのサイト）。**中国**: `https://www.news.cn/politics/20261105/f90cd6ad4df94ab4833b141e52ccfc13/c.html`（新華社の受権発布。中国政府網の本文は見ていない）。**ベトナム**: `baochinhphu.vn` などの検索の結果と `cafef.vn` の記事。`moha.gov.vn` の頁は中身が取れなかった。**ウズベキスタン**: `lex.uz`・`president.uz` の検索で 2027 年の物は出なかった（無いと確かめたわけではない）。

### 契約からのずれ・決めたこと

1. **`NOTICE` から外さなかった**。リードの案（外す）より、`gen.py` に `PUBLISHED_AND_COMPARED = {"KZ": 2026, "TW": 2027}` を置き、`lastOfficialYear` をライブラリの表とこの年の大きい方にした。理由: (a) どちらも毎年の公表で動く国のまま（台湾は条例 第 8 条に調整放假と補行上班の公告があり、表は 2025 年まで毎年のように年がある。カザフスタンは労働法 85 条 3 項で移し、2025 年は 1/5 を 1/3 へ）。外すと、まだ公表の無い年（TW 2028・KZ 2027）の本当の「発表前」まで永久に言えなくなる。(b) 表に年が無いのは「動かす日が無かった」からで、0-29 の国の一覧が間違っていたのではない。(c) 発表前の国の見本を替えずに済み、確かめは弱くならない。変わるファイルは案と同じ（`index.json` と `SOURCE.json`）。外す案にするなら `NOTICE` から 2 つ消して、この値と期待を戻せばよい。
2. **台湾は 2027 まで上げた**。2026 だけ上げると、2027 年の 1 月に、公表済みで日も合っている年に「発表前」と出る。
3. **`HolidayChecks` に公表の日をそのまま書いた**（11 件増）。新しいライブラリの版で 1 日でも動けば止まる。XCTest は注記だけ。
4. **名前の差は直さない**（日は同じ）。公表の「小年夜」はデータでは「農曆除夕」（2026-02-15、2027-02-04）、「孔子誕辰紀念日/教師節」は「孔子誕辰紀念日」、「清明節」は「民族掃墓節」。どれもライブラリの名前。
5. **KZ の 2026-05-27 Құрбан айт の「（推定）」は残した**。政府の頁は 5/27 と言っているが、これは年の注記でなくイスラム暦の日の印で（0-17）、ライブラリの確定の年が 2025 まで。もう過ぎた日。

### 確かめ（この Mac、push・CI は無し）

| 確かめ | 結果 |
| --- | --- |
| `gen.py` を 2 回（`hol3/venv`、`-I`、`--previous` は木の `HolidayData`） | `diff -r` が空。木と違うのは `SOURCE.json`・`index.json` だけ。`index.json` の差は KZ と TW の `lastOfficialYear` の 2 つだけ（`compare_index.py`） |
| `swift run --package-path TegakiKit KitChecks` | **all 29447 checks passed**（29,436 ＋ 11）。compat10 は 361 件・失敗 0 |
| `tools/typecheck/typecheck.sh`（外の空のフォルダ） | all OK・警告 0 |
| `python3 -I tools/l10n/lint.py` | ok（L-1〜L-14） |
| `shasum -a 256 -c`（`DATA_1_1.sha256` の 18 行。cwd を変えないよう、同じ hash で名前だけ絶対パスにした写しで） | 18 件とも一致 |
| XCTest（`HolidayChoiceTests`・`WorldHolidaysTests`） | **走らせていない**（型の確かめだけ。CI で） |

### リードへ

1. **中国の 2027 年**: 通知が今日出た。データに入るのはライブラリの次の版を取り寄せた後で、取り寄せは毎回本人の了承が要る（§5.11）。今のままだと 2027 年の 1 月から、中国の人に、もう公表された年について「2027 年は発表前の推定」と出て、9 日の春節が 4 日に見え、出勤日も出ない。ベラルーシ（5/8）とベトナムも注記の文は同じ。1.2 に入れるか次の版かはリードと本人が決める。
2. CI-0 の 1 回目はこの変更の前の commit で走っている。この節の変更（`HolidayChoiceTests`・`WorldHolidaysTests` の期待）は次の CI で初めて XCTest を通る。
3. 閾値は 29,386 のままで通る。規則（N − 50）に合わせるなら 29,397（`build.yml` は C の物なので変えていない）。

## リード（2026-11-05 の後片付け。commit は Record）

CI-0 の 1 回目が走っている間に残りを片付けた。push・公開はしていない。main と Web の main は触っていない。Things・App Store Connect・メールも触っていない。

### CI-0

| run | 番号 | 状態 |
| --- | --- | --- |
| `build.yml`（`m7b`。`origin/m7b` は 1d2b511） | 42013412254 | 走っている途中。結果はこの節を書いた時点で見ていない |
| `ja-baseline.yml`（枝 `ja-baseline`） | 42013415033 | 同じ |

**この節の commit は 1 回目に入っていない**。XCTest を初めて通るのは次の push から（`HolidayChoiceTests`・`WorldHolidaysTests` の新しい期待、de の 2 件の字）。C の節の「CI-0 の後に書く欄」は **FIX2 の後に埋める**。

### commit（push なし）

| commit | 枝 | 中身 |
| --- | --- | --- |
| 54fd8df | `m7b` | 元を見ない逆翻訳 33 件と判定、de の `otherForm` の直し、生成物、`REVIEW.md`、`back/*`（P-2 の分も入っている） |
| 159d8aa | `m7b` | 祝日の注記（TW 2027・KZ 2026。`gen.py`・`index.json`・`SOURCE.json`・`HolidayChecks`・テストの期待） |
| 2e67c65 | `m7b` | プライバシーの第 12 節と定型文（P-2）、`SUPPORT.en.md` のつづり |
| この節の commit | `m7b` | 契約 §12.6、`M7_PLAN.md` §4.5、この文書 |
| cb9b78e（P2 の役）、88d4861 | `m7b-legal` | Web の P-2 と FIX の分、`en/support.html` のつづり |

### 1. 契約

- **新しい §12.6「第 4 版の後の読み替え」**（33 項）を §12.5 の後に足し、頭に 1 段落、該当の節に「→ §12.6 の n」を足した。番号は動かしていない。中身: FIX のずれ 2〜9（1〜8）、P のずれ 1・2・4（9〜11）、この役が読んで確かめた C のずれ（12〜22）、数と文の読み替え（23〜28）、リードの決定（29〜33）。
- **本文も直した所**: 「今日から 1 週間」を 2026-11-11 に（§9・§11.1 の順 1・§11.4・§11.7）、§11.1 の順 5 と S-5 を「置き換える」に（`docs` は `XX`・`Month DD` のまま。置き換え忘れは検査で止まらないと書いた）、§12.4 の (8) を §11.1 の順 8 に合わせた、S-4 の英語のつづり。§11.6 に検証（eu-legal）の問い 5 つ（4・9 に足し、11〜13 を新しく）。法律の判断は足していない。

### 2. SUPPORT.en の cancelled と Canceling

本当に揺れていた（S-4 の 2 番の “can be cancelled”、3 番の “Canceling”。ほかに cancelled の字は無い）。`SUPPORT.en.md` の他の語（color・license）とアプリの英語（“refunded or canceled”）が米国のつづりなので “canceled” にそろえた。直したのは契約の案文、`docs/SUPPORT.en.md`、Web の `app/en/support.html`（`regen.sh`）の 1 語ずつ。公開前で、意味は変わらない。契約の §11.9 の Apple の文の引用の “cancelled” は引用なので変えていない。

### 3. `M7_PLAN.md` §4.5 と 1.2 の実測

「確かめ直しの数字」は B_DESIGN §10 から出す里程の数字で、**実測では埋まらない**（§10 に確かめ直しの行が無く、1.3 の実績も無い）。なので里程は埋めず、Xcode 27 へ移す最初の CI がもう一度通す量を書いた。里程は 1.3 の契約を書くときにリードが入れる。

| 項目 | 2026-11-05 の実測 |
| --- | --- |
| `KitChecks` | 29,447 件（閾値は `build.yml` の 29,386） |
| キー | 495（アプリ 432: P 32・S 229・U 171、Kit 63: K 61・H 2）。カタログは `Localizable` 430・`InfoPlist` 2 |
| 訳 | 476 キー × 9 言語 = 4,284 件。`REVIEW.md` は ○ 3,809・△ 475・× 0 |
| 表示の言語 | 10 |
| ストアのロケール | 16（ja と 15）。写真の組 11 |
| `HolidayData` | 254 ファイル、250 の国・地域、4,228,506 バイト（`du` で 4.5 MiB） |
| テストのファイル | アプリの単体 34、UI 6（XCTest の本数は CI-0 で） |
| 定型文 | 7 |

1.3 以降の「訳とストアの目安」の材料にもなる。**時間の実績は測っていない**ので、目安の里程は書いていない。

### 確かめ（この節の commit の前の木。この Mac。commit の後の確かめは Record の報告に）

| 確かめ | 結果 |
| --- | --- |
| `swift run --package-path TegakiKit KitChecks` | all 29447 checks passed。compat10 は 361 件・失敗 0。販売中の一覧は 175 で XK を含む |
| `python3 -I tools/l10n/lint.py` | L-1〜L-14 すべて ok（L-12 は目安の警告だけ） |
| `build.py --check`・`baseline.py --check`（`/usr/bin/python3`） | 一致。基準は 516 行・42 ファイル・31d243c |
| `shasum -a 256 -c`（`DATA_1_1.sha256` の 18 行。同じ hash で名前だけ絶対パスにした写しで） | 18 件とも一致 |
| `m7b-impl/LA2-EU/check_eu.py` | OK: no problems（直した契約と 6 文書の字が合う） |
| Web: `npm test`・`npm run check:legal` | 632 件・失敗 0、OK（7 files）。`regen.sh` の差は `en/support.html` の 1 語だけ |
| **走らせていないもの** | typecheck（この節で Swift は変えていない。TW の節で通した後に変わったのは訳だけ）、本物の XCTest・UI テスト・シミュレータ（CI-0 から） |

### 残り

1. **CI-0 の結果を書く欄は FIX2 の後**。
2. **本人に報告する**（公開の直前の確認で）: 第 12 節の言語の限定を外したこと（§12.6 の 29）。**決めてもらう**: 中国の 2027 年（「TW」の節。ライブラリの次の版の取り寄せは本人の了承が要る）。
3. **リードが決める**: `build.yml` の閾値を 29,397 に上げるか（今のままでも通る。コメントも 29436 のまま）。de の直した 2 件をもう一度逆翻訳させるか。fr の `toast.weekStart.otherForm.other` が日曜・10 ページ以上・311 pt で 4 行になる件（Catalyst の測り。`REVIEW.md` の 10。CI の判定は 402 pt）。pt-BR の `regionChanged.sunday` の semanas de segunda（△ のまま）。`support-replies/README.md` に日本語のメールを Claude に渡すときの手順が要るか。
4. `M7_PLAN.md` §4.5 の里程、C の節の「リードの残作業」の 6〜8（確認表、B11 の 2 回目、その後の順）。

## FIX3（CI の 1 回目の写真の確認で残った指摘の直し。2026-11-05）

CI の 1 回目（`build.yml` は全部緑、run 42013412254。`ja-baseline.yml` は run 42013415033）の写真を別の役が開いて判定した KEEP の指摘（major 0・minor 5・note 17）のうち、リードが頼んだ分を直した。**push していない。CI はこの節の変更をまだ通っていない**。ja の見た目は変えていない（下の確かめ）。凍結の 18 ファイル、`InkCanvasViewTests`、`Compat10`・`Fixtures`、既存の月曜の期待、K-1〜K-11 は触っていない。

### commit（push なし）

| commit | 中身 |
| --- | --- |
| bd30ad8 | 週の見出し（1・3） |
| 318eac1 | 振替の型の名前（2） |
| 472b65f | 見本の語（4） |
| c620c78 | 撮影の揺れ（5）、課金画面（6）、閾値 |
| この節の commit | 契約（§12.6 の 33・35〜40 と本文）、`M7_PLAN.md` の件数、この節 |

### 直したもの

1. **pt-BR の週の見出し（`dom` が「d...」）**: 3 字の曜日の言語は、曜日を数字の上に置く（`PaperWords.weekColumnStacksWeekday`）。7 列とも 12 pt で、切れない。ピンチの途中で高さが変わらないよう、列の幅でなく言語で決める（全部のズームと機種で同じ形。iPad の `dom.` も数字の上）。行の高さは 48 → 約 52 pt。1 日の列も曜日を出す。**案を変えた理由**: 案は「数字の枠を 28 に」か「8 pt 固定」。この Mac の字で `dom` は 12 pt の medium で 26.2 pt、bold で 27.2 pt。CI の写真の iPhone 17 の列は 53.7 pt（幅でなく紙の範囲の高さでズームが決まる）で、数字の横の残りは 15.7 pt。枠を 28 にしても 8 pt 前後になり、狭い iPhone の列（高さの見積もりで 40 pt ほど）では入らない。数字の上なら 40 pt の列でも 12 pt のまま入る。`PaperFitTests.testWeekColumnWeekdaysFit` が測る。
2. **振替の型の名前**: `.substituted` のとき `%s` を埋めず、`full` も `short` の字（「休息日」「放假日」「Day off」）。実データを全部読んだ（`m7b-impl/FIX3/subst.py`）: flags 4 の名前があるのは 15 か国（AM AZ BG BY CN HU KG KZ LV MM RU TW UA UZ VN）、どの国も全部の列に `short` があり、**国のファイルは変えずに済んだ**。JP には flags 4 が無い（J-4 に関係しない）。TW の「國慶日（補假）」（flags 2）、米国の「(observed)」、推定の印は別の型で巻き込まない（`HolidayChecks` の既存の期待のまま）。`substFrom`・`substFmt`・型はファイルに残し、読むときの検査だけに使う（`CountryHolidays` の `filled`・`substFormat`・`substFrom`・`addFrom`・`pairs` は消した）。`HolidayChecks` に 15 か国 × 10 言語 × 全部の年の確かめを足した。§7.4 の「2026-10-07 は祝日なし」は、9 言語の地域と英国・スペイン・日本で照らして「中国だけ休息日」に直した。
3. **週の見出しの祝日名**: ja 以外は `ViewThatFits(in: .horizontal)` で、`full` が列に入らなければ `short`（「国庆节（补假）」→「国庆节」、「國慶日（補假）」→「國慶日」、ko の「개천절」）。`DateLabel.holidayShortName` を足した（週のページだけ値がある）。ja の道は 1.1 の 1 つの `Text`。日本の名前は `full` と `short` が同じ（KitChecks の J-5 と、足した F-9 の確かめ）。
4. **見本の語**: es の camping を Carpa、pt-BR を Tenda、es の deadline を Plazo、it を Scad.。Mac Catalyst の 10 pt semibold で 31.2・31.5・28.5・29.6 pt（年のチップの上限 42 pt。週の 1 日の帯に入っている pt-BR の Prazo は 29.8 pt）。`REVIEW.md` の 7・9・10、`back/*`。判定は △ のままで合計の数は変わらない。**元を見ない逆翻訳は通っていない**。
5. **撮影の揺れ**: 13 インチの写真の段の最初で、アプリを前に出して 120 秒待つ（`build.yml` と `ja-baseline.yml` に同じ行。`--last 10m` は `14m`）。理由は下の「揺れの原因」。`status_bar` の日付の固定は入れない（§12.6 の 33 に理由）。
6. **iPhone の課金画面**: `l10n-shots` に `de/iphone-portrait-sheet-paywall.png`（63 枚）。`LanguageUITests.testGermanPaywallReachesItsLinks`（起動 1 回）: 下まで送り（最大 6 回）、購入の復元・利用規約・プライバシーポリシー・EULA・下の「あとで」の 5 つが、ドイツ語の字のとおりで、`isHittable` で、枠が窓の中にあることを見る。自動更新の説明も枠が窓の中にあり、字が de の文で始まることを見る。写真を 2 枚残す（`paywall-de-top`・`paywall-de-bottom`。`screenshots/ui-tests/attachments`）。リンクは押さない（Safari に出るため）。写真モードの購入の復元は何もしないので、押しても確かめにならない。`PaywallSheet` に `accessibilityIdentifier` を 6 つ足した（`paywall.restore`・`.terms`・`.privacy`・`.eula`・`.laterBottom`・`.disclosure`。絵は変わらない）。
7. **確認表の文**: §8 の 8 の表の 5 行（日本語の設定と祝日のシート、en の日、de の設定、pseudo の課金画面）を実物に合わせて書き直し、iPhone の課金画面の行を足した。

### 揺れの原因（CI の 1 回目の記録を読んだ）

- **月の写真に手書きが無い**: `ja-baseline` の `app-log.txt` で、最初の起動（pid 15125、10:55:19.08 に起動）は `(Metal) Metal Compiling Shader` が 34 回あり、最後は 10:55:37.95（起動から 18.9 秒）。写真は `simctl launch` が返ってから 8 秒後。2 回目の起動（pid 15803）は 0 回。1.2 の run の最初の起動は同じ 34 回が 1 秒で終わっていて、手書きが写った。つまりインストール後の最初の起動だけが遅れうる。**写真の時刻そのものは見ていない**（`ja-baseline` のジョブの記録が手元に無く、起動と 8 秒からの推定）。
- **週の写真の通知**: C1 の読みのとおり。boot の段の終わりから約 85〜105 秒。
- **待ちの起動**はこの 2 つを先に済ませる。段の長さは CI の 1 回目で 8.9 分（11:04:11〜11:13:07）で、2 分足すと約 11 分なので `--last 14m`。

### 契約からのずれ

契約 §12.6 の 33・35〜40 に入れた。案を変えたのは上の 1 だけ。F-9 の「0.6 までの縮小」は pt-BR だけ外れる（数字の上の曜日は縮む必要が無い）。

### 節の記録の読み替え

| 節 | 記録 | 今 |
| --- | --- | --- |
| C の節、「リード」の節 | KitChecks 29,447、閾値 29,397 | **29,470**、閾値 **29,420**（足したのは F-9 の 5 件、振替の 16 件、CN の 2 件で 23 件） |
| C の節の「CI で初めて分かること」の 5、C と FIX の節の「残作業の 6」 | `l10n-shots` 62 枚、es・es-ES・pt-BR の年の写真の Acampar を見る | 63 枚。Acampar の項目は要らない |
| C1 の「読み方」 | 通知の入った方を撮り直す | 待ちを入れたので入らない見込み。入ったら今までどおり撮り直す |
| C の節の「ずれ」の 9、「リードの残作業」の 4 | 13 インチの通知の待ちは入れていない、CI-0 の写真を見て決める | 入れた（§12.6 の 33）。日付の固定は入れない |
| C1 の「次の役へ」の 1 | 両方の `10m` を `12m` に | `14m`（CI の 1 回目で段が 8.9 分かかった） |

### 次の版の候補（直さなかった note。判定の KEEP note のうち）

| 写真の指摘 | 今の見方 | 次にすること |
| --- | --- | --- |
| iPhone の道具の説明が語の途中で切れる（de「Löscht be」、fr「Efface le t」など） | 枠の幅は言語によらず、横に送れる作り（`ToolbarView`）。1.2 で新しく出た切れではないと見ているが、日本語の iPhone の消しゴムの写真が無く比べていない | 日本語の iPhone の `tool-eraser` を 1 枚撮って比べる |
| it の 11/1 が「Giorno dell'unità nazionale · …」で始まり「Ognissanti」が見えない | **データの日付は誤りと言い切れない**。`IT.json` は 11 月の最初の日曜に置いている（2024-11-03、2025-11-02、2026-11-01、2027-11-07。11/4 には無い）。1977 年の法 54 号が「11 月の最初の日曜に祝う」としているのと同じ（この本文は検索の要約で読んだだけ）。2024 年の法 27 号は 11/4 を「国民統一と軍隊の日」と認め、休日の効果は無いとする（Normattiva の本文を読んだ。1977 年の法には触れていない）。2026 年は最初の日曜が諸聖人の日と重なるのでこう並ぶ | 本当の休みの Ognissanti を先に出すかを決める（データの順のままにするか）。**ライブラリへの報告の候補にはしない**（聞くなら「2024 年の法の後も最初の日曜でよいか」という問いとして） |
| zh-Hant の 10/25・26 が同じ「臺灣光復暨金門古寧頭大捷紀…」で切れ、「（補假）」が隠れる | F-3 どおり。`short` も同じ 15 字なので落としても直らない | データに短い呼び方を持たせるか（元データの扱いの決まりを確かめる） |
| 終日の欄の fr「Jour」、es「Día」、pt-BR「Dia」が切り替えの「日」と同じ語 | `GLOSSARY.md` で幅に合わせて決めた形 | `allday.label.short` を fr「Tout」、es・pt-BR「Todo」にする案（F-7 の 2.4 em に入るか測る） |
| de の「保存済み」が Gesichert | 誤訳とは言えないが Gespeichert の方がふつう | 長くなるので mini の見出しの幅を測ってから。ドイツ語を読める人の判断 |
| ko の 1/1 が「신정연휴」 | KR.json のライブラリの名前のまま。1 日だけの休みに「연휴」（連休）は少し不自然に見えるという印象で、確かではない | 韓国語を読める人か R に確認 |
| TW の 2/15 が「農曆除夕」（公表は「小年夜」） | 「TW」の節の 4 と同じ。日は公表と合い、名前だけ違う | **ライブラリへの報告の候補**（行政院の公表の CSV が根拠。2026-02-15、2027-02-04）。データの名前を直すなら次の版の取り寄せのとき |
| fr・es・it の年の 10 月で「13 ma」が予定の棒にほぼ接する | 重なってはいない | このまま。人が見て気になれば |

**この役が気づいた分**: (a) de の iPhone の課金画面の 3 つのリンクは 1 行に入らず、ボタンごとに 2〜3 行に折り返す（Mac Catalyst の絵。語はハイフンで分かれるが「…」では切れない）。縦に 3 行に並べる形は `ViewThatFits` で作れるが、iPad の `.fitted` のシートの高さに響くかをここで確かめられないので、App Review の必須の所は今回は変えない。(b) 2 字の曜日の言語（en・de・fr・es・it）も、狭い iPhone の列（40 pt ほど）では数字の横に入らない見込み（写真が無く未確認）。ja も 1.1 から同じ。(c) iPhone の小さい機種の 1 日の列は「11/1」が 0.6 倍でも入らず「1…」になる（Mac Catalyst の絵。1.1 からの数字の枠の話で、ja も同じ）。

### J-4 の記録（CI の 1 回目。判定の KEEP の note。基準は仮の 31d243c）

比べた写真は基準 75 枚、今 106 枚。同じ 60、違う 15、新だけ 31。環境の `env.txt` は同じ（Xcode 26.6、iOS 26.4）。

- **違ってよい 3 枚**: `ipad13-portrait-sheet-settings`、`ipad13-portrait-sheet-info`、`store/ipad13/06-settings`。
- **基準の揺れ 4 枚**（基準を撮り直して比べ直す）: `ipad13-portrait-month`・`store/ipad13/01-month`（基準に手書きが無い）、`ipad13-portrait-week`・`store/ipad13/02-week`（基準に通知）。
- **`ipad13-portrait-sheet-sync`**（114,061 画素、強い差 33,805）: 字と行は同じで、リスト全体が今の方で 1 画素ほど下にある。C1 の「変わらない見込み」は外れた。上に節が増えたことによるスクロール位置の丸めと見ている。
- **弱い差だけの 7 枚**（強い差 0）: `sheet-lasso` 21,559 画素・最大 2、`iphone-portrait-day` 87,554・4、`store/iphone/03-day` 102,850・9、`readonly` 981・5、`sheet-export` 327・1、`month-zoom2` 49・1、`sheet-create` 3・1。

### 確かめ（この Mac、Swift 6.4.2、Command Line Tools。push・CI は無し）

| 確かめ | 結果 |
| --- | --- |
| `swift build --package-path TegakiKit` | 成功。新しい警告 0 |
| `swift run --package-path TegakiKit KitChecks` | **all 29470 checks passed**。compat10 は 361 件・失敗 0 |
| `tools/typecheck/typecheck.sh`（`m7b-impl/FIX3/tc`） | all OK・警告 0（アプリ、TegakiCalendarTests 34、UI テスト 6、Kit のテスト） |
| `python3 -I tools/l10n/lint.py` | L-1〜L-14 すべて ok（L-12 は目安の警告だけ） |
| `build.py --check`・`baseline.py --check`（基準の行は変わらない。516 行） | 一致 |
| `shasum -a 256 -c`（`m7b-impl/Record/data-abs.sha256`） | 18 件とも一致 |
| `diff_steps.rb`（`ja-baseline.yml` と `build.yml`） | 写した 13 段のうち 12 段の `run` が同じ（13 インチの写真の段を含む）。残り 1 段の差はシートの `holidays week-start` だけ |
| `check_workflow.rb`（Ruby の YAML と `bash -n`） | `build`・`ja-baseline` とも OK。この Mac に actionlint は無い |
| **Mac Catalyst の代わりで XCTest**（`m7b-impl/S2/apprun/run.sh PaperFitTests PaywallSheetTests`。XCTest の意味だけを写した小さな代わり） | 25 本・1,319 件・失敗 0。新しい `testWeekColumnWeekdaysFit`・`testWeekColumnShortHoliday` を含む |
| **日本語の絵の、この役の前の HEAD（e1073ae）との比較**（J-4 の代わりの先取り。`m7b-impl/FIX3/harness/ja-compare.sh`。紙・PDF 4 種・`StickyHeaderView`・`AllDayBandView`・`PageHeaderView` を今日 3 通りで 89 枚。週の見出しは 10/12 のスポーツの日を含む） | 77 枚が 0 画素。12 枚は `header-*` だけで最大 1/255・強い差 0。**同じ HEAD を 2 回描いて比べても同じ 12 枚が同じ画素数で違う**ので、描き直しの揺れ（P の節と同じ）で、変更の差ではない。`sticky-*` は全部 0 画素 |
| 他の言語の絵（Mac Catalyst の `ImageRenderer`。`m7b-impl/FIX3/harness`） | pt-BR の週を前後で見た（前は 402 pt の幅、後は iPhone 17 の 53.7 pt の列、40 pt の列、1024 pt の幅）: 後は 7 列が同じ大きさで切れない。zh-Hans の 10/5〜7「国庆节」「休息日」、zh-Hant の 10/9「國慶日」、ko の 10/5「개천절」が切れない |

**走らせていないもの**: 本物の XCTest（`swift test` の `WorldHolidaysTests`・`HolidayGeometryTests` の新しい期待はこの Mac では型だけ、アプリの単体テストは上の代わりだけ）、UI テスト（`testGermanPaywallReachesItsLinks` は型だけ）、シミュレータ、CI、新しい写真の手順、本物の `<1.1.1>` との J-4。

### CI で初めて分かること（リードへ）

1. `testGermanPaywallReachesItsLinks`: `isHittable` と枠。`paywall-de-bottom` の写真を開いて、§8 の 8 の表の字を確かめる。ドラッグの開始の位置（画面の 75%）で、シートが閉じたり送れなかったりしないか。
2. pt-BR の週の写真: 数字の上の曜日と、行の高さ（約 52 pt。幅の決まるズームが少し下がる）。ja の週が動いていないこと（J-4）。
3. `ViewThatFits` の祝日名（`zh-Hans`・`zh-Hant`・`ko` の iPhone の週）と、`zh-Hans` の日の題名と札の「休息日」。
4. 基準の撮り直し（`ja-baseline.yml`）: 月に手書きがあり、週に通知が無いこと。段が `--last 14m` に入ること。

資料: [Legge 1 marzo 2024, n. 27（Normattiva）](https://www.normattiva.it/eli/id/2024/03/16/24G00044/ORIGINAL)。1977 年の法は検索の要約だけで、本文は開いていない。
