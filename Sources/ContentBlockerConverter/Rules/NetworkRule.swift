import Foundation

/**
 * Network rule class
 */
class NetworkRule: Rule {
    private static let MASK_WHITE_LIST = "@@";
    
    var isCspRule = false;
    var isWebSocket = false;
    
    // TODO: set isUrlBlock/isCssExceptionRule according to:
    //        function isUrlBlockRule(r) {
    //            return isSingleOption(r, adguard.rules.UrlFilterRule.options.URLBLOCK) ||
    //                isSingleOption(r, adguard.rules.UrlFilterRule.options.GENERICBLOCK);
    //        }
    //
    //        function isCssExceptionRule(r) {
    //            return isSingleOption(r, adguard.rules.UrlFilterRule.options.GENERICHIDE) ||
    //                isSingleOption(r, adguard.rules.UrlFilterRule.options.ELEMHIDE);
    //        }

    var isUrlBlock = false;
    var isCssExceptionRule = false;
    
    var urlRuleText = "";
    
    var isCheckThirdParty = false;
    var isThirdParty = false;
    var isMatchCase = false;
    var isBlockPopups = false;
    var isReplace = false;
    
    var permittedContentType: [ContentType] = [];
    var restrictedContentType: [ContentType] = [];
    
    var urlRegExpSource: String? = nil;
    
    override init() {
        super.init();
    }
    
    override init(ruleText: String) throws {
        try super.init(ruleText: ruleText);
        
        let ruleParts = try! NetworkRule.parseRuleText(ruleText: ruleText);
        self.urlRuleText = ruleParts.pattern!;
        self.isWhiteList = ruleParts.whitelist;
        
        // TODO: set
//        var isImportant = false;
//
//        var isScript = false;
//        var isScriptlet = false;
//        var isDocumentWhiteList = false;
    }
    
    /**
     * parseRuleText splits the rule text into multiple parts.
     * @param ruleText - original rule text
     * @returns basic rule parts
     *
     * @throws error if the rule is empty (for instance, empty string or `@@`)
     */
    private static func parseRuleText(ruleText: String) throws -> BasicRuleParts {
        var ruleParts = BasicRuleParts();

        var startIndex = 0;
        if (ruleText.hasPrefix(NetworkRule.MASK_WHITE_LIST)) {
            ruleParts.whitelist = true;
            startIndex = MASK_WHITE_LIST.count;
        }

        if (ruleText.count <= startIndex) {
            throw SyntaxError.invalidRule(message: "Rule is too short");
        }

        // Setting pattern to rule text (for the case of empty options)
        ruleParts.pattern = ruleText.subString(startIndex: startIndex);

        // Avoid parsing options inside of a regex rule
        if (ruleParts.pattern!.hasPrefix("/")
            && ruleParts.pattern!.hasSuffix("/")
            && (ruleParts.pattern?.indexOf(target: "$replace=") == nil)) {
            return ruleParts;
        }

//        let foundEscaped = false;
//        for (let i = ruleText.length - 2; i >= startIndex; i -= 1) {
//            const c = ruleText.charAt(i);
//
//            if (c === OPTIONS_DELIMITER) {
//                if (i > startIndex && ruleText.charAt(i - 1) === escapeCharacter) {
//                    foundEscaped = true;
//                } else {
//                    ruleParts.pattern = ruleText.substring(startIndex, i);
//                    ruleParts.options = ruleText.substring(i + 1);
//
//                    if (foundEscaped) {
//                        // Find and replace escaped options delimiter
//                        ruleParts.options = ruleParts.options.replace(reEscapedOptionsDelimiter, OPTIONS_DELIMITER);
//                        // Reset the regexp state
//                        reEscapedOptionsDelimiter.lastIndex = 0;
//                    }
//
//                    // Options delimiter was found, exiting loop
//                    break;
//                }
//            }
//        }

        return ruleParts;
    }
    
    func getUrlRegExpSource() -> String? {
        return urlRegExpSource;
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

        if (!domain.isMatch(regex: "^[a-zA-Z0-9][a-zA-Z0-9-.]*[a-zA-Z0-9]\\.[a-zA-Z-]{2,}$")) {
            // Not a valid domain name, ignore it
            return nil;
        }

        return DomainInfo(domain: domain, path: path);
    };
    
    struct BasicRuleParts {
        var pattern: String?;
        var options: String?;
        var whitelist = false;
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
    }
}
