// Record Mode: a menu bar toggle that switches the main display to a lighter mode for screen
// recording (1080p-looking HiDPI at 60 Hz) and back. The icon is filled while recording mode is on.
import SwiftUI
import CoreGraphics

// ZazenCodes (alex@zazencodes.com). Keep the recording tabs together for easy updates.
func openRecordingTabs() throws {
    let chrome = Process()
    chrome.executableURL = URL(fileURLWithPath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
    // Launch directly so Chrome creates the window on the current Space before activating.
    chrome.arguments = [
        "--profile-directory=Profile 4",
        "--new-window",
        "https://zazencodes.com/newsletter",
        "https://www.skool.com/zazencodes-agentic-coding-club-7823",
        "https://zazencodes.com/courses/agentic-coding-fundamentals",
    ]
    try chrome.run()
}

struct DisplaySetting: Equatable {
    let width: Int        // points ("Looks like")
    let height: Int
    let pixelWidth: Int   // rendered backing pixels
    let pixelHeight: Int
    let refreshRate: Double

    static let normal = DisplaySetting(width: 3008, height: 1692, pixelWidth: 6016, pixelHeight: 3384, refreshRate: 120)
    // A 3840x2160 backing store scales down to a 1080p video exactly 2x. Recordings are 60 fps, so 60 Hz gives the
    // video every frame it can use for half the drawing of 120 Hz.
    static let record = DisplaySetting(width: 1920, height: 1080, pixelWidth: 3840, pixelHeight: 2160, refreshRate: 60)

    init(width: Int, height: Int, pixelWidth: Int, pixelHeight: Int, refreshRate: Double) {
        self.width = width
        self.height = height
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.refreshRate = refreshRate
    }

    init(_ mode: CGDisplayMode) {
        self.init(width: mode.width, height: mode.height, pixelWidth: mode.pixelWidth,
                  pixelHeight: mode.pixelHeight, refreshRate: mode.refreshRate)
    }
}

func currentSetting() -> DisplaySetting {
    DisplaySetting(CGDisplayCopyDisplayMode(CGMainDisplayID())!)
}

func apply(_ setting: DisplaySetting) {
    let display = CGMainDisplayID()
    let options = [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
    let modes = CGDisplayCopyAllDisplayModes(display, options) as! [CGDisplayMode]
    guard let mode = modes.first(where: { DisplaySetting($0) == setting }) else {
        fatalError("Main display has no mode \(setting)")
    }
    var config: CGDisplayConfigRef?
    precondition(CGBeginDisplayConfiguration(&config) == .success, "CGBeginDisplayConfiguration failed")
    precondition(CGConfigureDisplayWithDisplayMode(config, display, mode, nil) == .success,
                 "CGConfigureDisplayWithDisplayMode failed")
    precondition(CGCompleteDisplayConfiguration(config, .permanently) == .success,
                 "CGCompleteDisplayConfiguration failed")
}

@MainActor
final class RecordMode: ObservableObject {
    static let shared = RecordMode()

    // Read from the display, so it stays right when the mode is changed in System Settings.
    @Published var setting = currentSetting() {
        didSet { InputLog.shared.setRunning(isOn, display: describe(setting)) }
    }

    init() {
        InputLog.shared.setRunning(isOn, display: describe(setting))
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { _ in
            Task { @MainActor in self.setting = currentSetting() }
        }
    }

    var isOn: Bool { setting == .record }

    func toggle() { set(on: !isOn) }

    // Does nothing when the mode is already as asked, so `recordmode://on` never opens duplicate tabs.
    func set(on: Bool) {
        guard on != isOn else { return }
        apply(on ? .record : .normal)
        setting = currentSetting()
        if on {
            let image = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/space-1080p.jpeg")
            NSWorkspace.shared.open(image)
            do {
                try openRecordingTabs()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Could not open recording tabs"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }
}

func describe(_ setting: DisplaySetting) -> String {
    "\(setting.width)×\(setting.height) @ \(Int(setting.refreshRate)) Hz"
}

// Scripts switch the mode with `open recordmode://on` and `open recordmode://off`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            switch url.host {
            case "on": RecordMode.shared.set(on: true)
            case "off": RecordMode.shared.set(on: false)
            default:
                let alert = NSAlert()
                alert.messageText = "Unknown Record Mode URL"
                alert.informativeText = "\(url.absoluteString)\nUse recordmode://on or recordmode://off."
                alert.runModal()
            }
        }
    }
}

@main
struct RecordModeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var mode = RecordMode.shared

    var body: some Scene {
        MenuBarExtra {
            Button(mode.isOn ? "Turn Off Record Mode" : "Turn On Record Mode") { mode.toggle() }
            Text("Now: \(describe(mode.setting))")
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: mode.isOn ? "record.circle.fill" : "record.circle")
        }
    }
}
