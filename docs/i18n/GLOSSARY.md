# 用語集（1.2「世界対応」）

アプリ・ストアの文の語を、言語ごとに 1 つに決めた表です（[M7B_CONTRACT.md](../M7B_CONTRACT.md) §6.1・§6.2、書いた人は X）。英語は契約が決めた語です。1.4.1 で足した語（等倍・利き手・ツールバーを動かす）は §5 です（[R1_4_1_CONTRACT.md](../R1_4_1_CONTRACT.md) §8.1・§8.2。等倍の語は §16.9 で直した）。

**正直に書くこと**: 訳は Claude が書き、別の Claude が日本語の元を見ずに訳し戻して照らします（`REVIEW.md`）。**各言語を母語とする人の確認はありません。** 本人は日本語しか読めません。誤りはサポートのメールで受け、次の版で直します（§6.1 の 8）。

## 1. 書き方

| 言語 | 丁寧さ（§6.1 の 1） | 読み手と書き方（§6.1 の 9、§11.2） | 引用符 |
| --- | --- | --- | --- |
| en | 普通の丁寧さ | 英語の店頭すべて。米国のつづり | “ ” |
| zh-Hans | 你（您は使わない） | 中国本土・シンガポール | “ ” |
| zh-Hant | 你（您は使わない） | 台湾の語を主に。香港・マカオも読む | 「 」 |
| ko | 해요체 | 韓国 | ‘ ’ |
| fr | vous | **フランスの書き方**（évènement は Apple のつづり）。記号の前に改行しない空白（U+00A0）。ベルギー・ルクセンブルク・スイス・カナダ・アフリカの 3 か国も読む | « » |
| de | Sie | **標準のドイツ語（ß を使う）**。ドイツ・オーストリアの既定で、スイスとルクセンブルクも読む | „ “ |
| es | usted | **画面は 1 つでスペインと中南米が読む**。中南米だけの語を使わない（celular・computadora など。§6.1 の 9）。「Agregar」は iOS の中南米の画面の名前を添えるときだけ | “ ” |
| it | Lei（Le・Suo は大文字） | 標準のイタリア語。スイスも読む | “ ” |
| pt-BR | você | ブラジル。**画面は pt-PT の端末にもこの文が出る**（0-2） | “ ” |

ストアの文だけの 2 つ（画面の言語は上の es・pt-BR）:

| ロケール | 書き方 | アプリの画面の名前 |
| --- | --- | --- |
| **es-ES** | es-MX から直した。スペインの語（añadir、iOS の Ajustes、sitio）。usted | アプリの es の語のまま（Ajustes・Días festivos・Exportar escritura a mano） |
| **pt-PT** | pt-BR の写しにせず別に書いた（ecrã、ficheiro、aplicação、programador、eliminar、guardar、“à segunda-feira”）。iOS は Definições | アプリの **pt-BR の語のまま**（Ajustes・Feriados・Exportar escrita à mão）。そう表示されるため。説明の 1 点に「画面はブラジルのポルトガル語」と書いた（§11.2） |
| fr-CA | fr-FR と同じ文 | — |

en-GB・en-AU・en-CA は en-US と同じ文です。

## 2. アプリ自身の言葉

