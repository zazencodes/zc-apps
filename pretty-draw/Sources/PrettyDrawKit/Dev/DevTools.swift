import AppKit
import SwiftUI

// Renders the real drawing code to PNGs, so visual changes can be checked without driving the app. See AGENTS.md.
public enum DevTools {
    // Raw pointer input in thin grey under the guided stroke that comes out of it.
    public static func renderSmoothing(to directory: URL, palette: Palette = .classic) throws {
        let samples = SampleStrokes.all()
        let cell = CGSize(width: 440, height: 290)
        let columns = 2
        let rows = (samples.count + columns - 1) / columns
        let size = CGSize(width: cell.width * CGFloat(columns), height: cell.height * CGFloat(rows))
        let png = try renderPNG(size: size) { context in
            context.setFillColor(NSColor(white: 0.12, alpha: 1).cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            for (index, sample) in samples.enumerated() {
                let origin = CGPoint(
                    x: CGFloat(index % columns) * cell.width + 10,
                    y: CGFloat(index / columns) * cell.height + 24
                )
                context.saveGState()
                context.translateBy(x: origin.x, y: origin.y)
                var stroke = GuidedStroke(start: sample.points[0], width: SizeSteps.defaultLineWidth)
                sample.points.dropFirst().forEach { stroke.add($0) }
                let result = stroke.finishedWithGuidance(closingLoops: true)
                let color = palette.colors[index % Palette.size]
                let pen = Pen(width: SizeSteps.defaultLineWidth, style: .clean)
                MarkRenderer.draw(
                    Mark(display: 0, color: color, kind: .stroke(points: result.points, closed: result.closed, pen: pen)),
                    in: context
                )
                context.setStrokeColor(NSColor(white: 1, alpha: 0.9).cgColor)
                context.setLineWidth(1)
                context.addLines(between: sample.points)
                context.strokePath()
                context.restoreGState()
                let guidance = String(format: "guided %.0f%%", result.guidance * 100)
                label(
                    "\(sample.name)\(result.closed ? " · closed" : "") · \(guidance)",
                    at: CGPoint(x: origin.x, y: origin.y - 18)
                )
            }
        }
        try write(png, to: directory.appendingPathComponent("smoothing.png"))
    }

    // Every line style side by side: the sample strokes after guidance, rectangles and arrows, at the default width and
    // a thin one.
    public static func renderStyles(to directory: URL, palette: Palette = .classic) throws {
        let width = SizeSteps.defaultLineWidth
        var scenes: [(name: String, kinds: (Pen) -> [Mark.Kind])] = SampleStrokes.all().map { sample in
            var stroke = GuidedStroke(start: sample.points[0], width: width)
            sample.points.dropFirst().forEach { stroke.add($0) }
            let result = stroke.finished(closingLoops: true)
            return (sample.name, { [.stroke(points: result.points, closed: result.closed, pen: $0)] })
        }
        scenes += [
            ("rectangle", { [.rectangle(CGRect(x: 40, y: 30, width: 350, height: 190), pen: $0)] }),
            ("arrows", { pen in [
                .arrow(from: CGPoint(x: 40, y: 230), to: CGPoint(x: 330, y: 40), pen: pen),
                .arrow(from: CGPoint(x: 230, y: 200), to: CGPoint(x: 390, y: 170), pen: pen),
            ] }),
            ("small", { pen in [
                .rectangle(CGRect(x: 40, y: 40, width: 90, height: 44), pen: pen),
                .arrow(from: CGPoint(x: 200, y: 160), to: CGPoint(x: 260, y: 110), pen: pen),
                .stroke(points: [CGPoint(x: 40, y: 200), CGPoint(x: 380, y: 200)], closed: false, pen: pen),
            ] }),
            ("thin", { pen in
                let thin = Pen(width: 4, style: pen.style)
                return [
                    .rectangle(CGRect(x: 40, y: 30, width: 200, height: 120), pen: thin),
                    .arrow(from: CGPoint(x: 380, y: 230), to: CGPoint(x: 260, y: 110), pen: thin),
                ]
            }),
        ]

        let cell = CGSize(width: 440, height: 270)
        let size = CGSize(width: cell.width * CGFloat(LineStyle.allCases.count), height: cell.height * CGFloat(scenes.count) + 20)
        let png = try renderPNG(size: size) { context in
            context.setFillColor(NSColor(white: 0.12, alpha: 1).cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            for (column, style) in LineStyle.allCases.enumerated() {
                label(style.title, at: CGPoint(x: CGFloat(column) * cell.width + 10, y: 4), size: 14)
                for (row, scene) in scenes.enumerated() {
                    let origin = CGPoint(x: CGFloat(column) * cell.width, y: CGFloat(row) * cell.height + 28)
                    label(scene.name, at: CGPoint(x: origin.x + 10, y: origin.y))
                    context.saveGState()
                    context.translateBy(x: origin.x, y: origin.y + 14)
                    for (index, kind) in scene.kinds(Pen(width: width, style: style)).enumerated() {
                        let color = palette.colors[(row + index) % Palette.size]
                        MarkRenderer.draw(Mark(id: sampleID(row * 10 + index), display: 0, color: color, kind: kind), in: context)
                    }
                    context.restoreGState()
                }
            }
        }
        try write(png, to: directory.appendingPathComponent("styles.png"))
    }

    // A fixed ID per number, so hand-drawn samples look the same on every run.
    static func sampleID(_ number: Int) -> UUID {
        let mixed = UInt32(truncatingIfNeeded: (number + 1) &* 2_654_435_761)
        return UUID(uuidString: String(format: "%08X-%04X-4000-8000-000000000000", mixed, number))!
    }

    // MARK: Helpers

    static func label(_ text: String, at point: CGPoint, size: CGFloat = 12) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: .medium),
            .foregroundColor: NSColor(white: 1, alpha: 0.55),
        ]
        NSAttributedString(string: text, attributes: attributes).draw(at: point)
    }

    // Draws into a flipped 2× context, the way the canvas sees its points.
    static func renderPNG(size: CGSize, scale: CGFloat = 2, draw: (CGContext) -> Void) throws -> Data {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else { throw RenderError.bitmap }
        bitmap.size = size
        guard let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { throw RenderError.bitmap }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let flipped = NSGraphicsContext(cgContext: graphics.cgContext, flipped: true)
        NSGraphicsContext.current = flipped
        let context = flipped.cgContext
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        draw(context)
        context.flush()
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw RenderError.encoding }
        return data
    }

    static func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        print("Wrote \(url.path)")
    }

    enum RenderError: Error {
        case bitmap, encoding
    }
}

