import Foundation
import Punycode

/**
 * AG Rule super class
 */
class Rule {
    var ruleText: NSString = "";

    var isWhiteList = false;
    var isImportant = false;

    var isScript = false;
    var isScriptlet = false;
    var isDocumentWhiteList = false;

    var permittedDomains = [String]();
    var restrictedDomains = [String]();

    var pathModifier: String?;

    public static let COMMA_SEPARATOR = ","
    public static let VERTICAL_SEPARATOR = "|"

    init() {

    }

    init(ruleText: NSString) throws {
        self.ruleText = ruleText;
    }

    func setDomains(domains: String, separator: String) throws -> Void {
        let domainsList = domains.components(separatedBy: separator)

        for var domain in domainsList {
            var restricted = false;
            if domain.hasPrefix("~") {
                restricted = true
                domain = domain.subString(startIndex: 1)
            }

            if domain == "" {
                throw SyntaxError.invalidRule(message: "Empty domain specified")
            }

            var encoded = domain
            if !domain.isASCII() {
                encoded = domain.idnaEncoded!
            }

            if restricted {
                restrictedDomains.append(domain)
            } else {
                permittedDomains.append(encoded)
            }
        }
    }
}
