import Foundation

// ✅ Fully migrated — @MainActor isolated app entry point

@MainActor
final class AppLauncher {
    private let coordinator: RootCoordinator

    init(coordinator: RootCoordinator) {
        self.coordinator = coordinator
    }

    func launch() async {
        await coordinator.start()
    }

    func handleDeepLink(_ url: URL) async {
        await coordinator.handle(deepLink: url)
    }

    func handlePushNotification(_ userInfo: [AnyHashable: Any]) async {
        guard let type = userInfo["type"] as? String else { return }
        await coordinator.handle(notification: type)
    }
}
