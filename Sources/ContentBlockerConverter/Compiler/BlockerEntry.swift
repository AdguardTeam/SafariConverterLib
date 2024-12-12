import Foundation

/// Represents a Safari content blocking rule.
///
/// The format of this rule is described here:
/// https://developer.apple.com/documentation/safariservices/creating-a-content-blocker
///
/// In addition to Safari normal syntax it adds some new fields that are interpreted by a custom extension.
public struct BlockerEntry {
    public init(trigger: BlockerEntry.Trigger, action: BlockerEntry.Action) {
        self.trigger = trigger
        self.action = action
    }
    
    public var trigger: Trigger
    public let action: Action
    
    /// Trigger is the "trigger" field of a content blocking rule, i.e. defines conditions when the rule is applied.
    public struct Trigger {
        public init(ifDomain: [String]? = nil, urlFilter: String? = nil, unlessDomain: [String]? = nil, shortcut: String? = nil, regex: NSRegularExpression? = nil, loadType: [String]? = nil, resourceType: [String]? = nil, caseSensitive: Bool? = nil, loadContext: [String]? = nil) {
            self.ifDomain = ifDomain
            self.urlFilter = urlFilter
            self.unlessDomain = unlessDomain
            self.shortcut = shortcut
            self.regex = regex
            self.loadType = loadType
            self.resourceType = resourceType
            self.caseSensitive = caseSensitive
            self.loadContext = loadContext
        }
        
        public var ifDomain: [String]?
        public var urlFilter: String?
        public var unlessDomain: [String]?
        
        var shortcut: String?
        var regex: NSRegularExpression?
        
        var loadType: [String]?
        var resourceType: [String]?
        var caseSensitive: Bool?
        var loadContext: [String]?
        
        enum CodingKeys: String, CodingKey {
            case ifDomain = "if-domain"
            case urlFilter = "url-filter"
            case unlessDomain = "unless-domain"
            case shortcut = "url-shortcut"
            case loadType = "load-type"
            case resourceType = "resource-type"
            case caseSensitive = "url-filter-is-case-sensitive"
            case loadContext = "load-context"
        }
        
        mutating func setShortcut(shortcutValue: String?) {
            self.shortcut = shortcutValue;
        }
        
        mutating func setRegex(regex: NSRegularExpression?) {
            self.regex = regex;
        }
        
        mutating func setIfDomain(domains: [String]?) {
            self.ifDomain = domains;
        }
        
        mutating func setUnlessDomain(domains: [String]?) {
            self.unlessDomain = domains;
        }
    }
    
    /// Action represents an action that this rule applies.
    public struct Action {
        public init(type: String, selector: String? = nil, css: String? = nil, script: String? = nil, scriptlet: String? = nil, scriptletParam: String? = nil) {
            self.type = type
            self.selector = selector
            self.css = css
            self.script = script
            self.scriptlet = scriptlet
            self.scriptletParam = scriptletParam
        }
        
        public var type: String
        var selector: String?
        public var css: String?
        public var script: String?
        public var scriptlet: String?
        public var scriptletParam: String?
    }
}

extension BlockerEntry: Codable {}
extension BlockerEntry.Trigger: Codable {}
extension BlockerEntry.Action: Codable {}
