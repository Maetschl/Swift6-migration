public struct Finding: Codable, Sendable {
    public let file: String
    public let line: Int
    public let column: Int
    public let severity: Severity
    public let rule: String
    public let message: String
    /// An optional, structured fix suggestion. When present, reporters may display
    /// it alongside the `message` (e.g. as a separate "Fix" column in Markdown or
    /// as an appended note in the Xcode format). `nil` means no fix is provided.
    public let fix: String?

    public init(
        file: String,
        line: Int,
        column: Int = 0,
        severity: Severity,
        rule: String,
        message: String,
        fix: String? = nil
    ) {
        self.file = file
        self.line = line
        self.column = column
        self.severity = severity
        self.rule = rule
        self.message = message
        self.fix = fix
    }

    public var location: String { "\(file):\(line)" }
}
