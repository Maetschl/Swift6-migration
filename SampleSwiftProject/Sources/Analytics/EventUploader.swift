import Foundation

// ✅ Fully migrated — uses async/await and actors

actor EventUploader {
    private let session: URLSession
    private let endpoint: URL

    init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    func upload(_ events: [AnalyticsEvent]) async {
        guard !events.isEmpty else { return }
        let payload = events.map { ["name": $0.name, "ts": $0.timestamp.timeIntervalSince1970.description] }
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                print("✅ \(events.count) events uploaded")
            }
        } catch {
            print("Upload error: \(error)")
        }
    }
}
