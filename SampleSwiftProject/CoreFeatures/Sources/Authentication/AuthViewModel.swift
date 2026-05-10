import Foundation
import Combine

// ❌ ObservableObject + @Published — should use @Observable macro
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var currentUser: String? = nil

    private let sessionManager: AuthSessionManager
    private var cancellables = Set<AnyCancellable>()

    init(sessionManager: AuthSessionManager) {
        self.sessionManager = sessionManager
    }

    // ❌ CompletionHandler — wrapping a callback-based API instead of making it async
    func signIn(email: String, password: String) {
        // ❌ DispatchQueue.main.async — should be @MainActor
        DispatchQueue.main.async { self.isLoading = true }

        sessionManager.login(email: email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let token):
                    self?.isAuthenticated = true
                    self?.currentUser = email
                    print("Logged in with token: \(token)")
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // ❌ Combine sink — subscribing to a publisher instead of async sequence
    func observeAuthState(publisher: AnyPublisher<Bool, Never>) {
        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuth in
                self?.isAuthenticated = isAuth
            }
            .store(in: &cancellables)
    }
}
