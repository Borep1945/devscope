import Foundation

public struct ProcessRow: Identifiable, Sendable, Equatable {
    public let id: Int
    public let cpu: Double
    public let memoryBytes: UInt64
    public let command: String
    public init(id: Int, cpu: Double, memoryBytes: UInt64, command: String) {
        self.id = id; self.cpu = cpu; self.memoryBytes = memoryBytes; self.command = command
    }
}
public struct SystemSnapshot: Sendable {
    public let timestamp: Date
    public let cpuPercent: Double?
    public let memoryUsed: UInt64
    public let memoryTotal: UInt64
    public let diskAvailable: Int64?
    public let processes: [ProcessRow]
}
public struct ScriptTask: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var path: String
    public init(id: UUID = UUID(), name: String, path: String) { self.id = id; self.name = name; self.path = path }
}
public struct TaskResult: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let started: Date
    public let finished: Date
    public let exitCode: Int32
    public let output: String
    public let logURL: URL
}
public enum ProcessParser {
    /// ps: PID, CPU percent, RSS in KiB, then command (possibly containing spaces).
    public static func parse(_ text: String) -> [ProcessRow] {
        text.split(separator: "\n").compactMap { line in
            let fields = line.split(maxSplits: 3, omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
            guard fields.count == 4, let pid = Int(fields[0]), pid > 0,
                  let cpu = Double(fields[1]), cpu.isFinite, cpu >= 0,
                  let rss = UInt64(fields[2]), rss <= UInt64.max / 1024 else { return nil }
            return ProcessRow(id: pid, cpu: cpu, memoryBytes: rss * 1024, command: String(fields[3]))
        }.sorted { $0.cpu == $1.cpu ? $0.id < $1.id : $0.cpu > $1.cpu }
    }
}
public enum CPUDelta {
    /// Unsigned wrapping subtraction handles 32-bit host counter wraparound.
    public static func percentage(previous: [UInt32], current: [UInt32]) -> Double? {
        guard previous.count == 4, current.count == 4 else { return nil }
        let delta = zip(previous, current).map { UInt64($1 &- $0) }
        let total = delta.reduce(0, +)
        guard total > 0 else { return nil }
        return 100 * Double(total - delta[2]) / Double(total)
    }
}