| 日本語 | en（契約） | zh-Hans | zh-Hant | ko | fr | de | es | it | pt-BR |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 手帳 | planner | 手帐 | 手帳 | 플래너 | agenda | Planer | agenda | agenda | agenda |
| 紙 | paper | 纸 | 紙 | 종이 | papier | Papier | papel | carta | papel |
| 日のページ | day page | 日页面 | 日頁面 | 일 페이지 | page du jour | Tagesseite | página del día | pagina del giorno | página do dia |
| 週のページ | week page | 周页面 | 週頁面 | 주 페이지 | page de la semaine | Wochenseite | página de la semana | pagina della settimana | página da semana |
| 月のページ | month page | 月页面 | 月頁面 | 월 페이지 | page du mois | Monatsseite | página del mes | pagina del mese | página do mês |
| 年のページ | year page | 年页面 | 年頁面 | 연 페이지 | page de l’année | Jahresseite | página del año | pagina dell’anno | página do ano |
| 指でも書く | Draw with Finger | 用手指书写 | 用手指書寫 | 손가락으로 쓰기 | Écrire au doigt | Mit Finger zeichnen | Dibujar con el dedo | Scrivi con il dito | Traçar com o dedo |
| メモ | Notes | 备忘 | 備忘 | 메모 | Notes | Notizen | Notas | Note | Notas |
| 自由メモ | Free Notes | 自由备忘 | 自由備忘 | 자유 메모 | Notes libres | Freie Notizen | Notas libres | Note libere | Notas livres |
| 閲覧専用 | View Only | 仅查看 | 僅檢視 | 보기 전용 | Lecture seule | Nur ansehen | Solo lectura | Sola lettura | Somente leitura |
| 予定（文の中） | event | 日程 | 行程 | 일정 | évènement | Termin | evento | evento | evento |
| ペン（文の中） | pen | 钢笔 | 鋼筆 | 펜 | stylo | Stift | pluma | penna | caneta |
| マーカー（文の中） | marker | 马克笔 | 麥克筆 | 마커 | feutre | Marker | marcador | marker | marcador |
| 消しゴム（文の中） | eraser | 橡皮擦 | 橡皮擦 | 지우개 | gomme | Radierer | goma | gomma | borracha |
| 投げなわ（文の中） | lasso | 套索 | 套索 | 올가미 | lasso | Lasso | lazo | lazo | laço |
| 元に戻す | Undo | 撤销 | 還原 | 실행 취소 | Annuler | Widerrufen | Deshacer | Annulla | Desfazer |
| やり直す | Redo | 重做 | 重做 | 실행 복귀 | Rétablir | Wiederholen | Rehacer | Ripeti | Refazer |
| 太さ | Width | 粗细 | 粗細 | 굵기 | Épaisseur | Stärke | Grosor | Spessore | Espessura |
| 終日 | All-day | 全天 | 整天 | 종일（予定のシートは 하루 종일） | Journée entière | Ganztägig | Todo el día | Tutto il giorno | Dia inteiro |
| 祝日 | Holidays | 节假日 | 假日 | 공휴일 | Jours fériés | Feiertage | Días festivos | Festività | Feriados |
| （推定） | (est.) | （推算） | （推估） | (추정) | (estimé) | (geschätzt) | (estimado) | (stima) | (estimado) |
| 振替の休み | Day off | 休息日 | 休息日 | 쉬는 날 | Jour de repos | Freier Tag | Día libre | Giorno libero | Dia de folga |
| 同期 | Sync | 同步 | 同步 | 동기화 | Synchronisation | Synchronisierung | Sincronización | Sincronizzazione | Sincronização |
| この端末 | this device | 此设备 | 這部裝置 | 이 기기 | cet appareil | dieses Gerät | este dispositivo | questo dispositivo | este dispositivo |
| 手書き | handwriting | 手写内容 | 手寫內容 | 손글씨 | écriture manuscrite | Handschrift | escritura a mano | scrittura a mano | escrita à mão |
| 線（本） | stroke(s) | 条线 | 條線 | 선 ○개 | trait(s) | Strich/Striche | trazo(s) | tratto/tratti | traço(s) |
| 手書きを書き出す | Export Handwriting | 导出手写内容 | 匯出手寫內容 | 손글씨 내보내기 | Exporter l’écriture manuscrite | Handschrift exportieren | Exportar escritura a mano | Esporta scrittura a mano | Exportar escrita à mão |
| Web 版の手書きを取り込む | Import from the Web Version | 导入网页版手写内容 | 匯入網頁版手寫內容 | 웹 버전 손글씨 가져오기 | Importer depuis la version web | Aus der Web-Version importieren | Importar de la versión web | Importa dalla versione web | Importar da versão web |
| このページを PDF | This Page as PDF | 此页面的 PDF | 此頁面的 PDF | 이 페이지를 PDF로 | Cette page en PDF | Diese Seite als PDF | Esta página en PDF | Questa pagina in PDF | Esta página em PDF |
| データ（節） | Data | 数据 | 資料 | 데이터 | Données | Daten | Datos | Dati | Dados |
| 購読する | Subscribe | 订阅 | 訂閱 | 구독 | S’abonner | Abonnieren | Suscribirse | Abbonarsi | Assinar |
| 無料試用 | free trial | 免费试用 | 免費試用 | 무료 체험 | essai gratuit | kostenlose Testphase | prueba gratuita | prova gratuita | teste grátis |
| 月額 | Monthly | 按月 | 月繳 | 월간 | Mensuel | Monatlich | Mensual | Mensile | Mensal |
| 年額 | Yearly | 按年 | 年繳 | 연간 | Annuel | Jährlich | Anual | Annuale | Anual |
| 解約 | cancel | 取消 | 取消 | 해지 | résilier | kündigen | cancelar | disdire | cancelar |
| 猶予の期間 | grace period | 宽限期 | 寬限期 | 유예 기간 | délai de grâce | Nachfrist | periodo de gracia | periodo di tolleranza | período de carência |
| 表示する祝日 | Holidays to Show | 显示的节假日 | 顯示的假日 | 표시할 공휴일 | Jours fériés à afficher | Angezeigte Feiertage | Días festivos que se muestran | Festività da mostrare | Feriados exibidos |
| 週の始まり（画面の名前） | Week Starts On | 一周的第一天 | 一週的第一天 | 한 주의 첫째 날 | Premier jour de la semaine | Erster Tag der Woche | Primer día de la semana | Primo giorno della settimana | Primeiro dia da semana |
| もう一方の週の始まり（文の中） | the other week start | 另一种一周的第一天 | 另一種一週的第一天 | 다른 한 주의 첫째 날 | l’autre premier jour | anderer Wochenstart | el otro primer día | l’altro primo giorno | o outro primeiro dia |
| 月曜 / 日曜 | Monday / Sunday | 周一 / 周日 | 週一 / 週日 | 월요일 / 일요일 | Lundi / Dimanche | Montag / Sonntag | Lunes / Domingo | Lunedì / Domenica | Segunda-feira / Domingo |
| 前後の月の日のマス | cells for days of the previous or next month | 前后月份日期格子 | 前後月份日期格子 | 앞뒤 달의 날짜 칸 | cases des jours du mois précédent ou suivant | Felder für Tage des vorherigen oder nächsten Monats | casillas de días del mes anterior o siguiente | caselle dei giorni del mese precedente o successivo | células de dias do mês anterior ou seguinte |
| 2 本の指を広げる（拡大）・つまむ（縮小） | Spread two fingers to zoom in, pinch to zoom out | 双指张开可放大，双指捏合可缩小 | 兩指張開可放大，兩指捏合可縮小 | 두 손가락을 벌리면 확대, 오므리면 축소 | Écartez deux doigts pour zoomer, pincez pour dézoomer | Zwei Finger spreizen zum Vergrößern, zusammenziehen zum Verkleinern | Separe dos dedos para ampliar y júntelos para reducir | Allarghi due dita per ingrandire, le avvicini per rimpicciolire | Afaste dois dedos para ampliar e aproxime-os para reduzir |
| てがきカレンダー（ホーム画面） | Tegaki | Tegaki | Tegaki | Tegaki | Tegaki | Tegaki | Tegaki | Tegaki | Tegaki |

週の始まりの画面の名前は、iOS の「言語と地域」の同じ項目の語（Apple の記事の語）にそろえました。英語だけは契約の “Week Starts On” です。トーストは 3 行に入れるので、文の中では短い語を使います（de の Wochenstart など）。

`settings.data.importFooter` の「手書きを書き出す（iPad アプリ用）」は、どの言語でも日本語のまま括弧の中に置き、後ろにその言語の説明を添えました（Web 版は日本語だけ。§6.2、`allowJapanese`）。

