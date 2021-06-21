import Foundation

public enum SafariVersions: Int {
    case DEFAULT = 14;
    case EXPERIMENTAL = 15;
    
    func getRulesLimit() -> Int {
        let RULES_LIMIT: Int = 50000;
        let RULES_LIMIT_EXTENDED: Int = 150000;
        
        if self == .EXPERIMENTAL {
            return RULES_LIMIT_EXTENDED
        } else {
            return RULES_LIMIT
            
        }
    }
}
