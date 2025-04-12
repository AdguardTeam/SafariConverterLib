import Foundation

/// Represents a network rule.
///
/// Note, that this implementations supports limited set of modifiers, it does
/// not support the ones that are not supported by Safari content blocking and
/// cannot be implemented using WebExtensions API.
///
/// Not supported:
/// - $replace
/// - $redirect
/// - $redirect-rule
/// - $csp
/// - $object
public class NetworkRule: Rule {
    /// If true, the network rule unblocks everything on the website (cosmetic + network).
    public var isDocumentWhiteList = false
    /// If true, the network rule unblocks all request from matching domains.
    public var isUrlBlock = false
    /// If true, the network rule unblocks cosmetics on matching domains.
    public var isCssExceptionRule = false
    /// If true, the network rule disables script rules and scriptlets on matching domains.
    public var isJsInject = false

    public var isCheckThirdParty = false
    public var isThirdParty = false
    public var isMatchCase = false

    // TODO: [ameshkov]: Modifying url-filter for WebSocket was required until
    // Safari 15, it can be removed now.
    public var isWebSocket = false
    public var isBadfilter = false

    public var permittedContentType: ContentType = .all
    public var restrictedContentType: ContentType = []

    /// Lists of options that are enabled (or disabled) by modifiers in this rule.
    public var enabledOptions: Option = []
    public var disabledOptions: Option = []

    /// Network rule pattern.
    public var urlRuleText: String = ""

    /// Regular expression that's converted from the rule pattern.
    ///
    /// nil here means that the rule will match all URLs.
    public var urlRegExpSource: String?

    /// Initializes a network rule by parsing its properties from the rule text.
    ///
    /// - Parameters:
    ///   - ruleText: AdGuard rule text.
    ///   - version: Safari version which will use that rule. Depending on the
    ///              version some features may be available or not.
    /// - Throws: SyntaxError if any issue with the rule is detected.
    public override init(
        ruleText: String,
        for version: SafariVersion = DEFAULT_SAFARI_VERSION
    ) throws {
        try super.init(ruleText: ruleText)

        let ruleParts = try NetworkRuleParser.parseRuleText(ruleText: ruleText)
        isWhiteList = ruleParts.whitelist

        if let options = ruleParts.options, !options.isEmpty {
            try loadOptions(options: options, version: version)
        }

        urlRuleText = ruleParts.pattern

        if let regex = SimpleRegex.extractRegex(urlRuleText) {
            urlRegExpSource = regex
        } else {
            guard
                let encodedPattern = NetworkRuleParser.encodeDomainIfRequired(pattern: urlRuleText)
            else {
                throw SyntaxError.invalidRule(message: "Failed to encode the domain in \(ruleText)")
            }

            urlRuleText = encodedPattern
            if !urlRuleText.isEmpty {
                urlRegExpSource = try SimpleRegex.createRegexText(pattern: urlRuleText)
            }
        }

        isDocumentWhiteList = isWhiteList && isOptionEnabled(option: .document)
        isUrlBlock = isSingleOption(option: .urlblock) || isSingleOption(option: .genericblock)
        isCssExceptionRule =
            isSingleOption(option: .elemhide) || isSingleOption(option: .generichide)
        isJsInject = isSingleOption(option: .jsinject)

        try validateRule(version: version)
    }

    /// Returns true if rule pattern is a regular expression.
    public func isRegexRule() -> Bool {
        return SimpleRegex.isRegexPattern(urlRuleText)
    }

    /// Checks if rule targets specified content type.
    public func hasContentType(contentType: ContentType) -> Bool {
        return permittedContentType.contains(contentType)
            && !restrictedContentType.contains(contentType)
    }

    /// Returns true if the rule targets only the specified content type and nothing else.
    public func isContentType(contentType: ContentType) -> Bool {
        return permittedContentType == contentType
    }

    /// Returns true if the specified content type is restricted for this rule.
    public func hasRestrictedContentType(contentType: ContentType) -> Bool {
        return restrictedContentType.contains(contentType)
    }

    /// Checks if this rule negates the other rule.
    /// Only makes sense when this rule has a `$badfilter` modifier.
    public func negatesBadfilter(specifiedRule: NetworkRule) -> Bool {
        if isWhiteList != specifiedRule.isWhiteList {
            return false
        }

        if urlRuleText != specifiedRule.urlRuleText {
            return false
        }

        if permittedContentType != specifiedRule.permittedContentType {
            return false
        }

        if restrictedContentType != specifiedRule.restrictedContentType {
            return false
        }

        if enabledOptions != specifiedRule.enabledOptions {
            return false
        }

        if disabledOptions != specifiedRule.disabledOptions {
            return false
        }

        if restrictedDomains != specifiedRule.restrictedDomains {
            return false
        }

        if !NetworkRule.stringArraysHaveIntersection(
            left: permittedDomains,
            right: specifiedRule.permittedDomains
        ) {
            return false
        }

        return true
    }

