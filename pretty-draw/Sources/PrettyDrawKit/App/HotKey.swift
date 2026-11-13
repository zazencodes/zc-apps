import AppKit
import Carbon.HIToolbox

public struct HotKeyCombo: Codable, Equatable {
    public enum Modifier: String, Codable, CaseIterable {
        case control, option, shift, command

        var glyph: String {
            switch self {
            case .control: "⌃"
            case .option: "⌥"
            case .shift: "⇧"
            case .command: "⌘"
            }
        }
    }

    public var keyCode: Int
    public var modifiers: Set<Modifier>

    public init(keyCode: Int, modifiers: Set<Modifier>) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    // ⌃B, as in Alex's Presentify setup.
    public static let standard = HotKeyCombo(keyCode: kVK_ANSI_B, modifiers: [.control])

    public init?(event: NSEvent) {
        var modifiers: Set<Modifier> = []
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        // A global shortcut needs ⌃, ⌥ or ⌘, or it would swallow ordinary typing.
        guard !modifiers.subtracting([.shift]).isEmpty else { return nil }
        self.init(keyCode: Int(event.keyCode), modifiers: modifiers)
    }

    public var displayString: String {
        Modifier.allCases.filter(modifiers.contains).map(\.glyph).joined() + keyLabel
    }

    // The character the key types on the current layout, or its name.
    public var keyLabel: String {
        if let name = Self.specialKeys[keyCode] { return name }
        guard
            let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return "Key \(keyCode)" }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = data.withUnsafeBytes { buffer in
            UCKeyTranslate(
                buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress, UInt16(keyCode), UInt16(kUCKeyActionDisplay),
                0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, 4, &length, &characters
            )
        }
        guard status == noErr, length > 0 else { return "Key \(keyCode)" }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }

    var carbonModifiers: UInt32 {
        var flags = 0
        if modifiers.contains(.shift) { flags |= shiftKey }
        if modifiers.contains(.control) { flags |= controlKey }
        if modifiers.contains(.option) { flags |= optionKey }
        if modifiers.contains(.command) { flags |= cmdKey }
        return UInt32(flags)
    }

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋", kVK_Delete: "⌫",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]
}

// The global start/stop shortcut. Carbon hot keys need no permission and work in the App Sandbox.
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, context in
                Unmanaged<HotKey>.fromOpaque(context!).takeUnretainedValue().action()
                return noErr
            },
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
        precondition(status == noErr, "Could not install the hot key handler: \(status)")
    }

    // Returns false when another app already owns the combination.
    func register(_ combo: HotKeyCombo) -> Bool {
        unregister()
        let id = EventHotKeyID(signature: OSType(0x5044_5257), id: 1)
        let status = RegisterEventHotKey(
            UInt32(combo.keyCode), combo.carbonModifiers, id, GetEventDispatcherTarget(), 0, &ref
        )
        return status == noErr
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }
}
