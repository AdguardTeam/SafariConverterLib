import Foundation
import ContentBlockerConverter
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

/// Converter tool
///
/// ## Usage
///
/// ```
/// cat rules.txt | ./ConverterTool --safari-version 14 --advanced-blocking true
/// ```
struct ConverterTool: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "ConverterTool")

    @Option(name: .shortAndLong, help: "Safari version.")
    var safariVersion: Double = 13

    @Option(name: .shortAndLong, help: "Advanced blocking.")
    var advancedBlocking = false

    @Option(name: .shortAndLong, help: "Maximum json size in bytes. Leave empty for no limit.")
    var maxJsonSizeBytes: Int = 0

    @Argument(help: "Reads rules from standard input.")
    var rules: String?

    mutating func run() throws {
        let safariVersionResolved = SafariVersion(safariVersion);

        let maxJsonSizeBytesOption: Int? = (maxJsonSizeBytes <= 0) ? nil : maxJsonSizeBytes

        Logger.log("(ConverterTool) - Safari version: \(safariVersionResolved)")
        Logger.log("(ConverterTool) - Advanced blocking: \(advancedBlocking)")

        if let size = maxJsonSizeBytesOption {
            Logger.log("(ConverterTool) - Max json limit: \(size)")
        } else {
            Logger.log("(ConverterTool) - Max json limit: No limit set")
        }

        var rules: [String] = []
        var line: String?
        while true {
            line = readLine(strippingNewline: true)
            guard let unwrappedLine = line, !unwrappedLine.isEmpty else {
                break
            }

            rules.append(unwrappedLine)
        }

        Logger.log("(ConverterTool) - Rules to convert: \(rules.count)")

        let result: ConversionResult = ContentBlockerConverter()
            .convertArray(
                rules: rules,
                safariVersion: safariVersionResolved,
                advancedBlocking: advancedBlocking,
                maxJsonSizeBytes: maxJsonSizeBytesOption
            )

        Logger.log("(ConverterTool) - Conversion done.")

        let encoded = try encodeJson(result)

        writeToStdOut(str: "\(encoded)")
    }
}

ConverterTool.main()
