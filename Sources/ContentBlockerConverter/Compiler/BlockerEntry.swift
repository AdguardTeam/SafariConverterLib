import Foundation

/**
 * Blocker entry object description
 */
public struct BlockerEntry {
    public var trigger: Trigger
    public let action: Action
    
    public struct Trigger {
        public var ifDomain: [String]?
        public var urlFilter: String?
        public var unlessDomain: [String]?
        
        var shortcut: String?
        var regex: NSRegularExpression?
        
        var loadType: [String]?
        var resourceType: [String]?
        var caseSensitive: Bool?
        
        enum CodingKeys: String, CodingKey {
            case ifDomain = "if-domain"
            case urlFilter = "url-filter"
            case unlessDomain = "unless-domain"
            case shortcut = "url-shortcut"
            case loadType = "load-type"
            case resourceType = "resource-type"
            case caseSensitive = "url-filter-is-case-sensitive"
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
    
    public struct Action {
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
