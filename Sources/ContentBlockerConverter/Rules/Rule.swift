import Foundation

/**
 * AG Rule class
 */
class Rule {
    var isWhiteList = false;
    var isImportant = false;
    var isScript = false;
    var isScriptlet = false;
    var isDocumentWhiteList = false;
    
    var permittedDomains = [String]();
    var restrictedDomains = [String]();
    
    func isSingleOption(optionName: String) -> Bool {
        return false;
    }
}
