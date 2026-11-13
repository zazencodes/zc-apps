import AppKit
import SwiftUI

// What the toolbar can ask the session to do.
struct ToolbarActions {
    var chooseColor: (Int) -> Void
    var chooseTool: (Tool) -> Void
    var chooseStyle: (LineStyle) -> Void
    var toggleLoops: () -> Void
    var stepSize: (_ up: Bool) -> Void
    var resetSize: () -> Void
    // Opens or closes the font list below the font button, whose frame in the toolbar view (from its top left) is given.
    var toggleFonts: (_ button: CGRect) -> Void
    var close: () -> Void
    // Called as the bar is dragged by its background. The panel follows the pointer.
    var drag: (_ ended: Bool) -> Void
}

final class SessionState: ObservableObject {
    @Published var isEditingText = false
}

struct ToolbarView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var state: SessionState
    let actions: ToolbarActions
    @State private var fontButton: CGRect = .zero

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                ForEach(0..<Palette.size, id: \.self) { index in
                    ColorKey(
                        color: preferences.palette.colors[index], number: index + 1,
                        isSelected: preferences.colorIndex == index
                    ) { actions.chooseColor(index) }
                }
            }
            separator
            HStack(spacing: 6) {
                ForEach(Tool.allCases) { tool in
                    ToolKey(tool: tool, isSelected: preferences.tool == tool) { actions.chooseTool(tool) }
                }
            }
            separator
            SizeControl(
                size: preferences.size(for: preferences.tool),
                standard: Preferences.defaultSize(for: preferences.tool),
                isText: preferences.tool == .text,
                step: actions.stepSize,
                reset: actions.resetSize
            )
            options
                .frame(width: Self.optionsWidth, alignment: .leading)
            Button(action: actions.close) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Theme.faintLegend)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .help("End annotating (\(preferences.hotKey.displayString))")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Theme.bar.opacity(0.97))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Theme.barEdge))
                .shadow(color: .black.opacity(0.4), radius: 14, y: 4)
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { _ in actions.drag(false) }
                        .onEnded { _ in actions.drag(true) }
                )
        )
        .padding(18)
        .fixedSize()
    }

    // What's after the size: the line styles, plus the loop switch for freehand, or the font for text. It's the same
    // width for every tool, so the bar doesn't change size as the tool changes.
    static let optionSpacing: CGFloat = 6
    static let styleKeyWidth: CGFloat = 38
    static let loopSwitchWidth: CGFloat = 54
    static var optionsWidth: CGFloat {
        let styles = CGFloat(LineStyle.allCases.count)
        return styles * styleKeyWidth + styles * optionSpacing + loopSwitchWidth
    }

    @ViewBuilder private var options: some View {
        switch preferences.tool {
        case .text:
            FontButton(fontName: preferences.fontName) { actions.toggleFonts(fontButton) }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { fontButton = $0 }
        case .freehand:
            HStack(spacing: Self.optionSpacing) {
                styleKeys(width: Self.styleKeyWidth)
                LoopSwitch(isOn: preferences.closesLoops, action: actions.toggleLoops)
            }
        case .arrow, .rectangle:
            // Without the loop switch, the style keys share its room.
            let styles = CGFloat(LineStyle.allCases.count)
            styleKeys(width: (Self.optionsWidth - (styles - 1) * Self.optionSpacing) / styles)
        }
    }

    private func styleKeys(width: CGFloat) -> some View {
        HStack(spacing: Self.optionSpacing) {
            ForEach(LineStyle.allCases) { style in
                StyleKey(
                    style: style, tool: preferences.tool, isSelected: preferences.lineStyles[preferences.tool] == style,
                    width: width
                ) { actions.chooseStyle(style) }
            }
        }
    }

    private var separator: some View {
        RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.1)).frame(width: 1.5, height: 22)
    }
}

private struct ColorKey: View {
    let color: PaletteColor
    let number: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: color.nsColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.25), lineWidth: 0.75)
                    )
                Text("\(number)")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(ink(on: color).opacity(0.55))
                    .padding(.trailing, 3.5)
                    .padding(.bottom, 2)
            }
            .frame(width: 24, height: 24)
            .padding(3)
            .overlay(
                RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                    .strokeBorder(Color.white.opacity(isSelected ? 0.95 : 0), lineWidth: 2)
            )
            .shadow(color: isSelected ? Color(nsColor: color.nsColor).opacity(0.6) : .clear, radius: 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Color \(number)")
    }
}

private struct ToolKey: View {
    let tool: Tool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: tool.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.selectedLegend : Theme.legend)
                    .padding(.trailing, 4)
                    .frame(width: 38, height: 30)
                Text(String(tool.key).uppercased())
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? Theme.selectedLegend.opacity(0.6) : Theme.faintLegend)
                    .padding(.trailing, 4)
                    .padding(.bottom, 2.5)
            }
            .background(KeycapBackground(selected: isSelected))
            .padding(.bottom, 1.5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(tool.title) (\(String(tool.key).uppercased()))")
    }
}

