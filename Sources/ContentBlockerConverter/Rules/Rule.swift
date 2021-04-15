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
    
    var denyallowDomains = [String]();
    
    init() {
        
    }
    
    init(ruleText: NSString) throws {
        self.ruleText = ruleText;
    }
    
    /**
     * Parses source string and sets up permitted and restricted domains fields
     */
    func setDomains(domains: String, sep: String) throws -> Void {
        if (domains == "") {
            throw SyntaxError.invalidRule(message: "Modifier $domain cannot be empty");
        }
        
        let parts = domains.components(separatedBy: sep);
        for var domain in parts {
            var restricted = false;
            if (domain.hasPrefix("~")) {
                restricted = true;
                domain = domain.subString(startIndex: 1);
            }

            if (domain == "") {
                throw SyntaxError.invalidRule(message: "Empty domain specified");
            }

            var encoded = domain;
            if (!domain.isASCII()) {
                encoded = domain.idnaEncoded!;
            }
            
            if (restricted) {
                self.restrictedDomains.append(domain);
            } else {
                self.permittedDomains.append(encoded);
            }
        }
    }
    
    /*
     * Sets and validates exceptionally allowed domains presented in $denyallow modifier
     */
    func setDenyallowDomains(domains: String, sep: String) throws -> Void {
        if (domains == "") {
            throw SyntaxError.invalidRule(message: "Modifier $denyallow cannot be empty");
        }
        
        let parts = domains.components(separatedBy: sep);
        
        for var domain in parts {
            if (domain.hasPrefix("~")) {
                throw SyntaxError.invalidRule(message: "Modifier $denyallow cannot be negated");
            }

            if (domain.contains("*")) {
                throw SyntaxError.invalidRule(message: "Modifier $denyallow cannot have a wildcard TLD");
            }

            var encoded = domain;
            if (!domain.isASCII()) {
                encoded = domain.idnaEncoded!;
            }
            
            self.denyallowDomains.append(encoded);
        }
    }
}
