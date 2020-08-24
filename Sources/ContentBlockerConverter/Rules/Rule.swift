import Foundation

/**
 * AG Rule class
 */
class Rule {
    var ruleText = "";
    
    var isWhiteList = false;
    var isImportant = false;
    
    var isScript = false;
    var isScriptlet = false;
    var isDocumentWhiteList = false;
    
    var permittedDomains = [String]();
    var restrictedDomains = [String]();
    
    init() {
        
    }
    
    init(ruleText: String) throws {
        self.ruleText = ruleText;
    }
    
    func isSingleOption(optionName: String) -> Bool {
        return false;
    }
    
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

            if (restricted) {
                self.restrictedDomains.append(domain);
            } else {
                self.permittedDomains.append(domain);
            }
        }
    }
}
