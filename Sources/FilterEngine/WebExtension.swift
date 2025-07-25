import ContentBlockerConverter
import Foundation
import PublicSuffixList

/// WebExtension is a class that provides public interface to be used in web
/// (or app) extensions.
///
/// It is responsible for the following pieces of work:
///
/// 1. Initializing `FilterEngine` and serializing it to a binary form.
/// 2. Keeping track of the storage schema version. Whenever the schema version
///    is changed, the engine needs to be rebuilt.
/// 3. Rules lookup using the engine.
///
/// This class is supposed to be used in both the native extension and in the
/// host app.
///
/// Generally, the host app builds the engine and serializes it to a binary form
/// and later this binary form is used by the native extension to lookup the
/// rules.
///
/// This functionality requires having a shared file storage since some
/// information must be shared between the host app and the native extension
/// process.
///
/// WebExtension stores its information in a shared directory `Schema.BASE_DIR`,
/// and there are three important files that are kept there:
///
/// - `Schema.ENGINE_META_FILE_NAME` - engine meta info (timestamp, schema
///   version)
/// - `Schema.RULES_FILE_NAME` - plain text advanced rules. This file will be
///   used if the serialized engine file is missing and the engine needs to be
///   rebuilt.
/// - `Schema.FILTER_RULE_STORAGE_FILE_NAME` - serialized `FilterRuleStorage`.
/// - `Schema.FILTER_ENGINE_INDEX_FILE_NAME` - serialized `FilterEngine` index.
/// - `Schema.MIGRATION_MARKER_FILE_NAME` - marker file used to signal that
///   migration (engine rebuild) is in progress.
/// - `Schema.LOCK_FILE_NAME` - lock file used for synchronizing access to
///   shared resources between different processes. See `EngineMeta` for more
///   details.
public class WebExtension {
    /// Place where extension related files are to be stored.
    private let baseURL: URL

    /// Safari version for which the engine should be built.
    private let version: SafariVersion

    /// `FileLock` object to synchronize operations between the extension
    /// process and the host app process. It protects access to file resources
    /// (`baseURL` etc).
    private let fileLock: FileLock?

    /// Cached instance of `FilterEngine`.
    private var filterEngine: FilterEngine?

    /// Last time the `FilterEngine` was deserialized.
    private var engineTimestamp: Double = 0

    /// Initializes a new instance of `WebExtension`.
    ///
    /// - Parameters:
    ///   - containerURL: Path to the container directory that's shared between
    ///                   the host app and the web extension. This directory
    ///                   will be used to store filter rules, engine meta info,
    ///                   and the serialized `FilterEngine`.
    ///   - version: Safari version for which the rules are compiled.
    /// - Throws: throws WebExtensionError if it fails to create a directory for
    ///           shared files
    public init(
        containerURL: URL,
        version: SafariVersion = SafariVersion.autodetect()
    ) throws {
        self.baseURL = containerURL.appendingPathComponent(Schema.BASE_DIR, isDirectory: true)
        self.version = version

        let lockFilePath = baseURL.appendingPathComponent(Schema.LOCK_FILE_NAME).path
        self.fileLock = FileLock(filePath: lockFilePath)

        if !FileManager.default.fileExists(atPath: baseURL.path) {
            do {
                try FileManager.default.createDirectory(
                    at: baseURL,
                    withIntermediateDirectories: true
                )
            } catch {
                throw WebExtensionError.containerURLCreationFailed(
                    url: baseURL,
                    underlyingError: error
                )
            }
        }
    }

    /// Error types that can be thrown by WebExtension
    public enum WebExtensionError: Error {
        /// Failed to get container URL for the specified group ID
        case containerURLNotFound(groupID: String)

        /// Failed to create container directory at the specified URL
        case containerURLCreationFailed(url: URL, underlyingError: Error)

        /// Failed to build filter engine
        case buildEngineFailed(underlyingError: Error)
    }
}

// MARK: - WebExtension singleton

extension WebExtension {
    /// Dictionary to store WebExtension instances by (groupID, version)
    private static var instances: [InstanceKey: WebExtension] = [:]
    private struct InstanceKey: Hashable {
        let groupID: String
        let version: Double
    }

