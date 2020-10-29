import Foundation

/**
 * Network rule class
 */
class NetworkRule: Rule {
    private static let MASK_WHITE_LIST = "@@";
    private static let DOMAIN_VALIDATION_REGEXP = try! NSRegularExpression(pattern: "^[a-zA-Z0-9][a-zA-Z0-9-.]*[a-zA-Z0-9]\\.[a-zA-Z-]{2,}$", options: [.caseInsensitive]);
    
    private static let delimeterChar = ",".utf16.first!;
    private static let escapeChar = "\\".utf16.first!;

    var isUrlBlock = false;
    var isCssExceptionRule = false;
    
    var urlRuleText = "";
    
    var isCheckThirdParty = false;
    var isThirdParty = false;
    var isMatchCase = false;
    var isBlockPopups = false;
    var isReplace = false;
    var isCspRule = false;
    var isWebSocket = false;
    
    var permittedContentType: [ContentType] = [ContentType.ALL];
    var restrictedContentType: [ContentType] = [];
    
    var enabledOptions: [NetworkRuleOption] = [];
    var disabledOptions: [NetworkRuleOption] = [];
    
    var urlRegExpSource: String? = nil;
    
    var badfilter: String? = nil;
    
    override init() {
        super.init();
    }
    
    override init(ruleText: NSString) throws {
        try super.init(ruleText: ruleText);
        
        let ruleParts = try NetworkRuleParser.parseRuleText(ruleText: ruleText);
        self.isWhiteList = ruleParts.whitelist;
        
        if (ruleParts.options != nil && ruleParts.options != "") {
            try loadOptions(options: ruleParts.options!);
        }

        if (ruleParts.pattern != nil) {
            if (ruleParts.pattern! == "||"
                || ruleParts.pattern! == "*"
                || ruleParts.pattern! == ""
                || ruleParts.pattern!.count < 3
            ) {
                if (self.permittedDomains.count < 1) {
                    // Rule matches too much and does not have any domain restriction
                    // We should not allow this kind of rules
                    throw SyntaxError.invalidRule(message: "The rule is too wide, add domain restriction or make the pattern more specific");
                }
            }
        }
        
        self.urlRuleText = NetworkRuleParser.getAsciiDomainRule(pattern: ruleParts.pattern)!;
        
        if (self.isRegexRule()) {
            self.urlRegExpSource = self.urlRuleText.subString(startIndex: 1, length: self.urlRuleText.count - 2);
        } else {
            if (self.urlRuleText != "") {
                self.urlRegExpSource = SimpleRegex.createRegexText(str: self.urlRuleText);
            }
        }
        
        self.isDocumentWhiteList = isOptionEnabled(option: .Document);
        self.isUrlBlock = isSingleOption(option: .Urlblock) || isSingleOption(option: .Genericblock);
        self.isCssExceptionRule = isSingleOption(option: .Elemhide) || isSingleOption(option: .Generichide);
    }
    
    func isRegexRule() -> Bool {
        return self.urlRuleText.hasPrefix("/") && self.urlRuleText.hasSuffix("/")
    }

    func isSingleOption(option: NetworkRuleOption) -> Bool {
        return self.enabledOptions.count == 1 && self.enabledOptions.firstIndex(of: option) != nil;
    }
    
    func hasContentType(contentType: ContentType) -> Bool {
        if (permittedContentType == [ContentType.ALL] &&
            restrictedContentType.count == 0) {
            // Rule does not contain any constraint
            return true;
        }

        // Checking that either all content types are permitted or request content type is in the permitted list
        let matchesPermitted = permittedContentType == [ContentType.ALL] ||
            permittedContentType.firstIndex(of: contentType) ?? -1 >= 0;

        // Checking that either no content types are restricted or request content type is not in the restricted list
        let notMatchesRestricted = restrictedContentType.count == 0 ||
            restrictedContentType.firstIndex(of: contentType) == nil;

        return matchesPermitted && notMatchesRestricted;
    }
    
    func isContentType(contentType: ContentType) -> Bool {
        return permittedContentType.count == 1 && permittedContentType[0] == contentType;
    }
    
    /**
     * Parses domain and path
     */
    func parseRuleDomain() -> DomainInfo? {
        let startsWith = ["http://www.", "https://www.", "http://", "https://", "||", "//"];
        let contains = ["/", "^"];
        
        var startIndex = 0;

        for start in startsWith {
            if (self.urlRuleText.hasPrefix(start)) {
                startIndex = start.count;
                break;
            }
        }

        // Exclusive for domain
        let exceptRule = "domain=";
        let domainIndex = self.urlRuleText.indexOf(target: exceptRule);
        if (domainIndex > -1 && self.urlRuleText.indexOf(target: "$") > -1) {
            startIndex = domainIndex + exceptRule.count;
        }

        if (startIndex == -1) {
            return nil;
        }

        var symbolIndex = -1;
        for containsPrefix in contains {
            let index = self.urlRuleText.indexOf(target: containsPrefix, startIndex: startIndex);
            if (index >= 0) {
                symbolIndex = index;
                break;
            }
        }
        
        var pathEndIndex = self.urlRuleText.indexOf(target: "$");
        if (pathEndIndex == -1) {
            pathEndIndex = urlRuleText.count;
        }

        let domain = symbolIndex == -1 ? self.urlRuleText.subString(startIndex: startIndex) : self.urlRuleText.subString(startIndex: startIndex, toIndex: symbolIndex);
        let path = symbolIndex == -1 ? nil : self.urlRuleText.subString(startIndex: symbolIndex, toIndex: pathEndIndex);

        if (!SimpleRegex.isMatch(regex: NetworkRule.DOMAIN_VALIDATION_REGEXP, target: domain)) {
            // Not a valid domain name, ignore it
            return nil;
        }

        return DomainInfo(domain: domain, path: path);
    };
    
