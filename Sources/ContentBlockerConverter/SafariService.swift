import Foundation

private let DEFAULT_SAFARI_VERSION = SafariVersion.safari13;

public enum SafariVersion: Int {
    // AdGuard for iOS supports Safari from 11 version
    // AdGuard for Safari doesn't support OS Sierra, so minimal Safari version is 13
    @available (OSX, unavailable)
    case safari11;
    @available (OSX, unavailable)
    case safari12;

    case safari13;
    case safari14;
    case safari15;
    case safari16;
    
    public init(rawValue: Int) {
        switch rawValue {
        case 13:
            self = .safari13
        case 14:
            self = .safari14
        case 15:
            self = .safari15
        case 16:
            self = .safari16
        default:
            self = DEFAULT_SAFARI_VERSION
        }
    }
    
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
