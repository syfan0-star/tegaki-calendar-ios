import Foundation
import Compression

public enum InkCodecError: Error, Equatable {
    /// The data is not well-formed JSON (the stored file is corrupt).
    case invalidJSON(String)
    /// The JSON is well-formed but not an object.
    case notAnObject
    case compressionFailed
    case decompressionFailed
}

/// JSON (DESIGN §3.9) and LZFSE for `InkPage`. Files are `<pageId>.json.lzfse` = `compress(encode(page))`.
public enum InkPageCodec {
    /// Deterministic JSON (keys sorted, compact). Tombstoned strokes are not written.
    public static func encode(_ page: InkPage) throws -> Data {
        page.jsonValue.serializedData()
    }

    /// Tolerant read: throws only when the data is not a JSON object; broken strokes are dropped and
    /// unknown items are kept (see `InkPage.init(json:)`).
    public static func decode(_ data: Data) throws -> InkPage {
        let json: JSONValue
        do {
            json = try JSONValue.parse(data)
        } catch {
            throw InkCodecError.invalidJSON(String(describing: error))
        }
        guard json.objectValue != nil else { throw InkCodecError.notAnObject }
        return InkPage(json: json)
    }

    /// LZFSE-compresses `data` (an empty input gives the LZFSE end-of-stream marker).
    public static func compress(_ data: Data) throws -> Data {
        try run(data, operation: COMPRESSION_STREAM_ENCODE, failure: .compressionFailed)
    }

    /// Inverse of `compress`. Throws for data that is not a complete LZFSE stream.
    public static func decompress(_ data: Data) throws -> Data {
        try run(data, operation: COMPRESSION_STREAM_DECODE, failure: .decompressionFailed)
    }

    private static func run(_ input: Data, operation: compression_stream_operation, failure: InkCodecError) throws -> Data {
        let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { stream.deallocate() }
        guard compression_stream_init(stream, operation, COMPRESSION_LZFSE) == COMPRESSION_STATUS_OK else {
            throw failure
        }
        defer { compression_stream_destroy(stream) }

        let chunk = 64 * 1024
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: chunk)
        defer { destination.deallocate() }

        // A non-empty source array keeps the source pointer valid even for empty input (size 0).
        let source: [UInt8] = input.isEmpty ? [0] : [UInt8](input)
        var output = Data()
        try source.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { throw failure }
            stream.pointee.src_ptr = base
            stream.pointee.src_size = input.count
            var idleRounds = 0
            while true {
                stream.pointee.dst_ptr = destination
                stream.pointee.dst_size = chunk
                let status = compression_stream_process(stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                let produced = chunk - stream.pointee.dst_size
                if produced > 0 { output.append(destination, count: produced) }
                if status == COMPRESSION_STATUS_END { break }
                guard status == COMPRESSION_STATUS_OK else { throw failure }
                if produced == 0 && stream.pointee.src_size == 0 {
                    idleRounds += 1
                    if idleRounds > 8 { throw failure }
                } else {
                    idleRounds = 0
                }
            }
        }
        if operation == COMPRESSION_STREAM_DECODE && stream.pointee.src_size != 0 {
            // Trailing bytes after the end of the stream: not a file we wrote.
            throw failure
        }
        return output
    }
}
