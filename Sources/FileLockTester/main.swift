/// FileLockTester is a helper executable required for testing inter-process synchronization of the FileLock class.
///
/// To do that you can run this command from two different terminals and check the timings:
///
/// ```
/// swift run FileLockTester test.lock 5
/// ```
///
/// Additionally, you can test the lock with a deadline:
///
/// ```
/// swift run FileLockTester test.lock 5 10
/// ```
///
/// You can also check the lock behavior when the process is killed and unlock was not called.

import Foundation
import FilterEngine

guard CommandLine.arguments.count >= 3 else {
    print("Usage: FileLockTester <lockFilePath> <sleepSeconds> [deadlineSeconds]")
    exit(1)
}

let lockFile = CommandLine.arguments[1]
let sleepSeconds: Double = Double(CommandLine.arguments[2]) ?? 2.0

let startTime = Date()  // record start time before trying to acquire lock

guard let lock = FileLock(filePath: lockFile) else {
    print("Failed to create FileLock")
    exit(1)
}

if CommandLine.arguments.count >= 4 {
    // If a deadlineSeconds argument is provided, use lock(before:) with the specified deadline
    let deadlineSeconds: Double = Double(CommandLine.arguments[3]) ?? 5.0
    let deadline = Date().addingTimeInterval(deadlineSeconds)
    print(String(format: "Deadline: %@", deadline.description))

    if !lock.lock(before: deadline) {
        let elapsed = Date().timeIntervalSince(startTime)
        print(String(format: "Failed to acquire lock with deadline in %.3f seconds", elapsed))
        exit(1)
    }
} else {
    // Otherwise use blocking lock() call
    lock.lock()
}

let acquiredTime = Date()  // record time when lock acquired
let elapsedBeforeLock = acquiredTime.timeIntervalSince(startTime)
print(String(format: "Time elapsed before acquiring the lock: %.3f seconds", elapsedBeforeLock))
print("locked \(lockFile)")
fflush(stdout)

Thread.sleep(forTimeInterval: sleepSeconds)
let beforeUnlockTime = Date()  // record time just before unlocking
_ = lock.unlock()
let lockHeldDuration = beforeUnlockTime.timeIntervalSince(acquiredTime)
print(String(format: "Time spent before releasing the lock: %.3f seconds", lockHeldDuration))
print("released \(lockFile)")
fflush(stdout)

exit(0)