// MARK: - Toolbar, sheet and icon

extension DevTools {
    // The toolbar for each tool, the font list and the shortcut sheet, on a backdrop like a desktop.
    public static func renderInterface(to directory: URL, palette: Palette = .classic) throws {
        let name = "PrettyDrawRender-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = Preferences(defaults: defaults)
        if !palette.isBuiltIn {
            preferences.customPalettes = [palette]
        }
        preferences.paletteID = palette.id
        let actions = ToolbarActions(
            chooseColor: { _ in }, chooseTool: { _ in }, chooseStyle: { _ in }, toggleLoops: {}, stepSize: { _ in },
            resetSize: {}, toggleFonts: { _ in }, close: {}, drag: { _ in }
        )

        var images: [NSImage] = []
        // Tool, color, its line style, a size off the default, close loops.
        let toolbars: [(Tool, Int, LineStyle?, Bool, Bool)] = [
            (.rectangle, 0, .clean, false, true), (.arrow, 1, .handDrawn, true, true),
            (.freehand, 4, .handDrawn, false, true), (.freehand, 3, .clean, false, false), (.text, 2, nil, false, true),
        ]
        for (tool, color, style, offDefault, closesLoops) in toolbars {
            preferences.tool = tool
            preferences.colorIndex = color
            preferences.closesLoops = closesLoops
            if let style {
                preferences.lineStyles[tool] = style
            }
            preferences.lineWidth = offDefault ? 14 : SizeSteps.defaultLineWidth
            images.append(try snapshot(ToolbarView(preferences: preferences, state: SessionState(), actions: actions)))
        }
        images.append(try snapshot(FontList(
            custom: ["Didot-Bold", "MarkerFelt-Wide"], standard: Preferences.standardFonts, current: "MarkerFelt-Wide",
            minWidth: 0, choose: { _ in }
        )))
        images.append(try snapshot(ShortcutSheet(hotKey: preferences.hotKey.displayString)))

        let width = images.map(\.size.width).max()! + 40
        let height = images.map(\.size.height).reduce(40, +)
        let png = try renderPNG(size: CGSize(width: width, height: height)) { context in
            let backdrop = NSGradient(colors: [
                NSColor(red: 0.36, green: 0.42, blue: 0.62, alpha: 1), NSColor(red: 0.62, green: 0.55, blue: 0.5, alpha: 1),
            ])!
            backdrop.draw(in: CGRect(x: 0, y: 0, width: width, height: height), angle: -60)
            var y: CGFloat = 20
            for image in images {
                image.draw(
                    in: CGRect(x: (width - image.size.width) / 2, y: y, width: image.size.width, height: image.size.height),
                    from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil
                )
                y += image.size.height
            }
        }
        try write(png, to: directory.appendingPathComponent("interface.png"))
    }

