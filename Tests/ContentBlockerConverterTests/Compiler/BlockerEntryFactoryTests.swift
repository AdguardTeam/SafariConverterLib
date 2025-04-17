import Foundation
import XCTest

@testable import ContentBlockerConverter

final class BlockerEntryFactoryTests: XCTestCase {
    func testBlockerEntryFactory() throws {
        struct TestCase {
            let ruleText: String
            var version: SafariVersion = DEFAULT_SAFARI_VERSION
            var expectedEntry: BlockerEntry?
            var expectedErrorsCount = 0
        }

        let testCases: [TestCase] = [
            TestCase(
                // Normal rule with domain modifier.
                ruleText: "||example.com/path$domain=test.com",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        ifDomain: ["*test.com"],
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.com\\/path"
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // Regular expression rule.
                ruleText: "/regex/$script,css",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "regex",
                        resourceType: ["style-sheet", "script"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // Rule matching path.
                ruleText: "/addyn|*|adtech",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: #"\/addyn\|.*\|adtech"#
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // $match-case rule.
                ruleText: "||example.org^$match-case",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        caseSensitive: true
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // $third-party rule.
                ruleText: "||example.org^$third-party",
                version: SafariVersion.safari16_4,
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        loadType: ["third-party"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // $third-party rule for older Safari versions.
                ruleText: "||example.org^$third-party",
                version: SafariVersion.safari13,
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        unlessDomain: ["*example.org"],
                        loadType: ["third-party"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // $first-party rule.
                ruleText: "||example.org^$~third-party",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        loadType: ["first-party"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // $all rule.
                ruleText: "||example.org^$all",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$"
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // $image rule.
                ruleText: "||example.org^$image",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        resourceType: ["image"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // $image rule.
                ruleText: "||example.org^$image,font",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        resourceType: ["image", "font"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // $~image rule.
                ruleText: "||example.org^$image,font,~font",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        resourceType: ["image"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // $~image rule.
                ruleText: "||example.org^$~image",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        resourceType: ["style-sheet", "script", "media", "raw", "font", "document"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // $xmlhttprequest rule in older Safari versions maps to "raw".
                ruleText: "||example.org^$xmlhttprequest",
                version: SafariVersion.safari14,
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        resourceType: ["raw"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // $xmlhttprequest rule in new Safari versions maps to "fetch".
                ruleText: "||example.org^$xmlhttprequest",
                version: SafariVersion.safari15,
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        resourceType: ["fetch"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // $other rule in older Safari versions maps to "raw".
                ruleText: "||example.org^$other",
                version: SafariVersion.safari14,
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        resourceType: ["raw"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // $other rule in new Safari versions maps to "other".
                ruleText: "||example.org^$other",
                version: SafariVersion.safari15,
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        resourceType: ["other"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // $websocket rule in older Safari versions maps to "raw".
                ruleText: "||example.org^$websocket",
                version: SafariVersion.safari14,
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        resourceType: ["raw"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // $websocket rule in older Safari versions maps to "websocket".
                ruleText: "||example.org^$websocket",
                version: SafariVersion.safari15,
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        resourceType: ["websocket"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // $ping rule supported starting with Safari 14.
                ruleText: "||example.org^$ping",
                version: SafariVersion.safari14,
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        resourceType: ["ping"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // Blocklist $document rule.
                ruleText: "||example.org^$document",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        resourceType: ["document"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // Blocklist $popup rule.
                ruleText: "||example.org^$popup",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        resourceType: ["document"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // Simple whitelist rule.
                ruleText: "@@||example.com^",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.com([\\/:&\\?].*)?$"
                    ),
                    action: BlockerEntry.Action(
                        type: "ignore-previous-rules"
                    )
                )
            ),
            TestCase(
                // Element hiding rule.
                ruleText: "example.org##.banner",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        ifDomain: ["*example.org"],
                        urlFilter: ".*"
                    ),
                    action: BlockerEntry.Action(
                        type: "css-display-none",
                        selector: ".banner"
                    )
                )
            ),
            TestCase(
                // Whitelist element hiding rule.
                ruleText: "example.org#@#.banner",
                expectedEntry: nil,
                expectedErrorsCount: 1
            ),
            TestCase(
                // Whitelist $document rule.
                ruleText: "@@||example.com^$document",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        ifDomain: ["*example.com"],
                        urlFilter: ".*"
                    ),
                    action: BlockerEntry.Action(
                        type: "ignore-previous-rules"
                    )
                )
            ),
            TestCase(
                // Whitelist $elemhide rule.
                ruleText: "@@||example.com^$elemhide",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        ifDomain: ["*example.com"],
                        urlFilter: ".*"
                    ),
                    action: BlockerEntry.Action(
                        type: "ignore-previous-rules"
                    )
                )
            ),
            TestCase(
                // Whitelist $jsinject rule.
                ruleText: "@@||example.com^$jsinject",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        ifDomain: ["*example.com"],
                        urlFilter: ".*"
                    ),
                    action: BlockerEntry.Action(
                        type: "ignore-previous-rules"
                    )
                )
            ),
            TestCase(
                // Whitelist $urlblock rule.
                ruleText: "@@||example.com^$urlblock",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        ifDomain: ["*example.com"],
                        urlFilter: ".*"
                    ),
                    action: BlockerEntry.Action(
                        type: "ignore-previous-rules"
                    )
                )
            ),
            TestCase(
                // Domain cannot be extracted so relying just on url-filter.
                ruleText: "@@test.com/path^$document",
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "test\\.com\\/path([\\/:&\\?].*)?$"
                    ),
                    action: BlockerEntry.Action(
                        type: "ignore-previous-rules"
                    )
                )
            ),
            TestCase(
                // Converting simple script rule.
                ruleText: "example.org,example.com#%#test",
                expectedEntry: nil,
                expectedErrorsCount: 1
            ),
            TestCase(
                // Whitelist script rule.
                ruleText: "example.org,example.com#@%#test",
                expectedEntry: nil,
                expectedErrorsCount: 1
            ),
            TestCase(
                // Scriptlet rule.
                ruleText: "~example.org#%#//scriptlet(\"test-name\")",
                expectedEntry: nil,
                expectedErrorsCount: 1
            ),
            TestCase(
                // Scriptlet with parameters rule.
                ruleText:
                    "~example.org,~example.com#%#//scriptlet('test scriptlet', 'test scriptlet param')",
                expectedEntry: nil,
                expectedErrorsCount: 1
            ),
            TestCase(
                // Whitelist scriptlet with parameters rule.
                ruleText:
                    "~example.org,~example.com#@%#//scriptlet('test scriptlet', 'test scriptlet param')",
                expectedEntry: nil,
                expectedErrorsCount: 1
            ),
            TestCase(
                // Extended CSS element hiding rule.
                ruleText: "example.com#?#.banner",
                expectedEntry: nil,
                expectedErrorsCount: 1
            ),
            TestCase(
                // CSS injection rule.
                ruleText: "example.com#$#.banner { display: none; }",
                expectedEntry: nil,
                expectedErrorsCount: 1
            ),
            TestCase(
                // Extended CSS injection rule.
                ruleText: "example.com#$?#.banner { display: none; }",
                expectedEntry: nil,
                expectedErrorsCount: 1
            ),
            TestCase(
                // Unsupported regular expression.
                ruleText: "/regex{0,9}/",
                expectedEntry: nil,
                expectedErrorsCount: 1
            ),
            TestCase(
                // Unsupported regular expression.
                ruleText: "/regex|test/",
                expectedEntry: nil,
                expectedErrorsCount: 1
            ),
            TestCase(
                // Unsupported regular expression.
                ruleText: "/test(?!test)/",
                expectedEntry: nil,
                expectedErrorsCount: 1
            ),
            TestCase(
                // Unsupported regular expression.
                ruleText: "/test\\b/",
                expectedEntry: nil,
                expectedErrorsCount: 1
            ),
            TestCase(
                // $subdocument without $third-party on a newer Safari.
                ruleText: "||example.org^$subdocument,~third-party",
                version: SafariVersion.safari16_4,
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        loadType: ["first-party"],
                        loadContext: ["child-frame"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // ~$subdocument on a newer Safari.
                ruleText: "||example.org^$~subdocument",
                version: SafariVersion.safari16_4,
                expectedEntry: BlockerEntry(
                    trigger: BlockerEntry.Trigger(
                        urlFilter: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                        resourceType: [
                            "image",
                            "style-sheet",
                            "script",
                            "media",
                            "fetch",
                            "other",
                            "websocket",
                            "font",
                            "ping",
                            "document",
                        ],
                        loadContext: ["top-frame"]
                    ),
                    action: BlockerEntry.Action(
                        type: "block"
                    )
                )
            ),
            TestCase(
                // Mixed if-domain and unless-domain is not supporteed.
                ruleText: "||example.org^$domain=example.org|~example.com",
                expectedEntry: nil,
                expectedErrorsCount: 1
            ),
            TestCase(
                // Mixed if-domain and unless-domain is not supporteed.
                ruleText: "example.org,~example.com##.banner",
                expectedEntry: nil,
                expectedErrorsCount: 1
            ),
        ]

        for testCase in testCases {
            let errorsCounter = ErrorsCounter()
            let converter = BlockerEntryFactory(
                errorsCounter: errorsCounter,
                version: testCase.version
            )

            let rule = try! RuleFactory.createRule(
                ruleText: testCase.ruleText,
                for: testCase.version
            )
            let result = converter.createBlockerEntry(rule: rule!)

            XCTAssertEqual(
                result,
                testCase.expectedEntry,
                "Rule \(testCase.ruleText) conversion result didn't match"
            )
            XCTAssertEqual(
                errorsCounter.getCount(),
                testCase.expectedErrorsCount,
                "Rule \(testCase.ruleText) conversion errors count didn't match"
            )
        }
    }

    func testTldDomains() throws {
        let converter = BlockerEntryFactory(
            errorsCounter: ErrorsCounter(),
            version: DEFAULT_SAFARI_VERSION
        )
        let rule = try CosmeticRule(ruleText: "example.*##.banner")

        let result = converter.createBlockerEntry(rule: rule)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.trigger.ifDomain!.count >= 100)
        XCTAssertTrue(result!.trigger.ifDomain!.contains("*example.com"))
        XCTAssertTrue(result!.trigger.ifDomain!.contains("*example.com.tr"))
    }
}
