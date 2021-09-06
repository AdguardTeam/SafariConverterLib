import Foundation

// Wrapper result class
final class BlockerData {
    var scripts: [String] = []
    var cssExtended: [String] = []
    var cssInject: [String] = []
    var scriptlets: [String] = []

    func addScript(script: String?) {
        guard let script = script, !script.isEmpty else {
            return
        }
        scripts.append(script)
    }

    func addCssExtended(style: String?) {
        guard let style = style, !style.isEmpty else {
            return
        }
        cssExtended.append(style)
    }

    func addCssInject(style: String?) {
        guard let style = style, !style.isEmpty else {
            return
        }
        cssInject.append(style)
    }

    func addScriptlet(scriptlet: String?) {
        guard let scriptlet = scriptlet, !scriptlet.isEmpty else {
            return
        }
        scriptlets.append(scriptlet)
    }

    func clear() {
        scripts = []
        cssExtended = []
        cssInject = []
        scriptlets = []
    }
}

extension BlockerData: Codable {}
