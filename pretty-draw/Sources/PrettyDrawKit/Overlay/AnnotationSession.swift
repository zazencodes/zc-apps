import AppKit
import Combine
import SwiftUI

// One stretch of annotating, from ⌃B to ⌃B or Esc. It covers every display with a canvas, shows the toolbar, and turns
// pointer and key input into marks. Everything drawn goes away when it ends, as a step the next session can undo.
final class AnnotationSession: NSObject, NSTextViewDelegate {
    let preferences: Preferences
    private let state = SessionState()
    private let onClose: () -> Void

    private var drawing: Drawing
    private var canvases: [CGDirectDisplayID: CanvasView] = [:]
    private var windows: [CGDirectDisplayID: OverlayWindow] = [:]
    private var toolbar: ToolbarPanel?
    private var toolbarDrag: (mouse: CGPoint, origin: CGPoint)?
    private var gesture: Gesture?
    private var editing: TextEditing?
    private var fontList: ToolbarPanel?
    private var subscriptions: Set<AnyCancellable> = []

    private enum Gesture {
        case stroke(GuidedStroke, NewLine)
        case shape(Tool, from: CGPoint, to: CGPoint, NewLine)
        // Pressed on existing text: a drag moves it, a click edits it.
        case text(TextMarkView, CanvasView, grab: CGVector, from: CGPoint, moved: Bool)
    }

    // A line being drawn: the mark it becomes, all but its shape, which is fixed when the drag starts.
    private struct NewLine {
        let id = UUID()
        let canvas: CanvasView
        let color: PaletteColor
        let pen: Pen

        func mark(_ kind: Mark.Kind) -> Mark {
            Mark(id: id, display: canvas.display, color: color, kind: kind)
        }
    }

    private struct TextEditing {
        let view: TextMarkView
        let canvas: CanvasView
        let isNew: Bool
        let undo = UndoManager()
    }

    // `drawing` is what the last session ended with, already cleared, so undo brings it back.
    init(preferences: Preferences, drawing: Drawing, onClose: @escaping () -> Void) {
        self.preferences = preferences
        self.drawing = drawing
        self.onClose = onClose
        super.init()
    }

    // MARK: Start and end

