import XCTest

@testable import FilterEngine

final class FilterRuleExtractRegexShortcutsTests: XCTestCase {
    // MARK: - Basic tests

    func testExtractRegexShortcutsEmptyString() {
        let pattern = ""
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, [], "Empty string should yield an empty array.")
    }

    func testExtractRegexShortcutsTooShort() {
        let pattern = "ab"
        // Shortcuts must be of length 3 or more
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, [], "Empty string should yield an empty array.")
    }

    func testExtractRegexShortcutsNoBracketsNoEscapes() {
        let pattern = "abc123xyz"
        // Entire string is outside parentheses => one shortcut
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, ["abc123xyz"])
    }

    func testExtractRegexShortcutsOnlyParenthesesNoContentOutside() {
        let pattern = "(abc)"
        // All content is inside parentheses => skip => no outside content
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, [], "All inside parentheses => no shortcuts outside.")
    }

    func testExtractRegexShortcutsSimpleBrackets() {
        let pattern = "abc(def)ghi"
        // "def" is inside parentheses => skip
        // => shortcuts: ["abc", "ghi"]
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, ["abc", "ghi"])
    }

    func testExtractRegexShortcutsNestedBrackets() {
        let pattern = "abc(c(de)f)ghd"
        // bracketDepth is > 0 inside "(c(de)f)", skip everything there
        // => shortcuts: ["abc", "ghd"]
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, ["abc", "ghd"])
    }

    // MARK: - Escaping Behavior

    func testExtractRegexShortcutsEscapedBracket() {
        let pattern = "ab\\(cd"
        // '\(' is an escaped parenthesis => treat "(" literally if bracketDepth == 0
        // => shortcuts: ["ab(cd"]
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, ["ab(cd"])
    }

    func testExtractRegexShortcutsEscapedClosingBracket() {
        let pattern = "ab\\)cd"
        // '\)' is an escaped parenthesis => treat ")" literally if bracketDepth == 0
        // => shortcuts: ["ab)cd"]
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, ["ab)cd"])
    }

    func testExtractRegexShortcutsEscapedBackslash() {
        let pattern = "ab\\\\cd"
        // First backslash escapes second => effectively "ab\cd"
        // => shortcuts: ["ab\\cd"]
        // The sequence of bytes is: 'a','b','\\','\\','c','d'
        // The first two backslashes become a literal backslash in the final output.
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, ["ab\\cd"])
    }

    func testExtractRegexShortcutsMultipleConsecutiveEscapes() {
        // This pattern has multiple consecutive backslashes. We want to be sure
        // that we only treat the next character as escaped if we haven't used the backslash already.
        // In short, every second backslash produces a literal '\' in the output.
        let pattern = "abc\\\\\\(def"
        // Breaking it down:
        //  - 'abc' => "abc"
        //  - '\\\\' => 2 pairs of backslashes => effectively "ab\\"
        // Actually, let's do it carefully:
        //  - 'abc'
        //  - '\\' => sets isEscaped = true
        //    next char also '\\' => literal backslash => buffer = "abc\"
        //    that second '\\' also sets isEscaped = false
        //  - Then third '\\' => sets isEscaped = true
        //  - Then '(' => is escaped => literal '(' => buffer = "abc\\("
        // => result => ["abc\\(def"]
        // There's no parentheses opened unescaped, so "def" continues in the same chunk => "abc\\(def"
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, ["abc\\(def"])
    }

    // MARK: - Pipe Character Outside Brackets => Discard

    func testExtractRegexShortcutsDiscardIfPipeOutsideBrackets() {
        let pattern = "abc|cde"
        // There's a '|' outside of parentheses => discard => []
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, [])
    }

    func testExtractRegexShortcutsPipeInsideBrackets() {
        let pattern = "(a|b)cde"
        // The pipe is inside parentheses => skip it. Outside parentheses => "cde"
        // => shortcuts: ["cde"]
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, ["cde"])
    }

    func testExtractRegexShortcutsMultiplePipesOutside() {
        let pattern = "abc|bcd|cde"
        // The moment we detect the first '|' outside parentheses => discard => []
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, [])
    }

    func testExtractRegexShortcutsPipeAtStartOutsideBrackets() {
        let pattern = "|abc"
        // First character is '|' outside parentheses => discard => []
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, [])
    }

    // MARK: - Negative Lookahead / (?)

    func testExtractRegexShortcutsDiscardIfQuestionMarkAfterBracketOpen() {
        let pattern = "abc(?=\\d)xyz"
        // We see '(' followed by '?' => immediate discard => []
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, [])
    }

    func testExtractRegexShortcutsDiscardIfQuestionMarkAfterBracketOpenInNested() {
        let pattern = "abc(c(?!)cde)fde"
        // Even if it's inside a bracket, the moment we see '(?' we discard => []
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, [])
    }

    func testExtractRegexShortcutsParensButNoQuestionMark() {
        let pattern = "abc(cde)efg"
        // No '(?' sequence => valid. "cde" is inside parentheses => skip => "abc", "efg"
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, ["abc", "efg"])
    }

    // MARK: - Complex Nested / Mixed Cases

    func testExtractRegexShortcutsMultipleNestedBracketsAndEscapes() {
        let pattern = "12a(3bc(\\(4cd\\))5fd)6\\)7"
        // Explanation:
        //  1. "12a" is outside => accumulate => 12a
        //  2. "(3bc(\(4cd\))5fd)" => bracketDepth>0 => skip everything inside
        //  3. "6\)" => escaped parenthesis => literal ')' => accumulate => "6)"
        //  4. "7" => accumulate => "7"
        // => result => ["12a", "6)7"]
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, ["12a", "6)7"])
    }

    func testExtractRegexShortcutsPartialEscapesAndNestedBrackets() {
        let pattern = "abc(\\)cdd(efg))ghe"
        // Step by step:
        //  - "abc" outside => buffer = "abc"
        //  - '(' => bracketDepth=1 => flush => ["abc"], buffer cleared
        //  - '\)' is an escaped parenthesis, but we're inside bracketDepth=1 => it is still content inside parentheses => skip
        //  - 'cdd' inside parentheses => skip
        //  - '(efg)' => nested => bracketDepth=2 => skip
        //  - '))' => pop bracketDepth from 2->1, then 1->0 => once bracketDepth == 0, we resume collecting
        // => outside => "ghe"
        // => final shortcuts => ["abc", "ghe"]
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, ["abc", "ghe"])
    }

    func testExtractRegexShortcutsMultipleBracketsSeparate() {
        let pattern = "abb(cdd)eff(ghh)ijj"
        // "cdd" inside parentheses => skip
        // => outside => "abb", "eff"
        // then "(ghh)" => skip "ghh"
        // => outside => "ijj"
        // => shortcuts => ["abb", "eff", "ijj"]
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, ["abb", "eff", "ijj"])
    }

    func testExtractRegexShortcutsEscapedParenthesesRightNextToRegularOnes() {
        let pattern = "\\(abc(def)\\)ghi"
        // Breaking it down:
        // - '\(' => outside bracket => literal "(" => "(", accumulate => "("
        // - "abc" => accumulate => "(abc"
        // - '(' => bracketDepth=1 => flush => ["(abc"], buffer cleared
        // - "def" => inside => skip
        // - ')' => bracketDepth=0 => end skip
        // - '\)' => outside bracket => literal ")" => accumulate => ")"
        // - "ghi" => accumulate => ")ghi"
        // => final => ["(abc", ")ghi"]
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, ["(abc", ")ghi"])
    }

    func testExtractRegexShortcutsNoDiscardOnlyParenthesesSkipping() {
        let pattern = "outside(inside)outside2"
        // => skip "inside"
        // => result => ["outside", "outside2"]
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, ["outside", "outside2"])
    }

    func testExtractRegexShortcutsEscapeCharacterAtEnd() {
        let pattern = "abc\\"
        // The trailing backslash attempts to escape something, but there's nothing left
        // => just treat it as normal? In practice, the code won't see an escaped next char,
        //    so effectively "abc" plus a trailing backslash that tries to escape something but no char -> that won't add anything new.
        // Implementation detail: The `isEscaped = true` gets set, but the loop ends.
        // => so result => ["abc"]
        // That said, if you want to interpret a trailing backslash as a literal char, you'd need special handling.
        // For simplicity, let's see how the implementation we wrote handles it.
        // It's likely ignoring it because we never add the backslash to the buffer once isEscaped is set.
        // So let's define the expected outcome.
        // => Typically I'd say ["abc"] is correct.
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(
            result,
            ["abc"],
            "Trailing backslash with no next char should be ignored, yielding 'abc'."
        )
    }

    func testExtractRegexShortcutsParenthesesImmediateClose() {
        let pattern = "()abc"
        // "()" => bracketDepth=1 => skip => bracketDepth=0 => no content
        // => "abc" => outside => ["abc"]
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, ["abc"])
    }

    func testExtractRegexShortcutsMultipleTopLevelChunks() {
        let pattern = "abc(def)ghi(jkl)mno"
        // skip "def", skip "jkl"
        // => outside => "abc", "ghi", "mno"
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, ["abc", "ghi", "mno"])
    }

    // MARK: - Edge Cases

    func testExtractRegexShortcutsBracketNotClosed() {
        let pattern = "abc(def"
        // "def" never closed => bracketDepth remains 1 => skip "def"
        // => outside => "abc"
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(
            result,
            ["abc"],
            "Unclosed bracket means skipping everything until end, leaving 'abc'."
        )
    }

    func testExtractRegexShortcutsBracketClosedTooManyTimes() {
        let pattern = "abc)def"
        // We see a closing parent ) outside => bracketDepth=0 =>
        //  in our code, if bracketDepth == 0 and we see ')', it doesn't do anything.
        // => that means 'abc' is still outside => "abc"
        // => 'def' also outside => appended => "abc)def"
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(
            result,
            ["abc)def"],
            "Extra closing parenthesis outside bracketDepth should be ignored."
        )
    }

    func testExtractRegexShortcutsMultipleRandomParenthesesUnmatched() {
        let pattern = "abc(de)f)gh(ij"
        // Step wise:
        // "abc" => outside => accumulate => "abc"
        // '(' => bracketDepth=1 => flush => ["abc"], buffer cleared
        // "de" => inside => skip
        // ')' => bracketDepth=0 => skip ends
        // "f" => outside => accumulate => "f"
        // ')' => bracketDepth=0 => ignore => accumulate => "f)"
        // We only treat it as normal if it’s escaped. If it’s not escaped, we skip it if bracketDepth>0. But bracketDepth=0 => we do nothing special.
        // '(' => bracketDepth=1 => flush => ["f)gh"], buffer cleared
        // "ij" => inside => skip
        // end => flush => but bracketDepth=1 => skipping everything => no leftover
        // => final => ["abc", "f)gh"]
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(
            result,
            ["abc", "f)gh"],
            "Unmatched parentheses with extra ) outside yields two chunks: 'abc' and 'f'."
        )
    }

    func testExtractRegexShortcutsComplexNoDiscard() {
        let pattern = "122(3(\\(4\\))5)6\\)7(no|discard)888"
        // There's a '|' inside parentheses => skip anyway
        // => top-level text is "122" and then "6\)7" and then "8"
        // => "6\)7" => the '\)' is an escaped ) => literal => "6)7"
        // final => ["12", "6)7", "8"]
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, ["122", "6)7", "888"])
    }

    func testExtractRegexShortcutsPipeInsideNestedBrackets() {
        let pattern = "abc(dee|fgg(hii|jkk))xyz"
        // All the pipes are inside parentheses => skip => outside => "abc", "xyz"
        let result = FilterRule.extractRegexShortcuts(from: pattern)
        XCTAssertEqual(result, ["abc", "xyz"])
    }

    // MARK: - Performance tests

    /// Test how fast regex shortcuts are extracted.
    ///
    /// Baseline results (March 2025):
    /// - Machine: MacBook Pro M1 Max, 32GB RAM
    /// - OS: macOS 15.1
    /// - Swift: 6.0
    /// - Average execution time: ~0.063 seconds
    ///
    /// To get your machine info: `system_profiler SPHardwareDataType`
    /// To get your macOS version: `sw_vers`
    /// To get your Swift version: `swift --version`
    func testPerformanceExtractRegexShortcuts() {
        // Number of random patterns to generate
        let patternCount = 10_000

        // Range of lengths for each pattern
        let maxLength = 100

        // Characters we might include in a random pattern
        // Feel free to tweak to match your real-world usage.
        let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789()\\?|" as String)

        // Generate random patterns
        let randomPatterns: [String] = (0..<patternCount).map { _ in
            let length = Int.random(in: 0...maxLength)
            var pattern = ""
            pattern.reserveCapacity(length)
            for _ in 0..<length {
                pattern.append(chars.randomElement()!)
            }
            return pattern
        }

        // Measure performance of extractRegexShortcuts on all patterns
        measure {
            for pattern in randomPatterns {
                _ = FilterRule.extractRegexShortcuts(from: pattern)
            }
        }
    }
}
