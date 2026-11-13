import AppKit
import Combine

// All settings, saved as they change. Structured values are stored as JSON strings, which keeps them readable with
// `defaults read com.zazencodes.prettydraw`.
public final class Preferences: ObservableObject {
    // The standard fonts ship with macOS, so every Mac has them. They're always in the font list.
    public static let standardFonts = ["AvenirNext-DemiBold", "HelveticaNeue-Bold", "Menlo-Bold", "Georgia-Bold"]

    private let defaults: UserDefaults

    @Published public var tool: Tool { didSet { defaults.set(tool.rawValue, forKey: Key.tool) } }
    @Published public var colorIndex: Int { didSet { defaults.set(colorIndex, forKey: Key.colorIndex) } }
    @Published public var lineWidth: CGFloat { didSet { defaults.set(Double(lineWidth), forKey: Key.lineWidth) } }
    @Published public var lineStyles: LineStyles { didSet { saveJSON(lineStyles, forKey: Key.lineStyles) } }
    // Whether a freehand stroke that comes back around to its start closes into a smooth loop.
    @Published public var closesLoops: Bool { didSet { defaults.set(closesLoops, forKey: Key.closesLoops) } }
    // Whether annotating shows the toolbar. Without it, everything is done with keys.
    @Published public var showsToolbar: Bool { didSet { defaults.set(showsToolbar, forKey: Key.showsToolbar) } }
    @Published public var textSize: CGFloat { didSet { defaults.set(Double(textSize), forKey: Key.textSize) } }
    @Published public var fontName: String { didSet { defaults.set(fontName, forKey: Key.fontName) } }
    // Fonts added in Settings from those installed on the Mac.
    @Published public var customFonts: [String] { didSet { defaults.set(customFonts, forKey: Key.customFonts) } }
    @Published public var paletteID: String { didSet { defaults.set(paletteID, forKey: Key.paletteID) } }
    @Published public var customPalettes: [Palette] { didSet { saveJSON(customPalettes, forKey: Key.customPalettes) } }
    @Published public var hotKey: HotKeyCombo { didSet { saveJSON(hotKey, forKey: Key.hotKey) } }
    // Where the toolbar's center sits, as fractions of its display from the top left. Nil is top center.
    @Published public var toolbarPosition: CGPoint? {
        didSet {
            if let toolbarPosition {
                saveJSON(toolbarPosition, forKey: Key.toolbarPosition)
            } else {
                defaults.removeObject(forKey: Key.toolbarPosition)
            }
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.tool: Tool.freehand.rawValue,
            Key.colorIndex: 0,
            Key.lineWidth: Double(SizeSteps.defaultLineWidth),
            Key.closesLoops: true,
            Key.showsToolbar: true,
            Key.textSize: Double(SizeSteps.defaultTextSize),
            Key.fontName: Self.standardFonts[0],
            Key.customFonts: [String](),
            Key.paletteID: Palette.classic.id,
        ])

