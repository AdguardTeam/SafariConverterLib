import Foundation
import Punycode

/// Super class for AdGuard rules.
public class Rule {
    public let ruleText: String

    public var isWhiteList = false
    public var isImportant = false

    public var permittedDomains: [String] = []
    public var restrictedDomains: [String] = []

    init(ruleText: String, for version: SafariVersion = SafariVersion.autodetect()) throws {
        self.ruleText = ruleText
    }

    /// Parses domainsStr and populates `permittedDomains` and `restrictedDomains` arrays with
    /// the lists of domains parsed out.
    ///
    /// - Parameters:
    ///   - domainsStr: String with the list of domains separated by `separator`. If the domain name
    ///           starts with `~` it will be added to `restrictedDomains`,
    ///           otherwise to `permittedDomains`.
    ///   - separator: Separator character for the domains list.
    ///
    /// - Throws: `SyntaxError` if the list is invalid.
    func addDomains(domainsStr: String, separator: UInt8) throws {
        let utf8 = domainsStr.utf8
        var currentIndex = utf8.startIndex
        var domainStartIndex = currentIndex
        var nonASCIIFound = false
        var restricted = false

        /// Creates domain string from `current` buffer and adds it to the corresponding list.
        ///
        /// - Throws: `SyntaxError` if domain is invalid.
        @inline(__always)
        func addDomain() throws {
            if domainStartIndex == currentIndex {
                throw SyntaxError.invalidModifier(
                    message: "Empty domain"
                )
            }

            var domain = String(domainsStr[domainStartIndex..<currentIndex])

            if domain.utf8.count < 2 {
                throw SyntaxError.invalidModifier(
                    message: "Domain is too short: \(domain)"
                )
            }

            if nonASCIIFound, let encodedDomain = domain.idnaEncoded {
                domain = encodedDomain
            }

            if domain.utf8.first == Chars.SLASH && domain.utf8.last == Chars.SLASH {
                // https://github.com/AdguardTeam/SafariConverterLib/issues/53
                throw SyntaxError.invalidModifier(
                    message: "Using regular expression for domain modifier is not supported"
                )
            }

            if restricted {
                restrictedDomains.append(domain)
            } else {
                permittedDomains.append(domain)
            }
        }

        while currentIndex < utf8.endIndex {
            let char = utf8[currentIndex]

            switch char {
            case separator:
                try addDomain()

                // Reset
                domainStartIndex = utf8.index(after: currentIndex)
                nonASCIIFound = false
                restricted = false
            case UInt8(ascii: "~"):
                // Validate that the previous character was separator
                if domainStartIndex != currentIndex {
                    throw SyntaxError.invalidModifier(
                        message: "Unexpected tilda character"
                    )
                }
                restricted = true

                // Shift domain start index +1 char.
                domainStartIndex = utf8.index(after: currentIndex)
            default:
                if char > 127 {
                    // Record that a non-ASCII character was found in the domain name.
                    nonASCIIFound = true
                }
            }

            currentIndex = utf8.index(after: currentIndex)
        }

        // Add the last domain
        try addDomain()
    }
}
