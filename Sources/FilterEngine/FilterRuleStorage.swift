import ContentBlockerConverter
import Foundation

/// Main class for storing `FilterRule` objects in a file, allowing partial
/// in-memory usage.
///
/// This storage writes all rules sequentially (each rule is preceded by a
/// 4-byte length). It can be initialized from an array of text lines (e.g.,
/// raw rules) by parsing them all with `RuleFactory` at once, then writing each
/// resulting `FilterRule` to file. You can also open an existing storage file.
///
/// The storage provides:
///
/// 1. A custom Index type (representing a file offset).
/// 2. Subscript access by a `FilterRuleStorage.Index` to retrieve a single
///    rule in O(1) file I/O.
/// 3. An iterator (`FilterRuleStorage.Iterator`) to read all rules
///    sequentially, yielding (`Index`, `FilterRule`) pairs.
public class FilterRuleStorage {
    /// Magic string that's written to the file header. This is how we can
    /// detect that the file is serialized `FilterRuleStorage`.
    /// "FRS0" stands for "Filter Rule Storage version 0".
    ///
    /// If magic string is changed, `Schema.VERSION` **MUST** be incremented.
    private static let MAGIC_STR = "FRS0"

    private let fileURL: URL
    private var rulesCount: Int = 0

    // MARK: - Error

    public enum FilterRuleStorageError: Error {
        case invalidIndex
        case fileFormatError(reason: String)
        case readError(reason: String)
    }

    // MARK: - Index

    /// Represents the file offset where a rule is stored. You can subscript
    /// FilterRuleStorage with this Index to retrieve the corresponding rule.
    public struct Index {
        public let offset: UInt32

        public init(offset: UInt32) {
            self.offset = offset
        }
    }

    // MARK: - Creating new storage from lines, writing rules in a single pass

    public init(from lines: [String], for version: SafariVersion, fileURL: URL) throws {
        self.fileURL = fileURL
        try createStorageFile(from: lines, for: version)
        try readHeader()  // sets `rulesCount`
    }

