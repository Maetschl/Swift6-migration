import Foundation

// ✅ Fully migrated — @MainActor isolated coordinator

@MainActor
final class AppCoordinator {
    private let tracker: AnalyticsTracker
    private let cache: Cache<String, UserProfile>

    init(tracker: AnalyticsTracker) {
        self.tracker = tracker
        self.cache = Cache()
    }

    func start() async {
        await tracker.track(AnalyticsEvent(name: "app_started"))
        await tracker.flush()
    }

    func navigateToProfile(userID: String) async {
        await tracker.track(AnalyticsEvent(name: "profile_opened", parameters: ["user_id": userID]))
        if let profile = await cache.get(userID) {
            print("Showing cached profile for \(profile.name)")
        }
    }
}
