import AppKit

// The drawing surface covering one display. It draws finished shapes itself and holds a text view per text mark.
// Whatever changes as the pointer moves has a small view of its own, above the shapes and below the text, so following
// the pointer never redraws the finished shapes. Input goes to the session, which owns all the decisions.
final class CanvasView: NSView {
    let display: CGDirectDisplayID
    weak var session: AnnotationSession?

    private var shapes: [Mark] = []
    private(set) var textViews: [UUID: TextMarkView] = [:]
    // The line being drawn. It already has the ID its mark will keep, so the hand-drawn style's wobble stays put.
    private let liveView = MarkView()
    // A finished freehand stroke while it settles. The canvas draws it once it has.
    private let settlingView = MarkView()
    private var morph: Morph?
    private var morphTimer: Timer?
    private let indicatorView = IndicatorView()
    private var sheet: NSView?

    // A finished freehand stroke settling from how it was drawn into its guided shape.
    private struct Morph {
        static let duration: CFTimeInterval = 0.2
        let mark: Mark
        let from: [CGPoint]
        let to: [CGPoint]
        let closed: Bool
        let pen: Pen
        let started = CACurrentMediaTime()

        init(mark: Mark, from: [CGPoint]) {
            guard case .stroke(let to, let closed, let pen) = mark.kind else {
                preconditionFailure("Only freehand strokes settle")
            }
            let count = max(from.count, to.count, 2)
            self.mark = mark
            self.from = GuidedStroke.resample(from, count: count)
            self.to = GuidedStroke.resample(to, count: count)
            self.closed = closed
            self.pen = pen
        }

        var progress: CGFloat {
            let t = min(CGFloat((CACurrentMediaTime() - started) / Self.duration), 1)
            return 1 - pow(1 - t, 3)
        }

        // The mark part of the way from how it was drawn to its guided shape.
        var shown: Mark {
            let t = progress
            var shown = mark
            let points = zip(from, to).map { CGPoint(x: $0.x + ($1.x - $0.x) * t, y: $0.y + ($1.y - $0.y) * t) }
            shown.kind = .stroke(points: points, closed: closed, pen: pen)
            return shown
        }

    }

    init(frame: NSRect, display: CGDirectDisplayID) {
        self.display = display
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        addSubview(settlingView)
        addSubview(liveView)
        addSubview(indicatorView)
        addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect], owner: self
        ))
    }

    required init?(coder: NSCoder) { fatalError("Not used") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Content

    // Matches the canvas to the drawing. `editing` is a text view the session is editing, which stays even before its
    // text is part of the drawing.
    func sync(_ marks: [Mark], editing: TextMarkView?) {
        let mine = marks.filter { $0.display == display }
        let newShapes = mine.filter { $0.text == nil }
        // Redraws only where a shape was added, removed or changed.
        let old = Dictionary(uniqueKeysWithValues: shapes.map { ($0.id, $0) })
        let new = Dictionary(uniqueKeysWithValues: newShapes.map { ($0.id, $0) })
        for mark in shapes where new[mark.id] != mark { setNeedsDisplay(MarkRenderer.bounds(of: mark.kind)) }
        for mark in newShapes where old[mark.id] != mark { setNeedsDisplay(MarkRenderer.bounds(of: mark.kind)) }
        shapes = newShapes
        if let morph, new[morph.mark.id] == nil { finishSettling() }

        var keep = Set<UUID>()
        for mark in mine {
            guard let content = mark.text else { continue }
            keep.insert(mark.id)
            if let view = textViews[mark.id] {
                guard view !== editing else { continue }
                if view.string != content.string { view.string = content.string }
                view.setStyle(color: mark.color, fontName: content.fontName, size: content.size)
                view.setFrameOrigin(content.origin)
            } else {
                let view = TextMarkView(markID: mark.id, content: content, color: mark.color)
                addSubview(view, positioned: .above, relativeTo: indicatorView)
                textViews[mark.id] = view
            }
        }
        if let editing, editing.superview === self { keep.insert(editing.markID) }
        for (id, view) in textViews where !keep.contains(id) {
            view.removeFromSuperview()
            textViews[id] = nil
        }
    }

    func addEditingView(_ view: TextMarkView) {
        addSubview(view, positioned: .above, relativeTo: indicatorView)
        textViews[view.markID] = view
    }

    func textView(at point: CGPoint) -> TextMarkView? {
        textViews.values.first { $0.frame.insetBy(dx: -6, dy: -4).contains(point) && !$0.isHidden }
    }

    func setLive(_ mark: Mark?) {
        liveView.mark = mark
    }

    // Animates a finished freehand stroke from the points it was drawn with into its own.
    func settle(_ mark: Mark, from: [CGPoint]) {
        finishSettling()
        let morph = Morph(mark: mark, from: from)
        self.morph = morph
        settlingView.mark = morph.shown
        morphTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            guard let self, let morph = self.morph else { return }
            if morph.progress < 1 {
                self.settlingView.mark = morph.shown
            } else {
                self.finishSettling()
            }
        }
    }

    // Hands the settling stroke, if there is one, over to the canvas to draw as it ended up.
    private func finishSettling() {
        guard let morph else { return }
        self.morph = nil
        morphTimer?.invalidate()
        morphTimer = nil
        settlingView.mark = nil
        setNeedsDisplay(MarkRenderer.bounds(of: morph.mark.kind))
    }

    func setIndicator(at point: CGPoint?, tool: Tool, color: PaletteColor) {
        indicatorView.show(at: point, tool: tool, color: color)
    }

    func showSheet(_ view: NSView?) {
        sheet?.removeFromSuperview()
        sheet = view
        guard let view else { return }
        let size = view.fittingSize
        view.frame = NSRect(
            x: ((bounds.width - size.width) / 2).rounded(), y: ((bounds.height - size.height) / 2).rounded(),
            width: size.width, height: size.height
        )
        addSubview(view)
    }

    var isShowingSheet: Bool { sheet != nil }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        for mark in shapes where mark.id != morph?.mark.id {
            guard MarkRenderer.bounds(of: mark.kind).intersects(dirtyRect) else { continue }
            MarkRenderer.draw(mark, in: context)
        }
    }

    // MARK: Input

    private func location(of event: NSEvent) -> CGPoint {
        convert(event.locationInWindow, from: nil)
    }

    override func mouseDown(with event: NSEvent) {
        session?.mouseDown(at: location(of: event), on: self, event: event)
    }

    override func mouseDragged(with event: NSEvent) {
        session?.mouseDragged(to: location(of: event), on: self, event: event)
    }

    override func mouseUp(with event: NSEvent) {
        session?.mouseUp(at: location(of: event), on: self, event: event)
    }

    override func mouseMoved(with event: NSEvent) {
        session?.mouseMoved(to: location(of: event), on: self)
    }

    override func mouseExited(with event: NSEvent) {
        session?.mouseMoved(to: nil, on: self)
    }

    override func keyDown(with event: NSEvent) {
        session?.keyDown(event)
    }

    override func flagsChanged(with event: NSEvent) {
        session?.flagsChanged(event)
    }

    // Keeps ⌘Z and ⇧⌘Z from reaching the menu bar, which this app doesn't show.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        return session?.keyDown(event) ?? false
    }
}

