/// Prefix matcher provides a simple and fast option to check whether the test
/// string starts with one of the provided prefixes.
public final class PrefixMatcher {
    private var trie: TrieNode

    /// Initializes the prefix matcher from a list of prefixes.
    init(prefixes: [String]) {
        // Build a trie from a list of strings.
        // Each string is inserted by its UTF-8 code units.
        trie = TrieNode()

        for prefixStr in prefixes {
            var current = trie
            for byte in prefixStr.utf8 {
                if current.children[byte] == nil {
                    current.children[byte] = TrieNode()
                }
                // swiftlint:disable:next force_unwrapping
                current = current.children[byte]!
            }
            current.isEnd = true
            current.prefix = prefixStr
        }
    }

    /// Checks if `string` starts with any of the prefixes in the PrefixMatcher.
    ///
    /// - Parameters:
    ///   - in: string to check.
    /// - Returns:
    ///   - idx: the index of the last matched character if matched, or nil if no match.
    ///   - prefix: the prefix string.
    public func matchPrefix(in string: String) -> (idx: String.Index?, prefix: String?) {
        var current = trie
        let utf8 = string.utf8
        var currentIndex = utf8.startIndex

        while currentIndex < utf8.endIndex {
            let char = utf8[currentIndex]
            guard let nextNode = current.children[char] else {
                // No continuation in trie, stop
                break
            }
            current = nextNode
            if current.isEnd {
                // Found a pattern match that ends here.
                return (currentIndex, current.prefix)
            }

            currentIndex = utf8.index(after: currentIndex)
        }

        return (nil, nil)
    }

    /// Trie is a go-to structure for fast prefix matching.
    ///
    /// A TrieNode holds transitions for UTF-8 code units and a flag for pattern endings.
    private final class TrieNode {
        var children: [UInt8: TrieNode] = [:]
        var isEnd: Bool = false
        var prefix: String?
    }
}
