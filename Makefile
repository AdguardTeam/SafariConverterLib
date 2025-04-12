# Keep the Makefile POSIX-compliant.  We currently allow hyphens in
# target names, but that may change in the future.
#
# See https://pubs.opengroup.org/onlinepubs/9699919799/utilities/make.html.
.POSIX:

PNPM = pnpm -C ./Extension

init:
	git config core.hooksPath ./scripts/hooks

# Building

build: swift-build js-build

swift-build:
	swift build -c release

js-build:
	$(PNPM) install && $(PNPM) build

# Linter commands

lint: md-lint swift-lint js-lint

md-lint:
	npx markdownlint .

swift-lint: swiftlint-lint swiftformat-lint periphery-lint

swiftlint-lint:
	swiftlint lint --strict --quiet

swiftformat-lint:
	swift format lint --recursive --strict .

periphery-lint:
	periphery scan --retain-public --quiet --strict

js-lint:
	$(PNPM) install && $(PNPM) lint

# Testing

test: swift-test js-test filelock-test command-line-wrapper-test

swift-test:
	swift test --quiet

js-test:
	$(PNPM) install && CI=1 $(PNPM) test

filelock-test:
	swift build -c release --product FileLockTester
	./scripts/tests/file_lock_test.sh .build/release/FileLockTester

command-line-wrapper-test:
	swift build -c release --product ConverterTool
	./scripts/tests/command_line_wrapper_test.sh .build/release/ConverterTool
