import Foundation

// ✅ Fully migrated — actor-based coordinator

actor RootCoordinator {
    enum Route: Sendable {
        case home, profile(userID: String), settings, onboarding
    }

    private var currentRoute: Route = .home
    private var navigationStack: [Route] = []

    func start() async {
        await navigate(to: .home)
    }

    func navigate(to route: Route) async {
        navigationStack.append(route)
        currentRoute = route
        print("Navigating to \(route)")
    }

    func handle(deepLink url: URL) async {
        let route = resolveRoute(from: url)
        await navigate(to: route)
    }

    func handle(notification type: String) async {
        switch type {
        case "profile": await navigate(to: .profile(userID: "unknown"))
        case "settings": await navigate(to: .settings)
        default: await navigate(to: .home)
        }
    }

    private func resolveRoute(from url: URL) -> Route {
        switch url.host {
        case "profile": return .profile(userID: url.lastPathComponent)
        case "settings": return .settings
        default: return .home
        }
    }
}
