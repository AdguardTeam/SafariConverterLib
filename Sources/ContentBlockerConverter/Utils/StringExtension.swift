import Foundation

extension String {
    
    func indexOf(target: String) -> Int {
        var range = self.range(of: target)
        if let range = range {
            return distance(from: self.startIndex, to: range.lowerBound)
        } else {
            return -1
        }
    }
    
    func indexOf(target: String, startIndex: Int) -> Int {
        let startRange = self.index(target.startIndex, offsetBy: startIndex);
        let range = self.range(of: target, options: NSString.CompareOptions.literal)

        if let range = range {
            return distance(from: self.startIndex, to: range.lowerBound)
        } else {
            return -1
        }
    }
    
    func lastIndexOf(target: String) -> Int {
        var index = -1
        var stepIndex = self.indexOf(target: target)
        while stepIndex > -1
        {
            index = stepIndex
            if stepIndex + target.count < self.count {
                stepIndex = indexOf(target: target, startIndex: stepIndex + target.count)
            } else {
                stepIndex = -1
            }
        }
        return index
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
    
    func isMatch(regex: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: regex, options: [.caseInsensitive]) else { return false }
        let matchCount = regex.numberOfMatches(in: self, options: [], range: NSMakeRange(0, self.count))
        return matchCount > 0
    }
    
    func matches(regex: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: [.caseInsensitive]) else { return [] }
        let matches  = regex.matches(in: self, options: [], range: NSMakeRange(0, self.count))
        return matches.map { match in
            return String(self[Range(match.range, in: self)!])
        }
    }
}
