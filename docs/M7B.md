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

