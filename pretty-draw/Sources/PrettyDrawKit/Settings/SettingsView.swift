import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var app: AppController
    @ObservedObject var preferences: Preferences

    init(app: AppController) {
        self.app = app
        preferences = app.preferences
    }

    var body: some View {
        TabView {
            GeneralPane(app: app, preferences: preferences)
                .tabItem { Label("General", systemImage: "gearshape") }
            PalettesPane(preferences: preferences)
                .tabItem { Label("Colors", systemImage: "paintpalette") }
            FontsPane(preferences: preferences)
                .tabItem { Label("Text", systemImage: "textformat") }
        }
        .frame(width: 520, height: 430)
    }
}

private struct GeneralPane: View {
    @ObservedObject var app: AppController
    @ObservedObject var preferences: Preferences

    var body: some View {
        Form {
            Section {
                LabeledContent("Annotate shortcut") {
                    ShortcutRecorder(app: app, preferences: preferences)
                }
                if let problem = app.hotKeyProblem {
                    Text(problem).foregroundStyle(.red)
                }
                Toggle("Open at login", isOn: Binding(get: { app.launchesAtLogin }, set: { app.setLaunchAtLogin($0) }))
            } footer: {
                Text("Press \(preferences.hotKey.displayString) to start drawing over your screen, and again to clear it away. While annotating, press / to see every shortcut.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section("While annotating") {
                Toggle(isOn: $preferences.showsToolbar) {
                    Text("Show toolbar")
                    Text("Off, the screen shows only what you draw, and you choose colors, tools and sizes with keys.")
                }
            }
        }
        .formStyle(.grouped)
    }
}

// Click, then press the new shortcut. It needs ⌃, ⌥ or ⌘. Esc cancels.
private struct ShortcutRecorder: View {
    @ObservedObject var app: AppController
    @ObservedObject var preferences: Preferences
    @State private var monitor: Any?

    var body: some View {
        Button(monitor == nil ? preferences.hotKey.displayString : "Type a shortcut…") {
            monitor == nil ? startRecording() : stopRecording()
        }
        .frame(minWidth: 120)
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        app.suspendHotKey(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == 53 {
                stopRecording()
            } else if let combo = HotKeyCombo(event: event) {
                preferences.hotKey = combo
                stopRecording()
            }
            return nil
        }
    }

    private func stopRecording() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
        app.suspendHotKey(false)
    }
}

private struct PalettesPane: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        Form {
            Section {
                ForEach(preferences.palettes) { palette in
                    PaletteRow(
                        palette: palette,
                        isSelected: palette.id == preferences.paletteID,
                        select: { preferences.paletteID = palette.id }
                    )
                }
            } header: {
                Text("Palette")
            } footer: {
                Text("Keys 1 to 5 pick the selected palette's colors while annotating.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section {
                PaletteEditor(preferences: preferences, palette: preferences.palette)
                    .id(preferences.palette.id)
            }
        }
        .formStyle(.grouped)
    }
}

private struct PaletteRow: View {
    let palette: Palette
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                Text(palette.name)
                Spacer()
                Swatches(colors: palette.colors)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct Swatches: View {
    let colors: [PaletteColor]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(nsColor: color.nsColor))
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(.black.opacity(0.2)))
                    .frame(width: 18, height: 18)
            }
        }
    }
}

// Built-in palettes can only be duplicated. Copies can be renamed, recolored and deleted.
private struct PaletteEditor: View {
    @ObservedObject var preferences: Preferences
    let palette: Palette

    var body: some View {
        if palette.isBuiltIn {
            LabeledContent(palette.name) {
                Button("Duplicate to Customize") { preferences.duplicate(palette) }
            }
        } else {
            TextField("Name", text: Binding(
                get: { palette.name },
                set: { name in
                    var changed = palette
                    changed.name = name
                    preferences.update(changed)
                }
            ))
            LabeledContent("Colors") {
                HStack(spacing: 8) {
                    ForEach(0..<Palette.size, id: \.self) { index in
                        ColorPicker("Color \(index + 1)", selection: colorBinding(index), supportsOpacity: false)
                            .labelsHidden()
                    }
                }
            }
            HStack {
                Button("Duplicate") { preferences.duplicate(palette) }
                Spacer()
                Button("Delete Palette", role: .destructive) { preferences.delete(palette) }
            }
        }
    }

    private func colorBinding(_ index: Int) -> Binding<Color> {
        Binding(
            get: { Color(nsColor: palette.colors[index].nsColor) },
            set: { color in
                var changed = palette
                changed.colors[index] = PaletteColor(NSColor(color))
                preferences.update(changed)
            }
        )
    }
}

// The font list: custom fonts, added here from any font installed on the Mac, and the standard ones every Mac has.
private struct FontsPane: View {
    @ObservedObject var preferences: Preferences
    @State private var addMenu: SystemFontMenu?

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(preferences.customFonts, id: \.self) { name in
                        HStack {
                            FontName(name: name)
                            Spacer()
                            inUse(name)
                            Button {
                                preferences.removeCustomFont(name)
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Remove from the font list")
                        }
                    }
                    .onMove { preferences.customFonts.move(fromOffsets: $0, toOffset: $1) }
                }
                .frame(minHeight: 140)
                .overlay {
                    if preferences.customFonts.isEmpty {
                        Text("No custom fonts yet").foregroundStyle(.secondary)
                    }
                }
                Button("Add Font…", action: showAddMenu)
            } header: {
                Text("Custom fonts")
            } footer: {
                footer("Add any font installed on this Mac. Custom fonts come first in the font list, which the toolbar shows with the text tool. Drag to reorder.")
            }
            Section {
                ForEach(Preferences.standardFonts, id: \.self) { name in
                    HStack {
                        FontName(name: name)
                        Spacer()
                        inUse(name)
                    }
                }
            } header: {
                Text("Standard fonts")
            } footer: {
                footer("These come with every Mac and are always in the font list.")
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func inUse(_ name: String) -> some View {
        if name == preferences.fontName {
            Text("In use").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func footer(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func showAddMenu() {
        let menu = SystemFontMenu(listed: preferences.fonts) { preferences.addCustomFont($0) }
        addMenu = menu
        menu.makeMenu().popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}

// A font's name in its own face, or marked missing once it's no longer installed.
private struct FontName: View {
    let name: String

    var body: some View {
        if FontCatalog.isInstalled(name) {
            Text(FontCatalog.displayName(name)).font(Font(FontCatalog.font(name, size: 17)))
        } else {
            Text("\(name) (missing)").foregroundStyle(.secondary)
        }
    }
}