    func start() {
        layOutDisplays()
        // Without the toolbar, everything is done with keys.
        if preferences.showsToolbar {
            let toolbar = ToolbarPanel(view: ToolbarView(preferences: preferences, state: state, actions: toolbarActions))
            self.toolbar = toolbar
            placeToolbar(on: screenUnderPointer)
            toolbar.orderFrontRegardless()
        }

        if let canvas = canvas(on: screenUnderPointer) {
            canvas.window?.makeKeyAndOrderFront(nil)
            canvas.window?.makeFirstResponder(canvas)
            updateIndicator(at: canvas.convert(canvas.window!.mouseLocationOutsideOfEventStream, from: nil), on: canvas)
        }

        preferences.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.preferencesChanged() }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.layOutDisplays() }
            .store(in: &subscriptions)
    }

    // Clears the drawing as one undoable step and hands it back for the next session.
    func end() -> Drawing {
        closeFonts()
        finishEditing()
        subscriptions.removeAll()
        windows.values.forEach { $0.orderOut(nil) }
        windows.removeAll()
        canvases.removeAll()
        toolbar?.orderOut(nil)
        toolbar = nil
        drawing.clear()
        return drawing
    }

    // A canvas for every display, kept in step as displays come and go. Marks on a display that's gone stay in the
    // drawing and show again if it comes back.
    private func layOutDisplays() {
        var present = Set<CGDirectDisplayID>()
        for screen in NSScreen.screens {
            let id = screen.displayID
            present.insert(id)
            if let window = windows[id] {
                window.setFrame(screen.frame, display: true)
                canvases[id]!.frame = NSRect(origin: .zero, size: screen.frame.size)
            } else {
                let canvas = CanvasView(frame: NSRect(origin: .zero, size: screen.frame.size), display: id)
                canvas.session = self
                let window = OverlayWindow(screen: screen, canvas: canvas)
                canvases[id] = canvas
                windows[id] = window
                window.orderFrontRegardless()
            }
        }
        for id in windows.keys where !present.contains(id) {
            windows[id]!.orderOut(nil)
            windows[id] = nil
            canvases[id] = nil
        }
        syncCanvases()
    }

    private var screenUnderPointer: NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main!
    }

    private func canvas(on screen: NSScreen) -> CanvasView? {
        canvases[screen.displayID]
    }

    private func syncCanvases() {
        for canvas in canvases.values {
            canvas.sync(drawing.marks, editing: editing?.canvas === canvas ? editing?.view : nil)
        }
    }

    // MARK: Pointer

    func mouseDown(at point: CGPoint, on canvas: CanvasView, event: NSEvent) {
        // A click away from the font list or the shortcut sheet closes it, and does nothing else.
        if fontList != nil {
            closeFonts()
            return
        }
        if canvas.isShowingSheet {
            canvas.showSheet(nil)
            return
        }
        // A click away from the text being typed finishes it, and does nothing else.
        if editing != nil {
            finishEditing()
            return
        }
        if canvas.window?.isKeyWindow == false {
            canvas.window?.makeKeyAndOrderFront(nil)
        }
        canvas.window?.makeFirstResponder(canvas)
        canvas.setIndicator(at: nil, tool: preferences.tool, color: preferences.color)

        switch preferences.tool {
        case .text:
            if let view = canvas.textView(at: point) {
                let grab = CGVector(dx: point.x - view.frame.minX, dy: point.y - view.frame.minY)
                gesture = .text(view, canvas, grab: grab, from: point, moved: false)
            } else {
                beginNewText(at: point, on: canvas)
            }
        case .freehand:
            let line = NewLine(canvas: canvas, color: preferences.color, pen: preferences.pen(for: .freehand))
            let stroke = GuidedStroke(start: point, width: line.pen.width)
            gesture = .stroke(stroke, line)
            canvas.setLive(line.mark(.stroke(points: stroke.live, closed: false, pen: line.pen)))
        case .arrow, .rectangle:
            let line = NewLine(canvas: canvas, color: preferences.color, pen: preferences.pen(for: preferences.tool))
            gesture = .shape(preferences.tool, from: point, to: point, line)
        }
    }

    func mouseDragged(to point: CGPoint, on canvas: CanvasView, event: NSEvent) {
        guard let gesture else { return }
        switch gesture {
        case .stroke(var stroke, let line):
            stroke.add(point)
            self.gesture = .stroke(stroke, line)
            showLiveStroke(stroke, line, straight: event.modifierFlags.contains(.shift))
        case .shape(let tool, let from, _, let line):
            self.gesture = .shape(tool, from: from, to: point, line)
            line.canvas.setLive(line.mark(Self.shape(tool, from: from, to: point, pen: line.pen)))
        case .text(let view, let canvas, let grab, let from, var moved):
            moved = moved || GuidedStroke.distance(from, point) > 3
            if moved {
                view.setFrameOrigin(CGPoint(x: point.x - grab.dx, y: point.y - grab.dy))
            }
            self.gesture = .text(view, canvas, grab: grab, from: from, moved: moved)
        }
    }

    func mouseUp(at point: CGPoint, on canvas: CanvasView, event: NSEvent) {
        guard let gesture else { return }
        self.gesture = nil
        switch gesture {
        case .stroke(var stroke, let line):
            stroke.add(point)
            line.canvas.setLive(nil)
            let mark: Mark
            if event.modifierFlags.contains(.shift) {
                mark = line.mark(.stroke(points: Self.straight(stroke), closed: false, pen: line.pen))
            } else {
                let result = stroke.finished(closingLoops: preferences.closesLoops)
                mark = line.mark(.stroke(points: result.points, closed: result.closed, pen: line.pen))
                line.canvas.settle(mark, from: stroke.live)
            }
            drawing.add(mark)
            syncCanvases()
        case .shape(let tool, let from, _, let line):
            line.canvas.setLive(nil)
            guard GuidedStroke.distance(from, point) >= 4 else { break }
            drawing.add(line.mark(Self.shape(tool, from: from, to: point, pen: line.pen)))
            syncCanvases()
        case .text(let view, let canvas, _, let from, let moved):
            if moved, var mark = drawing.mark(view.markID), var content = mark.text {
                content.origin = view.frame.origin
                mark.kind = .text(content)
                drawing.update(mark)
                syncCanvases()
            } else {
                beginEditing(view, on: canvas, caretAt: from)
            }
        }
        updateIndicator(at: point, on: canvas)
    }

    func mouseMoved(to point: CGPoint?, on canvas: CanvasView) {
        updateIndicator(at: point, on: canvas)
    }

    private func updateIndicator(at point: CGPoint?, on canvas: CanvasView) {
        let shown = gesture == nil && editing == nil ? point : nil
        canvas.setIndicator(at: shown, tool: preferences.tool, color: preferences.color)
    }

    private func showLiveStroke(_ stroke: GuidedStroke, _ line: NewLine, straight: Bool) {
        let points = straight ? Self.straight(stroke) : stroke.live
        line.canvas.setLive(line.mark(.stroke(points: points, closed: false, pen: line.pen)))
    }

    private static func straight(_ stroke: GuidedStroke) -> [CGPoint] {
        stroke.raw.count > 1 ? [stroke.raw.first!, stroke.raw.last!] : [stroke.raw[0]]
    }

    private static func shape(_ tool: Tool, from: CGPoint, to: CGPoint, pen: Pen) -> Mark.Kind {
        switch tool {
        case .arrow:
            return .arrow(from: from, to: to, pen: pen)
        case .rectangle:
            return .rectangle(CGRect(x: from.x, y: from.y, width: to.x - from.x, height: to.y - from.y).standardized, pen: pen)
        case .freehand, .text:
            preconditionFailure("\(tool) isn't a dragged shape")
        }
    }

    // MARK: Keys

    // Returns whether the key meant something.
    @discardableResult
    func keyDown(_ event: NSEvent) -> Bool {
        guard editing == nil else { return false }
        guard let command = KeyCommand(
            keyCode: Int(event.keyCode),
            characters: event.charactersIgnoringModifiers ?? "",
            modifiers: KeyCommand.Modifiers(event.modifierFlags)
        ) else { return false }

        switch command {
        case .color(let index):
            chooseColor(index)
        case .tool(let tool):
            chooseTool(tool)
        case .smaller:
            stepSize(up: false)
        case .larger:
            stepSize(up: true)
        case .clear:
            guard gesture == nil else { break }
            drawing.clear()
            syncCanvases()
        case .undo:
            guard gesture == nil else { break }
            drawing.undo()
            syncCanvases()
        case .redo:
            guard gesture == nil else { break }
            drawing.redo()
            syncCanvases()
        case .toggleShortcuts:
            toggleShortcuts()
        case .cancel:
            // Esc backs out one step at a time: a drag, the shortcut sheet, the font list, then annotating.
            if let gesture {
                cancel(gesture)
            } else if canvases.values.contains(where: \.isShowingSheet) {
                canvases.values.forEach { $0.showSheet(nil) }
            } else if fontList != nil {
                closeFonts()
            } else {
                onClose()
            }
        }
        return true
    }

    func flagsChanged(_ event: NSEvent) {
        guard case .stroke(let stroke, let line) = gesture else { return }
        showLiveStroke(stroke, line, straight: event.modifierFlags.contains(.shift))
    }

    private func cancel(_ gesture: Gesture) {
        self.gesture = nil
        switch gesture {
        case .stroke(_, let line), .shape(_, _, _, let line):
            line.canvas.setLive(nil)
        case .text(let view, _, let grab, let from, _):
            view.setFrameOrigin(CGPoint(x: from.x - grab.dx, y: from.y - grab.dy))
        }
    }

    private func toggleShortcuts() {
        guard let canvas = canvas(on: screenUnderPointer) else { return }
        let showing = canvas.isShowingSheet
        canvases.values.forEach { $0.showSheet(nil) }
        if !showing {
            canvas.showSheet(NSHostingView(rootView: ShortcutSheet(hotKey: preferences.hotKey.displayString)))
        }
    }

    // MARK: Toolbar and key actions

    private var toolbarActions: ToolbarActions {
        ToolbarActions(
            chooseColor: { [weak self] in self?.chooseColor($0) },
            chooseTool: { [weak self] in self?.chooseTool($0) },
            chooseStyle: { [weak self] in self?.chooseStyle($0) },
            toggleLoops: { [weak self] in self?.preferences.closesLoops.toggle() },
            stepSize: { [weak self] in self?.stepSize(up: $0) },
            resetSize: { [weak self] in self?.resetSize() },
            toggleFonts: { [weak self] in self?.toggleFonts(below: $0) },
            close: { [weak self] in self?.onClose() },
            drag: { [weak self] in self?.dragToolbar(ended: $0) }
        )
    }

    // While typing, toolbar changes apply to the text being typed.
    private func chooseColor(_ index: Int) {
        preferences.colorIndex = index
        if let view = editing?.view {
            view.setStyle(color: preferences.color, fontName: view.fontName, size: view.fontSize)
        }
    }

    private func chooseTool(_ tool: Tool) {
        closeFonts()
        finishEditing()
        preferences.tool = tool
    }

    // Changes the style of the selected tool only.
    private func chooseStyle(_ style: LineStyle) {
        preferences.lineStyles[preferences.tool] = style
    }

    private func stepSize(up: Bool) {
        if let view = editing?.view {
            let size = SizeSteps.step(view.fontSize, in: SizeSteps.textSizes, up: up)
            view.setStyle(color: view.color, fontName: view.fontName, size: size)
            preferences.textSize = size
        } else {
            preferences.stepSize(for: preferences.tool, up: up)
        }
    }

    private func resetSize() {
        let size = Preferences.defaultSize(for: preferences.tool)
        if let view = editing?.view {
            view.setStyle(color: view.color, fontName: view.fontName, size: size)
        }
        preferences.setSize(size, for: preferences.tool)
    }

    private func chooseFont(_ name: String) {
        closeFonts()
        preferences.fontName = name
        if let view = editing?.view {
            view.setStyle(color: view.color, fontName: name, size: view.fontSize)
        }
    }

    // The font list opens below the font button, or above it when there's no room below. `button` is the button's
    // frame in the toolbar view, from its top left.
    private func toggleFonts(below button: CGRect) {
        guard fontList == nil else { return closeFonts() }
        guard let toolbar, let screen = toolbar.screen else { return }
        let list = ToolbarPanel(view: FontList(
            custom: preferences.customFonts,
            standard: Preferences.standardFonts,
            current: editing?.view.fontName ?? preferences.fontName,
            minWidth: button.width
        ) { [weak self] in self?.chooseFont($0) })
        list.level = NSWindow.Level(rawValue: toolbar.level.rawValue + 1)

        let size = list.fittingSize
        let margin = ToolbarPanel.margin
        let gap: CGFloat = 6
        let frame = screen.frame
        let buttonTop = toolbar.frame.maxY - button.minY
        let buttonBottom = toolbar.frame.maxY - button.maxY
        var origin = CGPoint(x: toolbar.frame.minX + button.minX - margin, y: buttonBottom - gap + margin - size.height)
        if origin.y + margin < frame.minY {
            origin.y = buttonTop + gap - margin
        }
        origin.x = min(max(origin.x, frame.minX - margin), frame.maxX - size.width + margin)
        list.setFrame(NSRect(origin: origin, size: size), display: true)
        list.orderFrontRegardless()
        fontList = list
    }

    private func closeFonts() {
        fontList?.orderOut(nil)
        fontList = nil
    }

    private func preferencesChanged() {
        refitToolbar()
        guard let canvas = canvas(on: screenUnderPointer), let window = canvas.window else { return }
        updateIndicator(at: canvas.convert(window.mouseLocationOutsideOfEventStream, from: nil), on: canvas)
    }

    // MARK: Toolbar placement

    // The toolbar keeps its spot from session to session, as fractions of the display: its center across, and its top
    // edge down from the top. It starts just below the menu bar, in the middle.
    private func placeToolbar(on screen: NSScreen) {
        guard let toolbar else { return }
        let size = toolbar.fittingSize
        let margin = ToolbarPanel.margin
        let frame = screen.frame
        let center: CGFloat
        let top: CGFloat
        if let position = preferences.toolbarPosition {
            center = frame.minX + position.x * frame.width
            top = frame.maxY - position.y * frame.height
        } else {
            center = frame.midX
            top = screen.visibleFrame.maxY - 6
        }
        var origin = CGPoint(x: center - size.width / 2, y: top + margin - size.height)
        origin.x = min(max(origin.x, frame.minX - margin), frame.maxX - size.width + margin)
        origin.y = min(max(origin.y, frame.minY - margin), frame.maxY - size.height + margin)
        toolbar.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    // The bar changes width with the tool. It stays centred where it was.
    private func refitToolbar() {
        guard let toolbar, let screen = toolbar.screen ?? NSScreen.main else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.toolbar === toolbar else { return }
            let size = toolbar.fittingSize
            guard size != toolbar.frame.size else { return }
            if self.preferences.toolbarPosition == nil {
                self.placeToolbar(on: screen)
            } else {
                let frame = toolbar.frame
                let origin = CGPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height)
                toolbar.setFrame(NSRect(origin: origin, size: size), display: true)
            }
        }
    }

    private func dragToolbar(ended: Bool) {
        guard let toolbar else { return }
        closeFonts()
        let mouse = NSEvent.mouseLocation
        let drag = toolbarDrag ?? (mouse, toolbar.frame.origin)
        toolbarDrag = ended ? nil : drag
        toolbar.setFrameOrigin(CGPoint(x: drag.origin.x + mouse.x - drag.mouse.x, y: drag.origin.y + mouse.y - drag.mouse.y))
        guard ended, let screen = toolbar.screen else { return }
        let frame = screen.frame
        let bar = toolbar.frame.insetBy(dx: ToolbarPanel.margin, dy: ToolbarPanel.margin)
        preferences.toolbarPosition = CGPoint(
            x: (bar.midX - frame.minX) / frame.width,
            y: (frame.maxY - bar.maxY) / frame.height
        )
    }

    // MARK: Text

    private func beginNewText(at point: CGPoint, on canvas: CanvasView) {
        let content = TextContent(string: "", origin: point, fontName: preferences.fontName, size: preferences.textSize)
        let view = TextMarkView(markID: UUID(), content: content, color: preferences.color)
        // The click lands in the middle of the first line.
        view.setFrameOrigin(CGPoint(x: point.x, y: point.y - view.lineHeight / 2))
        canvas.addEditingView(view)
        startEditing(TextEditing(view: view, canvas: canvas, isNew: true), caretAt: nil)
    }

    private func beginEditing(_ view: TextMarkView, on canvas: CanvasView, caretAt point: CGPoint) {
        startEditing(TextEditing(view: view, canvas: canvas, isNew: false), caretAt: point)
    }

    private func startEditing(_ editing: TextEditing, caretAt point: CGPoint?) {
        self.editing = editing
        state.isEditingText = true
        let view = editing.view
        view.delegate = self
        view.setEditing(true)
        editing.canvas.window?.makeKeyAndOrderFront(nil)
        editing.canvas.window?.makeFirstResponder(view)
        if let point {
            let index = view.characterIndexForInsertion(at: view.convert(point, from: editing.canvas))
            view.setSelectedRange(NSRange(location: index, length: 0))
        }
        editing.canvas.setIndicator(at: nil, tool: preferences.tool, color: preferences.color)
    }

    // Keeps the text as typed, minus trailing blank lines and spaces. Text left empty goes away.
    func finishEditing() {
        guard let editing else { return }
        self.editing = nil
        state.isEditingText = false
        let view = editing.view
        view.delegate = nil
        view.setEditing(false)
        editing.canvas.window?.makeFirstResponder(editing.canvas)

        var text = view.string
        while let last = text.last, last.isWhitespace { text.removeLast() }
        if text != view.string { view.string = text }
        view.fitToText()

        let mark = Mark(id: view.markID, display: editing.canvas.display, color: view.color, kind: .text(view.content))
        switch (editing.isNew, text.isEmpty) {
        case (true, true):
            break
        case (true, false):
            drawing.add(mark)
        case (false, true):
            drawing.remove(mark.id)
        case (false, false):
            drawing.update(mark)
        }
        syncCanvases()
    }

    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.cancelOperation(_:)), #selector(NSTextView.complete(_:)):
            if fontList != nil {
                closeFonts()
            } else {
                finishEditing()
            }
            return true
        case #selector(NSResponder.insertLineBreak(_:)), #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)):
            textView.insertNewline(nil)
            return true
        default:
            return false
        }
    }

    // Each text gets its own undo history while it's being typed.
    func undoManager(for view: NSTextView) -> UndoManager? {
        editing?.undo
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
    }
}
