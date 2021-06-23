import Foundation

public enum SafariVersion: Int {
    @available (OSX, unavailable)
    case safari11 = 11;
    @available (OSX, unavailable)
    case safari12 = 12;
    
    case safari13 = 13;
    case safari14 = 14;
    case safari15 = 15;
    
    /**
     * Returns rules limit for current Safari version
     * Safari allows up to 50k rules by default, but starting from 15 version it allows up to 150k rules
     */
    var rulesLimit: Int {
        switch self {
            case .safari11, .safari12, .safari13, .safari14: return 50000
            case .safari15: return 150000
        }
    }
}

public enum SafariVersionError: Error {
    case invalidSafariVersion(message: String)
    case unsupportedSafariVersion(message: String)
}
