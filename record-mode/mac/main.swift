// Record Mode: a menu bar toggle that switches the main display to a lighter mode for screen
// recording (1080p-looking HiDPI at 60 Hz) and back. The icon is filled while recording mode is on.
import SwiftUI
import CoreGraphics

struct DisplaySetting: Equatable {
    let width: Int        // points ("Looks like")
    let height: Int
    let pixelWidth: Int   // rendered backing pixels
    let pixelHeight: Int
    let refreshRate: Double

    static let normal = DisplaySetting(width: 3008, height: 1692, pixelWidth: 6016, pixelHeight: 3384, refreshRate: 120)
    // A 3840x2160 backing store scales down to a 1080p video exactly 2x, at about a fifth of normal's pixels per second.
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
    // Read from the display, so it stays right when the mode is changed in System Settings.
    @Published var setting = currentSetting()

    init() {
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { _ in
            Task { @MainActor in self.setting = currentSetting() }
        }
    }

    var isOn: Bool { setting == .record }

    func toggle() {
        apply(isOn ? .normal : .record)
        setting = currentSetting()
    }
}

func describe(_ setting: DisplaySetting) -> String {
    "\(setting.width)×\(setting.height) @ \(Int(setting.refreshRate)) Hz"
}

@main
struct RecordModeApp: App {
    @StateObject private var mode = RecordMode()

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
