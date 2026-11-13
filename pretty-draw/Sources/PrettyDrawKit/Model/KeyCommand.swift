import AppKit
import Carbon.HIToolbox

// What a key press means while annotating and no text is being edited. The keys match Presentify's.
public enum KeyCommand: Equatable {
    case color(Int)
    case tool(Tool)
    case smaller
    case larger
    case clear
    case undo
    case redo
    case toggleShortcuts
    case cancel

    public struct Modifiers: OptionSet, Equatable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let shift = Modifiers(rawValue: 1 << 0)
        public static let control = Modifiers(rawValue: 1 << 1)
        public static let option = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)

        public init(_ flags: NSEvent.ModifierFlags) {
            var modifiers: Modifiers = []
            if flags.contains(.shift) { modifiers.insert(.shift) }
            if flags.contains(.control) { modifiers.insert(.control) }
            if flags.contains(.option) { modifiers.insert(.option) }
            if flags.contains(.command) { modifiers.insert(.command) }
            self = modifiers
        }
    }

    // `characters` is the key's character with no modifiers applied, so it follows the keyboard layout.
    public init?(keyCode: Int, characters: String, modifiers: Modifiers) {
        switch keyCode {
        case kVK_Delete, kVK_ForwardDelete:
            guard modifiers.isEmpty else { return nil }
            self = .clear
            return
        case kVK_Escape:
            self = .cancel
            return
        default:
            break
        }

        let character = characters.lowercased()
        if modifiers == .command, character == "z" {
            self = .undo
            return
        }
        if modifiers == [.command, .shift], character == "z" {
            self = .redo
            return
        }
        guard modifiers.isEmpty, character.count == 1, let key = character.first else { return nil }

        if let digit = key.wholeNumberValue, (1...Palette.size).contains(digit) {
            self = .color(digit - 1)
        } else if let tool = Tool.allCases.first(where: { $0.key == key }) {
            self = .tool(tool)
        } else if key == "[" {
            self = .smaller
        } else if key == "]" {
            self = .larger
        } else if key == "/" {
            self = .toggleShortcuts
        } else {
            return nil
        }
    }
}
