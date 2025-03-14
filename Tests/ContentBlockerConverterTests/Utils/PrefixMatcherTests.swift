import XCTest

@testable import ContentBlockerConverter

final class PrefixMatcherTests: XCTestCase {
    func testNoPrefixes() {
        let matcher = PrefixMatcher(prefixes: [])
        let input = "hello"
        let result = matcher.matchPrefix(in: input)
        XCTAssertNil(result.idx, "Expected no match with empty prefix list.")
        XCTAssertNil(result.prefix, "Expected no prefix with empty prefix list.")
    }

    func testSinglePrefixExactMatch() {
        let matcher = PrefixMatcher(prefixes: ["hello"])
        let input = "hello world"
        let result = matcher.matchPrefix(in: input)
        // "hello" is 5 bytes (characters), index of last character in zero-based is 4
        let expectedIndex = input.utf8.index(input.utf8.startIndex, offsetBy: 4)
        XCTAssertEqual(
            result.idx,
            expectedIndex,
            "Index should point to the last character of the matched prefix."
        )
        XCTAssertEqual(result.prefix, "hello", "Matched prefix should be 'hello'.")
    }

    func testSinglePrefixNoMatch() {
        let matcher = PrefixMatcher(prefixes: ["goodbye"])
        let input = "hello"
        let result = matcher.matchPrefix(in: input)
        XCTAssertNil(result.idx, "No match expected.")
        XCTAssertNil(result.prefix, "No prefix expected.")
    }

    func testMultiplePrefixesFirstMatches() {
        let matcher = PrefixMatcher(prefixes: ["he", "hello", "h"])
        let input = "hello"
        // The Trie should find "h" first, but we must confirm the logic:
        // Actually, given the code, it will continue until no next node or end is found.
        // Once "h" node is found and isEnd = true, it returns immediately.
        // So it should match "h" at index 0.
        let result = matcher.matchPrefix(in: input)

        let expectedIndex = input.utf8.index(input.utf8.startIndex, offsetBy: 0)
        XCTAssertEqual(result.idx, expectedIndex, "Should match 'h' at index 0.")
        XCTAssertEqual(
            result.prefix,
            "h",
            "Should return the shortest matching prefix found at the earliest opportunity."
        )
    }

    func testMultiplePrefixesLongerMatch() {
        // let matcher = PrefixMatcher(prefixes: ["he", "hello", "h"])
        let input = "hello"
        // If we reorder prefixes to find 'hello' first, does it matter?
        // The code doesn't seem to stop after first prefix is found unless isEnd is encountered.
        // The trie is built from all prefixes. The traversal will go character by character:
        // 'h' -> isEnd = true (prefix "h"). This returns immediately without checking longer prefixes.
        // To specifically test a scenario where a longer prefix can be matched, let's remove the shortest prefix that would return early.
        let matcher2 = PrefixMatcher(prefixes: ["he", "hello"])
        let result = matcher2.matchPrefix(in: input)

        // The traversal: 'h' -> no immediate return unless isEnd is true there.
        // Check how trie is built:
        // 'h' -> node, not isEnd? Actually "he" and "hello" both start with 'h',
        // the node after 'h' might not be marked isEnd immediately, it depends on code in init:
        // The code sets isEnd at the end of each prefix. For "he", after 'h','e' node is isEnd=true.
        // That means at 'h' it won't be isEnd yet.
        // We'll match 'h','e' next:
        // At 'he' node: isEnd = true, prefix = "he", returns immediately.
        // This means it won't even get to 'hello'.
        let expectedIndex = input.utf8.index(input.utf8.startIndex, offsetBy: 1)
        XCTAssertEqual(result.idx, expectedIndex, "Should match 'he' at index 1.")
        XCTAssertEqual(
            result.prefix,
            "he",
            "Longest match not guaranteed. Should return first complete prefix encountered."
        )
    }

    func testNoMatchWhenPrefixNotAtStart() {
        let matcher = PrefixMatcher(prefixes: ["world"])
        let input = "hello world"
        // There's "world" in the string but not at the start.
        // The code checks from the beginning of 'hello world', so no match.
        let result = matcher.matchPrefix(in: input)
        XCTAssertNil(result.idx, "No match expected since prefix not at start.")
        XCTAssertNil(result.prefix, "No prefix expected.")
    }

    func testEmptyStringInput() {
        let matcher = PrefixMatcher(prefixes: ["h", "he", "hello"])
        let input = ""
        let result = matcher.matchPrefix(in: input)
        XCTAssertNil(result.idx, "Empty string can't match any prefix.")
        XCTAssertNil(result.prefix, "No prefix expected.")
    }