    /**
    * Returns true if this rule negates the specified rule
    * Only makes sense when this rule has a `badfilter` modifier
    */
    func negatesBadfilter(specifiedRule: NetworkRule) -> Bool {
        if (self.isWhiteList != specifiedRule.isWhiteList) {
            return false;
        }

        if (self.urlRuleText != specifiedRule.urlRuleText) {
            return false;
        }

        if (self.permittedContentType != specifiedRule.permittedContentType) {
            return false;
        }

        if (self.restrictedContentType != specifiedRule.restrictedContentType) {
            return false;
        }

        if (self.enabledOptions != specifiedRule.enabledOptions) {
            return false;
        }

        if (self.disabledOptions != specifiedRule.disabledOptions) {
            return false;
        }

        if (self.restrictedDomains != specifiedRule.restrictedDomains) {
            return false;
        }
        
        if (!NetworkRule.stringArraysHaveIntersection(left: self.permittedDomains, right: specifiedRule.permittedDomains)) {
            return false;
        }
        
        return true;
    }
    
    /**
     * TODO: Move to Array extension
     */
    static func stringArraysHaveIntersection(left: [String], right: [String]) -> Bool {
        if (left.count == 0 || right.count == 0) {
            return true;
        }

        for elem in left {
            if (right.contains(elem)) {
                return true;
            }
        }

        return false;
    }
    
    private func loadOptions(options: String) throws -> Void {
        let optionParts = options.splitByDelimiterWithEscapeCharacter(delimeter: NetworkRule.delimeterChar, escapeChar: NetworkRule.escapeChar);
        
        for option in optionParts {
            var optionName = option;
            var optionValue = "";
            
            let valueIndex = option.indexOf(target: "=");
            if (valueIndex > 0) {
                optionName = option.subString(startIndex: 0, toIndex: valueIndex);
                optionValue = option.subString(startIndex: valueIndex + 1);
            }
            
            try loadOption(optionName: optionName, optionValue: optionValue);
        }

        // Rules of these types can be applied to documents only
        // $jsinject, $elemhide, $urlblock, $genericblock, $generichide and $content for whitelist rules.
        // $popup - for url blocking
        if (
            isOptionEnabled(option: NetworkRuleOption.Document)
            || isOptionEnabled(option: NetworkRuleOption.Jsinject)
            || isOptionEnabled(option: NetworkRuleOption.Elemhide)
            || isOptionEnabled(option: NetworkRuleOption.Content)
            || isOptionEnabled(option: NetworkRuleOption.Urlblock)
            || isOptionEnabled(option: NetworkRuleOption.Genericblock)
            || isOptionEnabled(option: NetworkRuleOption.Generichide)
            || isBlockPopups
        ) {
            self.permittedContentType = [ContentType.DOCUMENT];
        }
    }

