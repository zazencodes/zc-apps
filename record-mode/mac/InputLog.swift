// TEMPORARY. Here to track down the pointer trouble while recording: window drags that let go, clicks that don't
// land, lines that break. Once that's solved, delete this file, the `InputLog` lines in main.swift and its entry in
// CHANGELOG.md.
//
// While Record Mode is on it writes ~/Library/Logs/Record Mode/<start time>.log:
// - every mouse button press and release: where it was, what sent it and which windows were under it
// - pointer events that reached this app late
// - app switches
// - every few seconds, how busy the Mac was and how evenly the pointer's events arrived
// It never reads the keyboard.
import AppKit
import IOKit
import os

@MainActor
final class InputLog {
    static let shared = InputLog()

    private var session: Session?

    func setRunning(_ running: Bool, display: String) {
        if running, session == nil {
            session = Session(display: display)
        } else if !running, let session {
            session.end()
            self.session = nil
        }
    }
}

// One log file, from Record Mode turning on to it turning off.
@MainActor
private final class Session {
    // How the pointer's move and drag events arrived since the last sample.
    private struct Movement {
        var events = 0
        var latest = 0.0    // seconds, the longest an event took to get here
        var longestGap = 0.0 // seconds, between two events of one movement
        var longGaps = 0
    }

    private struct Press {
        let time: TimeInterval
        var drags = 0
    }

    private nonisolated static let sampleInterval = 5.0
    // A move or drag this late gets its own line.
    private nonisolated static let late = 0.03
    // Events further apart than this belong to separate movements.
    private nonisolated static let pause = 0.25
    private nonisolated static let longGap = 0.04

    private let file: LogFile
    private let movement = OSAllocatedUnfairLock(initialState: Movement())
    private var monitor: Any?
    private var activation: NSObjectProtocol?
    private let sampler: DispatchSourceTimer
    private var lastMove: TimeInterval?
    private var lastLateLine: TimeInterval = 0
    private var presses: [String: Press] = [:]
    private var releases: [String: TimeInterval] = [:]

    init(display: String) {
        let file = LogFile()
        self.file = file
        file.write("start  display \(display)  macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")

        let movement = self.movement
        sampler = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "com.zazencodes.recordmode.sampler", qos: .utility))
        var ticks = System.cpuTicks()
        sampler.setEventHandler {
            let now = System.cpuTicks()
            let busy = 100 * Double(now.busy - ticks.busy) / Double(max(now.total - ticks.total, 1))
            ticks = now
            let moved = movement.withLock { current in
                defer { current = Movement() }
                return current
            }
            let processes = System.processes()
            let top = processes.prefix(6).map { "\($0.name) \(Int($0.cpu))" }.joined(separator: ", ")
            file.write(
                "load  cpu \(Int(busy))%  loadavg \(String(format: "%.1f", System.loadAverage()))"
                    + "  gpu \(System.gpuUtilization().map { "\($0)%" } ?? "?")"
                    + "  thermal \(System.thermalState())  memory \(System.memoryPressure())"
                    + "  free disk \(String(format: "%.1f", System.freeDiskGB())) GB"
                    + "  recording \(processes.contains { $0.name == "screencapture" } ? "yes" : "no")"
                    + "  moves \(moved.events)  latest \(ms(moved.latest))  longest gap \(ms(moved.longestGap))"
                    + "  gaps over \(ms(Self.longGap)) \(moved.longGaps)"
                    + "  top: \(top)"
            )
        }
        sampler.schedule(deadline: .now() + Self.sampleInterval, repeating: Self.sampleInterval)
        sampler.resume()

        monitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .mouseMoved, .leftMouseDragged,
        ]) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }
        precondition(monitor != nil, "Could not watch the pointer")
        activation = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            file.write("app    \(app?.localizedName ?? "?")")
        }
    }

    func end() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let activation { NSWorkspace.shared.notificationCenter.removeObserver(activation) }
        sampler.cancel()
        file.write("stop")
        file.close()
    }

    private func handle(_ event: NSEvent) {
        let late = ProcessInfo.processInfo.systemUptime - event.timestamp
        switch event.type {
        case .mouseMoved, .leftMouseDragged:
            let gap = lastMove.map { event.timestamp - $0 }
            lastMove = event.timestamp
            movement.withLock { current in
                current.events += 1
                current.latest = max(current.latest, late)
                if let gap, gap < Self.pause {
                    current.longestGap = max(current.longestGap, gap)
                    if gap > Self.longGap { current.longGaps += 1 }
                }
            }
            if event.type == .leftMouseDragged { presses["left"]?.drags += 1 }
            if late > Self.late, event.timestamp - lastLateLine > Self.pause {
                lastLateLine = event.timestamp
                file.write("late   \(event.type == .mouseMoved ? "move" : "drag") arrived \(ms(late)) late")
            }
        case .leftMouseDown, .rightMouseDown:
            let button = event.type == .leftMouseDown ? "left" : "right"
            presses[button] = Press(time: event.timestamp)
            let sinceRelease = releases[button].map { "  \(ms(event.timestamp - $0)) after release" } ?? ""
            file.write("down   \(button)  click \(event.clickCount)\(sinceRelease)  \(describe(event, late: late, windows: true))")
        case .leftMouseUp, .rightMouseUp:
            let button = event.type == .leftMouseUp ? "left" : "right"
            let press = presses.removeValue(forKey: button)
            releases[button] = event.timestamp
            let held = press.map { "held \(ms(event.timestamp - $0.time))  drags \($0.drags)" } ?? "with no press seen"
            file.write("up     \(button)  \(held)  \(describe(event, late: late, windows: false))")
        default:
            break
        }
    }

    // Where a button event was and what sent it. For a press, also the windows under the pointer from the front, each
    // with its window level, so an overlay sitting on top of the app shows up.
    private func describe(_ event: NSEvent, late: TimeInterval, windows: Bool) -> String {
        guard let cgEvent = event.cgEvent else { return "arrived \(ms(late)) late  (no event details)" }
        let point = cgEvent.location
        let sender = pid_t(cgEvent.getIntegerValueField(.eventSourceUnixProcessID))
        var line = "at \(Int(point.x)),\(Int(point.y))  arrived \(ms(late)) late"
            + "  from \(sender == 0 ? "the mouse" : Self.name(of: sender))"
            + "  front \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?")"
        if windows { line += "  over \(Self.windows(at: point))" }
        return line
    }

    private static func name(of pid: pid_t) -> String {
        NSRunningApplication(processIdentifier: pid)?.localizedName ?? "pid \(pid)"
    }

    private static func windows(at point: CGPoint) -> String {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        let under = list.filter { window in
            guard let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds) else { return false }
            return frame.contains(point)
        }
        return under.prefix(4).map { window in
            "\(window[kCGWindowOwnerName as String] as? String ?? "?")(\(window[kCGWindowLayer as String] as? Int ?? 0))"
        }.joined(separator: " > ")
    }
}

