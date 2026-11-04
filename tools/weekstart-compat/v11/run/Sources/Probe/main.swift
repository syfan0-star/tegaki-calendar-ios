import Foundation
import CoreGraphics
import InkModel
import Layout
var fails = 0
func say(_ s: String) { print(s) }
func ck(_ c: Bool, _ s: String) { print((c ? "ok   " : "FAIL ") + s); if !c { fails += 1 } }
func pts(_ x: CGFloat, _ y: CGFloat) -> [InkPoint] { (0..<4).map { InkPoint(x: x + CGFloat($0) * 5, y: y + CGFloat($0), dtMs: 8 * $0, sizeW: 2, sizeH: 2, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.5) } }
func st(_ id: String, _ cell: CellKey, x: CGFloat, y: CGFloat = 100, t: Int = 1_780_000_000_000) -> InkStroke { InkStroke(id: id, cell: cell, tool: .pen, color: "#1f2937", t: t, dev: "ipad-12", points: pts(x, y)) }
let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Tokyo")!; return c }()
let now = DayKey(year: 2026, month: 11, day: 4).startOfDay(in: cal)

// ── A. A Sunday week page written by 1.2
var sunday = InkPage(pageId: "w-2026-11-01")
sunday.add(st("s1", .grid, x: 80, y: 300))
sunday.add(st("s2", .grid, x: 1300, y: 1500))
sunday.add(st("s3-gone", .grid, x: 500))
sunday.remove(ids: ["s3-gone"], at: 1_780_000_100_000)
ck(sunday.liveStrokeCount == 2 && sunday.deleted.count == 1, "A0 built: 2 live, 1 tombstone")
let json = sunday.jsonValue
let back = InkPage(json: json)
ck(back == sunday, "A1 read: InkPage(json:) keeps the page as it is")
ck(!BandMigration.needsMigration(back) && BandMigration.migrate(back) == back, "A2 BandMigration: nothing to move, same page")
let coded = try! InkPageCodec.encode(sunday); let decoded = try! InkPageCodec.decode(coded)
ck(decoded == sunday, "A3 codec: the stored file form round trips")
var older = InkPage(pageId: "w-2026-11-01"); older.add(st("s0", .grid, x: 300, t: 1_770_000_000_000))
let merged = InkPage.merge(older, sunday)
ck(merged.liveStrokeCount == 3 && merged.deleted["s3-gone"] != nil && merged.pageId == "w-2026-11-01", "A4 merge: union kept, tombstone wins, id unchanged")
ck(InkPage.merge(sunday, sunday) == sunday, "A5 merge with itself: the same")

// never opened: every day of 2000-2099 maps to a Monday page
var d = DayKey(year: 2000, month: 1, day: 1); var sundayIds = 0; var n = 0
while d.year < 2100 { let id = PageNavigation.pageId(.week, focus: d); if DayKey(ymd: String(id.dropFirst(2)))!.weekday != 1 { sundayIds += 1 }; n += 1; d = d.adding(days: 1) }
ck(sundayIds == 0, "A6 this version writes / opens only Monday w- ids (\(n) days)")
let lay = WeekLayoutEngine.layout(WeekLayoutInput(focus: DayKey(year: 2026, month: 11, day: 1), events: [], inkBottoms: [:], now: now, calendar: cal))
say("     focus Sunday 2026-11-01 opens \(lay.pageId)")

// export -> import through the app door
let doc = AppExport.Document(exportedAt: "2026-11-04T12:00:00+09:00", app: "ios/1.2 (1)", pages: [sunday])
let bytes = AppExport.encode(doc)
let parsed = try! InkImport.parse(bytes)
let outcome = InkImport.pages(parsed)
ck(outcome.pages == [sunday] && outcome.skipped == 0 && outcome.isAppExport, "A7 app export -> import: the Sunday page comes in whole, skipped 0")
let reexport = AppExport.encode(AppExport.Document(exportedAt: doc.exportedAt, app: doc.app, pages: outcome.pages))
ck(reexport == bytes, "A8 this version writes the same bytes back")

// web format: Sunday w- stays refused
let web = ##"{"format":"tegaki-web-export","v":1,"pages":[{"pageId":"w-2026-11-01","updatedAt":5,"deleted":{},"strokes":{"x":{"id":"x","tool":"pen","color":"#000000","size":3.5,"t":5,"pts":[1,1,0.5,2,2,0.5]}}}]}"##
if case .web(let wd) = try! InkImport.parse(Data(web.utf8)) {
  let c = WebImport.convert(wd)
  ck(c.pages.isEmpty && c.skipped.map(\.reason) == [.legacyPageId], "A9 web export: a Sunday w- is skipped as legacy")
} else { ck(false, "A9 web") }

// ── B. A month page written under the Sunday grid
let ym = YearMonth(year: 2026, month: 11)  // Nov 1 2026 is a Sunday: Monday grid Oct 26–Dec 6, Sunday grid Nov 1–Dec 12
var month = InkPage(pageId: ym.inkPageId)
month.add(st("both", .day(DayKey(year: 2026, month: 11, day: 14)), x: 20))
month.add(st("sunOnly", .day(DayKey(year: 2026, month: 12, day: 12)), x: 20))
month.add(st("monOnly", .day(DayKey(year: 2026, month: 10, day: 26)), x: 20))
month.add(st("memo", .memo, x: 20))
let cells = MonthLayoutEngine.layout(MonthLayoutInput(month: ym, events: [], inkBottoms: month.inkBottoms(), now: now, calendar: cal)).cells
let drawn = month.liveStrokes.filter { cells[$0.cell] != nil }.map(\.id).sorted()
ck(drawn == ["both", "memo", "monOnly"], "B1 this version draws only cells of its own grid: \(drawn)")
ck(cells[.day(DayKey(year: 2026, month: 12, day: 12))] == nil, "B2 12/12 is not a cell here")
let mback = InkPage(json: month.jsonValue)
ck(mback == month && mback.strokes["sunOnly"] != nil, "B3 read: the stroke of the missing cell stays")
ck(InkPage.merge(mback, month) == month, "B4 merge: stays")
let mo = InkImport.pages(try! InkImport.parse(AppExport.encode(AppExport.Document(exportedAt: "", app: "", pages: [month]))))
ck(mo.pages == [month], "B5 export -> import: stays")
let h = MonthLayoutEngine.layout(MonthLayoutInput(month: ym, events: [], inkBottoms: ["2026-12-12": 900].reduce(into: [CellKey: CGFloat]()) { $0[.day(DayKey(ymd: $1.key)!)] = $1.value }, now: now, calendar: cal))
ck(h.size.height == MonthLayoutEngine.layout(MonthLayoutInput(month: ym, events: [], inkBottoms: [:], now: now, calendar: cal)).size.height, "B6 a tall stroke on the missing cell does not grow this version's paper")
// 1.1 and later only
let parsedId = PageNavigation.parse(pageId: "w-2026-11-01")
say("     parse w-2026-11-01 -> \(String(describing: parsedId?.kind)) \(parsedId?.focus.description ?? "nil")")
say("     pageLabel on this version: \(StrokeBudget.pageLabel("w-2026-11-01"))  (the page really shows 2026-11-01..11-07 on 1.2)")
ck(StrokeBudget.importExceedsLegacyCap(localIds: [], incoming: sunday) == nil, "C1 import check: no warning")
ck(sunday.budgetCount == 2, "C2 budget counts this page alone")
print("<1.1.1> real code (tools/l10n/ja-baseline-ref.txt): failures \(fails)")
exit(fails == 0 ? 0 : 1)