    /// Shared lock to protect access to the instances dictionary
    private static let instancesLock = NSLock()

    /// Returns a shared instance of WebExtension for the specified app group.
    /// If an instance for the specified group ID already exists, returns it.
    /// Otherwise, creates a new instance.
    ///
    /// - Parameters:
    ///   - groupID: App group identifier
    ///   - version: Safari version for which the rules are compiled
    /// - Returns: A shared instance of WebExtension
    /// - Throws: WebExtensionError if it fails to initialize WebExtension
    public static func shared(
        groupID: String,
        version: SafariVersion = SafariVersion.autodetect()
    ) throws -> WebExtension {
        instancesLock.lock()
        defer {
            instancesLock.unlock()
        }

        let key = InstanceKey(groupID: groupID, version: version.doubleValue)
        if let instance = Self.instances[key] {
            return instance
        }

        // Get the shared container URL for the app group
        guard
            let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: groupID
            )
        else {
            throw WebExtensionError.containerURLNotFound(groupID: groupID)
        }

        // Initialize WebExtension instance
        let instance = try WebExtension(
            containerURL: containerURL,
            version: version
        )

        // Store the instance
        instances[key] = instance

        return instance
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
    /// - Returns: A `FilterEngine` instance.
    /// - Throws: `WebExtensionError` if it fails to build the engine.
    public func buildFilterEngine(rules: String) throws -> FilterEngine {
        self.fileLock?.lock()
        defer {
            _ = self.fileLock?.unlock()
        }

        let filterRuleStorageURL = baseURL.appendingPathComponent(
            Schema.FILTER_RULE_STORAGE_FILE_NAME
        )
        let filterEngineIndexURL = baseURL.appendingPathComponent(
            Schema.FILTER_ENGINE_INDEX_FILE_NAME
        )

        do {
            // First, prepare the filter rule storage.
            let storage = try FilterRuleStorage(
                from: rules.components(separatedBy: "\n"),
                for: version,
                fileURL: filterRuleStorageURL
            )
            Logger.log("Initialized filter rule storage for \(filterRuleStorageURL.path).")

            // Build filter engine from rules in the storage.
            let engine = try FilterEngine(storage: storage)

            Logger.log("Initialized FilterEngine")

            // Serialize the engine to a file.
            try engine.write(to: filterEngineIndexURL)

            Logger.log("Serialized FilterEngine to \(filterEngineIndexURL.path)")

            // Save the original not-compiled rules. It may be required in the future
            // if we need to rebuild the engine when the schema version was changed.
            let rulesFileURL = baseURL.appendingPathComponent(Schema.RULES_FILE_NAME)
            try rules.write(to: rulesFileURL, atomically: true, encoding: .utf8)

            Logger.log("Saved plain text rules to \(rulesFileURL.path)")

            // Save the timestamp and schema version to the meta file for fast access.
            // This allows quick determination if the engine needs to be rebuilt later.
            let currentTimestamp = Date().timeIntervalSince1970
            let meta = EngineMeta(timestamp: currentTimestamp, schemaVersion: Int32(Schema.VERSION))
            let metaURL = baseURL.appendingPathComponent(Schema.ENGINE_META_FILE_NAME)
            try EngineMeta.write(meta: meta, to: metaURL, lock: fileLock)

            Logger.log("Saved metadata to \(metaURL.path)")

            // Clean up migration marker file if it exists
            let migrationMarkerURL = baseURL.appendingPathComponent(
                Schema.MIGRATION_MARKER_FILE_NAME
            )
            if FileManager.default.fileExists(atPath: migrationMarkerURL.path) {
                Logger.log("Removing migration marker at \(migrationMarkerURL.path)")

                try? FileManager.default.removeItem(at: migrationMarkerURL)
            }

            return engine
        } catch {
            throw WebExtensionError.buildEngineFailed(underlyingError: error)
        }
    }
}

// MARK: - Reading FilterEngine from binary format

