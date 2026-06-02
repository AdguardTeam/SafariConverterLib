# Safari Converter Lib

## Table of Contents

- [Project Overview](#project-overview)
- [Technical Context](#technical-context)
- [Project Structure](#project-structure)
- [Build And Test Commands](#build-and-test-commands)
- [Contribution Instructions](#contribution-instructions)
- [Code Guidelines](#code-guidelines)
    - [System Design](#system-design)
    - [Architecture](#architecture)
    - [Code Quality](#code-quality)
    - [Testing](#testing)
    - [Dependency Management](#dependency-management)
    - [Configuration & Documentation](#configuration--documentation)
    - [Markdown Formatting](#markdown-formatting)

## Project Overview

This library provides a compatibility layer between [AdGuard filtering rules][adguardrules] and [Safari content blocking rules][safarirules]. It converts AdGuard ad-blocking rules into the format that Safari understands, handling both basic network rules and advanced rules that require interpretation by a Safari Web Extension or App Extension.

The library is consumed by iOS and macOS applications (adguard-ios, adguard-mini) to power Safari content blockers.

[adguardrules]: https://adguard.com/kb/general/ad-filtering/create-own-filters/
[safarirules]: https://developer.apple.com/documentation/safariservices/creating-a-content-blocker

## Technical Context

- **Language**: Swift (swift-tools-version 5.6+, requires Swift 6 to build)
- **Extension language**: TypeScript (bundled with Rollup)
- **Primary dependencies**:
    - [PunycodeSwift][punycode] 3.0.0 — IDN domain encoding
    - [swift-argument-parser][argumentparser] 1.5.0 — CLI interface
    - [swift-psl][swift-psl] ^1.1.0 — public suffix list lookups
- **Storage**: File system for serialized FilterEngine binary data
- **Testing**: XCTest (Swift), Vitest (JS/TS)
- **Linting**: [SwiftLint][swiftlint], [swift-format][swift-format],
  [periphery][periphery], [markdownlint-cli][markdownlint], ESLint (JS)
- **Target platform**: macOS / iOS (Safari Content Blocker +
  Safari Web Extension)
- **Project type**: Library/Package (Swift Package with CLI tool + JS extension)
- **Performance goals**: Fast rule parsing using UTF8View, sub-100ms grouping for 10k rules

[punycode]: https://github.com/gumob/PunycodeSwift
[argumentparser]: https://github.com/apple/swift-argument-parser
[swift-psl]: https://github.com/ameshkov/swift-psl
[swiftlint]: https://github.com/realm/SwiftLint
[swift-format]: https://github.com/swiftlang/swift-format
[periphery]: https://github.com/peripheryapp/periphery
[markdownlint]: https://www.npmjs.com/package/markdownlint-cli

## Project Structure

```text
├── Sources/
│   ├── ContentBlockerConverter/     # Core converter library
│   │   ├── Compiler/                # Compiles parsed rules → Safari JSON
│   │   ├── Rules/                   # Rule parsing (NetworkRule, CosmeticRule)
│   │   ├── Utils/                   # Shared helpers (Chars, Logger)
│   │   ├── Affinity.swift           # Affinity OptionSet for routing rules
│   │   ├── AffinityRulesGrouper.swift # Groups rules by affinity directives
│   │   ├── ContentBlockerType.swift # Safari content blocker type enum
│   │   ├── ContentBlockerConverter.swift # Main converter API
│   │   └── ConversionResult.swift   # Conversion output structure
│   ├── CommandLineWrapper/          # CLI tool (ConverterTool)
│   ├── FilterEngine/                # Advanced-rules engine (build/serialize/lookup)
│   │   └── Utils/                   # Engine-specific utilities
│   └── FileLockTester/              # Helper app for distributed lock tests
├── Extension/                       # JS/TS extension library (advanced rules)
│   ├── src/                         # TypeScript source
│   └── test/                        # Vitest tests
├── Tests/
│   ├── ContentBlockerConverterTests/    # XCTest tests for the converter
│   │   ├── AffinityRulesGrouperTests.swift # Tests for affinity grouping
│   │   ├── Compiler/                  # Compiler tests
│   │   ├── Rules/                     # Rule parsing tests
│   │   ├── Utils/                     # Utility tests
│   │   └── Resources/                 # Test data files
│   ├── FilterEngineTests/             # XCTest tests for the engine
│   │   ├── Utils/                     # Engine utility tests
│   │   └── Resources/                 # Engine test data
│   └── WebKitCompilationTests/        # macOS-only WebKit compilation tests
├── scripts/                         # Build, test, and CI helper scripts
│   ├── hooks/                       # Git hooks (pre-commit)
│   ├── make/                        # Build codegen scripts
│   ├── perf/                        # Performance profiling scripts
│   └── tests/                       # Integration test scripts
├── bamboo-specs/                    # CI pipeline definitions
├── Package.swift                    # Swift Package Manager manifest
├── Makefile                         # Build/test/lint commands
├── README.md                        # User-facing documentation
├── DEVELOPMENT.md                   # Developer setup guide
└── AGENTS.md                        # This file
```

## Code Organization

### ContentBlockerConverter

The public API is provided by the `ContentBlockerConverter` class and its
public `convertArray` function.

Internally, it parses string lines using `ContentBlockerConverter/Rules/*`
classes and discards the lines that cannot be parsed.

After that the rules are transformed into Safari content blocking rules by
`Compiler`.

The module also provides `AffinityRulesGrouper` — a utility for grouping
rules across Safari content blocker types based on
`!#safari_cb_affinity(...)` directives. See the public API:

- `AffinityRulesGrouper.group(rules:)` — groups rules by affinity
- `AffinityRulesGrouper.rule(_:withAffinity:)` — wraps a rule with
  affinity directives
- `ContentBlockerType` — enum of 6 Safari content blocker slots
- `Affinity` — OptionSet bitmask of affinity values

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

## Contribution Instructions

You MUST follow the following rules for EVERY task that you perform:

- You MUST verify the code with linter, formatter, compiler: `make lint`
    and fix all the issues that are found.

- You MUST run tests: `make test` and make sure that all tests pass.

- After adding new functionality or changing existing one, you MUST
    add unit tests for new code and verify/update existing tests.

- When changing user-facing behavior (e.g. supported rule types,
    conversion options, CLI flags), you MUST update `README.md`.

- When changing the directory structure, adding/removing modules, or
    altering public APIs, you MUST update `AGENTS.md`.

- When the task is finished ask the user if you should update `CHANGELOG.md`.
  If you do, explain changes in the Unreleased section. Add entries to the appropriate subsection (Added, Changed, or Fixed) if it already exists; do not create duplicate subsections.

- You MUST verify that new code follows the Code Guidelines section below
  before completing a task.

## Code Guidelines

### System Design

This is a **library/package** consumed by iOS and macOS applications. Follow
these principles:

- **Public API stability**: The library exposes `ContentBlockerConverter`,
  `FilterEngine`, `WebExtension`, and utility types like
  `AffinityRulesGrouper`. Maintain backward compatibility for public APIs.
- **Performance first**: Use `UTF8View` for string parsing, avoid unnecessary
  allocations, and optimize for fast rule processing.
- **Platform awareness**: The library targets both macOS and iOS. Ensure code
  works on both platforms and respects Safari's constraints (e.g., 6 content
  blocker slots, rule limits).
- **Minimal dependencies**: Keep external dependencies to a minimum. Prefer
  Swift standard library when possible.
- **Clear error handling**: Use Swift's error types and Result patterns.
  Provide meaningful error messages for debugging.

### Architecture

Follow these universal design principles:

- **Separation of Concerns** — each module handles one aspect (parsing,
  compilation, grouping, filtering)
- **Single Responsibility Principle** — every file, class, or function has
  one reason to change
- **Dependency Direction** — dependencies point downward: CommandLineWrapper
  → FilterEngine → ContentBlockerConverter. Never reverse.
- **Explicit Boundaries** — module interfaces are intentional; no reaching
  into internals
- **Data Flow Clarity** — data moves through the system in a predictable,
  traceable path (parse → compile → output)
- **Minimize Coupling, Maximize Cohesion** — modules are self-contained and
  interact through narrow interfaces
- **Make Invalid States Impossible** — use types and validation to prevent
  illegal combinations at compile time
- **Observability Built-in** — logging, metrics, and error reporting are
  first-class, not afterthoughts
- **Keep It Boring** — prefer well-understood patterns over clever or novel
  solutions

**Layered Architecture:**

| Layer | Responsibility | Examples |
| ----- | -------------- | -------- |
| CLI | Command-line interface, user input/output | `Sources/CommandLineWrapper/` |
| Engine | Advanced rule filtering, serialization | `Sources/FilterEngine/` |
| Converter | Rule parsing, affinity grouping, compilation | `Sources/ContentBlockerConverter/` |
| Utilities | Shared helpers, logging, string processing | `Sources/ContentBlockerConverter/Utils/` |

**Dependency Flow:**

```text
CommandLineWrapper
        ↓
  FilterEngine
        ↓
ContentBlockerConverter
        ↓
     Utils
```

No architecture violations detected.

### Code Quality

- **Documentation**: Use `///` style comments for all public APIs. Use
  proper markdown formatting in doc comments. Use `//` for inline comments.
- **Line length**: Keep comments under 80 characters, code under 100
  characters.
- **Indentation**: Use 4 spaces for indentation.
- **Comment placement**: Avoid comments on the same line as code; place
  them on a previous line.
- **Linting**: All code must pass SwiftLint, swift-format, and periphery.
  Run `make swift-lint` to verify.
- **Error handling**: Use Swift's `throws` and `Result` types. Avoid force
  unwrapping except in tests.
- **Naming**: Follow Swift naming conventions (camelCase for functions and
  variables, PascalCase for types).
- **Imports**: Only import what is needed. Periphery detects unused imports.

### Testing

- **Test placement**: Tests live in `Tests/` with target names matching
  the source target plus `Tests` suffix (e.g., `ContentBlockerConverterTests`).
- **Test naming**: Test files follow `<ClassName>Tests.swift` pattern.
  Test methods follow `test<MethodName>` pattern.
- **Coverage**: Add unit tests for all new functionality. Update existing
  tests when behavior changes.
- **Test data**: Store test fixtures in `Tests/<TargetTests>/Resources/`.
- **Verification**: Run `make test` to execute all tests (Swift, JS,
  integration). All tests must pass before completing a task.
- **Performance tests**: Use `XCTest.measure` for benchmarks. Run
  `make test-performance` after changes that affect runtime behavior.
- **WebKit tests**: macOS-only tests verify Safari content blocker
  compilation. Run with `make webkit-test`.

### Dependency Management

- **Pin all dependency versions explicitly** — do not use version ranges
  that allow automatic upgrades to untested versions. The `Package.swift`
  uses `exact:` for PunycodeSwift and swift-argument-parser.
- **Prefer vanilla solutions** — use Swift standard library and built-in
  APIs when they adequately solve the problem.
- **Reputable sources only** — dependencies MUST come from well-established,
  actively maintained projects (check repository activity and maintainers).
- **Minimize dependency count** — each new dependency increases attack
  surface and maintenance burden. Justify every addition.
- **Use the latest stable version** — when adding a new dependency, check
  the package registry for the latest stable release.

**Known exclusions:**

- `swift-psl` uses a version range (`"1.1.0"..<"2.0.0"`) instead of exact
  pinning. This should be fixed by pinning to a specific version.

### Configuration & Documentation

- **Runtime configuration**: The library is configured programmatically via
  API parameters (e.g., `safariVersion`, `advancedBlocking`, `maxJsonSizeBytes`).
  No environment variables or config files.
- **CLI configuration**: ConverterTool accepts command-line flags and
  arguments. See `ConverterTool help <subcommand>`.
- **Documentation updates**: When changing user-facing behavior, update
  `README.md`. When changing project structure or public APIs, update
  `AGENTS.md`.
- **Version tracking**: The library version is generated via codegen. Run
  `make codegen VERSION=X.Y.Z` to update `ContentBlockerConverterVersion.swift`.
- **Changelog**: Update `CHANGELOG.md` for all user-visible changes in the
  Unreleased section.

### Markdown Formatting

Uniform Markdown formatting is important because AI agents consume project
documentation as context — inconsistent formatting wastes tokens and can
confuse tools that parse Markdown.

Follow these rules (configured in `.markdownlint.json`):

- **List style**: Use dash (`-`) for unordered lists. Indent list items by
  4 spaces.
- **Emphasis**: Use asterisks (`*text*` for italic, `**text**` for bold).
- **Headings**: No duplicate headings at the same level (siblings only).
- **HTML**: Only allow `<a>`, `<details>`, `<summary>`, `<img>` inline HTML.
- **Links**: Bare URLs are allowed. Link fragments are not validated.
- **Line length**: No line length limit enforced by markdownlint.
- **Trailing spaces**: Not allowed (0 spaces before line break).

## Build And Test Commands

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
    - `make webkit-test` — runs WebKit compilation tests (macOS only).

### Performance Tests

All benchmark tests use `XCTest.measure` unless noted otherwise.

Running performance tests: `make test-performance`. Follow the
instructions in `scripts/perf/README.md` for the full procedure.

You MUST run performance tests after any changes to files under
`Sources/` that could affect runtime behavior.

When adding or changing performance tests, you MUST update the
test list in `scripts/perf/README.md` accordingly.
