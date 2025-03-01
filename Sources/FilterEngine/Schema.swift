/// The purpose of this class is to define constants that are used in the FilterEngine library.
class Schema {
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
    static let VERSION = 1
}
