#!/bin/bash

# file_lock_test.sh - Test script for FileLockTester
# Tests the distributed locking behavior of FileLock class

set -e

# Check if the FileLockTester binary path is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <path_to_FileLockTester_binary>"
    exit 1
fi

TESTER_BIN="$1"
LOCK_FILE="/tmp/file_lock_test.lock"
TEST_LOG="/tmp/file_lock_test.log"
TEMP_DIR="/tmp/file_lock_test_tmp"

# Create temp directory for test files
mkdir -p "$TEMP_DIR"

# Ensure the lock file doesn't exist at the start
rm -f "$LOCK_FILE"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to clean up resources
cleanup() {
    echo "Cleaning up resources..."
    pkill -f "FileLockTester" 2>/dev/null || true
    rm -f "$LOCK_FILE" 2>/dev/null || true
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

# Test 1: Basic functionality - can acquire and release a lock
test_basic_functionality() {
    local test_name="Basic Functionality Test"
    echo -e "\n=== Running Test: $test_name ==="

    "$TESTER_BIN" "$LOCK_FILE" 1 > "$TEST_LOG" 2>&1
    local exit_code=$?

    if [ $exit_code -eq 0 ] && grep -q "Released lock at depth 1, result: true" "$TEST_LOG"; then
        print_result "$test_name" "PASS" "Successfully acquired and released lock"
        return 0
    else
        print_result "$test_name" "FAIL" "Failed to acquire or release lock"
        cat "$TEST_LOG"
        return 1
    fi
}

# Test 2: Concurrent locks - second process waits for first to release
test_concurrent_locks() {
    local test_name="Concurrent Lock Test"
    echo -e "\n=== Running Test: $test_name ==="

    # Start first process in background
    local lock_time=3
    echo "Starting first process to hold lock for $lock_time seconds"
    "$TESTER_BIN" "$LOCK_FILE" $lock_time > "$TEMP_DIR/first.log" 2>&1 &
    local pid1=$!

    # Give it time to acquire the lock
    sleep 1

    # Start second process and time how long it takes
    echo "Starting second process"
    local start_time=$(date +%s)
    "$TESTER_BIN" "$LOCK_FILE" 1 > "$TEMP_DIR/second.log" 2>&1
    local end_time=$(date +%s)

    # Calculate elapsed time
    local elapsed=$((end_time - start_time))

    # Ensure first process is done
    wait $pid1 2>/dev/null || true

    echo "First process log:"
    cat "$TEMP_DIR/first.log"
    echo "Second process log:"
    cat "$TEMP_DIR/second.log"
    echo "Elapsed time: $elapsed seconds"

    # Second process should have waited at least lock_time-1 seconds
    if [ $elapsed -ge $((lock_time - 1)) ]; then
        print_result "$test_name" "PASS" "Second process waited for first to release lock (waited $elapsed seconds)"
        return 0
    else
        print_result "$test_name" "FAIL" "Second process did not wait long enough (only $elapsed seconds)"
        return 1
    fi
}

# Test 3: Deadline test - should fail to acquire lock before deadline
test_deadline() {
    local test_name="Deadline Test"
    echo -e "\n=== Running Test: $test_name ==="

    # Start first process to hold the lock
    local lock_time=5
    echo "Starting first process to hold lock for $lock_time seconds"
    "$TESTER_BIN" "$LOCK_FILE" $lock_time > "$TEMP_DIR/first.log" 2>&1 &
    local pid1=$!

    # Give it time to acquire the lock
    sleep 1

    # Start second process with a short deadline
    local deadline=1
    echo "Starting second process with deadline of $deadline seconds"
    "$TESTER_BIN" "$LOCK_FILE" 1 $deadline > "$TEMP_DIR/second.log" 2>&1
    local exit_code=$?

    # Ensure first process is terminated
    kill $pid1 2>/dev/null || true
    wait $pid1 2>/dev/null || true

    echo "First process log:"
    cat "$TEMP_DIR/first.log"
    echo "Second process log:"
    cat "$TEMP_DIR/second.log"

    # Second process should fail with exit code 1
    if [ $exit_code -eq 1 ] && grep -q "Failed to acquire lock" "$TEMP_DIR/second.log"; then
        print_result "$test_name" "PASS" "Process correctly failed to acquire lock before deadline"
        return 0
    else
        print_result "$test_name" "FAIL" "Process should have failed to acquire lock before deadline"
        return 1
    fi
}

# Test 4: Re-entrant behavior - can acquire lock multiple times
test_reentrant() {
    local test_name="Re-entrant Lock Test"
    echo -e "\n=== Running Test: $test_name ==="

    local depth=3
    echo "Testing re-entrant behavior with depth $depth"
    "$TESTER_BIN" "$LOCK_FILE" 1 0 $depth > "$TEST_LOG" 2>&1
    local exit_code=$?

    local acquired_count=$(grep -c "Acquired lock at depth" "$TEST_LOG")
    local released_count=$(grep -c "Released lock at depth" "$TEST_LOG")

    echo "Test log:"
    cat "$TEST_LOG"

    if [ $exit_code -eq 0 ] && [ $acquired_count -eq $depth ] && [ $released_count -eq $depth ]; then
        print_result "$test_name" "PASS" "Successfully acquired and released lock $depth times"
        return 0
    else
        print_result "$test_name" "FAIL" "Expected to acquire and release lock $depth times"
        return 1
    fi
}

# Test 5: Process killed - lock should be released when process is killed
test_process_killed() {
    local test_name="Process Killed Test"
    echo -e "\n=== Running Test: $test_name ==="

    # Start process to hold the lock
    local lock_time=10
    echo "Starting process to hold lock for $lock_time seconds"
    "$TESTER_BIN" "$LOCK_FILE" $lock_time > "$TEMP_DIR/first.log" 2>&1 &
    local pid=$!

    # Give it time to acquire the lock
    sleep 1

    # Kill the process
    echo "Killing process $pid"
    kill -9 $pid

    # Wait a moment for the OS to clean up
    sleep 1

    # Try to acquire the lock with a new process
    echo "Attempting to acquire the lock after process was killed"
    "$TESTER_BIN" "$LOCK_FILE" 1 > "$TEMP_DIR/second.log" 2>&1
    local exit_code=$?

    echo "Second process log:"
    cat "$TEMP_DIR/second.log"

    if [ $exit_code -eq 0 ]; then
        print_result "$test_name" "PASS" "Lock was released when process was killed"
        return 0
    else
        print_result "$test_name" "FAIL" "Lock was not released when process was killed"
        return 1
    fi
}

# Run all tests
echo "=== FileLock Test Suite ==="
echo "Testing FileLockTester binary: $TESTER_BIN"

# Track overall success
success=true

# Run tests and track failures
test_basic_functionality || success=false
test_concurrent_locks || success=false
test_deadline || success=false
test_reentrant || success=false
test_process_killed || success=false

echo -e "\n=== Test Suite Completed ==="

# Return overall success/failure
if [ "$success" = true ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
