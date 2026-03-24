# Safari Converter Lib

This is a library that provides a compatibility layer between
[AdGuard filtering rules][adguardrules] and
[Safari content blocking rules][safarirules].

[adguardrules]: https://adguard.com/kb/general/ad-filtering/create-own-filters/
[safarirules]: https://developer.apple.com/documentation/safariservices/creating-a-content-blocker

## Technical Context

- **Language**: Swift (swift-tools-version 5.6+, requires Swift 6 to build)
- **Extension language**: TypeScript (bundled with Rollup)
- **Primary dependencies**:
    - [PunycodeSwift][punycode] — IDN domain encoding
    - [swift-argument-parser][argumentparser] — CLI interface
    - [swift-psl][swift-psl] — public suffix list lookups
- **Testing**: XCTest (Swift), Vitest (JS/TS)
- **Linting**: [SwiftLint][swiftlint], [swift-format][swift-format],
  [periphery][periphery], [markdownlint-cli][markdownlint], ESLint (JS)
- **Target platform**: macOS / iOS (Safari Content Blocker +
  Safari Web Extension)
- **Project type**: Swift Package (library + CLI tool + JS extension)

[punycode]: https://github.com/gumob/PunycodeSwift
[argumentparser]: https://github.com/apple/swift-argument-parser
[swift-psl]: https://github.com/ameshkov/swift-psl

## General Code Style & Formatting

1. Use standard Swift formatting and style guidelines.
2. Use 4 spaces for indentation.
3. When writing class and function comments, prefer `///` style comments. In
   this case, you should use proper markdown formatting.
4. When writing inline comments, prefer `//` style comments.
5. In the case of comments, try to keep line length under 80 characters. In the
   case of code, it should be under 100.
6. Avoid comments on the same line as the code; place them on a previous line.

## Contribution Instructions

You MUST follow the following rules for EVERY task that you perform:

- You MUST verify the code with linter, formatter, compiler: `make lint`
    and fix all the issues that are found.

- You MUST run tests: `make test` and make sure that all tests pass.

- After adding new functionality or changing existing one, you MUST update the documentation, add Unit-tests for new code and verify/update existing tests.

## Build Instructions

### Prerequisites

- Swift 6 or newer.
- Install [Node.js][nodejs]: recommend to use [nvm][nvm] for that.
- Install [pnpm][pnpm]: `brew install pnpm`.
- Install [SwiftLint][swiftlint]: `brew install swiftlint`.
- Install [xcbeautify][xcbeautify]: `brew install xcbeautify`.
- Install [periphery][periphery]: `brew install periphery`.
- Install [markdownlint-cli][markdownlint]: `npm install -g markdownlint-cli`.
- Install [jq][jq]: `brew install jq`.

[nodejs]: https://nodejs.org/
[nvm]: https://github.com/nvm-sh/nvm
[pnpm]: https://pnpm.io/
[swiftlint]: https://github.com/realm/SwiftLint
[xcbeautify]: https://github.com/cpisciotta/xcbeautify
[periphery]: https://github.com/peripheryapp/periphery
[markdownlint]: https://www.npmjs.com/package/markdownlint-cli
[jq]: https://jqlang.org/
[swift-format]: https://github.com/swiftlang/swift-format

### Building

Run `make init` to setup pre-commit hooks.

- `make build` — builds JS and Swift code (debug).
    - `make swift-build` — builds the Swift package.
    - `make js-build` — builds the extension library code.
- `make release` — builds JS and Swift (release).

### Linting

- `make lint` — runs **all** linters.
    - `make md-lint` — runs markdown linter.
    - `make swift-lint` — runs swift linters ([SwiftLint][swiftlint],
      [swift-format][swift-format], and [periphery][periphery]).
    - `make js-lint` — lints JS extension code.

### Testing

- `make test` — runs **all** tests.
    - `make swift-test` — runs Swift tests.
    - `make js-test` — runs JS tests.
    - `make filelock-test` — runs file lock test suite.
    - `make command-line-wrapper-test` — runs command-line wrapper test suite.

### Performance Tests

All benchmark tests use `XCTest.measure` unless noted otherwise.
Each test's doc comment contains historical wall-clock baselines per
machine — update them after profiling on your hardware.

#### ContentBlockerConverter

File:
`Tests/ContentBlockerConverterTests/ContentBlockerConverterPerformanceTests.swift`

- **`testPerformanceSingleRun`** — a single invocation of
  `ContentBlockerConverter.convertArray` on the bundled
  `test-rules.txt` (~32 660 rules). It is intended for CPU profiling
  with Instruments (**not** wrapped in `measure`). The test comments
  contain historical CPU-cycle baselines per machine — update them
  after profiling on your hardware.
