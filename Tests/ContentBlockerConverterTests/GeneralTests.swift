import Foundation

import XCTest
@testable import ContentBlockerConverter

final class GeneralTests: XCTestCase {
    
    private func parseJsonString(json: String) throws -> [BlockerEntry] {
        let data = json.data(using: String.Encoding.utf8, allowLossyConversion: false)!
        
        let decoder = JSONDecoder();
        let parsedData = try decoder.decode([BlockerEntry].self, from: data);
        
        return parsedData;
    }
    
    private func encodeJson(item: BlockerEntry) -> String {
        let encoder = JSONEncoder();
        encoder.outputFormatting = .prettyPrinted
        
        let json = try! encoder.encode(item);
        return String(data: json, encoding: .utf8)!.replacingOccurrences(of: "\\/", with: "/");
    }
    
    let rules = [
        "||pics.rbc.ru/js/swf",
        "||tardangro.com^$third-party",
        "||videoplaza.com^$~object-subrequest,third-party",
        "||videoplaza.tv^$object-subrequest,third-party,domain=tv4play.se",
        "||b.babylon.com^",
        "||getsecuredfiles.com^$popup,third-party",
        "popsugar.com###calendar_widget",
        "@@||emjcd.com^$image,domain=catalogfavoritesvip.com|freeshipping.com",
        "@@||intellitxt.com/ast/js/nbcuni/$script",
        "@@||hulu.com/embed$document",
        "@@||hulu.com/$document",
        "@@http://hulu.com^$document",
        "@@https://hulu.com$document",
        "@@www.any.gs$urlblock",
        "@@wfarm.yandex.net/$document",
        "@@.instantservice.com$document",
        "/addyn|*|adtech;",
        "@@||test-document.com$document",
        "@@||test-urlblock.com$urlblock",
        "@@||test-elemhide.com$elemhide",
        "@@/testelemhidenodomain$document",
        "lenta1.ru#@##social",
        "lenta2.ru#@##social",
        "###social",
        "yandex.ru###pub",
        "yandex.ru#@##pub",
    #"@@/^https?\:\/\/(?!(qs\.ivwbox\.de|qs\.ioam.de|platform\.twitter\.com|connect\.facebook\.net|de\.ioam\.de|pubads\.g\.doubleclick\.net|stats\.wordpress\.com|www\.google-analytics\.com|www\.googletagservices\.com|apis\.google\.com|script\.ioam\.de)\/)/$script,third-party,domain=gamona.de"#,
        #"/\.filenuke\.com/.*[a-zA-Z0-9]{4}/$script"#,
        "##.banner"
    ];
    
