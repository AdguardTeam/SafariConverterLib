import Foundation

import XCTest
@testable import ContentBlockerConverter

final class DistributorTests: XCTestCase {
    func testEmpty() {
        let builder = Distributor(limit: 0, advancedBlocking: true);
        
        let result = try! builder.createConversionResult(data: CompilationResult());
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.totalConvertedCount, 0);
        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.overLimit, false);
        XCTAssertEqual(result.converted, "[]");
    }
    
    func testApplyWildcards() {
        
        let builder = Distributor(limit: 0, advancedBlocking: true);
        
        let testTrigger = BlockerEntry.Trigger(
            ifDomain: ["test_if_domain", "*wildcarded_if_domain"],
            urlFilter: "test_url_filter",
            unlessDomain: ["*test_unless_domain"],
            shortcut: "test_shorcut",
            regex: nil
        );
        
        let testAction = BlockerEntry.Action(
            type: "test_type",
            selector: nil,
            css: "test_css",
            script: nil,
            scriptlet: nil,
            scriptletParam: nil
        );
        
        var entries = [
            BlockerEntry(trigger: testTrigger, action: testAction)
        ];
        
        entries = builder.updateDomains(entries: entries);
        
        XCTAssertEqual(entries[0].trigger.ifDomain![0], "*test_if_domain");
        XCTAssertEqual(entries[0].trigger.ifDomain![1], "*wildcarded_if_domain");
        
        XCTAssertEqual(entries[0].trigger.unlessDomain![0], "*test_unless_domain");
    }

    func testHandleIfDomainsLimit() {
        let builder = Distributor(limit: 0, advancedBlocking: true);

        var testTrigger = BlockerEntry.Trigger(
            ifDomain: [],
            urlFilter: "test_url_filter",
            unlessDomain: ["*test_unless_domain"],
            shortcut: "test_shorcut",
            regex: nil
        );

        let testAction = BlockerEntry.Action(
            type: "test_type",
            selector: nil,
            css: "test_css",
            script: nil,
            scriptlet: nil,
            scriptletParam: nil
        );

        var domains = [String]();
        for index in (1...551) {
            domains.append("test-domain-" + String(index));
        }

        testTrigger.setIfDomain(domains: domains);

        let entries = [
            BlockerEntry(trigger: testTrigger, action: testAction)
        ];

        let result = builder.updateDomains(entries: entries);
        XCTAssertNotNil(result);
        XCTAssertEqual(result.count, 3);
        XCTAssertEqual(result[0].trigger.ifDomain!.count, 250);
        XCTAssertEqual(result[1].trigger.ifDomain!.count, 250);
        XCTAssertEqual(result[2].trigger.ifDomain!.count, 51);
    }

    func testHandleUnlessDomainsLimit() {
        let builder = Distributor(limit: 0, advancedBlocking: true);

        var testTrigger = BlockerEntry.Trigger(
            ifDomain: ["test_if_domain"],
            urlFilter: "test_url_filter",
            unlessDomain: [],
            shortcut: "test_shorcut",
            regex: nil
        );

        let testAction = BlockerEntry.Action(
            type: "test_type",
            selector: nil,
            css: "test_css",
            script: nil,
            scriptlet: nil,
            scriptletParam: nil
        );

        var domains = [String]();
        for index in (1...551) {
            domains.append("test-unless-domain-" + String(index));
        }

        testTrigger.setUnlessDomain(domains: domains);

        let entries = [
            BlockerEntry(trigger: testTrigger, action: testAction)
        ];

        let result = builder.updateDomains(entries: entries);
        XCTAssertNotNil(result);
        XCTAssertEqual(result.count, 3);
        XCTAssertEqual(result[0].trigger.unlessDomain!.count, 250);
        XCTAssertEqual(result[1].trigger.unlessDomain!.count, 250);
        XCTAssertEqual(result[2].trigger.unlessDomain!.count, 51);
    }


    static var allTests = [
        ("testEmpty", testEmpty),
        ("testApplyWildcards", testApplyWildcards),
        ("testHandleIfDomainsLimit", testHandleIfDomainsLimit),
        ("testHandleUnlessDomainsLimit", testHandleUnlessDomainsLimit),
    ]
}