extension WebExtension {
    /// Gets or creates an instance of `FilterEngine`.
    private func getFilterEngine() -> FilterEngine? {
        Logger.log("Getting filter engine")

        // Read engine meta info from the binary meta file for fast access.
        let metaURL = baseURL.appendingPathComponent(Schema.ENGINE_META_FILE_NAME)
        guard let meta = try? EngineMeta.read(from: metaURL, lock: fileLock) else {
            Logger.log("FilterEngine meta file not found, engine was never initialized")

            return nil
        }
        let engineTimestamp = meta.timestamp
        let schemaVersion = Int(meta.schemaVersion)

        if engineTimestamp > self.engineTimestamp {
            if schemaVersion == Schema.VERSION {
                Logger.log("Reading FilterEngine from binary format")

                self.filterEngine = readFilterEngine()
                self.engineTimestamp = engineTimestamp
            } else {
                Logger.log("FilterEngine migration is required")

                let engine = rebuildFilterEngine()
                if engine != nil {
                    self.filterEngine = engine

                    // Read the timestamp again since it was changed when rebuilding.
                    if let updatedMeta = try? EngineMeta.read(from: metaURL, lock: fileLock) {
                        self.engineTimestamp = updatedMeta.timestamp
                    }
                }
            }
        }

        return self.filterEngine
    }

    /// Re-builds the `FilterEngine` from the source rules. This may be
    /// necessary when the schema version has changed, but we have not yet
    /// rebuilt the engine.
    private func rebuildFilterEngine() -> FilterEngine? {
        self.fileLock?.lock()
        defer {
            _ = self.fileLock?.unlock()
        }

        let migrationMarkerURL = baseURL.appendingPathComponent(Schema.MIGRATION_MARKER_FILE_NAME)
        // Step 1: Check if migration marker file exists
        if FileManager.default.fileExists(atPath: migrationMarkerURL.path) {
            Logger.log(
                "Migration marker file exists. Previous migration may have been "
                    + "interrupted. Skipping rebuild this time."
            )

            return nil
        }

        // Step 2: Create migration marker file
        FileManager.default.createFile(
            atPath: migrationMarkerURL.path,
            contents: nil,
            attributes: nil
        )

        defer {
            Logger.log("Removing migration marker file")

            // Make sure the marker is cleaned up if the migration was not
            // interrupted.
            try? FileManager.default.removeItem(at: migrationMarkerURL)
        }

        let filterRulesURL = baseURL.appendingPathComponent(Schema.RULES_FILE_NAME)
        if !FileManager.default.fileExists(atPath: filterRulesURL.path) {
            Logger.log("Plain text rules file not found, skipping rebuild")

            return nil
        }

        do {
            Logger.log("Reading plain text rules from \(filterRulesURL)")
            let rules = try String(contentsOf: filterRulesURL, encoding: .utf8)

            Logger.log("Building filter engine from rules")
            let engine = try buildFilterEngine(rules: rules)

            return engine
        } catch {
            Logger.log("Failed to rebuild the engine: \(error)")
        }

        return nil
    }

    /// Reads `FilterEngine` from the persistent storage.
    private func readFilterEngine() -> FilterEngine? {
        self.fileLock?.lock()
        defer {
            _ = self.fileLock?.unlock()
        }

        let filterRuleStorageURL = baseURL.appendingPathComponent(
            Schema.FILTER_RULE_STORAGE_FILE_NAME
        )
        let filterEngineIndexURL = baseURL.appendingPathComponent(
            Schema.FILTER_ENGINE_INDEX_FILE_NAME
        )

        // Check if the relevant files exist, otherwise bail out
        guard FileManager.default.fileExists(atPath: filterRuleStorageURL.path),
            FileManager.default.fileExists(atPath: filterEngineIndexURL.path)
        else {
            Logger.log("Not found filter rule storage and engine files")

            return nil
        }

        // Deserialize the FilterRuleStorage.
        guard let storage = try? FilterRuleStorage(fileURL: filterRuleStorageURL) else {
            Logger.log("Failed to deserialize the rule storage")

            return nil
        }

        // Deserialize the engine.
        guard let engine = try? FilterEngine(storage: storage, indexFileURL: filterEngineIndexURL)
        else {
            Logger.log("Failed to deserialize the engine")

            return nil
        }

        return engine
    }
}

