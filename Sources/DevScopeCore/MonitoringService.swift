import Foundation
import Darwin

public actor MonitoringService {
    private var previousTicks: [UInt32]?
    public init() {}
    public func sample() throws -> SystemSnapshot {
        let ticks = try cpuTicks()
        let cpu = previousTicks.flatMap { CPUDelta.percentage(previous: $0, current: ticks) }
        previousTicks = ticks
        let total = ProcessInfo.processInfo.physicalMemory
        let free = try freeMemory()
        let disk = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
        let processes = try processList()
        return SystemSnapshot(timestamp: Date(), cpuPercent: cpu, memoryUsed: total - min(total, free), memoryTotal: total, diskAvailable: disk, processes: Array(processes.prefix(30)))
    }
    private func cpuTicks() throws -> [UInt32] {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { throw MonitoringError.kernel(result) }
        return [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3]
    }
    private func freeMemory() throws -> UInt64 {
        var info = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { throw MonitoringError.kernel(result) }
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { throw MonitoringError.pageSize }
        return UInt64(info.free_count) * UInt64(pageSize)
    }
    private func processList() throws -> [ProcessRow] {
        let process = Process(); let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,pcpu=,rss=,comm="]
        process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw MonitoringError.processList }
        return ProcessParser.parse(String(decoding: data, as: UTF8.self))
    }
}
public enum MonitoringError: Error { case kernel(kern_return_t), pageSize, processList }
