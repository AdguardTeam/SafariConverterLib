import Foundation
import ContentBlockerConverter

/// WebExtension is a class that provides public interface to be used in web (or app) extensions.
///
/// It is responsible for the following pieces of work:
///
/// 1. Initializing `FilterEngine` and serializing it to a binary form.
/// 2. Keeping track of the storage schema version. Whenever the schema version is changed, the engine needs to be rebuilt.
/// 3. Rules lookup using the engine.
///
/// This class is supposed to be used in both the native extension and in the host app.
/// Generally, the host app builds the engine and serializes it to a binary form and later this binary form is used
/// by the native extension to lookup the rules.
///
/// This functionality requires having a shared file storage and shared UserDefaults since some information
/// must be shared between the host app and the native extension process.
public class WebExtension {
    /// Base directory name for storing all WebExtension related files.
    private static let BASE_DIR = ".webkit"

    /// UserDefaults key for storing the current schema version.
    private static let ENGINE_SCHEMA_VERSION_KEY = "com.adguard.safari-converter.schema-version"

    /// UserDefaults key for storing the timestamp when the engine was last built.
    private static let ENGINE_TIMESTAMP_KEY = "com.adguard.safari-converter.engine-timestamp"

    /// Name of the lock file used for synchronizing access to shared resources.
    private static let LOCK_FILE_NAME = "lock"

    /// Name of the file storing the original, uncompiled filtering rules.
    private static let RULES_FILE_NAME = "rules.txt"

    /// Name of the file storing the serialized `FilterRuleStorage`.
    private static let FILTER_RULE_STORAGE_FILE_NAME = "rules.bin"

    /// Name of the file storing the serialized `FilterEngine` index.
    private static let FILTER_ENGINE_INDEX_FILE_NAME = "engine.bin"

    /// Place where extension related files are to be stored.
    private let baseURL: URL

    /// `UserDefaults` shared between the extension process and the host app process.
    private let sharedUserDefaults: UserDefaults

    /// Safari version for which the engine should be built.
    private let version: SafariVersion

    /// `FileLock` object to synchronize operations between the extension process and the host app process.
    /// It protects access to file resources (`baseURL` etc).
    private let fileLock: FileLock?

    /// Cached instance of `FilterEngine`.
    private var filterEngine: FilterEngine?

    /// Last time the `FilterEngine` was deserialized.
    private var engineTimestamp: Double = 0

    /// Initializes a new instance of `WebExtension`.
    ///
    /// - Parameters:
    ///   - containerURL: path to the container directory that's shared between the host app
    ///                   and the web extension. This directory will be used to store filter rules,
    ///                   and the serialized `FilterEngine`.
    ///   - sharedUserDefaults: instance of `UserDefaults` shared between the host app
    ///                         and the web extension process. This instance will be used to
    ///                         store the engine timestamp and schema version.
    ///   - version: Safari version for which the rules are compiled.
    /// - Throws: throws error if it fails to create a directory for shared files
    public init(containerURL: URL,
                sharedUserDefaults: UserDefaults,
                version: SafariVersion
    ) throws {
        self.baseURL = containerURL.appendingPathComponent(WebExtension.BASE_DIR, isDirectory: true)
        self.sharedUserDefaults = sharedUserDefaults
        self.version = version

        let lockFilePath = baseURL.appendingPathComponent(WebExtension.LOCK_FILE_NAME).path
        self.fileLock = FileLock(filePath: lockFilePath)

        if !FileManager.default.fileExists(atPath: baseURL.path) {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        }
    }
}

// MARK: - Building FilterEngine from rules

extension WebExtension {
    /// Builds a `FilterEngine` from the specified rules and serializes it to a binary form that can later
    /// be used to very quickly deserialize it.
    ///
    /// This function is supposed to be used from the host app, but it can also be used from the native extension
    /// when migration to a new schema version is required (can occur when the
    /// app was updated).
    ///
    /// - Parameters:
    ///   - rules: rules to build the engine from.
    public func buildFilterEngine(rules: String) throws -> FilterEngine {
        self.fileLock?.lock()
        defer {
            _ = self.fileLock?.unlock()
        }

        let filterRuleStorageURL = baseURL.appendingPathComponent(WebExtension.FILTER_RULE_STORAGE_FILE_NAME)
        let filterEngineIndexURL = baseURL.appendingPathComponent(WebExtension.FILTER_ENGINE_INDEX_FILE_NAME)

        // First, prepare the filter rule storage.
        let storage = try FilterRuleStorage(
            from: rules.components(separatedBy: "\n"),
            for: version,
            fileURL: filterRuleStorageURL
        )

        // Build filter engine from rules in the storage.
        let engine = try FilterEngine(storage: storage)

        // Serialize the engine to a file.
        try engine.write(to: filterEngineIndexURL)

        // Save the original not-compiled rules. It may be required in the future
        // if we need to rebuild the engine when the schema version was changed.
        let rulesFileURL = baseURL.appendingPathComponent(WebExtension.RULES_FILE_NAME)
        try rules.write(to: rulesFileURL, atomically: true, encoding: .utf8)

        // Save the timestamp when the engine was built and the schema version.
        // This way, we can quickly determine if the engine needs to be rebuilt
        // later.
        let currentTimestamp = Date().timeIntervalSince1970
        sharedUserDefaults.set(currentTimestamp, forKey: WebExtension.ENGINE_TIMESTAMP_KEY)
        sharedUserDefaults.set(Schema.VERSION, forKey: WebExtension.ENGINE_SCHEMA_VERSION_KEY)

        return engine

        // TODO: acquire semaphore?
        // TODO: build engine
        // TODO: save rules to file in /.webext/rules.txt
        // TODO: save rule storage to /.webext/rules.bin
        // TODO: save engine index to /.webext/engine.bin
        // TODO: save engine timestamp to userdefaults
        // TODO: save schema version to userdefaults
        // TODO: release semaphore
    }
}

