import XCTest

@testable import ContentBlockerConverter

final class AffinityRulesGrouperTests: XCTestCase {

    // MARK: - group(rules:)

    func testGroupWithoutAffinity() {
        let generalRules = [
            "||cdn.allsportsflix.best^$third-party",
            "||vurobyde.xyz^$third-party",
            "||adnxs-simple.com^$third-party",
            "||main-ti-hub.com^",
        ]

        let result = AffinityRulesGrouper.group(rules: [
            (.general, generalRules)
        ])

        XCTAssertEqual(result[.general]?.count, 4)
        XCTAssertEqual(result[.privacy]?.count, 0)
        XCTAssertEqual(result[.socialWidgetsAndAnnoyances]?.count, 0)
        XCTAssertEqual(result[.other]?.count, 0)
        XCTAssertEqual(result[.custom]?.count, 0)
        XCTAssertEqual(result[.security]?.count, 0)
    }

    func testGroupWithAffinity() {
        let rules = [
            "! Checksum: ZfQYKYYCHnYvVSRxWh6gNw",
            "",
            "ally.sh#@#.adsBox",
            "ondemandkorea.com#@#.afs_ads",
            "!#safari_cb_affinity(general,privacy)",
            "@@||imasdk.googleapis.com/js/sdkloader/ima3.js$domain=ondemandkorea.com",
            "@@||production-static.ondemandkorea.com/images^",
            "@@||openx.net/|$domain=ondemandkorea.com",
            "!#safari_cb_affinity",
            "||vurobyde.xyz^$third-party",
        ]

        let result = AffinityRulesGrouper.group(rules: [
            (.general, rules)
        ])

        // 2 rules without affinity + 3 affinity rules + 1 after closing = 6
        XCTAssertEqual(result[.general]?.count, 6)
        // 3 rules with affinity (general, privacy)
        XCTAssertEqual(result[.privacy]?.count, 3)
        // No rules for other types
        XCTAssertEqual(result[.socialWidgetsAndAnnoyances]?.count, 0)
        XCTAssertEqual(result[.other]?.count, 0)
        XCTAssertEqual(result[.custom]?.count, 0)
        XCTAssertEqual(result[.security]?.count, 0)
    }

    func testGroupWithAllKeyword() {
        let rules = [
            "||cdn.allsportsflix.best^$third-party",
            "!#safari_cb_affinity(all)",
            "@@||imasdk.googleapis.com/js/sdkloader/ima3.js",
            "!#safari_cb_affinity",
            "||main-ti-hub.com^",
        ]

        let result = AffinityRulesGrouper.group(rules: [
            (.custom, rules)
        ])

        // custom gets: 2 default rules + 1 all-rules affinity = 3
        XCTAssertEqual(result[.custom]?.count, 3, "Type custom should have 3 rules")
        // Other types get only the affinity rule
        for type in ContentBlockerType.allCases where type != .custom {
            XCTAssertEqual(result[type]?.count, 1, "Type \(type) should have 1 rule")
        }
    }

    func testGroupWithMultipleBatches() {
        let generalBatch = [
            "||ad1.com^",
            "!#safari_cb_affinity(privacy)",
            "@@||tracker.com/analytics.js",
            "!#safari_cb_affinity",
        ]

        let privacyBatch = [
            "||tracker.org^"
        ]

        let result = AffinityRulesGrouper.group(rules: [
            (.general, generalBatch),
            (.privacy, privacyBatch),
        ])

        // general: "||ad1.com^" (default) + tracker rule redirected
        XCTAssertEqual(result[.general]?.count, 1)
        // privacy: "||tracker.org^" (default) + affinity redirect
        XCTAssertEqual(result[.privacy]?.count, 2)
    }

