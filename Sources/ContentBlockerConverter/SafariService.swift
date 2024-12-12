import Foundation

let DEFAULT_SAFARI_VERSION = SafariVersion.safari13;

public enum SafariVersion: CustomStringConvertible, CustomDebugStringConvertible, Equatable {
    public var description: String {
        return "\(self.doubleValue)"
    }

    public var debugDescription: String {
        return "Safari v\(self.description)"
    }

    /**
     * Returns rules limit for current Safari version:
     * Safari allows up to 50k rules by default,
     * but starting from 15 version it allows up to 150k rules
     */
    public var rulesLimit: Int {
        return self.doubleValue >= SafariVersion.safari15.doubleValue ? 150000 : 50000
    }

    // AdGuard for iOS supports Safari from 11 version
    // AdGuard for Safari doesn't support OS Sierra, so minimal Safari version is 13
    @available(OSX, unavailable)
    case safari11
    @available(OSX, unavailable)
    case safari12

    case safari13
    case safari14
    case safari15
    case safari16
    case safari16_4
    case safari16_4Plus(Double)

    public init(_ version: Double) {
        if version == 16.4 {
            self = .safari16_4
            return
        } else if version > 16.4 {
            self = .safari16_4Plus(version)
            return
        }

        let majorVersion = Int(version)
        switch majorVersion {
        case 13: self = .safari13
        case 14: self = .safari14
        case 15: self = .safari15
        case 16: self = .safari16
        default: self = DEFAULT_SAFARI_VERSION
        }
    }

    var doubleValue: Double {
        switch self {
        case .safari13: return 13
        case .safari14: return 14
        case .safari15: return 15
        case .safari16: return 16
        case .safari16_4: return 16.4
        case .safari16_4Plus(let version): return version
        default: return 13
        }
    }

    func isSafari14orGreater() -> Bool {
        return self.doubleValue >= SafariVersion.safari14.doubleValue;
    }

    func isSafari15orGreater() -> Bool {
        return self.doubleValue >= SafariVersion.safari15.doubleValue;
    }

    /**
     * Starting from 16.4 version Safari content blockers supports :has() pseudo-class.
     * https://www.webkit.org/blog/13966/webkit-features-in-safari-16-4/
     */
    func isSafari16_4orGreater() -> Bool {
        return self.doubleValue >= SafariVersion.safari16_4.doubleValue;
    }
}

/// This is a singleton that's used for signalling for which Safari version we're compiling the content blocker.
///
/// Depending on the Safari version content blocking API supports different features and it needs to be
/// taken into account.
///
/// TODO(ameshkov): !!! Add tests for SafariService.
class SafariService {
    var version: SafariVersion = DEFAULT_SAFARI_VERSION;
    static let current: SafariService = SafariService();
}
