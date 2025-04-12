import ArgumentParser
import ContentBlockerConverter
import FilterEngine
import Foundation

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
    guard let jsonString = String(data: json, encoding: .utf8) else {
        throw NSError(
            domain: "EncodingError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON to string"]
        )
    }
    return jsonString.replacingOccurrences(of: "\\/", with: "/")
}

/// Reads rules from either a file path or stdin
/// - Parameter inputPath: Optional path to a file containing rules
/// - Returns: Array of rule strings
func readRules(from inputPath: String? = nil) throws -> [String] {
    var rules: [String] = []

    if let inputPath = inputPath {
        // Read from file
        do {
            let content = try String(contentsOfFile: inputPath, encoding: .utf8)
            rules = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            Logger.log("Read \(rules.count) rules from file: \(inputPath)")
        } catch {
            throw NSError(
                domain: "FileReadError",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to read from file: "
                        + "\(error.localizedDescription)"
                ]
            )
        }
    } else {
        // Read from stdin
        while let line = readLine(strippingNewline: true), !line.isEmpty {
            rules.append(line)
        }
        Logger.log("Read \(rules.count) rules from stdin")
    }

    return rules
}

/// Root command with two subcommands: convert and buildengine.
struct ConverterTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ConverterTool",
        abstract: "Tool for converting rules to JSON or building the FilterEngine binary.",
        subcommands: [Convert.self, BuildEngine.self],
        defaultSubcommand: Convert.self
    )
}

/// Subcommand for converting rules to JSON.
///
/// ### Usage
///
/// ```
/// cat rules.txt | ./ConverterTool convert --safari-version 14 --advanced-blocking true
/// ```
///
/// Or with input file:
///
/// ```
/// ./ConverterTool convert --input-path rules.txt --safari-version 14 --advanced-blocking true
/// ```
struct Convert: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "convert",
        abstract:
            "Convert AdGuard rules to Safari content blocking JSON and advanced rules for a web extension."
    )

    @Option(name: .shortAndLong, help: "Safari version.")
    var safariVersion: Double = SafariVersion.autodetect().doubleValue

    @Option(name: .shortAndLong, help: "Advanced blocking flag.")
    var advancedBlocking = false

    @Option(name: .shortAndLong, help: "Maximum json size in bytes. Leave empty for no limit.")
    var maxJsonSizeBytes: Int = 0

    @Option(
        name: .long,
        help: "Path to the input file with rules. Leave empty to read from stdin."
    )
    var inputPath: String?

    @Option(
        name: .long,
        help: "Output path to write Safari content blocking JSON file. Leave empty for stdout."
    )
    var safariRulesJSONPath: String?

    @Option(
        name: .long,
        help: "Output path to write advanced blocking rules file. Leave empty for stdout."
    )
    var advancedBlockingRulesPath: String?

    mutating func run() throws {
        let safariVersionResolved = SafariVersion(safariVersion)
        let maxJsonSizeBytesOption: Int? = (maxJsonSizeBytes <= 0) ? nil : maxJsonSizeBytes

        Logger.log("(Convert) - Safari version: \(safariVersionResolved)")
        Logger.log("(Convert) - Advanced blocking: \(advancedBlocking)")
        if let size = maxJsonSizeBytesOption {
            Logger.log("(Convert) - Max json limit: \(size)")
        } else {
            Logger.log("(Convert) - Max json limit: No limit set")
        }

        if let inputPath = inputPath {
            Logger.log("(Convert) - Input file: \(inputPath)")
        } else {
            Logger.log("(Convert) - Reading from stdin")
        }

        let rules = try readRules(from: inputPath)
        Logger.log("(Convert) - Rules to convert: \(rules.count)")

        let result: ConversionResult = ContentBlockerConverter()
            .convertArray(
                rules: rules,
                safariVersion: safariVersionResolved,
                advancedBlocking: advancedBlocking,
                maxJsonSizeBytes: maxJsonSizeBytesOption
            )

        Logger.log("(Convert) - Conversion done.")

        if safariRulesJSONPath == nil && advancedBlockingRulesPath == nil {
            let encoded = try encodeJson(result)
            writeToStdOut(str: encoded)
        }

        if let safariRulesJSONPath = safariRulesJSONPath {
            let content = result.safariRulesJSON
            try content.write(toFile: safariRulesJSONPath, atomically: true, encoding: .utf8)
        }

        if let advancedBlockingRulesPath = advancedBlockingRulesPath {
            let content = result.advancedRulesText ?? ""
            try content.write(toFile: advancedBlockingRulesPath, atomically: true, encoding: .utf8)
        }
    }
}

/// Subcommand for building the FilterEngine in the binary form.
///
/// ## Usage:
///
/// ```
/// cat advanced-rules.txt | ./ConverterTool buildengine --safari-version 14 --output-dir <path-to-dir>
/// ```
///
/// Or with input file:
///
/// ```
/// ./ConverterTool buildengine --input-path advanced-rules.txt --safari-version 14 --output-dir <path-to-dir>
/// ```
struct BuildEngine: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "buildengine",
        abstract: "Build the FilterEngine binary."
    )

    @Option(name: .shortAndLong, help: "Safari version.")
    var safariVersion: Double = 13

    @Option(
        name: .long,
        help: "Path to the input file with rules. Leave empty to read from stdin."
    )
    var inputPath: String?

    @Option(name: .shortAndLong, help: "Output directory for the FilterEngine binary.")
    var outputDir: String

    mutating func run() throws {
        let safariVersionResolved = SafariVersion(safariVersion)
        Logger.log("(BuildEngine) - Safari version: \(safariVersionResolved)")
        Logger.log("(BuildEngine) - Output directory: \(outputDir)")

        if let inputPath = inputPath {
            Logger.log("(BuildEngine) - Input file: \(inputPath)")
        } else {
            Logger.log("(BuildEngine) - Reading from stdin")
        }

        let rules = try readRules(from: inputPath)
        Logger.log("(BuildEngine) - Advanced rules count: \(rules.count)")

        // Build the FilterEngine binary using the provided rules and safari version.
        // Remove any previous settings from sharedUserDefaults.
        guard let sharedUserDefaults = EmptyDefaults(suiteName: #file) else {
            throw NSError(
                domain: "UserDefaultsError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create UserDefaults"]
            )
        }
        defer { sharedUserDefaults.removePersistentDomain(forName: #file) }

        // Create a URL from the output directory string.
        let containerURL = URL(fileURLWithPath: outputDir)

        // Pass the URL to the WebExtension constructor.
        let webExtension = try WebExtension(
            containerURL: containerURL,
            sharedUserDefaults: sharedUserDefaults,
            version: safariVersionResolved
        )

        // Build the engine.
        _ = try webExtension.buildFilterEngine(rules: rules.joined(separator: "\n"))

        Logger.log("(BuildEngine) - FilterEngine files written to \(outputDir)")
    }
}

/// EmptyDefaults is a UserDefaults instance that does not save or read anything.
/// It is required to avoid creating unnecessary files.
class EmptyDefaults: UserDefaults {
    override func double(forKey defaultName: String) -> Double {
        0
    }

    override func integer(forKey defaultName: String) -> Int {
        0
    }

    override func set(_ value: Double, forKey defaultName: String) {
    }

    override func set(_ value: Int, forKey defaultName: String) {
    }
}

ConverterTool.main()
