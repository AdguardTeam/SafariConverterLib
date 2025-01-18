import Foundation

/// A compact, memory-efficient trie implementation that stores its node structure
/// in a single contiguous byte buffer. It supports:
///
///  - **Insertion** of ASCII-based words along with optional payload.
///  - **Lookup** of words to retrieve payload data.
///  - **Prefix traversal** or partial match logic (collecting payloads as you descend
///    through the trie’s nodes).
///  - **Serialization** to and from a `Data` object, making it easy to save or transmit.
///
/// By storing the entire trie structure (child pointers, payload sizes, payload values)
/// in a single `[UInt8]`, this trie can be written to disk or transferred across
/// processes or networks with minimal overhead.
///
/// **Key highlights**:
///  - Each node’s children count, characters, offsets, and payload are packed in a
///    compact format (using just enough bytes to store the relevant data).
///  - Words are limited to ASCII characters for simplicity and tight packing.
///  - Payload values can be stored inline (e.g., as `UInt32` offsets, if you're referencing
///    a separate data region) or as any integral type, depending on your needs.
///  - Because all data is in a single contiguous buffer, once built, lookups require
///    no dynamic allocations. Traversal is simply a matter of reading offsets and
///    child lists at the right byte positions.
///
/// This data structure is ideal if:
///
///  - You need a space-optimized read-mostly trie.
///  - You want to quickly serialize/deserialize a trie (e.g., load it from disk or
///    embed it in your app bundle).
///  - You have a large number of words and want O(length of word) lookups without
///    the overhead of pointers or node objects scattered in memory.
///
/// **Note**:
///  - Building the trie requires a recursive or iterative pass of your in-memory
///    data (e.g., from a simpler `TrieNode` structure).
///  - If you need heavy insertions/deletions after the trie is built, a dynamic
///    in-memory structure (like a traditional tree of nodes) may be more convenient.
///    This trie format is best for static or infrequently modified datasets.
public class ByteArrayTrie {
    /// The raw byte array that holds all trie nodes.
    private var storage: [UInt8] = []

    /// The offset of the root node in `storage`.
    private var rootOffset: UInt32 = 0

    // MARK: - Public Initializers

    /// Initialize from an existing in-memory `TrieNode`.
    public init(from rootNode: TrieNode) {
        // We'll build up the storage dynamically, so start empty
        storage = []

        // Recursively build the root node
        rootOffset = buildNode(node: rootNode)
    }

    /// Initialize from existing `Data` (deserialize).
    public init(from data: Data) {
        // Just copy the bytes into storage
        self.storage = [UInt8](data)
        // The root node is at offset 0
        self.rootOffset = 0
    }

    // MARK: - Serialization

    /// Returns the number of underlying bytes.
    public var count: Int {
        return storage.count
    }

    /// Write to `Data`.
    public func write() -> Data {
        return Data(storage)
    }

    // MARK: - Lookups

    /// Find exact word; returns the payload if found, or `nil` if not present.
    public func find(word: any StringProtocol) -> [UInt32]? {
        var currentOffset = rootOffset

        for ch in word.utf8 {
            guard let childOffset = findChildOffset(parentOffset: currentOffset, char: ch) else {
                // Child not found => word not in trie
                return nil
            }
            currentOffset = childOffset
        }

        // We've landed on the final node for this word.
        let payload = readPayload(nodeOffset: currentOffset)
        return payload
    }

    /// Collect all payload values along the path of the word.
    /// i.e., accumulate payload from the root, then from each node as we go deeper.
    /// If any character is not found, we stop.
    public func collectPayload(word: any StringProtocol) -> [UInt32] {
        var currentOffset = rootOffset
        var result: [UInt32] = []

        // Add the root's payload (if any):
        result.append(contentsOf: readPayload(nodeOffset: currentOffset))

        for ch in word.utf8 {
            guard let childOffset = findChildOffset(parentOffset: currentOffset, char: ch) else {
                // Path breaks here
                return result
            }
            currentOffset = childOffset
            // Add child's payload
            result.append(contentsOf: readPayload(nodeOffset: currentOffset))
        }

        return result
    }
}

