/// Represents Safari content blocker types.
///
/// The set is fixed (6 cases) because:
/// - Safari supports at most 6 content blocker extension slots.
/// - Affinity keywords are standardized by the AdGuard filter format.
/// - `advanced` is intentionally excluded because advanced rules are handled
///   separately by ``ContentBlockerConverter``'s
///   ``ContentBlockerConverter/convertArray(rules:safariVersion:advancedBlocking:maxJsonSizeBytes:progress:)``.
///
/// The enum is intentionally **not** extensible by consumers. If a new type is
/// required in the future, the library should be updated to include it.
public enum ContentBlockerType: Int, CaseIterable, Codable {
    case general
    case privacy
    case socialWidgetsAndAnnoyances
    case other
    case custom
    case security
}
