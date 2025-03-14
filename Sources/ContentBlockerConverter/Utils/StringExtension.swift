import Foundation

/// Useful string extensions.
extension String {
    /// Escapes special characters so that the string could be used in a JSON.
    public func escapeForJSON() -> String {
        var result = ""

        let utf8 = self.utf8
        var escapedSequence: String?
        var startNonEscapedIndex = utf8.startIndex
        var lastNotEscapedIndex = startNonEscapedIndex
        while lastNotEscapedIndex < utf8.endIndex {
            let char = utf8[lastNotEscapedIndex]
            switch char {
            case 0x5C: escapedSequence = "\\\\"
            case 0x22: escapedSequence = "\\\""
            case 0x0A: escapedSequence = "\\n"
            case 0x0D: escapedSequence = "\\r"
            case 0x09: escapedSequence = "\\t"
            case 0x08: escapedSequence = "\\b"
            case 0x0C: escapedSequence = "\\f"
            case 0x00..<0x10:
                escapedSequence = "\\u000\(String(char, radix: 16, uppercase: true))"
            case 0x10..<0x20:
                escapedSequence = "\\u00\(String(char, radix: 16, uppercase: true))"
            default:
                lastNotEscapedIndex = utf8.index(after: lastNotEscapedIndex)
                continue
            }

            if lastNotEscapedIndex != startNonEscapedIndex {
                result.append(String(self[startNonEscapedIndex..<lastNotEscapedIndex]))
            }
            if let escapedSequence = escapedSequence {
                result.append(escapedSequence)
            }

            lastNotEscapedIndex = utf8.index(after: lastNotEscapedIndex)
            startNonEscapedIndex = lastNotEscapedIndex
        }

        if escapedSequence == nil {
            // If nothing was escaped in the string, we can simply return the String itself.
            return self
        }

        if startNonEscapedIndex != utf8.endIndex {
            result.append(String(self[startNonEscapedIndex..<utf8.endIndex]))
        }

        return result
    }

    /// Replaces all occurrences of the target string with the specified string.
    public func replace(target: String, withString: String) -> String {
        return self.replacingOccurrences(
            of: target,
            with: withString,
            options: NSString.CompareOptions.literal,
            range: nil
        )
    }

    /// Splits the string into parts by the specified delimiter.
    ///
    /// Takes into account if delimiter is escaped by the specified escape character.
    /// Ignores empty components.
    public func split(delimiter: UInt8, escapeChar: UInt8) -> [String] {
        let utf8 = self.utf8

        if utf8.isEmpty {
            return [String]()
        }

        // In case of AdGuard rules most of the rules have just one modifier
        // so this tiny check despite looking strange allows to avoid
        // quite a lot of unnecessary allocations.
        if utf8.firstIndex(of: delimiter) == nil {
            return [self]
        }

        var result: [String] = []
        var currentIndex = utf8.startIndex
        var escaped = false
        var buffer: [UInt8] = []

        while currentIndex < utf8.endIndex {
            let char = utf8[currentIndex]

            switch char {
            case delimiter:
                if escaped {
                    // Add the delimiter to the buffer since it's escaped.
                    buffer.append(char)
                    escaped = false
                } else {
                    if !buffer.isEmpty {
                        if let string = String(bytes: buffer, encoding: .utf8) {
                            result.append(string)
                        }
                        buffer.removeAll()
                    }
                }
            case escapeChar:
                if escaped {
                    // Add the escape character itself since it was escaped.
                    buffer.append(char)
                    escaped = false
                } else {
                    escaped = true
                }
            default:
                if escaped {
                    // Add the escape character for an escaped non-delimiter character.
                    escaped = false
                }
                buffer.append(char)
            }

            currentIndex = utf8.index(after: currentIndex)
        }

        // Add the last part if there are remaining characters in the buffer
        if !buffer.isEmpty {
            if let string = String(bytes: buffer, encoding: .utf8) {
                result.append(string)
            }
        }

        return result
    }

    /// Returns range of the first regex match in the string.
    public func firstMatch(for regex: NSRegularExpression) -> Range<String.Index>? {
        let range = NSRange(location: 0, length: self.utf16.count)
        if let match = regex.firstMatch(in: self, options: [], range: range) {
            return Range(match.range, in: self)
        }

        return nil
    }

    /// Returns all regex matches found in the string.
    public func matches(regex: NSRegularExpression) -> [String] {
        let range = NSRange(location: 0, length: self.utf16.count)
        let matches = regex.matches(in: self, options: [], range: range)
        return matches.compactMap { match in
            guard let substringRange = Range(match.range, in: self) else {
                return nil
            }
            return String(self[substringRange])
        }
    }
}

extension StringProtocol {
    public func isASCII() -> Bool {
        return utf8.allSatisfy { $0 < 128 }
    }
}

extension Collection where Element == UInt8, Index == String.Index {
    /// Access a UTF-8 code unit by integer index.
    public subscript(safeIndex index: Int) -> UInt8? {
        guard index >= 0,
            let utf8Index = self.index(startIndex, offsetBy: index, limitedBy: endIndex)
        else {
            return nil
        }
        return self[utf8Index]
    }
}

/// Extending Collection with UInt8 elements as they're used when working with UTF8 String representations.
extension Collection where Element == UInt8 {
    /// Checks if the collection contains the specified one.
    public func includes<C: Collection>(_ other: C) -> Bool where C.Element == UInt8 {
        guard !other.isEmpty else {
            // Empty subsequence is trivially included
            return true
        }

        // If other is longer than self, it can’t be included
        guard count >= other.count else {
            return false
        }

        var start = startIndex
        while start != endIndex {
            // Check if there’s enough space left for other
            if distance(from: start, to: endIndex) < other.count {
                break
            }

            var currentIndex = start
            var otherIndex = other.startIndex
            var matched = true

            while otherIndex != other.endIndex {
                if self[currentIndex] != other[otherIndex] {
                    matched = false
                    break
                }
                formIndex(after: &currentIndex)
                other.formIndex(after: &otherIndex)
            }

            if matched {
                return true
            }

            formIndex(after: &start)
        }

        return false
    }
}