## 3. iOS の画面の名前（§6.1 の 4）

Apple のサポート記事の各言語版を 2026-11-05 に読んだ語です（公開のページを読むだけ。ログインしていない）。**同じ言語でも国で違うので、es-ES・es-MX、pt-BR・pt-PT は別々に確かめました。**

| 日本語の名前 | en-US | fr-FR | de-DE | it-IT | es-ES | es-MX | pt-BR | pt-PT | zh-CN | zh-TW | ko-KR |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 「設定」アプリ | Settings | Réglages | Einstellungen | Impostazioni | Ajustes | Configuración | Ajustes | Definições | 设置 | 設定 | 설정 |
| 自分の名前（Apple Account の行） | your name | votre nom | deinen Namen | il tuo nome | tu nombre | tu nombre | seu nome | seu nome | 你的姓名 | 你的姓名 | 사용자의 이름 |
| Apple Account | Apple Account | compte Apple | Apple Account | Apple Account | Cuenta de Apple | cuenta de Apple | Conta Apple | conta Apple | Apple 账户 | Apple 帳號 | Apple 계정 |
| サブスクリプション | Subscriptions | Abonnements | Abonnements | Abbonamenti | Suscripciones | Suscripciones | Assinaturas | Assinaturas | 订阅 | 訂閱項目 | 구독 |
| お支払いと配送先 | Payment & Shipping | Paiement et livraison | Zahlung & Versand | Pagamento e spedizione | Pago y envío | Pago y Envío | Pagamento e Entrega | Pagamento e envio | 付款与配送 | 付款與寄送 | 결제 및 배송 |
| 一般 | General | Général | Allgemein | Generali | General | General | Geral | Geral | 通用 | 一般 | 일반 |
| 言語と地域 | Language & Region | Langue et région | Sprache & Region | Lingua e zona | Idioma y región | Idioma y región | Idioma e Região | Idioma e região | 语言与地区 | 語言與地區 | 언어 및 지역 |
| 言語を追加 | Add Language | Ajouter une langue | Sprache hinzufügen | Aggiungi lingua | Añadir idioma | Agregar idioma | Adicionar Idioma | Adicionar idioma | 添加语言 | 加入語言 | 언어 추가 |
| 週の始まり（地域の項目） | First day of the week | Premier jour de la semaine | Erster Tag der Woche | Primo giorno della settimana | Primer día de la semana | Primer día de la semana | Primeiro dia da semana | Primeiro dia da semana | 一周的第一天 | 一週的第一天 | 한 주의 첫째 날 |
| アプリ（設定の項目） | Apps | Apps | Apps | App | Apps | Apps | Apps | Aplicações | App | App | 앱 |
| カレンダー | Calendar | Calendrier | Kalender | Calendario | Calendario | Calendario | Calendário | Calendário | 日历 | 行事曆 | 캘린더 |
| カレンダーアカウント | Calendar Accounts | Comptes Calendrier | Kalender-Accounts | Account Calendario | Cuentas de Calendario | Cuentas de Calendario | Contas de Calendário | Contas de calendário | 日历账户 | 行事曆帳號 | 캘린더 계정 |
| アカウントを追加 | Add Account | Ajouter un compte | Account hinzufügen | Aggiungi account | Añadir cuenta | Agregar cuenta | Adicionar Conta | Adicionar conta | 添加账户 | 加入帳號 | 계정 추가 |
| データの取得方法 | Fetch New Data | Nouvelles données | Datenabgleich | Scarica nuovi dati | Obtener datos | Obtener datos | Obter Novos Dados | Obter dados | 抓取新数据 | 擷取新資料 | 데이터 업데이트 |
| スクリブル | Scribble | Griffonner | Kritzeln | Scrivi a mano | Escribir a mano | Escribir a mano | Escrever à Mão | Escrever à mão | 随手写 | 隨手寫 | 손글씨 입력 |
| ダブルタップ（Apple Pencil の項目） | Double Tap | Toucher deux fois | Doppeltippen | Doppio tocco | Doble toque | Tocar dos veces | Toque Duplo | Dois toques | 轻点两下 | 點兩下 | 두 번 탭 |
| スクイーズ（Apple Pencil の項目） | Squeeze | Pincement | Drücken | Pressione | Gesto de apretar | Apretar | Apertar | Apertar | 轻捏 | 擠壓 | 스퀴즈 |
| フルアクセス（記事の文の語。下の注） | full access | accéder complètement | vollen Zugriff | accesso totale | pleno acceso | acceso completo | acesso total | acesso pleno | 完全访问 | 完整權限 | 전체 접근 권한 |

読んだ記事（`<loc>` は `en-us`・`fr-fr`・`de-de`・`it-it`・`es-es`・`es-mx`・`pt-br`・`pt-pt`・`zh-cn`・`zh-tw`・`ko-kr`）:

| 語 | URL |
| --- | --- |
| 解約の道（サブスクリプション） | `https://support.apple.com/<loc>/118428` |
| お支払いと配送先 | `https://support.apple.com/<loc>/118293` |
| 言語を追加（端末の言語） | `https://support.apple.com/<loc>/109358` |
| 一般・言語と地域・週の始まり | `https://support.apple.com/<loc>/guide/iphone/iphce20717a3/ios` |
| カレンダーアカウント・アカウントを追加 | `https://support.apple.com/<loc>/guide/iphone/ipha0d932e96/ios` |
| データの取得方法 | `https://support.apple.com/<loc>/guide/iphone/iphc37be2016/ios` |
| スクリブル | `https://support.apple.com/<loc>/guide/ipad/ipad355ab2a7/ipados` |
| ダブルタップ・スクイーズ | `https://support.apple.com/<loc>/guide/ipad/ipadc55b6c7a/ipados` |
| フルアクセス（Mac の記事） | `https://support.apple.com/<loc>/guide/mac-help/mh43710/mac` |

