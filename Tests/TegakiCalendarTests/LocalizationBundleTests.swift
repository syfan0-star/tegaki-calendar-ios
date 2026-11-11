import Foundation
import Layout
import XCTest
@testable import TegakiCalendar

/// The tables the app is built with (docs/M7B_CONTRACT.md §7.2, J-1): every language has every key
/// of tools/l10n/source, the Japanese is 1.1's text, and no right-to-left language slipped in. The
/// sources are read from the repository through `#filePath` (the simulator can read the Mac's files).
final class LocalizationBundleTests: XCTestCase {
    private static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private struct Key {
        var name: String
        var ja: String
        var target: String
        var was: [String]
        /// 1.3 (docs/M7C_CONTRACT.md D12, §8.1): the prototype build's words ("prototype.*") are in ja only.
        var jaOnly: Bool = false
    }

    /// Every key of tools/l10n/source/app-*.json.
    private func appKeys() throws -> [Key] {
        let folder = Self.repository.appendingPathComponent("tools/l10n/source", isDirectory: true)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasPrefix("app-") && $0.hasSuffix(".json") }
        XCTAssertFalse(names.isEmpty)
        var keys: [Key] = []
        for name in names.sorted() {
            let data = try Data(contentsOf: folder.appendingPathComponent(name))
            let file = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let entries = try XCTUnwrap(file["keys"] as? [String: [String: Any]])
            for (key, entry) in entries {
                keys.append(Key(name: key, ja: try XCTUnwrap(entry["ja"] as? String), target: try XCTUnwrap(entry["target"] as? String),
                                was: entry["was"] as? [String] ?? [], jaOnly: entry["jaOnly"] as? Bool ?? false))
            }
        }
        return keys.sorted { $0.name < $1.name }
    }

    func testEveryLanguageBundleHasEveryKey() throws {
        // A jaOnly key (the prototype's, 1.3) has its ja only; `testJapaneseMatchesTheOneOneBaseline` reads it.
        let keys = try appKeys().filter { $0.target == "app" && !$0.jaOnly }
        XCTAssertGreaterThan(keys.count, 200)
        for language in UILanguage.allCases {
            let missing = keys.map(\.name).filter { key in
                guard let value = L.value(key, in: language) else { return true }
                return value.isEmpty || value == key
            }
            XCTAssertEqual(missing, [], "\(language.rawValue).lproj has no value for \(missing.count) keys")
        }
    }

    func testInfoPlistIsLocalized() throws {
        let keys = ["CFBundleDisplayName", "NSCalendarsFullAccessUsageDescription"]
        let marker = "\u{E000}"
        for language in UILanguage.allCases {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language.rawValue, ofType: "lproj"), language.rawValue)
            let bundle = try XCTUnwrap(Bundle(path: path))
            for key in keys {
                let value = bundle.localizedString(forKey: key, value: marker, table: "InfoPlist")
                XCTAssertNotEqual(value, marker, "\(language.rawValue): \(key)")
                XCTAssertFalse(value.isEmpty, "\(language.rawValue): \(key)")
            }
        }
        // The Japanese is the value of project.yml, which the Info.plist itself holds (§2.2).
        let japanese = try XCTUnwrap(Bundle(path: try XCTUnwrap(Bundle.main.path(forResource: "ja", ofType: "lproj"))))
        let source = try appKeys().filter { $0.target == "infoplist" }
        XCTAssertEqual(Set(source.map(\.name)), Set(keys))
        for key in source {
            XCTAssertEqual(japanese.localizedString(forKey: key.name, value: nil, table: "InfoPlist"), key.ja)
            let projectFile = try String(contentsOf: Self.repository.appendingPathComponent("project.yml"), encoding: .utf8)
            XCTAssertTrue(projectFile.contains("\(key.name): \(key.ja)"), "project.yml has \(key.name): \(key.ja)")
        }
    }

    /// J-1 as the app really reads it: the simple keys of the ja table are the strings of
    /// tools/l10n/ja-baseline.tsv (lint L-3 checks the sources, this checks what was built).
    func testJapaneseMatchesTheOneOneBaseline() throws {
        let tsv = try String(contentsOf: Self.repository.appendingPathComponent("tools/l10n/ja-baseline.tsv"), encoding: .utf8)
        var rows: [String: [String]] = [:]
        for line in tsv.split(separator: "\n") where !line.hasPrefix("#") {
            let columns = line.components(separatedBy: "\t")
            XCTAssertEqual(columns.count, 3, String(line))
            rows["\(columns[0]):\(columns[1])", default: []].append(columns[2])
        }
        var compared = 0
        for key in try appKeys() where key.target == "app" {
            let value = try XCTUnwrap(L.value(key.name, in: .ja), key.name)
            XCTAssertEqual(value, key.ja, key.name)
            for reference in key.was {
                let parts = reference.components(separatedBy: "#")
                let bodies = try XCTUnwrap(rows[parts[0]], "\(key.name): \(reference) is not in ja-baseline.tsv")
                let strings = try bodies.map(Self.unescape)
                let picked: String?
                if parts.count > 1, let n = Int(parts[1]) {
                    picked = strings[n - 1]
                } else {
                    picked = strings.first { $0 == value }
                }
                XCTAssertEqual(picked, value, "\(key.name): \(reference)")
                compared += 1
            }
        }
        XCTAssertGreaterThan(compared, 200)
    }

    func testNoRightToLeftLocalization() {
        let localizations = Bundle.main.localizations
        for language in UILanguage.allCases {
            XCTAssertTrue(localizations.contains(language.rawValue), language.rawValue)
        }
        for language in localizations {
            let base = language.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? language
            XCTAssertFalse(["ar", "he", "fa", "ur"].contains(base.lowercased()), language)
        }
    }

    /// The value of a Swift string as ja-baseline.tsv writes it (the escapes of tools/l10n/baseline.py).
    /// A row with an interpolation has no value of its own, and no "was" points at it (lint L-3).
    private static func unescape(_ body: String) throws -> String {
        var out = ""
        var rest = Substring(body)
        while let ch = rest.popFirst() {
            guard ch == "\\" else {
                out.append(ch)
                continue
            }
            guard let next = rest.popFirst() else { break }
            switch next {
            case "n": out.append("\n")
            case "t": out.append("\t")
            case "r": out.append("\r")
            case "0": out.append("\0")
            case "\"", "'", "\\": out.append(next)
            case "(": return body  // composed from parts; never equal to a key's ja
            case "u":
                guard rest.first == "{", let close = rest.firstIndex(of: "}"),
                      let code = UInt32(rest[rest.index(after: rest.startIndex)..<close], radix: 16),
                      let scalar = Unicode.Scalar(code) else {
                    throw NSError(domain: "LocalizationBundleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: body])
                }
                out.unicodeScalars.append(scalar)
                rest = rest[rest.index(after: close)...]
            default:
                throw NSError(domain: "LocalizationBundleTests", code: 2, userInfo: [NSLocalizedDescriptionKey: body])
            }
        }
        return out
    }
}
