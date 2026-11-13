import AppKit
import Combine
import ServiceManagement
import SwiftUI

public enum PrettyDrawApp {
    public static func run() {
        let app = NSApplication.shared
        let controller = AppController()
        app.delegate = controller
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

// The menu bar app: the status item, the global shortcut, Settings and the annotation session.
final class AppController: NSObject, NSApplicationDelegate, ObservableObject {
    let preferences = Preferences()
    @Published private(set) var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @Published private(set) var hotKeyProblem: String?
    @Published private(set) var isAnnotating = false

    private var hotKey: HotKey!
    private var statusItem: NSStatusItem!
    private var session: AnnotationSession?
    // Carried from one session to the next: each starts blank, and undo brings back what the last one ended with.
    private var drawing = Drawing()
    private var settingsWindow: NSWindow?
    private var subscriptions: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = Self.mainMenu()
        hotKey = HotKey { [weak self] in self?.toggle() }
        registerHotKey()
        preferences.$hotKey.dropFirst().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.registerHotKey() }
            .store(in: &subscriptions)
        preferences.objectWillChange.receive(on: RunLoop.main)
            .sink { [weak self] in self?.updateStatusItem() }
            .store(in: &subscriptions)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "scribble.variable", accessibilityDescription: "Pretty Draw")
        statusItem.menu = makeStatusMenu()
        updateStatusItem()

        if !Self.launchedAsLoginItem() {
            showSettings()
        }
    }

    // Opening the app again, from Spotlight or Finder, opens Settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    private static func launchedAsLoginItem() -> Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    // MARK: Annotating

    @objc func toggle() {
        if let session {
            drawing = session.end()
            self.session = nil
        } else {
            let session = AnnotationSession(preferences: preferences, drawing: drawing) { [weak self] in self?.toggle() }
            self.session = session
            session.start()
        }
        isAnnotating = session != nil
        updateStatusItem()
    }

    // MARK: Shortcut

    private func registerHotKey() {
        hotKeyProblem = hotKey.register(preferences.hotKey)
            ? nil
            : "\(preferences.hotKey.displayString) is already used by another app. Choose another shortcut."
        updateStatusItem()
    }

    // Recording a new shortcut needs the old one out of the way, or pressing it would start annotating.
    func suspendHotKey(_ suspended: Bool) {
        if suspended {
            hotKey.unregister()
        } else {
            registerHotKey()
        }
    }

    // MARK: Launch at login

    func setLaunchAtLogin(_ isOn: Bool) {
        do {
            if isOn {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Couldn't change Open at Login"
            alert.runModal()
        }
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: Menus and windows

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        let annotate = NSMenuItem(title: "Annotate Screen", action: #selector(toggle), keyEquivalent: "")
        annotate.target = self
        annotate.tag = 1
        menu.addItem(annotate)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Pretty Draw", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func updateStatusItem() {
        guard let statusItem else { return }
        statusItem.button?.contentTintColor = isAnnotating ? preferences.color.nsColor : nil
        if let item = statusItem.menu?.item(withTag: 1) {
            item.title = isAnnotating ? "Stop Annotating" : "Annotate Screen"
            let combo = preferences.hotKey
            item.keyEquivalent = combo.keyLabel.count == 1 ? combo.keyLabel.lowercased() : ""
            var mask: NSEvent.ModifierFlags = []
            if combo.modifiers.contains(.control) { mask.insert(.control) }
            if combo.modifiers.contains(.option) { mask.insert(.option) }
            if combo.modifiers.contains(.shift) { mask.insert(.shift) }
            if combo.modifiers.contains(.command) { mask.insert(.command) }
            item.keyEquivalentModifierMask = mask
        }
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(app: self)))
            window.title = "Pretty Draw"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // Edit commands for text fields in Settings. The menu bar itself never shows for this app.
    private static func mainMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        appMenu.addItem(NSMenuItem(title: "Quit Pretty Draw", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(redo)
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = edit
        main.addItem(editItem)
        return main
    }
}
