import PublicSuffixList

/// Helper functions for working with domains.
public enum DomainUtils {
    /// Determines if `candidate` is the same as `domain` or its subdomain.
    ///
    /// Fast path:
    /// For normal domains (no `.*`), this uses UTF-8 byte comparison and avoids
    /// allocations or bridging.
    ///
    /// Wildcard TLD (`.*`) support:
    /// If `domain` ends with `.*` (e.g., `google.*`, `sub.google.*`), the
    /// candidate's public suffix is resolved with `PublicSuffixList`. Then a
    /// concrete base domain is built as `prefix + "." + suffix`, and the same
    /// fast suffix check is applied. This keeps the common path fast while
    /// supporting rules that target all effective TLDs.
    ///
    /// ### Examples
    /// ```
    /// // Normal domains
    /// DomainUtils.isDomainOrSubdomain(candidate: "google.com", domain: "google.com") == true
    /// DomainUtils.isDomainOrSubdomain(candidate: "mail.google.com", domain: "google.com") == true
    /// DomainUtils.isDomainOrSubdomain(candidate: "google.com", domain: "mail.google.com") == false
    ///
    /// // Wildcard TLD
    /// DomainUtils.isDomainOrSubdomain(candidate: "google.com", domain: "google.*") == true
    /// DomainUtils.isDomainOrSubdomain(candidate: "google.co.uk", domain: "google.*") == true
    /// DomainUtils.isDomainOrSubdomain(candidate: "sub.google.com", domain: "google.*") == true
    /// DomainUtils.isDomainOrSubdomain(candidate: "sub.google.com", domain: "sub.google.*") == true
    /// ```
    ///
    /// - Parameters:
    ///   - candidate: The domain string being tested.
    ///   - domain: The reference domain. May end with `.*` to match any TLD.
    /// - Returns: `true` if `candidate` is the same as or a subdomain of
    ///   `domain`; otherwise, `false`.
    public static func isDomainOrSubdomain(candidate: String, domain: String) -> Bool {
        // Handle wildcard TLD pattern: "<prefix>.*" (e.g., "google.*", "sub.google.*").
        // This branch is only taken for wildcard domains to keep the common path fast.
        if domain.hasSuffix(".*") {
            return isDomainOrSubdomainWithWildcard(candidate: candidate, domain: domain)
        }

        // Non-wildcard: use the original fast path.
        return isDomainOrSubdomainFast(candidate: candidate, domain: domain)
    }

    /// Handles the case when domain ends with `.*` and checks if `candidate` is
    /// a subdomain (or exactly one of the domains disregarding the TLD).
    private static func isDomainOrSubdomainWithWildcard(candidate: String, domain: String) -> Bool {
        let prefix = String(domain.dropLast(2))
        guard !prefix.isEmpty else { return false }

        // Resolve candidate's public suffix (e.g., "com", "co.uk").
        guard let (suffix, _) = PublicSuffixList.parsePublicSuffix(candidate) else {
            return false
        }

        // Compose a concrete base domain (e.g., "google.com", "sub.google.co.uk").
        let baseDomain = prefix + "." + suffix
        return isDomainOrSubdomainFast(candidate: candidate, domain: baseDomain)
    }

    /// Checks whether two domains overlap in either direction, taking
    /// wildcard TLDs (`.*`) into account.
    ///
    /// This is useful for determining whether restricting
    /// `concreteDomain` on a rule scoped to `wildcardDomain` would
    /// have any effect. It returns `true` when:
    /// - `concreteDomain` is a subdomain of (or equal to) the
    ///   resolved wildcard domain, **or**
    /// - the resolved wildcard domain is a subdomain of
    ///   `concreteDomain`.
    ///
    /// When `wildcardDomain` does not end with `.*`, this falls back
    /// to the standard `isDomainOrSubdomain` check in both
    /// directions.
    ///
    /// ### Examples
    /// ```
    /// // "www.google.*" resolved with "com" → "www.google.com"
    /// // "www.google.com" IS a subdomain of "google.com" → true
    /// doDomainsOverlap(
    ///     concreteDomain: "google.com",
    ///     wildcardDomain: "www.google.*"
    /// ) == true
    ///
    /// // "google.*" resolved with "com" → "google.com"
    /// // "google.com" == "google.com" → true
    /// doDomainsOverlap(
    ///     concreteDomain: "google.com",
    ///     wildcardDomain: "google.*"
    /// ) == true
    ///
    /// // "example.*" resolved with "com" → "example.com"
    /// // "example.com" is NOT related to "other.com" → false
    /// doDomainsOverlap(
    ///     concreteDomain: "other.com",
    ///     wildcardDomain: "example.*"
    /// ) == false
    /// ```
    ///
    /// - Parameters:
    ///   - concreteDomain: A concrete domain (no wildcards).
    ///   - wildcardDomain: A domain that may end with `.*`.
    /// - Returns: `true` when the domains overlap; otherwise `false`.
    public static func doDomainsOverlap(
        concreteDomain: String,
        wildcardDomain: String
    ) -> Bool {
        if wildcardDomain.hasSuffix(".*") {
            let prefix = String(wildcardDomain.dropLast(2))
            guard !prefix.isEmpty else { return false }

            guard
                let (suffix, _) =
                    PublicSuffixList.parsePublicSuffix(concreteDomain)
            else {
                return false
            }

            let resolved = prefix + "." + suffix
            // Check both directions.
            return isDomainOrSubdomainFast(
                candidate: concreteDomain,
                domain: resolved
            )
                || isDomainOrSubdomainFast(
                    candidate: resolved,
                    domain: concreteDomain
                )
        }

        // No wildcard — check both directions with plain domains.
        return isDomainOrSubdomainFast(
            candidate: concreteDomain,
            domain: wildcardDomain
        )
            || isDomainOrSubdomainFast(
                candidate: wildcardDomain,
                domain: concreteDomain
            )
    }

    /// Fast path for checking if `candidate` is exactly `domain` or a subdomain of it.
    /// This function uses UTF-8 byte comparison and avoids unnecessary allocations.
    private static func isDomainOrSubdomainFast(candidate: String, domain: String) -> Bool {
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
