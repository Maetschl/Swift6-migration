import Foundation
import Combine

// ❌ ObservableObject — should be @Observable
class FeedViewModel: ObservableObject {
    @Published var posts: [String] = []
    @Published var isLoadingMore: Bool = false
    @Published var currentPage: Int = 0

    private var cancellables = Set<AnyCancellable>()

    // ❌ DispatchGroup — should use withTaskGroup
    func fetchAllFeeds() {
        let group = DispatchGroup()
        var allPosts: [String] = []

        group.enter()
        DispatchQueue.global().async {
            allPosts.append(contentsOf: ["Post A1", "Post A2"])
            group.leave()
        }

        group.enter()
        DispatchQueue.global().async {
            allPosts.append(contentsOf: ["Post B1", "Post B2"])
            group.leave()
        }

        group.enter()
        DispatchQueue.global().async {
            allPosts.append(contentsOf: ["Post C1", "Post C2"])
            group.leave()
        }

        // ❌ DispatchQueue.main in group.notify
        group.notify(queue: .main) {
            self.posts = allPosts
        }
    }

    // ❌ CompletionHandler
    func loadNextPage(completion: @escaping ([String]) -> Void) {
        isLoadingMore = true
        DispatchQueue.global(qos: .userInitiated).async {
            let newPosts = ["Post \(self.currentPage + 1)A", "Post \(self.currentPage + 1)B"]
            DispatchQueue.main.async {
                self.posts.append(contentsOf: newPosts)
                self.currentPage += 1
                self.isLoadingMore = false
                completion(newPosts)
            }
        }
    }
}
