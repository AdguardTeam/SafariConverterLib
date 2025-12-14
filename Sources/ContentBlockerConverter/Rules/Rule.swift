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
    ///   - version: Safari version which will use that rule.
    ///
    /// - Throws: `SyntaxError` if the list is invalid.
    func addDomains(domainsStr: String, separator: UInt8, version: SafariVersion) throws {
        let utf8 = domainsStr.utf8
        var currentIndex = utf8.startIndex
        var domainStartIndex = currentIndex
        var nonASCIIFound = false
        var restricted = false
        var insideRegex = false
        var previousCharWasBackslash = false

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
            let domainUtf8 = domain.utf8
            let domainByteCount = domainUtf8.count

            if domainByteCount < 2 {
                throw SyntaxError.invalidModifier(
                    message: "Domain is too short: \(domain)"
                )
            }

            let domainStartsWithSlash = domainUtf8.first == Chars.SLASH
            if domainStartsWithSlash, domainByteCount == 2 {
                let secondByte = domainUtf8[domainUtf8.index(after: domainUtf8.startIndex)]
                if secondByte == Chars.SLASH {
                    throw SyntaxError.invalidModifier(
                        message: "Empty regular expression for domain modifier"
                    )
                }
            }

            let domainEndsWithSlash = domainUtf8.last == Chars.SLASH
            if domainStartsWithSlash {
                if !domainEndsWithSlash {
                    throw SyntaxError.invalidModifier(
                        message: "Invalid regular expression for domain modifier: \(domain)"
                    )
                }

                if !version.isSafari26orGreater() {
                    // https://github.com/AdguardTeam/SafariConverterLib/issues/53
                    throw SyntaxError.invalidModifier(
                        message: "Using regular expression for domain modifier is not supported"
                    )
                }
            } else if nonASCIIFound, let encodedDomain = domain.idnaEncoded {
                domain = encodedDomain
            }

            if restricted {
                restrictedDomains.append(domain)
            } else {
                permittedDomains.append(domain)
            }
        }

        while currentIndex < utf8.endIndex {
            let char = utf8[currentIndex]

            if currentIndex == domainStartIndex && char == Chars.SLASH {
                insideRegex = true
            }

            if insideRegex && char == Chars.SLASH && !previousCharWasBackslash
                && currentIndex != domainStartIndex
            {
                // Closing slash of the regex domain.
                insideRegex = false
            }

            switch char {
            case separator:
                if insideRegex {
                    break
                }

                try addDomain()

                // Reset
                domainStartIndex = utf8.index(after: currentIndex)
                nonASCIIFound = false
                restricted = false
                insideRegex = false
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

            if previousCharWasBackslash {
                previousCharWasBackslash = false
            } else {
                previousCharWasBackslash = char == Chars.BACKSLASH
            }

            currentIndex = utf8.index(after: currentIndex)
        }

        // Add the last domain
        try addDomain()
    }
}