### 決めたこと

- **解約の道は「設定 > 自分の名前 > サブスクリプション」にしました。** 日本語の文は「Apple Account」ですが、Apple の 9 言語の記事の手順はどれも「設定で自分の名前を押す」です。この書き方なら iOS・iPadOS 17（Apple ID の時代）でも同じ道になるので、Apple ID を書き分ける文が要りません（英語の TERMS.en も同じ書き方）。`REVIEW.md` では △ になります。
- **アプリの es の画面の「設定」アプリは「Ajustes (Configuración)」と両方書きました。** スペインの iOS は Ajustes、中南米の iOS は Configuración で、es の画面は 1 つです。アプリ自身の設定の題名は Ajustes です。ストアの es-ES は Ajustes だけ、es-MX は iOS の話が Configuración、アプリの話が Ajustes です。
- **pt-PT は iOS の話が Definições、アプリの話が Ajustes です**（アプリの画面はブラジルのポルトガル語なので）。
- **de のアカウントは Account です**（Konto と混ぜません。iOS の Kalender-Accounts と `settings.sync.newAccount` にそろえました）。
- **de の「州・地域」の画面の語は Regionen です。** Bundesland はドイツとオーストリアの語で、米国の州などは Bundesstaat なので、国を問わない語にしました。ストアの文は例を挙げるので Bundesland と Bundesstaat を両方書いています。

### 確かめられなかった語（TestFlight でリードが見る）

- **「言語」「優先する言語」**: アプリごとの言語の項目は Apple の記事に見つかりませんでした。次の語は iOS の普段の語から書いたもので、確かめていません: en Language / Preferred Language、fr Langue / Langue préférée、de Sprache / Bevorzugte Sprache、it Lingua / Lingua preferita、es Idioma / Idioma preferido、pt-BR Idioma / Idioma Preferido、pt-PT Idioma / Idioma preferido、zh-Hans 语言 / 首选语言、zh-Hant 語言 / 偏好的語言、ko 언어 / 선호하는 언어。§2.1 のとおり、道そのものをリードが TestFlight で確かめるときに語も見てください。
- **「15 分ごと」**: 選択肢の語は記事にありませんでした。en Every 15 Minutes、fr Toutes les 15 minutes、de Alle 15 Minuten、it Ogni 15 minuti、es Cada 15 minutos、pt-BR A Cada 15 Minutos、zh-Hans 每 15 分钟、zh-Hant 每 15 分鐘、ko 15분마다 は確かめていません。
- **「フルアクセス」**: iOS の画面の字は iPhone の記事に無く、上の表は Mac の記事の文の中の語です。アプリの字は iOS の普段の語から次にしました: fr accès complet、de Voller Zugriff、it accesso completo、es acceso total、pt-BR Acesso Total、zh-Hans 完全访问、zh-Hant 完整取用權限、ko 전체 접근。iOS の表記と違っても、文は「すべてのカレンダーへのアクセスを許す」の意味で読めます。
- **iOS・iPadOS 17 の「カレンダー > アカウント」**: 今の記事に 17 の道はありません。各言語の Accounts にあたる普段の語です。

## 4. 幅を測った語（F-5〜F-7、F-12〜F-16）

幅はこの Mac の Mac Catalyst の UIFont で 2026-11-05 に測りました（単位 pt）。Catalyst の字は同じ大きさの AppKit より約 4% 広く、契約の数字（AppKit で測った値）より大きく出ます。本当の判定は CI-0 のシミュレータの `ToolbarFitTests`・`PaperFitTests`・`WeekStartChoiceTests` です。

### ツールバーの名前（10 pt。38 以内を先に選ぶ。47.5 まで。F-12）

| キー | en | zh-Hans | zh-Hant | ko | fr | de | es | it | pt-BR |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ペン | Pen 18.8 | 钢笔 18.5 | 鋼筆 18.5 | 펜 8.7 | Stylo 25.7 | Stift 21.5 | Pluma 30.7 | Penna 30.9 | Caneta 35.5 |
| マーカー | Marker 34.9 | 马克笔 27.7 | 麥克筆 27.7 | 마커 17.3 | Feutre 32.4 | Marker 34.9 | Marcar 35.0 | Marker 34.9 | Marcar 35.0 |
| 消しゴム | Eraser 32.2 | 橡皮擦 27.7 | 橡皮擦 27.7 | 지우개 26.0 | Gomme 38.3 | Radierer 42.5 | Goma 29.0 | Gomma 38.1 | Borracha 45.6 |
| 投げなわ | Lasso 29.3 | 套索 18.5 | 套索 18.5 | 올가미 26.0 | Lasso 29.3 | Lasso 29.3 | Lazo 23.8 | Lazo 23.8 | Laço 24.1 |
| 予定 | Event 28.2 | 日程 18.5 | 行程 18.5 | 일정 17.3 | RDV 21.4 | Termin 34.2 | Evento 34.4 | Evento 34.4 | Evento 34.4 |
| しまう | Hide 23.2 | 收起 18.5 | 收起 18.5 | 숨기기 26.0 | Réduire 38.5 | Ablegen 41.3 | Ocultar 37.2 | Riduci 31.2 | Ocultar 37.2 |
| 細 | Thin 22.0 | 细 9.2 | 細 9.2 | 가늘게 26.0 | Fin 15.1 | Dünn 26.2 | Fino 21.4 | Sottile 32.8 | Fino 21.4 |
| 中 | Medium 39.8 | 中 9.2 | 中 9.2 | 보통 17.3 | Moyen 33.0 | Mittel 28.8 | Medio 30.8 | Medio 30.8 | Médio 30.8 |
| 太 | Thick 27.5 | 粗 9.2 | 粗 9.2 | 굵게 17.3 | Épais 27.1 | Dick 22.2 | Grueso 36.1 | Spesso 36.6 | Grosso 35.5 |

言い換えの理由:

