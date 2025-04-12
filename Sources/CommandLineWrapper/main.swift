import ArgumentParser
import Foundation

/// Root command with two subcommands:
///
/// - `convert`
/// - `buildengine
struct ConverterTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ConverterTool",
        abstract: "Tool for converting rules to JSON or building the FilterEngine binary.",
        subcommands: [
            ConvertCommand.self,
            BuildEngineCommand.self,
        ],
        defaultSubcommand: ConvertCommand.self
    )
}

ConverterTool.main()
