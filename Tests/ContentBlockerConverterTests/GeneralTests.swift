import Foundation

import XCTest
@testable import ContentBlockerConverter

final class GeneralTests: XCTestCase {
    
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
    
    func testGeneral() {
        let result = ContentBlockerConverter().convertArray(rules: rules);
        
        XCTAssertEqual(result?.totalConvertedCount, 26);
        XCTAssertEqual(result?.convertedCount, 26);
        XCTAssertEqual(result?.errorsCount, 3);
        XCTAssertEqual(result?.overLimit, false);
        
        // XCTAssertEqual(result?.converted, "[\n\n]");
    }
    
    //Converting 29 rules. Optimize=false
    //log.js:71 2020-08-28T00:13:50.366Z: Applying 3 selector exceptions
    //log.js:71 2020-08-28T00:13:50.367Z: Exceptions selector applied: 3
    //log.js:71 2020-08-28T00:13:50.367Z: Exceptions selector errors: 1
    //log.js:71 2020-08-28T00:13:50.367Z: Trying to compact 3 elemhide rules
    //log.js:71 2020-08-28T00:13:50.367Z: Compacted result: wide=1 domainSensitive=1
    //log.js:71 2020-08-28T00:13:50.367Z: Rules converted: 26 (3 errors)
    //Basic rules: 6
    //Basic important rules: 0
    //Elemhide rules (wide): 1
    //Elemhide rules (generic domain sensitive): 1
    //Exceptions Elemhide (wide): 0
    //Elemhide rules (domain-sensitive): 1
    //Script rules: 0
    //Scriptlets rules: 0
    //Extended Css Elemhide rules (wide): 0
    //Extended Css Elemhide rules (generic domain sensitive): 0
    //Extended Css Elemhide rules (domain-sensitive): 0
    //Exceptions (elemhide): 1
    //Exceptions (important): 0
    //Exceptions (document): 8
    //Exceptions (jsinject): 0
    //Exceptions (other): 4
    //log.js:71 2020-08-28T00:13:50.368Z: Content blocker length: 22
}
