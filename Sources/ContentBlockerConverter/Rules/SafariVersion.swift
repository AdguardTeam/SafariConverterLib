/// Default Safari version for which the rules will be converted if another version is not explicitly specified.
public let DEFAULT_SAFARI_VERSION = SafariVersion.safari13

/// Represents Safari browser version for which the library will prepare
/// a content blocker.
public enum SafariVersion: CustomStringConvertible, CustomDebugStringConvertible, Equatable {
    public var description: String {
        return "\(self.doubleValue)"
    }

    public var debugDescription: String {
        return "Safari v\(self.description)"
    }

    /// Returns rules limit for current Safari version:
    ///
    /// - Starting from Safari 15 it allows up to 150k rules in a single content blocker extension.
    /// - Older Safari versions only allowed up to 50k rules by default.
    public var rulesLimit: Int {
        return self.doubleValue >= SafariVersion.safari15.doubleValue ? 150000 : 50000
    }

    // AdGuard for iOS supports Safari from 11 version.
    // AdGuard for Safari doesn't support OS Sierra, so minimal Safari version is 13.
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

    public var doubleValue: Double {
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

    public func isSafari14orGreater() -> Bool {
        return self.doubleValue >= SafariVersion.safari14.doubleValue
    }

    public func isSafari15orGreater() -> Bool {
        return self.doubleValue >= SafariVersion.safari15.doubleValue
    }

    /// Starting from 16.4 version Safari content blockers supports :has() pseudo-class.
    /// https://www.webkit.org/blog/13966/webkit-features-in-safari-16-4/
    public func isSafari16_4orGreater() -> Bool {
        return self.doubleValue >= SafariVersion.safari16_4.doubleValue
    }

    /// Detects the Safari version based on the current OS version.
    /// - Returns: The detected SafariVersion based on the OS.
    public static func autodetect() -> SafariVersion {
        #if os(macOS)
        if #available(macOS 13.3, *) {
            return .safari16_4
        } else if #available(macOS 13.0, *) {
            return .safari16
        } else if #available(macOS 12.0, *) {
            return .safari15
        } else if #available(macOS 11.0, *) {
            return .safari14
        } else if #available(macOS 10.15, *) {
            return .safari13
        } else {
            return DEFAULT_SAFARI_VERSION
        }
        #elseif os(iOS)
        if #available(iOS 16.4, *) {
            return .safari16_4
        } else if #available(iOS 16.0, *) {
            return .safari16
        } else if #available(iOS 15.0, *) {
            return .safari15
        } else if #available(iOS 14.0, *) {
            return .safari14
        } else if #available(iOS 13.0, *) {
            return .safari13
        } else {
            return DEFAULT_SAFARI_VERSION
        }
        #else
        return DEFAULT_SAFARI_VERSION
        #endif
    }
}
