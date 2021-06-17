import XCTest
@testable import ContentBlockerConverter

final class ContentBlockerConverterTests: XCTestCase {
    let URL_FILTER_ANY_URL = "^[htpsw]+:\\/\\/";
    let URL_FILTER_REGEXP_START_URL = "^[htpsw]+:\\\\/\\\\/([a-z0-9-]+\\\\.)?";

    let START_URL_UNESCAPED = "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?";
    let URL_FILTER_WS_ANY_URL_UNESCAPED = "^wss?:\\/\\/";
    let URL_FILTER_REGEXP_END_SEPARATOR = "([\\/:&\\?].*)?$";
    let URL_FILTER_REGEXP_SEPARATOR = "[/:&?]?";
    let URL_FILTER_CSS_RULES = ".*";
    let URL_FILTER_URL_RULES_EXCEPTIONS = ".*";

    let converter = ContentBlockerConverter();

    private func parseJsonString(json: String) throws -> [BlockerEntry] {
        let data = json.data(using: String.Encoding.utf8, allowLossyConversion: false)!

        let decoder = JSONDecoder();
        let parsedData = try decoder.decode([BlockerEntry].self, from: data);

        return parsedData;
    }
    
    private func checkEntriesByCondition(entries: [BlockerEntry], condition: (BlockerEntry)->Bool) -> Bool {
        entries.contains{ condition($0) }
    }

    func testEmpty() {
        var result = converter.convertArray(rules: []);

        XCTAssertEqual(result?.totalConvertedCount, 0);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.overLimit, false);
        XCTAssertEqual(result?.converted, "[{\"trigger\": {},\"action\": {}}]");
        
        result = converter.convertArray(rules: [""]);

