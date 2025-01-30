import XCTest

@testable import FilterEngine  // Replace with the name of your module or project

final class TrieNodeTests: XCTestCase {

    // MARK: - Basic functionality tests

    /// Test an empty trie
    func testEmptyTrie() {
        let root = TrieNode()

        // No words inserted => any find should return nil
        XCTAssertNil(root.find(word: "anything"), "Expected 'anything' to be nil in empty TrieNode")

        // collectPayload on empty should be empty
        let collected = root.collectPayload(word: "anything")
        XCTAssertTrue(collected.isEmpty, "Expected an empty array from collecting payloads in empty TrieNode")
    }

    /// Test simple insert and find
    func testSimpleInsertAndFind() {
        let root = TrieNode()
        root.insert(word: "apple", payload: [100, 101])

        // Check that we can find "apple"
        let found = root.find(word: "apple")
        XCTAssertNotNil(found, "Expected to find 'apple' in TrieNode")
        XCTAssertEqual(found!, [100, 101], "Payload mismatch for 'apple'")

        // Check a missing word
        let missing = root.find(word: "banana")
        XCTAssertNil(missing, "Expected 'banana' to be missing in TrieNode")
    }

    /// Test multiple inserts and finds
    func testMultipleInserts() {
        let root = TrieNode()
        root.insert(word: "cat", payload: [1])
        root.insert(word: "car", payload: [2, 3])
        root.insert(word: "dog", payload: [42])

        // Verify each
        XCTAssertEqual(root.find(word: "cat"), [1])
        XCTAssertEqual(root.find(word: "car"), [2, 3])
        XCTAssertEqual(root.find(word: "dog"), [42])

        // Missing word
        XCTAssertNil(root.find(word: "cow"))
    }

    /// Test collecting payloads with no shared prefixes
    func testCollectPayloadNoSharedPrefixes() {
        let root = TrieNode()
        root.insert(word: "car", payload: [100])
        root.insert(word: "bus", payload: [200])

        // Collect from "car"
        let collectedCar = root.collectPayload(word: "car")
        XCTAssertEqual(collectedCar, [100], "Expected to collect [100] from 'car'")

        // Collect from "bus"
        let collectedBus = root.collectPayload(word: "bus")
        XCTAssertEqual(collectedBus, [200], "Expected to collect [200] from 'bus'")
    }

    /// Test collecting payloads with shared prefixes
    func testCollectPayloadWithSharedPrefixes() {
        let root = TrieNode()
        // 'app' => [1], 'apple' => [2]
        root.insert(word: "app", payload: [1])
        root.insert(word: "apple", payload: [2])

        // Collect on "apple" => path includes root (which has no payload unless set),
        // 'app' node => [1], then 'apple' => [2].
        let collected = root.collectPayload(word: "apple")
        XCTAssertEqual(collected, [1, 2], "Expected [1, 2] for 'apple'")

        // Collect on "app" => just the root's payload (if any) + [1]
        let collectedApp = root.collectPayload(word: "app")
        XCTAssertEqual(collectedApp, [1], "Expected [1] for 'app'")
    }

    /// Test collecting payload on a partial/missing path
    func testCollectPayloadMissingPrefix() {
        let root = TrieNode()
        root.insert(word: "apple", payload: [10])

        // "bpple" diverges right away at 'b' vs 'a'.
        // The root node doesn't have a payload by default, so collectPayload should be empty.
        let collected = root.collectPayload(word: "bpple")
        XCTAssertTrue(collected.isEmpty, "Expected empty array for missing path 'bpple'")
    }

    /// Test inserting the empty string (i.e., payload at the root node)
    func testInsertEmptyString() {
        let root = TrieNode()
        root.insert(word: "", payload: [9999])  // attach payload to root
        root.insert(word: "abc", payload: [10])

        // If we treat the empty string as a valid word, find("") => [9999]
        XCTAssertEqual(root.find(word: ""), [9999], "Expected root payload to be [9999]")

        // Still can find "abc"
        XCTAssertEqual(root.find(word: "abc"), [10])

        // Collect payload for "abc" => includes the root's payload + node's payload
        XCTAssertEqual(root.collectPayload(word: "abc"), [9999, 10])
    }

    /// Test inserting the same word multiple times with different payload (assuming it adds payload on top)
    func testInsertDuplicateWord() {
        let root = TrieNode()
        root.insert(word: "hello", payload: [10])
        root.insert(word: "hello", payload: [20, 30])  // duplicate insert

        // We assume the last insert was added on top of existing.
        XCTAssertEqual(root.find(word: "hello"), [10, 20, 30], "Expected the final payload to be [10, 20, 30]")
    }

    /// Test a very long word (thousands of characters)
    func testInsertVeryLongWord() {
        let longWord = String(repeating: "a", count: 5000)
        let root = TrieNode()
        root.insert(word: longWord, payload: [1])

        XCTAssertEqual(root.find(word: longWord), [1], "Expected to find payload [1] for the long word")
        // Missing a slightly different word
        XCTAssertNil(root.find(word: longWord + "x"))
    }

    /// Test root node payload plus children
    func testRootNodePayload() {
        let root = TrieNode()
        root.payload = [1234] // manually attaching at root
        root.insert(word: "a", payload: [100])

        // find("a") => [100], ignoring the root's payload
        XCTAssertEqual(root.find(word: "a"), [100])

        // collectPayload("a") => root's [1234] + child's [100]
        XCTAssertEqual(root.collectPayload(word: "a"), [1234, 100])
    }

    // MARK: - Performance Tests

    /// Performance test that checks how long it takes to build a trie.
    func testPerformanceBuildTrie() {
        self.measure {
            let root = TrieNode()

            // Insert a bunch of words
            for i in 0..<10_000 {
                let word = "word\(i)"
                root.insert(word: word, payload: [UInt32(i)])
            }
        }
    }

    /// Performance test that checks how long a single lookup takes.
    func testPerformanceFind() {
        let root = TrieNode()
        // Insert a bunch of words
        for i in 0..<10_000 {
            let word = "word\(i)"
            root.insert(word: word, payload: [UInt32(i)])
        }

        self.measure {
            // Now do some random lookups
            for i in stride(from: 0, to: 10_000, by: 1000) {
                _ = root.find(word: "word\(i)")
            }
        }
    }

    /// Performance test that checks how long collecting payload takes.
    func testPerformanceCollectPayload() {
        let root = TrieNode()
        // Insert a bunch of words
        for i in 0..<10_000 {
            let word = "word\(i)"
            root.insert(word: word, payload: [UInt32(i)])
        }

        self.measure {
            // Now do some random lookups
            for i in stride(from: 0, to: 10_000, by: 1000) {
                _ = root.collectPayload(word: "word\(i)")
            }
        }
    }
}
