import Foundation
import Combine

// ⚠️ GlobalMutableState — file-scope vars not concurrency-safe
var currentUserID: String = ""
var isSessionActive: Bool = false

// ⚠️ ObservableObject + @Published instead of @Observable
class HomeViewModel: ObservableObject {
    @Published var items: [String] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private var cancellables = Set<AnyCancellable>()
    private let service: DataService

    init(service: DataService) {
        self.service = service
    }

    // ⚠️ CompletionHandler instead of async/await
    func loadItems(completion: @escaping (Result<[String], Error>) -> Void) {
        // ⚠️ DispatchQueue.main.async instead of @MainActor
        DispatchQueue.main.async {
            self.isLoading = true
        }
        service.fetchItems { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let items):
                    self?.items = items
                    completion(.success(items))
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    // ⚠️ Combine sink instead of async sequence
    func bindToSearch(publisher: AnyPublisher<String, Never>) {
        publisher
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                self?.loadItems { _ in }
            }
            .store(in: &cancellables)
    }

    // ⚠️ Timer callback-based polling
    func startAutoRefresh() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.loadItems { _ in }
        }
    }

    // ⚠️ DispatchGroup instead of withTaskGroup
    func loadAllSections() {
        let group = DispatchGroup()

        group.enter()
        service.fetchItems { _ in group.leave() }

        group.enter()
        service.fetchItems { _ in group.leave() }

        group.notify(queue: .main) {
            print("All sections loaded")
        }
    }
}