- **fr 予定 = RDV**: Évènement は 10 pt で 53 pt あり、上限 47.5 に入りません。RDV（rendez-vous）はフランス語の手帳で普通の略です。文の中は évènement です。
- **fr マーカー = Feutre**、**it マーカー = Marker**: Marqueur・Surligneur・Marcatore・Pennarello は 38 を超えるか上限に近いので。
- **es・pt-BR マーカー = Marcar**: Marcador は 47.8 pt で上限を超えます。動詞ですが、文の中の marcador と同じ語の仲間です。文の中は marcador です。
- **es ペン = Pluma**、**es 消しゴム = Goma**: Apple のスペインとメキシコの記事が両方 pluma です。消しゴムは Apple のスペインが goma、メキシコが borrador で、borrador はスペインでは「下書き」の意味が強いので goma にしました（メキシコでも goma は通じます）。
- **de しまう = Ablegen**: Ausblenden 56.6・Einklappen 52.7・Verbergen 50.0 は上限を超えます。読み上げは「Werkzeugleiste ausblenden」です。
- **fr・it しまう = Réduire・Riduci**: Masquer・Nascondi は 38 を超えます。

### 「指でも書く」（13 pt。ja の幅 60.0 ＋ 76 = 136 まで。F-13）

en Draw with Finger 105.8、zh-Hans 用手指书写 60.0、zh-Hant 用手指書寫 60.0、ko 손가락으로 쓰기 82.6、fr Écrire au doigt 91.7、de Mit Finger zeichnen 123.6、es Dibujar con el dedo 122.4、it Scrivi con il dito 100.8、pt-BR Traçar com o dedo 117.9（Desenhar com o dedo は 137.9 で超えた）。

### 投げなわのメニュー（14 pt、1 つ目は semibold。合計 220 まで。F-15）

| 言語 | 予定にする | 削除 | 選択解除 | 合計 |
| --- | --- | --- | --- | --- |
| en | Make Event 80.1 | Delete 43.4 | Deselect 59.1 | 182.6 |
| zh-Hans | 转为日程 50.5 | 删除 25.9 | 取消选择 51.7 | 128.1 |
| zh-Hant | 轉為行程 51.7 | 刪除 25.9 | 取消選取 51.7 | 129.3 |
| ko | 일정 만들기 64.4 | 삭제 24.2 | 선택 해제 52.5 | 141.1 |
| fr | Créer RDV 72.4 | Supprimer 69.6 | Annuler 51.7 | 193.7 |
| de | Als Termin 73.6 | Löschen 56.3 | Abwählen 65.1 | 195.0 |
| es | Crear evento 89.7 | Eliminar 53.2 | Cancelar 59.3 | 202.2 |
| it | Crea evento 83.8 | Elimina 47.7 | Deseleziona 81.6 | 213.1 |
| pt-BR | Criar evento 85.5 | Apagar 48.0 | Desmarcar 72.5 | 206.0 |

**fr・es の選択解除は Annuler・Cancelar です。** Désélectionner・Deseleccionar だと合計が 220 を超えます。iOS の選択の画面を抜けるボタンと同じ語です。

### 見出しの切り替え（13 pt の semibold。44 が目安で、テストは 44.5。F-16）

| | en | zh-Hans | zh-Hant | ko | fr | de | es | it | pt-BR |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 日 | Day 24.9 | 日 12.0 | 日 12.0 | 일 11.2 | Jour 29.4 | Tag 23.5 | Día 21.2 | Giorno 43.7 | Dia 21.2 |
| 週 | Week 35.8 | 周 12.0 | 週 12.0 | 주 11.2 | **Sem.** 33.1 | Woche 44.2 | **Sem.** 33.1 | **Sett.** 31.8 | **Sem.** 33.1 |
| 月 | Month 41.6 | 月 12.0 | 月 12.0 | 월 11.2 | Mois 31.0 | Monat 41.0 | Mes 27.0 | Mese 34.9 | Mês 27.0 |
| 年 | Year 29.1 | 年 12.0 | 年 12.0 | 연 11.2 | Année 41.4 | Jahr 29.1 | Año 25.7 | Anno 33.8 | Ano 25.7 |

### 「今日」（17 pt。ja の幅 31.4 ＋ 16 = 47.4 まで。テストは測りの余裕の 0.5 を足した 47.9。F-16）

en Today 47.3、zh-Hans 今天 31.4、zh-Hant 今天 31.4、ko 오늘 29.4、**fr Auj. 29.7**（Aujourd’hui は iPhone の題名の幅を削りすぎるので、契約どおり略した）、de Heute 47.4、es Hoy 31.2、it Oggi 37.5、pt-BR Hoje 36.1。**en と de はほとんど余裕がありません**（契約が入ると決めた語）。

### 終日の帯（10 pt。短い形は 24 まで。F-7）

| | en | zh-Hans | zh-Hant | ko | fr | de | es | it | pt-BR |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 正式 | All-day 35.9 | 全天 18.5 | 整天 18.5 | 종일 17.3 | Journée entière 79.3 | Ganztägig 51.3 | Todo el día 55.3 | Tutto il giorno 70.7 | Dia inteiro 51.7 |
| 短い形 | All 12.9 | 全天 18.5 | 整天 18.5 | 종일 17.3 | Jour 22.4 | Tag 18.0 | Día 16.3 | **24h** 19.3 | Dia 16.3 |

it の短い形は Tutto が 25 pt で入らないので 24h にしました（「24 時間」の意味）。

### そのほか

