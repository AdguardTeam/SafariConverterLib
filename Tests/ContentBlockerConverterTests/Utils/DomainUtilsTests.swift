import XCTest

@testable import ContentBlockerConverter

final class DomainUtilsTests: XCTestCase {
    func testExactMatch() {
        // Arrange
        let candidate = "google.com"
        let domain = "google.com"

        // Act
        let result = DomainUtils.isDomainOrSubdomain(candidate: candidate, domain: domain)

        // Assert
        XCTAssertTrue(
            result,
            "Expected \(candidate) to be recognized as the same domain \(domain)."
        )
    }

    func testSubdomainBasic() {
        // Arrange
        let candidate = "mail.google.com"
        let domain = "google.com"

        // Act
        let result = DomainUtils.isDomainOrSubdomain(candidate: candidate, domain: domain)

        // Assert
        XCTAssertTrue(result, "Expected \(candidate) to be recognized as a subdomain of \(domain).")
    }

    func testSubSubdomain() {
        // Arrange
        let candidate = "sub.mail.google.com"
        let domain = "google.com"

        // Act
        let result = DomainUtils.isDomainOrSubdomain(candidate: candidate, domain: domain)

        // Assert
        XCTAssertTrue(
            result,
            "Expected \(candidate) to be recognized as a deeper subdomain of \(domain)."
        )
    }

    func testDifferentDomain() {
        // Arrange
        let candidate = "gmail.com"
        let domain = "google.com"

        // Act
        let result = DomainUtils.isDomainOrSubdomain(candidate: candidate, domain: domain)

        // Assert
        XCTAssertFalse(
            result,
            "Expected \(candidate) NOT to be recognized as \(domain) or its subdomain."
        )
    }

    func testSimilarButNotSubdomain() {
        // Arrange
        let candidate = "googlecom"
        let domain = "google.com"

        // Act
        let result = DomainUtils.isDomainOrSubdomain(candidate: candidate, domain: domain)

        // Assert
        XCTAssertFalse(result, "Expected \(candidate) NOT to match or be a subdomain of \(domain).")
    }

    func testSubdomainWithDotAtEnd() {
        // Arrange
        let candidate = "subdomain.google.com."
        let domain = "google.com"

        // Act
        let result = DomainUtils.isDomainOrSubdomain(candidate: candidate, domain: domain)

        // Assert
        XCTAssertFalse(
            result,
            "Expected \(candidate) with trailing dot NOT to be recognized as a subdomain of \(domain)."
        )
    }

    func testMultipleTLDs() {
        // Arrange
        let candidate = "maps.google.co.uk"
        let domain = "google.co.uk"

        // Act
        let result = DomainUtils.isDomainOrSubdomain(candidate: candidate, domain: domain)

        // Assert
        XCTAssertTrue(result, "Expected \(candidate) to be recognized as a subdomain of \(domain).")
    }

    func testExactMultipleTLDs() {
        // Arrange
        let candidate = "google.co.uk"
        let domain = "google.co.uk"

        // Act
        let result = DomainUtils.isDomainOrSubdomain(candidate: candidate, domain: domain)

        // Assert
        XCTAssertTrue(
            result,
            "Expected \(candidate) to be recognized as the same domain \(domain)."
        )
    }

    func testShorterCandidate() {
        // Arrange
        let candidate = "com"
        let domain = "google.com"

        // Act
        let result = DomainUtils.isDomainOrSubdomain(candidate: candidate, domain: domain)

        // Assert
        XCTAssertFalse(result, "Expected \(candidate) NOT to match or be a subdomain of \(domain).")
    }

    func testEdgeCaseEmptyCandidate() {
        // Arrange
        let candidate = ""
        let domain = "google.com"

        // Act
        let result = DomainUtils.isDomainOrSubdomain(candidate: candidate, domain: domain)

        // Assert
        XCTAssertFalse(result, "Expected empty candidate NOT to be a subdomain of \(domain).")
    }

