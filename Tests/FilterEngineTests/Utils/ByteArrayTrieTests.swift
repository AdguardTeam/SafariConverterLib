import XCTest

@testable import FilterEngine

final class ByteArrayTrieTests: XCTestCase {
    // MARK: - Basic Tests

    /// Test an empty trie: lookups on an empty trie should return nil or empty payload.
    func testEmptyTrie() {
        // Build an empty TrieNode (no words)
        let root = TrieNode()
        let trie = ByteArrayTrie(from: root)

        // Since no words were inserted, any word should return nil
        XCTAssertNil(trie.find(word: "anything"), "Expected find to return nil on empty trie")

        // collectPayload should be empty
        let collected = trie.collectPayload(word: "anything")
        XCTAssertTrue(collected.isEmpty, "Expected empty payload from an empty trie")
    }

    /// Test inserting a single word and retrieving it.
    func testSimpleInsertAndFind() {
        // Create an in-memory root node
        let root = TrieNode()
        root.insert(word: "apple", payload: [100, 101])  // payload is [UInt32]

        // Build the ByteArrayTrie
        let trie = ByteArrayTrie(from: root)

        // Expect "apple" to be found
        let found = trie.find(word: "apple")
        XCTAssertNotNil(found, "Expected to find 'apple' in trie, but got nil")
        XCTAssertEqual(found!, [100, 101], "Mismatch payload for 'apple'")

        // "banana" was not inserted, so expect nil
        let missing = trie.find(word: "banana")
        XCTAssertNil(
            missing,
            "Expected 'banana' to be missing, but got payload \(String(describing: missing))"
        )
    }

    /// Test multiple inserts and finds.
    func testInsertMultipleWords() {
        let root = TrieNode()
        root.insert(word: "car", payload: [1])
        root.insert(word: "cat", payload: [2, 3])
        root.insert(word: "dog", payload: [42])

        let trie = ByteArrayTrie(from: root)

        // Verify "car"
        XCTAssertEqual(trie.find(word: "car"), [1])

        // Verify "cat"
        XCTAssertEqual(trie.find(word: "cat"), [2, 3])

        // Verify "dog"
        XCTAssertEqual(trie.find(word: "dog"), [42])

        // Verify a missing word
        XCTAssertNil(trie.find(word: "cow"))
    }

    // MARK: - Shared Prefix / Payload Collection Tests

    /// If none of the words share prefixes, the collected path is just the final node's payload.
    func testCollectPayloadNoSharedPrefixes() {
        let root = TrieNode()
        root.insert(word: "car", payload: [100])
        root.insert(word: "bus", payload: [200])

        let trie = ByteArrayTrie(from: root)

        XCTAssertEqual(
            trie.collectPayload(word: "car"),
            [100],
            "Expected to collect [100] from 'car'"
        )
        XCTAssertEqual(
            trie.collectPayload(word: "bus"),
            [200],
            "Expected to collect [200] from 'bus'"
        )
    }

    /// If words share prefixes, collectPayload accumulates from each node along the path.
    func testCollectPayloadWithSharedPrefixes() {
        let root = TrieNode()
        root.insert(word: "app", payload: [1])
        root.insert(word: "apple", payload: [2])

        let trie = ByteArrayTrie(from: root)

        // "app" => payload [1]
        // "apple" => extends "app" => payload [2]
        // collectPayload("apple") => [1, 2]
        let collected = trie.collectPayload(word: "apple")
        XCTAssertEqual(collected, [1, 2], "Expected to collect [1, 2] for 'apple'")

        // "app" => just [1]
        let collectedApp = trie.collectPayload(word: "app")
        XCTAssertEqual(collectedApp, [1], "Expected to collect [1] for 'app'")

        // "app" => payload [1]
        // "apple" => extends "app" => payload [2]
        // "appleid" => no other words
        let collectedAppleid = trie.collectPayload(word: "appleid")
        XCTAssertEqual(collectedAppleid, [1, 2], "Expected to collect [1, 2] for 'appleid'")
    }

    /// If a lookup fails partway, we only gather payload up to that point.
    /// In our code, we typically gather from the root node first (if it had payload),
    /// then move down. As soon as a link is missing, we stop.
    func testCollectPayloadMissingPrefix() {
        let root = TrieNode()
        root.insert(word: "apple", payload: [10])
        let trie = ByteArrayTrie(from: root)

        // There's no path for "bpple", so the path diverges at first character 'b' vs 'a'.
        // Typically, the root has no payload, so we'd just get an empty array.
        let collected = trie.collectPayload(word: "bpple")
        XCTAssertEqual(
            collected,
            [],
            "Expected an empty result since 'bpple' doesn't match 'apple' path"
        )
    }

    // MARK: - Serialization & Deserialization

