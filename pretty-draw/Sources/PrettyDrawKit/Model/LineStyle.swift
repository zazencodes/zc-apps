import CoreGraphics

// How lines look: freehand strokes, arrows and rectangles. Each of those tools has its own style, chosen in the toolbar,
// and each mark keeps the style it was drawn in.
public enum LineStyle: String, CaseIterable, Codable, Identifiable {
    // Even lines with round ends.
    case clean
    // Marker ink that swells and thins like a real pen, with shapes sketched the way a quick hand draws them.
    case handDrawn

    public var id: Self { self }

    public var title: String {
        switch self {
        case .clean: "Clean"
        case .handDrawn: "Hand-drawn"
        }
    }
}

// The style each line tool draws with.
public struct LineStyles: Codable, Equatable {
    public var freehand: LineStyle
    public var arrow: LineStyle
    public var rectangle: LineStyle

    public static let standard = LineStyles(freehand: .clean, arrow: .clean, rectangle: .clean)

    public init(freehand: LineStyle, arrow: LineStyle, rectangle: LineStyle) {
        self.freehand = freehand
        self.arrow = arrow
        self.rectangle = rectangle
    }

    public subscript(tool: Tool) -> LineStyle {
        get {
            switch tool {
            case .freehand: freehand
            case .arrow: arrow
            case .rectangle: rectangle
            case .text: preconditionFailure("Text has no line style")
            }
        }
        set {
            switch tool {
            case .freehand: freehand = newValue
            case .arrow: arrow = newValue
            case .rectangle: rectangle = newValue
            case .text: preconditionFailure("Text has no line style")
            }
        }
    }
}

// What a line is drawn with.
public struct Pen: Equatable {
    public var width: CGFloat
    public var style: LineStyle

    public init(width: CGFloat, style: LineStyle) {
        self.width = width
        self.style = style
    }
}
