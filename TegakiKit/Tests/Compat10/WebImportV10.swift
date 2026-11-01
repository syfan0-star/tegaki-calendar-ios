// a21e469 TegakiKit/Sources/InkModel/WebImport.swift:1-1  imports
import Foundation

/// Only what `AppExport.parse` uses: `supportedVersion`, `ParseError` and `versionNumber`.
// a21e469 TegakiKit/Sources/InkModel/WebImport.swift:10-10  WebImportV10
public enum WebImportV10 {
    // a21e469 TegakiKit/Sources/InkModel/WebImport.swift:12-12  WebImportV10.supportedVersion
    public static let supportedVersion = 1

    // a21e469 TegakiKit/Sources/InkModel/WebImport.swift:29-35  WebImportV10.ParseError
    /// invalidJSON = not readable as JSON / notAnExport = `format` differs or the top level is not an
    /// object / unsupportedVersion = `v` > 1.
    public enum ParseError: Error, Equatable {
        case invalidJSON
        case notAnExport
        case unsupportedVersion(Int)
    }

    // a21e469 TegakiKit/Sources/InkModel/WebImport.swift:165-169  WebImportV10.versionNumber
    /// `v` as an Int; a missing or unusable value counts as version 1 (the only version so far).
    static func versionNumber(_ value: JSONValueV10?) -> Int {
        guard let raw = value?.doubleValue, raw.isFinite, abs(raw) < 1e9 else { return supportedVersion }
        return Int(raw.rounded())
    }
}
