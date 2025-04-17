import Foundation

/// FileLock provides a mechanism for file-based locking that works both across threads
/// within a process and across separate processes.
///
/// This implementation uses a combination of:
/// - flock() for cross-process locking
/// - NSRecursiveLock for in-process thread synchronization
///
/// The dual-locking approach ensures proper synchronization in all scenarios.
/// This implementation is re-entrant, meaning the same thread can acquire the lock multiple times
/// without causing a deadlock.
public class FileLock {
    /// File descriptor for the lock file
    private var fileDescriptor: Int32 = -1

    /// The number of times this lock was acquired by the same thread.
    /// We maintain the lock count to introduce the proper reentrant behavior of `flock()`
    private var lockCount: Int = 0

    /// Secondary lock for synchronizing threads within the same process.
    /// We are using NSRecursiveLock to maintain the reentrant behavior.
    private let threadLock = NSRecursiveLock()

    /// Initializes a new FileLock instance.
    ///
    /// - Parameter filePath: Path where the lock file should be created or accessed
    /// - Returns: A FileLock instance, or nil if the lock file couldn't be opened or created
    public init?(filePath: String) {
        // Open (or create) the lock file with read/write permissions.
        // O_CREAT - Create the file if it doesn't exist
        // O_RDWR - Open for reading and writing
        // S_IRUSR | S_IWUSR - User read/write permissions
        fileDescriptor = open(filePath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        if fileDescriptor == -1 {
            return nil
        }
    }

    /// Closes the file descriptor when the instance is deallocated.
    deinit {
        if fileDescriptor != -1 {
            close(fileDescriptor)
        }
    }

    /// Acquires both the thread lock and file lock, blocking indefinitely until both are acquired.
    ///
    /// This method first acquires the in-process thread lock, then attempts to acquire the file lock.
    /// The method will not return until both locks are successfully acquired.
    /// If the current thread already owns the lock, it will re-acquire it without blocking (re-entrant behavior).
    public func lock() {
        // First acquire in-process thread lock (blocking indefinitely)
        threadLock.lock()

        if lockCount > 0 {
            // The lock was already acquired before, there's no need to
            // call flock() again, just increment the counter.
            lockCount += 1
            return
        }

        // Then acquire the file lock (LOCK_EX = exclusive lock)
        // This will block until the lock is acquired
        var result: Int32 = -1
        repeat {
            result = flock(fileDescriptor, LOCK_EX)
        } while result == -1

        // Increment the lock count.
        lockCount += 1
    }

    /// Attempts to acquire both locks before the specified time limit.
    ///
    /// - Parameter limit: The deadline by which both locks must be acquired
    /// - Returns: true if both locks were acquired before the deadline, false otherwise
    public func lock(before limit: Date) -> Bool {
        // Attempt to acquire the thread lock with a deadline
        // NSRecursiveLock allows the same thread to acquire the lock multiple times without deadlocking
        if !threadLock.lock(before: limit) {
            return false
        }

        if lockCount > 0 {
            // The lock was already acquired before, there's no need to
            // call flock() again, just increment the counter.
            lockCount += 1
            return true
        }

        var result: Int32 = -1

        // Try to acquire the file lock non-blocking (LOCK_NB)
        // Keep trying until success or deadline is reached
        repeat {
            result = flock(fileDescriptor, LOCK_EX | LOCK_NB)
        } while result != 0 && Date() < limit

        // If we couldn't acquire the file lock before the deadline,
        // release the thread lock and return failure
        if result != 0 {
            threadLock.unlock()
            return false
        }

        // Increment the lock count.
        lockCount += 1

        return true
    }

    /// Releases both the file lock and thread lock.
    ///
    /// Note, that you **MUST** call `unlock()` from the same thread where the lock was acquired.
    ///
    /// - Returns: true if the file lock was successfully released, false otherwise.
    public func unlock() -> Bool {
        var result = true
        if lockCount == 1 {
            // We only release the file lock when the lock count is 1 to ensure
            // re-entrancy.
            result = flock(fileDescriptor, LOCK_UN) == 0
        }

        // Always release the thread lock.
        threadLock.unlock()

        if lockCount == 0 {
            return false
        }

        lockCount -= 1

        return result
    }
}
