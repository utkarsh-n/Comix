import Foundation
import zlib

/// Streaming ZIP32 writer. Images are already compressed; storing them avoids
/// another large in-memory archive and satisfies EPUB's uncompressed mimetype rule.
final class StoredZIP {
    private struct Entry {
        var name: Data
        var crc: UInt32
        var size: UInt32
        var offset: UInt32
    }
    private let handle: FileHandle
    private var entries: [Entry] = []
    private var position: UInt64 = 0
    private var finished = false

    init(url: URL) throws {
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw ComixError.message("Could not create the EPUB. Check your available storage.")
        }
        handle = try FileHandle(forWritingTo: url)
    }
    deinit { try? handle.close() }

    func add(_ name: String, text: String) throws { try add(name, data: Data(text.utf8)) }
    func add(_ name: String, data: Data) throws {
        let entry = try header(name, size: UInt64(data.count), crc: Self.checksum(data))
        try write(data)
        entries.append(entry)
    }
    func add(_ name: String, file: URL) throws {
        let input = try FileHandle(forReadingFrom: file)
        defer { try? input.close() }
        var size: UInt64 = 0
        var crc: UInt32 = 0
        while let chunk = try input.read(upToCount: 1_048_576), !chunk.isEmpty {
            try Task.checkCancellation()
            size += UInt64(chunk.count)
            crc = Self.checksum(chunk, initial: crc)
        }
        let entry = try header(name, size: size, crc: crc)
        try input.seek(toOffset: 0)
        while let chunk = try input.read(upToCount: 1_048_576), !chunk.isEmpty {
            try Task.checkCancellation()
            try write(chunk)
        }
        entries.append(entry)
    }
    private func header(_ name: String, size: UInt64, crc: UInt32) throws -> Entry {
        let bytes = Data(name.utf8)
        guard !finished, entries.count < Int(UInt16.max), bytes.count <= Int(UInt16.max),
              size <= UInt64(UInt32.max), position + size + UInt64(bytes.count) + 30 <= UInt64(UInt32.max) else {
            throw ComixError.message("This comic exceeds the 4 GB EPUB limit. Choose a smaller image quality or split it into volumes.")
        }
        let entry = Entry(name: bytes, crc: crc, size: UInt32(size), offset: UInt32(position))
        var header = Data()
        header.le(UInt32(0x04034b50)); header.le(UInt16(10)); header.le(UInt16(0x0800))
        header.le(UInt16(0)); header.le(UInt16(0)); header.le(UInt16(33))
        header.le(crc); header.le(entry.size); header.le(entry.size)
        header.le(UInt16(bytes.count)); header.le(UInt16(0)); header.append(bytes)
        try write(header)
        return entry
    }
    func finish() throws {
        let start = position
        for entry in entries {
            var record = Data()
            record.le(UInt32(0x02014b50)); record.le(UInt16(20)); record.le(UInt16(10))
            record.le(UInt16(0x0800)); record.le(UInt16(0)); record.le(UInt16(0)); record.le(UInt16(33))
            record.le(entry.crc); record.le(entry.size); record.le(entry.size)
            record.le(UInt16(entry.name.count)); record.le(UInt16(0)); record.le(UInt16(0))
            record.le(UInt16(0)); record.le(UInt16(0)); record.le(UInt32(0)); record.le(entry.offset)
            record.append(entry.name)
            guard position + UInt64(record.count) + 22 <= UInt64(UInt32.max) else {
                throw ComixError.message("This comic is too large for EPUB. Choose a smaller image quality.")
            }
            try write(record)
        }
        var end = Data()
        end.le(UInt32(0x06054b50)); end.le(UInt16(0)); end.le(UInt16(0))
        end.le(UInt16(entries.count)); end.le(UInt16(entries.count))
        end.le(UInt32(position - start)); end.le(UInt32(start)); end.le(UInt16(0))
        try write(end)
        try handle.synchronize()
        try handle.close()
        finished = true
    }
    private func write(_ data: Data) throws { try handle.write(contentsOf: data); position += UInt64(data.count) }
    static func checksum(_ data: Data, initial: UInt32 = 0) -> UInt32 {
        data.withUnsafeBytes { bytes in
            UInt32(crc32(uLong(initial), bytes.bindMemory(to: Bytef.self).baseAddress, uInt(bytes.count)))
        }
    }
}

private extension Data {
    mutating func le<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
