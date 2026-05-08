public struct Finding: Codable, Sendable {
    public let file: String
    public let line: Int
    public let column: Int
    public let severity: Severity
    public let rule: String
    public let message: String

    public init(file: String, line: Int, column: Int = 0, severity: Severity, rule: String, message: String) {
        self.file = file
        self.line = line
        self.column = column
        self.severity = severity
        self.rule = rule
        self.message = message
    }

    public var location: String { "\(file):\(line)" }
}