    /// Checks if two string arrays have at least 1 element in intersection.
    private static func stringArraysHaveIntersection(left: [String], right: [String]) -> Bool {
        if left.isEmpty && right.isEmpty {
            return true
        }

        for elem in left where right.contains(elem) {
            return true
        }

        return false
    }

    /// Sets rule domains from the $domain modifier.
    private func setNetworkRuleDomains(domains: String) throws {
        if domains.isEmpty {
            throw SyntaxError.invalidModifier(message: "$domain cannot be empty")
        }

        try addDomains(domainsStr: domains, separator: Chars.PIPE)
    }

    /// Checks that the rule and its options is valid.
    ///
    /// - Throws: SyntaxError if the rule is not valid.
    private func validateRule(version: SafariVersion) throws {
        if urlRuleText == "||"
            || urlRuleText == "*"
            || urlRuleText.isEmpty
            || urlRuleText.utf8.count < 3
        {
            if permittedDomains.count < 1 {
                // Rule matches too much and does not have any domain restriction
                // We should not allow this kind of rules
                throw SyntaxError.invalidPattern(
                    message:
                        "The rule is too wide, add domain restriction or make the pattern more specific"
                )
            }
        }

        if urlRegExpSource?.isEmpty ?? false {
            throw SyntaxError.invalidPattern(message: "Empty regular expression for URL")
        }

        if !isWhiteList && !enabledOptions.isDisjoint(with: .whitelistOnly) {
            throw SyntaxError.invalidModifier(
                message: "Blocking rule cannot use whitelist-only modifiers"
            )
        }

        if !version.isSafari15orGreater() && !isWhiteList && !isContentType(contentType: .all)
            && hasContentType(contentType: .subdocument) && !isThirdParty
            && permittedDomains.isEmpty
        {
            // Due to https://github.com/AdguardTeam/AdguardBrowserExtension/issues/145
            throw SyntaxError.invalidRule(
                message:
                    "$subdocument blocking rules are allowed only along with third-party or if-domain modifiers"
            )
        }
    }

    /// Parses network rule options from the options string.
    private func loadOptions(options: String, version: SafariVersion) throws {
        let optionParts = options.split(delimiter: Chars.COMMA, escapeChar: Chars.BACKSLASH)

        for option in optionParts {
            var optionName = option
            var optionValue = ""

            if let valueIndex = option.utf8.firstIndex(of: Chars.EQUALS_SIGN) {
                optionName = String(option[..<valueIndex])
                if let nextIndex = option.utf8.index(
                    valueIndex,
                    offsetBy: 1,
                    limitedBy: option.utf8.endIndex
                ) {
                    optionValue = String(option[nextIndex...])
                }
            }

            try loadOption(optionName: optionName, optionValue: optionValue, version: version)
        }

        // Rules of these types can be applied to documents only:
        // $jsinject, $elemhide, $urlblock, $genericblock, $generichide and $content for whitelist rules.
        // $popup - for url blocking
        if !enabledOptions.isDisjoint(with: .documentLevel) {
            if permittedContentType != .subdocument {
                permittedContentType = .document
            }
        }
    }

