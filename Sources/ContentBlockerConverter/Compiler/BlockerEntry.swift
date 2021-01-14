import Foundation

/**
 * Blocker entry object description
 */
struct BlockerEntry: Codable {
    var trigger: Trigger
    let action: Action
    
    struct Trigger : Codable {
        var ifDomain: [String]?
        var urlFilter: String?
        var unlessDomain: [String]?
        
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
    
    struct Action : Codable {
        var type: String
        var selector: String?
        var css: String?
        var extCss: String?
        var script: String?
        var scriptlet: String?
        var scriptletParam: String?
    }
}
