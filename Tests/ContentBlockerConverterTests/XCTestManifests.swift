import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(RuleConverterTests.allTests),
        testCase(RuleFactoryTests.allTests),
        testCase(ConverterTests.allTests),
        testCase(CompilerTests.allTests),
        testCase(ConversionResultTests.allTests),
        testCase(BuilderTests.allTests),
        testCase(ContentBlockerConverterTests.allTests),
    ]
}
#endif