private func ms(_ seconds: TimeInterval) -> String {
    String(format: "%.1fms", seconds * 1000)
}

// The log file. Lines are stamped when they're written and stored in order, from any thread.
private final class LogFile: @unchecked Sendable {
    private let handle: FileHandle
    private let queue = DispatchQueue(label: "com.zazencodes.recordmode.log")
    private let clock = DateFormatter()

    init() {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Record Mode")
        let name = DateFormatter()
        name.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let url = folder.appendingPathComponent("\(name.string(from: Date())).log")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data().write(to: url)
            handle = try FileHandle(forWritingTo: url)
        } catch {
            fatalError("Could not create \(url.path): \(error)")
        }
        clock.dateFormat = "HH:mm:ss.SSS"
    }

    func write(_ line: String) {
        let now = Date()
        queue.async { [self] in
            handle.write(Data("\(clock.string(from: now))  \(line)\n".utf8))
        }
    }

    func close() {
        queue.sync { try? handle.close() }
    }
}

// What the Mac is busy with.
private enum System {
    static func cpuTicks() -> (busy: UInt64, total: UInt64) {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        precondition(result == KERN_SUCCESS, "host_statistics failed")
        let (user, system, idle, nice) = info.cpu_ticks
        let busy = UInt64(user) + UInt64(system) + UInt64(nice)
        return (busy, busy + UInt64(idle))
    }

    static func loadAverage() -> Double {
        var load = [0.0]
        precondition(getloadavg(&load, 1) == 1, "getloadavg failed")
        return load[0]
    }

    // The busiest GPU, as the percentage Activity Monitor shows.
    static func gpuUtilization() -> Int? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS
        else { return nil }
        defer { IOObjectRelease(iterator) }
        var busiest: Int?
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            let statistics = IORegistryEntryCreateCFProperty(
                service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue() as? [String: Any]
            if let used = statistics?["Device Utilization %"] as? Int {
                busiest = max(busiest ?? 0, used)
            }
        }
        return busiest
    }

    static func thermalState() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }

    static func memoryPressure() -> String {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        precondition(sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0, "sysctl failed")
        switch level {
        case 1: return "normal"
        case 2: return "warning"
        case 4: return "critical"
        default: return "level \(level)"
        }
    }

    static func freeDiskGB() -> Double {
        let values = try! URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return Double(values.volumeAvailableCapacityForImportantUsage!) / 1e9
    }

    // Every process with its share of a core, busiest first.
    static func processes() -> [(cpu: Double, name: String)] {
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-Acr", "-o", "pcpu=,comm="]
        let output = Pipe()
        ps.standardOutput = output
        try! ps.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        ps.waitUntilExit()
        return String(decoding: data, as: UTF8.self).split(separator: "\n").compactMap { line in
            let fields = line.split(separator: " ", maxSplits: 1)
            guard fields.count == 2, let cpu = Double(fields[0]) else { return nil }
            return (cpu, String(fields[1]))
        }
    }
}
