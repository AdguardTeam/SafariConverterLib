import Foundation

public enum SafariVersions: Int {
    case DEFAULT = 14;
    case EXPERIMENTAL = 15;
    
    /**
     * Returns rules limit for current Safari version
     * Safari allows up to 50k rules by default, but starting from 15 version it allows up to 150k rules
     */
    func getRulesLimit() -> Int {
        let RULES_LIMIT: Int = 50000;
        let RULES_LIMIT_EXTENDED: Int = 150000;
        
        return self == .EXPERIMENTAL ? RULES_LIMIT_EXTENDED : RULES_LIMIT;
    }
}
