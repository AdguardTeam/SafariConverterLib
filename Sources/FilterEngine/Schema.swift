/// The purpose of this class is to define constants that are used in the FilterEngine library.
public enum Schema {
    /// Defines schema version. Whenever any change is made to the serialization logic this number
    /// **MUST** be incremented.
    ///
    /// Normally, the engine is supposed to be built by the app's main process. However, there can
    /// be a situation when the app was updated, but the user has not launched the app's main process.
    /// In these cases the new updated extension process may be launched, but the serialized engine
    /// was prepared by the old code.
    ///
    /// This situation can be handled by the extension's process. Whenever it needs to read the
    /// serialized engine from the persistent storage, it first checks if the schema version has not
    /// changed. If there was any change, the extension native process can use plain text rules
    /// to rebuild the engine.
    ///
    /// **IMPORTANT**
    /// This is very important to increment this value whenever any changes are made
    /// to serialization logic in the `FilterRuleStorage`, `FilterRule` or `FilterEngine`.
    /// You should also increment the schema version whenever you change
    /// `FILTER_RULE_STORAGE_FILE_NAME` or `FILTER_ENGINE_INDEX_FILE_NAME`.
    public static let VERSION = 1

    /// Base directory name for storing all WebExtension related files.
    ///
    /// **IMPORTANT**
    /// Changing this will lead to invalidating the engine cached in the extension directory and makes
    /// it required to write additional migration code in the extension.
    public static let BASE_DIR = ".webext"

    /// UserDefaults key for storing the current schema version.
    ///
    /// **IMPORTANT**
    /// Changing this will lead to invalidating the engine cached in the extension directory and makes
    /// it required to write additional migration code in the extension.
    public static let ENGINE_SCHEMA_VERSION_KEY = "com.adguard.safari-converter.schema-version"

    /// UserDefaults key for storing the timestamp when the engine was last built.
    ///
    /// **IMPORTANT**
    /// Changing this will lead to invalidating the engine cached in the extension directory and makes
    /// it required to write additional migration code in the extension.
    public static let ENGINE_TIMESTAMP_KEY = "com.adguard.safari-converter.engine-timestamp"

    /// Name of the file storing the original, uncompiled filtering rules.
    ///
    /// **IMPORTANT**
    /// Changing this will lead to invalidating the engine cached in the extension directory and makes
    /// it required to write additional migration code in the extension.
    public static let RULES_FILE_NAME = "rules.txt"

    /// Name of the file storing the serialized `FilterRuleStorage`.
    public static let FILTER_RULE_STORAGE_FILE_NAME = "rules.bin"

    /// Name of the file storing the serialized `FilterEngine` index.
    public static let FILTER_ENGINE_INDEX_FILE_NAME = "engine.bin"

    /// Name of the lock file used for synchronizing access to shared resources.
    public static let LOCK_FILE_NAME = "lock"
}
