import Foundation

/// EngineMeta represents the metadata for the filter engine build.
/// It is designed for ultra-fast binary serialization and deserialization.
///
/// The binary file format is always 12 bytes:
/// - 8 bytes: Double (timestamp, seconds since 1970)
/// - 4 bytes: Int32 (schema version)
///
/// **IMPORTANT**
/// Changing this will lead to invalidating the engine cached in the extension
/// directory and makes it required to write additional migration code in the
/// extension.
public struct EngineMeta {
    /// The timestamp of when the engine was built (seconds since 1970).
    public let timestamp: Double
    /// The schema version used to build the engine.
    public let schemaVersion: Int32

    /// The fixed size of the binary representation (in bytes).
    private static let byteSize = 8 + 4

    /// Creates a new instance of EngineMeta.
    /// Exposing it as it may be necessary for migrations.
    public init(timestamp: Double, schemaVersion: Int32) {
        self.timestamp = timestamp
        self.schemaVersion = schemaVersion
    }

    /// Serializes the EngineMeta to a 12-byte Data object.
    public func toData() -> Data {
        var data = Data(capacity: Self.byteSize)
        var tsmp = timestamp
        var ver = schemaVersion
        withUnsafeBytes(of: &tsmp) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &ver) { data.append(contentsOf: $0) }

        return data
    }

    /// Deserializes EngineMeta from a 12-byte Data object.
    /// - Parameter data: The binary data to deserialize.
    /// - Returns: An EngineMeta instance if the data is valid, nil otherwise.
    public static func fromData(_ data: Data) -> EngineMeta? {
        guard data.count == byteSize else { return nil }
        let tsmp = data.withUnsafeBytes { $0.load(as: Double.self) }
        let ver = data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: Int32.self) }

        return EngineMeta(timestamp: tsmp, schemaVersion: ver)
    }

    /// Writes EngineMeta to the given file URL, atomically and protected by
    /// the lock if provided.
    ///
    /// - Parameters:
    ///   - meta: The EngineMeta instance to write.
    ///   - url: The destination file URL.
    ///   - lock: Optional FileLock for cross-process safety.
    /// - Throws: Any file or lock error.
    public static func write(meta: EngineMeta, to url: URL, lock: FileLock?) throws {
        lock?.lock()
        defer { _ = lock?.unlock() }
        let data = meta.toData()
        try data.write(to: url, options: .atomic)
    }

    /// Reads EngineMeta from the given file URL, protected by the lock if provided.
    /// - Parameters:
    ///   - url: The source file URL.
    ///   - lock: Optional FileLock for cross-process safety.
    /// - Returns: The EngineMeta instance, or throws if file is missing or corrupt.
    public static func read(from url: URL, lock: FileLock?) throws -> EngineMeta {
        lock?.lock()
        defer { _ = lock?.unlock() }
        let data = try Data(contentsOf: url)
        guard let meta = EngineMeta.fromData(data) else {
            throw EngineMeta.EngineMetaIOError.invalidData
        }
        return meta
    }

    /// Error type for EngineMeta read/write operations.
    public enum EngineMetaIOError: Error {
        case invalidData
    }
}
