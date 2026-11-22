# アプリの文 1.4.1 の直しの逆翻訳（本人の 11/22 の直しの後: `header.zoomReset.spoken` の 8 言語）

R が日本語の元を見ずに訳し戻した表です（2026-11-22）。母語の人の確認ではありません。判定は [REVIEW.md](../REVIEW.md) の 15 に書きます（**まだ**。契約 [R1_4_1_CONTRACT.md](../../R1_4_1_CONTRACT.md) §16.9 の「2 人の判定」がそろってから）。

- **対象**: `tools/l10n/translations/<言語>.json` の `header.zoomReset.spoken`（ja「等倍に戻す」の読み上げの名前）。X が 5c58e15 で「元の大きさ」の意味から「ズームを戻す」の意味に訳し直した 8 言語です。en の「Reset Zoom」は替えていないので、この表に入っていません（逆翻訳は `en.json` の同じキーのまま）。`header.today` は comment だけの変更で、訳は替えていません（R の対象の外）。
- **R に渡したもの**: 訳の字の 8 行（リードのスクラッチの `rework/x2-for-R.txt`。各行は「言語 TAB キー TAB 訳の字」）。R へ渡す段取りはリードの Workflow です（この表を写した見直しの直し役は、その段取りを見ていません）。8 行にかなが無いことと、8 行とも 5c58e15 の `translations/<言語>.json` の字と同じことは、写すときに機械で確かめました。
- R の逆翻訳はスクラッチの `rework/r2-back.txt` に書かれ、この表に機械で写しました（訳の字と逆翻訳の字は 1 字も変えていない）。
- **前の訳の逆翻訳は消していません**（契約 §16.9）。`back/<言語>.json` の `header.zoomReset.spoken` は、前の訳（「元の大きさ」の意味）とその逆翻訳のままで、REVIEW.md の 14 の表にもあります。今の訳の逆翻訳はこのファイルです。

| 言語 | キー | 訳（R が読んだ字） | 元を見ない逆翻訳 |
| --- | --- | --- | --- |
| zh-Hans | `header.zoomReset.spoken` | 重置缩放 | 拡大率をリセット |
| zh-Hant | `header.zoomReset.spoken` | 重置縮放 | 拡大率をリセット |
| ko | `header.zoomReset.spoken` | 확대·축소 재설정 | 拡大・縮小をリセット |
| fr | `header.zoomReset.spoken` | Réinitialiser le zoom | ズームをリセット |
| de | `header.zoomReset.spoken` | Zoom zurücksetzen | ズームをリセット |
| es | `header.zoomReset.spoken` | Restablecer el zoom | ズームを元に戻す |
| it | `header.zoomReset.spoken` | Reimposta lo zoom | ズームを設定し直す |
| pt-BR | `header.zoomReset.spoken` | Redefinir o zoom | ズームを設定し直す |
