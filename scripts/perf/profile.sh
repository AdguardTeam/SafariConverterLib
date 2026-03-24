#!/bin/bash
#
# Run CPU profiling on testPerformanceSingleRun via xctrace and extract
# CPU cycle counts for ContentBlockerConverter.convertArray.
#
# Usage:
#   ./scripts/perf/profile.sh [--skip-build]
#
# Options:
#   --skip-build  Skip building tests (use existing test binary)
#
# Prerequisites:
#   - Xcode with xctrace (comes with Xcode Command Line Tools)
#   - Python 3
#
# Output:
#   Prints the CPU cycle count (Mc) and percentage for convertArray,
#   matching the format used in the baselines recorded in
#   ContentBlockerConverterPerformanceTests.swift.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TRACE_FILE="$(mktemp -d)/perf-test.trace"

SKIP_BUILD=0
for arg in "$@"; do
    case "$arg" in
        --skip-build) SKIP_BUILD=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

cd "$REPO_DIR"

# 1. Build tests in release mode with testability (matches Xcode Profile).
if [ "$SKIP_BUILD" -eq 0 ]; then
    echo "Building tests (release)..."
    swift build --build-tests -c release -Xswiftc -enable-testing --quiet
fi

# 2. Locate the test bundle.
TEST_BUNDLE=".build/arm64-apple-macosx/release/ContentBlockerConverterPackageTests.xctest"
if [ ! -d "$TEST_BUNDLE" ]; then
    echo "Error: test bundle not found at $TEST_BUNDLE" >&2
    echo "Run 'swift build --build-tests' first." >&2
    exit 1
fi

# 3. Find xctest binary.
XCTEST_BIN="$(xcrun --find xctest 2>/dev/null)"
if [ -z "$XCTEST_BIN" ]; then
    echo "Error: xctest not found. Is Xcode installed?" >&2
    exit 1
fi

# 4. Record a CPU Profiler trace.
echo "Recording CPU Profiler trace..."
xctrace record \
    --template 'CPU Profiler' \
    --output "$TRACE_FILE" \
    --no-prompt \
    --launch -- "$XCTEST_BIN" \
    -XCTest ContentBlockerConverterTests/testPerformanceSingleRun \
    "$(pwd)/$TEST_BUNDLE" 2>&1

echo ""

# 5. Export and parse.
echo "=== CPU Profiler Results ==="
python3 "$SCRIPT_DIR/parse_xctrace.py" "$TRACE_FILE"
echo ""
echo "Trace file: $TRACE_FILE"
echo "(Open in Instruments for detailed analysis)"
