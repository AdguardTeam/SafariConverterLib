/// Extension to divide array by chunk size
extension Array {
    public func chunked(into size: Int) -> [[Element]] {
        if size <= 0 {
            return []
        }

        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

extension Array where Element == String {
    /// Encodes the string array to JSON format.
    /// - Parameter escape: If true, escape the strings in the array. Otherwise, just concatenate as is.
    /// - Returns: A JSON-formatted string representation of the array.
    public func encodeToJSON(escape: Bool = false) -> String {
        var result = "["

        for index in 0..<self.count {
            if index > 0 {
                result.append(",")
            }

            result.append("\"")
            result.append(escape ? self[index].escapeForJSON() : self[index])
            result.append("\"")
        }

        result.append("]")

        return result
    }
}
