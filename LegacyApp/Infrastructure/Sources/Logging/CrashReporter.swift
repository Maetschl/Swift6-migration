import Foundation

// ❌ @preconcurrency suppressing concurrency errors from legacy SDK
@preconcurrency import Foundation

// ❌ GlobalMutableState
var crashReportingEnabled: Bool = true

// ❌ UncheckedSendable
final class CrashReporter: @unchecked Sendable {

    // ❌ NonisolatedUnsafe
    nonisolated(unsafe) var apiKey: String = ""

    // ❌ SynchronizationPrimitive
    private let reportLock = NSLock()
    private var pendingReports: [[String: Any]] = []

    // ❌ NotificationCenter — listening for crash signals
    func setup() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc func handleMemoryWarning() {
        // ❌ OperationQueue.main
        OperationQueue.main.addOperation {
            self.log(event: "memory_warning")
        }
    }

    // ❌ Task.detached — loses isolation
    func uploadPendingReports() {
        Task.detached {
            self.reportLock.lock()
            let reports = self.pendingReports
            self.pendingReports.removeAll()
            self.reportLock.unlock()
            for report in reports {
                print("Uploading crash report: \(report)")
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    func log(event: String) {
        guard crashReportingEnabled else { return }
        reportLock.lock()
        pendingReports.append(["event": event, "timestamp": Date().timeIntervalSince1970])
        reportLock.unlock()
    }
}
