#!/bin/bash

# command_line_wrapper_test.sh - Test script for CommandLineWrapper
# Tests the functionality of the ConverterTool command-line utility

set -e

# Check if the ConverterTool binary path is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <path_to_ConverterTool_binary>"
    exit 1
fi

CONVERTER_BIN="$1"
TEMP_DIR="/tmp/converter_tool_test"
TEST_RULES_FILE="$TEMP_DIR/test_rules.txt"
TEST_LOG="$TEMP_DIR/test.log"
SAFARI_RULES_JSON="$TEMP_DIR/safari_rules.json"
ADVANCED_RULES_FILE="$TEMP_DIR/advanced_rules.txt"
ENGINE_DIR="$TEMP_DIR/engine"

# Create temp directory for test files
mkdir -p "$TEMP_DIR"
mkdir -p "$ENGINE_DIR"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to clean up resources
cleanup() {
    echo "Cleaning up resources..."
    rm -rf "$TEMP_DIR" 2>/dev/null || true
}

# Ensure cleanup happens on script exit
trap cleanup EXIT INT TERM

# Function to print colored output
print_result() {
    local test_name="$1"
    local result="$2"
    local details="$3"

    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
    elif [ "$result" = "FAIL" ]; then
        echo -e "${RED}[FAIL]${NC} $test_name: $details"
    else
        echo -e "${YELLOW}[INFO]${NC} $test_name: $details"
    fi
}

# Create test rules file
create_test_rules() {
    cat >"$TEST_RULES_FILE" <<EOF
! Test rules for CommandLineWrapper
||example.com^
@@||good.example.com^
example.org##.ads
example.net#%#//scriptlet('abort-on-property-read', 'ads')
EOF
    echo "Created test rules file with $(wc -l <"$TEST_RULES_FILE") rules"
}

# Test 1: Convert command with stdin input
test_convert_stdin() {
    local test_name="Convert Command (stdin)"
    echo -e "\n=== Running Test: $test_name ==="

    cat "$TEST_RULES_FILE" | "$CONVERTER_BIN" convert --safari-version 15 >"$TEST_LOG" 2>&1
    local exit_code=$?

    if [ $exit_code -eq 0 ] && grep -q "safariRulesJSON" "$TEST_LOG"; then
        print_result "$test_name" "PASS" "Successfully converted rules from stdin"
        return 0
    else
        print_result "$test_name" "FAIL" "Failed to convert rules from stdin"
        cat "$TEST_LOG"
        return 1
    fi
}

# Test 2: Convert command with file input
test_convert_file() {
    local test_name="Convert Command (file input)"
    echo -e "\n=== Running Test: $test_name ==="

    "$CONVERTER_BIN" convert --safari-version 15 --input-path "$TEST_RULES_FILE" >"$TEST_LOG" 2>&1
    local exit_code=$?

    if [ $exit_code -eq 0 ] && grep -q "safariRulesJSON" "$TEST_LOG"; then
        print_result "$test_name" "PASS" "Successfully converted rules from file"
        return 0
    else
        print_result "$test_name" "FAIL" "Failed to convert rules from file"
        cat "$TEST_LOG"
        return 1
    fi
}

# Test 3: Convert command with output file paths
test_convert_output_files() {
    local test_name="Convert Command (output files)"
    echo -e "\n=== Running Test: $test_name ==="

    "$CONVERTER_BIN" convert --safari-version 15 --input-path "$TEST_RULES_FILE" \
        --safari-rules-json-path "$SAFARI_RULES_JSON" \
        --advanced-blocking-rules-path "$ADVANCED_RULES_FILE" \
        --advanced-blocking true >"$TEST_LOG" 2>&1
    local exit_code=$?

    # Check if output files exist and have content
    if [ $exit_code -eq 0 ] && [ -s "$SAFARI_RULES_JSON" ] && [ -s "$ADVANCED_RULES_FILE" ]; then
        print_result "$test_name" "PASS" "Successfully created output files"
        return 0
    else
        print_result "$test_name" "FAIL" "Failed to create output files"
        cat "$TEST_LOG"
        return 1
    fi
}

