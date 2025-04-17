import Foundation

/// Represents a Safari content blocking rule.
///
/// The format of this rule is described here:
/// https://developer.apple.com/documentation/safariservices/creating-a-content-blocker
///
/// In addition to Safari normal syntax it adds some new fields that are interpreted by a custom extension.
public struct BlockerEntry: Codable, Equatable, CustomStringConvertible {
    public init(trigger: BlockerEntry.Trigger, action: BlockerEntry.Action) {
        self.trigger = trigger
        self.action = action
    }

    // Define CodingKeys to guarantee the correct property order in the output.
    enum CodingKeys: String, CodingKey {
        case trigger
        case action
    }

    public var trigger: Trigger
    public let action: Action

    public var description: String {
        let encoder = JSONEncoder()

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let json = try? encoder.encode(self),
            let jsonString = String(data: json, encoding: .utf8)
        {
            return jsonString
        }

        return "{}"
    }

    /// Trigger is the "trigger" field of a content blocking rule, i.e. defines conditions when the rule is applied.
    public struct Trigger: Codable, Equatable {
        public init(
            ifDomain: [String]? = nil,
            urlFilter: String? = nil,
            unlessDomain: [String]? = nil,
            loadType: [String]? = nil,
            resourceType: [String]? = nil,
            caseSensitive: Bool? = nil,
            loadContext: [String]? = nil
        ) {
            self.ifDomain = ifDomain
            self.urlFilter = urlFilter
            self.unlessDomain = unlessDomain
            self.loadType = loadType
            self.resourceType = resourceType
            self.caseSensitive = caseSensitive
            self.loadContext = loadContext
        }

        public var ifDomain: [String]?
        public var urlFilter: String?
        public var unlessDomain: [String]?
        public var loadType: [String]?
        public var resourceType: [String]?
        public var caseSensitive: Bool?
        public var loadContext: [String]?

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case ifDomain = "if-domain"
            case urlFilter = "url-filter"
            case unlessDomain = "unless-domain"
            case loadType = "load-type"
            case resourceType = "resource-type"
            case caseSensitive = "url-filter-is-case-sensitive"
            case loadContext = "load-context"
        }

        // Custom Equatable implementation
        public static func == (lhs: Trigger, rhs: Trigger) -> Bool {
            return lhs.ifDomain == rhs.ifDomain && lhs.urlFilter == rhs.urlFilter
                && lhs.unlessDomain == rhs.unlessDomain && lhs.loadType == rhs.loadType
                && lhs.resourceType == rhs.resourceType && lhs.caseSensitive == rhs.caseSensitive
                && lhs.loadContext == rhs.loadContext
        }
    }

    /// Action represents an action that this rule applies.
    public struct Action: Codable, Equatable {
        public init(type: String, selector: String? = nil) {
            self.type = type
            self.selector = selector
        }

        public var type: String
        public var selector: String?

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case type
            case selector
        }
    }
}
