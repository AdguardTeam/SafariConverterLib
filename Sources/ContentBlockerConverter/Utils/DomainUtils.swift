/// Helper functions for working with domains.
public enum DomainUtils {
    /// Determines if `candidate` is exactly the given `domain` or a subdomain of it.
    ///
    /// This function compares the candidate string to the domain string using their
    /// UTF-8 representation, ensuring minimal overhead by avoiding unnecessary allocations
    /// or bridging.
    ///
    /// - Parameters:
    ///   - candidate: The domain string being tested.
    ///   - domain: The reference domain.
    /// - Returns: `true` if `candidate` is the same as or a subdomain of `domain`; otherwise, `false`.
    public static func isDomainOrSubdomain(candidate: String, domain: String) -> Bool {
        // 1) Quick check for exact match
        if candidate == domain {
            return true
        }

        // 2) Check byte length in UTF-8
        let domainCount = domain.utf8.count
        let candidateCount = candidate.utf8.count

        // candidate must be at least 1 character (the '.') longer than domain
        guard candidateCount > domainCount else {
            return false
        }

        // 3) Compare the tail of `candidate` with `domain`
        let cBytes = candidate.utf8
        let dBytes = domain.utf8

        // Start index for comparing the trailing part of `candidate` with `domain`
        var cIndex = cBytes.index(cBytes.endIndex, offsetBy: -domainCount)
        var dIndex = dBytes.startIndex

        // Compare byte by byte
        while dIndex < dBytes.endIndex {
            if cBytes[cIndex] != dBytes[dIndex] {
                return false
            }
            cBytes.formIndex(after: &cIndex)
            dBytes.formIndex(after: &dIndex)
        }

        // 4) If the tail matched, ensure there's a '.' right before it in `candidate`
        //    Since candidateCount > domainCount, there must be at least one character before the tail.
        let dotIndex = cBytes.index(cBytes.endIndex, offsetBy: -domainCount - 1)
        return cBytes[dotIndex] == UInt8(ascii: ".")
    }
}
