import Foundation

// MARK: - Serialization

extension FilterRule {
    enum FilterRuleCodingError: Error {
        case stringTooLong(actualLength: Int, maxAllowed: Int)
        case notEnoughBytes
        case dataCorrupted(message: String)
    }

    /// Serialize this FilterRule to a Data blob (binary property list).
    public func toData() throws -> Data {
        var buffer = Data()

        // 1) Write action.rawValue as a 4-byte integer (Int32).
        var actionRaw = Int32(action.rawValue)
        withUnsafeBytes(of: &actionRaw) { buffer.append(contentsOf: $0) }

        // 2) Write urlPattern (non-optional in the struct, but we follow the compact rules).
        try FilterRule.writeString(urlPattern, to: &buffer)

        // 3) Write urlRegex
        try FilterRule.writeString(urlRegex, to: &buffer)

        // 4) Write thirdParty
        FilterRule.writeOptionalBool(thirdParty, to: &buffer)

        // 5) Write subdocument
        FilterRule.writeOptionalBool(subdocument, to: &buffer)

        // 6) Write pathRegex
        try FilterRule.writeString(pathRegex, to: &buffer)

        // 7) Write priority as 1 byte
        buffer.append(priority)

        // 8) Write permittedDomains array
        try FilterRule.writeStringArray(permittedDomains, to: &buffer)

        // 9) Write restrictedDomains array
        try FilterRule.writeStringArray(restrictedDomains, to: &buffer)

        // 10) Write cosmeticContent
        try FilterRule.writeString(cosmeticContent, to: &buffer)

        return buffer
    }

    /// Deserialize a FilterRule from a Data blob produced by toData().
    public static func fromData(_ data: Data) throws -> FilterRule {
        // We'll parse the data in the same order we wrote it.
        var index = 0

        // Helper to ensure we don't read past the end.
        func requireBytes(_ count: Int) throws {
            guard index + count <= data.count else {
                throw FilterRuleCodingError.notEnoughBytes
            }
        }

        // 1) Read action.rawValue (4 bytes -> Int32)
        try requireBytes(4)
        let actionValue = data.subdata(in: index..<(index + 4)).withUnsafeBytes {
            $0.load(as: Int32.self)
        }
        index += 4
        let action = Action(rawValue: Int(actionValue))

        // 2) Read urlPattern
        let urlPattern = try readString(from: data, index: &index) ?? ""

        // 3) Read urlRegex
        let urlRegex = try readString(from: data, index: &index)

        // 4) Read thirdParty
        let thirdParty = try readOptionalBool(from: data, index: &index)

        // 5) Read subdocument
        let subdocument = try readOptionalBool(from: data, index: &index)

        // 6) Read pathRegex
        let pathRegex = try readString(from: data, index: &index)

        // 7) Read priority (1 byte)
        try requireBytes(1)
        let priority = data[index]
        index += 1

        // 8) Read permittedDomains array
        let permittedDomains = try readStringArray(from: data, index: &index)

        // 9) Read restrictedDomains array
        let restrictedDomains = try readStringArray(from: data, index: &index)

        // 10) Read cosmeticContent
        let cosmeticContent = try readString(from: data, index: &index)

        return FilterRule(
            action: action,
            urlPattern: urlPattern,
            urlRegex: urlRegex,
            thirdParty: thirdParty,
            subdocument: subdocument,
            pathRegex: pathRegex,
            priority: priority,
            permittedDomains: permittedDomains,
            restrictedDomains: restrictedDomains,
            cosmeticContent: cosmeticContent
        )
    }
}

// MARK: - Private helpers for compact serialization

extension FilterRule {
    /// Writes a String? into the buffer using [2-byte length] + [bytes].
    /// - If the string is nil or empty, writes 0 for length.
    private static func writeString(_ value: String?, to buffer: inout Data) throws {
        guard let string = value, !string.isEmpty else {
            // zero length is nil
            writeUInt16(0, to: &buffer)
            return
        }

        let utf8Bytes = Array(string.utf8)
        guard utf8Bytes.count <= UInt16.max else {
            throw FilterRuleCodingError.stringTooLong(
                actualLength: utf8Bytes.count,
                maxAllowed: Int(UInt16.max)
            )
        }

        writeUInt16(UInt16(utf8Bytes.count), to: &buffer)
        buffer.append(contentsOf: utf8Bytes)
    }

    /// Reads a String? from the buffer using our [2-byte length] + [bytes] format.
    /// - If length == 0, returns nil
    private static func readString(from data: Data, index: inout Int) throws -> String? {
        let length = try readUInt16(from: data, index: &index)
        if length == 0 {
            return nil
        }
        // Now read 'length' bytes
        guard index + Int(length) <= data.count else {
            throw FilterRuleCodingError.notEnoughBytes
        }
        let slice = data[index..<(index + Int(length))]
        index += Int(length)
        guard let str = String(data: slice, encoding: .utf8) else {
            throw FilterRuleCodingError.dataCorrupted(message: "Unable to decode UTF8")
        }
        return str
    }

    /// Writes an array of strings as:
    ///   [2-byte arrayCount], then each string with writeString(...)
    private static func writeStringArray(_ array: [String], to buffer: inout Data) throws {
        guard array.count <= UInt16.max else {
            throw FilterRuleCodingError.dataCorrupted(
                message: "Array has too many elements (\(array.count) > \(UInt16.max))"
            )
        }
        writeUInt16(UInt16(array.count), to: &buffer)
        for str in array {
            try writeString(str, to: &buffer)
        }
    }

    /// Reads an array of strings from the buffer (2-byte count + each string).
    private static func readStringArray(from data: Data, index: inout Int) throws -> [String] {
        let count = try readUInt16(from: data, index: &index)
        var result: [String] = []
        result.reserveCapacity(Int(count))
        for _ in 0..<count {
            let string = try readString(from: data, index: &index) ?? ""
            result.append(string)
        }
        return result
    }

    /// Writes a UInt16 as 2 big-endian bytes.
    private static func writeUInt16(_ value: UInt16, to buffer: inout Data) {
        // For clarity, we’ll store all multi-byte values in network (big-endian) order.
        buffer.append(UInt8(value >> 8 & 0xFF))
        buffer.append(UInt8(value & 0xFF))
    }

    /// Reads a UInt16 from 2 big-endian bytes in data[index...].
    private static func readUInt16(from data: Data, index: inout Int) throws -> UInt16 {
        guard index + 2 <= data.count else {
            throw FilterRuleCodingError.notEnoughBytes
        }
        let high = data[index]
        let low = data[index + 1]
        index += 2
        return (UInt16(high) << 8) | UInt16(low)
    }

    /// Writes Bool? (1 byte: 0 = nil, 1 = true, 2 = false)
    private static func writeOptionalBool(_ value: Bool?, to buffer: inout Data) {
        if let val = value {
            buffer.append(val ? 1 : 2)
        } else {
            buffer.append(0)
        }
    }

    /// Reads Bool? (1 byte: 0 = nil, 1 = true, 2 = false)
    private static func readOptionalBool(from data: Data, index: inout Int) throws -> Bool? {
        guard index + 1 <= data.count else {
            throw FilterRuleCodingError.notEnoughBytes
        }

        let val = data[index]
        index += 1

        switch val {
        case 1:
            return true
        case 2:
            return false
        default:
            // 0 or any other value means nil
            return nil
        }
    }
}
