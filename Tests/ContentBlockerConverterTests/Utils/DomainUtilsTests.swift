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
}
