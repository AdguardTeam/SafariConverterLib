import XCTest

import ContentBlockerConverterTests
import ContentBlockerEngineTests

var tests = [XCTestCaseEntry]()
tests += RuleConverterTests.allTests()
tests += NetworkRuleTests.allTests()
tests += ScriptletParserTests.allTests()
tests += CosmeticRuleTests.allTests()
tests += CosmeticRuleMarkerTests.allTests()
tests += RuleFactoryTests.allTests()
tests += BlockerEntryFactoryTests.allTests()
tests += BlockerEntryEncoderTests.allTests()
tests += CompilerTests.allTests()
tests += ConversionResultTests.allTests()
tests += DistiributorTests.allTests()
tests += ContentBlockerConverterTests.allTests()
tests += AdvancedBlockingTests.allTests()
tests += GeneralTests.allTests()
tests += ContentBlockerContainerTests.allTests()
tests += ContentBlockerEngineTests.allTests()
XCTMain(tests)
