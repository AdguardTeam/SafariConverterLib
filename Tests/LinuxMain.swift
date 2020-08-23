import XCTest

import ContentBlockerConverterTests

var tests = [XCTestCaseEntry]()
tests += RuleConverterTests.allTests()
tests += NetworkRuleTests.allTests()
tests += RuleFactoryTests.allTests()
tests += BlockerEntryFactoryTests.allTests()
tests += CompilerTests.allTests()
tests += ConversionResultTests.allTests()
tests += DistiributorTests.allTests()
tests += ContentBlockerConverterTests.allTests()
XCTMain(tests)
