import XCTest

class ArrayChunkedTests: XCTestCase {
    func testChunkedWithPerfectDivision() {
        // Arrange
        let array = [1, 2, 3, 4, 5, 6]
        let chunkSize = 2

        // Act
        let result = array.chunked(into: chunkSize)

        // Assert
        XCTAssertEqual(result, [[1, 2], [3, 4], [5, 6]])
    }

    func testChunkedWithRemainder() {
        // Arrange
        let array = [1, 2, 3, 4, 5]
        let chunkSize = 2

        // Act
        let result = array.chunked(into: chunkSize)

        // Assert
        XCTAssertEqual(result, [[1, 2], [3, 4], [5]])
    }

    func testChunkedWithSingleElementChunks() {
        // Arrange
        let array = [1, 2, 3, 4]
        let chunkSize = 1

        // Act
        let result = array.chunked(into: chunkSize)

        // Assert
        XCTAssertEqual(result, [[1], [2], [3], [4]])
    }

    func testChunkedWithChunkSizeGreaterThanArray() {
        // Arrange
        let array = [1, 2, 3]
        let chunkSize = 10

        // Act
        let result = array.chunked(into: chunkSize)

        // Assert
        XCTAssertEqual(result, [[1, 2, 3]])
    }

    func testChunkedWithEmptyArray() {
        // Arrange
        let array: [Int] = []
        let chunkSize = 3

        // Act
        let result = array.chunked(into: chunkSize)

        // Assert
        XCTAssertEqual(result, [])
    }

    func testChunkedWithNegativeChunkSize() {
        // Arrange
        let array = [1, 2, 3, 4]
        let chunkSize = -1

        // Act
        let result = array.chunked(into: chunkSize)

        // Assert
        XCTAssertEqual(result, [])  // Assume negative size results in empty chunks
    }

    func testChunkedWithZeroChunkSize() {
        // Arrange
        let array = [1, 2, 3, 4]
        let chunkSize = 0

        // Act
        let result = array.chunked(into: chunkSize)

        // Assert
        XCTAssertEqual(result, [])  // Assume zero size results in empty chunks
    }
}
