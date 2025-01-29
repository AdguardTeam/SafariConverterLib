import Foundation
import ContentBlockerConverter

// MARK: - Filter rule definition

/// Represents an ad blocking filtering rule for AdGuard.
///
/// This structure is used in `FilterEngine` which is supposed to be used
/// for implementing advanced ad blocking rules. Therefore, it only supports a limited
/// subset of functionality (see `Action`) which is possible to be implement in
/// Safari WebExtension, i.e. it only supports cosmetic rules and those allowlist rules
/// that can disable cosmetics.
///
/// TODO(ameshkov): !!! Does not support `$subdocument`, `$third-party`.
public struct FilterRule: Codable {
    /// Defines what this filter rule does.
    public let action: Action

    /// URL pattern that uses AdGuard syntax.
    public let urlPattern: String

    /// Regular expression for matching URLs.
    /// If not set, any URL is accepted.
    public let urlRegex: String?

    /// Regular expression for matching URL path. It comes from `$path` modifier
    /// of a cosmetic rule. /// If not set, any path is accepted.
    public let pathRegex: String?

    /// Rule priority (important for network rules only).
    public let priority: UInt8

    /// An array of domains for which this rule is allowed.
    public let permittedDomains: [String]

    /// An array of domains for which this rule is disallowed.
    public let restrictedDomains: [String]

    /// Cosmetic rule content means different things depending
    /// on the rule action.
    ///
    /// - For element hiding rules: this is a CSS selector
    /// - For CSS injection rules: this is CSS selector + style
    /// - For script rules: this is JS content.
    /// - For scriptlet rules: this is a scriptlet call (effectively the same as for JS rules).
    public let cosmeticContent: String?

    /// Initializes a `FilterRule` from a `Rule` instance.
    ///
    /// It can throw a `RuleError` if the specified rule is not supported.
    public init(from rule: Rule) throws {
        if rule is NetworkRule {
            try self.init(from: rule as! NetworkRule)
        } else if rule is CosmeticRule {
            try self.init(from: rule as! CosmeticRule)
        } else {
            throw RuleError.unsupported(message: "Unsupported rule: \(rule.ruleText)")
        }
    }

    /// Initializes a `FilterRule` from a `NetworkRule` instance.
    ///
    /// Note, that we only support whitelist (`@@`) rules that disable cosmetic rules, it will throw an error
    /// on any other rule.
    ///
    /// `$badfilter` rules aren't supported either, they're supposed to be interpreted by `RuleFactory`.
    public init(from rule: NetworkRule) throws {
        if !rule.isWhiteList {
            throw RuleError.unsupported(message: "Only whitelist network rules are supported: \(rule.ruleText)")
        }

        if rule.isBadfilter {
            throw RuleError.unsupported(message: "$badfilter rules are not supported: \(rule.ruleText)")
        }

        action = try FilterRule.getNetworkRuleAction(rule)
        urlPattern = rule.urlRuleText
        urlRegex = rule.urlRegExpSource
        // We're dealing with a very simplified case where we only have
        // whitelist rules and cosmetic rules. The priority would be
        // the following:
        // @@$important > @@ > cosmetic rules.
        priority = rule.isImportant ? 2 : 1
        permittedDomains = rule.permittedDomains
        restrictedDomains = rule.restrictedDomains

        // Specific to cosmetic rules.
        pathRegex = nil
        cosmeticContent = nil
    }

    /// Initializes a `FilterRule` from a `CosmeticRule` instance.
    ///
    /// Note, that whitelist cosmetic rules (likes of `#@#`) are not supported and a `RuleError`
    /// will be thrown. Whitelist rules are supposed to be interpreted by `RuleFactory`.
    public init(from rule: CosmeticRule) throws {
        if rule.isWhiteList {
            throw RuleError.unsupported(message: "Whitelist cosmetic rules are not supported: \(rule.ruleText)")
        }

        action = try FilterRule.getCosmeticRuleAction(rule)

        urlPattern = "*"
        urlRegex = nil
        pathRegex = rule.pathRegExpSource

        // For cosmetic rules priority is lower than for network rules.
        priority = 0
        permittedDomains = rule.permittedDomains
        restrictedDomains = rule.restrictedDomains
        cosmeticContent = rule.content
    }

