import Foundation

// MARK: - Serializing and deserializing the engine

extension FilterEngine {
    // A "magic" marker we'll write at the start of the file so we can validate it on read.
    private static let fileMagic: [UInt8] = [0x46, 0x49, 0x4C, 0x54]  // e.g. "FILT" in ASCII

    /// A simple struct for holding tries data.
    struct SerializedData {
        let domainTrie: ByteArrayTrie
        let shortcutsTrie: ByteArrayTrie
        let tailIndices: [UInt32]
    }

    /// Writes engine's indexes (including both tries and tail indices) to the specified file.
    /// This file can then be used to quickly initialize `FilterEngine` by calling
    /// the init(storage:indexFileURL:) initializer.
    public func write(to indexFileURL: URL) throws {
        // 1. Serialize each trie to Data
        let domainData = domainTrie.write()
        let shortcutsData = shortcutsTrie.write()

        // 2. Prepare a Data object to store all components:
        //
        //    [ fileMagic (4 bytes)
        //      domainDataCount (UInt32) | domainData (bytes)
        //      shortcutsDataCount (UInt32) | shortcutsData (bytes)
        //      tailIndicesCount (UInt32) | tailIndices(each UInt32) ]
        //
        var output = Data()

        // Write the "magic" bytes
        output.append(contentsOf: Self.fileMagic)

        // Write domainData size
        FilterEngine.appendUInt32(&output, UInt32(domainData.count))

        // Write domainData
        output.append(domainData)

        // Write shortcutsData size
        FilterEngine.appendUInt32(&output, UInt32(shortcutsData.count))

        // Write shortcutsData
        output.append(shortcutsData)

        // Write tailIndices count
        FilterEngine.appendUInt32(&output, UInt32(tailIndices.count))

        // Write each tail index (as UInt32)
        for ruleIndex in tailIndices {
            FilterEngine.appendUInt32(&output, ruleIndex)
        }

        // 3. Write the final Data to the file
        try output.write(to: indexFileURL)
    }

    /// Reads the trie data and tail indexes from a previously saved index file.
    /// Verifies the magic bytes, then deserializes the domain trie, shortcuts trie, and the tail indices.
    ///
    /// - Parameter indexFileURL: The URL where the trie data is stored.
    /// - Returns: A tuple containing the domain trie, shortcuts trie, and tail indices array.
    /// - Throws: An error if the file cannot be read or if it fails to pass validation checks.
    static func readTries(
        from indexFileURL: URL
    ) throws -> SerializedData {
        let data = try Data(contentsOf: indexFileURL)
        var cursor = 0

        // 1. Validate magic bytes
        let magicCount = Self.fileMagic.count
        guard data.count >= magicCount else {
            throw FilterEngineError.invalidIndexFile("Index file too small to contain magic bytes.")
        }

        let fileMagicRead = [UInt8](data[cursor..<cursor + magicCount])
        guard fileMagicRead == Self.fileMagic else {
            throw FilterEngineError.invalidIndexFile("File magic mismatch.")
        }
        cursor += magicCount

        // 2. Read domain trie data
        guard data.count >= cursor + 4 else {
            throw FilterEngineError.invalidIndexFile("Not enough bytes to read domainData size.")
        }
        let domainDataCount = readUInt32(data, cursor)
        cursor += 4

        guard data.count >= cursor + Int(domainDataCount) else {
            throw FilterEngineError.invalidIndexFile("Not enough bytes to read domain trie data.")
        }
        let domainData = data[cursor..<(cursor + Int(domainDataCount))]
        cursor += Int(domainDataCount)

        // 3. Read shortcuts trie data
        guard data.count >= cursor + 4 else {
            throw FilterEngineError.invalidIndexFile("Not enough bytes to read shortcutsData size.")
        }
        let shortcutsDataCount = readUInt32(data, cursor)
        cursor += 4

        guard data.count >= cursor + Int(shortcutsDataCount) else {
            throw FilterEngineError.invalidIndexFile(
                "Not enough bytes to read shortcuts trie data."
            )
        }
        let shortcutsData = data[cursor..<(cursor + Int(shortcutsDataCount))]
        cursor += Int(shortcutsDataCount)

        // 4. Read tail indices
        guard data.count >= cursor + 4 else {
            throw FilterEngineError.invalidIndexFile("Not enough bytes to read tailIndices count.")
        }
        let tailCount = readUInt32(data, cursor)
        cursor += 4

        // For each tail index, read a UInt32
        var tailIndices: [UInt32] = []
        tailIndices.reserveCapacity(Int(tailCount))

        let bytesNeededForTail = Int(tailCount) * MemoryLayout<UInt32>.size
        guard data.count >= cursor + bytesNeededForTail else {
            throw FilterEngineError.invalidIndexFile("Not enough bytes to read all tailIndices.")
        }

        for _ in 0..<tailCount {
            let ruleIndex: UInt32 = readUInt32(data, cursor)
            cursor += 4
            tailIndices.append(ruleIndex)
        }

        // 5. Construct trie objects
        let domainTrie = ByteArrayTrie(from: Data(domainData))
        let shortcutsTrie = ByteArrayTrie(from: Data(shortcutsData))

        return SerializedData(
            domainTrie: domainTrie,
            shortcutsTrie: shortcutsTrie,
            tailIndices: tailIndices
        )
    }

    private static func appendUInt32(_ data: inout Data, _ value: UInt32) {
        var littleEndianValue = value.littleEndian
        withUnsafeBytes(of: &littleEndianValue) {
            data.append(contentsOf: $0)
        }
    }

    private static func readUInt32(_ data: Data, _ cursor: Int) -> UInt32 {
        // Manual bit-shift
        let byte0 = UInt32(data[cursor])
        let byte1 = UInt32(data[cursor + 1]) << 8
        let byte2 = UInt32(data[cursor + 2]) << 16
        let byte3 = UInt32(data[cursor + 3]) << 24
        return byte0 | byte1 | byte2 | byte3
    }
}

/// An error type to indicate an invalid or corrupted index file.
enum FilterEngineError: Error {
    case invalidIndexFile(String)
}