# Test 4: Convert command with advanced blocking
test_convert_advanced_blocking() {
    local test_name="Convert Command (advanced blocking)"
    echo -e "\n=== Running Test: $test_name ==="

    "$CONVERTER_BIN" convert --safari-version 15 --input-path "$TEST_RULES_FILE" \
        --advanced-blocking true >"$TEST_LOG" 2>&1
    local exit_code=$?

    if [ $exit_code -eq 0 ] && grep -q "advancedRulesText" "$TEST_LOG"; then
        print_result "$test_name" "PASS" "Successfully converted with advanced blocking"
        return 0
    else
        print_result "$test_name" "FAIL" "Failed to convert with advanced blocking"
        cat "$TEST_LOG"
        return 1
    fi
}

# Test 5: BuildEngine command with stdin input
test_buildengine_stdin() {
    local test_name="BuildEngine Command (stdin)"
    echo -e "\n=== Running Test: $test_name ==="

    # Create advanced rules file
    cat >"$TEMP_DIR/advanced_only.txt" <<EOF
example.net#%#//scriptlet('abort-on-property-read', 'ads')
EOF

    # Clean engine directory
    rm -rf "$ENGINE_DIR"/*
    mkdir -p "$ENGINE_DIR"

    cat "$TEMP_DIR/advanced_only.txt" | "$CONVERTER_BIN" buildengine --safari-version 15 --output-dir "$ENGINE_DIR" >"$TEST_LOG" 2>&1
    local exit_code=$?

    # Check if engine files were created
    if [ $exit_code -eq 0 ] && [ "$(ls -A "$ENGINE_DIR" | wc -l)" -gt 0 ]; then
        print_result "$test_name" "PASS" "Successfully built engine from stdin"
        return 0
    else
        print_result "$test_name" "FAIL" "Failed to build engine from stdin"
        cat "$TEST_LOG"
        return 1
    fi
}

# Test 6: BuildEngine command with file input
test_buildengine_file() {
    local test_name="BuildEngine Command (file input)"
    echo -e "\n=== Running Test: $test_name ==="

    # Clean engine directory
    rm -rf "$ENGINE_DIR"/*
    mkdir -p "$ENGINE_DIR"

    "$CONVERTER_BIN" buildengine --safari-version 15 --output-dir "$ENGINE_DIR" \
        --input-path "$TEMP_DIR/advanced_only.txt" >"$TEST_LOG" 2>&1
    local exit_code=$?

    # Check if engine files were created
    if [ $exit_code -eq 0 ] && [ "$(ls -A "$ENGINE_DIR" | wc -l)" -gt 0 ]; then
        print_result "$test_name" "PASS" "Successfully built engine from file"
        return 0
    else
        print_result "$test_name" "FAIL" "Failed to build engine from file"
        cat "$TEST_LOG"
        return 1
    fi
}

# Test 7: Error handling - non-existent input file
test_error_handling() {
    local test_name="Error Handling (non-existent file)"
    echo -e "\n=== Running Test: $test_name ==="

    "$CONVERTER_BIN" convert --input-path "/non/existent/file.txt" >"$TEST_LOG" 2>&1
    local exit_code=$?

    if [ $exit_code -ne 0 ] && grep -q "Failed to read from file" "$TEST_LOG"; then
        print_result "$test_name" "PASS" "Correctly handled non-existent file"
        return 0
    else
        print_result "$test_name" "FAIL" "Did not properly handle non-existent file"
        cat "$TEST_LOG"
        return 1
    fi
}

# Run all tests
echo "=== CommandLineWrapper Test Suite ==="
echo "Testing ConverterTool binary: $CONVERTER_BIN"

# Create test rules
create_test_rules

# Track overall success
success=true

# Run tests and track failures
test_convert_stdin || success=false
test_convert_file || success=false
test_convert_output_files || success=false
test_convert_advanced_blocking || success=false
test_buildengine_stdin || success=false
test_buildengine_file || success=false
test_error_handling || success=false

echo -e "\n=== Test Suite Completed ==="

# Return overall success/failure
if [ "$success" = true ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
