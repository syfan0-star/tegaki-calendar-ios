import Foundation
import XCTest
import Compat10
import CompatFixtures
import InkModel
import Layout

/// The fixture folder of the compatibility tests (M7A_CONTRACT §1.4, §7.2): the committed fixtures
/// of `Tests/Fixtures/compat11` (K's, P's and U's) plus K's large fixtures made again, prepared once
/// per test run in the temporary directory. Pages are read with the frozen 1.0 copy (`…10`) and with
/// the new code (`…11`); byte comparisons go through each side's own `InkPageCodec.encode`.
enum Compat10TestSupport {
    static let folder: URL = {
        let fm = FileManager.default
        let url = fm.temporaryDirectory
            .appendingPathComponent("TegakiKit-Compat10Tests-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
        try? fm.removeItem(at: url)
        do {
            try CompatFixtures.prepare(from: CompatFixtures.committedFolder, into: url)
        } catch {
            XCTFail("preparing the fixture folder: \(error)")
        }
        return url
    }()

    /// The page fixtures of the folder (`*.json` but digests.json and the export), sorted.
    static var pageNames: [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
            .filter { $0.hasSuffix(".json") && $0 != CompatFixtures.digests && $0 != CompatFixtures.export11 }
            .sorted()
    }

    static func data(_ name: String) -> Data? {
        try? Data(contentsOf: folder.appendingPathComponent(name))
    }

    static func page10(_ name: String) -> InkPageV10? {
        data(name).flatMap { try? InkPageCodecV10.decode($0) }
    }

    static func page11(_ name: String) -> InkPage? {
        data(name).flatMap { try? InkPageCodec.decode($0) }
    }

    static func bytes10(_ page: InkPageV10) -> Data? {
        try? InkPageCodecV10.encode(page)
    }

    static func bytes11(_ page: InkPage) -> Data? {
        try? InkPageCodec.encode(page)
    }

    /// The new page read by 1.0 (through its JSON).
    static func to10(_ page: InkPage) -> InkPageV10? {
        bytes11(page).flatMap { try? InkPageCodecV10.decode($0) }
    }

    /// The stroke objects of a page as 1.0 writes them, keyed by id.
    static func strokesJSON10(_ page: InkPageV10) -> [String: JSONValueV10] {
        page.jsonValue["strokes"]?.objectValue ?? [:]
    }

    /// The legacy fixture keeps an old band cell on purpose.
    static func isLegacy(_ name: String) -> Bool {
        name.contains(".legacy.")
    }
}
