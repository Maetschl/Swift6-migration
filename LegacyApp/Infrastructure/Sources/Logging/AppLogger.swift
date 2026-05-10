import Foundation

// ❌ GlobalMutableState
var logLevel: Int = 2 // 0=off 1=error 2=info 3=debug
var logDestination: String = "console"

// ❌ @preconcurrency import suppressing Swift 6 errors
@preconcurrency import os

// ❌ UncheckedSendable
final class AppLogger: @unchecked Sendable {

    // ❌ NonisolatedUnsafe
    nonisolated(unsafe) var subsystem: String = "com.legacyapp"
    nonisolated(unsafe) var category: String = "general"

    // ❌ SynchronizationPrimitive
    private let logLock = NSLock()
    private var logBuffer: [String] = []

    // ❌ OperationQueue.main — should be Task { @MainActor in }
    func logToUI(_ message: String) {
        OperationQueue.main.addOperation {
            print("[UI LOG] \(message)")
        }
    }

    // ❌ Task.detached — loses actor context
    func flushAsync() {
        Task.detached {
            self.logLock.lock()
            let buffer = self.logBuffer
            self.logBuffer.removeAll()
            self.logLock.unlock()
            for entry in buffer {
                print(entry)
            }
        }
    }

    // ❌ Thread
    func startDiskWriter() {
        Thread.detachNewThread {
            while true {
                Thread.sleep(forTimeInterval: 5.0)
                self.flushAsync()
            }
        }
    }

    func log(_ message: String, level: Int = 2) {
        guard level <= logLevel else { return }
        logLock.lock()
        logBuffer.append("[\(level)] \(message)")
        logLock.unlock()
    }
}
