public enum Severity: String, Codable, Sendable {
    case info
    case warning
    case error

    var badge: String {
        switch self {
        case .info:    return "ℹ️"
        case .warning: return "⚠️"
        case .error:   return "🔴"
        }
    }

    var htmlClass: String {
        switch self {
        case .info:    return "info"
        case .warning: return "warning"
        case .error:   return "error"
        }
    }
}
