import Foundation

import XCTest
@testable import ContentBlockerConverter

final class CompilerTests: XCTestCase {

    func testEmpty() {
        let compiler = Compiler(
            optimize: false,
            advancedBlocking: false,
            errorsCounter: ErrorsCounter(),
            version: DEFAULT_SAFARI_VERSION
        )
        let result = compiler.compileRules(rules: [Rule]())

        XCTAssertNotNil(result)
        XCTAssertEqual(result.cssBlockingWide.count, 0)
        XCTAssertEqual(result.cssBlockingGenericDomainSensitive.count, 0)
        XCTAssertEqual(result.cssBlockingDomainSensitive.count, 0)
        XCTAssertEqual(result.cssBlockingGenericHideExceptions.count, 0)
        XCTAssertEqual(result.cssElemhide.count, 0)
        XCTAssertEqual(result.urlBlocking.count, 0)
        XCTAssertEqual(result.other.count, 0)
        XCTAssertEqual(result.important.count, 0)
        XCTAssertEqual(result.importantExceptions.count, 0)
        XCTAssertEqual(result.documentExceptions.count, 0)
        XCTAssertEqual(result.script.count, 0)
        XCTAssertEqual(result.scriptlets.count, 0)
        XCTAssertEqual(result.scriptJsInjectExceptions.count, 0)
        XCTAssertEqual(result.extendedCssBlockingWide.count, 0)
        XCTAssertEqual(result.extendedCssBlockingGenericDomainSensitive.count, 0)
        XCTAssertEqual(result.extendedCssBlockingDomainSensitive.count, 0)
    }