    static func snapshot(_ view: some View) throws -> NSImage {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(origin: .zero, size: hosting.fittingSize)
        hosting.layoutSubtreeIfNeeded()
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { throw RenderError.bitmap }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let image = NSImage(size: hosting.bounds.size)
        image.addRepresentation(bitmap)
        return image
    }

    // The app icon at every size an .iconset needs.
    public static func renderIconSet(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let png = try renderPNG(size: CGSize(width: points, height: points), scale: CGFloat(scale)) { context in
                    context.scaleBy(x: CGFloat(points) / 1024, y: CGFloat(points) / 1024)
                    drawIcon(in: context)
                }
                let suffix = scale == 2 ? "@2x" : ""
                try png.write(to: directory.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
            }
        }
    }

    public static func renderIcon(to directory: URL) throws {
        let png = try renderPNG(size: CGSize(width: 1024, height: 1024), scale: 1) { drawIcon(in: $0) }
        try write(png, to: directory.appendingPathComponent("icon.png"))
    }

    // A dark tile with a single brushed loop, like an ensō, in the ZazenCodes colors, and an arrow pointing into it.
    static func drawIcon(in context: CGContext) {
        let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
        let tilePath = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
        context.addPath(tilePath)
        context.setFillColor(NSColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1).cgColor)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(tilePath)
        context.clip()
        let space = CGColorSpace(name: CGColorSpace.displayP3)!
        let background = CGGradient(colorsSpace: space, colors: [
            NSColor(red: 0.17, green: 0.16, blue: 0.2, alpha: 1).cgColor,
            NSColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1).cgColor,
        ] as CFArray, locations: [0, 1])!
        context.drawLinearGradient(background, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])

        // The loop: most of the way round an ellipse, open at the top right.
        let loop = CGMutablePath()
        let center = CGPoint(x: 548, y: 470)
        let start: CGFloat = -0.28 * .pi
        let sweep: CGFloat = 1.78 * .pi
        for step in 0...120 {
            let angle = start - sweep * CGFloat(step) / 120
            let wobble = 1 + 0.025 * sin(3 * angle)
            let point = CGPoint(x: center.x + 250 * cos(angle) * wobble, y: center.y + 215 * sin(angle) * wobble)
            step == 0 ? loop.move(to: point) : loop.addLine(to: point)
        }
        context.saveGState()
        context.addPath(loop.copy(strokingWithWidth: 74, lineCap: .round, lineJoin: .round, miterLimit: 1))
        context.clip()
        let ink = CGGradient(colorsSpace: space, colors: [
            NSColor(displayP3Red: 0.83, green: 0.70, blue: 0.98, alpha: 1).cgColor,
            NSColor(displayP3Red: 0.92, green: 0.52, blue: 0.76, alpha: 1).cgColor,
            NSColor(displayP3Red: 0.92, green: 0.41, blue: 0.38, alpha: 1).cgColor,
        ] as CFArray, locations: [0, 0.55, 1])!
        context.drawLinearGradient(ink, start: CGPoint(x: 280, y: 230), end: CGPoint(x: 800, y: 740), options: [])
        context.restoreGState()

        // The arrow, in mint, from the lower left toward the middle of the loop.
        let mint = NSColor(displayP3Red: 0.65, green: 1, blue: 0.74, alpha: 1).cgColor
        context.setStrokeColor(mint)
        context.setFillColor(mint)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(46)
        context.addPath(ArrowGeometry(from: CGPoint(x: 236, y: 800), to: CGPoint(x: 460, y: 560), width: 46).path)
        context.strokePath()
        context.restoreGState()
    }
}
