/// A simple in-memory trie node structure that stores ASCII-based words and associated payloads.
///
/// This node supports:
///   - Insertion of words, storing a payload at the final node.
///   - Finding an exact word, retrieving its stored payload if it exists.
///   - Collecting payloads from every node along the path of a given word.
///
/// Typical usage involves creating a root `TrieNode` and inserting words:
///
///     let root = TrieNode()
///     root.insert(word: "apple", payload: [100, 101])
///     root.insert(word: "app",   payload: [50])
///
/// Then you can:
///
///     let exactPayload = root.find(word: "apple")      // -> [100, 101]
///     let allPayloads  = root.collectPayload(word: "apple") // -> [ (root payload?), 50, 100, 101 ]
///
/// Once you've built up your trie, you can optionally flatten it into a more compact structure
/// (e.g., `ByteArrayTrie`), or serialize it, etc.
public class TrieNode {
    /// Children keyed by ASCII character byte.
    /// Each key is a `UInt8` representing one character (0–127 if strictly ASCII).
    public var children: [UInt8: TrieNode] = [:]

    /// Optional payload stored at this node.
    /// In many trie designs, the payload is nonempty only if this node represents
    /// the "end" of one or more words, but you can also store partial payload if desired.
    public var payload: [UInt32] = []

    public init() {}

    // MARK: - Insert

    /// Inserts a word into the trie, storing `payload` at the node representing
    /// the final character of the word.
    ///
    /// - Parameters:
    ///   - word: The word (ASCII only) to insert.
    ///   - payload: The array of `UInt32` values to store at the final node.
    public func insert(word: String, payload: [UInt32]) {
        var current = self
        for byte in word.utf8 {
            if current.children[byte] == nil {
                current.children[byte] = TrieNode()
            }
            // swiftlint:disable:next force_unwrapping
            current = current.children[byte]!
        }
        // Attach the payload at the final node for this word
        if !current.payload.isEmpty {
            current.payload += payload
        } else {
            current.payload = payload
        }
    }

    // MARK: - Find

    /// Finds an exact match for a given word in the trie.
    ///
    /// - Parameter word: The ASCII string to look up.
    /// - Returns: The payload stored at the node representing the end of this word,
    ///            or `nil` if the word is not present.
    public func find(word: any StringProtocol) -> [UInt32]? {
        var current = self
        for byte in word.utf8 {
            guard let child = current.children[byte] else {
                return nil  // No path => not in trie
            }
            current = child
        }
        // Return the payload at the final node
        return current.payload
    }

    // MARK: - Collect Payload

    /// Collects payloads from each node along the path of the given word,
    /// including the payload in the root (if any), then each intermediate node,
    /// and finally the node corresponding to the last character of `word`.
    ///
    /// - Parameter word: The ASCII string whose path we traverse.
    /// - Returns: An array of all payload values encountered.
    ///            If the path diverges at some character, we return whatever was
    ///            collected up until that break.
    public func collectPayload(word: any StringProtocol) -> [UInt32] {
        var current = self
        var result: [UInt32] = []

        // Add root's payload (if it has one)
        result.append(contentsOf: current.payload)

        // Move along each character in the word, collecting payload
        for byte in word.utf8 {
            guard let child = current.children[byte] else {
                // No further path => stop
                return result
            }
            current = child
            // Add this node's payload
            result.append(contentsOf: current.payload)
        }

        return result
    }
}
