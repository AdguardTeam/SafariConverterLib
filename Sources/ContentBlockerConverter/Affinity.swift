import Foundation

/// Bitmask representing Safari content blocker affinity.
///
/// Affinity determines which content blocker(s) a rule should be associated
/// with, overriding the default assignment derived from the filter group.
///
/// The `all` value (rawValue 0) means the rule should be included in every
/// content blocker.
public struct Affinity: OptionSet, Sendable {
    public let rawValue: UInt8

    public static let general = Affinity(rawValue: 1 << 0)
    public static let privacy = Affinity(rawValue: 1 << 1)
    public static let socialWidgetsAndAnnoyances = Affinity(rawValue: 1 << 2)
    public static let other = Affinity(rawValue: 1 << 3)
    public static let custom = Affinity(rawValue: 1 << 4)
    public static let security = Affinity(rawValue: 1 << 5)

    /// Special value that means the rule applies to **all** content blockers.
    // swiftlint:disable:next static_operator
    public static let all = Affinity([])

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}
