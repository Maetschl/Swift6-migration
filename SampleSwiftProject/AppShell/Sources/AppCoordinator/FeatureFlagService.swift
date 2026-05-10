import Foundation

// ✅ Fully migrated — async feature flag system

actor FeatureFlagService {
    private var flags: [String: Bool] = [
        "newDashboard": true,
        "betaProfile": false,
        "darkMode": true,
    ]

    func isEnabled(_ flag: String) async -> Bool {
        flags[flag] ?? false
    }

    func setFlag(_ flag: String, enabled: Bool) async {
        flags[flag] = enabled
    }

    func refreshFlags() async throws {
        // Simulate async fetch — structured concurrency, no callbacks
        try await Task.sleep(nanoseconds: 200_000_000)
        flags["newDashboard"] = true
        flags["betaProfile"] = true
        print("Feature flags refreshed")
    }
}