    func testEdgeCaseEmptyDomain() {
        // Arrange
        let candidate = "some.domain"
        let domain = ""

        // Act
        let result = DomainUtils.isDomainOrSubdomain(candidate: candidate, domain: domain)

        // Assert
        XCTAssertFalse(result, "Expected \(candidate) NOT to be recognized when domain is empty.")
    }

    // MARK: - Wildcard TLD (.*) tests

    func testWildcardTld_SameEtld1() {
        // Arrange
        let candidate = "google.com"
        let domain = "google.*"

        // Act
        let result = DomainUtils.isDomainOrSubdomain(candidate: candidate, domain: domain)

        // Assert
        XCTAssertTrue(result, "Expected \(candidate) to match wildcard domain \(domain).")
    }

    func testWildcardTld_MultipleTld() {
        // Arrange
        let candidate = "google.co.uk"
        let domain = "google.*"

        // Act
        let result = DomainUtils.isDomainOrSubdomain(candidate: candidate, domain: domain)

        // Assert
        XCTAssertTrue(result, "Expected \(candidate) to match wildcard domain \(domain).")
    }

    func testWildcardTld_Subdomain() {
        // Arrange
        let candidate = "sub.google.com"
        let domain = "google.*"

        // Act
        let result = DomainUtils.isDomainOrSubdomain(candidate: candidate, domain: domain)

        // Assert
        XCTAssertTrue(result, "Expected \(candidate) to be subdomain of wildcard \(domain).")
    }

    func testWildcardTld_SubPrefix() {
        // Arrange
        let candidate = "sub.google.com"
        let domain = "sub.google.*"

        // Act
        let result = DomainUtils.isDomainOrSubdomain(candidate: candidate, domain: domain)

        // Assert
        XCTAssertTrue(result, "Expected \(candidate) to match wildcard domain \(domain).")
    }

    func testWildcardTld_NegativeDifferentBase() {
        // Arrange
        let candidate = "notgoogle.com"
        let domain = "google.*"

        // Act
        let result = DomainUtils.isDomainOrSubdomain(candidate: candidate, domain: domain)

        // Assert
        XCTAssertFalse(result, "Expected \(candidate) NOT to match wildcard domain \(domain).")
    }

    func testWildcardTld_NegativeNotSubdomainOfSubPrefix() {
        // Arrange
        let candidate = "google.com"
        let domain = "sub.google.*"

        // Act
        let result = DomainUtils.isDomainOrSubdomain(candidate: candidate, domain: domain)

        // Assert
        XCTAssertFalse(result, "Expected \(candidate) NOT to match wildcard domain \(domain).")
    }

    // MARK: - doDomainsOverlap tests

    func testDoDomainsOverlap_WildcardSubdomainOfConcrete() {
        // "www.google.*" resolved with "com" → "www.google.com"
        // "www.google.com" IS a subdomain of "google.com" → true
        XCTAssertTrue(
            DomainUtils.doDomainsOverlap(
                concreteDomain: "google.com",
                wildcardDomain: "www.google.*"
            )
        )
    }

    func testDoDomainsOverlap_WildcardExactMatch() {
        // "google.*" resolved with "com" → "google.com"
        // "google.com" == "google.com" → true
        XCTAssertTrue(
            DomainUtils.doDomainsOverlap(
                concreteDomain: "google.com",
                wildcardDomain: "google.*"
            )
        )
    }

    func testDoDomainsOverlap_ConcreteSubdomainOfWildcard() {
        // "google.*" resolved with "com" → "google.com"
        // "sub.google.com" IS a subdomain of "google.com" → true
        XCTAssertTrue(
            DomainUtils.doDomainsOverlap(
                concreteDomain: "sub.google.com",
                wildcardDomain: "google.*"
            )
        )
    }

