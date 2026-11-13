import AppKit
import Carbon.HIToolbox

// A text annotation. The same view shows finished text and edits it, so nothing shifts when typing ends.
final class TextMarkView: NSTextView {
    let markID: UUID
    private(set) var color: PaletteColor
    private(set) var fontName: String
    private(set) var fontSize: CGFloat
    var isEditing: Bool { isEditable }

    init(markID: UUID, content: TextContent, color: PaletteColor) {
        self.markID = markID
        self.color = color
        fontName = content.fontName
        fontSize = content.size

        // TextKit 1 sizes to fit its text predictably.
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude))
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        super.init(frame: NSRect(origin: content.origin, size: NSSize(width: 1, height: 1)), textContainer: container)

        isRichText = false
        importsGraphics = false
        allowsUndo = true
        drawsBackground = false
        isHorizontallyResizable = true
        isVerticallyResizable = true
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textContainerInset = .zero
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        isAutomaticLinkDetectionEnabled = false
        focusRingType = .none
        isEditable = false
        isSelectable = false

        string = content.string
        applyStyle()
    }

    required init?(coder: NSCoder) { fatalError("Not used") }

    var content: TextContent {
        TextContent(string: string, origin: frame.origin, fontName: fontName, size: fontSize)
    }

    var lineHeight: CGFloat {
        layoutManager!.defaultLineHeight(for: FontCatalog.font(fontName, size: fontSize))
    }

    func setStyle(color: PaletteColor, fontName: String, size: CGFloat) {
        self.color = color
        self.fontName = fontName
        fontSize = size
        applyStyle()
    }

    func setEditing(_ editing: Bool) {
        isEditable = editing
        isSelectable = editing
        if !editing {
            setSelectedRange(NSRange(location: (string as NSString).length, length: 0))
        }
    }

    private func applyStyle() {
        let font = FontCatalog.font(fontName, size: fontSize)
        self.font = font
        textColor = color.nsColor
        insertionPointColor = color.nsColor
        typingAttributes = [.font: font, .foregroundColor: color.nsColor]
        selectedTextAttributes = [.backgroundColor: color.nsColor.withAlphaComponent(0.3)]
        fitToText()
    }

    // Grows and shrinks with the text, keeping its top left corner. An empty line keeps room for the caret.
    func fitToText() {
        guard let layoutManager, let textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer)
        let width = ceil(max(used.width, 0) + caretWidth + 2)
        let height = ceil(max(used.height, lineHeight))
        setFrameSize(NSSize(width: width, height: height))
    }

    override func didChangeText() {
        super.didChangeText()
        fitToText()
    }

    // A caret that scales with the text, so it reads at presentation sizes.
    private var caretWidth: CGFloat { max(2, (fontSize / 16).rounded()) }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        guard flag else {
            super.drawInsertionPoint(in: rect, color: color, turnedOn: false)
            return
        }
        let caret = NSRect(x: rect.minX, y: rect.minY, width: caretWidth, height: rect.height)
        color.setFill()
        NSBezierPath(roundedRect: caret, xRadius: caretWidth / 2, yRadius: caretWidth / 2).fill()
    }

    // The wider caret has to be erased as well when it blinks off.
    override func setNeedsDisplay(_ rect: NSRect, avoidAdditionalLayout flag: Bool) {
        var rect = rect
        rect.size.width += caretWidth
        super.setNeedsDisplay(rect, avoidAdditionalLayout: flag)
    }

    // ⌃↓ starts a new line below the current one, wherever the caret is on it.
    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.function, .numericPad])
        if Int(event.keyCode) == kVK_DownArrow, modifiers == .control {
            moveToEndOfParagraph(nil)
            insertNewline(nil)
            return
        }
        super.keyDown(with: event)
    }

    // Edit commands while typing. The canvas panel takes key input without making the app active, so they're handled
    // here, where they can't depend on the app's menu.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isEditing, window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch (modifiers, event.charactersIgnoringModifiers?.lowercased()) {
        case ([.command], "c"): copy(nil)
        case ([.command], "x"): cut(nil)
        case ([.command], "v"): pasteAsPlainText(nil)
        case ([.command], "a"): selectAll(nil)
        case ([.command], "z"): undoManager?.undo()
        case ([.command, .shift], "z"): undoManager?.redo()
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    // Finished text lets clicks through to the canvas, which decides whether they move, edit or draw over it.
    override func hitTest(_ point: NSPoint) -> NSView? {
        isEditing ? super.hitTest(point) : nil
    }

    override var acceptsFirstResponder: Bool { isEditing }
}
