import Foundation

// ✅ Fully migrated — pure Swift extensions, no concurrency concerns

extension String {
    var isValidEmail: Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    func truncated(to length: Int, suffix: String = "…") -> String {
        count > length ? String(prefix(length)) + suffix : self
    }
}

extension Date {
    var isToday: Bool { Calendar.current.isDateInToday(self) }
    var isYesterday: Bool { Calendar.current.isDateInYesterday(self) }

    func formatted(style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        return formatter.string(from: self)
    }
}

extension Collection {
    var isNotEmpty: Bool { !isEmpty }

    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(dropFirst($0).prefix(size))
        }
    }
}

extension Optional {
    func orThrow(_ error: Error) throws -> Wrapped {
        guard let value = self else { throw error }
        return value
    }
}