    func testSerializationAndDeserialization() {
        let root = TrieNode()
        root.insert(word: "apple", payload: [100, 101])
        root.insert(word: "banana", payload: [9999])

        let originalTrie = ByteArrayTrie(from: root)

        // Serialize
        let data = originalTrie.write()

        // Deserialize into a new instance
        let newTrie = ByteArrayTrie(from: data)

        // Ensure the new trie preserves the old data
        XCTAssertEqual(
            newTrie.find(word: "apple"),
            [100, 101],
            "Payload mismatch for 'apple' after deserialization"
        )
        XCTAssertEqual(
            newTrie.find(word: "banana"),
            [9999],
            "Payload mismatch for 'banana' after deserialization"
        )

        // Check a missing word
        XCTAssertNil(newTrie.find(word: "apples"), "'apples' should not be found")
    }

    func testSerializeLargeTrie() {
        let root = TrieNode()
        // Insert a bunch of words
        for i in 0..<10_000 {
            let word = "word\(i)"
            root.insert(word: word, payload: [UInt32(i)])
        }

        let trie = ByteArrayTrie(from: root)

        XCTAssertEqual(trie.count, 120035)
    }

    // MARK: - Special Cases

    /// Test inserting the *empty string* as a word in the trie.
    /// Some tries allow an empty string to attach payload to the root node.
    func testInsertEmptyString() {
        let root = TrieNode()
        root.insert(word: "", payload: [9999])  // Attach payload at the root
        root.insert(word: "abc", payload: [10])

        let trie = ByteArrayTrie(from: root)

        // If we consider the empty string as a valid word, find("") should return [9999].
        XCTAssertEqual(
            trie.find(word: ""),
            [9999],
            "The root node should have payload [9999] for the empty string"
        )

        // "abc" is normal
        XCTAssertEqual(trie.find(word: "abc"), [10])
    }

    /// Test inserting a large word (very long string) to ensure the trie can handle it.
    func testInsertVeryLongWord() {
        let longWord = String(repeating: "a", count: 5000)  // 5k 'a's
        let root = TrieNode()
        root.insert(word: longWord, payload: [1])

        let trie = ByteArrayTrie(from: root)

        // Make sure we can find it again
        let found = trie.find(word: longWord)
        XCTAssertEqual(found, [1], "Expected to find the long word in the trie")
    }

    /// Test inserting the same word multiple times (with different payload).
    func testInsertDuplicateWord() {
        let root = TrieNode()
        root.insert(word: "hello", payload: [10])
        // Insert again with different payload
        root.insert(word: "hello", payload: [20, 30])

        let trie = ByteArrayTrie(from: root)

        // We'll assume the final payload is [10,20,30].
        XCTAssertEqual(trie.find(word: "hello"), [10, 20, 30])
    }

    /// Test attaching payload to the root node *and* to children,
    /// then verifying collectPayload sees both.
    func testRootNodePayload() {
        let root = TrieNode()
        root.payload = [1234]  // Root node payload
        root.insert(word: "a", payload: [100])

        let trie = ByteArrayTrie(from: root)

        // find("a") returns just the final node's payload
        XCTAssertEqual(trie.find(word: "a"), [100])

        // collectPayload("a") returns root payload + "a" node payload => [1234, 100]
        XCTAssertEqual(trie.collectPayload(word: "a"), [1234, 100])
    }

    /// Test a scenario with multiple children from a single node (like 'car', 'cat', 'cap'),
    /// ensuring the childrenCount fits in a single UInt8, and lookups are correct.
    func testMultipleChildrenFromSingleNode() {
        // "c" node has children for 'a', 'o', 'r', etc.
        let root = TrieNode()
        root.insert(word: "ca", payload: [10])
        root.insert(word: "cb", payload: [11])
        root.insert(word: "cc", payload: [12])
        root.insert(word: "cd", payload: [13])
        // ... you can insert more as needed
        let trie = ByteArrayTrie(from: root)

        XCTAssertEqual(trie.find(word: "ca"), [10])
        XCTAssertEqual(trie.find(word: "cb"), [11])
        XCTAssertEqual(trie.find(word: "cc"), [12])
        XCTAssertEqual(trie.find(word: "cd"), [13])
        XCTAssertNil(trie.find(word: "ce"))
    }

