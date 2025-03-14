import ContentBlockerConverter
import Foundation
import XCTest

@testable import FilterEngine

final class FilterEngineTests: XCTestCase {
    private var tempDirectory: URL!
    private var tempFileURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        tempFileURL = tempDirectory.appendingPathComponent("filterRules.bin")
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    func testFindAll() throws {
        struct TestCase {
            let name: String
            let rules: [String]
            let urlString: String
            var subdocument: Bool?
            var thirdParty: Bool?
            let expectedCosmeticContent: [String]
        }

        let testCases: [TestCase] = [
            // Empty rules list.
            TestCase(
                name: "empty",
                rules: [],
                urlString: "https://example.org/",
                expectedCosmeticContent: []
            ),
            TestCase(
                name: "single cosmetic rule",
                rules: [
                    "example.org##.banner"
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: [".banner"]
            ),
            TestCase(
                name: "path modifier not matching",
                rules: [
                    "[$path=/test]example.org##.banner"
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: []
            ),
            TestCase(
                name: "path modifier matching",
                rules: [
                    "[$path=/test]example.org##.banner"
                ],
                urlString: "https://example.org/test",
                expectedCosmeticContent: [".banner"]
            ),
            TestCase(
                name: "path modifier match root",
                rules: [
                    "[$path=/^\\/$/]example.org##.banner"
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: [".banner"]
            ),
            TestCase(
                name: "path modifier match root url with path",
                rules: [
                    "[$path=/^\\/$/]example.org##.banner"
                ],
                urlString: "https://example.org/path",
                expectedCosmeticContent: []
            ),
            TestCase(
                name: "many cosmetic rules",
                rules: [
                    "###banner",
                    "#$##banner { display: hidden; }",
                    "example.org##.banner",
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: [
                    ".banner",
                    "#banner",
                    "#banner { display: hidden; }",
                ]
            ),
            TestCase(
                name: "many cosmetic rules for the same domain",
                rules: [
                    "example.org###banner",
                    "example.org#$##banner { display: hidden; }",
                    "example.org##.banner",
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: [
                    "#banner",
                    "#banner { display: hidden; }",
                    ".banner",
                ]
            ),
            TestCase(
                name: "disable css",
                rules: [
                    "@@||example.org^$elemhide",
                    "example.org##.banner",
                    "###banner",
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: []
            ),
            TestCase(
                name: "disabled only for subdocument (not for document)",
                rules: [
                    "@@||example.org^$elemhide,subdocument",
                    "example.org##.banner",
                    "###banner",
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: [".banner", "#banner"]
            ),
            TestCase(
                name: "disabled css for subdocument",
                rules: [
                    "@@||example.org^$elemhide,subdocument",
                    "example.org##.banner",
                    "###banner",
                ],
                urlString: "https://example.org/",
                subdocument: true,
                expectedCosmeticContent: []
            ),
            TestCase(
                name: "disabled css for third-party subdocuments (not for first-party req)",
                rules: [
                    "@@||example.org^$elemhide,subdocument,third-party",
                    "example.org##.banner",
                    "###banner",
                ],
                urlString: "https://example.org/",
                subdocument: true,
                expectedCosmeticContent: [".banner", "#banner"]
            ),
            TestCase(
                name: "disabled css for third-party subdocuments",
                rules: [
                    "@@||example.org^$elemhide,subdocument,third-party",
                    "example.org##.banner",
                    "###banner",
                ],
                urlString: "https://example.org/",
                subdocument: true,
                thirdParty: true,
                expectedCosmeticContent: []
            ),
            TestCase(
                name: "disable css on url",
                rules: [
                    "@@||example.org/path$elemhide",
                    "example.org##.banner",
                    "###banner",
                ],
                urlString: "https://example.org/path",
                expectedCosmeticContent: []
            ),
            TestCase(
                name: "disable css on another domain",
                rules: [
                    "@@||example.net^$elemhide",
                    "example.org##.banner",
                    "###banner",
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: [".banner", "#banner"]
            ),
            TestCase(
                name: "disable generic css",
                rules: [
                    "@@||example.org^$generichide",
                    "example.org##.banner",
                    "###banner",
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: [".banner"]
            ),
            TestCase(
                name: "disable specific css",
                rules: [
                    "@@||example.org^$specifichide",
                    "example.org##.banner",
                    "###banner",
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: ["#banner"]
            ),
            TestCase(
                name: "negate css rule",
                rules: [
                    "##.banner",
                    "example.org#@#.banner",
                    "###banner",
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: ["#banner"]
            ),
            TestCase(
                name: "single script inject rule",
                rules: [
                    "#%#console.log('1')"
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: ["console.log('1')"]
            ),
            TestCase(
                name: "many script rules",
                rules: [
                    "#%#console.log('1')",
                    "example.org#%#//scriptlet('set-constant', 'test', '1')",
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: [
                    "//scriptlet('set-constant', 'test', '1')",
                    "console.log('1')",
                ]
            ),
            TestCase(
                name: "disable script rules",
                rules: [
                    "@@||example.org^$jsinject",
                    "#%#console.log('1')",
                    "example.org#%#//scriptlet('set-constant', 'test', '1')",
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: []
            ),
            TestCase(
                // The current algorithm is that the last rule found will
                // be preferred. It's not critical and can be changed,
                // but having this test here is still useful.
                name: "test network rules priority",
                rules: [
                    "@@||example.org^$elemhide",
                    "@@||example.org^$jsinject",
                    "example.org##.banner",
                    "example.org#%#//scriptlet('set-constant', 'test', '1')",
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: [
                    ".banner"
                ]
            ),
            TestCase(
                // Make sure that $important rule overrides the others
                name: "test network rules priority",
                rules: [
                    "@@||example.org^$elemhide,important",
                    "@@||example.org^$jsinject",
                    "example.org##.banner",
                    "example.org#%#//scriptlet('set-constant', 'test', '1')",
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: [
                    "//scriptlet('set-constant', 'test', '1')"
                ]
            ),
            TestCase(
                // Make sure that invalid regex is simply ignored.
                // Second rule is required to cover the invalid regexes cache.
                name: "test invalid regex",
                rules: [
                    "@@/[z-a]/$elemhide,important",
                    "@@/[z-a]/$document",
                    "example.org##.banner",
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: [
                    ".banner"
                ]
            ),
        ]

        for testCase in testCases {
            // Fill storage with the rules
            let storage = try FilterRuleStorage(
                from: testCase.rules,
                for: .safari16_4,
                fileURL: tempFileURL
            )

            // Init the engine
            let engine = try FilterEngine(storage: storage)

            // Check that rules are found for example.org
            let url = URL(string: testCase.urlString)!
            let request = Request(
                url: url,
                subdocument: testCase.subdocument ?? false,
                thirdParty: testCase.thirdParty ?? false
            )
            let rules = engine.findAll(for: request)

            XCTAssertEqual(
                rules.map(\.cosmeticContent),
                testCase.expectedCosmeticContent,
                "Failed \(testCase.name)"
            )
        }
    }
}