// MARK: - Reading FilterEngine from binary format

extension WebExtension {
    /// Represents scriptlet data: its name and arguments.
    ///
    /// The scriptlets are evaluated using the scriptlets JS library:
    /// https://github.com/AdguardTeam/Scriptlets
    ///
    /// This object is passed as a part of `Configuration` to the extension's
    /// content script.
    ///
    /// See the `Extension` code to learn how it's used.
    public struct Scriptlet: Equatable {
        /// Scriptlet name.
        public let name: String

        /// Scriptlet arguments
        public let args: [String]
    }

    /// Represents content script configuration that needs to be applied.
    ///
    /// This object is then interpreted by the content script and the rules from the configuration
    /// are applied to the web page.
    public struct Configuration: Equatable {
        /// A list of CSS rules to be added to the page.
        ///
        /// CSS rule can be a CSS selector (in this case a `display: none` rule is added),
        /// or a valid CSS rule with styles.
        public let css: [String]

        /// A list of extended CSS rules to be aded to the page.
        ///
        /// These rules are evaluated in the same way as regular CSS rules with one difference:
        /// they're applied using a JS library: https://github.com/AdguardTeam/ExtendedCss
        public let extendedCss: [String]

        /// A list of JS snippets to be evaluated on the page.
        public let js: [String]

        /// A list of scriptlets to be executed on the page.
        public let scriptlets: [Scriptlet]

        /// The timestamp of when the engine was built. This field is supposed to be used
        /// to implement caching on the extension side.
        public let engineTimestamp: Double
    }

    /// Looks up filtering rules in the filtering engine.
    ///
    /// - Parameters:
    ///   - pageUrl: URL of the page where the rules should be applied.
    ///   - topUrl: URL of the page from which the iframe was loaded. Only makes sense for subdocuments.
    /// - Returns: the list of rules to be applied.
    public func lookup(pageUrl: URL, topUrl: URL?) -> Configuration? {
        guard let engine = getFilterEngine() else {
            return nil
        }

        let pageHostname = pageUrl.host ?? ""
        let topHostname = topUrl?.host ?? ""

        // If page address is different from the top frame address then we can
        // assume that we're dealing with a subdocument.
        let subdocument = !pageHostname.isEmpty && !topHostname.isEmpty
        var thirdParty = false
        if subdocument {
            // It only makes sense to distinguish third-party from first-party requests
            // when we're dealing with a subdocuments. For documents there will be no
            // top URL anyway so there're no "parties".
            let pageDomain = PublicSuffixList.effectiveTLDPlusOne(pageHostname)
            let topDomain = PublicSuffixList.effectiveTLDPlusOne(topHostname)
            thirdParty = pageDomain != topDomain
        }

        // Find all AdGuard rules that should be applied to this page.
        let request = Request(url: pageUrl, subdocument: subdocument, thirdParty: thirdParty)
        let rules = engine.findAll(for: request)

        let conf = createConfiguration(rules)

        return conf
    }

    /// Creates content script configuration object with the rules that need to be applied on the page.
    private func createConfiguration(_ rules: [FilterRule]) -> Configuration {
        var css: [String] = []
        var extendedCss: [String] = []
        var js: [String] = []
        var scriptlets: [Scriptlet] = []

        for rule in rules {
            guard let cosmeticContent = rule.cosmeticContent else {
                continue
            }

            if rule.action.contains(.cssDisplayNone) || rule.action.contains(.cssInject) {
                if rule.action.contains(.extendedCSS) {
                    extendedCss.append(cosmeticContent)
                } else {
                    css.append(cosmeticContent)
                }
            } else if rule.action == .scriptInject {
                js.append(cosmeticContent)
            } else if rule.action == .scriptlet {
                if let data = try? ScriptletParser.parse(cosmeticRuleContent: cosmeticContent) {
                    scriptlets.append(Scriptlet(name: data.name, args: data.args))
                }
            }
        }

        return Configuration(
            css: css,
            extendedCss: extendedCss,
            js: js,
            scriptlets: scriptlets,
            engineTimestamp: engineTimestamp
        )
    }
}
