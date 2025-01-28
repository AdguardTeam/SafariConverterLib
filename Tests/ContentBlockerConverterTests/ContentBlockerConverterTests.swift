import XCTest

@testable import ContentBlockerConverter


final class ContentBlockerConverterTests: XCTestCase {
    private let START_URL_UNESCAPED = "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?"
    private let URL_FILTER_WS_ANY_URL_UNESCAPED = "^wss?:\\/\\/"
    private let URL_FILTER_REGEXP_END_SEPARATOR = "([\\/:&\\?].*)?$"
    private let URL_FILTER_CSS_RULES = ".*"
    // TODO(ameshkov): !!! Remove
    private let URL_FILTER_URL_RULES_EXCEPTIONS = ".*"

    let converter = ContentBlockerConverter();

    func parseJsonString(json: String) throws -> [BlockerEntry] {
        let data = json.data(using: String.Encoding.utf8)!

        let decoder = JSONDecoder()
        let parsedData = try decoder.decode([BlockerEntry].self, from: data)

        return parsedData
    }

    private func checkEntriesByCondition(entries: [BlockerEntry], condition: (BlockerEntry) -> Bool) -> Bool {
        entries.contains {
            condition($0)
        }
    }

    /// Helper function that checks if the specified json matches the expected one.
    private func assertContentBlockerJSON(_ json: String, _ expected: String, _ msg: String) {
        if expected == "" && json == "" {
            XCTAssertEqual(json, expected)
        }

        let expectedRules = try! parseJsonString(json: expected)
        let actualRules = try! parseJsonString(json: json)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted,.sortedKeys]

        let expectedRulesJSON = String(data: try! encoder.encode(expectedRules), encoding: .utf8)!
        let actualRulesJSON = String(data: try! encoder.encode(actualRules), encoding: .utf8)!

