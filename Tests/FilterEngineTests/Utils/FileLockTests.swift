import XCTest
import Foundation
@testable import FilterEngine

class FileLockTests: XCTestCase {
    func testThreadSynchronization() {
        let filePath = NSTemporaryDirectory().appending("test.lock")
        guard let lock = FileLock(filePath: filePath) else {
            XCTFail("Failed to create FileLock")
            return
        }

        let iterations = 1000
        var counter = 0
        let queue = DispatchQueue.global(qos: .background)
        let group = DispatchGroup()

        for _ in 0..<iterations {
            group.enter()
            queue.async {
                // Acquire lock (blocking call, does not return a value now)
                lock.lock()
                // Critical section protected by thread lock
                let local = counter
                // simulate work
                Thread.sleep(forTimeInterval: 0.0001)
                counter = local + 1
                XCTAssertTrue(lock.unlock(), "Expected unlock to succeed")
                group.leave()
            }
        }

        // Wait for all tasks to complete
        group.wait()

        XCTAssertEqual(counter, iterations, "Counter should match number of iterations")
    }

    func testLockBeforeDeadline() {
        let filePath = NSTemporaryDirectory().appending("deadlineTest.lock")
        guard let lock = FileLock(filePath: filePath) else {
            XCTFail("Failed to create FileLock")
            return
        }

        // Acquire the lock in a background thread and hold it for a while
        let lockHeldExpectation = expectation(description: "Lock is held")
        DispatchQueue.global().async {
            lock.lock()
            // hold the lock for 2 seconds
            Thread.sleep(forTimeInterval: 2)
            XCTAssertTrue(lock.unlock(), "Expected unlock to succeed")
            lockHeldExpectation.fulfill()
        }

        // Wait a moment to ensure the background thread acquired the lock
        Thread.sleep(forTimeInterval: 0.1)

        // Now, in the main thread, attempt to acquire the lock with a deadline that is too soon
        let deadline = Date().addingTimeInterval(0.2)
        let acquired = lock.lock(before: deadline)
        // We expect failure because the background thread holds the lock
        XCTAssertFalse(acquired, "Expected lock to not be acquired as it's held by another thread")

        // Wait for the background thread to finish
        waitForExpectations(timeout: 3, handler: nil)
    }
}