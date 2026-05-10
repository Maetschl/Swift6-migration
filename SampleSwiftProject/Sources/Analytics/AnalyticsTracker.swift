import Foundation

// ✅ Analytics module — fully migrated to Swift 6

/// Tracks user events with full actor isolation.
actor AnalyticsTracker {
    private var eventQueue: [AnalyticsEvent] = []
    private let uploader: EventUploader

    init(uploader: EventUploader) {
        self.uploader = uploader
    }

    func track(_ event: AnalyticsEvent) {
        eventQueue.append(event)
    }

    func flush() async {
        guard !eventQueue.isEmpty else { return }
        let batch = eventQueue
        eventQueue.removeAll()
        await uploader.upload(batch)
    }
}

struct AnalyticsEvent: Sendable {
    let name: String
    let parameters: [String: String]
    let timestamp: Date

    init(name: String, parameters: [String: String] = [:]) {
        self.name = name
        self.parameters = parameters
        self.timestamp = Date()
    }
}
