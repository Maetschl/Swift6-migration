import Foundation

// ❌ GlobalMutableState
var preferredCurrency: String = "USD"
var decimalSeparator: String = "."

// ❌ ObservableObject
class LocalizationManager: ObservableObject {
    @Published var currentLocale: String = appLanguage
    @Published var supportedLanguages: [String] = ["en", "es", "fr", "de", "ja"]

    // ❌ NotificationCenter observer
    func startListeningForLocaleChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(localeDidChange),
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )
    }

    @objc func localeDidChange() {
        DispatchQueue.main.async {
            self.currentLocale = Locale.current.identifier
            preferredCurrency = Locale.current.currency?.identifier ?? "USD"
        }
    }

    // ❌ CompletionHandler
    func applyLanguage(_ code: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global().async {
            appLanguage = code
            self.currentLocale = code
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("LanguageChanged"),
                    object: code
                )
                completion(true)
            }
        }
    }
}
