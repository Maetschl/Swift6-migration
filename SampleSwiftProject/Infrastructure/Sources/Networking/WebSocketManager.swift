import Foundation

// ❌ Thread — manual thread management bypassing actor model
class WebSocketManager {

    // ❌ NonisolatedUnsafe
    nonisolated(unsafe) var endpoint: String = "wss://ws.legacyapp.com"

    // ❌ SynchronizationPrimitive
    private let socketLock = NSRecursiveLock()
    private var isConnected: Bool = false
    private var messageQueue: [String] = []

    // ❌ Thread.detachNewThread — should use structured concurrency
    func connect() {
        Thread.detachNewThread {
            print("WebSocket connecting on thread: \(Thread.current)")
            self.socketLock.lock()
            self.isConnected = true
            self.socketLock.unlock()
            self.startHeartbeat()
        }
    }

    // ❌ Thread usage
    private func startHeartbeat() {
        Thread.detachNewThread {
            while self.isConnected {
                Thread.sleep(forTimeInterval: 15.0)
                if Thread.isMainThread {
                    print("Heartbeat on main — bad!")
                }
                self.sendPing()
            }
        }
    }

    private func sendPing() {
        socketLock.lock()
        defer { socketLock.unlock() }
        messageQueue.append("ping")
        print("Ping sent")
    }

    // ❌ DispatchGroup — should use withTaskGroup
    func fetchInitialData() {
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global().async {
            print("Fetching channels...")
            group.leave()
        }

        group.enter()
        DispatchQueue.global().async {
            print("Fetching presence...")
            group.leave()
        }

        group.notify(queue: .main) {
            print("WebSocket initial data ready")
        }
    }
}
