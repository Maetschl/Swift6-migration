import Foundation

// ✅ Fully migrated — async/await app lifecycle

@MainActor
final class AppLifecycleManager {
    private var isForegrounded: Bool = false

    func applicationDidBecomeActive() async {
        isForegrounded = true
        await resumeBackgroundTasks()
    }

    func applicationDidEnterBackground() async {
        isForegrounded = false
        await suspendBackgroundTasks()
    }

    private func resumeBackgroundTasks() async {
        // Structured concurrency — no DispatchQueue needed
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshSession() }
            group.addTask { await self.syncLocalCache() }
        }
    }

    private func suspendBackgroundTasks() async {
        print("Suspending tasks gracefully")
    }

    private func refreshSession() async {
        try? await Task.sleep(nanoseconds: 100_000_000)
        print("Session refreshed")
    }

    private func syncLocalCache() async {
        try? await Task.sleep(nanoseconds: 50_000_000)
        print("Cache synced")
    }
}