    /// A convenient public initializer to allow creating a FilterRule with explicit parameters.
    /// Swift won't auto-generate it publicly unless all properties are public (which they are),
    /// but depending on Swift version/visibility rules, you may need an explicit initializer
    /// to match the usage in fromData(...).
    init(
        action: Action,
        urlPattern: String,
        urlRegex: String?,
        pathRegex: String?,
        priority: UInt8,
        permittedDomains: [String],
        restrictedDomains: [String],
        cosmeticContent: String?
    ) {
        self.action = action
        self.urlPattern = urlPattern
        self.urlRegex = urlRegex
        self.pathRegex = pathRegex
        self.priority = priority
        self.permittedDomains = permittedDomains
        self.restrictedDomains = restrictedDomains
        self.cosmeticContent = cosmeticContent
    }
}

/// Action represents what the rule should do.
public struct Action: OptionSet, Codable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Rules that disable CSS cosmetic rules, i.e. `$elemhide`.
    public static let disableCSS         = Action(rawValue: 1 << 0)

    /// Rules that disable generic CSS rules, i.e. `$generichide`.
    public static let disableGenericCSS  = Action(rawValue: 1 << 1)

    /// Rules that disable specific CSS rules, i.e. `$specifichide`.
    public static let disableSpecificCSS = Action(rawValue: 1 << 2)

    /// Rules that disable script rules, i.e. `$jsinject`.
    public static let disableScript      = Action(rawValue: 1 << 3)

    /// Regular element hiding rules, i.e. `##`.
    public static let cssDisplayNone   = Action(rawValue: 1 << 4)

    /// CSS injection rules, i.e. `#$#`.
    public static let cssInject        = Action(rawValue: 1 << 5)

    /// Scriptlet rules, i.e. `#%#//scriptlet`.
    public static let scriptlet        = Action(rawValue: 1 << 6)

    /// Script injection rules, i.e. `#%#`.
    public static let scriptInject     = Action(rawValue: 1 << 7)

    /// Extended CSS rules (can be element hiding or CSS inject), i.e. `#?#` or `#$?#`
    public static let extendedCSS      = Action(rawValue: 1 << 8)

    public static let network: Action = [disableCSS, disableGenericCSS, disableSpecificCSS, disableScript]
    public static let cosmetic: Action = [cssDisplayNone, cssInject, scriptlet, scriptInject, extendedCSS]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(Int.self)
        self.init(rawValue: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

/// Represents a rule error.
public enum RuleError: Error {
    case unsupported(message: String)
}

// MARK: - Helper functions for FilterRule initialization

extension FilterRule {

    /// Creates `Action` from a network rule and returns it or throws `RuleError`
    /// if this network rule cannot be used in Safari.
    private static func getNetworkRuleAction(_ rule: NetworkRule) throws -> Action {
        var action = Action()

        if rule.isOptionEnabled(option: .elemhide) {
            action.insert(.disableCSS)
        }

        if rule.isOptionEnabled(option: .jsinject) {
            action.insert(.disableScript)
        }

        if rule.isOptionEnabled(option: .generichide) {
            action.insert(.disableGenericCSS)
        }

        if rule.isOptionEnabled(option: .specifichide) {
            action.insert(.disableSpecificCSS)
        }

        if rule.isOptionEnabled(option: .document) {
            action = [.disableCSS, .disableScript]
        }

        if action.isEmpty {
            throw RuleError.unsupported(message: "No usable action found: \(rule.ruleText)")
        }

        return action
    }

    /// Creates `Action` from a cosmetic rule and returns it or throws `RuleError`
    /// if this cosmetic rule cannot be used in Safari.
    private static func getCosmeticRuleAction(_ rule: CosmeticRule) throws -> Action {
        var action = Action()

        if rule.isExtendedCss {
            action.insert(.extendedCSS)
        }

        if rule.isElemhide {
            action.insert(.cssDisplayNone)
        } else if rule.isInjectCss {
            action.insert(.cssInject)
        } else if rule.isScriptlet {
            action.insert(.scriptlet)
        } else if rule.isScript {
            action.insert(.scriptInject)
        } else {
            throw RuleError.unsupported(message: "No usable action found: \(rule.ruleText)")
        }

        return action
    }
}


// MARK: - Extracting rule pattern shortcut

extension FilterRule {

    /// Extracts "shortcuts" from the given pattern. Shortcuts:
    ///  - Must not contain `|`, `*`, or `^`
    ///  - Must be at least 3 characters long
    ///  - Are collected in a single pass through the `pattern`'s UTF8View
    public static func extractShortcuts(from pattern: String) -> [String] {
        var result = [String]()
        var buffer = [UInt8]()  // Temporarily store bytes for the current shortcut

        for byte in pattern.utf8 {
            switch byte {
            case UInt8(ascii: "|"), UInt8(ascii: "*"), UInt8(ascii: "^"):
                // We've hit a special character.
                // If the buffer has at least 3 bytes, convert it and add to results.
                if buffer.count >= 3,
                   let shortcut = String(bytes: buffer, encoding: .utf8) {
                    result.append(shortcut)
                }
                // Reset the buffer for the next potential shortcut.
                buffer.removeAll()
            default:
                buffer.append(byte)
            }
        }

        // End of string: check if there's a leftover shortcut in the buffer
        if buffer.count >= 3,
           let shortcut = String(bytes: buffer, encoding: .utf8) {
            result.append(shortcut)
        }

        return result
    }
}

// MARK: - Extracting regex shortcuts

extension FilterRule {

    /// Extracts "shortcuts" from a regex pattern, following the rules:
    ///  1. Shortcut is a string without special characters that can be used to
    ///     test a string before using the regular expression.
    ///  2. Discard (return []) immediately if `(?` is encountered anywhere.
    ///  3. Discard (return []) immediately if `|` is encountered outside of brackets.
    ///  4. Keep track of brackets `()`, `[]`, `{}`:
    ///     - Anything inside brackets is discarded (not added to shortcuts).
    ///     - Nested brackets are allowed.
    ///  5. A bracket can be escaped (e.g. `\(`), so it does NOT count as an opening bracket.
    ///  6. Accumulate all valid characters outside of brackets into "shortcut" strings,
    ///     splitting whenever we see a "special" regex character (while outside brackets).
    public static func extractRegexShortcuts(from pattern: String) -> [String] {

        // 1) Define sets / maps we'll need:

        // Special regex characters that *end* a shortcut (while outside brackets).
        // Feel free to expand this set if your scenario demands it.
        @inline(__always) func isSpecialCharacter(_ c: UInt8) -> Bool {
            switch c {
            case UInt8(ascii: "^"),
                UInt8(ascii: "$"),
                UInt8(ascii: "."),
                UInt8(ascii: "*"),
                UInt8(ascii: "+"),
                UInt8(ascii: "?"),
                UInt8(ascii: "|"):
                return true
            default: return false
            }
        }

        // We’ll track matching brackets in a stack to handle nesting properly:
        //   '(' matches ')'
        //   '[' matches ']'
        //   '{' matches '}'
        @inline(__always) func getBracketPair(_ c: UInt8) -> UInt8? {
            switch c {
            case UInt8(ascii: "("): return UInt8(ascii: ")")
            case UInt8(ascii: "["): return UInt8(ascii: "]")
            case UInt8(ascii: "{"): return UInt8(ascii: "}")
            default: return nil
            }
        }

        var bracketStack = [UInt8]()   // keeps track of opening brackets
        var result = [String]()        // final shortcuts
        var buffer = [UInt8]()         // accumulate outside-bracket chars
        var isEscaped = false          // are we escaping the *next* character?

        let utf8 = pattern.utf8
        var i = utf8.startIndex
        let end = utf8.endIndex

        // Helper function that flushes the current buffer and adds the shortcut
        // to the resulting array (given that the buffer is 3 or more characters).
        @inline(__always) func flushBuffer() {
            if buffer.count >= 3 {
                if let str = String(bytes: buffer, encoding: .utf8), !str.isEmpty {
                    result.append(str)
                }
            }

            if !buffer.isEmpty {
                buffer.removeAll()
            }
        }

        // Helper function to peek the next character.
        @inline(__always) func peekNext() -> UInt8? {
            let next = utf8.index(after: i)
            guard next < end else { return nil }
            return utf8[next]
        }

        while i < end {
            let byte = utf8[i]

            // -- Step 0: Check for negative lookahead "(?" here
            if !isEscaped && byte == UInt8(ascii: "(") {
                if peekNext() == UInt8(ascii: "?") {
                    // Found "(?" => discard immediately
                    return []
                }
            }

            // -- Step 1: Check for '|' outside of brackets
            if !isEscaped && bracketStack.isEmpty && byte == UInt8(ascii: "|") {
                // If '|' is encountered outside brackets, discard everything as
                // we cannot guarantee a shortcut.
                return []
            }

            // -- Step 2: Handle escaping logic
            if isEscaped {
                // The current byte is escaped => treat it as a literal outside bracket context if we are outside
                // or ignore it if we are inside bracket? The requirement says:
                //  "A bracket can be escaped, in this case it can be used as a shortcut."
                // We'll interpret it as: if the bracket is escaped, do NOT open or close bracketStack,
                // but do add it to the buffer if bracketStack is empty.
                // The backslash itself is not part of the "shortcut" so we'll skip it.

                // The previous character was '\', so let's treat 'byte' as literal:
                if bracketStack.isEmpty {
                    // If we're outside brackets, we accumulate
                    // BUT if it's a special regex char, that ends the current buffer
                    if isSpecialCharacter(byte) {
                        flushBuffer()
                    } else {
                        buffer.append(byte)
                    }
                }
                // If we are inside brackets, we skip adding to outside buffer (we discard it).
                isEscaped = false
                i = utf8.index(after: i)
                continue
            }

            // If not escaped, check if current is '\'
            if byte == UInt8(ascii: "\\") {
                // The next character is escaped, so set isEscaped = true
                isEscaped = true
                i = utf8.index(after: i)
                continue
            }

            // -- Step 3: Check if the current byte is an opening bracket (not escaped)
            if let closing = getBracketPair(byte) {
                // It's one of '(', '[', or '{'
                bracketStack.append(closing)
                // We are entering bracket context => discard anything inside.
                // So first, finalize the buffer if we have something:
                flushBuffer()
                i = utf8.index(after: i)
                continue
            }

            // -- Step 4: Check if the current byte is a closing bracket (not escaped)
            if bracketStack.last == byte {
                // It's the matching closing bracket for the top of the stack
                bracketStack.removeLast()
                // We do not add the bracket to the buffer, since we are discarding bracket content.
                i = utf8.index(after: i)
                continue
            }

            // -- Step 5: If we are inside brackets, ignore this character
            if !bracketStack.isEmpty {
                // Just skip it
                i = utf8.index(after: i)
                continue
            }

            // -- Step 6: If we’re outside brackets and the current character is a "special" regex char,
            //            that ends the current buffer (like a splitter).
            if isSpecialCharacter(byte) {
                flushBuffer()
            } else {
                // Otherwise, it's a normal character outside brackets => accumulate
                buffer.append(byte)
            }

            i = utf8.index(after: i)
        }

        // End of string => finalize buffer if non-empty
        flushBuffer()

        return result
    }

}

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

        // 4) Write pathRegex
        try FilterRule.writeString(pathRegex, to: &buffer)

        // 5) Write priority as 1 byte
        buffer.append(priority)

        // 6) Write permittedDomains array
        try FilterRule.writeStringArray(permittedDomains, to: &buffer)

        // 7) Write restrictedDomains array
        try FilterRule.writeStringArray(restrictedDomains, to: &buffer)

        // 8) Write cosmeticContent
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
        let actionValue = data.subdata(in: index..<(index + 4)).withUnsafeBytes { $0.load(as: Int32.self) }
        index += 4
        let action = Action(rawValue: Int(actionValue))

        // 2) Read urlPattern
        let urlPattern = try readString(from: data, index: &index) ?? ""

        // 3) Read urlRegex
        let urlRegex = try readString(from: data, index: &index)

        // 4) Read pathRegex
        let pathRegex = try readString(from: data, index: &index)

        // 5) Read priority (1 byte)
        try requireBytes(1)
        let priority = data[index]
        index += 1

        // 6) Read permittedDomains array
        let permittedDomains = try readStringArray(from: data, index: &index)

        // 7) Read restrictedDomains array
        let restrictedDomains = try readStringArray(from: data, index: &index)

        // 8) Read cosmeticContent
        let cosmeticContent = try readString(from: data, index: &index)

        return FilterRule(
            action: action,
            urlPattern: urlPattern,
            urlRegex: urlRegex,
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
        guard let s = value, !s.isEmpty else {
            // zero length is nil
            try writeUInt16(0, to: &buffer)
            return
        }

        let utf8Bytes = Array(s.utf8)
        guard utf8Bytes.count <= UInt16.max else {
            throw FilterRuleCodingError.stringTooLong(
                actualLength: utf8Bytes.count,
                maxAllowed: Int(UInt16.max)
            )
        }

        try writeUInt16(UInt16(utf8Bytes.count), to: &buffer)
        buffer.append(contentsOf: utf8Bytes)
    }

    /// Reads a String? from the buffer using our [2-byte length] + [bytes] format.
    /// - If length == 0, returns nil
    fileprivate static func readString(from data: Data, index: inout Int) throws -> String? {
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
    fileprivate static func writeStringArray(_ array: [String], to buffer: inout Data) throws {
        guard array.count <= UInt16.max else {
            throw FilterRuleCodingError.dataCorrupted(
                message: "Array has too many elements (\(array.count) > \(UInt16.max))"
            )
        }
        try writeUInt16(UInt16(array.count), to: &buffer)
        for str in array {
            try writeString(str, to: &buffer)
        }
    }

    /// Reads an array of strings from the buffer (2-byte count + each string).
    fileprivate static func readStringArray(from data: Data, index: inout Int) throws -> [String] {
        let count = try readUInt16(from: data, index: &index)
        var result = [String]()
        result.reserveCapacity(Int(count))
        for _ in 0..<count {
            let s = try readString(from: data, index: &index) ?? ""
            result.append(s)
        }
        return result
    }

    /// Writes a UInt16 as 2 big-endian bytes.
    fileprivate static func writeUInt16(_ value: UInt16, to buffer: inout Data) throws {
        // For clarity, we’ll store all multi-byte values in network (big-endian) order.
        buffer.append(UInt8(value >> 8 & 0xFF))
        buffer.append(UInt8(value & 0xFF))
    }

    /// Reads a UInt16 from 2 big-endian bytes in data[index...].
    fileprivate static func readUInt16(from data: Data, index: inout Int) throws -> UInt16 {
        guard index + 2 <= data.count else {
            throw FilterRuleCodingError.notEnoughBytes
        }
        let high = data[index]
        let low  = data[index + 1]
        index += 2
        return (UInt16(high) << 8) | UInt16(low)
    }
}
