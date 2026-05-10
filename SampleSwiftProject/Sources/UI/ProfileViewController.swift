import UIKit

// ⚠️ MainActorMissing — UIViewController without @MainActor
class ProfileViewController: UIViewController {

    // ⚠️ Force unwrap
    var userID: String!
    var avatarURL: URL!

    override func viewDidLoad() {
        super.viewDidLoad()
        // ⚠️ Force try
        let data = try! Data(contentsOf: avatarURL)
        print("Avatar data: \(data.count) bytes")

        // ⚠️ DispatchQueue.main.async
        DispatchQueue.main.async {
            self.title = "Profile"
        }
    }

    // ⚠️ CompletionHandler
    func uploadAvatar(imageData: Data, completion: @escaping (Bool) -> Void) {
        // ⚠️ DispatchQueue.global
        DispatchQueue.global(qos: .userInitiated).async {
            // simulate upload
            Thread.sleep(forTimeInterval: 1.0)
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }

    // ⚠️ @preconcurrency usage
    @preconcurrency func legacySetup() {
        print("Legacy setup for user: \(userID!)")
    }
}
