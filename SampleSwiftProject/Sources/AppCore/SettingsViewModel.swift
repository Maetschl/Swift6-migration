import Foundation

// ⚠️ ObservableObject + @Published
class SettingsViewModel: ObservableObject {
    @Published var notificationsEnabled: Bool = true
    @Published var darkModeEnabled: Bool = false
    @Published var language: String = "en"

    private let store: UserDefaults

    init(store: UserDefaults = .standard) {
        self.store = store
    }

    // ⚠️ CompletionHandler
    func saveSettings(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.store.set(self.notificationsEnabled, forKey: "notifications")
            self.store.set(self.darkModeEnabled, forKey: "darkMode")
            self.store.set(self.language, forKey: "language")
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }

    // ⚠️ DispatchQueue.main.async
    func resetToDefaults() {
        DispatchQueue.main.async {
            self.notificationsEnabled = true
            self.darkModeEnabled = false
            self.language = "en"
        }
    }
}

class DataService {
    // ⚠️ CompletionHandler
    func fetchItems(completion: @escaping (Result<[String], Error>) -> Void) {
        DispatchQueue.global().async {
            let items = ["Item A", "Item B", "Item C"]
            DispatchQueue.main.async {
                completion(.success(items))
            }
        }
    }
}
