import Foundation

/// Represents a request for filtering rules.
public struct Request {
    /// The URL to find rules for.
    public let url: URL

    /// Whether the request is for a subdocument.
    public let subdocument: Bool

    /// Whether the request is third-party.
    public let thirdParty: Bool

    /// Initializes a new request.
    ///
    /// - Parameters:
    ///   - url: The URL to find rules for.
    ///   - subdocument: Whether the request is for a subdocument. Default is false.
    ///   - thirdParty: Whether the request is third-party. Default is false.
    public init(url: URL, subdocument: Bool = false, thirdParty: Bool = false) {
        self.url = url
        self.subdocument = subdocument
        self.thirdParty = thirdParty
    }
}
