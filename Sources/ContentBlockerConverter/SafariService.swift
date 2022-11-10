import Foundation

public enum SafariVersion: Int {
    // AdGuard for iOS supports Safari from 11 version
    // AdGuard for Safari doesn't support OS Sierra, so minimal Safari version is 13
    @available (OSX, unavailable)
    case safari11 = 11;
    @available (OSX, unavailable)
    case safari12 = 12;
    
    case safari13 = 13;
    case safari14 = 14;
    case safari15 = 15;
    case safari16 = 16;
    
    /**
     * Returns rules limit for current Safari version
     * Safari allows up to 50k rules by default, but starting from 15 version it allows up to 150k rules
     */
    var rulesLimit: Int {
        self.rawValue >= SafariVersion.safari15.rawValue ? 150000 : 50000
    }
    
    func isSafari15orGreater() -> Bool {
        return self.rawValue >= SafariVersion.safari15.rawValue;
        
    }
    
    func isSafari16orGreater() -> Bool {
        return self.rawValue >= SafariVersion.safari16.rawValue;
    }
}

class SafariService {
    var version: SafariVersion = .safari13;
    static let current: SafariService = SafariService();
}

public enum SafariVersionError: Error, CustomDebugStringConvertible {
    case invalidSafariVersion(version: String)
    case unsupportedSafariVersion(version: Int)
    
    public var debugDescription: String {
        switch self {
            case .invalidSafariVersion: return "Invalid Safari version value"
            case .unsupportedSafariVersion: return "The provided Safari version is not supported"
        }
    }
}
