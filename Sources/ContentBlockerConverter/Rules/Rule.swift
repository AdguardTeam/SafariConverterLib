import Foundation
import Punycode

/**
 * AG Rule super class
 */
class Rule {
    var ruleText: String = ""
    
    var isWhiteList = false
    var isImportant = false

    // TODO(ameshkov): !!! Cosmetic???
    var isScript = false
    var isScriptlet = false
    var isDocumentWhiteList = false

    var permittedDomains = [String]()
    var restrictedDomains = [String]()
    
    init() {
        
    }
    
    init(ruleText: String) throws {
        self.ruleText = ruleText;
    }
    
    /// Parses the list of domains separated by the separator character.
    func setDomains(domainsStr: String, separator: UInt8) throws -> Void {
        let utfString = domainsStr.utf8
        
        let maxIndex = utfString.count - 1
        var previousSeparator = 0
        var nonASCIIFound = false
        
        for i in 0...maxIndex {
            let char = utfString[safeIndex: i]!
            
            if char == separator || i == maxIndex {
                if i - previousSeparator <= 2 {
                    // TODO(ameshkov): !!! Add test that checks this.
                    throw SyntaxError.invalidRule(message: "Empty or too short domain specified")
                }
                
                var restricted = false
                let firstDomainChar = utfString[safeIndex: previousSeparator]
                if firstDomainChar == Chars.TILDE {
                    restricted = true
                    previousSeparator += 1
                }
                
                let separatorIndex = i == maxIndex ? maxIndex + 1 : i
                let utfStartIdx = utfString.index(utfString.startIndex, offsetBy: previousSeparator)
                let utfEndIdx = utfString.index(utfString.startIndex, offsetBy: separatorIndex)
                
                var domain = String(domainsStr[utfStartIdx..<utfEndIdx])
                if nonASCIIFound {
                    domain = domain.idnaEncoded!
                }
                
                if restricted {
                    restrictedDomains.append(domain)
                } else {
                    permittedDomains.append(domain)
                }
                
                previousSeparator = i + 1
                nonASCIIFound = false
            } else {
                // TODO(ameshkov): !!! Test for non-ASCII domains.
                if char > 127 {
                    // Record that a non-ASCII character was found in the domain name.
                    nonASCIIFound = true
                }
            }
        }
    }
}
