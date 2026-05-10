import Foundation

// ❌ GlobalMutableState — top-level vars not concurrency-safe
var appLanguage: String = "en"
var appTheme: String = "light"
var analyticsEnabled: Bool = true
var notificationsGranted: Bool = false

// ❌ ObservableObject + @Published
class SettingsViewModel: ObservableObject {
    @Published var language: String = appLanguage
    @Published var theme: String = appTheme
    @Published var analyticsEnabled: Bool = true
    @Published var pushNotificationsEnabled: Bool = false

    // ❌ NotificationCenter — addObserver callback style
    func observeSystemTheme() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemThemeChanged),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }

    @objc func systemThemeChanged() {
        // ❌ DispatchQueue.main.async — should be @MainActor
        DispatchQueue.main.async {
            self.theme = "dark"
            appTheme = "dark"
        }
    }

    // ❌ CompletionHandler
    func saveSettings(completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            // Persist settings
            appLanguage = self.language
            appTheme = self.theme
            analyticsEnabled = self.analyticsEnabled
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("SettingsDidChange"),
                    object: nil
                )
                completion(.success(()))
            }
        }
    }

    // ❌ NotificationCenter.post
    func broadcastReset() {
        appLanguage = "en"
        appTheme = "light"
        NotificationCenter.default.post(name: Notification.Name("SettingsDidReset"), object: nil)
    }
}
