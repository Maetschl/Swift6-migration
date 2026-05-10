import UIKit
import Combine

// ⚠️ MainActorMissing — UIViewController subclass without @MainActor
class HomeViewController: UIViewController {
    @Published var title2: String = "Home"
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        // ⚠️ OperationQueue.main instead of @MainActor
        OperationQueue.main.addOperation {
            self.view.backgroundColor = .systemBackground
        }
        setupNotifications()
    }

    // ⚠️ NotificationCenter observer
    func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForeground),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc func handleForeground() {
        NotificationCenter.default.post(name: .init("HomeDidAppear"), object: nil)
        DispatchQueue.main.async {
            self.title = "Home (Active)"
        }
    }

    @objc func handleBackground() {
        print("App went to background")
    }

    // ⚠️ Task.detached losing actor context
    func refreshData() {
        Task.detached {
            let url = URL(string: "https://api.example.com/home")!
            let (data, _) = try! await URLSession.shared.data(from: url)
            DispatchQueue.main.async {
                print("Received \(data.count) bytes")
            }
        }
    }
}

// ⚠️ MainActorMissing — UIView subclass without @MainActor
class CardView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = 12
    }
}

// ⚠️ MainActorMissing — UITableViewCell
class ItemCell: UITableViewCell {
    func configure(with text: String) {
        textLabel?.text = text
    }
}