    func testGroupWithNestedAffinityBlocks() {
        // Nested affinity blocks are not supported — closing resets to default
        let rules = [
            "||default.com^",
            "!#safari_cb_affinity(general)",
            "||affinity-general.com^",
            "!#safari_cb_affinity(privacy)",
            "||affinity-privacy.com^",
            "!#safari_cb_affinity",
            "||after-first-close.com^",
            "!#safari_cb_affinity",
            "||default2.com^",
        ]

        let result = AffinityRulesGrouper.group(rules: [
            (.security, rules)
        ])

        // security (default): default.com^ + after-first-close.com^ + default2.com^
        XCTAssertEqual(result[.security]?.count, 3)
        // general: affinity-general.com^
        XCTAssertEqual(result[.general]?.count, 1)
    }

    func testGroupSkipsCommentsAndFirstLine() {
        let rules = [
            "[Adblock Plus 2.0]",
            "! This is a comment",
            "||real-rule.com^",
        ]

        let result = AffinityRulesGrouper.group(rules: [
            (.general, rules)
        ])

        XCTAssertEqual(result[.general]?.count, 1)
        XCTAssertTrue(result[.general]?.first?.contains("real-rule") ?? false)
    }

    func testGroupWithEmptyAffinityDirective() {
        let rules = [
            "||default1.com^",
            "!#safari_cb_affinity()",
            "||should-be-default.com^",
            "!#safari_cb_affinity",
            "||default2.com^",
        ]

        let result = AffinityRulesGrouper.group(rules: [
            (.general, rules)
        ])

        // Empty affinity () means nil — rules stay in default
        XCTAssertEqual(result[.general]?.count, 3)
    }

    func testGroupWithUnknownAffinityKeyword() {
        let rules = [
            "||default.com^",
            "!#safari_cb_affinity(unknown,general)",
            "||affinity-rule.com^",
            "!#safari_cb_affinity",
        ]

        let result = AffinityRulesGrouper.group(rules: [
            (.privacy, rules)
        ])

        // "general" is recognized, so the rule goes there
        XCTAssertEqual(result[.general]?.count, 1)
        // default rule stays in privacy
        XCTAssertEqual(result[.privacy]?.count, 1)
    }

    func testGroupWithEmptyInput() {
        let result = AffinityRulesGrouper.group(rules: [])

        for type in ContentBlockerType.allCases {
            XCTAssertEqual(result[type]?.count, 0)
        }
    }

    // MARK: - rule(_:withAffinity:)

    func testRuleWithAffinity() {
        let rule = "@@||imasdk.googleapis.com"
        let result = AffinityRulesGrouper.rule(
            rule,
            withAffinity: [.security, .general, .custom]
        )

        let expected = """
            !#safari_cb_affinity(general,custom,security)
            @@||imasdk.googleapis.com
            !#safari_cb_affinity
            """

        XCTAssertEqual(result, expected)
    }

    func testRuleWithEmptyAffinity() {
        let rule = "@@||imasdk.googleapis.com"
        let result = AffinityRulesGrouper.rule(rule, withAffinity: [])

        let expected = """
            !#safari_cb_affinity(all)
            @@||imasdk.googleapis.com
            !#safari_cb_affinity
            """

        XCTAssertEqual(result, expected)
    }

    func testRuleWithNilAffinity() {
        let rule = "@@||imasdk.googleapis.com"
        let result = AffinityRulesGrouper.rule(rule, withAffinity: nil)

        XCTAssertEqual(result, rule)
    }

    func testRuleWithEmptyRuleAndAffinity() {
        let rule = "  "
        let result = AffinityRulesGrouper.rule(rule, withAffinity: [.general])

        XCTAssertEqual(result, rule)
    }

    // MARK: - Performance

    func testGroupPerformance10kRules() {
        // Generate 10,000 rules with mixed affinity directives
        var rules: [String] = []
        for i in 0..<10_000 {
            // Every 100th rule starts an affinity block
            if i % 100 == 0 {
                rules.append("!#safari_cb_affinity(general,privacy)")
            }
            // Every 50th rule closes an affinity block
            if i % 50 == 49 {
                rules.append("!#safari_cb_affinity")
            }
            // Regular rule
            rules.append("||example\(i).com^$third-party")
        }

        // Measure grouping performance
        measure {
            _ = AffinityRulesGrouper.group(rules: [(.general, rules)])
        }
    }
}
