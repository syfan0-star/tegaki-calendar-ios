import Foundation

/// A small JSON tree, used to keep unknown items of an ink page exactly as they were read
/// (DESIGN §3.9: a reader must write back what it does not understand).
public enum JSONValueV10: Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValueV10])
    case object([String: JSONValueV10])

    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    public var doubleValue: Double? {
        if case .number(let d) = self { return d }
        return nil
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var arrayValue: [JSONValueV10]? {
        if case .array(let a) = self { return a }
        return nil
    }

    public var objectValue: [String: JSONValueV10]? {
        if case .object(let o) = self { return o }
        return nil
    }

    public subscript(key: String) -> JSONValueV10? {
        objectValue?[key]
    }

    // MARK: - Parsing (JSONSerialization) and deterministic serialization

    public enum ParseError: Error, Equatable {
        case invalidJSON(String)
    }

    /// Parses JSON text. Throws for anything that is not well-formed JSON.
    public static func parse(_ data: Data) throws -> JSONValueV10 {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw ParseError.invalidJSON(String(describing: error))
        }
        return convert(object)
    }

    private static func convert(_ any: Any) -> JSONValueV10 {
        if any is NSNull { return .null }
        if let number = any as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
            return .number(number.doubleValue)
        }
        if let string = any as? String { return .string(string) }
        if let array = any as? [Any] { return .array(array.map(convert)) }
        if let object = any as? [String: Any] { return .object(object.mapValues(convert)) }
        return .null
    }

    /// Compact JSON text with object keys sorted, so equal values give byte-equal output on every
    /// platform. Integral numbers are written without a fraction ("3", not "3.0"); non-finite numbers
    /// become null.
    ///
    /// `pretty: false` (the default) is the compact form the stored files and iCloud use; its bytes
    /// never change. `pretty: true` is the readable form of the export file (M6_CONTRACT §1.3):
    /// - object: `{`, one key per line indented `indent + 2` spaces as `"key": value`, keys sorted,
    ///   `,` between members, then `}` on its own line at `indent`; an empty object is `{}`.
    /// - array: when every element is a number (or there is none) one line `[1, 2, 3]` (so a
    ///   stroke's `pts` stays on one line); otherwise one element per line like an object; an empty
    ///   array is `[]`.
    /// - numbers are `format(_:)` as in the compact form; strings and the other scalars too.
    /// `indent` is the indentation of the line the value starts on (its first line is not indented
    /// by this method: the caller has already written the key or the array's indentation).
    public func serialized(pretty: Bool = false, indent: Int = 0) -> String {
        var out = ""
        if pretty {
            writePretty(into: &out, indent: indent)
        } else {
            write(into: &out)
        }
        return out
    }

    public func serializedData(pretty: Bool = false) -> Data {
        Data(serialized(pretty: pretty).utf8)
    }

    private func writePretty(into out: inout String, indent: Int) {
        switch self {
        case .null, .bool, .number, .string:
            write(into: &out)
        case .array(let a):
            if a.isEmpty {
                out += "[]"
            } else if a.allSatisfy({ if case .number = $0 { return true } else { return false } }) {
                out += "["
                for (i, v) in a.enumerated() {
                    if i > 0 { out += ", " }
                    v.write(into: &out)
                }
                out += "]"
            } else {
                let inner = String(repeating: " ", count: indent + 2)
                out += "[\n"
                for (i, v) in a.enumerated() {
                    if i > 0 { out += ",\n" }
                    out += inner
                    v.writePretty(into: &out, indent: indent + 2)
                }
                out += "\n" + String(repeating: " ", count: indent) + "]"
            }
        case .object(let o):
            if o.isEmpty {
                out += "{}"
                return
            }
            let inner = String(repeating: " ", count: indent + 2)
            out += "{\n"
            for (i, key) in o.keys.sorted().enumerated() {
                if i > 0 { out += ",\n" }
                out += inner
                JSONValueV10.writeString(key, into: &out)
                out += ": "
                o[key]?.writePretty(into: &out, indent: indent + 2)
            }
            out += "\n" + String(repeating: " ", count: indent) + "}"
        }
    }

    private func write(into out: inout String) {
        switch self {
        case .null:
            out += "null"
        case .bool(let b):
            out += b ? "true" : "false"
        case .number(let d):
            out += JSONValueV10.format(d)
        case .string(let s):
            JSONValueV10.writeString(s, into: &out)
        case .array(let a):
            out += "["
            for (i, v) in a.enumerated() {
                if i > 0 { out += "," }
                v.write(into: &out)
            }
            out += "]"
        case .object(let o):
            out += "{"
            for (i, key) in o.keys.sorted().enumerated() {
                if i > 0 { out += "," }
                JSONValueV10.writeString(key, into: &out)
                out += ":"
                o[key]?.write(into: &out)
            }
            out += "}"
        }
    }

    /// Deterministic number text: integers plain, others Swift's shortest round-trip form.
    public static func format(_ d: Double) -> String {
        guard d.isFinite else { return "null" }
        if d == d.rounded(.towardZero), abs(d) < 9_007_199_254_740_992 {
            return String(Int64(d))
        }
        return "\(d)"
    }

    private static func writeString(_ s: String, into out: inout String) {
        out += "\""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        out += "\""
    }
}

// MARK: - Codable (so the ink types can also travel through JSONEncoder / JSONDecoder)

extension JSONValueV10: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let d = try? container.decode(Double.self) {
            self = .number(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([JSONValueV10].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: JSONValueV10].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let b):
            try container.encode(b)
        case .number(let d):
            if d.isFinite, d == d.rounded(.towardZero), abs(d) < 9_007_199_254_740_992 {
                try container.encode(Int64(d))
            } else if d.isFinite {
                try container.encode(d)
            } else {
                try container.encodeNil()
            }
        case .string(let s):
            try container.encode(s)
        case .array(let a):
            try container.encode(a)
        case .object(let o):
            try container.encode(o)
        }
    }
}