// MARK: - Reading FilterEngine from binary format

extension WebExtension {
    /// Gets or creates an instance of `FilterEngine`.
    private func getFilterEngine() -> FilterEngine? {
        let engineTimestamp = sharedUserDefaults.double(forKey: WebExtension.ENGINE_TIMESTAMP_KEY)
        if engineTimestamp == 0 {
            // Engine was never initialized.
            return nil
        }

        if engineTimestamp > self.engineTimestamp {
            let schemaVersion = sharedUserDefaults.integer(forKey: WebExtension.ENGINE_SCHEMA_VERSION_KEY)
            let engine = (schemaVersion == Schema.VERSION) ? readFilterEngine() : rebuildFilterEngine()

            if engine != nil {
                self.filterEngine = engine
                self.engineTimestamp = engineTimestamp
            }
        }

        return self.filterEngine
    }

    /// Re-builds the `FilterEngine` from the source rules
    private func rebuildFilterEngine() -> FilterEngine? {
        // TODO: Implement
        return nil
    }

    /// Reads `FilterEngine` from the persistent storage.
    private func readFilterEngine() -> FilterEngine? {
        self.fileLock?.lock()
        defer {
            _ = self.fileLock?.unlock()
        }


        let filterRuleStorageURL = baseURL.appendingPathComponent(WebExtension.FILTER_RULE_STORAGE_FILE_NAME)
        let filterEngineIndexURL = baseURL.appendingPathComponent(WebExtension.FILTER_ENGINE_INDEX_FILE_NAME)

        // Check if the relevant files exist, otherwise bail out
        guard FileManager.default.fileExists(atPath: filterRuleStorageURL.path),
              FileManager.default.fileExists(atPath: filterEngineIndexURL.path) else {
            // TODO(ameshkov): !!! Log this
            return nil
        }

        // Deserialize the FilterRuleStorage.
        guard let storage = try? FilterRuleStorage(fileURL: filterRuleStorageURL) else {
            // TODO(ameshkov): !!! Log this
            return nil
        }

        // Deserialize the engine.
        guard let engine = try? FilterEngine(storage: storage, indexFileURL: filterEngineIndexURL) else {
            // TODO(ameshkov): !!! Log this
            return nil
        }

        return engine

        // TODO: acquire semaphore
        // TODO: read engine timestamp from userdefaults.
        // TODO: if engine timestamp is zero/empty/whatever - exit, engine was never prepared.
        // TODO: read schema version
        // TODO: if schema version is okay, read from /.webext/rules.bin and /.webext/engine.bin
        // TODO: if schema version is too old or if could not read, use /.webext/rules.txt to build the engine
        // TODO: save new schema version to userdefaults
        // TODO: release semaphore
    }
}

// MARK: - Reading FilterEngine from binary format

extension WebExtension {
    /// Represents scriptlet data: its name and arguments.
    public struct Scriptlet {
        public let name: String
        public let args: [String]
    }

    /// Represents content script configuration that needs to be applied.
    public struct Configuration {
        public let css: [String]
        public let extendedCss: [String]
        public let js: [String]
        public let scriptlets: [Scriptlet]
        public let engineTimestamp: Double
    }

    /// Looks up filtering rules in the filtering engine.
    ///
    /// - Parameters:
    ///   - url: URL of the page where the rules should be applied.
    /// - Returns: the list of rules to be applied.
    public func lookup(for url: URL) -> Configuration? {
        return nil
    }
}

// MARK: - Working with shared files

// MARK: - Synchronizing resources access in WebExtension

extension WebExtension {
    private func lock() {
    }
}
