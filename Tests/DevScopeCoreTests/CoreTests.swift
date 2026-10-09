import Testing
import Foundation
@testable import DevScopeCore

struct CoreTests {
    @Test func processParsingPreservesCommandAndSortsCPU() {
        let rows = ProcessParser.parse(" 42 12.5 2048 /Applications/My App/helper\n 9 120.0 4 /bin/worker\n")
        #expect(rows.count == 2); #expect(rows[0].id == 9)
        #expect(rows[1].memoryBytes == 2_097_152)
        #expect(rows[1].command == "/Applications/My App/helper")
    }
    @Test func processParserRejectsMalformedAndOverflow() {
        #expect(ProcessParser.parse("bad\n-2 1.0 4 /bad\n3 nan 4 /bad\n4 1.0 18446744073709551615 /bad\n5 -1 4 /bad").isEmpty)
    }
    @Test func cpuDeltaAndIdle() {
        #expect(CPUDelta.percentage(previous: [10, 20, 30, 40], current: [20, 30, 100, 50]) == 30)
        #expect(CPUDelta.percentage(previous: [1, 2, 3, 4], current: [1, 2, 3, 4]) == nil)
        #expect(CPUDelta.percentage(previous: [], current: []) == nil)
    }
    @Test func counterWrap() {
        #expect(CPUDelta.percentage(previous: [UInt32.max - 2, 0, 0, 0], current: [2, 0, 5, 0]) == 50)
    }
    @Test func scriptTaskCodable() throws {
        let task = ScriptTask(name: "Build", path: "/tmp/build.sh")
        #expect(try JSONDecoder().decode(ScriptTask.self, from: JSONEncoder().encode(task)) == task)
    }
    @Test func scriptRunnerOutputExitCodeAndPersistentLog() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let script = directory.appendingPathComponent("script with spaces.sh")
        try "print 'stdout verified'\nprint -u2 'stderr verified'\nexit 7\n".write(to: script, atomically: true, encoding: .utf8)
        let runner = TaskRunner(logDirectory: directory.appendingPathComponent("logs"))
        let result = try await runner.run(ScriptTask(name: "Test", path: script.path))
        #expect(result.exitCode == 7)
        #expect(result.output.contains("stdout verified")); #expect(result.output.contains("stderr verified"))
        #expect(try String(contentsOf: result.logURL, encoding: .utf8) == result.output)
    }
    @Test func runnerRejectsInvalidScript() async {
        #expect(!TaskRunner.validate(path: "/bin/ls"))
        let runner = TaskRunner(logDirectory: FileManager.default.temporaryDirectory)
        do { _ = try await runner.run(ScriptTask(name: "Missing", path: "/missing/task.sh")); Issue.record("Expected validation failure") }
        catch { #expect(error is TaskRunnerError) }
    }
    @Test func runnerStopsAndRejectsConcurrentExecution() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let script = directory.appendingPathComponent("sleep.sh")
        try "exec /bin/sleep 30\n".write(to: script, atomically: true, encoding: .utf8)
        let runner = TaskRunner(logDirectory: directory.appendingPathComponent("logs"))
        let task = ScriptTask(name: "Sleep", path: script.path)
        let first = Task { try await runner.run(task) }
        for _ in 0..<100 {
            if await runner.isRunning { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(await runner.isRunning)
        do { _ = try await runner.run(task); Issue.record("Expected concurrent run rejection") }
        catch { #expect(error as? TaskRunnerError == .alreadyRunning) }
        await runner.stop()
        let result = try await first.value
        #expect(result.exitCode != 0)
        #expect(result.finished.timeIntervalSince(result.started) < 5)
        #expect(await runner.isRunning == false)
    }
    @Test func liveSystemSampler() async throws {
        let monitor = MonitoringService()
        let first = try await monitor.sample()
        #expect(first.memoryTotal > 0)
        #expect(first.memoryUsed <= first.memoryTotal)
        #expect(!first.processes.isEmpty)
        #expect(first.cpuPercent == nil)
        let second = try await monitor.sample()
        if let cpu = second.cpuPercent { #expect((0...100).contains(cpu)) }
    }
}