    // MARK: - Loading existing storage

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        try readHeader()
    }

    // MARK: - Public API

    /// Returns the total number of rules stored.
    public var count: Int {
        return rulesCount
    }

    /// Subscript for random access by file offset (Index).
    ///
    /// This allows retrieving a single rule in O(1) for file I/O (plus decode time),
    /// but requires that you already have a valid Index (for example, one obtained
    /// from iterating).
    ///
    /// This function can throw a `FilterRuleStorageError` if it fails to read
    /// the rule from the storage.
    public subscript(index: Index) -> FilterRule {
        get throws {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { handle.closeFile() }

            handle.seek(toFileOffset: UInt64(index.offset))

            // 1) Read the 4-byte length
            let lengthData = handle.readData(ofLength: 4)
            if lengthData.count < 4 {
                throw FilterRuleStorageError.readError(
                    reason: "Cannot read length at offset \(index.offset)"
                )
            }
            let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self) }

            // 2) Read rule data
            let ruleData = handle.readData(ofLength: Int(length))
            if ruleData.count < Int(length) {
                throw FilterRuleStorageError.readError(
                    reason: "Cannot read rule data at offset \(index.offset)"
                )
            }

            // 3) Decode into FilterRule
            return try FilterRule.fromData(ruleData)
        }
    }

    /// Creates an iterator that yields (Index, FilterRule) pairs for all rules in this storage.
    ///
    /// Usage:
    ///   let iterator = try storage.makeIterator()
    ///   while let (idx, rule) = iterator.next() {
    ///       // ...
    ///   }
    public func makeIterator() throws -> Iterator {
        return try Iterator(fileURL: fileURL, totalCount: rulesCount)
    }

    // MARK: - Nested Iterator Class

    /// Iterator for accessing FilterRules in the storage
    public class Iterator: IteratorProtocol {
        private let fileHandle: FileHandle
        private let totalCount: Int
        private var readCount = 0

        /// Current offset in the file. Initially 8 (skip magic + count),
        /// then advanced after each read.
        private var currentOffset: UInt64

        public init(fileURL: URL, totalCount: Int) throws {
            self.fileHandle = try FileHandle(forReadingFrom: fileURL)
            self.totalCount = totalCount
            self.currentOffset = 8  // skip the 4-byte magic + 4-byte count
            fileHandle.seek(toFileOffset: currentOffset)
        }

        deinit {
            fileHandle.closeFile()
        }

        /// Reads the next rule if available, returning (Index, FilterRule).
        public func next() -> (FilterRuleStorage.Index, FilterRule)? {
            guard readCount < totalCount else {
                // No more rules
                return nil
            }

            // Save the offset for this rule's length field
            let ruleIndex = Index(offset: UInt32(currentOffset))

            // 1) Read 4-byte length
            let lengthData = fileHandle.readData(ofLength: 4)
            guard lengthData.count == 4 else {
                // truncated
                return nil
            }
            let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self) }

            // 2) Read encoded rule
            let ruleData = fileHandle.readData(ofLength: Int(length))
            guard ruleData.count == Int(length) else {
                // truncated
                return nil
            }

            // 3) Decode
            let rule: FilterRule
            do {
                rule = try FilterRule.fromData(ruleData)
            } catch {
                Logger.log("Failed to decode a rule: \(error)")

                // skip corrupted
                return nil
            }

            // Advance offset and read count
            currentOffset += 4 + UInt64(length)
            readCount += 1

            return (ruleIndex, rule)
        }
    }

    // MARK: - Internals

    /// Creates a new file, writes a magic header + placeholder count,
    /// then parses lines at once and writes each FilterRule in sequence.
    /// Finally, updates the count in the file header.
    private func createStorageFile(from lines: [String], for version: SafariVersion) throws {
        // Overwrite existing file if present
        try Data().write(to: fileURL, options: .atomic)
        let handle = try FileHandle(forUpdating: fileURL)
        defer { handle.closeFile() }

        // 1) Write 4-byte magic
        handle.write(Data("FRS0".utf8))

        // 2) Write 4-byte placeholder for count
        var zeroCount: UInt32 = 0
        handle.write(Data(bytes: &zeroCount, count: 4))

        // 3) Parse lines all at once and filter out exceptions
        var rawRules = RuleFactory.createRules(lines: lines, for: version)
        rawRules = RuleFactory.filterOutExceptions(from: rawRules)

        // 4) Convert each raw rule to a FilterRule and write it
        var writtenCount: UInt32 = 0
        for rawRule in rawRules {
            guard let filterRule = try? FilterRule(from: rawRule) else {
                continue  // skip unsupported
            }
            let encoded = try filterRule.toData()
            var length = UInt32(encoded.count)
            let lengthData = withUnsafeBytes(of: &length) { Data($0) }

            handle.write(lengthData)
            handle.write(encoded)
            writtenCount += 1
        }

        // 5) Seek back to update the rule count
        handle.seek(toFileOffset: 4)
        var count = writtenCount
        handle.write(withUnsafeBytes(of: &count) { Data($0) })
    }

    /// Reads the 4-byte magic and 4-byte count from the file header.
    private func readHeader() throws {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { handle.closeFile() }

        // 1) Read magic
        let magicData = handle.readData(ofLength: 4)
        guard let magicStr = String(data: magicData, encoding: .utf8), magicStr == Self.MAGIC_STR
        else {
            throw FilterRuleStorageError.fileFormatError(reason: "Wrong magic header")
        }

        // 2) Read count
        let countData = handle.readData(ofLength: 4)
        guard countData.count == 4 else {
            throw FilterRuleStorageError.fileFormatError(reason: "Missing rule count")
        }
        rulesCount = Int(countData.withUnsafeBytes { $0.load(as: UInt32.self) })
    }
}
