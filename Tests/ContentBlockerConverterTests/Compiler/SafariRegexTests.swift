import XCTest

@testable import ContentBlockerConverter

final class SafariRegexTests: XCTestCase {
    func testIsSupported() {
        let testPatterns: [(pattern: String, expected: Bool)] = [
            // Basic allowed patterns
            (".*", true),  // Matches all strings
            (".", true),  // Matches any single character
            ("\\.", true),  // Explicitly matches a dot
            ("a", true),  // Single literal character
            ("a*", true),  // Single literal character with a quantifier
            ("a+", true),  // Single literal character with a quantifier
            ("a?", true),  // Single literal character with a quantifier
            ("abc", true),  // Multiple literal characters
            ("[a-z]", true),  // Simple character range
            ("[abc]", true),  // Simple character set
            ("(abc)", true),  // Simple group
            ("a+", true),  // One or more 'a'
            ("a*", true),  // Zero or more 'a'
            ("a?", true),  // Zero or one 'a'
            ("\\\\", true),  // Explicitly matches '\'
            ("\\*", true),  // Explicitly matches '*'
            ("\\?", true),  // Explicitly matches '*'
            ("\\?+", true),  // Escaped special character is quantifiable
            ("[a-b]", true),  // Range a-b
            ("(abc)?", true),  // Group with optional quantifier
            ("[abc]*", true),  // Character class zero or more
            ("(abc)+", true),  // Group one or more
            ("[a-z]+", true),  // One or more in a range
            ("(abc)*", true),  // Group zero or more
            ("(abc).*", true),  // Group followed by any chars
            ("a\\.b", true),  // 'a' literal, dot escaped, 'b' literal
            ("[a-zA-Z]", true),  // Multiple ranges combined
            ("(\\()", true),  // Balanced parentheses, escaped '('
            ("(abc)(def)", true),  // Multiple top-level groups
            ("(a\\.)+", true),  // Escaping inside group followed by quantifier
            ("[^abc]", true),  // Negated classes
            ("(a(bc))", true),  // Nested groups allowed
            ("abc\\^def", true),  // Escaped '^' in the middle of a pattern is allowed
            ("abc\\$def", true),  // Escaped '$' in the middle of a pattern is allowed

            // POSIX character classes are not supported but allowed since they break nothing
            ("[[:alpha:]]", true),

            ("^abc", true),  // Matching beginning of a string
            ("abc$", true),  // Matching the ending of a string
            ("[$^{}()|*+?.\\\\]", true),  // Special characters are allowed inside character range
            ("[abc)(]", true),  // Mixed bracket/parenthesis inside character class is okay
            ("[(]", true),  // Bracket inside character class is ignored
            ("([(])", true),  // Bracket inside character class is ignored

            // Real-life examples
            ("\\.com\\/[_0-9a-zA-Z]+\\.jpg$", true),
            ("^\\/$", true),
            (#"@@/:\/\/.*[.]wp[.]pl\/[a-z0-9_]+[.][a-z]+\/"#, true),
            ("\\/(sub1|sub2)\\/page\\.html", false),
            ("^https?\\:\\/\\/", false),

            // Edge cases allowed due to simplicity of logic
            ("[a-]", true),  // In our simplified logic, we allowed this

            // Explicitly invalid patterns
            (")", false),  // Closing parenthesis without opening
            ("(", false),  // Opening parenthesis not closed
            ("[", false),  // Opening bracket not closed
            ("]", false),  // Closing bracket without opening
            ("[abc", false),  // Unclosed character class
            ("(abc", false),  // Unclosed group
            ("абв", false),  // Non-ASCII characters are not allowed
            ("a**", false),  // Double quantifier not supported by our logic
            ("(()", false),  // Unbalanced parentheses
            ("[[]", false),  // Unbalanced parentheses
            ("|+", false),  // Special character is not quantifiable
            ("[*", false),  // Special character is not quantifiable
            ("^*", false),  // Special character is not quantifiable
            ("a++", false),  // Another double quantifier scenario
            ("a+*", false),  // Another double quantifier scenario
            ("a*+", false),  // Another double quantifier scenario
            ("a*?", false),  // Another double quantifier scenario
            ("a?*", false),  // Another double quantifier scenario
            ("\\d", false),  // Unsupported escape character
            ("\\w", false),  // Unsupported escape
            ("a|b", false),  // '|' is not listed as supported
            ("a{3}", false),  // Curly braces quantifier not listed as supported
            ("a{3}", false),  // Curly braces quantifier not listed as supported
            ("^(?!abc)", false),  // Negative lookahead
            ("(?:com)", false),  // Negative lookahead
            ("(?i)abc", false),  // Inline modifiers not allowed
            ("abc|def", false),  // Alternation not allowed
            ("abc^def", false),  // Unescaped '^' in the middle of a pattern is not allowed
            ("abc$def", false),  // Unescaped '$' in the middle of a pattern is not allowed
            (".*?", false),  // .* followed by ?, in our logic not allowed

            // Unescaped '\' is not allowed even inside character range
            ("[$^{}()|*+?.\\]", false),
        ]

        for (pattern, expected) in testPatterns {
            let result = SafariRegex.isSupported(pattern: pattern)

            switch result {
            case .success:
                if !expected {
                    XCTAssertTrue(false, "Pattern: \(pattern) expected to not be supported but was")
                }

            case .failure(let error):
                if expected {
                    XCTAssertTrue(
                        false,
                        "Pattern: \(pattern) expected to be supported but got \(error)"
                    )
                }
            }
        }
    }
}
