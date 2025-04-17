import XCTest

@testable import ContentBlockerConverter

final class ContentBlockerConverterTests: XCTestCase {
    func testConvertArrayEmptyOrComments() {
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
                rules: ["! just a comment", "! other comment"],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON
            ),
        ]

        runTests(testCases)
    }

    func testConvertArrayThirdParty() {
        let testCases: [TestCase] = [
            TestCase(
                rules: ["@@||example.org^$third-party"],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "type" : "ignore-previous-rules"
                        },
                        "trigger" : {
                          "load-type" : [
                            "third-party"
                          ],
                          "unless-domain" : [
                            "*example.org"
                          ],
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.org([\\\/:&\\?].*)?$"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
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
                // $1p modifier rules.
                rules: ["@@||example.org/*/test.js$1p"],
                version: SafariVersion.safari16_4,
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
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.org\\\/.*\\\/test\\.js"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $3p modifier rules.
                rules: ["@@||example.org/*/test.js$3p"],
                version: SafariVersion.safari16_4,
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "type" : "ignore-previous-rules"
                        },
                        "trigger" : {
                          "load-type" : [
                            "third-party"
                          ],
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.org\\\/.*\\\/test\\.js"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
        ]

        runTests(testCases)
    }

    func testConvertArrayDomainModifier() {
        let testCases: [TestCase] = [
            TestCase(
                // Check that $domain and its aliases are supported.
                rules: [
                    "||example.org^$domain=example.net",
                    "||example.org^$from=example.net",
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*example.net"
                          ],
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.org([\\\/:&\\?].*)?$"
                        }
                      },
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*example.net"
                          ],
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.org([\\\/:&\\?].*)?$"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            )
        ]

        runTests(testCases)
    }

    func testConvertArrayMatchCase() {
        let testCases: [TestCase] = [
            TestCase(
                rules: ["eXamPle.com$match-case"],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "url-filter" : "eXamPle\\.com",
                          "url-filter-is-case-sensitive" : true
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            )
        ]

        runTests(testCases)
    }

    func testConvertArrayDocumentRules() {
        let testCases: [TestCase] = [
            TestCase(
                rules: [
                    "||example1.com$document",
                    "||example2.com$document,popup",
                    "||example5.com$popup,document",
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
                // Convert $document rule in Safari 15.
                // Note, that load-context is not used here (we only use it for $subdocument).
                rules: [
                    "||example.net^$document",
                    "@@||example.org^$document",
                ],
                version: SafariVersion.safari15,
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
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.net([\\\/:&\\?].*)?$"
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
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            ),
        ]

        runTests(testCases)
    }

    func testConvertArrayUnsupportedModifiers() {
        let testCases: [TestCase] = [
            TestCase(
                // $network rules are not supported.
                rules: ["|127.0.0.1^$network"],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedErrorsCount: 1
            ),
            TestCase(
                // $csp rules are not supported.
                rules: ["||example.org^$csp=script-src none"],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedErrorsCount: 1
            ),
            TestCase(
                // $to is waiting until this is implemented (or not):
                // https://github.com/AdguardTeam/SafariConverterLib/issues/60
                rules: ["||example.com^$to=example.net"],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedErrorsCount: 1
            ),
            TestCase(
                // $strict-first-party is waiting until this is implemented:
                // https://github.com/AdguardTeam/SafariConverterLib/issues/64
                rules: ["||example.com^$strict-first-party"],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedErrorsCount: 1
            ),
            TestCase(
                // $strict-third-party is waiting until this is implemented:
                // https://github.com/AdguardTeam/SafariConverterLib/issues/65
                rules: ["||example.com^$strict-third-party"],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedErrorsCount: 1
            ),
            TestCase(
                // $cookie is waiting until this is implemented:
                // https://github.com/AdguardTeam/SafariConverterLib/issues/54
                rules: ["||example.com^$cookie=test"],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedErrorsCount: 1
            ),
            TestCase(
                // $domain modifier with regular expression are not supported.
                rules: [
                    "||example.com^$domain=/test\\.com/",
                    "[$domain=/test\\.com/]##.banner",
                ],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedErrorsCount: 2
            ),
        ]

        runTests(testCases)
    }

    func testConvertArrayWebsocket() {
        let testCases: [TestCase] = [
            TestCase(
                // $websocket conversion for old Safari versions.
                rules: ["||test.com^$websocket"],
                version: SafariVersion.safari13,
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
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $websocket conversion for old Safari versions.
                rules: ["$websocket,domain=123movies.is"],
                version: SafariVersion.safari13,
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
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $websocket conversion for old Safari versions.
                rules: [".rocks^$third-party,websocket"],
                version: SafariVersion.safari13,
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
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $websocket conversion for Safari 15+.
                rules: ["||test.com^$websocket"],
                version: SafariVersion.safari15,
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
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $~websocket conversion for Safari 15+.
                rules: ["||test.com^$~websocket,domain=example.org"],
                version: SafariVersion.safari15,
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
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // Convert $websocket rule in older Safari versions.
                // $websocket is converted to "raw" (even though it is not ideal),
                // but only for blocking rules.
                rules: [
                    "||example.org^$websocket",
                    "||example.com^$~websocket",
                ],
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
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.org([\\\/:&\\?].*)?$"
                        }
                      },
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "resource-type" : [
                            "image",
                            "style-sheet",
                            "script",
                            "media",
                            "raw",
                            "font",
                            "document"
                          ],
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.com([\\\/:&\\?].*)?$"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            ),
            TestCase(
                // Convert $websocket rule in Safari 15.
                // $websocket is converted to "websocket".
                rules: [
                    "||example.org^$websocket",
                    "||example.com^$~websocket",
                ],
                version: SafariVersion.safari15,
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
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.org([\\\/:&\\?].*)?$"
                        }
                      },
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
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
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.com([\\\/:&\\?].*)?$"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            ),
        ]

        runTests(testCases)
    }

    func testConvertArrayScriptModifier() {
        let testCases: [TestCase] = [
            TestCase(
                // $~script conversion for older Safari versions.
                rules: ["||test.com^$~script,domain=example.com"],
                version: SafariVersion.safari13,
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
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $~script conversion for newer Safari versions.
                rules: ["||test.com^$~script,domain=example.com"],
                version: SafariVersion.safari16_4,
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
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $third-party and "unless-domains" workaround for old Safari.
                rules: ["||test.com^$third-party"],
                version: SafariVersion.safari13,
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
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $third-party and "unless-domains" workaround is not required in newer Safari.
                rules: ["||test.com^$third-party"],
                version: SafariVersion.safari16_4,
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
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
        ]

        runTests(testCases)
    }

    func testConvertArraySubdocument() {
        let testCases: [TestCase] = [
            TestCase(
                // $subdocument without $third-party forbidden for old Safari versions.
                rules: ["||test.com^$subdocument,~third-party"],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedErrorsCount: 1
            ),
            TestCase(
                // $subdocument with $domain is allowed for old Safari versions.
                rules: ["||test.com^$subdocument,domain=example.com"],
                version: SafariVersion.safari13,
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
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $subdocument,first-party is allowed in newer Safari versions
                rules: ["||test.com^$subdocument,1p"],
                version: SafariVersion.safari16_4,
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
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $~subdocument in newer Safari versions changes load-context
                rules: ["||test.com^$~subdocument"],
                version: SafariVersion.safari16_4,
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
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
        ]

        runTests(testCases)
    }

    func testConvertArrayEmptyPattern() {
        let testCases: [TestCase] = [
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
            )
        ]

        runTests(testCases)
    }

    func testConvertArrayCosmeticExceptions() {
        let testCases: [TestCase] = [
            TestCase(
                // Convert whitelist element hiding rule.
                // Disable generic rule on several websites.
                rules: [
                    "##.banner",
                    "example.org,example.net#@#.banner",
                    "example.com#@#.banner",
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
                    "example.org#@#.banner",
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
                    "[$domain=example.org]##.banner",
                    "[$path=page.html]example.com##.banner",
                    "example.net##.banner",
                    "example.org##.banner",
                    "#@#.banner",
                ],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedSourceRulesCount: 5,
                expectedSourceSafariCompatibleRulesCount: 5,
                expectedSafariRulesCount: 0
            ),
            TestCase(
                // Convert whitelist element hiding rule.
                // Whitelist rule is discarded because of the mixed if-domain / unless-domain issue.
                rules: [
                    "example.net##.banner",
                    "example.org#@#.banner",
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
                // Keep 1 domain, remove the other.
                rules: [
                    "test.com,example.org###banner",
                    "example.org#@##banner",
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : "#banner",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*test.com"
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
                // Keep 1 domain, remove the other.
                rules: [
                    "test.com,example.org###banner",
                    "example.com,example.org#@##banner",
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : "#banner",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*test.com"
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
                // Keep 1 domain, remove 2 other domains.
                rules: [
                    "test1.com,example.org,test2.com###banner",
                    "example.com,example.org,test1.com#@##banner",
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : "#banner",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*test2.com"
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
                // Discard multiple rules.
                rules: [
                    "test1.com,test2.com,test3.com###banner",
                    "example1.org,example2.org###banner",
                    "test1.com,example2.org#@##banner",
                    "test2.com,example1.org#@##banner",
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : "#banner",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*test3.com"
                          ],
                          "url-filter" : ".*"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 4,
                expectedSourceSafariCompatibleRulesCount: 4,
                expectedSafariRulesCount: 1
            ),
        ]

        runTests(testCases)
    }

    func testConvertArrayExceptionRules() {
        let testCases: [TestCase] = [
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
            )
        ]

        runTests(testCases)
    }

    func testConvertArrayGenerichide() {
        let testCases: [TestCase] = [
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
                // $generichide rule, make sure that specific rules will be applied,
                // but generic rules will be disabled.
                rules: [
                    "@@||example.org^$generichide",
                    "##.generic",
                    "example.org##.specific",
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
        ]

        runTests(testCases)
    }

    func testConvertArrayElemhide() {
        let testCases: [TestCase] = [
            TestCase(
                // $elemhide rule, check that it disables all element hiding,
                // but does not unblock URL filtering.
                rules: [
                    "@@||example.org^$elemhide",
                    "##.generic",
                    "example.org##.specific",
                    "||example.org^",
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
            )
        ]

        runTests(testCases)
    }

    func testConvertArrayCompactCosmeticRules() {
        let testCases: [TestCase] = [
            TestCase(
                // Compacting multiple generic rules.
                rules: [
                    "###selector-one",
                    "###selector-two",
                    "###selector-three",
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : "#selector-one, #selector-two, #selector-three",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
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
                // Compacting multiple rules for the same domain to a single rule.
                rules: [
                    "example.org###selector-one",
                    "example.org###selector-two",
                    "example.org###selector-three",
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
                // Compacting multiple rules for the same domain to a single rule.
                // Rule with $path modifier should not be compacted.
                rules: [
                    "[$path=page.html]example.org###selector-one",
                    "[$domain=example.org]###selector-two",
                    "example.org###selector-three",
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : "#selector-one",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*example.org"
                          ],
                          "url-filter" : ".*page\\.html"
                        }
                      },
                      {
                        "action" : {
                          "selector" : "#selector-two, #selector-three",
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
                expectedSafariRulesCount: 2
            ),
        ]

        runTests(testCases)
    }

    func testConvertArrayPunycodeConversion() {
        let testCases: [TestCase] = [
            TestCase(
                // Rules with Cyrillic letters.
                rules: [
                    "меил.рф",
                    "||меил.рф",
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
                // Rules with different unicode letters.
                rules: [
                    "||ได้รับการโปรโมท.com^",
                    "ได้รับการโปรโมท.com##banner",
                    "||example.org^$domain=ได้รับการโปรโมท.com",
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : "banner",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*xn--12c1bkkg0bkcb9kna7qcr0f.com"
                          ],
                          "url-filter" : ".*"
                        }
                      },
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?xn--12c1bkkg0bkcb9kna7qcr0f\\.com([\\\/:&\\?].*)?$"
                        }
                      },
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*xn--12c1bkkg0bkcb9kna7qcr0f.com"
                          ],
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.org([\\\/:&\\?].*)?$"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 3,
                expectedSourceSafariCompatibleRulesCount: 3,
                expectedSafariRulesCount: 3
            ),
            TestCase(
                // Unicode in domain modifier.
                rules: [
                    "||example.org$domain=/реклама\\.рф/"
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*xn--\/\\-7kcax4ahj5a.xn--\/-4tbm"
                          ],
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.org"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
        ]

        runTests(testCases)
    }

    func testConvertArrayInvalidRegex() {
        let testCases: [TestCase] = [
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
                    #"/example{/"#,
                    // Digit range is not supported.
                    #"/([0-9]{1,3}\.){3}[0-9]{1,3}.\/proxy$/$script,websocket,third-party"#,
                ],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedSourceRulesCount: 5,
                expectedSourceSafariCompatibleRulesCount: 5,
                expectedSafariRulesCount: 0,
                expectedErrorsCount: 5
            ),
            TestCase(
                // Unicode in regex.
                rules: [
                    "/тест-регексп/$domain=/test\\.com/"
                ],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedSourceRulesCount: 0,
                expectedSourceSafariCompatibleRulesCount: 0,
                expectedSafariRulesCount: 0,
                expectedErrorsCount: 1
            ),
        ]

        runTests(testCases)
    }

    func testConvertArrayCSSPseudoClasses() {
        let testCases: [TestCase] = [
            TestCase(
                // CSS with pseudo-classes. Checking that validation works as expected.
                // Also, checks that the rules are compacted.
                rules: [
                    "###main > table.w3-table-all.notranslate:first-child > tbody > tr:nth-child(17) > td.notranslate:nth-child(2)",
                    "###:root div.ads",
                    "###body div[attr='test']:first-child  div",
                    "##.todaystripe::after",
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
            )
        ]

        runTests(testCases)
    }

    func testConvertArrayRulesPriority() {
        let testCases: [TestCase] = [
            TestCase(
                // Test that exception rules unblock regular rules.
                rules: [
                    "||example.org^",
                    "@@/test",
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
                    "@@/test",
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
                    "@@/test$important",
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
                    "@@/test$document",
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

        runTests(testCases)
    }

    func testConvertArrayBadfilterRules() {
        let testCases: [TestCase] = [
            TestCase(
                // Test $badfilter rules.
                rules: [
                    "||example.org^$image",
                    "||test.org^",
                    "||example.org^$badfilter,image",
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?test\\.org([\\\/:&\\?].*)?$"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 3,
                expectedSourceSafariCompatibleRulesCount: 3,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // Test $badfilter rules with domain restrictions.
                rules: [
                    "*$domain=test1.com,third-party,important",
                    "*$domain=test2.com,important",
                    "*$domain=bad1.com,third-party,important",
                    "*$domain=bad2.com|google.com,third-party,important",
                    "*$domain=bad1.com|bad2.com|lenta.ru,third-party,important",
                    "*$domain=bad2.com|bad1.com,third-party,important",
                    "*$domain=bad1.com|bad2.com,third-party,important,badfilter",
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*test1.com"
                          ],
                          "load-type" : [
                            "third-party"
                          ],
                          "url-filter" : ".*"
                        }
                      },
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*test2.com"
                          ],
                          "url-filter" : ".*"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 7,
                expectedSourceSafariCompatibleRulesCount: 7,
                expectedSafariRulesCount: 2
            ),
        ]

        runTests(testCases)
    }

    func testConvertArrayUBOConversion() {
        let testCases: [TestCase] = [
            TestCase(
                // Test uBO scriptlet rules conversion
                rules: [
                    "example.org##+js(aopr,__cad.cpm_popunder)",
                    "example.org##+js(acis,setTimeout,testad)",
                ],
                advancedBlocking: true,
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedAdvancedRulesText: [
                    #"example.org#%#//scriptlet("ubo-aopr", "__cad.cpm_popunder")"#,
                    #"example.org#%#//scriptlet("ubo-acis", "setTimeout", "testad")"#,
                ].joined(separator: "\n"),
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 0,
                expectedSafariRulesCount: 0,
                expectedAdvancedRulesCount: 2
            )
        ]

        runTests(testCases)
    }

    func testConvertArrayCSSInjection() {
        let testCases: [TestCase] = [
            TestCase(
                // Test CSS injection rules.
                rules: [
                    "#$?#div:has(> .banner) { display: none; debug: global; }",
                    "google.com#$##js-header, #searchform, .O-j-k, .header:not(.column-section):not(.viewed):not(.ng-star-inserted):not([class*=\"_ngcontent\"]), .js-header.chr-header, .mobile-action-bar, body > .ng-scope, #flt-nav, .gws-flights__scrollbar-padding.gws-flights__selection-bar, .gws-flights__selection-bar-shadow-mask { position: absolute !important; }",
                ],
                advancedBlocking: true,
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedAdvancedRulesText: [
                    #"#$?#div:has(> .banner) { display: none; debug: global; }"#,
                    "google.com#$##js-header, #searchform, .O-j-k, .header:not(.column-section):not(.viewed):not(.ng-star-inserted):not([class*=\"_ngcontent\"]), .js-header.chr-header, .mobile-action-bar, body > .ng-scope, #flt-nav, .gws-flights__scrollbar-padding.gws-flights__selection-bar, .gws-flights__selection-bar-shadow-mask { position: absolute !important; }",
                ].joined(separator: "\n"),
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 0,
                expectedSafariRulesCount: 0,
                expectedAdvancedRulesCount: 2
            )
        ]

        runTests(testCases)
    }

    func testConvertArrayPatternWithSpecialCharacters() {
        let testCases: [TestCase] = [
            TestCase(
                // Test escaping special characters.
                rules: [
                    "+Popunder+$popup",
                    "||calabriareportage.it^+-Banner-",
                    #"@@/:\/\/.*[.]wp[.]pl\/[a-z0-9_]+[.][a-z]+\\/"#,
                    #"/\\/"#,
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
                          "url-filter" : "\\+Popunder\\+"
                        }
                      },
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?calabriareportage\\.it[\/:&?]?\\+-Banner-"
                        }
                      },
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "url-filter" : "\\\\"
                        }
                      },
                      {
                        "action" : {
                          "type" : "ignore-previous-rules"
                        },
                        "trigger" : {
                          "url-filter" : ":\\\/\\\/.*[.]wp[.]pl\\\/[a-z0-9_]+[.][a-z]+\\\\"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 4,
                expectedSourceSafariCompatibleRulesCount: 4,
                expectedSafariRulesCount: 4
            ),
            TestCase(
                // Test that backslash is properly escaped.
                rules: [
                    "||gamer.no/?module=Tumedia\\DFProxy\\Modules^",
                    "/g\\.alicdn\\.com\\/mm\\/yksdk\\/0\\.2\\.\\d+\\/playersdk\\.js/>>>1111.51xiaolu.com/playersdk.js>>>>keyword=playersdk",
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?gamer\\.no\\\/\\?module=Tumedia\\\\DFProxy\\\\Modules([\\\/:&\\?].*)?$"
                        }
                      },
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "url-filter" : "\\\/g\\\\\\.alicdn\\\\\\.com\\\\\\\/mm\\\\\\\/yksdk\\\\\\\/0\\\\\\.2\\\\\\.\\\\d\\+\\\\\\\/playersdk\\\\\\.js\\\/>>>1111\\.51xiaolu\\.com\\\/playersdk\\.js>>>>keyword=playersdk"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            ),
        ]

        runTests(testCases)
    }

    func testConvertArraySpecifichide() {
        let testCases: [TestCase] = [
            TestCase(
                // Test $specifichide modifier rules.
                // Filters out all specific CSS rules for example.org.
                rules: [
                    "example.org##.banner1",
                    "example.org,test.com##.banner2",
                    "##.banner3",
                    "@@||example.org^$specifichide",
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : ".banner3",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "url-filter" : ".*"
                        }
                      },
                      {
                        "action" : {
                          "selector" : ".banner2",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*test.com"
                          ],
                          "url-filter" : ".*"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 4,
                expectedSourceSafariCompatibleRulesCount: 4,
                expectedSafariRulesCount: 2
            ),
            TestCase(
                // Test $specifichide modifier rules.
                // Filters out all specific CSS rules for subdomain.test.com,
                // but does not filter out test.com.
                rules: [
                    "subdomain.test.com##.banner",
                    "test.com##.headeads",
                    "##.ad-banner",
                    "@@||subdomain.test.com^$specifichide",
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : ".ad-banner",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "url-filter" : ".*"
                        }
                      },
                      {
                        "action" : {
                          "selector" : ".headeads",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*test.com"
                          ],
                          "url-filter" : ".*"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 4,
                expectedSourceSafariCompatibleRulesCount: 4,
                expectedSafariRulesCount: 2
            ),
            TestCase(
                // Test $specifichide modifier rules.
                // Filters out two domains, but keeps the one that was not affected by $specifichide.
                rules: [
                    "example1.org,example2.org,example3.org##.banner1",
                    "@@||example1.org^$specifichide",
                    "@@||example2.org^$specifichide",
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : ".banner1",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*example3.org"
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
                // Test $specifichide with advanced rules.
                // The rule should be applied to Safari JSON and kept in the
                // list of advanced rules to be evaluated later.
                rules: [
                    "test.com,example.org#$#body { overflow: visible!important; }",
                    "##.banner",
                    "@@||example.org^$specifichide",
                ],
                advancedBlocking: true,
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : ".banner",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "url-filter" : ".*"
                        }
                      }
                    ]
                    """#,
                expectedAdvancedRulesText: [
                    "test.com,example.org#$#body { overflow: visible!important; }",
                    "@@||example.org^$specifichide",
                ].joined(separator: "\n"),
                expectedSourceRulesCount: 3,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 1,
                expectedAdvancedRulesCount: 2
            ),
        ]

        runTests(testCases)
    }

    func testConvertArrayPingModifier() {
        let testCases: [TestCase] = [
            TestCase(
                // Tests that $ping modifier is not supported by older Safari.
                rules: [
                    "||example.org^$ping",
                    "||example.org^$~ping,domain=test.com",
                ],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedSourceRulesCount: 0,
                expectedSourceSafariCompatibleRulesCount: 0,
                expectedSafariRulesCount: 0,
                expectedErrorsCount: 2
            ),
            TestCase(
                // Tests that $ping modifier is supported starting with Safari 15.
                rules: [
                    "||example.org^$ping",
                    "||example.org^$~ping,domain=test.com",
                ],
                version: SafariVersion.safari15,
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "resource-type" : [
                            "ping"
                          ],
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.org([\\\/:&\\?].*)?$"
                        }
                      },
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*test.com"
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
                            "document"
                          ],
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.org([\\\/:&\\?].*)?$"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            ),
        ]

        runTests(testCases)
    }

    func testConvertArrayOtherModifier() {
        let testCases: [TestCase] = [
            TestCase(
                // Tests that $other modifier is converted to resource type "raw" in older Safari.
                rules: [
                    "||test.com^$other",
                    "||test.com^$~other,domain=example.org",
                ],
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
                      },
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
                            "raw",
                            "font",
                            "document"
                          ],
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?test\\.com([\\\/:&\\?].*)?$"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            ),
            TestCase(
                // Tests that $other modifier is converted to resource type "other" starting with Safari 15.
                rules: [
                    "||test.com^$other",
                    "||test.com^$~other,domain=example.org",
                ],
                version: SafariVersion.safari15,
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "resource-type" : [
                            "other"
                          ],
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?test\\.com([\\\/:&\\?].*)?$"
                        }
                      },
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
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            ),
            TestCase(
                // Tests that $xmlhttprequest modifier is converted to resource type "raw" in older Safari.
                rules: [
                    "||test.com^$other",
                    "||test.com^$~other,domain=example.org",
                ],
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
                      },
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
                            "raw",
                            "font",
                            "document"
                          ],
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?test\\.com([\\\/:&\\?].*)?$"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            ),
        ]

        runTests(testCases)
    }

    func testConvertArrayXmlhttprequestModifier() {
        let testCases: [TestCase] = [
            TestCase(
                // Tests that $xmlhttprequest modifier is converted to resource type "fetch" starting with Safari 15.
                rules: [
                    "||test.com^$xmlhttprequest",
                    "||test.com^$~xmlhttprequest,domain=example.org",
                ],
                version: SafariVersion.safari15,
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "resource-type" : [
                            "fetch"
                          ],
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?test\\.com([\\\/:&\\?].*)?$"
                        }
                      },
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
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            ),
            TestCase(
                // Tests that $xhr is also supported.
                rules: [
                    "||test.com^$xhr",
                    "||test.com^$~xhr,domain=example.org",
                ],
                version: SafariVersion.safari15,
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "resource-type" : [
                            "fetch"
                          ],
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?test\\.com([\\\/:&\\?].*)?$"
                        }
                      },
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
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            ),
            TestCase(
                // Tests $subdocument rules in Safari 15 (with load-context).
                rules: [
                    "||test.com^$subdocument,domain=example.com",
                    "||test.com^$~subdocument,domain=example.com",
                ],
                version: SafariVersion.safari15,
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
                          "load-context" : [
                            "child-frame"
                          ],
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?test\\.com([\\\/:&\\?].*)?$"
                        }
                      },
                      {
                        "action" : {
                          "type" : "block"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*example.com"
                          ],
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
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            ),
        ]

        runTests(testCases)
    }

    func testConvertArrayInvalidRules() {
        let testCases: [TestCase] = [
            TestCase(
                // Invalid rule: too short, without domain restrictions.
                rules: ["zz"],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedSafariRulesCount: 0,
                expectedErrorsCount: 1
            ),
            TestCase(
                // Invalid rule: no cosmetic content.
                rules: ["example.org##", "example.org#@#"],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedSafariRulesCount: 0,
                expectedErrorsCount: 2
            ),
            TestCase(
                // Invalid rules: no script/scriptlets content.
                rules: [
                    "test.com#%#",
                    "test.com#@%#",
                    "example.org#%#",
                    "example.org#@%#",
                ],
                advancedBlocking: true,
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedSafariRulesCount: 0,
                expectedAdvancedRulesCount: 0,
                expectedErrorsCount: 4
            ),
        ]

        runTests(testCases)
    }

    func testConvertArrayCosmeticRulesWithPathModifier() {
        let testCases: [TestCase] = [
            TestCase(
                // Generic rule that targets path.html only.
                rules: [
                    "[$path=page.html]##.textad"
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : ".textad",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "url-filter" : ".*page\\.html"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // Rule with $path and domain restriction.
                rules: [
                    "[$path=/page.html]test.com##.textad"
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : ".textad",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*test.com"
                          ],
                          "url-filter" : ".*\\\/page\\.html"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // Rules with $path and $domain modifiers.
                rules: [
                    "[$path=/page.html,domain=example.org|test.com]##.textad",
                    "[$domain=example.org,path=/page.html]##.textad",
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : ".textad",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*example.org",
                            "*test.com"
                          ],
                          "url-filter" : ".*\\\/page\\.html"
                        }
                      },
                      {
                        "action" : {
                          "selector" : ".textad",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*example.org"
                          ],
                          "url-filter" : ".*\\\/page\\.html"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            ),
            TestCase(
                // $path + mixing $domain and traditional domains.
                rules: [
                    "[$domain=example.org|test.com,path=/page.html]website.com##.textad"
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : ".textad",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*example.org",
                            "*test.com",
                            "*website.com"
                          ],
                          "url-filter" : ".*\\\/page\\.html"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // $path + mixing $domain and traditional domains.
                rules: [
                    "[$domain=example.org|test.com,path=/page.html]website.com##.textad"
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : ".textad",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*example.org",
                            "*test.com",
                            "*website.com"
                          ],
                          "url-filter" : ".*\\\/page\\.html"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1
            ),
            TestCase(
                // Using regular expressions in $path.
                rules: [
                    "[$path=/\\/sub\\/.*\\/page\\.html/]##.textad",
                    "[$path=/^\\/$/]##.textad",
                ],
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : ".textad",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "url-filter" : ".*\\\/sub\\\/.*\\\/page\\.html"
                        }
                      },
                      {
                        "action" : {
                          "selector" : ".textad",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "url-filter" : "^(https?:\\\/\\\/)([^\\\/]+)\\\/$"
                        }
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 2,
                expectedSourceSafariCompatibleRulesCount: 2,
                expectedSafariRulesCount: 2
            ),
            TestCase(
                // Using unsupported regular expressions in $path.
                rules: [
                    "[$path=/\\/(sub1|sub2)\\/page\\.html/]##.textad"
                ],
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 0,
                expectedErrorsCount: 1
            ),
        ]

        runTests(testCases)
    }

    func testConvertArrayExtendedCSSPseudoDetection() {
        let testCases: [TestCase] = [
            TestCase(
                // In older Safari versions :has rules can only be evaluated as "advanced".
                rules: [
                    "test.com##div:has(.banner)"
                ],
                version: SafariVersion.safari15,
                advancedBlocking: true,
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedAdvancedRulesText: [
                    "test.com##div:has(.banner)"
                ].joined(separator: "\n"),
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 0,
                expectedSafariRulesCount: 0,
                expectedAdvancedRulesCount: 1,
                expectedErrorsCount: 0
            ),
            TestCase(
                // In new Safari versions :has rules can be evaluated by Safari.
                rules: [
                    "test.com##div:has(.banner)"
                ],
                version: SafariVersion.safari16_4,
                advancedBlocking: true,
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : "div:has(.banner)",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*test.com"
                          ],
                          "url-filter" : ".*"
                        }
                      }
                    ]
                    """#,
                expectedAdvancedRulesText: nil,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1,
                expectedAdvancedRulesCount: 0,
                expectedErrorsCount: 0
            ),
            TestCase(
                // But if the rule uses #?# marker it will anyway be evaluated by ExtCSS
                // even if the Safari version is new.
                rules: [
                    "test.com#?#div:has(.banner)"
                ],
                version: SafariVersion.safari16_4,
                advancedBlocking: true,
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedAdvancedRulesText: [
                    "test.com#?#div:has(.banner)"
                ].joined(separator: "\n"),
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 0,
                expectedSafariRulesCount: 0,
                expectedAdvancedRulesCount: 1,
                expectedErrorsCount: 0
            ),
            TestCase(
                // In Safari 13 :is rules can only be evaluated as "advanced".
                rules: [
                    "test.com##div:is(.banner)"
                ],
                version: SafariVersion.safari13,
                advancedBlocking: true,
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedAdvancedRulesText: [
                    "test.com##div:is(.banner)"
                ].joined(separator: "\n"),
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 0,
                expectedSafariRulesCount: 0,
                expectedAdvancedRulesCount: 1,
                expectedErrorsCount: 0
            ),
            TestCase(
                // Starting with Safari 14 :is rules can be evaluated by Safari.
                rules: [
                    "test.com##div:is(.banner)"
                ],
                version: SafariVersion.safari14,
                advancedBlocking: true,
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : "div:is(.banner)",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*test.com"
                          ],
                          "url-filter" : ".*"
                        }
                      }
                    ]
                    """#,
                expectedAdvancedRulesText: nil,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 1,
                expectedSafariRulesCount: 1,
                expectedAdvancedRulesCount: 0,
                expectedErrorsCount: 0
            ),
            TestCase(
                // $xpath are always evaluated as advanced rules.
                rules: [
                    "test.com#?#:xpath(//div[@data-st-area='Advert'])",
                    "example.org##:xpath(//div[@id='stream_pagelet'])",
                    "example.com##:xpath(//div[@id='adv'])",
                    "example.com#@#:xpath(//div[@id='adv'])",
                ],
                version: SafariVersion.safari16_4,
                advancedBlocking: true,
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedAdvancedRulesText: [
                    "test.com#?#:xpath(//div[@data-st-area='Advert'])",
                    "example.org##:xpath(//div[@id='stream_pagelet'])",
                    "example.com##:xpath(//div[@id='adv'])",
                    "example.com#@#:xpath(//div[@id='adv'])",
                ].joined(separator: "\n"),
                expectedSourceRulesCount: 4,
                expectedSourceSafariCompatibleRulesCount: 0,
                expectedSafariRulesCount: 0,
                expectedAdvancedRulesCount: 4,
                expectedErrorsCount: 0
            ),
        ]

        runTests(testCases)
    }

    func testConvertArrayAdvancedRules() {
        let testCases: [TestCase] = [
            TestCase(
                // Test that nothing is returned when advancedBlocking is disabled.
                rules: [
                    "example.org#$#.content { margin-top: 0!important; }"
                ],
                advancedBlocking: false,
                expectedSafariRulesJSON: ConversionResult.EMPTY_RESULT_JSON,
                expectedSourceRulesCount: 1,
                expectedSourceSafariCompatibleRulesCount: 0,
                expectedSafariRulesCount: 0,
                expectedAdvancedRulesCount: 0
            ),
            TestCase(
                // Test that rules are correctly distributed between simple and advanced.
                rules: [
                    // Simple rule, not included.
                    "||example.org^",
                    // $elemhide, included into both sets: advanced and safari.
                    "@@||example.org^$elemhide",
                    // Simple element hiding, only safari.
                    "example.com##div.textad",
                    // Must be evaluated as advanced.
                    "example.com#?#div.textad",
                    // CSS injection, only advanced.
                    "example.org#$#.div { background:none!important; }",
                    // Advanced pseudo-class.
                    "example.org##div:contains(test)",
                    // JS rule, advanced.
                    "example.org#%#window.__gaq = undefined;",
                    // Scriptlet rule, advanced.
                    "example.org#%#//scriptlet(\"abort-on-property-read\", \"alert\")",
                ],
                advancedBlocking: true,
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : "div.textad",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "if-domain" : [
                            "*example.com"
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
                expectedAdvancedRulesText: [
                    "@@||example.org^$elemhide",
                    "example.com#?#div.textad",
                    "example.org#$#.div { background:none!important; }",
                    "example.org##div:contains(test)",
                    "example.org#%#window.__gaq = undefined;",
                    "example.org#%#//scriptlet(\"abort-on-property-read\", \"alert\")",
                ].joined(separator: "\n"),
                expectedSourceRulesCount: 8,
                expectedSourceSafariCompatibleRulesCount: 3,
                expectedSafariRulesCount: 3,
                expectedAdvancedRulesCount: 6
            ),
        ]

        runTests(testCases)
    }

    /// This is a big test that checks how the rules are sorted.
    ///
    /// Currently, the sorting order is the following:
    ///
    /// 1. Domain-wide `css-display-none` rules (no domain restrictions at all, i.e. `##.banner`).
    /// 2. Generic rules with restricted domains (i.e. `~example.org##.banner`)
    /// 3. `$generichide` exceptions (i.e. `@@||example.org^$generichide`)
    /// 4. `css-display-none` rules with domain restrictions (i.e. `example.org##.banner`)
    /// 5. `$elemhide` exceptions (i.e. `@@||example.org^$elemhide`)`
    /// 6. Basic blocking rules (i.e. `||example.org^`)
    /// 7. Exception rules (i.e. `@@||example.org^`)
    /// 8. Blocking rules with `$important` modifier (i.e. `||example.org^$important`)
    /// 9. Exception rules with `$important` modifier (i.e. `@@||example.org^$important`)
    /// 10. `$document` exceptions (i.e. `@@||example.org^$document`)
    ///
    /// The order will change when the following tasks are implemented:
    /// * https://github.com/AdguardTeam/SafariConverterLib/issues/69
    /// * https://github.com/AdguardTeam/SafariConverterLib/issues/71
    /// * https://github.com/AdguardTeam/SafariConverterLib/issues/70
    func testConvertArraySortOrder() {
        let testCases: [TestCase] = [
            TestCase(
                // $xpath are always evaluated as advanced rules.
                rules: [
                    "##.banner",
                    "~example.org##.banner",
                    "@@||example.org^$generichide",
                    "example.org##.banner",
                    "@@||example.org^$elemhide",
                    "||example.org^",
                    "@@||example.org^",
                    "||example.org^$important",
                    "@@||example.org^$important",
                    "@@||example.org^$document",
                ],
                version: SafariVersion.safari16_4,
                expectedSafariRulesJSON: #"""
                    [
                      {
                        "action" : {
                          "selector" : ".banner",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "url-filter" : ".*"
                        }
                      },
                      {
                        "action" : {
                          "selector" : ".banner",
                          "type" : "css-display-none"
                        },
                        "trigger" : {
                          "unless-domain" : [
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
                          "selector" : ".banner",
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
                      },
                      {
                        "action" : {
                          "type" : "ignore-previous-rules"
                        },
                        "trigger" : {
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.org([\\\/:&\\?].*)?$"
                        }
                      },
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
                          "url-filter" : "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?example\\.org([\\\/:&\\?].*)?$"
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
                      }
                    ]
                    """#,
                expectedSourceRulesCount: 10,
                expectedSourceSafariCompatibleRulesCount: 10,
                expectedSafariRulesCount: 10
            )
        ]

        runTests(testCases)
    }

    func testMaxJsonSize() {
        let rules = [
            "||example1.org^",
            "||example2.com^$document",
            "example3.com##h1",
        ]

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

        func performTest(withLimit limit: Int?, expectedCount: Int) {
            let converter = ContentBlockerConverter()

            let result = converter.convertArray(
                rules: rules,
                advancedBlocking: false,
                maxJsonSizeBytes: limit
            )

            let jsonSize = result.safariRulesJSON.utf8.count
            if let limit = limit {
                XCTAssertLessThanOrEqual(
                    jsonSize,
                    limit,
                    "The converted JSON size should be less than or equal to the limit"
                )
            }
            XCTAssertEqual(
                result.safariRulesCount,
                expectedCount,
                "The converted count should match the expected count"
            )
            XCTAssertTrue(isJSONValid(result.safariRulesJSON), "The converted JSON should be valid")
        }

        // Bigger than empty JSON, smaller for rules to fit
        performTest(withLimit: 110, expectedCount: 0)
        // Enough for one rule
        performTest(withLimit: 150, expectedCount: 1)
        // Enough for two rules
        performTest(withLimit: 300, expectedCount: 2)
        // Enough for all rules
        performTest(withLimit: 1000, expectedCount: 3)
        // No limit
        performTest(withLimit: nil, expectedCount: 3)
    }

    func testTldWildcardRules() {
        let converter = ContentBlockerConverter()

        var result = converter.convertArray(rules: [
            "surge.*,testcases.adguard.*###case-5-wildcard-for-tld > .test-banner"
        ])
        XCTAssertEqual(result.safariRulesCount, 1)

        var decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*")
        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*surge.com.bd")
        XCTAssertEqual(decoded[0].trigger.ifDomain?[1], "*surge.com.np")
        XCTAssertEqual(decoded[0].trigger.ifDomain?[2], "*surge.com")
        XCTAssertEqual(decoded[0].trigger.ifDomain?.count, 200)

        result = converter.convertArray(rules: [
            "||*/test-files/adguard.png$domain=surge.*|testcases.adguard.*"
        ])
        XCTAssertEqual(result.safariRulesCount, 1)

        decoded = try! parseJsonString(json: result.safariRulesJSON)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(
            decoded[0].trigger.urlFilter,
            "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?.*\\/test-files\\/adguard\\.png"
        )
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

    func testProblematicRules() {
        let rules = [
            "facebook.com##div[role=\"feed\"] div[style=\"border-radius: max(0px, min(8px, ((100vw - 4px) - 100%) * 9999)) / 8px;\"] div[style=\"border-radius: max(0px, min(8px, ((100vw - 4px) - 100%) * 9999)) / 8px;\"]",
            "hdpass.net#%#AG_onLoad(function() {setTimeout(function() {function clearify(url) {         var size = url.length;         if (size % 2 == 0) {             var halfIndex = size / 2;             var firstHalf = url.substring(0, halfIndex);             var secondHalf = url.substring(halfIndex, size);             var url = secondHalf + firstHalf;             var base = url.split(\"\").reverse().join(\"\");             var clearText = $.base64('decode', base);             return clearText         } else {             var lastChar = url[size - 1];             url[size - 1] = ' ';             url = $.trim(url);             var newSize = url.length;             var halfIndex = newSize / 2;             var firstHalf = url.substring(0, halfIndex);             var secondHalf = url.substring(halfIndex, newSize);             url = secondHalf + firstHalf;             var base = url.split(\"\").reverse().join(\"\");             base = base + lastChar;             var clearText = $.base64('decode', base);             return clearText         }     }  var urlEmbed = $('#urlEmbed').val(); urlEmbed = clearify(urlEmbed); var iframe = '<iframe width=\"100%\" height=\"100%\" src=\"' + urlEmbed + '\" frameborder=\"0\" scrolling=\"no\" allowfullscreen />'; $('#playerFront').html(iframe); }, 300); });",
            "allegro.pl##div[data-box-name=\"banner - cmuid\"][data-prototype-id=\"allegro.advertisement.slot.banner\"]",
            "msn.com#%#AG_onLoad(function() { setTimeout(function() { var el = document.querySelectorAll(\".todaystripe .swipenav > li\"); if(el) { for(i=0;i<el.length;i++) { el[i].setAttribute(\"data-aop\", \"slide\" + i + \">single\"); var data = el[i].getAttribute(\"data-id\"); el[i].setAttribute(\"data-m\", ' {\"i\":' + data + ',\"p\":115,\"n\":\"single\",\"y\":8,\"o\":' + i + '} ')}; var count = document.querySelectorAll(\".todaystripe .infopane-placeholder .slidecount span\"); var diff = count.length - el.length; while(diff > 0) { var count_length = count.length; count[count_length-1].remove(); var count = document.querySelectorAll(\".todaystripe .infopane-placeholder .slidecount span\"); var diff = count.length - el.length; } } }, 300); });",
            "abplive.com#?#.articlepage > .center_block:has(> p:contains(- - Advertisement - -))",
            "facebook2.com##div[role=\"region\"] + div[role=\"main\"] div[role=\"article\"] div[style=\"border-radius: max(0px, min(8px, ((100vw - 4px) - 100%) * 9999)) / 8px;\"] > div[class]:not([class*=\" \"])",
        ]
        let converter = ContentBlockerConverter()
        let result = converter.convertArray(
            rules: rules,
            safariVersion: .safari15,
            advancedBlocking: true
        )
        XCTAssertEqual(result.sourceRulesCount, rules.count)
        XCTAssertEqual(result.sourceSafariCompatibleRulesCount, 3)
        XCTAssertEqual(result.safariRulesCount, 3)
        XCTAssertEqual(result.advancedRulesCount, 3)
        XCTAssertEqual(result.errorsCount, 0)
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
}
