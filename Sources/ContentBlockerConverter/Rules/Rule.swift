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
    
    init(ruleText: String) {
        self.ruleText = ruleText;
    }
    
    func isSingleOption(optionName: String) -> Bool {
        return false;
    }
}
