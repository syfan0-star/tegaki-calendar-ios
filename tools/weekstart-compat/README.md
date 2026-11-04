# tools/weekstart-compat — 古い版の本物で週の始まりの互換を確かめる

1.2 は日曜始まりの週のページ（`w-<日曜>`）と、日曜の並びで書いた月のページを作る（`docs/M7B_CONTRACT.md` の K-11、§10）。古い版の端末がそれを読んでも、消さない・動かさない・壊さないことを、**古い版の本物の TegakiKit** で確かめる（§10.8）。`tools/compat10`（K-7）は変えず、ここに別に置く。

| ファイル | 役目 |
| --- | --- |
| `common.swift` | 両方の版で同じ確かめ（A: 日曜の週のページ、B: 日曜の並びで書いた月のページ） |
| `v10/run/` | 1.0（a21e469）の Kit で走らせる SwiftPM のパッケージ。`main.swift` は `common.swift` ＋ 最後の行 |
| `v11/run/` | `tools/l10n/ja-baseline-ref.txt` の commit（`<1.1.1>`、§1.5）の Kit で走らせるパッケージ。`main.swift` は `common.swift` ＋ 1.1 以後だけの確かめ（C）＋ 最後の行 |

`main.swift` は `common.swift` を含む（SwiftPM の 1 つの target に 2 つを入れると、同じ名前の宣言がぶつかるため）。`common.swift` を直したら、2 つの `main.swift` の同じ部分も同じに直す。

## 走らせ方

パッケージは `../TegakiKit` を読むので、古い版の checkout の中に `run/` を置く。

```sh
# 1.0。<dir> はリポジトリの外の空のフォルダ
mkdir -p <dir>/v10
git archive a21e4692109e504701b507ad9c695181fdecddfd TegakiKit | tar -x -C <dir>/v10
cp -R tools/weekstart-compat/v10/run <dir>/v10/run
swift run --package-path <dir>/v10/run Probe

# <1.1.1>
REF="$(tr -d '[:space:]' < tools/l10n/ja-baseline-ref.txt)"
mkdir -p <dir>/v11
git archive "$REF" TegakiKit | tar -x -C <dir>/v11
cp -R tools/weekstart-compat/v11/run <dir>/v11/run
swift run --package-path <dir>/v11/run Probe
```

最後の行が `… failures 0` で、終了の状態が 0 なら合格。失敗があれば `FAIL` の行が出て、終了の状態は 1。

CI は `compat-v1.0` のジョブの 1 段で、既にある `v10` の checkout と `ja-baseline-ref.txt` の commit の checkout に対して同じことをする（段を足すのは C、§7.5）。
