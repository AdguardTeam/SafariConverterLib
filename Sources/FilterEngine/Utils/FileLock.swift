import Foundation

/// FileLock provides a mechanism for file-based locking that works both across threads
/// within a process and across separate processes.
///
/// This implementation uses a combination of:
/// - flock() for cross-process locking
/// - NSLock for in-process thread synchronization
///
/// The dual-locking approach ensures proper synchronization in all scenarios.
public class FileLock {
    /// Path to the lock file on disk
    private let filePath: String

    /// File descriptor for the lock file
    private var fileDescriptor: Int32 = -1

    /// Secondary lock for synchronizing threads within the same process
    private let threadLock: NSLock = NSLock()

    /// Initializes a new FileLock instance.
    ///
    /// - Parameter filePath: Path where the lock file should be created or accessed
    /// - Returns: A FileLock instance, or nil if the lock file couldn't be opened or created
    public init?(filePath: String) {
        self.filePath = filePath
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
    public func lock() {
        // First acquire in-process thread lock (blocking indefinitely)
        threadLock.lock()

        // Then acquire the file lock (LOCK_EX = exclusive lock)
        // This will block until the lock is acquired
        var result: Int32 = -1
        repeat {
            result = flock(fileDescriptor, LOCK_EX)
        } while result == -1
    }

    /// Attempts to acquire both locks before the specified time limit.
    ///
    /// - Parameter limit: The deadline by which both locks must be acquired
    /// - Returns: true if both locks were acquired before the deadline, false otherwise
    public func lock(before limit: Date) -> Bool {
        // Attempt to acquire the thread lock with a deadline
        if !threadLock.lock(before: limit) {
            return false
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

        return true
    }

    /// Releases both the file lock and thread lock.
    ///
    /// - Returns: true if the file lock was successfully released, false otherwise.
    ///            Note that the thread lock is always released regardless of the file lock result.
    public func unlock() -> Bool {
        // Release the file lock (LOCK_UN = unlock)
        let result = flock(fileDescriptor, LOCK_UN) == 0

        // Always release the thread lock
        threadLock.unlock()

        return result
    }
}