- **`testPerformance`** — the same workload wrapped in `measure` to
  track wall-clock regression.
- **`testSpecifichidePerformance`** — measures `$specifichide`
  processing cost (1 000 rule pairs).

#### FilterEngine Serialization

File: `Tests/FilterEngineTests/FilterEngineSerializationTests.swift`

- **`testPerformanceSerialization`** — builds `FilterRuleStorage` +
  `FilterEngine` from `advanced-rules.txt` and serializes to a file.
- **`testPerformanceDeserialization`** — deserializes
  `FilterRuleStorage` + `FilterEngine` from a previously written
  file.

#### ByteArrayTrie

File: `Tests/FilterEngineTests/Utils/ByteArrayTrieTests.swift`

- **`testPerformanceBuildTrie`** — inserts 10 000 random words into
  a `TrieNode` and builds a `ByteArrayTrie` from it.
- **`testPerformanceFind`** — performs `find` lookups on 10 000
  words in a pre-built `ByteArrayTrie`.
- **`testPerformanceCollectPayload`** — performs `collectPayload`
  lookups on 10 000 words in a pre-built `ByteArrayTrie`.

#### TrieNode

File: `Tests/FilterEngineTests/Utils/TrieNodeTests.swift`

- **`testPerformanceBuildTrie`** — inserts 10 000 random words into
  a `TrieNode`.
- **`testPerformanceFind`** — performs `find` lookups on 10 000
  words in a pre-built `TrieNode`.
- **`testPerformanceCollectPayload`** — performs `collectPayload`
  lookups on 10 000 words in a pre-built `TrieNode`.

When you change core conversion logic, run all performance tests
and compare the results against the baselines recorded in each
test's doc comment. Add a new dated baseline entry to the
corresponding test if the numbers shift noticeably.

## Project Structure

```text
├── Sources/
│   ├── ContentBlockerConverter/  # Core converter library
│   │   ├── Compiler/             # Compiles parsed rules → Safari JSON
│   │   ├── Rules/                # Rule parsing (NetworkRule, CosmeticRule, …)
│   │   └── Utils/                # Shared helpers (Chars, Logger, …)
│   ├── CommandLineWrapper/       # CLI tool (ConverterTool)
│   ├── FilterEngine/             # Advanced-rules engine (build/serialize/lookup)
│   └── FileLockTester/           # Helper app for distributed lock tests
├── Extension/                    # JS/TS extension library (advanced rules)
│   ├── src/                      # TypeScript source
│   └── test/                     # Vitest tests
├── Tests/
│   ├── ContentBlockerConverterTests/  # XCTest tests for the converter
│   └── FilterEngineTests/             # XCTest tests for the engine
├── scripts/                      # Build, test, and CI helper scripts
├── bamboo-specs/                 # CI pipeline definitions
├── Package.swift                 # Swift Package Manager manifest
├── Makefile                      # Build/test/lint commands
└── AGENTS.md                     # This file
```

## Code Organization

### ContentBlockerConverter

The public API is provided by the `ContentBlockerConverter` class and its
public `convertArray` function.

Internally, it parses string lines using `ContentBlockerConverter/Rules/*`
classes and discards the lines that cannot be parsed.

After that the rules are transformed into Safari content blocking rules by
`Compiler`.

- `/Sources/ContentBlockerConverter` — converter library code. It is
  responsible for converting [AdGuard rules][adguardrules] to Safari
  content blocking rules and advanced blocking rules. "Advanced rules"
  are AdGuard rules that cannot be directly converted to Safari syntax
  and should be interpreted using JS by a browser extension.

### CommandLineWrapper

- `/Sources/CommandLineWrapper` — command-line interface code. It is
  responsible for providing a command-line interface to the converter
  library.

### FilterEngine

The public API is provided by two classes:

- `WebExtension` — the class that is supposed to be used by web
  extensions. It covers all the important use cases:

    - Building and serializing the filtering engine (see
      `buildFilterEngine`) to a location shared between the main app
      process and the extension's process.
    - Looking up for the set of filtering rules that should be applied
      to the specified page (see `lookup`). This method also implicitly
      deserializes the filtering engine.

- `FilterEngine` — provides the low-level API for building, serializing
  and deserializing the filtering engine, a class that interprets AdGuard
  rules and is capable of performing all the operations very quickly.

### Extension

Please refer to [Extension/README.md][extension] for details on how code
is organized there.

### FileLockTester

- `/Sources/FileLockTester` — file lock tester code. It is responsible
  for testing file lock functionality. The library uses `FileLock` class
  for distributed locking functionality. Unfortunately, to test it we
  have to create a separate helper app.

[extension]: ./Extension/README.md
