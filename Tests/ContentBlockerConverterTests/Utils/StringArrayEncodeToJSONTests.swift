import XCTest

class StringArrayEncodeToJSONTests: XCTestCase {
    func testEncodeToJSONWithoutEscape() {
        // Arrange
        let strings = ["Hello", "World", "Simple Test"]

        // Act
        let result = strings.encodeToJSON(escape: false)

        // Assert
        XCTAssertEqual(result, "[\"Hello\",\"World\",\"Simple Test\"]")
    }

    func testEncodeToJSONWithEscape() {
        // Arrange
        let strings = ["Hello\nWorld", "Quote\"Test", "Backslash\\"]

        // Act
        let result = strings.encodeToJSON(escape: true)

        // Assert
        XCTAssertEqual(result, "[\"Hello\\nWorld\",\"Quote\\\"Test\",\"Backslash\\\\\"]")
    }

    func testEncodeToJSONWithEmptyArray() {
        // Arrange
        let strings: [String] = []

        // Act
        let result = strings.encodeToJSON(escape: true)

        // Assert
        XCTAssertEqual(result, "[]")
    }

    func testEncodeToJSONWithSpecialCharacters() {
        // Arrange
        let strings = ["Line\nBreak", "Tab\tCharacter", "Carriage\rReturn"]

        // Act
        let result = strings.encodeToJSON(escape: true)

        // Assert
        XCTAssertEqual(result, "[\"Line\\nBreak\",\"Tab\\tCharacter\",\"Carriage\\rReturn\"]")
    }

    func testEncodeToJSONWithUnicodeCharacters() {
        // Arrange
        let strings = ["Emoji 😊", "漢字", "Special © Character"]

        // Act
        let result = strings.encodeToJSON(escape: false)

        // Assert
        XCTAssertEqual(result, "[\"Emoji 😊\",\"漢字\",\"Special © Character\"]")
    }
}
