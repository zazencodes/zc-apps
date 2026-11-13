import SwiftUI

// Every key Pretty Draw answers to, shown with /.
struct ShortcutSheet: View {
    let hotKey: String

    private struct Row: Identifiable {
        let keys: [String]
        let action: String
        var id: String { action }
    }

    private struct Section: Identifiable {
        let title: String
        let rows: [Row]
        var id: String { title }
    }

    private var columns: [[Section]] {
        [
            [
                Section(title: "Tools", rows: [
                    Row(keys: ["F"], action: "Freehand"),
                    Row(keys: ["A"], action: "Arrow"),
                    Row(keys: ["R"], action: "Rectangle"),
                    Row(keys: ["T"], action: "Text"),
                ]),
                Section(title: "Color and size", rows: [
                    Row(keys: ["1–5"], action: "Palette colors"),
                    Row(keys: ["[", "]"], action: "Thinner, thicker line"),
                    Row(keys: ["[", "]"], action: "Smaller, larger text (text tool)"),
                ]),
            ],
            [
                Section(title: "Drawing", rows: [
                    Row(keys: ["⇧"], action: "Hold for a straight freehand line"),
                    Row(keys: ["⌘", "Z"], action: "Undo, or bring back the last drawing"),
                    Row(keys: ["⇧", "⌘", "Z"], action: "Redo"),
                    Row(keys: ["⌫"], action: "Clear everything"),
                    Row(keys: [hotKey], action: "Start or end annotating"),
                    Row(keys: ["esc"], action: "End annotating"),
                    Row(keys: ["/"], action: "Show or hide these shortcuts"),
                ]),
                Section(title: "Typing text", rows: [
                    Row(keys: ["↩"], action: "New line (also ⇧↩)"),
                    Row(keys: ["⌃", "↓"], action: "New line below"),
                    Row(keys: ["esc"], action: "Done (or click elsewhere)"),
                ]),
            ],
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Pretty Draw")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.legend)
                Spacer()
                Text("Press / or esc to close")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.faintLegend)
            }
            HStack(alignment: .top, spacing: 36) {
                ForEach(Array(columns.enumerated()), id: \.offset) { column, sections in
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title.uppercased())
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .tracking(0.8)
                                    .foregroundStyle(Theme.faintLegend)
                                ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                                    HStack(spacing: 10) {
                                        HStack(spacing: 3) {
                                            ForEach(Array(row.keys.enumerated()), id: \.offset) { _, key in
                                                KeyLabel(text: key)
                                            }
                                        }
                                        .frame(width: column == 0 ? 64 : 92, alignment: .leading)
                                        Text(row.action)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Theme.legend)
                                    }
                                }
                            }
                        }
                    }
                    .frame(alignment: .leading)
                }
            }
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.bar.opacity(0.97))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.barEdge))
                .shadow(color: .black.opacity(0.45), radius: 24, y: 8)
        )
        .padding(30)
        .fixedSize()
    }
}
