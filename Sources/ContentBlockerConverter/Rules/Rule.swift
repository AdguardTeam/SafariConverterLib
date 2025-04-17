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

    /// Parses the list of domains separated by the separator character and populates
    /// permittedDomains and restrictedDomains collections.
    ///
    /// Note, that it does not clear its state and can be called multiple times.
    ///
    /// - Parameters:
    ///   - domainsStr: a string with domains to be parsed.
    ///   - separator: a separator for the list of domains.
    /// - Throws: SyntaxError if encountered an invalid domain.
    func addDomains(domainsStr: String, separator: UInt8) throws {
        let utfString = domainsStr.utf8

        let maxIndex = utfString.count - 1
        var previousSeparator = 0
        var nonASCIIFound = false

        for i in 0...maxIndex {
            // swiftlint:disable:next force_unwrapping
            let char = utfString[safeIndex: i]!

            if char == separator || i == maxIndex {
                if i - previousSeparator <= 2 {
                    throw SyntaxError.invalidModifier(
                        message: "Empty or too short domain specified"
                    )
                }

                var restricted = false
                if let firstDomainChar = utfString[safeIndex: previousSeparator],
                    firstDomainChar == Chars.TILDE
                {
                    restricted = true
                    previousSeparator += 1
                }

                let separatorIndex = i == maxIndex ? maxIndex + 1 : i
                let utfStartIdx = utfString.index(utfString.startIndex, offsetBy: previousSeparator)
                let utfEndIdx = utfString.index(utfString.startIndex, offsetBy: separatorIndex)

                var domain = String(domainsStr[utfStartIdx..<utfEndIdx])
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

                previousSeparator = i + 1
                nonASCIIFound = false
            } else {
                if char > 127 {
                    // Record that a non-ASCII character was found in the domain name.
                    nonASCIIFound = true
                }
            }
        }
    }
}
