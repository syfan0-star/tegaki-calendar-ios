# tools/holidays — 祝日データの作り方

アプリが持っている世界の祝日のデータ（`TegakiKit/HolidayData/`）は、python-holidays（Vacanza Team と貢献者、MIT ライセンス）から、この中の `gen.py` で作ります。契約は `docs/M7B_CONTRACT.md` の §5（データの形は §5.2、毎年の更新は §5.11）。日本の祝日はアプリの計算（`JapaneseHolidays`）なので、このデータの日本の分は英語などの名前にだけ使います。

| ファイル | 役目 |
| --- | --- |
| `gen.py` | python-holidays → `TegakiKit/HolidayData`（国ごとのファイル・`index.json`・`SOURCE.json`・ライセンス 2 つ） |
| `requirements.txt` | 使う python-holidays と依存の版と wheel の sha256（`--require-hashes` 用） |
| `iso_regions.swift` / `iso-regions.txt` | Foundation の 2 字の地域の一覧（と日本語の名前）。ここにある国だけを書く（"UK" は GB の別名なので書かない） |
| `summarize.py` | 2 つの HolidayData を比べて、国ごとの変化を日本語で 1 行ずつ出す |

## 使う物（リポジトリの外に置く）

- Python 3.10 以上（python-holidays 0.107 の `Requires-Python: >=3.10`）。1.2 のデータは Python 3.12.16（python-build-standalone 20261026、`~/.local/share/tegaki-python/python`）で作った。この Mac のもとからある `/usr/bin/python3` は 3.9.6 なので使えない（`gen.py` 以外の `summarize.py` は 3.9 で動く）。
- wheel 3 つ（`requirements.txt` のとおり）: `holidays-0.107-py3-none-any.whl`・`python_dateutil-2.9.0.post0-py2.py3-none-any.whl`・`six-1.17.0-py2.py3-none-any.whl`。1.2 では `~/.local/share/tegaki-python/holidays-0.107/wheels/` に置いた（2026-11-01 に PyPI から本人の了承で取り寄せたもの）。
- 取り寄せた wheel は data として扱う: その中から何かを走らせない。Python はいつも `-I` で走らせる。

venv の作り方（ネットにつながない）:

```sh
<python3.12> -m venv <venv>          # 例: /private/tmp/…/hol3/venv（リポジトリの外）
<venv>/bin/python -I -m pip install --require-hashes --no-index \
    --find-links <wheel のフォルダ> -r tools/holidays/requirements.txt
<venv>/bin/python -I -m pip freeze     # holidays==0.107 / python-dateutil==2.9.0.post0 / six==1.17.0
```

venv を一時フォルダ（`/private/tmp` の下）に置くと、数日で中の `.py` や `pyvenv.cfg` が消えることがある（2026-11-05 に 0.83 の venv で起きた）。`No module named 'holidays'` などで動かなくなったら、消して上の手順で作り直す（wheel と Python は `~/.local/share/tegaki-python/` に残っている）。作り直してもデータは同じになる。

## データを作る

```sh
<venv>/bin/python -I tools/holidays/gen.py TegakiKit/HolidayData
```

- 約 15 秒。venv の版が `requirements.txt` と違うと止まる。`-I` が無いと止まる。
- 書くのは `<国>.json`（1.2 は 250 個）・`index.json`・`SOURCE.json`・`LICENSE-python-holidays.txt`・`CONTRIBUTORS-python-holidays.txt`。中身が同じファイルは書き直さない。ライブラリから消えた国の `<国>.json` は消す。ほかのファイルには触らない。
- 標準エラーに、作った数と注意（訳の照らし合わせで同じ日の名前を使った数、全国と差の無い州の数、州の祝日の出勤日が国と違うもの、ライブラリの警告）が出る。`--report <ファイル>` を付けると、国ごとの年の件数なども JSON で書く（M7B.md の表を作るときに使う。リポジトリには入れない）。
- **2 回作って `diff -r` が空**であることを、作るたびに確かめる（ハッシュの順に頼っていないことの確かめ。`-I` は毎回ちがう乱数でハッシュを作る）:

```sh
rm -rf /tmp/hol-a /tmp/hol-b      # どこでもよい空のフォルダ（リポジトリの外）
<venv>/bin/python -I tools/holidays/gen.py /tmp/hol-a --previous TegakiKit/HolidayData
<venv>/bin/python -I tools/holidays/gen.py /tmp/hol-b --previous TegakiKit/HolidayData
diff -r /tmp/hol-a /tmp/hol-b && echo 同じ
```

- `iso-regions.txt` は 1 回作って commit した物を使う（`swift tools/holidays/iso_regions.swift > tools/holidays/iso-regions.txt`）。macOS が新しくなると地域や名前が変わりうるので、作り直すのはわざとそうするときだけ。

## 作った後の確かめ

```sh
swift build --package-path TegakiKit && swift run --package-path TegakiKit KitChecks
```

