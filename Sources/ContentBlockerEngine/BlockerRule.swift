import Foundation

// Json decoded object description
struct BlockerRule: Codable {
    let ifDomain: [String]?
    let urlFilter: String?
    let unlessDomain: [String]?
    let shortcut: String?
    let type: String
    let css: String?
    let script: String?
    let scriptlet: String?
    let scriptletParam: String?

    lazy var regex: NSRegularExpression? = {
        if let urlFilter = urlFilter {
            let regex = try? NSRegularExpression(pattern: urlFilter, options: [])
            return regex
        }
        return nil
    }()
}