    /// Test a scenario with a node that has the maximum number of children (255),
    /// if you want to push the limit. (Optional)
    ///
    /// NOTE:  This can be a large test. For ASCII, you might generate a node with
    /// all letters, digits, punctuation, etc. up to 255.
    /// Depending on the coverage, we can show a short example here:
    func testMaximumChildrenCount() {
        let root = TrieNode()

        // We'll insert words "aX" for each possible child character X from 0...254
        // That’s 255 possible children.
        // For ASCII, let's just do 0...254.
        // If you truly want 0...255, be aware that 255 children is the max.

        for c in 0..<255 {
            let char = UInt8(c)
            let word = "a" + String(UnicodeScalar(char))
            // Insert with payload [UInt32(char)]
            root.insert(word: word, payload: [UInt32(char)])
        }

        let trie = ByteArrayTrie(from: root)

        // Verify some random ones
        // For example, char = 97 is 'a', so word = "aa"
        XCTAssertEqual(trie.find(word: "aa"), [97], "Payload mismatch for 'aa'")

        // char = 0 => "a\u{0}"
        let nullPayload = trie.find(word: "a" + String(UnicodeScalar(0)))
        XCTAssertEqual(nullPayload, [0], "Expected payload [0] for 'a\\0'")

        // char = 127 => "a\u{7F}" (DEL char in ASCII)
        XCTAssertEqual(trie.find(word: "a" + String(UnicodeScalar(127))), [127])

        // Ensure a missing character (255) is not found
        XCTAssertNil(trie.find(word: "a" + String(UnicodeScalar(255))))
    }

    // MARK: - Large Payloads

    /// Test inserting a word that has a large number of payload items.
    /// For example, we can have 10,000 payload items of type UInt32.
    func testLargePayloadArray() {
        let root = TrieNode()

        let largePayload = (0..<10_000).map { UInt32($0) }
        root.insert(word: "big", payload: largePayload)

        let trie = ByteArrayTrie(from: root)

        // Check that find("big") returns the same payload
        let foundPayload = trie.find(word: "big")
        XCTAssertNotNil(foundPayload)
        XCTAssertEqual(foundPayload?.count, largePayload.count)

        // Quick spot-check
        XCTAssertEqual(foundPayload?.first, 0)
        XCTAssertEqual(foundPayload?.last, 9999)
    }

    // MARK: - Performance Tests

    /// Performance test that checks how long it takes to build a trie.
    ///
    /// Baseline results (March 2025):
    /// - Machine: MacBook Pro M1 Max, 32GB RAM
    /// - OS: macOS 15.1
    /// - Swift: 6.0
    /// - Average execution time: ~0.657 seconds
    ///
    /// To get your machine info: `system_profiler SPHardwareDataType`
    /// To get your macOS version: `sw_vers`
    /// To get your Swift version: `swift --version`
    func testPerformanceBuildTrie() {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        var words = [String]()

        // Generate and insert 10,000 random words
        for _ in 0..<10_000 {
            let wordLength = Int.random(in: 3...30)
            let word = String((0..<wordLength).map { _ in alphabet.randomElement()! })
            words.append(word)
        }

        self.measure {
            let root = TrieNode()

            // Insert a bunch of words
            for word in words {
                root.insert(word: word, payload: [0])
            }

            // Build the byte array trie
            _ = ByteArrayTrie(from: root)
        }
    }

    /// Performance test that checks how long a single lookup takes.
    ///
    /// Baseline results (March 2025):
    /// - Machine: MacBook Pro M1 Max, 32GB RAM
    /// - OS: macOS 15.1
    /// - Swift: 6.0
    /// - Average execution time: ~0.051 seconds
    ///
    /// To get your machine info: `system_profiler SPHardwareDataType`
    /// To get your macOS version: `sw_vers`
    /// To get your Swift version: `swift --version`
    func testPerformanceFind() {
        let root = TrieNode()
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        var words = [String]()

        // Generate and insert 10,000 random words
        for _ in 0..<10_000 {
            let wordLength = Int.random(in: 3...30)
            let word = String((0..<wordLength).map { _ in alphabet.randomElement()! })
            words.append(word)
            root.insert(word: word, payload: [UInt32.random(in: 0..<UInt32.max)])
        }

        let trie = ByteArrayTrie(from: root)

        self.measure {
            // Perform lookups on each generated word
            for word in words {
                guard trie.find(word: word) != nil else {
                    XCTFail("Did not find word: \(word)")

                    return
                }
            }
        }
    }

    /// Performance test that checks how long collecting payload takes.
    ///
    /// Baseline results (March 2025):
    /// - Machine: MacBook Pro M1 Max, 32GB RAM
    /// - OS: macOS 15.1
    /// - Swift: 6.0
    /// - Average execution time: ~0.121 seconds
    ///
    /// To get your machine info: `system_profiler SPHardwareDataType`
    /// To get your macOS version: `sw_vers`
    /// To get your Swift version: `swift --version`
    func testPerformanceCollectPayload() {
        let root = TrieNode()
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        var words = [String]()

        // Generate and insert 10,000 random words
        for _ in 0..<10_000 {
            let wordLength = Int.random(in: 3...30)
            let word = String((0..<wordLength).map { _ in alphabet.randomElement()! })
            words.append(word)
            root.insert(word: word, payload: [UInt32.random(in: 0..<UInt32.max)])
        }

        let trie = ByteArrayTrie(from: root)

        self.measure {
            // Perform lookups on each generated word
            for word in words {
                let res = trie.collectPayload(word: word)
                guard !res.isEmpty else {
                    XCTFail("Did not find payload for word: \(word)")

                    return
                }
            }
        }
    }
}