    func testCompactCss() {
        let entries = [
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["popsugar.com"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#calendar-widget")),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["lenta1.ru"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#social")),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["lenta2.ru"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#social")),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#social")),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["yandex.ru"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#pub")),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["yandex2.ru"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#pub")),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#banner")),
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
                action: BlockerEntry.Action(type: "css-display-none", selector: "#some-selector")),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["some.com", "an-other.com"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#some-selector")),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["compact.com"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#selector-one")),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["compact.com"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#selector-two")),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["compact.com"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#selector-three")),
        ]

        let result = Compiler.compactDomainCssRules(entries: entries)
        XCTAssertNotNil(result)
        XCTAssertEqual(result.count, 3)
    }

    func testCompactUnlessDomainCss() {
        let entries = [
            BlockerEntry(
                trigger: BlockerEntry.Trigger(urlFilter: ".*", unlessDomain: ["some.com"]),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#some-selector")),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(urlFilter: ".*", unlessDomain: ["compact.com"]),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#selector-two")),
            BlockerEntry(
                trigger: BlockerEntry.Trigger(urlFilter: ".*", unlessDomain: ["compact.com"]),
                action: BlockerEntry.Action(type: "css-display-none", selector: "#selector-three")),
        ]

        let result = Compiler.compactDomainCssRules(entries: entries, useUnlessDomain: true)

        XCTAssertNotNil(result)
        XCTAssertEqual(result.count, 2)
    }

    func testApplyActionExceptions() {
        var blockingItems = [
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["example.org"]),
                action: BlockerEntry.Action(type: "selector", selector: ".banner"))
        ]

        let exceptions = [
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["example.org"]),
                action: BlockerEntry.Action(type: "ignore-previous-rules", selector: ".banner"))
        ]

        let filtered = Compiler.applyActionExceptions(blockingItems: &blockingItems, exceptions: exceptions, actionValue: "selector")

        XCTAssertNotNil(filtered)
        XCTAssertEqual(filtered.count, 0)
    }

    func testApplyActionExceptionsForGenericRule() {
        var blockingItems = [
            BlockerEntry(
                trigger: BlockerEntry.Trigger(urlFilter: ".*"),
                action: BlockerEntry.Action(type: "selector", selector: "test_selector"))
        ]

        let exceptions = [
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["whitelisted.com"]),
                action: BlockerEntry.Action(type: "ignore-previous-rules", selector: "test_selector"))
        ]

        let filtered = Compiler.applyActionExceptions(blockingItems: &blockingItems, exceptions: exceptions, actionValue: "selector")

        XCTAssertNotNil(filtered)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertNotNil(filtered[0].trigger.unlessDomain)
        XCTAssertEqual(filtered[0].trigger.unlessDomain, ["whitelisted.com"])
    }

    func testApplyActionExceptionsForMultiDomainRule() {
        var blockingItems = [
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["example.org", "test.com"], urlFilter: ".*"),
                action: BlockerEntry.Action(type: "selector", selector: ".banner"))
        ]

        let exceptions = [
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["test.com"]),
                action: BlockerEntry.Action(type: "ignore-previous-rules", selector: ".banner"))
        ]

        let filtered = Compiler.applyActionExceptions(blockingItems: &blockingItems, exceptions: exceptions, actionValue: "selector")

        XCTAssertNotNil(filtered)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertNil(filtered[0].trigger.unlessDomain)
        XCTAssertEqual(filtered[0].trigger.ifDomain!, ["example.org"])
        XCTAssertEqual(filtered[0].action.selector, ".banner")
    }

    func testIfDomainAndUnlessDomain() {
        let compiler = Compiler(
            optimize: false,
            advancedBlocking: false,
            errorsCounter: ErrorsCounter(),
            version: SafariVersion.safari13
        )

        func assertResultEmpty(result: CompilationResult) -> Void {
            XCTAssertEqual(result.cssBlockingWide.count, 0)
            XCTAssertEqual(result.cssBlockingGenericDomainSensitive.count, 0)
            XCTAssertEqual(result.cssBlockingDomainSensitive.count, 0)
            XCTAssertEqual(result.cssBlockingGenericHideExceptions.count, 0)
            XCTAssertEqual(result.cssElemhide.count, 0)
            XCTAssertEqual(result.urlBlocking.count, 0)
            XCTAssertEqual(result.other.count, 0)
            XCTAssertEqual(result.important.count, 0)
            XCTAssertEqual(result.importantExceptions.count, 0)
            XCTAssertEqual(result.documentExceptions.count, 0)
            XCTAssertEqual(result.script.count, 0)
            XCTAssertEqual(result.scriptlets.count, 0)
            XCTAssertEqual(result.scriptJsInjectExceptions.count, 0)
            XCTAssertEqual(result.extendedCssBlockingWide.count, 0)
            XCTAssertEqual(result.extendedCssBlockingGenericDomainSensitive.count, 0)
            XCTAssertEqual(result.extendedCssBlockingDomainSensitive.count, 0)
        }

        var ruleText = "example.org,~subdomain.example.org###banner"

        var rule = try! RuleFactory.createRule(ruleText: ruleText, for: SafariVersion.safari13)
        var result = compiler.compileRules(rules: [rule!])

        XCTAssertNotNil(result)
        XCTAssertEqual(result.rulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        assertResultEmpty(result: result)

        ruleText = "yandex.kz,~afisha.yandex.kz#@#body.i-bem > a[data-statlog^='banner']"

        rule = try! RuleFactory.createRule(ruleText: ruleText, for: SafariVersion.safari13)
        result = compiler.compileRules(rules: [rule!])

        XCTAssertNotNil(result)
        XCTAssertEqual(result.rulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        assertResultEmpty(result: result)

        ruleText = "||example.org^$domain=test.com|~sub.test.com"

        rule = try! RuleFactory.createRule(ruleText: ruleText, for: SafariVersion.safari13)
        result = compiler.compileRules(rules: [rule!])

        XCTAssertNotNil(result)
        XCTAssertEqual(result.rulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        assertResultEmpty(result: result)

        ruleText = "@@||example.org^$domain=test.com|~sub.test.com"

        rule = try! RuleFactory.createRule(ruleText: ruleText, for: SafariVersion.safari13)
        result = compiler.compileRules(rules: [rule!])

        XCTAssertNotNil(result)
        XCTAssertEqual(result.rulesCount, 1)
        XCTAssertEqual(result.errorsCount, 0)

        assertResultEmpty(result: result)
    }
}
