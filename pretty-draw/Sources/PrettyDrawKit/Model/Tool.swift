import Foundation

public enum Tool: String, CaseIterable, Codable, Identifiable {
    case freehand, arrow, rectangle, text

    public var id: Self { self }

    // The key that selects the tool, as in Presentify.
    public var key: Character {
        switch self {
        case .freehand: "f"
        case .arrow: "a"
        case .rectangle: "r"
        case .text: "t"
        }
    }

    public var title: String {
        switch self {
        case .freehand: "Freehand"
        case .arrow: "Arrow"
        case .rectangle: "Rectangle"
        case .text: "Text"
        }
    }

    public var symbolName: String {
        switch self {
        case .freehand: "scribble.variable"
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .text: "textformat"
        }
    }
}

// The steps [ and ] move through, and the defaults they start from.
public enum SizeSteps {
    public static let defaultLineWidth: CGFloat = 11
    public static let defaultTextSize: CGFloat = 40

    public static let lineWidths: [CGFloat] = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 24, 28, 32]
    public static let textSizes: [CGFloat] = [14, 16, 18, 20, 24, 28, 32, 36, 40, 48, 56, 64, 72, 88, 104, 128]

    // The next step up or down from a value, which needn't be one of the steps itself.
    public static func step(_ value: CGFloat, in steps: [CGFloat], up: Bool) -> CGFloat {
        if up {
            return steps.first { $0 > value } ?? steps.last!
        }
        return steps.last { $0 < value } ?? steps.first!
    }
}
