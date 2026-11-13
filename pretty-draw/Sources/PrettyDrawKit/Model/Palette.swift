import AppKit

// One opaque color, stored as Display P3 components so wide-gamut colors survive exactly.
public struct PaletteColor: Codable, Equatable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init(hex: Int) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    public init(_ color: NSColor) {
        guard let p3 = color.usingColorSpace(.displayP3) else {
            preconditionFailure("\(color) has no Display P3 equivalent")
        }
        self.init(
            red: Self.clamped(p3.redComponent),
            green: Self.clamped(p3.greenComponent),
            blue: Self.clamped(p3.blueComponent)
        )
    }

    public var nsColor: NSColor {
        NSColor(displayP3Red: red, green: green, blue: blue, alpha: 1)
    }

    public var cgColor: CGColor { nsColor.cgColor }

    // Relative luminance, used to pick legible ink on top of the color.
    public var isLight: Bool {
        let srgb = nsColor.usingColorSpace(.sRGB)!
        let luminance = 0.2126 * srgb.redComponent + 0.7152 * srgb.greenComponent + 0.0722 * srgb.blueComponent
        return luminance > 0.55
    }

    private static func clamped(_ value: CGFloat) -> Double {
        min(max(Double(value), 0), 1)
    }
}

// Five colors, chosen with keys 1 to 5.
public struct Palette: Codable, Equatable, Identifiable {
    public static let size = 5

    public var id: String
    public var name: String
    public var colors: [PaletteColor]

    public init(id: String, name: String, colors: [PaletteColor]) {
        precondition(colors.count == Self.size, "A palette has exactly \(Self.size) colors")
        self.id = id
        self.name = name
        self.colors = colors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colors = try container.decode([PaletteColor].self, forKey: .colors)
        guard colors.count == Self.size else {
            throw DecodingError.dataCorruptedError(
                forKey: .colors, in: container, debugDescription: "A palette has exactly \(Self.size) colors"
            )
        }
    }

    public var isBuiltIn: Bool {
        Self.builtIns.contains { $0.id == id }
    }

    // The palette everyone starts with.
    public static let classic = Palette(id: "classic", name: "Classic", colors: [
        PaletteColor(hex: 0xFF3B30),
        PaletteColor(hex: 0xFFCC00),
        PaletteColor(hex: 0x34C759),
        PaletteColor(hex: 0x0A84FF),
        PaletteColor(hex: 0xFFFFFF),
    ])

    public static let pastel = Palette(id: "pastel", name: "Pastel", colors: [
        PaletteColor(hex: 0xFF8A80),
        PaletteColor(hex: 0xFFE082),
        PaletteColor(hex: 0xA5D6A7),
        PaletteColor(hex: 0x90CAF9),
        PaletteColor(hex: 0xCE93D8),
    ])

    public static let neon = Palette(id: "neon", name: "Neon", colors: [
        PaletteColor(red: 1.0, green: 0.16, blue: 0.55),
        PaletteColor(red: 1.0, green: 0.92, blue: 0.0),
        PaletteColor(red: 0.2, green: 1.0, blue: 0.35),
        PaletteColor(red: 0.0, green: 0.85, blue: 1.0),
        PaletteColor(red: 0.62, green: 0.3, blue: 1.0),
    ])

    public static let builtIns = [classic, pastel, neon]
}
