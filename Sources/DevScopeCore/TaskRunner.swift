import Foundation

public enum TaskRunnerError: Error, LocalizedError, Equatable {
    case alreadyRunning, invalidScript
    public var errorDescription: String? {
        switch self {
        case .alreadyRunning: "Another script is running."
        case .invalidScript: "Select an existing regular .sh or .command file."
        }
    }
}
/// Caller must obtain an explicit user confirmation before each call to run.
public actor TaskRunner {
    private var running: Process?
    private let logDirectory: URL
    public init(logDirectory: URL) { self.logDirectory = logDirectory }
    public var isRunning: Bool { running?.isRunning ?? false }
    public static func validate(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard ["sh", "command"].contains(url.pathExtension.lowercased()),
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey]), values.isRegularFile == true else { return false }
        return FileManager.default.isReadableFile(atPath: url.path)
    }
    public func run(_ task: ScriptTask) async throws -> TaskResult {
        guard running == nil else { throw TaskRunnerError.alreadyRunning }
        guard Self.validate(path: task.path) else { throw TaskRunnerError.invalidScript }
        try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        let id = UUID(), started = Date()
        let logURL = logDirectory.appendingPathComponent("\(id.uuidString).log")
        guard FileManager.default.createFile(atPath: logURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let handle = try FileHandle(forWritingTo: logURL)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["--", task.path]
        process.currentDirectoryURL = URL(fileURLWithPath: task.path).deletingLastPathComponent()
        process.standardOutput = handle; process.standardError = handle
        running = process
        do {
            let code: Int32 = try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { completed in continuation.resume(returning: completed.terminationStatus) }
                do { try process.run() } catch { process.terminationHandler = nil; continuation.resume(throwing: error) }
            }
            try handle.close(); running = nil
            let reader = try FileHandle(forReadingFrom: logURL)
            defer { try? reader.close() }
            let data = try reader.read(upToCount: 1_048_576) ?? Data()
            let size = (try? logURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? data.count
            let output = String(decoding: data, as: UTF8.self) + (size > data.count ? "\n[Preview limited to 1 MiB; full output is in the log file.]" : "")
            return TaskResult(id: id, name: task.name, started: started, finished: Date(), exitCode: code, output: output, logURL: logURL)
        } catch {
            running = nil; try? handle.close(); throw error
        }
    }
    /// Sends SIGTERM to the script process; children may outlive their parent.
    public func stop() { running?.terminate() }
}