    let safariCorrectRulesJson = """
    [
        {
            "trigger" : {
                "url-filter" : ".*"
            },
            "action" : {
                "type" : "css-display-none",
                "selector" : ".banner"
            }
        },
        {
            "trigger" : {
                "url-filter" : ".*",
                "unless-domain" : [
                    "*lenta1.ru",
                    "*lenta2.ru"
                ]
            },
            "action" : {
                "type" : "css-display-none",
                "selector" : "#social"
            }
        },
        {
            "trigger" : {
                "url-filter" : ".*",
                "if-domain" : [
                    "*popsugar.com"
                ]
            },
            "action" : {
                "type" : "css-display-none",
                "selector" : "#calendar_widget"
            }
        },
        {
            "trigger" : {
                "url-filter" : ".*",
                "if-domain" : [
                    "*test-elemhide.com"
                ]
            },
            "action" : {
                "type" : "ignore-previous-rules"
            }
        },
        {
            "trigger" : {
                "url-filter" : "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?pics\\.rbc\\.ru\\/js\\/swf"
            },
            "action" : {
                "type" : "block"
            }
        },
        {
            "trigger" : {
                "url-filter" : "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?tardangro\\.com[/:&?]?",
                "load-type" : [
                    "third-party"
                ]
            },
            "action" : {
                "type" : "block"
            }
        },
        {
            "trigger" : {
                "url-filter" : "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?videoplaza\\.com[/:&?]?",
                "load-type" : [
                    "third-party"
                ],
                "resource-type" : [
                    "image",
                    "style-sheet",
                    "script",
                    "media",
                    "raw",
                    "font",
                    "document"
                ]
            },
            "action" : {
                "type" : "block"
            }
        },
        {
            "trigger" : {
                "url-filter" : "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?b\\.babylon\\.com[/:&?]?"
            },
            "action" : {
                "type" : "block"
            }
        },
        {
            "trigger" : {
                "url-filter" : "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?getsecuredfiles\\.com[/:&?]?",
                "load-type" : [
                    "third-party"
                ],
                "resource-type" : [
                    "document"
                ]
            },
            "action" : {
                "type" : "block"
            }
        },
        {
            "trigger" : {
                "url-filter" : "\\/addyn\\|.*\\|adtech;"
            },
            "action" : {
                "type" : "block"
            }
        },
        {
            "trigger" : {
                "url-filter" : "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?emjcd\\.com[/:&?]?",
                "resource-type" : [
                    "image"
                ],
                "if-domain" : [
                    "*catalogfavoritesvip.com",
                    "*freeshipping.com"
                ]
            },
            "action" : {
                "type" : "ignore-previous-rules"
            }
        },
        {
            "trigger" : {
                "url-filter" : "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?intellitxt\\.com\\/ast\\/js\\/nbcuni\\/",
                "resource-type" : [
                    "script"
                ]
            },
            "action" : {
                "type" : "ignore-previous-rules"
            }
        },
        {
            "trigger" : {
                "url-filter" : ".*",
                "if-domain" : [
                    "*www.any.gs"
                ]
            },
            "action" : {
                "type" : "ignore-previous-rules"
            }
        },
        {
            "trigger" : {
                "url-filter" : ".*",
                "if-domain" : [
                    "*test-urlblock.com"
                ]
            },
            "action" : {
                "type" : "ignore-previous-rules"
            }
        },
        {
            "trigger" : {
                "url-filter" : "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?hulu\\.com\\/embed"
            },
            "action" : {
                "type" : "ignore-previous-rules"
            }
        },
        {
            "trigger" : {
                "url-filter" : ".*",
                "if-domain" : [
                    "*hulu.com"
                ]
            },
            "action" : {
                "type" : "ignore-previous-rules"
            }
        },
        {
            "trigger" : {
                "url-filter" : ".*",
                "if-domain" : [
                    "*hulu.com"
                ]
            },
            "action" : {
                "type" : "ignore-previous-rules"
            }
        },
        {
            "trigger" : {
                "url-filter" : ".*",
                "if-domain" : [
                    "*hulu.com"
                ]
            },
            "action" : {
                "type" : "ignore-previous-rules"
            }
        },
        {
            "trigger" : {
                "url-filter" : ".*",
                "if-domain" : [
                    "*wfarm.yandex.net"
                ]
            },
            "action" : {
                "type" : "ignore-previous-rules"
            }
        },
        {
            "trigger" : {
                "url-filter" : "\\.instantservice\\.com"
            },
            "action" : {
                "type" : "ignore-previous-rules"
            }
        },
        {
            "trigger" : {
                "url-filter" : ".*",
                "if-domain" : [
                    "*test-document.com"
                ]
            },
            "action" : {
                "type" : "ignore-previous-rules"
            }
        },
        {
            "trigger" : {
                "url-filter" : "\\/testelemhidenodomain"
            },
            "action" : {
                "type" : "ignore-previous-rules"
            }
        }
    ]

    """;
    
    func testGeneral() {
        let conversionResult = ContentBlockerConverter().convertArray(rules: rules);
        
        XCTAssertEqual(conversionResult?.totalConvertedCount, 22);
        XCTAssertEqual(conversionResult?.convertedCount, 22);
        XCTAssertEqual(conversionResult?.errorsCount, 3);
        XCTAssertEqual(conversionResult?.overLimit, false);
        
        print(conversionResult!.converted);
        
        let decoded = try! parseJsonString(json: conversionResult!.converted);
        let correct = try! parseJsonString(json: safariCorrectRulesJson.replacingOccurrences(of: "\\", with: "\\\\"));
        
        XCTAssertEqual(decoded.count, correct.count);
        
        for (index, entry) in correct.enumerated() {
            let correspondingDecoded = decoded[index];
            XCTAssertEqual(encodeJson(item: correspondingDecoded), encodeJson(item: entry));
        }
    }
    
    func testPerformance() {
        let thisSourceFile = URL(fileURLWithPath: #file);
        let thisDirectory = thisSourceFile.deletingLastPathComponent();
        let resourceURL = thisDirectory.appendingPathComponent("Resources/test-rules.txt");
        
        let content = try! String(contentsOf: resourceURL, encoding: String.Encoding.utf8);
        let rules = content.components(separatedBy: "\n");
        
        self.measure {
            let conversionResult = ContentBlockerConverter().convertArray(rules: rules);
            NSLog(conversionResult!.message);
            
            XCTAssertEqual(conversionResult?.totalConvertedCount, 22901);
            XCTAssertEqual(conversionResult?.convertedCount, 22901);
            XCTAssertEqual(conversionResult?.errorsCount, 143);
            XCTAssertEqual(conversionResult?.overLimit, false);
        }
        
    }
    
    static var allTests = [
        ("testGeneral", testGeneral),
        ("testPerformance", testPerformance),
    ]
}
