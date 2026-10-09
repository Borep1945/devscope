import SwiftUI
import AppKit
import DevScopeCore

@main
struct DevScopeApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup("DevScope") {
            ContentView().environmentObject(model)
                .frame(minWidth: 1000, minHeight: 680)
                .preferredColorScheme(model.darkMode ? .dark : .light)
                .onAppear { NSApplication.shared.setActivationPolicy(.regular); NSApplication.shared.activate(ignoringOtherApps: true); model.start() }
        }
        .windowStyle(.hiddenTitleBar)
    }
}
struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var section = "Overview"
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 28) {
                HStack { Image(systemName: "terminal.fill").foregroundStyle(.mint); Text("DevScope").font(.title2.bold()) }
                Text("DEVELOPER CONTROL CENTER").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
                ForEach([("Overview", "chart.xyaxis.line"), ("Tasks", "play.rectangle"), ("Settings", "slider.horizontal.3")], id: \.0) { label, icon in
                    Button { section = label } label: {
                        Label(label, systemImage: icon).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                            .background(section == label ? Color.mint.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain).focusable(false)
                }
                Spacer()
                Label("Local workspace", systemImage: "desktopcomputer").font(.caption).foregroundStyle(.secondary)
                Text("macOS · Local device").font(.caption2).foregroundStyle(.secondary)
            }.padding(24).navigationSplitViewColumnWidth(240)
        } detail: {
            ScrollView { VStack(alignment: .leading, spacing: 26) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section == "Overview" ? "Your machine, at a glance." : section).font(.system(size: 30, weight: .bold))
                        Text(section == "Overview" ? "Live system signals and the processes behind them." : section == "Tasks" ? "Run local scripts with an explicit confirmation." : "Tune your workspace.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label("\(Int(model.interval))s refresh", systemImage: "circle.fill").font(.caption).foregroundStyle(.mint)
                }
                if section == "Overview" { OverviewView() }
                else if section == "Tasks" { TasksView() }
                else { SettingsView() }
            }.padding(32) }.background(Color(nsColor: .windowBackgroundColor))
        }
        .alert("DevScope", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
}
private func bytes(_ value: UInt64) -> String { ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .memory) }
struct MetricCard: View {
    let title: String, value: String, detail: String, icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text(title).font(.caption).foregroundStyle(.secondary); Spacer(); Image(systemName: icon).foregroundStyle(.mint) }
            Text(value).font(.system(size: 29, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
    }
}
struct OverviewView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        if let snapshot = model.snapshot {
            HStack(spacing: 16) {
                MetricCard(title: "CPU UTILIZATION", value: snapshot.cpuPercent.map { String(format: "%.1f%%", $0) } ?? "Sampling…", detail: "Across \(ProcessInfo.processInfo.activeProcessorCount) logical cores", icon: "cpu")
                MetricCard(title: "MEMORY IN USE", value: bytes(snapshot.memoryUsed), detail: "\(bytes(snapshot.memoryTotal)) physical · total minus free", icon: "memorychip")
                MetricCard(title: "DISK AVAILABLE", value: snapshot.diskAvailable.map { bytes(UInt64(max(0, $0))) } ?? "Unavailable", detail: "Home volume · important usage estimate", icon: "internaldrive")
            }
            VStack(alignment: .leading, spacing: 18) {
                HStack { Text("CPU activity").font(.headline); Spacer(); Text("LAST 60 SAMPLES").font(.caption2.monospaced()).foregroundStyle(.secondary) }
                Canvas { context, size in
                    for fraction in [0.0, 0.25, 0.5, 0.75, 1.0] {
                        var grid = Path(); grid.move(to: CGPoint(x: 0, y: size.height * fraction)); grid.addLine(to: CGPoint(x: size.width, y: size.height * fraction)); context.stroke(grid, with: .color(.gray.opacity(0.15)), lineWidth: 1)
                    }
                    guard model.cpuHistory.count > 1 else { return }
                    var path = Path()
                    for (index, value) in model.cpuHistory.enumerated() {
                        let point = CGPoint(x: size.width * Double(index) / Double(model.cpuHistory.count - 1), y: size.height * (1 - min(100, max(0, value)) / 100))
                        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    context.stroke(path, with: .color(.mint), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                }.frame(height: 130)
                HStack { Text("0%"); Spacer(); Text("100% scale") }.font(.caption2).foregroundStyle(.secondary)
            }.padding(22).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 16) {
                HStack { Text("Active processes").font(.headline); Spacer(); Text("TOP 30 · SORTED BY CPU").font(.caption2.monospaced()).foregroundStyle(.secondary) }
                HStack { Text("PROCESS / PID"); Spacer(); Text("CPU").frame(width: 70, alignment: .trailing); Text("MEMORY").frame(width: 100, alignment: .trailing) }.font(.caption2).foregroundStyle(.secondary)
                ForEach(snapshot.processes) { process in
                    HStack {
                        VStack(alignment: .leading) { Text(URL(fileURLWithPath: process.command).lastPathComponent).lineLimit(1); Text("PID \(process.id)").font(.caption2).foregroundStyle(.secondary) }
                        Spacer(); Text(String(format: "%.1f%%", process.cpu)).monospacedDigit().frame(width: 70, alignment: .trailing)
                        Text(bytes(process.memoryBytes)).monospacedDigit().frame(width: 100, alignment: .trailing)
                    }.font(.caption).padding(.vertical, 4)
                    Divider()
                }
            }.padding(22).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            Text("Updated \(snapshot.timestamp.formatted(date: .omitted, time: .standard)) · Process CPU may exceed 100% for multicore workloads.").font(.caption).foregroundStyle(.secondary)
        } else { ProgressView("Reading system metrics…").frame(maxWidth: .infinity, minHeight: 300) }
    }
}
struct TasksView: View {
    @EnvironmentObject private var model: AppModel
    @State private var pending: ScriptTask?
    @State private var selectedLog: TaskResult?
    var body: some View {
        HStack { Text("Saved scripts").font(.headline); Spacer(); Button("Add script", systemImage: "plus") { model.addScript() } }
        if model.tasks.isEmpty { ContentUnavailableViewCompat() }
        ForEach(model.tasks) { task in
            HStack {
                Image(systemName: "terminal").foregroundStyle(.mint)
                VStack(alignment: .leading, spacing: 6) { Text(task.name).font(.headline); Text(task.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                Spacer()
                if model.runningID == task.id { ProgressView().controlSize(.small); Button("Stop") { model.stop() } }
                else { Button("Run") { pending = task }.disabled(model.runningID != nil) }
                Button { model.remove(task) } label: { Image(systemName: "trash") }.disabled(model.runningID == task.id)
            }.padding(20).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        }
        Text("Recent runs").font(.headline)
        if model.results.isEmpty { Text("Completed runs appear here. Full logs are kept in Application Support.").foregroundStyle(.secondary) }
        ForEach(model.results) { result in
            Button { selectedLog = result } label: {
                HStack { Image(systemName: result.exitCode == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill").foregroundStyle(result.exitCode == 0 ? .mint : .orange); Text(result.name); Spacer(); Text("exit \(result.exitCode)").font(.caption.monospaced()); Text(result.finished.formatted(date: .omitted, time: .shortened)).foregroundStyle(.secondary) }.padding(14)
            }.buttonStyle(.plain)
        }
        Color.clear.frame(height: 1)
            .sheet(item: $pending) { task in
                VStack(alignment: .leading, spacing: 20) {
                    Text("Run \(task.name)?").font(.title2.bold())
                    Text("This script runs with your user account permissions and can change files or contact services. Review its contents before running.")
                    Text(task.path).font(.caption.monospaced()).textSelection(.enabled)
                    HStack { Button("Open script") { NSWorkspace.shared.open(URL(fileURLWithPath: task.path)) }; Spacer(); Button("Cancel") { pending = nil }; Button("Run script") { pending = nil; model.runConfirmed(task) }.buttonStyle(.borderedProminent).tint(.mint) }
                }.padding(30).frame(width: 560)
            }
            .sheet(item: $selectedLog) { result in
                VStack(alignment: .leading, spacing: 16) {
                    HStack { Text(result.name).font(.title2.bold()); Spacer(); Button("Close") { selectedLog = nil } }
                    Text("Exit \(result.exitCode) · \(String(format: "%.2f", result.finished.timeIntervalSince(result.started))) seconds").foregroundStyle(.secondary)
                    ScrollView { Text(result.output.isEmpty ? "No output." : result.output).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(minHeight: 300)
                    Button("Reveal full log") { NSWorkspace.shared.activateFileViewerSelecting([result.logURL]) }
                }.padding(24).frame(width: 720, height: 480)
            }
    }
}
struct ContentUnavailableViewCompat: View {
    var body: some View { VStack(spacing: 12) { Image(systemName: "terminal").font(.largeTitle).foregroundStyle(.mint); Text("Add your first local script").font(.headline); Text("Build, test or inspect a workspace from one place.").foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(36) }
}
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Toggle("Dark appearance", isOn: $model.darkMode)
            VStack(alignment: .leading) { Text("Refresh interval: \(Int(model.interval)) seconds"); Slider(value: $model.interval, in: 1...10, step: 1); Text("Longer intervals reduce monitoring overhead.").font(.caption).foregroundStyle(.secondary) }
            Divider()
            Text("Logs").font(.headline)
            Text(model.logDirectory.path).font(.caption.monospaced()).textSelection(.enabled)
            Button("Open log folder") { try? FileManager.default.createDirectory(at: model.logDirectory, withIntermediateDirectories: true); NSWorkspace.shared.open(model.logDirectory) }
            Text("Saved scripts and settings stay in UserDefaults. Recent run summaries last for this session; log files persist until you delete them. DevScope does not send telemetry.").foregroundStyle(.secondary)
        }.padding(24).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
    }
}
