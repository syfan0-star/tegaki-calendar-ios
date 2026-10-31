import Foundation
import XCTest
import Compat10
import CompatFixtures
import InkModel
import Layout

/// The app export `tegaki-app-export` v1 (K-5: its version is not raised): a 1.1 export imports on
/// 1.0 page for page, and 1.0 writes it again to the same bytes as 1.1.
final class Compat10ExportTests: XCTestCase {
    private let support = Compat10TestSupport.self

    func testExport11ImportsOn10Equal() throws {
        let file = try XCTUnwrap(support.data(CompatFixtures.export11))
        let document10 = try AppExportV10.parse(json: JSONValueV10.parse(file))
        XCTAssertEqual(document10.app, "ios/1.1 (1)")
        XCTAssertEqual(document10.pages.map(\.pageId), ["d-2026-11-02", "m1-2026-11", "w-2026-11-02"])
        // Each page equals its fixture as 1.0 reads a page of an export (the week page migrated).
        let expected = try [CompatFixtures.dayPage, CompatFixtures.monthPage, CompatFixtures.weekLegacy].map { name in
            try XCTUnwrap(AppExportV10.parsePage(JSONValueV10.parse(XCTUnwrap(support.data(name)))), name)
        }
        XCTAssertEqual(document10.pages, expected)
        XCTAssertTrue(document10.pages.allSatisfy(AppExportV10.isWorthExporting))
        // Written again by 1.0: the same bytes as the new AppExport.encode.
        XCTAssertEqual(AppExportV10.encode(document10), file)
        let document11 = try AppExport.parse(json: JSONValue.parse(file))
        XCTAssertEqual(AppExport.encode(document11), file)
        for (a, b) in zip(document10.pages, document11.pages) {
            XCTAssertEqual(support.bytes10(a), support.bytes11(b), a.pageId)
        }
        // The streamed import of 1.1 reads what the whole-tree parse reads.
        guard case .app(let streamed, let skipped) = try InkImport.parse(file) else { return XCTFail("an app export") }
        XCTAssertEqual(streamed, document11)
        XCTAssertEqual(skipped, 0)
        // 1.0 refuses a version it does not know.
        XCTAssertThrowsError(try AppExportV10.parse(json: .object(["format": .string("tegaki-app-export"), "v": .number(2)]))) { error in
            XCTAssertEqual(error as? WebImportV10.ParseError, .unsupportedVersion(2))
        }
    }
}
