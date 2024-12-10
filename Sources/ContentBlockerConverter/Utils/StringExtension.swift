import Foundation

/**
 * Useful string extensions
 *
 * TODO(ameshkov): !!! Rework using UTF8View
 */
extension String {
    
    /// Escapes special characters so that the string could be used in a JSON.
    ///
    /// TODO(ameshkov): Optimize
    func escapeForJSON() -> String {
        var result = ""
        
        let scalars = self.unicodeScalars
        var start = scalars.startIndex
        let end = scalars.endIndex
        var idx = start
        while idx < scalars.endIndex {
            let s: String
            let c = scalars[idx]
            switch c {
            case "\\": s = "\\\\"
            case "\"": s = "\\\""
            case "\n": s = "\\n"
            case "\r": s = "\\r"
            case "\t": s = "\\t"
            case "\u{8}": s = "\\b"
            case "\u{C}": s = "\\f"
            case "\0"..<"\u{10}":
                s = "\\u000\(String(c.value, radix: 16, uppercase: true))"
            case "\u{10}"..<" ":
                s = "\\u00\(String(c.value, radix: 16, uppercase: true))"
            default:
                idx = scalars.index(after: idx)
                continue
            }
            
            if idx != start {
                result.append(String(scalars[start..<idx]))
            }
            result.append(s)
            
            idx = scalars.index(after: idx)
            start = idx
        }
        
        if start != end {
            result.append(String(scalars[start..<end]))
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
    func indexOf(target: String, startIndex: Int) -> Int {
        let startRange = self.index(target.startIndex, offsetBy: startIndex);
        let range = self.range(of: target, options: NSString.CompareOptions.literal, range: (startRange..<self.endIndex))
        
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
    func lastIndexOf(target: String, maxLength: Int) -> Int {
        let cut = String(self.prefix(maxLength));
        return cut.lastIndexOf(target: target);
    }
    
    // TODO(ameshkov): !!! Remove
    func subString(startIndex: Int) -> String {
        let start = self.index(self.startIndex, offsetBy: startIndex);
        let end = self.index(self.endIndex, offsetBy: 0);
        return String(self[start..<end])
    }
    
    // TODO(ameshkov): !!! Remove
    func subString(startIndex: Int, toIndex: Int) -> String {
        let start = self.index(self.startIndex, offsetBy: startIndex)
        let end = self.index(self.startIndex, offsetBy: toIndex)
        return String(self[start..<end])
    }
    
    // TODO(ameshkov): !!! Remove
    func subString(from: Int, toSubstring s2: String) -> String? {
        guard let r = self.range(of: s2) else {
            return nil
        }
        var s = self.prefix(upTo: r.lowerBound)
        s = s.dropFirst(from)
        return String(s);
    }
    
    // TODO(ameshkov): !!! Remove
    func subString(startIndex: Int, length: Int) -> String {
        let start = self.index(self.startIndex, offsetBy: startIndex);
        let end = self.index(self.startIndex, offsetBy: startIndex + length);
        return String(self[start..<end])
    }
    
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

    // TODO(ameshkov): !!! Remove
    func splitByDelimiterWithEscapeCharacter(delimiter: unichar, escapeChar: unichar) -> [String] {
        let str = self as NSString
        if str.length == 0 {
            return [String]()
        }
        
        var delimiterIndexes = [Int]()
        for index in 0...str.length - 1 {
            let char = str.character(at: index)
            switch char {
            case delimiter:
                // ignore escaped
                if (index > 0 && str.character(at: index - 1) == escapeChar) {
                    continue
                }
                
                delimiterIndexes.append(index)
            default:
                break
            }
        }
        
        var result = [String]()
        var previous = 0
        for ind in delimiterIndexes {
            if ind > previous {
                let part = str.substring(with: NSRange(location: previous, length: ind - previous))
                result.append(part)
            } else {
                result.append("")
            }
            previous = ind + 1
        }
        
        result.append(str.substring(from: previous))
        
        return result
    }
}

extension StringProtocol {
    func isASCII() -> Bool {
        for scalar in unicodeScalars {
            if (!scalar.isASCII) {
                return false;
            }
        }
        
        return true;
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
