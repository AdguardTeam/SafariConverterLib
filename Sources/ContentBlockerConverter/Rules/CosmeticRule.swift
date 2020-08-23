import Foundation

/**
 * Cosmetic rule class
 */
class CosmeticRule: Rule {
    var script: String? = nil;
    var scriptlet: String? = nil;
    var scriptletParam: String? = nil;
    
    var isExtendedCss = false;
    var isInjectCss = false;
    var cssSelector: String? = nil;
}
