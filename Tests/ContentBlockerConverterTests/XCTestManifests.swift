import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(RuleConverterTests.allTests),
        testCase(NetworkRuleTests.allTests),
        testCase(ScriptletParserTests.allTests),
        testCase(CosmeticRuleTests.allTests),
        testCase(RuleFactoryTests.allTests),
        testCase(BlockerEntryFactoryTests.allTests),
        testCase(CompilerTests.allTests),
        testCase(ConversionResultTests.allTests),
        testCase(DistiributorTests.allTests),
        testCase(ContentBlockerConverterTests.allTests),
    ]
}
#endif
