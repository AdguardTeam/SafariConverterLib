import Foundation

/**
 * Useful string extensions
 */
extension String {

    /**
     Escapes special characters so that the string could be used in a JSON.
     */
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

    func indexOf(target: String) -> Int {
        let range = self.range(of: target)
        if let range = range {
            return distance(from: self.startIndex, to: range.lowerBound)
        } else {
            return -1
        }
    }

    func indexOf(target: String, startIndex: Int) -> Int {
        let startRange = self.index(target.startIndex, offsetBy: startIndex);
        let range = self.range(of: target, options: NSString.CompareOptions.literal, range: (startRange ..< self.endIndex))
    
        if let range = range {
            return distance(from: self.startIndex, to: range.lowerBound)
        } else {
            return -1
        }
    }

    func lastIndexOf(target: String) -> Int {
        let range = self.range(of: target, options: .backwards)
        if let range = range {
            return distance(from: self.startIndex, to: range.lowerBound)
        } else {
            return -1
        }
    }

    func lastIndexOf(target: String, maxLength: Int) -> Int {
        let cut = String(self.prefix(maxLength));
        return cut.lastIndexOf(target: target);
    }

    func subString(startIndex: Int) -> String {
        let start = self.index(self.startIndex, offsetBy: startIndex);
        let end = self.index(self.endIndex, offsetBy: 0);
        return String(self[start ..< end])
    }

    func subString(startIndex: Int, toIndex: Int) -> String {
        let start = self.index(self.startIndex, offsetBy: startIndex);
        let end = self.index(self.startIndex, offsetBy: toIndex);
        return String(self[start ..< end])
    }

    func subString(from:Int, toSubstring s2 : String) -> String? {
        guard let r = self.range(of:s2) else {return nil}
        var s = self.prefix(upTo:r.lowerBound)
        s = s.dropFirst(from)
        return String(s);
    }

    func subString(startIndex: Int, length: Int) -> String {
        let start = self.index(self.startIndex, offsetBy: startIndex);
        let end = self.index(self.startIndex, offsetBy: startIndex + length);
        return String(self[start ..< end])
    }

    func replace(target: String, withString: String) -> String {
        return self.replacingOccurrences(of: target, with: withString, options: NSString.CompareOptions.literal, range: nil)
    }

    func splitByDelimiterWithEscapeCharacter(delimeter: unichar, escapeChar: unichar) -> [String] {
        let nsstring = self as NSString;
        
        var delimeterIndexes = [Int]();
        for index in 0...nsstring.length - 1 {
            let char = nsstring.character(at: index)
            switch char {
                case delimeter:
                    // ignore escaped
                    if (index > 0 && nsstring.character(at: index - 1) == escapeChar) {
                        continue;
                    }
                    
                    delimeterIndexes.append(index);
                default:
                    break;
            }
        }
                    
        var result = [String]();
        var previous = 0;
        for ind in delimeterIndexes {
            result.append(nsstring.substring(to: ind).subString(startIndex: previous));
            previous = ind + 1;
        }
        
        result.append(nsstring.substring(from: previous));
        
        return result;
    }
    
    func isASCII() -> Bool {
        for scalar in self.unicodeScalars {
            if (!scalar.isASCII) {
                return false;
            }
        }
        
        return true;
    }
}
