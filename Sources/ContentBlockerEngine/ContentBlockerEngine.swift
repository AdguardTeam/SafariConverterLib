import Foundation
import Shared

protocol ContentBlockerEngineProtocol {
    init(_ json: String) throws
    init(_ decoder: Decoder) throws
    func getData(url: URL) throws -> String
}

final public class ContentBlockerEngine: ContentBlockerEngineProtocol {    
    private var contentBlockerContainer: ContentBlockerContainer
    private var blockerDataCache = NSCache<NSString, NSString>()
    private var version = "1"

    enum CodingKeys: String, CodingKey {
        case contentBlockerContainer
        case version
    }

    enum EngineError: Error {
        case schemeError(message: String)
    }

    // Constructor used when initialized with JSON data
    required public init(_ json: String) throws {
        contentBlockerContainer = ContentBlockerContainer()
        try contentBlockerContainer.setJson(json: json)
    }

    // Constructor used when initialized with indexed rules data
    required public init(_ decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try values.decode(String.self, forKey: .version)
        if version != decodedVersion {
            throw EngineError.schemeError(message: "Version expected \(version), but received \(decodedVersion)")
        }

        version = decodedVersion
        contentBlockerContainer = try values.decode(ContentBlockerContainer.self, forKey: .contentBlockerContainer)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // encode scheme version so that we could check it when decoding
        try container.encode(version, forKey: .version)
        try container.encode(contentBlockerContainer, forKey: .contentBlockerContainer)
    }

    // Returns requested scripts and css for specified url
    public func getData(url: URL) throws -> String {
        let cacheKey = url.absoluteString as NSString
        if let cachedVersion = blockerDataCache.object(forKey: cacheKey) {
            Logger.log("AG: AdvancedBlocking: Return cached version")
            return cachedVersion as String
        }

        let data = try getBlockerData(url: url)
        blockerDataCache.setObject(data as NSString, forKey: cacheKey)

        return data
    }

    // Returns blocker data from content blocker container
    private func getBlockerData(url: URL) throws -> String {
        let data: BlockerData = try contentBlockerContainer.getData(url: url)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let json = try encoder.encode(data)
        return String(data: json, encoding: .utf8)!
    }
}

extension ContentBlockerEngine: Codable {}
