import Foundation
import Combine

// ❌ GlobalMutableState — file-scope vars accessible from any concurrency domain
var activeDashboardSections: [String] = ["news", "trending", "recommended"]
var dashboardRefreshInterval: TimeInterval = 60.0
var lastRefreshTimestamp: Date? = nil

// ❌ ObservableObject + @Published — should use @Observable
class DashboardViewModel: ObservableObject {
    @Published var sections: [String] = []
    @Published var isRefreshing: Bool = false
    @Published var unreadCount: Int = 0

    private var cancellables = Set<AnyCancellable>()

    // ❌ Timer callback — should use async loop with Task.sleep
    func startAutoRefresh() {
        Timer.scheduledTimer(withTimeInterval: dashboardRefreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // ❌ DispatchQueue.main.async — should be @MainActor
    func refresh() {
        DispatchQueue.main.async { self.isRefreshing = true }

        DispatchQueue.global(qos: .background).async {
            // Simulate fetch
            let newSections = activeDashboardSections
            DispatchQueue.main.async {
                self.sections = newSections
                self.isRefreshing = false
                lastRefreshTimestamp = Date()
            }
        }
    }

    // ❌ CompletionHandler
    func fetchUnreadCount(completion: @escaping (Int) -> Void) {
        DispatchQueue.global().async {
            let count = Int.random(in: 0...99)
            DispatchQueue.main.async {
                self.unreadCount = count
                completion(count)
            }
        }
    }

    // ❌ Combine assign(to:on:)
    func bindUnreadBadge(publisher: AnyPublisher<Int, Never>) {
        publisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.unreadCount, on: self)
            .store(in: &cancellables)
    }
}
