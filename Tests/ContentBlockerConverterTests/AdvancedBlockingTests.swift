import XCTest
@testable import ContentBlockerConverter

final class AdvancedBlockingTests: XCTestCase {
    let URL_FILTER_ANY_URL = "^[htpsw]+:\\/\\/";
    let URL_FILTER_REGEXP_START_URL = "^[htpsw]+:\\\\/\\\\/([a-z0-9-]+\\\\.)?";

    let START_URL_UNESCAPED = "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?";
    let URL_FILTER_WS_ANY_URL_UNESCAPED = "^wss?:\\/\\/";
    let URL_FILTER_REGEXP_SEPARATOR = "([\\/:&\\?].*)?$";
    let URL_FILTER_CSS_RULES = ".*";
    let URL_FILTER_URL_RULES_EXCEPTIONS = ".*";

    let converter = ContentBlockerConverter();

    private func parseJsonString(json: String) throws -> [BlockerEntry] {
        let data = json.data(using: String.Encoding.utf8, allowLossyConversion: false)!

        let decoder = JSONDecoder();
        let parsedData = try decoder.decode([BlockerEntry].self, from: data);

        return parsedData;
    }

    func testAdvancedBlockingParam() {
        let result = converter.convertArray(rules: ["filmitorrent.xyz#$#.content { margin-top: 0!important; }"], advancedBlocking: false);
        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlocking, nil);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 0);
    }

    func testAdvancedBlockingScriptRules() {
        let result = converter.convertArray(rules: [
            "example.org,example-more.com#%#alert(1);",
            "~test.com#%#alert(2);"
        ], advancedBlocking: true);

        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 2);

        let decoded = try! parseJsonString(json: result.advancedBlocking!);
        XCTAssertEqual(decoded.count, 2);
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.ifDomain?[0], "*example.org");
        XCTAssertEqual(decoded[0].trigger.ifDomain?[1], "*example-more.com");
        XCTAssertEqual(decoded[0].trigger.unlessDomain, nil);
        XCTAssertEqual(decoded[0].action.type, "script");
        XCTAssertEqual(decoded[0].action.script, "alert(1);");

        XCTAssertEqual(decoded[1].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[1].trigger.ifDomain, nil);
        XCTAssertEqual(decoded[1].trigger.unlessDomain, ["*test.com"]);
        XCTAssertEqual(decoded[1].action.type, "script");
        XCTAssertEqual(decoded[1].action.script, "alert(2);");
    }

    func testScriptRulesExceptions() {
        let result = converter.convertArray(rules: [
            "#%#window.__gaq = undefined;",
            "example.com#@%#window.__gaq = undefined;"
        ], advancedBlocking: true);

        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 1);

        let decoded = try! parseJsonString(json: result.advancedBlocking!);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.unlessDomain, ["*example.com"]);
        XCTAssertEqual(decoded[0].action.type, "script");
        XCTAssertEqual(decoded[0].action.script, "window.__gaq = undefined;");
    }

    func testScriptRulesJsinject() {
        let result = converter.convertArray(rules: [
            "example.com#%#alert(1);",
            "@@||example.com^$jsinject"
        ], advancedBlocking: true);

        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 2);

        let decoded = try! parseJsonString(json: result.advancedBlocking!);
        XCTAssertEqual(decoded.count, 2);
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.com"]);
        XCTAssertEqual(decoded[0].action.type, "script");
        XCTAssertEqual(decoded[0].action.script, "alert(1);");

        XCTAssertEqual(decoded[1].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[1].trigger.ifDomain, ["*example.com"]);
        XCTAssertEqual(decoded[1].action.script, nil);
    }

    func testScriptRulesDocument() {
        let result = converter.convertArray(rules: [
            "example.com#%#alert(2);",
            "@@||example.com^$document"
        ], advancedBlocking: true);

        XCTAssertEqual(result.convertedCount, 1);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 2);

        let decoded = try! parseJsonString(json: result.advancedBlocking!);
        XCTAssertEqual(decoded.count, 2);
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.com"]);
        XCTAssertEqual(decoded[0].action.type, "script");
        XCTAssertEqual(decoded[0].action.script, "alert(2);");

        XCTAssertEqual(decoded[1].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[1].trigger.ifDomain, ["*example.com"]);
        XCTAssertEqual(decoded[1].action.type, "ignore-previous-rules");
        XCTAssertEqual(decoded[1].action.script, nil);
    }

    func testExtendedCssRules() {
        let result = converter.convertArray(rules: [
            "ksl.com#?#.queue:-abp-has(.sponsored)",
            #"yelp.com#?#li[class^="domtags--li"]:-abp-has(a[href^="/adredir?"])"#
        ], advancedBlocking: true);

        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 2);

        let decoded = try! parseJsonString(json: result.advancedBlocking!);
        XCTAssertEqual(decoded.count, 2);
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*ksl.com"]);
        XCTAssertEqual(decoded[0].action.type, "css-extended");
        XCTAssertEqual(decoded[0].action.css, ".queue:-abp-has(.sponsored)");

        XCTAssertEqual(decoded[1].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[1].trigger.ifDomain, ["*yelp.com"]);
        XCTAssertEqual(decoded[1].action.type, "css-extended");
        XCTAssertEqual(decoded[1].action.css, "li[class^=\"domtags--li\"]:-abp-has(a[href^=\"/adredir?\"])");
    }

    func testExtendedCssRulesExceptionsElemhide() {
        let result = converter.convertArray(rules: [
            "ksl.com#?#.queue:-abp-has(.sponsored)",
            "@@||ksl.com^$elemhide"
        ], advancedBlocking: true);

        XCTAssertEqual(result.convertedCount, 1);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 2);

        let decoded = try! parseJsonString(json: result.advancedBlocking!);
        XCTAssertEqual(decoded.count, 2);
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*ksl.com"]);
        XCTAssertEqual(decoded[0].action.type, "css-extended");
        XCTAssertEqual(decoded[0].action.css, ".queue:-abp-has(.sponsored)");

        XCTAssertEqual(decoded[1].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[1].trigger.ifDomain, ["*ksl.com"]);
        XCTAssertEqual(decoded[1].action.type, "ignore-previous-rules");
        XCTAssertEqual(decoded[1].action.css, nil);
    }

    func testExtendedCssRulesExceptionsDocument() {
        let result = converter.convertArray(rules: [
            "ksl.com#?#.queue:-abp-has(.sponsored)",
            "@@||ksl.com^$document"
        ], advancedBlocking: true);

        XCTAssertEqual(result.convertedCount, 1);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 2);

        let decoded = try! parseJsonString(json: result.advancedBlocking!);
        XCTAssertEqual(decoded.count, 2);
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*ksl.com"]);
        XCTAssertEqual(decoded[0].action.type, "css-extended");
        XCTAssertEqual(decoded[0].action.css, ".queue:-abp-has(.sponsored)");

        XCTAssertEqual(decoded[1].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[1].trigger.ifDomain, ["*ksl.com"]);
        XCTAssertEqual(decoded[1].action.type, "ignore-previous-rules");
        XCTAssertEqual(decoded[1].action.css, nil);
    }

    func testCosmeticCssRules() {
        let result = converter.convertArray(rules: [
            "filmitorrent.xyz#$#.content { margin-top: 0!important; }"
        ], advancedBlocking: true);

        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 1);

        let decoded = try! parseJsonString(json: result.advancedBlocking!);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*filmitorrent.xyz"]);
        XCTAssertEqual(decoded[0].action.type, "css-inject");
        XCTAssertEqual(decoded[0].action.css, ".content { margin-top: 0!important; }");
    }

    func testCosmeticCssRulesInvalids() {
        let result = converter.convertArray(rules: [
            #"filmitorrent.xyz#$#.content { url("http://example.com/style.css") }"#
        ], advancedBlocking: true);

        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 1);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 0);
    }

    func testCosmeticCssRulesExceptions() {
        var result = converter.convertArray(rules: [
            "example.com##h1",
            "example.com#@$#div { max-height: 2px !important; }"
        ], advancedBlocking: true);

        XCTAssertEqual(result.convertedCount, 1);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 0);

        result = converter.convertArray(rules: [
            "example.com#$#div { max-height: 2px !important; }",
            "example.com#@$#div { max-height: 2px !important; }"
        ], advancedBlocking: true);

        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 0);

        result = converter.convertArray(rules: [
            "example.com##h1",
            "example.com#$#div { max-height: 2px !important; }",
            "example.com#@$#div { max-height: 2px !important; }"
        ], advancedBlocking: true);

        XCTAssertEqual(result.convertedCount, 1);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 0);
    }

    func testScriptletRules() {
        let result = converter.convertArray(rules: [
            "example.org#%#//scriptlet('abort-on-property-read', 'I10C')"
        ], advancedBlocking: true);

        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 1);

        let decoded = try! parseJsonString(json: result.advancedBlocking!);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*");
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org"]);
        XCTAssertEqual(decoded[0].action.type, "scriptlet");
        XCTAssertEqual(decoded[0].action.scriptlet, "abort-on-property-read");
        XCTAssertEqual(decoded[0].action.scriptletParam, "{\"name\":\"abort-on-property-read\",\"args\":[\"I10C\"]}");
    }

    func testScriptletRulesExceptions() {
        let result = converter.convertArray(rules: [
            "example.org#%#//scriptlet('abort-on-property-read', 'I10C')",
            "example.org#@%#//scriptlet('abort-on-property-read', 'I10C')"
        ], advancedBlocking: true);

        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 0);
    }

    func testScriptletRulesArgumentWithComma() {
        let result = converter.convertArray(rules: [
            "foxracingshox.de#%#//scriptlet('ubo-rc.js', 'cookie--not-set', ', stay')"
        ], advancedBlocking: true)

        XCTAssertEqual(result.convertedCount, 0)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.advancedBlockingConvertedCount, 1)

        let decoded = try! parseJsonString(json: result.advancedBlocking!)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].trigger.urlFilter, ".*")
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*foxracingshox.de"])
        XCTAssertEqual(decoded[0].action.type, "scriptlet")
        XCTAssertEqual(decoded[0].action.scriptlet, "ubo-rc.js")
        XCTAssertEqual(decoded[0].action.scriptletParam, "{\"name\":\"ubo-rc.js\",\"args\":[\"cookie--not-set\",\", stay\"]}")
    }

    func testCompileCssInjectRule() {
            let compiler = Compiler(
                optimize: false,
                advancedBlocking: true,
                errorsCounter: ErrorsCounter()
            );
            let rule = try! CosmeticRule(ruleText: "test.com#$#.banner { top: -9999px!important; }");
            let result = compiler.compileRules(rules: [rule as Rule]);

            XCTAssertNotNil(result);
            XCTAssertEqual(result.errorsCount, 0);
            XCTAssertEqual(result.rulesCount, 1);
            XCTAssertNotNil(result.сssInjects);
            XCTAssertEqual(result.сssInjects[0].action.type, "css-inject");
            XCTAssertEqual(result.сssInjects[0].trigger.ifDomain, ["test.com"]);
            XCTAssertEqual(result.сssInjects[0].action.css, ".banner { top: -9999px!important; }");
        }

    func testCompileExtendedCssRule() {
        let compiler = Compiler(
            optimize: false,
            advancedBlocking: true,
            errorsCounter: ErrorsCounter()
        );

        let rule = try! CosmeticRule(ruleText: "test.com#?#.content:has(> .test_selector)");
        let result = compiler.compileRules(rules: [rule as Rule]);

        XCTAssertNotNil(result)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.rulesCount, 1)
        XCTAssertNotNil(result.extendedCssBlockingDomainSensitive)
        XCTAssertEqual(result.extendedCssBlockingDomainSensitive[0].action.type, "css-extended")
        XCTAssertEqual(result.extendedCssBlockingDomainSensitive[0].trigger.ifDomain, ["test.com"])
        XCTAssertEqual(result.extendedCssBlockingDomainSensitive[0].action.css, ".content:has(> .test_selector)")
    }

    func testAdvancedBlockingFormatParam() {
        let result = converter.convertArray(
                rules: ["example.org#$#.content { margin-top: 0!important; }"],
                advancedBlocking: true,
                advancedBlockingFormat: AdvancedBlockingFormat.json
        );
        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 1);
        XCTAssertEqual(result.advancedBlockingText, nil);

        let decoded = try! parseJsonString(json: result.advancedBlocking!);
        XCTAssertEqual(decoded.count, 1);
    }

    func testAdvancedBlockingText() {
        let networkRule = "||example.org^"
        let cssRule = "example.com##div.textad";
        let injectCssRule = "example.org#$#.div { background:none!important; }";
        let extendedCssRule = "example.org#?#div:has(> a[target=\"_blank\"][rel=\"nofollow\"])"
        let extendedInjectCssRule = "example.com#$?#h3:contains(cookies) { display: none!important; }"
        let scriptRule = "example.org#%#window.__gaq = undefined;"
        let scriptletRule = "example.org#%#//scriptlet(\"abort-on-property-read\", \"alert\")"

        let simpleRules = [
            cssRule,
            networkRule,
        ]

        let advancedRules = [
            injectCssRule,
            extendedCssRule,
            extendedInjectCssRule,
            scriptRule,
            scriptletRule
        ]

        let rules = simpleRules + advancedRules

        let result = converter.convertArray(
                rules: rules,
                advancedBlocking: true,
                advancedBlockingFormat: AdvancedBlockingFormat.txt
        );
        XCTAssertEqual(result.convertedCount, simpleRules.count);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlocking, nil);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 0);
        XCTAssertEqual(result.advancedBlockingText, advancedRules.joined(separator: "\n"));
    }

    func testAdvancedBlockingParamFalse() {
        var result = converter.convertArray(
                rules: ["example.org#$#.content { margin-top: 0!important; }"],
                advancedBlocking: false,
                advancedBlockingFormat: AdvancedBlockingFormat.json
        );
        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 0);
        XCTAssertEqual(result.advancedBlocking, nil);
        XCTAssertEqual(result.advancedBlockingText, nil);

        result = converter.convertArray(
                rules: ["example.org#$#.content { margin-top: 0!important; }"],
                advancedBlocking: false,
                advancedBlockingFormat: AdvancedBlockingFormat.txt
        );

        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 0);
        XCTAssertEqual(result.advancedBlocking, nil);
        XCTAssertEqual(result.advancedBlockingText, nil);
    }

    func testAdvancedBlockingTextWithAllowlistRules() {
        let allowlistRule = "@@||example.org^$document"
        let injectCssRule = "example.org#$#.div { background:none!important; }";
        let injectCssRuleAllowlist = "example.org#@$#.div { background:none!important; }";
        let extendedCssRule = "example.org#?#div:has(> a[target=\"_blank\"][rel=\"nofollow\"])"
        let extendedCssRuleAllowlist = "example.org#@?#div:has(> a[target=\"_blank\"][rel=\"nofollow\"])"
        let extendedInjectCssRule = "example.com#$?#h3:contains(cookies) { display: none!important; }"
        let extendedInjectCssRuleAllowlist = "example.com#@$?#h3:contains(cookies) { display: none!important; }"
        let scriptRule = "example.org#%#window.__gaq = undefined;"
        let scriptRuleAllowlist = "example.org#@%#window.__gaq = undefined;"
        let scriptletRule = "example.org#%#//scriptlet(\"abort-on-property-read\", \"alert\")"

        let rules = [
            injectCssRule,
            injectCssRuleAllowlist,
            extendedCssRule,
            extendedCssRuleAllowlist,
            extendedInjectCssRule,
            extendedInjectCssRuleAllowlist,
            scriptRule,
            scriptRuleAllowlist,
            scriptletRule
        ]

        let result = converter.convertArray(
            // conjunct arrays in this way,
            // because createRules method adds allowlist rules to the end of the list
            rules: rules + [allowlistRule],
            advancedBlocking: true,
            advancedBlockingFormat: AdvancedBlockingFormat.txt
        );

        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.convertedCount, 1);
        XCTAssertEqual(result.totalConvertedCount, 1);
        XCTAssertEqual(result.advancedBlocking, nil);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 0);
        // conjunct arrays in this way,
        // because createRules method adds allowlist rules to the end of the list
        XCTAssertEqual(result.advancedBlockingText, (rules + [allowlistRule]).joined(separator: "\n"));
    }

    func testAdvancedBlockingTextWithExceptionModifiers() {
        let injectCssRule = "example.org#$#.div { background:none!important; }";
        let extendedCssRule = "example.org#?#div:has(> a[target=\"_blank\"][rel=\"nofollow\"])"
        let extendedInjectCssRule = "example.com#$?#h3:contains(cookies) { display: none!important; }"
        let scriptRule = "example.org#%#window.__gaq = undefined;"
        let scriptletRule = "example.org#%#//scriptlet(\"abort-on-property-read\", \"alert\")"
        // Rules with exception modifiers
        let elemhideAllowlistRule = "@@||example.org^$elemhide";
        let generichideAllowlistRule = "@@||example.org^$generichide";
        let jsinjectAllowlistRule = "@@||example.org^$jsinject";

        let rules = [
            injectCssRule,
            extendedCssRule,
            extendedInjectCssRule,
            scriptRule,
            scriptletRule,
            elemhideAllowlistRule,
            generichideAllowlistRule,
            jsinjectAllowlistRule,
        ]

        let result = converter.convertArray(
            // conjunct arrays in this way,
            // because createRules method adds allowlist rules to the end of the list
            rules: rules,
            advancedBlocking: true,
            advancedBlockingFormat: AdvancedBlockingFormat.txt
        );

        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.advancedBlocking, nil);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 0);
        // conjunct arrays in this way,
        // because createRules method adds allowlist rules to the end of the list
        XCTAssertEqual(result.advancedBlockingText, (rules).joined(separator: "\n"));
    }

    static var allTests = [
        ("testAdvancedBlockingParam", testAdvancedBlockingParam),
        ("testAdvancedBlockingScriptRules", testAdvancedBlockingScriptRules),
        ("testScriptRulesExceptions", testScriptRulesExceptions),
        ("testScriptRulesJsinject", testScriptRulesJsinject),
        ("testScriptRulesDocument", testScriptRulesDocument),
        ("testExtendedCssRules", testExtendedCssRules),
        ("testExtendedCssRulesExceptionsElemhide", testExtendedCssRulesExceptionsElemhide),
        ("testExtendedCssRulesExceptionsDocument", testExtendedCssRulesExceptionsDocument),
        ("testCosmeticCssRules", testCosmeticCssRules),
        ("testCosmeticCssRulesInvalids", testCosmeticCssRulesInvalids),
        ("testCosmeticCssRulesExceptions", testCosmeticCssRulesExceptions),
        ("testScriptletRules", testScriptletRules),
        ("testScriptletRulesExceptions", testScriptletRulesExceptions),
        ("testScriptletRulesArgumentWithComma", testScriptletRulesArgumentWithComma),
        ("testCompileCssInjectRule", testCompileCssInjectRule),
        ("testCompileExtendedCssRule", testCompileExtendedCssRule),
        ("testAdvancedBlockingText", testAdvancedBlockingText),
        ("testAdvancedBlockingParamFalse", testAdvancedBlockingParamFalse),
        ("testAdvancedBlockingTextWithAllowlistRules", testAdvancedBlockingTextWithAllowlistRules),
        ("testAdvancedBlockingTextWithExceptionModifiers", testAdvancedBlockingTextWithExceptionModifiers),
    ]
}