    func testDoDomainsOverlap_DeepSubdomainWildcard() {
        // "sub.example.*" resolved with "com" → "sub.example.com"
        // "sub.example.com" IS a subdomain of "example.com" → true
        XCTAssertTrue(
            DomainUtils.doDomainsOverlap(
                concreteDomain: "example.com",
                wildcardDomain: "sub.example.*"
            )
        )
    }

    func testDoDomainsOverlap_NegativeDifferentBase() {
        // "example.*" resolved with "com" → "example.com"
        // "other.com" is NOT related to "example.com" → false
        XCTAssertFalse(
            DomainUtils.doDomainsOverlap(
                concreteDomain: "other.com",
                wildcardDomain: "example.*"
            )
        )
    }

    func testDoDomainsOverlap_PlainDomains() {
        XCTAssertTrue(
            DomainUtils.doDomainsOverlap(
                concreteDomain: "sub.example.org",
                wildcardDomain: "example.org"
            )
        )
        XCTAssertTrue(
            DomainUtils.doDomainsOverlap(
                concreteDomain: "example.org",
                wildcardDomain: "sub.example.org"
            )
        )
        XCTAssertFalse(
            DomainUtils.doDomainsOverlap(
                concreteDomain: "example.org",
                wildcardDomain: "other.org"
            )
        )
    }

    func testDoDomainsOverlap_WildcardMultipleTld() {
        // "www.google.*" resolved with "co.uk" → "www.google.co.uk"
        // "www.google.co.uk" IS a subdomain of "google.co.uk" → true
        XCTAssertTrue(
            DomainUtils.doDomainsOverlap(
                concreteDomain: "google.co.uk",
                wildcardDomain: "www.google.*"
            )
        )
    }

    // MARK: - Performance tests

    /// Baseline results (Aug 8, 2025):
    /// - Machine: MacBook Pro M4 Max, 48GB RAM
    /// - OS: macOS 26
    /// - Swift: 6.2
    /// - Average execution time: ~0.022 sec
    ///
    /// To get your machine info: `system_profiler SPHardwareDataType`
    /// To get your macOS version: `sw_vers`
    /// To get your Swift version: `swift --version`
    func testPerformance_NonWildcardFastPath() {
        let pairs: [(String, String)] = [
            ("mail.google.com", "google.com"),
            ("sub.mail.google.com", "google.com"),
            ("maps.google.co.uk", "google.co.uk"),
            ("docs.example.org", "example.org"),
        ]

        var sink = 0
        measure {
            var local = 0
            for _ in 0..<20_000 {
                for (c, d) in pairs {
                    if DomainUtils.isDomainOrSubdomain(candidate: c, domain: d) {
                        local &+= 1
                    }
                }
            }
            sink = local
        }
        XCTAssertGreaterThanOrEqual(sink, 0)
    }

    /// Baseline results (Aug 8, 2025):
    /// - Machine: MacBook Pro M4 Max, 48GB RAM
    /// - OS: macOS 26
    /// - Swift: 6.2
    /// - Average execution time: ~0.022 sec
    ///
    /// To get your machine info: `system_profiler SPHardwareDataType`
    /// To get your macOS version: `sw_vers`
    /// To get your Swift version: `swift --version`
    func testPerformance_WildcardTldPath() {
        let pairs: [(String, String)] = [
            ("google.com", "google.*"),
            ("sub.google.com", "google.*"),
            ("google.co.uk", "google.*"),
            ("sub.google.co.uk", "sub.google.*"),
            ("maps.apple.fr", "apple.*"),
        ]

        var sink = 0
        measure {
            var local = 0
            for _ in 0..<2_000 {
                for (c, d) in pairs {
                    if DomainUtils.isDomainOrSubdomain(candidate: c, domain: d) {
                        local &+= 1
                    }
                }
            }
            sink = local
        }
        XCTAssertGreaterThanOrEqual(sink, 0)
    }
}
