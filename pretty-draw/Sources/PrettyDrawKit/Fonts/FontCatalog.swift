import AppKit

// Fonts installed on the Mac, named by PostScript name, the one name that pins down a single face.
public enum FontCatalog {
    public struct Face: Identifiable, Equatable {
        public let postScriptName: String
        public let style: String
        public var id: String { postScriptName }
    }

    public static func isInstalled(_ postScriptName: String) -> Bool {
        NSFont(name: postScriptName, size: 12) != nil
    }

    // A font that isn't installed any more, because it was removed after being chosen, is drawn in the system font.
    // The toolbar and Settings mark it as missing.
    public static func font(_ postScriptName: String, size: CGFloat) -> NSFont {
        NSFont(name: postScriptName, size: size) ?? .systemFont(ofSize: size, weight: .semibold)
    }

    // "Switzer", for the toolbar's font button, where room is short.
    public static func familyName(_ postScriptName: String) -> String {
        guard let family = NSFont(name: postScriptName, size: 12)?.familyName else {
            preconditionFailure("\(postScriptName) isn't installed")
        }
        return family
    }

    // "Switzer Semibold", for menus and lists.
    public static func displayName(_ postScriptName: String) -> String {
        NSFont(name: postScriptName, size: 12)?.displayName ?? postScriptName
    }

    public static var families: [String] {
        NSFontManager.shared.availableFontFamilies.filter { !$0.hasPrefix(".") }
    }

    public static func faces(of family: String) -> [Face] {
        (NSFontManager.shared.availableMembers(ofFontFamily: family) ?? []).compactMap { member in
            guard let name = member.first as? String, let style = member[1] as? String else { return nil }
            return Face(postScriptName: name, style: style)
        }
    }
}

// Every font installed on the Mac, by family, for adding custom fonts in Settings. Fonts already in the font list are
// checked and can't be added again.
final class SystemFontMenu: NSObject, NSMenuDelegate {
    private let listed: Set<String>
    private let add: (String) -> Void

    init(listed: [String], add: @escaping (String) -> Void) {
        self.listed = Set(listed)
        self.add = add
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "Fonts")
        for family in FontCatalog.families {
            let item = NSMenuItem(title: family, action: nil, keyEquivalent: "")
            let faces = NSMenu(title: family)
            faces.autoenablesItems = false
            faces.delegate = self
            item.submenu = faces
            menu.addItem(item)
        }
        return menu
    }

    // Faces are listed when a family is opened, so the menu opens quickly.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.items.isEmpty else { return }
        for face in FontCatalog.faces(of: menu.title) {
            let item = NSMenuItem(title: face.style, action: #selector(pick(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = face.postScriptName
            item.state = listed.contains(face.postScriptName) ? .on : .off
            item.isEnabled = !listed.contains(face.postScriptName)
            item.attributedTitle = NSAttributedString(
                string: face.style, attributes: [.font: FontCatalog.font(face.postScriptName, size: 14)]
            )
            menu.addItem(item)
        }
    }

    @objc private func pick(_ sender: NSMenuItem) {
        add(sender.representedObject as! String)
    }
}