KitChecks の「holidays (1.2)」の節（`TegakiKit/Sources/KitChecks/HolidayChecks.swift`）が、日本の祝日が 2000〜2099 年の全部の日で `JapaneseHolidays` と同じこと、`JP.json` の日付が 1,773 日すべて一致すること、答えの分かっている日、全部のファイルが読めて検査を通ること、`SOURCE.json` の sha256、ライセンスの写し（`HolidayDataLicense.mitText`）を確かめる。XCTest は `TegakiKit/Tests/HolidaysTests/WorldHolidaysTests.swift`（CI で走る）。どちらにも「0.107 の値」と書いた期待があり、版を上げると変わりうる。

## 毎年の更新（§5.11）

年に 1 回（12 月ごろ、中国の调休の発表の後）と、臨時の祝日が出たとき。

1. **本人の了承をもらってから**、PyPI から新しい版の wheel を取り寄せる（`pip download --only-binary=:all: holidays==<版>` で依存も。取り寄せる物の出どころ・ファイルの名前・大きさ・置く場所・消し方を書いて聞く。1.2 の「はい」は 1.2 の 1 回だけ）。新しい版の `Requires-Python` と、手元の Python で入るかを見る。
2. `requirements.txt` の版と `--hash=sha256:` を書き換え、新しい venv を作る。
3. 今の `TegakiKit/HolidayData` をリポジトリの外に写す（例 `/tmp/hol-old`）。
4. `gen.py` で作る（上の「データを作る」。`--previous` の既定は出力先の今の `index.json` なので、出力先にそのまま作れば、前の版との `renamed` が作られる）。**2 回作って `diff -r` が空**を確かめる。
5. `python3 -I tools/holidays/summarize.py /tmp/hol-old TegakiKit/HolidayData` の日本語の要約を本人とリードが読む。必ず出るもの: 消えた州・地域のコード（選んでいた端末は国全体になる）、改名された州・地域のコード（旧 → 新）、全国の祝日の件数が 20% 以上変わった年、`lastOfficialYear`（公式の表の最後の年）・`coverage`（データの揃っている年）の変化。
5b. `notice` の 7 か国（0-29）の、今年と来年の政府の公表を 1 次資料で確かめ、データと日ごとに照らす。合っていて、ライブラリの表がその年に届いていない国（調整の日が無い年は表に年が載らない）は、`gen.py` の `PUBLISHED_AND_COMPARED` の年を上げ、`HolidayChecks.swift` の同じ名前の表に公表の日を足して作り直す。照らせない国と合わない国は上げない（その年は「発表前の推定」のまま）。
6. 改名された州が `index.json` の `renamed` に入っていることを確かめる（記録済みの "XX-旧コード" が何の表示もなく国全体に戻らないように）。消えた州で、本当は改名なのに `renamed` に入っていないもの（新しい版の別名に旧コードが無い）は、`gen.py` を直してから作り直す。
7. `HolidayDataLicense.swift` の `mitText` を新しい `LICENSE-python-holidays.txt` と同じにし、`contributorsURL` の版を直す。`HolidayChecks.swift` と `WorldHolidaysTests.swift` の「0.107 の値」の期待を新しい版で確かめ直す。
8. KitChecks（日本との一致・答えの分かっている日）と CI が緑になってから、アプリの更新として出す。データだけを通信で更新することはしない。

## データの形（短く）

1 国 1 ファイル、UTF-8、キーは辞書順、空白なし（§5.2）。日は 2000-01-01 からの日数。

- `langs`: 名前の列の言語（`langs[0]` はその国の言語。ライブラリに無ければ "en"）。`ui`: アプリの 10 言語 → 列の番号（その言語の名前がある物だけ）。
- `names`（列ごとの名前）・`flags`（1 推定、2 振替、4 週末と入れ替えた休み）・`short`（年のマス用の短い名前。違う物だけ）・`substFmt`（入れ替えた日付の書き方。`%Y` `%m` `%d` だけ）。
- `days`（`[日, 名前の番号, …]`）・`substFrom`（入れ替えた休みの日 → 入れ替えた週末の日）・`workdays`（出勤日になる週末）・`subdivisions`（全国と差のある州・地域だけ。`add`・`addFrom`・`remove`）。
- `index.json`: 国ごとに `code`・`langs`・`ui`・`subdivisions`（`code`・`display`・`names`・`local`）・`renamed`・`lastOfficialYear`・`notice`・`coverage`。
- `coverage`（データの揃っている年、0-30）: その年の祝日の数（名前の種類。週末と入れ替えた休みは数えない）が 2015〜2024 年の中央値の 80% 以上の年が続く範囲のうち、2020 年を含むもの（無ければいちばん長いもの）。基準を下回る年が 1 年だけで、0 件でなく、前後の年が基準以上のときは範囲を切らない（スロバキアの 2026 年）。今年がこの外だと、設定の行に「<年> 年以降のデータがありません」と出る。作り直したら、`summarize.py` の出す `coverage` の変化を必ず読む。

決め方の細かいこと（訳の列の照らし合わせ、推定の後ろ書きの外し方、`coverage` の数え方など）は `gen.py` の先頭の説明に書いた。
