import Foundation
import ContentBlockerConverter
import Shared
import ArgumentParser

func writeToStdError(str: String) {
    let handle = FileHandle.standardError

    if let data = str.data(using: String.Encoding.utf8, allowLossyConversion: false) {
        handle.write(data)
    }
}

func writeToStdOut(str: String) {
    let handle = FileHandle.standardOutput

    if let data = str.data(using: String.Encoding.utf8, allowLossyConversion: false) {
        handle.write(data)
    }
}

func encodeJson(_ result: ConversionResult) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted

    let json = try encoder.encode(result)
    return String(data: json, encoding: .utf8)!.replacingOccurrences(of: "\\/", with: "/")
}

/**
 * Converter tool
 * Usage:
 *  "cat rules.txt | ./ConverterTool -safariVersion=14 -optimize=true -advancedBlocking=false"
 */
struct ConverterTool: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "ConverterTool")

    @Option(name: .shortAndLong, help: "Safari version.")
    var safariVersion: Int = 13

    @Option(name: .shortAndLong, help: "Optimize.")
    var optimize = false

    @Option(name: .shortAndLong, help: "Advanced blocking.")
    var advancedBlocking = false

    @Argument(help: "Reads rules from standard input.")
    var rules: String?

    mutating func run() throws {
        guard let safariVersionResolved = SafariVersion(rawValue: safariVersion) else {
            throw SafariVersionError.unsupportedSafariVersion(version: safariVersion)
        }

        Logger.log("Safari version - \(safariVersionResolved)")
        Logger.log("Optimize - \(optimize)")
        Logger.log("Advanced blocking - \(advancedBlocking)")

        var rules: [String] = []
        var line: String?
        while true {
            line = readLine(strippingNewline: true)
            guard let unwrappedLine = line, !unwrappedLine.isEmpty else {
                break
            }

            rules.append(unwrappedLine)
        }

        Logger.log("Rules to convert: \(rules.count)")

        let result: ConversionResult? = ContentBlockerConverter()
            .convertArray(
                rules: rules,
                safariVersion: safariVersionResolved,
                optimize: optimize,
                advancedBlocking: advancedBlocking
            )

        Logger.log("Conversion done.")

        guard let unwrappedResult = result else {
            writeToStdError(str: "ContentBlockerConverter: Empty result.")
            Foundation.exit(EXIT_FAILURE)
        }

        let encoded = try encodeJson(unwrappedResult)

        writeToStdOut(str: "\(encoded)")
    }
}

ConverterTool.main()
