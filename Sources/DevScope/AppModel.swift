import SwiftUI
import DevScopeCore

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshot: SystemSnapshot?
    @Published var cpuHistory: [Double] = []
    @Published var tasks: [ScriptTask] = []
    @Published var results: [TaskResult] = []
    @Published var runningID: UUID?
    @Published var error: String?
    @Published var interval: Double { didSet { UserDefaults.standard.set(interval, forKey: "pollInterval") } }
    @Published var darkMode: Bool { didSet { UserDefaults.standard.set(darkMode, forKey: "darkMode") } }
    private let monitor = MonitoringService()
    private let runner: TaskRunner
    private var loop: Task<Void, Never>?
    let logDirectory: URL
    init() {
        let saved = UserDefaults.standard.double(forKey: "pollInterval")
        interval = saved >= 1 && saved <= 10 ? saved : 2
        darkMode = UserDefaults.standard.object(forKey: "darkMode") as? Bool ?? true
        logDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DevScope/logs")
        runner = TaskRunner(logDirectory: logDirectory)
        if let data = UserDefaults.standard.data(forKey: "scriptTasks"), let decoded = try? JSONDecoder().decode([ScriptTask].self, from: data) { tasks = decoded }
    }
    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    let value = try await monitor.sample()
                    snapshot = value
                    if let cpu = value.cpuPercent { cpuHistory.append(cpu); if cpuHistory.count > 60 { cpuHistory.removeFirst() } }
                } catch { self.error = "Monitoring failed: \(error.localizedDescription)" }
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }
    func addScript() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        panel.message = "Choose a shell script. Running it will require confirmation."
        if panel.runModal() == .OK, let url = panel.url {
            guard TaskRunner.validate(path: url.path) else { error = TaskRunnerError.invalidScript.localizedDescription; return }
            tasks.append(ScriptTask(name: url.deletingPathExtension().lastPathComponent, path: url.path)); saveTasks()
        }
    }
    func remove(_ task: ScriptTask) { tasks.removeAll { $0.id == task.id }; saveTasks() }
    private func saveTasks() { if let data = try? JSONEncoder().encode(tasks) { UserDefaults.standard.set(data, forKey: "scriptTasks") } }
    func runConfirmed(_ task: ScriptTask) {
        guard runningID == nil else { return }
        runningID = task.id
        Task {
            defer { runningID = nil }
            do { let result = try await runner.run(task); results.insert(result, at: 0); if results.count > 50 { results.removeLast() } }
            catch { self.error = error.localizedDescription }
        }
    }
    func stop() { Task { await runner.stop() } }
}
