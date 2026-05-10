import Foundation

// ❌ GlobalMutableState
var databasePath: String = "/var/db/legacyapp.sqlite"
var cacheExpirySeconds: Int = 3600

// ❌ UncheckedSendable — bypasses race-condition checks on DB access
final class DatabaseManager: @unchecked Sendable {

    // ❌ SynchronizationPrimitive — DispatchSemaphore instead of actor
    private let writeSemaphore = DispatchSemaphore(value: 1)
    private let readSemaphore = DispatchSemaphore(value: 3) // reader-writer pattern
    private let dbLock = NSLock()

    // ❌ CompletionHandler
    func write(key: String, value: Data, completion: @escaping (Bool) -> Void) {
        writeSemaphore.wait()
        DispatchQueue.global(qos: .userInitiated).async {
            defer { self.writeSemaphore.signal() }
            self.dbLock.lock()
            defer { self.dbLock.unlock() }
            // Simulate write
            print("Writing \(key) to \(databasePath)")
            DispatchQueue.main.async { completion(true) }
        }
    }

    // ❌ CompletionHandler + force try
    func read(key: String, completion: @escaping (Data?) -> Void) {
        readSemaphore.wait()
        DispatchQueue.global(qos: .userInitiated).async {
            defer { self.readSemaphore.signal() }
            // ❌ ForceTry — should use do/catch
            let data = try! JSONSerialization.data(withJSONObject: ["key": key])
            DispatchQueue.main.async { completion(data) }
        }
    }

    // ❌ CompletionHandler + force try
    func batchWrite(_ entries: [(String, Data)], completion: @escaping (Int) -> Void) {
        writeSemaphore.wait()
        DispatchQueue.global().async {
            defer { self.writeSemaphore.signal() }
            var written = 0
            for (key, value) in entries {
                // ❌ ForceTry
                let _ = try! JSONSerialization.jsonObject(with: value) as! [String: Any]
                print("Batch writing \(key)")
                written += 1
            }
            DispatchQueue.main.async { completion(written) }
        }
    }
}
