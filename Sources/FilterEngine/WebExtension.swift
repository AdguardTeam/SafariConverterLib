import Foundation
import ContentBlockerConverter
import PublicSuffixList

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
    public init(
        containerURL: URL,
        sharedUserDefaults: UserDefaults,
        version: SafariVersion
    ) throws {
        self.baseURL = containerURL.appendingPathComponent(Schema.BASE_DIR, isDirectory: true)
        self.sharedUserDefaults = sharedUserDefaults
        self.version = version

        let lockFilePath = baseURL.appendingPathComponent(Schema.LOCK_FILE_NAME).path
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

        let filterRuleStorageURL = baseURL.appendingPathComponent(Schema.FILTER_RULE_STORAGE_FILE_NAME)
        let filterEngineIndexURL = baseURL.appendingPathComponent(Schema.FILTER_ENGINE_INDEX_FILE_NAME)

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
        let rulesFileURL = baseURL.appendingPathComponent(Schema.RULES_FILE_NAME)
        try rules.write(to: rulesFileURL, atomically: true, encoding: .utf8)

        // Save the timestamp when the engine was built and the schema version.
        // This way, we can quickly determine if the engine needs to be rebuilt
        // later.
        let currentTimestamp = Date().timeIntervalSince1970
        sharedUserDefaults.set(currentTimestamp, forKey: Schema.ENGINE_TIMESTAMP_KEY)
        sharedUserDefaults.set(Schema.VERSION, forKey: Schema.ENGINE_SCHEMA_VERSION_KEY)

        return engine
    }
}

// MARK: - Reading FilterEngine from binary format

extension WebExtension {
    /// Gets or creates an instance of `FilterEngine`.
    private func getFilterEngine() -> FilterEngine? {
        let engineTimestamp = sharedUserDefaults.double(forKey: Schema.ENGINE_TIMESTAMP_KEY)
        if engineTimestamp == 0 {
            // Engine was never initialized.
            return nil
        }

        if engineTimestamp > self.engineTimestamp {
            let schemaVersion = sharedUserDefaults.integer(forKey: Schema.ENGINE_SCHEMA_VERSION_KEY)

            if schemaVersion == Schema.VERSION {
                self.filterEngine = readFilterEngine()
                self.engineTimestamp = engineTimestamp
            } else {
                let engine = rebuildFilterEngine()
                if engine != nil {
                    self.filterEngine = engine
                    // Read the timestamp again since it was changed when rebuilding.
                    self.engineTimestamp = sharedUserDefaults.double(forKey: Schema.ENGINE_TIMESTAMP_KEY)
                }
            }
        }

        return self.filterEngine
    }

    /// Re-builds the `FilterEngine` from the source rules
    private func rebuildFilterEngine() -> FilterEngine? {
        self.fileLock?.lock()
        defer {
            _ = self.fileLock?.unlock()
        }

        let filterRulesURL = baseURL.appendingPathComponent(Schema.RULES_FILE_NAME)
        if !FileManager.default.fileExists(atPath: filterRulesURL.path) {
            return nil
        }

        do {
            let rules = try String(contentsOf: filterRulesURL, encoding: .utf8)

            return try buildFilterEngine(rules: rules)
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

        let filterRuleStorageURL = baseURL.appendingPathComponent(Schema.FILTER_RULE_STORAGE_FILE_NAME)
        let filterEngineIndexURL = baseURL.appendingPathComponent(Schema.FILTER_ENGINE_INDEX_FILE_NAME)

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
    }
}

// MARK: - Reading FilterEngine from binary format

extension WebExtension {
    /// Represents scriptlet data: its name and arguments.
    ///
    /// TODO(ameshkov): !!! Link the extension
    public struct Scriptlet: Equatable {
        public let name: String
        public let args: [String]
    }

    /// Represents content script configuration that needs to be applied.
    ///
    /// TODO(ameshkov): !!! Link the extension
    public struct Configuration: Equatable {
        public let css: [String]
        public let extendedCss: [String]
        public let js: [String]
        public let scriptlets: [Scriptlet]
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
        let subdocument = pageHostname != "" && topHostname != "" && pageHostname != topHostname
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
        let rules = engine.findAll(for: pageUrl, subdocument: subdocument, thirdParty: thirdParty)

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

            if rule.action.contains(.cssDisplayNone) ||
                rule.action.contains(.cssInject) {

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