    /// Attempts to parse a single network rule option.
    private func loadOption(optionName: String, optionValue: String, version: SafariVersion) throws
    {
        if optionName.utf8.first == Chars.UNDERSCORE {
            // A noop modifier does nothing and can be used to increase some rules readability.
            // It consists of the sequence of underscore characters (_) of any length
            // and can appear in a rule as many times as it's needed.
            if optionName.utf8.allSatisfy({ $0 == Chars.UNDERSCORE }) {
                return
            }
        }

        switch optionName {
        case "all":
            // A normal blocking rule in the case of Safari is almost the same as $all,
            // i.e. it blocks all requests including main frame ones.
            // So we're doing nothing here.
            break
        case "third-party", "~first-party", "3p", "~1p":
            isCheckThirdParty = true
            isThirdParty = true
        case "~third-party", "first-party", "1p", "~3p":
            isCheckThirdParty = true
            isThirdParty = false
        case "match-case":
            isMatchCase = true
        case "~match-case":
            isMatchCase = false
        case "important":
            isImportant = true
        case "popup":
            try setOptionEnabled(option: .popup, value: true)
        case "badfilter":
            isBadfilter = true
        case "domain", "from":
            try setNetworkRuleDomains(domains: optionValue)
        case "elemhide", "ehide":
            try setOptionEnabled(option: .elemhide, value: true)
        case "generichide", "ghide":
            try setOptionEnabled(option: .generichide, value: true)
        case "genericblock":
            try setOptionEnabled(option: .genericblock, value: true)
        case "specifichide", "shide":
            try setOptionEnabled(option: .specifichide, value: true)
        case "jsinject":
            try setOptionEnabled(option: .jsinject, value: true)
        case "urlblock":
            try setOptionEnabled(option: .urlblock, value: true)
        case "content":
            try setOptionEnabled(option: .content, value: true)
        case "document", "doc":
            try setOptionEnabled(option: .document, value: true)
        case "script":
            setRequestType(contentType: .script, enabled: true)
        case "~script":
            setRequestType(contentType: .script, enabled: false)
        case "stylesheet", "css":
            setRequestType(contentType: .stylesheet, enabled: true)
        case "~stylesheet", "~css":
            setRequestType(contentType: .stylesheet, enabled: false)
        case "subdocument", "frame":
            setRequestType(contentType: .subdocument, enabled: true)
        case "~subdocument", "~frame":
            setRequestType(contentType: .subdocument, enabled: false)
        case "image":
            setRequestType(contentType: .image, enabled: true)
        case "~image":
            setRequestType(contentType: .image, enabled: false)
        case "xmlhttprequest", "xhr":
            setRequestType(contentType: .xmlHttpRequest, enabled: true)
        case "~xmlhttprequest", "~xhr":
            setRequestType(contentType: .xmlHttpRequest, enabled: false)
        case "media":
            setRequestType(contentType: .media, enabled: true)
        case "~media":
            setRequestType(contentType: .media, enabled: false)
        case "font":
            setRequestType(contentType: .font, enabled: true)
        case "~font":
            setRequestType(contentType: .font, enabled: false)
        case "websocket":
            self.isWebSocket = true
            setRequestType(contentType: .websocket, enabled: true)
        case "~websocket":
            setRequestType(contentType: .websocket, enabled: false)
        case "other":
            setRequestType(contentType: .other, enabled: true)
        case "~other":
            setRequestType(contentType: .other, enabled: false)
        case "ping":
            // `ping` resource type is supported since Safari 14
            if version.isSafari14orGreater() {
                setRequestType(contentType: .ping, enabled: true)
            } else {
                throw SyntaxError.invalidModifier(message: "$ping is not supported")
            }
        case "~ping":
            // `ping` resource type is supported since Safari 14
            if version.isSafari14orGreater() {
                setRequestType(contentType: .ping, enabled: false)
            } else {
                throw SyntaxError.invalidModifier(message: "$~ping is not supported")
            }
        default:
            throw SyntaxError.invalidModifier(message: "Unsupported modifier: \(optionName)")
        }

        if optionName != "domain" && optionName != "from" && !optionValue.isEmpty {
            throw SyntaxError.invalidModifier(message: "Option \(optionName) must not have value")
        }
    }

    /// Enables or disables the specified content type for this rule.
    private func setRequestType(contentType: ContentType, enabled: Bool) {
        if enabled {
            if permittedContentType == .all {
                permittedContentType = []
            }

            permittedContentType.insert(contentType)
        } else {
            restrictedContentType.insert(contentType)
        }
    }

    /// Returns true if the rule has an option and that's the only specified option.
    public func isSingleOption(option: Option) -> Bool {
        return enabledOptions == option
    }

    /// Returns true if the specified option is enabled in this rule.
    public func isOptionEnabled(option: Option) -> Bool {
        return self.enabledOptions.contains(option)
    }

    /// Enables or disables the specified option.
    private func setOptionEnabled(option: Option, value: Bool) throws {
        if value {
            self.enabledOptions.insert(option)
        } else {
            self.disabledOptions.insert(option)
        }
    }

    /// Represents content types the rule can be limited to.
    public struct ContentType: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let image = ContentType(rawValue: 1 << 0)
        public static let stylesheet = ContentType(rawValue: 1 << 1)
        public static let script = ContentType(rawValue: 1 << 2)
        public static let media = ContentType(rawValue: 1 << 3)
        public static let xmlHttpRequest = ContentType(rawValue: 1 << 4)
        public static let other = ContentType(rawValue: 1 << 5)
        public static let websocket = ContentType(rawValue: 1 << 6)
        public static let font = ContentType(rawValue: 1 << 7)
        public static let document = ContentType(rawValue: 1 << 8)
        public static let subdocument = ContentType(rawValue: 1 << 9)
        public static let ping = ContentType(rawValue: 1 << 10)

        public static let all: ContentType = [
            .image,
            .stylesheet,
            .script,
            .media,
            .xmlHttpRequest,
            .other,
            .websocket,
            .font,
            .document,
            .subdocument,
            .ping,
        ]
    }

    /// Represents network rule options.
    public struct Option: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let elemhide = Option(rawValue: 1 << 0)
        public static let generichide = Option(rawValue: 1 << 1)
        public static let genericblock = Option(rawValue: 1 << 2)
        public static let specifichide = Option(rawValue: 1 << 3)
        public static let jsinject = Option(rawValue: 1 << 4)
        public static let urlblock = Option(rawValue: 1 << 5)
        public static let content = Option(rawValue: 1 << 6)
        public static let document = Option(rawValue: 1 << 7)
        public static let popup = Option(rawValue: 1 << 8)

        /// Document-level options cause the rule to be limited to "document" type.
        public static let documentLevel: Option = [
            .document,
            .popup,
            .whitelistOnly,
        ]

        /// These options can only be used in whitelist rules.
        public static let whitelistOnly: Option = [
            .jsinject,
            .elemhide,
            .content,
            .urlblock,
            .genericblock,
            .generichide,
            .specifichide,
        ]
    }
}