- **メモ（幅 ＋ 0.15 em × 字数 が 8.0 em まで。F-6）**: いちばん長いのは de Freie Notizen 7.98 em（契約の語。余裕はほとんどありません）。
- **「+99 …」（7 em まで。F-5）**: いちばん長いのは de +99 weitere 5.52 em。
- **ツールバーの説明（12 pt。消しゴムは 144、投げなわと予定は 155。F-14）**: いちばん長いのは de Löscht berührte Striche 140、fr Tracez pour créer un RDV. 154。全部測ってテストが通っています。
- **週の始まりのトースト（15 pt、幅 402 − 64 = 338 で 3 行まで。§10.4）**: 全部入ります。幅 375 − 64 = 311 でも、Mac Catalyst の字では全部 3 行に入ります（検証の後に de・it・pt-BR・fr の `otherForm` と pt-BR の `regionChanged` を短くしました。fr は日曜でも入ります。`REVIEW.md` の 10）。311 は 1 pt も余らない文があるので（it の `hiddenInk.other`）、`testWeekStartToastsFitThreeLines` はログだけで、判定は 402 pt です。
- **`demo.*`（ストアの写真の見本。終日 4.2 em、時刻 5.7 em）**: 入るように短い語にしました（「出張（大阪）」は Osaka だけなど）。見本なので元の意味に厳密でない語があります。

## 5. 1.4.1 の語（等倍・利き手・ツールバーを動かす）

[R1_4_1_CONTRACT.md](../R1_4_1_CONTRACT.md) §8.1 の 11 キーのための語です（§8.2 の「GLOSSARY を先に直す」。2026-11-22、書いた人は X）。en は契約 §8.1 の案の語で、案が「—」のキー（つまみの名前・ヒント・4 つの操作）の語はここで決めました。アプリの訳（`tools/l10n/translations/<言語>.json`）、新機能の文（契約 §8.3）、SUPPORT と審査メモの英語は、この表の字を使います。母語の人の確認が無いことは、上の「正直に書くこと」のとおりです。

**2026-11-22 の直し（契約第 3 版の §16.9）**: 本人の直しで、日と週の等倍が「1 日・1 週のページの幅が画面の幅にちょうど合う大きさ」になりました（月と年は開いたときの大きさのまま）。そのため、表の等倍の 2 行（名詞と読み上げ）と、下の「決めたこと」の等倍の 3 点と字のボタンの点を、X が書き直しました。ほかの行と点は前のままです。

| 日本語 | en | zh-Hans | zh-Hant | ko | fr | de | es | it | pt-BR |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 等倍（文の中の名詞。日と週は 1 日・1 週のページの幅が画面の幅にちょうど合う大きさ、月と年は開いたときの大きさ） | standard size | 标准大小 | 標準大小 | 표준 크기 | taille standard | Standardgröße | tamaño estándar | dimensione standard | tamanho padrão |
| 等倍に戻す（虫めがねに「1」のボタンの読み上げ。`header.zoomReset.spoken`。意味は「ズームを戻す」） | Reset Zoom | 重置缩放 | 重置縮放 | 확대·축소 재설정 | Réinitialiser le zoom | Zoom zurücksetzen | Restablecer el zoom | Reimposta lo zoom | Redefinir o zoom |
| 利き手（設定の節の見出し。`settings.hand.header`） | Dominant Hand | 惯用手 | 慣用手 | 주로 쓰는 손 | Main dominante | Dominante Hand | Mano dominante | Mano dominante | Mão dominante |
| 右手（選び。`settings.hand.right`） | Right Hand | 右手 | 右手 | 오른손 | Main droite | Rechte Hand | Mano derecha | Mano destra | Mão direita |
| 左手（選び。`settings.hand.left`） | Left Hand | 左手 | 左手 | 왼손 | Main gauche | Linke Hand | Mano izquierda | Mano sinistra | Mão esquerda |
| 設定 › 利き手（文の中の道） | Settings > Dominant Hand | “设置” > 惯用手 | 「設定」> 慣用手 | 설정 > 주로 쓰는 손 | Réglages > Main dominante | Einstellungen > Dominante Hand | Ajustes > Mano dominante | Impostazioni > Mano dominante | Ajustes > Mão dominante |
| ツールバー（今の語。1.1 から） | toolbar | 工具栏 | 工具列 | 도구 막대 | barre d’outils | Werkzeugleiste | barra de herramientas | barra degli strumenti | barra de ferramentas |
| ツールバーを動かす（つまみの読み上げの名前。`toolbar.grip.spoken`） | Move Toolbar | 移动工具栏 | 移動工具列 | 도구 막대 옮기기 | Déplacer la barre d’outils | Werkzeugleiste verschieben | Mover la barra de herramientas | Sposta la barra degli strumenti | Mover a barra de ferramentas |
| つまみ（文書の中だけ。アプリの字には無い） | handle | — | — | — | — | — | — | — | — |
| 端（上下左右の端。`toolbar.grip.hint`） | edge | 边缘 | 邊緣 | 가장자리 | bord | Rand | borde | bordo | borda |
| 上へ移す（`toolbar.moveTo.top`） | Move to Top | 移到顶部 | 移到頂端 | 위로 옮기기 | Déplacer en haut | Nach oben | Mover arriba | Sposta in alto | Mover para cima |
| 下へ移す（`toolbar.moveTo.bottom`） | Move to Bottom | 移到底部 | 移到底部 | 아래로 옮기기 | Déplacer en bas | Nach unten | Mover abajo | Sposta in basso | Mover para baixo |
| 左へ移す（`toolbar.moveTo.left`） | Move to Left | 移到左侧 | 移到左側 | 왼쪽으로 옮기기 | Déplacer à gauche | Nach links | Mover a la izquierda | Sposta a sinistra | Mover para a esquerda |
| 右へ移す（`toolbar.moveTo.right`） | Move to Right | 移到右侧 | 移到右側 | 오른쪽으로 옮기기 | Déplacer à droite | Nach rechts | Mover a la derecha | Sposta a destra | Mover para a direita |
| しまった（ツールバー。`settings.hand.footer`） | hidden | 收起的 | 收起的 | 숨긴 | réduite | abgelegte | oculta | ridotta | oculta |
| 丸いボタン（しまったツールバー。`settings.hand.footer`） | round button | 圆形按钮 | 圓形按鈕 | 둥근 버튼 | bouton rond | runde Schaltfläche | botón redondo | pulsante rotondo | botão redondo |

