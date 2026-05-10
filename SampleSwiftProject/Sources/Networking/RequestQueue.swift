import Foundation

// ⚠️ SynchronizationPrimitive — DispatchSemaphore
final class RequestQueue {
    private let semaphore = DispatchSemaphore(value: 1)
    private let internalLock = NSRecursiveLock()
    private var pendingRequests: [String] = []

    func enqueue(_ requestID: String) {
        internalLock.lock()
        defer { internalLock.unlock() }
        pendingRequests.append(requestID)
    }

    func processNext() {
        semaphore.wait()
        defer { semaphore.signal() }
        guard !pendingRequests.isEmpty else { return }
        let next = pendingRequests.removeFirst()
        print("Processing: \(next)")
    }
}

// ⚠️ GlobalMutableState
var sharedRequestQueue = RequestQueue()
var networkRetryCount: Int = 3

// ⚠️ Thread usage
class SocketManager {
    func startListening() {
        Thread.detachNewThread {
            print("Socket listener running on: \(Thread.current)")
            while true {
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
    }

    func checkThread() {
        if Thread.isMainThread {
            print("On main thread — dispatching to background")
        } else {
            print("Already on background")
        }
    }
}
