import Foundation

public enum SafariVersion: Int {
    case safari14 = 14;
    case safari15 = 15;
    
    /**
     * Returns rules limit for current Safari version
     * Safari allows up to 50k rules by default, but starting from 15 version it allows up to 150k rules
     */
    var rulesLimit: Int {
        switch self {
            case .safari14: return 50000
            case .safari15: return 150000
        }
    }
    
    func isDefaultSafariVersion() -> Bool {
        return self.rawValue <= SafariVersion.safari14.rawValue;
    }
}