        XCTAssertEqual(result?.totalConvertedCount, 0);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.overLimit, false);
        XCTAssertEqual(result?.converted, "[{\"trigger\": {},\"action\": {}}]");
    }

    func testConvertComment() {
        let result = converter.convertArray(rules: ["! this is a comment"]);

        XCTAssertEqual(result?.totalConvertedCount, 0);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.overLimit, false);
        XCTAssertEqual(result?.converted, "[]");
    }

    func testConvertNetworkRule() {
        let result = converter.convertArray(rules: ["127.0.0.1$network"]);

        XCTAssertEqual(result?.totalConvertedCount, 0);
        XCTAssertEqual(result?.convertedCount, 0);
        // XCTAssertEqual(result?.errorsCount, 1);
        XCTAssertEqual(result?.overLimit, false);
        XCTAssertEqual(result?.converted, "[]");
    }

    func testPopupRules() {
        var ruleText = [
            "||example1.com$document",
            "||example2.com$document,popup",
            "||example5.com$popup,document",
        ];

        var result = converter.convertArray(rules: ruleText);

        XCTAssertEqual(result?.totalConvertedCount, 3);
        XCTAssertEqual(result?.convertedCount, 3);
        XCTAssertEqual(result?.errorsCount, 0);

        var decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 3);

        XCTAssertEqual(decoded[0].trigger.urlFilter, START_URL_UNESCAPED + "example1\\.com");
        XCTAssertEqual(decoded[0].trigger.resourceType, ["document"]);
        XCTAssertEqual(decoded[0].action.type, "block");

        var regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://example1.com"));
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://example1.com/test"));

        XCTAssertEqual(decoded[1].trigger.urlFilter, START_URL_UNESCAPED + "example2\\.com");
        XCTAssertEqual(decoded[1].trigger.resourceType, ["document"]);
        XCTAssertEqual(decoded[1].action.type, "block");

        regex = try! NSRegularExpression(pattern: decoded[1].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://example2.com"));

        XCTAssertEqual(decoded[2].trigger.urlFilter, START_URL_UNESCAPED + "example5\\.com");
        XCTAssertEqual(decoded[2].trigger.resourceType, ["document"]);
        XCTAssertEqual(decoded[2].action.type, "block");

        regex = try! NSRegularExpression(pattern: decoded[2].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://example5.com"));

        // conversion of $document rule
        ruleText = ["||example.com$document"];
        result = converter.convertArray(rules: ruleText);

        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded[0].trigger.urlFilter, "\(START_URL_UNESCAPED)example\\.com");
        XCTAssertEqual(decoded[0].trigger.resourceType, ["document"]);
        XCTAssertEqual(decoded[0].action.type, "block");

        regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://example.com"));


        // conversion of $document and $popup rule
        ruleText = ["||test.com$document,popup"];
        result = converter.convertArray(rules: ruleText);

        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded[0].trigger.urlFilter, "\(START_URL_UNESCAPED)test\\.com");
        XCTAssertEqual(decoded[0].trigger.resourceType, ["document"]);
        XCTAssertEqual(decoded[0].action.type, "block");

        regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://test.com"));


        // conversion of $popup rule
        ruleText = ["||example.com^$popup"];
        result = converter.convertArray(rules: ruleText);

        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded[0].trigger.urlFilter, "\(START_URL_UNESCAPED)example\\.com" + URL_FILTER_REGEXP_END_SEPARATOR);
        XCTAssertEqual(decoded[0].trigger.resourceType, ["document"]);
        XCTAssertEqual(decoded[0].action.type, "block");

        regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://example.com"));


        // conversion of $popup and third-party rule
        ruleText = ["||getsecuredfiles.com^$popup,third-party"];
        result = converter.convertArray(rules: ruleText);

        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded[0].trigger.urlFilter, "\(START_URL_UNESCAPED)getsecuredfiles\\.com" + URL_FILTER_REGEXP_END_SEPARATOR);
        XCTAssertEqual(decoded[0].trigger.resourceType, ["document"]);
        XCTAssertEqual(decoded[0].trigger.loadType, ["third-party"]);
        XCTAssertEqual(decoded[0].action.type, "block");

        regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://getsecuredfiles.com"));

    }

    func testConvertFirstPartyRule() {
        let result = converter.convertArray(rules: ["@@||adriver.ru^$~third-party"]);

        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.overLimit, false);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded[0].trigger.urlFilter, "\(START_URL_UNESCAPED)adriver\\.ru" + URL_FILTER_REGEXP_END_SEPARATOR);
        XCTAssertEqual(decoded[0].trigger.loadType, ["first-party"]);
        XCTAssertEqual(decoded[0].action.type, "ignore-previous-rules");

        let regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://adriver.ru"));
    }

    func testConvertWebsocketRules() {
        var result = converter.convertArray(rules: ["||test.com^$websocket"]);
        XCTAssertEqual(result?.convertedCount, 1);

        var decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        var entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "test\\.com" + URL_FILTER_REGEXP_END_SEPARATOR);
        XCTAssertEqual(entry.trigger.ifDomain, nil);
        XCTAssertEqual(entry.trigger.unlessDomain, nil);
        XCTAssertEqual(entry.trigger.loadType, nil);
        XCTAssertEqual(entry.trigger.resourceType, ["raw"]);

        let regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://test.com"));

        result = converter.convertArray(rules: ["$websocket,domain=123movies.is"]);
        XCTAssertEqual(result?.convertedCount, 1);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, URL_FILTER_WS_ANY_URL_UNESCAPED);
        XCTAssertEqual(entry.trigger.ifDomain, ["*123movies.is"]);
        XCTAssertEqual(entry.trigger.resourceType, ["raw"]);

        result = converter.convertArray(rules: [".rocks^$third-party,websocket"]);
        XCTAssertEqual(result?.convertedCount, 1);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, URL_FILTER_WS_ANY_URL_UNESCAPED + ".*\\.rocks" + URL_FILTER_REGEXP_END_SEPARATOR);
        XCTAssertEqual(entry.trigger.ifDomain, nil);
        XCTAssertEqual(entry.trigger.unlessDomain, nil);
        XCTAssertEqual(entry.trigger.loadType, ["third-party"]);
        XCTAssertEqual(entry.trigger.resourceType, ["raw"]);
    }

    func testConvertScriptRestrictRules() {
        let result = converter.convertArray(rules: ["||test.com^$~script,domain=example.com"]);
        XCTAssertEqual(result?.convertedCount, 1);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        let entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "test\\.com" + URL_FILTER_REGEXP_END_SEPARATOR);
        XCTAssertEqual(entry.trigger.ifDomain, ["*example.com"]);
        XCTAssertEqual(entry.trigger.unlessDomain, nil);
        XCTAssertEqual(entry.trigger.resourceType, ["image", "style-sheet", "media", "raw", "font", "document"]);

        let regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://test.com"));
    }

    func testConvertSubdocumentFirstParty() {
        let result = converter.convertArray(rules: ["||test.com^$subdocument,~third-party"]);
        XCTAssertEqual(result?.convertedCount, 0);
    }

    func testConvertSubdocumentThirdParty() {
        let result = converter.convertArray(rules: ["||test.com^$subdocument,domain=example.com"]);
        XCTAssertEqual(result?.convertedCount, 1);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        let entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "test\\.com" + URL_FILTER_REGEXP_END_SEPARATOR);
        XCTAssertEqual(entry.trigger.ifDomain, ["*example.com"]);
        XCTAssertEqual(entry.trigger.unlessDomain, nil);
        XCTAssertEqual(entry.trigger.resourceType, ["document"]);
        XCTAssertEqual(entry.action.type, "block");

        let regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://test.com"));
    }

    func testAddUnlessDomainsForThirdParty() {
        var result = converter.convertArray(rules: ["||test.com^$third-party"]);
        XCTAssertEqual(result?.convertedCount, 1);

        var decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        var entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "test\\.com" + URL_FILTER_REGEXP_END_SEPARATOR);
        XCTAssertEqual(entry.trigger.ifDomain, nil);
        XCTAssertEqual(entry.trigger.unlessDomain, ["*test.com"]);
        XCTAssertEqual(entry.trigger.loadType, ["third-party"]);

        var regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://test.com"));

        result = converter.convertArray(rules: ["||test.com$third-party,domain=~example.com"]);
        XCTAssertEqual(result?.convertedCount, 1);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "test\\.com");
        XCTAssertEqual(entry.trigger.ifDomain, nil);
        XCTAssertEqual(entry.trigger.unlessDomain, ["*example.com","*test.com"]);
        XCTAssertEqual(entry.trigger.loadType, ["third-party"]);

        regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://test.com"));


        // Only for third-party rules
        result = converter.convertArray(rules: ["||test.com^$important"]);
        XCTAssertEqual(result?.convertedCount, 1);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "test\\.com" + URL_FILTER_REGEXP_END_SEPARATOR);
        XCTAssertEqual(entry.trigger.ifDomain, nil);
        XCTAssertEqual(entry.trigger.unlessDomain, nil);

        regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://test.com"));


        // Add domains only
        result = converter.convertArray(rules: ["not-a-domain$third-party"]);
        XCTAssertEqual(result?.convertedCount, 1);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, "not-a-domain");
        XCTAssertEqual(entry.trigger.ifDomain, nil);
        XCTAssertEqual(entry.trigger.unlessDomain, nil);
        XCTAssertEqual(entry.trigger.loadType, ["third-party"]);


        // Skip rules with permitted domains
        result = converter.convertArray(rules: ["||test.com^$third-party,domain=example.com"]);
        XCTAssertEqual(result?.convertedCount, 1);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "test\\.com" + URL_FILTER_REGEXP_END_SEPARATOR);
        XCTAssertEqual(entry.trigger.ifDomain, ["*example.com"]);
        XCTAssertEqual(entry.trigger.unlessDomain, nil);
        XCTAssertEqual(entry.trigger.loadType, ["third-party"]);

        regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://test.com"));
    }

    func testConvertEmptyRegex() {
        let result = converter.convertArray(rules: ["@@$image,domain=moonwalk.cc"]);
        XCTAssertEqual(result?.convertedCount, 1);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        let entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, URL_FILTER_ANY_URL);
        XCTAssertEqual(entry.trigger.ifDomain, ["*moonwalk.cc"]);
        XCTAssertEqual(entry.trigger.unlessDomain, nil);
        XCTAssertEqual(entry.trigger.resourceType, ["image"]);
        XCTAssertEqual(entry.action.type, "ignore-previous-rules");
    }

    func testConvertInvertedWhitelistRule() {
        let result = converter.convertArray(rules: ["@@||*$domain=~whitelisted.domain.com|~whitelisted.domain2.com"]);
        XCTAssertEqual(result?.convertedCount, 1);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        let entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, URL_FILTER_ANY_URL);
        XCTAssertEqual(entry.trigger.ifDomain, nil);
        XCTAssertEqual(entry.trigger.unlessDomain, ["*whitelisted.domain.com", "*whitelisted.domain2.com"]);
        XCTAssertEqual(entry.action.type, "ignore-previous-rules");
    }

    func testConvertGenerichide() {
        var result = converter.convertArray(rules: ["@@||hulu.com/page$generichide"]);
        XCTAssertEqual(result?.convertedCount, 1);

        var decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        let entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "hulu\\.com\\/page");
        XCTAssertEqual(entry.action.type, "ignore-previous-rules");

        let regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://hulu.com/page"));
        
        let rules = [
            "@@||example.org^$generichide,genericblock",
            "##.ad-banner",
            "||example.org^"
        ]
        result = ContentBlockerConverter().convertArray(rules: rules);

        XCTAssertEqual(result?.totalConvertedCount, 3);
        XCTAssertEqual(result?.convertedCount, 3);
        XCTAssertEqual(result?.errorsCount, 0);
        
        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 3);
        
        XCTAssertNil(decoded[0].trigger.ifDomain);
        XCTAssertNil(decoded[0].trigger.unlessDomain);
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".ad-banner");
        
        XCTAssertNil(decoded[1].trigger.ifDomain);
        XCTAssertNil(decoded[1].trigger.unlessDomain);
        XCTAssertEqual(decoded[1].trigger.urlFilter, "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$");
        XCTAssertNil(decoded[1].trigger.resourceType);
        XCTAssertEqual(decoded[1].action.type, "block");
        
        XCTAssertNil(decoded[2].trigger.ifDomain);
        XCTAssertNil(decoded[2].trigger.unlessDomain);
        XCTAssertEqual(decoded[2].trigger.urlFilter, "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$");
        XCTAssertEqual(decoded[2].trigger.resourceType, ["document"]);
        XCTAssertEqual(decoded[2].action.type, "ignore-previous-rules");
    }

    func testConvertGenericDomainSensitive() {
        let result = converter.convertArray(rules: ["~google.com##banner"]);
        XCTAssertEqual(result?.convertedCount, 1);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        let entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, URL_FILTER_CSS_RULES);
        XCTAssertEqual(entry.action.type, "css-display-none");
        XCTAssertEqual(entry.trigger.unlessDomain, ["*google.com"]);
    }

    func testConvertGenericDomainSensitiveSortingOrder() {
        let result = converter.convertArray(rules: ["~example.org##generic", "##wide1", "##specific", "@@||example.org^$generichide"]);
        XCTAssertEqual(result?.convertedCount, 3);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 3);

        XCTAssertEqual(decoded[0].trigger.urlFilter, URL_FILTER_CSS_RULES);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, "wide1, specific");

        XCTAssertEqual(decoded[1].trigger.urlFilter, URL_FILTER_CSS_RULES);
        XCTAssertEqual(decoded[1].action.type, "css-display-none");
        XCTAssertEqual(decoded[1].action.selector, "generic");
        XCTAssertEqual(decoded[1].trigger.unlessDomain, ["*example.org"]);

        XCTAssertEqual(decoded[2].trigger.urlFilter, URL_FILTER_URL_RULES_EXCEPTIONS);
        XCTAssertEqual(decoded[2].action.type, "ignore-previous-rules");
        XCTAssertEqual(decoded[2].trigger.ifDomain, ["*example.org"]);
    }

    func testConvertGenericDomainSensitiveSortingOrderGenerichide() {
        let result = converter.convertArray(rules: ["###generic", "@@||example.org^$generichide"]);
        XCTAssertEqual(result?.convertedCount, 2);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 2);

        XCTAssertEqual(decoded[0].trigger.urlFilter, URL_FILTER_CSS_RULES);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, "#generic");

        XCTAssertEqual(decoded[1].trigger.urlFilter, URL_FILTER_URL_RULES_EXCEPTIONS);
        XCTAssertEqual(decoded[1].action.type, "ignore-previous-rules");
        XCTAssertEqual(decoded[1].trigger.ifDomain, ["*example.org"]);
    }

    func testConvertGenericDomainSensitiveSortingOrderElemhide() {
        let result = converter.convertArray(rules: ["example.org###generic", "@@||example.org^$elemhide"]);
        XCTAssertEqual(result?.convertedCount, 2);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 2);

        XCTAssertEqual(decoded[0].trigger.urlFilter, URL_FILTER_CSS_RULES);
        XCTAssertEqual(decoded[1].trigger.ifDomain, ["*example.org"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, "#generic");

        XCTAssertEqual(decoded[1].trigger.urlFilter, URL_FILTER_URL_RULES_EXCEPTIONS);
        XCTAssertEqual(decoded[1].trigger.ifDomain, ["*example.org"]);
        XCTAssertEqual(decoded[1].action.type, "ignore-previous-rules");
    }

    func testConvertCompactDomainSensitiveElemhide() {
        let result = converter.convertArray(rules: [
            "example.org###selector-one",
            "example.org###selector-two",
            "example.org###selector-three"
        ]);
        XCTAssertEqual(result?.convertedCount, 1);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);

        XCTAssertEqual(decoded[0].trigger.urlFilter, URL_FILTER_CSS_RULES);
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, "#selector-one, #selector-two, #selector-three");
    }

    func testCyrillicRules() {
        let result = converter.convertArray(rules: ["меил.рф", "||меил.рф"]);
        XCTAssertEqual(result?.convertedCount, 2);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 2);

        XCTAssertEqual(decoded[0].trigger.urlFilter, "xn--e1agjb\\.xn--p1ai");

        var regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://xn--e1agjb.xn--p1ai"));

        XCTAssertEqual(decoded[1].trigger.urlFilter, START_URL_UNESCAPED + "xn--e1agjb\\.xn--p1ai");

        regex = try! NSRegularExpression(pattern: decoded[1].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://xn--e1agjb.xn--p1ai"));
    }

    func testRegexRules() {
        var ruleText = #"/^https?://(?!static\.)([^.]+\.)+?fastpic\.ru[:/]/$script,domain=fastpic.ru"#;
        var result = converter.convertArray(rules: [ruleText]);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 1);

        ruleText = #"@@/:\/\/.*[.]wp[.]pl\/[a-z0-9_]{30,50}[.][a-z]{2,5}([\/:&\?].*)?$/"#;
        result = converter.convertArray(rules: [ruleText]);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 1);

        ruleText = #"@@/:\/\/.*[.]wp[.]pl\/[a-z0-9_]+[.][a-z]+\b/"#;
        result = converter.convertArray(rules: [ruleText]);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 1);

        ruleText = #"/example{/"#;
        result = converter.convertArray(rules: [ruleText]);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);
    }

    func testCssPseudoClasses() {
        let result = converter.convertArray(rules: [
                "w3schools1.com###main > table.w3-table-all.notranslate:first-child > tbody > tr:nth-child(17) > td.notranslate:nth-child(2)",
                "w3schools2.com###:root div.ads",
                "w3schools3.com###body div[attr='test']:first-child  div",
                "w3schools4.com##.todaystripe::after"
            ]
        );
        XCTAssertEqual(result?.convertedCount, 4);
        XCTAssertEqual(result?.errorsCount, 0);
    }

    func testUpperCaseDomains() {
        let result = converter.convertArray(rules: ["@@||UpperCase.test^$genericblock"]);
        XCTAssertEqual(result?.convertedCount, 1);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*uppercase.test"]);

        let regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://UpperCase.test"));
    }

    func testCspRules() {
        let result = converter.convertArray(rules: ["|blob:$script,domain=pornhub.com|xhamster.com|youporn.com"]);
        XCTAssertEqual(result?.convertedCount, 1);
    }

    func testElemhideRules() {
        let result = converter.convertArray(rules: [
            "lenta.ru###root > section.b-header.b-header-main.js-header:nth-child(4) > div.g-layout > div.row",
            "https://icdn.lenta.ru/images/2017/04/10/16/20170410160659586/top7_f07b6db166774abba29e0de2e335f50a.jpg",
            "@@||lenta.ru^$elemhide",
            "@@||lenta.ru^$elemhide,genericblock"
        ]);
        XCTAssertEqual(result?.convertedCount, 4);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 4);

        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, "#root > section.b-header.b-header-main.js-header:nth-child(4) > div.g-layout > div.row");

        XCTAssertEqual(decoded[1].trigger.urlFilter, URL_FILTER_URL_RULES_EXCEPTIONS);
        XCTAssertEqual(decoded[1].action.type, "ignore-previous-rules");
        XCTAssertEqual(decoded[1].trigger.ifDomain, ["*lenta.ru"]);

        XCTAssertEqual(decoded[2].trigger.urlFilter, "https:\\/\\/icdn\\.lenta\\.ru\\/images\\/2017\\/04\\/10\\/16\\/20170410160659586\\/top7_f07b6db166774abba29e0de2e335f50a\\.jpg");
        XCTAssertEqual(decoded[2].action.type, "block");

        XCTAssertEqual(decoded[3].trigger.urlFilter, START_URL_UNESCAPED + "lenta\\.ru" + URL_FILTER_REGEXP_END_SEPARATOR);
        XCTAssertEqual(decoded[3].action.type, "ignore-previous-rules");

        let regex = try! NSRegularExpression(pattern: decoded[3].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://lenta.ru"));
    }

    func testImportantModifierRules() {
        let result = converter.convertArray(rules: [
            "||example-url-block.org^",
            "||example-url-block-important.org^$important",
            "@@||example-url-block-exception.org^",
            "@@||example-url-block-exception-important.org^$important",
            "@@||example-url-block-exception-document.org^$document"
        ]);
        XCTAssertEqual(result?.convertedCount, 5);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 5);

        XCTAssertEqual(decoded[0].action.type, "block");
        XCTAssertEqual(decoded[0].trigger.urlFilter, START_URL_UNESCAPED + "example-url-block\\.org" + URL_FILTER_REGEXP_END_SEPARATOR);

        var regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://example-url-block.org"));

        XCTAssertEqual(decoded[1].action.type, "ignore-previous-rules");
        XCTAssertEqual(decoded[1].trigger.urlFilter, START_URL_UNESCAPED + "example-url-block-exception\\.org" + URL_FILTER_REGEXP_END_SEPARATOR);

        regex = try! NSRegularExpression(pattern: decoded[1].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://example-url-block-exception.org"));

        XCTAssertEqual(decoded[2].action.type, "block");
        XCTAssertEqual(decoded[2].trigger.urlFilter, START_URL_UNESCAPED + "example-url-block-important\\.org" + URL_FILTER_REGEXP_END_SEPARATOR);

        regex = try! NSRegularExpression(pattern: decoded[2].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://example-url-block-important.org"));

        XCTAssertEqual(decoded[3].action.type, "ignore-previous-rules");
        XCTAssertEqual(decoded[3].trigger.urlFilter, START_URL_UNESCAPED + "example-url-block-exception-important\\.org" + URL_FILTER_REGEXP_END_SEPARATOR);

        regex = try! NSRegularExpression(pattern: decoded[2].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://example-url-block-important.org"));

        XCTAssertEqual(decoded[4].action.type, "ignore-previous-rules");
        XCTAssertEqual(decoded[4].trigger.urlFilter, URL_FILTER_URL_RULES_EXCEPTIONS);
        XCTAssertEqual(decoded[4].trigger.ifDomain, ["*example-url-block-exception-document.org"]);
    }

    func testBadfilterRules() {
        let result = converter.convertArray(rules: [
            "||example.org^$image",
            "||test.org^",
            "||example.org^$badfilter,image"
        ]);
        XCTAssertEqual(result?.convertedCount, 1);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);

        XCTAssertEqual(decoded[0].trigger.urlFilter, START_URL_UNESCAPED + "test\\.org" + URL_FILTER_REGEXP_END_SEPARATOR);

        let regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://test.org"));
    }

    func testTldWildcardRules() {
        var result = converter.convertArray(rules: ["surge.*,testcases.adguard.*###case-5-wildcard-for-tld > .test-banner"]);
        XCTAssertEqual(result?.convertedCount, 2);

        var decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 2);
        XCTAssertEqual(decoded[0].trigger.urlFilter, URL_FILTER_CSS_RULES);
        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*surge.com");
        XCTAssertEqual(decoded[0].trigger.ifDomain?[1], "*surge.ru");
        XCTAssertEqual(decoded[0].trigger.ifDomain?[2], "*surge.net");
        XCTAssertEqual(decoded[0].trigger.ifDomain?.count, 250);

        XCTAssertEqual(decoded[1].trigger.urlFilter, URL_FILTER_CSS_RULES);
        XCTAssertNotNil(decoded[1].trigger.ifDomain?[0]);
        XCTAssertEqual(decoded[1].trigger.ifDomain?.count, 150);


        result = converter.convertArray(rules: ["||*/test-files/adguard.png$domain=surge.*|testcases.adguard.*"]);
        XCTAssertEqual(result?.convertedCount, 2);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 2);
        XCTAssertEqual(decoded[0].trigger.urlFilter, START_URL_UNESCAPED + ".*\\/test-files\\/adguard\\.png");
        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*surge.com");
        XCTAssertEqual(decoded[0].trigger.ifDomain?[1], "*surge.ru");
        XCTAssertEqual(decoded[0].trigger.ifDomain?[2], "*surge.net");
        XCTAssertEqual(decoded[0].trigger.ifDomain?.count, 250);

        var regex = try! NSRegularExpression(pattern: decoded[0].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://test.com/test-files/adguard.png"));

        XCTAssertEqual(decoded[1].trigger.urlFilter, START_URL_UNESCAPED + ".*\\/test-files\\/adguard\\.png");
        XCTAssertNotNil(decoded[1].trigger.ifDomain?[0]);
        XCTAssertEqual(decoded[1].trigger.ifDomain?.count, 150);

        regex = try! NSRegularExpression(pattern: decoded[1].trigger.urlFilter!);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://test.com/test-files/adguard.png"));

        result = converter.convertArray(rules: ["|http$script,domain=forbes.*"]);
        XCTAssertEqual(result?.convertedCount, 1);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].action.type, "block");
        XCTAssertEqual(decoded[0].trigger.urlFilter, "^http");
        XCTAssertEqual(decoded[0].trigger.resourceType, ["script"]);
        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*forbes.com");
        XCTAssertEqual(decoded[0].trigger.ifDomain?[1], "*forbes.ru");
        XCTAssertEqual(decoded[0].trigger.ifDomain?[2], "*forbes.net");
        XCTAssertEqual(decoded[0].trigger.ifDomain?[199], "*forbes.sh");
        XCTAssertEqual(decoded[0].trigger.ifDomain?.count, 200);
    }

    func testUboScriptletRules() {
        let ruleText = [
            "example.org##+js(aopr,__cad.cpm_popunder)",
            "example.org##+js(acis,setTimeout,testad)",
        ];

        let result = converter.convertArray(rules: ruleText, advancedBlocking: true);
        XCTAssertEqual(result?.errorsCount, 0);

        let decoded = try! parseJsonString(json: result!.advancedBlocking!);
        XCTAssertEqual(decoded.count, 2);

        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*example.org");
        XCTAssertEqual(decoded[0].action.type, "scriptlet");
        XCTAssertEqual(decoded[0].action.scriptlet, "ubo-aopr");
        XCTAssertEqual(decoded[0].action.scriptletParam, #"{"name":"ubo-aopr","args":["__cad.cpm_popunder"]}"#);

        XCTAssertEqual(decoded[1].trigger.ifDomain?[0], "*example.org");
        XCTAssertEqual(decoded[1].action.type, "scriptlet");
        XCTAssertEqual(decoded[1].action.scriptlet, "ubo-acis");
        XCTAssertEqual(decoded[1].action.scriptletParam, #"{"name":"ubo-acis","args":["setTimeout","testad"]}"#);
    }

    func testInvalidRegexpRules() {
        let ruleText = [
            #"/([0-9]{1,3}\.){3}[0-9]{1,3}.\/proxy$/$script,websocket,third-party"#
        ];

        let result = converter.convertArray(rules: ruleText);
        XCTAssertEqual(result?.errorsCount, 1);
        XCTAssertEqual(result?.convertedCount, 0);
    }

    func testCollisionCssAndScriptRules() {
        let ruleText = [
            "example.org##body",
            "example.org#%#alert('1');",
        ];

        let result = converter.convertArray(rules: ruleText);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.convertedCount, 1);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, "body");
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*example.org");
    }

    func testCollisionCssAndScriptletRules() {
        let ruleText = [
            "example.org##body",
            "example.org#%#//scriptlet('abort-on-property-read', 'I10C')",
        ];

        let result = converter.convertArray(rules: ruleText);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.convertedCount, 1);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, "body");
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*example.org");
    }

    func testCollisionCssAndScriptRulesAdvancedBlocking() {
        let ruleText = [
            "example.org##body",
            "example.org#%#alert('1');",
        ];

        let result = converter.convertArray(rules: ruleText, advancedBlocking: true);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.convertedCount, 1);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, "body");
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*example.org");

        let decodedAdvBlocking = try! parseJsonString(json: result!.advancedBlocking!);
        XCTAssertEqual(decodedAdvBlocking.count, 1);

        XCTAssertEqual(decodedAdvBlocking[0].trigger.ifDomain?[0], "*example.org");
        XCTAssertEqual(decodedAdvBlocking[0].action.type, "script");
        XCTAssertEqual(decodedAdvBlocking[0].action.script, "alert(\'1\');");
    }

    func testCollisionCssAndScriptletRulesAdvancedBlocking() {
        let ruleText = [
            "example.org##body",
            "example.org#%#//scriptlet('abort-on-property-read', 'I10C')",
        ];

        let result = converter.convertArray(rules: ruleText, advancedBlocking: true);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.convertedCount, 1);

        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, "body");
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*example.org");

        let decodedAdvBlocking = try! parseJsonString(json: result!.advancedBlocking!);
        XCTAssertEqual(decodedAdvBlocking.count, 1);

        XCTAssertEqual(decodedAdvBlocking[0].trigger.ifDomain?[0], "*example.org");
        XCTAssertEqual(decodedAdvBlocking[0].action.scriptlet, "abort-on-property-read");
        XCTAssertEqual(decodedAdvBlocking[0].action.scriptletParam, "{\"name\":\"abort-on-property-read\",\"args\":[\"I10C\"]}");
    }

    func testGenericCssRules() {
        let ruleText = [
            "#$?#div:has(> .banner) { display: none; debug: global; }",
        ];

        let result = converter.convertArray(rules: ruleText, advancedBlocking: true);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.advancedBlockingConvertedCount, 1);
    }

    func testCssInjectWithMultiSelectors() {
        let ruleText = [
            "google.com#$##js-header, #searchform, .O-j-k, .header:not(.column-section):not(.viewed):not(.ng-star-inserted):not([class*=\"_ngcontent\"]), .js-header.chr-header, .mobile-action-bar, body > .ng-scope, #flt-nav, .gws-flights__scrollbar-padding.gws-flights__selection-bar, .gws-flights__selection-bar-shadow-mask { position: absolute !important; }",
        ];
        let result = converter.convertArray(rules: ruleText, advancedBlocking: true);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.advancedBlockingConvertedCount, 1);

        let decoded = try! parseJsonString(json: result!.advancedBlocking!);
        XCTAssertEqual(decoded.count, 1);

        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*google.com"]);
        XCTAssertNil(decoded[0].trigger.unlessDomain);
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].action.type, "css-inject");
        XCTAssertEqual(decoded[0].action.css, "#js-header, #searchform, .O-j-k, .header:not(.column-section):not(.viewed):not(.ng-star-inserted):not([class*=\"_ngcontent\"]), .js-header.chr-header, .mobile-action-bar, body > .ng-scope, #flt-nav, .gws-flights__scrollbar-padding.gws-flights__selection-bar, .gws-flights__selection-bar-shadow-mask { position: absolute !important; }");
    }

    func testSpecialCharactersEscape() {
        var ruleText = [
            "+Popunder+$popup",
        ];

        var result = converter.convertArray(rules: ruleText);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.convertedCount, 1);

        var decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].action.type, "block");
        XCTAssertEqual(decoded[0].trigger.urlFilter, "\\+Popunder\\+");

        ruleText = [
            "||calabriareportage.it^+-Banner-",
        ];

        result = converter.convertArray(rules: ruleText);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.convertedCount, 1);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].action.type, "block");
        XCTAssertEqual(decoded[0].trigger.urlFilter, START_URL_UNESCAPED + "calabriareportage\\.it[/:&?]?\\+-Banner-");

        ruleText = [
            #"@@/:\/\/.*[.]wp[.]pl\/[a-z0-9_]+[.][a-z]+\\/"#,
        ];

        result = converter.convertArray(rules: ruleText);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.convertedCount, 1);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].action.type, "ignore-previous-rules");
        XCTAssertEqual(decoded[0].trigger.urlFilter, ":\\/\\/.*[.]wp[.]pl\\/[a-z0-9_]+[.][a-z]+\\\\");

        ruleText = [
            #"/\\/"#,
        ];

        result = converter.convertArray(rules: ruleText);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.convertedCount, 1);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].action.type, "block");
        XCTAssertEqual(decoded[0].trigger.urlFilter, "\\\\");
    }

    func testSpecifichide() {
        var ruleText: [String] = [
            "example.org##.banner1",
            "example.org,test.com##.banner2",
            "##.banner3",
            "@@||example.org^$specifichide",
        ];

        // should remain only "##.banner3" and "test.com##.banner2"

        var result = converter.convertArray(rules: ruleText);

        XCTAssertEqual(result?.totalConvertedCount, 2);
        XCTAssertEqual(result?.convertedCount, 2);
        XCTAssertEqual(result?.errorsCount, 0);

        var decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 2);

        XCTAssertNil(decoded[0].trigger.ifDomain);
        XCTAssertNil(decoded[0].trigger.unlessDomain);
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".banner3");

        XCTAssertEqual(decoded[1].trigger.ifDomain, ["*test.com"]);
        XCTAssertNil(decoded[1].trigger.unlessDomain);
        XCTAssertEqual(decoded[1].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[1].action.type, "css-display-none");
        XCTAssertEqual(decoded[1].action.selector, ".banner2");

        ruleText = [
            "example.org##.banner1",
            "##.banner2",
            "@@||example.org^$specifichide",
        ];

        // should remain only "##.banner2"

        result = converter.convertArray(rules: ruleText);

        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);

        XCTAssertNil(decoded[0].trigger.ifDomain);
        XCTAssertNil(decoded[0].trigger.unlessDomain);
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".banner2");

        ruleText = [
            "test.com,example.org#$#body { overflow: visible!important; }",
            "##.banner",
            "@@||example.org^$specifichide",
        ];

        // should remain only "##.banner" and "test.com#$#body { overflow: visible!important }"

        result = converter.convertArray(rules: ruleText, advancedBlocking: true);

        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.advancedBlockingConvertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);

        XCTAssertNil(decoded[0].trigger.ifDomain);
        XCTAssertNil(decoded[0].trigger.unlessDomain);
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".banner");

        var decodedAdvBlocking = try! parseJsonString(json: result!.advancedBlocking!);
        XCTAssertEqual(decodedAdvBlocking.count, 1);

        XCTAssertEqual(decodedAdvBlocking[0].trigger.ifDomain, ["*test.com"]);
        XCTAssertNil(decodedAdvBlocking[0].trigger.unlessDomain);
        XCTAssertEqual(decodedAdvBlocking[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decodedAdvBlocking[0].action.type, "css-inject");
        XCTAssertEqual(decodedAdvBlocking[0].action.css, "body { overflow: visible!important; }");

        ruleText = [
            "test.com,example.org#$?#div:has(> .banner) { visibility: hidden!important; }",
            "##.banner",
            "example.org#$#.adsblock { opacity: 0!important; }",
            "@@||example.org^$specifichide",
        ];

        // should remain only "##.banner" and "test.com#$?#div:has(> .banner) { visibility: hidden!important; }"

        result = converter.convertArray(rules: ruleText, advancedBlocking: true);

        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.advancedBlockingConvertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);

        XCTAssertNil(decoded[0].trigger.ifDomain);
        XCTAssertNil(decoded[0].trigger.unlessDomain);
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".banner");

        decodedAdvBlocking = try! parseJsonString(json: result!.advancedBlocking!);
        XCTAssertEqual(decodedAdvBlocking.count, 1);

        XCTAssertEqual(decodedAdvBlocking[0].trigger.ifDomain, ["*test.com"]);
        XCTAssertNil(decodedAdvBlocking[0].trigger.unlessDomain);
        XCTAssertEqual(decodedAdvBlocking[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decodedAdvBlocking[0].action.type, "css-extended");
        XCTAssertEqual(decodedAdvBlocking[0].action.css, "div:has(> .banner) { visibility: hidden!important; }");

        ruleText = [
            "test.subdomain.test.com##.banner",
            "test.com##.headeads",
            "##.ad-banner",
            "@@||subdomain.test.com^$specifichide",
        ];

        // should remain "##.ad-banner", "test.subdomain.test.com##.banner" and "test.com##.headeads"

        result = converter.convertArray(rules: ruleText);

        XCTAssertEqual(result?.totalConvertedCount, 3);
        XCTAssertEqual(result?.convertedCount, 3);
        XCTAssertEqual(result?.errorsCount, 0);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 3);
        
        XCTAssertTrue(checkEntriesByCondition(
                        entries: decoded,
                        condition: {
                            $0.trigger.ifDomain == nil &&
                            $0.trigger.unlessDomain == nil &&
                            $0.trigger.urlFilter == ".*" &&
                            $0.action.type == "css-display-none" &&
                            $0.action.selector == ".ad-banner"
                            
                        }));
        
        XCTAssertTrue(checkEntriesByCondition(
                        entries: decoded,
                        condition: {
                            $0.trigger.ifDomain == ["*test.subdomain.test.com"] &&
                            $0.trigger.unlessDomain == nil &&
                            $0.trigger.urlFilter == ".*" &&
                            $0.action.type == "css-display-none" &&
                            $0.action.selector == ".banner"
                            
                        }));
        
        XCTAssertTrue(checkEntriesByCondition(
                        entries: decoded,
                        condition: {
                            $0.trigger.ifDomain == ["*test.com"] &&
                            $0.trigger.unlessDomain == nil &&
                            $0.trigger.urlFilter == ".*" &&
                            $0.action.type == "css-display-none" &&
                            $0.action.selector == ".headeads"
                        }));
        

        ruleText = [
            "example1.org,example2.org,example3.org##.banner1",
            "@@||example1.org^$specifichide",
            "@@||example2.org^$specifichide"
        ];

        // should remain only "example3.org##.banner1"

        result = converter.convertArray(rules: ruleText);

        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);

        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example3.org"]);
        XCTAssertNil(decoded[0].trigger.unlessDomain);
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".banner1");
        
        ruleText = [
            "#$#.banner { color: red!important; }",
            "@@||example.org^$specifichide",
        ];

        // should remain only "##.banner { color: red!important; }"

        result = converter.convertArray(rules: ruleText, advancedBlocking: true);

        XCTAssertEqual(result?.totalConvertedCount, 0);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.advancedBlockingConvertedCount, 1);

        decoded = try! parseJsonString(json: result!.advancedBlocking!);
        XCTAssertEqual(decoded.count, 1);

        XCTAssertNil(decoded[0].trigger.ifDomain);
        XCTAssertNil(decoded[0].trigger.unlessDomain);
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].action.type, "css-inject");
        XCTAssertEqual(decoded[0].action.css, ".banner { color: red!important; }");
    }

    func testEscapeBackslash() {
        var ruleText = [
            "||gamer.no/?module=Tumedia\\DFProxy\\Modules^",
        ];
        var result = converter.convertArray(rules: ruleText);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.convertedCount, 1);
        var decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertTrue(decoded[0].trigger.urlFilter!.contains("Tumedia\\\\DFProxy\\\\Modules"));

        ruleText = [
            "||xyz^$third-party,script,xmlhttprequest,domain=~anidub.com|~animedia.pro|~animeheaven.ru|~app.element.io|~assistir-filme.biz|~avtomaty-i-bonusy.com|~chelentano.top|~coomeet.com|~crackstreams.com|~crackstreams.ga|~csgoreports.com|~cvid.kiev.ua|~estream.to|~europixhd.io|~films.hds-stream.com|~funtik.tv|~getvi.tv|~hanime.tv|~hentaiz.org|~herokuapp.com|~infoua.biz|~jokehd.com|~jokerswidget.com|~kinobig.me|~kinoguru.be|~kinoguru.me|~kristinita.ru|~live-golf.stream|~lookbase.xyz|~magicfilm.net|~mail.google.com|~map-a-date.cc|~matchat.online|~mikeamigorein.xyz|~miranimbus.ru|~my.mail.ru|~nccg.ru|~newdeaf.club|~newdmn.icu​|~onmovies.se|~playjoke.xyz|~roadhub.ru|~roblox.com|~sextop.net|~soccer365.ru|~soonwalk.net|~sportsbay.org|~streetbee.io|~streetbee.ru|~telerium.club|~telerium.live|~uacycling.info|~uploadedpremiumlink.net|~vk.com|~vmeste.tv|~web.app",
        ];

        result = converter.convertArray(rules: ruleText);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.convertedCount, 1);
        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertTrue(decoded[0].trigger.urlFilter!.contains("^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?xyz" + URL_FILTER_REGEXP_END_SEPARATOR));

        ruleText = [
            "/g\\.alicdn\\.com\\/mm\\/yksdk\\/0\\.2\\.\\d+\\/playersdk\\.js/>>>1111.51xiaolu.com/playersdk.js>>>>keyword=playersdk",
        ];
        result = converter.convertArray(rules: ruleText);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.convertedCount, 1);
        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertTrue(decoded[0].trigger.urlFilter!.contains(".com\\\\\\/mm\\\\\\/yksdk"));
    }

    func testCssExceptions() {
        var rules = ["test.com,example.com##.ad-banner", "test.com#@#.ad-banner"]
        var result = ContentBlockerConverter().convertArray(rules: rules);

        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);

        var decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.com"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".ad-banner");

        rules = ["test.com##.ad-banner", "test.com#@#.ad-banner"]
        result = ContentBlockerConverter().convertArray(rules: rules);

        XCTAssertEqual(result?.totalConvertedCount, 0);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.converted, "[]");

        rules = ["##.ad-banner", "test.com#@#.ad-banner"]
        result = ContentBlockerConverter().convertArray(rules: rules);

        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertNil(decoded[0].trigger.ifDomain);
        XCTAssertEqual(decoded[0].trigger.unlessDomain, ["*test.com"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".ad-banner");

        rules = ["##.ad-banner", "test.com#@#.ad-banner", "test.com##.ad-banner"]
        result = ContentBlockerConverter().convertArray(rules: rules);

        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertNil(decoded[0].trigger.ifDomain);
        XCTAssertEqual(decoded[0].trigger.unlessDomain, ["*test.com"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".ad-banner");

        rules = ["test.com#@##banner", "example.org#@##banner", "###banner"]
        result = ContentBlockerConverter().convertArray(rules: rules);

        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertNil(decoded[0].trigger.ifDomain);
        XCTAssertEqual(decoded[0].trigger.unlessDomain, ["*test.com", "*example.org"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, "#banner");

        rules = ["~test.com##.ad-banner", "~test.com#@#.ad-banner"]
        result = ContentBlockerConverter().convertArray(rules: rules);

        XCTAssertEqual(result?.totalConvertedCount, 0);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.converted, "[]");

        rules = ["subdomain.example.org##.ad-banner", "example.org#@#.ad-banner"]
        result = ContentBlockerConverter().convertArray(rules: rules);

        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*subdomain.example.org"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".ad-banner");
        
        rules = ["example.org###banner", "#@##banner"];
        
        result = ContentBlockerConverter().convertArray(rules: rules);

        XCTAssertEqual(result?.totalConvertedCount, 0);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 0);
        
        rules = ["~example.org###banner", "#@##banner"];
        
        result = ContentBlockerConverter().convertArray(rules: rules);

        XCTAssertEqual(result?.totalConvertedCount, 0);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 0);
        
        rules = ["example.org###banner", "*#@##banner"];
        
        result = ContentBlockerConverter().convertArray(rules: rules);

        XCTAssertEqual(result?.totalConvertedCount, 0);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 0);
        
        rules = [
            "example.org,test.com,ya.ru###banner",
            "example.org,test.com,ya.ru#@##banner"
        ];
        
        result = ContentBlockerConverter().convertArray(rules: rules);

        XCTAssertEqual(result?.totalConvertedCount, 0);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 0);
    }

    func testAdvancedBlockingExceptions() {
        func assertEmptyResult(result: ConversionResult) -> Void {
            XCTAssertEqual(result.totalConvertedCount, 0);
            XCTAssertEqual(result.convertedCount, 0);
            XCTAssertEqual(result.advancedBlockingConvertedCount, 0);
            XCTAssertEqual(result.errorsCount, 0);
            XCTAssertEqual(result.converted, "[]");
            XCTAssertNil(result.advancedBlocking);
        }

        var rules = [
            "test.com#%#window.__testCase2 = true;",
            "test.com#@%#window.__testCase2 = true;",
            "test.com#$#.banner { display: none!important; }",
            "test.com#@$#.banner { display: none!important; }",
            "test.com#$?#div:has(> .banner) { display: none!important; }",
            "test.com#@$?#div:has(> .banner) { display: none!important; }",
            "test.com#%#//scriptlet('abort-on-property-read', 'abc')",
            "test.com#@%#//scriptlet('abort-on-property-read', 'abc')",
        ]

        var result = ContentBlockerConverter().convertArray(rules: rules, advancedBlocking: true);

        XCTAssertEqual(result?.errorsCount, 0);
        assertEmptyResult(result: result!);

        rules = [
            "~test.com#%#window.__testCase2 = true;",
            "~test.com#@%#window.__testCase2 = true;",
            "~test.com#$#.banner { display: none!important; }",
            "~test.com#@$#.banner { display: none!important; }",
            "~test.com#$?#div:has(> .banner) { display: none!important; }",
            "~test.com#@$?#div:has(> .banner) { display: none!important; }",
            "~test.com#%#//scriptlet('abort-on-property-read', 'abc')",
            "~test.com#@%#//scriptlet('abort-on-property-read', 'abc')",
        ]

        result = ContentBlockerConverter().convertArray(rules: rules, advancedBlocking: true);

        XCTAssertEqual(result?.errorsCount, 0);
        assertEmptyResult(result: result!);

        // css-inject exception
        rules = ["test.com,example.org#$#.banner { display: none!important; }", "test.com#@$#.banner { display: none!important; }"]
        result = ContentBlockerConverter().convertArray(rules: rules, advancedBlocking: true);

        var decoded = try! parseJsonString(json: result!.advancedBlocking!);
        XCTAssertEqual(decoded.count, 1);

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org"]);
        XCTAssertNil(decoded[0].trigger.unlessDomain);
        XCTAssertEqual(decoded[0].action.type, "css-inject");
        XCTAssertEqual(decoded[0].action.css, ".banner { display: none!important; }");

        // css-extended exception
        rules = ["test.com,example.org#?#div:has(> .banner)", "test.com#@?#div:has(> .banner)"]
        result = ContentBlockerConverter().convertArray(rules: rules, advancedBlocking: true);

        decoded = try! parseJsonString(json: result!.advancedBlocking!);
        XCTAssertEqual(decoded.count, 1);

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org"]);
        XCTAssertNil(decoded[0].trigger.unlessDomain);
        XCTAssertEqual(decoded[0].action.type, "css-extended");
        XCTAssertEqual(decoded[0].action.css, "div:has(> .banner)");

        // script exception
        rules = ["test.com,example.org#%#alert(1)", "test.com#@%#alert(1)"]
        result = ContentBlockerConverter().convertArray(rules: rules, advancedBlocking: true);

        decoded = try! parseJsonString(json: result!.advancedBlocking!);
        XCTAssertEqual(decoded.count, 1);

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org"]);
        XCTAssertNil(decoded[0].trigger.unlessDomain);
        XCTAssertEqual(decoded[0].action.type, "script");
        XCTAssertEqual(decoded[0].action.script, "alert(1)");

        // scriptlet exception
        rules = ["test.com,example.org#%#//scriptlet('abort-on-property-read', 'abc')", "test.com#@%#//scriptlet('abort-on-property-read', 'abc')"]
        result = ContentBlockerConverter().convertArray(rules: rules, advancedBlocking: true);

        decoded = try! parseJsonString(json: result!.advancedBlocking!);
        XCTAssertEqual(decoded.count, 1);

        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org"]);
        XCTAssertNil(decoded[0].trigger.unlessDomain);
        XCTAssertEqual(decoded[0].action.type, "scriptlet");
        XCTAssertEqual(decoded[0].action.scriptlet, "abort-on-property-read");
    }

    static var allTests = [
        ("testEmpty", testEmpty),
        ("testConvertComment", testConvertComment),
        ("testConvertNetworkRule", testConvertNetworkRule),
        ("testPopupRules", testPopupRules),
        ("testConvertFirstPartyRule", testConvertFirstPartyRule),
        ("testConvertWebsocketRules", testConvertWebsocketRules),
        ("testConvertScriptRestrictRules", testConvertScriptRestrictRules),
        ("testConvertSubdocumentFirstParty", testConvertSubdocumentFirstParty),
        ("testConvertSubdocumentThirdParty", testConvertSubdocumentThirdParty),
        ("testAddUnlessDomainsForThirdParty", testAddUnlessDomainsForThirdParty),
        ("testConvertEmptyRegex", testConvertEmptyRegex),
        ("testConvertInvertedWhitelistRule", testConvertInvertedWhitelistRule),
        ("testConvertGenerichide", testConvertGenerichide),
        ("testConvertGenericDomainSensitive", testConvertGenericDomainSensitive),
        ("testConvertGenericDomainSensitiveSortingOrder", testConvertGenericDomainSensitiveSortingOrder),
        ("testConvertGenericDomainSensitiveSortingOrderGenerichide", testConvertGenericDomainSensitiveSortingOrderGenerichide),
        ("testConvertGenericDomainSensitiveSortingOrderElemhide", testConvertGenericDomainSensitiveSortingOrderElemhide),
        ("testConvertCompactDomainSensitiveElemhide", testConvertCompactDomainSensitiveElemhide),
        ("testCyrillicRules", testCyrillicRules),
        ("testRegexRules", testRegexRules),
        ("testCssPseudoClasses", testCssPseudoClasses),
        ("testUpperCaseDomains", testUpperCaseDomains),
        ("testCspRules", testCspRules),
        ("testElemhideRules", testElemhideRules),
        ("testImportantModifierRules", testImportantModifierRules),
        ("testBadfilterRules", testBadfilterRules),
        ("testTldWildcardRules", testTldWildcardRules),
        ("testUboScriptletRules", testUboScriptletRules),
        ("testInvalidRegexpRules", testInvalidRegexpRules),
        ("testCollisionCssAndScriptRules", testCollisionCssAndScriptRules),
        ("testCollisionCssAndScriptletRules", testCollisionCssAndScriptletRules),
        ("testCollisionCssAndScriptRulesAdvancedBlocking", testCollisionCssAndScriptRulesAdvancedBlocking),
        ("testCollisionCssAndScriptletRulesAdvancedBlocking", testCollisionCssAndScriptletRulesAdvancedBlocking),
        ("testGenericCssRules", testGenericCssRules),
        ("testCssInjectWithMultiSelectors", testCssInjectWithMultiSelectors),
        ("testSpecialCharactersEscape", testSpecialCharactersEscape),
        ("testSpecifichide", testSpecifichide),
        ("testEscapeBackslash", testEscapeBackslash),
        ("testCssExceptions", testCssExceptions),
        ("testAdvancedBlockingExceptions", testAdvancedBlockingExceptions),
    ]
}