        let toolName = defaults.string(forKey: Key.tool)!
        guard let tool = Tool(rawValue: toolName) else { preconditionFailure("Unknown tool setting \(toolName)") }
        self.tool = tool
        let colorIndex = defaults.integer(forKey: Key.colorIndex)
        precondition((0..<Palette.size).contains(colorIndex), "Color setting \(colorIndex) is out of range")
        self.colorIndex = colorIndex
        lineWidth = CGFloat(defaults.double(forKey: Key.lineWidth))
        lineStyles = Self.loadJSON(defaults, Key.lineStyles) ?? .standard
        closesLoops = defaults.bool(forKey: Key.closesLoops)
        showsToolbar = defaults.bool(forKey: Key.showsToolbar)
        textSize = CGFloat(defaults.double(forKey: Key.textSize))
        let fontName = defaults.string(forKey: Key.fontName)!
        let customFonts = defaults.stringArray(forKey: Key.customFonts)!
        precondition(
            (customFonts + Self.standardFonts).contains(fontName),
            "The selected font \(fontName) isn't in the font list"
        )
        self.fontName = fontName
        self.customFonts = customFonts
        let paletteID = defaults.string(forKey: Key.paletteID)!
        let customPalettes: [Palette] = Self.loadJSON(defaults, Key.customPalettes) ?? []
        precondition(
            (Palette.builtIns + customPalettes).contains { $0.id == paletteID },
            "The selected palette \(paletteID) doesn't exist"
        )
        self.paletteID = paletteID
        self.customPalettes = customPalettes
        hotKey = Self.loadJSON(defaults, Key.hotKey) ?? .standard
        toolbarPosition = Self.loadJSON(defaults, Key.toolbarPosition)
    }

    public var palettes: [Palette] { Palette.builtIns + customPalettes }

    public var palette: Palette {
        guard let palette = palettes.first(where: { $0.id == paletteID }) else {
            preconditionFailure("The selected palette \(paletteID) doesn't exist")
        }
        return palette
    }

    public var color: PaletteColor { palette.colors[colorIndex] }

    // What a line tool draws new lines with.
    public func pen(for tool: Tool) -> Pen {
        Pen(width: lineWidth, style: lineStyles[tool])
    }

    // The size [ and ] change for this tool, and its default.
    public func size(for tool: Tool) -> CGFloat {
        tool == .text ? textSize : lineWidth
    }

    public static func defaultSize(for tool: Tool) -> CGFloat {
        tool == .text ? SizeSteps.defaultTextSize : SizeSteps.defaultLineWidth
    }

    public func setSize(_ size: CGFloat, for tool: Tool) {
        if tool == .text {
            textSize = size
        } else {
            lineWidth = size
        }
    }

    public func stepSize(for tool: Tool, up: Bool) {
        let steps = tool == .text ? SizeSteps.textSizes : SizeSteps.lineWidths
        setSize(SizeSteps.step(size(for: tool), in: steps, up: up), for: tool)
    }

    // MARK: Fonts

    // The font list in the toolbar: custom fonts first, then the standard ones.
    public var fonts: [String] { customFonts + Self.standardFonts }

    public func addCustomFont(_ postScriptName: String) {
        precondition(!fonts.contains(postScriptName), "\(postScriptName) is already in the font list")
        customFonts.append(postScriptName)
    }

    // Removing the font in use goes back to the first standard font.
    public func removeCustomFont(_ postScriptName: String) {
        guard let index = customFonts.firstIndex(of: postScriptName) else {
            preconditionFailure("\(postScriptName) isn't a custom font")
        }
        if fontName == postScriptName {
            fontName = Self.standardFonts[0]
        }
        customFonts.remove(at: index)
    }

    // MARK: Palettes

    // Adds a copy of a palette, selects it and returns it.
    @discardableResult
    public func duplicate(_ palette: Palette) -> Palette {
        let names = Set(palettes.map(\.name))
        var name = "\(palette.name) Copy"
        var number = 2
        while names.contains(name) {
            name = "\(palette.name) Copy \(number)"
            number += 1
        }
        let copy = Palette(id: UUID().uuidString, name: name, colors: palette.colors)
        customPalettes.append(copy)
        paletteID = copy.id
        return copy
    }

    public func update(_ palette: Palette) {
        guard let index = customPalettes.firstIndex(where: { $0.id == palette.id }) else {
            preconditionFailure("Only custom palettes can be changed, and \(palette.id) isn't one")
        }
        customPalettes[index] = palette
    }

    public func delete(_ palette: Palette) {
        guard let index = customPalettes.firstIndex(where: { $0.id == palette.id }) else {
            preconditionFailure("Only custom palettes can be deleted, and \(palette.id) isn't one")
        }
        if paletteID == palette.id {
            paletteID = Palette.classic.id
        }
        customPalettes.remove(at: index)
    }

    // MARK: Storage

    private enum Key {
        static let tool = "tool"
        static let colorIndex = "colorIndex"
        static let lineWidth = "lineWidth"
        static let lineStyles = "lineStyles"
        static let closesLoops = "closesLoops"
        static let showsToolbar = "showsToolbar"
        static let textSize = "textSize"
        static let fontName = "fontName"
        static let customFonts = "customFonts"
        static let paletteID = "paletteID"
        static let customPalettes = "customPalettes"
        static let hotKey = "hotKey"
        static let toolbarPosition = "toolbarPosition"
    }

    private func saveJSON<Value: Encodable>(_ value: Value, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value), let string = String(data: data, encoding: .utf8) else {
            preconditionFailure("Could not encode the \(key) setting")
        }
        defaults.set(string, forKey: key)
    }

    private static func loadJSON<Value: Decodable>(_ defaults: UserDefaults, _ key: String) -> Value? {
        guard let string = defaults.string(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(Value.self, from: Data(string.utf8))
        } catch {
            preconditionFailure("The \(key) setting is invalid: \(error)")
        }
    }
}
