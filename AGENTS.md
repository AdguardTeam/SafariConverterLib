# Safari Converter Lib

This is a library that provides a compatibility layer between
[AdGuard filtering rules][adguardrules] and
[Safari content blocking rules][safarirules].

[adguardrules]: https://adguard.com/kb/general/ad-filtering/create-own-filters/
[safarirules]: https://developer.apple.com/documentation/safariservices/creating-a-content-blocker

## General Code Style & Formatting

1. Use standard Swift formatting and style guidelines.
2. Use 4 spaces for indentation.
3. When writing class and function comments, prefer `///` style comments. In
   this case, you should use proper markdown formatting.
4. When writing inline comments, prefer `//` style comments.
5. In the case of comments, try to keep line length under 80 characters. In the
   case of code, it should be under 100.
6. Avoid comments on the same line as the code; place them on a previous line.

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

### Building

Run `make init` to setup pre-commit hooks.

- `make lint` - runs all linters.

    You can also run individual linters:

    - `make md-lint` - runs markdown linter.
    - `make swift-lint` - runs swift linters ([SwiftLint][swiftlint],
      [swift-format][swift-format], and [periphery][periphery]).
    - `make js-lint` - lints JS extensions code.

- `make test` - runs all tests.

    You can also run individual test suites:

    - `make swift-test` - runs Swift tests.
    - `make js-test` - runs JS tests.
    - `make filelock-test` - runs file lock test suite.
    - `make command-line-wrapper-test` - runs command-line wrapper test suite.

- `make build` - builds JS and Swift code (debug).

    You can also run individual build commands:

    - `make swift-build` - builds the Swift package.
    - `make js-build` - builds the extension library code.

- `make release` - builds JS and Swift (release).

[swift-format]: https://github.com/swiftlang/swift-format

## Code Organization

The code is organized in the following way:

- `/Sources/ContentBlockerConverter` - converter library code. It is reponsible
  for converting [AdGuard rules][adguardrules] to Safari content blocking rules
  and advanced blocking rules. "Advanced rules" are AdGuard rules that cannot be
  directly converted to Safari syntax and should be interpreted using JS by a
  browser extension.

- `/Sources/CommandLineWrapper` - command-line interface code. It is responsible
  for providing a command-line interface to the converter library.

- `/Sources/FilterEngine` - filter engine code. `FilterEngine` is a part of the
  library that is used to interpret advanced blocking rules.

- `/Extension` - javascript code responsible for interpreting advanced rules.
  It is supposed to be used as a library in a Safari Web Extension (or Safari
  App Extension).

- `/Sources/FileLockTester` - file lock tester code. It is responsible for
  testing file lock functionality. The library uses `FileLock` class for
  distributed locking functionality. Unfortunately, to test it we have to
  create a separate helper app.

### ContentBlockerConverter code organization

The public API is provided by the `ContentBlockerConverter` class and its
public `convertArray` function.

Internally, it parses string lines using `ContentBlockerConverter/Rules/*`
classes and discards the lines that cannot be parsed.

After that the rules are transformed into Safari content blocking rules by
`Compiler`.

### FilterEngine code organization

The public API is provided by two classes:

- `WebExtension` - the class that is supposed to be used by web extensions. It
  covers all the important use cases:

    - Building and serializing the filtering engine (see `buildFilterEngine`) to
      a location shared between the main app process and the extension's
      process.
    - Looking up for the set of filtering rules that should be applied to the
      specified page (see `lookup`). This method also implicitly deserializes
      the filtering engine.

- `FilterEngine` - provides the low-level API for building, serializing and
  deserializing the filtering engine, a class that interprets AdGuard rules
  and is capable of performing all the operations very quickly.

### Extension code organization

Please refer to [Extension/README.md][extension] for details on how code is
organized there.

[extension]: ./Extension/README.md
