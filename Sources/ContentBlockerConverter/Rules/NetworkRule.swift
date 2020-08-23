import Foundation

/**
 * Network rule class
 */
class NetworkRule: Rule {
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
    
    func getUrlRegExpSource() -> String? {
        // TODO: getUrlRegExpSource
        return nil;
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
