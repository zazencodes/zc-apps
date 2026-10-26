// CPU Bars: a menu bar CPU monitor. The icon shows total CPU as 1-4 bars (25% each);
// clicking it opens a panel with the top processes as a bar chart.
import SwiftUI
import Darwin

let iconRefreshSeconds = 3.0
let panelRefreshSeconds = 2.0
let topProcessCount = 10

struct ProcessUsage: Identifiable {
    let id: Int32
    let name: String
    let cpu: Double
    let memoryMB: Int
}

// Total CPU from kernel tick counters, as a delta since the previous sample.
final class CPUSampler {
    private var last = CPUSampler.ticks()

    static func ticks() -> (busy: UInt64, total: UInt64) {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        precondition(result == KERN_SUCCESS, "host_statistics failed: \(result)")
        let user = UInt64(info.cpu_ticks.0), system = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2), nice = UInt64(info.cpu_ticks.3)
        return (user + system + nice, user + system + nice + idle)
    }

    func sample() -> Double? {
        let now = CPUSampler.ticks()
        let busy = now.busy - last.busy, total = now.total - last.total
        last = now
        return total == 0 ? nil : Double(busy) / Double(total)
    }
}

func topProcesses() -> [ProcessUsage] {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/ps")
    task.arguments = ["-Aceo", "pid=,pcpu=,rss=,comm=", "-r"]
    let pipe = Pipe()
    task.standardOutput = pipe
    try! task.run()
    let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    task.waitUntilExit()
    return output.split(separator: "\n").prefix(topProcessCount).map { line in
        let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
        return ProcessUsage(id: Int32(parts[0])!, name: String(parts[3]),
                            cpu: Double(parts[1])!, memoryMB: Int(parts[2])! / 1024)
    }
}

@MainActor
final class Monitor: ObservableObject {
    // Published separately so the menu bar icon only redraws when the bar count changes.
    @Published var bars = 1
    @Published var total = 0.0
    @Published var processes: [ProcessUsage] = []
    private let sampler = CPUSampler()
    private var panelTimer: Timer?

    init() {
        Timer.scheduledTimer(withTimeInterval: iconRefreshSeconds, repeats: true) { _ in
            Task { @MainActor in self.updateTotal() }
        }
    }

    private var panelOpen: Bool { panelTimer != nil }

    func updateTotal() {
        guard let value = sampler.sample() else { return }
        let level = min(4, max(1, Int((value * 4).rounded(.up))))
        if level != bars { bars = level }
        if panelOpen { total = value }
    }

    func panelOpened() {
        processes = topProcesses()
        panelTimer = Timer.scheduledTimer(withTimeInterval: panelRefreshSeconds, repeats: true) { _ in
            Task { @MainActor in
                self.updateTotal()
                self.processes = topProcesses()
            }
        }
        updateTotal()
    }

    func panelClosed() {
        panelTimer?.invalidate()
        panelTimer = nil
    }
}

// Four rising bars; the first `level` are filled. Drawn as a template image so it matches the menu bar.
func barsIcon(level: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: 18, height: 16), flipped: false) { _ in
        let width = 3.0, gap = 1.5
        for i in 0..<4 {
            let height = 4.0 + Double(i) * 3.5
            let rect = NSRect(x: 1.5 + Double(i) * (width + gap), y: 2, width: width, height: height)
            let path = NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1)
            NSColor.black.withAlphaComponent(i < level ? 1 : 0.25).setFill()
            path.fill()
        }
        return true
    }
    image.isTemplate = true
    return image
}

func usageColor(_ fraction: Double) -> Color {
    fraction < 0.5 ? .green : fraction < 0.75 ? .yellow : .red
}

struct PanelView: View {
    @ObservedObject var monitor: Monitor
    // ps reports per-core percentages (100% is one full core); bars scale to the busiest process, at least one core.
    private var barScale: Double { max(100, monitor.processes.first?.cpu ?? 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("CPU").font(.headline)
                Spacer()
                Text(monitor.total, format: .percent.precision(.fractionLength(0)))
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
            }
            UsageBar(fraction: monitor.total, height: 8)

            Divider()

            VStack(spacing: 10) {
                ForEach(monitor.processes) { process in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(process.name).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text("\(process.memoryMB) MB").foregroundStyle(.secondary)
                            Text(String(format: "%.0f%%", process.cpu))
                                .frame(width: 44, alignment: .trailing)
                        }
                        .font(.system(size: 12))
                        .monospacedDigit()
                        UsageBar(fraction: process.cpu / barScale, height: 5)
                    }
                }
            }

            Divider()

            HStack {
                Button("Activity Monitor") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12))
        }
        .padding(16)
        .frame(width: 320)
        .onAppear { monitor.panelOpened() }
        .onDisappear { monitor.panelClosed() }
    }
}

struct UsageBar: View {
    let fraction: Double
    let height: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(usageColor(fraction).gradient)
                    .frame(width: max(height, geometry.size.width * min(1, fraction)))
            }
        }
        .frame(height: height)
        .animation(.smooth, value: fraction)
    }
}

@main
struct CPUBarsApp: App {
    @StateObject private var monitor = Monitor()

    var body: some Scene {
        MenuBarExtra {
            PanelView(monitor: monitor)
        } label: {
            Image(nsImage: barsIcon(level: monitor.bars))
        }
        .menuBarExtraStyle(.window)
    }
}