### 決めたこと

- **等倍は、日と週と、月と年で中身が違います（契約 §16.3.1・§16.9。2026-11-22 の本人の直し）。** 日と週は 1 日・1 週のページの幅が画面の幅にちょうど合う大きさ、月と年はページを初めて開いたときの大きさです。前の定義（拡大も縮小もしていないもとの大きさ）と、その語（en original size、zh 原始大小、ko 원래 크기、fr taille d’origine、de Originalgröße、es・pt-BR tamaño・tamanho original、it dimensione originale）は使いません。日と週の等倍は、開いたときより大きいことが多いためです（iPad の日では約 2 倍）。
  - **名詞は「標準の大きさ」の語です**（表の 1 行目）。「もとの大きさ」は上のとおり日と週で違い、「既定の大きさ」（en default size など）も、日と週では初めて開いたときの大きさ（等倍を一度押すまで）と違うので避けました。de の Standardgröße と pt-BR の tamanho padrão は「既定」の意味も持ちますが、ほかに「もとの」「実際の」「合わせる」のどれでもない、ふつうの語がありません。
  - **文では、できるだけ名詞を使いません。** 読み上げと同じ「ズームを戻す」の動詞（下の点）で書き、大きさを言う所では上の定義をそのまま書きます（en は審査メモの字: on day and week pages, one day or one week fits the screen width exactly; month and year pages go back to the size they open at）。名詞は、そう書けない所だけで使います。
  - 「拡大も縮小もしていない」は、もう添えません（日と週の等倍は拡大した大きさのことがあるため）。拡大・縮小の語は今までどおり §2 の「2 本の指を広げる（拡大）・つまむ（縮小）」の行と同じです（en zoom in / zoom out、fr zoomer / dézoomer、de vergrößern / verkleinern、es・pt-BR ampliar / reducir・reduzir、it ingrandire / rimpicciolire、zh 放大 / 缩小・縮小、ko 확대 / 축소）。
  - 「実際の大きさ」の語（en Actual Size、zh-Hans 实际大小、zh-Hant 實際大小、ko 실제 크기、fr taille réelle、es tamaño real、it dimensioni reali、pt-BR tamanho real）は使いません。等倍は倍率 1.0（実寸）ではないためです（契約 §3.6。本人の iPhone の月では、倍率 1.0 は開いたときの約 3.2 倍）。
  - 「合わせる」の語（en Fit、fr Ajuster、de Einpassen、es・pt-BR Ajustar、it Adatta、zh 适合・適合、ko 맞춤）を、等倍の名前（読み上げと名詞）に使いません。**幅に合わせるのは日と週だけで、月と年は幅に合わせない（開いたときの大きさ）ためです**（契約 §16.9）。日と週の説明の文で「画面の幅にちょうど合う」と動詞で書くのは構いません（en fits the screen width exactly）。
- **読み上げ（等倍に戻す）は、どの言語も「ズームを戻す（リセットする）」の形です（契約 §16.9）。** en は契約 §8.1 の Reset Zoom のまま（英語の画面で、拡大を戻すボタンのふつうの名前。SUPPORT.en も “(Reset Zoom)” と書き、審査メモは見た目から “the 1× button” と書く）。8 言語は 2026-11-22 に、前の「もとの大きさに戻す」の訳（恢复原始大小、Auf Originalgröße zurücksetzen など）から訳し直しました。日と週では押すと大きくなることがあり、「もとの大きさに戻す」と聞くと違ってしまうためです。ja の字（等倍に戻す）と jaSha1 は同じなので、lint と `build.py` は前の訳が古いことを知らせません（契約 §16.10 の危険の行。元を見ない逆翻訳と判定は `REVIEW.md` の 15）。
  - ズームの語: zh・ko はアプリの今の字（zh は `onboarding.pen.text`・`settings.purchase.footer.readOnly` の 缩放・縮放、ko は `onboarding.pen.text` の 확대·축소）。fr・de もアプリの今の語（zoomer・zoomen）の名詞の zoom・Zoom。es・it・pt-BR のアプリは拡大を ampliar・ingrandire と書きますが、ズームを戻すボタンの名前では名詞の zoom がふつうなので、el zoom・lo zoom・o zoom にしました。
  - リセットの語: zh-Hans・zh-Hant 重置（契約 §16.9 の例。zh-Hans の iOS は「リセット」に 还原 を使う所もありますが、zh-Hant の 還原 はアプリの「元に戻す」なので、両方とも 重置 にそろえた）、ko 재설정（「-기」の形の 재설정하기 は不自然なので名詞のまま）、fr Réinitialiser、de zurücksetzen、es Restablecer、it Reimposta（Ripristina は購入の復元と同じ語なので避けた。下の点）、pt-BR Redefinir。どれもリセットのふつうの語です（出典は無い。下の「確かめていないこと」）。形は今の読み上げと同じです（fr・es・pt-BR は不定詞と定冠詞、de は名詞と不定詞、it は命令形、zh は動詞と名詞）。
