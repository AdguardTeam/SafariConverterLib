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

do {
    Logger.log("AG: Conversion started");

    let arguments: [String] = CommandLine.arguments;
    if (arguments.count < 4) {
        writeToStdError(str: "AG: Invalid arguments: Usage: ./CommandLineWrapper -safariVersion=14 -optimize=false -advancedBlocking)");
        exit(EXIT_FAILURE);
    }

    let safariVersionIndex = String.Index(utf16Offset: 15, in: arguments[1]);
    let safariVersionStr = arguments[1][safariVersionIndex...];

    guard let safariVersionNum = Int(safariVersionStr) else {
        throw SafariVersionError.invalidSafariVersion(version: String(safariVersionStr));
    };

    guard let safariVersion = SafariVersion(rawValue: safariVersionNum) else {
        throw SafariVersionError.unsupportedSafariVersion(version: safariVersionNum);
    };

    Logger.log("AG: Safari version: \(safariVersion)");

    let optimize = arguments[2] == "-optimize=true";
    Logger.log("AG: Optimize: \(optimize)");

    let advancedBlocking = arguments[3] == "-advancedBlocking=true";
    Logger.log("AG: AdvancedBlocking: \(advancedBlocking)");

    var rules = [String]();
    var line: String? = nil;
    while (true) {
        line = readLine(strippingNewline: true);
        if (line == nil || line == "") {
            break;
        }

        rules.append(line!);
    }

    Logger.log("AG: Rules to convert: \(rules.count)");

    let result: ConversionResult? = ContentBlockerConverter().convertArray(
        rules: rules, safariVersion: safariVersion, optimize: optimize, advancedBlocking: advancedBlocking
    );
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
        guard let safariVersion = SafariVersion(rawValue: safariVersion) else {
            throw SafariVersionError.unsupportedSafariVersion()
        }

        Logger.log("Safari version - \(safariVersion)")
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
                safariVersion: safariVersion,
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
