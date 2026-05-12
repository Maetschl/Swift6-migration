import Foundation

// MARK: - MainActorRunRule demo
// Non-isolated classes calling await MainActor.run while capturing self
// triggers "Sending self risks causing data races" in Swift 6.

class ProfileSyncService {
    var displayName: String = ""
    var lastSyncDate: Date?

    func syncProfile() async {
        try? await Task.sleep(for: .milliseconds(100))
        // Flagged: self (ProfileSyncService) is not Sendable
        await MainActor.run {
            self.displayName = "Jane Doe"
            self.lastSyncDate = Date()
        }
    }

    func refreshUI() async {
        await MainActor.run {
            _ = self.displayName.uppercased()
        }
    }
}

class AnalyticsTracker {
    var eventCount: Int = 0

    func trackEvent(_ name: String) async {
        // Flagged: capturing non-Sendable self across MainActor boundary
        await MainActor.run {
            self.eventCount += 1
            print("Tracked: \(name) (total: \(self.eventCount))")
        }
    }
}
