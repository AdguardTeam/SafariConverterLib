import ContentBlockerConverter
import Foundation
import XCTest

@testable import FilterEngine

final class FilterEngineTests: XCTestCase {

    // MARK: - Tests setup

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

    // MARK: - Test helpers

    /// Helper struct that combines all the information for testing.
    struct TestCase {
        let name: String
        let rules: [String]
        let urlString: String
        var subdocument: Bool?
        var thirdParty: Bool?
        let expectedCosmeticContent: [String]
    }

    /// Runs an individual test case.
    func runTest(_ testCase: TestCase) {
        // Fill storage with the rules
        guard
            let storage = try? FilterRuleStorage(
                from: testCase.rules,
                for: .safari16_4,
                fileURL: tempFileURL
            )
        else {
            XCTAssertTrue(false, "Failed to initialize storage for \(testCase.name)")

            return
        }

        // Init the engine
        guard let engine = try? FilterEngine(storage: storage) else {
            XCTAssertTrue(false, "Failed to initialize engine for \(testCase.name)")

            return
        }

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

    /// Runs a list of test cases.
    func runTests(_ testCases: [TestCase]) {
        for testCase in testCases {
            runTest(testCase)
        }
    }

    // MARK: - Tests

    func testFindAll_EdgeCases() {
        let testCases: [TestCase] = [
            // Empty rules list.
            TestCase(
                name: "empty",
                rules: [],
                urlString: "https://example.org/",
                expectedCosmeticContent: []
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

        runTests(testCases)
    }

    func testFindAll_SimpleCosmeticRules() {
        let testCases: [TestCase] = [
            TestCase(
                name: "single cosmetic rule",
                rules: [
                    "example.org##.banner"
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: [".banner"]
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
                name: "specific rule applies to subdomain",
                rules: [
                    "example.org##.banner"
                ],
                urlString: "https://sub.example.org/",
                expectedCosmeticContent: [".banner"]
            ),
        ]

        runTests(testCases)
    }

    func testFindAll_PathModifier() {
        let testCases: [TestCase] = [
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
        ]

        runTests(testCases)
    }

    func testFindAll_PathModifierWithQuery() {
        let testCases: [TestCase] = [
            TestCase(
                name: "path modifier matches query",
                rules: [
                    "[$path=/p=1/]example.org##.banner"
                ],
                urlString: "https://example.org/?p=1",
                expectedCosmeticContent: [".banner"]
            ),
            TestCase(
                name: "path modifier does not match different query",
                rules: [
                    "[$path=/p=1/]example.org##.banner"
                ],
                urlString: "https://example.org/?p=2",
                expectedCosmeticContent: []
            ),
        ]

        runTests(testCases)
    }

    func testFindAll_ElemhideRules() {
        let testCases: [TestCase] = [
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
        ]

        runTests(testCases)
    }

    func testFindAll_GenericHideRules() {
        let testCases: [TestCase] = [
            TestCase(
                name: "disable generic css",
                rules: [
                    "@@||example.org^$generichide",
                    "example.org##.banner",
                    "###banner",
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: [".banner"]
            )
        ]

        runTests(testCases)
    }

    func testFindAll_SpecifichideRules() {
        let testCases: [TestCase] = [
            TestCase(
                name: "disable specific css",
                rules: [
                    "@@||example.org^$specifichide",
                    "example.org##.banner",
                    "###banner",
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: ["#banner"]
            )
        ]

        runTests(testCases)
    }

    func testFindAll_GenericAndSpecificHideCombined() {
        let testCases: [TestCase] = [
            TestCase(
                name: "$generichide + $specifichide disables all css",
                rules: [
                    "@@||example.org^$generichide,specifichide",
                    "##.banner",
                    "example.org##.banner",
                    "###banner",
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: []
            )
        ]

        runTests(testCases)
    }

    func testFindAll_DocumentDisablesCssAndScripts() {
        let testCases: [TestCase] = [
            TestCase(
                name: "$document disables both css and js",
                rules: [
                    "@@||example.org^$document",
                    "example.org##.banner",
                    "example.org#%#console.log('1')",
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: []
            )
        ]

        runTests(testCases)
    }

    func testFindAll_NegateCosmeticRules() {
        let testCases: [TestCase] = [
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
                name: "negate css rule on a subdomain",
                rules: [
                    "##.banner",
                    "sub.example.org#@#.banner",
                    "###banner",
                ],
                urlString: "https://sub.example.org/",
                expectedCosmeticContent: ["#banner"]
            ),
        ]

        runTests(testCases)
    }

    func testFindAll_ScriptRules() {
        let testCases: [TestCase] = [
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
        ]

        runTests(testCases)
    }

    func testFindAll_RulesPriority() {
        let testCases: [TestCase] = [
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
        ]

        runTests(testCases)
    }

    func testFindAll_WildcardTldCosmeticRules() throws {
        let testCases: [TestCase] = [
            TestCase(
                name: "wildcard tld base domain .com",
                rules: [
                    "example.*##.banner"
                ],
                urlString: "https://example.com/",
                expectedCosmeticContent: [".banner"]
            ),
            TestCase(
                name: "wildcard tld base domain multi-psl",
                rules: [
                    "example.*##.banner"
                ],
                urlString: "https://example.co.uk/",
                expectedCosmeticContent: [".banner"]
            ),
            TestCase(
                name: "wildcard tld subdomain",
                rules: [
                    "example.*##.banner"
                ],
                urlString: "https://sub.example.com/",
                expectedCosmeticContent: [".banner"]
            ),
            TestCase(
                name: "wildcard tld negative different base",
                rules: [
                    "example.*##.banner"
                ],
                urlString: "https://notexample.com/",
                expectedCosmeticContent: []
            ),
            TestCase(
                name: "wildcard tld negative suffix-like but different etld1",
                rules: [
                    "example.*##.banner"
                ],
                urlString: "https://example.evil.com/",
                expectedCosmeticContent: []
            ),
        ]

        runTests(testCases)
    }

    func testFindAll_WildcardTldScriptletRules() throws {
        let testCases: [TestCase] = [
            TestCase(
                name: "wildcard tld base domain .com",
                rules: [
                    "example.*#%#//scriptlet('set-constant', 'test', '1')"
                ],
                urlString: "https://example.com/",
                expectedCosmeticContent: [
                    "//scriptlet('set-constant', 'test', '1')"
                ]
            ),
            TestCase(
                name: "wildcard tld base domain multi-psl",
                rules: [
                    "example.*#%#//scriptlet('set-constant', 'test', '1')"
                ],
                urlString: "https://example.co.uk/",
                expectedCosmeticContent: [
                    "//scriptlet('set-constant', 'test', '1')"
                ]
            ),
            TestCase(
                name: "wildcard tld subdomain",
                rules: [
                    "example.*#%#//scriptlet('set-constant', 'test', '1')"
                ],
                urlString: "https://sub.example.com/",
                expectedCosmeticContent: [
                    "//scriptlet('set-constant', 'test', '1')"
                ]
            ),
            TestCase(
                name: "wildcard tld negative different base",
                rules: [
                    "example.*#%#//scriptlet('set-constant', 'test', '1')"
                ],
                urlString: "https://notexample.com/",
                expectedCosmeticContent: []
            ),
            TestCase(
                name: "wildcard tld negative suffix-like but different etld1",
                rules: [
                    "example.*#%#//scriptlet('set-constant', 'test', '1')"
                ],
                urlString: "https://example.evil.com/",
                expectedCosmeticContent: []
            ),
        ]

        runTests(testCases)
    }

    func testFindAll_WildcardTldScriptRules() throws {
        let testCases: [TestCase] = [
            TestCase(
                name: "wildcard tld base domain .com",
                rules: [
                    "example.*#%#console.log('1')"
                ],
                urlString: "https://example.com/",
                expectedCosmeticContent: [
                    "console.log('1')"
                ]
            ),
            TestCase(
                name: "wildcard tld base domain multi-psl",
                rules: [
                    "example.*#%#console.log('1')"
                ],
                urlString: "https://example.co.uk/",
                expectedCosmeticContent: [
                    "console.log('1')"
                ]
            ),
            TestCase(
                name: "wildcard tld subdomain",
                rules: [
                    "example.*#%#console.log('1')"
                ],
                urlString: "https://sub.example.com/",
                expectedCosmeticContent: [
                    "console.log('1')"
                ]
            ),
            TestCase(
                name: "wildcard tld negative different base",
                rules: [
                    "example.*#%#console.log('1')"
                ],
                urlString: "https://notexample.com/",
                expectedCosmeticContent: []
            ),
            TestCase(
                name: "wildcard tld negative suffix-like but different etld1",
                rules: [
                    "example.*#%#console.log('1')"
                ],
                urlString: "https://example.evil.com/",
                expectedCosmeticContent: []
            ),
        ]

        runTests(testCases)
    }

    func testFindAll_NoHostSchemesAreIgnored() {
        let testCases: [TestCase] = [
            TestCase(
                name: "about:blank has no host",
                rules: [
                    "###banner",
                    "##.banner",
                    "example.org##.banner",
                ],
                urlString: "about:blank",
                expectedCosmeticContent: []
            ),
            TestCase(
                name: "file scheme has no host",
                rules: [
                    "###banner",
                    "##.banner",
                    "example.org##.banner",
                ],
                urlString: "file:///Users/test/index.html",
                expectedCosmeticContent: []
            ),
        ]

        runTests(testCases)
    }

    func testFindAll_InvalidPathRegexIgnored() {
        let testCases: [TestCase] = [
            TestCase(
                name: "invalid path regex is ignored and cached",
                rules: [
                    "[$path=/[z-a]/]example.org##.hidden1",
                    "[$path=/[z-a]/]example.org##.hidden2",
                    "###banner",
                ],
                urlString: "https://example.org/",
                expectedCosmeticContent: ["#banner"]
            )
        ]

        runTests(testCases)
    }

    // MARK: - Performance tests

    /// Benchmark test for the `findAll` method
    ///
    /// Baseline results (Aug 8, 2025):
    /// - Machine: MacBook Pro M4 Max, 48GB RAM
    /// - OS: macOS 26
    /// - Swift: 6.2
    /// - Average execution time: ~0.175 sec
    ///
    /// To get your machine info: `system_profiler SPHardwareDataType`
    /// To get your macOS version: `sw_vers`
    /// To get your Swift version: `swift --version`
    func testPerformanceFindAll() throws {
        // Load advanced rules from the resource file
        let thisSourceFile = URL(fileURLWithPath: #file)
        let thisDirectory = thisSourceFile.deletingLastPathComponent()
        let resourceURL = thisDirectory.appendingPathComponent("Resources/advanced-rules.txt")
        let rulesContent = try String(contentsOf: resourceURL)
        let rules = rulesContent.components(separatedBy: .newlines).filter { !$0.isEmpty }

        // Create a storage with the rules
        let storage = try FilterRuleStorage(
            from: rules,
            for: .safari16_4,
            fileURL: tempFileURL
        )

        // Initialize the engine
        let engine = try FilterEngine(storage: storage)

        // Generate a list of random URLs for testing
        let domains = [
            "example.org", "example.com", "youtube.com", "google.com",
            "facebook.com", "twitter.com", "reddit.com", "amazon.com",
            "wikipedia.org", "github.com", "netflix.com", "apple.com",
            "microsoft.com", "linkedin.com", "instagram.com", "foxtel.com.au",
            "imdb.com", "adguard.com", "mail.yandex.ru", "7plus.com.au",
        ]

        let paths = [
            "/", "/index.html", "/about", "/contact", "/products",
            "/services", "/blog", "/news", "/gallery", "/faq",
            "/terms", "/privacy", "/login", "/register", "/profile",
            "/settings", "/search", "/video", "/audio", "/download",
        ]

        var testURLs: [URL] = []
        for domain in domains {
            for path in paths {
                if let url = URL(string: "https://\(domain)\(path)") {
                    testURLs.append(url)
                }
            }
        }

        // Measure performance
        measure {
            for url in testURLs {
                // Test with different combinations of subdocument and thirdParty parameters
                let requests = [
                    Request(url: url, subdocument: false, thirdParty: false),
                    Request(url: url, subdocument: true, thirdParty: false),
                    Request(url: url, subdocument: false, thirdParty: true),
                    Request(url: url, subdocument: true, thirdParty: true),
                ]

                for request in requests {
                    let _ = engine.findAll(for: request)
                }
            }
        }
    }
}
