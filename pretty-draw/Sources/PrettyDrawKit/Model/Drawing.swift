import CoreGraphics
import Foundation

// One finished annotation. Points are in the display's own coordinates, origin at its top left.
public struct Mark: Identifiable, Equatable {
    public enum Kind: Equatable {
        case stroke(points: [CGPoint], closed: Bool, pen: Pen)
        case arrow(from: CGPoint, to: CGPoint, pen: Pen)
        case rectangle(CGRect, pen: Pen)
        case text(TextContent)
    }

    public let id: UUID
    public var display: CGDirectDisplayID
    public var color: PaletteColor
    public var kind: Kind

    public init(id: UUID = UUID(), display: CGDirectDisplayID, color: PaletteColor, kind: Kind) {
        self.id = id
        self.display = display
        self.color = color
        self.kind = kind
    }

    public var text: TextContent? {
        if case .text(let content) = kind { return content }
        return nil
    }

    // Varies the hand-drawn style's wobble from mark to mark, and keeps a mark's wobble the same every time it's drawn.
    public var seed: UInt64 {
        withUnsafeBytes(of: id.uuid) { $0.loadUnaligned(as: UInt64.self) }
    }
}

public struct TextContent: Equatable {
    public var string: String
    // Top left corner of the text's layout box.
    public var origin: CGPoint
    public var fontName: String
    public var size: CGFloat

    public init(string: String, origin: CGPoint, fontName: String, size: CGFloat) {
        self.string = string
        self.origin = origin
        self.fontName = fontName
        self.size = size
    }
}

// Everything drawn in one session, with undo and redo. Each change is one undo step.
public struct Drawing: Equatable {
    public private(set) var marks: [Mark] = []
    private var undoStack: [[Mark]] = []
    private var redoStack: [[Mark]] = []

    public init() {}

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public func mark(_ id: UUID) -> Mark? {
        marks.first { $0.id == id }
    }

    public mutating func add(_ mark: Mark) {
        record()
        marks.append(mark)
    }

    // Swaps in a changed version of an existing mark, such as edited or moved text.
    public mutating func update(_ mark: Mark) {
        guard let index = marks.firstIndex(where: { $0.id == mark.id }) else {
            preconditionFailure("No mark \(mark.id) to update")
        }
        guard marks[index] != mark else { return }
        record()
        marks[index] = mark
    }

    public mutating func remove(_ id: UUID) {
        guard let index = marks.firstIndex(where: { $0.id == id }) else {
            preconditionFailure("No mark \(id) to remove")
        }
        record()
        marks.remove(at: index)
    }

    public mutating func clear() {
        guard !marks.isEmpty else { return }
        record()
        marks.removeAll()
    }

    @discardableResult
    public mutating func undo() -> Bool {
        guard let previous = undoStack.popLast() else { return false }
        redoStack.append(marks)
        marks = previous
        return true
    }

    @discardableResult
    public mutating func redo() -> Bool {
        guard let next = redoStack.popLast() else { return false }
        undoStack.append(marks)
        marks = next
        return true
    }

    private mutating func record() {
        undoStack.append(marks)
        redoStack.removeAll()
    }
}
