import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(RuleConverterTests.allTests),
        testCase(RuleFactoryTests.allTests),
        testCase(BlcokerEntryFactoryTests.allTests),
        testCase(CompilerTests.allTests),
        testCase(ConversionResultTests.allTests),
        testCase(DistiributorTests.allTests),
        testCase(ContentBlockerConverterTests.allTests),
    ]
}
#endif