    private func loadOption(optionName: String, optionValue: String) throws -> Void {
        switch (optionName) {
            // General options
            case "third-party",
                 "~first-party":
                self.isCheckThirdParty = true;
                self.isThirdParty = true;
                break;
            case "~third-party",
                 "first-party":
                self.isCheckThirdParty = true;
                self.isThirdParty = false;
                break;
            case "match-case":
                self.isMatchCase = true;
                break;
            case "~match-case":
                self.isMatchCase = false;
                break;
            case "important":
                self.isImportant = true;
                break;
            case "popup":
                self.isBlockPopups = true;
                break;
            
            // Special modifiers
            case "badfilter":
                self.badfilter = parseBadfilter();
                break;
            case "csp":
                self.isCspRule = true;
                break;
            case "replace":
                self.isReplace = true;
                break;

            // $domain modifier
            case "domain":
                try self.setDomains(domains: optionValue, sep: "|");
                break;
            
            // Document-level whitelist rules
            case "elemhide":
                try setOptionEnabled(option: NetworkRuleOption.Elemhide, value: true);
                break;
            case "generichide":
                try setOptionEnabled(option: NetworkRuleOption.Generichide, value: true);
                break;
            case "genericblock":
                try setOptionEnabled(option: NetworkRuleOption.Genericblock, value: true);
                break;
            case "jsinject":
                try setOptionEnabled(option: NetworkRuleOption.Jsinject, value: true);
                break;
            case "urlblock":
                try setOptionEnabled(option: NetworkRuleOption.Urlblock, value: true);
                break;
            case "content":
                try setOptionEnabled(option: NetworkRuleOption.Content, value: true);
                break;

            // $document
            case "document":
                try setOptionEnabled(option: NetworkRuleOption.Document, value: true);
                break;

            // Content type options
            case "script":
                setRequestType(contentType: ContentType.SCRIPT, enabled: true);
                break;
            case "~script":
                setRequestType(contentType: ContentType.SCRIPT, enabled: false);
                break;
            case "stylesheet":
                setRequestType(contentType: ContentType.STYLESHEET, enabled: true);
                break;
            case "~stylesheet":
                setRequestType(contentType: ContentType.STYLESHEET, enabled: false);
                break;
            case "subdocument":
                setRequestType(contentType: ContentType.SUBDOCUMENT, enabled: true);
                break;
            case "~subdocument":
                setRequestType(contentType: ContentType.SUBDOCUMENT, enabled: false);
                break;
            case "object":
                setRequestType(contentType: ContentType.OBJECT, enabled: true);
                break;
            case "~object":
                setRequestType(contentType: ContentType.OBJECT, enabled: false);
                break;
            case "image":
                setRequestType(contentType: ContentType.IMAGE, enabled: true);
                break;
            case "~image":
                setRequestType(contentType: ContentType.IMAGE, enabled: false);
                break;
            case "xmlhttprequest":
                setRequestType(contentType: ContentType.XMLHTTPREQUEST, enabled: true);
                break;
            case "~xmlhttprequest":
                setRequestType(contentType: ContentType.XMLHTTPREQUEST, enabled: false);
                break;
            case "media":
                setRequestType(contentType: ContentType.MEDIA, enabled: true);
                break;
            case "~media":
                setRequestType(contentType: ContentType.MEDIA, enabled: false);
                break;
            case "font":
                setRequestType(contentType: ContentType.FONT, enabled: true);
                break;
            case "~font":
                setRequestType(contentType: ContentType.FONT, enabled: false);
                break;
            case "websocket":
                self.isWebSocket = true;
                setRequestType(contentType: ContentType.WEBSOCKET, enabled: true);
                break;
            case "~websocket":
                setRequestType(contentType: ContentType.WEBSOCKET, enabled: false);
                break;
            case "other":
                setRequestType(contentType: ContentType.OTHER, enabled: true);
                break;
            case "~other":
                setRequestType(contentType: ContentType.OTHER, enabled: false);
                break;
            case "object-subrequest":
                setRequestType(contentType: ContentType.OBJECT_SUBREQUEST, enabled: true);
                break;
            case "~object-subrequest":
                setRequestType(contentType: ContentType.OBJECT_SUBREQUEST, enabled: false);
                break;
            case "ping":
                setRequestType(contentType: ContentType.PING, enabled: true);
                break;
            case "~ping":
                setRequestType(contentType: ContentType.PING, enabled: false);
                break;
            case "webrtc":
                setRequestType(contentType: ContentType.WEBRTC, enabled: true);
                break;
            case "~webrtc":
                setRequestType(contentType: ContentType.WEBRTC, enabled: false);
                break;

            default:
                throw SyntaxError.invalidRule(message: "Unknown option: \(optionName)");
            }
    }
    
    private func setRequestType(contentType: ContentType, enabled: Bool) -> Void {
        if (enabled) {
            if (self.permittedContentType.firstIndex(of: ContentType.ALL) != nil) {
                self.permittedContentType = [];
            }
            
            self.permittedContentType.append(contentType)
        } else {
            self.restrictedContentType.append(contentType);
        }
    }
    
    private func setOptionEnabled(option: NetworkRuleOption, value: Bool) throws -> Void {
        // TODO: Respect options restrictions
        if (value) {
            self.enabledOptions.append(option);
        } else {
            self.disabledOptions.append(option);
        }
    }
    
    private func isOptionEnabled(option: NetworkRuleOption) -> Bool {
        return self.enabledOptions.firstIndex(of: option) != nil;
    }
    
    private func parseBadfilter() -> String {
        return self.ruleText
            .replacingOccurrences(of: "$badfilter,", with: "$")
            .replacingOccurrences(of: ",badfilter", with: "")
            .replacingOccurrences(of: "$badfilter", with: "");
    }
    
    struct DomainInfo {
        var domain: String?;
        var path: String?;
    }
    
    enum ContentType {
        case ALL
        case IMAGE
        case STYLESHEET
        case SCRIPT
        case MEDIA
        case XMLHTTPREQUEST
        case OTHER
        case WEBSOCKET
        case FONT
        case DOCUMENT
        case SUBDOCUMENT
        case OBJECT
        case OBJECT_SUBREQUEST
        case WEBRTC
        case PING
    }
    
    enum NetworkRuleOption {
        case Elemhide
        case Generichide
        case Genericblock
        case Jsinject
        case Urlblock
        case Content
        case Document
    }
}
