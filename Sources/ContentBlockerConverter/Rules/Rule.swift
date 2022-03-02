import Foundation
import Punycode

/**
 * AG Rule super class
 */
class Rule {
    var ruleText: NSString = "";
    
    var isWhiteList = false;
    var isImportant = false;
    
    var isScript = false;
    var isScriptlet = false;
    var isDocumentWhiteList = false;
    
    var permittedDomains = [String]();
    var restrictedDomains = [String]();
    
    var pathModifier: String?;
    
    private static let OPEN_BRACKET = "["
    private static let CLOSE_BRACKET = "]"
    private static let MODIFIER_KEY = "$"
    
    private static let COMMA_SEPARATOR = ","
    private static let VERTICAL_SEPARATOR = "|"
    
    private static let PATH_MODIFIER = "path="
    private static let DOMAIN_MODIFIER = "domain="
    
    init() {
        
    }
    
    init(ruleText: NSString) throws {
        self.ruleText = ruleText;
    }
    
    /**
     * Parses source string and sets up permitted and restricted domains fields
     */
    func setNetworkRuleDomains(domains: String) throws -> Void {
        if (domains == "") {
            throw SyntaxError.invalidRule(message: "Modifier $domain cannot be empty")
        }
        
        try setDomains(domains: domains, separator: Rule.VERTICAL_SEPARATOR)
    }
    
    func setCosmeticRuleDomains(domains: String) throws -> Void {
        var domainsString = domains;

        // handle modifiers
        if domainsString.starts(with: Rule.OPEN_BRACKET + Rule.MODIFIER_KEY) {
            let closeBracketIndex = domains.indexOf(target: Rule.CLOSE_BRACKET)
            
            if closeBracketIndex < 2 {
                // invalid or empty modifier
                throw SyntaxError.invalidRule(message: "Invalid modifier")
            }
            
            let modifiersString = domains.subString(startIndex: 2, toIndex: closeBracketIndex)
            
            let modifiers = modifiersString.components(separatedBy: Rule.COMMA_SEPARATOR)
            
            for modifier in modifiers {
                if modifier.starts(with: Rule.PATH_MODIFIER) {
                    self.pathModifier = modifier.subString(startIndex: Rule.PATH_MODIFIER.count)
                }
                
                if modifier.starts(with: Rule.DOMAIN_MODIFIER) {
                    let domainModifier = modifier.subString(startIndex: Rule.DOMAIN_MODIFIER.count)
                    try setDomains(domains: domainModifier, separator: Rule.VERTICAL_SEPARATOR)
                }
            }
            
            if closeBracketIndex + 1 < domains.count {
                domainsString = domains.subString(startIndex: closeBracketIndex + 1)
                try setDomains(domains: domainsString, separator: Rule.COMMA_SEPARATOR)
            }
            
            return;
        }

        try setDomains(domains: domainsString, separator: Rule.COMMA_SEPARATOR)
    }
    
    func setDomains(domains: String, separator: String) throws -> Void {
        let domainsList = domains.components(separatedBy: separator)
    
        for var domain in domainsList {
            var restricted = false;
            if (domain.hasPrefix("~")) {
                restricted = true
                domain = domain.subString(startIndex: 1)
            }

            if (domain == "") {
                throw SyntaxError.invalidRule(message: "Empty domain specified")
            }

            var encoded = domain
            if (!domain.isASCII()) {
                encoded = domain.idnaEncoded!
            }

            if (restricted) {
                self.restrictedDomains.append(domain)
            } else {
                self.permittedDomains.append(encoded)
            }
        }
    }
}
