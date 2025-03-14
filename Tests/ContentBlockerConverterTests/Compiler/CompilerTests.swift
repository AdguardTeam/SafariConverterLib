import Foundation
import XCTest

@testable import ContentBlockerConverter

final class CompilerTests: XCTestCase {
    func testEmpty() {
        let compiler = Compiler(errorsCounter: ErrorsCounter(), version: DEFAULT_SAFARI_VERSION)
        let result = compiler.compileRules(rules: [Rule]())

        XCTAssertNotNil(result)
        XCTAssertEqual(result.cssBlockingWide.count, 0)
        XCTAssertEqual(result.cssBlockingGenericDomainSensitive.count, 0)
        XCTAssertEqual(result.cssBlockingDomainSensitive.count, 0)
        XCTAssertEqual(result.cssBlockingGenericHideExceptions.count, 0)
        XCTAssertEqual(result.cssElemhideExceptions.count, 0)
        XCTAssertEqual(result.urlBlocking.count, 0)
        XCTAssertEqual(result.otherExceptions.count, 0)
        XCTAssertEqual(result.important.count, 0)
        XCTAssertEqual(result.importantExceptions.count, 0)
        XCTAssertEqual(result.documentExceptions.count, 0)
    }

    func testCompactCss() {
        let entries = [
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["popsugar.com"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#calendar-widget")
            ),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["lenta1.ru"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#social")
            ),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["lenta2.ru"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#social")
            ),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#social")
            ),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["yandex.ru"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#pub")
            ),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["yandex2.ru"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#pub")
            ),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#banner")
            ),
        ]

        let result = Compiler.compactCssRules(cssBlocking: entries)
        XCTAssertNotNil(result)
        XCTAssertEqual(result.cssBlockingWide.count, 1)
        XCTAssertEqual(result.cssBlockingDomainSensitive.count, 5)
        XCTAssertEqual(result.cssBlockingGenericDomainSensitive.count, 0)
    }

    func testCompactIfDomainCss() {
        let entries = [
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["some.com"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#some-selector")
            ),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(
                    ifDomain: ["some.com", "an-other.com"],
                    urlFilter: ".*"
                ),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#some-selector")
            ),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["compact.com"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#selector-one")
            ),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["compact.com"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#selector-two")
            ),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["compact.com"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#selector-three")
            ),
        ]

        let result = Compiler.compactDomainCssRules(entries: entries)
        XCTAssertNotNil(result)
        XCTAssertEqual(result.count, 3)
    }

    func testIfDomainAndUnlessDomain() {
        var errorsCounter = ErrorsCounter()
        var compiler = Compiler(errorsCounter: errorsCounter, version: SafariVersion.safari13)

        func assertResultEmpty(result: CompilationResult) {
            XCTAssertEqual(result.cssBlockingWide.count, 0)
            XCTAssertEqual(result.cssBlockingGenericDomainSensitive.count, 0)
            XCTAssertEqual(result.cssBlockingDomainSensitive.count, 0)
            XCTAssertEqual(result.cssBlockingGenericHideExceptions.count, 0)
            XCTAssertEqual(result.cssElemhideExceptions.count, 0)
            XCTAssertEqual(result.urlBlocking.count, 0)
            XCTAssertEqual(result.otherExceptions.count, 0)
            XCTAssertEqual(result.important.count, 0)
            XCTAssertEqual(result.importantExceptions.count, 0)
            XCTAssertEqual(result.documentExceptions.count, 0)
        }

        var ruleText = "example.org,~subdomain.example.org###banner"

        var rule = try! RuleFactory.createRule(ruleText: ruleText, for: SafariVersion.safari13)
        var result = compiler.compileRules(rules: [rule!])

        XCTAssertNotNil(result)
        XCTAssertEqual(result.rulesCount, 0)
        XCTAssertEqual(errorsCounter.getCount(), 1)

        assertResultEmpty(result: result)

        ruleText = "yandex.kz,~afisha.yandex.kz#@#body.i-bem > a[data-statlog^='banner']"
        rule = try! RuleFactory.createRule(ruleText: ruleText, for: SafariVersion.safari13)

        errorsCounter = ErrorsCounter()
        compiler = Compiler(errorsCounter: errorsCounter, version: SafariVersion.safari13)
        result = compiler.compileRules(rules: [rule!])

        XCTAssertNotNil(result)
        XCTAssertEqual(result.rulesCount, 0)
        XCTAssertEqual(errorsCounter.getCount(), 1)

        assertResultEmpty(result: result)

        ruleText = "||example.org^$domain=test.com|~sub.test.com"
        rule = try! RuleFactory.createRule(ruleText: ruleText, for: SafariVersion.safari13)

        errorsCounter = ErrorsCounter()
        compiler = Compiler(errorsCounter: errorsCounter, version: SafariVersion.safari13)
        result = compiler.compileRules(rules: [rule!])

        XCTAssertNotNil(result)
        XCTAssertEqual(result.rulesCount, 0)
        XCTAssertEqual(errorsCounter.getCount(), 1)

        assertResultEmpty(result: result)

        ruleText = "@@||example.org^$domain=test.com|~sub.test.com"
        rule = try! RuleFactory.createRule(ruleText: ruleText, for: SafariVersion.safari13)

        errorsCounter = ErrorsCounter()
        compiler = Compiler(errorsCounter: errorsCounter, version: SafariVersion.safari13)
        result = compiler.compileRules(rules: [rule!])

        XCTAssertNotNil(result)
        XCTAssertEqual(result.rulesCount, 0)
        XCTAssertEqual(errorsCounter.getCount(), 1)

        assertResultEmpty(result: result)
    }
}