// A line style, shown as the current tool drawn in that style. The drawing keeps its size on a wider key.
private struct StyleKey: View {
    let style: LineStyle
    let tool: Tool
    let isSelected: Bool
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            let sample = Self.sample(tool, style: style, color: PaletteColor(NSColor(isSelected ? Theme.selectedLegend : Theme.legend)))
            Canvas { context, _ in
                context.withCGContext { MarkRenderer.draw(sample, in: $0) }
            }
            .frame(width: 38, height: 30)
            .frame(width: width)
            .background(KeycapBackground(selected: isSelected))
            .padding(.bottom, 1.5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(style.title) lines")
    }

    // The same seed every time, so the sample never changes.
    private static let sampleID = UUID(uuidString: "6A1C3E52-0B7D-4F19-9E2A-5D8C7B4F3A21")!

    static func sample(_ tool: Tool, style: LineStyle, color: PaletteColor) -> Mark {
        let pen = Pen(width: 2.5, style: style)
        let kind: Mark.Kind
        switch tool {
        case .freehand:
            let points = (0...24).map { step -> CGPoint in
                let t = CGFloat(step) / 24
                return CGPoint(x: 9 + 20 * t, y: 15 + 4.5 * sin(t * 2 * .pi))
            }
            kind = .stroke(points: points, closed: false, pen: pen)
        case .arrow:
            kind = .arrow(from: CGPoint(x: 10, y: 22), to: CGPoint(x: 28, y: 8), pen: pen)
        case .rectangle:
            kind = .rectangle(CGRect(x: 9, y: 8, width: 20, height: 14), pen: pen)
        case .text:
            preconditionFailure("Text has no line style")
        }
        return Mark(id: sampleID, display: 0, color: color, kind: kind)
    }
}

// Close loops, on or off: whether a freehand stroke that comes back around to its start closes into a smooth loop.
private struct LoopSwitch: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? Theme.selectedTop : Color.white.opacity(0.12))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(isOn ? 0.18 : 0.07), lineWidth: 0.75))
                    Circle()
                        .fill(isOn ? Theme.selectedLegend : Theme.faintLegend)
                        .padding(2)
                }
                .frame(width: 28, height: 16)
                Text("close loops")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(isOn ? Theme.legend : Theme.faintLegend)
                    .fixedSize()
            }
            .frame(width: ToolbarView.loopSwitchWidth, height: 30)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: isOn)
        }
        .buttonStyle(.plain)
        .help(isOn
            ? "Close loops is on: a stroke that comes back to its start closes into a smooth loop"
            : "Close loops is off: strokes stay as drawn")
    }
}

// The line width or text size, with [ and ] on either side. Below the number: "default" at the default, otherwise the
// default to go back to, which a click does.
private struct SizeControl: View {
    let size: CGFloat
    let standard: CGFloat
    let isText: Bool
    let step: (Bool) -> Void
    let reset: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            stepper("[", up: false)
            Button(action: reset) {
                VStack(spacing: 0) {
                    Text("\(Int(size))")
                        .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.legend)
                    Text(size == standard ? "default" : "default \(Int(standard))")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(size == standard ? Theme.faintLegend : Color(red: 1, green: 0.78, blue: 0.4))
                }
                .frame(minWidth: 46, minHeight: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(size == standard
                ? "\(isText ? "Text size" : "Line width") is at the default"
                : "Back to the default \(isText ? "text size" : "line width"), \(Int(standard))")
            stepper("]", up: true)
        }
    }

    private func stepper(_ key: String, up: Bool) -> some View {
        Button { step(up) } label: {
            Text(key)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.legend)
                .frame(width: 24, height: 30)
                .background(KeycapBackground(radius: 7))
                .padding(.bottom, 1.5)
        }
        .buttonStyle(.plain)
        .help(up ? (isText ? "Larger text" : "Thicker line") : (isText ? "Smaller text" : "Thinner line"))
    }
}

private struct FontButton: View {
    let fontName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // The family name, which is short enough for the slot. The font list shows the full names.
            HStack(spacing: 6) {
                Text(FontCatalog.isInstalled(fontName) ? FontCatalog.familyName(fontName) : "\(fontName) (missing)")
                    .font(Font(FontCatalog.font(fontName, size: 14)))
                    .foregroundStyle(Theme.legend)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.faintLegend)
            }
            .padding(.horizontal, 10)
            .frame(width: ToolbarView.optionsWidth, height: 30)
            .background(KeycapBackground(radius: 8))
            .padding(.bottom, 1.5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(FontCatalog.isInstalled(fontName) ? "Text font: \(FontCatalog.displayName(fontName))" : "Text font")
    }
}

// The toolbar's own small panel, above the canvases. It never becomes key, so typing keeps going to the canvas or the
// text being edited.
final class ToolbarPanel: NSPanel {
    init(view: some View) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10), styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = NSHostingView(rootView: view)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // The panel's content has a margin for the bar's shadow, which isn't part of the bar.
    static let margin: CGFloat = 18

    var fittingSize: NSSize { contentView!.fittingSize }
}