        XCTAssertEqual(expectedRulesJSON, actualRulesJSON, msg)
    }

    // TODO: [ameshkov]: Most of the tests here should be replaced with testConverterBasicRules.
    func testConverterBasicRules() {
        struct TestCase {
            let rules: [String]
            let expectedSafariRulesJSON: String
            var expectedAdvancedRulesText: String? = nil
            var version: SafariVersion = DEFAULT_SAFARI_VERSION
            var expectedSourceRulesCount = 0
            var expectedSourceSafariCompatibleRulesCount = 0
            var expectedSafariRulesCount = 0
            var expectedAdvancedRulesCount = 0
            var expectedErrorsCount = 0
        }

        let testCases: [TestCase] = [
            TestCase(
                rules: [],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON
            ),
            TestCase(
                rules: [""],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON
            ),
            TestCase(
                rules: ["! just a comment"],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON
            ),
            TestCase(
                rules: [
                    "||example1.com$document",
                    "||example2.com$document,popup",
                    "||example5.com$popup,document"
                ],
                expectedSafariRulesJSON: #"""
                                   [
                                     {
                                       "action" : {
                                         "type" : "block"
                                       },
                                       "trigger" : {
                                         "resource-type" : [
                                           "document"
                                         ],
                                         "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example1\\.com"
                                       }
                                     },
                                     {
                                       "action" : {
                                         "type" : "block"
                                       },
                                       "trigger" : {
                                         "resource-type" : [
                                           "document"
                                         ],
                                         "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example2\\.com"
                                       }
                                     },
                                     {
                                       "action" : {
                                         "type" : "block"
                                       },
                                       "trigger" : {
                                         "resource-type" : [
                                           "document"
                                         ],
                                         "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example5\\.com"
                                       }
                                     }
                                   ]
                                   """#,
                expectedSourceRulesCount: 3,
                expectedSourceSafariCompatibleRulesCount: 3,
                expectedSafariRulesCount: 3
            ),
            TestCase(
                rules: ["||getsecuredfiles.com^$popup,third-party"],
                expectedSafariRulesJSON: #"""
                                    [
                                      {
                                        "action" : {
                                          "type" : "block"
                                        },
                                        "trigger" : {
                                          "load-type" : [
                                            "third-party"
                                          ],
                                          "resource-type" : [
                                            "document"
                                          ],
                                          "unless-domain" : [
                                            "*getsecuredfiles.com"
                                          ],
                                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?getsecuredfiles\\.com([\\\/:&\\?].*)?$"
                                        }
                                      }
                                    ]
                                    """#,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // Single invalid rule.
                rules: ["|127.0.0.1^$network"],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedErrorsCount: 1
            ),
            TestCase(
                rules: ["@@||adriver.ru^$~third-party"],
                expectedSafariRulesJSON: #"""
                                    [
                                      {
                                        "action" : {
                                          "type" : "ignore-previous-rules"
                                        },
                                        "trigger" : {
                                          "load-type" : [
                                            "first-party"
                                          ],
                                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?adriver\\.ru([\\\/:&\\?].*)?$"
                                        }
                                      }
                                    ]
                                    """#,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $websocket conversion for old Safari versions.
                rules: ["||test.com^$websocket"],
                expectedSafariRulesJSON: #"""
                                    [
                                      {
                                        "action" : {
                                          "type" : "block"
                                        },
                                        "trigger" : {
                                          "resource-type" : [
                                            "raw"
                                          ],
                                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?test\\.com([\\\/:&\\?].*)?$"
                                        }
                                      }
                                    ]
                                    """#,
                version: SafariVersion.safari13,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $websocket conversion for old Safari versions.
                rules: ["$websocket,domain=123movies.is"],
                expectedSafariRulesJSON: #"""
                                    [
                                      {
                                        "action" : {
                                          "type" : "block"
                                        },
                                        "trigger" : {
                                          "if-domain" : [
                                            "*123movies.is"
                                          ],
                                          "resource-type" : [
                                            "raw"
                                          ],
                                          "url-filter" : "^wss?:\\\/\\\/"
                                        }
                                      }
                                    ]
                                    """#,
                version: SafariVersion.safari13,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $websocket conversion for old Safari versions.
                rules: [".rocks^$third-party,websocket"],
                expectedSafariRulesJSON: #"""
                                    [
                                      {
                                        "action" : {
                                          "type" : "block"
                                        },
                                        "trigger" : {
                                          "load-type" : [
                                            "third-party"
                                          ],
                                          "resource-type" : [
                                            "raw"
                                          ],
                                          "url-filter" : "^wss?:\\\/\\\/.*\\.rocks([\\\/:&\\?].*)?$"
                                        }
                                      }
                                    ]
                                    """#,
                version: SafariVersion.safari13,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $websocket conversion for Safari 15+.
                rules: ["||test.com^$websocket"],
                expectedSafariRulesJSON: #"""
                                    [
                                      {
                                        "action" : {
                                          "type" : "block"
                                        },
                                        "trigger" : {
                                          "resource-type" : [
                                            "websocket"
                                          ],
                                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?test\\.com([\\\/:&\\?].*)?$"
                                        }
                                      }
                                    ]
                                    """#,
                version: SafariVersion.safari15,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $~websocket conversion for Safari 15+.
                rules: ["||test.com^$~websocket,domain=example.org"],
                expectedSafariRulesJSON: #"""
                                    [
                                      {
                                        "action" : {
                                          "type" : "block"
                                        },
                                        "trigger" : {
                                          "if-domain" : [
                                            "*example.org"
                                          ],
                                          "resource-type" : [
                                            "image",
                                            "style-sheet",
                                            "script",
                                            "media",
                                            "fetch",
                                            "other",
                                            "font",
                                            "ping",
                                            "document"
                                          ],
                                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?test\\.com([\\\/:&\\?].*)?$"
                                        }
                                      }
                                    ]
                                    """#,
                version: SafariVersion.safari15,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $~script conversion for older Safari versions.
                rules: ["||test.com^$~script,domain=example.com"],
                expectedSafariRulesJSON: #"""
                                    [
                                      {
                                        "action" : {
                                          "type" : "block"
                                        },
                                        "trigger" : {
                                          "if-domain" : [
                                            "*example.com"
                                          ],
                                          "resource-type" : [
                                            "image",
                                            "style-sheet",
                                            "media",
                                            "raw",
                                            "font",
                                            "document"
                                          ],
                                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?test\\.com([\\\/:&\\?].*)?$"
                                        }
                                      }
                                    ]
                                    """#,
                version: SafariVersion.safari13,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $~script conversion for newer Safari versions.
                rules: ["||test.com^$~script,domain=example.com"],
                expectedSafariRulesJSON: #"""
                                    [
                                      {
                                        "action" : {
                                          "type" : "block"
                                        },
                                        "trigger" : {
                                          "if-domain" : [
                                            "*example.com"
                                          ],
                                          "resource-type" : [
                                            "image",
                                            "style-sheet",
                                            "media",
                                            "fetch",
                                            "other",
                                            "websocket",
                                            "font",
                                            "ping",
                                            "document"
                                          ],
                                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?test\\.com([\\\/:&\\?].*)?$"
                                        }
                                      }
                                    ]
                                    """#,
                version: SafariVersion.safari16_4,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $subdocument without $third-party forbidden for old Safari versions.
                rules: ["||test.com^$subdocument,~third-party"],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedErrorsCount: 1
            ),
            TestCase(
                // $subdocument with $domain is allowed for old Safari versions.
                rules: ["||test.com^$subdocument,domain=example.com"],
                expectedSafariRulesJSON: #"""
                                   [
                                     {
                                       "action" : {
                                         "type" : "block"
                                       },
                                       "trigger" : {
                                         "if-domain" : [
                                           "*example.com"
                                         ],
                                         "resource-type" : [
                                           "document"
                                         ],
                                         "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?test\\.com([\\\/:&\\?].*)?$"
                                       }
                                     }
                                   ]
                                   """#,
                version: SafariVersion.safari13,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $subdocument,first-party is allowed in newer Safari versions
                rules: ["||test.com^$subdocument,1p"],
                expectedSafariRulesJSON: #"""
                                    [
                                      {
                                        "action" : {
                                          "type" : "block"
                                        },
                                        "trigger" : {
                                          "load-context" : [
                                            "child-frame"
                                          ],
                                          "load-type" : [
                                            "first-party"
                                          ],
                                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?test\\.com([\\\/:&\\?].*)?$"
                                        }
                                      }
                                    ]
                                    """#,
                version: SafariVersion.safari16_4,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $~subdocument in newer Safari versions changes load-context
                rules: ["||test.com^$~subdocument"],
                expectedSafariRulesJSON: #"""
                                    [
                                      {
                                        "action" : {
                                          "type" : "block"
                                        },
                                        "trigger" : {
                                          "load-context" : [
                                            "top-frame"
                                          ],
                                          "resource-type" : [
                                            "image",
                                            "style-sheet",
                                            "script",
                                            "media",
                                            "fetch",
                                            "other",
                                            "websocket",
                                            "font",
                                            "ping",
                                            "document"
                                          ],
                                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?test\\.com([\\\/:&\\?].*)?$"
                                        }
                                      }
                                    ]
                                    """#,
                version: SafariVersion.safari16_4,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $third-party and "unless-domains" workaround for old Safari.
                rules: ["||test.com^$third-party"],
                expectedSafariRulesJSON: #"""
                                    [
                                      {
                                        "action" : {
                                          "type" : "block"
                                        },
                                        "trigger" : {
                                          "load-type" : [
                                            "third-party"
                                          ],
                                          "unless-domain" : [
                                            "*test.com"
                                          ],
                                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?test\\.com([\\\/:&\\?].*)?$"
                                        }
                                      }
                                    ]
                                    """#,
                version: SafariVersion.safari13,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $third-party and "unless-domains" workaround is not required in newer Safari.
                rules: ["||test.com^$third-party"],
                expectedSafariRulesJSON: #"""
                                    [
                                      {
                                        "action" : {
                                          "type" : "block"
                                        },
                                        "trigger" : {
                                          "load-type" : [
                                            "third-party"
                                          ],
                                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?test\\.com([\\\/:&\\?].*)?$"
                                        }
                                      }
                                    ]
                                    """#,
                version: SafariVersion.safari16_4,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // Convert empty regex (i.e. match all urls).
                rules: ["@@$image,domain=moonwalk.cc"],
                expectedSafariRulesJSON: #"""
                                    [
                                      {
                                        "action" : {
                                          "type" : "ignore-previous-rules"
                                        },
                                        "trigger" : {
                                          "if-domain" : [
                                            "*moonwalk.cc"
                                          ],
                                          "resource-type" : [
                                            "image"
                                          ],
                                          "url-filter" : ".*"
                                        }
                                      }
                                    ]
                                    """#,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // Convert whitelist element hiding rule.
                // Disable generic rule on several websites.
                rules: [
                    "##.banner",
                    "example.org,example.net#@#.banner",
                    "example.com#@#.banner"
                ],
                expectedSafariRulesJSON: #"""
                                    [
                                      {
                                        "action" : {
                                          "selector" : ".banner",
                                          "type" : "css-display-none"
                                        },
                                        "trigger" : {
                                          "unless-domain" : [
                                            "*example.org",
                                            "*example.net",
                                            "*example.com"
                                          ],
                                          "url-filter" : ".*"
                                        }
                                      }
                                    ]
                                    """#,
                expectedSourceRulesCount: 3,
                expectedSourceSafariCompatibleRulesCount: 3,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // Convert whitelist element hiding rule.
                // Cancel each other.
                rules: [
                    "example.org##.banner",
                    "example.org#@#.banner"
                ],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 0
            ),
            TestCase(
                // Convert whitelist element hiding rule.
                // Cancel each other.
                rules: [
                    "example.net##.banner",
                    "example.org##.banner",
                    "#@#.banner"
                ],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedSourceRulesCount: 3,
                expectedSourceSafariCompatibleRulesCount: 3,
                expectedSafariRulesCount: 0
            ),
            TestCase(
                // Convert whitelist element hiding rule.
                // Whitelist rule is discarded because of the mixed if-domain / unless-domain issue.
                rules: [
                    "example.net##.banner",
                    "example.org#@#.banner"
                ],
                expectedSafariRulesJSON: #"""
                                   [
                                     {
                                       "action" : {
                                         "selector" : ".banner",
                                         "type" : "css-display-none"
                                       },
                                       "trigger" : {
                                         "if-domain" : [
                                           "*example.net"
                                         ],
                                         "url-filter" : ".*"
                                       }
                                     }
                                   ]
                                   """#,
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // Convert whitelist rule with domain restrictions.
                rules: [
                    "@@||*$document,domain=~whitelisted.domain.com|~whitelisted.domain2.com"
                ],
                expectedSafariRulesJSON: #"""
                                   [
                                     {
                                       "action" : {
                                         "type" : "ignore-previous-rules"
                                       },
                                       "trigger" : {
                                         "unless-domain" : [
                                           "*whitelisted.domain.com",
                                           "*whitelisted.domain2.com"
                                         ],
                                         "url-filter" : ".*"
                                       }
                                     }
                                   ]
                                   """#,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // Single $generichide rule.
                rules: [
                    "@@||hulu.com/page$generichide"
                ],
                expectedSafariRulesJSON: #"""
                                   [
                                     {
                                       "action" : {
                                         "type" : "ignore-previous-rules"
                                       },
                                       "trigger" : {
                                         "resource-type" : [
                                           "document"
                                         ],
                                         "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?hulu\\.com\\\/page"
                                       }
                                     }
                                   ]
                                   """#,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $elemhide rule, check that it disables all element hiding,
                // but does not unblock URL filtering.
                rules: [
                    "@@||example.org^$elemhide",
                    "##.generic",
                    "example.org##.specific",
                    "||example.org^"
                ],
                expectedSafariRulesJSON: #"""
                                   [
                                     {
                                       "action" : {
                                         "selector" : ".generic",
                                         "type" : "css-display-none"
                                       },
                                       "trigger" : {
                                         "url-filter" : ".*"
                                       }
                                     },
                                     {
                                       "action" : {
                                         "selector" : ".specific",
                                         "type" : "css-display-none"
                                       },
                                       "trigger" : {
                                         "if-domain" : [
                                           "*example.org"
                                         ],
                                         "url-filter" : ".*"
                                       }
                                     },
                                     {
                                       "action" : {
                                         "type" : "ignore-previous-rules"
                                       },
                                       "trigger" : {
                                         "if-domain" : [
                                           "*example.org"
                                         ],
                                         "url-filter" : ".*"
                                       }
                                     },
                                     {
                                       "action" : {
                                         "type" : "block"
                                       },
                                       "trigger" : {
                                         "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.org([\\\/:&\\?].*)?$"
                                       }
                                     }
                                   ]
                                   """#,
                expectedSourceRulesCount: 4,
                expectedSourceSafariCompatibleRulesCount: 4,
                expectedSafariRulesCount: 4
            ),
            TestCase(
                // $generichide rule, make sure that specific rules will be applied,
                // but generic rules will be disabled.
                rules: [
                    "@@||example.org^$generichide",
                    "##.generic",
                    "example.org##.specific"
                ],
                expectedSafariRulesJSON: #"""
                                   [
                                     {
                                       "action" : {
                                         "selector" : ".generic",
                                         "type" : "css-display-none"
                                       },
                                       "trigger" : {
                                         "url-filter" : ".*"
                                       }
                                     },
                                     {
                                       "action" : {
                                         "type" : "ignore-previous-rules"
                                       },
                                       "trigger" : {
                                         "if-domain" : [
                                           "*example.org"
                                         ],
                                         "url-filter" : ".*"
                                       }
                                     },
                                     {
                                       "action" : {
                                         "selector" : ".specific",
                                         "type" : "css-display-none"
                                       },
                                       "trigger" : {
                                         "if-domain" : [
                                           "*example.org"
                                         ],
                                         "url-filter" : ".*"
                                       }
                                     }
                                   ]
                                   """#,
                expectedSourceRulesCount: 3,
                expectedSourceSafariCompatibleRulesCount: 3,
                expectedSafariRulesCount: 3
            ),
            TestCase(
                // Compacting multiple rules for the same domain to a single rule.
                rules: [
                    "example.org###selector-one",
                    "example.org###selector-two",
                    "example.org###selector-three"
                ],
                expectedSafariRulesJSON: #"""
                                   [
                                     {
                                       "action" : {
                                         "selector" : "#selector-one, #selector-two, #selector-three",
                                         "type" : "css-display-none"
                                       },
                                       "trigger" : {
                                         "if-domain" : [
                                           "*example.org"
                                         ],
                                         "url-filter" : ".*"
                                       }
                                     }
                                   ]
                                   """#,
                expectedSourceRulesCount: 3,
                expectedSourceSafariCompatibleRulesCount: 3,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // Rules with Cyrillic letters.
                rules: [
                    "меил.рф",
                    "||меил.рф"
                ],
                expectedSafariRulesJSON: #"""
                                   [
                                     {
                                       "action" : {
                                         "type" : "block"
                                       },
                                       "trigger" : {
                                         "url-filter" : "xn--e1agjb\\.xn--p1ai"
                                       }
                                     },
                                     {
                                       "action" : {
                                         "type" : "block"
                                       },
                                       "trigger" : {
                                         "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?xn--e1agjb\\.xn--p1ai"
                                       }
                                     }
                                   ]
                                   """#,
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            ),
            TestCase(
                // Discarding regex rules (real cases).
                rules: [
                    // Negative lookahead.
                    #"/^https?://(?!static\.)([^.]+\.)+?fastpic\.ru[:/]/$script,domain=fastpic.ru"#,
                    // Digit range is not supported.
                    #"@@/:\/\/.*[.]wp[.]pl\/[a-z0-9_]{30,50}[.][a-z]{2,5}([\/:&\?].*)?$/"#,
                    // Escape sequences like \b are not supported.
                    #"@@/:\/\/.*[.]wp[.]pl\/[a-z0-9_]+[.][a-z]+\b/"#,
                    // Unbalanced bracket.
                    #"/example{/"#
                ],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedSourceRulesCount: 4,
                expectedSourceSafariCompatibleRulesCount: 4,
                expectedSafariRulesCount: 0,
                expectedErrorsCount: 4
            ),
            TestCase(
                // CSS with pseudo-classes. Checking that validation works as expected.
                // Also, checks that the rules are compacted.
                rules: [
                    "###main > table.w3-table-all.notranslate:first-child > tbody > tr:nth-child(17) > td.notranslate:nth-child(2)",
                    "###:root div.ads",
                    "###body div[attr='test']:first-child  div",
                    "##.todaystripe::after"
                ],
                expectedSafariRulesJSON: #"""
                                         [
                                           {
                                             "action" : {
                                               "selector" : "#main > table.w3-table-all.notranslate:first-child > tbody > tr:nth-child(17) > td.notranslate:nth-child(2), #:root div.ads, #body div[attr='test']:first-child  div, .todaystripe::after",
                                               "type" : "css-display-none"
                                             },
                                             "trigger" : {
                                               "url-filter" : ".*"
                                             }
                                           }
                                         ]
                                         """#,
                expectedSourceRulesCount: 4,
                expectedSourceSafariCompatibleRulesCount: 4,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // Test that exception rules unblock regular rules.
                rules: [
                    "||example.org^",
                    "@@/test"
                ],
                expectedSafariRulesJSON: #"""
                                   [
                                     {
                                       "action" : {
                                         "type" : "block"
                                       },
                                       "trigger" : {
                                         "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.org([\\\/:&\\?].*)?$"
                                       }
                                     },
                                     {
                                       "action" : {
                                         "type" : "ignore-previous-rules"
                                       },
                                       "trigger" : {
                                         "url-filter" : "\\\/test"
                                       }
                                     }
                                   ]
                                   """#,
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            ),
            TestCase(
                // Test that $important rules override exception rules.
                rules: [
                    "||example.org^$important",
                    "@@/test"
                ],
                expectedSafariRulesJSON: #"""
                                   [
                                     {
                                       "action" : {
                                         "type" : "ignore-previous-rules"
                                       },
                                       "trigger" : {
                                         "url-filter" : "\\\/test"
                                       }
                                     },
                                     {
                                       "action" : {
                                         "type" : "block"
                                       },
                                       "trigger" : {
                                         "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.org([\\\/:&\\?].*)?$"
                                       }
                                     }
                                   ]
                                   """#,
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            ),
            TestCase(
                // Test that $important exception rules unblock $important rules.
                rules: [
                    "||example.org^$important",
                    "@@/test$important"
                ],
                expectedSafariRulesJSON: #"""
                                   [
                                     {
                                       "action" : {
                                         "type" : "block"
                                       },
                                       "trigger" : {
                                         "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.org([\\\/:&\\?].*)?$"
                                       }
                                     },
                                     {
                                       "action" : {
                                         "type" : "ignore-previous-rules"
                                       },
                                       "trigger" : {
                                         "url-filter" : "\\\/test"
                                       }
                                     }
                                   ]
                                   """#,
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            ),
            TestCase(
                // Test that $document exception rules unblock $important rules.
                rules: [
                    "||example.org^$important",
                    "@@/test$document"
                ],
                expectedSafariRulesJSON: #"""
                                   [
                                     {
                                       "action" : {
                                         "type" : "block"
                                       },
                                       "trigger" : {
                                         "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.org([\\\/:&\\?].*)?$"
                                       }
                                     },
                                     {
                                       "action" : {
                                         "type" : "ignore-previous-rules"
                                       },
                                       "trigger" : {
                                         "url-filter" : "\\\/test"
                                       }
                                     }
                                   ]
                                   """#,
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            ),
        ]

        // TODO(ameshkov): !!! Add test for all
        //        entries.append(contentsOf: result.cssBlockingWide)
        //        entries.append(contentsOf: result.cssBlockingGenericDomainSensitive)
        //        entries.append(contentsOf: result.cssBlockingGenericHideExceptions)
        //        entries.append(contentsOf: result.cssBlockingDomainSensitive)
        //        entries.append(contentsOf: result.cssElemhideExceptions)
        //        entries.append(contentsOf: result.urlBlocking)
        //        entries.append(contentsOf: result.otherExceptions)
        //        entries.append(contentsOf: result.important)
        //        entries.append(contentsOf: result.importantExceptions)
        //        entries.append(contentsOf: result.documentExceptions)

        for testCase in testCases {
            let converter = ContentBlockerConverter()
            let result = converter.convertArray(rules: testCase.rules, safariVersion: testCase.version)

            let msg = "Unexpected result for converting rules\n \(testCase.rules.joined(separator: "\n"))"

            XCTAssertEqual(result.sourceRulesCount, testCase.expectedSourceRulesCount, msg)
            XCTAssertEqual(result.sourceSafariCompatibleRulesCount, testCase.expectedSourceSafariCompatibleRulesCount, msg)
            XCTAssertEqual(result.safariRulesCount, testCase.expectedSafariRulesCount, msg)
            XCTAssertEqual(result.advancedRulesCount, testCase.expectedAdvancedRulesCount, msg)
            XCTAssertEqual(result.errorsCount, testCase.expectedErrorsCount, msg)
            assertContentBlockerJSON(result.safariRulesJSON, testCase.expectedSafariRulesJSON, msg)
            XCTAssertEqual(result.advancedRulesText, testCase.expectedAdvancedRulesText, msg)
        }
    }

    func testBadfilterRules() {
        let result = converter.convertArray(rules: [
            "||example.org^$image",
            "||test.org^",
            "||example.org^$badfilter,image"
        ])
        XCTAssertEqual(result.safariRulesCount, 1)

        let decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertEqual(decoded[0].trigger.urlFilter, START_URL_UNESCAPED + "test\\.org" + URL_FILTER_REGEXP_END_SEPARATOR)

        let regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!)
        XCTAssertNotNil("https://test.org".firstMatch(for: regex))
    }

    func testBadfilterWithDomainsRules() {
        let result = converter.convertArray(rules: [
            "*$domain=test1.com,third-party,important",
            "*$domain=test2.com,important",
            "*$domain=bad1.com,third-party,important",
            "*$domain=bad2.com|google.com,third-party,important",
            "*$domain=bad1.com|bad2.com|lenta.ru,third-party,important",
            "*$domain=bad2.com|bad1.com,third-party,important",
            "*$domain=bad1.com|bad2.com,third-party,important,badfilter"
        ])

        XCTAssertEqual(result.safariRulesCount, 2)

        let decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 2)

        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*test1.com")
        XCTAssertEqual(decoded[1].trigger.ifDomain?[0], "*test2.com")
    }

    func testTldWildcardRules() {
        var result = converter.convertArray(rules: ["surge.*,testcases.adguard.*###case-5-wildcard-for-tld > .test-banner"])
        XCTAssertEqual(result.safariRulesCount, 1)

        var decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.urlFilter, URL_FILTER_CSS_RULES)
        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*surge.com.bd")
        XCTAssertEqual(decoded[0].trigger.ifDomain?[1], "*surge.com.np")
        XCTAssertEqual(decoded[0].trigger.ifDomain?[2], "*surge.com")
        XCTAssertEqual(decoded[0].trigger.ifDomain?.count, 200)

        result = converter.convertArray(rules: ["||*/test-files/adguard.png$domain=surge.*|testcases.adguard.*"])
        XCTAssertEqual(result.safariRulesCount, 1)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.urlFilter, START_URL_UNESCAPED + ".*\\/test-files\\/adguard\\.png")
        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*surge.com.bd")
        XCTAssertEqual(decoded[0].trigger.ifDomain?[1], "*surge.com.np")
        XCTAssertEqual(decoded[0].trigger.ifDomain?[2], "*surge.com")
        XCTAssertEqual(decoded[0].trigger.ifDomain?.count, 200)

        let regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!)
        XCTAssertNotNil("https://test.com/test-files/adguard.png".firstMatch(for: regex))

        result = converter.convertArray(rules: ["|http$script,domain=forbes.*"])
        XCTAssertEqual(result.safariRulesCount, 1)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].action.type, "block")
        XCTAssertEqual(decoded[0].trigger.urlFilter, "^http")
        XCTAssertEqual(decoded[0].trigger.resourceType, ["script"])
        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*forbes.com.bd")
        XCTAssertEqual(decoded[0].trigger.ifDomain?[1], "*forbes.com.np")
        XCTAssertEqual(decoded[0].trigger.ifDomain?[2], "*forbes.com")
        XCTAssertEqual(decoded[0].trigger.ifDomain?[99], "*forbes.link")
        XCTAssertEqual(decoded[0].trigger.ifDomain?.count, 100)
    }

    // TODO(ameshkov): !!! Restore test
    //    func testUboScriptletRules() {
    //        let ruleText = [
    //            "example.org##+js(aopr,__cad.cpm_popunder)",
    //            "example.org##+js(acis,setTimeout,testad)",
    //        ];
    //
    //        let result = converter.convertArray(rules: ruleText, advancedBlocking: true);
    //        XCTAssertEqual(result.errorsCount, 0);
    //
    //        let decoded = try! parseJsonString(json: result.advancedBlocking!);
    //        XCTAssertEqual(decoded.count, 2);
    //
    //        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*example.org");
    //        XCTAssertEqual(decoded[0].action.type, "scriptlet");
    //        XCTAssertEqual(decoded[0].action.scriptlet, "ubo-aopr");
    //        XCTAssertEqual(decoded[0].action.scriptletParam, #"{"name":"ubo-aopr","args":["__cad.cpm_popunder"]}"#);
    //
    //        XCTAssertEqual(decoded[1].trigger.ifDomain?[0], "*example.org");
    //        XCTAssertEqual(decoded[1].action.type, "scriptlet");
    //        XCTAssertEqual(decoded[1].action.scriptlet, "ubo-acis");
    //        XCTAssertEqual(decoded[1].action.scriptletParam, #"{"name":"ubo-acis","args":["setTimeout","testad"]}"#);
    //    }

    func testInvalidRegexpRules() {
        let ruleText = [
            #"/([0-9]{1,3}\.){3}[0-9]{1,3}.\/proxy$/$script,websocket,third-party"#
        ]

        let result = converter.convertArray(rules: ruleText)
        XCTAssertEqual(result.errorsCount, 1)
        XCTAssertEqual(result.safariRulesCount, 0)
    }

    func testCollisionCssAndScriptRules() {
        let ruleText = [
            "example.org##body",
            "example.org#%#alert('1');",
        ]

        let result = converter.convertArray(rules: ruleText)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.safariRulesCount, 1)

        let decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, "body")
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*")
        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*example.org")
    }

    func testCollisionCssAndScriptletRules() {
        let ruleText = [
            "example.org##body",
            "example.org#%#//scriptlet('abort-on-property-read', 'I10C')",
        ]

        let result = converter.convertArray(rules: ruleText)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.safariRulesCount, 1)

        let decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, "body")
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*")
        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*example.org")
    }

    // TODO(ameshkov): !!! Restore test
    //    func testCollisionCssAndScriptRulesAdvancedBlocking() {
    //        let ruleText = [
    //            "example.org##body",
    //            "example.org#%#alert('1');",
    //        ];
    //
    //        let result = converter.convertArray(rules: ruleText, advancedBlocking: true);
    //        XCTAssertEqual(result.errorsCount, 0);
    //        XCTAssertEqual(result.convertedCount, 1);
    //
    //        let decoded = try! parseJsonString(json: result.converted);
    //        XCTAssertEqual(decoded.count, 1);
    //        XCTAssertEqual(decoded[0].action.type, "css-display-none");
    //        XCTAssertEqual(decoded[0].action.selector, "body");
    //        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
    //        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*example.org");
    //
    //        let decodedAdvBlocking = try! parseJsonString(json: result.advancedBlocking!);
    //        XCTAssertEqual(decodedAdvBlocking.count, 1);
    //
    //        XCTAssertEqual(decodedAdvBlocking[0].trigger.ifDomain?[0], "*example.org");
    //        XCTAssertEqual(decodedAdvBlocking[0].action.type, "script");
    //        XCTAssertEqual(decodedAdvBlocking[0].action.script, "alert(\'1\');");
    //    }

    // TODO(ameshkov): !!! Restore test
    //    func testCollisionCssAndScriptletRulesAdvancedBlocking() {
    //        let ruleText = [
    //            "example.org##body",
    //            "example.org#%#//scriptlet('abort-on-property-read', 'I10C')",
    //        ];
    //
    //        let result = converter.convertArray(rules: ruleText, advancedBlocking: true);
    //        XCTAssertEqual(result.errorsCount, 0);
    //        XCTAssertEqual(result.convertedCount, 1);
    //
    //        let decoded = try! parseJsonString(json: result.converted);
    //        XCTAssertEqual(decoded.count, 1);
    //        XCTAssertEqual(decoded[0].action.type, "css-display-none");
    //        XCTAssertEqual(decoded[0].action.selector, "body");
    //        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
    //        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*example.org");
    //
    //        let decodedAdvBlocking = try! parseJsonString(json: result.advancedBlocking!);
    //        XCTAssertEqual(decodedAdvBlocking.count, 1);
    //
    //        XCTAssertEqual(decodedAdvBlocking[0].trigger.ifDomain?[0], "*example.org");
    //        XCTAssertEqual(decodedAdvBlocking[0].action.scriptlet, "abort-on-property-read");
    //        XCTAssertEqual(decodedAdvBlocking[0].action.scriptletParam, "{\"name\":\"abort-on-property-read\",\"args\":[\"I10C\"]}");
    //    }

    func testGenericCssRules() {
        let ruleText = [
            "#$?#div:has(> .banner) { display: none; debug: global; }",
        ]

        let result = converter.convertArray(rules: ruleText, advancedBlocking: true)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.safariRulesJSON, ConversionResult.EMPTY_RESULT_JSON)
        XCTAssertEqual(result.advancedRulesCount, 1)
        XCTAssertEqual(result.advancedRulesText, ruleText.joined(separator: "\n"))
    }

    // TODO(ameshkov): !!! Restore test
    //    func testCssInjectWithMultiSelectors() {
    //        let ruleText = [
    //            "google.com#$##js-header, #searchform, .O-j-k, .header:not(.column-section):not(.viewed):not(.ng-star-inserted):not([class*=\"_ngcontent\"]), .js-header.chr-header, .mobile-action-bar, body > .ng-scope, #flt-nav, .gws-flights__scrollbar-padding.gws-flights__selection-bar, .gws-flights__selection-bar-shadow-mask { position: absolute !important; }",
    //        ];
    //        let result = converter.convertArray(rules: ruleText, advancedBlocking: true);
    //        XCTAssertEqual(result.errorsCount, 0);
    //        XCTAssertEqual(result.convertedCount, 0);
    //        XCTAssertEqual(result.advancedBlockingConvertedCount, 1);
    //
    //        let decoded = try! parseJsonString(json: result.advancedBlocking!);
    //        XCTAssertEqual(decoded.count, 1);
    //
    //        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*google.com"]);
    //        XCTAssertNil(decoded[0].trigger.unlessDomain);
    //        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
    //        XCTAssertEqual(decoded[0].action.type, "css-inject");
    //        XCTAssertEqual(decoded[0].action.css, "#js-header, #searchform, .O-j-k, .header:not(.column-section):not(.viewed):not(.ng-star-inserted):not([class*=\"_ngcontent\"]), .js-header.chr-header, .mobile-action-bar, body > .ng-scope, #flt-nav, .gws-flights__scrollbar-padding.gws-flights__selection-bar, .gws-flights__selection-bar-shadow-mask { position: absolute !important; }");
    //    }

    func testSpecialCharactersEscape() {
        var ruleText = [
            "+Popunder+$popup",
        ]

        var result = converter.convertArray(rules: ruleText)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.safariRulesCount, 1)

        var decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].action.type, "block")
        XCTAssertEqual(decoded[0].trigger.urlFilter, "\\+Popunder\\+")

        ruleText = [
            "||calabriareportage.it^+-Banner-",
        ]

        result = converter.convertArray(rules: ruleText)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.safariRulesCount, 1)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].action.type, "block")
        XCTAssertEqual(decoded[0].trigger.urlFilter, START_URL_UNESCAPED + "calabriareportage\\.it[/:&?]?\\+-Banner-")

        ruleText = [
            #"@@/:\/\/.*[.]wp[.]pl\/[a-z0-9_]+[.][a-z]+\\/"#,
        ]

        result = converter.convertArray(rules: ruleText)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.safariRulesCount, 1)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].action.type, "ignore-previous-rules")
        XCTAssertEqual(decoded[0].trigger.urlFilter, ":\\/\\/.*[.]wp[.]pl\\/[a-z0-9_]+[.][a-z]+\\\\")

        ruleText = [
            #"/\\/"#,
        ]

        result = converter.convertArray(rules: ruleText)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.safariRulesCount, 1)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].action.type, "block")
        XCTAssertEqual(decoded[0].trigger.urlFilter, "\\\\")
    }

    func testSpecifichide() {
        var ruleText: [String] = [
            "example.org##.banner1",
            "example.org,test.com##.banner2",
            "##.banner3",
            "@@||example.org^$specifichide",
        ]

        // should remain only "##.banner3" and "test.com##.banner2"
        var result = converter.convertArray(rules: ruleText)

        XCTAssertEqual(result.safariRulesCount, 2)
        XCTAssertEqual(result.discardedSafariRules, 0)
        XCTAssertEqual(result.errorsCount, 0)

        var decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 2)

        XCTAssertNil(decoded[0].trigger.ifDomain)
        XCTAssertNil(decoded[0].trigger.unlessDomain)
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*")
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, ".banner3")

        XCTAssertEqual(decoded[1].trigger.ifDomain, ["*test.com"])
        XCTAssertNil(decoded[1].trigger.unlessDomain)
        XCTAssertEqual(decoded[1].trigger.urlFilter, ".*")
        XCTAssertEqual(decoded[1].action.type, "css-display-none")
        XCTAssertEqual(decoded[1].action.selector, ".banner2")

        ruleText = [
            "example.org##.banner1",
            "##.banner2",
            "@@||example.org^$specifichide",
        ]

        // should remain only "##.banner2"
        result = converter.convertArray(rules: ruleText)

        XCTAssertEqual(result.sourceSafariCompatibleRulesCount, 3)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.discardedSafariRules, 0)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertNil(decoded[0].trigger.ifDomain)
        XCTAssertNil(decoded[0].trigger.unlessDomain)
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*")
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, ".banner2")

        ruleText = [
            "test.com,example.org#$#body { overflow: visible!important; }",
            "##.banner",
            "@@||example.org^$specifichide",
        ]

        // should remain only "##.banner" and "test.com#$#body { overflow: visible!important }"
        result = converter.convertArray(rules: ruleText, advancedBlocking: true)

        XCTAssertEqual(result.sourceRulesCount, 3)
        XCTAssertEqual(result.sourceSafariCompatibleRulesCount, 2)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.advancedRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertNil(decoded[0].trigger.ifDomain)
        XCTAssertNil(decoded[0].trigger.unlessDomain)
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*")
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, ".banner")

        // TODO(ameshkov): !!! Restore test
        //        var decodedAdvBlocking = try! parseJsonString(json: result.advancedBlocking!);
        //        XCTAssertEqual(decodedAdvBlocking.count, 1);
        //
        //        XCTAssertEqual(decodedAdvBlocking[0].trigger.ifDomain, ["*test.com"]);
        //        XCTAssertNil(decodedAdvBlocking[0].trigger.unlessDomain);
        //        XCTAssertEqual(decodedAdvBlocking[0].trigger.urlFilter, ".*");
        //        XCTAssertEqual(decodedAdvBlocking[0].action.type, "css-inject");
        //        XCTAssertEqual(decodedAdvBlocking[0].action.css, "body { overflow: visible!important; }");

        ruleText = [
            "test.com,example.org#$?#div:has(> .banner) { visibility: hidden!important; }",
            "##.banner",
            "example.org#$#.adsblock { opacity: 0!important; }",
            "@@||example.org^$specifichide",
        ]

        // should remain only "##.banner" and "test.com#$?#div:has(> .banner) { visibility: hidden!important; }"

        result = converter.convertArray(rules: ruleText, advancedBlocking: true)

        XCTAssertEqual(result.sourceSafariCompatibleRulesCount, 2)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.advancedRulesCount, 3)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertNil(decoded[0].trigger.ifDomain)
        XCTAssertNil(decoded[0].trigger.unlessDomain)
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*")
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, ".banner")

        // TODO(ameshkov): !!! Restore test
        //        decodedAdvBlocking = try! parseJsonString(json: result.advancedBlocking!);
        //        XCTAssertEqual(decodedAdvBlocking.count, 1);
        //
        //        XCTAssertEqual(decodedAdvBlocking[0].trigger.ifDomain, ["*test.com"]);
        //        XCTAssertNil(decodedAdvBlocking[0].trigger.unlessDomain);
        //        XCTAssertEqual(decodedAdvBlocking[0].trigger.urlFilter, ".*");
        //        XCTAssertEqual(decodedAdvBlocking[0].action.type, "css-extended");
        //        XCTAssertEqual(decodedAdvBlocking[0].action.css, "div:has(> .banner) { visibility: hidden!important; }");

        ruleText = [
            "test.subdomain.test.com##.banner",
            "test.com##.headeads",
            "##.ad-banner",
            "@@||subdomain.test.com^$specifichide",
        ]

        // should remain "##.ad-banner", "test.subdomain.test.com##.banner" and "test.com##.headeads"
        result = converter.convertArray(rules: ruleText)

        XCTAssertEqual(result.sourceSafariCompatibleRulesCount, 4)
        XCTAssertEqual(result.safariRulesCount, 3)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 3)

        XCTAssertTrue(checkEntriesByCondition(
            entries: decoded,
            condition: {
                $0.trigger.ifDomain == nil &&
                $0.trigger.unlessDomain == nil &&
                $0.trigger.urlFilter == ".*" &&
                $0.action.type == "css-display-none" &&
                $0.action.selector == ".ad-banner"
            }))

        XCTAssertTrue(checkEntriesByCondition(
            entries: decoded,
            condition: {
                $0.trigger.ifDomain == ["*test.subdomain.test.com"] &&
                $0.trigger.unlessDomain == nil &&
                $0.trigger.urlFilter == ".*" &&
                $0.action.type == "css-display-none" &&
                $0.action.selector == ".banner"
            }))

        XCTAssertTrue(checkEntriesByCondition(
            entries: decoded,
            condition: {
                $0.trigger.ifDomain == ["*test.com"] &&
                $0.trigger.unlessDomain == nil &&
                $0.trigger.urlFilter == ".*" &&
                $0.action.type == "css-display-none" &&
                $0.action.selector == ".headeads"
            }))

        ruleText = [
            "example1.org,example2.org,example3.org##.banner1",
            "@@||example1.org^$specifichide",
            "@@||example2.org^$specifichide"
        ]

        // should remain only "example3.org##.banner1"
        result = converter.convertArray(rules: ruleText)

        XCTAssertEqual(result.sourceSafariCompatibleRulesCount, 3)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.discardedSafariRules, 0)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example3.org"])
        XCTAssertNil(decoded[0].trigger.unlessDomain)
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*")
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, ".banner1")

        ruleText = [
            "#$#.banner { color: red!important; }",
            "@@||example.org^$specifichide",
        ]

        // should remain only "##.banner { color: red!important; }"
        result = converter.convertArray(rules: ruleText, advancedBlocking: true)

        XCTAssertEqual(result.sourceSafariCompatibleRulesCount, 1)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.advancedRulesCount, 2)

        // TODO(ameshkov): !!! Restore test
        //        decoded = try! parseJsonString(json: result.advancedBlocking!);
        //        XCTAssertEqual(decoded.count, 1);
        //
        //        XCTAssertNil(decoded[0].trigger.ifDomain);
        //        XCTAssertNil(decoded[0].trigger.unlessDomain);
        //        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        //        XCTAssertEqual(decoded[0].action.type, "css-inject");
        //        XCTAssertEqual(decoded[0].action.css, ".banner { color: red!important; }");
    }

    func testEscapeBackslash() {
        var ruleText = [
            "||gamer.no/?module=Tumedia\\DFProxy\\Modules^",
        ]
        var result = converter.convertArray(rules: ruleText)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.safariRulesCount, 1)
        var decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertTrue(decoded[0].trigger.urlFilter!.contains("Tumedia\\\\DFProxy\\\\Modules"))

        ruleText = [
            "||xyz^$third-party,script,xmlhttprequest,domain=~anidub.com|~animedia.pro|~animeheaven.ru|~app.element.io|~assistir-filme.biz|~avtomaty-i-bonusy.com|~chelentano.top|~coomeet.com|~crackstreams.com|~crackstreams.ga|~csgoreports.com|~cvid.kiev.ua|~estream.to|~europixhd.io|~films.hds-stream.com|~funtik.tv|~getvi.tv|~hanime.tv|~hentaiz.org|~herokuapp.com|~infoua.biz|~jokehd.com|~jokerswidget.com|~kinobig.me|~kinoguru.be|~kinoguru.me|~kristinita.ru|~live-golf.stream|~lookbase.xyz|~magicfilm.net|~mail.google.com|~map-a-date.cc|~matchat.online|~mikeamigorein.xyz|~miranimbus.ru|~my.mail.ru|~nccg.ru|~newdeaf.club|~newdmn.icu​|~onmovies.se|~playjoke.xyz|~roadhub.ru|~roblox.com|~sextop.net|~soccer365.ru|~soonwalk.net|~sportsbay.org|~streetbee.io|~streetbee.ru|~telerium.club|~telerium.live|~uacycling.info|~uploadedpremiumlink.net|~vk.com|~vmeste.tv|~web.app",
        ]

        result = converter.convertArray(rules: ruleText)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.safariRulesCount, 1)
        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertTrue(decoded[0].trigger.urlFilter!.contains("^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?xyz" + URL_FILTER_REGEXP_END_SEPARATOR))

        ruleText = [
            "/g\\.alicdn\\.com\\/mm\\/yksdk\\/0\\.2\\.\\d+\\/playersdk\\.js/>>>1111.51xiaolu.com/playersdk.js>>>>keyword=playersdk",
        ]
        result = converter.convertArray(rules: ruleText)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.safariRulesCount, 1)
        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertTrue(decoded[0].trigger.urlFilter!.contains(".com\\\\\\/mm\\\\\\/yksdk"))
    }

    func testPingModifierRules() {
        var rules = ["||example.org^$ping"]
        var result = converter.convertArray(rules: rules)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.sourceRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 1)

        rules = ["||example.org^$~ping,domain=test.com"]
        result = converter.convertArray(rules: rules)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.sourceRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 1)

        rules = ["||example.org^$ping"]
        result = converter.convertArray(rules: rules, safariVersion: SafariVersion.safari15)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.sourceRulesCount, 1)

        var decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        var entry = decoded[0]
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "example\\.org" + URL_FILTER_REGEXP_END_SEPARATOR)
        XCTAssertNil(entry.trigger.ifDomain)
        XCTAssertNil(entry.trigger.unlessDomain)
        XCTAssertEqual(entry.trigger.resourceType, ["ping"])

        rules = ["||example.org^$~ping,domain=test.com"]
        result = converter.convertArray(rules: rules, safariVersion: SafariVersion.safari15)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.sourceRulesCount, 1)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        entry = decoded[0]
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "example\\.org" + URL_FILTER_REGEXP_END_SEPARATOR)
        XCTAssertEqual(entry.trigger.ifDomain, ["*test.com"])
        XCTAssertNil(entry.trigger.unlessDomain)
        XCTAssertEqual(entry.trigger.resourceType, ["image", "style-sheet", "script", "media", "fetch", "other", "websocket", "font", "document"])
    }

    func testOtherModifierRules() {
        var rules = ["||test.com^$other"]
        var result = converter.convertArray(rules: rules)

        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.sourceRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        var decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.count, 1)
        var entry = decoded[0]
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "test\\.com" + URL_FILTER_REGEXP_END_SEPARATOR)
        XCTAssertEqual(entry.trigger.ifDomain, nil)
        XCTAssertEqual(entry.trigger.unlessDomain, nil)
        XCTAssertEqual(entry.trigger.loadType, nil)
        XCTAssertEqual(entry.trigger.resourceType, ["raw"])

        rules = ["||test.com^$~other,domain=example.org"]
        result = converter.convertArray(rules: rules)

        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.sourceRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.count, 1)
        entry = decoded[0]
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "test\\.com" + URL_FILTER_REGEXP_END_SEPARATOR)
        XCTAssertEqual(entry.trigger.ifDomain, ["*example.org"])
        XCTAssertEqual(entry.trigger.unlessDomain, nil)
        XCTAssertEqual(entry.trigger.loadType, nil)
        XCTAssertEqual(entry.trigger.resourceType, ["image", "style-sheet", "script", "media", "raw", "font", "document"])

        result = converter.convertArray(rules: ["||test.com^$other"], safariVersion: SafariVersion.safari15)

        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        entry = decoded[0]
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "test\\.com" + URL_FILTER_REGEXP_END_SEPARATOR)
        XCTAssertEqual(entry.trigger.ifDomain, nil)
        XCTAssertEqual(entry.trigger.unlessDomain, nil)
        XCTAssertEqual(entry.trigger.loadType, nil)
        XCTAssertEqual(entry.trigger.resourceType, ["other"])

        result = converter.convertArray(rules: ["||test.com^$~other,domain=example.org"], safariVersion: SafariVersion.safari15)

        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        entry = decoded[0]
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "test\\.com" + URL_FILTER_REGEXP_END_SEPARATOR)
        XCTAssertEqual(entry.trigger.ifDomain, ["*example.org"])
        XCTAssertEqual(entry.trigger.unlessDomain, nil)
        XCTAssertEqual(entry.trigger.loadType, nil)
        XCTAssertEqual(entry.trigger.resourceType, ["image", "style-sheet", "script", "media", "fetch", "websocket", "font", "ping", "document"])
    }

    func testXmlhttprequestModifierRules() {
        var rules = ["||test.com^$xmlhttprequest"]
        var result = converter.convertArray(rules: rules)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.sourceRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        var decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.count, 1)
        var entry = decoded[0]
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "test\\.com" + URL_FILTER_REGEXP_END_SEPARATOR)
        XCTAssertEqual(entry.trigger.ifDomain, nil)
        XCTAssertEqual(entry.trigger.unlessDomain, nil)
        XCTAssertEqual(entry.trigger.loadType, nil)
        XCTAssertEqual(entry.trigger.resourceType, ["raw"])

        rules = ["||test.com^$~xmlhttprequest,domain=example.org"]
        result = converter.convertArray(rules: rules)

        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.sourceRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.count, 1)
        entry = decoded[0]
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "test\\.com" + URL_FILTER_REGEXP_END_SEPARATOR)
        XCTAssertEqual(entry.trigger.ifDomain, ["*example.org"])
        XCTAssertEqual(entry.trigger.unlessDomain, nil)
        XCTAssertEqual(entry.trigger.loadType, nil)
        XCTAssertEqual(entry.trigger.resourceType, ["image", "style-sheet", "script", "media", "raw", "font", "document"])

        result = converter.convertArray(rules: ["||test.com^$xmlhttprequest"], safariVersion: SafariVersion.safari15)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        entry = decoded[0]
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "test\\.com" + URL_FILTER_REGEXP_END_SEPARATOR)
        XCTAssertEqual(entry.trigger.ifDomain, nil)
        XCTAssertEqual(entry.trigger.unlessDomain, nil)
        XCTAssertEqual(entry.trigger.loadType, nil)
        XCTAssertEqual(entry.trigger.resourceType, ["fetch"])

        result = converter.convertArray(rules: ["||test.com^$~xmlhttprequest,domain=example.org"], safariVersion: SafariVersion.safari15)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        entry = decoded[0]
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "test\\.com" + URL_FILTER_REGEXP_END_SEPARATOR)
        XCTAssertEqual(entry.trigger.ifDomain, ["*example.org"])
        XCTAssertEqual(entry.trigger.unlessDomain, nil)
        XCTAssertEqual(entry.trigger.loadType, nil)
        XCTAssertEqual(entry.trigger.resourceType, ["image", "style-sheet", "script", "media", "other", "websocket", "font", "ping", "document"])
    }

    func testCssExceptions() {
        var rules = ["test.com,example.com##.ad-banner", "test.com#@#.ad-banner"]
        var result = ContentBlockerConverter().convertArray(rules: rules)

        XCTAssertEqual(result.sourceRulesCount, 1)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        var decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*")
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.com"])
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, ".ad-banner")

        rules = ["test.com##.ad-banner", "test.com#@#.ad-banner"]
        result = ContentBlockerConverter().convertArray(rules: rules)

        XCTAssertEqual(result.sourceRulesCount, 0)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.safariRulesJSON, ConversionResult.EMPTY_RESULT_JSON)

        rules = ["##.ad-banner", "test.com#@#.ad-banner"]
        result = ContentBlockerConverter().convertArray(rules: rules)

        XCTAssertEqual(result.sourceRulesCount, 1)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*")
        XCTAssertNil(decoded[0].trigger.ifDomain)
        XCTAssertEqual(decoded[0].trigger.unlessDomain, ["*test.com"])
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, ".ad-banner")

        rules = ["##.ad-banner", "test.com#@#.ad-banner", "test.com##.ad-banner"]
        result = ContentBlockerConverter().convertArray(rules: rules)

        XCTAssertEqual(result.sourceRulesCount, 1)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*")
        XCTAssertNil(decoded[0].trigger.ifDomain)
        XCTAssertEqual(decoded[0].trigger.unlessDomain, ["*test.com"])
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, ".ad-banner")

        rules = ["test.com#@##banner", "example.org#@##banner", "###banner"]
        result = ContentBlockerConverter().convertArray(rules: rules)

        XCTAssertEqual(result.sourceRulesCount, 1)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*")
        XCTAssertNil(decoded[0].trigger.ifDomain)
        XCTAssertEqual(decoded[0].trigger.unlessDomain, ["*test.com", "*example.org"])
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, "#banner")

        rules = ["~test.com##.ad-banner", "~test.com#@#.ad-banner"]
        result = ContentBlockerConverter().convertArray(rules: rules)

        XCTAssertEqual(result.sourceRulesCount, 0)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.safariRulesJSON, ConversionResult.EMPTY_RESULT_JSON)

        rules = ["subdomain.example.org##.ad-banner", "example.org#@#.ad-banner"]
        result = ContentBlockerConverter().convertArray(rules: rules)

        XCTAssertEqual(result.sourceRulesCount, 0)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 0)

        rules = ["example.org###banner", "#@##banner"]

        result = ContentBlockerConverter().convertArray(rules: rules)

        XCTAssertEqual(result.sourceRulesCount, 0)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 0)

        rules = ["~example.org###banner", "#@##banner"]

        result = ContentBlockerConverter().convertArray(rules: rules)

        XCTAssertEqual(result.sourceRulesCount, 0)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 0)

        rules = ["example.org###banner", "*#@##banner"]

        result = ContentBlockerConverter().convertArray(rules: rules)

        XCTAssertEqual(result.sourceRulesCount, 0)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 0)

        rules = [
            "example.org,test.com,ya.ru###banner",
            "example.org,test.com,ya.ru#@##banner"
        ]

        result = ContentBlockerConverter().convertArray(rules: rules)

        XCTAssertEqual(result.sourceRulesCount, 0)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 0)
    }

    // TODO(ameshkov): !!! Restore test
    //    func testAdvancedBlockingExceptions() {
    //        func assertEmptyResult(result: ConversionResult) -> Void {
    //            XCTAssertEqual(result.totalConvertedCount, 0)
    //            XCTAssertEqual(result.convertedCount, 0)
    //            XCTAssertEqual(result.advancedBlockingConvertedCount, 0)
    //            XCTAssertEqual(result.errorsCount, 0)
    //            XCTAssertEqual(result.converted, ConversionResult.EMPTY_RESULT_JSON)
    //            XCTAssertNil(result.advancedBlocking)
    //        }
    //
    //        var rules = [
    //            "test.com#%#window.__testCase2 = true;",
    //            "test.com#@%#window.__testCase2 = true;",
    //            "test.com#$#.banner { display: none!important; }",
    //            "test.com#@$#.banner { display: none!important; }",
    //            "test.com#$?#div:has(> .banner) { display: none!important; }",
    //            "test.com#@$?#div:has(> .banner) { display: none!important; }",
    //            "test.com#%#//scriptlet('abort-on-property-read', 'abc')",
    //            "test.com#@%#//scriptlet('abort-on-property-read', 'abc')",
    //        ]
    //
    //        var result = ContentBlockerConverter().convertArray(rules: rules, advancedBlocking: true)
    //
    //        XCTAssertEqual(result.errorsCount, 0)
    //        XCTAssertEqual(result.converted, ConversionResult.EMPTY_RESULT_JSON)
    //
    //        rules = [
    //            "~test.com#%#window.__testCase2 = true;",
    //            "~test.com#@%#window.__testCase2 = true;",
    //            "~test.com#$#.banner { display: none!important; }",
    //            "~test.com#@$#.banner { display: none!important; }",
    //            "~test.com#$?#div:has(> .banner) { display: none!important; }",
    //            "~test.com#@$?#div:has(> .banner) { display: none!important; }",
    //            "~test.com#%#//scriptlet('abort-on-property-read', 'abc')",
    //            "~test.com#@%#//scriptlet('abort-on-property-read', 'abc')",
    //        ]
    //
    //        result = ContentBlockerConverter().convertArray(rules: rules, advancedBlocking: true)
    //
    //        XCTAssertEqual(result.errorsCount, 0)
    //        assertEmptyResult(result: result)
    //
    //        // css-inject exception
    //        rules = ["test.com,example.org#$#.banner { display: none!important; }", "test.com#@$#.banner { display: none!important; }"]
    //        result = ContentBlockerConverter().convertArray(rules: rules, advancedBlocking: true)
    //
    //        var decoded = try! parseJsonString(json: result.advancedBlocking!)
    //        XCTAssertEqual(decoded.count, 1)
    //
    //        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*")
    //        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org"])
    //        XCTAssertNil(decoded[0].trigger.unlessDomain)
    //        XCTAssertEqual(decoded[0].action.type, "css-inject")
    //        XCTAssertEqual(decoded[0].action.css, ".banner { display: none!important; }")
    //
    //        // css-extended exception
    //        rules = ["test.com,example.org#?#div:has(> .banner)", "test.com#@?#div:has(> .banner)"]
    //        result = ContentBlockerConverter().convertArray(rules: rules, advancedBlocking: true)
    //
    //        decoded = try! parseJsonString(json: result.advancedBlocking!)
    //        XCTAssertEqual(decoded.count, 1)
    //
    //        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*")
    //        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org"])
    //        XCTAssertNil(decoded[0].trigger.unlessDomain)
    //        XCTAssertEqual(decoded[0].action.type, "css-extended")
    //        XCTAssertEqual(decoded[0].action.css, "div:has(> .banner)")
    //
    //        // script exception
    //        rules = ["test.com,example.org#%#alert(1)", "test.com#@%#alert(1)"]
    //        result = ContentBlockerConverter().convertArray(rules: rules, advancedBlocking: true)
    //
    //        decoded = try! parseJsonString(json: result.advancedBlocking!)
    //        XCTAssertEqual(decoded.count, 1)
    //
    //        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*")
    //        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org"])
    //        XCTAssertNil(decoded[0].trigger.unlessDomain)
    //        XCTAssertEqual(decoded[0].action.type, "script")
    //        XCTAssertEqual(decoded[0].action.script, "alert(1)")
    //
    //        // scriptlet exception
    //        rules = ["test.com,example.org#%#//scriptlet('abort-on-property-read', 'abc')", "test.com#@%#//scriptlet('abort-on-property-read', 'abc')"]
    //        result = ContentBlockerConverter().convertArray(rules: rules, advancedBlocking: true)
    //
    //        decoded = try! parseJsonString(json: result.advancedBlocking!)
    //        XCTAssertEqual(decoded.count, 1)
    //
    //        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*")
    //        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org"])
    //        XCTAssertNil(decoded[0].trigger.unlessDomain)
    //        XCTAssertEqual(decoded[0].action.type, "scriptlet")
    //        XCTAssertEqual(decoded[0].action.scriptlet, "abort-on-property-read")
    //    }

    func testLoadContext() {
        var rules = ["||test.com^$subdocument,domain=example.com"]
        var result = converter.convertArray(rules: rules, safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 1)

        var decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.loadContext, ["child-frame"])

        result = converter.convertArray(rules: rules, safariVersion: .safari14)
        XCTAssertEqual(result.safariRulesCount, 1)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertNil(decoded[0].trigger.loadContext)
        XCTAssertEqual(decoded[0].trigger.resourceType, ["document"])

        rules = ["||test.com^$~subdocument,domain=example.com"]
        result = converter.convertArray(rules: rules, safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 1)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.loadContext, ["top-frame"])

        result = converter.convertArray(rules: rules, safariVersion: .safari14)
        XCTAssertEqual(result.safariRulesCount, 1)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertNil(decoded[0].trigger.loadContext)

        rules = ["@@||test.com^$subdocument,domain=example.com"]
        result = converter.convertArray(rules: rules, safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 1)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.loadContext, ["child-frame"])

        rules = [
            "||ya.ru^",
            "||ya.ru",
            "@@||test.com",
            "||example1.org^$domain=test.com",
            "||example2.org^$domain=~test.com",
            "||example3.org^$document",
            "||example4.org^$image",
            "||example5.org^$~image,third-party",
            "@@||example.org^$document",
            "test1.com###banner"
        ]
        result = converter.convertArray(rules: rules, safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 10)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 10)
        decoded.forEach {
            XCTAssertNil($0.trigger.loadContext)
        }
    }

    func testResourceTypeForVariousSafariVersions() {
        // Safari 15
        var result = converter.convertArray(rules: ["||miner.pr0gramm.com^$websocket"], safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 1)

        var decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.resourceType, ["websocket"])

        // Safari 14
        result = converter.convertArray(rules: ["||miner.pr0gramm.com^$websocket"], safariVersion: .safari14)
        XCTAssertEqual(result.safariRulesCount, 1)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.resourceType, ["raw"])

        // test default safari version
        result = converter.convertArray(rules: ["||miner.pr0gramm.com^$websocket"])
        XCTAssertEqual(result.safariRulesCount, 1)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.resourceType, ["raw"])

        // Safari 15
        result = converter.convertArray(rules: ["||miner.pr0gramm.com^$xmlhttprequest"], safariVersion: .safari15);
        XCTAssertEqual(result.safariRulesCount, 1)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.resourceType, ["fetch"])

        // Safari 14
        result = converter.convertArray(rules: ["||miner.pr0gramm.com^$xmlhttprequest"], safariVersion: .safari14)
        XCTAssertEqual(result.safariRulesCount, 1)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.resourceType, ["raw"])

        // test default safari version
        result = converter.convertArray(rules: ["||miner.pr0gramm.com^$xmlhttprequest"])
        XCTAssertEqual(result.safariRulesCount, 1)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.resourceType, ["raw"])
    }

    func testCreateInvertedAllowlistRule() {
        var rules = ["test.com"]
        var result = ContentBlockerConverter.createInvertedAllowlistRule(by: rules)
        XCTAssertEqual(result, "@@||*$document,domain=~test.com")

        rules = ["test1.com", "test2.com", "test3.com"]
        result = ContentBlockerConverter.createInvertedAllowlistRule(by: rules)
        XCTAssertEqual(result, "@@||*$document,domain=~test1.com|~test2.com|~test3.com")

        rules = ["", "test1.com", "", "test2.com", ""]
        result = ContentBlockerConverter.createInvertedAllowlistRule(by: rules)
        XCTAssertEqual(result, "@@||*$document,domain=~test1.com|~test2.com")

        rules = [""]
        result = ContentBlockerConverter.createInvertedAllowlistRule(by: rules)
        XCTAssertNil(result)

        rules = ["", "", ""]
        result = ContentBlockerConverter.createInvertedAllowlistRule(by: rules)
        XCTAssertNil(result)

        rules = []
        result = ContentBlockerConverter.createInvertedAllowlistRule(by: rules)
        XCTAssertNil(result)
    }

    func testBlockingRuleValidation() {
        var result = converter.convertArray(rules: ["/cookie-law-$~script"], safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 1)
        var decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.resourceType?.contains("script"), false)

        result = converter.convertArray(rules: ["/cookie-law-$script"])
        XCTAssertEqual(result.safariRulesCount, 1)
        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.resourceType?.contains("script"), true)

        result = converter.convertArray(rules: ["/cookie-law-$script,~third-party"])
        XCTAssertEqual(result.safariRulesCount, 1)
        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.resourceType?.contains("script"), true)

        result = converter.convertArray(rules: ["/cookie-law-$script,subdocument,~third-party,domain=test.com"])
        XCTAssertEqual(result.safariRulesCount, 1)
        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.resourceType?.contains("script"), true)

        result = converter.convertArray(rules: ["/cookie-law-$image"], safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 1)
        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.resourceType?.contains("image"), true)

        result = converter.convertArray(rules: ["/cookie-law-$image,domain=test.com"], safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 1)
        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.resourceType?.contains("image"), true)

        result = converter.convertArray(rules: ["/cookie-law-$~ping"], safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 1)
        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.resourceType?.contains("ping"), false)
    }

    func testInvalidRules() {
        var result = converter.convertArray(rules: ["zz"], safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 1)
        XCTAssertEqual(result.safariRulesJSON, ConversionResult.EMPTY_RESULT_JSON)

        // The rules will not be considered cosmetic
        result = converter.convertArray(rules: ["example.org##", "example.org#@#"], safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 2)
        XCTAssertEqual(result.safariRulesJSON, ConversionResult.EMPTY_RESULT_JSON)

        result = converter.convertArray(rules: ["", "", "", ""], safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.safariRulesJSON, ConversionResult.EMPTY_RESULT_JSON)

        result = converter.convertArray(rules: [], safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.safariRulesJSON, ConversionResult.EMPTY_RESULT_JSON)

        result = converter.convertArray(rules: ["test.com#%#", "test.com#@%#"], safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 2)
        XCTAssertEqual(result.safariRulesJSON, ConversionResult.EMPTY_RESULT_JSON)

        result = converter.convertArray(rules: ["example.org#%#//scriptlet()"], safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 1)
        XCTAssertEqual(result.safariRulesJSON, ConversionResult.EMPTY_RESULT_JSON)

        result = converter.convertArray(rules: ["example.org#%#", "example.org#@%#"], safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 2)
        XCTAssertEqual(result.safariRulesJSON, ConversionResult.EMPTY_RESULT_JSON)
    }

    func testProblematicRules() {
        var rules = [
            "facebook.com##div[role=\"feed\"] div[style=\"border-radius: max(0px, min(8px, ((100vw - 4px) - 100%) * 9999)) / 8px;\"] div[style=\"border-radius: max(0px, min(8px, ((100vw - 4px) - 100%) * 9999)) / 8px;\"]",
            "hdpass.net#%#AG_onLoad(function() {setTimeout(function() {function clearify(url) {         var size = url.length;         if (size % 2 == 0) {             var halfIndex = size / 2;             var firstHalf = url.substring(0, halfIndex);             var secondHalf = url.substring(halfIndex, size);             var url = secondHalf + firstHalf;             var base = url.split(\"\").reverse().join(\"\");             var clearText = $.base64('decode', base);             return clearText         } else {             var lastChar = url[size - 1];             url[size - 1] = ' ';             url = $.trim(url);             var newSize = url.length;             var halfIndex = newSize / 2;             var firstHalf = url.substring(0, halfIndex);             var secondHalf = url.substring(halfIndex, newSize);             url = secondHalf + firstHalf;             var base = url.split(\"\").reverse().join(\"\");             base = base + lastChar;             var clearText = $.base64('decode', base);             return clearText         }     }  var urlEmbed = $('#urlEmbed').val(); urlEmbed = clearify(urlEmbed); var iframe = '<iframe width=\"100%\" height=\"100%\" src=\"' + urlEmbed + '\" frameborder=\"0\" scrolling=\"no\" allowfullscreen />'; $('#playerFront').html(iframe); }, 300); });",
            "allegro.pl##div[data-box-name=\"banner - cmuid\"][data-prototype-id=\"allegro.advertisement.slot.banner\"]",
            "msn.com#%#AG_onLoad(function() { setTimeout(function() { var el = document.querySelectorAll(\".todaystripe .swipenav > li\"); if(el) { for(i=0;i<el.length;i++) { el[i].setAttribute(\"data-aop\", \"slide\" + i + \">single\"); var data = el[i].getAttribute(\"data-id\"); el[i].setAttribute(\"data-m\", ' {\"i\":' + data + ',\"p\":115,\"n\":\"single\",\"y\":8,\"o\":' + i + '} ')}; var count = document.querySelectorAll(\".todaystripe .infopane-placeholder .slidecount span\"); var diff = count.length - el.length; while(diff > 0) { var count_length = count.length; count[count_length-1].remove(); var count = document.querySelectorAll(\".todaystripe .infopane-placeholder .slidecount span\"); var diff = count.length - el.length; } } }, 300); });",
            "abplive.com#?#.articlepage > .center_block:has(> p:contains(- - Advertisement - -))",
        ]
        var result = converter.convertArray(rules: rules, safariVersion: .safari15, advancedBlocking: true)
        XCTAssertEqual(result.sourceRulesCount, rules.count)
        XCTAssertEqual(result.sourceSafariCompatibleRulesCount, rules.count)
        XCTAssertEqual(result.safariRulesCount, rules.count)
        XCTAssertEqual(result.errorsCount, 0)

        rules = [
            "facebook.com##div[role=\"region\"] + div[role=\"main\"] div[role=\"article\"] div[style=\"border-radius: max(0px, min(8px, ((100vw - 4px) - 100%) * 9999)) / 8px;\"] > div[class]:not([class*=\" \"])",
        ]
        result = converter.convertArray(rules: rules, safariVersion: .safari15, advancedBlocking: true)
        XCTAssertEqual(result.sourceRulesCount, rules.count)
        XCTAssertEqual(result.sourceSafariCompatibleRulesCount, rules.count)
        XCTAssertEqual(result.safariRulesCount, rules.count)
        XCTAssertEqual(result.errorsCount, 0)
    }

    func testCosmeticRulesWithPathModifier() {
        var rules = ["[$path=page.html]##.textad"]
        var result = converter.convertArray(rules: rules)
        XCTAssertEqual(result.sourceRulesCount, 1)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        var decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*page\\.html")
        XCTAssertNil(decoded[0].trigger.ifDomain)
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, ".textad")

        rules = ["[$path=/page.html]test.com##.textad"]
        result = converter.convertArray(rules: rules)
        XCTAssertEqual(result.sourceRulesCount, 1)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*\\/page\\.html")
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*test.com"])
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, ".textad")

        rules = ["[$path=/page.html,domain=example.org|test.com]##.textad"]
        result = converter.convertArray(rules: rules)
        XCTAssertEqual(result.sourceRulesCount, 1)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*\\/page\\.html")
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org", "*test.com"])
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, ".textad")

        rules = ["[$domain=example.org,path=/page.html]##.textad"]
        result = converter.convertArray(rules: rules)
        XCTAssertEqual(result.sourceRulesCount, 1)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*\\/page\\.html")
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org"])
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, ".textad")

        rules = ["[$domain=example.org|test.com,path=/page.html]website.com##.textad"]
        result = converter.convertArray(rules: rules)
        XCTAssertEqual(result.sourceRulesCount, 1)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*\\/page\\.html")
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org", "*test.com", "*website.com"])
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, ".textad")

        rules = ["[$path=/page*.html]##.textad"]
        result = converter.convertArray(rules: rules)
        XCTAssertEqual(result.sourceRulesCount, 1)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*\\/page.*\\.html")
        XCTAssertNil(decoded[0].trigger.ifDomain)
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, ".textad")

        rules = ["[$path=/\\/sub\\/.*\\/page\\.html/]##.textad"]
        result = converter.convertArray(rules: rules)
        XCTAssertEqual(result.sourceRulesCount, 1)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*\\/sub\\/.*\\/page\\.html")
        XCTAssertNil(decoded[0].trigger.ifDomain)
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, ".textad")

        // Supported regex in path
        rules = ["[$path=/^\\/$/]##.textad"]
        result = converter.convertArray(rules: rules)
        XCTAssertEqual(result.sourceRulesCount, 1)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertEqual(decoded[0].trigger.urlFilter, "^(https?:\\/\\/)([^\\/]+)\\/$")
        XCTAssertNil(decoded[0].trigger.ifDomain)
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, ".textad")

        // Not supported regex in $path.
        rules = ["[$path=/\\/(sub1|sub2)\\/page\\.html/]##.textad"]
        result = converter.convertArray(rules: rules)
        XCTAssertEqual(result.sourceRulesCount, 0)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 1)
        XCTAssertEqual(result.safariRulesJSON, ConversionResult.EMPTY_RESULT_JSON)
    }

    // TODO(ameshkov): !!! Restore test
    //    func testAdvancedCosmeticRulesWithPathModifier() {
    //        var rules = ["[$path=page.html]#$#.textad { visibility: hidden }"];
    //        var result = converter.convertArray(rules: rules, advancedBlocking: true);
    //        XCTAssertEqual(result.convertedCount, 0);
    //        XCTAssertEqual(result.advancedBlockingConvertedCount, 1);
    //        XCTAssertEqual(result.totalConvertedCount, 1);
    //        XCTAssertEqual(result.errorsCount, 0);
    //
    //        var decoded = try! parseJsonString(json: result.advancedBlocking!);
    //        XCTAssertEqual(decoded.count, 1);
    //
    //        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*page\\.html");
    //        XCTAssertNil(decoded[0].trigger.ifDomain);
    //        XCTAssertEqual(decoded[0].action.type, "css-inject");
    //        XCTAssertEqual(decoded[0].action.css, ".textad { visibility: hidden }");
    //
    //        rules = ["[$path=/page.html]test.com#?#div:has(.textad)"];
    //        result = converter.convertArray(rules: rules, advancedBlocking: true);
    //        XCTAssertEqual(result.convertedCount, 0);
    //        XCTAssertEqual(result.advancedBlockingConvertedCount, 1);
    //        XCTAssertEqual(result.totalConvertedCount, 1);
    //        XCTAssertEqual(result.errorsCount, 0);
    //
    //        decoded = try! parseJsonString(json: result.advancedBlocking!);
    //        XCTAssertEqual(decoded.count, 1);
    //
    //        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*\\/page\\.html");
    //        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*test.com"]);
    //        XCTAssertEqual(decoded[0].action.type, "css-extended");
    //        XCTAssertEqual(decoded[0].action.css, "div:has(.textad)");
    //
    //        rules = ["[$path=/\\/тест\\/.*\\/page\\.html/]##.textad"];
    //        result = converter.convertArray(rules: rules);
    //        XCTAssertEqual(result.convertedCount, 0);
    //        XCTAssertEqual(result.totalConvertedCount, 0);
    //        XCTAssertEqual(result.errorsCount, 1);
    //        XCTAssertEqual(result.converted, ConversionResult.EMPTY_RESULT_JSON);
    //
    //        rules = ["[$path=/^\\/test\\/$/]example.org##.classname"]
    //        result = converter.convertArray(rules: rules)
    //        XCTAssertEqual(result.convertedCount, 1)
    //        XCTAssertEqual(result.errorsCount, 0)
    //
    //        decoded = try! parseJsonString(json: result.converted);
    //        XCTAssertEqual(decoded.count, 1);
    //        let urlFilter = decoded[0].trigger.urlFilter;
    //        XCTAssertEqual(urlFilter, "^(https?:\\/\\/)([^\\/]+)\\/test\\/$");
    //    }

    // TODO(ameshkov): !!! Restore test
    //    func testAdvancedCosmeticRulesWithDomainModifier() {
    //        var rules = ["[$domain=mail.ru,path=/^\\/$/]#?#.toolbar:has(> div.toolbar__inner > div.toolbar__aside > span.toolbar__close)"]
    //        var result = converter.convertArray(rules: rules, advancedBlocking: true)
    //        XCTAssertEqual(result.advancedBlockingConvertedCount, 1)
    //        XCTAssertEqual(result.totalConvertedCount, 1)
    //        XCTAssertEqual(result.errorsCount, 0)
    //
    //        var decoded = try! parseJsonString(json: result.advancedBlocking!);
    //        XCTAssertEqual(decoded.count, 1);
    //        var ifDomain = decoded[0].trigger.ifDomain;
    //        XCTAssertEqual(ifDomain, ["*mail.ru"])
    //        var urlFilter = decoded[0].trigger.urlFilter
    //        XCTAssertEqual(urlFilter, "^(https?:\\/\\/)([^\\/]+)/$")
    //        XCTAssertEqual(decoded[0].action.type, "css-extended")
    //        var css = decoded[0].action.css
    //        XCTAssertEqual(css, ".toolbar:has(> div.toolbar__inner > div.toolbar__aside > span.toolbar__close)")
    //
    //        rules = ["[$domain=mail.ru,path=/^\\/$/]#?#div[data-testid=\"pulse-row\"] > div[data-testid=\"pulse-card\"] div[class*=\"_\"] > input[name=\"email\"]:upward(div[data-testid=\"pulse-card\"])"]
    //        result = converter.convertArray(rules: rules, advancedBlocking: true)
    //        XCTAssertEqual(result.advancedBlockingConvertedCount, 1)
    //        XCTAssertEqual(result.totalConvertedCount, 1)
    //        XCTAssertEqual(result.errorsCount, 0)
    //
    //        decoded = try! parseJsonString(json: result.advancedBlocking!);
    //        XCTAssertEqual(decoded.count, 1);
    //        ifDomain = decoded[0].trigger.ifDomain;
    //        XCTAssertEqual(ifDomain, ["*mail.ru"]);
    //        urlFilter = decoded[0].trigger.urlFilter;
    //        XCTAssertEqual(urlFilter, "^(https?:\\/\\/)([^\\/]+)/$");
    //
    //        rules = ["[$domain=facebook.com,path=/gaming]#$#body > .AdBox.Ad.advert ~ div[class] { display: block !important; }"]
    //        result = converter.convertArray(rules: rules, advancedBlocking: true)
    //        XCTAssertEqual(result.advancedBlockingConvertedCount, 1)
    //        XCTAssertEqual(result.totalConvertedCount, 1)
    //        XCTAssertEqual(result.errorsCount, 0)
    //
    //        decoded = try! parseJsonString(json: result.advancedBlocking!);
    //        XCTAssertEqual(decoded.count, 1);
    //        ifDomain = decoded[0].trigger.ifDomain;
    //        XCTAssertEqual(ifDomain, ["*facebook.com"]);
    //        urlFilter = decoded[0].trigger.urlFilter;
    //        XCTAssertEqual(urlFilter, ".*\\/gaming");
    //        XCTAssertEqual(decoded[0].action.type, "css-inject");
    //        css = decoded[0].action.css;
    //        XCTAssertEqual(css, "body > .AdBox.Ad.advert ~ div[class] { display: block !important; }");
    //
    //        rules = ["[$domain=facebook.com,path=/gaming]#$#body > .AdBox.Ad.advert { display: block !important; }"]
    //        result = converter.convertArray(rules: rules, advancedBlocking: true)
    //        XCTAssertEqual(result.advancedBlockingConvertedCount, 1)
    //        XCTAssertEqual(result.totalConvertedCount, 1)
    //        XCTAssertEqual(result.errorsCount, 0)
    //
    //        decoded = try! parseJsonString(json: result.advancedBlocking!);
    //        XCTAssertEqual(decoded.count, 1);
    //        ifDomain = decoded[0].trigger.ifDomain;
    //        XCTAssertEqual(ifDomain, ["*facebook.com"]);
    //        urlFilter = decoded[0].trigger.urlFilter;
    //        XCTAssertEqual(urlFilter, ".*\\/gaming");
    //        XCTAssertEqual(decoded[0].action.type, "css-inject");
    //        css = decoded[0].action.css;
    //        XCTAssertEqual(css, "body > .AdBox.Ad.advert { display: block !important; }");
    //
    //        rules = ["[$domain=lifebursa.com,path=/^\\/$/]#?#.container > div.row:has(> div[class^=\"col-\"] > div.banner)"]
    //        result = converter.convertArray(rules: rules, advancedBlocking: true)
    //        XCTAssertEqual(result.advancedBlockingConvertedCount, 1)
    //        XCTAssertEqual(result.totalConvertedCount, 1)
    //        XCTAssertEqual(result.errorsCount, 0)
    //
    //        decoded = try! parseJsonString(json: result.advancedBlocking!);
    //        XCTAssertEqual(decoded.count, 1);
    //        ifDomain = decoded[0].trigger.ifDomain;
    //        XCTAssertEqual(ifDomain, ["*lifebursa.com"]);
    //        urlFilter = decoded[0].trigger.urlFilter;
    //        XCTAssertEqual(urlFilter, "^(https?:\\/\\/)([^\\/]+)/$");
    //        XCTAssertEqual(decoded[0].action.type, "css-extended");
    //        css = decoded[0].action.css;
    //        XCTAssertEqual(css, ".container > div.row:has(> div[class^=\"col-\"] > div.banner)");
    //    }

    func testUnicodeRules() {
        let rules = [
            "example.org#$#simulate-event-poc click 'xpath(//*[text()=\"ได้รับการโปรโมท\"]')",
            "||ได้รับการโปรโมท.com^",
            "ได้รับการโปรโมท.com##banner",
            "||example.org^$domain=ได้รับการโปรโมท.com"
        ]
        let result = converter.convertArray(rules: rules, safariVersion: .safari15, advancedBlocking: true)
        XCTAssertEqual(result.sourceRulesCount, rules.count)
        XCTAssertEqual(result.safariRulesCount, rules.count)
        XCTAssertEqual(result.errorsCount, 0)
    }

    func testBlockingRulesWithNonAsciiCharacters() {
        var rules = ["||example.org$domain=/реклама\\.рф/"]
        var result = converter.convertArray(rules: rules)
        XCTAssertEqual(result.sourceRulesCount, 1)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        let decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertEqual(decoded[0].trigger.urlFilter, "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org")
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*xn--/\\-7kcax4ahj5a.xn--/-4tbm"])
        XCTAssertEqual(decoded[0].action.type, "block")

        rules = ["/тест-регексп/$domain=/test\\.com/"]
        result = converter.convertArray(rules: rules)
        XCTAssertEqual(result.safariRulesCount, 0)
        XCTAssertEqual(result.errorsCount, 1)
        XCTAssertEqual(result.safariRulesJSON, ConversionResult.EMPTY_RESULT_JSON)
    }

    func testNetworkExceptionRulesWithConvertedOptions() {
        var rules = ["@@||example.org/*/test.js$1p"]
        var result = converter.convertArray(rules: rules)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        var decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.loadType, ["first-party"])
        XCTAssertEqual(decoded[0].action.type, "ignore-previous-rules")

        rules = ["@@||example.org/*/test.js$3p"]
        result = converter.convertArray(rules: rules)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.loadType, ["third-party"])
        XCTAssertEqual(decoded[0].action.type, "ignore-previous-rules")
    }

    // TODO(ameshkov): !!! Restore test
    //    func testConvertRulesWithPseudoClassHas() {
    //        let rules = [
    //            "test.com##div:has(.banner)",
    //            "example.org#?#div:has(.adv)",
    //        ]
    //
    //        var result = converter.convertArray(rules: rules, safariVersion: .safari15, advancedBlocking: true)
    //        XCTAssertEqual(result.convertedCount, 0)
    //        XCTAssertEqual(result.advancedBlockingConvertedCount, 2)
    //        XCTAssertEqual(result.totalConvertedCount, 2)
    //        XCTAssertEqual(result.errorsCount, 0)
    //
    //        let decoded = try! parseJsonString(json: result.advancedBlocking!);
    //        XCTAssertEqual(decoded.count, 2);
    //
    //        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*test.com"]);
    //        XCTAssertEqual(decoded[0].action.type, "css-extended");
    //        XCTAssertEqual(decoded[0].action.css, "div:has(.banner)");
    //
    //        XCTAssertEqual(decoded[1].trigger.ifDomain, ["*example.org"]);
    //        XCTAssertEqual(decoded[1].action.type, "css-extended");
    //        XCTAssertEqual(decoded[1].action.css, "div:has(.adv)");
    //
    //        result = converter.convertArray(rules: rules, safariVersion: .safari16_4, advancedBlocking: true)
    //        XCTAssertEqual(result.convertedCount, 1)
    //        XCTAssertEqual(result.advancedBlockingConvertedCount, 1)
    //        XCTAssertEqual(result.totalConvertedCount, 2)
    //        XCTAssertEqual(result.errorsCount, 0)
    //
    //        let decodedSimpleRules = try! parseJsonString(json: result.converted);
    //        XCTAssertEqual(decodedSimpleRules.count, 1);
    //        XCTAssertEqual(decodedSimpleRules[0].trigger.ifDomain, ["*test.com"]);
    //        XCTAssertEqual(decodedSimpleRules[0].action.type, "css-display-none");
    //        XCTAssertEqual(decodedSimpleRules[0].action.selector, "div:has(.banner)");
    //
    //        let decodedAdvancedRules = try! parseJsonString(json: result.advancedBlocking!);
    //        XCTAssertEqual(decodedAdvancedRules.count, 1);
    //        XCTAssertEqual(decodedAdvancedRules[0].trigger.ifDomain, ["*example.org"]);
    //        XCTAssertEqual(decodedAdvancedRules[0].action.type, "css-extended");
    //        XCTAssertEqual(decodedAdvancedRules[0].action.css, "div:has(.adv)");
    //    }

    func testConvertRulesWithPseudoClassIs() {
        let rules = [
            "##:is(.test1, .test2)",
            "example.org###adv:is(.test1, .test2)",
        ]

        // converts as cosmetic rule for Safari 14
        let result = converter.convertArray(rules: rules, safariVersion: .safari14, advancedBlocking: true)
        XCTAssertEqual(result.safariRulesCount, 2)
        XCTAssertEqual(result.advancedRulesCount, 0)
        XCTAssertEqual(result.sourceRulesCount, 2)
        XCTAssertEqual(result.errorsCount, 0)
    }

    // TODO(ameshkov): !!! Restore test
    //    func testXpathRules() {
    //        let rules = [
    //            "test.com#?#:xpath(//div[@data-st-area='Advert'])",
    //            "example.org##:xpath(//div[@id='stream_pagelet'])",
    //            "example.com##:xpath(//div[@id='adv'])",
    //            "example.com#@#:xpath(//div[@id='adv'])",
    //        ]
    //        let result = converter.convertArray(rules: rules, safariVersion: .safari15, advancedBlocking: true)
    //        XCTAssertEqual(result.convertedCount, 0)
    //        XCTAssertEqual(result.advancedBlockingConvertedCount, 2)
    //        XCTAssertEqual(result.totalConvertedCount, 2)
    //        XCTAssertEqual(result.errorsCount, 0)
    //
    //        let decoded = try! parseJsonString(json: result.advancedBlocking!);
    //        XCTAssertEqual(decoded.count, 2);
    //
    //        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*test.com"])
    //        XCTAssertEqual(decoded[0].action.type, "css-extended")
    //        XCTAssertEqual(decoded[0].action.css, ":xpath(//div[@data-st-area='Advert'])")
    //
    //        XCTAssertEqual(decoded[1].trigger.ifDomain, ["*example.org"])
    //        XCTAssertEqual(decoded[1].action.type, "css-extended")
    //        XCTAssertEqual(decoded[1].action.css, ":xpath(//div[@id='stream_pagelet'])")
    //    }

    func testApplyMultidomainCosmeticExclusions() {
        var rules = [
            "test.com,example.org###banner",
            "example.org#@##banner",
        ]
        var result = converter.convertArray(rules: rules, safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.sourceSafariCompatibleRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        var decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*test.com"])
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, "#banner")

        rules = [
            "test.com,example.org###banner",
            "example.com,example.org#@##banner",
        ]
        result = converter.convertArray(rules: rules, safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.sourceSafariCompatibleRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*test.com"])
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, "#banner")

        rules = [
            "test1.com,example.org,test2.com###banner",
            "example.com,example.org,test1.com#@##banner",
        ]
        result = converter.convertArray(rules: rules, safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.sourceSafariCompatibleRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*test2.com"])
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, "#banner")

        rules = [
            "test1.com,test2.com,test3.com###banner",
            "example1.org,example2.org###banner",
            "test1.com,example2.org#@##banner",
            "test2.com,example1.org#@##banner",
        ]
        result = converter.convertArray(rules: rules, safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesCount, 1)
        XCTAssertEqual(result.sourceSafariCompatibleRulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*test3.com"])
        XCTAssertEqual(decoded[0].action.type, "css-display-none")
        XCTAssertEqual(decoded[0].action.selector, "#banner")
    }

    // TODO(ameshkov): !!! Restore test
    //    func testApplyMultidomainAdvancedExclusions() {
    //        var rules = [
    //            "example.com,test.com#$##adv{visibility:hidden;}",
    //            "test.com#@$##adv{visibility:hidden;}",
    //        ]
    //        var result = converter.convertArray(rules: rules, safariVersion: .safari15, advancedBlocking: true)
    //        XCTAssertEqual(result.convertedCount, 0)
    //        XCTAssertEqual(result.advancedBlockingConvertedCount, 1)
    //        XCTAssertEqual(result.totalConvertedCount, 1)
    //        XCTAssertEqual(result.errorsCount, 0)
    //
    //        var decoded = try! parseJsonString(json: result.advancedBlocking!)
    //        XCTAssertEqual(decoded.count, 1)
    //        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.com"])
    //        XCTAssertEqual(decoded[0].action.type, "css-inject")
    //        XCTAssertEqual(decoded[0].action.css, "#adv{visibility:hidden;}")
    //
    //        rules = [
    //            "test.com,example.org#$##adv{visibility:hidden;}",
    //            "example.com,example.org#@$##adv{visibility:hidden;}",
    //        ]
    //        result = converter.convertArray(rules: rules, safariVersion: .safari15, advancedBlocking: true)
    //        XCTAssertEqual(result.convertedCount, 0)
    //        XCTAssertEqual(result.advancedBlockingConvertedCount, 1)
    //        XCTAssertEqual(result.totalConvertedCount, 1)
    //        XCTAssertEqual(result.errorsCount, 0)
    //
    //        decoded = try! parseJsonString(json: result.advancedBlocking!)
    //        XCTAssertEqual(decoded.count, 1)
    //        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*test.com"])
    //        XCTAssertEqual(decoded[0].action.type, "css-inject")
    //        XCTAssertEqual(decoded[0].action.css, "#adv{visibility:hidden;}")
    //
    //        rules = [
    //            "test.com,example.org#?#div:has(> a[target='_blank'])",
    //            "example.com,example.org#@?#div:has(> a[target='_blank'])",
    //        ]
    //        result = converter.convertArray(rules: rules, safariVersion: .safari15, advancedBlocking: true)
    //        XCTAssertEqual(result.convertedCount, 0)
    //        XCTAssertEqual(result.advancedBlockingConvertedCount, 1)
    //        XCTAssertEqual(result.totalConvertedCount, 1)
    //        XCTAssertEqual(result.errorsCount, 0)
    //
    //        decoded = try! parseJsonString(json: result.advancedBlocking!)
    //        XCTAssertEqual(decoded.count, 1)
    //        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*test.com"])
    //        XCTAssertEqual(decoded[0].action.type, "css-extended")
    //        XCTAssertEqual(decoded[0].action.css, "div:has(> a[target='_blank'])")
    //
    //        rules = [
    //            "example.org,test1.com,test2.com#%#window.adv_id = null;",
    //            "example.com,example.org,test1.com#@%#window.adv_id = null;",
    //        ]
    //        result = converter.convertArray(rules: rules, safariVersion: .safari15, advancedBlocking: true)
    //        XCTAssertEqual(result.convertedCount, 0)
    //        XCTAssertEqual(result.advancedBlockingConvertedCount, 1)
    //        XCTAssertEqual(result.totalConvertedCount, 1)
    //        XCTAssertEqual(result.errorsCount, 0)
    //
    //        decoded = try! parseJsonString(json: result.advancedBlocking!)
    //        XCTAssertEqual(decoded.count, 1)
    //        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*test2.com"])
    //        XCTAssertEqual(decoded[0].action.type, "script")
    //        XCTAssertEqual(decoded[0].action.script, "window.adv_id = null;")
    //    }

    func testExcludingRulesWithRegex() {
        var rules = ["||example.org$domain=/test\\.com/"]

        var result = converter.convertArray(rules: rules, safariVersion: .safari15)
        XCTAssertEqual(result.safariRulesJSON, ConversionResult.EMPTY_RESULT_JSON)

        rules = [
            "/example1\\.org/#%#alert('1');",
            "||example2.org$domain=/test2\\.com/",
            "||example3.org$domain=test3.com/",
            "/example4\\.org/##.adv"
        ]

        result = converter.convertArray(rules: rules, safariVersion: .safari15)
        let decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)

        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*test3.com/"])
        XCTAssertEqual(decoded[0].trigger.urlFilter, "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example3\\.org")
        XCTAssertEqual(decoded[0].action.type, "block")
    }

    func testMatchCase() {
        let rule = "eXamPle.com$match-case"
        let result = converter.convertArray(rules: [rule])
        let decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.caseSensitive, true)
        XCTAssertEqual(decoded[0].trigger.urlFilter, "eXamPle\\.com")
    }

    // Check if the JSON string is valid
    func isJSONValid(_ jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else { return false }
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [])
            return true
        } catch {
            print("Invalid JSON: \(error.localizedDescription)")
            return false
        }
    }

    func testMaxJsonSize() {
        let rules = [
            "||example1.org^",
            "||example2.com^$document",
            "example3.com##h1"
        ]

        func performTest(withLimit limit: Int?, expectedCount: Int) {
            let result = converter.convertArray(
                rules: rules,
                advancedBlocking: false,
                maxJsonSizeBytes: limit
            )

            let jsonSize = result.safariRulesJSON.utf8.count
            if let limit = limit {
                XCTAssertLessThanOrEqual(jsonSize, limit, "The converted JSON size should be less than or equal to the limit")
            }
            XCTAssertEqual(result.safariRulesCount, expectedCount, "The converted count should match the expected count")
            XCTAssertTrue(isJSONValid(result.safariRulesJSON), "The converted JSON should be valid")
        }

        performTest(withLimit: 110, expectedCount: 0)  // Bigger than empty JSON, smaller for rules to fit
        performTest(withLimit: 150, expectedCount: 1)  // Enough for one rule
        performTest(withLimit: 300, expectedCount: 2)  // Enough for two rules
        performTest(withLimit: 1000, expectedCount: 3) // Enough for all rules
        performTest(withLimit: nil, expectedCount: 3)  // No limit
    }

}