// MARK: - Private Building/Reading Extensions

extension ByteArrayTrie {

    /// Recursively build a node in `storage`, return the offset where it's placed.
    private func buildNode(node: TrieNode) -> UInt32 {
        // The offset where this node will begin in `storage`.
        let nodeStartOffset = UInt32(storage.count)

        // 1) childrenCount (1 byte)
        let childrenCount = UInt8(node.children.count)
        appendUInt8(childrenCount)

        // We need to store (char, childOffset) for each child.
        // But we don't know childOffset until we recursively build the child.
        // We'll do the typical "reserve space, build child, patch in offset" approach.

        let childrenStart = storage.count
        // For each child, we'll have 5 bytes: (1 for char, 4 for offset)
        storage.append(contentsOf: repeatElement(0, count: Int(childrenCount) * 5))

        // 2) payloadCount (2 bytes, UInt16)
        let payloadCount = UInt16(node.payload.count)
        appendUInt16(payloadCount)

        // 3) payload items (4 bytes each, UInt32)
        for p in node.payload {
            let valBytes = withUnsafeBytes(of: p.littleEndian, Array.init)
            storage.append(contentsOf: valBytes)
        }

        // Build children, patch them in
        var i = 0
        for (char, childNode) in node.children {
            let childOffset = buildNode(node: childNode)

            // The patch location = childrenStart + (i * 5)
            let patchIndex = childrenStart + i * 5

            // 1 byte for char
            storage[patchIndex] = char

            // 4 bytes for offset
            let offsetBytes = withUnsafeBytes(of: childOffset.littleEndian, Array.init)
            for j in 0..<4 {
                storage[patchIndex + 1 + j] = offsetBytes[j]
            }
            i += 1
        }

        // Return where this node began
        return nodeStartOffset
    }

    /// Given a parent's node offset, find the offset of the child for `char`.
    private func findChildOffset(parentOffset: UInt32, char: UInt8) -> UInt32? {
        var cursor = Int(parentOffset)

        // 1) read childrenCount (1 byte)
        let childrenCount = readUInt8(at: cursor)
        cursor += 1

        // 2) read each child's info: (1 byte char, 4 bytes offset)
        for _ in 0..<childrenCount {
            let c = storage[cursor]
            let offset = readUInt32(at: cursor + 1)
            cursor += 5
            if c == char {
                return offset
            }
        }

        // Not found
        return nil
    }

    /// Read the payload array for a node at `nodeOffset`.
    private func readPayload(nodeOffset: UInt32) -> [UInt32] {
        var cursor = Int(nodeOffset)

        // Skip children
        let childrenCount = readUInt8(at: cursor)
        cursor += 1 + (Int(childrenCount) * 5)

        // Now read payloadCount (2 bytes)
        let pcount = readUInt16(at: cursor)
        cursor += 2

        // Read pcount * 4 bytes
        var result: [UInt32] = []
        result.reserveCapacity(Int(pcount))
        for _ in 0..<pcount {
            let val = readUInt32(at: cursor)
            result.append(val)
            cursor += 4
        }

        return result
    }
}

// MARK: - Private read/write numeric helpers

extension ByteArrayTrie {

    private func appendUInt8(_ value: UInt8) {
        storage.append(value)
    }

    private func appendUInt16(_ value: UInt16) {
        let le = value.littleEndian
        withUnsafeBytes(of: le) { storage.append(contentsOf: $0) }
    }

    private func readUInt8(at index: Int) -> UInt8 {
        return storage[index]
    }

    private func readUInt16(at index: Int) -> UInt16 {
        // Assuming the bytes in storage are in little-endian format
        let b0 = UInt16(storage[index])
        let b1 = UInt16(storage[index + 1]) << 8
        return b0 | b1
    }

    private func readUInt32(at index: Int) -> UInt32 {
        // Manual bit-shift
        let b0 = UInt32(storage[index])
        let b1 = UInt32(storage[index + 1]) << 8
        let b2 = UInt32(storage[index + 2]) << 16
        let b3 = UInt32(storage[index + 3]) << 24
        return b0 | b1 | b2 | b3
    }
}
