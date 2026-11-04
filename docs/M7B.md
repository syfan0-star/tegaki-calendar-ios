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