- **「戻す」に、§2 の「元に戻す」「やり直す」の語を使いません。** 別のボタンと聞き違えないためです。特に zh-Hant の 還原（元に戻す）、fr の Rétablir（やり直す）と Annuler、es の Deshacer、it の Annulla、pt-BR の Desfazer。購入の復元（`settings.purchase.restore`）の語（zh-Hans 恢复、zh-Hant 回復、ko 복원、fr Restaurer、de wiederherstellen、es・pt-BR Restaurar、it Ripristina）も使いません（前の zh-Hans の 恢复原始大小 は 恢复购买 と同じ字でした）。
- **利き手・右手・左手は、人ではなく「手」の語にしました（性別の無い形）。** de・fr・es・it・pt-BR の「右利き・左利き」の語は人を指し、男女で形が変わります（de Rechtshänder／Rechtshänderin・Linkshänder／Linkshänderin、fr droitier／droitière・gaucher／gauchère、es diestro／diestra・zurdo／zurda、it destrimano／destrimana・mancino／mancina、pt-BR destro／destra・canhoto／canhota）。「手」の語（Hand・main・mano・mão）は、語に文法の性があっても、人の性別を言いません。見出しは「利き手」（dominant hand）、選びは「右の手」「左の手」です。en の Dominant Hand・Right Hand・Left Hand は契約 §8.1 の案のままです。
  - 文の中（脚注・新機能の文・ストアの文）でも、読み手を「左利きの人」と呼びません。選びの名前を引くか（« Main gauche »・„Linke Hand“・“Mano izquierda”・“Mano sinistra”・“Mão esquerda”）、読み手に向けた動詞で書きます（fr si vous écrivez de la main gauche、de wenn Sie mit der linken Hand schreiben、es si escribe con la mano izquierda、it se scrive con la mano sinistra、pt-BR se você escreve com a mão esquerda。§1 の丁寧さ）。en も left-handed people と書かず、“Left Hand” を引くか if you write with your left hand。zh は 左撇子（くだけた語）を使わず 左手、ko は 왼손잡이 を使わず 왼손（画面の選びと同じ字）。
  - 新機能の文の「利き手」「左手」は、アプリの `settings.hand.header`・`settings.hand.left` と同じ字にします（[docs/store/README.md](../store/README.md) の 1.4.1 の行）。
  - es は中南米でよく言う mano hábil ではなく、スペインと中南米の両方で通じる mano dominante です（§1 の es の決まり）。ko は 주로 쓰는 손（「主に使う手」。쓰다 は「使う」と「書く」の両方の意味で、アプリの 손가락으로 쓰기 と同じ動詞）。zh は 惯用手・慣用手（ふつうの語）。
- **ツールバーとしまうは、今の語のままです**（`toolbar.collapse.spoken`・`toolbar.dock.spoken` など 1.1〜1.2 の訳。しまうは §4 の表）。「ツールバーを動かす」は、今の「ツールバーをしまう」「ツールバーを出す」の読み上げと同じ形です（fr・es・pt-BR は不定詞と定冠詞、de は名詞と不定詞、it は命令形（§2 の Scrivi con il dito と同じ）、zh は動詞と名詞、ko は「명사 ＋ -기」）。脚注の「しまった」はしまうの語の形（en hidden、fr réduite、de abgelegte（Ablegen）、es・pt-BR oculta、it ridotta、zh 收起的、ko 숨긴）です。
- **4 つの操作は、今の丸いボタンの操作 `toolbar.moveEdge.*`（「左下へ移す」「右下へ移す」）と同じ形です。** en Move to Bottom Left → Move to Top、fr Déplacer en bas à gauche → Déplacer en haut、de Nach unten links → Nach oben（動詞を付けない今の形）、es Mover abajo a la izquierda → Mover arriba、it Sposta in basso a sinistra → Sposta in alto、pt-BR Mover para baixo à esquerda → Mover para cima、ko 왼쪽 아래로 옮기기 → 위로 옮기기、zh 移到左下角 → 移到顶部・移到頂端。
  - zh は「上方・下方」（上のほう）ではなく、端を指す 顶部・底部（zh-Hant は 頂端・底部）にしました。脚注の 屏幕顶部・螢幕頂端 と同じ字です。
- **en の大文字**: 1.4.1 の en の名前は全部 Title Case です（契約の Reset Zoom・Dominant Hand と、今の `toolbar.moveEdge.*` の Move to Bottom Left・`toolbar.pin` の Always Show Toolbar にそろえた）。今の読み上げの Hide toolbar・Show toolbar は変えません（読み上げでは大文字は聞こえません）。
- **つまみは、アプリの字に出ません**（読み上げは「ツールバーを動かす」で、つまみの名前を言わない）。名前が要るのは ja と en の SUPPORT と審査メモだけで、en は handle（SUPPORT.en の “the small handle”）。grip（コードの名前）と grabber（Apple の HIG の語）は、読み手に通じにくいので使いません。ほかの 8 言語の店の文では、つまみを名指さず「指でツールバーを動かす」と書きます（新機能の文の 4 行目のとおり）。
- **端**は、今の「左端」（`onboarding.dayPageTap`）の語にそろえました（en edge、fr bord、de Rand、es borde、it bordo、pt-BR borda）。zh は 边缘・邊緣、ko は 가장자리 です（今の 왼쪽 끝 の 끝 は「終わり」に近いので、4 つの辺には 가장자리）。
- 脚注と新機能の文の 3 行目の「画面の上のボタンの並びが左右逆」は、同じ言語では同じ言い方にします。
- **幅**: 読み上げだけの文（等倍に戻す・ツールバーを動かす・ヒント・4 つの操作）は画面に出ないので、§4 の幅の決まりはありません。利き手の見出し・選び・脚注は設定の画面の行で、折り返します。
- **「等倍」の字のボタン（`header.zoomReset`）は作りません。** 本人が 2026-11-22 に虫めがねに「1」の印を採りました（契約 §16.11 の問い 8・§16.12 の 0e-2）。字の訳と幅の確かめもしません。

### 確かめていないこと

- 利き手の語は、iOS に同じ項目が無く、Apple の記事で確かめた語ではありません（§3 のような出典はありません）。各言語のふつうの語から選びました。
- zh-Hant の 頂端・底部、ko の 주로 쓰는 손、de の Dominante Hand が、その言語の設定の画面で一番ふつうの言い方かは確かめていません。TestFlight で設定の画面と VoiceOver を見るときに、リードが字を見てください。
- 「ズームを戻す」の 8 言語（2026-11-22）が、その言語の VoiceOver でいちばんふつうに聞こえる名前かは確かめていません。Apple の画面に同じ役のボタンが無く、出典はありません。「標準の大きさ」の名詞（taille standard など）が、日と週の幅にちょうど合う大きさの呼び名として自然かも、母語の人の確認はありません。