// One mark that changes from frame to frame: the line being drawn, or a stroke settling. The view is only as big as
// the mark and draws in the canvas's coordinates, so each frame draws that mark and nothing else.
private final class MarkView: NSView {
    var mark: Mark? {
        didSet {
            isHidden = mark == nil
            guard let mark else { return }
            let frame = MarkRenderer.bounds(of: mark.kind).integral
            self.frame = frame
            setBoundsOrigin(frame.origin)
            needsDisplay = true
        }
    }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("Not used") }

    override var isFlipped: Bool { true }
    // Clicks belong to the canvas.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let mark, let context = NSGraphicsContext.current?.cgContext else { return }
        MarkRenderer.draw(mark, in: context)
    }
}

// A small picture of the current tool in the current color, just below and right of the pointer. It moves with the
// pointer and is drawn again only when the tool or color changes.
private final class IndicatorView: NSView {
    private static let symbolSize: CGFloat = 15
    // Room around the symbol for its shadow.
    private static let margin: CGFloat = 4
    private static let offset: CGFloat = 12

    private var badge: (tool: Tool, color: PaletteColor)?

    init() {
        let side = Self.symbolSize + 2 * Self.margin
        super.init(frame: NSRect(x: 0, y: 0, width: side, height: side))
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("Not used") }

    override var isFlipped: Bool { true }
    // Clicks belong to the canvas.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func show(at point: CGPoint?, tool: Tool, color: PaletteColor) {
        isHidden = point == nil
        guard let point else { return }
        if badge?.tool != tool || badge?.color != color {
            badge = (tool, color)
            needsDisplay = true
        }
        setFrameOrigin(CGPoint(
            x: (point.x + Self.offset - Self.margin).rounded(), y: (point.y + Self.offset - Self.margin).rounded()
        ))
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let badge else { return }
        let configuration = NSImage.SymbolConfiguration(pointSize: Self.symbolSize, weight: .bold)
            .applying(.init(paletteColors: [badge.color.nsColor]))
        guard let symbol = NSImage(systemSymbolName: badge.tool.symbolName, accessibilityDescription: badge.tool.title)?
            .withSymbolConfiguration(configuration) else { return }
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.6)
        shadow.shadowBlurRadius = 2
        shadow.shadowOffset = .zero
        shadow.set()
        symbol.draw(in: bounds.insetBy(dx: Self.margin, dy: Self.margin))
    }
}

// A borderless panel over a whole display. It takes key input without switching away from the app in front, so the
// menu bar and windows underneath stay as they were.
final class OverlayWindow: NSPanel {
    init(screen: NSScreen, canvas: CanvasView) {
        super.init(
            contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = canvas
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
