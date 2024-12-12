import Foundation

/**
 * Useful string extensions
 *
 * TODO(ameshkov): !!! Rework using UTF8View
 */
extension String {
    
    /// Escapes special characters so that the string could be used in a JSON.
    func escapeForJSON() -> String {
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
            result.append(escapedSequence!)
            
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
    
    // TODO(ameshkov): !!! Remove
    func indexOf(target: String) -> Int {
        let range = self.range(of: target)
        if let range = range {
            return distance(from: self.startIndex, to: range.lowerBound)
        } else {
            return -1
        }
    }
    
    // TODO(ameshkov): !!! Remove
    func lastIndexOf(target: String) -> Int {
        let range = self.range(of: target, options: .backwards)
        if let range = range {
            return distance(from: self.startIndex, to: range.lowerBound)
        } else {
            return -1
        }
    }
    
    // TODO(ameshkov): !!! Remove
    func subString(startIndex: Int) -> String {
        let start = self.index(self.startIndex, offsetBy: startIndex);
        let end = self.index(self.endIndex, offsetBy: 0);
        return String(self[start..<end])
    }
    
    /// Replaces all occuriences of the target string with the specified string.
    func replace(target: String, withString: String) -> String {
        return self.replacingOccurrences(of: target, with: withString, options: NSString.CompareOptions.literal, range: nil)
    }
    
    /// Splits the string into parts by the specified delimiter.
    ///
    /// Takes into account if delimiter is escaped by the specified escape character.
    /// Ignores empty components.
    ///
    /// TODO(ameshkov): !!! Add tests for this method
    func split(delimiter: UInt8, escapeChar: UInt8) -> [String] {
        let maxIndex = self.utf8.count - 1
        
        var result = [String]()
        var previousDelimiterIndex = -1
        
        for index in 0...maxIndex {
            let char = self.utf8[safeIndex: index]!
            
            if char == delimiter || index == maxIndex {
                // Ignore escaped delimiter.
                if index > 0 && char == delimiter && self.utf8[safeIndex: index - 1] == escapeChar {
                    continue
                }
                
                var partEndIndex = index
                if index == maxIndex {
                    partEndIndex = index + 1
                }
                
                if partEndIndex > previousDelimiterIndex+1 {
                    let startIndex = self.utf8.index(self.startIndex, offsetBy: previousDelimiterIndex + 1)
                    let endIndex = self.utf8.index(self.startIndex, offsetBy: partEndIndex)

                    let part = String(self[startIndex..<endIndex])
                    result.append(part)
                }
                
                previousDelimiterIndex = index
            }
        }

        return result
    }
    
    /// Returns range of the first regex match in the string.
    func firstMatch(for regex: NSRegularExpression) -> Range<String.Index>? {
        let range = NSMakeRange(0, self.utf16.count)
        if let match = regex.firstMatch(in: self, options: [], range: range) {
            return Range(match.range, in: self)
        }

        return nil
    }
    
    /// Returns all regex matches found in the string.
    func matches(regex: NSRegularExpression) -> [String] {
        let range = NSMakeRange(0, self.utf16.count)
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
    func isASCII() -> Bool {
        return utf8.allSatisfy { $0 < 128 }
    }
}

extension Collection where Element == UInt8, Index == String.Index {
    /// Access a UTF-8 code unit by integer index.
    subscript(safeIndex index: Int) -> UInt8? {
        guard index >= 0, let utf8Index = self.index(startIndex, offsetBy: index, limitedBy: endIndex) else {
            return nil
        }
        return self[utf8Index]
    }
}

/// Extending Collection with UInt8 elements as they're used when working with UTF8 String representations.
extension Collection where Element == UInt8 {
    /// Checks if the collection contains the specified one.
    func includes<C: Collection>(_ other: C) -> Bool where C.Element == UInt8 {
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