    func testEmptyPrefix() {
        // It's unusual but let's see what happens if an empty prefix is added.
        // According to the code: inserting empty prefix means isEnd will be set at the root.
        // That would mean everything matches immediately at index 0?
        let matcher = PrefixMatcher(prefixes: [""])
        let input = "anything"
        let result = matcher.matchPrefix(in: input)
        // The construction would set the root as isEnd. Let's verify logically:
        // For prefix "", no iteration over utf8, isEnd set at root.
        // As soon as we try to match something, root node is already isEnd, but note the code:
        // The code doesn't return at the root before traversing. It starts checking characters:
        // Actually, it never increments currentIndex if no children are found.
        // The code loop:
        // - current = trie (root)
        // - while currentIndex < endIndex:
        // - tries guard let nextNode = current.children[char]
        //   If empty prefix sets root.isEnd = true:
        //   The code does not return immediately at start, it only returns upon finding isEnd *after* consuming a character.
        // In this special scenario, isEnd is set at the root, but we never return before reading a character. The code checks `isEnd` after moving `current` to `nextNode`, never at the root itself.
        // That means an empty prefix might never actually return since no traversal occurs to a next node.
        //
        // In that sense, no prefix is effectively ignored as there's no code unit consumed.
        XCTAssertNil(result.idx, "Empty prefix might not trigger a match under current logic.")
        XCTAssertNil(result.prefix, "No prefix returned.")
    }

    func testPrefixWithSpecialCharacters() {
        let matcher = PrefixMatcher(prefixes: ["http://", "https://", "||", "@@||", "//"])
        let input1 = "https://www.example.com"
        let res1 = matcher.matchPrefix(in: input1)
        // "https://" is 8 characters: h(0) t(1) t(2) p(3) s(4) :(5) /(6) /(7)
        let idx1 = input1.utf8.index(input1.utf8.startIndex, offsetBy: 7)
        XCTAssertEqual(res1.idx, idx1)
        XCTAssertEqual(res1.prefix, "https://")

        let input2 = "||pipe"
        let res2 = matcher.matchPrefix(in: input2)
        // "||" are two characters: index 1 is the last char
        let idx2 = input2.utf8.index(input2.utf8.startIndex, offsetBy: 1)
        XCTAssertEqual(res2.idx, idx2)
        XCTAssertEqual(res2.prefix, "||")

        let input3 = "@@||test"
        let res3 = matcher.matchPrefix(in: input3)
        // "@@" (2 chars) + "||" (2 chars) = 4 chars total, last char index = 3
        let idx3 = input3.utf8.index(input3.utf8.startIndex, offsetBy: 3)
        XCTAssertEqual(res3.idx, idx3)
        XCTAssertEqual(res3.prefix, "@@||")
    }

    func testOverlappingPrefixes() {
        let matcher = PrefixMatcher(prefixes: ["a", "ab", "abc"])
        let input = "abc"
        let result = matcher.matchPrefix(in: input)
        // The trie will first check 'a': isEnd = true (prefix "a"), returns immediately at idx=0
        // It won't proceed to 'ab' or 'abc'.
        let expectedIndex = input.utf8.index(input.utf8.startIndex, offsetBy: 0)
        XCTAssertEqual(result.idx, expectedIndex, "Should match the shortest prefix first.")
        XCTAssertEqual(result.prefix, "a", "Should return 'a' and not longer ones.")
    }

    func testMatchAtVeryStart() {
        let matcher = PrefixMatcher(prefixes: ["h"])
        let input = "hello"
        let result = matcher.matchPrefix(in: input)
        let expectedIndex = input.utf8.startIndex  // just the first character
        XCTAssertEqual(result.idx, expectedIndex)
        XCTAssertEqual(result.prefix, "h")
    }

    func testPrefixWithUnicodeCharacters() {
        // Unicode test: e.g. "hëllo"
        // Each special character might consist of multiple UTF-8 code units.
        // The prefix "hë" in UTF-8 is h(0x68), ë could be multiple bytes (depends on normalization),
        // Let's try a prefix that includes a unicode character.
        // Important: The code and logic rely on direct UTF8 iteration.

        // Let's pick a stable Unicode character like "é" (U+00E9) which in UTF-8 is 0xC3 0xA9.
        let matcher = PrefixMatcher(prefixes: ["hé"])
        let input = "héllo"

        // Checking the code logic:
        // prefix "hé" in utf8: 'h'(0x68), 'é'(0xC3,0xA9)
        // When constructing trie:
        //  root -> 'h'(0x68) -> node
        //            '0xC3' -> node
        //            '0xA9' -> node isEnd=true
        // input utf8 starts: 'h'(0x68), 'é'(0xC3,0xA9)
        // After consuming 'h'(idx=0), '0xC3'(idx=1), '0xA9'(idx=2), isEnd=true, return idx=2
        // idx=2 means the last matched code unit offset is 2. Let's confirm indexing:
        // The matched prefix "hé" consists of 3 UTF-8 code units: 'h'(1 code unit), 'é'(2 code units).
        // The last matched code unit index is indeed offset by 2 from start.
        let res = matcher.matchPrefix(in: input)
        let idx = input.utf8.index(input.utf8.startIndex, offsetBy: 2)
        XCTAssertEqual(res.idx, idx)
        XCTAssertEqual(res.prefix, "hé")
    }
}
