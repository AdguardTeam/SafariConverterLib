# Keep the Makefile POSIX-compliant.  We currently allow hyphens in
# target names, but that may change in the future.
#
# See https://pubs.opengroup.org/onlinepubs/9699919799/utilities/make.html.
.POSIX:

PNPM = pnpm -C ./Extension

# Init the repo

init: tools
	git config core.hooksPath ./scripts/hooks

# Generate ContentBlockerConverterVersion.swift file
codegen:
	./scripts/make/verifychangelog.sh $(VERSION)
	./scripts/make/codegen.sh $(VERSION)

# Makes sure that the necessary tools are installed
tools:
	swift --version
	swiftlint --version
	xcbeautify --version
	periphery version
	node --version
	npm --version
	pnpm --version
	npx markdownlint --version

# Building debug builds

build: swift-build js-build

swift-build:
	swift build

js-build:
	$(PNPM) install && $(PNPM) build

# Building release builds

release: swift-release js-release

swift-release:
	swift build -c release

js-release:
	$(PNPM) install && $(PNPM) package

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
