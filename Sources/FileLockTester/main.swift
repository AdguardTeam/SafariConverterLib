/// FileLockTester is a helper executable required for testing inter-process
/// synchronization of the FileLock class.
///
/// To do that you can run this command from two different terminals and check
/// the timings:
///
/// ```
/// swift run FileLockTester /tmp/reentrant-test.lock 5
/// ```
///
/// Additionally, you can test the lock with a deadline:
///
/// ```
/// swift run FileLockTester /tmp/reentrant-test.lock 5 10
/// ```
///
/// You can also test re-entrant behavior by specifying the number of times
/// to lock recursively:
///
/// ```
/// swift run FileLockTester /tmp/reentrant-test.lock 5 10 3
/// ```
///
/// You can also check the lock behavior when the process is killed and unlock
/// was not called.

import FilterEngine
import Foundation

guard CommandLine.arguments.count >= 3 else {
    print("Usage: FileLockTester <lockFilePath> <sleepSeconds> [deadlineSeconds] [maxLockDepth]")
    print("  lockFilePath: Path to the lock file")
    print("  sleepSeconds: Time to sleep at each lock level in seconds")
    print("  deadlineSeconds: Optional. If provided, use lock(before:) with this deadline")
    print("  maxLockDepth: Optional. Maximum recursive lock depth (tests re-entrancy)")
    exit(1)
}

let lockFile = CommandLine.arguments[1]
let sleepSeconds: Double = Double(CommandLine.arguments[2]) ?? 2.0

// Default max lock depth is 1 (no recursion)
let maxLockDepth = CommandLine.arguments.count >= 5 ? (Int(CommandLine.arguments[4]) ?? 1) : 1

let startTime = Date()  // record start time before trying to acquire lock

guard let lock = FileLock(filePath: lockFile) else {
    print("Failed to create FileLock")
    exit(1)
}

// Use deadline if provided
let useDeadline = CommandLine.arguments.count >= 4 && CommandLine.arguments[3] != "0"
let deadlineSeconds: Double = useDeadline ? (Double(CommandLine.arguments[3]) ?? 5.0) : 0
let deadline = useDeadline ? Date().addingTimeInterval(deadlineSeconds) : Date()

if useDeadline {
    print(String(format: "Deadline: %@", deadline.description))
}

// Recursive function to test re-entrancy
func doWorkRecursive(currentDepth: Int) {
    print("Attempting to acquire lock at depth \(currentDepth)")

    let lockAcquired: Bool
    if useDeadline {
        lockAcquired = lock.lock(before: deadline)
        if !lockAcquired {
            print("Failed to acquire lock at depth \(currentDepth) with deadline")
            exit(1)
        }
    } else {
        lock.lock()
        lockAcquired = true
    }

    print("Acquired lock at depth \(currentDepth)")
    defer {
        let unlockResult = lock.unlock()
        print("Released lock at depth \(currentDepth), result: \(unlockResult)")
    }

    // If we haven't reached max depth, recurse deeper
    if currentDepth < maxLockDepth {
        doWorkRecursive(currentDepth: currentDepth + 1)
    }

    // Sleep at each level
    print("Sleeping at depth \(currentDepth) for \(sleepSeconds) seconds")
    Thread.sleep(forTimeInterval: sleepSeconds)
    print("Finished sleeping at depth \(currentDepth)")
}

// Start the recursive lock testing
print("Starting recursive lock test with max depth \(maxLockDepth)")
doWorkRecursive(currentDepth: 1)

let totalTime = Date().timeIntervalSince(startTime)
print(String(format: "Total time for recursive lock test: %.3f seconds", totalTime))

// Try to unlock one more time to verify behavior after all locks are released
let extraUnlockResult = lock.unlock()
print("Extra unlock result (should be false if lock fully released): \(extraUnlockResult)")

exit(0)
