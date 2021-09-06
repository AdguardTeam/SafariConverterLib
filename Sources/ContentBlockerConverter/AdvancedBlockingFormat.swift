import Foundation

public enum AdvancedBlockingFormat: String {
    case json
    case txt
}

public enum AdvancedBlockingFormatError: Error {
    case unsupportedFormat(message: String = "Provided format is not supported")
}
